# Mundos grandes e infinitos no Godot

Resposta curta: **mundo grande é viável e moderadamente difícil; infinito é possível, mas
só se for procedural e custa bem mais.** Decidido: **mundo finito e grande**. Nada disso é necessário ainda: a cidade
e o mundo atual (12480x5760 px, ~150 prédios e 250 árvores) cabem inteiros na memória.

## Limites reais

| Tema | Situação |
|---|---|
| Precisão numérica | O Godot usa `float` de 32 bits. Longe da origem (dezenas/centenas de milhares de px) surgem tremores em física e sprites. Versão de 64 bits exige compilar o engine e não serve para web. |
| Memória/CPU | Mundo inteiro como nós não escala. Só o entorno do jogador deve existir. |
| Multiplayer | Cada jogador pode estar em lugar diferente; carregamento por chunk deve ser por jogador. |
| Interiores | Já são cenas separadas, então não pesam no mundo aberto. |

## Técnicas

1. **Chunks:** dividir o mundo em blocos (ex.: 1024x1024 px). Carregar/descarregar os
   blocos próximos de cada jogador. Cada chunk é gerado por `seed + coordenada`, então todos
   os clientes geram o mesmo conteúdo sem enviar o mapa.
2. **Floating origin:** quando o jogador passa de certa distância da origem, deslocar o
   mundo inteiro de volta (e ajustar coordenadas de rede). Resolve o tremor de precisão.
3. **Terreno procedural:** `FastNoiseLite` para bioma (cidade/campo/floresta/água) e
   rios (linhas de ruído de baixo valor). Cidades são "ilhas" com layout próprio.
4. **Água e barcos:** água é uma camada/zona; barco é um veículo com física própria e só
   navega sobre água; o jogador a pé não entra (ou nada devagar).
5. **Navegação/IA:** pedestres e inimigos só existem nos chunks ativos; fora deles são
   dados simulados de forma simples (ou congelados).

## Recomendação

1. Mundo **finito e grande** (ex.: 20.000 x 20.000 px) com chunks + floating origin.
2. Cidades e pontos de missão desenhados/gerados por seed (missões precisam de lugares fixos).
3. Campo e rios procedurais ao redor.
4. Infinito só se o jogo pedir; missões de agente secreto se encaixam melhor em um mundo
   com lugares conhecidos do que em terreno infinito.

## Ordem sugerida

1. Extrair `CityLayout` em um gerador por chunk (a lógica já é independente de nós).
2. Criar `ChunkManager` com testes de carregar/descarregar.
3. Introduzir biomas e rio. 4. Barco. 5. Floating origin.
