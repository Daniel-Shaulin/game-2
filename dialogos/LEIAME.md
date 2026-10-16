# Como escrever um diálogo

Cada conversa é um arquivo `.json` nesta pasta, com o nome usado no mapa (`scripts/data.gd`, em `NPCS`).
O arquivo é uma lista de entradas, lidas de cima para baixo.

## Tipos de entrada

| Entrada | O que faz |
| --- | --- |
| `{"quem": "Nanshe", "texto": "..."}` | Uma fala. `quem` aparece na etiqueta acima da caixa; sem `quem`, a etiqueta some (narração). |
| `"fim": true` numa fala | A conversa termina depois dessa fala. |
| `"ir": "marcador"` numa fala | Depois dessa fala, pula para o marcador. |
| `"escolhas": [{"texto": "...", "ir": "marcador"}]` numa fala | Mostra as opções quando a fala termina; cada uma pula para o seu marcador. |
| `{"id": "marcador"}` | Um marcador para onde `ir` pode pular. Não aparece na tela. |
| `{"marcar": "nome"}` | Guarda uma marca no jogo (vai junto no save). Serve para lembrar que algo aconteceu. |
| `{"se": "nome", "ir": "marcador"}` | Se a marca existir, pula para o marcador; se não, segue para a próxima entrada. |
| `{"ir": "marcador"}` | Pula sem mostrar nada. |

## Exemplo

O arquivo `npc_teste.json` usa todos os tipos: muda a conversa depois da primeira vez com `se` e `marcar`, e tem uma escolha com dois caminhos.

## Dicas

- A Branca é dócil e apática: fala pouco e quase nunca pergunta.
- Frases longas quebram a linha sozinhas; a caixa cabe umas 3 linhas.
- Aspas dentro do texto precisam de `\"`.
