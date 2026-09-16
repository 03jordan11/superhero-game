extends RigidBody3D
const MODEL=preload("res://assets/aircraft/helicopter/helicopter.tscn")
const FIRE=preload("res://effects/helicopter_wreck_fire.gdshader")
var lifetime:=30.0
var age:=0.0
var _fire_material: ShaderMaterial
var _flames: Node3D
var model: Node3D
func _ready() -> void:
	name="HelicopterWreck"
	add_to_group(&"helicopter_wreck")
	mass=1800; continuous_cd=true; collision_layer=1; collision_mask=1
	linear_damp=.2; angular_damp=.4
	model=MODEL.instantiate(); model.rotors_spinning=false
	add_child(model)
	var black:=StandardMaterial3D.new(); black.albedo_color=Color(.025,.022,.02); black.roughness=1
	for part in model.find_children("*","MeshInstance3D",true,false): part.material_override=black
	model.set_process(false)
	var originals:=model.get_node("ParkedCollision")
	for child in originals.get_children():
		var solid:=CollisionShape3D.new(); solid.shape=child.shape; solid.transform=child.transform; add_child(solid)
	originals.queue_free()
	_flames=Node3D.new(); _flames.position=Vector3(0,2,.3); add_child(_flames)
	_fire_material=ShaderMaterial.new(); _fire_material.shader=FIRE
	for i in range(3):
		var flame:=MeshInstance3D.new(); var quad:=QuadMesh.new(); quad.size=Vector2(3.8,4.5)
		flame.mesh=quad; flame.material_override=_fire_material; flame.position.y=2
		flame.rotation.y=i*PI/3; flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; _flames.add_child(flame)
	var smoke: GPUParticles3D=load("res://assets/effects/stack_smoke/stack_smoke.tscn").instantiate()
	# Wreck smoke is short-lived and independent of the industrial emitter pool.
	smoke.set_script(null); smoke.emitting=true; smoke.amount=24; smoke.position=Vector3(0,2,.3)
	smoke.process_material=smoke.process_material.duplicate()
	smoke.process_material.color=Color(.09,.085,.08,.65)
	smoke.process_material.color_ramp=null
	add_child(smoke)
func _physics_process(delta: float) -> void:
	age+=delta
	_fire_material.set_shader_parameter("elapsed",age)
	# Flames rise in world space as the fuselage tumbles beneath them.
	_flames.global_basis=Basis.IDENTITY
	if age>=lifetime: queue_free()
