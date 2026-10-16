# Combate rítmico: pistas D F J K (estilo Guitar Hero) + círculos para clicar (estilo osu!).
# Errar nota tira vida da Branca; acertar tira vida do inimigo. Morrer reinicia a luta com vida cheia
# e perde parte do dinheiro. Arte e música PROVISÓRIAS.
extends Node2D

signal ended(enemy: Dictionary, reward: int)

const Data := preload("res://scripts/data.gd")

const LANE_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const LANE_LABELS := ["D", "F", "J", "K"]
const LANE_COLORS := [Color(0.85, 0.82, 0.72), Color(0.55, 0.7, 0.85), Color(0.7, 0.25, 0.3), Color(0.95, 0.65, 0.3)]
const LANE_X0 := 170.0
const LANE_W := 76.0
const HIT_Y := 610.0
const SCROLL := 440.0  # pixels por segundo
const APPROACH := 0.9  # segundos que o círculo aparece antes
const CIRCLE_R := 36.0
const WIN_PERFECT := 0.05
const WIN_GOOD := 0.12
const GHOST_DAMAGE := 1.0  # apertar tecla sem nota

var main
var enemy: Dictionary
var kind: Dictionary
var notes: Array = []
var loop_len := 1.0
var beat := 0.5
var player: AudioStreamPlayer
var state := "idle"
var state_t := 0.0
var enemy_hp := 1.0
var enemy_start := 1.0
var dmg_per_hit := 0.01
var combo := 0
var feedback: Array = []  # [texto, posição, tempo, cor]
var lane_flash := [0.0, 0.0, 0.0, 0.0]
var lt := 0.0  # tempo dentro da música
var shake := 0.0
var msg := ""
var sub := ""
var reward := 0


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.finished.connect(_on_song_finished)
	add_child(player)


func start(e: Dictionary, start_hp: float) -> void:
	enemy = e
	kind = Data.ENEMIES[e.kind]
	var f := FileAccess.open(kind.notas, FileAccess.READ)
	var chart: Dictionary = JSON.parse_string(f.get_as_text())
	loop_len = chart.length
	beat = 60.0 / chart.bpm
	notes = []
	for n in chart.notes:
		var d: Dictionary = n.duplicate()
		d["done"] = false
		notes.append(d)
	dmg_per_hit = 1.0 / (notes.size() * chart.kill_ratio)
	player.stream = load(kind.musica)
	enemy_start = start_hp
	_begin("intro")
	msg = kind.nome
	sub = "Atordoado: começa com menos vida" if start_hp < 1.0 else ""


func _begin(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "intro":
		enemy_hp = enemy_start
		combo = 0
		feedback = []
		lt = -1.0
		for n in notes:
			n.done = false


func _on_song_finished() -> void:
	# a música recomeça até alguém cair
	if state == "play":
		for n in notes:
			n.done = false
		player.play()


func _song_time() -> float:
	return player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


func _process(delta: float) -> void:
	if not visible:
		return
	state_t += delta
	shake = maxf(shake - delta * 30.0, 0.0)
	for i in 4:
		lane_flash[i] = maxf(lane_flash[i] - delta * 5.0, 0.0)
	for fb in feedback:
		fb[2] -= delta
	feedback = feedback.filter(func(fb): return fb[2] > 0.0)
	match state:
		"intro":
			if state_t > 1.6:
				msg = ""
				sub = ""
				state = "play"
				player.play()
		"play":
			lt = _song_time()
			for n in notes:
				if not n.done and lt - n.t > WIN_GOOD:
					n.done = true
					_miss(n)
					if state != "play":
						break
		"dead":
			if state_t > 2.8:
				main.hp = main.MAX_HP
				_begin("intro")
				msg = "De novo."
		"won":
			if state_t > 2.2:
				state = "idle"
				ended.emit(enemy, reward)
	queue_redraw()


func handle_key(k: int) -> void:
	if state != "play":
		return
	var lane := LANE_KEYS.find(k)
	if lane < 0:
		return
	lane_flash[lane] = 1.0
	var best = null
	var best_dt := WIN_GOOD
	for n in notes:
		if n.done or n.k != "l" or int(n.lane) != lane:
			continue
		var dt: float = abs(n.t - lt)
		if dt <= best_dt:
			best_dt = dt
			best = n
	if best == null:
		_hurt(GHOST_DAMAGE)
		combo = 0
		return
	_hit(best, best_dt, Vector2(LANE_X0 + lane * LANE_W + LANE_W / 2, HIT_Y - 40))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or state != "play":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mp := get_global_mouse_position()
		var best = null
		var best_dt := WIN_GOOD
		for n in notes:
			if n.done or n.k != "c":
				continue
			var dt: float = abs(n.t - lt)
			if dt <= best_dt and mp.distance_to(Vector2(n.x, n.y)) <= CIRCLE_R * 1.25:
				best_dt = dt
				best = n
		if best != null:
			_hit(best, best_dt, Vector2(best.x, best.y - 50))


func _hit(n: Dictionary, dt: float, at: Vector2) -> void:
	n.done = true
	combo += 1
	var mult := 1.0 if dt <= WIN_PERFECT else 0.6
	feedback.append(["PERFEITO" if dt <= WIN_PERFECT else "BOM", at, 0.5, Color(0.9, 0.95, 1.0) if dt <= WIN_PERFECT else Color(0.7, 0.75, 0.8)])
	main.play_sfx("acerto")
	enemy_hp -= dmg_per_hit * mult
	if enemy_hp <= 0.0:
		enemy_hp = 0.0
		player.stop()
		var r: Array = kind.recompensa
		reward = randi_range(r[0], r[1])
		state = "won"
		state_t = 0.0
		msg = "Vitória"
		sub = "+%d de dinheiro" % reward


func _miss(n: Dictionary) -> void:
	combo = 0
	var at := Vector2(n.x, n.y - 50) if n.k == "c" else Vector2(LANE_X0 + int(n.lane) * LANE_W + LANE_W / 2, HIT_Y - 40)
	feedback.append(["ERROU", at, 0.5, Color(0.9, 0.25, 0.25)])
	main.play_sfx("erro")
	_hurt(kind.dano_erro)


func _hurt(amount: float) -> void:
	main.hp -= amount
	shake = 8.0
	if main.hp <= 0.0:
		main.hp = 0.0
		player.stop()
		var lost: int = main.death_penalty()
		state = "dead"
		state_t = 0.0
		msg = "Branca caiu."
		sub = "Perdeu %d de dinheiro. A luta recomeça." % lost


# ---------- desenho ----------

func _text(pos: Vector2, t: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string(f, pos + Vector2(2, 2), t, align, width, size, Color(0, 0, 0, 0.8))
	draw_string(f, pos, t, align, width, size, col)


func _draw() -> void:
	var off := Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	var pulse := 0.0
	if state == "play" and lt > 0.0:
		pulse = 1.0 - fmod(lt, beat) / beat
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.03, 0.03, 0.05).lerp(Color(0.07, 0.05, 0.08), pulse * 0.6))
	_draw_enemy_figure(Vector2(960, 560) + off * 0.5, pulse)
	# barras de vida
	_text(Vector2(40, 46), "Branca", 20, Color(0.9, 0.9, 0.88))
	draw_rect(Rect2(40, 58, 360, 16), Color(0.12, 0.1, 0.12))
	draw_rect(Rect2(40, 58, 360 * main.hp / main.MAX_HP, 16), Color(0.6, 0.12, 0.16))
	_text(Vector2(840, 46), kind.get("nome", ""), 20, Color(0.9, 0.9, 0.88), HORIZONTAL_ALIGNMENT_RIGHT, 400)
	draw_rect(Rect2(880, 58, 360, 16), Color(0.12, 0.1, 0.12))
	draw_rect(Rect2(880 + 360 * (1.0 - enemy_hp), 58, 360 * enemy_hp, 16), Color(0.75, 0.7, 0.6))
	# pistas
	for i in 4:
		var x := LANE_X0 + i * LANE_W + off.x
		draw_rect(Rect2(x + 2, 100, LANE_W - 4, 620), Color(0.07, 0.07, 0.09, 0.9))
		draw_rect(Rect2(x + 2, 100, LANE_W - 4, 620), Color(LANE_COLORS[i], 0.12 * lane_flash[i]))
	draw_line(Vector2(LANE_X0, HIT_Y) + off, Vector2(LANE_X0 + 4 * LANE_W, HIT_Y) + off, Color(0.8, 0.8, 0.8, 0.6), 2.0)
	for i in 4:
		var cx := LANE_X0 + i * LANE_W + LANE_W / 2 + off.x
		var col: Color = LANE_COLORS[i]
		draw_arc(Vector2(cx, HIT_Y + off.y), 24.0, 0, TAU, 24, Color(col, 0.5 + 0.5 * lane_flash[i]), 3.0)
		_text(Vector2(cx - 30, HIT_Y + 8 + off.y), LANE_LABELS[i], 22, Color(col, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 60)
	if state == "play":
		for n in notes:
			if n.done:
				continue
			var dt: float = n.t - lt
			if n.k == "l":
				if dt > (HIT_Y - 100) / SCROLL or dt < -WIN_GOOD:
					continue
				var y := HIT_Y - dt * SCROLL
				var x := LANE_X0 + int(n.lane) * LANE_W + off.x
				var col: Color = LANE_COLORS[int(n.lane)]
				draw_rect(Rect2(x + 8, y - 10 + off.y, LANE_W - 16, 20), col)
				draw_rect(Rect2(x + 8, y - 10 + off.y, LANE_W - 16, 4), Color(1, 1, 1, 0.35))
			elif dt <= APPROACH and dt >= -WIN_GOOD:
				var p := Vector2(n.x, n.y) + off
				var a := clampf(1.0 - dt / APPROACH, 0.0, 1.0)
				draw_circle(p, CIRCLE_R, Color(0.45, 0.12, 0.18, 0.85 * a))
				draw_arc(p, CIRCLE_R, 0, TAU, 32, Color(0.95, 0.9, 0.85, a), 3.0)
				var r := CIRCLE_R * (1.0 + 2.2 * maxf(dt, 0.0) / APPROACH)
				draw_arc(p, r, 0, TAU, 40, Color(0.95, 0.9, 0.85, 0.7 * a), 2.0)
	for fb in feedback:
		_text(fb[1] - Vector2(80, (0.5 - fb[2]) * 30), fb[0], 20, Color(fb[3], clampf(fb[2] * 2.5, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, 160)
	if combo >= 5:
		_text(Vector2(LANE_X0, 140), "%d" % combo, 30, Color(0.9, 0.9, 0.85, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 4 * LANE_W)
	if msg != "":
		draw_rect(Rect2(0, 300, 1280, 110), Color(0, 0, 0, 0.7))
		_text(Vector2(0, 352), msg, 36, Color(0.92, 0.9, 0.88), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		if sub != "":
			_text(Vector2(0, 390), sub, 18, Color(0.75, 0.72, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	if state == "play" and lt < 2.0 * 4.0 * beat:
		_text(Vector2(0, 700), "Pistas: D F J K    Círculos: clique quando o anel fechar", 16, Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_enemy_figure(c: Vector2, pulse: float) -> void:
	# silhueta grande do inimigo atrás da área dos círculos
	var body := Color(0.12, 0.11, 0.14, 0.9)
	var s := 1.0 + pulse * 0.02
	var hgt := 420.0 * s
	draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -hgt * 0.62), c + Vector2(40, -hgt * 0.62), c + Vector2(70, 200), c + Vector2(-70, 200)]), body)
	draw_line(c + Vector2(-44, -hgt * 0.58), c + Vector2(-120, 160), body, 14.0)
	draw_line(c + Vector2(44, -hgt * 0.58), c + Vector2(120, 160), body, 14.0)
	draw_rect(Rect2(c + Vector2(-32, -hgt * 0.62 - 70), Vector2(64, 76)), body)
	var horn := Color(0.4, 0.37, 0.32, 0.9)
	draw_line(c + Vector2(-28, -hgt * 0.62 - 60), c + Vector2(-70, -hgt * 0.62 - 140), horn, 8.0)
	draw_line(c + Vector2(28, -hgt * 0.62 - 60), c + Vector2(70, -hgt * 0.62 - 140), horn, 8.0)
	var eye: Color = kind.get("cor_olhos", Color.WHITE)
	var ey := -hgt * 0.62 - 36
	draw_rect(Rect2(c + Vector2(-20, ey), Vector2(12, 6)), eye)
	draw_rect(Rect2(c + Vector2(8, ey), Vector2(12, 6)), eye)
	draw_circle(c + Vector2(0, ey + 3), 46.0, Color(eye, 0.06 + 0.08 * pulse))
