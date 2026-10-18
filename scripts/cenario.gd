# Cenário de Kurnugi: margem do lago (água escura, névoa, pedra viva, ossos, árvores mortas, pedras de
# runa), a casa da Nanshe e os móveis de dentro, a Nanshe e as poses da Branca. Os desenhos são os
# sprites em pixel de arte/sprites (scripts/arte.gd); aqui fica qual sprite vai em cada casa do mapa.
# O chão casa por casa (floor_tile, water_tile) só é usado em áreas sem chão pintado.
extends RefCounted

const Arte := preload("res://scripts/arte.gd")

const TW := 64.0
const TH := 32.0

# paleta da ficha da Nanshe
const NAVY := Color(0.1, 0.13, 0.2)
const SLATE := Color(0.27, 0.3, 0.35)
const STONE := Color(0.33, 0.36, 0.4)
const BONE := Color(0.74, 0.7, 0.6)
const BONE_DARK := Color(0.5, 0.47, 0.4)
const WINE := Color(0.36, 0.12, 0.15)
const BROWN := Color(0.3, 0.23, 0.19)
const RUNE := Color(1.0, 0.58, 0.2)
const EYE := Color(0.95, 0.93, 0.85)


# ---------- chão e água ----------

static func floor_tile(wd, i: int, j: int, l: float) -> void:
	var p := Vector2(i + 0.5, j + 0.5)
	var h: int = wd._hash(i, j)
	var wet: bool = wd.tile(i - 1, j) == "~" or wd.tile(i, j - 1) == "~" or wd.tile(i + 1, j) == "~" or wd.tile(i, j + 1) == "~"
	var v := (h % 7) / 90.0
	var base := Color(0.2 + v, 0.21 + v, 0.23 + v)
	if h % 5 == 0:
		base = base.lerp(Color(0.17, 0.22, 0.18), 0.6)  # musgo
	if wet:
		base = base.lerp(Color(0.1, 0.13, 0.17), 0.55)  # pedra molhada e lodo
	wd.draw_colored_polygon(wd.diamond(p), wd.shade(base, l))
	wd.draw_polyline(wd.diamond(p), wd.shade(Color(0.13, 0.14, 0.16), l), 1.0)
	var c: Vector2 = wd.iso(p)
	if wet:
		var a := 0.08 + 0.06 * sin(wd.time * 1.7 + i * 1.3 + j)
		wd.draw_line(c + Vector2(-14, -2), c + Vector2(6, -5), Color(0.6, 0.7, 0.85, a * l * 2.0), 1.0)
	# pedrinhas e lascas de osso
	if h % 4 == 1:
		wd.draw_rect(Rect2(c + Vector2((h % 23) - 11, (h % 9) - 4), Vector2(3, 2)), wd.shade(Color(0.38, 0.39, 0.42), l))
	if h % 13 == 2:
		var b: Vector2 = c + Vector2((h % 17) - 8, (h % 7) - 3)
		wd.draw_line(b, b + Vector2(6, 2), wd.shade(BONE_DARK, l), 1.5)


static func water_tile(wd, i: int, j: int, l: float) -> void:
	var p := Vector2(i + 0.5, j + 0.5)
	var wave := 0.5 + 0.5 * sin(wd.time * 0.6 + i * 0.5 + j * 0.8)
	var base := Color(0.05, 0.07, 0.1).lerp(Color(0.07, 0.095, 0.13), wave)
	wd.draw_colored_polygon(wd.diamond(p), wd.shade(base, maxf(l, 0.6)))
	var h: int = wd._hash(i, j)
	var c: Vector2 = wd.iso(p)
	# brilhos frios na superfície parada
	if h % 6 == 0:
		var a := (0.04 + 0.05 * sin(wd.time * 0.9 + h)) * clampf(l + 0.4, 0.0, 1.0)
		var dx := sin(wd.time * 0.3 + h) * 4.0
		wd.draw_line(c + Vector2(-10 + dx, (h % 9) - 4), c + Vector2(4 + dx, (h % 9) - 4), Color(0.55, 0.65, 0.8, a), 1.0)
	# a água batendo na margem
	for d in [[Vector2i(1, 0), Vector2(0, TH / 2), Vector2(TW / 2, 0)], [Vector2i(0, 1), Vector2(-TW / 2, 0), Vector2(0, TH / 2)]]:
		var n: Vector2i = d[0]
		var t: String = wd.tile(i + n.x, j + n.y)
		if t != "~" and t != "#":
			var a2 := 0.12 + 0.1 * sin(wd.time * 1.4 + i + j * 0.7)
			wd.draw_line(c + d[1] * 0.95, c + d[2] * 0.95, Color(0.62, 0.7, 0.8, a2 * clampf(l + 0.3, 0.0, 1.0)), 1.5)


# Brilho animado por cima da água pintada: reflexos curtos que acendem e apagam devagar.
static func water_overlay(wd) -> void:
	for j in wd.h:
		for i in wd.w:
			if wd.grid[j][i] != "~":
				continue
			var h: int = wd._hash(i, j)
			if h % 3 != 0:
				continue
			var a := 0.5 + 0.5 * sin(wd.time * (0.5 + (h % 5) * 0.12) + h)
			if a < 0.55:
				continue
			var c: Vector2 = wd.iso(Vector2(i + 0.5, j + 0.5)) + Vector2((h % 31) - 15, (h % 13) - 6)
			var len := 3 + h % 5
			c = c.floor()
			wd.draw_rect(Rect2(c, Vector2(len, 1)), Color(0.42, 0.55, 0.62, (a - 0.55) * 0.9))


# ---------- penhascos, pedras, ossos, árvores e runas ----------

static func _center(wd, t: Vector2i) -> Vector2:
	return wd.iso(Vector2(t.x + 0.5, t.y + 0.5))


# Pedra viva: blocos irregulares; os da frente do mapa ficam baixos para não esconder a Branca.
static func cliff(wd, t: Vector2i) -> void:
	var h: int = wd._hash(t.x, t.y)
	var front: bool = t.y == wd.h - 1 or t.x == wd.w - 1
	var name := "penhasco_baixo_%d" % (h % 3) if front else "penhasco_%d" % (h % 6)
	Arte.draw(wd, name, _center(wd, t), (h / 7) % 2 == 0, Color.WHITE, 0.55 + 0.25 * sin(wd.time * 1.3 + h))


static func rock(wd, t: Vector2i) -> void:
	var h: int = wd._hash(t.x, t.y)
	Arte.draw(wd, "pedra_%d" % (h % 3), _center(wd, t), (h / 3) % 2 == 0)


# Costelas enormes saindo da terra, meio enterradas.
static func bones(wd, t: Vector2i) -> void:
	var h: int = wd._hash(t.x, t.y)
	Arte.draw(wd, "ossos_%d" % (h % 2), _center(wd, t), (h / 3) % 2 == 0)


# Árvore morta, seca e retorcida.
static func roots(wd, t: Vector2i) -> void:
	var h: int = wd._hash(t.x, t.y)
	Arte.draw(wd, "arvore_%d" % (h % 2), _center(wd, t), (h / 5) % 2 == 0)


# Pedra de runa: luz laranja. Algumas falham, como máquinas velhas da margem.
static func rune_level(wd, t: Vector2i) -> float:
	var h: int = wd._hash(t.x, t.y)
	var k := 0.75 + 0.2 * sin(wd.time * 2.0 + h)
	if h % 3 == 0:
		var f := sin(wd.time * 6.3 + h) * sin(wd.time * 1.7 + h * 0.3)
		k *= 0.15 if f > 0.55 else 1.0
	return k


static func runestone(wd, t: Vector2i) -> void:
	var h: int = wd._hash(t.x, t.y)
	Arte.draw(wd, "runa_%d" % (h % 3), _center(wd, t), false, Color.WHITE, rune_level(wd, t))


# ---------- casa da Nanshe ----------

# Casa de pedra viva com chifres de osso nas quinas e no telhado. `r` é o retângulo em casas (3 x 3);
# o sprite é preso pela quina da frente.
static func house(wd, r: Rect2i, _door_lit: bool) -> void:
	Arte.draw(wd, "casa_nanshe", wd.iso(Vector2(r.end.x, r.end.y)), false, Color.WHITE, 0.8 + 0.2 * sin(wd.time * 1.1))


# ---------- dentro de casa ----------

static func wall(wd, t: Vector2i, low: bool, rune: bool) -> void:
	var h: int = wd._hash(t.x, t.y)
	var name := "parede_baixa_%d" % (h % 2) if low else ("parede_runa" if rune else "parede_%d" % (h % 3))
	Arte.draw(wd, name, _center(wd, t), (h / 3) % 2 == 0 and not rune, Color.WHITE, 0.6 + 0.4 * sin(wd.time * 2.0 + t.x))


static func bed(wd, t: Vector2i, hidden: bool) -> void:
	var c := _center(wd, t)
	Arte.draw(wd, "cama", c)
	if hidden:
		# olhos da Branca espiando debaixo da cama
		_eyes(wd, c + Vector2(-4, -3))


static func wardrobe(wd, t: Vector2i, hidden: bool) -> void:
	var c := _center(wd, t)
	Arte.draw(wd, "armario", c)
	if hidden:
		# olhos da Branca espiando pela fresta
		_eyes(wd, c + Vector2(-14, -36))


static func _eyes(wd, p: Vector2) -> void:
	var col: Color = wd.glow_mod(0.9) * Color(0.85, 0.93, 1.0)
	wd.draw_rect(Rect2(p.round(), Vector2(1, 1)), col)
	wd.draw_rect(Rect2(p.round() + Vector2(3, 0), Vector2(1, 1)), col)


static func table(wd, t: Vector2i) -> void:
	Arte.draw(wd, "mesa", _center(wd, t))


# Luminária de runa: uma pedra pequena que acende quente dentro de casa.
static func lamp(wd, t: Vector2i) -> void:
	Arte.draw(wd, "luminaria", _center(wd, t), false, Color.WHITE, 0.8 + 0.2 * sin(wd.time * 2.6))


static func chest(wd, t: Vector2i) -> void:
	Arte.draw(wd, "bau", _center(wd, t), false, Color.WHITE, 0.6 + 0.4 * sin(wd.time * 2.0))


# ---------- névoa ----------

# Névoa baixa que passa devagar; desenhada por último e clareada para aparecer mesmo longe da luz.
static func mist(wd, spots: Array) -> void:
	for m in spots:
		var cyc: float = fmod(wd.time * m.speed + m.phase, 6.0)
		var p: Vector2 = m.pos + Vector2(cyc - 3.0, 0)
		var edge: float = clampf(1.0 - abs(cyc - 3.0) / 3.0, 0.0, 1.0)
		var a: float = m.alpha * (0.7 + 0.3 * sin(wd.time * 0.4 + m.phase)) * edge * 14.0
		var name := "nevoa_%d" % (int(m.phase * 10.0) % 3)
		var t: Texture2D = Arte.tex(name)
		if t == null:
			continue
		var sz: Vector2 = (t.get_size() * m.r / 70.0).round()
		var c: Vector2 = wd.iso(p) + Vector2(0, -6)
		wd.draw_texture_rect(t, Rect2((c - sz / 2.0).round(), sz), false, wd.glow_mod(minf(a, 0.6)) * Color(0.55, 0.6, 0.7))


# ---------- personagens ----------

# Nanshe: Gall alta e magra, chifres curvos com contas, olhos que brilham, xale com padrões e braços
# longos com garras (ficha arte/referencias/nanshe-escolhida.png). `pose`: "em_pe" ou "agachada".
static func nanshe(wd, pos: Vector2, pose: String, facing_left: bool) -> void:
	wd._shadow(wd.iso(pos), 12.0)
	Arte.draw(wd, "nanshe_" + pose, wd.iso(pos), facing_left)


# Branca deitada (desacordada) ou sentada (acordando). Em pé é desenhada pelo world.gd.
static func branca_pose(wd, pos: Vector2, pose: String) -> void:
	var s: Vector2 = wd.iso(pos)
	wd._shadow(s, 16.0 if pose == "deitada" else 11.0)
	Arte.draw(wd, "branca_" + pose, s)
