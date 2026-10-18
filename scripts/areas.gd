# Lê os arquivos de conteúdo do jogo (áreas, cenas, diálogos, inimigos).
# Um id simples vira res://<pasta>/<id>.json; um caminho res:// completo é usado como está.
extends RefCounted


static func path_for(folder: String, id: String) -> String:
	return id if id.begins_with("res://") else "res://%s/%s.json" % [folder, id]


static func read_json(path: String):
	if not FileAccess.file_exists(path):
		push_error("Arquivo não encontrado: " + path)
		return null
	var data = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if data == null:
		push_error("JSON inválido: " + path)
	return data


static func load_area(id: String) -> Dictionary:
	var d = read_json(path_for("areas", id))
	return d if typeof(d) == TYPE_DICTIONARY else {"mapa": ["#"]}


# Tipos de inimigo: res://dados/inimigos.json. As cores vêm como [r, g, b].
static func load_enemy_types(path := "res://dados/inimigos.json") -> Dictionary:
	var d = read_json(path)
	var out := {}
	if typeof(d) != TYPE_DICTIONARY:
		return out
	for k in d:
		var e: Dictionary = d[k].duplicate()
		var c: Array = e.get("cor_olhos", [1, 1, 1])
		e["cor_olhos"] = Color(c[0], c[1], c[2])
		out[k] = e
	return out
