# HUD limpa da exploração: vida, estamina, dinheiro, efeitos de itens, missão, dica de interação e avisos.
extends Control

const Data := preload("res://scripts/data.gd")
const Itens := preload("res://scripts/itens.gd")

var main


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _bar(pos: Vector2, size: Vector2, frac: float, col: Color) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos, size), Color(0.12, 0.1, 0.12))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(frac, 0.0, 1.0), size.y)), col)


func _text(pos: Vector2, t: String, size := 18, col := Color(0.85, 0.85, 0.82), align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string(f, pos + Vector2(1, 1), t, align, width, size, Color(0, 0, 0, 0.8))
	draw_string(f, pos, t, align, width, size, col)


func _draw() -> void:
	if main == null:
		return
	_text(Vector2(24, 34), "Branca", 18)
	_bar(Vector2(100, 22), Vector2(220, 14), main.hp / main.MAX_HP, Color(0.55, 0.12, 0.16))
	_bar(Vector2(100, 44), Vector2(160, 8), main.stamina / main.MAX_STAMINA, Color(0.75, 0.78, 0.8))
	_text(Vector2(24, 82), "Dinheiro: %d" % main.money, 16, Color(1.0, 0.75, 0.4))
	var x := 24.0
	for ef in ["amuleto", "cha"]:
		if not main.effects.has(ef):
			continue
		Itens.draw_icon(self, ef, Vector2(x + 9, 106), 18.0)
		var label: String = Data.EFEITOS[ef].nome
		if ef == "amuleto":
			label += " %d/%d" % [int(main.effects.amuleto), Data.EFEITOS.amuleto.cargas]
		_text(Vector2(x + 22, 112), label, 15, Color(0.8, 0.78, 0.74))
		x += 40 + ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	if main.missao != "":
		_text(Vector2(1040, 34), "Missão: " + main.missao, 16, Color(0.75, 0.75, 0.72), HORIZONTAL_ALIGNMENT_RIGHT, 216)
	if main.messages.any(func(m): return not m.get("lida", false)):
		_text(Vector2(1040, 58), "Nova mensagem [Tab]", 15, Color(0.5, 0.9, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, 216)
	if main.state == "phone":
		return  # o celular ocupa a tela; dicas e avisos voltam ao fechar
	if main.world.hint != "":
		_text(Vector2(0, 560), main.world.hint, 20, Color(0.95, 0.95, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var y := 610.0
	for t in main.toasts:
		_text(Vector2(0, y), t[0], 18, Color(0.85, 0.9, 0.95, clampf(t[1], 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		y += 24.0
	_text(Vector2(0, 704), "WASD mover   Shift correr   Espaço lanterna   E interagir   Tab celular", 14, Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 1280)
