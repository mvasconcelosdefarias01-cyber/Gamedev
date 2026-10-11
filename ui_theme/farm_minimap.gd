class_name FarmMinimap
extends Control

## Read-only map presentation. IDs/coordinates come from GameData; this Control
## never changes campaign state or moves the player. Configure from the HUD.

const SECTORS = [
	{"id":"S1", "name":"Terreiro", "bounds":Rect2(4,26,14,16), "repair":"", "color":Color("aa865f")},
	{"id":"S2", "name":"Horta baixa", "bounds":Rect2(20,26,14,16), "repair":"R1", "color":Color("b2bb86")},
	{"id":"S3", "name":"Pomar antigo", "bounds":Rect2(18,8,16,16), "repair":"R3", "color":Color("80916c")},
	{"id":"S4", "name":"Lago e margem", "bounds":Rect2(2,8,14,16), "repair":"R4", "color":Color("6b9293")},
	{"id":"S5", "name":"Campo da cisterna", "bounds":Rect2(36,4,9,20), "repair":"R5", "color":Color("a8c9c4")}
]
const CONNECTIONS = [[Vector2(15,34),Vector2(24,34)], [Vector2(24,34),Vector2(25,20)], [Vector2(25,20),Vector2(12,20)], [Vector2(25,20),Vector2(40,17)]]

var simulation: RefCounted
var player_tile := Vector2(13,35)
var destination_tile := Vector2(-1,-1)
var destination_name := "Destino selecionado"

func _ready() -> void:
	_sync_minimum()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_description()

func configure(farm: RefCounted, player: Vector2, destination: Vector2 = Vector2(-1,-1)) -> void:
	simulation = farm
	player_tile = player
	destination_tile = destination
	_update_description()
	queue_redraw()

func set_destination_name(value: String) -> void:
	destination_name = value
	_update_description()

func _update_description() -> void:
	var text = "Mapa isométrico: norte para o alto à direita. Você: (%d, %d)." % [roundi(player_tile.x),roundi(player_tile.y)]
	if _has_destination():
		text += " %s: (%d, %d)." % [destination_name,roundi(destination_tile.x),roundi(destination_tile.y)]
	else:
		text += " Selecione uma pista no caderno para marcar seu destino."
	text += " Setores fechados são listrados; canteiros disponíveis têm contorno."
	tooltip_text = text
	# The same plain text is exposed to Godot's accessibility backend when present.
	if "accessibility_description" in self:
		set("accessibility_description",text)

func _has_destination() -> bool:
	return destination_tile.x >= 0 and destination_tile.y >= 0 and destination_tile.x <= 48 and destination_tile.y <= 48

func _unlocked(repair: String) -> bool:
	return repair.is_empty() or (simulation != null and simulation.has_method("has") and bool(simulation.call("has",repair)))

func _point(tile: Vector2) -> Vector2:
	var font_size = maxf(14,get_theme_font_size("font_size","Label"))
	var ui_scale = font_size/16
	var center = Vector2(size.x/2,font_size+11*ui_scale)
	var available = maxf(0.1,minf((size.x-30*ui_scale)/96,(size.y-center.y-font_size*0.75-12*ui_scale)/48))
	return center + Vector2((tile.x-tile.y)*available,(tile.x+tile.y)*available/2)

func _sync_minimum() -> void:
	var text_scale = maxf(1,get_theme_font_size("font_size","Label")/16.0)
	custom_minimum_size = Vector2(180,112)*text_scale

func _quad(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([_point(rect.position),_point(rect.position+Vector2(rect.size.x,0)),_point(rect.end),_point(rect.position+Vector2(0,rect.size.y))])

func _draw() -> void:
	var ink = get_theme_color("font_color","Label")
	if ink.a == 0: ink = Color("243c47")
	var paper = Color("f7f4eb")
	var font = get_theme_font("font","Label")
	var font_size = maxi(get_theme_font_size("font_size","Label"),14)
	var ui_scale = font_size/16.0
	draw_style_box(get_theme_stylebox("panel","Panel"),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(10*ui_scale,font_size+4*ui_scale),"Mapa · N ↗",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
	var boundary = _quad(Rect2(0,0,48,48))
	draw_colored_polygon(boundary,Color("e1dfd4"))
	draw_polyline(PackedVector2Array([boundary[0],boundary[1],boundary[2],boundary[3],boundary[0]]),ink,1)
	for route in CONNECTIONS:
		draw_line(_point(route[0]),_point(route[1]),Color("aa865f"),2)
	for sector in SECTORS:
		var points = _quad(sector.bounds)
		var open = _unlocked(sector.repair)
		draw_colored_polygon(points,sector.color if open else Color("c4c3b9"))
		draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),ink,1)
		if not open:
			for i in range(3):
				var t = (i+1)/4.0
				draw_line(points[0].lerp(points[1],t),points[3].lerp(points[2],t),Color(ink,0.5),1)
	if simulation != null:
		for bid in GameData.BLOCKS:
			var block = GameData.BLOCKS[bid]
			if not _unlocked(block.unlock): continue
			var origin = Vector2(block.origin[0]+0.5,block.origin[1]+0.5)
			var point = _point(origin)
			draw_rect(Rect2(point-Vector2(2,2),Vector2(4,4)),paper)
			draw_rect(Rect2(point-Vector2(2,2),Vector2(4,4)),ink,false,1)
	if _has_destination():
		var dest = _point(destination_tile)
		draw_circle(dest,5,ink)
		draw_line(dest-Vector2(3,0),dest+Vector2(3,0),paper,2)
		draw_line(dest-Vector2(0,3),dest+Vector2(0,3),paper,2)
	var player = _point(player_tile.clamp(Vector2.ZERO,Vector2(48,48)))
	draw_circle(player,4,paper)
	draw_arc(player,4,0,TAU,16,ink,2)
	draw_circle(player,1.4,ink)
	draw_string(font,Vector2(10*ui_scale,size.y-6*ui_scale),"○ Você   + Destino",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(12*ui_scale),ink)
	if has_focus():
		draw_style_box(get_theme_stylebox("focus","Button"),Rect2(Vector2.ZERO,size))

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_sync_minimum()
	if what in [NOTIFICATION_RESIZED,NOTIFICATION_THEME_CHANGED,NOTIFICATION_FOCUS_ENTER,NOTIFICATION_FOCUS_EXIT]:
		queue_redraw()
