# Controla os estados do jogo (título, exploração, cena, diálogo, baú, combate, celular) e o estado da Branca.
extends Node

const Data := preload("res://scripts/data.gd")
const World := preload("res://scripts/world.gd")
const Combat := preload("res://scripts/combat.gd")
const Hud := preload("res://scripts/hud.gd")
const Phone := preload("res://scripts/phone.gd")
const Title := preload("res://scripts/title.gd")
const Dialogue := preload("res://scripts/dialogue.gd")
const Bau := preload("res://scripts/bau.gd")
const Cena := preload("res://scripts/cena.gd")
const Areas := preload("res://scripts/areas.gd")

const SAVE_PATH := "user://save.json"
const START_AREA := "margem_do_lago"  # onde o jogo começa
const START_CENA := "abertura"  # cena de abertura (cenas/abertura.json)
const MAX_HP := 100.0
const MAX_STAMINA := 100.0
const DEATH_PENALTY := 0.25  # parte do dinheiro perdida a cada morte na luta

var state := "title"
var hp := MAX_HP
var stamina := MAX_STAMINA
var money := 0
var messages: Array = []
var area_id := ""
var missao := ""  # missão atual mostrada na tela (vazia = nenhuma)
var taken: Array = []  # dinheiro já pego ("área:x,y")
var flags: Dictionary = {}  # marcas da história e dos diálogos ("marcar" nos arquivos de diálogo)
var inventory: Array = []  # ids de Data.ITENS, no máximo Data.INV_SLOTS
var chest: Array = []  # o baú dos pontos de sinal (sem limite)
var taken_items: Array = []  # itens do chão já pegos ("i,j" da casa no mapa)
var effects: Dictionary = {}  # efeitos ativos de itens: "amuleto" -> cargas restantes, "cha" -> true
var volume := 0.8
var toasts: Array = []  # [texto, tempo]
var enemy_types: Dictionary = {}  # res://dados/inimigos.json

var world: Node2D
var combat: Node2D
var hud: Control
var phone: Control
var title: Control
var dialogue: Control
var bau: Control
var cena: Control
var music: AudioStreamPlayer
var sfx: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_types = Areas.load_enemy_types()
	music = AudioStreamPlayer.new()
	music.stream = load("res://audio/ambiente.wav")
	music.volume_db = -6.0
	music.finished.connect(func(): if state != "combat": music.play())
	add_child(music)
	for n in ["acerto", "erro", "lanterna", "moeda", "sinal", "clique", "alerta", "fala", "item", "curar", "absorver", "queda"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	sfx["acerto"].volume_db = -8.0
	sfx["fala"].volume_db = -14.0

	world = World.new()
	world.main = self
	add_child(world)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

	var dialogue_layer := CanvasLayer.new()
	dialogue_layer.layer = 4
	add_child(dialogue_layer)
	dialogue = Dialogue.new()
	dialogue.main = self
	dialogue.visible = false
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue_layer.add_child(dialogue)

	var bau_layer := CanvasLayer.new()
	bau_layer.layer = 6
	add_child(bau_layer)
	bau = Bau.new()
	bau.main = self
	bau.visible = false
	bau_layer.add_child(bau)

	var combat_layer := CanvasLayer.new()
	combat_layer.layer = 5
	add_child(combat_layer)
	combat = Combat.new()
	combat.main = self
	combat.visible = false
	combat.ended.connect(_on_combat_ended)
	combat_layer.add_child(combat)

	var phone_layer := CanvasLayer.new()
	phone_layer.layer = 10
	add_child(phone_layer)
	phone = Phone.new()
	phone.main = self
	phone.visible = false
	phone_layer.add_child(phone)

	var cena_layer := CanvasLayer.new()
	cena_layer.layer = 15
	add_child(cena_layer)
	cena = Cena.new()
	cena.main = self
	cena_layer.add_child(cena)

	var title_layer := CanvasLayer.new()
	title_layer.layer = 20
	add_child(title_layer)
	title = Title.new()
	title.main = self
	title_layer.add_child(title)

	set_volume(volume)
	set_state("title")


const ZOOM_NORMAL := Vector2(1.7, 1.7)
const ZOOM_PHONE := Vector2(3.0, 3.0)
var cam_tween: Tween


func set_state(s: String) -> void:
	var prev := state
	state = s
	if s == "phone" and prev == "explore":
		_phone_camera(true)
		world.queue_redraw()  # garante a Branca visível no quadro congelado
	elif prev == "phone":
		_phone_camera(false)
	world.process_mode = Node.PROCESS_MODE_INHERIT if s == "explore" or s == "cena" else Node.PROCESS_MODE_DISABLED
	world.visible = s != "combat"
	hud.visible = s == "explore" or s == "phone"
	combat.visible = s == "combat"
	phone.visible = s == "phone"
	dialogue.visible = s == "dialogue"
	bau.visible = s == "chest"
	title.visible = s == "title"
	if (s == "explore" or s == "title") and music.stream and not music.playing:
		music.play()


# Zoom da câmera na Branca enquanto o celular está aberto.
func _phone_camera(open: bool) -> void:
	if cam_tween:
		cam_tween.kill()
	cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(world.cam, "zoom", ZOOM_PHONE if open else ZOOM_NORMAL, 0.4)
	cam_tween.tween_property(world.cam, "offset", Vector2(80, -12) if open else Vector2.ZERO, 0.4)
	cam_tween.tween_property(phone, "slide", 1.0 if open else 0.0, 0.3)


func _process(delta: float) -> void:
	for t in toasts:
		t[1] -= delta
	toasts = toasts.filter(func(t): return t[1] > 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.physical_keycode
	match state:
		"title":
			title.handle_key(k)
		"explore":
			if k == KEY_TAB or k == KEY_ESCAPE:
				play_sfx("clique")
				phone.open()
				set_state("phone")
			else:
				world.handle_key(k)
		"phone":
			phone.handle_key(k)
		"dialogue":
			dialogue.handle_key(k)
		"chest":
			bau.handle_key(k)
		"combat":
			combat.handle_key(k)


func toast(text: String) -> void:
	toasts.append([text, 3.5])


func play_sfx(n: String) -> void:
	if sfx.has(n):
		sfx[n].play()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


# ---------- novo jogo / save ----------

func new_game() -> void:
	hp = MAX_HP
	stamina = MAX_STAMINA
	money = 0
	messages = []
	taken = []
	flags = {}
	inventory = []
	chest = []
	taken_items = []
	effects = {}
	area_id = START_AREA
	missao = ""
	world.load_area(area_id)
	_area_music()
	set_state("explore")
	if START_CENA != "":
		start_cena(START_CENA)
	else:
		_enter_area_cena()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"hp": hp, "money": money, "messages": messages, "taken": taken, "flags": flags, "area": area_id, "missao": missao,
		"inventory": inventory, "chest": chest, "taken_items": taken_items, "effects": effects,
		"pos": [world.player_pos.x, world.player_pos.y], "volume": volume,
	}))


func load_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		new_game()
		return
	hp = d.get("hp", MAX_HP)
	money = int(d.get("money", 0))
	messages = d.get("messages", [])
	taken = d.get("taken", [])
	flags = d.get("flags", {})
	area_id = d.get("area", START_AREA)
	missao = d.get("missao", "")
	inventory = d.get("inventory", [])
	chest = d.get("chest", [])
	taken_items = d.get("taken_items", [])
	effects = d.get("effects", {})
	set_volume(d.get("volume", volume))
	stamina = MAX_STAMINA
	var p: Array = d.get("pos", [])
	world.load_area(area_id, Vector2(p[0], p[1]) if p.size() == 2 else null)
	_area_music()
	set_state("explore")
	toast("Jogo carregado")


func on_signal_point() -> void:
	save_game()
	play_sfx("sinal")
	toast("O celular pegou sinal. Jogo salvo.")


# ---------- itens e baú ----------

# Coloca um item no inventário. Retorna false se não houver espaço.
func add_item(id: String) -> bool:
	if inventory.size() >= Data.INV_SLOTS:
		return false
	inventory.append(id)
	return true


# Usa o item da vaga `i` pelo celular. Retorna o aviso para mostrar na tela.
func use_item(i: int) -> String:
	var it: Dictionary = Data.ITENS[inventory[i]]
	if it.has("efeito"):
		var ef: String = it.efeito
		if effects.has(ef):
			return "%s já está fazendo efeito." % it.nome
		effects[ef] = Data.EFEITOS[ef].get("cargas", true)
		inventory.remove_at(i)
		play_sfx("curar")
		return "Usou %s." % it.nome.to_lower()
	if hp >= MAX_HP:
		return "A vida já está cheia."
	hp = minf(MAX_HP, hp + it.curar)
	inventory.remove_at(i)
	play_sfx("curar")
	return "Usou %s." % it.nome.to_lower()


func open_chest() -> void:
	play_sfx("clique")
	bau.open()
	set_state("chest")


func close_chest() -> void:
	play_sfx("clique")
	set_state("explore")
	world.invuln = maxf(world.invuln, 0.4)


# ---------- diálogo ----------

func start_dialogue(id: String) -> void:
	if dialogue.start(id):
		set_state("dialogue")


func _on_dialogue_finished(_id: String) -> void:
	set_state("cena" if cena.running != "" else "explore")
	world.invuln = maxf(world.invuln, 0.6)


# ---------- áreas e cenas ----------

# Passa para outra área com a tela escurecendo.
func change_area(id: String, ponto := "inicio") -> void:
	set_state("transition")
	await cena.fade(1.0, 0.35)
	area_id = id
	world.load_area(id, null, ponto)
	_area_music()
	set_state("explore")
	await cena.fade(0.0, 0.35)
	_enter_area_cena()


# Cena que a área pede ao entrar ("ao_entrar" no arquivo da área), se ainda não foi vista.
func _enter_area_cena() -> void:
	var c: Dictionary = world.area.get("ao_entrar", {})
	if c.has("cena") and not flags.get(c.get("se_nao", ""), false):
		start_cena(c.cena)


func start_cena(id: String) -> void:
	await cena.play(id)


# Música da área ("musica" no arquivo da área). Sem o campo, continua a que estiver tocando.
func _area_music() -> void:
	var m: String = world.area.get("musica", "")
	if m != "" and (music.stream == null or music.stream.resource_path != m):
		play_music(m)


func play_music(path: String) -> void:
	if path == "":
		music.stop()
		music.stream = null
		return
	music.stream = load(path)
	music.play()


# ---------- combate ----------

func start_combat(enemy: Dictionary) -> void:
	if not enemy_types.has(enemy.kind):
		push_error("Tipo de inimigo desconhecido: " + enemy.kind)
		return
	music.stop()
	play_sfx("alerta")
	set_state("combat")
	combat.start(enemy, 0.6 if enemy.stun > 0.0 else 1.0)


func death_penalty() -> int:
	var lost := int(ceil(money * DEATH_PENALTY))
	money -= lost
	return lost


func _on_combat_ended(enemy: Dictionary, reward: int) -> void:
	effects.erase("cha")  # o chá dura uma luta; o amuleto dura até gastar as cargas
	money += reward
	world.enemy_defeated(enemy)
	set_state("explore")
	if reward > 0:
		toast("+%d de dinheiro" % reward)
