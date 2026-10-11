class_name GameData
extends RefCounted

const SCHEMA_VERSION = 1
const CROPS = {
"C1":{"name":"Nabo","unlock":"","seed":2,"time":24.0,"yield":4,"price":2},
"C2":{"name":"Feijão","unlock":"R1","seed":8,"time":40.0,"yield":6,"price":3},
"C3":{"name":"Milho","unlock":"R2","seed":12,"time":56.0,"yield":5,"price":5},
"C4":{"name":"Abóbora","unlock":"R3","seed":20,"time":80.0,"yield":4,"price":10},
"C5":{"name":"Linho","unlock":"R3","seed":10,"time":64.0,"yield":6,"price":4},
"C6":{"name":"Flor de sino","unlock":"R4","seed":16,"time":48.0,"yield":3,"price":9}}
const ITEMS = {"wood":{"name":"Madeira","price":1,"buy":6},"stone":{"name":"Pedra","price":1,"buy":6},"fiber":{"name":"Fibra","price":4,"buy":12},"fish_1":{"name":"Peixe de margem","price":12},"fish_2":{"name":"Peixe prateado","price":18},"fish_3":{"name":"Peixe de fundo","price":24},"compost":{"name":"Composto","price":0}}
const REPAIRS = {
"R1":{"name":"Limpar horta","coins":120,"items":{"C1":16},"requires":[],"result":"Horta baixa, 8 canteiros e feijão"},
"R2":{"name":"Abrir canal baixo","coins":450,"items":{"C2":24,"wood":6},"requires":["R1","P2"],"result":"Água, aspersor em B1, milho e padrões"},
"R3":{"name":"Recuperar oficina","coins":1800,"items":{"C3":30,"wood":12,"stone":6},"requires":["R2","P3"],"result":"Pomar, 16 canteiros, abóbora, linho e receitas"},
"R4":{"name":"Recuperar ponte","coins":4500,"items":{"fiber":18,"stone":10},"requires":["R3","P4"],"result":"Margem, 20 canteiros, pesca e flor de sino"},
"R5":{"name":"Reabrir campo alto","coins":14000,"items":{"C4":40,"fiber":12,"wood":10},"requires":["R4","P6"],"result":"Campo alto, 24 canteiros e cisterna"},
"R6":{"name":"Restaurar cisterna","coins":30000,"items":{"C6":30,"C3":20,"stone":12},"requires":["R5","P7"],"result":"Prepare PA3 em B6; colha e acione I → II → III"}}
const BLOCKS = {"B1":{"name":"Terreiro","origin":[14,34],"unlock":""},"B2":{"name":"Horta baixa","origin":[24,33],"unlock":"R1"},"B3":{"name":"Pomar oeste","origin":[22,17],"unlock":"R3"},"B4":{"name":"Pomar leste","origin":[29,17],"unlock":"R3"},"B5":{"name":"Margem","origin":[12,18],"unlock":"R4"},"B6":{"name":"Cisterna","origin":[40,17],"unlock":"R5"}}
const POSITIONS = ["A","B","C","D"]
const OFFSETS = {"A":[0,0],"B":[1,0],"C":[0,1],"D":[1,1]}
const PATTERNS = {
"PA1":{"name":"Voz do canal","recipe":["C1","C2","C1","C2"],"blocks":["B1","B2"],"unlock":"R2","clue":"P3"},
"PA2":{"name":"Rastro de tecido","recipe":["C3","C5","C5","C3"],"blocks":["B3","B4"],"unlock":"R3","clue":"P4"},
"PA3":{"name":"Última chuva","recipe":["C6","C3","C2","C6"],"blocks":["B5","B6"],"unlock":"R4","clue":"P6"}}
const CLUES = {
"P1":{"name":"Bilhete de chegada","text":"Cuide do que ainda cresce. — Tomás\nLia: Tomás preparou a cessão antes de partir. Ele deixou instruções entre suas ferramentas."},
"P2":{"name":"Tábuas marcadas","text":"Riscos na madeira registram antigos níveis d'água. Um desenho alterna nabo e feijão: A nabo; B feijão; C nabo; D feijão. Abrir o canal pode revelar sua voz."},
"P3":{"name":"Voz no canal","text":"A água repete o gesto de fechar uma comporta.\nTomás: Não repita o mesmo dia. Nem a água sabe esquecer.\nO registro conduz à oficina; não é alguém presente."},
"P4":{"name":"Tecido da oficina","text":"Uma fita de linho envolve peças desmontadas. Tomás isolou as máquinas deliberadamente. O desenho cruza milho e linho; a ponte guarda o próximo registro."},
"P5":{"name":"Recibo de viagem","text":"O recibo tem data posterior ao fechamento dos canais e destino fora do vale. Tomás estava vivo quando partiu. Rui reconhece a assinatura, mas a água ainda conserva seu gesto."},
"P6":{"name":"Reflexo impossível","text":"No lago, o canal antigo aparece sobre o canal restaurado. O mesmo gesto atravessa tempos distintos. São memórias preservadas, não presença atual. O campo alto reúne os canais."},
"P7":{"name":"Carta lacrada","text":"Eu tentei repetir um dia feliz. A cisterna repetiu também meus erros. Isolei os canais e parti para me recuperar. A fazenda é sua.\nÚltima chuva em B6: A flor; B milho; C feijão; D flor. Colha o lote e abra as válvulas I, II e III, nessa ordem. — Tomás"},
"P8":{"name":"Último registro","text":"O gesto termina: Tomás deixa a ferramenta e parte. A água segue adiante.\nLia: Recebi uma carta recente. Ele está vivo, em recuperação, e agradece por cuidar do que ainda cresce.\nA fazenda continua sua; cultive sem pressa."}}
const MACHINE_COSTS = {"sprinkler":250,"collector":600,"seeder":900}
const MACHINE_UNLOCKS = {"sprinkler":"R2","collector":"ENG3","seeder":"ENG5"}
const MACHINE_NAMES = {"sprinkler":"Aspersor","collector":"Coletor","seeder":"Semeador"}
const TOOLS = [{"name":"Instrumento gasto","cost":0,"unlock":"","area":1,"interval":0.8},{"name":"Cabo firme","cost":80,"unlock":"R1","area":1,"interval":0.6},{"name":"Cabeça dupla","cost":400,"unlock":"R2","area":2,"interval":0.6},{"name":"Lâmina larga","cost":1500,"unlock":"R3","area":4,"interval":0.45},{"name":"Instrumento calibrado","cost":4000,"unlock":"R5","area":4,"interval":0.3}]
const DECO = {"D1":"Vaso","D2":"Banco","D3":"Bandeirola","D4":"Espantalho","D5":"Lanterna","D6":"Placa da fazenda"}
static func upgrades() -> Dictionary:
	var d = {}
	var rows = [
	["CUL1","Sementes escolhidas",[60,120,240],["R1"],"yield",0.05],
	["CUL2","Terra solta",[100,200,400],["CUL1"],"growth",0.05],
	["CUL3","Mão treinada",[100,220],["CUL1"],"tool",0.1],
	["CUL4","Compra em lote",[180,360],["CUL2"],"seed",0.1],
	["CUL5","Safra abundante",[400,800,1200],["CUL2","R3"],"yield",0.1],
	["CUL6","Passo firme",[150,300],["CUL3"],"move",0.1],
	["CUL7","Composto eficiente",[350],["CUL4","R3"],"compost",1],
	["CUL8","Mercado local",[600,1200,1800],["CUL5"],"price",0.05],
	["CUL9","Raízes profundas",[1000,2000],["CUL5:2","R4"],"growth",0.05],
	["CUL10","Colheita plena",[2500],["CUL9","R5"],"yield",0.15],
	["ENG1","Canal aberto",[120],["R2"],"coverage",1],
	["ENG2","Conta certa",[200],["ENG1"],"reserve",1],
	["ENG3","Coletor simples",[700],["ENG1","R3"],"collector",1],
	["ENG4","Coletor ágil",[500,1000],["ENG3"],"collector_speed",1],
	["ENG5","Semeador",[1200],["ENG3","R3"],"seeder",1],
	["ENG6","Frete automático",[1200],["ENG2","ENG5"],"auto_sell",1],
	["ENG7","Montagem econômica",[450,900],["ENG3"],"repair",0.05],
	["ENG8","Replantio ágil",[900,1800],["ENG5","R4"],"seeder_speed",1],
	["ENG9","Rotina distante",[1500],["ENG6","R4"],"offline",1],
	["ENG10","Manutenção simples",[2000],["ENG8","R5"],"copy",1],
	["ESC1","Atenção",[1],["P1"],"evidence",1],
	["ESC2","Anotar",[1],["ESC1"],"hint",1],
	["ESC3","Relacionar",[2],["ESC2"],"group",1],
	["ESC4","Ouvido atento",[2],["ESC1"],"captions",1],
	["ESC5","Trilhas antigas",[2],["ESC3","P3"],"minimap",1],
	["ESC6","Preparar padrão",[3],["ESC2","P3"],"pattern_select",1],
	["ESC7","Harmonia",[3],["ESC6","P4"],"harmony",1],
	["ESC8","Rever memória",[3],["ESC4","P4"],"replay",1],
	["ESC9","Caminho claro",[3],["ESC5","P6"],"final_path",1],
	["ESC10","Guardião do registro",[4],["ESC8","P7"],"epilogue",1]]
	for r in rows:
		d[r[0]] = {"name":r[1],"costs":r[2],"requires":r[3],"group":r[4],"value":r[5],"tree":str(r[0]).substr(0,3)}
	return d
static func item_name(id: String) -> String:
	return CROPS.get(id, ITEMS.get(id, {"name":id})).name
static func plot_tile(plot_id: String) -> Vector2:
	var parts = plot_id.split("_")
	var o = BLOCKS[parts[0]].origin
	var v = OFFSETS[parts[1]]
	return Vector2(o[0]+v[0],o[1]+v[1])
