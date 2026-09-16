extends RefCounted
## Coordinates local to the park center at city (-292, 0, 0).
const BOUNDS := Rect2(-254, -302, 508, 604)
const LAKE_CENTER := Vector2(32, -54)
const LAKE_SIZE := Vector2(91, 74)
const CABINS := [Vector2(-171, -186), Vector2(155, 156), Vector2(-157, 177)]
const TREE_COUNT := 400
const MEADOW := Vector2(-25, 170)
const MEADOW_RADII := Vector2(100, 70)

static func in_meadow(p: Vector2, margin := 0.0) -> bool:
	return ((p - MEADOW) / (MEADOW_RADII + Vector2.ONE * margin)).length() < 1.0

static func lake_radius(p: Vector2) -> float:
	var q := (p - LAKE_CENTER) / LAKE_SIZE
	var angle := atan2(q.y, q.x)
	return q.length() / (1.0 + 0.08 * sin(angle * 3.0) + 0.05 * cos(angle * 5.0))

static func height(p: Vector2) -> float:
	var edge := minf(254.0 - absf(p.x), 302.0 - absf(p.y))
	var h := 0.025 + smoothstep(0.0, 30.0, edge) * (1.6 + 1.3 * sin(p.x * 0.025) * cos(p.y * 0.017))
	# Broad, gently graded lawn, with a soft transition into the rolling ground.
	var meadow_radius := ((p - MEADOW) / MEADOW_RADII).length()
	h = lerpf(0.35, h, smoothstep(0.72, 1.18, meadow_radius))
	# Flat, accessible clearings beneath the houses.
	for clearing in CABINS:
		h = lerpf(0.15, h, smoothstep(13.0, 24.0, p.distance_to(clearing)))
	var r := lake_radius(p)
	if r < 1.22: h = lerpf(-3.5, h, smoothstep(0.65, 1.22, r))
	return h

static func paths() -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	paths.append({"name":"Promenade", "width":5.0, "lit":true, "points":smooth([Vector2(-205,245),Vector2(-214,135),Vector2(-202,20),Vector2(-214,-110),Vector2(-176,-244),Vector2(-70,-264),Vector2(65,-246),Vector2(183,-182),Vector2(208,-68),Vector2(196,58),Vector2(211,195),Vector2(116,254),Vector2(0,266),Vector2(-120,252)], true)})
	var lake: Array[Vector2] = []
	for i in 24:
		var angle := float(i) / 24.0 * TAU
		lake.append(LAKE_CENTER + Vector2(cos(angle),sin(angle)) * LAKE_SIZE * 1.48)
	paths.append({"name":"LakesideWalk", "width":4.5, "lit":true, "points":smooth(lake, true)})
	for entry in [
		["SouthGate",5.5,[Vector2(0,302),Vector2(0,266)]],
		["SouthwestGate",5.5,[Vector2(-228,302),Vector2(-205,245)]],
		["NorthGate",5.5,[Vector2(-70,-302),Vector2(-70,-264)]],
		["WestGate",5.5,[Vector2(-254,135),Vector2(-214,135)]],
		["EastGate",5.5,[Vector2(254,58),Vector2(196,58)]],
		["LakeApproach",4.5,[Vector2(0,266),Vector2(35,215),Vector2(50,134),Vector2(35,75),Vector2(32,56)]],
		["WestLakeLink",4.5,[Vector2(-202,20),Vector2(-160,28),Vector2(-112,10),Vector2(-102,-20)]],
		["NorthLakeLink",4.5,[Vector2(-70,-264),Vector2(-30,-210),Vector2(5,-184),Vector2(32,-164)]],
		["EastLakeLink",4.5,[Vector2(208,-68),Vector2(185,-58),Vector2(167,-54)]],
		["WillowHouseTrail",2.5,[Vector2(-214,-110),Vector2(-183,-128),Vector2(-163,-153),Vector2(-171,-179)]],
		["MossHouseTrail",2.5,[Vector2(-205,245),Vector2(-170,231),Vector2(-142,209),Vector2(-157,184)]],
		["BirchHouseTrail",2.5,[Vector2(196,58),Vector2(164,91),Vector2(133,124),Vector2(155,163)]],
		["BridgeWestLink",3.5,[Vector2(-74,24),Vector2(-60,18),Vector2(-48,18)]],
		["BridgeEastLink",3.5,[Vector2(133,27),Vector2(120,22),Vector2(112,18)]]
	]:
		paths.append({"name":entry[0],"width":entry[1],"lit":float(entry[1])>=4.0,"points":smooth(entry[2],false)})
	return paths

static func smooth(controls: Array, closed: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	var segments := controls.size() if closed else controls.size()-1
	for i in segments:
		var a: Vector2 = controls[posmod(i-1,controls.size())] if closed else controls[maxi(0,i-1)]
		var b: Vector2 = controls[i]
		var c: Vector2 = controls[(i+1)%controls.size()]
		var d: Vector2 = controls[(i+2)%controls.size()] if closed else controls[mini(controls.size()-1,i+2)]
		var steps := maxi(2, ceili(b.distance_to(c)/3.0))
		for step in steps:
			var t := float(step)/steps
			output.append(0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t))
	output.append(controls[0] if closed else controls[-1])
	return output

static func path_distance(p: Vector2, routes: Array[Dictionary]) -> float:
	var nearest := INF
	for path in routes:
		var points: PackedVector2Array = path.points
		for i in points.size()-1:
			var a := points[i]
			var segment := points[i+1]-a
			var t := clampf((p-a).dot(segment)/maxf(segment.length_squared(),0.001),0.0,1.0)
			nearest = minf(nearest,p.distance_to(a+segment*t)-float(path.width)*0.5)
	return nearest
