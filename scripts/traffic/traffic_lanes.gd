extends RefCounted
## Shared straight lanes and junction curves generated once from the city manifest.
## All positions are local to SuperCity.
static func build(layout: Dictionary, offset: float, height: float, keep_right: bool) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	for road in layout.get("roads",[]):
		if road.get("kind","") != "street": continue
		var row: Array = road.rect
		var rect := Rect2(row[0],row[1],row[2],row[3])
		var horizontal: bool = int(road.axis) == 0
		var start := Vector3(rect.position.x if horizontal else rect.get_center().x,height,rect.get_center().y if horizontal else rect.position.y)
		var end := Vector3(rect.end.x if horizontal else rect.get_center().x,height,rect.get_center().y if horizontal else rect.end.y)
		if start.distance_to(end) < 12.0: continue
		var half_width: float = (rect.size.y if horizontal else rect.size.x)*0.5
		# Leave a margin for the supplied vehicle bodies at the curb.
		var lane_offset := minf(maxf(offset,0.0),maxf(0.0,half_width-2.0))
		for reverse in [false,true]:
			var a := end if reverse else start
			var b := start if reverse else end
			var forward := (b-a).normalized()
			var side := forward.cross(Vector3.UP)*(1.0 if keep_right else -1.0)
			lanes.append({"start":a+side*lane_offset,"end":b+side*lane_offset,
				"forward":forward,"length":a.distance_to(b),"road":rect,
				"height_profile":road.get("height_profile",[]),"axis":0 if horizontal else 1,
				"junction":-1,"connections":[]})
	_connect_junctions(layout,lanes)
	return lanes

static func _connect_junctions(layout: Dictionary, lanes: Array[Dictionary]) -> void:
	var junction_id := 0
	for road in layout.get("roads",[]):
		if road.get("kind","") != "junction": continue
		var control_id: int = int(road.get("junction_id",junction_id))
		var row: Array = road.rect
		var rect := Rect2(row[0],row[1],row[2],row[3])
		var incoming: Array[int] = []
		var outgoing: Array[int] = []
		for i in range(lanes.size()):
			var lane: Dictionary = lanes[i]
			# Test just across the street boundary, including rectangles' end edges.
			var after: Vector3 = lane.end+lane.forward*0.05
			var before: Vector3 = lane.start-lane.forward*0.05
			if rect.has_point(Vector2(after.x,after.z)): incoming.append(i)
			if rect.has_point(Vector2(before.x,before.z)): outgoing.append(i)
		for from_id in incoming:
			var source: Dictionary = lanes[from_id]
			source.junction = control_id
			for to_id in outgoing:
				var target: Dictionary = lanes[to_id]
				# No U-turns: only straight/left/right connections to another street.
				if source.forward.dot(target.forward) < -0.5: continue
				var curve := Curve3D.new()
				curve.bake_interval = 0.5
				curve.up_vector_enabled = false
				var handle: float = source.end.distance_to(target.start)*0.55
				curve.add_point(source.end,Vector3.ZERO,source.forward*handle)
				curve.add_point(target.start,-target.forward*handle,Vector3.ZERO)
				source.connections.append({"to":to_id,"curve":curve,"length":curve.get_baked_length(),
					"straight":source.forward.dot(target.forward) > 0.5})
		junction_id += 1

static func point(lane: Dictionary, progress: float) -> Vector3:
	var result: Vector3 = lane.start+lane.forward*progress
	var profile: Array = lane.get("height_profile",[])
	if profile.is_empty(): return result
	var coordinate: float = result.x if lane.axis == 0 else result.z
	result.y = profile[0][1]
	for i in range(1,profile.size()):
		if coordinate <= float(profile[i][0]):
			var t := clampf(inverse_lerp(float(profile[i-1][0]),float(profile[i][0]),coordinate),0.0,1.0)
			result.y = lerpf(float(profile[i-1][1]),float(profile[i][1]),t)
			return result
	result.y = profile[-1][1]
	return result

static func direction(lane: Dictionary, progress: float, half_length: float = 0.5) -> Vector3:
	return (point(lane,progress+half_length)-point(lane,progress-half_length)).normalized()

static func vehicle_point(lane: Dictionary, progress: float, half_length: float) -> Vector3:
	# Let the front/rear of a rigid vehicle straddle a change of grade, instead
	# of burying its nose in the ramp until its origin reaches the slope.
	var result := point(lane,progress)
	result.y = maxf(result.y,(point(lane,progress-half_length).y+point(lane,progress+half_length).y)*0.5)
	return result
