# Interiores caprichados — Etapa 1 (motor + 5 plantas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o interior paramétrico por plantas em mapa de texto (piso, objetos, detalhe), com móveis na escala do
personagem, paredes com face visível, uniformes por prédio e NPCs com atividade, entregando as 5 plantas de referência
(casa do agente, hospital, delegacia, bar, casa) para o usuário aprovar o estilo.

**Architecture:** `PlanParser` (lógica pura) lê o dicionário de uma planta e devolve rooms, walls, items, npc_slots,
zones etc. `InteriorLayout` usa o parser quando o tipo tem planta (`Plans.has(type)`) e cai no construtor antigo nos
outros 20 tipos (que a Etapa 2 converte). `interior.gd` desenha pisos por célula, faces de parede, itens de parede e de
cima de móvel, e cria NPCs com atividade e uniforme do prédio.

**Tech Stack:** Godot 4.7.2, GDScript, runner próprio (`tests/run_tests.gd`).

**Spec:** `docs/superpowers/specs/2026-11-15-interiores-caprichados-design.md` (ler as seções 5 a 12 antes de começar).

## Global Constraints

- GDScript com tipagem estática, `snake_case`, constantes `UPPER_CASE`, comentários em português.
- Arte só por código em `scripts/art/`, só cores de `Palette.COLORS` (32 cores), 1 texel = 2 px, texturas via `SpriteFactory` (cache).
- Lógica pura em `RefCounted`; nós em `interior.gd`. Seed fixa pelo id do prédio.
- Interação só por `InteractZone` + `p{N}_interact`.
- Grade de 32 px. Tamanhos: P = 40x23 células (1280x736), M = 48x27 (1536x864), G = 56x32 (1792x1024).
- Personagem: 12x16 texels = 24x32 px. Escala (spec §6): cama de solteiro 48x80 px, casal 80x80, leito 48x80,
  sofá 96x48, poltrona 48x48, banco 96x32, mesa de escritório 64x48, mesa de 4 lugares 64x64, criado-mudo/vaso/lixeira ≤ 32x32.
- Face de parede: 24 px de altura (`FACE_H`).
- Toda tarefa termina com a **suíte inteira** passando:
  `Z:\Dev\Godot\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s tests/run_tests.gd`
  → `N testes, 0 falha(s)`. Depois de criar scripts novos, rodar antes `--headless --path . --import`.
  Filtro por arquivo: `... -s tests/run_tests.gd -- plan_parser`.
- Commits só quando o usuário pedir (regra do ambiente); as tarefas não fazem commit.

## Review Focus

1. **Planta mal escrita** (linha de largura diferente, letra sem legenda, peça não retangular, sentado fora de assento):
   deve falhar no `validate()` com mensagem que diz linha, coluna e letra — nunca virar interior quebrado em silêncio. (Tarefa 1)
2. **Espelhamento**: interior espelhado mantém saída alcançável, rotas de ronda dentro do cômodo e `facing` left/right
   trocados. (Tarefas 1 e 2)
3. **NPC sentado/deitado atacado**: levanta, volta a ter colisão e foge; não atravessa móveis depois. (Tarefa 7)
4. **NPC em ronda bloqueado pelo jogador**: espera e segue para o próximo ponto; nunca empurra o jogador nem fica
   preso tentando. (Tarefa 7)
5. **Tipos ainda sem planta** (20 tipos legados): continuam abrindo e válidos com o caminho antigo, sem erro na cena. (Tarefas 2 e 8)

---

## Estrutura de arquivos

| Arquivo | Papel |
|---|---|
| `scripts/interior/plan_parser.gd` (novo) | Valida e lê uma planta → dicionário de layout (pura) |
| `scripts/interior/plans/plans.gd` (novo) | Registro: tipo → planta |
| `scripts/interior/plans/{agent_home,hospital,police,bar,house}.gd` (novos) | `static func data() -> Dictionary` |
| `scripts/interior/interior_layout.gd` | Caminho "planejado" + legado |
| `scripts/interior/interior.gd` | Desenho de pisos, faces, itens por camada; NPCs com atividade e uniforme |
| `scripts/art/tile_factory.gd` | Pisos novos e faces de parede |
| `scripts/art/furniture_art.gd` | Móveis novos, itens de parede e de cima de móvel, `tone` opcional |
| `scripts/art/character_sprites.gd` | Uniformes por prédio, chapéu e detalhe, poses |
| `scripts/art/sprite_factory.gd` | `character(..., pose)` |
| `scripts/npc/npc.gd` | Atividades `post`, `patrol`, `sit`, `lie`, `work` |
| `tests/unit/test_plan_parser.gd` (novo), `test_plans.gd` (novo) | Parser e as 5 plantas |
| `tests/unit/test_interior_layout.gd`, `test_phase6.gd`, `test_npc.gd`, `test_sprites.gd` | Atualizados |
| `tools/probe.gd` | Captura das 5 plantas |
| `docs/redesign-fase-7.md` (novo), `docs/README.md`, `docs/changelog.md`, `docs/gdd.md` | Documentação |

---

### Task 1: PlanParser

**Files:**
- Create: `scripts/interior/plan_parser.gd`
- Test: `tests/unit/test_plan_parser.gd`

**Interfaces:**
- Produces:
  - `const CELL := 32.0`, `const THIN := 16.0`, `const FACE_H := 24.0`, `const EXIT_DEPTH := 12.0`
  - `const SIZES := {"P": Vector2i(40, 23), "M": Vector2i(48, 27), "G": Vector2i(56, 32)}`
  - `const SEATS := ["chair", "office_chair", "stool", "sofa", "armchair", "bench", "seats", "booth"]`
  - `const BEDS := ["bed", "double_bed", "hospital_bed", "bunk", "sofa", "car_lift"]`
  - `static func validate(plan: Dictionary) -> Array[String]` — lista de erros (vazia = ok).
  - `static func parse(plan: Dictionary, building_id: int) -> Dictionary` com as chaves:
    `size: Vector2`, `size_class: String`, `mirrored: bool`, `variant: int`,
    `rooms: Array[Dictionary]` `{name, rect: Rect2, floor: String, wall: String}`,
    `floor_rects: Array[Dictionary]` `{rect, floor}`, `walls: Array[Rect2]`, `doors: Array[Rect2]`,
    `wall_faces: Array[Dictionary]` `{rect, style}`,
    `items: Array[Dictionary]` `{kind, rect, solid: bool, layer: "floor"|"on"|"wall", tone: String}`,
    `npc_slots: Array[Dictionary]` `{role, position: Vector2, staff: bool, act: String, route: Array[Vector2], facing: String}`,
    `zones: Array[Dictionary]` `{id, rect, verb: ""}` (o verbo é preenchido pelo `InteriorLayout`),
    `exit: Rect2`, `spawn: Vector2`.

**Formato da planta** (dicionário devolvido por `data()`):

```gdscript
{
	"size": "M",
	"floor_grid": [...],   # Array[String], uma letra por célula: estilo do cômodo
	"object_grid": [...],  # paredes, portas, móveis, itens de parede
	"detail_grid": [...],  # "." = nada; pessoas, pontos de ronda, zonas, itens de cima de móvel
	"floor_legend": {"w": {"room": "Sala", "floor": "floor/herringbone", "wall": "stripes_wine"}},
	"object_legend": {"b": {"item": "double_bed", "size": [2.5, 2.5], "align": "top"},
					  "J": {"wall_item": "window"}},
	"detail_legend": {"1": {"npc": "enfermeiro", "staff": true, "act": "patrol", "route": "a", "facing": "down"},
					  "a": {"route": "a"}, "$": {"zone": "heal"}, "p": {"on": "plate", "size": [0.5, 0.5]}},
	"variants": [{"floors": {"w": "floor/wood"}, "walls": {"w": "plaster_cream"}, "tones": {"sofa": "blue"}}],
}
```

Regras fixas do formato (o resto é do implementador):
- `object_grid`: `#` parede cheia (célula inteira); `|` parede fina vertical (16 px centrada na célula); `-` parede fina
  horizontal; `D` vão de porta interna (piso livre; vai para `doors`); `E` saída (só na última linha, run de 3 células);
  `.` piso livre. Letra de `wall_item` conta como parede cheia e põe o item na face abaixo (`layer "wall"`, sem colisão,
  retângulo `Rect2(x, y_da_célula + CELL, CELL * w, FACE_H)`).
- Peça de várias células: retângulo conectado da mesma letra = uma peça. `size` (em células, aceita 0,5) e `align`
  (`center` padrão, `top`, `bottom`, `left`, `right`) posicionam o retângulo real dentro do bloco; `solid` padrão `true`;
  `chance` padrão 1.0 (sorteio pela seed, por peça); `tone` opcional.
- Paredes: runs horizontais de `#` mescladas em um `Rect2`; `|` e `-` idem.
- Faces: cada célula de `#` (ou `-`) com piso logo abaixo gera face `Rect2(x, y_abaixo, CELL, FACE_H)` com o `wall` da
  letra de piso abaixo; mesclar runs vizinhos de mesmo estilo.
- Cômodos: componente conectado de mesma letra de piso → um `room` (retângulo envolvente). `floor_rects`: runs
  horizontais de mesma letra (com override da variante aplicado).
- `detail_grid`: dígito = vaga (posição = centro da célula); letra com `route` = ponto de ronda; `zone` = retângulo
  conectado → zona; `on` = item de cima de móvel (`layer "on"`, sem colisão, centrado na célula).
  Rota da vaga = `[posição da vaga] + pontos da letra em ordem de leitura`. `chance` vale para vagas e `on`.
- `act` padrão `post`; `facing` padrão `down`; `staff` padrão `false`.
- Seed: `rng.seed = building_id * 7919 + 13`; primeiro `randf() < 0.5` → espelhado; depois `randi_range` para a
  variante (0 = sem override quando `variants` vazio); depois os `chance` em ordem de leitura (objetos, depois detalhe).
- Espelhar: `x' = size.x - rect.end.x` em todos os retângulos, `x' = size.x - x` nos pontos; `facing` left↔right.
- `exit = Rect2(x0, size.y - EXIT_DEPTH, largura_do_run_E, EXIT_DEPTH)`; `spawn = Vector2(centro_x_do_E, size.y - CELL * 1.5)`.

`validate()` devolve erros (texto com linha, coluna e letra) para: grade com número de linhas/colunas diferente de
`SIZES[size]`; as três grades com tamanhos diferentes; letra sem legenda; peça não retangular; `E` fora da última linha
ou ausente; vaga `sit` cuja célula não está sobre peça de `SEATS`, `lie` fora de `BEDS`; ponto de ronda sobre célula sólida;
`route` de vaga sem nenhum ponto.

- [ ] **Step 1: Escrever os testes** em `tests/unit/test_plan_parser.gd` com uma planta pequena de fixture
  (dicionário no próprio teste; usar `size: "P"` e grades 40x23 geradas por função auxiliar que preenche com `#`
  na borda e `.` dentro, permitindo "carimbar" trechos). Testes e asserções:
  - `test_valid_fixture_has_no_errors`: `validate(fixture) == []`.
  - `test_errors_point_to_line_column_and_letter`: linha encurtada → erro contém `"linha 3"`; letra `Z` sem legenda →
    erro contém `"Z"`; peça em L → erro contém `"retangular"`; sem `E` → erro contém `"saída"`.
  - `test_sizes_match_the_spec`: `PlanParser.SIZES["P"] * 32 == Vector2i(1280, 736)`, M `1536x864`, G `1792x1024`.
  - `test_multi_cell_piece_is_one_item_with_real_size`: bloco `bb` 3x3 células com `size [2.5, 2.5]`, `align top` →
    1 item `double_bed`, `rect.size == Vector2(80, 80)`, `rect.position.y` = topo do bloco.
  - `test_walls_merge_and_faces_take_the_style_of_the_room_below`: run de 10 `#` → 1 `Rect2` de 320x32; face abaixo
    com `style` da letra de piso abaixo e altura 24.
  - `test_thin_walls_are_16_px`: `|` vira `Rect2` de largura 16 centrado na célula.
  - `test_wall_item_sits_on_the_face`: `J` (janela) na borda de cima → item `layer "wall"`, `solid false`,
    `rect.position.y == 32`, `rect.size.y == 24`; e a célula conta como parede.
  - `test_detail_layer_people_routes_zones_and_on_items`: vaga `1` com `act patrol` e 2 pontos `a` → `route.size() == 3`;
    zona `$` 3x2 → `rect.size == Vector2(96, 64)`; `on` → item `layer "on"`, `solid false`.
  - `test_seated_npc_must_be_on_a_seat`: `sit` sobre piso → erro contendo `"assento"`; sobre `sofa` → sem erro.
  - `test_exit_and_spawn`: `exit.end.y == size.y`, `exit.size.x == 96`, `spawn` fica uma célula e meia acima da base,
    centrado no `E`.
  - `test_parse_is_deterministic_and_mirrors_some`: mesmo id → mesmo dicionário; em 40 ids, entre 8 e 32 espelhados;
    no espelhado, uma vaga com `facing "left"` vira `"right"` e a rota fica espelhada.
  - `test_chance_and_variants_vary_by_seed`: item com `chance 0.5` aparece em alguns ids e não em outros; com 2
    variantes, o piso da letra trocada muda entre ids.

- [ ] **Step 2: Rodar** `--headless --path . --import` e `... -s tests/run_tests.gd -- plan_parser`. Esperado: falha
  (script inexistente).

- [ ] **Step 3: Implementar** `plan_parser.gd` com as interfaces acima.

- [ ] **Step 4: Rodar** `-- plan_parser` → passa; depois a suíte inteira → `0 falha(s)`.

---

### Task 2: Registro de plantas e caminho planejado no InteriorLayout

**Files:**
- Create: `scripts/interior/plans/plans.gd`
- Modify: `scripts/interior/interior_layout.gd` (`_init`, `size_class_for`, `exit_door`, `spawn_point`, `clear_zone`)
- Test: `tests/unit/test_interior_layout.gd`

**Interfaces:**
- Consumes: `PlanParser.parse`, `PlanParser.validate`.
- Produces:
  - `Plans.has(type: String) -> bool`, `Plans.data(type: String) -> Dictionary`, `Plans.types() -> Array`.
    Nesta tarefa o registro aceita plantas injetadas para teste: `Plans.override(type: String, plan: Dictionary)` e
    `Plans.clear_overrides()` (o teste usa a fixture da Tarefa 1; as plantas reais entram nas Tarefas 9 a 13).
  - `InteriorLayout`: novos campos `planned: bool`, `floor_rects`, `wall_faces`, `doors`, `variant: int`;
    `items` ganham `layer` e `tone` (legado: `layer "floor"`, `tone ""`); `npc_slots` ganham `act`, `route`, `facing`
    (legado: `act "post"`, `route []`, `facing "down"`).
  - `InteriorLayout.is_planned(type: String) -> bool` (estático).
  - Planejado: `size_class_for(type, facade)` devolve o `size` da planta (ignora a fachada); `exit_door()` e
    `spawn_point()` vêm do parser; `clear_zone() = Rect2(exit.position.x, size.y - 3 * CELL, exit.size.x, 3 * CELL)`;
    zonas recebem `verb = Services.verb(id)`; sem `_dress()` nem `_fill_to_minimum()`.
  - Legado: tudo como hoje.

- [ ] **Step 1: Testes** em `test_interior_layout.gd`:
  - `test_planned_type_uses_the_plan`: com `Plans.override("bar", fixture)`, `InteriorLayout.new(3, "bar")` tem
    `planned == true`, `size == Vector2(1280, 736)`, e `size_class_for("bar", 300.0) == "P"`; `Plans.clear_overrides()`
    no fim.
  - `test_planned_zones_get_the_service_verb`: zona `heal` da fixture → `verb == Services.verb("heal")`.
  - `test_legacy_types_keep_working`: para `["armory", "hotel", "cinema"]`, `planned == false` e `_check(...)` passa.
  - Ajustar `_check()`: vagas com `act` `sit` ou `lie` não passam pela verificação "dentro de um sólido"
    (elas estão sobre o móvel por definição); itens com `layer` `on` e `wall` não entram na verificação de sobreposição.
- [ ] **Step 2:** rodar `-- interior_layout` → falha.
- [ ] **Step 3:** implementar `plans.gd` e o caminho planejado.
- [ ] **Step 4:** `-- interior_layout` passa; suíte inteira `0 falha(s)`.

---

### Task 3: Pisos novos e faces de parede

**Files:**
- Modify: `scripts/art/tile_factory.gd`
- Test: `tests/unit/test_sprites.gd` (ou `test_palette_and_canvas.gd`, onde já se testam tiles)

**Interfaces:**
- Produces:
  - Pisos (32x32 texels, repetíveis), ids: `floor/herringbone`, `floor/wood_dark`, `floor/laminate`,
    `floor/carpet_navy`, `floor/carpet_cream`, `floor/linoleum_mint` (teal/ice), `floor/linoleum_gray`,
    `floor/linoleum_white`, `floor/bath_tile`.
  - Faces: `TileFactory.face(style: String) -> RefCounted` — tela de 16x12 texels (32x24 px) repetível na horizontal,
    com rodapé (2 texels) embaixo e friso de sombra (1 texel) em cima. `TileFactory.has_face(style) -> bool`.
    `SpriteFactory.face(style) -> ImageTexture` (cache `face/<style>`).
    Estilos desta etapa: `stripes_wine` (listrado creme e vinho), `wood_panel` (madeira nobre), `tile_blue` (azulejo
    azul-claro), `tile_white_green` (azulejo branco com faixa verde), `navy_half` (painel azul-escuro em meia-parede,
    reboco claro em cima), `brick` (tijolo aparente), `floral` (papel florido), `plaster_cream`, `plaster_gray`.
  - Topo de parede: cor `shadow` com contorno `ink` (sem textura).

- [ ] **Step 1: Testes**: `test_new_floors_exist_and_use_the_palette` (cada id novo: `has_tile`, 32x32,
  `only_palette_colors()`, mais de 2 cores distintas); `test_wall_faces` (cada estilo: `has_face`, 16x12,
  `only_palette_colors()`, as 2 fileiras de baixo diferentes da fileira do meio = rodapé).
- [ ] **Step 2:** rodar → falha. **Step 3:** implementar. **Step 4:** passa; suíte inteira `0 falha(s)`.

---

### Task 4: Móveis na nova escala, itens de parede e de cima de móvel

**Files:**
- Modify: `scripts/art/furniture_art.gd`
- Test: `tests/unit/test_interior_layout.gd` (testes de arte já existem lá)

**Interfaces:**
- Produces:
  - `FurnitureArt.canvas(kind: String, w: int, h: int, tone := "") -> RefCounted`; `cache_key(kind, w, h, tone := "")`
    inclui o tom; `tone` vazio = material de `MATERIALS`.
  - Novos móveis: `armchair`, `double_bed`, `chair`, `office_chair`, `floor_lamp`, `fireplace`, `record_player`,
    `dresser`, `round_table`, `bar_stool`, `beer_taps`, `interrogation_table`, `flag`, `coffee_machine`.
  - Itens de parede: `window`, `painting`, `clock`, `extinguisher`, `poster`, `notice_board`, `wall_tv`, `wall_shelf`,
    `mirror`, `exit_sign`, `wall_lamp`, `diploma`, `wanted_board`, `dartboard`, `bottle_wall`, `case_wall` (mural com fios
    vermelhos), `safe_wall`.
  - Itens de cima: `plate`, `glass`, `bottle`, `papers`, `phone`, `book`, `table_lamp`, `fruit_bowl`, `coffee_pot`, `mug`,
    `ashtray`, `flowers`, `stethoscope_tray`, `pool_cue`, `cat` (gato dormindo enrolado, 16x12 texels).
  - `FurnitureArt.WALL_KINDS: Array` e `ON_KINDS: Array` (listas acima), para o parser e os testes.
  - Todos os desenhos devem ler bem no tamanho real da planta (ex.: `double_bed` 40x40 texels com colcha e dois
    travesseiros; `mug` 8x8 texels).
  - A janela é desenhada com o vidro transparente; o céu é pintado por trás em `interior.gd` (Tarefa 8).

- [ ] **Step 1: Testes**: `test_new_kinds_have_art_at_real_scale` — para cada novo tipo, `canvas(kind, w, h)` no tamanho
  da tabela da spec §6 (ou 16x12 para itens de parede, 8x8 para itens de cima) é `only_palette_colors()` e tem mais de
  40% dos texels opacos (itens de cima: mais de 20); `test_tone_changes_the_art`: `canvas("sofa", 48, 24, "blue")` ≠
  `canvas("sofa", 48, 24)` e ambos são da paleta; `test_wall_and_on_kinds_are_listed` (toda entrada de `WALL_KINDS` e
  `ON_KINDS` tem `has_kind`). Ajustar `test_every_furniture_kind_is_drawn_with_palette_colors` para itens de cima
  (aceitar `opaque_count() > 100` só para os que não são `ON_KINDS`).
- [ ] **Step 2:** falha. **Step 3:** implementar. **Step 4:** passa; suíte inteira `0 falha(s)`.

---

### Task 5: Uniformes por prédio, chapéu e detalhe

**Files:**
- Modify: `scripts/art/character_sprites.gd`, `scripts/art/sprite_factory.gd` (chave inclui os campos novos via `look_key`)
- Test: `tests/unit/test_phase6.gd` (seção de uniformes)

**Interfaces:**
- Produces:
  - Aparência ganha `hat: String` (`""`, `kepi`, `nurse_cap`, `chef_hat`, `helmet`, `straw`) e `detail: String`
    (`""`, `coat`, `apron`, `vest`, `tie`, `badge`, `reflective`) e `detail_color: String`. `civilian_look`,
    `agent_look` e `criminal_look` preenchem os três com `""`. `look_key` inclui os três.
  - `const BUILDING_UNIFORMS := {type: {"staff": overrides, "roles": {role: overrides}}}` para os 24 tipos, conforme a
    tabela da spec §9.2 (cores de `Palette.COLORS`). Obrigatórios nesta etapa, com valores exatos:
    - `police` staff: `shirt "blue", shirt2 "navy", pants "navy", cap "navy", hat "kepi", detail "badge", detail_color "amber"`;
      role `perito`: `shirt "white", shirt2 "light", pants "slate", detail "coat"`; role `detetive`: `shirt "sand", shirt2 "brown", pants "brown", cap ""`.
    - `hospital` staff: `shirt "white", shirt2 "light", pants "white", cap ""`; role `médica`: `detail "coat"`;
      roles `enfermeiro` e `auxiliar de enfermagem`: `hat "nurse_cap", cap "white"`; `recepcionista`: `detail "badge", detail_color "teal"`.
    - `bar` staff: `shirt "white", shirt2 "light", pants "ink", detail "vest", detail_color "ink"`.
  - `const VISITOR_UNIFORMS := {"paciente": {"shirt": "ice", "shirt2": "sky", "pants": "ice", "cap": ""}, "preso": {"shirt": "orange", "shirt2": "red", "pants": "orange", "cap": ""}}`.
  - `static func uniform_for(building_type: String, role: String, staff: bool) -> Dictionary` — staff: `staff` do tipo
    com o override do papel por cima; não-staff: `VISITOR_UNIFORMS.get(role, {})`.
  - `static func look_for(kind: String, p_seed: int, role := "", building_type := "", staff := false) -> Dictionary` —
    criminoso não muda; com `building_type`: aplica `uniform_for`; sem: `dressed(base, role)` (legado).
  - Desenho de `hat` e `detail` em `_apply_head`/`_apply_body` nas 3 direções (jaleco = camisa até o joelho; avental =
    retângulo `detail_color` no peito e na cintura; colete = laterais do tronco; gravata; crachá = 1 texel; faixa refletiva
    = linha horizontal). Usar letra trocável nova `6` = `detail_color` na legenda.

- [ ] **Step 1: Testes** (substituem os de uniforme por nome em `test_phase6.gd`, mantendo `dressed` legado testado):
  - `test_hospital_staff_all_white_by_building`: para todo papel de `BuildingDefs.staff_of("hospital")` e também
    `"atendente"` (papel fora da lista), `look_for("innocent", 5, role, "hospital", true).shirt == "white"`.
  - `test_police_staff_all_blue_with_kepi`: todo staff da delegacia, exceto `perito` e `detetive`, tem `shirt "blue"` e
    `hat "kepi"`; `preso` não-staff tem `shirt "orange"`; `paciente` tem `shirt "ice"`.
  - `test_customers_keep_their_clothes`: `look_for("innocent", 7, "frequentador", "bar", false) == civilian_look(...)`
    nas chaves de roupa.
  - `test_every_building_type_has_a_staff_uniform`: todo tipo de `BuildingDefs.ORDER` (exceto `house`, `apartment`,
    `agent_home`) tem `BUILDING_UNIFORMS[type].staff` não vazio e toda cor é chave de `Palette.COLORS`.
  - `test_hat_and_detail_change_the_sprite`: `rows_for` com `hat "kepi"` ≠ sem chapéu; com `detail "coat"` ≠ sem
    detalhe, nas 3 direções; `build(...)` continua `only_palette_colors()`.
- [ ] **Step 2:** falha. **Step 3:** implementar. **Step 4:** passa; suíte inteira `0 falha(s)`.

---

### Task 6: Poses do personagem (sentado, deitado, trabalhando)

**Files:**
- Modify: `scripts/art/character_sprites.gd`, `scripts/art/sprite_factory.gd`
- Test: `tests/unit/test_sprites.gd`

**Interfaces:**
- Produces:
  - `CharacterSprites.POSES := ["stand", "sit", "lie", "work"]`.
  - `rows_for(look, direction, frame, pose := "stand")`, `body(...)` e `build(look, direction, frame, pose := "stand")`.
    Mesmo canvas 16x20. `sit`: pernas dobradas (últimas 4 fileiras trocadas; de costas, pernas escondidas pelo
    encosto — desenho livre). `lie`: vista de cima de quem está deitado de barriga para cima = frente com o corpo da
    cintura para baixo coberto por lençol (`white`/`light`), braços sobre o lençol, **sem sombra no chão**; só direção
    `down`. `work`: quadros 1 e 2 com braços alternando à frente do corpo (digitar, mexer panela), pernas paradas.
  - `SpriteFactory.character(look, direction, frame, pose := "stand")`, chave `char/<look>/<dir>/<frame>/<pose>`.

- [ ] **Step 1: Testes**: `test_poses_differ_from_standing` (para cada pose ≠ stand, `build` difere de `stand` e é da
  paleta); `test_lying_has_no_floor_shadow` (nenhum texel com a cor `Palette.cast_shadow()` nas 3 fileiras de baixo);
  `test_work_animates` (quadros 1 e 2 de `work` diferem); `test_pose_is_part_of_the_cache_key`.
- [ ] **Step 2:** falha. **Step 3:** implementar. **Step 4:** passa; suíte inteira `0 falha(s)`.

---

### Task 7: Atividades do NPC

**Files:**
- Modify: `scripts/npc/npc.gd`
- Test: `tests/unit/test_npc.gd`

**Interfaces:**
- Consumes: `SpriteFactory.character(..., pose)` (Tarefa 6), `CharacterSprites.look_for(..., building_type, staff)` (Tarefa 5).
- Produces (propriedades do NPC, definidas antes de `add_child`):
  - `var activity := ""` (`""` = comportamento antigo; `post`, `patrol`, `sit`, `lie`, `work`)
  - `var route := PackedVector2Array()`, `var facing := "down"`
  - `var uniform_building := ""`, `var uniform_staff := false` (passados a `look_for`)
  - `const PATROL_SPEED := 40.0`, `const PATROL_PAUSE := Vector2(2.0, 4.0)` (min, máx em s),
    `const LOOK_AROUND := Vector2(4.0, 8.0)`, `const WORK_FRAME_TIME := 0.4`.
  - `func pose() -> String` (pose atual, para testes).
- Comportamento:
  - `sit`/`lie`: parado na posição, pose correspondente, `CollisionShape2D.disabled = true`, direção `facing`
    (`lie` sempre `down`).
  - `work`: parado, pose `work` animada.
  - `post`: parado olhando `facing`; a cada `LOOK_AROUND` vira para um lado por 1,5 s e volta.
  - `patrol`: anda a `PATROL_SPEED` até o próximo ponto de `route` (cíclico), pausa `PATROL_PAUSE`; se colidir
    (`get_slide_collision_count() > 0`) por mais de `BLOCKED_TURN_BACK_TIME`, para, espera a pausa e passa ao ponto
    seguinte.
  - Atacado (fuga já existente): `activity` vira `""`, colisão reativada, pose `stand`, e segue a fuga atual.
  - Conversa (`talking`) continua parando qualquer atividade.

- [ ] **Step 1: Testes** (cena do NPC em `tree.root`, `await wait_physics_frames(n)`):
  - `test_sitting_npc_has_no_collision_and_sits`: `activity "sit"` → `pose() == "sit"`, colisão desativada, posição
    inalterada após 30 quadros.
  - `test_lying_npc_lies_down`: `pose() == "lie"`, `sprite_direction() == "down"`.
  - `test_patrol_walks_only_between_route_points`: rota de 3 pontos num quadrado de 160 px; após 600 quadros, o NPC passou
    a menos de `ARRIVE_DISTANCE` de cada ponto e nunca saiu do retângulo envolvente da rota crescido em 16 px.
  - `test_patrol_waits_when_blocked_and_moves_on`: um `StaticBody2D` no caminho do ponto 2 → depois de 400 quadros o
    NPC chegou ao ponto 3 e o corpo não se moveu.
  - `test_attacked_sitting_npc_stands_up_and_flees`: `take_damage(1, atacante)` → `activity == ""`, colisão ativa,
    `pose() == "stand"`, distância do atacante aumenta.
  - `test_post_npc_stays_put`: posição inalterada após 300 quadros.
- [ ] **Step 2:** falha. **Step 3:** implementar. **Step 4:** passa; suíte inteira `0 falha(s)`.

---

### Task 8: Cena do interior desenhando a planta

**Files:**
- Modify: `scripts/interior/interior.gd`
- Test: `tests/unit/test_scenes.gd`

**Interfaces:**
- Consumes: campos novos do `InteriorLayout` (Tarefa 2), `SpriteFactory.face` (Tarefa 3), `FurnitureArt.canvas(..., tone)`
  (Tarefa 4), propriedades do NPC (Tarefa 7).
- Produces:
  - Planejado: `_draw()` pinta `floor_rects` (em vez de `base_floor` + `rooms`); paredes = topo `shadow` com contorno
    `ink` (sem o bloco cinza); faces = `Sprite2D` repetido (`texture_repeat`) em `z_index = FLOOR_ITEM_Z`, grupo
    `wall_faces`; itens `layer "wall"` em `z_index = FLOOR_ITEM_Z + 1` (grupo `wall_items`), e quando `kind == "window"`
    o céu (`sky_color`) é pintado atrás pelo `_draw`; itens `layer "on"` em `z_index = SOLID_Z` adicionados depois dos
    móveis (grupo `on_items`); batente nos `doors`; capacho e porta de saída como hoje.
  - Legado: desenho atual inalterado (`window_rects()` só no legado).
  - NPCs: `npc.activity = slot.get("act", "")` (legado mantém `stationary = true` e `activity ""`), `npc.route`,
    `npc.facing`, `npc.uniform_building = layout.type`, `npc.uniform_staff = slot.staff`.
  - Sem colisão contra a face (só visual); o jogador passa por cima (z do ator é maior).

- [ ] **Step 1: Testes** em `test_scenes.gd`, com `Plans.override("bar", fixture)` e `GameState.set_inside(...)` como nos
  testes existentes:
  - `test_planned_interior_draws_faces_wall_items_and_on_items`: grupos `wall_faces`, `wall_items`, `on_items` não
    vazios; nenhum nó em `wall_faces` tem colisão.
  - `test_planned_interior_npcs_get_activity_and_building_uniform`: um NPC `sit` da fixture tem `pose() == "sit"`; um
    staff tem `uniform_building == "bar"`.
  - `test_legacy_interior_still_builds`: `armory` abre, tem `exit_doors` e nenhum nó em `wall_faces`.
- [ ] **Step 2:** falha. **Step 3:** implementar. **Step 4:** passa; suíte inteira `0 falha(s)`.

---

### Tasks 9 a 13: As cinco plantas

Cada uma cria `scripts/interior/plans/<tipo>.gd` (`static func data() -> Dictionary`), registra em `Plans`, e adiciona
seus testes em `tests/unit/test_plans.gd`. O desenho exato é do implementador, seguindo a spec §11/§12 e a escala §6;
toda planta tem pelo menos 2 variantes (`variants`) e alguns itens com `chance`. Depois de cada uma: rodar
`tools/probe.gd` (Tarefa 14 prepara a lista) ou abrir o jogo e **olhar a captura** antes de seguir.

Teste comum (uma vez, em `test_plans.gd`), para todo `type in Plans.types()` e ids `0..19`:
- `test_every_plan_validates`: `PlanParser.validate(Plans.data(type)) == []`.
- `test_every_plan_gives_a_valid_interior`: o `_check` de `test_interior_layout.gd` (copiar como função auxiliar) passa.
- `test_plans_are_unique`: as `object_grid` de tipos diferentes são diferentes.
- `test_beds_are_to_scale`: todo item `bed`, `hospital_bed`, `bunk` tem no máximo 48x80 px; `double_bed` no máximo 80x80.
- `test_variants_differ`: entre os 12 primeiros ids, pelo menos 3 assinaturas diferentes (espelho + variante + chance).

#### Task 9: Casa (`house`, P)

Cômodos (nomes exatos): `Sala`, `Cozinha`, `Quarto do casal`, `Quarto das crianças`, `Banheiro`. Piso/parede: taco
(`floor/wood`) com `floral` na sala e quartos, `floor/bath_tile` + `tile_blue` no banheiro, `floor/checker` +
`plaster_cream` na cozinha. Itens obrigatórios: `sofa`, `armchair`, `tv`, `round_table` ou `table` (jantar), `stove`,
`fridge`, `sink`, `double_bed`, `bed`, `nightstand`, `wardrobe`, `toilet`, `bathtub`, `rug`; brinquedos e itens `on`.
Gente: 2–3 `morador` (staff false): um idoso `sit` na poltrona, outro `work` na cozinha, um `patrol` opcional (`chance`).
Testes (`test_house_plan`): cômodos acima; itens obrigatórios; todos os `role == "morador"`; entre 2 e 3 pessoas;
`zones.size() == 0`. Atualizar `test_ordinary_home_has_all_four_rooms` em `test_phase6.gd` para os novos nomes.

#### Task 10: Casa do agente (`agent_home`, M)

Spec §12. Cômodos: `Sala`, `Escritório`, `Quarto`, `Cozinha`, `Banheiro`. Pisos/paredes: `floor/herringbone` +
`stripes_wine` (sala), `floor/carpet_navy` + `wood_panel` (escritório), `floor/carpet_cream` + `stripes_wine` (quarto),
`floor/checker` + `plaster_cream` (cozinha), `floor/bath_tile` + `tile_blue` (banheiro). Itens obrigatórios:
`sofa`, `armchair`, `rug`, `wall_tv`, `bookshelf`, `record_player`, `floor_lamp`, `fireplace`, `desk`, `office_chair`,
`monitor` (2), `case_wall`, `file_cabinet`, `chest`, `safe_wall`, `double_bed` (80x80), `nightstand` (2) com
`table_lamp`, `wardrobe`, `dresser`, `stove`, `fridge`, `sink`, `table` + `chair` (2), `coffee_pot`, `fruit_bowl`,
`bathtub`, `toilet`, `mirror`, `cat` (item `on` sobre o sofá, `chance 0.7`, sem colisão). Zonas: `stash` em frente ao baú, `rest` ao lado da cama. Sem NPCs.
Testes: atualizar `test_agent_home_interior_is_complete_and_has_no_strangers` (trocar `tv` por `wall_tv`, `computer`
por `monitor`, remover a dependência de fachada) e `test_agent_home_interior_is_fuller_than_the_old_home`
(mais de 30 itens contando `on` e `wall`); `test_pressing_interact_in_the_bedroom_zone_rests` continua passando.

#### Task 11: Bar (`bar`, M)

Spec §11 item 8. Cômodos: `Salão`, `Balcão`, `Sinuca`, `Banheiro`. `floor/wood_dark` + `brick`; banheiro
`floor/bath_tile` + `tile_blue`. Itens: `counter` longo com `beer_taps`, `bottle_wall`, `bar_stool` (≥ 4),
`round_table` + `chair`, `pool_table`, `dartboard`, `jukebox`, `toilet`, `sink`; `on`: `glass`, `bottle`, `ashtray`,
`pool_cue`. Gente: `bartender` staff `work` atrás do balcão; `atendente` staff `patrol` entre mesas; 2–3
`frequentador` `sit` nas banquetas; 2 `frequentador` `patrol` em volta da sinuca (rota de 4 pontos); 1 `frequentador`
`sit` numa mesa (`chance 0.6`). Zona `rumor` em frente ao bartender. Testes: itens obrigatórios; zona `rumor`; staff
com `uniform_for("bar", ...)` não vazio; os `test_guests_vary_and_have_roles` e `test_recognizable_furniture_by_type`
atuais continuam passando (manter `counter`, `stool` ou trocar a expectativa para `bar_stool`, `pool_table`).

#### Task 12: Delegacia (`police`, M)

Spec §11 item 2. Cômodos: `Recepção`, `Sala dos agentes`, `Celas`, `Interrogatório`, `Delegado`. Pisos/paredes:
`floor/linoleum_gray` + `navy_half` (recepção, agentes), `floor/concrete` + `plaster_gray` (celas, interrogatório),
`floor/wood` + `wood_panel` (delegado). Itens: `counter` alto, `bench` (≥ 2), `wanted_board`, `desk` (4) +
`office_chair` + `computer`, `coffee_machine`, `notice_board`, `cell_bars`, `bunk` (3), `toilet` (3),
`interrogation_table` + `chair` (2) + `mirror`, `desk` do delegado + `flag` + `bookshelf`, `file_cabinet`, `locker`.
Gente: `atendente` staff `post` no balcão; 2 `policial` staff `sit` nas mesas; 1 `policial` staff `patrol` mesa↔café;
`detetive` staff `sit` no interrogatório + 1 `preso` não-staff `sit` em frente; `delegado` staff `sit`; 1–3 `preso`
não-staff nas celas (`lie` no beliche ou `post`, por `chance`); 1 `visitante` `sit` no banco (`chance 0.7`).
Zona `deliver` em frente ao balcão. Testes: reescrever `test_police_station_is_a_complete_police_station` com os
cômodos e itens acima, `roles` contém `policial`, `delegado`, `preso`; e na cena, todo NPC staff exceto `detetive`
veste `shirt "blue"` (estende `test_interior_npcs_get_their_uniform`).

#### Task 13: Hospital (`hospital`, G)

Spec §11 item 3. Cômodos: `Recepção`, `Enfermaria`, `UTI`, `Consultório`, `Farmácia`. Pisos/paredes:
`floor/marble` + `tile_white_green` (recepção), `floor/linoleum_mint` + `tile_white_green` (enfermaria, UTI),
`floor/linoleum_white` + `tile_white_green` (consultório, farmácia). Itens: `counter` + `computer`, `chair` em
fileiras (≥ 8) ou `bench`, `water_cooler`, `hospital_bed` (6 na enfermaria, 2 na UTI) com `curtain`/`screen_divider`
e `nightstand`, `monitor` (2), `cart`, `desk` + `hospital_bed` (maca) + `cabinet` no consultório, `bottle_shelf` +
`counter` na farmácia, `sink`; parede: `clock`, `notice_board`, `poster`; `on`: `stethoscope_tray`, `papers`, `flowers`.
Gente: `recepcionista` staff `post`; `médica` staff `patrol` pelos leitos (rota ≥ 3 pontos); `enfermeiro` staff `patrol`;
`auxiliar de enfermagem` staff `patrol` com o carrinho; `farmacêutico` staff `post`; 3–5 `paciente` `lie` nos leitos
(`chance` por leito, mínimo 3 garantido por leitos sem `chance`); 2–3 `paciente`/`acompanhante` `sit` na espera.
Zona `heal` em frente à recepção. Testes: reescrever `test_hospital_is_a_complete_hospital` (cômodos e itens acima,
`size_class == "G"`, pelo menos 3 vagas `paciente` com `act "lie"`); na cena, todo staff tem `shirt "white"` e todo
`paciente` tem `shirt "ice"`.

Para cada uma das Tarefas 9 a 13:
- [ ] **Step 1:** escrever os testes da planta em `test_plans.gd` (e as atualizações listadas).
- [ ] **Step 2:** rodar `-- plans` → falha.
- [ ] **Step 3:** escrever a planta.
- [ ] **Step 4:** rodar `-- plans` e a suíte inteira → `0 falha(s)`.
- [ ] **Step 5:** capturar (`tools/probe.gd`, Tarefa 14) e **olhar a imagem**: escala, leitura dos cômodos, nada
  "solto"; corrigir antes de seguir.

---

### Task 14: Captura, ajustes de testes antigos e documentação

**Files:**
- Modify: `tools/probe.gd` (`INTERIOR_TYPES` passa a incluir `agent_home` e aceitar um filtro opcional de tipos;
  o ponto da câmera passa a ser o centro do interior para as plantas)
- Modify: `tests/unit/test_interior_layout.gd`, `tests/unit/test_phase6.gd` (o que ainda depender do modelo antigo
  para os 5 tipos)
- Create: `docs/redesign-fase-7.md`; Modify: `docs/README.md`, `docs/changelog.md`, `docs/gdd.md` (§4.4)

Ajustes conhecidos nos testes antigos (motivo: as 5 plantas deixaram de ser paramétricas):
- `test_size_follows_type_and_facade_width`: `bar` passa a ser sempre `"M"` (fachada não muda); trocar os exemplos
  de fachada para um tipo legado (`restaurant`).
- `test_every_building_type_has_a_template`: `BASE_SIZE`/`FLOORS` continuam para os legados; tipos planejados são
  aceitos por `Plans.has`.
- `test_every_interior_has_the_minimum_amount_of_people`: pular `InteriorLayout.is_planned(type)` (a gente da planta
  é definida nela e testada em `test_plans.gd`).
- `test_people_never_stand_inside_furniture_or_walls`: pular vagas `sit`/`lie`.
- `test_hotel_rooms_vary_with_the_seed`, `test_shops_*` etc.: inalterados (legados).

- [ ] **Step 1:** ajustar os testes antigos listados e rodar a suíte → `0 falha(s)`.
- [ ] **Step 2:** rodar `Godot... --path . -s tools/probe.gd -- fase7` e conferir as capturas
  `docs/img/fase7-interior-{agent_home,hospital,police,bar,house}.png`.
- [ ] **Step 3:** escrever `docs/redesign-fase-7.md` (o que entrou, formato da planta com exemplo curto, tabela de
  testes atualizados e motivo, capturas, o que fica para as Etapas 2 e 3); linhas no `README.md` e `changelog.md`;
  `gdd.md` §4.4 (tamanhos novos, plantas autorais).
- [ ] **Step 4:** suíte inteira final → citar `N testes, 0 falha(s)`; mostrar as 5 capturas ao usuário e pedir aprovação
  do estilo antes da Etapa 2.

---

## Fora desta etapa (Etapas 2 e 3, plano próprio após aprovação)

As outras 20 plantas (e a passagem secreta do QG com E), atividades `exercise` e `dance`, pisos e paredes restantes,
falas por papel, remoção do construtor legado.
