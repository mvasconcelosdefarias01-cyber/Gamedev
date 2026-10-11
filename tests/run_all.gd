extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Store = preload("res://scripts/save_store.gd")
var passed := 0
var failures: Array[String] = []
var report: Dictionary = {"checks": [], "campaign": {}}
var scratch := OS.get_environment("FAZENDA_QA_DIR") if not OS.get_environment("FAZENDA_QA_DIR").is_empty() else ProjectSettings.globalize_path("user://qa/campaign")

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, name: String) -> void:
	report.checks.append({"name":name,"passed":condition})
	if condition:
		passed += 1
	else:
		failures.append(name)
		printerr("FAIL: "+name)

func ok(result: Dictionary, name: String) -> void:
	check(bool(result.get("ok",false)), name+" — "+str(result.get("message","")))

func unlock(sim, through: int = 6) -> void:
	# Isolated fixtures for regression cases; campaign below never injects resources.
	for i in range(1,through+1): sim.state.repairs["R"+str(i)] = true
	for p in sim.state.plots:
		if sim.block_unlocked(p.block): p.state = "empty"
	sim.state.objective = "P8"
	sim.refresh_reserves()

func mature_crop(sim, id: String, crop: String) -> void:
	sim.seed(id,crop)
	sim.water(id)
	sim.advance(float(GameData.CROPS[crop].time))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(scratch)
	test_cultivation()
	test_economy()
	test_patterns()
	test_automation()
	test_crafting_and_progression()
	test_persistence()
	test_offline()
	test_final()
	test_campaign()
	check(passed>0,"tests actually executed")
	report["passed"] = passed
	report["failed"] = failures.size()
	report["failures"] = failures
	var file = FileAccess.open(scratch+"/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("FAZENDA_TEST_RESULT: %d passed, %d failed" % [passed,failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_cultivation() -> void:
	var s = Sim.new()
	check(s.state.plots.size()==24,"24 fixed plots")
	check(s.state.plots.filter(func(p): return p.state=="empty").size()==4,"four starting plots")
	check(s.coins()==24,"starting balance")
	ok(s.seed("B1_A","C1"),"seed turnip")
	check(s.coins()==22 and s.plot("B1_A").state=="water","seed cost and water state")
	s.advance(100)
	check(s.plot("B1_A").state=="water","unwatered plant never grows")
	ok(s.water("B1_A"),"water once")
	s.advance(23)
	check(s.plot("B1_A").state=="growing","growth not premature")
	s.paused = true
	s.advance(120)
	check(is_equal_approx(s.plot("B1_A").remaining,1.0),"pause freezes growth")
	s.paused = false
	s.advance(1)
	check(s.plot("B1_A").state=="mature","growth completes at24s")
	ok(s.harvest("B1_A"),"harvest ripe")
	check(s.state.inventory.C1==4 and s.plot("B1_A").state=="empty","harvest returns plot to empty")
	check(not s.seed("B2_A","C1").ok,"locked plot refuses seed")
	check(not s.seed("B1_A","C6").ok,"locked culture refuses seed")
	check(s.clue_available("P1"),"first harvest unlocks P1")
	ok(s.inspect_clue("P1"),"inspect P1")
	check(s.state.listen_points==3,"P1 grants exactly3")
	check(not s.inspect_clue("P1").ok and s.state.listen_points==3,"evidence reward cannot repeat")
	var poor = Sim.new()
	poor.state.coins_cents=0
	ok(poor.seed("B1_A","C1"),"emergency turnip seed")
	check(poor.state.coins_cents==0,"emergency seed is free")
	check(not poor.seed("B1_B","C1").ok,"one existing plant ends emergency eligibility")
	var partial = Sim.new()
	partial.state.coins_cents=400
	var seeded = 0
	for pos in GameData.POSITIONS:
		if partial.seed("B1_"+pos,"C1").ok: seeded+=1
	check(seeded==2 and partial.state.coins_cents==0,"partial payment never creates negative balance")

func test_economy() -> void:
	var s = Sim.new()
	s.state.upgrades.CUL1=1
	for i in range(5):
		mature_crop(s,"B1_A","C1")
		s.harvest("B1_A")
	check(s.state.inventory.C1==21,"five4.2 yields deliver21")
	var switched = Sim.new()
	unlock(switched,1)
	switched.state.coins_cents=10000
	switched.state.upgrades.CUL1=1
	mature_crop(switched,"B1_A","C1"); switched.harvest("B1_A")
	var remainder: float = switched.plot("B1_A").remainders.C1
	mature_crop(switched,"B1_A","C2"); switched.harvest("B1_A")
	check(is_equal_approx(switched.plot("B1_A").remainders.C1,remainder),"crop swap preserves separate fractional remainder")
	s.state.upgrades.CUL8=1
	s.state.inventory.C1=1
	var before: int = s.state.coins_cents
	ok(s.sell("C1",1,false),"explicit sale")
	check(s.state.coins_cents-before==210,"sale stores fraction in cents")
	for id in s.upgrade_defs:
		s.state.upgrades[id]=s.upgrade_defs[id].costs.size()
	check(is_equal_approx(s.bonus("yield"),0.6),"yield cap60%")
	check(is_equal_approx(s.bonus("growth"),0.25),"growth cap25%")
	check(is_equal_approx(s.bonus("seed"),0.2),"seed cap20%")
	check(is_equal_approx(s.bonus("price"),0.15),"sale price cap15%")
	check(is_equal_approx(s.bonus("repair"),0.1),"repair cap10%")
	check(s.seed_cost("C1")==2 and s.seed_cost("C2")==7,"seed ceiling per unit")
	var r = Sim.new()
	r.state.inventory.C1=20
	ok(r.sell_excess(),"sell excess")
	check(r.state.inventory.C1==16,"objective reserve protects16 turnips")
	var old = r.export_state()
	check(not r.repair("R1").ok,"repair with deficient balance fails")
	check(r.state.coins_cents==old.coins_cents and r.state.inventory==old.inventory,"failed repair debits nothing")

func test_patterns() -> void:
	var s = Sim.new()
	unlock(s,3)
	s.state.coins_cents=100000
	s.state.upgrades.ENG3=1
	ok(s.install_machine("B1","collector"),"install collector fixture")
	ok(s.arm_pattern("B1","PA1"),"arm PA1")
	for i in range(4):
		s.seed("B1_"+GameData.POSITIONS[i],GameData.PATTERNS.PA1.recipe[i])
		s.water("B1_"+GameData.POSITIONS[i])
	s.advance(24)
	check(s.plot("B1_A").state=="mature" and s.plot("B1_B").state=="growing","collector holds shorter crop during armed pattern")
	s.advance(16)
	check(s.state.pending_signals.has("P3"),"pattern records evidence before collector")
	check(s.block_plots("B1").all(func(p): return p.state=="empty"),"collector harvests completed pattern")
	ok(s.inspect_clue("P3"),"P3 inspectable after collector")
	check(s.state.listen_points==3,"collector cannot lose Escuta reward")
	check(not s.arm_pattern("B3","PA1").ok,"pattern block restriction")
	var early = Sim.new()
	unlock(early,2); early.state.coins_cents=100000
	early.arm_pattern("B1","PA1")
	for i in range(4):
		early.seed("B1_"+GameData.POSITIONS[i],GameData.PATTERNS.PA1.recipe[i])
		early.water("B1_"+GameData.POSITIONS[i])
	early.advance(24); early.harvest("B1_A")
	check(early.state.blocks.B1.armed_pattern=="" and not early.state.pending_signals.has("P3"),"early manual harvest invalidates only current attempt")
	check(early.plot("B1_B").state=="growing","early harvest preserves other plants")

func test_automation() -> void:
	var s = Sim.new()
	unlock(s,4); s.state.coins_cents=1000000
	s.state.upgrades.ENG3=1; s.state.upgrades.ENG5=1
	for kind in ["sprinkler","collector","seeder"]: s.install_machine("B1",kind)
	s.configure_block("B1",{"preferred_crop":"C4"})
	check(s.seed_reserve()==80,"global minimum reserve is four most expensive seeds")
	s.state.coins_cents=8000
	s.advance(10)
	check(s.block_plots("B1").all(func(p): return p.state=="empty"),"automation honors seed floor")
	s.state.coins_cents=12000
	s.advance(5)
	check(s.coins()>=80,"automated seed never spends floor")
	check(s.block_plots("B1").filter(func(p): return p.state!="empty").size()==2,"automatic partial sowing")
	var planting_before = s.block_plots("B1").duplicate(true)
	s.configure_block("B1",{"preferred_crop":"C1"})
	check(s.block_plots("B1")==planting_before,"reconfiguration preserves existing plants")
	var timer: float = s.state.blocks.B1.machines.collector.timer
	ok(s.transfer_machine("B1","B2","collector"),"transfer collector")
	check(is_equal_approx(s.state.blocks.B2.machines.collector.timer,timer),"transfer preserves timer")
	check(not s.state.blocks.B1.machines.collector.owned,"transfer not duplication")

func test_crafting_and_progression() -> void:
	var s = Sim.new()
	unlock(s,6); s.state.coins_cents=10000000
	s.state.inventory.C5=12
	ok(s.craft("REC1",2),"fiber crafting batch")
	check(s.state.inventory.C5==0 and s.state.inventory.fiber==6,"6 linen ->3 fibers exact")
	s.state.inventory.C1=8; s.state.inventory.C2=4; s.state.upgrades.CUL7=1
	ok(s.craft("REC2"),"compost recipe")
	check(s.state.inventory.compost==2,"CUL7 doubles uses")
	ok(s.apply_compost("B1"),"apply one compound to empty block")
	s.seed("B1_A","C1")
	check(s.plot("B1_A").compost and s.state.blocks.B1.compound_positions.size()==3,"partial compound persists remaining positions")
	check(not s.apply_compost("B1").ok,"compound cannot stack")
	var fish: Array = []
	for i in range(4): fish.append(s.catch_fish().fish)
	check(fish==["fish_1","fish_1","fish_2","fish_3"],"deterministic fishing collection")
	for id in GameData.DECO: ok(s.buy_decoration(id),"cosmetic "+id)
	check(s.state.deco.size()==6,"all six fixed decorations")
	var listen_cost = 0
	for id in s.upgrade_defs:
		if str(id).begins_with("ESC"): listen_cost+=int(s.upgrade_defs[id].costs[0])
	check(listen_cost==24,"finite Escuta tree costs24")
	for i in range(1,9): s.state.clues["P"+str(i)]=true
	s.state.listen_points=24
	for id in s.upgrade_defs:
		while s.rank(id)<s.upgrade_defs[id].costs.size():
			var result = s.buy_upgrade(id)
			ok(result,"upgrade "+id+" rank"+str(s.rank(id)))
			if not result.ok: break
	check(s.state.listen_points==0,"all Escuta bought with24 exactly")
	for i in range(4): ok(s.buy_tool(),"tool rank"+str(i+1))
	check(s.tool_area()==4 and s.tool_interval()>=0.2,"final tool area and floor")

func test_persistence() -> void:
	var directory = scratch+"/save_"+str(Time.get_ticks_usec())
	var store = Store.new(directory)
	var s = Sim.new()
	s.seed("B1_A","C1"); s.water("B1_A"); s.advance(3.5)
	s.plot("B1_A").remainders.C1=0.2
	ok(store.save_slot(1,s.export_state()),"write slot1")
	var loaded = store.load_slot(1)
	ok(loaded,"read slot1")
	var resumed = Sim.new()
	ok(resumed.import_state(loaded.data),"import slot1")
	check(is_equal_approx(resumed.plot("B1_A").remaining,20.5),"growth remainder roundtrip")
	check(is_equal_approx(resumed.plot("B1_A").remainders.C1,0.2),"yield remainder roundtrip")
	s.state.coins_cents=9900
	ok(store.save_slot(1,s.export_state()),"second write creates backup")
	check(store.load_slot(1,true).data.coins_cents==2200,"backup retains previous record")
	var corrupt = FileAccess.open(store.slot_path(1),FileAccess.WRITE)
	corrupt.store_string("{broken"); corrupt.close()
	var rejected = store.load_slot(1)
	check(not rejected.ok and rejected.backup_available,"corrupt main requires explicit backup recovery")
	ok(store.load_slot(1,true),"backup still readable")
	check(FileAccess.get_file_as_string(store.slot_path(1))=="{broken","corruption never overwritten automatically")
	ok(store.restore_backup(1),"explicit recovery restores valid backup")
	check(store.load_slot(1).data.coins_cents==2200 and store.load_slot(1,true).data.coins_cents==2200,"backup recovery preserves good backup")
	var preserved=false
	for name in DirAccess.get_files_at(directory):
		if name.begins_with("slot_1.json.damaged_"):preserved=FileAccess.get_file_as_string(directory+"/"+name)=="{broken"
	check(preserved,"damaged primary remains available after recovery")
	ok(store.save_slot(2,s.export_state()),"slot2 independence")
	check(not store.load_slot(3).ok,"slot3 remains empty")
	var invalid = s.export_state()
	invalid.coins_cents=-900; invalid.tool_level=999; invalid.upgrades.CUL1=99
	ok(resumed.import_state(invalid),"normalize numeric invalid fields")
	check(resumed.state.coins_cents==0 and resumed.state.tool_level==4 and resumed.rank("CUL1")==3,"safe numeric normalization")
	var malformed=s.export_state()
	malformed.inventory=[]
	check(not resumed.import_state(malformed).ok,"reject structurally malformed inventory")
	malformed=s.export_state(); malformed.player=[]
	check(not resumed.import_state(malformed).ok,"reject malformed position safely")
	malformed=s.export_state(); malformed.blocks.B1.machines=[]
	check(not resumed.import_state(malformed).ok,"reject malformed machines safely")
	malformed=s.export_state(); malformed.coins_cents={"bad":"number"}
	check(not resumed.import_state(malformed).ok,"reject malformed numeric fields safely")
	malformed=s.export_state(); malformed.plots[0].block="missing"; malformed.plots[0].position="Z"
	ok(resumed.import_state(malformed),"repair immutable plot identity")
	check(resumed.plot("B1_A").block=="B1" and resumed.plot("B1_A").position=="A","plot identity restored from canonical IDs")
	malformed=s.export_state(); malformed.plots.append({"id":"B1_Z","state":"new_unknown_state"})
	ok(resumed.import_state(malformed),"unknown future plot preserved")
	check(resumed.state.unknown_plot_records.size()==1,"unknown record retained for diagnostics")
	var preferences = store.load_preferences()
	preferences.fish_assist=true; preferences.ui_scale=1.5
	ok(store.save_preferences(preferences),"preferences write")
	check(store.load_preferences().fish_assist and is_equal_approx(store.load_preferences().ui_scale,1.5),"preferences independent roundtrip")
	var damaged_preferences="{\"ui_scale\":[],\"music_volume\":\"bad\",\"bindings\":{\"tool\":[null]},\"shirt\":4,\"fish_assist\":\"true\"}"
	var pf=FileAccess.open(store.preferences_path(),FileAccess.WRITE);pf.store_string(damaged_preferences);pf.close()
	var recovered_options=store.load_preferences()
	check(recovered_options.ui_scale==1.0 and recovered_options.music_volume==0.5 and not recovered_options.fish_assist,"malformed options use safe defaults")
	check(recovered_options.bindings.is_empty() and recovered_options.has("recovery_notice"),"malformed bindings report recovery")
	check(FileAccess.get_file_as_string(store.preferences_path())==damaged_preferences,"option recovery preserves original file")
	var invalid_menu=FileAccess.open(store.slot_path(3),FileAccess.WRITE);invalid_menu.store_string("{\"plots\":[],\"coins_cents\":\"broken\",\"clues\":[]}");invalid_menu.close()
	check(not store.load_slot(3).ok and "preservado" in store.slot_summary(3),"title summary handles malformed slot without crashing")

func test_offline() -> void:
	var s = Sim.new()
	unlock(s,4); s.state.coins_cents=1000000
	for id in ["ENG3","ENG5","ENG6","ENG9"]: s.state.upgrades[id]=1
	for kind in ["sprinkler","collector","seeder"]: s.install_machine("B1",kind)
	s.state.auto_sell=true
	s.state.offline_reference=1000
	var before_active: float = s.state.total_active_seconds
	var summary = s.apply_offline(4600)
	check(summary.real_seconds==1800 and summary.computed_seconds==450,"offline max30min at25%")
	check(int(summary.produced.get("C1",0))>0,"offline summary counts production even after auto-sale")
	check(s.state.coins_cents>10000,"offline production generates economy")
	check(s.state.total_active_seconds==before_active,"offline does not increment active playtime")
	check(s.state.clues.is_empty() and s.state.pending_signals.is_empty(),"offline does not advance evidence")
	var before = s.export_state()
	var second = s.apply_offline(4600)
	check(second.computed_seconds==0 and s.state.coins_cents==before.coins_cents,"same interval consumed once")
	var negative = s.apply_offline(4500)
	check(negative.real_seconds==0 and s.state.offline_reference==4500,"negative clock useszero and resets reference")
	var dry = Sim.new()
	unlock(dry,4); dry.state.upgrades.ENG9=1; dry.state.offline_reference=1000
	dry.seed("B1_A","C1")
	dry.apply_offline(2000)
	check(dry.plot("B1_A").state=="water","offline cannot water without sprinkler")
	dry.water("B1_A"); dry.state.offline_reference=1000; dry.apply_offline(2000)
	check(dry.plot("B1_A").state=="mature","offline without collector stops ripe")
	var final_wait = Sim.new()
	unlock(final_wait,6); final_wait.state.coins_cents=1000000
	final_wait.state.upgrades.ENG3=1; final_wait.state.upgrades.ENG9=1
	final_wait.install_machine("B6","collector")
	final_wait.arm_pattern("B6","PA3")
	for i in range(4):
		var id = "B6_"+GameData.POSITIONS[i]
		final_wait.seed(id,GameData.PATTERNS.PA3.recipe[i]); final_wait.water(id)
	final_wait.advance(56)
	check(not final_wait.state.final_ready and not final_wait.state.final_lot.is_empty(),"final lot waits between maturity and collector")
	final_wait.state.offline_reference=1000
	final_wait.apply_offline(2000)
	check(not final_wait.state.final_completed and not final_wait.state.final_ready,"offline cannot advance ending")
	final_wait.advance(5)
	check(final_wait.state.final_ready,"return from offline can complete final lot without softlock")

func prepare_pattern(s, block: String, pattern: String) -> bool:
	var result = s.arm_pattern(block,pattern)
	if not result.ok: return false
	var recipe: Array = GameData.PATTERNS[pattern].recipe
	for i in range(4):
		var id = block+"_"+GameData.POSITIONS[i]
		if not s.seed(id,recipe[i]).ok: return false
		s.water(id)
	s.advance(80)
	return true

func test_final() -> void:
	var s = Sim.new()
	unlock(s,6); s.state.coins_cents=100000
	for i in range(1,8): s.state.clues["P"+str(i)]=true
	check(not s.valve(1).ok,"final requires planted and harvested lot")
	check(prepare_pattern(s,"B6","PA3"),"prepare final PA3")
	check(not s.state.final_ready,"maturity alone cannot unlock valves")
	for p in s.block_plots("B6"): s.harvest(p.id)
	check(s.state.final_ready,"four final harvests unlock valves")
	check(not s.valve(2).ok and s.state.valve_step==0 and s.state.final_ready,"wrong valve keeps lot")
	ok(s.valve(1),"valve I")
	ok(s.valve(2),"valve II")
	ok(s.valve(3),"valve III records P8")
	check(s.state.final_completed and s.has("P8") and s.state.listen_points==3,"final recorded before memory presentation")
	check(not s.valve(3).ok and s.state.listen_points==3,"final reward single use")
	ok(s.seed("B6_A","C1"),"free cultivation after ending")

func farm_until(s, target_coins: int, items: Dictionary = {}) -> bool:
	for cycle in range(5000):
		var enough: bool = s.coins()>=target_coins
		for id in items:
			if s.state.inventory.get(id,0)<items[id]: enough=false
		if enough: return true
		var preferred = "C4" if s.has("R3") else "C1"
		for id in items:
			if GameData.CROPS.has(id) and s.state.inventory[id]<items[id]: preferred=id; break
		for p in s.state.plots:
			if p.state=="empty":
				var crop: String = preferred if s.coins()>=s.seed_cost(preferred) else "C1"
				s.seed(p.id,crop)
			if p.state=="water": s.water(p.id)
		var grow := 0.0
		for p in s.state.plots:
			if p.state=="growing": grow=maxf(grow,float(p.remaining))
		if grow>0: s.advance(grow)
		for p in s.state.plots:
			if p.state=="mature": s.harvest(p.id)
		for id in GameData.CROPS:
			var excess: int = int(s.state.inventory[id])-int(items.get(id,0))
			if excess>0: s.sell(id,excess,false)
		if grow==0:
			# Legitimate guaranteed recovery, not a currency fixture.
			s.collect_material("wood",2); s.sell("wood",1,false); s.advance(2)
	return false

func campaign_repair(s, id: String, items_override: Dictionary = {}) -> bool:
	var items: Dictionary = GameData.REPAIRS[id].items.duplicate(true)
	items.merge(items_override,true)
	for material in ["wood","stone"]:
		var missing: int = maxi(0,int(items.get(material,0))-int(s.state.inventory[material]))
		if missing>0: s.collect_material(material,missing*2.0); s.advance(missing*2.0)
	if not farm_until(s,s.repair_cost(id),items): return false
	return s.repair(id).ok

func test_campaign() -> void:
	var s = Sim.new()
	check(farm_until(s,40),"campaign first harvest and sale")
	ok(s.inspect_clue("P1"),"campaign P1")
	check(campaign_repair(s,"R1"),"campaign R1 legitimate production")
	ok(s.inspect_clue("P2"),"campaign P2")
	farm_until(s,140); ok(s.buy_upgrade("CUL1"),"campaign first reinvestment"); ok(s.buy_tool(),"campaign F1")
	check(campaign_repair(s,"R2"),"campaign R2")
	farm_until(s,40)
	check(prepare_pattern(s,"B1","PA1"),"campaign PA1")
	for p in s.block_plots("B1"): s.harvest(p.id)
	ok(s.inspect_clue("P3"),"campaign slice to P3")
	var checkpoint = s.export_state()
	var continued = Sim.new()
	ok(continued.import_state(checkpoint),"slice resume state")
	check(continued.has("P3") and continued.state.blocks.B1.machines.sprinkler.owned,"slice includes eight plots and sprinkler")
	s=continued
	check(campaign_repair(s,"R3"),"campaign R3")
	farm_until(s,800); ok(s.buy_upgrade("CUL2"),"campaign growth upgrade"); ok(s.buy_upgrade("CUL5"),"campaign yield upgrade")
	farm_until(s,50)
	check(prepare_pattern(s,"B3","PA2"),"campaign PA2")
	for p in s.block_plots("B3"): s.harvest(p.id)
	ok(s.inspect_clue("P4"),"campaign P4")
	farm_until(s,4500,{"C5":36})
	ok(s.craft("REC1",6),"campaign deterministic18fibers")
	check(campaign_repair(s,"R4"),"campaign R4")
	ok(s.inspect_clue("P5"),"campaign P5 travel receipt")
	farm_until(s,80)
	check(prepare_pattern(s,"B5","PA3"),"campaign PA3")
	for p in s.block_plots("B5"): s.harvest(p.id)
	ok(s.inspect_clue("P6"),"campaign P6")
	farm_until(s,14000,{"C4":40,"C5":24})
	ok(s.craft("REC1",4),"campaign deterministic12fibers")
	check(campaign_repair(s,"R5"),"campaign R5")
	ok(s.inspect_clue("P7"),"campaign P7")
	check(campaign_repair(s,"R6"),"campaign R6")
	farm_until(s,80)
	check(prepare_pattern(s,"B6","PA3"),"campaign final pattern")
	for p in s.block_plots("B6"): s.harvest(p.id)
	ok(s.valve(1),"campaign final I"); ok(s.valve(2),"campaign final II"); ok(s.valve(3),"campaign final III")
	check(s.state.clues.size()==8 and s.state.listen_points==24,"campaign eight clues exactly24 points without Escuta nodes")
	check(s.state.final_completed and s.state.repairs.size()==6,"campaign canonical ending")
	check(s.state.plots.filter(func(p): return p.state!="locked").size()==24,"campaign24 plots unlocked")
	report.campaign={"completed":s.state.final_completed,"clues":s.state.clues.size(),"repairs":s.state.repairs.size(),"active_simulation_seconds":s.state.total_active_seconds,"human_playtest":false,"currency_injected":false}
	var file=FileAccess.open(scratch+"/campaign_final.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(s.export_state(),"\t")); file.close()
