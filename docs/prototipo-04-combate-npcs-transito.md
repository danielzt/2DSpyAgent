# Protótipo 04: carro melhorado, combate, NPCs e trânsito

## Carro: colisão com "chute" e auxílio de direção

- **Chute na batida** (`Car.collision_response`): em vez de travar, o carro perde parte da velocidade
  conforme o impacto (de frente: 60%; raspando: pouco), é empurrado para longe da parede (`knock`,
  que decai rápido) e gira rumo à direção da parede. Batida de frente quica e libera a direção;
  batida diagonal desliza ao longo da parede.
- **Auxílio de direção** (`Car.assist_turn`): sem apertar esquerda/direita e acima de 60 px/s, o carro se
  alinha suavemente à direção cardeal (cima, baixo, esquerda, direita) mais próxima, se já estiver a
  menos de ~12° dela. Diagonais não são alteradas; virar desliga o auxílio.
- Atropelamento: acima de 150 px/s o carro mata o NPC que atingir (ver pontuação).

## Combate

- (Atualizado no protótipo 05: o tiro agora é a arma da mão esquerda, botão esquerdo do mouse, mirando no
  cursor. Ver [prototipo-05-mira-inventario-ficha.md](prototipo-05-mira-inventario-ficha.md).)
- `Bullet` (`scripts/combat/bullet.gd`): 900 px/s, 0,7 s de vida, dano 1. Fere o primeiro corpo do
  grupo-alvo (`npcs` para tiros do jogador, `players` para tiros de criminosos); some em paredes e
  carros; atravessa personagens que não são alvo. Tiro de criminoso em carro com motorista fere o motorista.
- Jogador: 10 de vida; ao zerar, reaparece em `respawn_position` com vida cheia (saindo do carro se estiver
  dirigindo). Vida no HUD (canto inferior direito).

## NPCs (`scenes/npc/npc.tscn`)

| Tipo | Comportamento | Pontos ao matar (como jogador) |
|---|---|---|
| `innocent` | anda sem rumo; foge por 3 s quando atacado | **-100** |
| `criminal` | persegue e atira no jogador a até 450 px (mantém 180 px, tiro a cada 1,2 s) | **+50** |

3 de vida. Mortes por tiro ou atropelamento do jogador contam; mortes sem jogador (trânsito, tiros de
criminoso) não alteram a pontuação. No mundo: 40 inocentes, 4 criminosos na Cidade e 6 no Campo
(posições determinísticas por seed, livres de prédios/árvores, longe do ponto inicial).

## Trânsito (`Car.ai_controlled`)

- 10 carros dirigem sozinhos pelas ruas da cidade (`TrafficRoute`): sempre na faixa da direita,
  escolhem a direção em cada cruzamento (60% de seguir reto, nunca voltam), freiam diante de pessoas,
  jogadores e outros carros, e dão ré quando presos por 1,5 s.
- **Não podem ser roubados** (zona de interação desligada; coerente com o tema de agente).
- Carros estacionados continuam existindo (8 no mundo, dirigíveis).

## Limitações

- Sem mira livre (só 8 direções), sem outras armas, sem munição
- NPCs não têm nome, personalidade nem rotinas ainda; criminosos já nascem "criminosos"
  (nada de crimes que acontecem e a descobrir)
- Trânsito só na cidade, sem semáforos; carros às vezes raspam em quinas de cruzamento (a IA se recupera)
- Quem morre dirigindo é jogado para fora do carro e reaparece sem penalidade

## Testes

`test_car_handling` (chute, deslize, auxílio), `test_traffic` (rotas e IA), `test_combat` (projétil, arma,
vida), `test_npc` (comportamento, pontos, atropelamento); `test_world_layout`, `test_input_setup` e
`test_hud` ampliados.
