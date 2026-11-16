# Testes

Toda feature nova precisa de testes automatizados na mesma mudança.

## Como rodar

Há dois runners. Use cada um na hora certa:

| Quando | Comando (depois de `Godot_v4.7.2-stable_win64_console.exe`) | Tempo |
|---|---|---|
| **Enquanto trabalha**: só os arquivos do assunto | `--headless --fixed-fps 60 --path . -s tests/run_tests.gd -- plans interior` | 1–25 s |
| **Uma vez no fim** (antes de reportar ou commitar): tudo, em paralelo | `--headless --path . -s tests/run_parallel.gd` | ~20 s |
| Tudo num processo só (sem paralelismo) | `--headless --fixed-fps 60 --path . -s tests/run_tests.gd` | ~60 s |

Não repita a suíte inteira a cada passo: rode o arquivo do assunto até passar e a suíte inteira uma
vez no fim. Se ela acusar falha, corrija rodando só o arquivo afetado e repita a suíte uma vez.

Os dois mostram **só os problemas**: os arquivos e testes que falharam, com a mensagem, os testes
acima de 500 ms (`[lento] teste: N ms`) e o resumo final (`N testes, M asserções, K falha(s)`).
Termos soltos depois de `--` filtram arquivos pelo nome (nos dois runners); `verbose` lista todos
os testes (só em `run_tests.gd`). Código de saída `0` = tudo passou; `1` = alguma falha.

Na primeira vez (ou após adicionar scripts), rode antes `--headless --path . --import`.

`--fixed-fps 60` é essencial: sem ele o Godot sincroniza com o relógio e cada
`wait_physics_frames(n)` custa n/60 s reais (a suíte levava ~180 s); com ele os quadros rodam o
mais rápido possível com delta fixo, e de forma mais determinística. O `run_parallel.gd` já o passa
para cada processo.

Mensagens como `RID of type "CanvasItem" was leaked` ao final são avisos do encerramento
do runner e não indicam falha.

## Como funciona

Runner próprio, sem dependências externas:

- `tests/run_tests.gd` procura `tests/unit/test_*.gd`; cada arquivo estende `res://tests/base_test.gd`.
- Todo método `test_*` roda numa instância nova; `before_each()` e `after_each()` são hooks.
- Testes podem usar `await` (`wait_physics_frames(n)`, `wait_frames(n)`).
- Asserções: `assert_true/false`, `assert_eq/ne`, `assert_almost_eq`, `assert_gt`, e `ok`/`fail` para laços longos.
- **Isolamento:** antes de cada teste o runner zera os autoloads, o save e as opções, a largura das
  ruas, os efeitos (`Fx`) e as plantas injetadas; depois de cada teste, libera tudo o que ficou
  pendurado em `root` (partículas, itens no chão, cenas esquecidas). Assim o resultado de um teste
  não depende de quem rodou antes dele.
- Save e opções de teste ficam em `user://test_save_<pid>.json` e `user://test_options_<pid>.cfg`
  (um par por processo, apagado no fim), nunca nos arquivos do jogador.
- Cada execução grava o tempo de cada teste em `user://test_timings.json` (por máquina, fora do git).

### Em paralelo (`tests/run_parallel.gd`)

1. Lê os métodos `test_*` direto do texto dos arquivos (sem carregar os scripts).
2. Divide **por método** (não por arquivo) em N lotes de tempo parecido: o mais lento primeiro, sempre
   no lote mais leve, usando os tempos de `user://test_timings.json` (testes sem tempo valem 100 ms).
   Sem o arquivo, a primeira execução é menos equilibrada; as seguintes se ajustam sozinhas.
3. Abre N processos `run_tests.gd -- plan=<plano> shard=<i> out=<resultado>` e espera todos.
4. Soma os resultados e imprime no mesmo formato do runner sequencial, mais `N processos, X s`.

N padrão = metade dos núcleos, entre 2 e 8; mude com `-- jobs=N`. O piso de tempo é o teste mais
lento (cerca de 10 s). Se algo falhar, a saída completa de cada lote fica em
`user://test_runs/<pid>/lote_<i>.log` (o caminho é impresso; pastas com mais de 1 h são apagadas).
A lógica pura (argumentos, lotes, soma, tempos) está em `tests/runner_lib.gd`, testada em
`test_runner_tools.gd`.

## Escrevendo testes

- Prefira **lógica pura em `RefCounted`** (como `CityLayout`, `InteriorLayout`): testa sem cena.
- Para comportamento de nós, instancie a cena em `tree.root` e dê `queue_free()` no `after_each`.
- Input em teste: `Input.action_press("p1_right")` e solte no `after_each`.
- **Laços longos** (milhares de verificações): `if not ok(cond): fail("mensagem %s" % x)` em vez de
  `assert_*(cond, "mensagem %s" % x)`. O `assert_*` formata a mensagem mesmo quando passa; em
  milhões de asserções isso custava segundos.
- **Plantas de interior**: gerar um `InteriorLayout` custa ~15 ms. Em varreduras que só leem, use
  `Layouts.layout(id, tipo)` (`tests/layout_cache.gd`), que gera cada planta uma vez por processo.
  Use `InteriorLayout.new` quando o teste altera o layout, quando testa determinismo (comparar duas
  gerações) ou com planta injetada (o cache se desliga sozinho com `Plans.override`).
- Não conte com o que outro teste deixou na árvore: o runner limpa tudo entre testes, e em paralelo
  cada processo roda um subconjunto diferente.

## Cobertura atual (983 testes)

| Arquivo | Cobre |
|---|---|
| `test_city_layout.gd` | prédios, tamanhos, sobreposição, seed, portas, spawns |
| `test_country_layout.gd` | fazendas, plantações, árvores, estrada, determinismo |
| `test_world_layout.gd` | regiões, tamanho do mundo, ids únicos, spawns de carros |
| `test_interior_layout.gd` | interior por tipo: tamanho, planta, móveis, vagas de NPC, zonas, caminhos alcançáveis, determinismo |
| `test_plan_parser.gd` | leitura das plantas em mapa de texto: cômodos, paredes, portas, móveis, vagas, espelhamento, variantes |
| `test_plans.gd` | todas as plantas válidas e variadas, escala do personagem, conteúdo de cada tipo de prédio |
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
| `test_services.gd` | 13 serviços (custo, efeito, falta de dinheiro), só pela ação de input na zona, NPCs dos interiores |
| `test_day_cycle.gd` | relógio, fases, horários, cor ambiente com piso de luminosidade, horas das luzes |
| `test_lights.gd` | camada de luz, janelas e letreiros, faróis, interiores claros, portas fechadas, população por hora |
| `test_effects.gd` | clarão e cápsula do tiro, faíscas, poeira, marcas de pneu (limite de 200), tremor de câmera, limite de partículas |
| `test_transition.gd` | geometria da íris, tempos de 0,25 s, estado só muda com a íris fechada, novo jogo |
| `test_map.gd` | ícones por tipo, geometria do mapa, prédios conhecidos, minimapa no HUD, mapa de tela cheia, tecla M |
| `test_pause_title.gd` | menu em fonte pixel, controles, pausa que congela, opção de tremor, arte e tela de título |
| `test_map_points.gd` | neblina por quarteirão, pontos no mapa (clique, escolher, tirar), seta e distância no HUD |
| `test_save_melee.gd` | save (ficha, inventário, versão, migração, corrompido), autosave, opções, título com Continuar e Opções, cassetete e socos |
| `test_route.gd` | grade de ruas, rota mais curta, trilha pontilhada no HUD, ruas estreitas por bairro |
| `test_phase6.gd` | casinhas e becos, casa do agente, serviços de casa, uniformes, hospital, delegacia e gente mínima dos interiores |
| `test_art_rules.gd` | varredura: nenhum `ColorRect`/`Polygon2D`/`Line2D` e nenhuma cor fora da paleta nos scripts e cenas |
| `test_world_visuals.gd` | cena real sem `ColorRect`, pedaços de chão, sprites e animação, ordem de desenho, HUD |
| `test_runner_tools.gd` | runner: argumentos, descoberta, divisão em lotes paralelos, soma, tempos; cache de plantas; `ok`/`fail`; limpeza entre testes |

O aviso `Tipo de morte desconhecido` impresso durante `test_score` é esperado
(o teste confere que tipos inválidos são ignorados).
