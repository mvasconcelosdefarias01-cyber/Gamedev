extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.store=FarmSaveStore.new("/workspace/scratch/fazenda-ui/audio_isolated")
	main.start_game(3,true)
	main.close_modal()
	await create_timer(0.3).timeout
	main.has_focus=false
	main.shutdown_audio()
	main.queue_free()
	for i in range(30): await process_frame
	quit()
