# Interiores caprichados — Etapa 2 (as outras 20 plantas) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Dar planta autoral (mapa de texto) aos 20 tipos de prédio que ainda usam o construtor antigo, em quatro blocos,
e remover o construtor antigo no fim.

**Architecture:** O mesmo motor da Etapa 1 (`PlanParser`, `Plans`, `InteriorLayout` planejado, `interior.gd`). Esta etapa
acrescenta: lojas planejadas (balcão de loja, vendedor e zona de compra derivados da planta), atividades `exercise` e
`dance`, a passagem secreta do QG com E, a arte que faltar e, ao final, a remoção do caminho legado.

**Tech Stack:** Godot 4.7.2, GDScript, runner `tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-11-15-interiores-caprichados-design.md` (§8, §9, §11 por tipo).
Etapa anterior: `docs/superpowers/plans/2026-11-15-interiores-caprichados-etapa-1.md`, `docs/redesign-fase-7.md`.

## Global Constraints

As mesmas da Etapa 1 (paleta, `SpriteFactory`, escala §6, grade de 32 px, tamanhos P/M/G, `FACE_H` 24 px, suíte inteira
com `0 falha(s)` ao fim de cada tarefa, documentação na mesma mudança). Autoria das grades pelo gerador fora do repositório
(`.superpowers/sdd/.../gen.py`); os `.gd` gerados são a fonte da verdade.

Tamanhos por tipo (spec §11): P = armaria, farmácia, loja do agente, mercado, posto, armazém rural, lanchonete,
apartamento, casa de fazenda; M = banco, restaurante, oficina, academia, escritório, redação; G = hotel, boate, cinema,
armazém, QG.

## Review Focus

1. Loja planejada: a zona de compra fica exatamente sob o balcão, o vendedor é a primeira vaga e fica atrás do balcão,
   nenhum móvel na zona (mesmas garantias de `test_shops_keep_counter_merchant_and_buy_zone`).
2. QG: a passagem secreta só abre com E; a sala escondida não aparece antes; reentrar começa fechada.
3. Dançarinos e alunos (`dance`, `exercise`) não andam e não empurram o jogador.
4. Remoção do legado: nenhum tipo de `BuildingDefs.ORDER` (nem `agent_home`) fica sem planta; tipo desconhecido cai numa
   planta padrão (casa) em vez de quebrar.
5. Todas as plantas: alcance (`unreachable()`), sem sobreposição, escala de camas, variações (≥ 3 em 12 ids).

---

### Task 1: Lojas planejadas e atividades `exercise`/`dance`

**Files:** `scripts/interior/plan_parser.gd`, `scripts/interior/interior_layout.gd`, `scripts/art/character_sprites.gd`,
`scripts/npc/npc.gd`; testes `test_plan_parser.gd`, `test_interior_layout.gd`, `test_sprites.gd`, `test_npc.gd`.

**Interfaces:**
- Legenda de objeto aceita `"shop_counter": true` num item `counter` (no máximo um por planta; `validate()` acusa dois).
  `parse()` devolve `counter: Rect2` (vazio se não houver).
- `InteriorLayout` planejado e `is_shop`: `counter = parsed.counter`; acrescenta a zona `{"id": "shop", "rect": counter_zone()}`;
  insere na posição 0 de `npc_slots` o vendedor `{role: BuildingDefs.staff_of(type)[0], position: merchant_position(),
  staff: true, act: "post", facing: "down"}`. `validate()` + teste garantem que a célula do vendedor e a zona estão livres.
- Poses `exercise` (quadros 1 e 2: braços para cima e para baixo) e `dance` (quadros 1 e 2: corpo inclinado para os lados),
  em `CharacterSprites.POSES`; `npc.gd` trata `exercise` e `dance` como `work` (parados, animados, com colisão).
- Testes: planta de loja de fixture passa nas mesmas asserções de `test_shops_keep_counter_merchant_and_buy_zone`;
  dois `shop_counter` → erro; poses novas diferentes de `stand` e animadas; NPC `dance` não sai do lugar em 300 quadros.

### Task 2: Bloco 1 — banco, hotel, restaurante, lanchonete, boate

Para cada tipo: testes em `test_plans.gd` (cômodos com nome, itens característicos, papéis e uniformes, zonas de serviço de
`Services.for_type`), planta gerada, registro em `Plans`, captura com `tools/probe.gd -- fase7 12 so-interiores <tipos>`
e ajuste olhando a imagem. Arte nova que faltar (ex.: guichê com vidro, porta redonda de cofre, colunas, cordão, carrinho
de malas, carrinho de limpeza, frigobar, toalha xadrez, vela, cabine de lanchonete, chapa, máquina de milkshake, neon,
pista com luz, cabine de DJ elevada) entra em `furniture_art_7.gd` com teste em `test_interior_layout.gd`.
- Banco (M): hall, guichês, fila, gerente, cofre; zonas `deposit` e `withdraw`.
- Hotel (G): saguão, corredor, 3 quartos; zona `sleep`; camareira em ronda, hóspede deitado.
- Restaurante (M): salão, cozinha aberta, adega; zona `meal`; garçom em ronda, chef e ajudante `work`.
- Lanchonete (P): balcão com banquetas, cabines, chapa; zona `snack`.
- Boate (G): pista (`dance`), DJ, bar, VIP, camarote do informante; zona `informant`.
Atualizar testes antigos que usavam esses tipos como exemplo legado (motivo registrado em `docs/redesign-fase-7.md`).

### Task 3: Bloco 2 — as 6 lojas

Armaria (estande de tiro), farmácia (gôndolas brancas, cruz verde), loja do agente (vitrines de gadgets, manequim), mercado
(corredores, freezers, caixas com esteira), posto (conveniência), armazém rural (sacos de ração, ferramentas). Cada uma com
`shop_counter`, plantas e itens próprios (nenhuma igual à outra), clientes com atividade. `test_shops_keep_counter_merchant_and_buy_zone`
e `test_pickups_and_shops` continuam passando.

### Task 4: Bloco 3 — oficina, academia, cinema, escritório, redação

Oficina (elevador com carro, mecânico `lie` sob o carro; zona `paint`), academia (`exercise`; zona `train`), cinema (sala escura,
poltronas, lanterninha em ronda; zona `movie`), escritório (baias, sala de reunião, copa), redação (mesas juntas, sala escura
de foto, sala do editor).

### Task 5: Bloco 4 — apartamento, casa de fazenda, armazém, QG

Apartamento e casa de fazenda (moradores), armazém (estantes altas, empilhadeira, doca). QG: lavanderia na frente; a máquina
secreta vira `InteractZone` ("entrar no QG"); a sala do QG fica coberta por sombra até a passagem ser aberta naquela visita
(estado na cena, não em `GameState`); zona `briefing`. Testes: E abre; antes de abrir, a parede da passagem é sólida e a sombra
existe; após abrir, o caminho até `briefing` existe.

### Task 6: Remoção do construtor legado e documentação

Remover de `interior_layout.gd` os construtores por modelo, `_dress`, `_fill_to_minimum`, `DECOR`, `SIZES` antigos e o que
só eles usam; tipo sem planta usa a planta `house`. Atualizar/remover os testes que só verificavam o legado (cada um com motivo
em `docs/redesign-fase-7.md`). Atualizar `docs/redesign-fase-7.md` (Etapa 2, capturas `fase7-interior-*.png` de todos os
tipos), `README.md`, `changelog.md`, `gdd.md`, `arquitetura.md`. Suíte inteira `0 falha(s)`.
