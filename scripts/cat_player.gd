extends "res://scripts/actor_body.gd"
const Art = preload("res://scripts/art.gd")
const BODY_RADIUS := 0.76
const BODY_HEIGHT := 1.30
var model: Node3D
var pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.31
var hidden := false
var stamina := 100.0
var moving := false
var sprinting := false
var animation_time := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var enabled := false
var game: Node3D

func _ready() -> void:
	setup_collision(BODY_RADIUS,BODY_HEIGHT,2,1|4)
	model=Art.cat(self)
	pivot=Node3D.new()
	add_child(pivot)
	pivot.position.y=0.72
	spring=SpringArm3D.new()
	pivot.add_child(spring)
	spring.spring_length=3.7
	spring.margin=0.16
	spring.collision_mask=1|4
	var sphere := SphereShape3D.new()
	sphere.radius=0.20
	spring.shape=sphere
	spring.add_excluded_object(get_rid())
	# Shape casts end at contact; keep the lens slightly inside the safe segment.
	var camera_mount := Node3D.new()
	spring.add_child(camera_mount)
	camera=Camera3D.new()
	camera_mount.add_child(camera)
	camera.position.z=-0.16
	camera.fov=68
	camera.near=0.06
	camera.current=true
	floor_snap_length=0.18

func _unhandled_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		yaw-=event.relative.x*0.003
		pitch=clampf(pitch-event.relative.y*0.0025,-1.02,0.30)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			spring.spring_length=maxf(1.6,spring.spring_length-0.3)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			spring.spring_length=minf(5.5,spring.spring_length+0.3)

func _physics_process(delta: float) -> void:
	pivot.rotation=Vector3(pitch,yaw,0)
	if not enabled or hidden:
		velocity=Vector3.ZERO
		animate(delta,0)
		return
	var input := Input.get_vector("left","right","forward","back")
	var direction := Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)
	var crouch := Input.is_action_pressed("crouch")
	sprinting=Input.is_action_pressed("sprint") and stamina>1 and input.length()>0.1 and not crouch
	var speed := 6.0 if sprinting else (1.8 if crouch else 3.7)
	stamina=clampf(stamina+(-22 if sprinting else 17)*delta,0,100)
	velocity.x=move_toward(velocity.x,direction.x*speed,22*delta)
	velocity.z=move_toward(velocity.z,direction.z*speed,22*delta)
	if is_on_floor():
		coyote=0.12
	else:
		coyote-=delta
		velocity.y-=18*delta
	if Input.is_action_just_pressed("jump"): jump_buffer=0.15
	jump_buffer-=delta
	if jump_buffer>0 and coyote>0:
		velocity.y=7.0
		coyote=0
		jump_buffer=0
		game.sound("jump")
	move_with_steps(delta)
	moving=direction.length()>0.1
	if moving:
		model.rotation.y=lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),delta*13)
	model.scale.y=lerpf(model.scale.y,0.72 if crouch else 1.0,delta*10)
	animate(delta,Vector2(velocity.x,velocity.z).length())
	if position.y < -5:
		game.rescue_cat()

func animate(delta: float, speed: float) -> void:
	animation_time+=delta*(3+speed*2)
	model.position.y=sin(animation_time*2)*0.018 if speed>0.1 else sin(animation_time)*0.008
	var i := 0
	for child in model.get_children():
		if child.name.begins_with("Leg"):
			child.rotation.x=sin(animation_time*2+(PI if i in [1,2] else 0))*minf(speed*0.13,0.7)
			i+=1
	model.get_node("Tail").rotation.z=sin(animation_time*0.55)*0.14
