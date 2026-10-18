# Tela inicial. O nome do jogo ainda não foi decidido (passo 31 do plano), então a tela não mostra título:
# só os olhos da Branca no escuro, refletidos no lago.
extends Control

var main
var sel := 0
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _options() -> Array:
	var o := ["Novo jogo"]
	if main.has_save():
		o.append("Continuar")
	o.append("Sair")
	return o


func _process(delta: float) -> void:
	t += delta
	if visible:
		queue_redraw()


func handle_key(k: int) -> void:
	var o := _options()
	if k == KEY_W or k == KEY_UP:
		sel = (sel - 1 + o.size()) % o.size()
		main.play_sfx("clique")
	elif k == KEY_S or k == KEY_DOWN:
		sel = (sel + 1) % o.size()
		main.play_sfx("clique")
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_E or k == KEY_SPACE:
		match o[sel]:
			"Novo jogo": main.new_game()
			"Continuar": main.load_game()
			"Sair": get_tree().quit()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.025, 0.04))
	# a superfície do lago: o escuro de baixo é um pouco mais azul
	draw_rect(Rect2(0, 330, 1280, 390), Color(0.025, 0.035, 0.055))
	for k in 7:
		var y := 336.0 + k * k * 4.0
		var a := 0.05 - k * 0.006
		var wob := sin(t * 0.7 + k) * 30.0
		draw_line(Vector2(380 + wob - k * 30, y), Vector2(900 + wob + k * 30, y), Color(0.5, 0.6, 0.75, a), 1.0)
	# os olhos piscam devagar de vez em quando
	var blink := 1.0 if fmod(t, 7.0) > 0.18 else 0.15
	var a := (0.45 + 0.3 * sin(t * 1.5)) * blink
	draw_circle(Vector2(640, 251), 40.0, Color(0.6, 0.75, 1.0, 0.03 * blink))
	draw_rect(Rect2(626, 250, 6, 3), Color(0.8, 0.9, 1.0, a))
	draw_rect(Rect2(648, 250, 6, 3), Color(0.8, 0.9, 1.0, a))
	# reflexo tremido na água
	var r := sin(t * 2.3) * 2.0
	draw_rect(Rect2(626 + r, 410, 6, 2), Color(0.8, 0.9, 1.0, a * 0.3))
	draw_rect(Rect2(648 - r, 410, 6, 2), Color(0.8, 0.9, 1.0, a * 0.3))
	var o := _options()
	for i in o.size():
		var c := Color(0.92, 0.9, 0.85) if i == sel else Color(0.42, 0.42, 0.44)
		var label: String = ("> %s <" % o[i]) if i == sel else o[i]
		draw_string(f, Vector2(0, 480 + i * 36), label, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, c)
	draw_string(f, Vector2(0, 690), "W/S escolher   Enter confirmar", HORIZONTAL_ALIGNMENT_CENTER, 1280, 14, Color(0.35, 0.35, 0.37))
