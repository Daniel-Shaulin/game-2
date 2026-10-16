# Teste automático: joga o protótipo sozinho e tira prints.
# Uso: godot --path . -s tests/teste.gd -- <pasta_dos_prints>
extends SceneTree

var main
var out := "user://"
var autoplay := false
var miss_every := 0
var count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	process_frame.connect(_tick)
	_run()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("print: ", name)


func wait(t: float) -> void:
	await create_timer(t).timeout


func key(k: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _tick() -> void:
	if not autoplay or main.state != "combat":
		return
	var c = main.combat
	if c.state != "play":
		return
	for n in c.notes:
		if n.done or abs(n.t - c.lt) > 0.02:
			continue
		count += 1
		if miss_every > 0 and count % miss_every == 0:
			continue
		if n.k == "l":
			c.handle_key(c.LANE_KEYS[int(n.lane)])
		else:
			c._hit(n, abs(n.t - c.lt), Vector2(n.x, n.y))


func _run() -> void:
	await wait(1.0)
	await shot("01_titulo")
	main.new_game()
	await wait(1.2)
	await shot("02_exploracao")
	key(KEY_D, true)
	await wait(0.8)
	key(KEY_D, false)
	print("andou para: ", main.world.player_pos)
	# lanterna perto do inimigo 1
	var e = main.world.enemies[0]
	main.world.player_pos = e.pos + Vector2(-2.5, 0)
	main.world.facing = Vector2(1, 0)
	main.world.invuln = 3.0
	await wait(0.1)
	main.world.handle_key(KEY_SPACE)
	await wait(0.15)
	await shot("03_lanterna")
	print("estunado: ", e.stun > 0.0, " estamina: ", main.stamina)
	main.world.invuln = 0.0
	main.world.player_pos = e.pos + Vector2(-0.3, 0)
	await wait(0.3)
	print("estado: ", main.state)
	await wait(4.0)
	autoplay = true
	miss_every = 6
	await shot("04_combate")
	var t := 0.0
	while main.state == "combat" and t < 90.0:
		await wait(0.5)
		t += 0.5
	print("depois da luta 1: estado=", main.state, " vida=", main.hp, " dinheiro=", main.money, " tempo=", t)
	await wait(0.5)
	await shot("05_depois_da_luta")
	# morte: luta com o inimigo 2 sem tocar
	autoplay = false
	main.money = 40
	var e2 = main.world.enemies[1]
	main.world.player_pos = e2.pos
	main.world.invuln = 0.0
	await wait(0.3)
	t = 0.0
	while main.combat.state != "dead" and t < 60.0:
		await wait(0.25)
		t += 0.25
	await shot("06_morte")
	print("morte: dinheiro=", main.money, " (era 40)")
	await wait(3.5)
	print("recomeçou: vida=", main.hp, " estado=", main.combat.state)
	autoplay = true
	miss_every = 4
	await wait(5.0)
	await shot("07_combate_b")
	t = 0.0
	while main.state == "combat" and t < 120.0:
		await wait(0.5)
		t += 0.5
	print("depois da luta 2: estado=", main.state, " vida=", main.hp, " dinheiro=", main.money)
	# sinal / save
	main.world.player_pos = main.world.signals[0] + Vector2(0.8, 0)
	await wait(0.3)
	main.world.handle_key(KEY_E)
	print("save existe: ", main.has_save(), " mensagens: ", main.messages.size())
	await wait(0.3)
	await shot("08_sinal")
	# esconder no armário
	main.world.player_pos = Vector2(3.5, 10.5)
	main.world.handle_key(KEY_E)
	print("escondida: ", main.world.escondida)
	main.world.handle_key(KEY_E)
	# celular
	main._unhandled_input(_key_event(KEY_TAB))
	await wait(0.3)
	await shot("09_celular")
	main.phone.handle_key(KEY_ENTER)
	main.phone.handle_key(KEY_ENTER)
	await wait(0.3)
	await shot("10_mensagem")
	quit()


func _key_event(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	return ev
