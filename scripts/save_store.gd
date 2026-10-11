class_name FarmSaveStore
extends RefCounted
var directory: String = "user://saves"
func _init(path: String = "user://saves") -> void:
	directory=path
	DirAccess.make_dir_recursive_absolute(directory)
func slot_path(slot: int) -> String:
	return directory+"/slot_%d.json" % clampi(slot,1,3)
func save_slot(slot: int, data: Dictionary) -> Dictionary:
	var path=slot_path(slot)
	var temp=path+".tmp"
	var record=data.duplicate(true)
	record.last_saved_at=int(Time.get_unix_time_from_system())
	var file=FileAccess.open(temp,FileAccess.WRITE)
	if file==null: return {"ok":false,"message":"Não foi possível gravar. Último save preservado."}
	file.store_string(JSON.stringify(record,"\t")); file.flush(); file.close()
	var check=_read(temp)
	if not check.ok: return {"ok":false,"message":"Falha na validação do novo save; último preservado"}
	if FileAccess.file_exists(path):
		var err=DirAccess.copy_absolute(path,path+".bak")
		if err!=OK: return {"ok":false,"message":"Falha ao criar backup; último save preservado"}
	var err=DirAccess.rename_absolute(temp,path)
	return {"ok":err==OK,"message":"Salvo" if err==OK else "Falha de gravação; recupere backup", "data":record}
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok":false,"message":"Slot vazio"}
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return {"ok":false,"message":"Não foi possível ler o save"}
	var parser=JSON.new()
	var err=parser.parse(file.get_as_text()); file.close()
	if err!=OK or not parser.data is Dictionary or not parser.data.has("plots") or not parser.data.plots is Array:
		return {"ok":false,"message":"Save corrompido. Recupere o backup; arquivo preservado."}
	for key in ["inventory","repairs","clues","upgrades","blocks"]:
		if parser.data.has(key) and not parser.data[key] is Dictionary:return {"ok":false,"message":"Estrutura de save inválida: "+key+". Arquivo preservado; recupere backup."}
	if typeof(parser.data.get("coins_cents",0)) not in [TYPE_INT,TYPE_FLOAT]:return {"ok":false,"message":"Saldo inválido. Arquivo preservado; recupere backup."}
	return {"ok":true,"message":"Carregado","data":parser.data}
func load_slot(slot: int, recover_backup: bool = false) -> Dictionary:
	var path=slot_path(slot)
	var r=_read(path+".bak" if recover_backup else path)
	r["backup_available"]=FileAccess.file_exists(path+".bak")
	return r
func slot_summary(slot: int) -> String:
	var r=load_slot(slot)
	if not r.ok: return r.message
	return "%d moedas · %d/8 pistas · %.0f min" % [int(r.data.get("coins_cents",0)/100),r.data.get("clues",{}).size(),float(r.data.get("total_active_seconds",0))/60 if typeof(r.data.get("total_active_seconds",0)) in [TYPE_INT,TYPE_FLOAT] else 0.0]
func preferences_path() -> String:
	return directory+"/preferences.json"
func load_preferences() -> Dictionary:
	var defaults={"ui_scale":1.0,"text_scale":1.0,"high_contrast":false,"reduced_motion":false,"reduced_particles":false,"instant_text":true,"fish_assist":false,"toggle_action":false,"captions":true,"music_volume":0.5,"ambience_volume":0.5,"interface_volume":0.6,"shirt":"default","tutorial":true,"bindings":{},"offline_enabled":true,"text_speed":50,"minimap_visible":true}
	if not FileAccess.file_exists(preferences_path()):return defaults
	var value=JSON.parse_string(FileAccess.get_file_as_string(preferences_path()))
	if not value is Dictionary:
		defaults.recovery_notice="Opções corrompidas: defaults seguros em uso; arquivo original preservado."
		return defaults
	var invalid=false
	for key in defaults:
		if not value.has(key):continue
		var v=value[key]
		match key:
			"ui_scale","text_scale":
				if typeof(v) in [TYPE_INT,TYPE_FLOAT] and float(v) in [1.0,1.25,1.5]:defaults[key]=float(v)
				else:invalid=true
			"music_volume","ambience_volume","interface_volume":
				if typeof(v) in [TYPE_INT,TYPE_FLOAT]:defaults[key]=clampf(float(v),0,1)
				else:invalid=true
			"text_speed":
				if typeof(v) in [TYPE_INT,TYPE_FLOAT]:defaults[key]=clampi(int(v),20,100)
				else:invalid=true
			"shirt":
				if v is String and v in ["default","ochre","blue"]:defaults[key]=v
				else:invalid=true
			"bindings":
				if v is Dictionary:
					for action in v:
						var codes=v[action]
						if not codes is Array or codes.is_empty():invalid=true;continue
						var valid=true
						for code in codes:
							if typeof(code) not in [TYPE_INT,TYPE_FLOAT] or int(code)==0 or int(code)< -9 or int(code)>67108863:valid=false
						if valid:defaults.bindings[action]=codes
						else:invalid=true
				else:invalid=true
			_:
				if typeof(v)==TYPE_BOOL:defaults[key]=v
				else:invalid=true
	if invalid:defaults.recovery_notice="Opções inválidas normalizadas; arquivo original preservado até salvar suas escolhas."
	return defaults
func save_preferences(data: Dictionary) -> Dictionary:
	var file=FileAccess.open(preferences_path(),FileAccess.WRITE)
	if file==null: return {"ok":false,"message":"Não foi possível salvar opções"}
	file.store_string(JSON.stringify(data,"\t")); file.flush(); file.close()
	return {"ok":true,"message":"Opções salvas"}

func restore_backup(slot: int) -> Dictionary:
	var path=slot_path(slot)
	var backup=path+".bak"
	var result=_read(backup)
	if not result.ok:return result
	var temporary=path+".restore.tmp"
	if DirAccess.copy_absolute(backup,temporary)!=OK:return {"ok":false,"message":"Não foi possível preparar recuperação; arquivos preservados"}
	if FileAccess.file_exists(path):
		var archive=path+".damaged_%d" % int(Time.get_unix_time_from_system())
		if DirAccess.rename_absolute(path,archive)!=OK:return {"ok":false,"message":"Não foi possível preservar arquivo anterior; recuperação cancelada"}
	var error=DirAccess.rename_absolute(temporary,path)
	return {"ok":error==OK,"message":"Backup recuperado; arquivo anterior preservado" if error==OK else "Recuperação não concluída; backup preservado"}
