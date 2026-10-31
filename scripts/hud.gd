extends CanvasLayer
const INK := Color("f6edd6")
const MUTED := Color("b9c9b5")
const DARK := Color("263c36")
var game: Node3D
var root: Control
var status_label: Label
var room_label: Label
var goal_label: Label
var prompt_label: Label
var notice_label: Label
var stamina_bar: ProgressBar
var menu: Control
var menu_title: Label
var menu_copy: Label
var menu_button: Button
var menu_tag: Label
var map: Control
var notice_time := 0.0
var clock_label: Label
var controls_label: Label
var bottom_panel: Panel
var menu_card: Panel

func _ready() -> void:
	root=Control.new()
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names=PackedStringArray(["PingFang SC","Heiti SC","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	theme.default_font=font
	theme.default_font_size=18
	theme.set_color("font_color","Label",INK)
	root.theme=theme
	var top := panel(root,Vector2(32,28),Vector2(375,134),Color(0.12,0.21,0.18,0.91))
	label(top,"A LITTLE WAY HOME    /    米糕出逃记",Vector2(22,15),14,MUTED)
	room_label=label(top,"01  /  午后的公寓",Vector2(22,42),27,INK)
	goal_label=label(top,"穿过大门，去花园找到猫咪伙伴",Vector2(22,87),17,INK)
	var status := panel(root,Vector2(32,177),Vector2(375,61),Color(0.12,0.21,0.18,0.87))
	status_label=label(status,"●  奶奶正在散步",Vector2(20,17),19,MUTED)
	var bottom := panel(root,Vector2(32,-107),Vector2(385,76),Color(0.12,0.21,0.18,0.89))
	bottom_panel=bottom
	label(bottom,"米糕",Vector2(18,12),20,INK)
	label(bottom,"小小的爪子，大大的世界",Vector2(81,15),14,MUTED)
	stamina_bar=ProgressBar.new()
	bottom.add_child(stamina_bar)
	stamina_bar.position=Vector2(20,47)
	stamina_bar.size=Vector2(344,6)
	stamina_bar.show_percentage=false
	stamina_bar.add_theme_stylebox_override("background",style(Color("43594c"),4))
	stamina_bar.add_theme_stylebox_override("fill",style(Color("d9c08a"),4))
	prompt_label=label(root,"",Vector2.ZERO,24,INK)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position=Vector2(-280,-146)
	prompt_label.size=Vector2(560,44)
	prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_stylebox_override("normal",style(Color(0.12,0.21,0.18,0.92),14,Vector2(18,12)))
	notice_label=label(root,"",Vector2.ZERO,19,INK)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_label.position=Vector2(-360,38)
	notice_label.size=Vector2(720,44)
	notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_stylebox_override("normal",style(Color(0.12,0.21,0.18,0.92),12,Vector2(18,12)))
	controls_label=label(root,"W A S D  移动     鼠标  环视     空格  跳跃     E  互动\nShift  奔跑     Ctrl  慢走     Q  喵叫     Esc  暂停",Vector2.ZERO,16,INK)
	controls_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	controls_label.position=Vector2(-554,-88)
	controls_label.size=Vector2(520,58)
	controls_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	controls_label.add_theme_color_override("font_shadow_color",Color("263b30"))
	controls_label.add_theme_constant_override("shadow_offset_y",2)
	map=Control.new()
	root.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map.position=Vector2(-254,28)
	map.size=Vector2(222,234)
	map.draw.connect(draw_map)
	clock_label=label(root,"",Vector2.ZERO,15,MUTED)
	clock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	clock_label.position=Vector2(-250,272)
	clock_label.size=Vector2(210,30)
	clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	build_menu()
	root.resized.connect(layout_ui)
	layout_ui.call_deferred()

func style(color: Color, radius: int = 12, margin: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=color
	s.set_corner_radius_all(radius)
	s.content_margin_left=margin.x
	s.content_margin_right=margin.x
	s.content_margin_top=margin.y
	s.content_margin_bottom=margin.y
	return s

func panel(parent: Node, pos: Vector2, size_value: Vector2, color: Color) -> Panel:
	var p := Panel.new()
	parent.add_child(p)
	p.position=pos
	p.size=size_value
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",style(color,16))
	return p

func label(parent: Node, text_value: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	parent.add_child(l)
	l.text=text_value
	l.position=pos
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func build_menu() -> void:
	menu=Control.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.08,0.16,0.13,0.34)
	var card := panel(menu,Vector2(72,0),Vector2(570,625),Color(0.11,0.19,0.16,0.96))
	menu_card=card
	menu_tag=label(card,"一  场  小  小  的  冒  险",Vector2(38,36),17,Color("d8c491"))
	menu_title=label(card,"米糕\n出逃记",Vector2(34,79),60,INK)
	label(card,"A  L I T T L E  W A Y  H O M E",Vector2(39,254),16,MUTED)
	var line := ColorRect.new()
	card.add_child(line)
	line.position=Vector2(40,295)
	line.size=Vector2(486,1)
	line.color=Color("607460")
	menu_copy=label(card,"午后阳光正好，花园里的朋友在等你。\n跳上床，钻进纸箱，悄悄穿过奶奶的公寓。\n她平时很温柔，但不会放心让你独自出门。",Vector2(39,322),20,INK)
	menu_copy.add_theme_constant_override("line_spacing",12)
	menu_button=Button.new()
	card.add_child(menu_button)
	menu_button.position=Vector2(39,465)
	menu_button.size=Vector2(488,64)
	menu_button.text="出发，去找伙伴     →"
	menu_button.add_theme_font_size_override("font_size",22)
	menu_button.add_theme_color_override("font_color",DARK)
	menu_button.add_theme_color_override("font_focus_color",DARK)
	menu_button.add_theme_color_override("font_hover_color",DARK)
	menu_button.add_theme_color_override("font_pressed_color",DARK)
	menu_button.add_theme_stylebox_override("normal",style(Color("ddc793"),11))
	menu_button.add_theme_stylebox_override("hover",style(Color("f0dba9"),11))
	menu_button.add_theme_stylebox_override("pressed",style(Color("c2ad7d"),11))
	menu_button.pressed.connect(func(): game.menu_action())
	label(card,"第三人称探索  /  空格跳跃  /  E 互动\n戴上耳机，听听米糕的声音。",Vector2(39,551),16,MUTED)

func show_menu(mode: String) -> void:
	menu.visible=true
	match mode:
		"title":
			menu_title.text="米糕\n出逃记"
		"paused":
			menu_tag.text="让小爪子休息一下"
			menu_title.text="午后\n暂停键"
			menu_copy.text="WASD 移动，鼠标环视，滚轮调整距离。\n空格跳跃，E 互动，Shift 奔跑，Ctrl 慢走。\n靠家具、关房门或躲纸箱，让奶奶看不见你。"
			menu_button.text="继续冒险     →"
		"caught":
			menu_tag.text="一次温柔的拦截"
			menu_title.text="被奶奶\n抱回来了"
			menu_copy.text="「小米糕，怎么又想往外跑？」\n试试先用收音机引开奶奶，再去打开大门。\n被追赶时，关门和躲在家具后面都很有用。"
			menu_button.text="再试一次     →"
		"won":
			menu_tag.text="小小冒险，圆满抵达"
			menu_title.text="自由的风\n和新朋友"
			menu_copy.text="米糕找到了花园里的猫咪伙伴！\n这场冒险用了 %d 分 %02d 秒。\n阳光、草地，还有属于小猫的整个下午。" % [int(game.elapsed)/60,int(game.elapsed)%60]
			menu_button.text="再来一场冒险     →"
	menu_button.grab_focus()

func _process(delta: float) -> void:
	if not is_instance_valid(game.player): return
	var playing: bool=game.state=="playing"
	menu.visible=not playing
	for child in root.get_children():
		if child!=menu: child.visible=playing
	if not playing: return
	stamina_bar.value=game.player.stamina
	var outdoor: bool=game.player.position.z>8.2
	room_label.text="02  /  自由的花园" if outdoor else "01  /  "+game.room_name(game.player.position)
	goal_label.text="沿石板小路前进，在猫群中央会合" if outdoor else "穿过大门，去花园找到猫咪伙伴"
	var names := ["●  奶奶正在散步","!  奶奶追来了！挡住她的视线","◌  奶奶在寻找你……","♪  奶奶被声音吸引了"]
	status_label.text="◒  你藏好了 · E 离开纸箱" if game.player.hidden else names[game.grandma.mood]
	status_label.modulate=Color("ffc4a1") if game.grandma.mood==1 else Color.WHITE
	prompt_label.text=game.interaction_prompt()
	prompt_label.visible=not prompt_label.text.is_empty()
	notice_time-=delta
	notice_label.visible=notice_time>0
	clock_label.text="花园在出口外    ·    %02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60]
	map.queue_redraw()

func toast(text_value: String) -> void:
	notice_label.text=text_value
	notice_time=4.5

func draw_map() -> void:
	map.draw_style_box(style(Color(0.12,0.21,0.18,0.91),16),Rect2(Vector2.ZERO,map.size))
	var offset := Vector2(111,111)
	var scale_value := 8.5
	var wall_color := Color("b4bda4")
	map.draw_rect(Rect2(Vector2(25,37),Vector2(172,136)),Color("536657"),true)
	for x in [-1.8,1.8]:
		map.draw_line(offset+Vector2(x,-8)*scale_value,offset+Vector2(x,2)*scale_value,wall_color,2)
	for z in [-3.55,2.0]:
		map.draw_line(offset+Vector2(-10,z)*scale_value,offset+Vector2(-1.8,z)*scale_value,wall_color,2)
		map.draw_line(offset+Vector2(1.8,z)*scale_value,offset+Vector2(10,z)*scale_value,wall_color,2)
	map.draw_rect(Rect2(Vector2(25,37),Vector2(172,136)),wall_color,false,2)
	map.draw_line(Vector2(101,179),Vector2(122,179),Color("e4c480"),4)
	var font: Font=root.theme.default_font
	for entry in [["卧室",Vector2(49,60)],["卧室",Vector2(49,114)],["浴室",Vector2(144,60)],["厨房",Vector2(144,114)],["客厅",Vector2(91,158)]]:
		map.draw_string(font,entry[1],entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d6d8c1"))
	map.draw_string(font,Vector2(20,24),"公寓地图",HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK)
	map.draw_string(font,Vector2(20,217),"● 米糕    ● 奶奶    ━ 出口",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
	var p: Vector3=game.player.position
	var g: Vector3=game.grandma.position
	var point := offset+Vector2(p.x,clampf(p.z,-8,10))*scale_value
	map.draw_circle(offset+Vector2(g.x,clampf(g.z,-8,10))*scale_value,4,Color("e49c83"))
	map.draw_circle(point,5,Color("f0d296"))
	var direction := Vector2(-sin(game.player.yaw),-cos(game.player.yaw))
	map.draw_line(point,point+direction*12,Color("f0d296"),2)

func layout_ui() -> void:
	var viewport_size := root.size
	bottom_panel.position=Vector2(32,viewport_size.y-107)
	prompt_label.position=Vector2(viewport_size.x/2-280,viewport_size.y-146)
	notice_label.position=Vector2(viewport_size.x/2-300,28)
	notice_label.size=Vector2(600,44)
	controls_label.position=Vector2(viewport_size.x-554,viewport_size.y-88)
	map.position=Vector2(viewport_size.x-254,28)
	clock_label.position=Vector2(viewport_size.x-250,272)
	menu_card.position=Vector2(72,(viewport_size.y-625)/2)
