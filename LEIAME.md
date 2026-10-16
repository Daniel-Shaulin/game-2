# Protótipo (Godot 4.4.1)

Fatia jogável do ciclo principal: exploração isométrica, inimigo que patrulha e persegue, lanterna que atordoa,
armário para se esconder, dinheiro no chão, ponto de sinal (salva e recebe mensagem), celular como menu e
combate rítmico (pistas D F J K + círculos de clique). Toda a arte, música e sons são PROVISÓRIOS, feitos por código.

## Rodar
- Windows: `build/Prototipo-windows.zip`, extrair e abrir `Prototipo.exe`.
- Editor: abrir esta pasta na Godot 4.4.1.

## Pastas
- `scripts/` código (main, world = exploração, combat = combate, phone = celular, hud, title, data = mapa e inimigos)
- `audio/` músicas e notas do combate (`combate_*.json`) geradas por `ferramentas/gerar_audio.py`
- `tests/teste.gd` joga sozinho e tira prints: `godot --path . -s tests/teste.gd -- <pasta>`

## Exportar
`godot --headless --export-release "Windows Desktop" build/windows/Prototipo.exe`
