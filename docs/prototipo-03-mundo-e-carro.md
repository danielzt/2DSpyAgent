# Protótipo 03: interação com E, carro, mundo grande e regiões

## Interação (tecla E)

- Ações novas: `p1_interact` (E / botão A do gamepad 0) e `p2_interact` (Enter / botão A do gamepad 1).
- `InteractZone` (`scripts/interaction/interact_zone.gd`): `Area2D` que, quando um jogador entra,
  se registra no jogador (`set_interactable`). **Nada acontece até pressionar a tecla.**
- O jogador mostra no HUD, no **canto inferior esquerdo**, "Pressione E para entrar/sair/dirigir".
  O nome da tecla vem do `InputMap` (`InputSetup.key_label`), então aparece "Enter" para o jogador 2.
- `Door` estende `InteractZone`: E na porta de um prédio entra; E na porta do interior sai.
- Dirigindo, o prompt vira "Pressione E para sair do carro".

## HUD (`scripts/ui/hud.gd`)

`CanvasLayer` criado por cada jogador (pronto para split screen):
região no canto superior esquerdo, pontos no superior direito, instrução no inferior esquerdo.

## Carro (`scenes/vehicle/car.tscn`, `scripts/vehicle/car.gd`)

- `CharacterBody2D` com `InteractZone` ("dirigir"). Um motorista por vez.
- Controles do motorista: cima acelera, baixo freia/ré, esquerda/direita viram
  (a curva só funciona em movimento e inverte em ré).
- Velocidade máxima 520 px/s, ré 180 px/s. Batida em parede reduz a velocidade pela metade.
- Entrar: jogador some e perde colisão; segue o carro (a câmera é filha do jogador).
- Sair: jogador reaparece ao lado esquerdo, direito ou atrás do carro, o primeiro lado livre.
- Funções puras `Car.next_speed` e `Car.steer_amount` são testadas isoladamente.

## Pontuação (`scripts/autoload/score_keeper.gd`, autoload `Score`)

- Regra de design: **matar inocente = -100 pontos**; matar criminoso = +50. Pontos podem ficar negativos.
- `Score.register_kill("innocent" | "criminal")`. O HUD atualiza pelo sinal `changed`.
- **Ainda não há combate nem NPCs**: a regra existe e é testada, mas nada a dispara no jogo.

## Mundo e regiões

Mundo de **12480 x 5760 px**, de 3840x3840 do protótipo anterior (cerca de 3,7x a área).

| Região | Retângulo | Conteúdo |
|---|---|---|
| Cidade | (0,0) 5760x5760 | grade 12x12 de quarteirões, 144 prédios com porta, 6 carros |
| Campo | (5760,0) 6720x5760 | estrada de terra, 7 fazendas com porta, 8 plantações, 250 árvores sólidas, 2 carros |

- `WorldLayout` (`world_layout.gd`) junta `CityLayout` e `CountryLayout`; responde `region_at(ponto)`,
  `buildings()`, `vehicle_spawns()`.
- A estrada de terra (y = 2880) continua uma rua da cidade.
- Fazendas têm ids a partir de 1000, então cada uma tem interior próprio.
- O nome da região atual aparece no HUD; interiores mostram "Interior".
- `scripts/world/world.gd` substituiu `city.gd` e monta todos os nós.

## Limitações

- Tudo ainda é carregado de uma vez (~150 prédios e 250 árvores): sem chunks
  (ver [mundo-grande.md](mundo-grande.md))
- Sem rios, barcos, NPCs, combate, som ou sprites
- Carro só tem o jogador 1 testado no input; sem dano, sem atropelar
- Árvores são quadrados de colisão pequenos com visual circular
