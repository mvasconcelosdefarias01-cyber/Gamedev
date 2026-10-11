extends SceneTree

var passed=0
var failures=[]
var output=OS.get_environment("FAZENDA_PACK_QA_DIR")
var main

func _initialize() -> void:
	if output.is_empty():output=ProjectSettings.globalize_path("user://qa/packed")
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	if condition:passed+=1
	else:failures.append(text);printerr("PACK FAIL: "+text)

func frames(n: int) -> void:
	for i in range(n):await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	check(FileAccess.file_exists("res://project.binary"),"packed project loaded without checkout")
	check(not FileAccess.file_exists("res://tests/run_all.gd"),"tests excluded from playable package")
	check(not FileAccess.file_exists("res://tools/north_asset_forge_2d/forge.py"),"production source excluded from playable package")
	check(FileAccess.file_exists("res://assets/LICENSE.txt") and FileAccess.file_exists("res://ui_theme/FONT_LICENSE.txt"),"asset and font licenses included")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	check(manifest is Dictionary and manifest.assets.size()==226,"complete manifest in package")
	for id in manifest.assets:
		var path=manifest.assets[id].path
		check(ResourceLoader.exists(path) and load(path)!=null,"packaged resource loads: "+id)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main);await frames(8)
	main.store=load("res://scripts/save_store.gd").new(output+"/isolated_saves_"+str(Time.get_ticks_usec()))
	main.preferences=main.store.load_preferences();main.apply_preferences()
	main.start_game(1,true);main.close_modal();main.has_focus=false
	main.sim.paused=false
	check(main.sim.seed("B1_A","C1").ok,"packaged cultivation seeds")
	check(main.sim.water("B1_A").ok,"packaged cultivation waters")
	main.sim.advance(24.0)
	check(main.sim.harvest("B1_A").ok,"packaged cultivation harvests")
	check(main.sim.sell("C1",4,false).ok and main.sim.coins()==30,"packaged economy earns expected30coins after seed cost")
	check(main.save_game().ok,"packaged game saves to external user data")
	main.start_game(1,false);main.close_modal();main.has_focus=false
	check(main.sim.coins()==30 and main.sim.state.tutorial.first_harvest,"packaged game resumes harvest and balance")
	main.show_panel("journal");await frames(5)
	check(main.modal_id=="journal" and main.sim.paused,"packaged journal and modal pause")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/packaged_journal.png")==OK,"packed game renders")
	var report={"passed":passed,"failed":failures.size(),"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"audio_driver":AudioServer.get_driver_name(),"outside_checkout":true}
	var f=FileAccess.open(output+"/results.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
	print("FAZENDA_PACK_RESULT: %d passed, %d failed" % [passed,failures.size()])
	main.shutdown_audio();main.queue_free();await frames(30)
	quit(0 if failures.is_empty() else 1)
