# Protótipo 02: prédios maiores e interiores

## Mudanças

- **Prédios maiores:** quarteirão de 400 para 480 px; prédio de 280 para 360 px de lado;
  rua continua com 120 px. Mundo: 3840x3840 px.
- **Correção:** o ponto inicial antigo (200, 200) ficava dentro de um prédio. Agora é o
  cruzamento (480, 480) (`CityLayout.spawn_point()`).
- **Layout lógico sem nós:** `scripts/world/city_layout.gd` gera prédios, cores e portas
  por seed; `city.gd` só monta os nós a partir dele.
- **Portas:** cada prédio tem uma porta (`Area2D`, `scripts/world/door.gd`) no centro da
  parede inferior. Tocar nela com um jogador (grupo `players`) entra no prédio.
- **Interiores:** `scenes/interior/interior.tscn`. Sala de 1920x1200 px com piso
  quadriculado, paredes, 10 móveis sólidos e porta de saída embaixo. Móveis são gerados por
  seed do id do prédio (`scripts/interior/interior_layout.gd`), sempre na mesma posição,
  com área livre diante da saída.
- **Troca de cena:** autoload `GameState` guarda o prédio atual e a posição de retorno.
  Ao sair, o jogador reaparece 40 px abaixo da porta de onde entrou (fora da área da porta,
  para não reentrar).

## Proporção

Fachada: 360 px de largura. Interior: 1920 px (5,3x). A escala interna não acompanha a
externa, como em Retro City Rampage.

## Limitações

- Todos os interiores usam o mesmo estilo (só os móveis variam)
- Sem NPCs, itens ou interação dentro dos prédios
- Só o jogador 1 existe; troca de cena não pensada ainda para multiplayer/split screen

## Testes

`test_city_layout`, `test_interior_layout`, `test_game_state`, `test_scenes`
(inclui um teste que anda até a porta e confere a entrada no prédio).
