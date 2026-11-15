# Protótipo 05: mira com mouse, conversas, inventário e ficha do jogador

## Ajustes anteriores

- **Carro mais lento:** velocidade máxima 520 → 340 px/s (ré 140), aceleração e frenagem proporcionais.
  Carros de trânsito: cruzeiro 150 px/s. O "chute" da batida ficou mais forte para destravar melhor.
- **Trânsito na faixa da direita:** o carro persegue um ponto da faixa `110 px` à frente da sua projeção
  sobre ela (`TrafficRoute.lane_target`), em vez de um ponto distante; assim ele volta à faixa logo depois
  das curvas, em vez de andar no meio da rua. Há teste que mede o lado da pista em ~2400 quadros.
- **Resolução:** `stretch/aspect = expand` (o mundo se adapta a qualquer proporção, sem faixas pretas), janela
  redimensionável, tamanho inicial = 85% da tela (`DisplaySetup`) e **F11** alterna tela cheia.

## Mira e controles (jogador 1)

| Ação | Controle |
|---|---|
| Andar | WASD (independente da mira) |
| Mirar | mouse (o jogador gira para o cursor) |
| Mão esquerda | botão esquerdo do mouse |
| Mão direita | botão direito do mouse |
| Interagir (portas, carro) | E |
| Conversar | F |
| Inventário | I |
| Ficha do personagem | C |
| Tela cheia | F11 |

A mira só passa a seguir o mouse depois do primeiro movimento dele; até lá (ou com gamepad) o jogador mira
na direção em que anda. Jogador 2: setas, Enter, Num. (conversa), Num0/Num1 (mãos), Num2 (inventário), Num3 (ficha).

## Conversas (F) e NPCs com nome

- Cada NPC tem um **card de identidade** (`NpcIdentity`): nome, idade, área de trabalho, 2 traços de
  personalidade, humor. Determinístico pela semente do NPC.
- O nome **não aparece sobre o personagem**. Ao chegar a ~64 px, o canto inferior esquerdo mostra
  "Pressione F para falar com *Nome*". F abre o **card** (nome, resumo, personalidade, resposta, 4 perguntas por
  clique ou teclas 1-4; Esc ou F fecham).
- Durante a conversa o jogador e o NPC ficam parados e o jogador não atira. Se o NPC for atacado, morrer ou
  atordoado, a conversa termina. Com criminosos não dá para conversar (hostis, por enquanto).
- As respostas dependem do card (humor, trabalho, traço principal).
- Primeira conversa com cada NPC: +5 XP.

## Itens e mãos

| Item | Tipo | Efeito |
|---|---|---|
| Pistola | arma | tiro único, 0,25 s de recarga |
| Escopeta | arma | 5 projéteis em cone, 0,8 s de recarga, curto alcance |
| Taser | arma não letal | atordoa 3 s; criminoso atordoado +30 pontos e +15 XP, inocente -20 pontos |
| Kit médico | ferramenta | clique usa: cura 4 de vida; consumível; não gasta com vida cheia |
| Escudo balístico | escudo | segure: bloqueia tiros vindos de ±70° da mira; andar 40% mais lento |

- **Mão esquerda** (botão esquerdo) e **mão direita** (botão direito) podem ter qualquer item. Armas disparam ao
  segurar; ferramentas usam ao clicar; escudo ergue enquanto segura. Cada mão tem a sua recarga.
- **Inventário (I):** mochila com até 8 tipos de item e pilhas; cada linha tem botões "Esquerda" e "Direita"
  para equipar, e "Guardar mão". O mesmo item só vai nas duas mãos se houver 2 unidades.
- Kit inicial: pistola (esquerda), escudo (direita), taser, escopeta, 3 kits médicos.
- Com o inventário ou a ficha abertos o jogador fica parado e não atira (o mundo continua rodando).

## Ficha do personagem (C), XP e atributos

- Nome, codinome, passado, **características** (traços de personalidade), nível, XP e pontos disponíveis.
  Jogador 1: Dante Ramos "Falcão"; jogador 2: Lúcia Prado "Coruja".
- **XP:** matar criminoso +25, atordoar criminoso +15, primeira conversa com um NPC +5 (tudo multiplicado
  pela Inteligência). Matar inocente não dá XP. Nível N→N+1 custa `50 × N` XP; cada nível dá **2 pontos**;
  nível máximo 20. Começa com 3 pontos para gastar.
- **Atributos** (1 a 10), todos com efeito real:

| Atributo | Efeito por ponto acima de 1 |
|---|---|
| Velocidade | +6% de velocidade ao andar |
| Força | +20% de dano das armas (a escopeta e o tiro ficam mais letais) |
| Vitalidade | +2 de vida máxima (e cura essa diferença na hora) |
| Inteligência | +10% de XP; revela a personalidade dos NPCs na conversa (2 pts: 1 traço, 3 pts: 2 traços) |

- Ficha e inventário de cada jogador ficam no autoload `GameState` e sobrevivem às trocas de cena (entrar em prédios).

## Limitações

- Itens só vêm no kit inicial: não há loja nem itens no chão
- Inteligência prepara o terreno para o scanner (ainda não existe)
- Sem salvar/carregar; sem sprites; o menu não pausa o mundo
- Atributos futuros (ex.: Pontaria, Carisma) só entram quando tiverem uso claro

## Testes

`test_inventory` (itens, mãos, painel, taser, kit médico, escudo), `test_character` (ficha, XP, atributos, efeitos
no jogo), `test_conversation` (identidade, card, F), `test_aim_and_display` (mira, janela), `test_traffic`
(faixa da direita), `test_input_setup`, `test_hud`.
