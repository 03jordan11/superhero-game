class_name RescuePatient
extends "res://scripts/npc-scripts/civilian.gd"
## Living, protected civilian using a frozen death pose as an injury placeholder.

var encounter: BaseEncounter
var carrier: PlayerCharacter
var skeleton: Skeleton3D

func get_carry_anchor_position() -> Vector3:
	if skeleton == null: return global_position
	var pelvis := skeleton.find_bone("Hips")
	return skeleton.to_global(skeleton.get_bone_global_pose(pelvis).origin) if pelvis >= 0 else global_position

func _ready() -> void:
	super()
	for node in $Superhero_Female_FullBody.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	add_to_group(&"rescue_patient")
	health_label.hide()
	collision_layer = 0 # Cannot obstruct the hero or become a combat target.
	collision_mask = 1
	var shape := $CollisionShape3D as CollisionShape3D
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.28, 0)
	shape.rotation.x = PI / 2.0
	var animator := animation_controller.animation_player as AnimationPlayer
	animator.play("Death01")
	animator.seek(maxf(animator.get_animation("Death01").length - 0.01, 0.0), true)
	animator.pause()

func apply_damage(_damage_info) -> bool:
	return false

func _physics_process(delta: float) -> void:
	if is_instance_valid(carrier): return
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor(): velocity += get_gravity() * delta
	move_and_slide()

func start_flee(_target: Node3D) -> void:
	pass
