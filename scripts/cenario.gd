# Desenho do cenário de Kurnugi por código: margem do lago (água escura, névoa, pedra viva, ossos,
# raízes secas, pedras de runa), a casa da Nanshe e os móveis de dentro, a Nanshe e as poses da Branca.
# Fica no lugar dos sprites até a arte em pixel chegar (SpriteCook); as cores seguem a ficha da Nanshe.
extends RefCounted

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


# ---------- penhascos e pedras ----------

# Pedra viva: blocos irregulares; os da frente do mapa ficam baixos para não esconder a Branca.
static func cliff(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var h: int = wd._hash(t.x, t.y)
	var front: bool = t.y == wd.h - 1 or t.x == wd.w - 1
	var height := 16.0 + (h % 4) * 3.0 if front else 52.0 + (h % 5) * 9.0
	var l: float = maxf(wd.light_at(p + Vector2(0.6, 0.6)), 0.1)
	var c: Vector2 = wd.iso(p)
	var col := STONE.lerp(NAVY, 0.25 + (h % 3) * 0.1)
	var j1 := (h % 7) - 3.0
	var j2 := ((h / 7) % 7) - 3.0
	var top := [c + Vector2(0, -TH / 2 - height + j1), c + Vector2(TW / 2, -height + j2), c + Vector2(0, TH / 2 - height - j1 * 0.5), c + Vector2(-TW / 2, -height - j2 * 0.5)]
	var left := PackedVector2Array([c + Vector2(-TW / 2, 0), c + Vector2(0, TH / 2), top[2], top[3]])
	var right := PackedVector2Array([c + Vector2(0, TH / 2), c + Vector2(TW / 2, 0), top[1], top[2]])
	wd.draw_colored_polygon(left, wd.shade(wd.mul(col, 0.72), l))
	wd.draw_colored_polygon(right, wd.shade(wd.mul(col, 0.5), l))
	wd.draw_colored_polygon(PackedVector2Array(top), wd.shade(wd.mul(col, 1.1), l))
	# veias da pedra viva
	var vein: Color = wd.shade(wd.mul(col, 0.38), l)
	wd.draw_line(c + Vector2(-TW / 4, TH / 4 - 4), c + Vector2(-TW / 4 + 6, TH / 4 - height * 0.6), vein, 1.0)
	wd.draw_line(c + Vector2(TW / 5, TH / 5 - 8), c + Vector2(TW / 5 - 4, TH / 5 - height * 0.45), vein, 1.0)
	if not front and h % 9 == 0:
		# runa apagada gravada na pedra
		var rc := c + Vector2(TW / 4, TH / 4 - height * 0.5)
		var a := 0.25 + 0.2 * sin(wd.time * 1.3 + h)
		wd.draw_line(rc + Vector2(-3, -5), rc + Vector2(3, 5), Color(RUNE, a), 1.5)
		wd.draw_line(rc + Vector2(0, -6), rc + Vector2(0, 6), Color(RUNE, a), 1.0)


static func rock(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.12)
	var h: int = wd._hash(t.x, t.y)
	wd._shadow(c + Vector2(0, 2), 18.0)
	var k := 0.8 + (h % 3) * 0.12
	var pts := PackedVector2Array([c + Vector2(-17, 0) * k, c + Vector2(-12, -14) * k, c + Vector2(-2, -20) * k, c + Vector2(10, -17) * k, c + Vector2(17, -4) * k, c + Vector2(9, 6) * k, c + Vector2(-8, 6) * k])
	wd.draw_colored_polygon(pts, wd.shade(SLATE, l))
	wd.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -14) * k, c + Vector2(-2, -20) * k, c + Vector2(10, -17) * k, c + Vector2(2, -9) * k]), wd.shade(wd.mul(SLATE, 1.25), l))
	wd.draw_colored_polygon(PackedVector2Array([c + Vector2(17, -4) * k, c + Vector2(9, 6) * k, c + Vector2(2, -2) * k]), wd.shade(wd.mul(SLATE, 0.6), l))


# Costelas enormes saindo da terra, meio enterradas.
static func bones(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.14)
	var h: int = wd._hash(t.x, t.y)
	var flip := -1.0 if h % 2 == 0 else 1.0
	wd._shadow(c, 22.0)
	for k in 4:
		var base := c + Vector2((-18 + k * 11) * flip, 4 - k * 2)
		var hgt := 34.0 + k * 9.0 - (k * k) * 2.0
		var pts := PackedVector2Array()
		for s in 9:
			var u := s / 8.0
			pts.append(base + Vector2(sin(u * 1.6) * 16.0 * flip, -u * hgt))
		var col := BONE.lerp(BONE_DARK, 0.15 * k)
		wd.draw_polyline(pts, wd.shade(wd.mul(col, 0.55), l), 5.0)
		wd.draw_polyline(pts, wd.shade(col, l), 3.0)
	# a espinha deitada de onde as costelas saem
	wd.draw_line(c + Vector2(-22 * flip, 6), c + Vector2(20 * flip, -2), wd.shade(BONE_DARK, l), 4.0)


# Raízes secas e retorcidas de uma árvore morta.
static func roots(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.12)
	var h: int = wd._hash(t.x, t.y)
	var wood: Color = wd.shade(Color(0.17, 0.14, 0.13), l)
	var hi: Color = wd.shade(Color(0.28, 0.24, 0.21), l)
	wd._shadow(c, 14.0)
	wd.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 2), c + Vector2(6, 2), c + Vector2(3, -38), c + Vector2(-2, -40)]), wood)
	wd.draw_line(c + Vector2(1, -2), c + Vector2(2, -36), hi, 1.0)
	var sway := sin(wd.time * 0.8 + h) * 1.5
	for b in [[Vector2(0, -34), Vector2(-18, -52), Vector2(-26, -50)], [Vector2(1, -28), Vector2(16, -46), Vector2(24, -58)], [Vector2(-1, -20), Vector2(-14, -28), Vector2(-20, -36)], [Vector2(2, -38), Vector2(6, -56), Vector2(2, -64)]]:
		var a: Vector2 = c + b[0]
		var m: Vector2 = c + b[1] + Vector2(sway * 0.5, 0)
		var e: Vector2 = c + b[2] + Vector2(sway, 0)
		wd.draw_line(a, m, wood, 2.5)
		wd.draw_line(m, e, wood, 1.5)
	# raízes agarrando o chão
	for r in [Vector2(-16, 6), Vector2(14, 5), Vector2(-4, 9)]:
		wd.draw_line(c + Vector2(0, 0), c + r, wood, 2.0)


# Pedra de runa: luz laranja. Algumas falham, como máquinas velhas da margem.
static func rune_level(wd, t: Vector2i) -> float:
	var h: int = wd._hash(t.x, t.y)
	var k := 0.75 + 0.2 * sin(wd.time * 2.0 + h)
	if h % 3 == 0:
		var f := sin(wd.time * 6.3 + h) * sin(wd.time * 1.7 + h * 0.3)
		k *= 0.15 if f > 0.55 else 1.0
	return k


static func runestone(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.15)
	var k := rune_level(wd, t)
	wd._shadow(c, 12.0)
	wd.draw_circle(c + Vector2(0, -22), 26.0, Color(1.0, 0.55, 0.2, 0.05 * k))
	var body := PackedVector2Array([c + Vector2(-9, 2), c + Vector2(9, 2), c + Vector2(7, -36), c + Vector2(1, -44), c + Vector2(-7, -38)])
	wd.draw_colored_polygon(body, wd.shade(wd.mul(STONE, 0.8), l))
	wd.draw_colored_polygon(PackedVector2Array([c + Vector2(1, 2), c + Vector2(9, 2), c + Vector2(7, -36), c + Vector2(1, -44)]), wd.shade(wd.mul(STONE, 0.55), l))
	var g := Color(RUNE, 0.35 + 0.65 * k)
	var o := c + Vector2(-2, -24)
	wd.draw_line(o + Vector2(0, -10), o + Vector2(0, 10), g, 2.0)
	wd.draw_line(o + Vector2(0, -4), o + Vector2(5, -9), g, 1.5)
	wd.draw_line(o + Vector2(0, 2), o + Vector2(-5, 7), g, 1.5)
	wd.draw_circle(o, 9.0, Color(1.0, 0.6, 0.25, 0.12 * k))


# ---------- casa da Nanshe ----------

# Casa de pedra viva com costelas de osso nas quinas e no telhado. `r` é o retângulo em casas.
static func house(wd, r: Rect2i, door_lit: bool) -> void:
	var x0 := float(r.position.x)
	var y0 := float(r.position.y)
	var x1 := float(r.end.x)
	var y1 := float(r.end.y)
	var l: float = maxf(wd.light_at(Vector2(x1, y1)), 0.14)
	var wall := 58.0
	var a: Vector2 = wd.iso(Vector2(x0, y1))  # quina esquerda
	var b: Vector2 = wd.iso(Vector2(x1, y1))  # quina da frente
	var cc: Vector2 = wd.iso(Vector2(x1, y0))  # quina direita
	var back: Vector2 = wd.iso(Vector2(x0, y0))
	var up := Vector2(0, -wall)
	wd._shadow(wd.iso(Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0)), 52.0)
	var stone := STONE.lerp(NAVY, 0.2)
	# paredes tortas
	wd.draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up + Vector2(2, 4)]), wd.shade(wd.mul(stone, 0.78), l))
	wd.draw_colored_polygon(PackedVector2Array([b, cc, cc + up + Vector2(-2, 5), b + up]), wd.shade(wd.mul(stone, 0.55), l))
	# blocos de pedra
	for k in 4:
		var u := (k + 1) / 5.0
		wd.draw_line(a.lerp(b, u), a.lerp(b, u) + up * (0.6 + 0.1 * (k % 2)), wd.shade(wd.mul(stone, 0.5), l), 1.0)
		wd.draw_line(b.lerp(cc, u), b.lerp(cc, u) + up * (0.5 + 0.1 * (k % 2)), wd.shade(wd.mul(stone, 0.35), l), 1.0)
	for k in 3:
		var v := (k + 1) / 4.0
		wd.draw_line(a + up * v, b + up * v, wd.shade(wd.mul(stone, 0.5), l), 1.0)
		wd.draw_line(b + up * v, cc + up * v, wd.shade(wd.mul(stone, 0.35), l), 1.0)
	# telhado íngreme de lascas de pedra escura
	var ridge_a: Vector2 = wd.iso(Vector2(x0, (y0 + y1) / 2.0)) + up + Vector2(0, -44)
	var ridge_b: Vector2 = wd.iso(Vector2(x1, (y0 + y1) / 2.0)) + up + Vector2(0, -44)
	var roof: Color = wd.mul(NAVY, 1.4)
	wd.draw_colored_polygon(PackedVector2Array([a + up + Vector2(-6, 4), b + up + Vector2(0, 6), ridge_b, ridge_a]), wd.shade(wd.mul(roof, 0.9), l))
	wd.draw_colored_polygon(PackedVector2Array([b + up + Vector2(0, 6), cc + up + Vector2(6, 4), ridge_b]), wd.shade(wd.mul(roof, 0.6), l))
	for k in 6:
		var u := (k + 0.5) / 6.0
		var e1: Vector2 = (a + up).lerp(b + up, u) + Vector2(0, 5)
		var e2: Vector2 = ridge_a.lerp(ridge_b, u)
		wd.draw_line(e1, e2, wd.shade(wd.mul(roof, 0.55), l), 1.0)
	# costelas de osso nas quinas e na cumeeira, como chifres
	var bone: Color = wd.shade(BONE, l)
	var bone_d: Color = wd.shade(BONE_DARK, l)
	for q in [[a, Vector2(-14, -10)], [b, Vector2(4, -14)], [cc, Vector2(14, -10)]]:
		var base: Vector2 = q[0]
		var pts := PackedVector2Array()
		for s in 8:
			var u := s / 7.0
			pts.append(base + up * u * 1.2 + q[1] * u * u)
		wd.draw_polyline(pts, bone_d, 5.0)
		wd.draw_polyline(pts, bone, 3.0)
	for end in [ridge_a, ridge_b]:
		wd.draw_line(end, end + Vector2(0, -18), bone_d, 4.0)
		wd.draw_line(end + Vector2(0, -18), end + Vector2(-5 if end == ridge_a else 5, -30), bone, 2.5)
	# porta em arco na parede da esquerda, emoldurada de osso
	var dc: Vector2 = a.lerp(b, 0.5)
	var door := PackedVector2Array([dc + Vector2(-9, -4), dc + Vector2(9, 5), dc + Vector2(9, -26), dc + Vector2(4, -34), dc + Vector2(-4, -36), dc + Vector2(-9, -30)])
	wd.draw_colored_polygon(door, Color(0.02, 0.02, 0.03) if not door_lit else Color(0.16, 0.08, 0.04))
	wd.draw_polyline(door + PackedVector2Array([door[0]]), bone_d, 2.0)
	# janela redonda com luz de runa lá dentro
	var wc: Vector2 = b.lerp(cc, 0.45) + up * 0.6
	var glow := 0.55 + 0.25 * sin(wd.time * 1.1)
	wd.draw_circle(wc, 7.0, Color(0.9, 0.5, 0.2, 0.75 * glow))
	wd.draw_circle(wc, 16.0, Color(1.0, 0.55, 0.2, 0.06 * glow))
	wd.draw_arc(wc, 7.0, 0, TAU, 14, bone_d, 2.0)
	wd.draw_line(wc + Vector2(-7, 0), wc + Vector2(7, 0), bone_d, 1.0)


# ---------- móveis da casa ----------

static func bed(wd, t: Vector2i, hidden: bool) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.18)
	var legs := 7.0  # baixa, mas com vão para a Branca caber embaixo
	var thick := 7.0
	var sc := 0.9
	var hw := TW * 0.5 * sc
	var hh := TH * 0.5 * sc
	wd._shadow(c + Vector2(0, 2), hw)
	# vão escuro embaixo da cama
	wd.draw_colored_polygon(wd.diamond(p, 0.0, sc * 0.9), Color(0.0, 0.0, 0.01, 0.75))
	for f in [Vector2(-hw + 3, 0), Vector2(0, hh - 2), Vector2(hw - 3, 0)]:
		wd.draw_line(c + f, c + f + Vector2(0, -legs), wd.shade(BONE_DARK, l), 3.0)
	# estrado de madeira escura
	var y1 := legs + thick
	var left := PackedVector2Array([c + Vector2(-hw, -legs), c + Vector2(0, hh - legs), c + Vector2(0, hh - y1), c + Vector2(-hw, -y1)])
	var right := PackedVector2Array([c + Vector2(0, hh - legs), c + Vector2(hw, -legs), c + Vector2(hw, -y1), c + Vector2(0, hh - y1)])
	wd.draw_colored_polygon(left, wd.shade(wd.mul(BROWN, 0.85), l))
	wd.draw_colored_polygon(right, wd.shade(wd.mul(BROWN, 0.6), l))
	var top: PackedVector2Array = wd.diamond(p, y1, sc)
	wd.draw_colored_polygon(top, wd.shade(wd.mul(BONE_DARK, 0.8), l))
	# manta remendada com o padrão dos Gall, e um travesseiro de pano
	var cloth: PackedVector2Array = wd.diamond(p + Vector2(0.08, 0.08), y1 + 2, sc * 0.78)
	wd.draw_colored_polygon(cloth, wd.shade(WINE.lerp(NAVY, 0.35), l))
	for k in 4:
		var cp: Vector2 = c + Vector2(-12 + k * 8, -y1 - 1 + (k % 2) * 3)
		wd.draw_rect(Rect2(cp, Vector2(3, 2)), wd.shade(BONE, l))
	var pil: Vector2 = wd.iso(p + Vector2(-0.28, -0.28)) + Vector2(0, -y1 - 3)
	wd.draw_set_transform(pil, 0.0, Vector2(1.0, 0.5))
	wd.draw_circle(Vector2.ZERO, 9.0, wd.shade(Color(0.6, 0.57, 0.5), l))
	wd.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hidden:
		# olhos da Branca espiando debaixo da cama
		var e := c + Vector2(-4, -2)
		wd.draw_rect(Rect2(e, Vector2(2, 1)), Color(0.8, 0.9, 1.0, 0.9))
		wd.draw_rect(Rect2(e + Vector2(4, 0), Vector2(2, 1)), Color(0.8, 0.9, 1.0, 0.9))


static func table(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.15)
	var hgt := 22.0
	wd._shadow(c, 16.0)
	for f in [Vector2(-14, 0), Vector2(0, 7), Vector2(14, 0)]:
		wd.draw_line(c + f, c + f + Vector2(0, -hgt), wd.shade(BROWN, l), 2.0)
	wd.draw_colored_polygon(wd.diamond(p, hgt, 0.6), wd.shade(wd.mul(STONE, 0.9), l))
	# tigela de osso e um pano
	wd.draw_circle(c + Vector2(-3, -hgt - 3), 4.0, wd.shade(BONE, l))
	wd.draw_rect(Rect2(c + Vector2(3, -hgt - 3), Vector2(7, 3)), wd.shade(WINE, l))


# Luminária de runa: uma pedra pequena que acende quente dentro de casa.
static func lamp(wd, t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var c: Vector2 = wd.iso(p)
	var l: float = maxf(wd.light_at(p), 0.2)
	var k := 0.8 + 0.2 * sin(wd.time * 2.6)
	wd._shadow(c, 9.0)
	wd.draw_line(c, c + Vector2(0, -26), wd.shade(BONE_DARK, l), 3.0)
	wd.draw_circle(c + Vector2(0, -30), 6.0, Color(1.0, 0.6, 0.25, 0.9 * k))
	wd.draw_circle(c + Vector2(0, -30), 14.0, Color(1.0, 0.55, 0.2, 0.12 * k))
	wd.draw_arc(c + Vector2(0, -30), 7.0, PI, TAU, 10, wd.shade(BONE, l), 2.0)


# ---------- névoa ----------

static func mist(wd, spots: Array) -> void:
	for m in spots:
		var p: Vector2 = m.pos + Vector2(fmod(wd.time * m.speed + m.phase, 6.0) - 3.0, 0)
		var s: Vector2 = wd.iso(p) + Vector2(0, -6)
		var a: float = m.alpha * (0.7 + 0.3 * sin(wd.time * 0.4 + m.phase))
		var edge: float = clampf(1.0 - abs(fmod(wd.time * m.speed + m.phase, 6.0) - 3.0) / 3.0, 0.0, 1.0)
		wd.draw_set_transform(s, 0.0, Vector2(1.0, 0.38))
		for k in 8:
			wd.draw_circle(Vector2.ZERO, m.r * (1.0 - k * 0.11), Color(0.6, 0.67, 0.78, a * edge * 0.9))
		wd.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- personagens ----------

# Nanshe: Gall alta e magra, chifres curvos com contas, olhos que brilham, xale com padrões e
# braços longos com garras (ficha arte/referencias/nanshe-escolhida.png). `pose`: "em_pe" ou "agachada".
static func nanshe(wd, pos: Vector2, pose: String, facing_left: bool) -> void:
	var s: Vector2 = wd.iso(pos)
	var l: float = maxf(wd.light_at(pos), 0.3)
	wd._shadow(s, 12.0)
	var flip := -1.0 if facing_left else 1.0
	var sy := 0.64 if pose == "agachada" else 1.0
	var breathe := sin(wd.time * 1.4) * 0.6
	wd.draw_set_transform(s, 0.0, Vector2(flip, sy))
	var skin: Color = wd.shade(Color(0.42, 0.44, 0.5), l)
	var skin_d: Color = wd.shade(Color(0.3, 0.31, 0.37), l)
	var claw: Color = wd.shade(Color(0.12, 0.11, 0.12), l)
	# pernas finas com pés de garra
	wd.draw_line(Vector2(-3, -24), Vector2(-4, 0), skin_d, 2.0)
	wd.draw_line(Vector2(3, -24), Vector2(4, 0), skin_d, 2.0)
	for f in [-1.0, 1.0]:
		for k in 3:
			wd.draw_line(Vector2(4 * f, 0), Vector2(4 * f + (k - 1) * 3 + f * 2, 2), claw, 1.0)
	# saia em tiras (marrom, azul-marinho, vinho)
	var strips := [BROWN, NAVY, WINE, BROWN, NAVY, BROWN]
	for k in strips.size():
		var x := -9.0 + k * 3.2
		var len := 24.0 + float(k % 3) * 4.0 + sin(wd.time * 1.2 + k) * 1.0
		wd.draw_rect(Rect2(Vector2(x, -46), Vector2(3.2, len)), wd.shade(strips[k], maxf(l, 0.2)))
	# tronco magro
	wd.draw_colored_polygon(PackedVector2Array([Vector2(-6, -66), Vector2(6, -66), Vector2(5, -44), Vector2(-5, -44)]), skin_d)
	# xale com padrão
	var shawl := PackedVector2Array([Vector2(-11, -68 + breathe), Vector2(11, -68 + breathe), Vector2(14, -50), Vector2(6, -46), Vector2(0, -50), Vector2(-6, -46), Vector2(-14, -50)])
	wd.draw_colored_polygon(shawl, wd.shade(NAVY.lerp(SLATE, 0.3), maxf(l, 0.2)))
	for k in 5:
		wd.draw_rect(Rect2(Vector2(-9 + k * 4, -60 + (k % 2) * 3), Vector2(2, 2)), wd.shade(BONE, maxf(l, 0.2)))
	wd.draw_line(Vector2(-12, -51), Vector2(12, -51), wd.shade(WINE, maxf(l, 0.2)), 1.0)
	# braços longos até abaixo dos joelhos, com garras compridas
	for f in [-1.0, 1.0]:
		var sh := Vector2(10 * f, -64)
		var el := Vector2(13 * f, -44)
		var wr := Vector2(12 * f, -24)
		wd.draw_line(sh, el, skin, 2.0)
		wd.draw_line(el, wr, skin, 2.0)
		for k in 4:
			wd.draw_line(wr, wr + Vector2((k - 1.5) * 1.6, 9 + k % 2 * 2), claw, 1.0)
		wd.draw_line(wr + Vector2(0, -4), wr + Vector2(0, -2), wd.shade(BONE_DARK, l), 2.0)  # bracelete
	# cabeça, cabelo preto e chifres curvos
	var hd := Vector2(0, -76 + breathe)
	wd.draw_rect(Rect2(hd + Vector2(-6, -2), Vector2(12, 26)), wd.shade(Color(0.04, 0.04, 0.05), maxf(l, 0.4)))
	wd.draw_rect(Rect2(hd + Vector2(-4, -1), Vector2(8, 11)), skin)
	var horn: Color = wd.shade(Color(0.2, 0.18, 0.17), maxf(l, 0.3))
	for f in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for k in 9:
			var a := k / 8.0 * 4.2
			pts.append(hd + Vector2(5 * f, -2) + Vector2(cos(a) * 6.0 * f + 3 * f, -sin(a) * 5.0 - k * 0.5))
		wd.draw_polyline(pts, horn, 2.5)
		# contas penduradas nos chifres
		wd.draw_line(hd + Vector2(10 * f, -4), hd + Vector2(10 * f, 6), wd.shade(BONE_DARK, l), 1.0)
		wd.draw_rect(Rect2(hd + Vector2(10 * f - 1, 6), Vector2(2, 3)), wd.shade(BONE, l))
	# olhos que brilham
	var eye := Color(EYE, 0.95)
	wd.draw_rect(Rect2(hd + Vector2(-3, 3), Vector2(2, 1.5)), eye)
	wd.draw_rect(Rect2(hd + Vector2(1, 3), Vector2(2, 1.5)), eye)
	wd.draw_circle(hd + Vector2(0, 4), 7.0, Color(EYE, 0.07))
	wd.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Branca deitada (desacordada) ou sentada (acordando). Em pé é desenhada pelo world.gd.
static func branca_pose(wd, pos: Vector2, pose: String) -> void:
	var s: Vector2 = wd.iso(pos)
	var l: float = wd.light_at(pos)
	var dress: Color = wd.shade(Color(0.85, 0.85, 0.8), maxf(l, 0.25))
	var dress_d: Color = wd.shade(Color(0.6, 0.6, 0.58), maxf(l, 0.25))
	var skin: Color = wd.shade(Color(0.82, 0.8, 0.78), l)
	var hair: Color = wd.shade(Color(0.04, 0.04, 0.05), maxf(l, 0.5))
	var glow := Color(0.8, 0.9, 1.0, clampf(1.2 - l, 0.25, 0.9))
	if pose == "deitada":
		wd._shadow(s, 16.0)
		# cabelo espalhado no chão molhado
		wd.draw_colored_polygon(PackedVector2Array([s + Vector2(-26, -6), s + Vector2(-14, -9), s + Vector2(-10, -2), s + Vector2(-16, 4), s + Vector2(-28, 3)]), hair)
		wd.draw_line(s + Vector2(-22, 2), s + Vector2(-30, 6), hair, 2.0)
		# rosto virado para cima, olhos fechados
		wd.draw_rect(Rect2(s + Vector2(-17, -6), Vector2(7, 6)), skin)
		wd.draw_rect(Rect2(s + Vector2(-16, -9), Vector2(2, 2)), wd.shade(Color(0.2, 0.18, 0.18), l))
		# vestido branco rasgado, encharcado
		wd.draw_colored_polygon(PackedVector2Array([s + Vector2(-10, -6), s + Vector2(10, -6), s + Vector2(16, -8), s + Vector2(17, -1), s + Vector2(13, 1), s + Vector2(10, -1), s + Vector2(6, 2), s + Vector2(-10, 1)]), dress)
		wd.draw_line(s + Vector2(-8, -1), s + Vector2(12, -1), dress_d, 1.0)
		# braço caído e pés descalços
		wd.draw_line(s + Vector2(-6, 0), s + Vector2(4, 4), skin, 2.0)
		wd.draw_rect(Rect2(s + Vector2(17, -6), Vector2(4, 2)), skin)
		wd.draw_rect(Rect2(s + Vector2(17, -3), Vector2(4, 2)), skin)
	else:
		wd._shadow(s, 11.0)
		# sentada, com as pernas para a frente
		wd.draw_rect(Rect2(s + Vector2(-6, -36), Vector2(12, 26)), hair)
		wd.draw_colored_polygon(PackedVector2Array([s + Vector2(-6, -22), s + Vector2(5, -22), s + Vector2(8, -2), s + Vector2(16, -3), s + Vector2(17, 2), s + Vector2(-8, 2)]), dress)
		wd.draw_rect(Rect2(s + Vector2(16, -2), Vector2(4, 3)), skin)
		wd.draw_rect(Rect2(s + Vector2(-8, -20), Vector2(2, 14)), skin)
		wd.draw_rect(Rect2(s + Vector2(-3, -33), Vector2(6, 8)), skin)
		wd.draw_rect(Rect2(s + Vector2(-5, -37), Vector2(10, 4)), hair)
		wd.draw_rect(Rect2(s + Vector2(-5, -39), Vector2(2, 2)), wd.shade(Color(0.2, 0.18, 0.18), l))
		wd.draw_rect(Rect2(s + Vector2(3, -39), Vector2(2, 2)), wd.shade(Color(0.2, 0.18, 0.18), l))
		wd.draw_rect(Rect2(s + Vector2(-2, -30), Vector2(1, 1)), glow)
		wd.draw_rect(Rect2(s + Vector2(1, -30), Vector2(1, 1)), glow)
