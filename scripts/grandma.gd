extends "res://scripts/actor_body.gd"
const Art = preload("res://scripts/art.gd")
const BODY_RADIUS := 0.53
const BODY_HEIGHT := 2.15
enum Mood { CALM, CHASE, SEARCH, DISTRACTED }
var mood := Mood.CALM
var model: Node3D
var game: Node3D
var target: Vector3
var last_seen: Vector3
var lost_time := 0.0
var distracted_time := 0.0
var route: PackedVector3Array = []
var repath := 0.0
var wander_timer := 2.0
var patrol_index := 0
var phase := 0.0
var grace := 0.0
var patrol := [Vector3(1.8,0,4.8),Vector3(0,0,2.8),Vector3(0,0,-4.5),Vector3(0,0,-0.5)]
var sees_cat := false

func _ready() -> void:
	setup_collision(BODY_RADIUS,BODY_HEIGHT,4,1|2)
	model=Art.grandma(self)
	target=position
	floor_snap_length=0.25

func visible_cat(ignore_cone: bool = false) -> bool:
	var cat: CharacterBody3D=game.player
	if cat.hidden: return false
	var offset := cat.global_position-global_position
	if offset.length()>16: return false
	if not ignore_cone and offset.length()>2.3:
		var facing := -model.global_basis.z
		if facing.dot(offset.normalized())<0.25: return false
	var from := global_position+Vector3(0,1.63,0)
	var to := cat.global_position+Vector3(0,0.48,0)
	var ray := PhysicsRayQueryParameters3D.create(from,to,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _physics_process(delta: float) -> void:
	if game.state!="playing": return
	grace=maxf(0,grace-delta)
	var cat: CharacterBody3D=game.player
	sees_cat=visible_cat(mood==Mood.CHASE)
	var near_exit := Vector2(cat.position.x,cat.position.z-8).length()<4.0 or cat.position.z>8
	match mood:
		Mood.CALM:
			wander_timer-=delta
			if position.distance_to(target)<0.6 and wander_timer<=0:
				patrol_index=(patrol_index+1)%patrol.size()
				target=patrol[patrol_index]
				wander_timer=4
			if near_exit and sees_cat and grace<=0:
				alert()
		Mood.CHASE:
			if sees_cat:
				last_seen=cat.position
				lost_time=0
			else:
				lost_time+=delta
			if lost_time>1.25:
				mood=Mood.SEARCH
				lost_time=0
				game.toast("奶奶看丢了你……保持安静，找个地方藏好。")
			target=last_seen
			if sees_cat and position.distance_to(cat.position)<BODY_RADIUS+cat.BODY_RADIUS+0.12 and grace<=0:
				game.caught()
		Mood.SEARCH:
			target=last_seen
			lost_time+=delta
			if sees_cat and grace<=0:
				alert()
			elif lost_time>5.5:
				mood=Mood.CALM
				target=patrol[0]
				game.toast("「咦，小家伙跑哪儿去了？」奶奶又去忙自己的事了。")
		Mood.DISTRACTED:
			distracted_time-=delta
			if distracted_time<=0:
				mood=Mood.CALM
				target=patrol[0]
			# An obvious escape right beside her still attracts attention.
			if near_exit and sees_cat and position.distance_to(cat.position)<2.2:
				alert()
	repath-=delta
	if repath<=0:
		route=game.find_route(position,target)
		repath=0.42
	var direction := Vector3.ZERO
	if not route.is_empty():
		while route.size()>1 and Vector2(position.x-route[0].x,position.z-route[0].z).length()<0.08:
			route.remove_at(0)
		var offset := route[0]-position
		offset.y=0
		if offset.length()>0.04: direction=offset.normalized()
	var speed := 3.25 if mood==Mood.CHASE else (1.7 if mood==Mood.SEARCH else 1.05)
	if not route.is_empty():
		speed=minf(speed,Vector2(route[0].x-position.x,route[0].z-position.z).length()/delta)
	velocity.x=direction.x*speed
	velocity.z=direction.z*speed
	if not is_on_floor(): velocity.y-=18*delta
	else: velocity.y=0
	move_with_steps(delta)
	if direction.length()>0.1:
		model.rotation.y=lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),delta*6)
		phase+=delta*speed*6
		model.position.y=(sin(phase)+1.0)*0.0125
	else:
		model.position.y=0

func alert() -> void:
	if mood!=Mood.CHASE:
		game.toast("「米糕，外面危险！快回来！」奶奶追过来了。")
		game.sound("alert")
	mood=Mood.CHASE
	last_seen=game.player.position
	lost_time=0
	repath=0

func distract(point: Vector3) -> void:
	mood=Mood.DISTRACTED
	distracted_time=9.0
	target=point
	repath=0
