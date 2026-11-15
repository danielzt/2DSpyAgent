# Testes

Toda feature nova precisa de testes automatizados na mesma mudança.

## Como rodar

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
```

Para rodar só alguns arquivos, passe termos do nome depois de `--` (ex.: `-s tests/run_tests.gd -- combat traffic`).
Antes de concluir uma mudança, rode sempre a suíte inteira.

Código de saída `0` = tudo passou; `1` = alguma falha. Na primeira vez (ou após adicionar
scripts com `class_name`), rode antes `--headless --path . --import`.

Mensagens como `RID of type "CanvasItem" was leaked` ao final são avisos do encerramento
do runner e não indicam falha.

## Como funciona

Runner próprio, sem dependências externas (`tests/run_tests.gd`):

- Procura `tests/unit/test_*.gd`; cada arquivo estende `res://tests/base_test.gd`.
- Todo método `test_*` roda numa instância nova; `before_each()` e `after_each()` são hooks.
- Testes podem usar `await` (`wait_physics_frames(n)`, `wait_frames(n)`).
- Asserções: `assert_true/false`, `assert_eq/ne`, `assert_almost_eq`, `assert_gt`.
- Se for preciso, dá para migrar para GUT ou gdUnit4 depois; os testes são simples.

## Escrevendo testes

- Prefira **lógica pura em `RefCounted`** (como `CityLayout`, `InteriorLayout`): testa sem cena.
- Para comportamento de nós, instancie a cena em `tree.root` e dê `queue_free()` no `after_each`.
- Input em teste: `Input.action_press("p1_right")` e solte no `after_each`.

## Cobertura atual (577 testes)

| Arquivo | Cobre |
|---|---|
| `test_city_layout.gd` | prédios, tamanhos, sobreposição, seed, portas, spawns |
| `test_country_layout.gd` | fazendas, plantações, árvores, estrada, determinismo |
| `test_world_layout.gd` | regiões, tamanho do mundo, ids únicos, spawns de carros |
| `test_interior_layout.gd` | escala, móveis, saída livre, determinismo |
| `test_game_state.gd` | estado dentro/fora, posição de retorno |
| `test_score.gd` | regra de pontos (inocente tira, criminoso dá) |
| `test_input_setup.gd` | ações por jogador, teclas, gamepads, interação, idempotência |
| `test_hud.gd` | instrução no canto, região, pontos |
| `test_player.gd` | movimento, diagonal, colisão, input por jogador, câmera |
| `test_car_handling.gd` | chute em batidas, deslize, auxílio de direção |
| `test_traffic.gd` | rotas do trânsito, IA, freio para pedestres, anti-roubo |
| `test_combat.gd` | projéteis, arma, cooldown, vida, morte/respawn |
| `test_npc.gd` | comportamento, pontos por morte, atropelamento |
| `test_sidewalks.gd` | grafo de calçadas, pedestres, fuga, travamento |
| `test_pickups_and_shops.gd` | itens no chão, dinheiro, loot, lojas, painel, interior de loja |
| `test_crime.gd` | crimes por região, alertas, resolução, bônus |
| `test_inventory.gd` | itens, inventário, painel I, mãos, taser, kit médico, escudo |
| `test_character.gd` | ficha C, XP, níveis, atributos e seus efeitos no jogo |
| `test_conversation.gd` | identidade dos NPCs, card de conversa, tecla F |
| `test_aim_and_display.gd` | mira com mouse, ajuste de janela, F11 |
| `test_vehicle.gd` | física do carro, entrar/sair, lados livres, E, prompts |
| `test_scenes.gd` | montagem de main e interior, E em portas, regiões, câmera |
| `test_palette_and_canvas.gd` | paleta de 32 cores, rampas, legenda, operações da tela de pixel |
| `test_pixel_font.gd` | letras, acentos, cobertura dos textos do jogo, medidas |
| `test_sprites.gd` | personagens, carros, objetos e tiles (tamanho, paleta, variações), cache de texturas |
| `test_building_art.gd` | estilo dos prédios, limite da fachada, letreiros, desenho sem buracos |
| `test_street_props.gd` | mobiliário urbano, parques e quintais: determinismo, calçada livre, portas livres |
| `test_districts.gd` | bairros: todo quarteirão com bairro, contiguidade, cotas, determinismo, efeito nos prédios |
| `test_building_defs.gd` | tabela de tipos, cotas mínimas e máximas, tamanho mínimo, bairros permitidos, horários, porta alcançável |
| `test_names.gd` | nomes de prédios e ruas: únicos, determinísticos, desenháveis pela fonte; texto de lugar do HUD |
| `test_population.gd` | trabalho e moradia em prédios reais, falas que citam o lugar |
| `test_world_visuals.gd` | cena real sem `ColorRect`, pedaços de chão, sprites e animação, ordem de desenho, HUD |

O aviso `Tipo de morte desconhecido` impresso durante `test_score` é esperado
(o teste confere que tipos inválidos são ignorados).
