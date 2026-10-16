# Teste automático: joga o protótipo sozinho e tira prints.
# Uso: godot --path . -s tests/teste.gd -- <pasta_dos_prints>
extends SceneTree

var main
var out := "user://"
var autoplay := false


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
	main.combat.autoplay = autoplay


func _run() -> void:
	await wait(1.0)
	await shot("01_titulo")
	main.new_game()
	await wait(1.2)
	await shot("02_exploracao")
	# diálogo com a figura de teste
	main.world.player_pos = Vector2(11.5, 6.5)
	await wait(0.3)
	main.world.handle_key(KEY_E)
	print("diálogo aberto: ", main.state)
	await wait(0.5)
	await shot("02b_dialogo")
	var guard := 0
	while main.state == "dialogue" and guard < 40:
		guard += 1
		var d = main.dialogue
		if not d._typing() and d.current.has("escolhas"):
			await shot("02c_escolha")
			d.handle_key(KEY_S)
			await wait(0.2)
			await shot("02d_escolha_2")
		d.handle_key(KEY_E)
		await wait(0.15)
	print("diálogo terminou: ", main.state, " marca: ", main.flags.get("falou_com_teste", false))
	await wait(0.8)
	main.world.handle_key(KEY_E)
	await wait(2.5)
	await shot("02e_dialogo_de_novo")
	print("segunda conversa: ", main.dialogue.current.get("texto", ""))
	main.dialogue.handle_key(KEY_E)
	main.dialogue.handle_key(KEY_E)
	await wait(0.2)
	main.world.player_pos = main.world.start_pos
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
	await shot("04_combate")
	var w := 0.0
	while main.combat.mode != "osu" and w < 30.0:
		await wait(0.1)
		w += 0.1
	await wait(1.2)
	await shot("04b_modo_mira")
	while not main.combat.notes.any(func(n): return n.k == "s" and n.held) and w < 40.0:
		await wait(0.05)
		w += 0.05
	await shot("04c_slider")
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
	await wait(1.0)
	await shot("08b_antes_do_celular")
	# celular
	main._unhandled_input(_key_event(KEY_TAB))
	await wait(0.6)
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
