# Sprites em pixel do jogo (arte/sprites, gerados por ferramentas/gerar_arte.py). O índice sprites.json
# guarda, para cada sprite, o ponto onde ele toca o chão ("ancora") e se tem uma camada que brilha no
# escuro (<nome>_brilho.png: runas, janelas, olhos). Essa camada é desenhada logo depois do sprite, com a
# cor compensando o escuro da área (glow_mod do mundo), para brilhar sem passar por cima do que está na frente.
extends RefCounted

const DIR := "res://arte/sprites/"

static var _info: Dictionary = {}
static var _tex: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	_loaded = true
	var f := FileAccess.open(DIR + "sprites.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_info = d


static func has(name: String) -> bool:
	if not _loaded:
		_load()
	return _info.has(name)


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := DIR + name + ".png"
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


static func anchor(name: String) -> Vector2:
	if not has(name):
		return Vector2.ZERO
	var a: Array = _info[name].ancora
	return Vector2(a[0], a[1])


static func size(name: String) -> Vector2:
	var t := tex(name)
	return t.get_size() if t != null else Vector2.ZERO


# Desenha o sprite com a âncora em `ground` (posição no mundo); `flip` espelha para o outro lado.
# `glow_k` é a força da camada que brilha (0 apaga).
static func draw(ci: CanvasItem, name: String, ground: Vector2, flip := false, mod := Color.WHITE, glow_k := 1.0) -> void:
	if not has(name):
		return
	_blit(ci, tex(name), anchor(name), ground.round(), flip, mod)
	if _info[name].brilho and glow_k > 0.01:
		_blit(ci, tex(name + "_brilho"), anchor(name), ground.round(), flip, ci.glow_mod(mod.a * glow_k))


static func _blit(ci: CanvasItem, t: Texture2D, a: Vector2, ground: Vector2, flip: bool, mod: Color) -> void:
	if t == null:
		return
	if flip:
		ci.draw_set_transform(ground, 0.0, Vector2(-1, 1))
		ci.draw_texture(t, -a, mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture(t, ground - a, mod)

