extends RefCounted
## Original procedural models; no external assets are required.

static var materials: Dictionary = {}

static func mat(color: Color, rough: float = 0.85, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(rough) + str(glow)
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat(color)
	parent.add_child(n)
	n.position = pos
	return n

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return mesh(parent, m, pos, color)

static func ball(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radial_segments = 16
	m.rings = 8
	m.radius = 0.5
	m.height = 1.0
	var n := mesh(parent, m, pos, color)
	n.scale = size
	return n

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius if top < 0 else top
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 24
	return mesh(parent, m, pos, color)

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var n := cylinder(parent, (a + b) / 2.0, radius, a.distance_to(b), color)
	var direction := (b-a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		n.quaternion = Quaternion(Vector3.UP, direction)
	return n

static func torus(parent: Node3D, pos: Vector3, radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = radius - thickness
	m.outer_radius = radius + thickness
	m.rings = 24
	m.ring_segments = 8
	return mesh(parent, m, pos, color)

static func cat(parent: Node3D, fur: Color = Color("e9ad68")) -> Node3D:
	var c := Node3D.new()
	parent.add_child(c)
	var cream := Color("fff1d4")
	ball(c, Vector3(0,0.43,0.04), Vector3(0.48,0.48,0.82), fur)
	ball(c, Vector3(0,0.39,-0.18), Vector3(0.40,0.39,0.33), cream)
	var head := Node3D.new()
	c.add_child(head)
	head.name = "Head"
	head.position = Vector3(0,0.68,-0.37)
	ball(head, Vector3.ZERO, Vector3(0.53,0.47,0.44), fur)
	for side in [-1.0,1.0]:
		var ear := cylinder(head, Vector3(side*0.18,0.23,0.0), 0.13,0.29,fur,0.008)
		ear.rotation.z = -side*0.20
		var inner := cylinder(head, Vector3(side*0.18,0.24,-0.035),0.075,0.21,Color("df9b91"),0.002)
		inner.rotation.z = -side*0.20
		ball(head, Vector3(side*0.105,0.018,-0.195),Vector3(0.114,0.134,0.07),Color("384536"))
		ball(head, Vector3(side*0.105,0.025,-0.228),Vector3(0.052,0.101,0.017),Color("172c29"))
		ball(head, Vector3(side*0.105-0.014,0.049,-0.238),Vector3(0.027,0.031,0.012),Color.WHITE)
		ball(head, Vector3(side*0.070,-0.072,-0.206),Vector3(0.15,0.105,0.085),cream)
		for j in range(3):
			rod(head,Vector3(side*0.10,-0.064,-0.228),Vector3(side*0.33,-0.055+j*0.035,-0.24),0.004,Color("795c48"))
	ball(head,Vector3(0,-0.043,-0.259),Vector3(0.07,0.05,0.033),Color("b36b67"))
	for x in [-0.155,0.155]:
		for z in [-0.22,0.30]:
			var leg := Node3D.new()
			c.add_child(leg)
			leg.name = "Leg%d" % c.get_child_count()
			leg.position = Vector3(x,0.31,z)
			ball(leg,Vector3(0,-0.10,0),Vector3(0.14,0.36,0.16),fur)
			ball(leg,Vector3(0,-0.23,-0.022),Vector3(0.15,0.11,0.21),cream)
	var tail := Node3D.new()
	c.add_child(tail)
	tail.name = "Tail"
	tail.position = Vector3(0,0.49,0.36)
	rod(tail,Vector3.ZERO,Vector3(0,0.35,0.30),0.065,fur)
	rod(tail,Vector3(0,0.35,0.30),Vector3(0.06,0.69,0.32),0.056,fur)
	ball(tail,Vector3(0.06,0.69,0.32),Vector3(0.115,0.13,0.12),cream)
	for z in [-0.08,0.09,0.26]:
		ball(c,Vector3(0,0.653,z),Vector3(0.30,0.027,0.065),Color("c38751"))
	var collar := torus(c,Vector3(0,0.51,-0.27),0.18,0.026,Color("4f8d7a"))
	collar.rotation.x = PI/2
	ball(c,Vector3(0,0.35,-0.37),Vector3(0.075,0.09,0.055),Color("f2cf74"))
	merge_character(c,true)
	return c

static func grandma(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var dress := Color("727795")
	var skin := Color("e5b799")
	cylinder(n,Vector3(0,0.66,0),0.39,0.95,dress,0.27)
	ball(n,Vector3(0,1.24,0),Vector3(0.60,0.59,0.41),dress)
	box(n,Vector3(0,0.91,-0.285),Vector3(0.40,0.72,0.055),Color("e4d9bd"))
	box(n,Vector3(0,0.70,-0.323),Vector3(0.27,0.18,0.02),Color("d3c7a8"))
	ball(n,Vector3(0,1.67,-0.06),Vector3(0.48,0.55,0.46),skin)
	ball(n,Vector3(0,1.85,0.01),Vector3(0.52,0.37,0.49),Color("d5d1c7"))
	ball(n,Vector3(0,1.94,0.23),Vector3(0.27,0.26,0.25),Color("c0c0b9"))
	for side in [-1.0,1.0]:
		var glass := torus(n,Vector3(side*0.116,1.69,-0.279),0.084,0.010,Color("625343"))
		glass.rotation.x = PI/2
		ball(n,Vector3(side*0.112,1.689,-0.272),Vector3(0.035,0.052,0.025),Color("39392f"))
		ball(n,Vector3(side*0.15,1.58,-0.258),Vector3(0.08,0.04,0.018),Color("d39487"))
		rod(n,Vector3(side*0.27,1.31,0),Vector3(side*0.41,0.86,-0.14),0.095,dress)
		ball(n,Vector3(side*0.41,0.80,-0.16),Vector3(0.15,0.20,0.16),skin)
		var foot := ball(n,Vector3(side*0.18,0.13,-0.045),Vector3(0.23,0.22,0.38),Color("534c54"))
		foot.name = "Foot" + str(side)
	rod(n,Vector3(-0.03,1.70,-0.29),Vector3(0.03,1.70,-0.29),0.008,Color("625343"))
	ball(n,Vector3(0,1.61,-0.296),Vector3(0.08,0.10,0.09),skin)
	rod(n,Vector3(-0.045,1.53,-0.266),Vector3(0.045,1.53,-0.266),0.009,Color("996f62"))
	merge_character(n,false)
	return n

static func merge_character(root: Node3D, preserve_limbs: bool) -> void:
	var groups: Dictionary={}
	collect_character_meshes(root,root,preserve_limbs,groups)
	for key in groups:
		var node := MeshInstance3D.new()
		node.mesh=groups[key].surface.commit()
		node.material_override=groups[key].material
		root.add_child(node)

static func collect_character_meshes(node: Node3D, root: Node3D, preserve_limbs: bool, groups: Dictionary) -> void:
	if preserve_limbs and (node.name=="Tail" or node.name.begins_with("Leg")): return
	for child in node.get_children():
		if child is Node3D: collect_character_meshes(child,root,preserve_limbs,groups)
	if node is MeshInstance3D:
		var material: Material=node.material_override
		var key := material.get_instance_id()
		if not groups.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key]={"surface":surface,"material":material}
		groups[key].surface.append_from(node.mesh,0,root.global_transform.affine_inverse()*node.global_transform)
		node.queue_free()
