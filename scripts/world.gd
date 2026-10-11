class_name FarmWorld
extends Node2D
var sim: FarmSimulation
var preferences: Dictionary = {}
var camera_tile = Vector2(14,34)
var player_tile = Vector2(13,35)
var zoom = 1
var inspected = false
var target_plot = ""
var preview_plots: Array = []
var selected_crop = "C1"
var facing = 0
var moving = false
var animation = "idle"
var action_time = 0.0
var action_duration = 0.3
var action_effects: Array = []
var clock = 0.0
var textures: Dictionary = {}
var manifest: Dictionary = {}
var props: Array = []
var talking_npc = ""
var effects: Array = []
var memory_id = ""
var memory_progress = 0.0
var stations: Array = [
{"id":"house","name":"Casa de Tomás","tile":Vector2(8,35),"building":Vector2(8,34),"asset":"house","footprint":Vector2(2.4,1.8)},
{"id":"sale","name":"Caixa de venda","tile":Vector2(12,34),"asset":"sale_box"},
{"id":"well","name":"Poço · água inesgotável","tile":Vector2(14,30),"asset":"well"},
{"id":"wood","name":"Pilha de madeira · 2 s/unidade","tile":Vector2(10,31),"asset":"wood_pile"},
{"id":"stone","name":"Pilha de pedra · 2 s/unidade","tile":Vector2(12,30),"asset":"stone_pile"},
{"id":"lia","name":"Lia · correspondência","tile":Vector2(10,35),"asset":"lia"},
{"id":"R1","name":"R1 · Horta baixa","tile":Vector2(19,33),"asset":"field_gate"},
{"id":"P2","name":"Tábuas marcadas","tile":Vector2(20,31),"asset":"clue_marker"},
{"id":"R2","name":"R2 · Canal baixo","tile":Vector2(21,30),"asset":"channel_damaged"},
{"id":"R3","name":"R3 · Oficina","tile":Vector2(24,25),"building":Vector2(24,24),"asset":"workshop_damaged","footprint":Vector2(2,1.4)},
{"id":"workshop","name":"Bancada · fabricação","tile":Vector2(24,23),"asset":"workbench"},
{"id":"R4","name":"R4 · Ponte da margem","tile":Vector2(16,25),"asset":"bridge_damaged"},
{"id":"P5","name":"Recibo na ponte","tile":Vector2(14,24),"asset":"clue_marker"},
{"id":"fishing","name":"Píer · pesca","tile":Vector2(9,18),"asset":"pier"},
{"id":"rui","name":"Rui · pescador","tile":Vector2(10,20),"asset":"rui"},
{"id":"R5","name":"R5 · Campo alto","tile":Vector2(35,24),"asset":"field_gate"},
{"id":"P7","name":"Armário lacrado","tile":Vector2(38,12),"asset":"cabinet"},
{"id":"R6","name":"R6 · Cisterna","tile":Vector2(40,12),"building":Vector2(40,10),"asset":"cistern_damaged","footprint":Vector2(2,1.5)},
{"id":"valve_1","name":"Válvula I","tile":Vector2(38,15),"asset":"valve"},
{"id":"valve_2","name":"Válvula II","tile":Vector2(40,14),"asset":"valve"},
{"id":"valve_3","name":"Válvula III","tile":Vector2(42,13),"asset":"valve"}]
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if FileAccess.file_exists("res://assets/manifest.json"):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
		if parsed is Dictionary: manifest=parsed.get("assets",{})
	var prop_ids=["prop_tree_oak","prop_tree_fruit","prop_grass","prop_fern","prop_rock","prop_smallrock","prop_stump","prop_log","prop_bush","prop_fence","prop_crate","prop_barrel","prop_hook","prop_footprint","prop_ribbon","prop_wheel","prop_sack","prop_basket","prop_bird","prop_butterfly"]
	var locations=[Vector2(6,32),Vector2(6,29),Vector2(9,38),Vector2(16,38),Vector2(8,28),Vector2(15,27),Vector2(6,37),Vector2(10,29),Vector2(18,38),Vector2(4,34),Vector2(7,35),Vector2(11,33),Vector2(7,33),Vector2(20,29),Vector2(23,22),Vector2(25,22),Vector2(8,37),Vector2(16,36),Vector2(17,39),Vector2(9,27)]
	for i in range(prop_ids.size()): props.append({"asset":prop_ids[i],"tile":locations[i]})
	for i in range(20): props.append({"asset":"prop_tree_oak" if i%2==0 else "prop_tree_fruit","tile":Vector2(3+i*2,5 if i%2==0 else 44)})
func iso(tile: Vector2) -> Vector2:
	return Vector2((tile.x-tile.y)*32,(tile.x+tile.y)*16)
func screen(tile: Vector2) -> Vector2:
	return ((iso(tile)-iso(camera_tile))*zoom+Vector2(320,180)).round()
func screen_to_tile(pixel: Vector2) -> Vector2:
	var pos=(pixel-Vector2(320,180))/zoom+iso(camera_tile)
	return Vector2(pos.x/64+pos.y/32,pos.y/32-pos.x/64)
func asset_path(id: String) -> String:
	return str(manifest.get(id,{}).get("path",""))
func draw_asset(id: String, tile: Vector2, frame: int = 0, tint: Color = Color.WHITE) -> void:
	if not manifest.has(id): return
	var d=manifest[id]
	if not d.has("frame_size"): return
	var fs=Vector2(d.frame_size[0],d.frame_size[1]);var pivot=Vector2(d.pivot[0],d.pivot[1])
	sheet(d.path,tile,frame,fs,pivot,tint,int(d.get("columns",1)))
func texture(path: String) -> Texture2D:
	path=path.trim_prefix("res://")
	if textures.has(path): return textures[path]
	if ResourceLoader.exists("res://"+path): textures[path]=load("res://"+path); return textures[path]
	return null
func sheet(path: String, tile: Vector2, frame: int, frame_size: Vector2, pivot: Vector2, tint: Color = Color.WHITE, columns: int = 0) -> void:
	var tex=texture(path)
	if tex==null: return
	var cols=columns if columns>0 else int(tex.get_width()/frame_size.x)
	var rect=Rect2(Vector2((frame%cols)*frame_size.x,int(frame/cols)*frame_size.y),frame_size)
	draw_texture_rect_region(tex,Rect2(screen(tile)-pivot*zoom,frame_size*zoom),rect,tint)
func label_at(tile: Vector2, text: String, color: Color = Color("243c47"), offset: Vector2 = Vector2.ZERO) -> void:
	var font=ThemeDB.fallback_font
	var p=screen(tile)+offset
	var size=12
	var w=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_rect(Rect2(p+Vector2(-w/2-3,-12),Vector2(w+6,16)),Color("f7f4eb"))
	draw_string(font,p+Vector2(-w/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func diamond(tile: Vector2, color: Color, outline: Color = Color.TRANSPARENT, inset: float = 0.0) -> void:
	var p=screen(tile)
	var w=(32-inset)*zoom; var h=(16-inset/2)*zoom
	var points=PackedVector2Array([p+Vector2(0,-h),p+Vector2(w,0),p+Vector2(0,h),p+Vector2(-w,0)])
	draw_colored_polygon(points,color)
	if outline.a>0: draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),outline,1.0*zoom)
func visible(tile: Vector2, pad: float = 180) -> bool:
	var p=screen(tile)
	return p.x>-pad and p.x<640+pad and p.y>-pad and p.y<360+pad
func walkable(tile: Vector2) -> bool:
	if tile.x<1 or tile.y<1 or tile.x>46 or tile.y>46: return false
	if tile.x>=20 and tile.x<=34 and tile.y>=26 and tile.y<=42 and not sim.has("R1"): return false
	if tile.x>=18 and tile.x<=34 and tile.y<=24 and tile.y>=8 and not sim.has("R3"): return false
	if tile.x<=16 and tile.y>=8 and tile.y<=24 and not sim.has("R4"): return false
	if tile.x>=36 and tile.y<=24 and not sim.has("R5"): return false
	if tile.distance_to(Vector2(7,16))<3.0: return false
	for st in stations:
		if st.has("footprint"):
			var d=tile-st.building
			if absf(d.x)<st.footprint.x*0.5 and absf(d.y)<st.footprint.y*0.5: return false
	return true
func safe_position(desired: Vector2) -> Vector2:
	if walkable(desired):return desired
	for radius in range(1,49):
		for direction in [Vector2(0,1),Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
			var candidate=desired+direction*float(radius)
			if walkable(candidate):return candidate
	return Vector2(13,35)
func move_player(input_screen: Vector2, dt: float) -> void:
	moving=input_screen.length_squared()>0.001
	if not moving: return
	var v=input_screen.normalized()*96.0*(1.0+sim.bonus("move"))*dt
	var tile_delta=Vector2(v.x/64+v.y/32,v.y/32-v.x/64)
	var proposed=player_tile+tile_delta
	if walkable(proposed): player_tile=proposed
	else:
		if walkable(player_tile+Vector2(tile_delta.x,0)): player_tile.x+=tile_delta.x
		if walkable(player_tile+Vector2(0,tile_delta.y)): player_tile.y+=tile_delta.y
	var angle=fposmod(input_screen.angle()-PI/2,TAU)
	facing=int(round(angle/(PI/4)))%8
	sim.state.player=[player_tile.x,player_tile.y]
func nearest_station() -> Dictionary:
	var result={}; var distance=1.00001
	for st in stations:
		if st.id in ["fishing","rui","P5"] and not sim.has("R4"): continue
		if st.id in ["P7","R6","valve_1","valve_2","valve_3"] and not sim.has("R5"): continue
		var d=player_tile.distance_to(st.tile)
		if d<distance: distance=d; result=st
	for bid in GameData.BLOCKS:
		if not sim.block_unlocked(bid): continue
		var origin=GameData.BLOCKS[bid].origin
		var tile=Vector2(origin[0]-1,origin[1])
		var d=player_tile.distance_to(tile)
		if d<distance: distance=d; result={"id":bid,"name":bid+" · "+GameData.BLOCKS[bid].name,"tile":tile}
		for pid in sim.state.pending_signals:
			if sim.state.pending_signals[pid]==bid and player_tile.distance_to(tile)<=1.00001 and inspected:
				return {"id":pid,"name":"Inspecionar "+GameData.CLUES[pid].name,"tile":tile}
	return result
func _process(dt: float) -> void:
	clock+=dt
	action_time=maxf(0,action_time-dt)
	for effect in action_effects:effect.life-=dt
	action_effects=action_effects.filter(func(e):return e.life>0)
	for effect in effects: effect.life-=dt
	effects=effects.filter(func(e):return e.life>0)
	queue_redraw()
func _draw() -> void:
	if sim==null: return
	for y in range(48):
		for x in range(48):
			var tile=Vector2(x,y)
			if not visible(tile,40): continue
			var path="assets/terrain/grass_%02d.png" % ((x*13+y*7)%6+1)
			var tex=texture(path)
			if tex!=null: draw_texture_rect(tex,Rect2(screen(tile)-Vector2(32,16)*zoom,Vector2(64,32)*zoom),false)
			else: diamond(tile,Color("80916c").lightened(0.04*((x+y)%3)),Color("798763"))
			if (x>=5 and x<=17 and y>=26 and y<=40) or (x>=18 and x<=20 and y>=25):
				draw_asset("terrain_path_%02d" % ((x+y)%6+1),tile)
	# Short, readable channels connect each productive block.
	if sim.has("R2"):
		for bid in GameData.BLOCKS:
			if not sim.block_unlocked(bid): continue
			var origin=GameData.BLOCKS[bid].origin
			var base=Vector2(origin[0]-1,origin[1]-2)
			for i in range(4):
				var t=base+Vector2(i,0)
				if visible(t): diamond(t,Color("6b9293"),Color("a8c9c4"),11)
	# Water footprint stays behind interactable objects.
	for y in range(13,19):
		for x in range(4,10):
			var t=Vector2(x,y)
			if t.distance_to(Vector2(7,16))<3 and visible(t): diamond(t,Color("6b9293"),Color("a8c9c4"))
	var drawables=[]
	for prop in props:
		if visible(prop.tile): drawables.append({"kind":"prop","asset":prop.asset,"tile":prop.tile,"depth":iso(prop.tile).y})
	for p in sim.state.plots:
		var tile=GameData.plot_tile(p.id)
		if not visible(tile): continue
		diamond(tile,Color("625142") if p.state=="locked" else Color("aa865f"),Color("d1b590"),2)
		if p.state=="locked":
			draw_line(screen(tile)+Vector2(-13,0)*zoom,screen(tile)+Vector2(13,0)*zoom,Color("80916c"),4*zoom)
		else:
			for i in [-1,0,1]: draw_line(screen(tile)+Vector2(-12,i*5)*zoom,screen(tile)+Vector2(12,i*5)*zoom,Color("795b42"),1*zoom)
			if not str(p.crop).is_empty(): drawables.append({"kind":"crop","tile":tile,"plot":p,"depth":iso(tile).y})
		if p.id in preview_plots: diamond(tile,Color(1,1,1,0.08),Color("f7f4eb") if player_tile.distance_to(tile)<=1.0 else Color("e2b55f"),1)
		if inspected or not str(sim.state.blocks[p.block].armed_pattern).is_empty(): label_at(tile,p.position,Color("243c47"),Vector2(0,12)*zoom)
	for st in stations:
		var tile=st.get("building",st.tile)
		if visible(tile): drawables.append({"kind":"station","tile":tile,"station":st,"depth":iso(tile).y})
	for bid in GameData.BLOCKS:
		var origin=GameData.BLOCKS[bid].origin
		var tile=Vector2(origin[0]-1,origin[1])
		if not visible(tile): continue
		draw_asset("block_sign",tile)
		label_at(tile,bid,Color("243c47"),Vector2(0,-24))
		if sim.state.blocks[bid].label:label_at(tile,GameData.item_name(sim.state.blocks[bid].preferred_crop),Color("243c47"),Vector2(0,-43))
		if inspected and sim.has("ENG1") and sim.block_unlocked(bid):
			for p in sim.block_plots(bid):diamond(GameData.plot_tile(p.id),Color(0.65,0.78,0.76,0.06),Color("a8c9c4"),1)
			label_at(Vector2(origin[0]+0.5,origin[1]-2),"Cobertura "+bid+": 4",Color("243c47"),Vector2(0,-38))
		var b=sim.state.blocks[bid]
		for i in range(3):
			var kind=["sprinkler","collector","seeder"][i]
			if b.machines[kind].owned: drawables.append({"kind":"machine","machine":kind,"data":b.machines[kind],"tile":Vector2(origin[0]+i-1,origin[1]-2),"depth":iso(Vector2(origin[0]+i-1,origin[1]-2)).y})
		for pid in sim.state.pending_signals:
			if sim.state.pending_signals[pid]==bid: label_at(Vector2(origin[0]+0.5,origin[1]+0.5),"ECO · Tab + E",Color("243c47"),Vector2(0,-48))
	for id in sim.state.deco:
		var index=GameData.DECO.keys().find(id)
		drawables.append({"kind":"deco","asset":["cosmetic_pot","cosmetic_bench","cosmetic_banner","cosmetic_scarecrow","cosmetic_lantern","cosmetic_sign"][index],"tile":Vector2(9+index*1.5,38),"depth":iso(Vector2(9+index*1.5,38)).y})
	drawables.append({"kind":"player","tile":player_tile,"depth":iso(player_tile).y})
	drawables.sort_custom(func(a,b):return a.depth<b.depth)
	for d in drawables:
		match d.kind:
			"crop":
				var p=d.plot
				var frame=0
				if p.state=="growing": frame=1 if p.remaining>p.duration*0.5 else 2
				if p.state=="mature": frame=3+(int(clock)%2 if not preferences.get("reduced_motion",false) else 0)
				sheet("assets/crops/crop_"+p.crop+".png",d.tile,frame,Vector2(32,40),Vector2(16,38))
				if texture("assets/crops/crop_"+p.crop+".png")==null: draw_circle(screen(d.tile)-Vector2(0,10)*zoom,6*zoom,Color("e2b55f") if p.state=="mature" else Color("80916c"))
				if p.state=="water":
					var c=screen(d.tile)+Vector2(0,-26)*zoom
					draw_arc(c,3*zoom,0,TAU,12,Color("f7f4eb"),1*zoom)
					draw_line(c+Vector2(-3,-1)*zoom,c+Vector2(0,-7)*zoom,Color("f7f4eb"),1*zoom); draw_line(c+Vector2(3,-1)*zoom,c+Vector2(0,-7)*zoom,Color("f7f4eb"),1*zoom)
				if p.state=="mature": label_at(d.tile,"✓",Color("243c47"),Vector2(0,-42)*zoom)
			"station": _draw_station(d.station,d.tile)
			"machine":
				var size={"sprinkler":Vector2(32,32),"collector":Vector2(48,40),"seeder":Vector2(40,40)}[d.machine]
				var active=d.data.enabled and not preferences.get("reduced_motion",false)
				var frame=1+int(clock*6)%4 if active else 0
				draw_asset("machine_"+d.machine,d.tile,frame)
				if not d.data.enabled: label_at(d.tile,"Ⅱ",Color("243c47"),Vector2(0,-size.y)*zoom)
				elif "Saldo" in d.data.status: label_at(d.tile,"$",Color("243c47"),Vector2(0,-size.y)*zoom)
			"deco", "prop":
				var tint=Color.WHITE
				if d.asset.begins_with("prop_tree"):
					var meta=manifest.get(d.asset,{})
					if meta.has("frame_size"):
						var rect=Rect2(screen(d.tile)-Vector2(meta.pivot[0],meta.pivot[1])*zoom,Vector2(meta.frame_size[0],meta.frame_size[1])*zoom)
						if rect.has_point(screen(player_tile)-Vector2(0,20)*zoom): tint.a=0.35
				draw_asset(d.asset,d.tile,0,tint)
			"player":
				var start=0; var count=2
				if moving: start=2; count=6
				if action_time>0:
					match animation:
						"seed": start=8; count=4
						"water": start=12; count=4
						"harvest": start=16; count=6
						_: start=22; count=3
				var index=start+(int(clock*(8 if moving else 5))%count if not preferences.get("reduced_motion",false) or moving else 0)
				if action_time>0:index=start+clampi(int((1-action_time/action_duration)*count),0,count-1)
				var variant={"default":"player","ochre":"player_ochre","blue":"player_blue"}.get(preferences.get("shirt","default"),"player")
				sheet("assets/characters/"+variant+".png",player_tile,facing*25+index,Vector2(32,48),Vector2(16,47),Color.WHITE,25)
				if texture("assets/characters/player.png")==null: draw_circle(screen(player_tile)-Vector2(0,14)*zoom,7*zoom,Color("e2b55f"))
	if sim.has("ESC1"):
		for station in stations:
			var clue={"house":"P1","P2":"P2","P5":"P5","P7":"P7"}.get(station.id,station.id)
			if GameData.CLUES.has(clue) and sim.clue_available(clue):
				var p=screen(station.tile);draw_arc(p,22*zoom,0,TAU,20,Color("a8c9c4"),3*zoom)
		for clue in sim.state.pending_signals:
			var bid=sim.state.pending_signals[clue];var o=GameData.BLOCKS[bid].origin
			for p in sim.block_plots(bid):diamond(GameData.plot_tile(p.id),Color.TRANSPARENT,Color("a8c9c4"),-2)
	if sim.has("ESC9") and sim.has("R5") and not sim.state.final_completed:
		var route=[Vector2(40,17),Vector2(38,15),Vector2(40,14),Vector2(42,13),Vector2(40,10)]
		for i in range(route.size()-1):draw_line(screen(route[i]),screen(route[i+1]),Color("a8c9c4"),3*zoom)
		label_at(Vector2(40,19),"Último registro: B6 → I → II → III",Color("243c47"))
	if memory_id in ["P3","P6","P8"]:
		var tile=Vector2(14,32) if memory_id=="P3" else (Vector2(8,17) if memory_id=="P6" else Vector2(40,11))
		var frame=8;var alpha=0.65
		if memory_id=="P6":
			frame=0
			for i in range(4):draw_asset("channel_damaged",Vector2(6+i,16),0,Color(1,1,1,0.4))
			draw_line(screen(Vector2(5,17)),screen(Vector2(10,17)),Color("a8c9c4"),2*zoom)
		elif memory_id=="P8":
			frame=8
			alpha=0.7*(1-clampf((memory_progress-0.65)/0.35,0,1))
			if not preferences.get("reduced_motion",false):tile+=Vector2(1,-1)*maxf(0,memory_progress-0.3)*2.0
		if not preferences.get("reduced_motion",false):frame+=int(clock*4)%4
		draw_asset("echo_Tomas",tile,frame,Color(1,1,1,alpha))
	if sim.has("R6"):
		for tile in [Vector2(39,10),Vector2(41,10)]:
			draw_circle(screen(tile)+Vector2(0,-24)*zoom,2*zoom,Color("f2d890"))
	if not preferences.get("reduced_particles",false):
		for effect in action_effects:
			var p=screen(effect.tile);var progress=1-effect.life/effect.duration
			if effect.kind=="water":
				for i in range(4):draw_circle(p+Vector2(-12+i*8,-24+progress*24)*zoom,1.5*zoom,Color("a8c9c4"))
			elif effect.kind=="harvest":draw_arc(p,16*zoom,-PI+progress,-0.2+progress,12,Color("f2d890"),2*zoom)
			else:
				for i in range(3):draw_circle(p+Vector2(-6+i*6,-progress*8)*zoom,1.0*zoom,Color("806044"))
	for e in effects:
		var offset=Vector2(0,-30-(1.5-e.life)*15)
		if preferences.get("reduced_motion",false): offset=Vector2(0,-36)
		label_at(e.tile,e.text,Color("243c47"),offset)
func _draw_station(st: Dictionary, tile: Vector2) -> void:
	var asset=st.asset
	if st.id=="R3" and sim.has("R3"): asset="workshop_restored"
	if st.id=="R6" and sim.has("R6"): asset="cistern_restored"
	if st.id=="R4" and sim.has("R4"): asset="bridge_restored"
	if st.id=="R2" and sim.has("R2"): asset="channel_restored"
	var size=Vector2(64,64); var pivot=Vector2(32,62)
	if asset=="house": size=Vector2(192,176); pivot=Vector2(96,158)
	elif "workshop" in asset: size=Vector2(160,144); pivot=Vector2(80,126)
	elif "cistern" in asset: size=Vector2(128,112); pivot=Vector2(64,96)
	elif asset in ["lia","rui"]:
		draw_asset("npc_Lia" if asset=="lia" else "npc_Rui",tile,2+int(clock*5)%3 if talking_npc==asset else (int(clock)%2 if not preferences.get("reduced_motion",false) else 0))
		return
	if st.id=="R1": asset="horta_open" if sim.has("R1") else "horta_locked"
	if st.id=="R5": asset="field_open" if sim.has("R5") else "field_locked"
	if asset=="cabinet": asset="cupboard"
	if asset=="clue_marker": asset="cupboard" if st.id=="P7" else "sale_box"
	if asset=="wood_pile": asset="prop_log"
	if asset=="stone_pile": asset="prop_rock"
	if asset=="workbench": asset="prop_crate"
	if manifest.has(asset):
		var meta=manifest[asset]
		size=Vector2(meta.frame_size[0],meta.frame_size[1]);pivot=Vector2(meta.pivot[0],meta.pivot[1])
	var tint=Color.WHITE
	var image_rect=Rect2(screen(tile)-pivot*zoom,size*zoom)
	var player_point=screen(player_tile)-Vector2(0,22)*zoom
	var target_point=screen(GameData.plot_tile(target_plot))-Vector2(0,18)*zoom if not target_plot.is_empty() else Vector2(-99999,-99999)
	if st.has("footprint") and (image_rect.has_point(player_point) or image_rect.has_point(target_point)) and iso(player_tile).y<iso(tile).y+16: tint.a=0.35
	var path=asset_path(asset)
	var tex=texture(path)
	if tex!=null: draw_texture_rect(tex,image_rect,false,tint)
	else:
		draw_rect(Rect2(screen(tile)+Vector2(-10,-18)*zoom,Vector2(20,18)*zoom),Color("6b9293") if "valve" in asset else Color("795b42"))
	if st.id.begins_with("R"):
		label_at(st.tile,st.id+(" ✓" if sim.has(st.id) else ""),Color("243c47"),Vector2(0,-5))
	if st.id.begins_with("valve"):
		label_at(st.tile,["I","II","III"][int(st.id.substr(6))-1],Color("243c47"),Vector2(0,-22))
	if st.id in ["house","P2","P5","P7"]:
		var clue={"house":"P1","P2":"P2","P5":"P5","P7":"P7"}[st.id]
		if sim.clue_available(clue): label_at(st.tile,"! "+clue,Color("243c47"),Vector2(0,-30))
