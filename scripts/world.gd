# Exploração isométrica de uma área: mapa, Branca, inimigos, lanterna, esconderijos, sinal, baú,
# itens, dinheiro e saídas para outras áreas. A arte ainda é desenhada por código até chegarem os sprites;
# o cenário de Kurnugi (margem do lago, casa da Nanshe) fica em scripts/cenario.gd.
extends Node2D

const Data := preload("res://scripts/data.gd")
const Itens := preload("res://scripts/itens.gd")
const Areas := preload("res://scripts/areas.gd")
const Cenario := preload("res://scripts/cenario.gd")

const TW := 64.0
const TH := 32.0
const WALL_H := 46.0
const WALK := 3.0
const RUN := 4.8
const RUN_COST := 22.0
const FLASH_COST := 30.0
const FLASH_RANGE := 5.0
const FLASH_ANGLE := 0.6
const STUN_TIME := 5.0
const STAMINA_REGEN := 16.0
const PATROL_SPEED := 1.5
const CHASE_SPEED := 3.5
const SIGHT := 5.0
const RESPAWN := 120.0

var main
var grid: Array = []
var w := 0
var h := 0
var area_id := ""
var area: Dictionary = {}
var exits: Array = []  # saídas para outras áreas
var exit_lock := false
var player_pos := Vector2()
var facing := Vector2(1, 1).normalized()
var moving := false
var escondida := false
var player_hidden := false  # some durante uma cena
var player_pose := "em_pe"  # "em_pe", "sentada" ou "deitada" (cenas)
var estilo := "interior"  # "exterior" = pedra viva e água escura; "interior" = paredes de pedra
var lights: Array = []  # luzes do cenário: pedras de runa, luminárias, janelas
var houses: Array = []  # construções que ocupam várias casas
var mist_spots: Array = []
var hide_tile := Vector2i()
var invuln := 0.0
var flash_t := 0.0
var regen_wait := 0.0
var enemies: Array = []
var coins: Array = []
var signals: Array = []
var runes: Array = []
var npcs: Array = []
var pickups: Array = []  # itens no chão
var time := 0.0
var hint := ""
var cam: Camera2D


func _ready() -> void:
	cam = Camera2D.new()
	cam.zoom = Vector2(1.7, 1.7)
	cam.process_mode = Node.PROCESS_MODE_ALWAYS  # o zoom do celular anima com o mundo pausado
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	cam.make_current()


# Carrega a área (res://areas/<id>.json) e põe a Branca em `pos` (posição no mundo) ou no ponto `ponto`.
# Formato das áreas explicado em areas/LEIAME.md.
func load_area(id: String, pos = null, ponto := "inicio") -> void:
	area = Areas.load_area(id)
	area_id = id
	grid = []
	coins = []
	signals = []
	enemies = []
	runes = []
	npcs = []
	pickups = []
	exits = []
	lights = []
	houses = []
	mist_spots = []
	estilo = area.get("estilo", "interior")
	player_pose = "em_pe"
	player_hidden = false
	for row in area.mapa:
		grid.append(String(row))
	h = grid.size()
	w = grid[0].length()
	for b in area.get("construcoes", []):
		var rect := Rect2i(int(b.x), int(b.y), int(b.get("w", 1)), int(b.get("h", 1)))
		for j in range(rect.position.y, rect.end.y):
			for i in range(rect.position.x, rect.end.x):
				_set_tile(Vector2i(i, j), "H")
		houses.append({"rect": rect, "tipo": b.get("tipo", "casa")})
		# janela acesa na parede da direita
		lights.append({"pos": Vector2(rect.end.x + 0.3, rect.position.y + rect.size.y * 0.45), "r": 2.6, "max": 0.45, "k": 1.0, "kind": "janela"})
	for j in h:
		for i in w:
			match grid[j][i]:
				"R": lights.append({"pos": Vector2(i + 0.5, j + 0.5), "r": 3.4, "max": 0.55, "k": 1.0, "kind": "runa", "tile": Vector2i(i, j)})
				"L": lights.append({"pos": Vector2(i + 0.5, j + 0.5), "r": 4.5, "max": 0.7, "k": 1.0, "kind": "lampada"})
	if area.get("nevoa", false):
		var water: Array = []
		for j in h:
			for i in w:
				if grid[j][i] == "~":
					water.append(Vector2(i + 0.5, j + 0.5))
		for k in mini(26, water.size()):
			var hh := _hash(k * 7, k * 13)
			mist_spots.append({"pos": water[(hh * 31 + k * 97) % water.size()], "r": 40.0 + hh % 50, "alpha": 0.018 + (hh % 5) * 0.004, "speed": 0.08 + (hh % 7) * 0.02, "phase": float(hh % 600) / 100.0})
	for j in h:
		for i in w:
			if grid[j][i] == "S":
				signals.append(Vector2(i + 0.5, j + 0.5))
	for c in area.get("dinheiro", []):
		var key := "%s:%d,%d" % [id, c[0], c[1]]
		if not main.taken.has(key):
			coins.append({"pos": _tile_center(c), "key": key})
	for it in area.get("itens", []):
		var key := "%s:%d,%d" % [id, it.x, it.y]
		if not main.taken_items.has(key):
			pickups.append({"pos": _tile_center([it.x, it.y]), "key": key, "id": it.id})
	for n in area.get("npcs", []):
		if n.has("se") and not main.flags.get(n.se, false):
			continue
		if n.has("se_nao") and main.flags.get(n.se_nao, false):
			continue
		var t := Vector2i(int(n.x), int(n.y))
		_set_tile(t, "N")
		npcs.append({"pos": _tile_center([n.x, n.y]), "tile": t, "data": n})
	for e in area.get("inimigos", []):
		var home := _tile_center([e.x, e.y])
		var path: Array = []
		for p in e.get("rota", [[e.x, e.y]]):
			path.append(_tile_center(p))
		enemies.append({
			"kind": e.tipo, "pos": home, "home": home, "path": path, "path_i": 0,
			"state": "patrol", "stun": 0.0, "alive": true, "respawn": 0.0,
			"last_seen": home, "search_t": 0.0,
		})
	for x in area.get("saidas", []):
		exits.append({"rect": Rect2(x.x, x.y, x.get("w", 1), x.get("h", 1)), "para": x.para, "ponto": x.get("ponto", "inicio")})
	# runas que brilham em algumas paredes (pedra viva com máquinas de runas)
	for j in h:
		for i in w:
			if estilo == "interior" and grid[j][i] == "#" and _hash(i, j) % 11 == 0 and _is_visible_wall(i, j):
				runes.append(Vector2i(i, j))
	var pontos: Dictionary = area.get("pontos", {})
	player_pos = pos if pos != null else _tile_center(pontos.get(ponto, pontos.get("inicio", [1, 1])))
	escondida = false
	invuln = 1.0
	exit_lock = true  # quem chega por uma saída não volta por ela na hora
	cam.position = iso(player_pos)
	cam.reset_smoothing()
	queue_redraw()


func _tile_center(p) -> Vector2:
	return Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5)


func _set_tile(t: Vector2i, c: String) -> void:
	var row: String = grid[t.y]
	grid[t.y] = row.substr(0, t.x) + c + row.substr(t.x + 1)


func _hash(i: int, j: int) -> int:
	return abs((i * 73856093) ^ (j * 19349663)) % 1000


func _is_visible_wall(i: int, j: int) -> bool:
	return tile(i + 1, j) != "#" or tile(i, j + 1) != "#"


func tile(i: int, j: int) -> String:
	if i < 0 or j < 0 or i >= w or j >= h:
		return "#"
	return grid[j][i]


func walkable(i: int, j: int) -> bool:
	var c := tile(i, j)
	return c == "." or c == "S"


func iso(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * TW * 0.5, (p.x + p.y) * TH * 0.5)


func free_at(p: Vector2, r: float) -> bool:
	for c in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		if not walkable(int(floor(p.x + c.x)), int(floor(p.y + c.y))):
			return false
	return true


func try_move(p: Vector2, d: Vector2, r := 0.28) -> Vector2:
	var np := Vector2(p.x + d.x, p.y)
	if free_at(np, r):
		p = np
	np = Vector2(p.x, p.y + d.y)
	if free_at(np, r):
		p = np
	return p


func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var steps := int(a.distance_to(b) / 0.25) + 1
	for s in steps:
		var p := a.lerp(b, float(s) / steps)
		if tile(int(floor(p.x)), int(floor(p.y))) == "#":
			return false
	return true


# ---------- lógica ----------

func _process(delta: float) -> void:
	time += delta
	for lt in lights:
		match lt.kind:
			"runa": lt.k = Cenario.rune_level(self, lt.tile)
			"lampada": lt.k = 0.85 + 0.15 * sin(time * 2.6)
			_: lt.k = 0.8 + 0.2 * sin(time * 1.1)
	if main.state == "cena":
		# numa cena quem move a câmera e os personagens é a própria cena
		queue_redraw()
		return
	invuln = maxf(invuln - delta, 0.0)
	flash_t = maxf(flash_t - delta, 0.0)
	_move_player(delta)
	for e in enemies:
		_update_enemy(e, delta)
		if main.state != "explore":
			return
	if _check_exits():
		return
	_update_hint()
	cam.position = iso(player_pos) - Vector2(0, 16)
	queue_redraw()


func _move_player(delta: float) -> void:
	var s := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): s.x -= 1
	if Input.is_physical_key_pressed(KEY_D): s.x += 1
	if Input.is_physical_key_pressed(KEY_W): s.y -= 1
	if Input.is_physical_key_pressed(KEY_S): s.y += 1
	moving = s != Vector2.ZERO and not escondida
	var running := false
	if moving:
		# direção na tela -> direção no mundo isométrico
		var wv := Vector2(s.x / TW + s.y / TH, s.y / TH - s.x / TW).normalized()
		facing = wv
		var speed := WALK
		if Input.is_physical_key_pressed(KEY_SHIFT) and main.stamina > 1.0:
			speed = RUN
			running = true
			main.stamina -= RUN_COST * delta
		player_pos = try_move(player_pos, wv * speed * delta)
	if running:
		regen_wait = 0.8
	else:
		regen_wait -= delta
		if regen_wait <= 0.0:
			main.stamina = minf(main.MAX_STAMINA, main.stamina + STAMINA_REGEN * delta)
	for c in coins.duplicate():
		if c.pos.distance_to(player_pos) < 0.6:
			coins.erase(c)
			main.taken.append(c.key)
			main.money += 10
			main.play_sfx("moeda")
			main.toast("+10 de dinheiro")


# Entrar numa saída leva para outra área. Quem acabou de chegar precisa sair da casa da saída antes.
func _check_exits() -> bool:
	for x in exits:
		if x.rect.has_point(player_pos):
			if not exit_lock:
				main.change_area(x.para, x.ponto)
				return true
			return false
	exit_lock = false
	return false


func _update_enemy(e: Dictionary, delta: float) -> void:
	if not e.alive:
		e.respawn -= delta
		if e.respawn <= 0.0 and player_pos.distance_to(e.home) > 7.0:
			e.alive = true
			e.pos = e.home
			e.state = "patrol"
			e.path_i = 0
		return
	var d: float = e.pos.distance_to(player_pos)
	if e.stun > 0.0:
		e.stun -= delta
	else:
		var sees: bool = not escondida and (d < 1.4 or (d < SIGHT and line_of_sight(e.pos, player_pos)))
		match e.state:
			"patrol":
				if sees:
					e.state = "chase"
					main.play_sfx("alerta")
				else:
					var target: Vector2 = e.path[e.path_i]
					if e.pos.distance_to(target) < 0.15:
						e.path_i = (e.path_i + 1) % e.path.size()
					else:
						e.pos = try_move(e.pos, (target - e.pos).normalized() * PATROL_SPEED * delta, 0.25)
			"chase":
				if sees:
					e.last_seen = player_pos
					e.pos = try_move(e.pos, (player_pos - e.pos).normalized() * CHASE_SPEED * delta, 0.25)
				else:
					e.state = "search"
					e.search_t = 3.0
			"search":
				if sees:
					e.state = "chase"
				else:
					e.search_t -= delta
					if e.pos.distance_to(e.last_seen) > 0.2:
						e.pos = try_move(e.pos, (e.last_seen - e.pos).normalized() * PATROL_SPEED * delta, 0.25)
					if e.search_t <= 0.0:
						e.state = "patrol"
	# encostar no inimigo abre a luta (estunado = começa com menos vida)
	if not escondida and invuln <= 0.0 and e.pos.distance_to(player_pos) < 0.55:
		main.start_combat(e)


func enemy_defeated(e: Dictionary) -> void:
	e.alive = false
	e.stun = 0.0
	e.respawn = RESPAWN
	invuln = 1.5


func handle_key(k: int) -> void:
	if k == KEY_SPACE:
		_flash()
	elif k == KEY_E:
		_interact()


func _flash() -> void:
	if escondida or main.stamina < FLASH_COST:
		main.toast("Sem estamina para a lanterna")
		return
	main.stamina -= FLASH_COST
	regen_wait = 1.0
	flash_t = 0.35
	main.play_sfx("lanterna")
	for e in enemies:
		if not e.alive:
			continue
		var v: Vector2 = e.pos - player_pos
		if v.length() < FLASH_RANGE and abs(facing.angle_to(v)) < FLASH_ANGLE and line_of_sight(player_pos, e.pos):
			e.stun = STUN_TIME
			e.state = "search"
			e.last_seen = e.pos
			e.search_t = 1.0


func _nearby(kind: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1.25
	var ti := int(floor(player_pos.x))
	var tj := int(floor(player_pos.y))
	for j in range(tj - 2, tj + 3):
		for i in range(ti - 2, ti + 3):
			if tile(i, j) == kind:
				var dd := player_pos.distance_to(Vector2(i + 0.5, j + 0.5))
				if dd < best_d:
					best_d = dd
					best = Vector2i(i, j)
	return best


func _npc_near() -> Dictionary:
	var t := _nearby("N")
	for n in npcs:
		if n.tile == t and not n.get("oculto", false) and (n.data.has("dialogo") or n.data.has("cena")):
			return n
	return {}


func _pickup_near() -> Dictionary:
	var best := {}
	var best_d := 0.9
	for p in pickups:
		var d: float = p.pos.distance_to(player_pos)
		if d < best_d:
			best_d = d
			best = p
	return best


# Baú e sinal ficam lado a lado: vale o que estiver mais perto da Branca.
func _chest_first() -> bool:
	var b := _nearby("B")
	if b.x < 0:
		return false
	var sg := _nearby("S")
	if sg.x < 0:
		return true
	var c := Vector2(0.5, 0.5)
	return player_pos.distance_to(Vector2(b) + c) < player_pos.distance_to(Vector2(sg) + c)


func _pick_up(p: Dictionary) -> void:
	var nome: String = Data.ITENS[p.id].nome
	if not main.add_item(p.id):
		main.play_sfx("erro")
		main.toast("Inventário cheio. Guarde algo no baú do sinal.")
		return
	pickups.erase(p)
	main.taken_items.append(p.key)
	main.play_sfx("item")
	main.toast("Pegou: %s" % nome)


func _interact() -> void:
	if escondida:
		escondida = false
		invuln = 0.5
		return
	var npc := _npc_near()
	if not npc.is_empty():
		if npc.data.has("cena"):
			main.start_cena(npc.data.cena)
		else:
			main.start_dialogue(npc.data.dialogo)
		return
	var p := _pickup_near()
	if not p.is_empty():
		_pick_up(p)
		return
	var wd := _hide_spot()
	if wd.x >= 0:
		escondida = true
		hide_tile = wd
		main.play_sfx("clique")
		return
	if _chest_first():
		main.open_chest()
		return
	var sg := _nearby("S")
	if sg.x >= 0:
		main.on_signal_point()


# Armário ou cama (a Branca se esconde embaixo), o que estiver mais perto.
func _hide_spot() -> Vector2i:
	var a := _nearby("W")
	var b := _nearby("C")
	if a.x < 0:
		return b
	if b.x < 0:
		return a
	var c := Vector2(0.5, 0.5)
	return a if player_pos.distance_to(Vector2(a) + c) <= player_pos.distance_to(Vector2(b) + c) else b


func _update_hint() -> void:
	if escondida:
		hint = "[E] Sair de debaixo da cama" if tile(hide_tile.x, hide_tile.y) == "C" else "[E] Sair do armário"
	elif not _npc_near().is_empty():
		hint = "[E] Conversar com " + _npc_near().data.nome
	elif not _pickup_near().is_empty():
		hint = "[E] Pegar " + Data.ITENS[_pickup_near().id].nome.to_lower()
	elif _hide_spot().x >= 0:
		hint = "[E] Esconder-se debaixo da cama" if tile(_hide_spot().x, _hide_spot().y) == "C" else "[E] Esconder-se no armário"
	elif _chest_first():
		hint = "[E] Abrir o baú"
	elif _nearby("S").x >= 0:
		hint = "[E] Usar o sinal (salvar)"
	else:
		hint = ""


# ---------- desenho (provisório) ----------

func light_at(p: Vector2) -> float:
	var l := clampf(1.15 - p.distance_to(player_pos) / 5.0, 0.16 if estilo == "exterior" else 0.08, 1.0)  # fora, um pouco de luz fria do céu
	for s in signals:
		l = maxf(l, clampf(0.55 - p.distance_to(s) / 3.5, 0.0, 0.55))
	for r in runes:
		l = maxf(l, clampf(0.4 - p.distance_to(Vector2(r.x + 0.5, r.y + 0.5)) / 3.0, 0.0, 0.4))
	for lt in lights:
		var d: float = p.distance_to(lt.pos)
		if d < lt.r:
			l = maxf(l, lt.max * lt.k * (1.0 - d / lt.r))
	if flash_t > 0.0:
		var v := p - player_pos
		if v.length() < FLASH_RANGE + 1.0 and v.length() > 0.01 and abs(facing.angle_to(v)) < FLASH_ANGLE + 0.15:
			l = maxf(l, flash_t / 0.35)
	return l


func shade(c: Color, l: float) -> Color:
	# luz fria e baixa: escurece puxando para azul-marinho
	var dark := Color(0.02, 0.025, 0.05)
	return dark.lerp(c, l)


func mul(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func diamond(p: Vector2, lift := 0.0, scale := 1.0) -> PackedVector2Array:
	var c := iso(p) - Vector2(0, lift)
	var hw := TW * 0.5 * scale
	var hh := TH * 0.5 * scale
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])


func _draw() -> void:
	if grid.is_empty():
		return
	# chão e água
	for j in h:
		for i in w:
			var c := tile(i, j)
			if c == "#":
				continue
			var center := Vector2(i + 0.5, j + 0.5)
			var l := light_at(center)
			if estilo == "exterior":
				if c == "~":
					Cenario.water_tile(self, i, j, l)
				else:
					Cenario.floor_tile(self, i, j, l)
			elif c == "~":
				var wave := 0.5 + 0.5 * sin(time * 1.3 + i * 0.7 + j * 1.1)
				draw_colored_polygon(diamond(center), shade(Color(0.07, 0.11, 0.16).lerp(Color(0.1, 0.16, 0.22), wave), l))
			else:
				var v := (_hash(i, j) % 7) / 60.0
				var base := Color(0.27 + v, 0.27 + v, 0.30 + v)
				if _hash(j, i) % 17 == 0:
					base = Color(0.55, 0.52, 0.45)  # osso no chão
				draw_colored_polygon(diamond(center), shade(base, l))
				draw_polyline(diamond(center), shade(Color(0.18, 0.18, 0.21), l), 1.0)
	# saídas: o chão brilha de leve para mostrar que dá para seguir por ali
	for x in exits:
		var r: Rect2 = x.rect
		for j in range(int(r.position.y), int(r.end.y)):
			for i in range(int(r.position.x), int(r.end.x)):
				var a := 0.06 + 0.05 * sin(time * 2.0 + i + j)
				draw_colored_polygon(diamond(Vector2(i + 0.5, j + 0.5), 0.0, 0.9), Color(0.75, 0.8, 0.9, a))
	# objetos ordenados por profundidade
	var items: Array = []
	for j in h:
		for i in w:
			var c := tile(i, j)
			if c == "#" and _is_visible_wall(i, j):
				items.append([i + j + 1.0, "wall", Vector2i(i, j)])
			elif c == "W":
				items.append([i + j + 1.0, "wardrobe", Vector2i(i, j)])
			elif c == "S":
				items.append([i + j + 0.9, "signal", Vector2i(i, j)])
			elif c == "B":
				items.append([i + j + 1.0, "chest", Vector2i(i, j)])
			elif c in ["o", "X", "r", "R", "C", "m", "L"]:
				items.append([i + j + 1.0, c, Vector2i(i, j)])
	for b in houses:
		var hr: Rect2i = b.rect
		items.append([hr.position.x + hr.position.y + (hr.size.x + hr.size.y) * 0.5, "house", b])
	for n in npcs:
		if not n.get("oculto", false):
			items.append([n.pos.x + n.pos.y, "npc", n])
	for c in coins:
		items.append([c.pos.x + c.pos.y, "coin", c])
	for p in pickups:
		items.append([p.pos.x + p.pos.y, "pickup", p])
	for e in enemies:
		if e.alive:
			items.append([e.pos.x + e.pos.y, "enemy", e])
	if not escondida and not player_hidden:
		items.append([player_pos.x + player_pos.y, "player", null])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match it[1]:
			"wall":
				if estilo == "exterior":
					Cenario.cliff(self, it[2])
				else:
					var front: bool = it[2].y == h - 1 or it[2].x == w - 1  # parede da frente fica baixa
					_draw_block(it[2], 14.0 if front else WALL_H, Color(0.3, 0.31, 0.36), true)
			"o": Cenario.rock(self, it[2])
			"X": Cenario.bones(self, it[2])
			"r": Cenario.roots(self, it[2])
			"R": Cenario.runestone(self, it[2])
			"C": Cenario.bed(self, it[2], escondida and hide_tile == it[2])
			"m": Cenario.table(self, it[2])
			"L": Cenario.lamp(self, it[2])
			"house": Cenario.house(self, it[2].rect, false)
			"wardrobe": _draw_wardrobe(it[2])
			"signal": _draw_signal(it[2])
			"coin": _draw_coin(it[2])
			"pickup": _draw_pickup(it[2])
			"chest": _draw_chest(it[2])
			"enemy": _draw_enemy(it[2])
			"npc": _draw_npc(it[2])
			"player":
				if player_pose == "em_pe":
					_draw_branca()
				else:
					Cenario.branca_pose(self, player_pos, player_pose)
	Cenario.mist(self, mist_spots)
	if flash_t > 0.0:
		var o := iso(player_pos) - Vector2(0, 20)
		var a := flash_t / 0.35
		var pts := PackedVector2Array([o])
		for k in 9:
			var ang := -FLASH_ANGLE + k * FLASH_ANGLE / 4.0
			pts.append(iso(player_pos + facing.rotated(ang) * FLASH_RANGE) - Vector2(0, 20))
		draw_colored_polygon(pts, Color(0.9, 0.95, 1.0, 0.18 * a))


func _draw_block(t: Vector2i, height: float, col: Color, rune: bool) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var l := light_at(p + Vector2(0.6, 0.6))
	var c := iso(p)
	var bone := _hash(t.x, t.y) % 5 == 0
	var base := Color(0.62, 0.58, 0.5) if bone else col
	var left := PackedVector2Array([c + Vector2(-TW / 2, 0), c + Vector2(0, TH / 2), c + Vector2(0, TH / 2 - height), c + Vector2(-TW / 2, -height)])
	var right := PackedVector2Array([c + Vector2(0, TH / 2), c + Vector2(TW / 2, 0), c + Vector2(TW / 2, -height), c + Vector2(0, TH / 2 - height)])
	draw_colored_polygon(left, shade(mul(base, 0.75), l))
	draw_colored_polygon(right, shade(mul(base, 0.55), l))
	draw_colored_polygon(diamond(p, height), shade(mul(base, 1.05), l))
	draw_polyline(diamond(p, height), shade(mul(base, 0.4), l), 1.0)
	if rune and runes.has(t):
		var pulse := 0.6 + 0.4 * sin(time * 2.0 + t.x)
		var rc := c + Vector2(TW / 4, TH / 4 - height * 0.55)
		var amber := Color(1.0, 0.62, 0.22, pulse)
		draw_line(rc + Vector2(-4, -6), rc + Vector2(4, 6), amber, 2.0)
		draw_line(rc + Vector2(4, -6), rc + Vector2(-4, 6), amber, 2.0)
		draw_line(rc + Vector2(0, -8), rc + Vector2(0, 8), amber, 1.0)
		draw_circle(rc, 9.0, Color(1.0, 0.6, 0.2, 0.08 * pulse))


func _draw_wardrobe(t: Vector2i) -> void:
	_draw_block(t, 58.0, Color(0.28, 0.2, 0.16), false)
	var c := iso(Vector2(t.x + 0.5, t.y + 0.5))
	var l := light_at(Vector2(t.x + 1.0, t.y + 1.0))
	draw_line(c + Vector2(-TW / 4, TH / 4 - 4), c + Vector2(-TW / 4, TH / 4 - 50), shade(Color(0.1, 0.07, 0.05), l), 2.0)
	if escondida and hide_tile == t:
		# olhos da Branca espiando pela fresta
		var e := c + Vector2(-TW / 4 + 3, TH / 4 - 34)
		draw_rect(Rect2(e, Vector2(2, 2)), Color(0.8, 0.9, 1.0, 0.8))
		draw_rect(Rect2(e + Vector2(4, 1), Vector2(2, 2)), Color(0.8, 0.9, 1.0, 0.8))


func _draw_signal(t: Vector2i) -> void:
	var c := iso(Vector2(t.x + 0.5, t.y + 0.5))
	var pulse := fmod(time, 2.0) / 2.0
	draw_colored_polygon(diamond(Vector2(t.x + 0.5, t.y + 0.5), 0.0, 0.5), Color(0.4, 0.8, 0.9, 0.25))
	for k in 3:
		var r := 6.0 + 14.0 * fmod(pulse + k / 3.0, 1.0)
		draw_arc(c - Vector2(0, 30), r, -PI * 0.8, -PI * 0.2, 12, Color(0.5, 0.9, 1.0, 1.0 - fmod(pulse + k / 3.0, 1.0)), 1.5)
	for b in 4:
		draw_rect(Rect2(c + Vector2(-8 + b * 4, -12 - b * 3), Vector2(3, 4 + b * 3)), Color(0.5, 0.9, 1.0, 0.8))


func _draw_coin(c: Dictionary) -> void:
	var s := iso(c.pos)
	var bob := sin(time * 3.0 + c.pos.x) * 2.0
	var p := s + Vector2(0, -8 + bob)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 0), p + Vector2(0, 5), p + Vector2(-4, 0)]), Color(1.0, 0.7, 0.3))
	draw_circle(p, 9.0, Color(1.0, 0.65, 0.25, 0.12))


# Item no chão: o ícone flutuando com um brilho pálido para ser visto no escuro.
func _draw_pickup(p: Dictionary) -> void:
	var s := iso(p.pos)
	var bob := sin(time * 2.4 + p.pos.x) * 2.0
	var c := s + Vector2(0, -12 + bob)
	_shadow(s, 6.0)
	draw_circle(c, 13.0, Color(0.85, 0.9, 1.0, 0.07 + 0.04 * sin(time * 3.0)))
	Itens.draw_icon(self, p.id, c, 16.0, clampf(light_at(p.pos) + 0.35, 0.0, 1.0))


# Baú de pedra com faixas de osso e um fecho de runa que acende como o sinal.
func _draw_chest(t: Vector2i) -> void:
	var p := Vector2(t.x + 0.5, t.y + 0.5)
	var l := light_at(p + Vector2(0.6, 0.6))
	var c := iso(p)
	var hgt := 24.0
	var sc := 0.62  # menor que uma casa inteira
	var hw := TW * 0.5 * sc
	var hh := TH * 0.5 * sc
	var stone := Color(0.3, 0.28, 0.3)
	var left := PackedVector2Array([c + Vector2(-hw, 0), c + Vector2(0, hh), c + Vector2(0, hh - hgt), c + Vector2(-hw, -hgt)])
	var right := PackedVector2Array([c + Vector2(0, hh), c + Vector2(hw, 0), c + Vector2(hw, -hgt), c + Vector2(0, hh - hgt)])
	_shadow(c + Vector2(0, 2), hw)
	draw_colored_polygon(left, shade(mul(stone, 0.8), l))
	draw_colored_polygon(right, shade(mul(stone, 0.6), l))
	draw_colored_polygon(diamond(p, hgt, sc), shade(mul(stone, 1.2), l))
	var bone := shade(Color(0.72, 0.68, 0.58), l)
	for k in [0.3, 0.7]:
		draw_line(c + Vector2(-hw * k, hh * (1.0 - k)) - Vector2(0, hgt * 0.98), c + Vector2(-hw * k, hh * (1.0 - k)), bone, 2.0)
		draw_line(c + Vector2(hw * k, hh * (1.0 - k)) - Vector2(0, hgt * 0.98), c + Vector2(hw * k, hh * (1.0 - k)), bone, 2.0)
	draw_polyline(diamond(p, hgt, sc), bone, 1.5)
	var pulse := 0.6 + 0.4 * sin(time * 2.0)
	var lock := c + Vector2(hw * 0.5, hh * 0.5 - hgt * 0.55)
	draw_circle(lock, 7.0, Color(0.5, 0.9, 1.0, 0.1 * pulse))
	draw_rect(Rect2(lock - Vector2(2, 3), Vector2(4, 6)), Color(0.5, 0.9, 1.0, 0.85 * pulse))


func _shadow(s: Vector2, r: float) -> void:
	draw_set_transform(s, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_branca() -> void:
	var s := iso(player_pos)
	var l := light_at(player_pos)
	var bob := (sin(time * 10.0) * 1.0) if moving else 0.0
	var flip := -1.0 if iso(facing).x < 0 else 1.0
	_shadow(s, 9.0)
	if invuln > 0.0 and fmod(time, 0.2) < 0.1 and main.state == "explore":
		return
	var o := s + Vector2(0, bob)
	var dress := Color(0.85, 0.85, 0.8)
	var skin := Color(0.82, 0.8, 0.78)
	var hair := Color(0.04, 0.04, 0.05)
	# cabelo longo (atrás)
	draw_rect(Rect2(o + Vector2(-6, -40), Vector2(12, 26)), shade(hair, maxf(l, 0.5)))
	# vestido branco rasgado
	var hem := PackedVector2Array([o + Vector2(-5, -24), o + Vector2(5, -24), o + Vector2(8, -2), o + Vector2(5, 0), o + Vector2(3, -3), o + Vector2(0, 0), o + Vector2(-3, -2), o + Vector2(-6, 0), o + Vector2(-8, -3)])
	draw_colored_polygon(hem, shade(dress, maxf(l, 0.25)))
	# braços caídos
	draw_rect(Rect2(o + Vector2(-8, -23), Vector2(2, 13)), shade(skin, l))
	draw_rect(Rect2(o + Vector2(6, -23), Vector2(2, 13)), shade(skin, l))
	# pernas e pés descalços
	draw_rect(Rect2(o + Vector2(-3, -1), Vector2(2, 3)), shade(skin, l))
	draw_rect(Rect2(o + Vector2(1, -1), Vector2(2, 3)), shade(skin, l))
	# rosto quase sem traços
	draw_rect(Rect2(o + Vector2(-3 + flip, -37), Vector2(6, 8)), shade(skin, l))
	draw_rect(Rect2(o + Vector2(-5, -41), Vector2(10, 4)), shade(hair, maxf(l, 0.5)))
	# chifres pequenos escondidos no cabelo
	draw_rect(Rect2(o + Vector2(-5, -43), Vector2(2, 2)), shade(Color(0.2, 0.18, 0.18), l))
	draw_rect(Rect2(o + Vector2(3, -43), Vector2(2, 2)), shade(Color(0.2, 0.18, 0.18), l))
	# olhos que brilham fraco no escuro
	var glow := Color(0.8, 0.9, 1.0, clampf(1.2 - l, 0.25, 0.9))
	draw_rect(Rect2(o + Vector2(-2 + flip, -34), Vector2(1, 1)), glow)
	draw_rect(Rect2(o + Vector2(1 + flip, -34), Vector2(1, 1)), glow)


func _draw_enemy(e: Dictionary) -> void:
	var kd: Dictionary = main.enemy_types[e.kind]
	var s := iso(e.pos)
	var l := light_at(e.pos)
	var hgt: float = kd.altura
	var shake := Vector2(randf_range(-1, 1), 0) if e.stun > 0.0 else Vector2.ZERO
	var o := s + shake
	_shadow(s, 11.0)
	var body := Color(0.16, 0.15, 0.19) if e.stun <= 0.0 else Color(0.25, 0.3, 0.42)
	var step := sin(time * 6.0) * 2.0 if e.stun <= 0.0 else 0.0
	# corpo alongado e inumano
	draw_colored_polygon(PackedVector2Array([o + Vector2(-5, -hgt + 10), o + Vector2(5, -hgt + 10), o + Vector2(8, -18), o + Vector2(-8, -18)]), shade(body, maxf(l, 0.15)))
	draw_rect(Rect2(o + Vector2(-5 + step, -18), Vector2(3, 18)), shade(body, maxf(l, 0.15)))
	draw_rect(Rect2(o + Vector2(2 - step, -18), Vector2(3, 18)), shade(body, maxf(l, 0.15)))
	# braços longos até abaixo do joelho, com garras
	draw_line(o + Vector2(-6, -hgt + 12), o + Vector2(-12, -8), shade(body, maxf(l, 0.15)), 2.0)
	draw_line(o + Vector2(6, -hgt + 12), o + Vector2(12, -8), shade(body, maxf(l, 0.15)), 2.0)
	draw_line(o + Vector2(-12, -8), o + Vector2(-14, -2), shade(Color(0.5, 0.48, 0.42), l), 1.0)
	draw_line(o + Vector2(12, -8), o + Vector2(14, -2), shade(Color(0.5, 0.48, 0.42), l), 1.0)
	# cabeça e chifres
	draw_rect(Rect2(o + Vector2(-4, -hgt), Vector2(8, 10)), shade(mul(body, 1.2), maxf(l, 0.15)))
	var horn := shade(Color(0.55, 0.5, 0.42), maxf(l, 0.2))
	draw_line(o + Vector2(-4, -hgt + 2), o + Vector2(-9, -hgt - 8), horn, 2.0)
	draw_line(o + Vector2(4, -hgt + 2), o + Vector2(9, -hgt - 8), horn, 2.0)
	# olhos sempre visíveis no escuro
	var eye: Color = kd.cor_olhos
	if e.state == "chase":
		eye = Color(1.0, 0.15, 0.1)
	if e.stun > 0.0:
		eye = eye.darkened(0.6)
	draw_rect(Rect2(o + Vector2(-3, -hgt + 4), Vector2(2, 2)), eye)
	draw_rect(Rect2(o + Vector2(1, -hgt + 4), Vector2(2, 2)), eye)
	draw_circle(o + Vector2(0, -hgt + 5), 7.0, Color(eye.r, eye.g, eye.b, 0.1))
	if e.stun > 0.0:
		for k in 3:
			var a := time * 4.0 + k * TAU / 3.0
			draw_rect(Rect2(o + Vector2(cos(a) * 9.0, -hgt - 12 + sin(a) * 3.0), Vector2(2, 2)), Color(0.8, 0.9, 1.0))


# Figura encapuzada provisória, usada por qualquer personagem até ele ganhar sprite.
func _draw_npc(n: Dictionary) -> void:
	if n.data.get("id", "") == "nanshe":
		var left: bool = n.get("left", iso(player_pos).x < iso(n.pos).x)
		Cenario.nanshe(self, n.pos, n.get("pose", n.data.get("pose", "em_pe")), left)
		_draw_talk_mark(n, Vector2(0, -100))
		return
	var s := iso(n.pos)
	var l := maxf(light_at(n.pos), 0.18)
	var sway := sin(time * 1.5) * 1.0
	_shadow(s, 10.0)
	var cloak := Color(0.3, 0.27, 0.3)
	draw_colored_polygon(PackedVector2Array([s + Vector2(-6 + sway, -46), s + Vector2(6 + sway, -46), s + Vector2(11, -2), s + Vector2(-11, -2)]), shade(cloak, l))
	draw_colored_polygon(PackedVector2Array([s + Vector2(-7 + sway, -44), s + Vector2(sway, -56), s + Vector2(7 + sway, -44)]), shade(mul(cloak, 1.15), l))
	draw_rect(Rect2(s + Vector2(-4 + sway, -45), Vector2(8, 8)), Color(0.04, 0.04, 0.05))
	draw_rect(Rect2(s + Vector2(-3 + sway, -42), Vector2(2, 1)), Color(0.85, 0.8, 0.6, 0.8))
	draw_rect(Rect2(s + Vector2(1 + sway, -42), Vector2(2, 1)), Color(0.85, 0.8, 0.6, 0.8))
	_draw_talk_mark(n, Vector2(sway, -70))


# Setinha sobre quem está perto o bastante para conversar.
func _draw_talk_mark(n: Dictionary, off: Vector2) -> void:
	if not _npc_near().is_empty() and _npc_near() == n:
		var b := iso(n.pos) + off + Vector2(0, sin(time * 4.0) * 2.0)
		draw_colored_polygon(PackedVector2Array([b + Vector2(-5, -4), b + Vector2(5, -4), b + Vector2(0, 3)]), Color(0.85, 0.8, 0.7, 0.9))
