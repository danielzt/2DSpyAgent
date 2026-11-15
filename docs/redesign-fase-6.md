# Fase 6 — Casas, casa do agente, mapa com pontos e interiores completos

Pedido do autor (15/11): o mapa deve mostrar o mundo todo, com **neblina** no que o jogador ainda não
conhece; o jogador **clica no mapa para marcar um ponto** e a tela o **direciona**; a cidade precisa
de **casas** (área residencial) e o jogador de **uma casa para dormir**; os **interiores estavam vazios**
(hospital com gente de branco, delegacia, casa do jogador); ruas menos simétricas e mais estreitas nas
áreas de casas. Roteiro: `docs/redesign-roteiro.md`, itens 6.1 a 6.12.

## Feito

### Mapa com neblina e pontos (6.6 e 6.7)

- **Neblina:** o mapa mostra o mundo inteiro; os quarteirões que o jogador ainda não explorou ficam
  sob neblina (`MapView.FOG_ALPHA`), sem ícones. A exploração é por quarteirão (grade de 560 px sobre o
  mundo todo, `PlayerProfile.explored`): o mundo marca os quarteirões a até 600 px do jogador a cada 0,5 s.
  O minimapa e a pausa usam a mesma neblina.
- **Pontos:** clique esquerdo no mapa marca um ponto (até 5, nomeados "Ponto N"; o mais antigo sai);
  clicar perto de um ponto o torna o ativo; botão direito tira o ponto. Os pontos aparecem como bandeira
  (âmbar o ativo) no mapa, no minimapa e na pausa.
- **Direção na tela:** o ponto ativo ganha uma seta ciano na borda da tela e, no alto, o nome e a distância
  em metros (1 m = 32 px). Perto do ponto (110 px) o HUD avisa "Chegou a ..." e o ponto some. Não vale dentro
  de prédios. A rota pela rua (linha-guia) ficou para depois.

### Bairro residencial com casas (6.1)

- 60% dos lotes residenciais viram **lotes de casinhas**: duas fileiras de casas de 96 a 128 px com um
  beco no meio (`CityLayout._fill_houses`). As da fileira de cima abrem a porta para o beco; o lado
  do beco fica livre (44 px) para o jogador entrar. Cerca de 90 casas novas na cidade.
- As casas nascem com o tipo `house` (campo `forced` do prédio), fora do sorteio de cotas.

### Casa do agente (6.4 e 6.5)

- `BuildingDefs.designate_home` escolhe, em qualquer seed, a casa do bairro residencial **mais perto do
  QG** e a transforma no tipo `agent_home` ("Casa do agente"). `WorldLayout.home()` a devolve.
- Toda ficha nova **já conhece a casa**, a tem explorada e **marcada como ponto "Casa"** (o HUD já aponta para ela;
  o jogador pode tirar o ponto). Ícone próprio no mapa (casa com estrela).
- Interior (`agent_home`, nunca menor que M): **Sala** (sofá, TV, mural de casos, estantes), **Escritório**
  (mesa com dois monitores, arquivos, **baú**), **Quarto** (cama, criados-mudos, armários), **Cozinha** (fogão,
  geladeira, pia, bancada, mesa com banquetas) e **Banheiro** (banheira, privada, pia). Sem estranhos dentro.
- Serviços novos: **dormir em casa** (`rest`, de graça: vida cheia e a hora vai para 07:00) na zona da cama, e
  **baú** (`stash`: repõe os kits médicos até 3, uma vez por dia) na zona do baú.

### Interiores cheios (6.8 a 6.11)

- **Hospital** (agora sempre M; antes ia até G): enfermaria com duas fileiras de leitos e cortinas, UTI com
  monitores, dois consultórios (mesa com computador, maca, armários), recepção com balcão, bancos, máquina de
  lanches e bebedouro, farmácia com balcão e prateleiras, sala de raio-X. Equipe de branco (médica, enfermeiro,
  farmacêutico, técnico de raio-X, auxiliar, recepcionista) e pacientes de camisola.
- **Delegacia** (M): celas com grade, beliche e privada e presos de laranja; sala dos agentes com seis mesas com
  computador, quadro de casos e arquivos; sala do delegado; sala de provas; recepção com balcão, bancos e visitantes.
  Policiais de azul, detetive à paisana, delegado e perito.
- **Casa comum:** sala, quarto, banheiro e cozinha completos.
- **Todos os outros modelos:** uma passada de decoração (`InteriorLayout._dress`) enche as paredes dos cômodos
  com plantas, lixeiras, arquivos, máquinas de lanche, caixas etc., conforme o tipo (`DECOR`). Se a decoração
  fecharia um caminho (a validação de alcance em grade de 32 px, agora **também dos cômodos**), ela é retirada por
  inteiro ou pela metade.
- **Gente mínima por tamanho** (`MIN_PEOPLE`: P 4, M 8, G 12): o que o modelo não povoou é completado com
  visitantes de papel coerente (cliente, espectador, aluno...) em pontos livres.
- **Uniformes por papel** (`CharacterSprites.UNIFORMS`): branco na saúde, azul na polícia, laranja nos presos,
  gorro branco nos cozinheiros, e assim por diante. Nunca vale para criminosos.
- 13 móveis novos com arte própria: computador, monitor, arquivo, carrinho, aparelho de raio-X, privada, banheira,
  estante de livros, máquina de lanches, pia, cortina, lixeira, cabideiro.

## Não feito (fica na Fase 6)

| Item | Situação e motivo |
|---|---|
| 6.2 Ruas estreitas nos bairros residenciais | **Pendente.** A largura de cada rua hoje depende só do número da linha (`asphalt(line)`); fazê-la depender do bairro obriga a carregar o layout nas chamadas estáticas (chão, calçadas, trânsito, luzes, mapa) e a refazer 26 pontos de teste. Proposta: larguras por linha calculadas pelo bairro dominante e guardadas em `CityLayout`, e uma fase só para isso. |
| 6.3 Ruas com curvas | **Pendente, só estudo.** O trânsito, as calçadas, o chão em quarteirões de 560 px, os lotes e o mapa assumem a grade reta. Curvas em toda a cidade quebram isso tudo; a opção segura é um trecho curvo isolado (um bairro, ou uma avenida), que vale discutir antes de começar. |
| Rota automática até o ponto | **Pendente.** Hoje há seta e distância em linha reta. |

## Testes

829 testes, 0 falhas (29 novos em `test_phase6.gd` e 18 em `test_map_points.gd`, mais ajustes). Mudanças
intencionais em testes existentes: o mínimo de tamanho dos prédios aceita as casinhas; o teste da porta
acessível para as casas da fileira de cima só exige espaço para o jogador em frente; a tabela de tipos tem
25 entradas (a casa do agente fica fora do `ORDER`); fichas novas já trazem a casa (conhecida, explorada e
marcada); o número de clientes dos interiores agora é completado até o mínimo.

## Capturas

`docs/img/fase6-*.png`: lote de casinhas, a casa do agente, o mapa com neblina e 16 interiores
(`tools/probe_p6.gd`).

## Desempenho

Mesmos 6 pontos fixos (mais os de bairros), 12:00, sem interiores: média de **2,058 ms** por quadro (486 fps),
3843 nós. A Fase 5 media 2,151 ms: as casinhas não pesaram. A meta de 20% sobre a linha de base original e a
medição no export web seguem em aberto (ver `redesign-fase-4.md`).
