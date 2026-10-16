# Controla os estados do jogo (título, exploração, combate, celular) e o estado da Branca.
extends Node

const Data := preload("res://scripts/data.gd")
const World := preload("res://scripts/world.gd")
const Combat := preload("res://scripts/combat.gd")
const Hud := preload("res://scripts/hud.gd")
const Phone := preload("res://scripts/phone.gd")
const Title := preload("res://scripts/title.gd")

const SAVE_PATH := "user://save.json"
const MAX_HP := 100.0
const MAX_STAMINA := 100.0
const DEATH_PENALTY := 0.25  # parte do dinheiro perdida a cada morte na luta

var state := "title"
var hp := MAX_HP
var stamina := MAX_STAMINA
var money := 0
var messages: Array = []
var taken: Array = []  # dinheiro já pego no mapa
var volume := 0.8
var toasts: Array = []  # [texto, tempo]

var world: Node2D
var combat: Node2D
var hud: Control
var phone: Control
var title: Control
var music: AudioStreamPlayer
var sfx: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.stream = load("res://audio/ambiente.wav")
	music.volume_db = -6.0
	music.finished.connect(func(): if state != "combat": music.play())
	add_child(music)
	for n in ["acerto", "erro", "lanterna", "moeda", "sinal", "clique", "alerta"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	sfx["acerto"].volume_db = -8.0

	world = World.new()
	world.main = self
	add_child(world)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

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
	world.process_mode = Node.PROCESS_MODE_INHERIT if s == "explore" else Node.PROCESS_MODE_DISABLED
	world.visible = s != "combat"
	hud.visible = s == "explore" or s == "phone"
	combat.visible = s == "combat"
	phone.visible = s == "phone"
	title.visible = s == "title"
	if s == "explore" or s == "title":
		if not music.playing:
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
	world.reset(null)
	set_state("explore")
	toast("Missão: voltar para casa")


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"hp": hp, "money": money, "messages": messages, "taken": taken,
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
	set_volume(d.get("volume", volume))
	stamina = MAX_STAMINA
	var p: Array = d.get("pos", [])
	world.reset(Vector2(p[0], p[1]) if p.size() == 2 else null)
	set_state("explore")
	toast("Jogo carregado")


func on_signal_point() -> void:
	save_game()
	play_sfx("sinal")
	toast("O celular pegou sinal. Jogo salvo.")
	if messages.is_empty():
		var m: Dictionary = Data.MENSAGEM_SINAL.duplicate()
		m["lida"] = false
		messages.append(m)
		toast("Nova mensagem no celular [Tab]")


# ---------- combate ----------

func start_combat(enemy: Dictionary) -> void:
	music.stop()
	play_sfx("alerta")
	set_state("combat")
	var start_hp := 0.6 if enemy.stun > 0.0 else 1.0
	combat.start(enemy, start_hp)


func death_penalty() -> int:
	var lost := int(ceil(money * DEATH_PENALTY))
	money -= lost
	return lost


func _on_combat_ended(enemy: Dictionary, reward: int) -> void:
	money += reward
	world.enemy_defeated(enemy)
	set_state("explore")
	if reward > 0:
		toast("+%d de dinheiro" % reward)
