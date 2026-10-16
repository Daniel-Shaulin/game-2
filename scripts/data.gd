# Dados do protótipo: mapa de teste e tipos de inimigo (tudo provisório).
extends RefCounted

# '#' parede  '~' água  'W' armário (esconderijo)  'S' ponto de sinal (save)
# '$' dinheiro  'P' início da Branca  'a'/'b' inimigos  'N' personagem para conversar  '.' chão
# 'B' baú (perto do sinal)  '1' '2' '3' itens no chão (ver ITENS_NO_MAPA)
const MAP := [
	"########################",
	"#~~~~~~~~~~~~~~~~~~~~~~#",
	"#~~~~~~~~~~~~~~~~~~~~~~#",
	"#~~~~~~~~...~~~~~~~~~~~#",
	"#~~~~~~.......~~~~~~~~~#",
	"#~~~~.....P.....~~~~~~##",
	"#~~.........N...~~~~~~##",
	"#.......##..........SB##",
	"#....1..##...$........##",
	"#..W..........a.......##",
	"#.............##......##",
	"#.....$.......##.......#",
	"#....................2.#",
	"######..########...W...#",
	"#.......#...3..#.......#",
	"#.1.$...#..$...#...b...#",
	"#..W.......$...........#",
	"########################",
]

# Rotas de patrulha (em casas do mapa) para cada inimigo.
const PATROLS := {
	"a": [Vector2(14.5, 9.5), Vector2(19.5, 9.5), Vector2(19.5, 12.5), Vector2(12.5, 12.5), Vector2(12.5, 9.5)],
	"b": [Vector2(17.5, 14.5), Vector2(21.5, 14.5), Vector2(21.5, 16.5), Vector2(9.5, 16.5), Vector2(17.5, 16.5)],
}

# Personagens que conversam (letra no mapa -> nome e arquivo em res://dialogos/).
const NPCS := {
	"N": {"nome": "Figura de teste", "dialogo": "npc_teste"},
}

# Inventário: quantos itens a Branca carrega. O resto fica no baú dos pontos de sinal.
const INV_SLOTS := 6

# Itens (provisório). Todos são usados pelo celular:
# "curar" = vida recuperada na hora; "efeito" = fica ativo e age no combate (ver EFEITOS).
const ITENS := {
	"curativo": {"nome": "Curativo", "descricao": "Atadura para fechar feridas. Recupera 35 de vida.", "curar": 35.0},
	"cha": {"nome": "Chá", "descricao": "Beba antes de lutar: as notas vêm mais devagar durante a próxima luta.", "efeito": "cha"},
	"amuleto": {"nome": "Amuleto", "descricao": "Use antes de lutar: absorve os próximos três erros no combate.", "efeito": "amuleto"},
}

# Efeitos ativos. "cargas": quantos erros o amuleto absorve. "lentidao": quanto o chá desacelera as notas.
const EFEITOS := {
	"amuleto": {"nome": "Amuleto", "cargas": 3},
	"cha": {"nome": "Chá", "lentidao": 0.65},
}

# Itens no chão do mapa de teste (número no mapa -> item).
const ITENS_NO_MAPA := {"1": "curativo", "2": "cha", "3": "amuleto"}

const ENEMIES := {
	"a": {
		"nome": "Inimigo de teste 1",
		"musica": "res://audio/combate_a.wav",
		"notas": "res://audio/combate_a.json",
		"dano_erro": 6.0,
		"recompensa": [8, 15],
		"cor_olhos": Color(1.0, 0.55, 0.2),
		"altura": 64.0,
	},
	"b": {
		"nome": "Inimigo de teste 2",
		"musica": "res://audio/combate_b.wav",
		"notas": "res://audio/combate_b.json",
		"dano_erro": 7.0,
		"recompensa": [10, 18],
		"cor_olhos": Color(0.75, 0.9, 1.0),
		"altura": 52.0,
	},
}

const MENSAGEM_SINAL := {
	"de": "HAKUREN",
	"titulo": "[mensagem corrompida]",
	"texto": "UNIDADE E-317\n...ord█m ██ ...\n...abr█r a f█n██...\n...███ dentro...\n\n[sinal fraco]\n\n(texto provisório)",
}
