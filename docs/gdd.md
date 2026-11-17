# GDD — Game Design Document (v0.1)

> Documento vivo. Toda decisão de design nova entra aqui; o que já está implementado
> aponta para o doc técnico correspondente. Título: **Agente ZERO B**, o agente secreto de 0 bits
> (a piada do nome está no subtítulo da tela de título: "O AGENTE DE 0 BITS").

## 1. Visão geral

Jogo 2D de mundo aberto em visão de cima, com humor e liberdade de *Retro City Rampage*
e a estrutura de missões dos GTAs clássicos. Em vez de bandido, o jogador é um
**agente secreto que combate o crime**.

- **Gênero:** ação/RPG de mundo aberto, top-down, pixel art
- **Plataformas:** PC (Windows) primeiro; depois browser (HTML5) e mobile
- **Jogadores:** solo, co-op local (split screen) e co-op online com amigos
- **Controles:** teclado ou gamepad

## 2. Pilares

1. **Combater o crime, não cometê-lo.** Nada de roubar carros ou civis como mecânica central.
2. **Mundo variado e explorável:** cidade, campo, rios, barcos.
3. **Mundo dentro do mundo:** prédios entram em cenas próprias, com conteúdo e escala diferente da fachada.
4. **Jogar junto:** co-op local e online são parte do núcleo, não extra.
5. **Tom leve e retrô:** humor, referências e visual pixel art.

## 3. Premissa e papel do jogador

Agente de uma agência secreta que investiga e desmantela organizações criminosas.
Loop de jogo previsto:

1. Receber missão (briefing no QG ou por telefone)
2. Investigar: interrogar, vigiar, coletar pistas em prédios e áreas abertas
3. Agir: infiltrar, perseguir, combater, prender (preferência por prender/neutralizar)
4. Entregar resultado e ganhar progressão (equipamentos, veículos, gadgets, rank)

**Direção (14/11):** *meio espião, meio polícia*. O agente tem missões da agência, mas **pode combater o crime quando quiser**: andando pela cidade, um crime pode acontecer diante dele e ele decide ajudar. Ferramenta central: o **scanner**, usado nas pessoas para descobrir se escondem algum crime. Detalhes na seção 6.

**Tom:** paródia de espionagem (filmes de agente secreto exagerados, gadgets absurdos, vilões caricatos).
**Época:** anos 80 (neon, carros quadrados, espião de filme de ação).

**Violência:** armas **letais** são permitidas. Para manter o tema de combater o crime:

- Matar **inocentes tira pontos** (-100, já implementado em `Score`).
- Matar **criminosos** dá pontos (+50). Pontos podem ficar negativos.
- Futuro: prender vale mais que matar; "procurado" invertido (ordem pública) para quem mata inocentes.

**Campanha (aprovada em 14/11, não implementada):** 12 horas em 5 atos; a agência é o Departamento de
Assuntos Discretos, o rival aparente é o Sindicato e a vilã é a Central. Ver [historia.md](historia.md).
Dois modos de jogo: **Campanha** e **Livre** (patentes desbloqueadas, todas as armas à venda, XP do zero).
Mundo **sempre procedural**: a história usa papéis resolvidos pela seed, sem mapa fixo. Save automático,
sem slots. Derrota: perde dinheiro e acorda no hospital. Etapas em [roteiro-jogo.md](roteiro-jogo.md).

**Planejado (decidido em 14/11):** 15 armas com munição limitada, barra de itens de 8 espaços no lugar das
duas mãos, inventário de 16 espaços com baú, e cinco atributos (Força, Destreza, Vitalidade, Inteligência,
Carisma). Ver [armas-e-inventario.md](armas-e-inventario.md).

## 4. Mundo

### 4.1 Regiões

| Região | Descrição | Status |
|---|---|---|
| Cidade | Grade 12x12 de quarteirões, ruas com calçadas e 2 avenidas, 6 bairros, ~185 prédios de 22 tipos com nome próprio (inclui 7 lojas), parques | **Feito** |
| Campo | Estrada de terra, fazendas (uma é loja), plantações, árvores | **Feito** (básico) |
| Rios e lagos | Água atravessável só por barco/ponte | Planejado |
| Litoral/portos | Docas, barcos maiores | Ideia |

### 4.2 Escala

- Cidade: **quarteirão de 560 px**, rua de 200 px (asfalto 140 + 2 calçadas de 30), lote de 360 px; prédios de formatos variados dentro do lote.
- Jogador: 24 px.
- Interiores: do tamanho da tela ou pouco maiores (1280x736, 1536x864 ou 1792x1024 px), com móveis na escala do
  personagem. A proporção externa **não** é a interna.

### 4.3 Mundo grande ou infinito

Decisão: **mundo finito e grande** (hoje 13440x6720 px, 2 regiões). Ver [mundo-grande.md](mundo-grande.md). Plano: **dividir em
chunks carregados sob demanda**, com cidades desenhadas/geradas por seed e campo/rios
procedurais. Mundo infinito fica como possibilidade futura.

### 4.4 Interiores

Entrar em um prédio troca a cena: o jogador aparece em uma sala grande, com móveis e
uma porta de saída. Ao sair, reaparece na calçada, em frente à porta por onde entrou.
O mundo de fora **continua lá**: o carro deixado na porta, os bandidos e os NPCs ficam onde estavam
(a rua fica congelada enquanto o jogador está dentro; o relógio do jogo segue andando).
Entrar e sair exige apertar **E** diante da porta (aparece a instrução no canto da tela). Estado atual: todos os prédios (cidade e fazendas) têm interior, gerado por seed do id do prédio
(ver [prototipo-02-interiores.md](prototipo-02-interiores.md)).

**Fase 7 (feito):** cada um dos 25 interiores tem uma **planta autoral** em mapa de texto, única e característica,
com piso e paredes do lugar, móveis na escala do personagem e NPCs de uniforme que fazem algo (atendem, fazem ronda,
sentam, deitam, trabalham, dançam, se exercitam). No QG, a passagem secreta da lavanderia abre com E. Ver
[redesign-fase-7.md](redesign-fase-7.md).

Planejado: falas por papel, itens, pistas, cofres, andares/escadas.

## 5. Veículos

**Carro:** feito (os dirigíveis são os esportivos pretos da agência; entrar/sair com E, acelerar, frear, ré, curvas, colisão com chute, auxílio de direção para andar reto). Trânsito com IA (10 carros na cidade, não roubáveis). Planejado: motos,
barcos (rios/litoral), talvez helicóptero, derrapagem, dano.
Veículos entram como **recurso da agência** (garagem, upgrades), não como roubo.

## 6. Crimes, scanner, NPCs e combate

**Feito (protótipo 04):** tiro, vida, NPCs inocentes e criminosos, pontuação (-100 inocente, +50 criminoso),
carros de trânsito. Ver [prototipo-04-combate-npcs-transito.md](prototipo-04-combate-npcs-transito.md).

**Feito (protótipo 05):** NPCs com nome e card de personalidade (conversa com F e perguntas), inventário (I)
com itens nas duas mãos, ficha do jogador (C) com XP e atributos. Ver
[prototipo-05-mira-inventario-ficha.md](prototipo-05-mira-inventario-ficha.md).

**Feito (protótipo 06):** crimes que dependem da região (tipos, frequência e recompensas próprios em Cidade e Campo),
avisos de crime em andamento, resolução com bônus; itens no chão, dinheiro e lojas. Ver
[prototipo-06-cidade-lojas-crimes.md](prototipo-06-cidade-lojas-crimes.md).

**Feito (Fase 2 do redesenho):** cidade com contexto. Bairros, tipos de prédio, nomes de prédios, ruas e bairros,
NPCs com trabalho e moradia em prédios reais (citados na conversa) e crimes que dependem do bairro e do tipo de
prédio próximo. Ver [redesign-fase-2.md](redesign-fase-2.md).

**Feito (Fases 3 e 4 do redesenho):** interiores por tipo de prédio com serviços úteis (hotel, restaurante, hospital,
delegacia, banco, bar, boate, QG, oficina, cinema, academia), NPCs com papel dentro dos prédios, dia e noite com
relógio, luzes, prédios que abrem e fecham, menos gente na rua à noite e crimes diferentes. Ao ser derrotado o agente
perde metade do dinheiro em mãos e acorda no hospital. Ver [redesign-fase-3.md](redesign-fase-3.md) e
[redesign-fase-4.md](redesign-fase-4.md).

**Planejado (direção "espião e polícia"):**

- **NPCs com identidade (aprofundar):** rotina, segredos e relações, para o jogo ter tom pessoal e o jogador
  se importar com quem encontra.
- **Scanner:** ferramenta que lê uma pessoa e revela pistas (nervosismo, objetos, ficha, ligações com
  organizações). Pode apontar um criminoso escondido ou inocentar alguém, e o resultado deve combinar com o
  card de personalidade.
- **Crimes dinâmicos:** eventos que acontecem pela cidade sem aviso (assalto, briga, fuga, sequestro). O jogador
  intervém quando quiser; ignorar também é uma escolha, com consequências.
- **Missões da agência** convivem com a vida livre na cidade.
- Matar inocente continua custando pontos; prender e resolver crimes devem valer mais que matar.

**Direções gerais:**

- Armas não letais (taser, dardos) e letais, com preferência de design por prender
- Gadgets de espionagem (escuta, hackear, disfarce)
- Rank na agência, equipamentos e veículos liberados por missões

**Regra de design dos atributos:** nenhum atributo pode ser "enfeite". Cada um deve ter efeito claro em algo que
o jogador faz. Hoje: Velocidade (andar), Força (dano), Vitalidade (vida), Inteligência (XP e leitura da
personalidade dos NPCs, base do futuro scanner). Atributo novo só entra com uso definido.

**Itens:** armas (pistola, escopeta, taser não letal), ferramentas (kit médico) e escudo, equipados na mão
esquerda e na direita. O taser reflete o tema "meio polícia": atordoar um criminoso pontua e não custa a
moral do agente.

## 7. Multiplayer

- **Co-op até 4** na campanha do anfitrião; convidados são agentes temporários, cada um com inventário próprio.
  Limite por plataforma: desktop 4, browser 2, mobile 1. Online com um jogador hospedando.
- **Split screen local:** uma câmera por jogador via `SubViewport`.
  Input já separado por jogador (`p1_*`, `p2_*`) — ver [arquitetura.md](arquitetura.md).
- **Online:** co-op com amigos; transporte WebSocket/WebRTC para funcionar no browser.
- Mundo determinístico por seed: todos geram o mesmo mapa.
- Questão aberta: jogadores em interiores diferentes ao mesmo tempo (câmeras/cenas separadas).

## 8. Arte e áudio

- Pixel art 2D, filtro *nearest*, **gerada por código** (sem arquivos de imagem): paleta fixa de 32 cores,
  pixel lógico de 2 px, contorno escuro e luz a noroeste. Ver [redesign-fase-1.md](redesign-fase-1.md).
- Referência visual: *Retro City Rampage* (cores vivas, humor), não cópia de assets.
- Áudio: a definir (chiptune/retrô).
- **Redesenho em andamento:** Fase 1 (mundo externo, personagens, carros, HUD) feita. Faltam bairros,
  prédios com finalidade, interiores por tipo e ciclo de dia e noite. Design em
  [redesign-visual.md](redesign-visual.md); lista de trabalho em [redesign-roteiro.md](redesign-roteiro.md).

## 9. Requisitos técnicos

- Godot 4.7.2 standard, GDScript, renderer GL Compatibility
- Toda feature acompanhada de testes automatizados ([testes.md](testes.md))
- Toda mudança documentada em `docs/`

## 10. Roadmap

| # | Marco | Status |
|---|---|---|
| 1 | Jogador anda pela cidade | Feito |
| 2 | Prédios maiores + interiores com cena própria | Feito |
| 3 | Testes automatizados | Feito |
| 4 | Carro dirigível (entrar/sair com E) | Feito |
| 4b | Mapa grande com 2 regiões (Cidade e Campo) | Feito |
| 5 | Split screen 2 jogadores | Adiado (bem à frente) |
| 6a | NPCs, combate e trânsito básicos | Feito |
| 6b | NPCs com nome e card de personalidade | Feito (básico) |
| 6b2 | Inventário, ficha, atributos e XP | Feito |
| 6c | Crimes dinâmicos por região | Feito (básico) |
| 6d | Scanner, vítimas e criminosos disfarçados | Planejado |
| 6e | Itens no chão, dinheiro e lojas | Feito |
| 6f | Calçadas, população maior, prédios variados | Feito |
| 7 | Sistema de missões da agência | Planejado |
| 8 | Chunks + campo + rios + barcos | Planejado |
| 9 | Multiplayer online | Planejado |
| 10 | Arte pixel art e áudio | Arte: em andamento (Fases 1 a 4 de 5 feitas); áudio: planejado |

## 11. Questões em aberto

- Nome do jogo
- Escala final do mundo (hoje 13440x6720 px; rios e litoral ainda não existem)
- Idiomas: decidido, português e inglês
- Demais decisões em aberto: tabela ao final de [roteiro-jogo.md](roteiro-jogo.md)
