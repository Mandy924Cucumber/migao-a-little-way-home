extends Node3D
const Art = preload("res://scripts/art.gd")
signal navigation_changed
var obstacles: Array[Rect2] = []
var interactables: Array[Dictionary] = []
var doors: Array[Dictionary] = []
var lamps: Array[OmniLight3D] = []
var friends: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var wood: ShaderMaterial
const WALL := Color("eadcc4")
const TRIM := Color("f8ecd5")
const OAK := Color("9a7050")
const GREEN := Color("768e79")

func _ready() -> void:
	rng.seed = 71
	wood = ShaderMaterial.new()
	wood.shader = preload("res://shaders/wood.gdshader")
	wood.set_shader_parameter("tint",Color("ae8761"))
	build_shell()
	living_room()
	bedroom(Vector3(-6,0,-5.65),false)
	bedroom(Vector3(-6,0,0),true)
	kitchen()
	bathroom()
	outdoors()
	batch_static_meshes()

func solid(pos: Vector3, size: Vector3, color: Color, nav: bool = true, parent: Node3D = self) -> MeshInstance3D:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	var visual := Art.box(body,Vector3.ZERO,size,color)
	if nav and parent == self:
		obstacles.append(Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)))
	return visual

func collidable(visual: MeshInstance3D, nav: bool = true) -> MeshInstance3D:
	# Bake scale/rotation into the convex shape before static visual batching.
	var transform_value := global_transform.affine_inverse()*visual.global_transform
	var points := PackedVector3Array()
	for point in visual.mesh.get_faces(): points.append(transform_value*point)
	var shape := ConvexPolygonShape3D.new()
	shape.points=points
	var body := StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	var bounds: AABB=transform_value*visual.get_aabb()
	if nav and bounds.end.y>0.14 and bounds.position.y<2.15:
		obstacles.append(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)))
	return visual

func wall(pos: Vector3, size: Vector3, color: Color = WALL) -> void:
	solid(pos,size,color)
	Art.box(self,Vector3(pos.x,0.13,pos.z),Vector3(size.x+0.035,0.26,size.z+0.035),TRIM)
	Art.box(self,Vector3(pos.x,2.84,pos.z),Vector3(size.x+0.07,0.12,size.z+0.07),TRIM)
	# A narrow dado rail gives the apartment a hand-furnished character.
	Art.box(self,Vector3(pos.x,0.91,pos.z),Vector3(size.x+0.04,0.05,size.z+0.04),TRIM)

func build_shell() -> void:
	solid(Vector3(0,-0.16,0),Vector3(20,0.32,16),OAK,false)
	var ceiling := solid(Vector3(0,3.14,0),Vector3(20,0.16,16),Color("eee5d0"),false)
	ceiling.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in range(20):
		for z in range(8):
			var plank := Art.box(self,Vector3(-9.5+x,0.009,-7+z*2),Vector3(0.984,0.025,1.982),Color.WHITE)
			plank.material_override = wood
	wall(Vector3(-10,1.5,0),Vector3(0.22,3,16))
	wall(Vector3(10,1.5,0),Vector3(0.22,3,16))
	wall(Vector3(0,1.5,-8),Vector3(20,3,0.22))
	wall(Vector3(-5.65,1.5,8),Vector3(8.7,3,0.22))
	wall(Vector3(5.65,1.5,8),Vector3(8.7,3,0.22))
	solid(Vector3(0,2.77,8),Vector3(2.6,0.46,0.25),TRIM,false)
	# Four rooms open onto a generous central hall; living room lies to the south.
	for x in [-1.8,1.8]:
		wall(Vector3(x,1.5,-6.8),Vector3(0.18,3,2.4))
		wall(Vector3(x,1.5,-2.75),Vector3(0.18,3,1.7))
		wall(Vector3(x,1.5,1.2),Vector3(0.18,3,1.6))
		for z in [-4.6,-0.75]:
			solid(Vector3(x,2.78,z),Vector3(0.22,0.44,2),TRIM,false)
			make_door(Vector3(x,0,z-1),-PI/2,"卧室门" if x<0 else ("浴室门" if z< -2 else "厨房门"),true)
	for x in [-5.9,5.9]:
		wall(Vector3(x,1.5,-3.55),Vector3(8.2,3,0.18))
		wall(Vector3(x,1.5,2.0),Vector3(8.2,3,0.18))
	make_door(Vector3(-1.3,0,8),0,"通往花园的大门",false,2.6,true)
	# Windows are inset compositions with glass, mullions and curtains.
	window(Vector3(-9.86,1.95,4.9),PI/2,2.7)
	window(Vector3(9.86,1.95,4.7),-PI/2,2.4)
	window(Vector3(-6.2,1.95,-7.86),0,2.8)
	window(Vector3(6.2,1.95,-7.86),0,2.4)
	window(Vector3(9.86,1.95,-0.8),-PI/2,2.5)
	for z in [-5.6,-0.1,4.3]:
		var l := OmniLight3D.new()
		add_child(l)
		l.position = Vector3(0,2.6,z)
		l.light_color = Color("ffdfb0")
		l.light_energy = 0.28
		l.omni_range = 7.0
		Art.cylinder(self,l.position+Vector3(0,0.08,0),0.3,0.15,TRIM)
	rug(Vector3(0,0.04,-2.1),Vector2(1.7,9.0),Color("a85e49"))
	picture(Vector3(-1.67,1.85,-2.65),PI/2,Color("c58560"))

func make_door(pos: Vector3, angle: float, label: String, opened: bool, width: float = 2.0, exit_door: bool = false) -> void:
	var hinge := Node3D.new()
	add_child(hinge)
	hinge.position = pos
	hinge.rotation.y = angle
	var slab := solid(Vector3(width/2,1.2,0),Vector3(width,2.4,0.13),Color("839081") if not exit_door else Color("567968"),false,hinge)
	var collision: CollisionShape3D=slab.get_parent().get_child(0)
	collision.shape.size.z=0.42
	for y in [0.65,1.7]:
		Art.box(hinge,Vector3(width/2,y,-0.08),Vector3(width-0.30,0.74,0.025),Color("a2ab91") if not exit_door else Color("678b75"))
	Art.ball(hinge,Vector3(width-0.20,1.13,-0.14),Vector3(0.10,0.10,0.13),Color("ddba6e"))
	Art.ball(hinge,Vector3(width-0.20,1.13,0.14),Vector3(0.10,0.10,0.13),Color("ddba6e"))
	var center := pos + Basis(Vector3.UP,angle)*Vector3(width/2,0,0)
	var open_angle := angle+(PI/2 if pos.x>0 and not exit_door else -PI/2)
	var entry := {"node":hinge,"body":slab.get_parent(),"shape":collision.shape,"position":center,"open":opened,"base":angle,"open_angle":open_angle,"label":label,"exit":exit_door,"width":width,"kind":"door","moving":false}
	doors.append(entry)
	interactables.append(entry)
	if opened:
		hinge.rotation.y = open_angle

func toggle_door(entry: Dictionary) -> void:
	entry.open = not entry.open
	entry.moving=true
	navigation_changed.emit()

func door_transform(entry: Dictionary, angle: float) -> Transform3D:
	return global_transform*Transform3D(Basis(Vector3.UP,angle),entry.node.position)*entry.body.transform

func door_bounds(entry: Dictionary) -> Rect2:
	var bounds: AABB=entry.body.global_transform*AABB(-entry.shape.size/2,entry.shape.size)
	if entry.moving:
		# Reserve the entire swing while the leaf is moving or waiting for an actor.
		for i in range(17):
			bounds=bounds.merge(door_transform(entry,lerpf(entry.base,entry.open_angle,i/16.0))*AABB(-entry.shape.size/2,entry.shape.size))
	return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))

func _physics_process(delta: float) -> void:
	for entry in doors:
		if not entry.moving: continue
		var goal: float=entry.open_angle if entry.open else entry.base
		var remaining := minf(absf(goal-entry.node.rotation.y),delta*PI/0.64)
		while remaining>0.00001:
			var step := minf(remaining,0.02)
			var angle: float=move_toward(entry.node.rotation.y,goal,step)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape=entry.shape
			query.transform=door_transform(entry,angle)
			query.collision_mask=2|4
			query.margin=0.07
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): break
			entry.node.rotation.y=angle
			remaining-=step
		if is_equal_approx(entry.node.rotation.y,goal):
			entry.moving=false
			navigation_changed.emit()

func window(pos: Vector3, angle: float, width: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.rotation.y = angle
	var glass := Art.box(n,Vector3.ZERO,Vector3(width,1.45,0.035),Color("b9d9d7"))
	glass.material_override = Art.mat(Color("b9d9d7"),0.25,0.22)
	for x in [-width/2,0,width/2]:
		Art.box(n,Vector3(x,0,0.03),Vector3(0.07,1.55,0.08),TRIM)
	for y in [-0.74,0,0.74]:
		Art.box(n,Vector3(0,y,0.04),Vector3(width+0.15,0.07,0.08),TRIM)
	Art.box(n,Vector3(0,-0.80,0.14),Vector3(width+0.35,0.12,0.34),TRIM)
	Art.rod(n,Vector3(-width/2-0.32,0.9,0.2),Vector3(width/2+0.32,0.9,0.2),0.035,OAK)
	for side in [-1,1]:
		for i in range(4):
			Art.cylinder(n,Vector3(side*(width/2-0.04+i*0.12),-0.12,0.16),0.105,1.94,Color("dca77c"))

func rug(pos: Vector3, size: Vector2, color: Color) -> void:
	solid(pos,Vector3(size.x,0.035,size.y),color,false)
	solid(pos+Vector3(0,0.02,0),Vector3(size.x-0.16,0.012,size.y-0.16),color.lightened(0.19),false)
	solid(pos+Vector3(0,0.03,0),Vector3(size.x-0.30,0.01,size.y-0.30),color,false)
	for i in range(int(size.x*7)):
		for side in [-1,1]:
			Art.box(self,pos+Vector3(-size.x/2+0.08+i*0.14,0.006,side*(size.y/2+0.06)),Vector3(0.035,0.025,0.14),Color("e2cda6"))

func plant(pos: Vector3, scale_value: float = 1.0) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.scale = Vector3.ONE*scale_value
	collidable(Art.cylinder(n,Vector3(0,0.20,0),0.22,0.40,Color("bb8064"),0.29))
	Art.cylinder(n,Vector3(0,0.405,0),0.26,0.04,Color("605042"))
	for i in range(7):
		var a := i*2.4
		var end := Vector3(cos(a)*0.36,0.65+rng.randf()*0.48,sin(a)*0.36)
		Art.rod(n,Vector3(0,0.4,0),end,0.016,Color("5c7855"))
		var leaf := Art.ball(n,end,Vector3(0.22,0.46,0.10),Color("75916b") if i%2==0 else Color("4e7359"))
		leaf.rotation = Vector3(0,a,0.6)

func picture(pos: Vector3, angle: float, accent: Color) -> void:
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.rotation.y = angle
	Art.box(n,Vector3.ZERO,Vector3(0.90,1.08,0.08),OAK)
	Art.box(n,Vector3(0,0,0.045),Vector3(0.78,0.95,0.025),Color("f0e4cb"))
	Art.ball(n,Vector3(0.13,0.20,0.066),Vector3(0.27,0.27,0.015),accent)
	Art.ball(n,Vector3(-0.08,-0.19,0.073),Vector3(0.61,0.31,0.014),Color("7b937d"))
	Art.ball(n,Vector3(0.15,-0.30,0.085),Vector3(0.42,0.20,0.012),Color("536f63"))

func table(pos: Vector3, size: Vector2, height: float = 0.65) -> void:
	solid(pos+Vector3(0,height,0),Vector3(size.x,0.14,size.y),OAK)
	for x in [-1,1]:
		for z in [-1,1]:
			collidable(Art.cylinder(self,pos+Vector3(x*(size.x/2-0.14),height/2,z*(size.y/2-0.14)),0.065,height,Color("79583e")))

func book(pos: Vector3, color: Color, angle: float = 0) -> void:
	var n := Art.box(self,pos,Vector3(0.34,0.09,0.46),color)
	n.rotation.y = angle
	Art.box(n,Vector3(0,0,0.015),Vector3(0.30,0.061,0.43),Color("eee2c5"))

func living_room() -> void:
	picture(Vector3(-6.1,1.97,2.12),0,Color("d2a063"))
	picture(Vector3(-4.75,1.97,2.12),0,Color("bc8e78"))
	rug(Vector3(-4.9,0.055,4.95),Vector2(5.0,4.3),Color("839284"))
	# Cushioned sofa, individually modelled seams and pillows.
	solid(Vector3(-7.8,0.53,5.0),Vector3(1.7,0.65,3.6),Color("6d8a7f"))
	solid(Vector3(-8.48,1.08,5.0),Vector3(0.32,1.1,3.6),Color("668174"))
	for z in [3.3,6.7]:
		solid(Vector3(-7.8,0.9,z),Vector3(1.72,0.72,0.26),Color("78968a"))
	for z in [3.9,5.0,6.1]:
		collidable(Art.ball(self,Vector3(-7.65,0.91,z),Vector3(1.42,0.27,0.98),Color("92a99a")))
		var pillow := Art.ball(self,Vector3(-8.08,1.31,z),Vector3(0.36,0.66,0.76),Color("dec094") if z==5 else Color("acc0a9"))
		pillow.rotation.z = -0.2
		collidable(pillow)
	interactables.append({"kind":"scratch","position":Vector3(-6.7,0,5),"label":"沙发 · 磨磨爪子"})
	table(Vector3(-4.6,0,4.9),Vector2(1.65,2.0),0.57)
	book(Vector3(-4.85,0.72,4.6),Color("648c89"),0.17)
	Art.cylinder(self,Vector3(-4.35,0.80,5.25),0.12,0.30,Color("eddfb7"))
	Art.torus(self,Vector3(-4.35,0.95,5.25),0.095,0.015,Color("ad8e65"))
	# Sideboard and radio.
	solid(Vector3(5.9,0.62,2.48),Vector3(4.1,1.24,0.70),Color("ac825c"))
	for x in [4.45,5.4,6.35,7.3]:
		Art.box(self,Vector3(x,0.66,2.845),Vector3(0.88,0.98,0.03),Color("bc9269"))
		Art.ball(self,Vector3(x,0.77,2.90),Vector3(0.065,0.065,0.075),Color("e2c380"))
	solid(Vector3(5.4,1.51,2.5),Vector3(0.85,0.49,0.36),Color("6c7c6b"))
	for i in range(6):
		Art.box(self,Vector3(5.17+i*0.06,1.51,2.69),Vector3(0.02,0.28,0.02),Color("d6c8a6"))
	Art.ball(self,Vector3(5.65,1.49,2.71),Vector3(0.13,0.13,0.06),Color("d8b577"))
	interactables.append({"kind":"radio","position":Vector3(5.4,0,3.15),"label":"收音机 · 吸引奶奶注意"})
	plant(Vector3(7.5,1.26,2.45),0.65)
	picture(Vector3(6.0,2.12,2.12),0,Color("c89859"))
	lamp(Vector3(-8.8,0,7.0))
	plant(Vector3(8.7,0,6.9),1.7)
	# Cat's nook and hiding chest.
	collidable(Art.cylinder(self,Vector3(4.7,0.10,6.1),0.67,0.20,Color("c6a67d")))
	collidable(Art.ball(self,Vector3(4.7,0.20,6.1),Vector3(1.12,0.12,1.12),Color("e1c7a4")))
	for x in [5.9,6.6]:
		collidable(Art.cylinder(self,Vector3(x,0.11,6.65),0.24,0.20,Color("d7be92"),0.29))
		Art.cylinder(self,Vector3(x,0.215,6.65),0.23,0.013,Color("799d9e") if x>6 else Color("94704f"))
	interactables.append({"kind":"bowl","position":Vector3(6.2,0,6.6),"label":"小碗 · 喝一口水"})
	hide_box(Vector3(3.4,0,4.0))
	collidable(Art.ball(self,Vector3(-2.7,0.16,6.3),Vector3.ONE*0.30,Color("c47868")))
	for i in range(5):
		var yarn := Art.torus(self,Vector3(-2.7,0.16,6.3),0.151,0.009,Color("e1a493"))
		yarn.rotation = Vector3(i*0.6,i*0.4,0)

func lamp(pos: Vector3) -> void:
	collidable(Art.cylinder(self,pos+Vector3(0,0.08,0),0.3,0.12,Color("625740")))
	collidable(Art.cylinder(self,pos+Vector3(0,0.96,0),0.035,1.8,Color("a48959")))
	collidable(Art.cylinder(self,pos+Vector3(0,1.9,0),0.44,0.55,Color("f3d9a6"),0.26))
	var light := OmniLight3D.new()
	add_child(light)
	light.position = pos+Vector3(0,1.7,0)
	light.light_color = Color("ffd397")
	light.light_energy = 0.48
	light.omni_range = 4.0
	lamps.append(light)
	interactables.append({"kind":"lamp","position":pos,"label":"落地灯 · 开 / 关","light":light})

func hide_box(pos: Vector3) -> void:
	# Open-front cardboard shelter, with real sides and a roof.
	for side in [-1,1]:
		solid(pos+Vector3(side*0.53,0.46,0),Vector3(0.07,0.92,1.10),Color("bb9569"))
	solid(pos+Vector3(0,0.46,-0.53),Vector3(1.12,0.92,0.07),Color("bb9569"))
	solid(pos+Vector3(0,0.94,0),Vector3(1.13,0.07,1.13),Color("cda879"))
	Art.box(self,pos+Vector3(0,0.985,0),Vector3(0.17,0.008,1.13),Color("ddc49d"))
	interactables.append({"kind":"hide","position":pos+Vector3(0,0,0.85),"inside":pos,"label":"纸箱 · 躲进去"})

func bedroom(pos: Vector3, guest: bool) -> void:
	var color := Color("b2a0ad") if guest else Color("78999b")
	rug(pos+Vector3(0,0.06,0.3),Vector2(5.2,3.6),Color("b6a591") if guest else Color("aa8267"))
	var bed := pos+Vector3(-1.4,0,0)
	solid(bed+Vector3(0,0.33,0),Vector3(2.5,0.54,3.5),OAK)
	solid(bed+Vector3(0,0.67,0),Vector3(2.4,0.26,3.4),Color("f1e6ce"))
	solid(bed+Vector3(0,0.84,0.4),Vector3(2.43,0.18,2.42),color)
	solid(bed+Vector3(0,0.94,-0.72),Vector3(2.44,0.09,0.32),color.lightened(0.20))
	solid(bed+Vector3(0,0.89,-1.70),Vector3(2.6,1.65,0.15),OAK)
	for side in [-1,1]:
		collidable(Art.ball(self,bed+Vector3(side*0.61,0.94,-1.1),Vector3(1.04,0.26,0.67),Color("f7ead4")))
	for z in range(5):
		Art.box(self,bed+Vector3(0,0.937,-0.44+z*0.45),Vector3(2.40,0.008,0.025),color.lightened(0.18))
	interactables.append({"kind":"bed","position":bed,"label":"柔软的床 · 打个盹"})
	table(pos+Vector3(0.7,0,-1.05),Vector2(0.72,0.70),0.62)
	book(pos+Vector3(0.7,0.74,-1.05),Color("ba7f6e"))
	plant(pos+Vector3(-3.1,0,1.35),0.8)
	# Wardrobe is tall enough to block the grandmother's vision.
	var wardrobe := pos+Vector3(2.75,0,-2.75 if guest else -1.2)
	solid(wardrobe+Vector3(0,1.05,0),Vector3(1.15,2.1,1.0),Color("a37c58"))
	for x in [-0.28,0.28]:
		Art.box(self,wardrobe+Vector3(x,1.08,0.52),Vector3(0.51,1.94,0.035),Color("ba946b"))
		Art.ball(self,wardrobe+Vector3(x*0.4,1.04,0.56),Vector3(0.05,0.10,0.055),Color("e3c583"))
	if guest:
		hide_box(pos+Vector3(1.1,0,0.5))
	else:
		lamp(pos+Vector3(-3.15,0,-1.3))
	picture(pos+Vector3(-0.1,1.97,-2.74 if guest else -2.76),0,Color("ba8862"))

func kitchen() -> void:
	for x in range(8):
		for z in range(5):
			solid(Vector3(2.3+x,0.035,-3.0+z),Vector3(0.985,0.04,0.985),Color("c9c6ac") if (x+z)%2 else Color("e5ddc4"),false)
	for x in [4.3,5.7,7.1,8.5]:
		solid(Vector3(x,0.55,-2.85),Vector3(1.36,1.1,1.1),GREEN)
		solid(Vector3(x,1.13,-2.85),Vector3(1.42,0.12,1.18),Color("efe6d2"))
		Art.box(self,Vector3(x,0.58,-2.28),Vector3(1.20,0.93,0.045),Color("93a18a"))
		Art.rod(self,Vector3(x-0.19,0.88,-2.22),Vector3(x+0.19,0.88,-2.22),0.025,Color("beac80"))
		solid(Vector3(x,2.23,-3.16),Vector3(1.32,0.90,0.58),Color("d9ccad"))
		Art.box(self,Vector3(x,2.22,-2.85),Vector3(1.17,0.74,0.04),Color("e7dbbe"))
	Art.box(self,Vector3(5.7,1.202,-2.8),Vector3(1.07,0.022,0.77),Color("7d9894"))
	Art.box(self,Vector3(5.7,1.219,-2.8),Vector3(0.85,0.023,0.56),Color("465e61"))
	Art.rod(self,Vector3(5.7,1.18,-3.2),Vector3(5.7,1.54,-3.2),0.035,Color("b4bdab"))
	Art.rod(self,Vector3(5.7,1.54,-3.2),Vector3(5.7,1.54,-2.96),0.035,Color("b4bdab"))
	Art.box(self,Vector3(8.5,1.205,-2.84),Vector3(1.12,0.026,0.91),Color("4d5b53"))
	for x in [8.24,8.78]:
		for z in [-3.08,-2.6]:
			Art.torus(self,Vector3(x,1.23,z),0.16,0.025,Color("9b9d87"))
	Art.cylinder(self,Vector3(8.25,1.39,-3.07),0.18,0.30,Color("bd885f"))
	solid(Vector3(9.0,1.10,0.85),Vector3(1.35,2.2,1.13),Color("b8c8b3"))
	Art.box(self,Vector3(9,1.52,1.43),Vector3(1.22,0.035,0.025),Color("829687"))
	Art.rod(self,Vector3(8.52,0.85,1.46),Vector3(8.52,1.26,1.46),0.035,Color("e8dfc7"))
	table(Vector3(5.1,0,0.3),Vector2(1.7,1.45),0.94)
	Art.ball(self,Vector3(5.1,1.08,0.3),Vector3(0.54,0.12,0.54),Color("d0b08a"))
	for i in range(3):
		Art.ball(self,Vector3(4.97+i*0.13,1.18,0.3),Vector3.ONE*0.18,Color("c98254"))
	plant(Vector3(7.1,1.2,-2.8),0.5)
	interactables.append({"kind":"tap","position":Vector3(5.7,0,-1.6),"label":"水龙头 · 拨弄一下"})

func bathroom() -> void:
	for x in range(8):
		for z in range(4):
			solid(Vector3(2.3+x,0.04,-7.5+z),Vector3(0.98,0.035,0.98),Color("93b2ad") if (x+z)%2 else Color("cad8c7"),false)
	# Tub: rim, recessed water and four solid sides.
	solid(Vector3(8.8,0.39,-5.9),Vector3(1.55,0.76,3.3),Color("e7e8d9"))
	solid(Vector3(8.8,0.79,-5.9),Vector3(1.27,0.03,2.99),Color("7eaaa9"))
	for side in [-1,1]:
		solid(Vector3(8.8+side*0.70,0.86,-5.9),Vector3(0.16,0.16,3.25),Color("f4eddd"))
		solid(Vector3(8.8,0.86,-5.9+side*1.55),Vector3(1.4,0.16,0.16),Color("f4eddd"))
	Art.rod(self,Vector3(9.38,0.9,-7.1),Vector3(9.38,1.27,-7.1),0.04,Color("adbaa9"))
	Art.rod(self,Vector3(9.38,1.27,-7.1),Vector3(9.05,1.27,-7.1),0.04,Color("adbaa9"))
	# Recognisable toilet and cistern.
	solid(Vector3(3.2,0.32,-6.7),Vector3(0.62,0.64,0.95),Color("ece9db"))
	collidable(Art.ball(self,Vector3(3.2,0.54,-6.65),Vector3(0.79,0.38,1.12),Color("f1eddf")))
	Art.torus(self,Vector3(3.2,0.72,-6.6),0.26,0.06,Color("dedbc9")).scale.z=1.4
	solid(Vector3(3.2,0.99,-7.15),Vector3(0.77,0.81,0.3),Color("ece9db"))
	Art.cylinder(self,Vector3(3.4,1.41,-7.15),0.04,0.035,Color("a0ac9e"))
	solid(Vector3(5.8,0.49,-7.27),Vector3(1.32,0.98,0.8),Color("afbeaa"))
	collidable(Art.ball(self,Vector3(5.8,1.02,-7.2),Vector3(1.32,0.24,0.85),Color("f1eada")))
	Art.ball(self,Vector3(5.8,1.15,-7.15),Vector3(0.90,0.035,0.52),Color("92b1aa"))
	Art.box(self,Vector3(5.8,1.96,-7.83),Vector3(1.2,1.23,0.08),Color("b1956a"))
	Art.box(self,Vector3(5.8,1.96,-7.77),Vector3(1.08,1.10,0.02),Color("bdd2ce"))
	rug(Vector3(6.2,0.08,-4.75),Vector2(2.2,1.2),Color("e2bd8c"))
	plant(Vector3(9.0,0,-3.95),0.7)

func outdoors() -> void:
	solid(Vector3(0,-0.23,25),Vector3(55,0.4,34),Color("8b9d73"),false)
	# Invisible garden boundary prevents falling off the playable world.
	for x in [-27.0,27.0]:
		solid(Vector3(x,1,25),Vector3(0.4,4,34),Color("879b70")).visible=false
	for x in [-18.65,18.65]:
		solid(Vector3(x,1,8),Vector3(17.3,4,0.4),Color("879b70")).visible=false
	solid(Vector3(0,1,41.8),Vector3(54,4,0.4),Color("879b70")).visible=false
	Art.box(self,Vector3(0,-0.36,40),Vector3(160,0.2,135),Color("8b9d73"))
	for i in range(9):
		Art.ball(self,Vector3(-55+i*14,0,57+sin(i)*7),Vector3(25,14+cos(i)*5,29),Color("859573") if i%2 else Color("97a481"))
	for i in range(18):
		tree(Vector3(-25+i*3,0,40+rng.randf()*5),rng.randf_range(0.9,1.4))
	for i in range(18):
		var z := 9.0+i*1.50
		var x := sin(i*0.29)*1.5
		var stone := Art.cylinder(self,Vector3(x,0.025,z),0.83,0.07,Color("c6c1a1"))
		stone.scale.x = 1.5
		stone.rotation.y = rng.randf()*2
		collidable(stone,false)
	# Apartment exterior plinth, porch and planted hedges.
	for x in [-5.9,5.9]:
		solid(Vector3(x,0.28,8.28),Vector3(8.5,0.55,0.35),Color("b7a58a"))
	for i in range(18):
		var x := -18.0+i*2.1
		if absf(x)<2.7: continue
		collidable(Art.ball(self,Vector3(x,0.55,10),Vector3(2.3,1.4,1.8),Color("6f885b")))
	for i in range(36):
		var pos := Vector3(rng.randf_range(-22,22),0,rng.randf_range(13,40))
		if absf(pos.x)<4.5: pos.x += 7.5 if pos.x>=0 else -7.5
		tree(pos,rng.randf_range(0.75,1.5))
	for i in range(180):
		var pos := Vector3(rng.randf_range(-18,18),0.0,rng.randf_range(10.5,39))
		if absf(pos.x)<2.7: continue
		var color := Color("c9b276") if i%3==0 else Color("778e60")
		for j in range(3):
			var blade := Art.box(self,pos+Vector3(j*0.065,0.16,0),Vector3(0.045,0.32,0.025),color)
			blade.rotation.z = (j-1)*0.30
		if i%4==0:
			Art.ball(self,pos+Vector3(0,0.36,0),Vector3(0.12,0.10,0.12),Color("e8c993") if i%8==0 else Color("eadcbb"))
	# A sunny meeting place surrounded by a small colony of cats.
	collidable(Art.cylinder(self,Vector3(0,0.014,34.4),3.25,0.05,Color("b4b18a")),false)
	for i in range(5):
		var a := i*TAU/5
		var cat := Art.cat(self,[Color("d39a61"),Color("a0a7a0"),Color("eddfc2"),Color("6b6c65"),Color("b7a18b")][i])
		cat.position=Vector3(cos(a)*2.1,0.10,34.4+sin(a)*2.1)
		cat.rotation.y=-a-PI/2
		friends.append(cat)
	var post := collidable(Art.cylinder(self,Vector3(3.7,0.95,31.3),0.09,1.9,OAK))
	solid(Vector3(3.7,1.72,31.3),Vector3(1.6,0.55,0.13),Color("677e61"))
	var sign := Label3D.new()
	add_child(sign)
	sign.position=post.position+Vector3(0,0.80,-0.09)
	sign.rotation.y=PI
	sign.text="猫咪的秘密花园"
	sign.font_size=40
	sign.pixel_size=0.0025
	sign.outline_size=0
	sign.modulate=Color("f7edcc")

func tree(pos: Vector3, size: float) -> void:
	collidable(Art.cylinder(self,pos+Vector3(0,1.75*size,0),0.22*size,3.5*size,Color("8c7859"),0.13*size))
	for i in range(4):
		var offset := Vector3(cos(i*2.4)*0.63,3.4+i*0.36,sin(i*2.4)*0.63)*size
		Art.ball(self,pos+offset,Vector3(2.8,2.4,2.7)*size,Color("6d875e") if i%2 else Color("8a9b67"))

func batch_static_meshes() -> void:
	# Merge immutable scenery by material. Colliders remain separate and editable
	# doors / cats keep their individual meshes and animation transforms.
	var groups: Dictionary={}
	var excluded: Array[Node]=[]
	for door in doors: excluded.append(door.node)
	for friend in friends: excluded.append(friend)
	collect_meshes(self,excluded,groups)
	for key in groups:
		var group: Dictionary=groups[key]
		var instance := MeshInstance3D.new()
		instance.mesh=group.surface.commit()
		instance.material_override=group.material
		instance.cast_shadow=group.shadow
		add_child(instance)
		instance.name="BatchedScenery"

func collect_meshes(node: Node, excluded: Array[Node], groups: Dictionary) -> void:
	if node in excluded: return
	for child in node.get_children():
		collect_meshes(child,excluded,groups)
	if node is MeshInstance3D and node.mesh != null and node.visible:
		var material: Material=node.material_override
		var key := str(material.get_instance_id())+":"+str(node.cast_shadow)
		if not groups.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key]={"surface":surface,"material":material,"shadow":node.cast_shadow}
		groups[key].surface.append_from(node.mesh,0,global_transform.affine_inverse()*node.global_transform)
		node.queue_free()
