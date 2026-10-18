# Como escrever uma cena

Uma cena é um arquivo `.json` nesta pasta com uma lista de passos, executados um depois do outro.
Durante a cena a Branca não anda nem abre o celular. No fim, o jogo volta para a exploração.

Uma cena roda quando:
- a área pede ao entrar (`ao_entrar` no arquivo da área, ver `areas/LEIAME.md`);
- a Branca fala com um personagem que tem `"cena"` em vez de `"dialogo"`;
- o jogo começa, se `START_CENA` em `scripts/main.gd` tiver um id.

## Passos

Todo passo aceita `"tempo"` em segundos (o padrão é 1).

| Passo | O que faz |
| --- | --- |
| `{"tela": "preta"}` / `{"tela": "normal"}` | Escurece ou clareia a tela. |
| `{"texto": "Linha 1\nLinha 2", "tempo": 3}` | Texto no meio da tela, aparecendo e sumindo (bom sobre a tela preta). |
| `{"esperar": 1.5}` | Espera. |
| `{"camera": [12, 6]}` / `{"camera": "branca"}` | Leva a câmera até uma casa ou de volta para a Branca. |
| `{"mover": "branca", "para": [12, 8], "velocidade": 2}` | Anda em linha reta até a casa (velocidade em casas por segundo). |
| `{"posicionar": "nanshe", "em": [10, 4]}` | Põe alguém na casa na hora. |
| `{"pose": "deitada"}` / `{"pose": "agachada", "quem": "nanshe"}` | Muda a pose. Branca: `em_pe`, `sentada`, `deitada`. Nanshe: `em_pe`, `agachada`. Sem `quem`, vale para a Branca. |
| `{"esconder": "nanshe"}` / `{"mostrar": "nanshe"}` | Some ou aparece. |
| `{"dialogo": "nanshe_1"}` | Abre um diálogo de `dialogos/` e espera ele acabar. |
| `{"marcar": "acordou"}` | Guarda uma marca (vai no save). |
| `{"missao": "voltar para casa"}` | Troca a missão mostrada no canto da tela (`""` apaga). |
| `{"som": "sinal"}` | Toca um som de `audio/`. |
| `{"musica": "res://audio/....wav"}` | Troca a música (`""` para silêncio). |
| `{"area": "floresta", "ponto": "inicio"}` | Troca de área no meio da cena (melhor com a tela preta). |

Quem pode ser movido: `"branca"` ou o `id` de um personagem da área (`npcs` no arquivo da área).

Exemplos ficam em `tests/fixtures/cenas/`.
