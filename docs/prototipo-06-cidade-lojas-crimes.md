# Protótipo 06: calçadas, cidade variada, itens no chão, lojas e crimes por região

## Ruas, calçadas e população

- **Ruas com calçadas:** cada rua é um corredor de 200 px: asfalto de 140 px e duas calçadas de 30 px.
  Faixas de pedestres desenhadas nos cruzamentos. Quarteirão de 560 px, lote de 360 px, cidade de 6720 px
  (mundo todo: 13440 x 6720 px).
- **Pedestres andam pelas calçadas** (`SidewalkGraph`): cada cruzamento tem 4 cantos; o passeio segue pela
  calçada até o próximo cruzamento e, de vez em quando, atravessa a rua pela faixa. Se atacados, fogem pela
  calçada para longe do agressor. Se ficam presos por mais de 1,2 s, voltam pelo caminho.
- **Mais gente:** 110 pedestres na cidade (antes 40 inocentes), 12 civis soltos no campo, 10 criminosos.
- Carros do trânsito usam faixas de 26 px do centro; carros estacionados ficam rente ao meio-fio.
  Os carros podem subir nas calçadas (ainda não há meio-fio sólido).

## Prédios menos simétricos

Cada lote é sorteado (por seed) em um destes formatos:

| Formato | Chance | Descrição |
|---|---|---|
| Parque | 10% | sem prédio; grama e 4 a 7 árvores |
| Prédio único | 28% | recuos aleatórios em cada lado |
| Dois prédios | 34% | lote dividido com uma passagem entre eles |
| Prédio com quintal | 28% | ocupa 50 a 80% da largura; o resto é quintal com árvores |

Além disso: portas em posições aleatórias da parede, cores variadas, detalhes no telhado (caixas) e dimensões
quebradas em múltiplos de 4. A cidade passou de 144 para ~180 prédios.

## Itens no chão

- 18 itens espalhados (deterministas): dinheiro, kits médicos, taser, pistola, escopeta e escudo; calçadas na
  cidade, campo aberto na outra região.
- **Dinheiro** é recolhido ao encostar. **Outros itens** pedem a tecla E ("Pressione E para pegar Kit médico").
- Mochila cheia (8 tipos de item ou 9 unidades por tipo): o item continua no chão e aparece o aviso
  "Mochila cheia".
- **Criminal morto larga** dinheiro ($15 a $45), 25% de chance de kit médico e 8% de pistola. Atordoado não larga nada.
- Dinheiro novo no jogador: começa com $200; aparece no HUD abaixo dos pontos.
- Avisos temporários no topo da tela (`HUD.show_toast`, `Player.notify`).

## Lojas

| Loja | Vende | Onde |
|---|---|---|
| Armaria | pistola $150, escopeta $400, taser $200 | 2 na cidade |
| Farmácia | kit médico $40 | 3 na cidade |
| Loja do Agente | escudo $250, taser, kit médico | 2 na cidade |
| Armazém Rural | kit médico, escopeta | 1 fazenda no campo |

- Lojas são prédios com placa e cor própria. Ao entrar, o interior tem balcão e vendedor (nome vindo do
  gerador de NPCs); no balcão aparece "Pressione E para comprar na Farmácia".
- Painel de loja: **comprar** o estoque e **vender** itens da mochila por metade do preço (item equipado
  vendido esvazia a mão). Esc ou botão fecham. Dinheiro insuficiente ou mochila cheia não cobram nada.

## Crimes que dependem da região (`CrimeProfiles`, `IncidentManager`)

| Região | Frequência | Tipos (peso, criminosos, recompensa) |
|---|---|---|
| Cidade | a cada ~25 s | Assalto armado (3, 1, 100), Briga de gangues (2, 3, 200), Tráfico de drogas (2, 2, 150) |
| Campo | a cada ~45 s | Contrabando (2, 2, 150), Roubo de gado (3, 1, 100), Plantação ilegal (1, 3, 220) |

- A cada intervalo, perto de um jogador (500 a 900 px, em terreno livre) nasce um crime **da região em que ele está**.
  Aparece o aviso "Crime em andamento: Briga de gangues — a 90 m a nordeste".
- No máximo 2 crimes ao mesmo tempo. Os criminosos de cada crime têm o campo `crime` e são hostis.
- **Resolvido** quando todos os criminosos do crime estão mortos ou atordoados: bônus de pontos (recompensa) e
  metade em dinheiro. Prender vale mais que matar quando o taser é usado (estágio de design: pontos de
  atordoar + bônus do crime).
- Os criminosos fixos do mapa também recebem um crime da região onde estão.

## Limitações

- Crimes ainda são "criminosos hostis num lugar": sem vítima, sem cena de crime, sem criminosos disfarçados
- Sem meio-fio sólido nem calçadas exclusivas para pedestres; pedestres não evitam carros além de esperar
- Compra e venda sem estoque limitado nem variação de preço
- Interior de loja usa o mesmo layout base (só muda o balcão e os móveis)

## Testes

`test_city_layout` (calçadas, lotes, variação, parques, lojas), `test_sidewalks` (grafo e pedestres),
`test_pickups_and_shops` (itens, dinheiro, loot, loja, interior), `test_crime` (perfis por região, ocorrências),
`test_world_layout`, `test_traffic`, `test_scenes` ampliados.
