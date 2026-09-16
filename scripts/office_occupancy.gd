extends RefCounted
## Built only on load or explicit tuning changes. No time/frame noise.
const SIZE := Vector2i(128, 64)
const PALETTES := [Color("ffe6c4"), Color("fff3df"), Color("e4edff")]
static func profile(seed_value: int) -> Dictionary:
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value
	var pick:=rng.randf()
	var occupancy:=rng.randf_range(.12,.22) if pick<.40 else (rng.randf_range(.34,.48) if pick<.85 else rng.randf_range(.68,.82))
	var temperature:=rng.randf()
	return {"occupancy":occupancy,"palette":0 if temperature<.48 else (1 if temperature<.91 else 2)}
static func make_image(seed_value: int, occupancy: float, dark_floor_fraction: float, palette: int) -> Image:
	var image:=Image.create(SIZE.x,SIZE.y,false,Image.FORMAT_RGB8); image.fill(Color.BLACK)
	if occupancy<=0: return image
	var rng:=RandomNumberGenerator.new(); rng.seed=seed_value+7109
	var base_color: Color=PALETTES[clampi(palette,0,2)]
	var level:=0
	while level<SIZE.y:
		var height:=mini(rng.randi_range(3,6),SIZE.y-level)
		if rng.randf()>=dark_floor_fraction:
			for face in 8:
				var offices:=1+floori(clampf(occupancy,0,1)*4)
				for office in offices:
					if rng.randf()>occupancy*1.45: continue
					var width:=rng.randi_range(2,6)
					var x:=rng.randi_range(0,16-width)
					var office_height:=rng.randi_range(1,height)
					var y:=level+rng.randi_range(0,height-office_height)
					# Shared office colour/brightness, never random RGB per window.
					var tint:=base_color.lerp(PALETTES[1],rng.randf_range(0,.20))
					image.fill_rect(Rect2i(face*16+x,y,width,office_height),tint*rng.randf_range(.52,.92))
		level+=height
	return image
