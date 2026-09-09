extends SceneTree
## Offline industrial asset authoring. This generator shares helpers with residential.
const Builder = preload("res://assets/generated-buildings/residential/tools/building_builder.gd")
const OUT = "res://assets/generated-buildings/industrial/"
const NAMES = ["QUAY FREIGHT","RIVET TOOLWORKS","IRONVALE FOUNDRY","NORTH COLD STORE","CROSSLINE DEPOT","MILLSTONE TEXTILE","CANAL BOILERWORKS","BULKLINE MILL","WARD POWER","DOCKSIDE REPAIR"]
var b: RefCounted

func _initialize() -> void:
	b = Builder.new(OUT,"industrial",NAMES)
	b.make_materials([
		["red_factory","80564a","43565b","factory"],
		["buff_factory","a39476","40545c","factory"],
		["gray_cladding","929a96","42575e","cladding"],
		["blue_cladding","6e858a","344b53","warehouse"],
		["brick_wall","765044","35454b","blank_brick"],
		["concrete_panel","92918a","425157","warehouse"]
	])
	for i in range(10):
		b.begin()
		match i:
			0:
				b.box(34,26,0,8.5,"brick_wall")
				b.band(34.2,26.2,8.5,"stone",Vector2.ZERO,0.4)
				b.box(10,9,8.9,12.6,"red_factory",Vector2(-9,5))
				loading(i,26,[-10,0,10],6.5)
				b.box(28,1.8,5.3,5.55,"dark",Vector2(0,-13.7),"dark")
				b.finish(i,"Brick freight warehouse with three loading bays, canopy, and office penthouse")
			1:
				b.box(30,24,0,7,"red_factory")
				b.saw_roof(30,24,7,2.8,4)
				loading(i,24,[-8,8],5.4)
				b.finish(i,"Four-bay sawtooth machine workshop with opaque clerestory glazing")
			2:
				b.box(30,26,0,11,"brick_wall")
				b.gable(30.3,26.3,11,4,"roof")
				stack(3,11,25,Vector2(-10,8))
				loading(i,26,[-6,6],7)
				b.finish(i,"Pitched-roof foundry with an eight-sided tapered chimney")
			3:
				b.box(32,26,0,12,"gray_cladding")
				b.band(32.2,26.2,12,"metal",Vector2.ZERO,0.3)
				for x in [-9,0,9]:
					b.box(5,6,12.3,14.1,"metal",Vector2(x,3),"dark")
				loading(i,26,[-9,0,9],7.4)
				b.finish(i,"Insulated cold-storage warehouse with three rooftop chiller blocks")
			4:
				for x in [-8,8]:
					b.box(16,24,0,6,"blue_cladding",Vector2(x,0))
					b.gable(16,24,6,2.8,"metal",Vector2(x,0))
				loading(i,24,[-10,-3,4,11],4.7,3.8)
				b.finish(i,"Twin-gable distribution depot with four roller shutters")
			5:
				b.box(28,22,0,24,"red_factory")
				for y in [8,16,24]:
					b.band(28.3,22.3,y,"stone")
				b.box(8,8,24.28,29,"buff_factory",Vector2(6,4))
				loading(i,22,[-8,8],5.5)
				b.finish(i,"Six-story textile mill with stone floor bands and rooftop stair tower")
			6:
				b.box(30,24,0,13,"buff_factory")
				b.band(30.2,24.2,13,"stone")
				for x in [-8,8]:
					stack(1.8,13.28,28,Vector2(x,5))
				loading(i,24,[-8,8],6.2)
				b.finish(i,"Masonry boiler house with paired narrow smokestacks")
			7:
				b.box(32,24,0,6,"concrete_panel")
				b.box(11,16,6,19,"buff_factory",Vector2(-10,2))
				for x in [0,7]:
					for z in [-2,6]:
						b.cylinder(3.2,6,22,"metal",Vector2(x,z))
						b.cylinder(3.25,22,24,"metal",Vector2(x,z),0.35)
				loading(i,24,[-9,7],4.8)
				b.finish(i,"Compact bulk mill with four octagonal storage silos on a solid base")
			8:
				b.box(28,24,0,15,"concrete_panel")
				b.box(16,18,15,19,"gray_cladding",Vector2(-4,0))
				b.gable(16,18,19,2.5,"metal",Vector2(-4,0))
				b.box(5,5,15,30,"brick_wall",Vector2(9,6))
				b.band(5.3,5.3,30,"dark",Vector2(9,6),0.4)
				loading(i,24,[-7,7],6.7)
				b.finish(i,"Urban utility plant with raised turbine hall and square exhaust tower")
			9:
				b.box(30,24,0,7,"gray_cladding")
				b.box(9,24,7,12,"red_factory",Vector2(-10.5,0))
				b.gable(21,24,7,2.3,"roof",Vector2(4.5,0))
				loading(i,24,[0,9],5.2)
				b.door(24,-10.5,0.04,1.5,2.6)
				b.finish(i,"Repair works with tall office wing and lower pitched service hall")
	b.save_catalog()
	quit()

func loading(index: int, depth: float, positions: Array, sign_height: float, door_height := 4.5) -> void:
	for x in positions:
		b.door(depth,x,0.15,4.4,door_height,true)
	b.sign(index,depth,sign_height,9)

func stack(radius: float, bottom: float, top: float, offset: Vector2) -> void:
	b.cylinder(radius,bottom,top,"rust",offset,radius*0.74)
	b.cylinder(radius*0.8,top,top+0.6,"dark",offset,radius*0.8)
