# Combate rítmico em dois modos que se alternam durante a luta (nunca os dois ao mesmo tempo):
# - Pistas (estilo Guitar Hero): notas descem nas pistas D F J K.
# - Mira (estilo osu!): mira com o mouse e acerta com D ou F (ou clique); sliders: segura e segue a bolinha.
# Errar nota tira vida da Branca; acertar tira vida do inimigo. Morrer reinicia a luta com vida cheia
# e perde parte do dinheiro. Itens usados antes da luta: amuleto absorve erros, chá deixa as notas
# mais lentas. Arte e música PROVISÓRIAS.
extends Node2D

signal ended(enemy: Dictionary, reward: int)

const Data := preload("res://scripts/data.gd")
const Itens := preload("res://scripts/itens.gd")

const LANE_KEYS := [KEY_D, KEY_F, KEY_J, KEY_K]
const OSU_KEYS := [KEY_D, KEY_F]
const LANE_LABELS := ["D", "F", "J", "K"]
const LANE_COLORS := [Color(0.85, 0.82, 0.72), Color(0.55, 0.7, 0.85), Color(0.7, 0.25, 0.3), Color(0.95, 0.65, 0.3)]
const LANE_X0 := 170.0
const LANE_W := 76.0
const HIT_Y := 610.0
const SCROLL := 440.0  # pixels por segundo
const APPROACH := 0.9  # segundos que o círculo aparece antes
const CIRCLE_R := 36.0
const FOLLOW_R := 80.0  # distância que o mouse pode ficar da bolinha do slider
const SLIDER_SLACK := 0.12  # segundos que pode soltar/sair da bolinha antes de errar
const WIN_PERFECT := 0.05
const WIN_GOOD := 0.12
const GHOST_DAMAGE := 1.0  # apertar tecla de pista sem nota

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
var mode := "lanes"  # "lanes" ou "osu"
var lane_alpha := 1.0
var banner := ["", 0.0]
var autoplay := false  # só para o teste automático
var scroll := SCROLL  # o chá diminui a velocidade das notas
var approach := APPROACH
var absorb_flash := 0.0


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.finished.connect(_on_song_finished)
	add_child(player)


func start(e: Dictionary, start_hp: float) -> void:
	enemy = e
	kind = main.enemy_types[e.kind]
	var f := FileAccess.open(kind.notas, FileAccess.READ)
	var chart: Dictionary = JSON.parse_string(f.get_as_text())
	loop_len = chart.length
	beat = 60.0 / chart.bpm
	notes = []
	for n in chart.notes:
		notes.append(n.duplicate())
	_reset_notes()
	dmg_per_hit = 1.0 / (notes.size() * chart.kill_ratio)
	player.stream = load(kind.musica)
	enemy_start = start_hp
	var slow: float = Data.EFEITOS.cha.lentidao if main.effects.has("cha") else 1.0
	scroll = SCROLL * slow
	approach = APPROACH / slow
	_begin("intro")
	msg = kind.nome
	var notes_txt: Array = []
	if start_hp < 1.0:
		notes_txt.append("Atordoado: começa com menos vida")
	if main.effects.has("cha"):
		notes_txt.append("Chá: notas mais lentas")
	if main.effects.has("amuleto"):
		notes_txt.append("Amuleto: absorve %d erros" % int(main.effects.amuleto))
	sub = "   ·   ".join(notes_txt)


func _reset_notes() -> void:
	for n in notes:
		n["done"] = false
		n["held"] = false
		n["slack"] = 0.0
		n["mult"] = 1.0


func _begin(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "intro":
		enemy_hp = enemy_start
		combo = 0
		feedback = []
		lt = -1.0
		_reset_notes()
		mode = _next_mode()
		lane_alpha = 1.0 if mode == "lanes" else 0.15


func _on_song_finished() -> void:
	# a música recomeça até alguém cair
	if state == "play":
		_reset_notes()
		player.play()


func _song_time() -> float:
	return player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


func _next_mode() -> String:
	for n in notes:
		if not n.done:
			return "lanes" if n.k == "l" else "osu"
	return mode


func _process(delta: float) -> void:
	if not visible:
		return
	state_t += delta
	shake = maxf(shake - delta * 30.0, 0.0)
	absorb_flash = maxf(absorb_flash - delta * 2.5, 0.0)
	banner[1] = maxf(banner[1] - delta, 0.0)
	for i in 4:
		lane_flash[i] = maxf(lane_flash[i] - delta * 5.0, 0.0)
	for fb in feedback:
		fb[2] -= delta
	feedback = feedback.filter(func(fb): return fb[2] > 0.0)
	lane_alpha = move_toward(lane_alpha, 1.0 if mode == "lanes" else 0.15, delta * 4.0)
	match state:
		"intro":
			if state_t > 1.6:
				msg = ""
				sub = ""
				state = "play"
				player.play()
		"play":
			lt = _song_time()
			if autoplay:
				_autoplay()
			for n in notes:
				if n.done:
					continue
				if n.k == "s" and n.held:
					_update_slider(n, delta)
				elif lt - n.t > WIN_GOOD:
					n.done = true
					_miss(n)
				if state != "play":
					break
			var m := _next_mode()
			if m != mode:
				mode = m
				banner = ["PISTAS" if mode == "lanes" else "MIRA", 1.0]
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


func _update_slider(n: Dictionary, delta: float) -> void:
	if lt >= n.t + n.dur:
		n.done = true
		_damage(n.mult, "PERFEITO" if n.mult >= 1.0 else "BOM", _note_pos(n) - Vector2(0, 50))
		return
	var pressing := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_F) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var near := get_global_mouse_position().distance_to(_note_pos(n)) <= FOLLOW_R
	if autoplay or (pressing and near):
		return
	n.slack += delta
	if n.slack > SLIDER_SLACK:
		n.done = true
		_miss(n)


func handle_key(k: int) -> void:
	if state != "play":
		return
	if mode == "osu":
		if k in OSU_KEYS:
			_osu_press()
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
	_hit(best, best_dt)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or state != "play" or mode != "osu":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_osu_press()


# Acerta o círculo ou a cabeça do slider que está sob o mouse, no tempo certo.
func _osu_press() -> void:
	var mp := get_global_mouse_position()
	var best = null
	var best_dt := WIN_GOOD
	for n in notes:
		if n.done or n.held or n.k == "l":
			continue
		var dt: float = abs(n.t - lt)
		if dt <= best_dt and mp.distance_to(Vector2(n.x, n.y)) <= CIRCLE_R * 1.25:
			best_dt = dt
			best = n
	if best != null:
		_hit(best, best_dt)


func _autoplay() -> void:
	for n in notes:
		if n.done or n.held or n.t > lt + 0.005:
			continue
		if n.k == "l":
			handle_key(LANE_KEYS[int(n.lane)])
		else:
			_hit(n, abs(n.t - lt))


func _hit(n: Dictionary, dt: float) -> void:
	var mult := 1.0 if dt <= WIN_PERFECT else 0.6
	var label := "PERFEITO" if dt <= WIN_PERFECT else "BOM"
	main.play_sfx("acerto")
	combo += 1
	if n.k == "s":
		# cabeça do slider: o dano vem quando ele termina sem soltar
		n.held = true
		n.mult = mult
		_feedback(label, Vector2(n.x, n.y) - Vector2(0, 50), Color(0.8, 0.85, 0.9))
		return
	n.done = true
	_damage(mult, label, _note_pos(n) - Vector2(0, 40 if n.k == "l" else 50))


func _damage(mult: float, label: String, at: Vector2) -> void:
	_feedback(label, at, Color(0.9, 0.95, 1.0) if mult >= 1.0 else Color(0.7, 0.75, 0.8))
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


func _feedback(text: String, at: Vector2, col: Color) -> void:
	feedback.append([text, at, 0.5, col])


func _miss(n: Dictionary) -> void:
	combo = 0
	if main.effects.get("amuleto", 0) > 0:
		# o amuleto segura o erro: sem dano, gasta uma carga
		main.effects.amuleto = int(main.effects.amuleto) - 1
		if main.effects.amuleto <= 0:
			main.effects.erase("amuleto")
		absorb_flash = 1.0
		_feedback("ABSORVIDO", _note_pos(n) - Vector2(0, 40 if n.k == "l" else 50), Color(1.0, 0.65, 0.25))
		main.play_sfx("absorver")
		return
	_feedback("ERROU", _note_pos(n) - Vector2(0, 40 if n.k == "l" else 50), Color(0.9, 0.25, 0.25))
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


# Posição atual da nota na tela (para sliders, a bolinha ao longo da curva).
func _note_pos(n: Dictionary) -> Vector2:
	match n.k:
		"l":
			return Vector2(LANE_X0 + int(n.lane) * LANE_W + LANE_W / 2, HIT_Y)
		"s":
			return _slider_point(n, clampf((lt - n.t) / n.dur, 0.0, 1.0))
	return Vector2(n.x, n.y)


func _slider_point(n: Dictionary, p: float) -> Vector2:
	var a := Vector2(n.x, n.y)
	var c := Vector2(n.cx, n.cy)
	var b := Vector2(n.ex, n.ey)
	return a.lerp(c, p).lerp(c.lerp(b, p), p)


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
	_draw_lanes(off)
	_draw_effects()  # por cima das pistas
	if state == "play":
		_draw_osu(off)
	for fb in feedback:
		_text(fb[1] - Vector2(80, (0.5 - fb[2]) * 30), fb[0], 20, Color(fb[3], clampf(fb[2] * 2.5, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, 160)
	if combo >= 5:
		_text(Vector2(40, 120), "%d" % combo, 30, Color(0.9, 0.9, 0.85, 0.7))
	if banner[1] > 0.0:
		_text(Vector2(0, 150), banner[0], 34, Color(0.92, 0.9, 0.88, clampf(banner[1] * 2.0, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	if msg != "":
		draw_rect(Rect2(0, 300, 1280, 110), Color(0, 0, 0, 0.7))
		_text(Vector2(0, 352), msg, 36, Color(0.92, 0.9, 0.88), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		if sub != "":
			_text(Vector2(0, 390), sub, 18, Color(0.75, 0.72, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	if state == "play":
		var hint := "Pistas: D F J K" if mode == "lanes" else "Mira: mouse na bolinha + D ou F (ou clique)   Slider: segure e siga"
		_text(Vector2(0, 700), hint, 16, Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 1280)


# Efeitos de itens ativos, embaixo da vida da Branca.
func _draw_effects() -> void:
	var x := 40.0
	var y := 98.0
	if main.effects.has("amuleto") or absorb_flash > 0.0:
		if absorb_flash > 0.0:
			draw_circle(Vector2(x + 14, y), 16.0 + 14.0 * (1.0 - absorb_flash), Color(1.0, 0.65, 0.25, 0.25 * absorb_flash))
		Itens.draw_icon(self, "amuleto", Vector2(x + 14, y), 28.0)
		var left := int(main.effects.get("amuleto", 0))
		var total: int = Data.EFEITOS.amuleto.cargas
		for k in total:
			var p := Vector2(x + 42 + k * 20, y)
			var d := PackedVector2Array([p + Vector2(0, -8), p + Vector2(7, 0), p + Vector2(0, 8), p + Vector2(-7, 0)])
			if k < left:
				draw_colored_polygon(d, Color(1.0, 0.65, 0.25))
			else:
				d.append(d[0])
				draw_polyline(d, Color(0.5, 0.45, 0.4), 1.5)
		x += 42 + total * 20 + 24
	if main.effects.has("cha"):
		Itens.draw_icon(self, "cha", Vector2(x + 14, y), 28.0)
		_text(Vector2(x + 34, y + 6), "notas lentas", 16, Color(0.78, 0.75, 0.7))


func _draw_lanes(off: Vector2) -> void:
	var la := lane_alpha
	for i in 4:
		var x := LANE_X0 + i * LANE_W + off.x
		draw_rect(Rect2(x + 2, 100, LANE_W - 4, 620), Color(0.07, 0.07, 0.09, 0.9 * la))
		draw_rect(Rect2(x + 2, 100, LANE_W - 4, 620), Color(LANE_COLORS[i], 0.12 * lane_flash[i] * la))
	draw_line(Vector2(LANE_X0, HIT_Y) + off, Vector2(LANE_X0 + 4 * LANE_W, HIT_Y) + off, Color(0.8, 0.8, 0.8, 0.6 * la), 2.0)
	for i in 4:
		var cx := LANE_X0 + i * LANE_W + LANE_W / 2 + off.x
		var col: Color = LANE_COLORS[i]
		draw_arc(Vector2(cx, HIT_Y + off.y), 24.0, 0, TAU, 24, Color(col, (0.5 + 0.5 * lane_flash[i]) * la), 3.0)
		_text(Vector2(cx - 30, HIT_Y + 8 + off.y), LANE_LABELS[i], 22, Color(col, 0.8 * la), HORIZONTAL_ALIGNMENT_CENTER, 60)
	if state != "play":
		return
	for n in notes:
		if n.done or n.k != "l":
			continue
		var dt: float = n.t - lt
		if dt > (HIT_Y - 100) / scroll or dt < -WIN_GOOD:
			continue
		var y := HIT_Y - dt * scroll
		var x := LANE_X0 + int(n.lane) * LANE_W + off.x
		var col: Color = LANE_COLORS[int(n.lane)]
		draw_rect(Rect2(x + 8, y - 10 + off.y, LANE_W - 16, 20), col)
		draw_rect(Rect2(x + 8, y - 10 + off.y, LANE_W - 16, 4), Color(1, 1, 1, 0.35))


func _draw_osu(off: Vector2) -> void:
	var cream := Color(0.95, 0.9, 0.85)
	var wine := Color(0.45, 0.12, 0.18)
	# do mais distante para o mais próximo, para o próximo ficar por cima
	for idx in range(notes.size() - 1, -1, -1):
		var n: Dictionary = notes[idx]
		if n.done or n.k == "l":
			continue
		var dt: float = n.t - lt
		if dt > approach:
			continue
		var a := clampf(1.0 - dt / approach, 0.0, 1.0) if dt > 0.0 else 1.0
		var head := Vector2(n.x, n.y) + off
		if n.k == "s":
			var pts := PackedVector2Array()
			for k in 25:
				pts.append(_slider_point(n, k / 24.0) + off)
			draw_polyline(pts, Color(cream, 0.5 * a), CIRCLE_R * 2.0 + 6.0)
			draw_polyline(pts, Color(0.12, 0.06, 0.09, 0.95 * a), CIRCLE_R * 2.0)
			draw_arc(Vector2(n.ex, n.ey) + off, CIRCLE_R, 0, TAU, 32, Color(cream, 0.6 * a), 2.0)
			if n.held:
				var ball := _note_pos(n) + off
				draw_circle(ball, CIRCLE_R * 0.8, wine)
				draw_arc(ball, CIRCLE_R * 0.8, 0, TAU, 32, cream, 3.0)
				draw_arc(ball, FOLLOW_R, 0, TAU, 48, Color(cream, 0.6), 2.0)
				continue
		draw_circle(head, CIRCLE_R, Color(wine, 0.85 * a))
		draw_arc(head, CIRCLE_R, 0, TAU, 32, Color(cream, a), 3.0)
		if dt > 0.0:
			var r := CIRCLE_R * (1.0 + 2.2 * dt / approach)
			draw_arc(head, r, 0, TAU, 40, Color(cream, 0.7 * a), 2.0)


func _draw_enemy_figure(c: Vector2, pulse: float) -> void:
	# silhueta grande do inimigo ao fundo
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
