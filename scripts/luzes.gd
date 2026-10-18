# Luz do mundo: o escuro da área (CanvasModulate) e as luzes de verdade (PointLight2D) que iluminam
# o chão, as paredes e os personagens: a Branca, a lanterna, as pedras de runa, as luminárias,
# as janelas e os pontos de sinal.
extends Node2D

const TEX_SIZE := 256
const TILE_SCREEN := 45.25  # uma casa do mapa em pixels de tela (meia diagonal do losango)

var wd
var modulate_node: CanvasModulate
var player_light: PointLight2D
var flash_light: PointLight2D
var lights: Array = []  # [PointLight2D, dados do world.lights]
var signal_lights: Array = []

static var _round_tex: Texture2D
static var _cone_tex: Texture2D


func _ready() -> void:
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	player_light = _make(4.6, Color(0.78, 0.84, 0.95), 0.95)
	flash_light = PointLight2D.new()
	flash_light.texture = _cone()
	flash_light.color = Color(0.9, 0.95, 1.0)
	flash_light.energy = 0.0
	flash_light.offset = Vector2(TEX_SIZE / 2.0, 0)
	add_child(flash_light)


static func _round() -> Texture2D:
	if _round_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = TEX_SIZE
		t.height = TEX_SIZE
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_round_tex = t
	return _round_tex


# Cone da lanterna: abre para a direita a partir do meio da borda esquerda.
static func _cone() -> Texture2D:
	if _cone_tex == null:
		var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
		for y in TEX_SIZE:
			for x in TEX_SIZE:
				var v := Vector2(x, y - TEX_SIZE / 2.0)
				var d := v.length() / TEX_SIZE
				var ang := absf(v.angle())
				var a := clampf(1.0 - ang / 0.55, 0.0, 1.0) * clampf(1.0 - d, 0.0, 1.0) * clampf(d * 8.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_cone_tex = ImageTexture.create_from_image(img)
	return _cone_tex


func _make(radius: float, color: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _round()
	l.texture_scale = radius * TILE_SCREEN * 2.0 / TEX_SIZE
	l.scale = Vector2(1.0, 0.62)  # achatada como o chão isométrico
	l.color = color
	l.energy = energy
	add_child(l)
	return l


# Refaz as luzes fixas da área que acabou de carregar.
func rebuild() -> void:
	for l in lights:
		l[0].queue_free()
	for l in signal_lights:
		l.queue_free()
	lights = []
	signal_lights = []
	modulate_node.color = Color(0.27, 0.31, 0.42) if wd.estilo == "exterior" else Color(0.2, 0.19, 0.23)
	for lt in wd.lights:
		var spec: Array
		match lt.kind:
			"runa": spec = [3.0, Color(1.0, 0.55, 0.22), 1.25]
			"lampada": spec = [4.6, Color(1.0, 0.68, 0.38), 1.15]
			_: spec = [2.6, Color(1.0, 0.6, 0.3), 0.9]
		var l := _make(spec[0], spec[1], spec[2])
		l.position = wd.iso(lt.pos) - Vector2(0, 18)
		lights.append([l, lt, spec[2]])
	for s in wd.signals:
		var l := _make(2.8, Color(0.45, 0.85, 1.0), 0.75)
		l.position = wd.iso(s) - Vector2(0, 14)
		signal_lights.append(l)


func _process(_delta: float) -> void:
	if wd == null:
		return
	for l in lights:
		l[0].energy = l[2] * l[1].k
	player_light.position = wd.iso(wd.player_pos) - Vector2(0, 20)
	player_light.visible = not wd.player_hidden
	var f: float = wd.flash_t / 0.35
	flash_light.energy = 2.2 * f
	flash_light.visible = f > 0.0
	if f > 0.0:
		var dir: Vector2 = wd.iso(wd.player_pos + wd.facing) - wd.iso(wd.player_pos)
		flash_light.position = wd.iso(wd.player_pos) - Vector2(0, 20)
		flash_light.rotation = dir.angle()
		flash_light.texture_scale = wd.FLASH_RANGE * TILE_SCREEN / TEX_SIZE * 1.1
