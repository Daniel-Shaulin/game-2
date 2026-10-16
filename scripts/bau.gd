# Baú dos pontos de sinal: troca itens entre o inventário (espaço limitado) e o baú (sem limite).
# O baú é um só: o que for guardado em um ponto de sinal aparece em todos os outros.
extends Control

const Data := preload("res://scripts/data.gd")
const Itens := preload("res://scripts/itens.gd")

const BONE := Color(0.78, 0.74, 0.66)
const INK := Color(0.9, 0.89, 0.86)
const QUIET := Color(0.5, 0.49, 0.47)
const PANEL_BG := Color(0.035, 0.035, 0.05, 0.96)
const SEL_BG := Color(0.12, 0.05, 0.07, 0.96)
const LEFT := Rect2(200, 120, 420, 372)
const RIGHT := Rect2(660, 120, 420, 372)
const INFO := Rect2(200, 508, 880, 96)
const ROW_H := 48.0
const ROWS := 6  # linhas visíveis em cada lado

var main
var side := 0  # 0 = inventário, 1 = baú
var sel := [0, 0]
var notice := ""
var notice_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func open() -> void:
	side = 0
	sel = [0, 0]
	notice = ""


func _list(s: int) -> Array:
	return main.inventory if s == 0 else main.chest


func _rows(s: int) -> int:
	# o inventário mostra todas as vagas, até as vazias; o baú mostra o que tiver
	return Data.INV_SLOTS if s == 0 else maxi(main.chest.size(), 1)


func _selected_item() -> String:
	var l := _list(side)
	return l[sel[side]] if sel[side] < l.size() else ""


func _say(t: String) -> void:
	notice = t
	notice_t = 2.5


func handle_key(k: int) -> void:
	if k == KEY_ESCAPE or k == KEY_TAB or k == KEY_Q or k == KEY_BACKSPACE:
		main.close_chest()
		return
	if k == KEY_A or k == KEY_LEFT or k == KEY_D or k == KEY_RIGHT:
		side = 0 if (k == KEY_A or k == KEY_LEFT) else 1
		main.play_sfx("clique")
	elif k == KEY_W or k == KEY_UP:
		sel[side] = (sel[side] - 1 + _rows(side)) % _rows(side)
		main.play_sfx("clique")
	elif k == KEY_S or k == KEY_DOWN:
		sel[side] = (sel[side] + 1) % _rows(side)
		main.play_sfx("clique")
	elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_move()


# Passa o item escolhido para o outro lado.
func _move() -> void:
	var id := _selected_item()
	if id == "":
		return
	if side == 1 and main.inventory.size() >= Data.INV_SLOTS:
		main.play_sfx("erro")
		_say("Inventário cheio.")
		return
	_list(side).remove_at(sel[side])
	_list(1 - side).append(id)
	main.play_sfx("clique")
	_say(("%s guardado no baú." if side == 0 else "%s pego do baú.") % Data.ITENS[id].nome)
	if side == 1:
		sel[1] = clampi(sel[1], 0, maxi(main.chest.size() - 1, 0))


func _process(delta: float) -> void:
	if visible:
		notice_t = maxf(notice_t - delta, 0.0)
		queue_redraw()


func _box(r: Rect2, bg: Color, border: Color, bw := 2) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(6)
	draw_style_box(s, r)


func _draw() -> void:
	if main == null:
		return
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.62))
	draw_string(f, Vector2(0, 92), "BAÚ", HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, BONE)
	_draw_side(0, LEFT, "Inventário", "%d/%d" % [main.inventory.size(), Data.INV_SLOTS])
	_draw_side(1, RIGHT, "Guardado", "%d" % main.chest.size())
	# descrição do item escolhido
	_box(INFO, PANEL_BG, QUIET)
	var id := _selected_item()
	if id != "":
		var it: Dictionary = Data.ITENS[id]
		draw_string(f, INFO.position + Vector2(24, 36), it.nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BONE)
		draw_string(f, INFO.position + Vector2(24, 68), it.descricao, HORIZONTAL_ALIGNMENT_LEFT, INFO.size.x - 48, 17, INK)
	else:
		draw_string(f, INFO.position + Vector2(24, 54), "Espaço vazio.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, QUIET)
	if notice_t > 0.0:
		draw_string(f, Vector2(0, 640), notice, HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color(0.95, 0.85, 0.6, clampf(notice_t, 0.0, 1.0)))
	draw_string(f, Vector2(0, 690), "W/S escolher    A/D trocar de lado    E mover    Esc fechar", HORIZONTAL_ALIGNMENT_CENTER, 1280, 14, QUIET)


func _draw_side(s: int, r: Rect2, title: String, count: String) -> void:
	var f := ThemeDB.fallback_font
	var active := s == side
	_box(r, PANEL_BG, BONE if active else QUIET)
	draw_string(f, r.position + Vector2(24, 38), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, BONE if active else QUIET)
	draw_string(f, r.position + Vector2(0, 38), count, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24, 16, QUIET)
	draw_line(r.position + Vector2(20, 54), r.position + Vector2(r.size.x - 20, 54), Color(QUIET, 0.5), 1.0)
	var l := _list(s)
	var n := _rows(s)
	var first := clampi(sel[s] - ROWS + 1, 0, maxi(n - ROWS, 0))  # rola quando o baú passa de 6 itens
	for v in mini(ROWS, n):
		var i := first + v
		var row := Rect2(r.position + Vector2(14, 66 + v * ROW_H), Vector2(r.size.x - 28, ROW_H - 6))
		var picked: bool = active and i == sel[s]
		if picked:
			_box(row, SEL_BG, BONE)
		if i < l.size():
			var id: String = l[i]
			Itens.draw_icon(self, id, row.position + Vector2(26, row.size.y / 2), 28.0)
			draw_string(f, row.position + Vector2(54, 28), Data.ITENS[id].nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK if picked else Color(0.75, 0.74, 0.71))
		elif s == 0:
			draw_string(f, row.position + Vector2(54, 28), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(QUIET, 0.6))
		else:
			draw_string(f, row.position + Vector2(18, 28), "Nada guardado.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, QUIET)
	if first > 0:
		draw_string(f, r.position + Vector2(0, 62), "▲", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24, 12, QUIET)
	if first + ROWS < n:
		draw_string(f, r.position + Vector2(0, r.size.y - 6), "▼", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 24, 12, QUIET)
