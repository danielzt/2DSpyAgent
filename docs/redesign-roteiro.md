# Roteiro do redesenho visual e do mundo com contexto

> Lista de trabalho do redesenho. **Fases 0 a 5 concluídas; a Fase 6 (casas, mapa com pontos e interiores completos) é a próxima.** Cada item tem um status;
> atualize a coluna na mesma mudança em que o item avançar.
> O design detalhado (paleta, resolução, valores concretos) está em
> `docs/redesign-visual.md`.

**Status possíveis:** `Pendente` · `Em andamento` · `Feito` · `Adiado` · `Cancelado`

## Objetivo

Redesenho visual completo do jogo e reformulação da geração do mundo para que tudo tenha
contexto: cada prédio com finalidade, interiores com função, bairros, dia e noite.

Referência de estilo: *Retro City Rampage* (pixel art 8/16-bit, cores vivas, humor, cidade
densa e cheia de detalhe). É referência de clima: não copiar sprites, personagens, nomes
ou mapas de nenhum jogo.

Todas as regras do `AGENTS.md` continuam valendo (testes e docs na mesma mudança, sem
assets externos, GDScript, GL Compatibility, lógica pura em `RefCounted` com seed fixa,
`InteractZone`, input por jogador, tema de agente secreto sem mecânica de roubo).

## Resumo das fases

| Fase | Assunto | Status |
|---|---|---|
| 0 | Direção de arte e plano | Feito |
| 1 | Base visual do mundo externo | Feito (aguardando avaliação do autor) |
| 2 | Cidade com contexto | Feito (aguardando avaliação do autor) |
| 3 | Interiores com finalidade | Feito (aguardando avaliação do autor) |
| 4 | Dia e noite | Feito (aguardando avaliação do autor; desempenho noturno acima da meta) |
| 5 | Acabamento | Feito (aguardando avaliação do autor) |
| 6 | Casas, casa do agente, mapa com pontos e interiores completos | Pendente (pedido do autor em 15/11) |

## Como trabalhar

Regras de processo. Valem para todas as fases; o status indica se a regra já está em uso.

| # | Regra | Status |
|---|---|---|
| T1 | Trabalhar em fases. Na Fase 0 entregar só o design (`docs/redesign-visual.md`) e parar para aprovação. Depois, uma fase por vez, parando ao fim de cada uma | Em uso |
| T2 | Ao fim de cada fase: suíte inteira com 0 falhas | Em uso |
| T3 | Ao fim de cada fase: docs atualizados (README, changelog, gdd) | Em uso |
| T4 | Ao fim de cada fase: capturas de tela do jogo rodando (dia e noite quando existir) salvas em `docs/img/`. Abrir o jogo de verdade para capturar; não julgar o visual só pelo código | Em uso |
| T5 | Manter os saves de estado e as mecânicas atuais funcionando (carro, combate, NPCs, crimes, lojas, inventário, ficha). Teste quebrado por mudança intencional é atualizado e explicado | Em uso |
| T6 | Alvo inclui browser e mobile: gerar texturas uma vez e guardar em cache, evitar `_draw` pesado por frame | Em uso |
| T7 | Medir o FPS antes e depois de cada fase | Em uso |

## Fase 0 — Direção de arte e plano

Entrega: `docs/redesign-visual.md`, com cada ponto proposto e justificado. Para aqui até aprovação.

| # | Item | Status |
|---|---|---|
| 0.1 | Paleta fixa (cerca de 32 cores) com rampas para dia e noite | Feito |
| 0.2 | Resolução e tamanho do pixel. Hoje: viewport 1280x720, stretch `canvas_items`, jogador de 24 px. Decidir entre manter as unidades do mundo com "pixel lógico" maior ou baixar a resolução base com escala inteira, mostrando o impacto nos testes e nas constantes de layout | Feito |
| 0.3 | Produção da arte por código: fábrica de sprites/tiles (`Image` -> `ImageTexture` em cache) em vez de retângulos soltos, com contorno escuro, sombra projetada e 2-3 tons por material | Feito |
| 0.4 | Lista de tipos de prédio com valores concretos | Feito |
| 0.5 | Lista de bairros com valores concretos | Feito |
| 0.6 | Lista de modelos de interior com valores concretos | Feito |
| 0.7 | O que muda e o que é preservado em `city_layout.gd`, `country_layout.gd`, `interior_layout.gd` e `world.gd` | Feito |
| 0.8 | Aprovação do design pelo autor | Feito (D1 e D2 aprovadas) |

## Fase 1 — Base visual do mundo externo

Detalhes do que foi feito: [redesign-fase-1.md](redesign-fase-1.md).

| # | Item | Status |
|---|---|---|
| 1.1 | Ruas: asfalto com textura, faixas, faixa de pedestre nos cruzamentos, meio-fio, bueiros, calçada com padrão | Feito |
| 1.2 | Avenidas mais largas que ruas comuns | Feito na Fase 2 |
| 1.3 | Prédios com volume em vista de cima: telhado com detalhes (caixa d'água, ar condicionado, claraboia) | Feito |
| 1.4 | Fachada sul visível com porta, janelas, toldo e letreiro | Feito |
| 1.5 | Sombra projetada dos prédios no chão | Feito |
| 1.6 | Mobiliário urbano: postes, semáforos, bancos, lixeiras, hidrantes, pontos de ônibus, árvores de calçada, bancas | Feito (semáforos fixos; bancos só nos parques) |
| 1.7 | Parques com caminhos, lago, canteiros | Feito |
| 1.8 | Personagens com sprite legível e animação de andar em 4 direções | Feito |
| 1.9 | Jogador, inocentes e criminosos distinguíveis sem depender só de cor | Feito |
| 1.10 | Carros com modelos e cores variados, faróis e lanternas | Feito |
| 1.11 | Campo: terra, plantações com fileiras, cercas, celeiros, árvores com copa e sombra | Feito |
| 1.12 | HUD redesenhado no mesmo estilo (fonte pixel desenhada por código ou fonte padrão com moldura retrô) | Feito |
| 1.13 | HUD com relógio, nome do bairro e da rua | Parcial: bairro e rua feitos na Fase 2; relógio na Fase 4 |
| 1.14 | Fechamento da fase: testes, docs, capturas em `docs/img/`, FPS antes/depois | Feito |

## Fase 2 — Cidade com contexto

Detalhes do que foi feito: [redesign-fase-2.md](redesign-fase-2.md). Nos tipos de prédio, "Feito" quer dizer que o tipo existe na cidade com nome, fachada e letreiro; interior e serviço são da Fase 3.

| # | Item | Status |
|---|---|---|
| 2.1 | Bairros gerados por seed: centro comercial, residencial, vida noturna, industrial/armazéns, bairro nobre, cívico (delegacia, hospital, prefeitura) | Feito |
| 2.2 | Cada bairro com paleta de fachadas, densidade, altura e mistura de tipos próprias | Feito |
| 2.3 | Tabela única de tipos de prédio em `scripts/world/building_defs.gd`. Por tipo: nome, bairros onde aparece, quantidade mínima/máxima, aparência da fachada, letreiro, modelo de interior, NPCs que trabalham lá, horário de funcionamento e serviço oferecido | Feito |
| 2.4 | Lojas atuais (`armory`, `pharmacy`, `agent_store`, armazém rural) viram entradas da tabela, sem perder o que vendem | Feito |
| 2.5 | Nome próprio por prédio, gerado por seed (com humor), mostrado no letreiro e no HUD ao chegar perto da porta | Feito |
| 2.6 | Ruas e bairros com nome | Feito |
| 2.7 | NPCs ligados ao mundo: a profissão em `npc_identity.gd` aponta para um prédio real onde a pessoa trabalha | Feito |
| 2.8 | NPCs têm um prédio onde moram | Feito |
| 2.9 | Trabalho e moradia aparecem na conversa | Feito |
| 2.10 | Crimes consideram o bairro e o tipo de prédio próximo (assalto perto de banco, briga perto de bar), mantendo os perfis por região existentes | Feito |
| 2.11 | Fechamento da fase: testes, docs, capturas em `docs/img/`, FPS antes/depois | Feito |

### Tipos de prédio iniciais

| Tipo | Status |
|---|---|
| Hotel | Feito |
| Restaurante | Feito |
| Lanchonete | Feito |
| Bar | Feito |
| Boate | Feito |
| Loja de equipamentos do agente (`agent_store`, já existe como loja) | Feito |
| Loja de armas (`armory`, já existe como loja) | Feito |
| Farmácia (`pharmacy`, já existe como loja) | Feito |
| Mercado | Feito |
| Banco | Feito |
| Delegacia | Feito |
| Hospital | Feito |
| Oficina | Feito |
| Posto de gasolina | Feito |
| Cinema | Feito |
| Academia | Feito |
| Escritório | Feito |
| Prédio residencial | Feito |
| Casa | Feito |
| Armazém | Feito |
| QG da agência disfarçado de negócio comum (piada de espionagem) | Feito |

## Fase 3 — Interiores com finalidade

Detalhes do que foi feito: [redesign-fase-3.md](redesign-fase-3.md).

| # | Item | Status |
|---|---|---|
| 3.1 | Modelos de interior por tipo no lugar da sala única, gerados por seed do id do prédio | Feito |
| 3.2 | Planta com cômodos e paredes internas | Feito |
| 3.3 | Piso e parede próprios de cada tipo | Feito |
| 3.4 | Móveis reconhecíveis: camas e recepção no hotel, mesas e cozinha no restaurante, balcão e banquetas no bar, prateleiras na loja, celas na delegacia, macas no hospital | Feito |
| 3.5 | Tamanho do interior varia com o tipo e com o tamanho da fachada, sempre em escala maior que a externa | Feito |
| 3.6 | NPCs dentro, com papel (recepcionista, garçom, barman, vendedor, clientes) e falas coerentes com o lugar | Feito |
| 3.7 | Cada tipo oferece pelo menos uma interação útil via `InteractZone` e `p{N}_interact`, com instrução no HUD. Nenhuma interação pode ser enfeite | Feito |
| 3.8 | Residências e escritórios simples, mas com identidade (quem mora/trabalha lá) | Feito |
| 3.9 | Fechamento da fase: testes, docs, capturas em `docs/img/`, FPS antes/depois | Feito |

### Interações sugeridas

| Prédio | Interação | Status |
|---|---|---|
| Hotel | Pagar para dormir: recupera vida e avança o relógio | Feito |
| Restaurante / lanchonete | Comer cura | Feito |
| Bar | Rumores que revelam um crime ativo ou um criminoso | Feito |
| Hospital | Cura total paga | Feito |
| Delegacia | Entregar criminoso atordoado por recompensa maior | Feito |
| Banco | Guardar dinheiro | Feito |
| QG | Briefing e baú de equipamento | Parcial: briefing feito; o baú é só visual (depende do inventário de 16 espaços) |
| Oficina | Consertar/pintar o carro da agência | Parcial: pintura feita; conserto espera o dano de veículos |

## Fase 4 — Dia e noite

Detalhes do que foi feito: [redesign-fase-4.md](redesign-fase-4.md).

| # | Item | Status |
|---|---|---|
| 4.1 | Relógio do mundo em um autoload, determinístico e pronto para multiplayer | Feito |
| 4.2 | Duração do dia configurável (sugestão: 12 min reais) | Feito |
| 4.3 | Hora visível no HUD | Feito |
| 4.4 | Noite escura mas colorida e sempre legível: tinta azul/roxa saturada, nunca cinza nem preta | Feito |
| 4.5 | Piso de luminosidade: jogador, NPCs, carros e portas continuam fáceis de ver | Feito |
| 4.6 | Entardecer alaranjado e amanhecer rosado, com transição suave | Feito |
| 4.7 | Janelas dos prédios acesas à noite (padrão por seed, nem todas acesas) | Feito |
| 4.8 | Letreiros de neon por tipo de prédio | Feito |
| 4.9 | Postes com poça de luz na calçada | Feito |
| 4.10 | Faróis e lanternas dos carros | Feito |
| 4.11 | Semáforos e vitrines iluminados | Feito |
| 4.12 | Brilho aditivo barato como padrão; `Light2D` só se a medição mostrar que aguenta no GL Compatibility/browser | Feito |
| 4.13 | Interiores com iluminação própria, sem escurecer com a noite | Feito |
| 4.14 | Janelas internas mostram se é dia ou noite lá fora | Feito |
| 4.15 | Horário de funcionamento dos prédios (bar e boate à noite, banco de dia) | Feito |
| 4.16 | Menos pedestres de madrugada | Feito |
| 4.17 | Crimes diferentes e mais frequentes à noite | Feito |
| 4.18 | NPCs indo para casa | Feito |
| 4.19 | Fechamento da fase: testes, docs, capturas de dia e de noite em `docs/img/`, FPS antes/depois | Feito |

## Fase 5 — Acabamento

| # | Item | Status |
|---|---|---|
| 5.1 | Clarão e cápsula do tiro | Feito |
| 5.2 | Faísca de impacto | Feito |
| 5.3 | Poeira do carro | Feito |
| 5.4 | Marcas de pneu | Feito |
| 5.5 | Tremor leve de câmera | Feito |
| 5.6 | Transição ao entrar e sair de prédios | Feito |
| 5.7 | Minimapa ou mapa com bairros e ícones por tipo de prédio | Feito |
| 5.8 | Tela de título no estilo novo | Feito |
| 5.9 | Tela de pausa no estilo novo | Feito |
| 5.10 | Revisão geral de consistência: nenhum retângulo placeholder sobrando | Feito |
| 5.11 | Fechamento da fase: testes, docs, capturas em `docs/img/`, FPS antes/depois | Feito |

## Fase 6 — Casas, casa do agente, mapa com pontos e interiores completos

> Pedido do autor (15/11): a cidade só tem prédios, falta uma **área residencial com casas**; o
> jogador deve ter **uma casa para dormir**, achá-la no **mapa**, **marcar pontos** e ser
> **direcionado na tela**; os **interiores estão vazios** (hospital com gente de branco, delegacia,
> casa do jogador, cada tipo caprichado: com o espaço cheio, o tamanho deixa de parecer grande);
> as **ruas podem ter curvas** e ser **mais estreitas nas áreas residenciais**.

| # | Item | Status |
|---|---|---|
| 6.1 | Bairro residencial de verdade: lotes com várias casas pequenas, quintais, cercas e garagens (hoje há só `house`/`apartment` como prédios comuns) | Pendente |
| 6.2 | Ruas estreitas nos bairros residenciais (corredor e asfalto menores; ajustar calçadas, carros estacionados, trânsito e lotes) | Pendente |
| 6.3 | Ruas menos simétricas: estudo e protótipo de trechos curvos (impacto em lotes, rotas do trânsito, luzes e mapa) antes de adotar | Pendente |
| 6.4 | Casa do agente: uma casa do bairro residencial é a dele (marcada no mapa e no HUD), com porta própria | Pendente |
| 6.5 | Dentro da casa do agente: cama (dormir avança a hora e cura), baú, armário, cozinha, banheiro, mesa de trabalho; arrumada e cheia | Pendente |
| 6.6 | Mapa: marcar pontos (vários, com nome e cor), remover, mostrar no minimapa; a casa do agente já vem marcada | Feito (neblina, pontos por clique, vários pontos, minimapa) |
| 6.7 | Direção na tela: seta no HUD e distância até o ponto ativo; depois, linha-guia pela rua (rota) | Feito a seta e a distância; a rota pela rua fica para depois |
| 6.8 | Interiores densos: ocupação mínima por modelo e uniformes por papel (teste automático) | Pendente |
| 6.9 | Hospital completo: recepção, triagem, macas, quartos, UTI, farmácia, equipe de branco e pacientes | Pendente |
| 6.10 | Delegacia completa: balcão, mesas e computadores, celas com presos, sala do delegado, policiais | Pendente |
| 6.11 | Revisão dos outros 13 modelos de interior (mesmo critério de enchimento e de personagens) e da escala dos tamanhos | Pendente |
| 6.12 | Fechamento da fase: testes, docs, capturas em `docs/img/`, FPS antes/depois | Pendente |

Decisões em aberto da fase: a casa é fixa ou escolhida/comprada; ruas curvas em toda a cidade ou só
em alguns bairros (risco alto para o trânsito e para a geração dos lotes); rota automática até o ponto.

## Testes esperados (além dos existentes)

| # | Teste | Fase | Status |
|---|---|---|---|
| V1 | Geração determinística: mesma seed gera os mesmos bairros, tipos e nomes | 2 | Feito |
| V2 | Geração determinística: mesma seed gera os mesmos interiores | 3 | Feito |
| V3 | Todo tipo obrigatório existe pelo menos uma vez na cidade | 2 | Feito |
| V4 | Todo prédio tem tipo e porta acessível pela calçada | 2 | Feito |
| V5 | Todo prédio tem interior válido (sem móvel bloqueando porta ou caminho) | 3 | Feito |
| V6 | Cada interação de interior funciona via ação de input e só com o jogador na zona | 3 | Feito |
| V7 | Relógio: avanço e fases do dia | 4 | Feito |
| V8 | Horários de funcionamento | 4 | Feito |
| V9 | Cor ambiente da noite nunca abaixo do piso de luminosidade definido | 4 | Feito |
| V10 | Luzes acendem e apagam nas horas certas | 4 | Feito |

## Decisões em aberto

A resolver na Fase 0 ou antes.

| # | Decisão | Status |
|---|---|---|
| D1 | Época da paródia (anos 60/70 estilo Bond, 80/90 ou atual): define paleta, carros, letreiros e nomes | Decidido: anos 80 |
| D2 | Resolução base: manter 1280x720 com pixel lógico maior ou baixar com escala inteira | Decidido: manter 1280x720, texel de 2 px |
| D3 | Corte da lista de tipos de prédio e de interações para a primeira versão | Decidido: sem corte; cinema, academia e posto ficam (21 tipos urbanos + 2 rurais) |
| D4 | Tamanho do mundo: manter a grade 12x12 e o campo, ou incluir rios, pontes e litoral | Em vigor por omissão: manter grade 12x12 e campo |
| D5 | Duração do dia (sugestão: 12 min reais) | Em vigor por omissão: 12 min (ajustado do 24 original) |
| D6 | Avenidas: mais largas de verdade (mexe em calçadas e trânsito) ou só pintura diferente | Decidido: mais largas de verdade; 2 avenidas cruzando no centro |
| D7 | Mecânicas novas que alguns serviços exigem (perda de dinheiro ao ser derrotado, presos a entregar, item de comida, seta de alvo no HUD) | Assumido sim para as quatro, para a Fase 3 seguir (banco, delegacia, comida, seta); confirmar |
