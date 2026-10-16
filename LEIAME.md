# Protótipo (Godot 4.7.2)

Fatia jogável do ciclo principal: exploração isométrica, inimigo que patrulha e persegue, lanterna que atordoa,
armário para se esconder, dinheiro e itens no chão, inventário com 6 espaços, baú ao lado do ponto de sinal,
ponto de sinal (salva e recebe mensagem), diálogo com escolhas, celular como menu e combate rítmico
(modo pistas em D F J K e modo mira com o mouse). Toda a arte, música e sons são PROVISÓRIOS, feitos por código.

## Rodar
- Windows: `build/Prototipo-windows.zip`, extrair e abrir `Prototipo.exe`.
- Editor: abrir esta pasta na Godot 4.7.2.

## Pastas
- `scripts/` código (main, world = exploração, combat = combate, phone = celular, dialogue = diálogo,
  bau = baú, itens = ícones dos itens, hud, title, data = mapa, itens e inimigos)
- `dialogos/` falas em JSON (formato em `dialogos/LEIAME.md`)
- `audio/` músicas e notas do combate (`combate_*.json`) geradas por `ferramentas/gerar_audio.py`
- `tests/teste.gd` joga sozinho e tira prints: `godot --path . -s tests/teste.gd -- <pasta>`

## Exportar
`godot --headless --export-release "Windows Desktop" build/windows/Prototipo.exe`
