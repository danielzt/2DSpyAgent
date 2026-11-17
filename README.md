# Agente ZERO B

Jogo 2D de mundo aberto, visão de cima, no estilo dos GTAs clássicos com a pegada
humorística/RPG de *Retro City Rampage*, mas você é um **agente secreto que combate o
crime**: o **Agente ZERO B**, o agente secreto de 0 bits. Feito em **Godot 4.7** com **GDScript**. Design completo: [docs/gdd.md](docs/gdd.md).

## Objetivos

- Mundo aberto 2D, visão de cima, gráficos pixel art
- Multiplayer online com amigos
- Split screen local
- Teclado ou controle (gamepad)
- Alvos: PC (Windows) primeiro; browser (HTML5) e mobile depois

## Como rodar

1. Instale o Godot 4.7.2 (versão **standard**, não .NET).
2. Abra o Godot, clique em **Import** e selecione `project.godot` desta pasta.
3. Pressione **F5**.

Ou pela linha de comando:

```bash
Godot_v4.7.2-stable_win64.exe --path "E:\Dev\Repos GIT\2DGTA"
```

## Controles (protótipo)

| Ação | Jogador 1 | Jogador 2 |
|---|---|---|
| Andar / acelerar, ré, virar | WASD | Setas |
| Interagir: entrar/sair de prédio e carro | **E** | **Enter** |
| Mirar | **mouse** | direção do movimento |
| Usar item da mão esquerda / direita | **botão esquerdo / direito do mouse** | **Num0 / Num1** |
| Conversar com NPC próximo | **F** | **Num.** |
| Inventário / Ficha do personagem | **I / C** | **Num2 / Num3** |
| Tela cheia | **F11** | |
| Gamepad | Dispositivo 0: analógico esquerdo / D-pad, A interage, Y conversa, X/B mãos | Dispositivo 1: idem |

Chegando perto de uma porta ou carro, aparece no canto inferior esquerdo
"Pressione E para entrar/dirigir"; nada acontece até você apertar a tecla.
Por enquanto só o jogador 1 é criado em cena.

## Testes

Todo código novo precisa de testes. Para rodar **todos** (precisa do Godot 4.7.2 instalado):

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s tests/run_tests.gd
```

(Nesta máquina: `Z:\Dev\Godot\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`.)

- Saída esperada no fim: `N testes, M asserções, 0 falha(s)`; o código de saída é `0` se tudo passou.
- Rode `--headless --path . --import` uma vez antes se acabou de clonar o projeto ou adicionou scripts.
- Para **criar** um teste: crie `tests/unit/test_<assunto>.gd` começando com
  `extends "res://tests/base_test.gd"` e métodos `func test_<o_que_testa>() -> void:` usando
  `assert_eq`, `assert_true`, etc. Modelo e detalhes em [docs/testes.md](docs/testes.md).

## Mundo

Mundo finito de 13440 x 6720 px com duas regiões: **Cidade** (ruas com calçadas, ~180 prédios de formatos variados,
parques, 7 lojas) e **Campo** (estrada de terra, fazendas, plantações, árvores, 1 armazém). Há carros estacionados (dirigíveis),
10 carros de trânsito, ~120 pedestres e civis, criminosos e itens espalhados. Crimes em andamento surgem conforme a região
em que você está; resolva-os com tiros ou com o taser.

## Documentação

Ver [docs/](docs/README.md). Convenções para agentes de IA: [AGENTS.md](AGENTS.md).
