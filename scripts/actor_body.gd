extends CharacterBody3D

const STEP_HEIGHT := 0.14
var collider: CollisionShape3D
var body_radius := 0.0
var body_height := 0.0

func setup_collision(radius: float, height: float, layer: int, mask: int) -> void:
	body_radius=radius
	body_height=height
	collision_layer=layer
	collision_mask=mask
	safe_margin=0.015
	floor_snap_length=0.20
	platform_floor_layers=1
	# A full-height cylinder also protects feet, skirts and turning animations.
	collider=CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius=radius
	shape.height=height
	collider.shape=shape
	collider.position.y=height/2
	add_child(collider)

func can_stand_at(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=collider.shape
	query.transform=Transform3D(Basis.IDENTITY,point+collider.position)
	query.collision_mask=collision_mask
	query.exclude=[get_rid()]
	query.margin=safe_margin
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func move_with_steps(delta: float) -> void:
	var motion := Vector3(velocity.x,0,velocity.z)*delta
	if is_on_floor() and velocity.y<=0 and motion.length_squared()>0.000001:
		var hit := KinematicCollision3D.new()
		if test_move(global_transform,motion,hit,safe_margin) and hit.get_normal().y<cos(floor_max_angle):
			var raised := global_transform.translated(Vector3.UP*STEP_HEIGHT)
			# Probe past the edge bevel so a slow walker finds the tread, not its side.
			var forward := motion.normalized()*maxf(motion.length(),0.08)
			if not test_move(global_transform,Vector3.UP*STEP_HEIGHT,null,safe_margin) and not test_move(raised,forward,null,safe_margin):
				var landing := KinematicCollision3D.new()
				if test_move(raised.translated(forward),Vector3.DOWN*STEP_HEIGHT,landing,safe_margin):
					if landing.get_normal().y>=cos(floor_max_angle) and landing.get_collider() is StaticBody3D:
						global_position.y+=STEP_HEIGHT
	move_and_slide()
