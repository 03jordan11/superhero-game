extends RefCounted
## Solid gameplay volumes. Thin facade details never become collision edges.
## [width, depth, bottom, roof, center X, center Z] before the original origin shift.
const VOLUMES := [
	[[8.4,14,0,12.4,0,0]],
	[[12.4,13,0,6.4,0,0]],
	[[6,13,0,9.6,-6,0],[6,13,0,12.7,0,0],[6,13,0,9.6,6,0]],
	[[12,16,0,19.2,0,0]],
	[[20,10,0,18.6,0,-4],[10,8,0,18.6,-5,5]],
	[[18,16,0,23.4,0,0],[8,7,23.4,26.4,0,2]],
	[[18,14,0,15.8,0,0]],
	[[20,18,0,21.8,0,0],[16,14,21.8,31.1,0,1],[10,10,31.1,34.2,0,1]],
	[[21,16,0,25,0,0]],
	[[24,18,0,31.2,0,0]],
	[[7,20,0,22,-8,0],[7,20,0,22,8,0],[9,7,0,22,0,6.5]],
	[[28,16,0,40.6,0,0]],
	[[26,20,0,3.8,0,0],[12,18,3.8,31.7,-7,0],[10,18,3.8,41,8,0]],
	[[22,18,0,34.8,0,0],[17,14,34.8,47.2,1,1]],
	[[24,20,0,31.2,0,0],[20,17,31.2,46.7,0,0],[14,13,46.7,56,0,0]],
	[[20,20,0,65.2,0,0]],
	[[26,22,0,6.8,0,0],[20,18,6.8,87.4,0,0]],
	[[18,18,0,106,0,0],[13,13,106,112.2,0,0]],
	[[24,22,0,31,0,0],[20,18,31,52.7,-1,1],[16,14,52.7,71.3,-2,2],[10,10,71.3,77.5,-2,2]],
	[[26,24,0,7,0,0],[22,20,7,118.6,0,0],[16,14,118.6,128,0,0]]
]

static func fit(body: StaticBody3D, mesh: Mesh, index: int) -> void:
	var volumes: Array=VOLUMES[index-1]
	var actual_low:=Vector3(INF,0,INF); var actual_high:=Vector3(-INF,0,-INF)
	for surface in mesh.get_surface_count():
		var material:=mesh.surface_get_material(surface) as StandardMaterial3D
		if material==null or not material.emission_enabled: continue
		for v in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			actual_low.x=minf(actual_low.x,v.x); actual_low.z=minf(actual_low.z,v.z)
			actual_high.x=maxf(actual_high.x,v.x); actual_high.z=maxf(actual_high.z,v.z)
	var design_low:=Vector3(INF,0,INF); var design_high:=Vector3(-INF,0,-INF)
	for v in volumes:
		design_low.x=minf(design_low.x,v[4]-v[0]/2.0); design_low.z=minf(design_low.z,v[5]-v[1]/2.0)
		design_high.x=maxf(design_high.x,v[4]+v[0]/2.0); design_high.z=maxf(design_high.z,v[5]+v[1]/2.0)
	var shift: Vector3=(actual_low+actual_high-design_low-design_high)/2.0
	# Retain the primary node path; replace only building-owned collision nodes.
	for node in body.get_children():
		if node is CollisionShape3D and node.name!=&"CollisionShape3D": node.free()
	for i in volumes.size():
		var v: Array=volumes[i]
		var node: CollisionShape3D=body.get_node("CollisionShape3D") if i==0 else CollisionShape3D.new()
		if i>0:
			node.name="TierCollision%d"%i; body.add_child(node); node.owner=body
		node.shape=BoxShape3D.new()
		node.shape.size=Vector3(v[0],v[3]-v[2],v[1])
		node.transform=Transform3D(Basis.IDENTITY,Vector3(v[4],(v[2]+v[3])/2.0,v[5])+shift)
		node.disabled=false
	if index in [1,3]:
		var centers: Array=[-1.8] if index==1 else [-6,0,6]
		var depth:=14.0 if index==1 else 13.0
		for x in centers:
			for step in 3:
				var node:=CollisionShape3D.new(); node.name="StoopCollision%d"%body.get_child_count()
				node.shape=BoxShape3D.new(); node.shape.size=Vector3(2,0.24,1.35-step*.35)
				node.position=Vector3(x,step*.24+.12,-depth/2.0-.55+step*.15)+shift
				body.add_child(node); node.owner=body
	if index==7:
		var node:=CollisionShape3D.new(); node.name="CanopyCollision"
		node.shape=BoxShape3D.new(); node.shape.size=Vector3(6,.25,1.2)
		node.position=Vector3(0,3.025,-7.5)+shift; body.add_child(node); node.owner=body
