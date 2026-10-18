# Jogo (Godot 4.7.2)

O nome ainda não foi decidido. O jogo começa na margem do lago em Kurnugi: a Branca acorda onde a Nanshe
a tirou da água e segue até a casa dela. Por baixo estão os sistemas do jogo inteiro: exploração isométrica,
inimigos que patrulham e perseguem, lanterna que atordoa, armário e cama para se esconder, dinheiro e itens
no chão, inventário com 6 espaços, baú ao lado do ponto de sinal (que salva), diálogos com escolhas, cenas,
celular como menu e combate rítmico (modo pistas em D F J K e modo mira com o mouse).

A arte é pixel art gerada por `ferramentas/gerar_arte.py` (chão pintado de cada área em `arte/areas/`,
cenário e personagens em `arte/sprites/`), com luz de verdade (scripts/luzes.gd). Os sons saem de
`ferramentas/gerar_audio.py`.

## Rodar
- Editor: abrir esta pasta na Godot 4.7.2 e apertar F5.
- Windows: `build/Jogo-windows.zip`, extrair e abrir `Jogo.exe`.

## Pastas
- `areas/` mapas das áreas em JSON (formato em `areas/LEIAME.md`)
- `cenas/` cenas (formato em `cenas/LEIAME.md`); `cenas/abertura.json` abre o jogo
- `dialogos/` falas em JSON (formato em `dialogos/LEIAME.md`)
- `dados/inimigos.json` tipos de inimigo
- `audio/` sons e ambientes gerados por `ferramentas/gerar_audio.py`
- `arte/` chão das áreas e sprites gerados por `ferramentas/gerar_arte.py` (`python3 ferramentas/gerar_arte.py`);
  `arte/sprites/sprites.json` diz onde cada sprite toca o chão
- `scripts/` código: main, world (exploração), cenario (qual sprite vai em cada casa), arte (sprites), luzes, cena, combat, phone, dialogue,
  bau, itens, hud, title, areas (leitura dos arquivos), data (itens e efeitos)
- `tests/teste.gd` joga sozinho e tira prints: `godot --path . -s tests/teste.gd -- <pasta>`.
  O conteúdo usado só no teste (área, inimigos, diálogo e músicas de luta de exemplo) fica em `tests/fixtures/`.

## Exportar
`godot --headless --export-release "Windows Desktop" build/windows/Jogo.exe`
