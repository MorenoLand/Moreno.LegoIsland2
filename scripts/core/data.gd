class_name Data
extends RefCounted

static var root := ""
static var _index := {}
static var _ready := false

# When there is no local install (a browser), the archives are fetched over HTTP
# into user:// instead. `read` stays synchronous; the loading screen awaits
# `prepare` before it builds a scene.
static var remote_base := ""
static var fetched := {}

# Set trace to true to record every file that gets read, so we can see how much
# of the game data a screen actually needs.
static var trace := false
static var touched := {}


static func is_remote() -> bool:
	return remote_base != ""


static func indexed() -> int:
	return _index.size()


## Reads the shipped list of archives so we know what exists without being able
## to list a folder.
static func archives() -> Array:
	var out: Array = []
	for line in Table.field("res://data/archives.txt", 0):
		if line.begins_with("#") or line == "":
			continue
		out.append(line)
	return out


static func archive_size(name: String) -> int:
	for row in Table.rows("res://data/archives.txt"):
		if row.size() >= 2 and String(row[0]) == name:
			return int(row[1])
	return 0


## Builds the file index by fetching every .bod directory. Small: they total well
## under a megabyte.
static func locate_remote(base: String) -> bool:
	if _ready:
		return true
	remote_base = base
	for name in archives():
		var bytes := await _fetch(base + name + ".bod")
		if bytes.size() < 32:
			continue
		_load_directory_bytes(name, bytes)
	_ready = true
	return not _index.is_empty()


## Downloads whole archives into user://. Returns true when everything asked for
## is present, so a scene can then be built with ordinary synchronous reads.
static func prepare(names: Array) -> bool:
	if not is_remote():
		return true
	var ok := true
	for n in names:
		if not await fetch_archive(String(n)):
			ok = false
	return ok


static func fetch_archive(name: String) -> bool:
	if not is_remote():
		return true
	if fetched.has(name):
		return true
	var cached := cache_path(name)
	if FileAccess.file_exists(cached):
		fetched[name] = true
		return true
	DirAccess.make_dir_recursive_absolute("user://cache")
	var bytes := await _fetch(remote_base + name + ".bob")
	if bytes.is_empty():
		return false
	var file := FileAccess.open(cached, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	fetched[name] = true
	return true


static func cache_path(name: String) -> String:
	return "user://cache/%s.bob" % name


static func _fetch(url: String) -> PackedByteArray:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return PackedByteArray()
	var http := HTTPRequest.new()
	# This is first called from boot's _ready, while the tree is still setting up,
	# so the node has to go in on a later frame or add_child is refused.
	loop.root.add_child.call_deferred(http)
	await loop.process_frame
	await loop.process_frame
	if not is_instance_valid(http) or not http.is_inside_tree():
		if is_instance_valid(http):
			http.queue_free()
		return PackedByteArray()
	http.timeout = 120.0
	if http.request(url) != OK:
		http.queue_free()
		return PackedByteArray()
	# Wait for the signal. Polling get_http_client_status() is wrong: right after
	# request() the status has not become REQUESTING yet, so the loop would fall
	# straight through and free the node, aborting the request.
	var answer: Array = await http.request_completed
	var code: int = int(answer[1]) if answer.size() > 1 else 0
	var body: PackedByteArray = answer[3] if answer.size() > 3 else PackedByteArray()
	http.queue_free()
	return body if code == 200 else PackedByteArray()


static func locate() -> bool:
	if _ready:
		return true
	root = _find_root()
	if root == "":
		return false
	var dir := DirAccess.open(root.path_join("_data"))
	if dir == null:
		return false
	for file in dir.get_files():
		if file.to_lower().ends_with(".bod"):
			_load_directory(root.path_join("_data").path_join(file.get_basename()))
	_ready = true
	return true


static func exists(path: String) -> bool:
	return _index.has(_key(path))


static func read(path: String) -> PackedByteArray:
	var entry: Array = _index.get(_key(path), [])
	if entry.is_empty():
		# Not in an archive. On the web it has been fetched into the cache.
		var cached := cache_file(path)
		if FileAccess.file_exists(cached):
			var hit := FileAccess.get_file_as_bytes(cached)
			if trace:
				_record(path, hit.size(), "cached")
			return hit
		if is_remote():
			# A web build has no local data folder. Falling through to a relative
			# path would ask the browser for file:/// and raise a security error,
			# so report the miss instead.
			return PackedByteArray()
		var loose := root.path_join(path.replace("\\", "/"))
		if FileAccess.file_exists(loose):
			var whole := FileAccess.get_file_as_bytes(loose)
			if trace:
				_record(path, whole.size(), "loose")
			return whole
		return PackedByteArray()
	if trace:
		_record(path, entry[2], String(entry[0]).get_file())
	var file := FileAccess.open(entry[0], FileAccess.READ)
	if file == null:
		return PackedByteArray()
	file.seek(entry[1])
	return file.get_buffer(entry[2])


static func cache_file(path: String) -> String:
	return "user://cache/%s" % path.replace("\\", "/").to_lower()


## Downloads a file that sits loose in the data folder instead of inside an
## archive - the sounds and the save template are all like this.
static func fetch_file(path: String) -> bool:
	if not is_remote():
		return true
	var clean := path.replace("\\", "/")
	# remote_base already ends in _data/, and the loose paths start with it too
	if clean.begins_with("_data/"):
		clean = clean.substr(6)
	var cached := cache_file(path)
	if FileAccess.file_exists(cached):
		return true
	var bytes := await _fetch(remote_base + clean)
	if bytes.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(cached.get_base_dir())
	var file := FileAccess.open(cached, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	return true


static func fetch_files(paths: Array) -> void:
	for p in paths:
		await fetch_file(String(p))


## Returns a path VideoStreamTheora can open, or "" if the movie is not available.
##
## The web export excludes assets/fmv/* because the four .ogv files are 122 MB
## and would dominate the download. So on the web they are fetched on demand
## from the same host that serves _data/ and land in the cache, exactly like the
## loose sounds already are. VideoStreamTheora reads through FileAccess, so a
## user:// path works as well as a res:// one.
static func fetch_movie(name: String) -> String:
	var packaged := "res://assets/fmv/%s.ogv" % name
	if FileAccess.file_exists(packaged):
		return packaged
	if not is_remote():
		return ""
	var remote := "_data/fmv/%s.ogv" % name
	if await fetch_file(remote):
		return cache_file(remote)
	return ""


static func _record(path: String, size: int, source: String) -> void:
	touched[path] = {"size": size, "source": source}


static func read_text(path: String) -> String:
	var bytes := read(path)
	var out := ""
	for b in bytes:
		out += char(b)
	return out


static func _key(path: String) -> String:
	return path.replace("\\", "/").to_lower()


static func _find_root() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--root="):
			return arg.substr(7)
	var env := OS.get_environment("LI2_ROOT")
	if env != "":
		return env
	var config := ConfigFile.new()
	if config.load("user://config.cfg") == OK:
		return config.get_value("data", "root", "")
	return ""


static func _load_directory(base: String) -> void:
	var bod := FileAccess.get_file_as_bytes(base + ".bod")
	if bod.size() < 32:
		return
	_index_directory(base + ".bob", bod)


static func _load_directory_bytes(name: String, bod: PackedByteArray) -> void:
	_index_directory(cache_path(name), bod)


static func _index_directory(bob: String, bod: PackedByteArray) -> void:
	if bod.size() < 32:
		return
	var names_len := bod.decode_u32(bod.size() - 16)
	var count := bod.decode_u32(bod.size() - 12)
	var records := []
	for i in count:
		var at := names_len + i * 16
		records.append([bod.slice(at, at + 4).get_string_from_ascii(), bod.decode_u32(at + 4), bod.decode_u32(at + 8), bod.decode_u32(at + 12)])
	_walk(bob, bod, records, 0, "")


static func _walk(bob: String, bod: PackedByteArray, records: Array, index: int, prefix: String) -> void:
	var rec: Array = records[index]
	var name := _name_at(bod, rec[3])
	var here := name if prefix == "" else prefix + "/" + name
	for child in range(rec[2], rec[2] + rec[1]):
		var c: Array = records[child]
		if c[0] == "DIRY":
			_walk(bob, bod, records, child, here)
		else:
			_index[(here + "/" + _name_at(bod, c[3])).to_lower()] = [bob, c[2], c[1]]


static func _name_at(bod: PackedByteArray, offset: int) -> String:
	var end := offset
	while bod[end] != 0:
		end += 1
	return bod.slice(offset, end).get_string_from_ascii()
