class_name EngineSetup
extends RefCounted

## Wires the ported behaviour constructors into a ScriptContext. Anything not listed here
## is still a StubBehaviour (see AGENTS.md for the worklist).

static func register_ports(ctx: ScriptContext, services: ActorServices, vars) -> void:
	var f := ctx.factories
	ctx.services = services
	f[Ctor.FLAG_SETTER] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return FlagSetterBehaviour.from_descriptor(desc, services, vars)
	f[Ctor.VAR_OR_STEP] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return VarOrStep.from_descriptor(desc, vars)
	f[Ctor.BOT_END] = func(desc: Descriptor, _slot: int, _c: ScriptContext, tag: int) -> Behaviour:
		return BotEndBehaviour.from_descriptor(desc, services, vars, tag)
	f[Ctor.TELEPORT_STEP] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return TeleportStep.from_descriptor(desc, services, vars)
	f[Ctor.NOTE_EMITTER] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return NoteEmitter.from_descriptor(desc, services)
	f[Ctor.NULL_STEP] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return NullStep.from_descriptor(desc, c.actor)
	f[Ctor.TURN_TO_PEPPER] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return TurnToPepper.from_descriptor(desc, services, vars, c.player)
	f[Ctor.MEET_PEPPER] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return MeetPepper.from_descriptor(desc, services, vars)
	f[Ctor.NODE_SWING] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return NodeSwing.from_descriptor(desc, services, c.actor)
	f[Ctor.SCALE_MORPH] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return ScaleMorph.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.WALK_RAMP] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return WalkRamp.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.TALK_NODE] = func(desc: Descriptor, _slot: int, c: ScriptContext, tag: int) -> Behaviour:
		return TalkNode.from_descriptor(desc, services, vars, c.actor, tag)
	f[Ctor.PATH_WALKER] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return PathWalker.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.START_CSM] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return StartCSM.from_descriptor(desc, services, vars)
	f[Ctor.ZONE_TRIGGER] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return ZoneTrigger.from_descriptor(desc, services, vars)
	f[Ctor.DOOR_SWING] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return DoorSwing.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.SIREN_VEHICLE] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return SirenVehicle.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.HOLO_GUIDE] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return HoloGuide.from_descriptor(services, vars, c.actor)
	f[Ctor.RIDE_GATE] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return RideGate.from_descriptor(desc, services, vars)
	f[Ctor.PULSE_SCALE] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return PulseScale.from_descriptor(services, vars, c.actor)
	f[Ctor.PATROL_FALL] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return PatrolFall.from_descriptor(desc, services, vars)
	f[Ctor.BRICK_BOT] = func(desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return BrickBot.from_descriptor(desc, services, vars)
	f[Ctor.HOP_BOMB] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return HopBomb.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.BOT_DEFEAT] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return BotDefeat.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.RIDE_MACHINE] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, tag: int) -> Behaviour:
		return RideMachine.from_descriptor(services, vars, tag)
	f[Ctor.BOAT_DRIVE] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return BoatDrive.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.GUIDE_WALKER] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return GuideWalker.from_descriptor(desc, services, vars, c.actor)
	f[Ctor.FLYING_CRAFT] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return FlyingCraft.from_descriptor(services, vars, c.actor)
	f[Ctor.MUSIC_EMITTER] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return MusicEmitter.from_descriptor(services, vars)
	f[Ctor.HORSE] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return Horse.from_descriptor(services, vars, c.actor)
	f[Ctor.HORSE_RIDER] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return HorseRider.from_descriptor(services, vars)
	f[Ctor.CASTLE_MODE] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return CastleMode.from_descriptor(services, vars)
	f[Ctor.HORSE_FOLLOWER] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return HorseFollower.from_descriptor(services)
	f[Ctor.SKATE] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return Skate.from_descriptor(services, vars)
	f[Ctor.SKATE_ENTRY] = f[Ctor.SKATE]
	f[Ctor.ISLAND_MODE] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return IslandMode.from_descriptor(services, vars)
	f[Ctor.GEM] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return Gem.from_descriptor(services, vars, c.actor)
	f[Ctor.TUMBLEWEED] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return Tumbleweed.from_descriptor(services, vars, c.actor)
	f[Ctor.SCORPION] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return Scorpion.from_descriptor(services, vars, c.actor)
	f[Ctor.CASTLE_CUES] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return CastleCues.from_descriptor(services, vars)
	f[Ctor.PAGE_SPINNER] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return PageSpinner.from_descriptor()
	f[Ctor.ANCHOR_SWING] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return AnchorSwing.from_descriptor()
	f[Ctor.CLAM_HINGE] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return ClamHinge.from_descriptor(services)
	f[Ctor.OCTOPUS_ARM] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return OctopusArm.from_descriptor(services)
	f[Ctor.FISH_SWARM] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return FishSwarm.from_descriptor(desc, services, services.shared["dive_graph"], c.actor)
	f[Ctor.SWIMMER] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return Swimmer.from_descriptor(desc, services, c.actor)
	f[Ctor.DIVE_CAMERA] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return DiveCamera.from_descriptor(services, c.actor)
	f[Ctor.DIVE_BRICK] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return DiveBrick.from_descriptor(services, c.actor)
	f[Ctor.DIVE_CANNON] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return DiveCannon.from_descriptor(services)
	f[Ctor.CANNON_BALL] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return CannonBall.from_descriptor(services)
	f[Ctor.DIVE_PIRATE] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return DivePirate.from_descriptor(services, c.actor)
	f[Ctor.DIVE_DOLPHIN] = func(desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return DiveDolphin.from_descriptor(desc, services, services.shared["dive_graph"], c.actor)
	f[Ctor.CAROUSEL_RIDE] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return CarouselRide.from_descriptor(services)
	f[Ctor.RIDER_CLIPS] = func(_desc: Descriptor, _slot: int, _c: ScriptContext, _tag: int) -> Behaviour:
		return RiderClips.from_descriptor(services)
	f[Ctor.RATTUS] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return Rattus.from_descriptor(services, c.actor)
	f[Ctor.BRICK_PICKUP] = func(_desc: Descriptor, _slot: int, c: ScriptContext, _tag: int) -> Behaviour:
		return BrickPickup.from_descriptor(services, vars, c.actor)
