# Caixa de diálogo: nome de quem fala, texto aparecendo letra a letra e escolhas.
# Os diálogos ficam em res://dialogos/<id>.json (formato explicado em dialogos/LEIAME.md).
extends Control

signal finished(id: String)

const Areas := preload("res://scripts/areas.gd")

const BOX := Rect2(160, 516, 960, 172)
const CHARS_PER_SEC := 45.0
const BONE := Color(0.78, 0.74, 0.66)
const INK := Color(0.9, 0.89, 0.86)
const QUIET := Color(0.55, 0.54, 0.52)

var main
var dialog_id := ""
var entries: Array = []
var index := 0
var current: Dictionary = {}
var shown := 0.0  # letras já visíveis
var choice := 0
var blink := 0.0

var name_panel: PanelContainer
var name_label: Label
var text_label: Label
var choices_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := Panel.new()
	box.position = BOX.position
	box.size = BOX.size
	box.add_theme_stylebox_override("panel", _style(Color(0.035, 0.035, 0.05, 0.94), BONE, 2, 6))
	add_child(box)

	name_panel = PanelContainer.new()
	name_panel.position = BOX.position + Vector2(24, -22)
	name_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.07, 0.08), BONE, 2, 4, 14, 4))
	add_child(name_panel)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", BONE)
	name_panel.add_child(name_label)

	text_label = Label.new()
	text_label.position = BOX.position + Vector2(32, 34)
	text_label.size = Vector2(BOX.size.x - 64, BOX.size.y - 56)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.add_theme_color_override("font_color", INK)
	text_label.add_theme_constant_override("line_spacing", 6)
	add_child(text_label)

	choices_box = VBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 4)
	add_child(choices_box)


func _style(bg: Color, border: Color, bw: int, radius: int, padx := 0, pady := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = padx
	s.content_margin_right = padx
	s.content_margin_top = pady
	s.content_margin_bottom = pady
	return s


# Abre o diálogo res://dialogos/<id>.json (ou um caminho res:// completo). Retorna false se o arquivo não existir.
func start(id: String) -> bool:
	var path := Areas.path_for("dialogos", id)
	if not FileAccess.file_exists(path):
		push_error("Diálogo não encontrado: " + path)
		return false
	var data = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if typeof(data) != TYPE_ARRAY:
		push_error("Diálogo inválido (precisa ser uma lista): " + path)
		return false
	dialog_id = id
	entries = data
	index = 0
	_advance_to_line()
	return true


func _find(label: String) -> int:
	for i in entries.size():
		if entries[i].get("id", "") == label:
			return i
	push_error("Marcador '%s' não existe no diálogo %s" % [label, dialog_id])
	return entries.size()


# Anda pelas entradas de controle (id, se, marcar, ir) até a próxima fala.
func _advance_to_line() -> void:
	while index < entries.size():
		var e: Dictionary = entries[index]
		if e.has("marcar"):
			main.flags[e.marcar] = true
		if e.has("se"):
			if main.flags.get(e.se, false):
				index = _find(e.ir)
				continue
			index += 1
			continue
		if e.has("texto"):
			_show(e)
			return
		if e.has("ir"):
			index = _find(e.ir)
			continue
		if e.get("fim", false):
			break
		index += 1
	_end()


func _show(e: Dictionary) -> void:
	current = e
	shown = 0.0
	choice = 0
	var who: String = e.get("quem", "")
	name_panel.visible = who != ""
	name_label.text = who
	text_label.text = e.texto
	text_label.visible_characters = 0
	_build_choices()
	choices_box.visible = false


func _build_choices() -> void:
	for c in choices_box.get_children():
		c.queue_free()
	var opts: Array = current.get("escolhas", [])
	if opts.is_empty():
		return
	var widest := 0.0
	var font := ThemeDB.fallback_font
	for o in opts:
		widest = maxf(widest, font.get_string_size("› " + o.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	for i in opts.size():
		var p := PanelContainer.new()
		var l := Label.new()
		l.text = opts[i].texto
		l.add_theme_font_size_override("font_size", 20)
		l.custom_minimum_size.x = widest + 8
		p.add_child(l)
		choices_box.add_child(p)
	var h := opts.size() * 44.0
	choices_box.position = Vector2(BOX.end.x - widest - 56, BOX.position.y - h - 14)
	_paint_choices()


func _paint_choices() -> void:
	var opts := choices_box.get_children()
	for i in opts.size():
		var sel := i == choice
		var p: PanelContainer = opts[i]
		p.add_theme_stylebox_override("panel", _style(Color(0.12, 0.05, 0.07, 0.96) if sel else Color(0.035, 0.035, 0.05, 0.94), BONE if sel else QUIET, 2, 4, 14, 6))
		var l: Label = p.get_child(0)
		var t: String = current.escolhas[i].texto
		l.text = ("› " if sel else "   ") + t
		l.add_theme_color_override("font_color", INK if sel else QUIET)


func _typing() -> bool:
	return text_label.visible_characters >= 0 and text_label.visible_characters < text_label.get_total_character_count()


func _process(delta: float) -> void:
	if not visible or current.is_empty():
		return
	blink += delta
	if _typing():
		var before := int(shown)
		shown += CHARS_PER_SEC * delta
		text_label.visible_characters = int(shown)
		if int(shown) / 3 != before / 3:
			main.play_sfx("fala")
		if not _typing():
			text_label.visible_characters = -1
	if not _typing() and current.has("escolhas"):
		choices_box.visible = true
	queue_redraw()


func _draw() -> void:
	# setinha piscando quando a fala terminou e não há escolhas
	if current.is_empty() or _typing() or current.has("escolhas"):
		return
	if fmod(blink, 1.0) < 0.6:
		var p := BOX.end - Vector2(30, 22)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(12, 0), p + Vector2(6, 8)]), BONE)


func handle_key(k: int) -> void:
	var confirm := k in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if _typing():
		if confirm:
			text_label.visible_characters = -1
		return
	if current.has("escolhas"):
		var n: int = current.escolhas.size()
		if k == KEY_W or k == KEY_UP:
			choice = (choice - 1 + n) % n
			main.play_sfx("clique")
			_paint_choices()
		elif k == KEY_S or k == KEY_DOWN:
			choice = (choice + 1) % n
			main.play_sfx("clique")
			_paint_choices()
		elif confirm:
			main.play_sfx("clique")
			var target: String = current.escolhas[choice].get("ir", "")
			index = _find(target) if target != "" else index + 1
			_advance_to_line()
		return
	if confirm:
		if current.get("fim", false):
			_end()
			return
		index = _find(current.ir) if current.has("ir") else index + 1
		_advance_to_line()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_key(KEY_E)


func _end() -> void:
	current = {}
	finished.emit(dialog_id)
