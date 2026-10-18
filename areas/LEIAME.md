# Como montar uma área

Cada área do jogo é um arquivo `.json` nesta pasta. O nome do arquivo é o id da área
(`margem_do_lago.json` é a área `margem_do_lago`). O jogo começa na área de `START_AREA` em `scripts/main.gd`.

## O mapa

`mapa` é uma lista de linhas, todas do mesmo tamanho. Cada letra é uma casa do chão isométrico.
A coluna é o `x` e a linha é o `y`, contando do zero a partir do canto de cima à esquerda.

| Letra | O que é |
| --- | --- |
| `#` | Parede (pedra viva; algumas acendem runas sozinhas) |
| `~` | Água (não dá para andar) |
| `.` | Chão |
| `W` | Armário para se esconder |
| `S` | Ponto de sinal (salva o jogo) |
| `B` | Baú (fica ao lado de um ponto de sinal) |
| `C` | Cama (a Branca se esconde embaixo) |
| `o` | Pedra solta |
| `X` | Ossos enormes saindo da terra |
| `r` | Raízes secas de uma árvore morta |
| `R` | Pedra de runa (luz laranja; algumas falham) |
| `L` | Luminária de runa (luz quente, dentro de casa) |
| `m` | Mesa |

As paredes da última linha e da última coluna (a frente do mapa) ficam baixas, para não esconder a Branca.

## Campos

| Campo | Exemplo | O que faz |
| --- | --- | --- |
| `nome` | `"Margem do lago"` | Nome da área (para quem lê o arquivo). |
| `estilo` | `"exterior"` | `exterior`: `#` vira pedra viva e a água fica escura. `interior` (padrão): paredes de pedra. |
| `nevoa` | `true` | Névoa baixa passando sobre a água. |
| `construcoes` | `[{"tipo": "casa", "x": 21, "y": 9, "w": 3, "h": 3}]` | Construções de várias casas (a casa da Nanshe). A porta fica na parede da esquerda. |
| `musica` | `"res://audio/ambiente.wav"` | Música ao entrar. Sem o campo, continua a que estava tocando. |
| `pontos` | `{"inicio": [12, 10]}` | Lugares com nome onde a Branca pode aparecer. `inicio` é o padrão. |
| `dinheiro` | `[[13, 8], [6, 11]]` | Dinheiro no chão (10 cada). Some de vez depois de pego. |
| `itens` | `[{"id": "cha", "x": 21, "y": 12}]` | Itens no chão (ids de `ITENS` em `scripts/data.gd`). |
| `npcs` | ver abaixo | Personagens parados com quem a Branca conversa. |
| `inimigos` | ver abaixo | Inimigos que patrulham a área. |
| `saidas` | ver abaixo | Casas que levam para outra área. |
| `ao_entrar` | `{"cena": "chegada", "se_nao": "viu_chegada"}` | Cena que roda ao entrar, a não ser que a marca `se_nao` já exista. |

### Personagens (`npcs`)
```json
{"id": "nanshe", "nome": "Nanshe", "dialogo": "nanshe_1", "x": 12, "y": 6, "se": "marca", "se_nao": "outra_marca"}
```
- `dialogo` abre `dialogos/<id>.json`; trocar por `"cena": "<id>"` roda uma cena de `cenas/` no lugar.
  Sem nenhum dos dois, o personagem fica na área mas ainda não conversa.
- `pose` (opcional): pose inicial, como nas cenas. O personagem com `"id": "nanshe"` usa o desenho da Nanshe.
- `se` (opcional): o personagem só aparece se a marca existir. `se_nao`: some quando a marca existir.

### Inimigos (`inimigos`)
```json
{"tipo": "a", "x": 14, "y": 9, "rota": [[14, 9], [19, 9], [19, 12]]}
```
- `tipo` é um id de `dados/inimigos.json`. `rota` são as casas da patrulha, em ordem (volta para a primeira no fim).

### Saídas (`saidas`)
```json
{"x": 1, "y": 16, "w": 1, "h": 2, "para": "floresta", "ponto": "da_margem"}
```
- O retângulo começa na casa `x, y` e tem `w` por `h` casas (1 por 1 se faltar).
- `para` é a área de destino e `ponto` é onde a Branca aparece lá (um nome de `pontos` da outra área).
- As casas de saída brilham fraco no chão.

## Tipos de inimigo (`dados/inimigos.json`)
```json
{"a": {"nome": "...", "musica": "res://audio/....wav", "notas": "res://audio/....json",
       "dano_erro": 6.0, "recompensa": [8, 15], "cor_olhos": [1.0, 0.55, 0.2], "altura": 64.0}}
```
- `notas` é o mapa de notas da luta, `dano_erro` a vida que cada erro tira e `recompensa` o dinheiro mínimo e máximo.

Exemplos completos ficam em `tests/fixtures/` (a área do teste automático, com tudo isso em uso).
