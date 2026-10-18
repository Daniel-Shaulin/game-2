# Cenas do jogo (cutscenes) e a tela preta das passagens entre áreas.
# Uma cena é uma lista de passos em res://cenas/<id>.json (formato em cenas/LEIAME.md),
# executados em ordem: tela preta, texto, câmera, personagens andando, diálogos, marcas, sons.
extends Control

signal finished(id: String)

const Areas := preload("res://scripts/areas.gd")
const INK := Color(0.85, 0.84, 0.8)

var main
var black := 0.0  # 0 = transparente, 1 = tela preta
var text := ""
var text_alpha := 0.0
var running := ""
var tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if black > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, black))
	if text != "" and text_alpha > 0.0:
		var f := ThemeDB.fallback_font
		var lines := text.split("\n")
		var y := 360.0 - (lines.size() - 1) * 18.0
		for l in lines:
			draw_string(f, Vector2(0, y + 1), l, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(0, 0, 0, text_alpha))
			draw_string(f, Vector2(0, y), l, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color(INK, text_alpha))
			y += 36.0


# Escurece (to = 1) ou clareia (to = 0) a tela.
func fade(to: float, time := 0.5) -> void:
	if tween:
		tween.kill()
	if time <= 0.0:
		black = to
		return
	tween = create_tween()
	tween.tween_property(self, "black", to, time)
	await tween.finished


func _show_text(t: String, time: float) -> void:
	text = t
	var tw := create_tween()
	tw.tween_property(self, "text_alpha", 1.0, 0.6)
	tw.tween_interval(maxf(time - 1.2, 0.2))
	tw.tween_property(self, "text_alpha", 0.0, 0.6)
	await tw.finished
	text = ""


# Roda a cena `id`. Retorna quando ela termina.
func play(id: String) -> void:
	var steps = Areas.read_json(Areas.path_for("cenas", id))
	if typeof(steps) != TYPE_ARRAY:
		finished.emit(id)
		return
	running = id
	main.set_state("cena")
	for s in steps:
		await _step(s)
	running = ""
	main.set_state("explore")
	finished.emit(id)


func _step(s: Dictionary) -> void:
	var wd = main.world
	var time: float = s.get("tempo", 1.0)
	if s.has("tela"):
		await fade(1.0 if s.tela == "preta" else 0.0, time)
	elif s.has("texto"):
		await _show_text(s.texto, time)
	elif s.has("esperar"):
		await get_tree().create_timer(float(s.esperar)).timeout
	elif s.has("camera"):
		var to: Vector2 = wd.iso(wd.player_pos) - Vector2(0, 16) if typeof(s.camera) == TYPE_STRING else wd.iso(_pos(s.camera))
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(wd.cam, "position", to, time)
		await tw.finished
	elif s.has("mover"):
		await _move(s.mover, _pos(s.para), float(s.get("velocidade", 2.0)))
	elif s.has("pose"):
		_set_pose(s.get("quem", "branca"), s.pose)
	elif s.has("posicionar"):
		_set_actor(s.posicionar, _pos(s.em))
	elif s.has("esconder"):
		_actor_visible(s.esconder, false)
	elif s.has("mostrar"):
		_actor_visible(s.mostrar, true)
	elif s.has("dialogo"):
		main.start_dialogue(s.dialogo)
		if main.state == "dialogue":
			await main.dialogue.finished
	elif s.has("marcar"):
		main.flags[s.marcar] = true
	elif s.has("missao"):
		main.missao = s.missao
	elif s.has("som"):
		main.play_sfx(s.som)
	elif s.has("musica"):
		main.play_music(s.musica)
	elif s.has("area"):
		main.area_id = s.area
		wd.load_area(s.area, null, s.get("ponto", "inicio"))
		main._area_music()


func _pos(p) -> Vector2:
	return Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5)


func _npc(id: String) -> Dictionary:
	for n in main.world.npcs:
		if n.data.get("id", "") == id:
			return n
	push_error("Personagem '%s' não está na área" % id)
	return {}


func _set_actor(who: String, p: Vector2) -> void:
	if who == "branca":
		main.world.player_pos = p
	else:
		var n := _npc(who)
		if not n.is_empty():
			n.pos = p


func _set_pose(who: String, pose: String) -> void:
	if who == "branca":
		main.world.player_pose = pose
	else:
		var n := _npc(who)
		if not n.is_empty():
			n["pose"] = pose


func _actor_visible(who: String, v: bool) -> void:
	if who == "branca":
		main.world.player_hidden = not v
	else:
		var n := _npc(who)
		if not n.is_empty():
			n["oculto"] = not v


# Anda em linha reta até `to`, na velocidade em casas por segundo.
func _move(who: String, to: Vector2, speed: float) -> void:
	var wd = main.world
	var n := {} if who == "branca" else _npc(who)
	if who != "branca" and n.is_empty():
		return
	var from: Vector2 = wd.player_pos if who == "branca" else n.pos
	var dur := maxf(from.distance_to(to) / maxf(speed, 0.1), 0.05)
	if who == "branca":
		wd.facing = (to - from).normalized()
		wd.moving = true
	else:
		n["left"] = wd.iso(to).x < wd.iso(from).x
	var tw := create_tween()
	tw.tween_method(func(p: Vector2): _set_actor(who, p), from, to, dur)
	await tw.finished
	if who == "branca":
		wd.moving = false
	else:
		n.erase("left")
