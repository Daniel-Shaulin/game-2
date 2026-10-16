# Ícones dos itens, desenhados por código (PROVISÓRIOS até a arte do passo 16).
# Usado no chão do mapa, no baú e onde mais um item aparecer.
extends RefCounted


# Desenha o ícone do item `id` centrado em `c`, com `s` pixels de lado.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, alpha := 1.0) -> void:
	var lw := maxf(1.0, s * 0.07)
	match id:
		"curativo":
			# rolo de atadura com a ponta solta
			var cloth := Color(0.86, 0.84, 0.78, alpha)
			ci.draw_rect(Rect2(c + Vector2(0.0, 0.12 * s), Vector2(0.46 * s, 0.22 * s)), cloth)
			ci.draw_circle(c, 0.36 * s, cloth)
			ci.draw_arc(c, 0.24 * s, 0.0, TAU, 20, Color(0.62, 0.6, 0.55, alpha), lw)
			ci.draw_circle(c, 0.09 * s, Color(0.4, 0.38, 0.35, alpha))
			ci.draw_rect(Rect2(c + Vector2(0.3 * s, 0.14 * s), Vector2(0.12 * s, 0.06 * s)), Color(0.55, 0.12, 0.16, alpha))
		"cha":
			# frasco de vidro com chá escuro e rolha
			var glass := Color(0.7, 0.78, 0.8, 0.55 * alpha)
			var body := Rect2(c + Vector2(-0.26 * s, -0.12 * s), Vector2(0.52 * s, 0.5 * s))
			ci.draw_rect(body, glass)
			ci.draw_rect(Rect2(body.position + Vector2(0.04 * s, 0.14 * s), Vector2(0.44 * s, 0.32 * s)), Color(0.42, 0.26, 0.12, alpha))
			ci.draw_rect(Rect2(c + Vector2(-0.1 * s, -0.3 * s), Vector2(0.2 * s, 0.18 * s)), glass)
			ci.draw_rect(Rect2(c + Vector2(-0.12 * s, -0.42 * s), Vector2(0.24 * s, 0.13 * s)), Color(0.5, 0.36, 0.24, alpha))
			ci.draw_rect(body, Color(0.85, 0.9, 0.92, 0.7 * alpha), false, lw)
		"amuleto":
			# pingente de osso em losango com uma runa acesa
			var bone := Color(0.8, 0.76, 0.66, alpha)
			ci.draw_arc(c + Vector2(0, -0.22 * s), 0.22 * s, PI, TAU, 12, Color(0.45, 0.42, 0.38, alpha), lw)
			var d := PackedVector2Array([c + Vector2(0, -0.2 * s), c + Vector2(0.24 * s, 0.1 * s), c + Vector2(0, 0.44 * s), c + Vector2(-0.24 * s, 0.1 * s)])
			ci.draw_colored_polygon(d, bone)
			ci.draw_line(c + Vector2(0, -0.04 * s), c + Vector2(0, 0.28 * s), Color(1.0, 0.62, 0.22, alpha), lw)
			ci.draw_line(c + Vector2(-0.08 * s, 0.06 * s), c + Vector2(0.08 * s, 0.18 * s), Color(1.0, 0.62, 0.22, alpha), lw)
		_:
			ci.draw_circle(c, 0.3 * s, Color(0.7, 0.7, 0.7, alpha))
