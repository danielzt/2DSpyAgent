# Fase 5 — Acabamento

Efeitos de combate e de carro, transição ao entrar em prédios, mapa e minimapa, tela de título,
tela de pausa e uma varredura automática das regras de arte. Roteiro: `docs/redesign-roteiro.md`
(itens 5.1 a 5.11); especificação: `docs/redesign-visual.md`, seção 9.

## Efeitos (5.1 a 5.5)

Só enfeite: nenhum deles muda o jogo. Código em `scripts/effects/`, sprites em
`scripts/art/fx_sprites.gd` (pixel art por código, `SpriteFactory.fx(id)` com cache).

| Efeito | Quando | Como |
|---|---|---|
| Clarão do tiro | Todo tiro do jogador e dos criminosos | Dois quadros na ponta da arma (o grande e depois o menor), cada um dura 2 quadros do jogo |
| Cápsula | Tiro do jogador | Sai para o lado, desacelera e some em 2 s |
| Faíscas | Tiro em parede ou carro | 4 a 6 faíscas voltando contra a direção do tiro, 0,25 s |
| Poeira de impacto | Tiro que acaba o alcance | 3 nuvens de poeira que se espalham |
| Poeira do carro | Carro acima de 90 px/s na terra (campo fora da estrada) | Nuvem atrás das rodas a cada 0,07 s |
| Marcas de pneu | Carro do jogador freando forte (acima de 150) ou em curva forte (acima de 220) no asfalto | Duas marcas por quadro de espaçamento de 10 px; guarda até 200 e as mais antigas somem; `TireMarks` no mundo |
| Tremor de câmera | Escopeta, dano ao jogador e batida de carro (acima de 120) | 2 a 4 px por 0,15 s no `Camera2D.offset`; desligável (`GameState.screen_shake`, opção na pausa) |

- `Fx` (estático) cria as partículas; `Particle` (`Sprite2D`) anda, perde velocidade, cresce e esmaece.
- Teto de 160 partículas ao mesmo tempo; o sorteio usa seed fixa (mesmo tiro, mesmo desenho).
- Só o carro do jogador deixa marcas; o trânsito não.

## Transição em íris (5.6)

`Transition` (autoload, camada 100): ao entrar ou sair de um prédio e ao começar o jogo, a tela fecha
em círculo em 0,25 s, a cena troca e abre em 0,25 s. O círculo é desenhado em faixas de 8 px
(degraus de pixel) com a cor tinta; `iris_rects()` é função pura.

- `GameState.go_inside`, `go_outside`, `go_to_title` e `start_game` passam por ela. O estado do jogo só
  muda **com a íris fechada** (o `before` roda antes da troca), e um pedido novo é ignorado enquanto
  uma transição corre.
- Testes que dependem da troca esperam `Transition.DURATION` (ver `test_scenes.gd`); o runner chama
  `Transition.reset()` entre os testes.

## Mapa e minimapa (5.7)

- **Prédio conhecido:** visitado (entrou) ou visto de perto (até 380 px da parede, conferido a cada
  0,5 s pelo mundo). Fica em `PlayerProfile.known_buildings`. Só prédios conhecidos ganham ícone.
- **Ícones:** `MapIcons`, 18 glifos 7x7 sobre placa 9x9; vários tipos dividem um glifo (restaurante e
  lanchonete, casa e apartamento, loja de agente, mercado e loja rural...). Mais o marcador do jogador
  e o de crime.
- **Desenho comum:** `MapView.draw` pinta bairros (cor por bairro, as ruas são os vãos), prédios, o campo e
  os ícones; usado pelo minimapa, pelo mapa e pela pausa.
- **Minimapa:** no canto superior direito do HUD, 200 px, janela de 1 quarteirão e meio de raio em volta do
  jogador, com alvos de crime (presos à borda quando fora da janela). Escondido dentro de prédios.
  Redesenha a cada 0,2 s ou 6 px andados.
- **Mapa de tela cheia (M; Num5 no jogador 2):** cidade ou campo (a tecla de interagir alterna; abre na
  região do jogador), bairros com nome, ruas com nome (horizontais à esquerda, verticais no alto em 4
  fileiras), legenda, jogador piscando, alvos e o nome do lugar ao passar o mouse sobre um ícone. Só na
  rua (dentro de prédios mostra um aviso).
- Novas ações: `p{N}_map` (M, Num5; ombro esquerdo do gamepad) e `p{N}_pause` (Esc, Num+; Guide).

## Título e pausa (5.8 e 5.9)

- **Título** (`scenes/title/title.tscn`, agora a cena inicial): a cidade à noite em pixel art por código
  (`TitleArt`: céu em degraus, estrelas, lua, duas camadas de prédios com janelas acesas, letreiros de
  néon, avenida), o nome do jogo e o menu Novo jogo, Controles e Sair (sem Sair no navegador).
  Novo jogo chama `GameState.start_game()`, que zera a partida.
- **Pausa** (Esc): congela o jogo (`SceneTree.paused`) e mostra o mapa, os controles (lidos das ações
  reais, em `ControlsText`) e o menu Continuar, Tremor de câmera (SIM/NÃO) e Voltar ao título. O jogo
  volta dois quadros depois de fechar a pausa, para a tecla não virar uma ação do jogador. Esc fecha
  primeiro os painéis abertos (inventário, ficha, mapa) e só depois abre a pausa.
- `PixelMenu`: menu vertical em fonte pixel, navegado com as ações dos jogadores (cima, baixo, interagir)
  ou com o mouse.

## Regras de arte (5.10)

`test_art_rules.gd` varre `scripts/` e `scenes/`: nenhum `ColorRect`, `Polygon2D` ou `Line2D`, e nenhuma
cor solta (`Color("...")`, `Color8`, `Color(0x...)`, `Color(r, g, b)`) fora de `palette.gd` e
`day_cycle.gd` (tinta do ambiente). Saiu a cor solta `color` do jogador, que não era usada.

## Testes

781 testes, 0 falhas (97 novos em `test_effects`, `test_transition`, `test_map`, `test_pause_title` e
`test_art_rules`). O runner agora mostra só os problemas por padrão (`-- verbose` lista tudo).
Mudança intencional em testes existentes: os de `test_scenes.gd` que entram e saem de prédios esperam a
íris fechar.

## Capturas

`docs/img/fase5-*.png`: título, controles, tiro, faíscas, pneus, íris, minimapa, mapa e pausa
(`tools/probe_ui.gd`). O mapa e o minimapa mostram os prédios "vistos" ao percorrer a avenida.

## Desempenho

Mesmos 6 pontos fixos das fases anteriores (`tools/probe.gd`, sem interiores), tempo médio de quadro:

| Momento | Antes da Fase 1 | Fase 4 (dia) | Fase 4 (noite) | Fase 5 (dia, 12:00) | Fase 5 (noite, 23:00) |
|---|---|---|---|---|---|
| Média dos 6 pontos | 1,725 ms | 1,886 ms | 2,189 ms | 2,151 ms | 2,282 ms |

- **Minimapa:** ligar e desligar no mesmo ponto mudou a média de 2,152 ms para 2,177 ms (cerca de 1%).
  Os efeitos só custam enquanto existem (teto de 160 partículas).
- **Atenção:** a linha de base e a Fase 4 foram medidas em outra sessão; a Fase 5 aparece mais alta (+14% de dia, +4% de
  noite sobre a Fase 4) mas o minimapa explica só 1%, e não remedi a Fase 4 hoje, então parte da diferença pode ser a
  máquina. Sobre a linha de base original a conta dá +25% de dia e +32% de noite, **acima da meta de 20%**.
  Falta medir no export web. O primeiro candidato a otimizar continua sendo a camada de luz noturna (ver `redesign-fase-4.md`).
- Os 13 pontos de dia ficam entre 2,0 e 2,3 ms (cerca de 460 fps); 142 a 236 chamadas de desenho.
