class_name ZonePrograms
extends RefCounted

## The zone programs, by zone folder name.

static func for_zone(zone: String) -> ZoneProgram:
	match zone:
		"z16PYA":
			return PyramidProgram.new()
		"z14OSD":
			return OsdProgram.new()
	return null
