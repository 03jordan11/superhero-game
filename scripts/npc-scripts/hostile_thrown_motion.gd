extends Node
## Sweeps the existing hostile capsule until its first physical impact.
const DAMAGE=preload("res://scripts/combat-scripts/damage_info.gd")
var body: HostileBase
var source: PlayerCharacter
var impact_damage:=0.0
var elapsed:=0.0
var resolved:=false

func start(person: HostileBase, thrower: PlayerCharacter, launch: Vector3, damage: float) -> void:
	body=person; source=thrower; impact_damage=damage
	body.is_thrown=true; body.velocity=launch; body.set_physics_process(false)
	body.add_collision_exception_with(source)
	body.animation_controller.play_knockback()

func _physics_process(delta: float) -> void:
	if resolved or not is_instance_valid(body): queue_free(); return
	if not is_instance_valid(source): source=null
	if body.is_dead: _finish(); return
	elapsed+=delta
	if is_instance_valid(source) and body.global_position.distance_to(source.global_position)>3.0:
		body.remove_collision_exception_with(source)
	body.velocity+=body.get_gravity()*delta
	var collision:=body.move_and_collide(body.velocity*delta)
	if collision!=null:
		# Consume before damage callbacks: one impact, never repeated on resting contact.
		resolved=true
		var direction:=body.velocity.normalized()
		var struck=collision.get_collider()
		if struck is HostileBase and struck!=body and not struck.is_dead:
			var hit=DAMAGE.new(impact_damage*.5,collision.get_position(),direction,&"knockback",source)
			hit.force_knockdown=true; hit.damage_type=&"thrown_hostile"
			struck.apply_damage(hit)
		var self_hit=DAMAGE.new(impact_damage,collision.get_position(),direction,&"knockback",source)
		self_hit.force_knockdown=true; self_hit.damage_type=&"thrown_hostile"
		body.apply_damage(self_hit)
		_finish()
	elif elapsed>=15.0:
		# Off-map misses eventually resume ordinary falling; timeout never deals damage.
		_finish()

func _finish() -> void:
	resolved=true
	if is_instance_valid(body):
		if is_instance_valid(source): body.remove_collision_exception_with(source)
		body.is_thrown=false
		if not body.is_dead: body.set_physics_process(true)
	queue_free()
