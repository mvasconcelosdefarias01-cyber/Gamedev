extends SceneTree

var main
var failures: Array[String]=[]
var passed := 0
var output := OS.get_environment("FAZENDA_UI_QA_DIR") if not OS.get_environment("FAZENDA_UI_QA_DIR").is_empty() else ProjectSettings.globalize_path("user://qa/ui")
var campaign_dir := OS.get_environment("FAZENDA_QA_DIR") if not OS.get_environment("FAZENDA_QA_DIR").is_empty() else ProjectSettings.globalize_path("user://qa/campaign")
var captures: Array[String]=[]

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, name: String) -> void:
	if condition: passed+=1
	else: failures.append(name); printerr("UI FAIL: "+name)

func frames(count: int = 4) -> void:
	for i in range(count): await process_frame

func capture(name: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	var file=output+"/"+name+".png"
	var image=root.get_texture().get_image()
	check(image.save_png(file)==OK,"capture "+name)
	captures.append(file)

func key(code: int) -> void:
	var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(8)
	main.store=FarmSaveStore.new(output+"/isolated_saves_"+str(Time.get_ticks_usec()))
	main.preferences=main.store.load_preferences()
	main.apply_preferences()
	main.show_title()
	await capture("title_720")
	check(main.mode=="TITLE","starts at title")
	check(main.modal.find_children("*","Button",true,false).size()>=8,"three slot menu and options")
	main.start_game(3,true)
	await frames()
	check(main.modal_id=="dialog","intro dialogue")
	main.close_modal()
	main.has_focus=true
	await capture("initial_720_100")
	check(main.mode=="FARM","intro returns to farm")
	check(main.world_view.size==Vector2i(640,360),"world framebuffer remains640x360")
	# Input-level movement; the world function still handles footprints/collisions.
	var before: Vector2=main.world.player_tile
	Input.action_press("move_right")
	await create_timer(0.12).timeout
	Input.action_release("move_right")
	check(main.world.player_tile.distance_to(before)>0.01,"mapped movement responds")
	main.world.player_tile=Vector2(13,35)
	var iso_start: Vector2=main.world.iso(main.world.player_tile)
	main.world.move_player(Vector2(1,0),0.2)
	var straight: float=main.world.iso(main.world.player_tile).distance_to(iso_start)
	main.world.player_tile=Vector2(13,35)
	main.world.move_player(Vector2(1,1),0.2)
	var diagonal: float=main.world.iso(main.world.player_tile).distance_to(iso_start)
	check(is_equal_approx(straight,diagonal),"diagonal movement normalized")
	check(not main.world.walkable(Vector2(8,34)),"building footprint collision")
	# Tool requires a nearby aim and does not work in inspection mode.
	main.world.player_tile=Vector2(13,34)
	main.world.target_plot="B1_A";main.world.preview_plots=["B1_A"]
	main.inspection=true;main.execute_tool()
	check(main.sim.plot("B1_A").state=="empty","inspection cannot cultivate")
	main.inspection=false;main.execute_tool()
	check(main.sim.plot("B1_A").state=="water","nearby manual seed")
	main.world.player_tile=Vector2(8,36);main.execute_tool()
	check(main.sim.plot("B1_A").state=="water","out of range action has no effect")
	main.world.player_tile=Vector2(13,34);main.execute_tool()
	check(main.sim.plot("B1_A").state=="growing","contextual action waters")
	main.show_panel("sale")
	await frames()
	var remaining: float=main.sim.plot("B1_A").remaining
	await key(KEY_U)
	check(main.modal_id=="sale","U cannot stack modal over sale")
	check(is_equal_approx(main.sim.plot("B1_A").remaining,remaining),"modal freezes cultivation")
	var focus=root.gui_get_focus_owner()
	check(focus!=null and main.modal.is_ancestor_of(focus),"focus remains inside modal")
	await key(KEY_ESCAPE)
	check(main.mode=="FARM" and main.modal==null,"Esc returns to farm")
	await key(KEY_TAB)
	check(main.inspection,"Tab reaches inspection despite HUD focus")
	await key(KEY_TAB)
	check(not main.inspection,"Tab returns to cultivation")
	main.show_options();main.remap_action="journal"
	await key(KEY_K)
	check(main.preferences.bindings.get("journal",[])==[KEY_K],"keyboard remapping persists selected binding")
	main.close_modal();await key(KEY_K)
	check(main.modal_id=="journal","remapped key opens journal")
	main.preferences.bindings={};main.setup_input();main.close_modal()
	main.preferences.instant_text=false;main.preferences.text_speed=20
	main.show_dialog("Lia","Esta frase deve aparecer aos poucos; Enter completa o texto e mantém o painel aberto.")
	await frames(4)
	check(not main.reveal_labels.is_empty() and main.reveal_labels[0].visible_characters<main.reveal_labels[0].get_total_character_count(),"typewriter preference has an observable effect")
	await key(KEY_ENTER)
	check(main.modal_id=="dialog" and (main.reveal_labels[0].visible_characters==-1 or main.reveal_labels[0].visible_characters>=main.reveal_labels[0].get_total_character_count()),"Enter completes typewriter without dismissing dialogue")
	main.preferences.instant_text=true;main.close_modal()
	var recover=main.sim.export_state();recover.player=[8,34]
	check(main.store.save_slot(1,recover).ok,"isolated save stores obstructed position")
	main.start_game(1,false);main.close_modal()
	check(main.world.walkable(main.world.player_tile),"load recovers position trapped inside house")
	check(main.sim.state.coins_cents==recover.coins_cents,"position recovery preserves campaign currency")
	main.world.player_tile=Vector2(10,31);main.world.camera_tile=Vector2(10,31)
	main.interact()
	check(main.mode=="MEMORY" and main.world.memory_id=="material","wood collection uses timed interaction")
	var material_camera: Vector2=main.world.camera_tile
	var wood_before: int=main.sim.state.inventory.wood
	main.finish_memory("material")
	check(main.sim.state.inventory.wood==wood_before+1 and main.world.camera_tile==material_camera,"material collection rewards one unit without moving camera")
	# Visual fixture, distinct from the no-currency-injection campaign test.
	main.has_focus=false
	for i in range(1,5):main.sim.state.repairs["R"+str(i)]=true
	for p in main.sim.state.plots:
		if main.sim.block_unlocked(p.block):p.state="empty";p.crop=""
	main.sim.state.clues={"P1":true,"P2":true,"P3":true}
	main.sim.state.tutorial.first_harvest=true
	main.sim.state.coins_cents=123450
	main.sim.state.objective="R4"
	main.sim.state.blocks.B1.machines.sprinkler.owned=true
	var ids=["B1_A","B1_B","B1_C","B1_D","B2_A","B2_B"]
	for i in range(6):
		var p=main.sim.plot(ids[i]);p.crop="C"+str(i+1);p.duration=60.0;p.remaining=40.0
		p.state="water" if i==5 else ("growing" if i==2 or i==3 else "mature")
		if i==3:p.remaining=15.0
	main.world.camera_tile=Vector2(19,33.5);main.world.player_tile=Vector2(18,34)
	main.sim.refresh_reserves();main.refresh_hud();main.world.queue_redraw()
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution
		for scale in [1.0,1.5]:
			main.preferences.ui_scale=scale;main.preferences.text_scale=scale
			main.apply_preferences();main.build_hud();main.refresh_hud()
			await capture("farm_%d_%d" % [resolution.y,int(scale*100)])
			var view_rect=main.ui.get_viewport_rect()
			for b in main.culture_buttons.values():
				check(view_rect.encloses(b.get_global_rect()),"culture button in window %d/%d/%s" % [resolution.y,int(scale*100),b.text])
			for b in main.hud.find_children("*","Button",true,false):
				check(view_rect.encloses(b.get_global_rect()),"HUD button in window %d/%d/%s" % [resolution.y,int(scale*100),b.text])
	root.size=Vector2i(1280,720)
	main.preferences.ui_scale=1.5;main.apply_preferences();main.build_hud();main.refresh_hud()
	# Presentation upgrades must have visible effects, beyond their purchase flags.
	for id in ["ESC1","ESC2","ESC3","ESC4","ESC5","ESC8","ESC9"]:main.sim.state.upgrades[id]=1
	main.sim.state.pending_signals={"P6":"B5"}
	main.destination_tile=Vector2(12,34);main.refresh_hud()
	await capture("minimap_720_150")
	check(main.minimap!=null and main.minimap.visible,"ESC5 exposes live minimap")
	check(main.minimap.destination_tile==Vector2(12,34),"clue destination reaches minimap")
	check(main.ui.get_viewport_rect().encloses(main.minimap.get_global_rect()),"large-text minimap stays inside viewport")
	check("B5" in main.memory_captions.text,"ESC4 preserves pending echo caption")
	main.preferences.minimap_visible=false;main.refresh_hud()
	check(not main.minimap.visible and main.map_toggle.visible,"minimap can be collapsed")
	main.preferences.minimap_visible=true;main.refresh_hud()
	for screen in ["block","upgrades","journal","repair","sale","workshop","options"]:
		main.close_modal();main.show_panel(screen,"B1" if screen=="block" else ("R5" if screen=="repair" else ""))
		await capture(screen+"_720_150")
		check(main.modal!=null and main.sim.paused,"modal policy "+screen)
	main.close_modal()
	main.preferences.high_contrast=true;main.apply_preferences();main.build_hud();main.refresh_hud()
	await capture("high_contrast_720_150")
	main.preferences.high_contrast=false;main.apply_preferences()
	# Focus loss must not trigger offline earnings.
	main.has_focus=true;main.close_modal()
	main.sim.water("B2_B")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var paused_remaining: float=main.sim.plot("B2_B").remaining
	var offline_reference: int=main.sim.state.offline_reference
	await create_timer(0.1).timeout
	check(is_equal_approx(main.sim.plot("B2_B").remaining,paused_remaining),"focus loss freezes plants")
	check(main.sim.state.offline_reference==offline_reference,"focus loss does not invoke offline")
	main._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	# Fishing controller timing and assistance, separate from deterministic fish data.
	main.close_modal();main.begin_fishing();main.fishing_clock=1.0
	var fish_before: int=main.sim.state.fish_count
	main.reel_fish()
	check(main.sim.state.fish_count==fish_before,"early fishing attempt is free and does not advance sequence")
	main.begin_fishing();main.fishing_clock=6.2;main.reel_fish()
	check(main.sim.state.fish_count==fish_before+1,"valid fishing window awards catch")
	main.close_modal();main.preferences.fish_assist=true;main.begin_fishing();main.fishing_clock=6.1
	await frames(3)
	check(main.sim.state.fish_count==fish_before+2,"fishing assistance eliminates reaction window")
	main.close_modal();main.world.camera_tile=Vector2(19,33.5);main.world.player_tile=Vector2(18,34)
	main.show_memory("P3",GameData.CLUES.P3.text,12)
	await capture("memory_P3_720")
	check(main.mode=="MEMORY" and main.sim.paused,"memory pauses cultivation")
	check(main.modal.get_global_rect().position.y>=360,"memory leaves half world visible")
	var skip_visible=false
	for b in main.modal.find_children("*","Button",true,false):
		if "Pular" in b.text:skip_visible=skip_visible or main.ui.get_viewport_rect().encloses(b.get_global_rect())
	check(skip_visible,"memory skip stays visible with large text")
	main.finish_memory("P3")
	check(main.mode=="FARM","skip memory returns safely")
	# Rendering final state loaded from the actual verified campaign output.
	var final_data=JSON.parse_string(FileAccess.get_file_as_string(campaign_dir+"/campaign_final.json"))
	check(main.sim.import_state(final_data).ok,"UI loads complete campaign")
	main.world.player_tile=Vector2(40,16);main.world.camera_tile=Vector2(40,16)
	main.show_memory("P8",GameData.CLUES.P8.text,20)
	await capture("memory_P8_720")
	main.finish_memory("P8")
	check(main.modal_id=="ending" and main.sim.state.final_completed,"skip final memory retains campaign result")
	await capture("ending_720")
	main.close_modal();main.has_focus=false;main.refresh_hud()
	await capture("postgame_720")
	check(main.mode=="FARM" and main.sim.state.final_completed,"ending returns to free cultivation")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"captures":captures,"renderer":RenderingServer.get_video_adapter_name(),"human_playtest":false}
	var file=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("FAZENDA_UI_RESULT: %d passed, %d failed" % [passed,failures.size()])
	main.shutdown_audio()
	main.queue_free();await frames(30)
	quit(0 if failures.is_empty() else 1)
