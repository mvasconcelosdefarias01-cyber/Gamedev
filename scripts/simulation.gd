class_name FarmSimulation
extends RefCounted

signal changed(reason: String)
signal reward(kind: String, item: String, quantity: int, block: String)
var state: Dictionary = {}
var upgrade_defs = GameData.upgrades()
var paused = false
var _material_timers = {"wood":0.0,"stone":0.0}
var _offline_produced: Dictionary = {}
var _offline_sale_cents := 0
var _offline_tracking := false
func _init() -> void:
	new_game()
func new_game(slot_id: int = 1) -> void:
	var now = int(Time.get_unix_time_from_system())
	state = {"schema_version":1,"slot_id":slot_id,"created_at":now,"last_saved_at":now,"offline_reference":now,"total_active_seconds":0.0,"coins_cents":2400,"inventory":{},"reserves":{},"manual_reserves":{},"seed_reserve":0,"repairs":{},"clues":{},"upgrades":{},"listen_points":0,"tool_level":0,"blocks":{},"plots":[],"pending_signals":{},"patterns_completed":{},"history":[],"tutorial":{"first_harvest":false,"sold":false},"player":[13.0,35.0],"objective":"R1","final_completed":false,"final_lot":{},"final_harvested":{},"final_ready":false,"valve_step":0,"fish_count":0,"fish_collection":{},"deco":{},"auto_sell":false,"offline_enabled":true,"sale_timer":0.0,"lot_counter":0,"last_offline_summary":{}}
	for id in GameData.CROPS.keys()+GameData.ITEMS.keys():
		state.inventory[id] = 0
	for id in GameData.BLOCKS:
		state.blocks[id] = {"preferred_crop":"C1","armed_pattern":"","machines":{},"compound_positions":[],"label":false,"paused":false}
		for kind in GameData.MACHINE_COSTS:
			state.blocks[id].machines[kind] = {"owned":false,"enabled":true,"timer":0.0,"status":"Não instalado"}
		for pos in GameData.POSITIONS:
			state.plots.append({"id":id+"_"+pos,"block":id,"position":pos,"crop":"","state":"empty" if id=="B1" else "locked","remaining":0.0,"duration":0.0,"lot":0,"compost":false,"remainders":{},"pattern_bonus":1.0})
	set_objective("R1")
func success(message: String = "", extra: Dictionary = {}) -> Dictionary:
	var r = {"ok":true,"message":message}
	r.merge(extra)
	return r
func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
func notify(reason: String) -> void:
	changed.emit(reason)
func coins() -> int:
	return int(state.coins_cents / 100)
func rank(id: String) -> int:
	return int(state.upgrades.get(id,0))
func has(id: String) -> bool:
	if id.is_empty(): return true
	var p = id.split(":")
	if p.size() > 1: return rank(p[0]) >= int(p[1])
	return bool(state.repairs.get(id,false)) or bool(state.clues.get(id,false)) or rank(id)>0
func requirement_text(ids: Array) -> String:
	var parts: Array[String] = []
	for id in ids:
		if not has(id):
			var base = str(id).split(":")[0]
			parts.append(str(id)+" "+str(GameData.REPAIRS.get(base,GameData.CLUES.get(base,upgrade_defs.get(base,{"name":base}))).name))
	return "Requer: "+", ".join(parts) if not parts.is_empty() else ""
func crop_unlocked(id: String) -> bool:
	return GameData.CROPS.has(id) and has(GameData.CROPS[id].unlock)
func block_unlocked(id: String) -> bool:
	return GameData.BLOCKS.has(id) and has(GameData.BLOCKS[id].unlock)
func plot(id: String) -> Dictionary:
	for p in state.plots:
		if p.id==id: return p
	return {}
func block_plots(id: String) -> Array:
	return state.plots.filter(func(p): return p.block==id)
func bonus(group: String) -> float:
	var value = 0.0
	for id in upgrade_defs:
		if upgrade_defs[id].group==group: value += float(upgrade_defs[id].value)*rank(id)
	var caps = {"yield":0.6,"growth":0.25,"seed":0.2,"price":0.15,"repair":0.1}
	return minf(value,float(caps.get(group,100.0)))
func seed_cost(crop: String) -> int:
	return maxi(1,int(ceil(float(GameData.CROPS[crop].seed)*(1.0-bonus("seed")))))
func tool_interval() -> float:
	return maxf(0.2,float(GameData.TOOLS[state.tool_level].interval)*(1.0-bonus("tool")))
func tool_area() -> int:
	return GameData.TOOLS[state.tool_level].area
func speed() -> float:
	return 3.0*(1.0+bonus("move"))
func seed_reserve() -> int:
	var floor_value = 0
	for b in state.blocks.values():
		if b.machines.seeder.owned: floor_value=maxi(floor_value,4*seed_cost(b.preferred_crop))
	return maxi(floor_value,int(state.seed_reserve))
func emergency_allowed() -> bool:
	if coins()>0: return false
	for id in state.inventory:
		if state.inventory[id]>0 and item_price(id)>0: return false
	for p in state.plots:
		if p.state in ["water","growing","mature"]: return false
	return true
func seed(plot_id: String, crop_id: String, automatic: bool = false) -> Dictionary:
	var p = plot(plot_id)
	if p.is_empty(): return fail("Canteiro desconhecido")
	if p.state!="empty": return fail("Este canteiro não está vazio")
	if not crop_unlocked(crop_id): return fail("Requer "+str(GameData.CROPS.get(crop_id,{"unlock":"cultura válida"}).unlock))
	var cost = seed_cost(crop_id)
	if crop_id=="C1" and not automatic and emergency_allowed(): cost=0
	if coins()-cost < (seed_reserve() if automatic else 0): return fail("Saldo reservado" if automatic else "Faltam moedas para a semente")
	state.coins_cents -= cost*100
	state.lot_counter += 1
	p.crop=crop_id; p.state="water"; p.lot=state.lot_counter; p.pattern_bonus=1.0
	var b = state.blocks[p.block]
	p.compost=p.position in b.compound_positions
	if p.compost: b.compound_positions.erase(p.position)
	p.duration=float(GameData.CROPS[crop_id].time)*(1.0-minf(0.25,bonus("growth")+(0.1 if p.compost else 0.0)))
	p.remaining=p.duration
	reward.emit("seed",crop_id,1,p.block)
	notify("plant")
	return success("Semeado "+GameData.item_name(crop_id),{"cost":cost})
func water(plot_id: String) -> Dictionary:
	var p=plot(plot_id)
	if p.is_empty() or p.state!="water": return fail("A planta não precisa de água")
	p.state="growing"
	reward.emit("water",p.crop,1,p.block)
	notify("water")
	return success("Irrigado uma vez; agora basta crescer")
func harvest(plot_id: String, automatic: bool = false, offline: bool = false) -> Dictionary:
	var p=plot(plot_id)
	if p.is_empty() or p.state!="mature": return fail("A planta ainda não está madura")
	if offline and not state.final_completed and state.final_lot.get(p.id,-1)==p.lot:
		return fail("Lote final preservado até retomar a fazenda")
	if not offline: evaluate_patterns()
	var b=state.blocks[p.block]
	if not str(b.armed_pattern).is_empty():
		if automatic: return fail("Coletor aguarda quatro plantas maduras")
		b.armed_pattern=""
		notify("Prepare novo lote: maturação conjunta interrompida")
	var crop=str(p.crop)
	var expected=float(GameData.CROPS[crop].yield)*(1.0+bonus("yield"))*float(p.pattern_bonus)+float(p.remainders.get(crop,0.0))
	var quantity=int(floor(expected+0.000001))
	p.remainders[crop]=clampf(expected-quantity,0.0,0.999999999)
	state.inventory[crop]+=quantity
	if offline: _offline_produced[crop]=int(_offline_produced.get(crop,0))+quantity
	if not offline and state.final_lot.get(p.id,-1)==p.lot:
		state.final_harvested[p.id]=true
		if state.final_harvested.size()==4: state.final_ready=true
	p.state="empty"; p.crop=""; p.remaining=0.0; p.compost=false; p.pattern_bonus=1.0
	if not offline: state.tutorial.first_harvest=true
	reward.emit("harvest",crop,quantity,p.block)
	notify("harvest")
	return success("+%d %s" % [quantity,GameData.item_name(crop)],{"quantity":quantity})
func evaluate_patterns() -> void:
	if not has("R2"): return
	for bid in GameData.BLOCKS:
		if not block_unlocked(bid): continue
		var plants=block_plots(bid)
		for pid in GameData.PATTERNS:
			var def=GameData.PATTERNS[pid]
			if bid not in def.blocks or not has(def.unlock): continue
			if bid=="B6" and not has("R6"): continue
			var matches=true
			for i in range(4):
				if plants[i].state!="mature" or plants[i].crop!=def.recipe[i]: matches=false
			if not matches: continue
			state.patterns_completed[pid]=true
			if bid=="B6":
				if state.final_lot.is_empty():
					for p in plants: state.final_lot[p.id]=p.lot
			elif not has(def.clue):
				state.pending_signals[def.clue]=bid
			if rank("ESC7")>0:
				for p in plants: p.pattern_bonus=1.15
			state.blocks[bid].armed_pattern=""
func advance(seconds: float, offline: bool = false) -> void:
	if paused and not offline: return
	var left=maxf(0,seconds)
	while left>0.000001:
		var dt=minf(1.0,left)
		_tick(dt,offline)
		left-=dt
	if seconds>0: notify("tick")
func _tick(dt: float, offline: bool) -> void:
	if not offline: state.total_active_seconds+=dt
	for p in state.plots:
		if p.state=="growing":
			p.remaining=maxf(0,p.remaining-dt)
			if p.remaining<=0.000001:
				p.state="mature"
				if not offline: reward.emit("grow",p.crop,0,p.block)
	if not offline: evaluate_patterns()
	for bid in state.blocks:
		var b=state.blocks[bid]
		if not block_unlocked(bid) or b.paused: continue
		var machine=b.machines.collector
		if machine.owned and machine.enabled:
			machine.timer+=dt
			var interval=5.0-rank("ENG4")
			if machine.timer+0.000001>=interval:
				machine.timer=fmod(machine.timer,interval)
				for p in block_plots(bid):
					if p.state=="mature": harvest(p.id,true,offline)
			machine.status="Aguardar padrão" if not str(b.armed_pattern).is_empty() else "Coletando"
	state.sale_timer+=dt
	if state.sale_timer+0.000001>=10.0:
		state.sale_timer=fmod(state.sale_timer,10.0)
		if state.auto_sell and has("ENG6"): sell_excess()
	for bid in state.blocks:
		var b=state.blocks[bid]
		if not block_unlocked(bid) or b.paused: continue
		var machine=b.machines.seeder
		if machine.owned and machine.enabled:
			machine.timer+=dt
			var interval=5.0-rank("ENG8")
			if machine.timer+0.000001>=interval:
				machine.timer=fmod(machine.timer,interval)
				if str(b.armed_pattern).is_empty():
					for p in block_plots(bid):
						if p.state=="empty":
							var result=self.seed(p.id,b.preferred_crop,true)
							machine.status="Semeando" if result.ok else result.message
				else: machine.status="Padrão armado: semeadura manual"
		machine=b.machines.sprinkler
		if machine.owned and machine.enabled:
			machine.timer+=dt
			if machine.timer+0.000001>=2.0:
				machine.timer=fmod(machine.timer,2.0)
				for p in block_plots(bid):
					if p.state=="water": water(p.id)
			machine.status="Irrigando"
func item_price(id: String) -> int:
	return int(GameData.CROPS.get(id,GameData.ITEMS.get(id,{"price":0})).price)
func sell(id: String, quantity: int, respect_reserve: bool = true) -> Dictionary:
	if not state.inventory.has(id) or item_price(id)<=0: return fail("Item não vendável")
	var available=maxi(0,int(state.inventory[id])-int(state.reserves.get(id,0))) if respect_reserve else int(state.inventory[id])
	var count=clampi(quantity,0,available)
	if count==0: return fail("Nada disponível fora da reserva")
	var cents=int(round(item_price(id)*100.0*(1.0+bonus("price"))))*count
	state.coins_cents+=cents
	if _offline_tracking: _offline_sale_cents+=cents
	state.inventory[id]-=count
	state.tutorial.sold=true
	reward.emit("sale",id,count,""); notify("sale")
	return success("Vendido por %.2f moedas" % (cents/100.0),{"quantity":count,"cents":cents})
func sell_excess() -> Dictionary:
	var before=int(state.coins_cents)
	for id in state.inventory: sell(id,int(state.inventory[id]),true)
	return success("Excedentes: +%.2f moedas" % ((int(state.coins_cents)-before)/100.0),{"cents":int(state.coins_cents)-before})
func set_objective(id: String) -> void:
	state.objective=id
	refresh_reserves()
func refresh_reserves() -> void:
	state.reserves=state.manual_reserves.duplicate(true)
	if GameData.REPAIRS.has(state.objective) and not has(state.objective):
		for id in GameData.REPAIRS[state.objective].items:
			state.reserves[id]=maxi(int(state.reserves.get(id,0)),int(GameData.REPAIRS[state.objective].items[id]))
func set_reserve(id: String, quantity: int) -> Dictionary:
	if not has("ENG2"): return fail("Requere ENG2 Conta certa; objetivo já reserva materiais")
	state.manual_reserves[id]=maxi(0,quantity)
	refresh_reserves(); notify("config")
	return success("Reserva global atualizada")
func repair_cost(id: String) -> int:
	return int(ceil(GameData.REPAIRS[id].coins*(1.0-bonus("repair"))))
func repair_status(id: String) -> String:
	if has(id): return "Concluído"
	var d=GameData.REPAIRS[id]
	var req=requirement_text(d.requires)
	if not req.is_empty(): return req
	var deficits: Array[String]=[]
	if coins()<repair_cost(id): deficits.append("%d moedas" % (repair_cost(id)-coins()))
	for item in d.items:
		var deficit=int(d.items[item])-int(state.inventory.get(item,0))
		if deficit>0: deficits.append("%d %s" % [deficit,GameData.item_name(item)])
	return "Faltam "+", ".join(deficits) if not deficits.is_empty() else "Pronto para restaurar"
func repair(id: String) -> Dictionary:
	if not GameData.REPAIRS.has(id) or has(id): return fail("Reparo indisponível")
	if repair_status(id)!="Pronto para restaurar": return fail(repair_status(id))
	state.coins_cents-=repair_cost(id)*100
	for item in GameData.REPAIRS[id].items: state.inventory[item]-=GameData.REPAIRS[id].items[item]
	state.repairs[id]=true
	for p in state.plots:
		if p.state=="locked" and block_unlocked(p.block): p.state="empty"
	if id=="R2": state.blocks.B1.machines.sprinkler.owned=true
	var index=int(id.substr(1))+1
	set_objective("R"+str(index) if index<=6 else "P8")
	reward.emit("repair",id,1,""); notify("purchase")
	return success(GameData.REPAIRS[id].result)
func upgrade_status(id: String) -> String:
	var d=upgrade_defs[id]
	var n=rank(id)
	if n>=d.costs.size(): return "Máximo"
	var req=requirement_text(d.requires)
	if not req.is_empty(): return req
	var available=state.listen_points if d.tree=="ESC" else coins()
	return "Faltam %d %s" % [d.costs[n]-available,"pontos" if d.tree=="ESC" else "moedas"] if available<d.costs[n] else "Comprar"
func buy_upgrade(id: String) -> Dictionary:
	if not upgrade_defs.has(id) or upgrade_status(id)!="Comprar": return fail(upgrade_status(id) if upgrade_defs.has(id) else "Melhoria desconhecida")
	var d=upgrade_defs[id]
	var cost=d.costs[rank(id)]
	if d.tree=="ESC": state.listen_points-=cost
	else: state.coins_cents-=cost*100
	state.upgrades[id]=rank(id)+1
	reward.emit("purchase",id,1,""); notify("purchase")
	return success(d.name+" adquirido")
func buy_tool() -> Dictionary:
	if state.tool_level>=4: return fail("Ferramenta no máximo")
	var d=GameData.TOOLS[state.tool_level+1]
	if not has(d.unlock): return fail("Requer "+d.unlock)
	if coins()<d.cost: return fail("Faltam %d moedas" % (d.cost-coins()))
	state.coins_cents-=d.cost*100; state.tool_level+=1
	notify("purchase"); reward.emit("purchase","tool",1,"")
	return success(d.name)
func clue_available(id: String) -> bool:
	if has(id): return false
	match id:
		"P1": return state.tutorial.first_harvest
		"P2": return has("R1")
		"P3": return has("R2") and state.pending_signals.has(id)
		"P4": return has("R3") and state.pending_signals.has(id)
		"P5": return has("R4")
		"P6": return has("R4") and has("P5") and state.pending_signals.has(id)
		"P7": return has("R5")
		"P8": return has("R6") and state.final_ready and state.valve_step==3 and all_previous_clues()
	return false
func inspect_clue(id: String) -> Dictionary:
	if not clue_available(id): return fail("Evidência ainda não disponível")
	state.clues[id]=true; state.listen_points+=3; state.pending_signals.erase(id)
	state.history.append({"id":id,"text":GameData.CLUES[id].text})
	if id=="P8": state.final_completed=true
	notify("clue"); reward.emit("clue",id,3,"")
	return success(GameData.CLUES[id].text,{"points":3})
func arm_pattern(block: String, pattern: String) -> Dictionary:
	if not block_unlocked(block): return fail("Bloco bloqueado")
	if pattern.is_empty(): state.blocks[block].armed_pattern=""; notify("config"); return success("Padrão desarmado; plantas preservadas")
	if not GameData.PATTERNS.has(pattern): return fail("Padrão desconhecido")
	var d=GameData.PATTERNS[pattern]
	if not has(d.unlock): return fail("Requer "+d.unlock)
	if block not in d.blocks: return fail("Use "+", ".join(d.blocks))
	if block=="B6" and not has("R6"): return fail("Restaure a cisterna R6 primeiro")
	state.blocks[block].armed_pattern=pattern; notify("config")
	return success("Padrão armado. Semeie A, B, C e D; coletor aguarda o lote completo")
func suggested_crop(plot_id: String, selected: String) -> String:
	var p=plot(plot_id)
	if p.is_empty(): return selected
	var pid=state.blocks[p.block].armed_pattern
	if not str(pid).is_empty() and rank("ESC6")>0: return GameData.PATTERNS[pid].recipe[GameData.POSITIONS.find(p.position)]
	return selected
func install_machine(block: String, kind: String) -> Dictionary:
	if not block_unlocked(block) or not GameData.MACHINE_COSTS.has(kind): return fail("Encaixe indisponível")
	if not has(GameData.MACHINE_UNLOCKS[kind]): return fail("Requer "+GameData.MACHINE_UNLOCKS[kind])
	if state.blocks[block].machines[kind].owned: return fail("Já instalada")
	var cost=GameData.MACHINE_COSTS[kind]
	if coins()<cost: return fail("Faltam %d moedas" % (cost-coins()))
	state.coins_cents-=cost*100; state.blocks[block].machines[kind].owned=true
	notify("purchase"); return success("Máquina instalada")
func configure_block(block: String, config: Dictionary) -> Dictionary:
	if not block_unlocked(block): return fail("Bloco bloqueado")
	var b=state.blocks[block]
	if config.has("preferred_crop") and crop_unlocked(config.preferred_crop): b.preferred_crop=config.preferred_crop
	if config.has("paused"): b.paused=bool(config.paused)
	for k in GameData.MACHINE_COSTS:
		if config.has(k): b.machines[k].enabled=bool(config[k])
	if config.has("seed_reserve") and has("ENG2"): state.seed_reserve=maxi(0,int(config.seed_reserve))
	notify("config"); return success("Configuração aplicada ao próximo tick")
func transfer_machine(from_block: String, to_block: String, kind: String) -> Dictionary:
	if not block_unlocked(to_block) or from_block==to_block: return fail("Destino indisponível")
	var source=state.blocks[from_block].machines[kind]
	var target=state.blocks[to_block].machines[kind]
	if not source.owned or target.owned: return fail("Encaixe já ocupado ou origem vazia")
	state.blocks[to_block].machines[kind]=source.duplicate(true)
	state.blocks[from_block].machines[kind]={"owned":false,"enabled":true,"timer":0.0,"status":"Não instalado"}
	notify("config"); return success("Transferida sem tick adicional")
func copy_block(block: String) -> Dictionary:
	if not has("ENG10"): return fail("Requer ENG10")
	var b=state.blocks[block]
	for id in state.blocks:
		if not block_unlocked(id) or id==block: continue
		state.blocks[id].preferred_crop=b.preferred_crop; state.blocks[id].paused=b.paused
		for k in GameData.MACHINE_COSTS: state.blocks[id].machines[k].enabled=b.machines[k].enabled
	notify("config"); return success("Opções copiadas; plantas e máquinas preservadas")
func clear_block(block: String, confirmed: bool = false) -> Dictionary:
	if not confirmed: return fail("Confirme remoção: sementes já gastas não são devolvidas")
	if block=="B6" and not state.final_ready:
		state.final_lot={}; state.final_harvested={}; state.valve_step=0
	for p in block_plots(block):
		if p.state!="locked": p.state="empty"; p.crop=""; p.remaining=0.0; p.compost=false; p.pattern_bonus=1.0
	state.blocks[block].armed_pattern=""
	notify("config"); return success("Plantio removido sem reembolso")
func collect_material(id: String, seconds: float = 2.0) -> Dictionary:
	if id not in ["wood","stone"]: return fail("Material desconhecido")
	_material_timers[id]+=maxf(0,seconds)
	var count=int(_material_timers[id]/2.0)
	_material_timers[id]=fmod(_material_timers[id],2.0)
	state.inventory[id]+=count
	if count>0: reward.emit("harvest",id,count,""); notify("material")
	return success("+%d %s" % [count,GameData.item_name(id)],{"quantity":count})
func buy_material(id: String, quantity: int = 1) -> Dictionary:
	if id not in ["wood","stone","fiber"]: return fail("Material não vendido")
	var cost=GameData.ITEMS[id].buy*maxi(1,quantity)
	if coins()<cost: return fail("Faltam moedas")
	state.coins_cents-=cost*100; state.inventory[id]+=maxi(1,quantity)
	notify("purchase"); return success("Materiais comprados")
func craft(id: String, batches: int = 1, block: String = "B1") -> Dictionary:
	batches=clampi(batches,1,999)
	if id=="REC3":
		if not has("R1"): return fail("Requer R1")
		if coins()<20: return fail("Faltam moedas")
		if state.blocks[block].label: return fail("Etiqueta já instalada")
		state.coins_cents-=2000; state.blocks[block].label=true; notify("purchase"); return success("Etiqueta persistente instalada")
	if not has("R3"): return fail("Requer R3")
	if id=="REC1":
		if state.inventory.C5<6*batches: return fail("Cada lote requer 6 linhos")
		state.inventory.C5-=6*batches; state.inventory.fiber+=3*batches
	elif id=="REC2":
		if state.inventory.C1<8*batches or state.inventory.C2<4*batches: return fail("Cada lote requer 8 nabos e 4 feijões")
		state.inventory.C1-=8*batches; state.inventory.C2-=4*batches; state.inventory.compost+=batches*(2 if has("CUL7") else 1)
	else: return fail("Receita desconhecida")
	notify("purchase"); return success("Fabricação concluída")
func apply_compost(block: String) -> Dictionary:
	if not block_unlocked(block): return fail("Bloco bloqueado")
	var b=state.blocks[block]
	if not b.compound_positions.is_empty(): return fail("Composto já preparado")
	for p in block_plots(block):
		if p.state!="empty": return fail("Aplique com as quatro parcelas vazias")
	if state.inventory.compost<1: return fail("Fabrique composto na oficina")
	state.inventory.compost-=1; b.compound_positions=GameData.POSITIONS.duplicate()
	notify("config"); return success("Próximas quatro plantas: crescimento −10%, teto 25%")
func buy_decoration(id: String) -> Dictionary:
	if not has("R3"): return fail("Requer R3")
	if not GameData.DECO.has(id) or state.deco.has(id): return fail("Decoração indisponível")
	if coins()<200: return fail("Faltam %d moedas" % (200-coins()))
	state.coins_cents-=20000; state.deco[id]=true; notify("purchase"); return success(GameData.DECO[id]+" instalada")
func catch_fish() -> Dictionary:
	if not has("R4"): return fail("Requer R4")
	var index=[1,1,2,3][int(state.fish_count)%4]
	var id="fish_"+str(index)
	state.fish_count+=1; state.inventory[id]+=1; state.fish_collection[id]=true
	notify("fish"); reward.emit("harvest",id,1,"B5")
	return success("+1 "+GameData.item_name(id),{"fish":id})
func valve(index: int) -> Dictionary:
	if not has("R6") or not state.final_ready: return fail("Prepare PA3 em B6 e colha as quatro plantas")
	if state.final_completed: return fail("A água já segue adiante")
	if not all_previous_clues():
		var missing: Array[String]=[]
		for clue in ["P1","P2","P3","P4","P5","P6","P7"]:
			if not has(clue): missing.append(clue+" "+str(GameData.CLUES[clue].name))
		return fail("Examine antes: "+", ".join(missing)+". Lote preservado.")
	if index!=state.valve_step+1:
		state.valve_step=0; notify("config"); return fail("Ordem reiniciada; lote preservado. Use I → II → III")
	state.valve_step=index
	if index==3: return inspect_clue("P8")
	notify("config"); return success("Válvula %d aberta" % index)
func all_previous_clues() -> bool:
	for id in ["P1","P2","P3","P4","P5","P6","P7"]:
		if not has(id): return false
	return true
func apply_offline(now: int) -> Dictionary:
	var reference=int(state.get("offline_reference",state.last_saved_at))
	var elapsed=clampi(now-reference,0,1800)
	state.offline_reference=now
	var cents_before=int(state.coins_cents)
	_offline_produced={}; _offline_sale_cents=0
	var computed=0
	if has("ENG9") and state.offline_enabled:
		computed=int(floor(elapsed*0.25))
		_offline_tracking=true
		advance(float(computed),true)
	_offline_tracking=false
	var summary={"real_seconds":elapsed,"computed_seconds":computed,"produced":_offline_produced.duplicate(true),"coins_cents":_offline_sale_cents,"net_coins_cents":int(state.coins_cents)-cents_before}
	state.last_offline_summary=summary
	return summary
func export_state() -> Dictionary:
	return state.duplicate(true)
func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and not is_nan(float(value)) and not is_inf(float(value))
func import_state(data: Dictionary) -> Dictionary:
	for field in ["schema_version","slot_id","created_at","last_saved_at","offline_reference","total_active_seconds","coins_cents","listen_points","tool_level","seed_reserve","valve_step","fish_count","sale_timer","lot_counter"]:
		if data.has(field) and not valid_number(data[field]): return fail("Número inválido em "+field+"; recupere backup")
	if int(data.get("schema_version",1))>GameData.SCHEMA_VERSION: return fail("Versão de save mais recente; arquivo preservado")
	if not data.has("plots") or not data.plots is Array: return fail("Save inválido: canteiros ausentes")
	for field in ["inventory","reserves","manual_reserves","repairs","clues","upgrades","blocks","pending_signals","patterns_completed","tutorial","final_lot","final_harvested","fish_collection","deco","last_offline_summary"]:
		if data.has(field) and not data[field] is Dictionary: return fail("Save inválido em "+field+"; arquivo preservado")
	for field in ["history","player"]:
		if data.has(field) and not data[field] is Array: return fail("Save inválido em "+field+"; arquivo preservado")
	if data.has("player") and data.player.size()!=2: return fail("Posição inválida; recupere backup")
	if data.has("player"):
		for coordinate in data.player:
			if not valid_number(coordinate): return fail("Posição inválida; recupere backup")
	for field in ["inventory","manual_reserves","reserves","upgrades"]:
		if data.has(field):
			for id in data[field]:
				if not valid_number(data[field][id]): return fail("Quantidade inválida em "+field+"; recupere backup")
	if data.has("blocks"):
		for bid in GameData.BLOCKS:
			if not data.blocks.has(bid): continue
			var block=data.blocks[bid]
			if not block is Dictionary: return fail("Bloco inválido; recupere backup")
			if block.has("machines"):
				if not block.machines is Dictionary: return fail("Máquinas inválidas; recupere backup")
				for kind in GameData.MACHINE_COSTS:
					if block.machines.has(kind) and not block.machines[kind] is Dictionary: return fail("Máquina inválida; recupere backup")
					if block.machines.has(kind) and block.machines[kind].has("timer") and not valid_number(block.machines[kind].timer): return fail("Relógio de máquina inválido; recupere backup")
			if block.has("compound_positions") and not block.compound_positions is Array: return fail("Composto inválido; recupere backup")
	for p in data.plots:
		if not p is Dictionary: return fail("Canteiro inválido; recupere backup")
		if p.has("remainders") and not p.remainders is Dictionary: return fail("Restos de produção inválidos; recupere backup")
		for field in ["remaining","duration","lot","pattern_bonus"]:
			if p.has(field) and not valid_number(p[field]): return fail("Número de canteiro inválido; recupere backup")
		if p.has("remainders"):
			for id in p.remainders:
				if not valid_number(p.remainders[id]): return fail("Resto fracionário inválido; recupere backup")
	new_game(clampi(int(data.get("slot_id",1)),1,3))
	var defaults=state.duplicate(true)
	for key in data: state[key]=data[key]
	state.coins_cents=maxi(0,int(state.get("coins_cents",2400)))
	for id in defaults.inventory: state.inventory[id]=maxi(0,int(state.inventory.get(id,0)))
	state.tool_level=clampi(int(state.tool_level),0,4)
	for id in upgrade_defs: state.upgrades[id]=clampi(int(state.upgrades.get(id,0)),0,upgrade_defs[id].costs.size())
	state.listen_points=clampi(int(state.listen_points),0,24)
	for id in defaults.blocks:
		if not state.blocks.has(id): state.blocks[id]=defaults.blocks[id]
		else:
			for key in defaults.blocks[id]:
				if not state.blocks[id].has(key): state.blocks[id][key]=defaults.blocks[id][key]
			for kind in defaults.blocks[id].machines:
				if not state.blocks[id].machines.has(kind): state.blocks[id].machines[kind]=defaults.blocks[id].machines[kind]
				else:
					for field in defaults.blocks[id].machines[kind]:
						if not state.blocks[id].machines[kind].has(field): state.blocks[id].machines[kind][field]=defaults.blocks[id].machines[kind][field]
			state.blocks[id].compound_positions=state.blocks[id].compound_positions.filter(func(pos): return pos in GameData.POSITIONS)
			if not crop_unlocked(state.blocks[id].preferred_crop): state.blocks[id].preferred_crop="C1"
	state.unknown_plot_records=[]
	var known_plot_ids: Array=[]
	for p in defaults.plots: known_plot_ids.append(p.id)
	for entry in data.plots:
		if entry.get("id","") not in known_plot_ids: state.unknown_plot_records.append(entry.duplicate(true))
	var safe_plots=[]
	for original in defaults.plots:
		var found={}
		for p in data.plots:
			if p is Dictionary and p.get("id","")==original.id: found=p; break
		var merged=original.duplicate(true); merged.merge(found,true)
		merged.id=original.id; merged.block=original.block; merged.position=original.position
		if merged.state not in ["locked","empty","water","growing","mature"]: merged.state="empty"
		if not block_unlocked(merged.block): merged.state="locked"
		if merged.state in ["water","growing","mature"] and not GameData.CROPS.has(merged.crop): merged.state="empty"; merged.crop=""
		merged.remaining=maxf(0,float(merged.remaining))
		merged.duration=maxf(0,float(merged.duration))
		merged.pattern_bonus=clampf(float(merged.pattern_bonus),1.0,1.15)
		for crop in merged.remainders: merged.remainders[crop]=clampf(float(merged.remainders[crop]),0,0.99999999)
		safe_plots.append(merged)
	state.plots=safe_plots
	var pos=state.player
	state.player=[clampf(float(pos[0]),0.5,47.5),clampf(float(pos[1]),0.5,47.5)]
	refresh_reserves()
	return success("Save carregado; valores normalizados")
