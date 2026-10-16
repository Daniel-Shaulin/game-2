# Celular flip antigo (sem câmera) usado como menu. O jogo pausa enquanto ele está aberto.
extends Control

const MENU := ["Mensagens", "Notas", "Inventário", "Configurações"]

var main
var page := "menu"
var sel := 0
var reading := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func open() -> void:
	page = "menu"
	sel = 0
	reading = -1


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _close() -> void:
	main.play_sfx("clique")
	main.set_state("explore")


func _count() -> int:
	match page:
		"menu": return MENU.size()
		"Mensagens": return maxi(main.messages.size(), 1)
		"Configurações": return 3
	return 1


func handle_key(k: int) -> void:
	if k == KEY_TAB:
		_close()
		return
	if k == KEY_ESCAPE or k == KEY_BACKSPACE or k == KEY_Q:
		main.play_sfx("clique")
		if reading >= 0:
			reading = -1
		elif page != "menu":
			sel = MENU.find(page)
			page = "menu"
		else:
			_close()
		return
	if k == KEY_W or k == KEY_UP:
		sel = (sel - 1 + _count()) % _count()
		main.play_sfx("clique")
	elif k == KEY_S or k == KEY_DOWN:
		sel = (sel + 1) % _count()
		main.play_sfx("clique")
	elif page == "Configurações" and sel == 0 and (k == KEY_A or k == KEY_LEFT or k == KEY_D or k == KEY_RIGHT):
		main.set_volume(main.volume + (0.1 if k == KEY_D or k == KEY_RIGHT else -0.1))
		main.play_sfx("clique")
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_E or k == KEY_SPACE:
		main.play_sfx("clique")
		if page == "menu":
			page = MENU[sel]
			sel = 0
		elif page == "Mensagens" and reading < 0 and not main.messages.is_empty():
			reading = sel
			main.messages[sel]["lida"] = true
		elif page == "Configurações":
			if sel == 1:
				var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			elif sel == 2:
				get_tree().quit()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.17, 0.17, 0.19)
	body.set_corner_radius_all(26)
	body.border_color = Color(0.3, 0.3, 0.33)
	body.set_border_width_all(3)
	# parte de cima (tela) e de baixo (teclado), com a dobradiça no meio
	draw_style_box(body, Rect2(490, 70, 300, 300))
	draw_style_box(body, Rect2(490, 380, 300, 290))
	draw_rect(Rect2(500, 368, 280, 14), Color(0.1, 0.1, 0.11))
	var lcd := Rect2(520, 110, 240, 230)
	draw_rect(lcd, Color(0.55, 0.66, 0.62))
	draw_rect(Rect2(625, 88, 30, 4), Color(0.08, 0.08, 0.08))
	# teclado
	for r in 4:
		for c in 3:
			draw_rect(Rect2(530 + c * 76, 470 + r * 46, 66, 34), Color(0.24, 0.24, 0.27))
	draw_rect(Rect2(600, 400, 80, 52), Color(0.26, 0.26, 0.29))
	var ink := Color(0.08, 0.12, 0.1)
	var x := lcd.position.x + 10
	var y := lcd.position.y + 22
	# barra de status
	var bars := 4 if main.world._nearby("S").x >= 0 else 1
	for b in 4:
		var hb := 3 + b * 3
		draw_rect(Rect2(x + b * 5, y - hb, 3, hb), ink if b < bars else Color(ink, 0.2))
	draw_string(f, Vector2(x, y), "", HORIZONTAL_ALIGNMENT_RIGHT, 220, 13, ink)
	draw_string(f, Vector2(lcd.position.x, y), "E-317", HORIZONTAL_ALIGNMENT_RIGHT, 230, 13, ink)
	y += 22
	if reading >= 0:
		var m: Dictionary = main.messages[reading]
		draw_string(f, Vector2(x, y), "De: " + m.de, HORIZONTAL_ALIGNMENT_LEFT, 220, 14, ink)
		y += 20
		draw_multiline_string(f, Vector2(x, y), m.texto, HORIZONTAL_ALIGNMENT_LEFT, 220, 14, -1, ink)
		draw_string(f, Vector2(x, lcd.end.y - 8), "Esc voltar", HORIZONTAL_ALIGNMENT_LEFT, 220, 12, ink)
		return
	draw_string(f, Vector2(x, y), page if page != "menu" else "Menu", HORIZONTAL_ALIGNMENT_LEFT, 220, 16, ink)
	y += 8
	draw_line(Vector2(x, y), Vector2(x + 220, y), ink, 1.0)
	y += 22
	var lines: Array = []
	match page:
		"menu":
			lines = MENU
		"Mensagens":
			if main.messages.is_empty():
				lines = ["(nenhuma mensagem)"]
			else:
				for m in main.messages:
					lines.append(("* " if not m.get("lida", false) else "  ") + m.de + " " + m.titulo)
		"Notas":
			lines = ["WASD: andar", "Shift: correr", "Espaço: lanterna", "  (atordoa, gasta estamina)", "E: esconder / sinal", "Combate: D F J K", "  e clique nos círculos"]
		"Inventário":
			lines = ["Dinheiro: %d" % main.money, "", "(vazio)"]
		"Configurações":
			lines = ["Volume: < %d%% >" % int(round(main.volume * 100)), "Tela cheia", "Sair do jogo"]
	var selectable := page in ["menu", "Mensagens", "Configurações"]
	for i in lines.size():
		var line: String = lines[i]
		if selectable and i == sel:
			draw_rect(Rect2(x - 4, y - 15, 228, 20), ink)
			draw_string(f, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color(0.55, 0.66, 0.62))
		else:
			draw_string(f, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, 220, 14, ink)
		y += 22
	draw_string(f, Vector2(x, lcd.end.y - 8), "Enter ok   Esc voltar   Tab fechar", HORIZONTAL_ALIGNMENT_LEFT, 220, 11, ink)
