extends SceneTree
## Offline residential asset authoring. No scripts are attached to buildings.
const Builder = preload("res://assets/generated-buildings/residential/tools/building_builder.gd")
const OUT = "res://assets/generated-buildings/residential/"
const NAMES = ["BRIAR HOUSE","TWO ELMS","ASH ROW","WILLOW WALK","GROVE COURT","MAPLE MANSIONS","ORCHARD HOUSE","LINDEN TERRACE","HAWTHORN LOFTS","CEDAR APARTMENTS","FERN COURT","ELM GARDENS","PARKSIDE HOUSE","BIRCH RESIDENCES","STONEGATE","HEMLOCK HOUSE","QUAY RESIDENCES","JUNIPER TOWER","CANAL TERRACES","ALDER HEIGHTS"]
var b: RefCounted

func _initialize() -> void:
	b = Builder.new(OUT,"residential",NAMES)
	b.make_materials([
		["brownstone","88705c","344249","stone"],
		["red_brick","875548","35444a","brick"],
		["dark_brick","63534a","35434a","tenement"],
		["buff_brick","a39470","3e5158","tenement"],
		["limestone","b0aa98","42535b","stone"],
		["concrete","989c96","3f555e","modern"],
		["sage_panel","778985","435960","modern"],
		["loft_brick","79685b","4e6268","factory"]
	])
	for i in range(20):
		b.begin()
		match i:
			0:
				tier(8.4,14,0,12.4,"brownstone")
				b.band(8.8,14.3,11.9,"dark",Vector2.ZERO,0.22)
				b.stoop(14,-1.8)
				b.door(14,-1.8,0.72,1.5,2.4)
				b.sign(i,14,3.5,3.5)
				chimney(12.4,Vector2(2,4))
				b.finish(i,"Four-story brownstone with entrance stoop and deep cornice")
			1:
				for x in [-3.1,3.1]:
					tier(6.2,13,0,6.4,"red_brick",Vector2(x,0))
					b.gable(6.4,13.2,6.4,2.6,"roof",Vector2(x,0))
					b.door(13,x,0.04,1.4,2.4)
				b.sign(i,13,3.1,4)
				chimney(7,Vector2(4,3))
				b.finish(i,"Attached duplex with twin pitched roofs")
			2:
				for unit in range(3):
					var x = float(unit-1)*6
					var h = 9.6 if unit != 1 else 12.7
					tier(6,13,0,h,["red_brick","brownstone","buff_brick"][unit],Vector2(x,0))
					b.stoop(13,x)
					b.door(13,x,0.72,1.35,2.35)
				b.sign(i,13,3.5,3.4)
				b.finish(i,"Three-house row with separate doors and unequal rooflines")
			3:
				tier(12,16,0,19.2,"dark_brick")
				b.band(12.4,16.2,18.7,"dark")
				entry(i,16)
				b.water_tank(19.2,Vector2(2,3))
				b.finish(i,"Six-story tenement with textured window AC units and water tank")
			4:
				tier(20,10,0,18.6,"red_brick",Vector2(0,-4))
				tier(10,8,0,18.6,"red_brick",Vector2(-5,5))
				entry(i,18)
				b.box(4,3,18.6,20.7,"dark",Vector2(-4,1))
				b.finish(i,"L-shaped corner walk-up with rear light court")
			5:
				tier(18,16,0,23.4,"limestone")
				b.band(18.4,16.2,6.2)
				b.band(18.4,16.2,22.9,"dark")
				entry(i,16)
				b.box(8,7,23.4,26.4,"brownstone",Vector2(0,2))
				b.finish(i,"Prewar stone apartment house with penthouse and belt course")
			6:
				tier(18,14,0,15.8,"buff_brick")
				b.box(6,1.2,2.9,3.15,"dark",Vector2(0,-7.5),"dark")
				entry(i,14)
				chimney(15.8,Vector2(-5,3))
				b.finish(i,"Five-story buff-brick apartment house with entrance canopy")
			7:
				tier(20,18,0,21.8,"red_brick")
				tier(16,14,21.8,31.1,"red_brick",Vector2(0,1))
				tier(10,10,31.1,34.2,"brownstone",Vector2(0,1))
				entry(i,18)
				b.finish(i,"Brick terrace apartments with two deep setbacks")
			8:
				tier(21,16,0,25,"loft_brick")
				for x in [-9,-3,3,9]:
					b.box(0.3,0.2,0,25,"stone",Vector2(x,-8.02),"stone")
				entry(i,16)
				b.water_tank(25,Vector2(-5,3))
				b.finish(i,"Converted warehouse loft apartments with large divided windows")
			9:
				tier(24,18,0,31.2,"buff_brick")
				balconies(18,[-7,7],6.2,7)
				entry(i,18)
				b.box(7,6,31.2,33.3,"dark",Vector2(0,3))
				b.finish(i,"Wide apartment block with two stacks of simple slab balconies")
			10:
				tier(7,20,0,22,"red_brick",Vector2(-8,0))
				tier(7,20,0,22,"red_brick",Vector2(8,0))
				tier(9,7,0,22,"buff_brick",Vector2(0,6.5))
				b.door(20,-8)
				b.door(20,8)
				b.sign(i,20,3.2,5,-8)
				b.finish(i,"U-shaped courtyard apartments; courtyard uses conservative box collision")
			11:
				tier(28,16,0,40.6,"concrete")
				balconies(16,[-9,0,9],6.2,10)
				entry(i,16)
				b.box(16,8,40.6,43,"dark")
				b.finish(i,"Long postwar housing slab with repeated balcony strips")
			12:
				tier(26,20,0,3.8,"brownstone")
				tier(12,18,3.8,31.7,"red_brick",Vector2(-7,0))
				tier(10,18,3.8,41,"buff_brick",Vector2(8,0))
				entry(i,20)
				b.finish(i,"Unequal paired apartment wings over a shared base")
			13:
				tier(22,18,0,34.8,"sage_panel")
				tier(17,14,34.8,47.2,"concrete",Vector2(1,1))
				balconies(18,[-7,7],6.2,8)
				entry(i,18)
				b.finish(i,"Modern midrise apartments with stepped penthouse")
			14:
				tier(24,20,0,31.2,"limestone")
				tier(20,17,31.2,46.7,"limestone")
				tier(14,13,46.7,56,"brownstone")
				entry(i,20)
				b.finish(i,"Stone residential tower with a compact stepped crown")
			15:
				tier(20,20,0,65.2,"red_brick")
				b.band(20.2,20.2,31)
				b.box(11,9,65.2,68,"dark")
				entry(i,20)
				b.finish(i,"Square brick housing tower with broad horizontal belt")
			16:
				tier(26,22,0,6.8,"limestone")
				tier(20,18,6.8,87.4,"sage_panel")
				b.box(12,10,87.4,90,"dark")
				entry(i,22)
				b.finish(i,"Waterfront residential tower on a broad stone podium")
			17:
				tier(18,18,0,106,"concrete")
				tier(13,13,106,112.2,"sage_panel")
				entry(i,18)
				b.finish(i,"Slender square residential high-rise")
			18:
				tier(24,22,0,31,"red_brick")
				tier(20,18,31,52.7,"buff_brick",Vector2(-1,1))
				tier(16,14,52.7,71.3,"red_brick",Vector2(-2,2))
				tier(10,10,71.3,77.5,"limestone",Vector2(-2,2))
				entry(i,22)
				b.finish(i,"Asymmetric cascade of residential terraces")
			19:
				tier(26,24,0,7,"limestone")
				tier(22,20,7,118.6,"concrete")
				tier(16,14,118.6,128,"sage_panel")
				entry(i,24)
				b.finish(i,"Tall modern apartment tower with contrasting penthouse")
	b.save_catalog()
	quit()

func tier(w: float, d: float, bottom: float, top: float, material: String, offset := Vector2.ZERO) -> void:
	b.box(w,d,bottom,top-0.25,material,offset)
	b.band(w+0.15,d+0.15,top-0.25,"stone",offset,0.25)
	if bottom == 0:
		b.band(w+0.1,d+0.1,0,"stone",offset,0.28)

func entry(index: int, depth: float) -> void:
	b.door(depth,0,0.04,1.8,2.6)
	b.sign(index,depth,3.1,5)

func chimney(y: float, offset: Vector2) -> void:
	b.box(0.85,1.1,y,y+1.5,"rust",offset,"dark")

func balconies(depth: float, positions: Array, start: float, count: int) -> void:
	for x in positions:
		for floor_index in range(count):
			var y = start+float(floor_index)*3.1
			b.box(3.4,1.15,y,y+0.17,"stone",Vector2(x,-depth/2-0.48),"stone")
			# One opaque low-poly parapet per balcony; no rail bars or glass transparency.
			b.box(3.4,0.09,y+0.17,y+0.95,"metal",Vector2(x,-depth/2-1),"metal")
