extends RefCounted
## Height-aware, read-only index of authored pavement triangles.
const CELL := 16.0
var triangles: Array = []
var cells: Dictionary = {}

func build(rows: Array) -> void:
	triangles.clear()
	cells.clear()
	for row in rows:
		var v: Array = row.v
		var a := Vector3(v[0],v[1],v[2])
		var b := Vector3(v[3],v[4],v[5])
		var c := Vector3(v[6],v[7],v[8])
		var polygon := PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
		var rect := Rect2(polygon[0],Vector2.ZERO).expand(polygon[1]).expand(polygon[2])
		var id := triangles.size()
		triangles.append({"polygon":polygon,"plane":Plane(a,b,c),"crossing":row.get("kind","") == "crossing"})
		for x in range(floori(rect.position.x/CELL),floori(rect.end.x/CELL)+1):
			for z in range(floori(rect.position.y/CELL),floori(rect.end.y/CELL)+1):
				var key := Vector2i(x,z)
				if not cells.has(key): cells[key] = []
				cells[key].append(id)

func contains(p: Vector3, allow_crossing: bool, tolerance := 0.25) -> bool:
	var flat := Vector2(p.x,p.z)
	for id in cells.get(Vector2i(floori(p.x/CELL),floori(p.z/CELL)),[]):
		var triangle: Dictionary = triangles[id]
		if triangle.crossing and not allow_crossing: continue
		var plane: Plane = triangle.plane
		var height := (plane.d-plane.normal.x*p.x-plane.normal.z*p.z)/plane.normal.y
		if absf(height-p.y)>tolerance: continue
		if Geometry2D.is_point_in_polygon(flat,triangle.polygon): return true
		# Imported vertices and JSON coordinates round slightly differently.
		# Include shared edges within 2 mm without opening a navigable gap.
		for i in range(3):
			var closest := Geometry2D.get_closest_point_to_segment(flat,triangle.polygon[i],triangle.polygon[(i+1)%3])
			if closest.distance_squared_to(flat)<0.000004: return true
	return false
