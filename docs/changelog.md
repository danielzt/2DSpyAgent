# Changelog

## 2026-11-16 (2)

- Correção: ao entrar num prédio e sair, o mundo externo era recriado do zero (o carro deixado na porta sumia,
  bandidos e NPCs voltavam ao início). Agora a cena da rua é guardada fora da árvore enquanto o jogador está
  dentro e volta igual ao sair (ver "Mundo persistente" em [arquitetura.md](arquitetura.md))
- Correção: nos menus (título e pausa) as setas pareciam invertidas: uma seta disparava `p2_down` e `ui_down` e o
  menu andava duas casas (num menu de 3 itens, +2 = -1). Agora anda no máximo uma casa por quadro, e Enter escolhe uma vez
- 937 testes
## 2026-11-16

- Fase 7, Etapa 2: plantas próprias para os 20 tipos que faltavam (banco, hotel, restaurante, lanchonete, boate,
  as 6 lojas, oficina, academia, cinema, escritório, redação, apartamento, casa de fazenda, armazém e QG);
  construtor antigo de interiores removido
- Lojas com balcão, vendedor e zona de compra vindos da planta; dançarinos na boate e alunos se exercitando
- QG: a passagem secreta da lavanderia só abre com E e a sala fica escura até lá
- 8 pisos, 8 paredes e cerca de 35 móveis e itens novos; novos funcionários (garçom, camareira, bilheteiro, editor...)
- Rondas validadas para não atravessar móveis; ninguém senta no ar; quem se exercita no chão ocupa espaço
- 933 testes. Detalhes: [redesign-fase-7.md](redesign-fase-7.md)

## 2026-11-15 (6)

- Fase 7, Etapa 1 (interiores caprichados): plantas autorais em mapa de texto (`PlanParser`, `Plans`) do tamanho da
  tela ou pouco maiores; móveis na escala do personagem; paredes com face visível e itens de parede; 9 pisos e 9
  estilos de parede; ~45 móveis e itens novos; uniforme pelo prédio (hospital de branco, delegacia de azul) com
  chapéus e detalhes; NPCs com atividade (posto, ronda, sentado, deitado, trabalhando) e poses novas
- Plantas novas: casa, casa do agente, bar, delegacia e hospital. Os outros tipos seguem no modelo antigo até a Etapa 2
- 901 testes. Detalhes: [redesign-fase-7.md](redesign-fase-7.md)

## 2026-11-15 (5)

- Fase 6 do redesenho: mapa com neblina no que não foi explorado; pontos marcados por clique no mapa (até 5) com seta e distância no HUD; bairro residencial com lotes de casinhas em duas fileiras e beco; **casa do agente** (a casa mais perto do QG, já marcada, com dormir de graça e baú); hospital, delegacia e casas completos; decoração e gente mínima em todos os interiores; uniformes por papel; 13 móveis novos
- Ruas estreitas (100 px) nos bairros de casas e **rota pelas ruas** até o ponto marcado, com trilha pontilhada no HUD
- Pendente da fase: ruas com curvas (6.3), só estudo
- 848 testes. Detalhes: [redesign-fase-6.md](redesign-fase-6.md)

## 2026-11-15 (4)

- Fase 5 do redesenho: efeitos (clarão e cápsula do tiro, faíscas, poeira, marcas de pneu, tremor de câmera desligável), transição em íris ao entrar e sair de prédios (autoload `Transition`), mapa de tela cheia (M) e minimapa no HUD com ícone por tipo de prédio visitado ou visto, tela de título com a cidade à noite e tela de pausa (Esc) com mapa e controles
- Teste de regras de arte: nenhum `ColorRect` nem cor fora da paleta nos scripts e cenas
- Runner de testes agora mostra só os problemas por padrão (`-- verbose` lista tudo)
- 781 testes (97 novos). Detalhes: [redesign-fase-5.md](redesign-fase-5.md)
- Roteiro: nova **Fase 6** (casas e bairro residencial, ruas estreitas e curvas, casa do agente, mapa com pontos e direção no HUD, interiores completos como hospital e delegacia)

## 2026-11-15 (3)

- Dia do mundo reduzido de 24 para 12 min reais (`DayCycle.DAY_SECONDS = 720`; 1 hora de jogo = 30 s). Testes do relógio ajustados

## 2026-11-15 (2)

- Fase 3 do redesenho: interior paramétrico por tipo de prédio (15 modelos, 3 tamanhos, cômodos, paredes internas, móveis reconhecíveis, NPCs com papel), validado por preenchimento em grade
- 13 serviços com efeito real (dormir, refeição, hospital, entregar presos, banco, rumores, informante, briefing, pintar o carro, cinema, academia); mercado e posto passam a vender comida (`snack`)
- Mecânicas da D7 (assumidas como "sim"): perder metade do dinheiro ao ser derrotado e acordar no hospital, presos a entregar, item de comida e seta de alvo no HUD; a vida passa a ser guardada entre cenas
- Fase 4: relógio do mundo (autoload `WorldClock`, 12 min por dia), hora no HUD, tinta ambiente com piso de luminosidade, camada de luz aditiva (postes, janelas, letreiros, vitrines, faróis, halo do jogador), interiores sempre claros com janelas que mostram o céu
- Prédios fecham fora do horário ("Fechado — abre às 09:00"); de noite há menos pedestres (que vão para casa) e menos carros; crimes mais frequentes e com pesos noturnos; assalto a banco só com o banco aberto
- 684 testes (107 novos); testes atualizados por mudança intencional estão em [redesign-fase-3.md](redesign-fase-3.md)
- Desempenho: de dia +9% sobre a linha de base; de noite +27%, acima da meta de 20% (detalhes em [redesign-fase-4.md](redesign-fase-4.md))
- Detalhes: [redesign-fase-3.md](redesign-fase-3.md) e [redesign-fase-4.md](redesign-fase-4.md)

## 2026-11-15

- Testes: suíte passou de ~182 s para ~23 s usando `--fixed-fps 60` (sem sincronizar com o relógio); runner avisa testes acima de 500 ms

- Fase 2 do redesenho, cidade com contexto: duas avenidas mais largas cruzando no centro (duas faixas por sentido), seis bairros por seed com paredes, telhados, alturas e formatos de lote próprios
- Tabela única de 24 tipos de prédio em `building_defs.gd` (cotas, tamanho mínimo, letreiro, funcionários, horário, serviço); as lojas viraram entradas da tabela com o mesmo estoque; novo tipo "redação do jornal"
- Nome próprio por prédio (letreiro e instrução da porta), ruas e bairros com nome, "bairro • rua" no HUD
- NPCs com trabalho e moradia em prédios reais, citados na conversa
- Crimes por bairro e por tipo de prédio; três crimes novos (assalto a banco, briga de bar, arrombamento); o aviso cita o prédio
- Correção: erro `Invalid type in function 'take_damage'` quando um criminoso morria com o tiro ainda no ar
- Runner de testes com filtro opcional por arquivo; projeto passou a usar git
- Desempenho: 1,73 ms para 1,81 ms por quadro nos mesmos pontos (+5%)
- 577 testes (90 novos); 7 testes atualizados por mudança intencional, listados em [redesign-fase-2.md](redesign-fase-2.md)
- Detalhes: [redesign-fase-2.md](redesign-fase-2.md)

## 2026-11-14 (9)

- Plano do jogo completo em [roteiro-jogo.md](roteiro-jogo.md): 12 etapas (menu, save, split-screen até 4, corpo a corpo, percepção, quests, conversa com retrato, campanha, mapas aleatórios, co-op online, áudio, acabamento) e decisões em aberto
- Proposta de história em [historia.md](historia.md): campanha de 12 horas em 5 atos, rodando em qualquer mapa procedural por âncoras de papel
- História aprovada e decisões J2 a J14 registradas: procedural sempre, modos Campanha e Livre, save automático sem slots, criminosos à paisana, co-op com agentes temporários e itens compartilhados (desktop 4, browser 2, mobile 1), áudio por código, português e inglês
- `gdd.md` atualizado com a campanha, os modos de jogo e o co-op
- Plano de armas em [armas-e-inventario.md](armas-e-inventario.md): 15 armas, munição limitada em 6 tipos, barra de itens no lugar de mão esquerda/direita, menu único com abas
- Decididos: botão direito como ação secundária, recarga em R, ruído dos tiros, inventário de 16 espaços com baú, cinco atributos com teto de 5, co-op com jogadores independentes
- Só documentação; nenhum código alterado, suíte não executada

## 2026-11-14 (8)

- Decisões da Fase 2 do redesenho registradas: avenidas mais largas de verdade (D6) e lista de prédios sem corte, mantendo cinema, academia e posto (D3)
- Fase 2 aprovada, ainda não iniciada; D7 (mecânicas novas dos serviços) segue em aberto para a Fase 3
- Só documentação: [redesign-roteiro.md](redesign-roteiro.md) e [redesign-visual.md](redesign-visual.md)

## 2026-11-14 (7)

- Fase 1 do redesenho: todo o mundo externo em pixel art gerada por código (paleta de 32 cores, texel de 2 px)
- Fábrica de arte em `scripts/art/`: paleta, tela de pixel, fonte própria, tiles, personagens, carros, objetos, prédios e cache de texturas
- Chão em 288 pedaços (`ground_chunk.gd`); prédios com telhado, fachada, janelas, porta, toldo e letreiro em uma textura cada
- Mobiliário urbano por seed (`street_props_layout.gd`): postes, semáforos, hidrantes, lixeiras, pontos de ônibus, bancas, árvores de calçada, bueiros; parques com caminhos e lago; quintais gramados
- Personagens com 4 direções e animação de passo; jogador, civis e criminosos com silhuetas próprias; 7 modelos de carro em 32 direções
- Carros dirigíveis passam a ser o esportivo da agência; `car.color` virou `car.model` e `car.tone`
- HUD em placas com fonte pixel e barra de vida; espaços reservados para bairro/rua e relógio; moldura retrô nos painéis
- Ferramentas `tools/probe.gd` (capturas e desempenho) e `tools/sprite_sheet.gd` (folha de sprites)
- Desempenho: tempo de quadro de 6,5 ms para cerca de 2 ms; chamadas de desenho de ~935 para ~160
- 487 testes (102 novos), nenhum teste existente alterado
- Detalhes: [redesign-fase-1.md](redesign-fase-1.md)

## 2026-11-14 (6)

- Fase 0 do redesenho: design completo em [redesign-visual.md](redesign-visual.md) (paleta de 32 cores, resolução, fábrica de arte por código, 6 bairros, 23 tipos de prédio, 15 modelos de interior, serviços, dia e noite, impacto nos testes). Proposta aguardando aprovação
- Amostra da paleta em `docs/img/paleta.png` (dia, entardecer e noite); `docs/img/.gdignore` para o Godot não importar as imagens
- Corrigido o tamanho do mundo citado no `gdd.md` e no `arquitetura.md` (13440x6720 px, não 12480x5760)
- Só documentação; nenhum código alterado, suíte não executada

## 2026-11-14 (5)

- Planejamento do redesenho visual e do mundo com contexto (bairros, tipos de prédio, interiores com finalidade, dia e noite), em 6 fases com status por item. Só documentação; nenhum código alterado
- Detalhes: [redesign-roteiro.md](redesign-roteiro.md)

## 2026-11-14 (4)

- Ruas com calçadas e faixas de pedestres; pedestres andam pelas calçadas e atravessam nas faixas
- População: 110 pedestres na cidade (antes 40), 12 civis no campo
- Prédios menos simétricos: lotes com formatos sorteados, parques, quintais, portas em posições variadas, detalhes no telhado
- Mundo maior: 13440 x 6720 px (quarteirão 560 px)
- Itens no chão (dinheiro e itens); criminais mortos largam loot
- Dinheiro e lojas (Armaria, Farmácia, Loja do Agente, Armazém Rural) com interior, balcão, compra e venda
- Crimes dependem da região (Cidade e Campo têm tipos, frequência e recompensas próprios) com aviso na tela
- 385 testes
- Detalhes: [prototipo-06-cidade-lojas-crimes.md](prototipo-06-cidade-lojas-crimes.md)

## 2026-11-14 (3)

- Carro mais lento (340 px/s) e chute de colisão mais forte; trânsito agora fica na faixa da direita
- Janela se adapta à tela (stretch expand, 85% da tela, F11 tela cheia)
- Mira com o mouse; WASD só move; botão esquerdo = mão esquerda, direito = mão direita
- NPCs com nome e card de personalidade; F conversa, card com perguntas (nome só no aviso e no card)
- Inventário (I) com pistola, escopeta, taser, kit médico e escudo; mãos esquerda/direita
- Ficha do jogador (C): nome, características, XP, nível e 4 atributos com efeito real
- Taser (não letal, pontua), escudo, kit médico; XP por mortes, atordoamentos e conversas
- `p{N}_fire` virou `p{N}_use_left` / `p{N}_use_right`; novas ações talk, inventory, character
- 288 testes
- Detalhes: [prototipo-05-mira-inventario-ficha.md](prototipo-05-mira-inventario-ficha.md)

## 2026-11-14 (2)

- Carro: colisão com chute (não trava mais) e auxílio de direção para andar reto
- Combate: tiro (Espaço), projéteis, vida do jogador (10) com respawn
- NPCs: inocentes (fogem) e criminosos (atiram); matar inocente -100, criminoso +50; atropelamento conta
- 10 carros de trânsito com IA (faixa da direita, freiam para pessoas, não podem ser roubados)
- 171 testes
- GDD: nova direção "meio espião, meio polícia" (scanner, crimes dinâmicos, NPCs com nome e personalidade)
- Detalhes: [prototipo-04-combate-npcs-transito.md](prototipo-04-combate-npcs-transito.md)

## 2026-11-14

- Entrar/sair de prédios e carros só com a tecla E; instrução no canto da tela
- Carro dirigível (E para entrar e sair), 8 carros no mundo
- Pontuação: matar inocente tira pontos (ainda sem combate); HUD por jogador
- Mundo 3,7x maior com duas regiões: Cidade (12x12 quarteirões) e Campo (fazendas, plantações, árvores)
- `city.gd` substituído por `world.gd`; novos `CountryLayout` e `WorldLayout`
- 100 testes; README e AGENTS reforçados sobre testes
- GDD atualizado (tom de paródia de espionagem, armas letais, regra de pontos)
- Detalhes: [prototipo-03-mundo-e-carro.md](prototipo-03-mundo-e-carro.md)

## 2026-11-13 (2)

- Runner de testes próprio e 45 testes (ver [testes.md](testes.md))
- Prédios maiores (quarteirão 480 px), spawn inicial corrigido
- Portas e interiores em cena própria, com escala diferente da fachada
  ([prototipo-02-interiores.md](prototipo-02-interiores.md))
- Autoload `GameState`; `CityLayout` e `InteriorLayout` separados dos nós
- GDD inicial ([gdd.md](gdd.md)): tema de agente secreto contra o crime
- Análise de mundos grandes/infinitos ([mundo-grande.md](mundo-grande.md))

## 2026-11-13

- Criado o projeto Godot 4.7.2 (GL Compatibility, 1280x720)
- Protótipo 01: cidade de teste, jogador top-down com câmera, input por jogador
  (teclado e gamepad) — ver [prototipo-01.md](prototipo-01.md)
- Criados `README.md`, `AGENTS.md`, `.gitignore` e a pasta `docs/`
