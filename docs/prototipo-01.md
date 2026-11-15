# Protótipo 01: andar pela cidade

> Nota: os números de tamanho abaixo são do estado original; prédios foram aumentados
> no [protótipo 02](prototipo-02-interiores.md).

## O que existe

- **Cena principal** (`scenes/main.tscn`): contém a cidade e, via `scripts/main.gd`,
  instancia o jogador 1 no cruzamento (200, 200).
- **Cidade** (`scripts/world/city.gd`): mundo de 3200x3200 px gerado por código.
  Grade de 8x8 quarteirões de 400 px, ruas de 120 px, calçadas, faixas tracejadas,
  prédios sólidos (`StaticBody2D`) com cores sorteadas por seed fixa (2024) e
  paredes invisíveis nas bordas.
- **Jogador** (`scenes/player/player.tscn`, `scripts/player/player.gd`):
  `CharacterBody2D` em modo *floating* (top-down), velocidade 220 px/s, 8 direções
  com `Input.get_vector`. Visual provisório: quadrado com marcador de direção.
  Tem `Camera2D` com suavização, limitada às bordas do mundo.
- **Input** (`scripts/autoload/input_setup.gd`): ver [arquitetura.md](arquitetura.md).

## Parâmetros do jogador (`@export`)

| Propriedade | Padrão | Função |
|---|---|---|
| `player_index` | 1 | Define o prefixo das ações (`p1_`, `p2_`) |
| `speed` | 220 | Velocidade em px/s |
| `color` | amarelo | Cor do placeholder |

## Como testar

F5 no editor. Mova com WASD ou analógico do gamepad 0 e confirme que o jogador
colide com os prédios e a câmera segue sem sair do mapa.

## Limitações conhecidas

- Sem sprites, sons, carros, pedestres ou combate
- Só o jogador 1 é instanciado (jogador 2 tem input registrado, mas não aparece)
- Sem multiplayer nem split screen

## Próximos passos sugeridos

1. Carro dirigível (entrar/sair)
2. Split screen com 2 jogadores locais
3. Pedestres simples
4. Sprites pixel art no lugar dos placeholders
