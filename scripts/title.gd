# Tela inicial do protótipo (o nome do jogo ainda não foi decidido).
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
	# dois olhos fracos no escuro
	var a := 0.4 + 0.3 * sin(t * 1.5)
	draw_rect(Rect2(626, 250, 6, 3), Color(0.8, 0.9, 1.0, a))
	draw_rect(Rect2(648, 250, 6, 3), Color(0.8, 0.9, 1.0, a))
	draw_string(f, Vector2(0, 340), "PROTÓTIPO", HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, Color(0.8, 0.8, 0.78))
	draw_string(f, Vector2(0, 372), "teste do ciclo de exploração e combate", HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Color(0.45, 0.45, 0.45))
	var o := _options()
	for i in o.size():
		var c := Color(0.95, 0.95, 0.9) if i == sel else Color(0.45, 0.45, 0.45)
		var label: String = ("> %s <" % o[i]) if i == sel else o[i]
		draw_string(f, Vector2(0, 450 + i * 36), label, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, c)
	draw_string(f, Vector2(0, 690), "W/S escolher   Enter confirmar", HORIZONTAL_ALIGNMENT_CENTER, 1280, 14, Color(0.4, 0.4, 0.4))
