extends Node3D
const Apartment = preload("res://scripts/apartment.gd")
const CatPlayer = preload("res://scripts/cat_player.gd")
const Grandma = preload("res://scripts/grandma.gd")
const Hud = preload("res://scripts/hud.gd")
var apartment: Node3D
var player: CharacterBody3D
var grandma: CharacterBody3D
var hud: CanvasLayer
var grid := AStarGrid2D.new()
var state := "title"
var elapsed := 0.0
var nearest: Dictionary = {}
var hiding_place: Dictionary = {}
var interaction_cooldown := 0.0
var audio: AudioStreamPlayer
var sounds: Dictionary = {}
var title_camera: Camera3D
var capture_frames := 0

func _ready() -> void:
	setup_input()
	setup_environment()
	apartment=Apartment.new()
	apartment.name="ApartmentAndGarden"
	add_child(apartment)
	player=CatPlayer.new()
	player.name="Migao"
	player.game=self
	add_child(player)
	player.position=Vector3(-2.8,0.15,4.7)
	player.yaw=-0.70
	grandma=Grandma.new()
	grandma.name="Grandmother"
	grandma.game=self
	add_child(grandma)
	grandma.position=Vector3(2.0,0.15,4.8)
	grandma.target=grandma.position
	grandma.model.rotation.y=-0.6
	apartment.navigation_changed.connect(rebuild_navigation)
	rebuild_navigation()
	audio=AudioStreamPlayer.new()
	add_child(audio)
	audio.volume_db=-16
	build_sounds()
	hud=Hud.new()
	hud.game=self
	add_child(hud)
	title_camera=Camera3D.new()
	add_child(title_camera)
	title_camera.position=Vector3(-0.8,2.25,7.35)
	title_camera.look_at(Vector3(-4.7,0.55,3.8))
	title_camera.fov=72
	title_camera.current=true
	hud.show_menu("title")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if get_tree().has_meta("retry_migao"):
		get_tree().remove_meta("retry_migao")
		start_game()
	if "--capture" in OS.get_cmdline_user_args():
		start_game()
		player.yaw=-0.70
		player.pitch=-0.31
	if "--capture-garden" in OS.get_cmdline_user_args():
		start_game()
		player.position=Vector3(0,0.1,28)
		player.yaw=PI
		player.pitch=-0.2

func setup_input() -> void:
	var actions := {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE],"interact":[KEY_E],"sprint":[KEY_SHIFT],"crouch":[KEY_CTRL],"meow":[KEY_Q],"pause_game":[KEY_ESCAPE],"accept_game":[KEY_ENTER]}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(action,event)

func setup_environment() -> void:
	var environment := WorldEnvironment.new()
	add_child(environment)
	var env := Environment.new()
	environment.environment=env
	env.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color=Color("819fa6")
	material.sky_horizon_color=Color("e8dec4")
	material.ground_bottom_color=Color("708065")
	material.ground_horizon_color=Color("d7d5b4")
	sky.sky_material=material
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e8e2cd")
	env.ambient_light_energy=0.36
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees=Vector3(-51,-32,0)
	sun.light_color=Color("fff2df")
	sun.light_energy=0.48
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=65
	sun.shadow_bias=0.035

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if state=="playing":
			state="paused"
			player.enabled=false
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			hud.show_menu("paused")
		elif state=="paused":
			start_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("accept_game") and state!="playing": menu_action()
	if state!="playing": return
	if event.is_action_pressed("interact") and interaction_cooldown<=0:
		interact()
		interaction_cooldown=0.4
	if event.is_action_pressed("meow") and interaction_cooldown<=0:
		sound("meow")
		toast("喵——！" if grandma.mood==0 else "喵声会暴露位置，奶奶朝这边走来了！")
		if grandma.mood in [1,2]:
			grandma.last_seen=player.position
			grandma.target=player.position
			grandma.lost_time=0
		interaction_cooldown=1.0

func _process(delta: float) -> void:
	if state=="playing":
		elapsed+=delta
		interaction_cooldown-=delta
		update_nearest()
		if player.position.z>31.6 and player.position.distance_to(Vector3(0,0,34.4))<3.1:
			win()
	for i in range(apartment.friends.size()):
		var cat: Node3D=apartment.friends[i]
		cat.get_node("Tail").rotation.z=sin(Time.get_ticks_msec()*0.002+i)*0.17
	if "--capture" in OS.get_cmdline_user_args() or "--capture-garden" in OS.get_cmdline_user_args() or "--capture-title" in OS.get_cmdline_user_args():
		capture_frames+=1
		if capture_frames==90:
			capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var name_value := "garden" if "--capture-garden" in OS.get_cmdline_user_args() else ("title" if "--capture-title" in OS.get_cmdline_user_args() else "apartment")
	print("Capture FPS: ",Engine.get_frames_per_second(),"; draw calls: ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	get_viewport().get_texture().get_image().save_png("res://artifacts/"+name_value+".png")
	get_tree().quit()

func start_game() -> void:
	state="playing"
	player.enabled=true
	player.camera.current=true
	hud.menu.visible=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func menu_action() -> void:
	if state in ["caught","won"]:
		get_tree().set_meta("retry_migao",true)
		get_tree().reload_current_scene()
		return
	start_game()

func caught() -> void:
	if state!="playing": return
	state="caught"
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	sound("caught")
	hud.show_menu("caught")

func win() -> void:
	if state!="playing": return
	state="won"
	player.enabled=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	sound("win")
	hud.show_menu("won")

func rescue_cat() -> void:
	player.position=Vector3(-5.7,0.1,3.15)
	player.velocity=Vector3.ZERO
	grandma.grace=3
	toast("米糕轻巧地回到了客厅。")

func room_name(pos: Vector3) -> String:
	if pos.z>8: return "花园"
	if pos.z>2: return "客厅"
	if absf(pos.x)<1.8: return "走廊"
	if pos.x<0: return "奶奶的卧室" if pos.z< -3.55 else "客卧"
	return "浴室" if pos.z< -3.55 else "厨房"

func update_nearest() -> void:
	nearest={}
	var best := 1.9
	for entry in apartment.interactables:
		var dist: float=Vector2(player.position.x-entry.position.x,player.position.z-entry.position.z).length()
		if dist>=best: continue
		# No interaction through walls or another closed door.
		var from := player.global_position+Vector3(0,0.65,0)
		var to: Vector3=entry.position+Vector3(0,0.65,0)
		var ray := PhysicsRayQueryParameters3D.create(from,to,1)
		if entry.kind=="door": ray.exclude=[entry.body.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and from.distance_to(hit.position)<from.distance_to(to)-0.35:
			continue
		best=dist
		nearest=entry

func interaction_prompt() -> String:
	if player.hidden: return "[ E ]  离开纸箱"
	if nearest.is_empty(): return ""
	if nearest.kind=="door":
		return "[ E ]  "+("关闭 " if nearest.open else "打开 ")+nearest.label
	return "[ E ]  "+nearest.label

func interact() -> void:
	if player.hidden:
		var exit_point: Vector3=hiding_place.exit_position
		if not player.can_stand_at(exit_point):
			toast("纸箱前面被挡住了，等空出来再出去。")
			return
		player.position=exit_point
		player.collision_layer=2
		player.collider.set_deferred("disabled",false)
		player.hidden=false
		player.model.visible=true
		player.pivot.position.y=0.72
		hiding_place={}
		toast("轻轻地，探出小脑袋。")
		return
	if nearest.is_empty(): return
	match nearest.kind:
		"door":
			apartment.toggle_door(nearest)
			sound("door")
			if nearest.exit and nearest.open: toast("门打开了！沿着花园的石板路，去找猫咪伙伴。")
		"hide":
			if grandma.mood==1 and grandma.visible_cat(true):
				toast("奶奶正看着你！先绕到家具后面，再躲进纸箱。")
				return
			hiding_place=nearest.duplicate()
			hiding_place.exit_position=player.global_position+Vector3.UP*0.035
			player.hidden=true
			player.model.visible=false
			player.velocity=Vector3.ZERO
			player.collision_layer=0
			player.collider.set_deferred("disabled",true)
			player.position=nearest.inside+Vector3(0,0.02,0)
			player.pivot.position.y=1.35
			toast("纸箱里很安全。等奶奶走远后按 E 出来。")
		"radio":
			grandma.distract(nearest.position+Vector3(0,0,0.55))
			sound("radio")
			toast("收音机响了。奶奶要过去看看，现在是好机会！")
		"lamp":
			nearest.light.visible=not nearest.light.visible
			sound("door")
			toast("暖暖的灯光，轻轻一碰。")
		"bed":
			if player.position.y<0.68:
				toast("先按空格跳到床上，再按 E 打个小盹。")
			else:
				player.stamina=100
				sound("purr")
				toast("呼噜呼噜……柔软的被子，恢复了全部体力。")
		"scratch":
			sound("purr")
			toast("沙沙沙……伸个懒腰，磨磨小爪子。")
		"bowl":
			player.stamina=100
			sound("water")
			toast("咕噜，咕噜。喝饱水，体力恢复了！")
		"tap":
			sound("water")
			grandma.distract(Vector3(5.7,0,-1.25))
			toast("滴答滴答……奶奶听见水声，准备来厨房看看。")

func rebuild_navigation() -> void:
	grid.region=Rect2i(-19,-15,39,96)
	grid.cell_size=Vector2(0.5,0.5)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var clearance := Grandma.BODY_RADIUS+0.10
	var blocked_regions: Array[Rect2]=[]
	for rect in apartment.obstacles: blocked_regions.append(rect.grow(clearance))
	for door in apartment.doors: blocked_regions.append(apartment.door_bounds(door).grow(clearance))
	for x in range(-19,20):
		for z in range(-15,81):
			var point := Vector2(x*0.5,z*0.5)
			var blocked := false
			for rect in blocked_regions:
				if rect.has_point(point):
					blocked=true
					break
			grid.set_point_solid(Vector2i(x,z),blocked)

func closest_cell(pos: Vector3) -> Vector2i:
	var id := Vector2i(clampi(roundi(pos.x*2),-19,19),clampi(roundi(pos.z*2),-15,80))
	if not grid.is_point_solid(id): return id
	for radius in range(1,8):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var test := id+Vector2i(x,y)
				if grid.is_in_boundsv(test) and not grid.is_point_solid(test): return test
	return id

func find_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var route := PackedVector3Array()
	var ids := grid.get_id_path(closest_cell(from),closest_cell(to),true)
	for i in range(1,ids.size()):
		route.append(Vector3(ids[i].x*0.5,0,ids[i].y*0.5))
	return route

func toast(message: String) -> void:
	hud.toast(message)

func build_sounds() -> void:
	for kind in ["meow","purr","jump","door","water","alert","caught","win","radio"]:
		var duration := 0.55
		if kind in ["win","radio"]: duration=1.6
		var data := PackedByteArray()
		var count := int(duration*22050)
		data.resize(count*2)
		var phase := 0.0
		for i in range(count):
			var t := float(i)/22050.0
			var progress := t/duration
			var frequency := 440.0
			match kind:
				"meow": frequency=620+sin(progress*PI)*380-progress*220
				"purr": frequency=100+sin(t*140)*20
				"jump": frequency=330+progress*420
				"door": frequency=160-progress*100
				"water": frequency=800+sin(t*55)*350
				"alert": frequency=550 if progress<0.5 else 740
				"caught": frequency=440-progress*220
				"win","radio": frequency=[523.25,659.25,783.99,1046.5][mini(3,int(progress*4))]
			phase+=TAU*frequency/22050
			var envelope := sin(progress*PI)*0.32
			var sample := (sin(phase)+sin(phase*2)*0.2)*envelope
			data.encode_s16(i*2,int(sample*25000))
		var stream := AudioStreamWAV.new()
		stream.format=AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate=22050
		stream.data=data
		sounds[kind]=stream

func sound(kind: String) -> void:
	if sounds.has(kind):
		audio.stream=sounds[kind]
		audio.play()
