# Roteiro do jogo completo

> **Plano aprovado pelo autor; etapa E1 feita (Fases 2 a 4 do redesenho), exceto o item 1.2.** Lista as etapas que levam do protótipo atual ao
> jogo completo. Cada item tem status; atualize a coluna na mesma mudança em que o item avançar.
> A história está em [historia.md](historia.md). O redesenho visual tem roteiro próprio em
> [redesign-roteiro.md](redesign-roteiro.md).

**Status possíveis:** `Pendente` · `Em andamento` · `Feito` · `Adiado` · `Cancelado`

## Visão

- Campanha de cerca de 12 horas para 1 jogador, jogável em co-op com até 4.
- Mundo **sempre procedural**: a campanha roda em qualquer seed; o mapa oficial é a seed canônica.
- Modo livre (sem história) em mapa aleatório.
- Alvo: desktop, browser e mobile.

## Resumo das etapas

| Etapa | Assunto | Depende de | Status |
|---|---|---|---|
| E1b | Redesenho, Fase 6 (casas, casa do agente, mapa com pontos, interiores completos) | E1 | Pendente |
| E1 | Redesenho, Fases 2 a 4 (cidade com contexto, interiores, dia e noite) | — | Feito (falta o item 1.2) |
| E2 | Base: menu inicial, pausa, save, opções | — | Parcial (menu inicial e pausa na Fase 5; faltam save e opções) |
| E3 | Split-screen local (até 4) | E2 | Pendente |
| E4 | Corpo a corpo, armas e atributos | — | Pendente |
| E5 | Percepção e scanner | E4 | Pendente |
| E6 | Quests e guia do jogador | E1 | Pendente |
| E7 | Conversa nova com retrato | E1, E5 | Pendente |
| E8 | Campanha (Atos 1 a 5) | E1 a E7 | Pendente |
| E9 | Mapas aleatórios e modo livre | E2, E8 | Pendente |
| E10 | Co-op online (até 4) | E3, E8 | Pendente |
| E11 | Áudio | — | Pendente |
| E12 | Acabamento (inclui a Fase 5 do redesenho) e publicação | todas | Pendente |

## E1 — Redesenho, Fases 2 a 4

Itens e status em [redesign-roteiro.md](redesign-roteiro.md). Acréscimos que a campanha exige:

| # | Item | Status |
|---|---|---|
| 1.1 | Gerador garante os tipos de prédio obrigatórios da história em qualquer seed (lavanderia/QG, banco, boate, delegacia, oficina, bar, jornal) | Feito |
| 1.2 | Campo garante uma fazenda de ensaio e um silo | Pendente |
| 1.3 | Novo tipo de prédio: redação do jornal | Feito (fachada, nome e interior) |

## E2 — Base: menu, pausa, save, opções

| # | Item | Status |
|---|---|---|
| 2.1 | Menu inicial: nova campanha, continuar, modo livre, co-op, opções, sair | Pendente |
| 2.2 | Nova campanha: escolha entre seed canônica e seed aleatória | Pendente |
| 2.3 | Pausa de verdade (hoje os painéis não param o mundo); em co-op não pausa | Pendente |
| 2.4 | Save automático, sem slots (um por modo de jogo): seed + estado (ficha, inventário, dinheiro, quests, história, relógio, contatos, inocentes mortos). O mundo é regenerado pela seed, não gravado | Pendente |
| 2.5 | Save funciona no browser (`user://`) | Pendente |
| 2.6 | Versão no arquivo de save e migração entre versões | Pendente |
| 2.7 | Opções: volume, tela cheia, remapeamento de teclas | Pendente |
| 2.8 | Suporte a gamepad nas ações `p{N}_*` | Pendente |

## E3 — Split-screen local (até 4)

| # | Item | Status |
|---|---|---|
| 3.1 | Entrada e saída de jogadores a qualquer momento | Pendente |
| 3.2 | Tela dividida em 2, 3 ou 4 (um `SubViewport` por jogador), câmera e HUD por jogador | Pendente |
| 3.3 | Mira para jogadores com gamepad (hoje só mouse) | Pendente |
| 3.4 | Painéis (inventário, ficha, conversa, loja) por jogador, sem travar os outros | Pendente |
| 3.5 | Carro com mais de um ocupante | Pendente |
| 3.6 | Medição de desempenho com 4 telas no browser | Pendente |

## E4 — Corpo a corpo, armas e atributos

| # | Item | Status |
|---|---|---|
| 4.1 | Punhos e cassetete (curto alcance); o jogo começa sem arma de fogo | Pendente |
| 4.2 | Armas e gadgets desbloqueados pela história (15 armas, tabela em `armas-e-inventario.md`) | Pendente |
| 4.9 | Munição limitada: 6 tipos, pente, recarga, reserva, venda em loja e loot | Pendente |
| 4.10 | Barra de itens (8 espaços) no lugar de mão esquerda/direita; ação secundária no botão direito | Pendente |
| 4.11 | Itens de uso na barra: kit médico, comida, energético | Pendente |
| 4.12 | Menu único com abas (inventário, ficha, missões, mapa, opções); loja e conversa redesenhadas | Pendente |
| 4.16 | Ícone em pixel art para cada item; inventário, loja e baú em grade navegável, com texto só no item selecionado | Pendente |
| 4.3 | Gadgets: disfarce, gazua, bomba de fumaça, rastreador, óleo na pista | Pendente |
| 4.4 | Cinco atributos com teto de 5: Carisma novo, Velocidade absorvida pela Destreza, Força só no corpo a corpo (migrar fichas e testes atuais) | Pendente |
| 4.13 | Inventário de 16 espaços (barra 8 + mochila 8), baú no apartamento e no QG, soltar item no chão | Pendente |
| 4.14 | Ruído: tiros alertam inimigos e pedestres em um raio; silenciador e faca não alertam | Pendente |
| 4.15 | Recarga na tecla R (`p{N}_reload`) | Pendente |
| 4.5 | Patentes ligadas ao XP, que liberam missões | Pendente |
| 4.6 | Consequência por matar inocentes além dos pontos (ficha limpa/suja; caçado pela agência) | Pendente |
| 4.7 | Consequência por ser derrotado (decisão D7 do redesenho) | Pendente |
| 4.8 | Prender criminoso atordoado e entregar na delegacia | Pendente |

## E5 — Percepção e scanner

| # | Item | Status |
|---|---|---|
| 5.1 | Leitura de NPC sem conversar, em 5 níveis por Inteligência (nome, traço, arma, intenção, mentira) | Pendente |
| 5.2 | Scanner como item que soma níveis de leitura | Pendente |
| 5.3 | Criminosos à paisana, indistinguíveis sem percepção | Pendente |
| 5.4 | Intenção de crime visível antes de o crime começar | Pendente |

## E6 — Quests e guia do jogador

| # | Item | Status |
|---|---|---|
| 6.1 | Sistema de quests em lógica pura (`RefCounted`): objetivos, etapas, recompensa, falha | Pendente |
| 6.2 | Quest dinâmica: o aviso de crime vira quest com cronômetro | Pendente |
| 6.3 | Seta de objetivo no HUD e marcador no mapa | Pendente |
| 6.4 | Diário de quests (ativas, concluídas, falhas) | Pendente |
| 6.5 | Rádio da Central: mensagens curtas que anunciam e comentam as quests | Pendente |
| 6.6 | Quests falsas (emboscadas) para os Atos 3 e 4 | Pendente |
| 6.7 | Mapa ou minimapa com bairros, ícones de prédio e objetivos (item 5.7 do redesenho) | Pendente |
| 6.8 | Quests de contatos e rumores de bar | Pendente |

## E7 — Conversa nova com retrato

| # | Item | Status |
|---|---|---|
| 7.1 | Retrato do NPC gerado por código a partir da seed, coerente com o sprite | Pendente |
| 7.2 | Opções por contexto no lugar das 4 perguntas fixas: rumor, interrogar, persuadir, intimidar, recrutar | Pendente |
| 7.3 | Testes de atributo na conversa (Carisma, Força, Inteligência) | Pendente |
| 7.4 | Toda conversa pode render algo: pista, quest, desconto ou contato | Pendente |
| 7.5 | Contatos: NPCs recrutados que passam a dar rumores e ajuda | Pendente |
| 7.6 | Diálogos de história com falas fixas e nomes gerados pela seed | Pendente |

## E8 — Campanha

| # | Item | Status |
|---|---|---|
| 8.1 | Âncoras de história: papéis resolvidos para prédios do mapa pela seed | Pendente |
| 8.2 | Motor de missões de história (sobre o sistema de quests) | Pendente |
| 8.3 | Ato 1: 5 missões, tutorial embutido | Pendente |
| 8.4 | Ato 2: 4 chefes, 12 missões, ordem livre | Pendente |
| 8.5 | Ato 3: 6 missões, a virada (perda do carro, da loja e da Central confiável) | Pendente |
| 8.6 | Ato 4: 7 missões, invasão da lavanderia | Pendente |
| 8.7 | Ato 5: 5 missões, a cidade controlada pela Central, o silo | Pendente |
| 8.8 | Interiores fixos de história: subsolo do QG, celeiro de ensaio, silo | Pendente |
| 8.9 | Três finais e créditos | Pendente |
| 8.10 | Pós-jogo | Pendente |
| 8.11 | Teste: a campanha é concluível em várias seeds (todas as âncoras resolvem e são alcançáveis) | Pendente |

## E9 — Mapas aleatórios e modo livre

| # | Item | Status |
|---|---|---|
| 9.1 | Modo livre: mundo aberto sem história, com quests dinâmicas; patentes desbloqueadas e todas as armas à venda, XP e atributos do zero | Pendente |
| 9.2 | Parâmetros de geração: tamanho da cidade, proporção de campo | Pendente |
| 9.3 | Seed visível e digitável, para compartilhar mapas | Pendente |
| 9.4 | Variedade de terreno (decisão D4 do redesenho: rios, pontes, litoral) | Pendente |

## E10 — Co-op online (até 4)

| # | Item | Status |
|---|---|---|
| 10.1 | Escolha de rede que funcione no browser (WebRTC ou WebSocket) | Pendente |
| 10.2 | Anfitrião com autoridade sobre o mundo; convidados entram por código de sala | Pendente |
| 10.3 | Sincronização: jogadores, NPCs, carros, projéteis, quests, relógio | Pendente |
| 10.4 | Campanha do anfitrião; progresso dos convidados conforme decisão em aberto | Pendente |
| 10.5 | Dificuldade escala com o número de jogadores | Pendente |
| 10.6 | Online e split-screen combinados (2 em uma máquina + 2 em outra) | Pendente |

## E11 — Áudio

| # | Item | Status |
|---|---|---|
| 11.1 | Decisão: som gerado por código ou abrir exceção à regra de "sem assets externos" | Pendente |
| 11.2 | Efeitos: tiro, soco, passos, motor, sirene, interface | Pendente |
| 11.3 | Música por bairro e por momento (perseguição, noite) | Pendente |
| 11.4 | Voz da Central (chiado de rádio, sem dublagem) | Pendente |

## E12 — Acabamento e publicação

| # | Item | Status |
|---|---|---|
| 12.1 | Fase 5 do redesenho (efeitos, transições, telas no estilo novo) | Pendente |
| 12.2 | Controles de toque para mobile | Pendente |
| 12.3 | Exportação web e teste em navegadores | Pendente |
| 12.4 | Balanceamento: economia, XP, dificuldade, duração de 12 horas | Pendente |
| 12.5 | Idiomas (decisão em aberto) | Pendente |

## Decisões em aberto

| # | Decisão | Status |
|---|---|---|
| J1 | Campanha para 1 jogador, co-op até 4 | Decidido |
| J2 | Mundo sempre procedural; campanha por âncoras de papel | Decidido: procedural sempre, sem mapa fixo |
| J3 | História em 5 atos, com a Central como vilã | Decidido: aprovada |
| J4 | Progresso dos convidados no co-op | Decidido: agentes temporários, cada um independente, entram com inventário vazio; itens passam ao serem soltos no chão; dinheiro recolhido é creditado inteiro a todos; baú comum no QG |
| J5 | Criminosos à paisana (necessário para a percepção ter valor) | Decidido: sim |
| J6 | Derrota | Decidido: perde dinheiro e acorda no hospital |
| J7 | Save | Decidido: automático, sem slots; um save por modo de jogo |
| J8 | A campanha pode ser terminada sem matar ninguém? | Decidido: não precisa ser possível |
| J9 | Áudio | Decidido: tentar gerar tudo por código |
| J10 | Rede | Decidido: um jogador hospeda (WebRTC, com servidor de sinalização) |
| J11 | Idiomas | Decidido: português e inglês |
| J12 | Ordem das etapas | Decidido: a ordem da tabela acima (redesenho primeiro, online por último) |
| J13 | Número de jogadores por plataforma | Decidido: desktop 4, browser 2, mobile 1 |
| J14 | Dois modos de jogo: **Campanha** e **Livre**. No Livre as patentes já vêm desbloqueadas e qualquer arma pode ser comprada, mas XP e atributos começam do zero | Decidido |
| J15 | Armas, munição e barra de itens | Decidido: munição limitada e comprada; barra de itens no lugar das duas mãos; detalhes e pontos em aberto (A1 a A6) em `armas-e-inventario.md` |
| J16 | Lista final de atributos | Decidido: Força, Destreza (absorve a Velocidade), Vitalidade, Inteligência, Carisma; teto de 5 pontos cada; Força não aumenta mais o dano de armas de fogo |
