# Arquitetura

## Stack

- **Engine:** Godot 4.7.2 standard (sem .NET)
- **Linguagem:** GDScript
- **Renderer:** GL Compatibility, para manter exportação web e mobile viável
- **Resolução base:** 1280x720, stretch `canvas_items`, filtro de textura *nearest* (pixel art)

## Decisões

| Decisão | Motivo |
|---|---|
| GDScript, não C# | Godot 4 não exporta projetos C# para web |
| Rede via WebSocket/WebRTC (futuro) | Browsers não aceitam UDP, então ENet não funciona na web |
| Split screen via `SubViewport` (futuro) | Uma câmera por jogador no mesmo mundo |
| Input por ações `p{N}_*` | Permite vários jogadores locais, teclado e gamepad |
| Mapa com seed fixa | Todos os clientes geram o mesmo mundo |

## Pastas

```
scenes/            cenas
  main.tscn        mundo externo (Cidade + Campo)
  player/          jogador
  interior/        interior de prédio
  vehicle/         carro
  npc/             NPC
  combat/          projétil
scripts/
  main.gd          instancia o jogador no mundo
  autoload/        InputSetup, GameState, Score, DisplaySetup, WorldClock (singletons)
  player/          player.gd, player_profile.gd (ficha e atributos)
  interaction/     interact_zone.gd (zona "Pressione E")
  vehicle/         car.gd, traffic_route.gd
  combat/          bullet.gd
  npc/             npc.gd, npc_identity.gd (card de personalidade), population.gd (trabalho e moradia)
  ui/              hud.gd, pixel_label.gd, ui_style.gd, dialog_card.gd, inventory_panel.gd,
                   character_sheet.gd, shop_panel.gd
  items/           item_defs.gd, inventory.gd, pickup.gd, shop_defs.gd
  world/           world.gd, ground_chunk.gd (nós); city/country/world_layout.gd, sidewalk_graph.gd,
                   street_props_layout.gd, building_style.gd, district_layout.gd (bairros),
                   building_defs.gd (tipos de prédio), name_generator.gd, day_cycle.gd (lógica);
                   door.gd, light_layer.gd e light_chunk.gd (luzes)
  art/             fábrica de arte: palette, pixel_canvas, pixel_font, tile_factory, character_sprites,
                   car_sprites, prop_sprites, building_art, sprite_factory
  crime/           crime_profiles.gd, incident_manager.gd
  interior/        interior.gd (nós), interior_layout.gd (planta por tipo), services.gd (serviços)
tests/             run_tests.gd, base_test.gd, unit/test_*.gd
tools/             probe.gd (capturas e desempenho), sprite_sheet.gd (folha de sprites)
docs/              esta documentação
```

## Padrão layout x nós

Lógica de geração fica em classes `RefCounted` (`CityLayout`, `InteriorLayout`),
determinísticas por seed e testáveis sem cena. Os scripts de cena só montam nós a
partir delas. Siga esse padrão em sistemas novos.

## Arte gerada por código

Não há arquivos de imagem. `scripts/art/` monta sprites e tiles em `Image` (lógica pura, testável em
modo headless) e `SpriteFactory` guarda cada `ImageTexture` em cache por chave, inclusive entre trocas
de cena. Regras: só cores de `Palette`; 1 texel = 2 px do mundo; sprites pequenos são escritos como
texto (uma letra por texel) e recoloridos pela legenda.

- O chão é desenhado por `GroundChunk` (um nó por 560x560 px) com tiles repetidos; o motor descarta os
  pedaços fora da tela. Nada é redesenhado por quadro.
- Cada prédio é uma textura (`BuildingArt.render`), com estilo dado por `BuildingStyle`.
- Personagens e carros trocam de textura para animar; o carro usa 32 direções pré-geradas em vez de girar o sprite.
- Camadas (z): chão 0, itens 1, prédios 2, personagens e carros 3, projéteis 4, copas e postes 5.

## Navegação entre cenas

Autoload `GameState` guarda `building_id` e a posição de retorno. `Door` chama
`GameState.go_inside/go_outside`, que trocam de cena de forma adiada (`call_deferred`).
Grupos usados: `players`, `building_doors`, `exit_doors`, `vehicles`, `traffic`, `npcs`, `bullets`,
`buildings`, `ground_chunks`, `pickups`, `shop_zones`.

## Interação

Nada é acionado por simples toque. `InteractZone` (Area2D) registra-se no jogador;
o jogador mostra a instrução no HUD e só chama `interact()` quando a ação
`p{N}_interact` é pressionada. Portas e carros usam o mesmo mecanismo.

## Dados do jogador

`GameState.profile_for(n)` e `inventory_for(n)` guardam a ficha e o inventário de cada jogador. O nó
`Player` é recriado a cada troca de cena e só os referencia. `reset_players()` zera tudo (novo jogo, testes;
o runner chama antes de cada teste).

## Cidade, calçadas e crimes

- `CityLayout` monta as ruas (largura por linha: `asphalt(linha)`, `corridor(linha)`; a linha 6 de cada eixo é avenida),
  sorteia o formato de cada lote conforme o bairro e chama `BuildingDefs.assign` para dar tipo, loja e nome aos prédios.
- `DistrictLayout`: seis bairros por seed, contíguos, um por quarteirão. `BuildingDefs`: tabela única dos tipos de prédio.
  `NameGenerator`: nomes de prédios e ruas. `Population`: trabalho e moradia de cada civil.
- `SidewalkGraph`: grafo de calçadas (nó = `Vector4i(cx, cy, qx, qy)`), usado pelos pedestres (`NPC.start_on_sidewalk`).
- `CrimeProfiles` guarda os tipos de crime por região; `IncidentManager` (filho de `World`) cria crimes perto do jogador
  conforme a região e o bairro, em frente a um prédio compatível com o tipo do crime, e paga o bônus quando são resolvidos.
- Lojas: `ShopDefs` (lógica pura de compra e venda) + `ShopPanel` (UI) + balcão no interior (`GameState.building_shop`).

## Interiores, serviços e dia e noite

- `InteriorLayout.new(id, tipo, largura_da_fachada)`: planta por tipo (15 modelos), móveis, vagas de NPC e zonas
  de serviço; `unreachable()` valida os caminhos. `interior.gd` só monta os nós.
- `Services.use(id, ator, mundo)`: lógica pura de cada serviço; a zona do interior só chama quando o jogador aperta E.
- `DayCycle` (lógica pura) + `WorldClock` (autoload, só acumula o tempo). Tudo que depende da hora (cor ambiente,
  luzes, horário das portas, população, crimes) pergunta ao `DayCycle`.
- Luzes: `CanvasModulate` tinge o mundo; as luzes ficam em uma `CanvasLayer` própria (`LightLayer`) com brilho aditivo.

## Mundo

`WorldLayout` = `CityLayout` + `CountryLayout` (regiões lado a lado, 13440x6720 px).
`world.gd` cria os nós e atualiza `player.region_name` e `player.place_name` (bairro e rua) para o HUD.

## Input

`InputSetup` (autoload) registra em runtime, por jogador N, as ações
`pN_up/down/left/right`, `pN_interact`, `pN_talk`, `pN_use_left`, `pN_use_right`, `pN_inventory`, `pN_character`:

- Jogador 1: WASD, E, F, I, C, mouse (mira e botões) e gamepad 0
- Jogador 2: setas, Enter, Num. e gamepad 1

Tabela completa em [prototipo-05-mira-inventario-ficha.md](prototipo-05-mira-inventario-ficha.md).

Cada ação aceita tecla, D-pad e analógico esquerdo do gamepad do jogador.
