class_name ZonePrograms
extends RefCounted

## The zone programs, by zone folder name.

static func for_zone(zone: String) -> ZoneProgram:
	match zone:
		"z16PYA":
			return PyramidProgram.new()
		"z36CNT":
			return CarouselProgram.new()
		"z08BKD":
			return DiveProgram.new()
		"z07CSI":
			return CastleProgram.new()
		"z14OSD":
			return OsdProgram.new()
	return null
