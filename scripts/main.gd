extends Node

var sim: FarmSimulation
var store: FarmSaveStore
var preferences: Dictionary
var world: FarmWorld
var world_view: SubViewport
var world_container: SubViewportContainer
var ui: Control
var hud: Control
var coins_label: Label
var objective_label: Label
var prompt_label: Label
var toast_label: Label
var culture_buttons: Dictionary = {}
var modal: PanelContainer
var modal_body: VBoxContainer
var modal_context = ""
var modal_id = ""
var mode = "TITLE"
var current_slot = 1
var selected_crop = "C1"
var inspection = false
var action_held = false
var action_clock = 0.0
var autosave_clock = 0.0
var refresh_clock = 0.0
var toast_clock = 0.0
var has_focus = true
var panning = false
var fishing_clock = 0.0
var memory_clock = 0.0
var memory_limit = 0.0
var remap_action = ""
var material_target = ""
var machine_players: Dictionary = {}
var manual_action = false
var memory_captions: Label
var minimap: Control
var destination_tile = Vector2(14,34)
var reveal_labels: Array = []
var reveal_clock = 0.0
var memory_camera_before = Vector2.ZERO
var map_toggle: Button
var audio_caption = ""
var audio_caption_clock = 0.0
var ui_theme: Theme
var audio_players: Dictionary = {}
var music_players: Array = []
var ambience_players: Array = []
var last_music = ""
var pending_music = ""
var music_fade = 0.0
var last_reward_time = {}
var actions = {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"interact":[KEY_E],"inspection":[KEY_TAB],"upgrades":[KEY_U],"journal":[KEY_J],"pause":[KEY_ESCAPE],"home":[KEY_HOME],"culture_1":[KEY_1],"culture_2":[KEY_2],"culture_3":[KEY_3],"culture_4":[KEY_4],"culture_5":[KEY_5],"culture_6":[KEY_6],"tool":[-MOUSE_BUTTON_LEFT],"pan":[-MOUSE_BUTTON_MIDDLE],"zoom_in":[-MOUSE_BUTTON_WHEEL_UP],"zoom_out":[-MOUSE_BUTTON_WHEEL_DOWN]}
var action_names={"move_left":"Mover à esquerda","move_right":"Mover à direita","move_up":"Mover para cima","move_down":"Mover para baixo","interact":"Interagir","inspection":"Cultivo/inspeção","upgrades":"Melhorias","journal":"Caderno","pause":"Pausar/voltar","home":"Centralizar câmera","tool":"Usar ferramenta","pan":"Arrastar câmera","zoom_in":"Aumentar zoom","zoom_out":"Diminuir zoom"}
func _ready() -> void:
	store=FarmSaveStore.new()
	preferences=store.load_preferences()
	sim=FarmSimulation.new()
	sim.changed.connect(_simulation_changed)
	sim.reward.connect(_on_reward)
	setup_input()
	if ResourceLoader.exists("res://ui_theme/fazenda_theme.tres"): ui_theme=load("res://ui_theme/fazenda_theme.tres").duplicate(true)
	else: ui_theme=Theme.new()
	world_view=SubViewport.new(); world_view.size=Vector2i(640,360); world_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world_view.transparent_bg=false
	var view_container=SubViewportContainer.new(); view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); view_container.stretch=true; view_container.stretch_shrink=2; view_container.mouse_filter=Control.MOUSE_FILTER_IGNORE; view_container.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	world_container=view_container
	add_child(view_container); view_container.add_child(world_view)
	get_viewport().size_changed.connect(layout_world)
	layout_world()
	world=FarmWorld.new(); world.sim=sim; world.preferences=preferences; world_view.add_child(world)
	ui=Control.new(); ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(ui)
	apply_preferences()
	build_hud()
	show_title()
	get_tree().auto_accept_quit=false
	if OS.get_cmdline_user_args().has("--smoke-new"): start_game(1,true)
func layout_world() -> void:
	if world_container==null:return
	var size=get_viewport().get_visible_rect().size
	var factor=maxi(1,int(minf(size.x/640.0,size.y/360.0)))
	world_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	world_container.stretch_shrink=factor
	world_container.size=Vector2(640,360)*factor
	world_container.position=(size-world_container.size)/2
func setup_input() -> void:
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var keys=preferences.bindings.get(action,actions[action])
		for code in keys:
			var event
			if int(code)<0: event=InputEventMouseButton.new(); event.button_index=-int(code)
			else: event=InputEventKey.new(); event.physical_keycode=int(code)
			InputMap.action_add_event(action,event)
func apply_preferences() -> void:
	var theme_path="res://ui_theme/fazenda_high_contrast.tres" if preferences.high_contrast else "res://ui_theme/fazenda_theme.tres"
	if ResourceLoader.exists(theme_path):ui_theme=load(theme_path).duplicate(true)
	ui_theme.default_font_size=int(16*float(preferences.text_scale))
	ui.theme=ui_theme
	world.preferences=preferences
	for player in audio_players.values(): player.volume_db=linear_to_db(maxf(0.0001,float(preferences.interface_volume)))-12
	for player in music_players: player.volume_db=linear_to_db(maxf(0.0001,float(preferences.music_volume)))-18
	for player in ambience_players: player.volume_db=linear_to_db(maxf(0.0001,float(preferences.ambience_volume)))-20
func box(parent: Node, separation: int = 12) -> VBoxContainer:
	var b=VBoxContainer.new(); b.add_theme_constant_override("separation",separation); parent.add_child(b); return b
func row(parent: Node) -> HBoxContainer:
	var b=HBoxContainer.new(); b.add_theme_constant_override("separation",12); parent.add_child(b); return b
func label(parent: Node, text: String, size: int = 0) -> Label:
	var l=Label.new(); l.text=text; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if size>0: l.add_theme_font_size_override("font_size",int(size*float(preferences.text_scale)))
	parent.add_child(l); return l
func button(parent: Node, text: String, callback: Callable, disabled: bool = false) -> Button:
	var b=Button.new(); b.text=text; b.custom_minimum_size.y=40*float(preferences.ui_scale); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.disabled=disabled; b.pressed.connect(func():play_specific_audio("ui_confirm");callback.call());b.focus_entered.connect(func():play_specific_audio("ui_focus")); parent.add_child(b); return b
func check(parent: Node, text: String, value: bool, callback: Callable) -> CheckButton:
	var b=CheckButton.new(); b.text=text; b.button_pressed=value; b.custom_minimum_size.y=40*float(preferences.ui_scale); b.toggled.connect(callback); parent.add_child(b); return b
func separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())
func build_hud() -> void:
	if hud!=null: hud.queue_free()
	hud=Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(hud)
	var top=PanelContainer.new(); top.position=Vector2(32,24); top.size=Vector2(460,72); hud.add_child(top)
	coins_label=label(top,"",18)
	var objective=PanelContainer.new(); objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); objective.position=Vector2(-350,24); objective.size=Vector2(318,140); hud.add_child(objective)
	var ob=box(objective,5); objective_label=label(ob,"",16)
	button(ob,"Ver objetivo · caderno",func():show_panel("journal"))
	var bottom=PanelContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); bottom.offset_left=32; bottom.offset_right=-32; bottom.offset_top=-int((120 if float(preferences.ui_scale)<1.5 else 220)*float(preferences.ui_scale)/ (1.5 if float(preferences.ui_scale)>=1.5 else 1.0)+20); bottom.offset_bottom=-20; hud.add_child(bottom)
	var b=box(bottom,6)
	var grid=GridContainer.new(); grid.columns=3 if float(preferences.ui_scale)>=1.5 else 6; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",6); b.add_child(grid)
	culture_buttons={}
	for i in range(1,7):
		var id="C"+str(i)
		var btn=button(grid,str(i)+" · "+GameData.CROPS[id].name,func():select_crop(id))
		var path="res://assets/ui/crop_"+id+".png"
		if ResourceLoader.exists(path): btn.icon=load(path); btn.expand_icon=false
		btn.tooltip_text="Semente %d · valor de venda %d · saldo base por lote %d\n%s" % [GameData.CROPS[id].seed,GameData.CROPS[id].price*GameData.CROPS[id].yield,GameData.CROPS[id].price*GameData.CROPS[id].yield-GameData.CROPS[id].seed,"Disponível" if sim.crop_unlocked(id) else "Requer "+GameData.CROPS[id].unlock]
		culture_buttons[id]=btn
	var shortcuts=row(b)
	button(shortcuts,"Tab · inspeção",func():toggle_inspection())
	button(shortcuts,"U · melhorias",func():show_panel("upgrades"))
	button(shortcuts,"J · caderno",func():show_panel("journal"))
	button(shortcuts,"Esc · pausa",func():show_panel("pause"))
	prompt_label=label(hud,"",16); prompt_label.position=Vector2((ui.get_viewport_rect().size.x-550)/2,ui.get_viewport_rect().size.y-(280 if float(preferences.ui_scale)<1.5 else 320)); prompt_label.size=Vector2(550,50); prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color",Color("f7f4eb")); prompt_label.add_theme_color_override("font_outline_color",Color("243c47")); prompt_label.add_theme_constant_override("outline_size",5)
	memory_captions=label(hud,"",16);memory_captions.position=Vector2(32,260);memory_captions.size=Vector2(440,100)
	memory_captions.add_theme_color_override("font_color",Color("f7f4eb"));memory_captions.add_theme_color_override("font_outline_color",Color("243c47"));memory_captions.add_theme_constant_override("outline_size",4)
	if ResourceLoader.exists("res://ui_theme/farm_minimap.gd"):
		minimap=load("res://ui_theme/farm_minimap.gd").new();minimap.position=Vector2(ui.get_viewport_rect().size.x-290,290);minimap.size=Vector2(250,150);hud.add_child(minimap)
		map_toggle=button(hud,"Recolher mapa",func():preferences.minimap_visible=not preferences.get("minimap_visible",true);store.save_preferences(preferences);refresh_hud())
		map_toggle.position=Vector2(ui.get_viewport_rect().size.x-240,238);map_toggle.size=Vector2(190,40)
	toast_label=label(hud,"",16); toast_label.position=Vector2(32,145); toast_label.size=Vector2(435,120); toast_label.add_theme_color_override("font_color",Color("f7f4eb")); toast_label.add_theme_color_override("font_outline_color",Color("243c47")); toast_label.add_theme_constant_override("outline_size",5)
func show_title() -> void:
	mode="TITLE"; sim.paused=true; hud.visible=false
	open_modal("Fazenda Entre Ecos","title")
	label(modal_body,"Cultive o presente. Escute o que a água guardou.",24)
	label(modal_body,"Uma fazenda, seis culturas e um mistério sem pressa. Teclado e mouse · jogo local · três slots.")
	for slot in range(1,4):
		separator(modal_body)
		label(modal_body,"Slot %d — %s" % [slot,store.slot_summary(slot)],18)
		var r=row(modal_body)
		var result=store.load_slot(slot)
		button(r,"Continuar",func():start_game(slot,false),not result.ok)
		button(r,"Novo jogo",func():confirm_new(slot))
		if not result.ok and result.backup_available: button(r,"Recuperar backup",func():load_backup(slot))
	button(modal_body,"Opções e acessibilidade",func():show_panel("options","title"))
	button(modal_body,"Sair",func():quit_game())
	focus_first()
func confirm_new(slot: int) -> void:
	if FileAccess.file_exists(store.slot_path(slot)):
		open_modal("Substituir slot %d?" % slot,"confirm")
		label(modal_body,"Este comando substitui a campanha deste slot. O backup anterior será mantido.")
		button(modal_body,"Confirmar novo jogo",func():start_game(slot,true))
		button(modal_body,"Cancelar",func():show_title())
	else: start_game(slot,true)
func start_game(slot: int, new_game: bool = true) -> void:
	current_slot=slot
	if new_game: sim.new_game(slot);sim.state.offline_enabled=preferences.get("offline_enabled",true)
	else:
		var result=store.load_slot(slot)
		if not result.ok: show_error(result.message); return
		var loaded=sim.import_state(result.data)
		if not loaded.ok: show_error(loaded.message); return
	var saved_position=Vector2(sim.state.player[0],sim.state.player[1])
	world.player_tile=world.safe_position(saved_position);world.camera_tile=world.player_tile
	sim.state.player=[world.player_tile.x,world.player_tile.y]
	if world.player_tile.distance_to(saved_position)>0.01:toast("Posição recuperada em um corredor seguro; campanha preservada")
	close_modal(); mode="FARM"; sim.paused=false; hud.visible=true
	autosave_clock=0; action_held=false
	refresh_hud()
	if new_game:
		save_game()
		show_dialog("Lia","Tomás preparou a cessão desta propriedade antes de partir. Cuide do que ainda cresce.\n\nWASD ou setas para mover. Escolha Nabo (1), aproxime-se de B1 e segure o botão esquerdo para semear. Irrigue uma vez e colha quando aparecer ✓.")
	else:
		var summary=sim.apply_offline(int(Time.get_unix_time_from_system()))
		save_game()
		if summary.computed_seconds>0: show_panel("offline")
	update_music()
func load_backup(slot: int) -> void:
	var result=store.load_slot(slot,true)
	if not result.ok: show_error(result.message); return
	var r=sim.import_state(result.data)
	if not r.ok: show_error(r.message); return
	current_slot=slot
	var restored=store.restore_backup(slot)
	if not restored.ok:show_error(restored.message);return
	start_game(slot,false)
func show_error(message: String) -> void:
	open_modal("Recuperação","error"); label(modal_body,message); button(modal_body,"Voltar ao menu",func():show_title()); focus_first()
func open_modal(title: String, id: String) -> void:
	if modal!=null: modal.queue_free()
	play_specific_audio("ui_panel")
	action_held=false;world.moving=false; reveal_labels=[];reveal_clock=0; modal_id=id; sim.paused=true; hud.visible=false
	if mode!="TITLE": mode="MODAL"
	for player in machine_players.values():player.stop()
	for player in music_players:player.volume_db=linear_to_db(maxf(0.0001,float(preferences.music_volume)))-24
	modal=PanelContainer.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.offset_left=64; modal.offset_top=32; modal.offset_right=-64; modal.offset_bottom=-32; ui.add_child(modal)
	var margin=MarginContainer.new(); margin.add_theme_constant_override("margin_left",24); margin.add_theme_constant_override("margin_right",24); margin.add_theme_constant_override("margin_top",18); margin.add_theme_constant_override("margin_bottom",18); modal.add_child(margin)
	var body=box(margin)
	var title_row=row(body); label(title_row,title,26)
	if id=="memory":button(title_row,"Pular / continuar · Esc",func():finish_memory(world.memory_id))
	elif id!="title": button(title_row,"Voltar · Esc",func():close_modal())
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(scroll)
	modal_body=box(scroll,14); modal_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
func close_modal() -> void:
	if modal!=null: modal.queue_free(); modal=null
	if mode=="MEMORY" and world.memory_id in ["P3","P6","P8"]:world.camera_tile=memory_camera_before
	world.memory_id=""; world.talking_npc=""; action_held=false
	if mode=="TITLE": show_title(); return
	mode="FARM"; hud.visible=true; sim.paused=not has_focus; modal_id=""; refresh_hud()
	for player in music_players:player.volume_db=linear_to_db(maxf(0.0001,float(preferences.music_volume)))-18
func focus_first() -> void:
	call_deferred("_focus_first")
func _focus_first() -> void:
	if modal==null: return
	var buttons=modal.find_children("*","Button",true,false)
	for b in buttons:
		if not b.disabled: b.grab_focus(); return
func show_panel(id: String, context: String = "") -> void:
	var aliases={"T2":"block","T3":"upgrades","T4":"journal","T5":"repair","T6":"sale","T7":"workshop","T8":"fishing","T9":"pause","T11":"offline","T12":"ending"}
	id=aliases.get(id,id); modal_context=context
	match id:
		"block": show_block(context if not context.is_empty() else "B1")
		"upgrades": show_upgrades(context if not context.is_empty() else "CUL")
		"journal": show_journal(context)
		"repair": show_repair(context if not context.is_empty() else sim.state.objective)
		"sale": show_sale()
		"workshop": show_workshop()
		"fishing": begin_fishing()
		"pause": show_pause()
		"options": show_options(context)
		"offline": show_offline()
		"ending": show_ending()
	focus_first()
func show_pause() -> void:
	open_modal("Pausa — a fazenda espera por você","pause")
	button(modal_body,"Continuar cultivando",func():close_modal())
	button(modal_body,"Salvar agora",func():toast(save_game().message))
	button(modal_body,"Opções e acessibilidade",func():show_options("pause"))
	button(modal_body,"Salvar e voltar ao menu",func():
		var r=save_game()
		if r.ok: mode="TITLE"; show_title()
		else: label(modal_body,r.message))
func show_upgrades(tree: String = "CUL") -> void:
	open_modal("Melhorias — escolha seu ritmo","upgrades")
	var tabs=row(modal_body)
	for t in ["CUL","ENG","ESC"]:
		var name={"CUL":"Cultivo","ENG":"Engenho","ESC":"Escuta"}[t]
		var tab_button=button(tabs,name,func():show_upgrades(t))
		var icon_path=world.asset_path("tree_"+name)
		if ResourceLoader.exists(icon_path):tab_button.icon=load(icon_path)
	label(modal_body,"%d moedas · %d pontos de Escuta. Pesquisa habilita máquinas; cada unidade é comprada no bloco." % [sim.coins(),sim.state.listen_points])
	var crop=GameData.CROPS[selected_crop]
	label(modal_body,"%s: rendimento base %d → %.2f · crescimento base %.0fs → %.1fs · semente %d → %d" % [crop.name,crop.yield,float(crop.yield)*(1+sim.bonus("yield")),crop.time,float(crop.time)*(1-sim.bonus("growth")),crop.seed,sim.seed_cost(selected_crop)])
	var suggestions=[]
	for node in sim.upgrade_defs:
		if sim.upgrade_defs[node].tree==tree and sim.upgrade_status(node)=="Comprar":suggestions.append(node)
	if not suggestions.is_empty():label(modal_body,"Sugestões opcionais: "+", ".join(suggestions.slice(0,3))+". Nenhuma melhoria é exigida pela campanha.")
	label(modal_body,"Bônus: rendimento +%.0f%% (teto60%%) · crescimento −%.0f%% (teto25%%) · venda +%.0f%% · sementes −%.0f%%" % [sim.bonus("yield")*100,sim.bonus("growth")*100,sim.bonus("price")*100,sim.bonus("seed")*100])
	var tool=GameData.TOOLS[sim.state.tool_level]
	label(modal_body,"F%d %s · até %d parcelas · %.2f s/ação" % [sim.state.tool_level,tool.name,sim.tool_area(),sim.tool_interval()],18)
	if sim.state.tool_level<4:
		var next=GameData.TOOLS[sim.state.tool_level+1]
		button(modal_body,"Próxima ferramenta: %s · %d moedas · requer %s" % [next.name,next.cost,next.unlock],func():command(sim.buy_tool());show_upgrades(tree))
	separator(modal_body)
	for id in sim.upgrade_defs:
		var d=sim.upgrade_defs[id]
		if d.tree!=tree: continue
		var rank=sim.rank(id); var status=sim.upgrade_status(id)
		var effect=effect_text(d)
		var group=d.group
		if group in ["yield","growth","seed","price","repair","tool","move"] and rank<d.costs.size():
			var caps={"yield":0.6,"growth":0.25,"seed":0.2,"price":0.15,"repair":0.1,"tool":0.2,"move":0.2}
			effect+="\nBônus atual %.0f%% → %.0f%% após compra" % [sim.bonus(group)*100,minf(caps[group],sim.bonus(group)+float(d.value))*100]
		label(modal_body,"%s · %s · %d/%d\n%s\n%s" % [id,d.name,rank,d.costs.size(),effect,sim.requirement_text(d.requires)],18)
		if rank<d.costs.size(): button(modal_body,"%d %s — %s" % [d.costs[rank],"pontos" if tree=="ESC" else "moedas",status],func():command(sim.buy_upgrade(id));show_upgrades(tree),status!="Comprar")
		else: label(modal_body,"✓ Adquirido no máximo")
		separator(modal_body)
	focus_first()
func effect_text(d: Dictionary) -> String:
	var names={"yield":"Rendimento +","growth":"Crescimento −","tool":"Intervalo da ferramenta −","seed":"Custo de semente −","move":"Movimento +","price":"Venda +","repair":"Moedas de reparo −"}
	if names.has(d.group): return names[d.group]+"%.0f%% por nível; bônus soma respeitando teto global" % (d.value*100)
	var texts={"compost":"Composto rende dois usos","coverage":"Inspeção mostra cobertura do bloco","reserve":"Permite reservas globais adicionais","collector":"Habilita compra de coletor por 600 moedas","collector_speed":"Coleta 5 → 4 → 3 s","seeder":"Habilita compra de semeador por 900 moedas","auto_sell":"Venda de excedentes a cada10s, desligada inicialmente","seeder_speed":"Semeadura 5 → 4 → 3 s","offline":"Até30min offline a25% da velocidade ativa","copy":"Copia opções para blocos livres sem comprar máquinas","evidence":"Amplia contorno de evidências","hint":"Mostra requisito faltante no caderno","group":"Agrupa pistas por tema","captions":"Legendas de memória persistentes","minimap":"Marca destino de pista no mapa","pattern_select":"Seleciona semente indicada; semeadura continua paga","harmony":"Padrão completo rende +15% neste lote","replay":"Rever memórias já vistas","final_path":"Destaca canal do último registro","epilogue":"Epílogo comentado depois de P8"}
	return texts.get(d.group,d.name)
func show_block(bid: String) -> void:
	open_modal(bid+" — "+GameData.BLOCKS[bid].name,"block"); modal_context=bid
	if not sim.block_unlocked(bid): label(modal_body,"Requer "+GameData.BLOCKS[bid].unlock); return
	var b=sim.state.blocks[bid]
	for p in sim.block_plots(bid): label(modal_body,"%s · %s · %s%s" % [p.position,GameData.item_name(p.crop) if not str(p.crop).is_empty() else "Vazio",state_name(p.state)," · %.0f s" % p.remaining if p.state=="growing" else ""])
	var crops=OptionButton.new(); crops.custom_minimum_size.y=40*preferences.ui_scale
	var ids=[]
	for id in GameData.CROPS:
		if sim.crop_unlocked(id): ids.append(id); crops.add_item(GameData.CROPS[id].name)
	crops.selected=ids.find(b.preferred_crop); modal_body.add_child(crops)
	crops.item_selected.connect(func(i):command(sim.configure_block(bid,{"preferred_crop":ids[i]})))
	label(modal_body,"Cultura preferida altera só o próximo plantio. Reserva mínima de sementes: %d moedas para toda a fazenda." % sim.seed_reserve())
	check(modal_body,"Pausar todas as máquinas deste bloco",b.paused,func(v):command(sim.configure_block(bid,{"paused":v})))
	for kind in GameData.MACHINE_COSTS:
		var m=b.machines[kind]
		if m.owned:
			check(modal_body,GameData.MACHINE_NAMES[kind]+" · "+m.status,m.enabled,func(v):command(sim.configure_block(bid,{kind:v})))
			var r=row(modal_body)
			for other in GameData.BLOCKS:
				if other!=bid and sim.block_unlocked(other) and not sim.state.blocks[other].machines[kind].owned:
					button(r,"Mover para "+other,func():command(sim.transfer_machine(bid,other,kind));show_block(bid))
		else: button(modal_body,"Instalar %s · %d moedas · requer %s" % [GameData.MACHINE_NAMES[kind],GameData.MACHINE_COSTS[kind],GameData.MACHINE_UNLOCKS[kind]],func():command(sim.install_machine(bid,kind));show_block(bid))
	separator(modal_body)
	label(modal_body,"Padrões: A topo; B direita; C esquerda; D baixo. Semeador espera, coletor aguarda maturação conjunta; água continua.")
	for pid in GameData.PATTERNS:
		var d=GameData.PATTERNS[pid]
		if bid in d.blocks and sim.has(d.unlock):
			label(modal_body,pattern_text(pid))
			button(modal_body,"Armar "+pid,func():command(sim.arm_pattern(bid,pid));show_block(bid))
	if not str(b.armed_pattern).is_empty(): button(modal_body,"Desarmar sem remover plantas",func():command(sim.arm_pattern(bid,""));show_block(bid))
	button(modal_body,"Aplicar composto · −10% neste lote, teto25%",func():command(sim.apply_compost(bid));show_block(bid))
	if sim.has("ENG2"):
		label(modal_body,"Reserva de produção GLOBAL — protege toda a fazenda")
		for id in GameData.CROPS:
			if not sim.crop_unlocked(id): continue
			var r=row(modal_body); label(r,GameData.CROPS[id].name)
			var spinner=SpinBox.new(); spinner.min_value=0; spinner.max_value=99999; spinner.value=sim.state.manual_reserves.get(id,0); spinner.custom_minimum_size=Vector2(180,40); r.add_child(spinner)
			spinner.value_changed.connect(func(v):command(sim.set_reserve(id,int(v))))
		var r=row(modal_body); label(r,"Moedas de reserva GLOBAL (piso automático preservado)")
		var spinner=SpinBox.new(); spinner.min_value=0; spinner.max_value=99999; spinner.value=sim.state.seed_reserve; r.add_child(spinner)
		spinner.value_changed.connect(func(v):command(sim.configure_block(bid,{"seed_reserve":int(v)})))
	if sim.has("ENG6"): check(modal_body,"Venda automática global · excedentes a cada10s",sim.state.auto_sell,func(v):sim.state.auto_sell=v;save_game())
	if sim.has("ENG10"): button(modal_body,"Copiar opções aos demais blocos",func():command(sim.copy_block(bid)))
	button(modal_body,"Limpar plantio (confirmação)",func():confirm_clear(bid))
	focus_first()
func confirm_clear(bid: String) -> void:
	var lost=0
	for p in sim.block_plots(bid):
		if not str(p.crop).is_empty(): lost+=sim.seed_cost(p.crop)
	open_modal("Remover plantas de "+bid+"?","clear")
	label(modal_body,"O custo perdido é de aproximadamente %d moedas em sementes. Não há reembolso. Restos fracionários serão preservados." % lost)
	button(modal_body,"Confirmar remoção",func():command(sim.clear_block(bid,true));show_block(bid))
	button(modal_body,"Cancelar",func():show_block(bid))
func show_repair(id: String) -> void:
	if not GameData.REPAIRS.has(id): show_journal();return
	var d=GameData.REPAIRS[id]
	open_modal(id+" — "+d.name,"repair"); modal_context=id
	label(modal_body,"Resultado: "+d.result,22)
	var comparison=row(modal_body)
	var keys={"R1":["horta_locked","horta_open"],"R2":["channel_damaged","channel_restored"],"R3":["workshop_damaged","workshop_restored"],"R4":["bridge_damaged","bridge_restored"],"R5":["field_locked","field_open"],"R6":["cistern_damaged","cistern_restored"]}[id]
	for i in range(2):
		var column=box(comparison);column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label(column,"Antes" if i==0 else "Depois",18)
		var path=world.asset_path(keys[i])
		if ResourceLoader.exists(path):
			var image=TextureRect.new();image.texture=load(path);image.custom_minimum_size=Vector2(192,176);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;column.add_child(image)
	label(modal_body,"A instalação recupera sua função sem deslocar corredores ou canteiros.")
	label(modal_body,"%d moedas · disponível %d" % [sim.repair_cost(id),sim.coins()])
	for item in d.items: label(modal_body,"%s: %d / %d · reservado %d" % [GameData.item_name(item),sim.state.inventory.get(item,0),d.items[item],sim.state.reserves.get(item,0)])
	label(modal_body,sim.repair_status(id))
	button(modal_body,"Fixar objetivo e reservar requisitos",func():sim.set_objective(id);save_game();show_repair(id))
	button(modal_body,"Restaurar",func():
		var result=sim.repair(id)
		command(result)
		if result.ok: show_memory("repair",result.message,3.0)
		else: show_repair(id),sim.repair_status(id)!="Pronto para restaurar")
	focus_first()
func show_sale() -> void:
	open_modal("Caixa de venda — produção e reservas","sale")
	label(modal_body,"%d moedas. Excedentes preservam o objetivo fixado e as reservas globais. Quantidades escolhidas respeitam reservas." % sim.coins())
	button(modal_body,"Vender todos os excedentes",func():command(sim.sell_excess());show_sale())
	for id in sim.state.inventory:
		if sim.item_price(id)<=0: continue
		var total=int(sim.state.inventory[id]); var reserved=int(sim.state.reserves.get(id,0)); var excess=maxi(0,total-reserved)
		var r=row(modal_body); label(r,"%s · %d total · %d reservado · %d excedente\nVenda: %.2f moedas/unidade" % [GameData.item_name(id),total,reserved,excess,sim.item_price(id)*(1+sim.bonus("price"))])
		var spin=SpinBox.new();spin.min_value=0;spin.max_value=excess;spin.value=excess;spin.custom_minimum_size.x=110;r.add_child(spin)
		button(r,"Vender",func():command(sim.sell(id,int(spin.value)));show_sale(),excess==0)
	separator(modal_body)
	label(modal_body,"Comprar materiais (também disponíveis por coleta/fabricação gratuita)",20)
	for id in ["wood","stone","fiber"]:
		var r=row(modal_body); label(r,"%s · %d moedas/unidade" % [GameData.item_name(id),GameData.ITEMS[id].buy])
		var spin=SpinBox.new();spin.min_value=1;spin.max_value=99;spin.value=1;r.add_child(spin)
		button(r,"Comprar",func():command(sim.buy_material(id,int(spin.value)));show_sale())
	focus_first()
func show_workshop() -> void:
	open_modal("Oficina — materiais, cuidado e aparência","workshop")
	label(modal_body,"Fabricação em lote é instantânea. Linho vira fibra; composto ajuda o próximo lote de um bloco.")
	var recipes={"REC1":"6 linhos → 3 fibras · requer R3","REC2":"8 nabos + 4 feijões → %d usos de composto · requer R3" % (2 if sim.has("CUL7") else 1)}
	for id in recipes:
		var r=row(modal_body); label(r,recipes[id]);var spin=SpinBox.new();spin.min_value=1;spin.max_value=99;spin.value=1;r.add_child(spin)
		button(r,"Fabricar",func():command(sim.craft(id,int(spin.value)));show_workshop())
	for bid in GameData.BLOCKS:
		if sim.block_unlocked(bid): button(modal_body,"Placa de cultura em %s · 20 moedas · apenas visual" % bid,func():command(sim.craft("REC3",1,bid));show_workshop(),sim.state.blocks[bid].label)
	separator(modal_body); label(modal_body,"Decoração — posições fixas, sem bloquear passagem",20)
	for id in GameData.DECO: button(modal_body,GameData.DECO[id]+" · 200 moedas · requer R3",func():command(sim.buy_decoration(id));show_workshop(),sim.state.deco.has(id))
	focus_first()
func pattern_text(id: String) -> String:
	var d=GameData.PATTERNS[id]; var p=[]
	for i in range(4): p.append(GameData.POSITIONS[i]+": "+GameData.item_name(d.recipe[i]))
	return id+" · "+d.name+"\n"+" | ".join(p)+"\nBlocos: "+", ".join(d.blocks)
func clue_condition(id: String) -> String:
	return {"P1":"Colha pela primeira vez; examine a casa","P2":"Conclua R1; examine as tábuas no canal seco","P3":"R2 + PA1 em B1/B2; Tab para inspecionar o sinal","P4":"R3 + PA2 em B3/B4; inspecione o sinal","P5":"R4; examine caixa na ponte","P6":"R4 + P5 + PA3 em B5; inspecione o reflexo","P7":"R5; examine o armário da cisterna","P8":"R6 + PA3 em B6; colha o lote e acione I → II → III"}[id]
func show_journal(selection: String = "") -> void:
	open_modal("Caderno — pistas, padrões e caminhos","journal")
	label(modal_body,"%d/8 evidências · %d pontos de Escuta. Pistas não exigem melhorias da árvore." % [sim.state.clues.size(),sim.state.listen_points])
	var r=row(modal_body)
	button(r,"Evidências",func():show_journal())
	button(r,"Padrões",func():show_journal("patterns"))
	button(r,"Mapa e destinos",func():show_journal("map"))
	button(r,"Tutorial e histórico",func():show_journal("history"))
	if selection=="patterns":
		for id in GameData.PATTERNS:
			var d=GameData.PATTERNS[id]
			if sim.has(d.unlock): label(modal_body,pattern_text(id),20)
			else: label(modal_body,id+" · disponível após "+d.unlock)
		label(modal_body,"Arme no painel do bloco. Não colha antes de as quatro plantas amadurecerem juntas. O sinal permanece após a colheita automática.")
	elif selection=="map":
		label(modal_body,"Mapa 48×48 · norte↑ (isométrico). WASD desloca em relação à tela. Arrasto do meio: pan; roda: zoom inteiro; Home: recentralizar.")
		for bid in GameData.BLOCKS:
			var d=GameData.BLOCKS[bid];button(modal_body,"%s — %s · (%d,%d) · %s" % [bid,d.name,d.origin[0],d.origin[1],"aberto" if sim.block_unlocked(bid) else "requer "+d.unlock],func():world.camera_tile=Vector2(d.origin[0],d.origin[1]);close_modal())
		for repair in GameData.REPAIRS: button(modal_body,"Fixar "+repair+" · "+GameData.REPAIRS[repair].name,func():sim.set_objective(repair);save_game();show_journal("map"))
	elif selection=="history":
		label(modal_body,"Mover: WASD/setas. Ferramenta: botão esquerdo segurado, a até1tile. Vazio: semear; gota: irrigar; ✓: colher. Plantas maduras não estragam. E interage. Tab inspeção. U melhorias. J caderno. Esc pausa.\n\nReserve materiais para o objetivo; venda excedentes. Se faltar tudo, nabo de emergência gratuito; pilhas de madeira/pedra nunca esgotam.")
		for entry in sim.state.history: label(modal_body,str(entry.get("id",""))+"\n"+str(entry.get("text","")))
	else:
		var ids=GameData.CLUES.keys()
		var headings={}
		if sim.has("ESC3"):
			ids=["P2","P3","P6","P8","P1","P5","P7","P4"]
			headings={"P2":"Água","P1":"Ausência","P4":"Máquinas"}
		for id in ids:
			if headings.has(id):label(modal_body,headings[id],22)
			if sim.has(id):
				button(modal_body,"✓ "+id+" · "+GameData.CLUES[id].name,func():show_clue_page(id))
			else:
				label(modal_body,id+" — ainda não encontrada\n"+clue_condition(id))
				if sim.has("ESC2"):label(modal_body,"Anotar — "+clue_missing(id))
		for id in GameData.REPAIRS:
			if not sim.has(id): label(modal_body,id+" · "+sim.repair_status(id));break
		if sim.has("ESC10") and sim.state.final_completed: label(modal_body,"Epílogo: guardar um registro não significa viver dentro dele. A fazenda restaurada acolhe novas lembranças.",20)
	focus_first()
func clue_missing(id: String) -> String:
	var requirements={"P1":[],"P2":["R1"],"P3":["R2"],"P4":["R3"],"P5":["R4"],"P6":["R4","P5"],"P7":["R5"],"P8":["R6"]}
	var req=sim.requirement_text(requirements[id])
	if not req.is_empty():return req
	if id=="P1" and not sim.state.tutorial.first_harvest:return "Faça uma primeira colheita madura em B1"
	var pattern={"P3":"PA1","P4":"PA2","P6":"PA3"}.get(id,"")
	if not pattern.is_empty() and not sim.state.pending_signals.has(id):return "Complete "+pattern+" com quatro plantas maduras na receita do caderno"
	if id=="P8" and not sim.state.final_ready:return "Prepare e colha PA3 em B6"
	if id=="P8":return "Acione I → II → III; todas as sete pistas anteriores devem estar registradas"
	return "Evidência disponível: ative Tab e examine a estação ou sinal marcado"
func story_label(parent: Node, text: String, size: int = 20) -> Label:
	var line=label(parent,text,size)
	if not preferences.instant_text:line.visible_characters=0;reveal_labels.append(line)
	return line
func show_clue_page(id: String) -> void:
	open_modal(id+" — "+GameData.CLUES[id].name,"clue")
	var target_blocks={"P1":"B1","P2":"B2","P3":"B1","P4":"B3","P5":"B5","P6":"B5","P7":"B6","P8":"B6"}
	var origin=GameData.BLOCKS[target_blocks[id]].origin;destination_tile=Vector2(origin[0],origin[1])
	var path=world.asset_path("key_"+id)
	if ResourceLoader.exists(path):
		var image=TextureRect.new();image.texture=load(path);image.custom_minimum_size=Vector2(256,144);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;modal_body.add_child(image)
	story_label(modal_body,GameData.CLUES[id].text,20)
	if sim.has("ESC8") and id in ["P3","P6","P8"]: button(modal_body,"Rever memória (sem nova recompensa)",func():show_memory(id,GameData.CLUES[id].text,memory_duration(id)))
	button(modal_body,"Voltar ao caderno",func():show_journal())
	focus_first()
func show_dialog(name: String, text: String) -> void:
	open_modal(name,"dialog")
	var content=row(modal_body)
	var portrait_id="portrait_"+name if name in ["Lia","Rui"] else "portrait_Tomas"
	var path=world.asset_path(portrait_id)
	if ResourceLoader.exists(path):
		var atlas=AtlasTexture.new();atlas.atlas=load(path);atlas.region=Rect2(0,0,80,80)
		var portrait=TextureRect.new();portrait.texture=atlas;portrait.custom_minimum_size=Vector2(80,80)*preferences.ui_scale;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;content.add_child(portrait)
	story_label(content,text,20);button(modal_body,"Entendido · continuar",func():close_modal());focus_first()
func memory_duration(id: String) -> float:
	return {"P3":12.0,"P6":15.0,"P8":20.0}.get(id,0.0)
func show_memory(id: String, text: String, duration: float) -> void:
	open_modal("A água conserva gestos" if id!="repair" else "A fazenda se recupera","memory")
	mode="MEMORY"; memory_camera_before=world.camera_tile;world.memory_id=id;world.memory_progress=0.0;memory_clock=0;memory_limit=duration
	if id=="P3":world.camera_tile=Vector2(14,32)
	elif id=="P6":world.camera_tile=Vector2(8,17)
	elif id=="P8":world.camera_tile=Vector2(40,12)
	if id in ["P3","P6","P8"]:play_specific_audio({"P3":"memory_canal","P6":"memory_reflection","P8":"memory_final"}[id])
	# Memory remains in the actual world; a compact caption panel never covers the gesture.
	modal.offset_top=ui.get_viewport_rect().size.y*0.60;modal.offset_bottom=-24
	var heading=modal.find_children("*","Label",true,false)
	if not heading.is_empty():heading[0].add_theme_font_size_override("font_size",18)
	var line=story_label(modal_body,text,18)
	label(modal_body,"Legendas completas · cultivo pausado · pode pular",14)
	label(modal_body,"A simulação está pausada. Legenda completa; pular preserva o registro e a recompensa.")
	button(modal_body,"Pular / continuar",func():finish_memory(id))
	focus_first()
func finish_memory(id: String) -> void:
	world.memory_id=""
	if id!="material":world.camera_tile=memory_camera_before
	if id=="P8": show_ending()
	elif id=="material":command(sim.collect_material(material_target,2.0));close_modal()
	else: close_modal()
func examine_clue(id: String) -> void:
	if not inspection: toast("Tab: ative inspeção para examinar a evidência");return
	var r=sim.inspect_clue(id);command(r)
	if r.ok:
		if id in ["P3","P6","P8"]: show_memory(id,r.message,memory_duration(id))
		else: show_dialog(id+" · "+GameData.CLUES[id].name,r.message)
func show_offline() -> void:
	open_modal("Enquanto você esteve fora","offline")
	var d=sim.state.last_offline_summary
	label(modal_body,"%.0f minutos reais computados · %.0f segundos de produção\n25%% da velocidade ativa; até30min reais. Intervalo consumido uma única vez." % [d.get("real_seconds",0)/60.0,d.get("computed_seconds",0)])
	for id in d.get("produced",{}): label(modal_body,"+%d %s" % [d.produced[id],GameData.item_name(id)])
	label(modal_body,"Moedas de venda: %.2f" % (d.get("sales_cents",d.get("coins_cents",0))/100.0))
	button(modal_body,"Continuar cultivando",func():close_modal())
func show_ending() -> void:
	open_modal("Fazenda Entre Ecos — um novo dia","ending")
	label(modal_body,GameData.CLUES.P8.text,22)
	label(modal_body,"Campanha concluída. A propriedade, suas melhorias, coleção e culturas permanecem.\n\nCréditos: design baseado nos documentos Fazenda Entre Ecos; programação Godot/GDScript; arte e áudio autorais produzidos pelo projeto local North Asset Forge 2D. Fonte DejaVu Sans, licença em ui_theme. Assets: licença em assets/LICENSE.txt.")
	button(modal_body,"Continuar cultivando",func():close_modal())
	button(modal_body,"Caderno e epílogo",func():show_journal())
	save_game();update_music()
func show_options(origin: String = "") -> void:
	var was_title=mode=="TITLE" or origin=="title"
	open_modal("Opções e acessibilidade","options");modal_context="title" if was_title else "pause"
	label(modal_body,"As opções são independentes dos slots. Sem som ou sem animação, todas as informações essenciais permanecem em texto e símbolos.")
	if preferences.has("recovery_notice"):label(modal_body,preferences.recovery_notice)
	for key in ["ui_scale","text_scale"]:
		var r=row(modal_body);label(r,"Tamanho da interface" if key=="ui_scale" else "Tamanho do texto")
		for value in [1.0,1.25,1.5]: button(r,"%d%%" % (value*100),func():preferences[key]=value;store.save_preferences(preferences);apply_preferences();build_hud();show_options("title" if was_title else "pause"))
	var labels={"high_contrast":"Contraste alto","reduced_motion":"Movimentos reduzidos","reduced_particles":"Partículas reduzidas","instant_text":"Texto instantâneo","fish_assist":"Recolha assistida na pesca","toggle_action":"Toque alterna ferramenta contínua","captions":"Legendas de sons importantes","tutorial":"Mostrar dicas do tutorial"}
	for key in labels: check(modal_body,labels[key],preferences[key],func(v):preferences[key]=v;store.save_preferences(preferences);apply_preferences())
	check(modal_body,"Progresso offline (após ENG9)",preferences.get("offline_enabled",true) if was_title else sim.state.offline_enabled,func(v):
		preferences.offline_enabled=v;store.save_preferences(preferences)
		if not was_title:sim.state.offline_enabled=v;save_game())
	for key in ["music_volume","ambience_volume","interface_volume"]:
		var r=row(modal_body);label(r,{"music_volume":"Música","ambience_volume":"Ambiente","interface_volume":"Interface e ações"}[key]);var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.value=preferences[key];slider.custom_minimum_size.x=300;r.add_child(slider)
		slider.value_changed.connect(func(v):preferences[key]=v;store.save_preferences(preferences);apply_preferences())
	var speed_row=row(modal_body);label(speed_row,"Velocidade de texto (caracteres/s)")
	var text_speed=HSlider.new();text_speed.min_value=20;text_speed.max_value=100;text_speed.step=10;text_speed.value=preferences.get("text_speed",50);text_speed.custom_minimum_size.x=300;speed_row.add_child(text_speed)
	text_speed.value_changed.connect(func(v):preferences.text_speed=v;store.save_preferences(preferences))
	var shirt_row=row(modal_body);label(shirt_row,"Camisa (não altera colisão)")
	for color in ["default","ochre","blue"]:button(shirt_row,{"default":"Verde","ochre":"Ocre","blue":"Azul"}[color],func():preferences.shirt=color;store.save_preferences(preferences);apply_preferences())
	separator(modal_body);label(modal_body,"Remapear todas as ações — selecione e pressione tecla ou botão do mouse. Esc cancela captura.",20)
	for action in actions:
		var r=row(modal_body);label(r,action_names.get(action,"Cultura "+action.trim_prefix("culture_")))
		var binding=preferences.bindings.get(action,actions[action]);var code=int(binding[0]);var text=OS.get_keycode_string(code) if code>0 else "Mouse "+str(-code)
		button(r,text,func():remap_action=action;label(modal_body,"Pressione a entrada para "+action_names.get(action,action)))
	button(modal_body,"Restaurar controles padrão",func():preferences.bindings={};setup_input();store.save_preferences(preferences);show_options("title" if was_title else "pause"))
	button(modal_body,"Voltar",func():
		if was_title: mode="TITLE";show_title()
		else: show_pause())
	focus_first()
func begin_fishing() -> void:
	if not sim.has("R4"):toast("Recupere a ponte R4");return
	open_modal("Pesca — o lago não tem pressa","fishing"); mode="FISHING";fishing_clock=0
	label(modal_body,"Espere6s. Depois recolha em até2s. Falhar não tem custo e não avança a coleção.")
	label(modal_body,"Aguardando a água…",24).name="FishingStatus"
	button(modal_body,"Recolher · E / botão esquerdo",func():reel_fish())
	button(modal_body,"Cancelar sem penalidade",func():close_modal())
func reel_fish() -> void:
	if mode!="FISHING":return
	if fishing_clock>=6 and fishing_clock<=8:
		var r=sim.catch_fish();command(r);mode="MODAL";label(modal_body,r.message,24);button(modal_body,"Pescar novamente",func():begin_fishing());button(modal_body,"Voltar à fazenda",func():close_modal())
	else:
		mode="MODAL";label(modal_body,"A tentativa terminou sem custo. Você pode tentar novamente.");button(modal_body,"Tentar outra vez",func():begin_fishing())
func toast(text: String) -> void:
	if text.is_empty():return
	toast_label.text=text;toast_clock=5
	if modal!=null and mode in ["MODAL","TITLE"] and not text in ["Salvo"]:label(modal_body,text)
func command(result: Dictionary) -> void:
	if not result.ok:play_specific_audio("ui_unavailable")
	toast(result.message)
	if result.ok:save_game()
func save_game() -> Dictionary:
	var now=int(Time.get_unix_time_from_system())
	sim.state.offline_reference=now
	var result=store.save_slot(current_slot,sim.export_state())
	if result.ok:sim.state.last_saved_at=now
	else:toast(result.message)
	return result
func state_name(id: String) -> String:
	return {"locked":"Bloqueado","empty":"Vazio","water":"Irrigar ◇","growing":"Crescendo","mature":"Colher ✓"}.get(id,id)
func select_crop(id: String) -> void:
	if not sim.crop_unlocked(id):toast("Requer "+GameData.CROPS[id].unlock);return
	selected_crop=id;world.selected_crop=id;refresh_hud()
func toggle_inspection() -> void:
	if mode!="FARM":return
	inspection=not inspection;world.inspected=inspection;action_held=false;refresh_hud()
func refresh_hud() -> void:
	if coins_label==null:return
	var inventory=[]
	for item in GameData.CROPS:
		if sim.state.inventory[item]>0:inventory.append("%s %d" % [GameData.item_name(item),sim.state.inventory[item]])
	coins_label.text="%d moedas · Escuta %d\n%s" % [sim.coins(),sim.state.listen_points," | ".join(inventory.slice(0,2)) if not inventory.is_empty() else "Sua primeira colheita começa em B1"]
	var id=sim.state.objective
	objective_label.text="Objetivo: "+id+"\n"+(GameData.REPAIRS[id].name+"\n"+sim.repair_status(id) if GameData.REPAIRS.has(id) else "Último lote B6 · I → II → III")
	if sim.state.tutorial.first_harvest and not sim.has("P1"):objective_label.text="P1 · Bilhete de chegada\nVisite a casa. Tab: inspeção; E: examinar."
	if minimap!=null:
		minimap.visible=sim.has("ESC5") and preferences.get("minimap_visible",true)
		map_toggle.visible=sim.has("ESC5");map_toggle.text="Recolher mapa" if minimap.visible else "Mostrar mapa"
		minimap.configure(sim,world.player_tile,destination_tile)
	memory_captions.text=audio_caption if preferences.captions and audio_caption_clock>0 else ""
	if sim.has("ESC4"):
		for clue in sim.state.pending_signals:
			var bid=sim.state.pending_signals[clue];var o=GameData.BLOCKS[bid].origin;var vector=world.iso(Vector2(o[0],o[1]))-world.iso(world.player_tile)
			var horizontal="direita" if vector.x>20 else ("esquerda" if vector.x< -20 else "centro")
			var vertical="acima" if vector.y< -20 else ("abaixo" if vector.y>20 else "próximo")
			memory_captions.text="Eco registrado em %s · %s, %s" % [bid,horizontal,vertical];break
	for crop in culture_buttons:
		culture_buttons[crop].disabled=not sim.crop_unlocked(crop)
		culture_buttons[crop].text=("▶ " if crop==selected_crop else "")+crop.substr(1)+" · "+GameData.CROPS[crop].name
	world.inspected=inspection
func _simulation_changed(reason: String) -> void:
	if reason in ["purchase","clue","config"] and mode!="TITLE":save_game()
func _on_reward(kind: String, item: String, quantity: int, block: String) -> void:
	if world==null:return
	var pos=world.player_tile
	if GameData.BLOCKS.has(block):var o=GameData.BLOCKS[block].origin;pos=Vector2(o[0]+0.5,o[1]+0.5)
	if kind in ["seed","water","harvest"]:
		if not manual_action and world.player_tile.distance_to(pos)>6.0:return
		if manual_action and not world.target_plot.is_empty():
			var direction=world.iso(GameData.plot_tile(world.target_plot))-world.iso(world.player_tile)
			if direction.length_squared()>0.1:world.facing=int(round(fposmod(direction.angle()-PI/2,TAU)/(PI/4)))%8
		if manual_action:
			world.animation=kind;world.action_duration=minf(0.5,sim.tool_interval()*0.8);world.action_time=world.action_duration
			var target=GameData.plot_tile(world.target_plot) if not world.target_plot.is_empty() else pos
			world.action_effects.append({"tile":target,"kind":kind,"life":0.3,"duration":0.3})
		if kind=="harvest":
			if world.effects.size()>=4:world.effects.pop_front()
			world.effects.append({"tile":pos,"text":"+%d %s" % [quantity,GameData.item_name(item)],"life":1.5})
	if preferences.captions:
		audio_caption={"seed":"Som: terra sendo preparada","water":"Som: irrigação","grow":"Som: cultura pronta","harvest":"Som: colheita","sale":"Som: venda concluída","purchase":"Som: melhoria adquirida","clue":"Som: memória registrada"}.get(kind,"");audio_caption_clock=1.5
	play_audio(kind)
func play_audio(kind: String) -> void:
	if DisplayServer.get_name()=="headless" or AudioServer.get_driver_name()=="Dummy":return
	var map={"seed":"seed","water":"water","grow":"grow","harvest":"harvest","sale":"sale","purchase":"purchase","clue":"memory_1","repair":"purchase"}
	var name="sfx_"+map.get(kind,"purchase")
	if kind=="clue":name="memory_canal"
	play_specific_audio(name)
func play_specific_audio(name: String) -> void:
	if world==null or DisplayServer.get_name()=="headless" or AudioServer.get_driver_name()=="Dummy":return
	var path=world.asset_path(name)
	if not ResourceLoader.exists(path):return
	if not audio_players.has(name):var p=AudioStreamPlayer.new();p.stream=load(path);p.volume_db=linear_to_db(maxf(0.0001,float(preferences.interface_volume)))-12;add_child(p);audio_players[name]=p
	var now=Time.get_ticks_msec()
	if now-int(last_reward_time.get(name,0))<100:return
	last_reward_time[name]=now;audio_players[name].play()
func update_music() -> void:
	if DisplayServer.get_name()=="headless" or AudioServer.get_driver_name()=="Dummy":return
	var track="music_ending" if sim.state.final_completed else ("music_restoring" if sim.has("R2") else "music_arrival")
	if track==last_music:return
	var path=world.asset_path(track)
	if not ResourceLoader.exists(path):return
	for p in music_players:p.stop();p.queue_free()
	music_players=[]
	var p=AudioStreamPlayer.new();p.stream=load(path);p.volume_db=-60;add_child(p);p.finished.connect(func():p.play());p.play();music_players.append(p)
	var tween=create_tween();tween.tween_property(p,"volume_db",linear_to_db(maxf(0.0001,float(preferences.music_volume)))-18,2.0);last_music=track
	if ambience_players.is_empty():
		for name in ["ambient_wind","ambient_birds","ambient_water"]:
			var a_path=world.asset_path(name)
			if ResourceLoader.exists(a_path):var a=AudioStreamPlayer.new();a.stream=load(a_path);a.volume_db=linear_to_db(maxf(0.0001,float(preferences.ambience_volume)))-24;add_child(a);a.finished.connect(func():a.play());a.play();ambience_players.append(a)
func update_machine_audio() -> void:
	if DisplayServer.get_name()=="headless" or AudioServer.get_driver_name()=="Dummy":return
	for kind in GameData.MACHINE_COSTS:
		var audible=false
		for bid in GameData.BLOCKS:
			var b=sim.state.blocks[bid];var m=b.machines[kind]
			var o=GameData.BLOCKS[bid].origin
			if m.owned and m.enabled and not b.paused and world.player_tile.distance_to(Vector2(o[0],o[1]))<6.0:audible=true
		var id="machine_"+kind+"_loop"
		var path=world.asset_path(id)
		if not machine_players.has(kind) and ResourceLoader.exists(path):
			var player=AudioStreamPlayer.new();player.stream=load(path);player.volume_db=linear_to_db(maxf(0.0001,float(preferences.ambience_volume)))-27;add_child(player);machine_players[kind]=player
		if machine_players.has(kind):
			var player=machine_players[kind]
			if audible and not player.playing:player.play()
			elif not audible:player.stop()
func _process(dt: float) -> void:
	if has_focus and mode in ["MODAL","MEMORY"] and not preferences.instant_text:
		reveal_clock+=dt*float(preferences.get("text_speed",50))
		for line in reveal_labels:
			if is_instance_valid(line):line.visible_characters=int(reveal_clock)
	audio_caption_clock=maxf(0,audio_caption_clock-dt)
	if toast_clock>0:toast_clock-=dt
	else:toast_label.text=""
	if not has_focus:return
	if mode=="FARM":
		if not preferences.toggle_action and not Input.is_action_pressed("tool"):action_held=false
		sim.paused=false
		var direction=Input.get_vector("move_left","move_right","move_up","move_down")
		world.move_player(direction,dt)
		var offset=world.iso(world.player_tile)-world.iso(world.camera_tile)
		var vertical_limit=50.0 if float(preferences.ui_scale)>=1.5 and ui.get_viewport_rect().size.y<=720 else 70.0
		if absf(offset.x)>130 or absf(offset.y)>vertical_limit:world.camera_tile=world.camera_tile.lerp(world.player_tile,minf(1,dt*5))
		sim.advance(dt)
		action_clock=maxf(0,action_clock-dt)
		var pos=(ui.get_global_mouse_position()-world_container.position)/world_container.stretch_shrink
		update_target(pos)
		if action_held and action_clock<=0:execute_tool();action_clock=sim.tool_interval()
		autosave_clock+=dt
		if autosave_clock>=30:save_game();autosave_clock=0
		refresh_clock+=dt
		if refresh_clock>=0.2:refresh_clock=0;refresh_hud();update_prompt();update_machine_audio();update_music()
	elif mode=="FISHING":
		fishing_clock+=dt
		var status=modal.find_child("FishingStatus",true,false) if modal!=null else null
		if status!=null:status.text="Recolha agora! E / botão esquerdo" if fishing_clock>=6 else "Aguardando… %.1f s" % (6-fishing_clock)
		if preferences.fish_assist and fishing_clock>=6:reel_fish()
		elif fishing_clock>8:reel_fish()
	elif mode=="MEMORY":
		memory_clock+=dt
		world.memory_progress=clampf(memory_clock/maxf(0.001,memory_limit),0,1)
		if memory_clock>=memory_limit:finish_memory(world.memory_id)
func update_target(pixel: Vector2) -> void:
	var tile=world.screen_to_tile(pixel)
	world.target_plot="";world.preview_plots=[]
	for p in sim.state.plots:
		var pos=GameData.plot_tile(p.id)
		var d=tile-pos
		if absf(d.x)<=0.5 and absf(d.y)<=0.5:
			world.target_plot=p.id
			if not inspection:
				var candidates=sim.block_plots(p.block).filter(func(q):return q.state==p.state)
				candidates.sort_custom(func(a,b):return GameData.plot_tile(a.id).distance_squared_to(pos)<GameData.plot_tile(b.id).distance_squared_to(pos))
				for c in candidates.slice(0,sim.tool_area()):world.preview_plots.append(c.id)
			return
func update_prompt() -> void:
	position_prompt()
	var station=world.nearest_station()
	if not station.is_empty():prompt_label.text="E — "+station.name+"\n"+("INSPEÇÃO · Tab para cultivar" if inspection else "Cultivo · Tab para inspecionar");return
	if not world.target_plot.is_empty():
		var p=sim.plot(world.target_plot)
		if world.player_tile.distance_to(GameData.plot_tile(p.id))>1.0:prompt_label.text="Aproxime-se: alcance1tile";return
		if inspection:prompt_label.text=p.block+" · "+p.position+" · "+state_name(p.state);return
		if p.state=="empty":
			var crop=sim.suggested_crop(p.id,selected_crop);var n=world.preview_plots.size();var affordable=min(n,sim.coins()/sim.seed_cost(crop))
			if crop=="C1" and sim.emergency_allowed():prompt_label.text="Semear um nabo de emergência · gratuito\nDepois, irrigue e colha para recomeçar"
			else:prompt_label.text="Semear %s · %d/%d · custo %d\nSaldo depois %d · reserva %d" % [GameData.item_name(crop),affordable,n,affordable*sim.seed_cost(crop),sim.coins()-affordable*sim.seed_cost(crop),sim.seed_reserve()]
		elif p.state=="growing":prompt_label.text="Crescendo: %.0f s · não gasta recursos" % p.remaining
		else:prompt_label.text=state_name(p.state)+" · segure para agir"
	else:prompt_label.text=("INSPEÇÃO · Tab para cultivar" if inspection else "WASD mover · alcance1tile · segure botão esquerdo") if preferences.tutorial else ("Inspeção" if inspection else "Cultivo")
func position_prompt() -> void:
	var viewport_size=ui.get_viewport_rect().size
	var bottom_top=viewport_size.y-(140 if float(preferences.ui_scale)<1.5 else 240)
	var candidates=[Vector2((viewport_size.x-550)/2,bottom_top-85),Vector2(32,bottom_top-85),Vector2(viewport_size.x-582,bottom_top-85),Vector2((viewport_size.x-550)/2,190)]
	var protect=[]
	if minimap!=null and minimap.visible:protect.append(Rect2(minimap.position,minimap.size))
	var factor=world_container.stretch_shrink
	var player=world.screen(world.player_tile)*factor+world_container.position
	protect.append(Rect2(player-Vector2(20,48)*factor,Vector2(40,56)*factor))
	for plot in sim.state.plots:
		var point=world.screen(GameData.plot_tile(plot.id))*factor+world_container.position
		if point.y>=160 and point.y<=bottom_top:protect.append(Rect2(point-Vector2(26,45)*factor,Vector2(52,60)*factor))
	for candidate in candidates:
		var rect=Rect2(candidate,Vector2(550,60))
		var collision=false
		for protected in protect:
			if rect.intersects(protected):collision=true;break
		if not collision:prompt_label.position=candidate;return
	prompt_label.position=candidates[0]
func execute_tool() -> void:
	if inspection or world.target_plot.is_empty():return
	var primary=sim.plot(world.target_plot)
	if world.player_tile.distance_to(GameData.plot_tile(primary.id))>1.0:toast("Aproxime-se: alcance1tile");return
	var ids=world.preview_plots.duplicate()
	var operation=primary.state
	for id in ids:
		if world.player_tile.distance_to(GameData.plot_tile(id))>1.0:continue
		var result
		manual_action=true
		match operation:
			"empty":result=sim.seed(id,sim.suggested_crop(id,selected_crop))
			"water":result=sim.water(id)
			"mature":result=sim.harvest(id)
			"growing":manual_action=false;return
			_:manual_action=false;toast("Recupere o setor para cultivar");return
		manual_action=false
		if not result.ok:toast(result.message);break
func interact() -> void:
	var st=world.nearest_station()
	if st.is_empty():toast("Aproxime-se de uma placa, NPC ou estação");return
	var id=st.id
	world.animation="interact";world.action_duration=0.3;world.action_time=0.3
	var direction=world.iso(st.tile)-world.iso(world.player_tile)
	if direction.length_squared()>0.1:world.facing=int(round(fposmod(direction.angle()-PI/2,TAU)/(PI/4)))%8
	if GameData.BLOCKS.has(id):show_block(id)
	elif GameData.REPAIRS.has(id):show_repair(id)
	elif GameData.CLUES.has(id):examine_clue(id)
	elif id=="house":
		if sim.clue_available("P1"):examine_clue("P1")
		else:show_dialog("Casa de Tomás","Cultive o que ainda cresce. Depois da primeira colheita, o bilhete estará disponível em inspeção.")
	elif id=="sale":show_sale()
	elif id=="workshop":show_workshop()
	elif id=="well":toast("Água inesgotável. Use a ferramenta diretamente numa planta com gota.")
	elif id in ["wood","stone"]:
		open_modal("Coletando "+GameData.item_name(id),"material");mode="MEMORY";memory_clock=0;memory_limit=2;world.memory_id="material"
		label(modal_body,"Coleta gratuita, uma unidade a cada2s. A pilha nunca esgota.")
		material_target=id
	elif id=="fishing":begin_fishing()
	elif id in ["lia","rui"]:talk_npc(id)
	elif id.begins_with("valve"):
		var r=sim.valve(int(id.substr(6)));command(r)
		if r.ok and sim.state.final_completed:show_memory("P8",GameData.CLUES.P8.text,20)
func talk_npc(id: String) -> void:
	var stage=3 if sim.state.final_completed else (2 if sim.has("R5") else (1 if sim.has("R3") else 0))
	if id=="rui":stage=3 if sim.state.final_completed else (2 if sim.has("R5") else (1 if sim.has("P6") else 0))
	var lines={"lia":["Tomás preparou a cessão da fazenda antes de sair. As instruções estão aqui; eu posso ajudar com materiais pela caixa.","As peças foram guardadas, não roubadas. Ele sempre organizava suas ferramentas por sequência.","O recibo confirma uma viagem. A carta do armário explica por que ele isolou os canais.","Recebi contato recente: Tomás está vivo e se recuperando. Ele agradece por você cuidar da fazenda."],"rui":["Se quiser variar o trabalho, a pesca abre depois da ponte. Nenhuma pista depende de um peixe raro.","A água às vezes repete um gesto. Observe a margem sem confundir reflexo com presença.","Espere6s e recolha nos2s seguintes; a assistência nas opções retira a janela. Falhar não custa nada.","A corrente ficou tranquila. Guarde as histórias e faça outras; o lago continua aberto."]}
	var text=lines[id][stage]
	var history_id=id+"_"+str(stage)
	if not sim.state.history.any(func(e):return e.id==history_id):sim.state.history.append({"id":history_id,"text":text});save_game()
	world.talking_npc=id
	show_dialog("Lia" if id=="lia" else "Rui",text)
func _input(event: InputEvent) -> void:
	if not remap_action.is_empty():
		if event is InputEventKey and event.pressed:
			if event.physical_keycode==KEY_ESCAPE:remap_action="";get_viewport().set_input_as_handled();return
			preferences.bindings[remap_action]=[event.physical_keycode];remap_action="";setup_input();store.save_preferences(preferences);show_options(modal_context);get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:preferences.bindings[remap_action]=[-event.button_index];remap_action="";setup_input();store.save_preferences(preferences);show_options(modal_context);get_viewport().set_input_as_handled()
		return
	if modal!=null and event.is_action_pressed("ui_accept") and not preferences.instant_text:
		var incomplete=false
		for line in reveal_labels:
			if is_instance_valid(line) and line.visible_characters<line.get_total_character_count():line.visible_characters=-1;incomplete=true
		if incomplete:reveal_clock=1000000;get_viewport().set_input_as_handled();return
	if event.is_action_pressed("pause"):
		if mode=="FARM":show_pause()
		elif mode=="TITLE":show_title()
		elif mode=="MEMORY" and world.memory_id!="material":finish_memory(world.memory_id)
		else:close_modal()
		get_viewport().set_input_as_handled();return
	if mode=="FARM" and event.is_action_pressed("inspection"):
		toggle_inspection();get_viewport().set_input_as_handled();return
	# Constrain keyboard focus to the single visible panel.
	if modal!=null and event is InputEventKey and event.pressed and event.physical_keycode==KEY_TAB:
		var focusables=modal.find_children("*","BaseButton",true,false).filter(func(b):return not b.disabled)
		if not focusables.is_empty():
			var current=get_viewport().gui_get_focus_owner();var index=focusables.find(current);var step=-1 if event.shift_pressed else 1;focusables[posmod(index+step,focusables.size())].grab_focus()
		get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if mode=="FISHING":
		if event.is_action_pressed("interact") or event.is_action_pressed("tool"):reel_fish()
		return
	if mode!="FARM":return
	if event.is_action_pressed("interact"):interact()
	elif event.is_action_pressed("inspection"):toggle_inspection()
	elif event.is_action_pressed("upgrades"):show_upgrades("CUL")
	elif event.is_action_pressed("journal"):show_journal()
	elif event.is_action_pressed("home"):world.camera_tile=world.player_tile
	elif event.is_action_pressed("zoom_in"):world.zoom=clampi(world.zoom+1,1,4)
	elif event.is_action_pressed("zoom_out"):world.zoom=clampi(world.zoom-1,1,4)
	elif event.is_action_pressed("tool"):
		if preferences.toggle_action:action_held=not action_held
		else:action_held=true
	elif event.is_action_released("tool") and not preferences.toggle_action:action_held=false
	elif event.is_action_pressed("pan"):panning=true
	elif event.is_action_released("pan"):panning=false
	elif event is InputEventMouseMotion and panning:
		var v=event.relative/world_container.stretch_shrink/world.zoom
		world.camera_tile-=Vector2(v.x/64+v.y/32,v.y/32-v.x/64);world.camera_tile=world.camera_tile.clamp(Vector2.ZERO,Vector2(48,48))
	for i in range(1,7):
		if event.is_action_pressed("culture_"+str(i)):select_crop("C"+str(i))
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		has_focus=false;action_held=false;if sim!=null:sim.paused=true
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		has_focus=true;if sim!=null:sim.paused=mode!="FARM"
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		if mode!="TITLE" and sim!=null:save_game()
		quit_game()

func quit_game() -> void:
	shutdown_audio()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
func shutdown_audio() -> void:
	for player in audio_players.values()+machine_players.values()+music_players+ambience_players:
		if is_instance_valid(player):player.stop();player.stream=null
	audio_players.clear();machine_players.clear();music_players.clear();ambience_players.clear()
func _exit_tree() -> void:
	for player in audio_players.values()+machine_players.values()+music_players+ambience_players:
		if is_instance_valid(player):player.stop();player.stream=null
	audio_players.clear();machine_players.clear();music_players.clear();ambience_players.clear()
