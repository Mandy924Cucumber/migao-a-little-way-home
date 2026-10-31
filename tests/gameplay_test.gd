extends SceneTree
var game: Node3D
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks+=1
	if condition:
		print("PASS: ",message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	check(game.apartment.doors.size()==5,"Four room doors and one exit door exist")
	check(game.apartment.friends.size()==5,"Five cats await in the garden")
	for entry in [[Vector3(-6,0,-6),"奶奶的卧室"],[Vector3(-6,0,0),"客卧"],[Vector3(6,0,-6),"浴室"],[Vector3(6,0,0),"厨房"],[Vector3(0,0,5),"客厅"]]:
		check(game.room_name(entry[0])==entry[1],"Room exists: "+entry[1])
	game.start_game()
	await frames(15)
	check(game.grandma.mood==0,"Exploring the apartment does not trigger pursuit")
	# Deterministic visibility tests, using actual physics geometry.
	game.grandma.set_physics_process(false)
	game.player.enabled=false
	game.grandma.position=Vector3(0,0.08,5)
	game.player.position=Vector3(0,0.08,7)
	game.grandma.model.rotation.y=PI
	await frames(3)
	check(game.grandma.visible_cat(true),"Grandmother can see cat by the exit")
	game.grandma._physics_process(0.016)
	check(game.grandma.mood==1,"Visible cat near exit triggers pursuit")
	game.player.position=Vector3(-4,0.08,-5)
	game.grandma.position=Vector3(0,0.08,1)
	await frames(3)
	check(not game.grandma.visible_cat(true),"Bedroom wall breaks line of sight")
	game.grandma.lost_time=1.3
	game.grandma._physics_process(0.016)
	check(game.grandma.mood==2,"Losing sight changes pursuit to search")
	game.grandma.lost_time=6
	game.grandma._physics_process(0.016)
	check(game.grandma.mood==0,"Unsuccessful search returns to peaceful patrol")
	# Test solid wardrobe遮挡 using the master bedroom wardrobe.
	game.grandma.position=Vector3(-3.25,0.08,-4.5)
	game.player.position=Vector3(-3.25,0.08,-7.65)
	await frames(3)
	check(not game.grandma.visible_cat(true),"Tall furniture occludes actual sight rays")
	var door: Dictionary=game.apartment.doors[0]
	game.grandma.position=Vector3(0,0.08,1)
	game.player.position=Vector3(0,0.08,3)
	await frames(3)
	game.apartment.toggle_door(door)
	game.rebuild_navigation()
	await create_timer(0.36).timeout
	game.grandma.position=Vector3(0,0.08,-4.6)
	game.player.position=Vector3(-3,0.08,-4.6)
	await frames(3)
	check(not game.grandma.visible_cat(true),"Closed room door blocks visibility")
	game.grandma.position=Vector3(0,0.08,1)
	game.player.position=Vector3(0,0.08,3)
	await frames(3)
	game.apartment.toggle_door(door)
	game.rebuild_navigation()
	await create_timer(0.36).timeout
	game.grandma.position=Vector3(0,0.08,-4.6)
	game.player.position=Vector3(-3,0.08,-4.6)
	await frames(3)
	check(game.grandma.visible_cat(true),"Opening the room door restores visibility")
	# Hiding is allowed only once the cat is not being watched in pursuit.
	var hiding: Dictionary={}
	var radio: Dictionary={}
	for item in game.apartment.interactables:
		if item.kind=="hide": hiding=item
		if item.kind=="radio": radio=item
	game.nearest=hiding
	game.interact()
	check(game.player.hidden and not game.player.model.visible,"Cardboard box hides the cat")
	check(not game.grandma.visible_cat(true),"Hidden cat is invisible to grandmother")
	game.interact()
	check(not game.player.hidden and game.player.model.visible,"Cat can leave its hiding place")
	game.nearest=radio
	game.interact()
	check(game.grandma.mood==3 and game.grandma.distracted_time>8,"Radio distracts grandmother for an escape window")
	# Check connected routes from hallway into every room.
	for point in [Vector3(-4,0,-4.6),Vector3(-4,0,0.3),Vector3(4,0,-4.6),Vector3(3,0,0),Vector3(0,0,7)]:
		var route: PackedVector3Array=game.find_route(Vector3(0,0,3),point)
		if route.is_empty() or route[-1].distance_to(point)>=0.8: print("Route diagnostic: ",point," -> ",route)
		check(not route.is_empty() and route[-1].distance_to(point)<0.8,"Navigation reaches room / exit: "+str(point))
	# An actual physics jump lands on the guest-room bed.
	game.player.position=Vector3(-5.5,0.10,0)
	game.player.velocity=Vector3.ZERO
	game.player.enabled=true
	game.player.yaw=0
	await frames(20)
	Input.action_press("jump")
	Input.action_press("left")
	await frames(23)
	Input.action_release("jump")
	Input.action_release("left")
	await frames(50)
	check(game.player.position.y>0.75 and game.player.is_on_floor(),"Cat physically jumps onto and stands on the bed")
	game.player.enabled=false
	# Exit door becomes passable and navigation connects to the cat colony.
	var exit_door: Dictionary=game.apartment.doors[-1]
	check(not exit_door.open and exit_door.body.collision_layer==1,"Exit starts closed and solid")
	game.apartment.toggle_door(exit_door)
	game.rebuild_navigation()
	await create_timer(0.40).timeout
	var route: PackedVector3Array=game.find_route(Vector3(0,0,6),Vector3(0,0,34))
	check(not route.is_empty() and route[-1].distance_to(Vector3(0,0,34))<0.6,"Open exit connects apartment to garden colony")
	await create_timer(0.36).timeout
	game.player.position=Vector3(0,0.1,6)
	game.player.enabled=true
	game.player.yaw=0
	game.player.stamina=100
	Input.action_press("back")
	Input.action_press("sprint")
	await frames(360)
	Input.action_release("back")
	Input.action_release("sprint")
	check(game.state=="won","Physically running through the exit and garden triggers colony victory")
	game.state="playing"
	game.player.position=Vector3(0,0.1,6.5)
	game.grandma.position=Vector3(0,0.1,6)
	game.grandma.mood=1
	await frames(3)
	game.grandma._physics_process(0.016)
	check(game.state=="caught","Grandmother catches a nearby visible cat during pursuit")
	print("RESULT: %d / %d checks passed" % [checks-failures,checks])
	game.queue_free()
	await frames(3)
	quit.call_deferred(1 if failures else 0)
