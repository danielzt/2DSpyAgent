# Interiores caprichados — design

> Data: 2026-11-15. Substitui o modelo paramétrico das Fases 3 e 6
> ([redesign-fase-3.md](../../redesign-fase-3.md), [redesign-fase-6.md](../../redesign-fase-6.md)).

## 1. Intenção

Os interiores atuais são salões grandes (1280x800 a 2560x1440 px, até 4 telas) com poucos móveis,
desenhados 2 a 3 vezes maiores que o personagem (cama do agente com 150x110 px para um personagem de 24x32 px),
cheios de vasos e lixeiras sorteados. Parecem vazios e genéricos.

O pedido: **interiores do tamanho da tela ou um pouco maiores, com planta caprichada e cheia de detalhes,
cada tipo único e totalmente característico** — piso, paredes, móveis e gente. Os NPCs se vestem de acordo
(polícia de azul, hospital de branco) e **têm o que fazer** ali dentro. A casa do agente deve ser confortável.

## 2. Metas, não metas e antimetas

**Metas**
- Cada um dos 25 tipos (24 tipos de prédio + casa do agente) tem a sua planta própria, reconhecível
  em um relance, sem ler a placa.
- Tamanho entre 1 tela e ~1,4 tela (seção 5).
- Móveis na escala do personagem (seção 6).
- Piso e parede com cara do lugar, parede com face visível (seção 7).
- NPCs com uniforme do lugar e com atividade e propósito (seção 9).
- Prédios do mesmo tipo variam levemente (escolha do usuário: "segunda opção").

**Não metas**
- Novas mecânicas de serviço: os serviços atuais (`services.gd`) continuam iguais, só mudam de lugar.
- Rotinas por hora do dia (turno da noite com menos gente): fica para depois.
- NPCs que circulam entre cômodos com busca de caminho: as rondas são curtas e dentro de um cômodo.
- Interiores de história feitos à mão (subsolo da lavanderia, celeiro, silo): seguem planejados à parte.

**Antimetas** (seria fracasso mesmo funcionando)
- Interiores que ainda parecem salão vazio com móveis soltos.
- Dois tipos diferentes com a mesma cara (ex.: farmácia igual à armaria trocando a placa).
- Móvel desproporcional ao personagem.
- NPC de uniforme errado no lugar (atendente de vermelho no hospital, como hoje).
- Gente amontoada sem sentido só para "encher".

## 3. Restrições (AGENTS.md e projeto)

- GDScript, Godot 4.7.2, GL Compatibility. Toda arte por código em `scripts/art/`, só cores de `Palette`
  (32 cores), 1 texel = 2 px, texturas pedidas ao `SpriteFactory` (cache).
- Lógica pura em `RefCounted` (layout), nós em `interior.gd`. Testes na mesma mudança, suíte inteira passando.
- Interação só por `InteractZone` + `p{N}_interact`, com instrução no HUD.
- Seed fixa por id do prédio. Nada que dependa de "o jogador" único.
- Tela: 1280x720 (`canvas_items`, `expand`). Personagem: 12x16 texels = 24x32 px.
- Documentar em `docs/` (README, changelog, gdd) e conferir capturas com `tools/probe.gd`.

## 4. Abordagens consideradas

| | Abordagem | Prós | Contras |
|---|---|---|---|
| **A (escolhida)** | **Plantas como mapas de texto**: duas grades (piso e objetos) por tipo, célula de 32 px, legenda por planta | A planta "se parece" com o cômodo no arquivo; fácil de caprichar e revisar; escala certa por construção; variação por espelho, cores e itens opcionais | Reescreve `interior_layout.gd` (~1100 linhas) |
| B | Manter as funções por tipo com coordenadas calculadas, só reduzindo e adensando | Incremental | Coordenadas à mão foram a causa do visual atual; difícil caprichar 25 plantas |
| C | TileMap no editor do Godot | Editor visual | Quebra a regra de arte por código e os testes de lógica pura; descartada |

O usuário escolheu A e pediu que piso e paredes também tenham cara do lugar — a camada de piso e o estilo
de parede por cômodo atendem isso.

## 5. Tamanhos

Grade de **32 px** (16 texels). Três tamanhos fixos por tipo; a largura da fachada **deixa de influenciar**
o tamanho (as plantas são autorais; *decisão minha*).

| Classe | Células | Pixels | Telas |
|---|---|---|---|
| P | 40 x 23 | 1280 x 736 | 1 (rola 16 px) |
| M | 48 x 27 | 1536 x 864 | ~1,4 |
| G | 56 x 32 | 1792 x 1024 | ~2 (só hotel, hospital, cinema, boate, armazém, QG) |

A borda externa faz parte da grade (linha de parede no topo com face visível; nas laterais e embaixo,
parede só de topo). A porta de saída fica na parede de baixo.

## 6. Escala dos móveis

Referência: personagem 24x32 px (menos de 1x1 célula). Medidas em células (32 px), tamanho de jogo:

| Móvel | Hoje (px) | Novo (células) | Novo (px) |
|---|---|---|---|
| Cama de solteiro | 128x96 | 1,5 x 2,5 | 48 x 80 |
| Cama de casal | 150x110 | 2,5 x 2,5 | 80 x 80 |
| Leito de hospital | 80x136 | 1,5 x 2,5 | 48 x 80 |
| Sofá de 3 lugares | 176x64 | 3 x 1,5 | 96 x 48 |
| Poltrona | — | 1,5 x 1,5 | 48 x 48 |
| Banco de espera | 176x56 | 3 x 1 | 96 x 32 |
| Mesa de escritório | 128x64 | 2 x 1,5 | 64 x 48 |
| Mesa de restaurante (4 lugares) | 112x72 | 2 x 2 | 64 x 64 |
| Criado-mudo, vaso, lixeira | 40–44 | 1 x 1 ou menor | ≤ 32 x 32 |
| Balcão de atendimento | 320x48 | 5 a 8 x 1,5 | 160–256 x 48 |
| Carro no elevador | 192x320 | 3 x 5 | 96 x 160 (≈ carro da rua) |

Móveis podem ocupar meia célula (16 px) — a legenda dá o tamanho real e o alinhamento dentro do bloco.

## 7. Formato da planta

Cada tipo é um arquivo `scripts/interior/plans/<tipo>.gd` (`RefCounted` só com constantes):

```gdscript
const SIZE := "M"
const FLOOR := [            # uma letra por célula: estilo do cômodo (piso + parede)
	"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
	"hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
	...
]
const OBJECTS := [          # paredes, portas, móveis, pessoas, zonas
	"################################################",
	"#..J..R..W...W..|.n.bb.n..|...KKKFF.............#",
	...
]
const DETAIL := [           # opcional: pessoas, pontos de ronda e objetos em cima de móveis
	"................................................",
	"...........................3....................",
	...
]
const LEGEND := {
	"h": {"room": "Enfermaria", "floor": "floor/linoleum_mint", "wall": "wall/tile_white_green"},
	"b": {"item": "hospital_bed", "size": [1.5, 2.5]},
	"n": {"item": "nightstand", "size": [0.75, 0.75], "align": "top"},
	"J": {"wall_item": "window"},
	"R": {"wall_item": "clock"},
	"1": {"npc": "enfermeiro", "staff": true, "act": "patrol", "route": "a"},
	"a": {"route": "a"},                 # ponto de ronda do NPC 1 (célula livre)
	"$": {"zone": "heal"},
	"?b": {"chance": 0.6},              # item opcional (a seed decide)
}
```

Regras do leitor (`PlanParser`, lógica pura, testável):
- `#` parede, `|` e `-` paredes internas finas (16 px, centradas na célula), `D` vão de porta interna,
  `E` porta de saída, `.` piso livre.
- **Móvel de várias células**: o mesmo caractere repetido num retângulo conectado é **uma peça**; `size` e `align`
  ajustam o retângulo real dentro do bloco. Duas peças iguais encostadas usam letras diferentes com a mesma legenda.
- **Itens de parede** (`wall_item`) ficam na face da parede acima da célula; não têm colisão.
- **Itens de cima de móvel** (`on`: prato, computador, abajur, papéis) ficam no móvel da célula, sem colisão.
- **Terceira camada `DETAIL`** (mesma largura e altura, `.` = nada), por cima de `OBJECTS`: dígitos são vagas
  de NPC, letras de rota marcam pontos de ronda, e letras com `on` são objetos de cima de móvel. Assim uma
  pessoa sentada no sofá, um paciente no leito ou um prato na mesa não quebram o retângulo da peça embaixo.
  Vaga `sit`/`lie` precisa cair sobre um móvel compatível; ponto de ronda precisa cair em piso livre
  (*decisão minha*, a partir da revisão).
- Erros de formato (linhas de largura diferente, letra sem legenda, peça não retangular) falham nos testes.

O `InteriorLayout` passa a ser montado pelo leitor e mantém a mesma interface pública usada hoje
(`rooms`, `walls`, `items`, `npc_slots`, `zones`, `exit_door()`, `spawn_point()`, `solids()`, `unreachable()`,
`counter`, `is_shop`, `shop`), para não mexer em `services.gd`, `world.gd` e no HUD além do necessário.
`npc_slots` ganha `act`, `route` e `facing`.

## 8. Piso e paredes

**Pisos novos** (em `tile_factory.gd`, além dos 7 atuais), padrão de 16x16 texels:
taco em espinha, laminado claro, tábua rústica, linóleo verde-água, linóleo cinza, linóleo branco,
ladrilho preto e branco, ladrilho bege, azulejo de banheiro, carpete vinho com padrão, carpete azul-marinho,
carpete cinza, carpete roxo, borracha de academia, concreto com faixa amarela, chapa metálica.

**Paredes com face visível**: a parede ocupa a célula vista de cima (topo escuro) e, quando há piso logo abaixo,
desenha uma **face** de 24 px de altura sobre a célula de piso de baixo (não bloqueia; é só visual; o personagem
passa por trás dela no z). A face tem o estilo do cômodo de baixo (a legenda do piso diz qual), rodapé e,
em cima, a sombra do topo. Estilos (`wall/*` em `tile_factory.gd`):

| Estilo | Uso |
|---|---|
| azulejo branco com faixa verde | hospital, farmácia |
| painel azul-escuro em meia-parede | delegacia |
| painel de madeira nobre | banco, sala do delegado, escritório do editor |
| tijolo aparente | bar, oficina (fundos) |
| papel de parede listrado creme e vinho | casa do agente (sala), hotel |
| papel de parede florido | casa |
| reboco pintado (3 cores) | apartamento, escritório, mercado, academia |
| azulejo creme com faixa vermelha | lanchonete |
| veludo vinho com friso dourado | cinema |
| preto com faixa neon | boate |
| chapa ondulada | armazém, posto (fundos) |
| bloco de concreto pintado | oficina, armaria (estande) |
| madeira de celeiro | armazém rural, casa de fazenda |
| azulejo azul-claro | lavanderia do QG, banheiros |
| painel metálico com luzes | sala secreta do QG |

As paredes laterais e de baixo mostram só o topo (vista de cima). Portas internas: batente nos dois lados do vão.
Porta de saída: batente, capacho com a cor do lugar e luz de fora.

**Itens de parede** (sem colisão): janela com o céu (substitui `window_rects()`), quadro (3 variações),
relógio, extintor, cartaz, quadro de avisos, TV de parede, prateleira, espelho, placa de saída, lâmpada de parede,
diploma, chaveiro do hotel, painel de ferramentas, cabeça de cervo (fazenda), neon.

## 9. NPCs: roupa, atividade e propósito

### 9.1 Para que servem

1. **Prestar o serviço do lugar** — o funcionário fica atrás do balcão da zona de serviço. É só posição:
   a zona funciona mesmo se ele for ferido ou morto (sem ligação zona ↔ NPC; *decisão minha*, coerente com
   "sem mecânicas novas de serviço").
2. **Dar vida e credibilidade** — cada um faz algo que combina com o lugar (seção 9.3).
3. **Falar como quem trabalha ali** — a conversa existente (`NpcIdentity.answer`) ganha falas por papel:
   a enfermeira fala do plantão, o preso reclama do agente, o bartender insinua o rumor do dia (sem
   substituir o serviço pago), o repórter comenta a manchete. 2 a 3 falas por papel, sorteadas pela seed,
   na pergunta "O que você faz da vida?" e em "Viu algo suspeito por aqui?". São **falas fixas de sabor**,
   sem ler dados do jogo: não existe "rumor do dia" nem sistema de manchetes, e entregar a pista de graça
   esvaziaria o serviço pago do bar (*decisão minha*).
4. **Ganchos para o futuro** (não nesta mudança): turnos por hora, missões a partir de NPCs.

Matar ou ferir um NPC de interior segue as regras atuais de inocentes.

### 9.2 Uniforme pelo prédio, não pelo nome do papel

Hoje o uniforme vem de palavras no nome do papel e falha ("atendente" no hospital sai de vermelho).
Passa a ser: **tipo de prédio + papel → uniforme**, numa tabela em `character_sprites.gd`, com um
uniforme padrão por tipo para qualquer funcionário (`staff`) e roupa comum para clientes.
O uniforme ganha, além de camisa, calça e boné, um **detalhe** desenhado por cima: avental, gravata,
colete, jaleco (camisa longa), cruz, crachá, faixa refletiva, e um **chapéu**: quepe, touca de chef,
touca hospitalar, capacete, chapéu de palha.

| Prédio | Funcionários | Outros |
|---|---|---|
| Delegacia | policiais, atendente e delegado **azul** com quepe; perito de jaleco branco; detetive de sobretudo areia | presos **laranja**; visitantes à paisana |
| Hospital | **todos de branco**: médica de jaleco com estetoscópio, enfermeiro com touca, recepcionista de branco com crachá, farmacêutico de jaleco | pacientes de **camisola azul-clara**; acompanhantes à paisana |
| Banco | caixas camisa branca e gravata; gerente terno cinza; segurança preto com quepe | clientes |
| Hotel | recepção e concierge vinho com friso dourado; carregador com quepe; camareira preto e branco | hóspedes (um de roupão) |
| Restaurante | chef e ajudante branco com touca; maître e garçom preto e branco com gravata | clientes |
| Lanchonete | avental vermelho e boné | clientes |
| Bar | bartender camisa branca e colete preto | frequentadores |
| Boate | DJ roxo com fone; bartender preto; segurança preto | dançarinos com roupa colorida |
| Loja do Agente | blazer azul-marinho | clientes |
| Armaria | colete verde-oliva e boné | cliente com protetor de ouvido |
| Farmácia | jaleco branco com cruz verde | clientes |
| Mercado | avental verde | clientes com cesta |
| Posto | macacão vermelho e boné amarelo | clientes |
| Armazém Rural | camisa xadrez e chapéu de palha | fazendeiro |
| Oficina | macacão azul | cliente |
| Cinema | vinho com quepe (lanterninha), colete vinho (bomboniere) | espectadores |
| Academia | polo laranja (recepção), agasalho (personal) | alunos de regata e short |
| Redação | camisa social e colete; fotojornalista de colete cáqui | — |
| Escritório | social (camisa clara, calça escura), gerente de terno | visitante |
| Armazém | colete laranja refletivo e capacete amarelo | — |
| Casa, apartamento, fazenda | roupa comum (fazenda: xadrez e chapéu de palha) | — |
| QG | atendente de lavanderia com avental azul-claro; agentes de terno escuro | clientes da lavanderia |

### 9.3 Atividades

Cada vaga tem `act`. As atividades são locais (sem sair do cômodo) e usam quadros novos de sprite:

| `act` | O que faz | Sprite |
|---|---|---|
| `post` | Fica no posto, olha para o lado indicado, vira de vez em quando | atual |
| `patrol` | Anda entre os pontos da sua rota (2 a 4 pontos no mesmo cômodo), para alguns segundos em cada | atual (andando) |
| `sit` | Sentado em cadeira, banco, sofá, banqueta ou poltrona | **novo**: sentado (frente, costas, lado) |
| `lie` | Deitado na cama, maca, beliche ou elevador de oficina (mecânico) | **novo**: deitado |
| `work` | Trabalha no lugar: digita, cozinha, limpa copo, repõe prateleira | **novo**: 2 quadros de braços |
| `exercise` | Esteira, peso, saco de pancada | **novo**: 2 quadros |
| `dance` | Dança na pista | **novo**: 2 quadros |

Quem anda (`patrol`) para se o jogador estiver no caminho e nunca prende o jogador (colisão de NPC parado
como hoje; em ronda, desvia esperando). NPC sentado ou deitado não tem colisão com o móvel dele.

## 10. Variação entre prédios do mesmo tipo

Pela seed do id do prédio:
- **Espelhamento** horizontal (a porta de saída continua centrada ou é espelhada junto).
- **Paleta**: cada planta tem 2 ou 3 conjuntos de cor (piso, estofados, papel de parede), dentro da paleta.
- **Itens opcionais** (`chance` na legenda): vasos, quadros, objetos de cima de móvel, um móvel extra.
- **Quantidade de clientes**: cada vaga de cliente pode ter `chance`; funcionários sempre aparecem.

A validação de alcance (`unreachable()`) roda em todas as variações nos testes.

## 11. Os 25 interiores

Tamanho, cômodos, piso/parede, peças-chave e gente. Cada planta deve caber e ainda ter respiro para andar.

1. **QG (lavanderia)** — G. Frente: lavanderia (linóleo xadrez azul e branco, azulejo azul-claro), fileira de
   lavadoras, secadoras, mesa de dobrar, cestos, cadeiras de espera, máquina de troco. A máquina secreta
   (`InteractZone`, "Pressione E para entrar no QG", regra 1c do AGENTS.md; hoje é atravessável) abre a
   passagem para a **sala do QG**, que fica coberta por uma sombra escura até a passagem ser aberta naquela
   visita — mesma cena, sem cena nova (*decisão minha*). A sala: (chapa metálica, painel com luzes): mesa de briefing, telão com o mapa, armário de
   armas na parede, baú, cofre, cafeteira. Gente: atendente (`work`, dobrando roupa), 1–2 clientes sentados
   lendo; atrás, analista no computador (`work`) e o chefe na mesa de briefing (`post`). Serviço: briefing.
2. **Delegacia** — M. Recepção com balcão alto (painel azul), bancos de espera, quadro de procurados; sala dos
   agentes com 4 mesas, computadores, máquina de café, quadro de casos; 3 celas com grade, beliche e privada;
   sala de interrogatório (mesa, 2 cadeiras, espelho falso); sala do delegado (madeira nobre, bandeira, estante).
   Gente: atendente (`post`), 2 policiais sentados (`work`), 1 policial em ronda até o café (`patrol`), detetive
   no interrogatório com um suspeito (`sit`), delegado (`sit`), 1–3 presos (`lie` ou `post`), visitante (`sit`).
   Serviço: entregar presos.
3. **Hospital** — G. Recepção (mármore claro) com balcão, fileiras de cadeiras de espera, bebedouro;
   enfermaria com 6 leitos, cortinas e criados (linóleo verde-água, azulejo branco com faixa verde);
   UTI com 2 leitos e monitores; consultório (mesa, maca, armário de vidro); farmácia interna com balcão.
   Gente: recepcionista (`post`), médica (`patrol` pelos leitos), enfermeiro (`patrol`), auxiliar com carrinho
   (`patrol`), farmacêutico (`post`), **3–5 pacientes deitados** (`lie`), 2–3 pacientes e acompanhantes
   sentados na espera (`sit`). Serviço: atendimento (cura).
4. **Banco** — M. Hall de mármore com colunas, 3 guichês com vidro, fila com cordões, mesa do gerente com
   cadeiras, porta redonda do cofre ao fundo atrás de grade, câmeras e relógio na parede.
   Gente: 2 caixas (`post`), gerente (`sit`), segurança na porta (`post`), 2–3 clientes na fila (`post`).
   Serviço: depositar e sacar.
5. **Hotel** — G. Saguão (mármore, papel listrado): balcão com sinete e chaveiro na parede, sofás, vaso grande,
   carrinho de malas, porta de elevador; corredor de carpete vinho com 3 quartos (cama no tamanho certo,
   criado-mudo com abajur, frigobar, TV, banheirinho). Gente: recepcionista (`post`), carregador (`post`),
   camareira com carrinho no corredor (`patrol`), hóspede no saguão (`sit`), hóspede dormindo (`lie`).
   Serviço: dormir.
6. **Restaurante** — M. Salão de taco com mesas de toalha branca e vela, quadros; púlpito do maître;
   cozinha aberta (ladrilho preto e branco): fogões, bancada inox, pia, panelas penduradas, geladeira;
   adega na parede. Gente: maître (`post`), garçom (`patrol` mesas↔cozinha), chef (`work`), ajudante na pia
   (`work`), 4–6 clientes sentados comendo (`sit`). Serviço: refeição.
7. **Lanchonete** — P. Estilo americano: ladrilho preto e branco, azulejo creme com faixa vermelha, balcão longo
   com banquetas, 3 cabines vermelhas na janela, chapa, máquina de milkshake, jukebox, neon.
   Gente: atendente (`post`), cozinheiro na chapa (`work`), 2–4 clientes (`sit`). Serviço: lanche.
8. **Bar** — M. Tijolo aparente, taco escuro: balcão de madeira com torneiras de chope e prateleira de garrafas,
   banquetas, mesas redondas, sinuca, alvo de dardos, jukebox, banheiro. Gente: bartender (`work`, limpando
   copo), atendente (`patrol`), 2–3 no balcão (`sit`), 2 na sinuca (`patrol` ao redor da mesa), 1 cochilando
   na mesa (`sit`). Serviço: rodada e rumores.
9. **Boate** — G. Pista de luzes (piso `dance`), cabine do DJ elevada, caixas de som grandes, bar com neon,
   área VIP de carpete roxo com sofás e cordão, camarote fechado do informante, banheiros.
   Gente: DJ (`work`), bartender (`work`), segurança no cordão (`post`), 4–6 dançarinos (`dance`),
   informante no camarote (`sit`). Serviço: informante.
10. **Loja do Agente** — P. Carpete azul-marinho, painel azul-escuro: vitrines com relógios, canetas e maletas,
    manequim de smoking, parede de equipamentos, balcão com caixa. Gente: balconista (`post`), 1–2 clientes
    olhando vitrine (`post`). Serviço: loja.
11. **Armaria** — P. Frente: balcão de vidro com pistolas, parede de rifles em suportes, caixas de munição;
    fundos: estande de tiro com 3 cabines e alvos de papel (concreto, bloco pintado). Gente: balconista
    (`post`), cliente atirando no estande (`work`). Serviço: loja.
12. **Farmácia** — P. Linóleo branco, azulejo com cruz verde: gôndolas brancas com caixas coloridas, balcão do
    farmacêutico, caixa, balança de peso, cestas. Gente: farmacêutico (`post`), caixa (`post`), 1–2 clientes
    (`patrol` entre gôndolas). Serviço: loja.
13. **Mercado** — P. Ladrilho bege, reboco verde com placas de seção: corredores de gôndolas (latas, pães,
    frutas), freezers, 2 caixas com esteira, carrinhos. Gente: caixa (`post`), estoquista repondo (`work`),
    2–3 clientes com cesta (`patrol` pelos corredores). Serviço: loja.
14. **Posto (conveniência)** — P. Linóleo cinza, faixa vermelha e amarela: balcão com cigarros e raspadinhas,
    geladeiras de bebida, máquina de café, prateleiras de salgadinho, óleo de motor, mapa rodoviário.
    Gente: frentista no caixa (`post`), 1–2 clientes. Serviço: loja.
15. **Armazém Rural** — P. Tábua rústica, madeira de celeiro: sacos de ração empilhados, barris, ferramentas
    penduradas, balcão de madeira com balança antiga, sementes. Gente: balconista (`post`), fazendeiro
    (`post`). Serviço: loja.
16. **Oficina** — M. Concreto manchado com faixa amarela, bloco pintado: elevador com carro, bancada com morsa,
    painel de ferramentas, pneus empilhados, compressor, tambores de óleo; escritoriozinho com balcão.
    Gente: mecânico sob o carro (`lie`), lanterneiro na bancada (`work`), atendente no balcão (`post`).
    Serviço: pintar o carro.
17. **Cinema** — G. Saguão de carpete vinho com padrão: bilheteria, bomboniere (pipoca, refrigerante), cartazes,
    cordões; sala escura com tela, fileiras de poltronas, corredor com luzinhas no chão. Gente: bilheteiro
    (`post`), atendente da pipoca (`work`), lanterninha (`patrol` no corredor), 4–8 espectadores (`sit`).
    Serviço: sessão.
18. **Academia** — M. Borracha preta, reboco com espelhos e placas motivacionais: catraca e recepção, esteiras,
    bicicletas, supino, halteres, ringue com saco de pancada, vestiário com armários e chuveiro.
    Gente: recepcionista (`post`), personal (`patrol`), 3–5 alunos (`exercise`), 2 no ringue (`exercise`).
    Serviço: treino.
19. **Redação do jornal** — M. Carpete cinza, parede com primeiras páginas emolduradas: mesas juntas com
    computadores e máquinas de escrever, pilhas de jornal, mural de pautas, sala do editor envidraçada,
    sala escura de foto com luz vermelha. Gente: 2–3 repórteres (`work`), colunista (`sit`), fotojornalista
    (`work`), editor (`sit`).
20. **Escritório** — M. Carpete azul-acinzentado, reboco bege: recepção, baias, sala de reunião com mesa longa,
    copa com café, sala do chefe. Gente: recepcionista (`post`), 3–4 analistas (`work`), auxiliar com papéis
    (`patrol`), gerente (`sit`).
21. **Prédio residencial (apartamento)** — P. Laminado claro, reboco pintado: sala e cozinha integradas
    (kitchenette com bancada), quarto com cama de casal, banheiro, varandinha com plantas.
    Gente: 1–2 moradores (`sit` no sofá, `work` na cozinha).
22. **Casa** — P. Taco, papel florido: sala com sofá e poltrona, mesa de jantar, cozinha, quarto do casal,
    quarto de criança com brinquedos, banheiro. Gente: 2–3 moradores (um idoso na poltrona, `sit`).
23. **Casa de fazenda** — P. Tábua rústica, madeira de celeiro e reboco caiado: fogão a lenha, mesa comprida,
    cadeira de balanço, lareira, cabideiro com chapéu, quarto simples. Gente: ajudante (`work`), tratorista
    comendo (`sit`).
24. **Armazém** — G. Concreto com faixas, chapa ondulada: estantes altas em corredores, paletes, empilhadeira,
    doca de carga com porta de enrolar, escritório do conferente. Gente: estoquista (`work`), conferente com
    prancheta (`patrol`), um na empilhadeira (`post`).
25. **Casa do agente** — M. Ver seção 12.

## 12. Casa do agente (confortável)

Refúgio do jogador: quente, organizado, com personalidade de espião. Sem NPCs (só o gato).

- **Sala** (taco em espinha, papel listrado creme e vinho): sofá de 3 lugares e poltrona de couro,
  tapete grande, mesa de centro com revistas, TV de parede, estante cheia de livros, toca-discos com
  vinis, abajur de pé, lareira, quadro, plantas.
- **Escritório** (carpete azul-marinho, painel de madeira): mesa com dois monitores e luminária,
  cadeira, **mural de casos com fios vermelhos**, arquivo, **baú de equipamento** (zona `stash`), cofre na parede.
- **Quarto** (carpete creme): **cama de casal 80x80 px** com colcha, dois criados-mudos com abajur,
  guarda-roupa, cômoda com espelho, tapete ao pé da cama (zona `rest`: dormir de graça).
- **Cozinha** (azulejo xadrez): bancada em L com fogão, pia e geladeira, mesa pequena com duas cadeiras,
  cafeteira, fruteira.
- **Banheiro** (azulejo azul-claro): banheira, privada, pia com espelho, toalha.
- **Gato** dormindo no sofá ou na cama (item animado de 2 quadros, sem colisão; posição pela seed). *Decisão minha.*

## 13. Arte nova (estimativa)

- **Móveis redesenhados** na nova escala: todos os 62 atuais que continuarem em uso.
- **Novos (~40)**: poltrona, cama de casal, beliche novo, cadeira, cadeira de escritório, banqueta alta, cabine
  de lanchonete, mesa com toalha, mesa redonda, guichê com vidro, porta de cofre, coluna, cordão, púlpito,
  carrinho de malas, carrinho de limpeza, frigobar, abajur, luminária de pé, lareira, toca-discos, cômoda,
  gôndola, freezer, caixa com esteira, carrinho de compras, máquina de milkshake, chapa, torneira de chope,
  alvo de dardos, bicicleta ergométrica, supino, saco de pancada, chuveiro, catraca, máquina de escrever,
  pilha de jornal, sacos de ração, barril, estante alta de armazém, porta de enrolar, mesa de dobrar, secadora,
  gato.
- **Objetos de cima de móvel (~20)**: prato com comida, copo, garrafa, vela, computador pequeno, papéis,
  abajur, telefone, livro, revista, fruteira, cafeteira, caixa registradora, sinete, vaso pequeno, prancheta,
  caneca, cinzeiro, rádio, flores.
- **Itens de parede (~18)**: seção 8.
- **Pisos (16 novos) e paredes (15 estilos)**: seção 8.
- **Personagem**: quadros de sentado, deitado, trabalhando, exercitando e dançando; camadas de detalhe e chapéu
  do uniforme.

## 14. Testes

- `test_plan_parser.gd` (novo): formato (larguras iguais, letras com legenda, peças retangulares), peças de
  várias células, itens de parede e de cima de móvel, rotas, espelhamento, itens opcionais.
- `test_interior_layout.gd` (reescrito): para os 25 tipos e 20 ids cada — tamanho dentro das 3 classes,
  porta de saída, `unreachable()` vazio, toda zona de serviço do tipo presente, pelo menos um funcionário,
  planta única por tipo (assinatura das grades diferente entre tipos), escala (cama ≤ 80x80 px etc.).
- `test_character.gd` / `test_sprites.gd`: uniforme por prédio + papel (hospital todo branco, delegacia azul,
  presos laranja, pacientes azul-claro), novos quadros de postura.
- `test_npc.gd`: atividades (`patrol` anda só entre pontos da rota e não sai do cômodo; `sit`/`lie` não colidem
  com o próprio móvel; `post` fica no lugar).
- `test_conversation.gd`: falas por papel.
- `test_services.gd`, `test_scenes.gd`, `test_pickups_and_shops.gd`, `test_phase6.gd`: atualizados para as
  novas posições vindas do layout (a interface pública é a mesma).

## 15. Entrega em etapas

1. **Motor + 5 plantas de referência**: leitor, pisos e paredes com face, nova escala de móveis, uniformes por
   prédio, posturas `post`/`sit`/`lie`/`patrol`; plantas da **casa do agente, hospital, delegacia, bar e casa**.
   Capturas para o usuário aprovar o estilo antes de seguir.
2. **As outras 20 plantas** com a arte que pedirem, atividades `work`/`exercise`/`dance`.
3. **Falas por papel**, variações de paleta e itens opcionais em todas, capturas finais, documentação
   (`docs/redesign-fase-7.md`, README, changelog, gdd).

## 16. Decisões que ficam com quem constrói

- Desenho pixel a pixel de cada móvel, piso, parede e postura, dentro da paleta e das medidas da seção 6.
- Disposição exata de cada planta, seguindo a seção 11.
- Altura exata da face da parede (24 px proposta) se a leitura ficar melhor com 16 ou 32.
- Velocidade e pausas das rondas.
