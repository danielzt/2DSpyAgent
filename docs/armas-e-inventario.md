# Armas, munição, barra de itens e menus

> **Plano em discussão, nada implementado.** Hoje existem pistola, escopeta, taser, kit médico e
> escudo, com mão esquerda e mão direita, tiro infinito e sem corpo a corpo
> (ver [prototipo-05-mira-inventario-ficha.md](prototipo-05-mira-inventario-ficha.md)).
> Etapas em [roteiro-jogo.md](roteiro-jogo.md); história em [historia.md](historia.md).

## Decidido pelo autor

- **Munição limitada e comprada** em loja.
- **Barra de itens** na parte de baixo da tela (estilo Minecraft) no lugar de mão esquerda e direita.
  Aceita armas e itens de uso (cura, energético, comida).
- No celular, o jogador toca no espaço da barra (ou em um botão de trocar).
- **Botão direito** é a ação secundária do item ativo; não há mais dois itens em uso ao mesmo tempo.
- Lança-míssil entra na lista; faca vai para o começo do jogo; fuzil de precisão dá leve zoom out.
- Os menus atuais (inventário, ficha, loja, conversa) serão redesenhados.

## Armas

| Arma | Tipo | Letal | Munição | Papel | Entra em |
|---|---|---|---|---|---|
| Punhos | Corpo a corpo | Não | — | Sempre disponível; nocauteia | Início |
| Cassetete | Corpo a corpo | Não | — | Nocaute mais rápido, mais alcance | Ato 1 |
| Faca | Corpo a corpo | Sim | — | Silenciosa, só de perto; primeira arma letal | Ato 1 |
| Taser | Curto alcance | Não | Bateria | Atordoa na hora | Ato 1 |
| Pistola | Fogo | Sim | Leve | Padrão, precisa | Fim do Ato 1 |
| Pistola de dardos | Fogo | Não | Dardos | Não letal à distância; demora a fazer efeito | Ato 2 |
| Pistola com silenciador | Fogo | Sim | Leve | Não alerta quem está perto | Ato 2 (Madame) |
| Guarda-chuva blindado | Corpo a corpo | Não | — | Aberto é escudo, fechado é bastão; substitui o escudo balístico | Ato 2 (Comendador) |
| Escopeta | Fogo | Sim | Cartucho | Cone de perto | Ato 2 (Contador) |
| Submetralhadora | Fogo | Sim | Leve | Cadência alta, imprecisa, gasta muito | Ato 2 (Tonhão) |
| Granada de luz | Arremesso | Não | Unidade | Atordoa um grupo | Ato 3 |
| Bomba de fumaça | Arremesso | Não | Unidade | Quebra a linha de visão | Ato 4 |
| Fuzil de precisão | Fogo | Sim | Pesada | Alcance além da tela; ao mirar, a câmera afasta um pouco | Ato 4 |
| Pulso eletromagnético | Gadget | Não | Bateria | Desliga carros sem motorista e câmeras | Ato 5 |
| Lança-míssil | Explosivo | Sim | Míssil | Destrói veículos; explosão em área que também atinge inocentes | Ato 5 |

No modo Livre todas ficam à venda desde o início.

## Munição

Seis tipos, para a loja e a barra não virarem planilha:

| Tipo | Usada por | Preço relativo |
|---|---|---|
| Leve | Pistola, pistola com silenciador, submetralhadora | Barato |
| Cartucho | Escopeta | Médio |
| Dardos | Pistola de dardos | Médio |
| Pesada | Fuzil de precisão | Caro |
| Bateria | Taser, pulso eletromagnético | Médio |
| Míssil | Lança-míssil | Muito caro |

- Granada de luz e bomba de fumaça são compradas por unidade.
- Cada arma tem pente e recarga; a reserva tem limite por tipo.
- Criminosos derrotados largam um pouco de munição do tipo que usavam (o loot já existe).
- Corpo a corpo nunca acaba: é a rede de segurança de quem ficou sem bala.

## Barra de itens (proposta de detalhe)

```
                                                  PISTOLA  12 / 48
 ┌────┬────┬────┬────┬────┬────┬────┬────┐
 │ 1  │[2] │ 3  │ 4  │ 5  │ 6  │ 7  │ 8  │
 │soco│pist│esco│tasr│g-ch│ kit│lanc│ ener│
 │    │ 12 │  6 │  3 │    │ x2 │ x4 │ x1 │
 └────┴────┴────┴────┴────┴────┴────┴────┘
```

- 8 espaços. O espaço ativo fica destacado, com nome e munição (pente / reserva) acima.
- **Trocar:** roda do mouse ou teclas 1 a 8; no gamepad, os dois botões de ombro; no celular, toque no espaço.
- **Botão esquerdo:** usa o item ativo (atira, bate, come, aplica o kit).
- **Botão direito:** ação secundária do item ativo (abrir o guarda-chuva, mirar com o fuzil, bloquear no corpo a corpo, coronhada com as armas de fogo).
- **R:** recarrega a arma ativa.
- **Itens de uso:** kit médico (cura na hora), comida (cura aos poucos, barata), energético (velocidade por alguns segundos).
- Os punhos ocupam o espaço 1 e não podem ser removidos.
- Todas as trocas passam por ações `p{N}_*`; cada jogador tem a própria barra.

O que se perde em relação às duas mãos: usar dois itens ao mesmo tempo (escudo com pistola).
A ação secundária cobre o caso do escudo dentro de um único item.

## Inventário (decidido)

**16 espaços: a barra de 8 mais uma mochila de 8.** O jogador não carrega tudo e escolhe o
equipamento antes de cada missão.

| Categoria | Ocupa espaço? |
|---|---|
| Armas (fora os punhos) | Sim |
| Arremessos (granada de luz, bomba de fumaça) | Sim, empilham até 5 |
| Itens de uso (kit médico, comida, energético) | Sim, empilham até 5 |
| Munição | Não: contador à parte, com teto por tipo |
| Gadgets passivos (scanner, gazua, rastreador, disfarce) | Não: ficam na ficha |
| Itens de missão | Não: ficam no diário |

- **Baú** no apartamento e no QG para guardar o que não couber.
- **Soltar item:** qualquer item da barra ou da mochila pode ser largado no chão e pego por outro jogador.

## Co-op (decidido)

- Cada jogador tem inventário, barra, munição, atributos e carteira próprios.
- Jogador novo entra com o **inventário vazio** (só os punhos).
- **Dinheiro:** o valor recolhido por qualquer jogador é creditado inteiro a todos (não é dividido).
- Itens passam de um jogador a outro ao serem soltos no chão.
- O baú do QG é comum à equipe.

## Menus (proposta de detalhe)

Problemas apontados pelo autor nos menus atuais: **aparência**, **organização** e **falta de
finalidade** (o inventário é só texto; a conversa não leva a nada). Regras para o redesenho:

- **Ícone antes de texto:** todo item tem ícone em pixel art (pelo `SpriteFactory`), mostrado em
  grade; o texto aparece só no item selecionado (nome, descrição, munição, preço).
- **Navegar, não ler:** cursor que anda pela grade com teclado, gamepad ou toque; arrastar ou
  confirmar para mover entre mochila, barra e baú.
- **Nenhuma tela sem finalidade:** cada tela existe para uma decisão do jogador. A conversa passa
  a render pista, quest, desconto ou contato (etapa E7 do roteiro).

Um único menu com abas no lugar dos painéis separados, no estilo do HUD novo:

| Aba | Conteúdo |
|---|---|
| Inventário | Grade de itens; arrastar (ou escolher e confirmar) para um espaço da barra |
| Ficha | Atributos, patente, XP, ficha limpa/suja |
| Missões | Diário de quests |
| Mapa | Bairros, prédios, objetivos |
| Opções | Som, tela, controles, idioma |

Loja e conversa continuam como telas próprias, redesenhadas no mesmo estilo. Tudo navegável
por teclado, gamepad e toque.

## Em aberto

| # | Questão |
|---|---|
| A1 | **Decidido:** botão direito é a ação secundária do item ativo. Escudo junto com arma deixa de existir de propósito (era forte demais) |
| A2 | **Decidido:** barra de 8 espaços |
| A3 | **Decidido:** no co-op cada jogador tem a própria munição |
| A4 | **Decidido:** tiros alertam todos ao redor, inimigos e pedestres (dá sentido ao silenciador e à faca) |
| A5 | **Decidido:** só comprar armas novas; sem melhorias de arma por enquanto |
| A6 | **Decidido:** inventário limitado a 16 espaços (barra de 8 + mochila de 8), com baú |
| A7 | **Decidido:** recarga na tecla R (ação `p{N}_reload`); coronhada no botão direito das armas de fogo |
| A8 | **Decidido:** tudo individual no co-op; comum só o baú do QG e o crédito de dinheiro (ver seção Co-op) |
