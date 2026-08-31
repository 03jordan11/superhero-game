class_name PlayerCombatController
extends Node

var animation_controller: PlayerAnimationController

@export var punch_forward_speed: float = 8.0
@export var punch_forward_delay: float = 0.25
@export var punch_forward_duration: float = 0.08

var punch_time: float = 0.0
var is_punch_active: bool = false

func setup(target_animation_controller: PlayerAnimationController) -> void:
	animation_controller = target_animation_controller


func request_punch() -> void:
	if animation_controller == null:
		return
		
	if animation_controller.play_fighting_animation("Punch_01"):
		punch_time = 0.0
		is_punch_active = true
	
func update_punch_momentum(body: CharacterBody3D, delta: float) -> void:
	if not is_punch_active:
		return
	
	if not animation_controller.is_fighting:
		is_punch_active = false
		return
	punch_time += delta
	
	var push_end_time := punch_forward_delay + punch_forward_duration
	if punch_time < punch_forward_delay or punch_time > push_end_time:
		return
		
	var forward := -body.transform.basis.z.normalized()
	body.velocity.x = forward.x * punch_forward_speed
	body.velocity.z = forward.z * punch_forward_speed
