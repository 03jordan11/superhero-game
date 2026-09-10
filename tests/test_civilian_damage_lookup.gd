extends SceneTree

const LOD = preload("res://scripts/npc-scripts/civilian_capsule_lod.gd")
const DAMAGE = preload("res://scripts/combat-scripts/damage_info.gd")

class TestCrowd:
	extends Node3D
	var _active: Node3D


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var crowd := TestCrowd.new()
	crowd._active = Node3D.new()
	crowd.add_child(crowd._active)
	var lod := LOD.new()
	crowd.add_child(lod)
	root.add_child(crowd)
	var near := lod.create_capsule(-1)
	near.position = Vector3(-0.1, 0.0, -0.1)
	crowd._active.add_child(near)
	var second := lod.create_capsule(-1)
	second.position = Vector3(0.1, 0.0, 0.1)
	crowd._active.add_child(second)
	for i in 200:
		var far := lod.create_capsule(-1)
		far.position = Vector3(100.0 + i * 10.0, 0.0, 100.0)
		crowd._active.add_child(far)
	var origin := Vector3(0.0, 0.8, 0.0)
	assert(lod._get_damage_candidates(origin, 0.2).size() == 2)
	var info := DAMAGE.new(15.0)
	assert(lod.apply_melee_damage(origin, 0.2, info))
	assert(near.pending_damage.size() == 1 and second.pending_damage.is_empty())
	lod.apply_radius_damage(origin, 0.2, info)
	assert(near.pending_damage.size() == 2 and second.pending_damage.size() == 1)
	# Teleports update the index immediately, even before the next render frame.
	near.position = Vector3(3000.0, 0.0, 0.0)
	assert(lod._get_damage_candidates(origin, 0.2).size() == 1)
	near.position = Vector3.ZERO
	assert(lod._get_damage_candidates(origin, 0.2).size() == 2)
	# Horizontal buckets remain a broad phase; vertical distance still matters.
	var high := lod.create_capsule(-1)
	high.position = Vector3(0.0, 20.0, 0.0)
	crowd._active.add_child(high)
	lod.apply_radius_damage(origin, 0.2, info)
	assert(high.pending_damage.is_empty())
	second.free()
	assert(lod._get_damage_candidates(origin, 0.2).size() == 2)
	near.reparent(crowd)
	assert(lod._get_damage_candidates(origin, 0.2).size() == 1)
	near.reparent(crowd._active)
	assert(lod._get_damage_candidates(origin, 0.2).size() == 2)
	near.queue_free()
	assert(not lod._get_damage_candidates(origin, 0.2).has(near))
	assert(lod._get_damage_candidates(origin, 100000.0).size() == 201)
	crowd.free()
	assert(lod == null or not is_instance_valid(lod))
	print("PASS: civilian damage checks nearby candidates, preserves hit order, and tracks motion/removal")
	quit()
