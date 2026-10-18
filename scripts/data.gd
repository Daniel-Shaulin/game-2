# Regras fixas do jogo: tamanho do inventário, itens e efeitos.
# O conteúdo (áreas, cenas, diálogos, tipos de inimigo) fica em arquivos JSON, lidos por scripts/areas.gd.
extends RefCounted

# Inventário: quantos itens a Branca carrega. O resto fica no baú dos pontos de sinal.
const INV_SLOTS := 6

# Itens (os três do mercador misterioso, ver o GDD). Todos são usados pelo celular:
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
