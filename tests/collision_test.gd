extends SceneTree

var game: Node3D
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(condition: bool, message: String) -> void:
	checks+=1
	if condition: print("PASS: ",message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func overlaps(actor: CharacterBody3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=actor.collider.shape
	query.transform=actor.collider.global_transform
	query.collision_mask=actor.collision_mask
	query.exclude=[actor.get_rid()]
	return not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func model_fits(node: Node3D, actor: CharacterBody3D) -> bool:
	if node is MeshInstance3D and not node.is_queued_for_deletion():
		var relative: Transform3D=actor.global_transform.affine_inverse()*node.global_transform
		for vertex in node.mesh.get_faces():
			var point: Vector3=relative*vertex
			if Vector2(point.x,point.z).length()>actor.body_radius or point.y < -0.001 or point.y>actor.body_height:
				print("Model outside collider: ",actor.name," ",point)
				return false
	for child in node.get_children():
		if child is Node3D and not model_fits(child,actor): return false
	return true

func park_actors() -> void:
	game.player.position=Vector3(0,0.2,4)
	game.grandma.position=Vector3(7,0.2,4)
	game.player.velocity=Vector3.ZERO
	game.grandma.velocity=Vector3.ZERO

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	check(not overlaps(game.player) and not overlaps(game.grandma),"Both characters spawn clear of scenery and furniture")
	game.start_game()
	game.player.enabled=false
	game.player.set_physics_process(false)
	game.grandma.set_physics_process(false)
	park_actors()
	await frames(3)
	var fits := true
	for i in range(32):
		game.player.animate(0.03,6.0)
		game.player.model.rotation.y=i*TAU/32
		fits=fits and model_fits(game.player.model,game.player)
	check(fits,"Cat model, head, feet and animated tail fit its collider at every heading")
	check(model_fits(game.grandma.model,game.grandma),"Grandmother's skirt, hands, hair and feet fit her collider")

	for actor in [game.player,game.grandma]:
		park_actors()
		actor.position=Vector3(0,0.2,-2.75)
		await frames(3)
		actor.move_and_collide(Vector3(-12,0,0))
		check(actor.position.x > -1.71+actor.body_radius-0.02 and not overlaps(actor),actor.name+" cannot cross a wall even with a large movement")
		actor.position=Vector3(-2,0.2,4.9)
		await frames(3)
		actor.move_and_collide(Vector3(-5,0,0))
		check(actor.position.x > -3.775+actor.body_radius-0.02 and not overlaps(actor),actor.name+" stops before the coffee table")

	park_actors()
	game.grandma.position=Vector3(2,0.2,4)
	await frames(3)
	game.player.move_and_collide(Vector3(4,0,0))
	check(game.player.position.x<0.73 and not overlaps(game.player),"Cat cannot walk through grandmother")
	game.player.position=Vector3(0,0.2,4)
	await frames(3)
	game.grandma.move_and_collide(Vector3(-4,0,0))
	check(game.grandma.position.x>1.27 and not overlaps(game.grandma),"Grandmother cannot walk through cat")

	park_actors()
	var door: Dictionary=game.apartment.doors[0]
	game.player.position=Vector3(-2.8,0.2,-4.6)
	await frames(3)
	game.player.move_and_collide(Vector3(0,0,-3))
	check(game.player.position.z>-4.65 and not overlaps(game.player),"An open door leaf stays solid")
	park_actors()
	game.player.position=Vector3(-1.8,0.2,-4.6)
	await frames(3)
	game.apartment.toggle_door(door)
	await frames(35)
	check(door.moving and not overlaps(game.player),"Closing door waits instead of intersecting an actor")
	park_actors()
	await frames(35)
	check(not door.moving and not door.open,"Door finishes closing after the doorway clears")
	game.apartment.toggle_door(door)
	await frames(35)
	check(not door.moving and door.open and door.body.collision_layer==1,"Reopened door keeps its collision enabled")

	var hiding: Dictionary={}
	for item in game.apartment.interactables:
		if item.kind=="hide" and item.inside.x>0: hiding=item
	park_actors()
	game.player.position=Vector3(2,0.2,5.5)
	await frames(3)
	var entry_point: Vector3=game.player.position
	game.nearest=hiding
	game.interact()
	await frames(3)
	check(game.player.hidden and game.player.collider.disabled,"Hidden cat does not leave a body intersecting the box")
	game.grandma.position=entry_point
	await frames(3)
	game.interact()
	check(game.player.hidden,"Leaving a box waits while grandmother occupies the exit")
	game.grandma.position=Vector3(7,0.2,4)
	await frames(3)
	game.interact()
	await frames(3)
	check(not game.player.hidden and not game.player.collider.disabled and not overlaps(game.player),"Cat returns to its clear entry position after hiding")

	park_actors()
	game.player.position=Vector3(-7.4,2,0.5)
	game.player.enabled=true
	game.player.set_physics_process(true)
	await frames(100)
	check(game.player.is_on_floor() and game.player.position.y>=0.93 and not overlaps(game.player),"Cat lands on top of the visible bed quilt")
	game.player.position=Vector3(-7.6,2,5)
	game.player.velocity=Vector3.ZERO
	await frames(100)
	check(game.player.is_on_floor() and game.player.position.y>=1.02 and not overlaps(game.player),"Cat lands on top of the visible sofa cushion")
	game.player.enabled=false
	game.player.set_physics_process(false)

	for destination in [Vector3(-4,0,-4.5),Vector3(-3,0,-0.5),Vector3(4,0,-4.5),Vector3(3,0,-0.5)]:
		park_actors()
		game.player.position=Vector3(0,0.2,3)
		await frames(3)
		var clear := true
		for waypoint in [Vector3(0,0,destination.z),destination]:
			for i in range(300):
				var offset: Vector3=waypoint-game.player.position
				offset.y=0
				if offset.length()<0.06: break
				var movement := offset.normalized()*minf(3.7,offset.length()*60)
				game.player.velocity=Vector3(movement.x,0 if game.player.is_on_floor() else game.player.velocity.y-0.3,movement.z)
				game.player.move_with_steps(1.0/60)
				await frames(1)
				clear=clear and not overlaps(game.player)
		var reached: bool=Vector2(game.player.position.x-destination.x,game.player.position.z-destination.z).length()<0.1
		if not reached: print("Cat stopped at ",game.player.position," heading for ",destination)
		check(reached and clear,"Cat physically passes room doorway: "+str(destination))

	# Follow real routes with the AI and physics active, including all four doorways.
	for destination in [Vector3(-4,0,-4.5),Vector3(-3,0,0),Vector3(4,0,-4.5),Vector3(3,0,0)]:
		park_actors()
		game.player.position=Vector3(7,0.2,4)
		game.grandma.position=Vector3(0,0.2,3)
		await frames(3)
		game.grandma.distract(destination)
		game.grandma.distracted_time=60
		game.grandma.set_physics_process(true)
		var clear := true
		for i in range(1000):
			await frames(1)
			clear=clear and not overlaps(game.grandma)
			if Vector2(game.grandma.position.x-destination.x,game.grandma.position.z-destination.z).length()<0.65: break
		game.grandma.set_physics_process(false)
		var reached: bool=Vector2(game.grandma.position.x-destination.x,game.grandma.position.z-destination.z).length()<0.65
		if not reached: print("AI stopped at ",game.grandma.position," heading for ",destination," route ",game.grandma.route," state ",game.state," velocity ",game.grandma.velocity," mood ",game.grandma.mood)
		check(reached and clear,"Grandmother physically reaches room without overlap: "+str(destination))

	park_actors()
	var camera_clear := true
	var camera_query := PhysicsShapeQueryParameters3D.new()
	camera_query.shape=game.player.spring.shape
	camera_query.collision_mask=1|4
	camera_query.exclude=[game.player.get_rid()]
	for point in [Vector3(-0.8,0.2,-2.75),Vector3(0,0.2,7),Vector3(-2.8,0.2,-4.6)]:
		game.player.position=point
		for heading in range(12):
			for pitch in [-1.02,-0.31,0.30]:
				game.player.pivot.rotation=Vector3(pitch,heading*TAU/12,0)
				await frames(3)
				camera_query.transform=game.player.camera.global_transform
				var hits := game.get_world_3d().direct_space_state.intersect_shape(camera_query,1)
				if not hits.is_empty(): print("Camera overlap: ",point," heading ",heading," pitch ",pitch," camera ",game.player.camera.global_position," collider ",hits[0].collider.global_position)
				camera_clear=camera_clear and hits.is_empty()
	check(camera_clear,"Camera stays outside walls, doors and furniture at 108 viewing angles")
	game.player.position=Vector3(0,0.2,3)
	game.grandma.position=Vector3(0,0.2,5.5)
	game.player.pivot.rotation=Vector3.ZERO
	await frames(5)
	camera_query.transform=game.player.camera.global_transform
	check(game.player.camera.global_position.z<4.8 and game.get_world_3d().direct_space_state.intersect_shape(camera_query,1).is_empty(),"Camera retracts before entering grandmother's model")

	park_actors()
	var trunk := Vector2.ZERO
	for rect in game.apartment.obstacles:
		if rect.position.y>13 and rect.position.y<30 and rect.size.x<0.7 and rect.size.y<0.7:
			trunk=rect.get_center()
			break
	game.player.position=Vector3(trunk.x+2,0.2,trunk.y)
	await frames(3)
	game.player.move_and_collide(Vector3(-4,0,0))
	check(trunk!=Vector2.ZERO and game.player.position.x>trunk.x+0.8 and not overlaps(game.player),"Garden tree trunks stop the player")

	park_actors()
	game.player.position=Vector3(23,0.2,9.5)
	await frames(3)
	game.player.move_and_collide(Vector3(0,0,-4))
	check(game.player.position.z>8.9 and not overlaps(game.player),"Garden front boundary prevents walking into the background void")

	game.player.position=Vector3(0,0.2,7)
	game.grandma.position=Vector3(0,0.2,3)
	game.grandma.velocity=Vector3.ZERO
	game.grandma.grace=0
	await frames(3)
	game.grandma.alert()
	game.grandma.set_physics_process(true)
	for i in range(300):
		await frames(1)
		if game.state=="caught": break
	game.grandma.set_physics_process(false)
	check(game.state=="caught" and not overlaps(game.player),"Actual pursuit catches the cat before their bodies overlap")
	print("RESULT: %d / %d collision checks passed" % [checks-failures,checks])
	game.queue_free()
	await frames(3)
	quit.call_deferred(1 if failures else 0)
