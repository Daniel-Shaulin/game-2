# Teste automático: abre o jogo de verdade, depois joga a área de teste (tests/fixtures/) sozinho e tira prints.
# Uso: godot --path . -s tests/teste.gd -- <pasta_dos_prints>
extends SceneTree

const Areas := preload("res://scripts/areas.gd")
const AREA_TESTE := "res://tests/fixtures/area_teste.json"

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
	await _teste_abertura()
	print("jogo começa em: ", main.area_id, " missão: '", main.missao, "' tipos de inimigo: ", main.enemy_types.keys())
	# daqui em diante, a área de teste com tudo em uso
	main.enemy_types.merge(Areas.load_enemy_types("res://tests/fixtures/inimigos.json"))
	main.area_id = AREA_TESTE
	main.world.load_area(AREA_TESTE)
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
	await _teste_inventario()
	main.world.player_pos = main.world._tile_center(main.world.area.pontos.inicio)
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
	print("velocidade das notas com chá: ", main.combat.scroll, " (normal ", main.combat.SCROLL, ")")
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
	print("depois da luta 1: estado=", main.state, " vida=", main.hp, " dinheiro=", main.money, " tempo=", t, " efeitos=", main.effects)
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
	while main.effects.get("amuleto", 3) >= 3 and t < 30.0:
		await wait(0.05)
		t += 0.05
	await wait(0.1)
	await shot("05b_amuleto_absorveu")
	print("amuleto absorveu: cargas=", main.effects.get("amuleto", 0), " vida=", main.hp)
	t = 0.0
	while main.combat.state != "dead" and t < 60.0:
		await wait(0.25)
		t += 0.25
	await shot("06_morte")
	print("efeitos depois da morte: ", main.effects, " (amuleto gastou as 3 cargas)")
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
	main.world.player_pos = main.world.signals[0] + Vector2(0, 0.3)
	await wait(0.3)
	main.world.handle_key(KEY_E)
	print("save existe: ", main.has_save(), " mensagens: ", main.messages.size(), " estado: ", main.state)
	var salvo = JSON.parse_string(FileAccess.open(main.SAVE_PATH, FileAccess.READ).get_as_text())
	print("save tem inventário: ", salvo.get("inventory"), " baú: ", salvo.get("chest"))
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
	main.phone.handle_key(KEY_TAB)
	await wait(0.5)
	await _teste_areas_e_cenas()
	quit()


# Sai pela saída da área, vê a cena de entrada, conversa com quem tem cena e volta.
func _teste_areas_e_cenas() -> void:
	var wd = main.world
	print("salvo na área: ", JSON.parse_string(FileAccess.open(main.SAVE_PATH, FileAccess.READ).get_as_text()).get("area"))
	wd.player_pos = Vector2(1.5, 15.3)
	await wait(0.3)
	await shot("11_perto_da_saida")
	wd.player_pos = Vector2(1.5, 16.5)
	await wait(0.6)
	print("estado na passagem: ", main.state)
	await wait(0.9)
	await shot("11b_cena_de_entrada")
	print("cena rodando: ", main.cena.running, " área: ", wd.area.get("nome"))
	var t := 0.0
	while main.cena.running != "" and t < 10.0:
		await wait(0.1)
		t += 0.1
	print("depois da cena: estado=", main.state, " missão=", main.missao, " marca=", main.flags.get("entrou_na_sala_2", false))
	await shot("11c_sala_2")
	wd.player_pos = Vector2(4.6, 3.5)
	await wait(0.3)
	print("dica: ", wd.hint)
	wd.handle_key(KEY_E)
	await wait(0.6)
	await shot("11d_cena_camera")
	t = 0.0
	while main.state != "dialogue" and t < 10.0:
		await wait(0.1)
		t += 0.1
	await wait(0.6)
	await shot("11e_cena_dialogo")
	main.dialogue.handle_key(KEY_E)
	main.dialogue.handle_key(KEY_E)
	t = 0.0
	while main.cena.running != "" and t < 10.0:
		await wait(0.1)
		t += 0.1
	print("cena com personagem: estado=", main.state, " marca=", main.flags.get("viu_a_cena", false), " sombra oculta=", wd.npcs[0].get("oculto", false))
	await shot("11f_depois_da_cena")
	wd.player_pos = Vector2(1.5, 4.5)
	await wait(1.5)
	print("voltou para: ", wd.area.get("nome"), " em ", wd.player_pos, " estado=", main.state)
	await shot("11g_voltou")


# A cena de abertura na margem do lago, depois a casa da Nanshe.
func _teste_abertura() -> void:
	var wd = main.world
	await wait(0.3)
	print("abertura: cena=", main.cena.running, " tela preta=", main.cena.black, " pose=", wd.player_pose)
	await wait(7.0)
	await shot("02a_abertura_despertar")
	await wait(3.2)
	await shot("02b_abertura_sentada")
	var t := 0.0
	while main.cena.running != "" and t < 40.0:
		await wait(0.2)
		t += 0.2
		if t > 2.0 and t < 2.3:
			await shot("02c_abertura_nanshe_andando")
	print("abertura terminou: estado=", main.state, " marca acordou=", main.flags.get("acordou", false), " nanshe oculta=", wd.npcs[0].get("oculto", false))
	await wait(1.0)
	await shot("02d_margem")
	# perto da pedra de runa, dos ossos e da água
	wd.player_pos = Vector2(14.5, 11.5)
	await wait(1.0)
	await shot("02e_margem_ossos")
	wd.player_pos = Vector2(21.5, 21.5)
	await wait(1.0)
	await shot("02f_margem_sinal")
	print("dica no sinal: ", wd.hint)
	# casa da Nanshe
	wd.player_pos = Vector2(22.5, 13.6)
	await wait(1.0)
	await shot("02g_porta_da_casa")
	wd.player_pos = Vector2(22.5, 12.5)
	await wait(1.6)
	print("entrou em: ", main.area_id, " estado=", main.state, " nanshe aqui=", wd.npcs.size())
	await shot("02h_casa_da_nanshe")
	wd.player_pos = Vector2(1.5, 4.4)
	await wait(0.3)
	print("dica perto da cama: ", wd.hint)
	wd.handle_key(KEY_E)
	await wait(0.3)
	await shot("02i_debaixo_da_cama")
	print("escondida debaixo da cama: ", wd.escondida)
	wd.handle_key(KEY_E)
	wd.player_pos = Vector2(4.5, 7.5)
	await wait(1.6)
	print("voltou para: ", main.area_id, " em ", wd.player_pos)


# Pega item do chão, testa o inventário cheio, o baú e o curativo pelo celular.
func _teste_inventario() -> void:
	var wd = main.world
	wd.player_pos = Vector2(5.5, 8.5) + Vector2(0.4, 0.2)
	wd.invuln = 3.0
	await wait(0.4)
	await shot("02f_item_no_chao")
	wd.handle_key(KEY_E)
	print("pegou item: ", main.inventory, " dica: ", wd.hint)
	main.inventory = ["curativo", "cha", "amuleto", "curativo", "cha", "amuleto"]
	wd.player_pos = Vector2(21.5, 12.5) + Vector2(-0.4, 0.2)
	await wait(0.3)
	wd.handle_key(KEY_E)
	await wait(0.2)
	await shot("02g_inventario_cheio")
	print("inventário cheio: ", main.inventory.size(), " item ainda no chão: ", wd.pickups.size())
	# baú
	wd.player_pos = Vector2(21.5, 8.4)
	await wait(0.3)
	print("dica perto do baú: ", wd.hint)
	wd.handle_key(KEY_E)
	print("baú aberto: ", main.state)
	main.bau.handle_key(KEY_E)
	main.bau.handle_key(KEY_S)
	main.bau.handle_key(KEY_E)
	await wait(0.2)
	main.bau.handle_key(KEY_D)
	await wait(0.2)
	await shot("02h_bau")
	main.bau.handle_key(KEY_E)
	print("inventário: ", main.inventory, " baú: ", main.chest)
	main.bau.handle_key(KEY_A)
	await wait(0.2)
	await shot("02i_bau_inventario")
	main.bau.handle_key(KEY_ESCAPE)
	print("baú fechado: ", main.state)
	# curativo pelo celular
	main.hp = 50.0
	main._unhandled_input(_key_event(KEY_TAB))
	await wait(0.4)
	main.phone.handle_key(KEY_S)
	main.phone.handle_key(KEY_S)
	main.phone.handle_key(KEY_ENTER)
	await wait(0.1)
	await shot("02j_celular_inventario")
	var cur: int = main.inventory.find("curativo")
	for i in cur:
		main.phone.handle_key(KEY_S)
	main.phone.handle_key(KEY_ENTER)
	await wait(0.1)
	await shot("02k_item")
	main.phone.handle_key(KEY_ENTER)
	await wait(0.1)
	await shot("02l_usou_curativo")
	print("vida depois do curativo: ", main.hp, " inventário: ", main.inventory)
	# amuleto e chá pelo celular
	while main.phone.sel != main.inventory.find("amuleto"):
		main.phone.handle_key(KEY_W)
	main.phone.handle_key(KEY_ENTER)
	main.phone.handle_key(KEY_ENTER)
	while main.phone.sel != main.inventory.find("cha"):
		main.phone.handle_key(KEY_W)
	main.phone.handle_key(KEY_ENTER)
	await wait(0.1)
	await shot("02m_item_cha")
	main.phone.handle_key(KEY_ENTER)
	await wait(0.1)
	print("efeitos: ", main.effects, " inventário: ", main.inventory)
	print("chá de novo: ", main.use_item(main.inventory.find("cha")))
	main.phone.handle_key(KEY_TAB)
	await wait(0.5)
	main.hp = main.MAX_HP
	await shot("02n_hud_efeitos")


func _key_event(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	return ev
