extends Node3D
## Animation-only paired staging. No AI, damage, pickup or throw gameplay.
const LIBRARY=preload("res://assets/animations/authored-combo/hero_combo.glb")
const MODEL=preload("res://assets/characters/Superhero-male/Superhero_Male_FullBody.gltf")
var players: Array[AnimationPlayer]=[]
var pairs: Array[String]=[]
var clip_data: Dictionary={}
var selected:="Hold"
var elapsed:=0.0
var playing:=true
var speed:=1.0
var camera: Camera3D
var yaw:=.65
var pitch:=.2
var distance:=3.3
var scrub: HSlider
var timing: Label
var picker: OptionButton

func _ready() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/authored-combo/grab_manifest.json"))
	for clip in manifest.clips:
		if clip.role=="Hero": pairs.append(clip.pair); clip_data[clip.pair]=clip
	for role in ["Hero","Victim"]:
		var actor: Node3D=MODEL.instantiate(); actor.name=role; add_child(actor)
		var anim:=AnimationPlayer.new(); actor.add_child(anim)
		anim.add_animation_library("Combat",LIBRARY)
		anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		players.append(anim)
		if role=="Victim":
			var material:=StandardMaterial3D.new(); material.albedo_color=Color(.17,.35,.53); material.roughness=.8
			for mesh in actor.find_children("*","MeshInstance3D",true,false): mesh.material_override=material
	var env_node:=WorldEnvironment.new(); var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color(.055,.075,.105)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color(.8,.86,1); env.ambient_light_energy=.6
	env_node.environment=env; add_child(env_node)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-30,0); light.light_energy=1.5; add_child(light)
	var fill:=DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-30,140,0); fill.light_energy=.7; add_child(fill)
	var floor_mesh:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(30,30); floor_mesh.mesh=plane
	var floor_mat:=StandardMaterial3D.new(); floor_mat.albedo_color=Color(.10,.13,.17); floor_mat.roughness=.95
	floor_mesh.material_override=floor_mat; add_child(floor_mesh)
	camera=Camera3D.new(); camera.fov=50; camera.h_offset=-.55; add_child(camera); camera.make_current(); _update_camera()
	var canvas:=CanvasLayer.new(); add_child(canvas)
	var panel:=PanelContainer.new(); panel.position=Vector2(16,16); panel.custom_minimum_size=Vector2(520,0); canvas.add_child(panel)
	var rows:=VBoxContainer.new(); panel.add_child(rows)
	var title:=Label.new(); title.text="GRAB ANIMATIONS  |  Player + blue victim"; rows.add_child(title)
	picker=OptionButton.new(); rows.add_child(picker)
	for pair in pairs: picker.add_item(pair)
	picker.select(pairs.find(selected)); picker.item_selected.connect(func(index: int): select_pair(pairs[index]))
	var buttons:=HBoxContainer.new(); rows.add_child(buttons)
	var pause:=Button.new(); pause.text="Play / Pause (Space)"; pause.pressed.connect(func(): playing=not playing); buttons.add_child(pause)
	var restart:=Button.new(); restart.text="Restart"; restart.pressed.connect(func(): elapsed=0; playing=true); buttons.add_child(restart)
	var rate:=OptionButton.new(); rate.add_item("1x speed"); rate.add_item("0.25x speed"); buttons.add_child(rate)
	rate.item_selected.connect(func(index: int): speed=1.0 if index==0 else .25)
	scrub=HSlider.new(); scrub.step=.001; rows.add_child(scrub)
	scrub.value_changed.connect(func(value: float): elapsed=value; playing=false; _pose())
	timing=Label.new(); rows.add_child(timing)
	var help:=Label.new(); help.text="Drag RMB to orbit · Wheel to zoom · Scrub to inspect contact\nPreview only: release/flight trajectory and damage come later."; rows.add_child(help)
	select_pair(selected)

func select_pair(pair: String) -> void:
	selected=pair; elapsed=0; playing=true
	picker.select(pairs.find(pair))
	scrub.max_value=clip_data[pair].duration
	players[0].play("Combat/Hero_"+pair)
	players[1].play("Combat/Victim_"+pair)
	_pose()

func _process(delta: float) -> void:
	if playing:
		elapsed+=delta*speed
		var length: float=clip_data[selected].duration
		if clip_data[selected].loop: elapsed=fposmod(elapsed,length)
		else: elapsed=minf(elapsed,length)
	_pose()

func _pose() -> void:
	for anim in players: anim.seek(elapsed,true)
	scrub.set_value_no_signal(elapsed)
	timing.text="%.2f / %.2f s   %s"%[elapsed,clip_data[selected].duration,str(clip_data[selected].events)]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE: playing=not playing
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
		yaw-=event.relative.x*.008; pitch=clampf(pitch+event.relative.y*.008,-.3,1.2); _update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(2,distance-.3)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(10,distance+.3)
		_update_camera()

func _update_camera() -> void:
	var focus:=Vector3(0,1,.55)
	camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(focus)
