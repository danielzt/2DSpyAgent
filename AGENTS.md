# AGENTS.md

Instruções para agentes de IA (e humanos) que trabalham neste repositório.

## Projeto

Jogo 2D top-down de mundo aberto (estilo GTA clássico / Retro City Rampage).
Godot **4.7.2 standard**, linguagem **GDScript** (não usar C#: não exporta para web).
Renderer: **GL Compatibility** (necessário para HTML5/mobile).

Executável do Godot (máquina do autor):
`Z:\Dev\Godot\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe`

## Estrutura

```
project.godot        configuração do projeto
scenes/              cenas (.tscn)
scripts/             scripts (.gd), espelhando a organização de scenes/
  autoload/          singletons globais (InputSetup, GameState, Score)
  world/             layouts (lógica) e world.gd (nós); interaction/, vehicle/, ui/, interior/
  art/               fábrica de arte: paleta, sprites e tiles gerados por código, cache de texturas
tests/               runner próprio + unit/test_*.gd
tools/               ferramentas de desenvolvimento (capturas, desempenho, folha de sprites)
docs/                documentação (ver regra abaixo)
```

## Regras

0. **Testar tudo, sempre**: toda feature ou correção vem com testes em `tests/unit/test_*.gd`
   **na mesma mudança**, e você **deve rodar a suíte inteira** antes de dizer que terminou.
   Não conclua com testes falhando; se um teste quebrar por mudança intencional, atualize-o
   e explique. Nunca apague um teste só para passar.
   Fluxo obrigatório:
   1. Escreva (ou atualize) o teste da feature em `tests/unit/test_<assunto>.gd`
      (`extends "res://tests/base_test.gd"`, métodos `test_*`, ver `docs/testes.md`).
   2. Implemente.
   3. Rode `--headless --path . --import` se criou scripts novos e depois a suíte (comando em "Validação").
   4. Só então reporte, citando o resultado (`N testes, 0 falha(s)`).
   Prefira lógica pura em `RefCounted` (layout x nós) para facilitar o teste; comportamento de
   nós (movimento, E, cenas) testa-se instanciando a cena em `tree.root` com `await wait_physics_frames(n)`.
1. **Documentar tudo**: toda feature, cena, sistema ou decisão nova deve ser registrada
   em `docs/` na mesma mudança. Atualize `docs/README.md` (índice), `docs/changelog.md`
   e, se mudar o design, `docs/gdd.md`.
1b. **Tema**: paródia de espionagem; o jogador é um agente secreto que combate o crime (armas
   letais permitidas, mas matar inocentes tira pontos); não criar mecânicas centrais de roubo.
1c. **Interação**: nunca acionar portas/veículos por simples toque; use `InteractZone` e a ação
   `p{N}_interact` (E / Enter), com instrução no HUD. Interiores de prédios são cenas próprias com escala maior que a fachada.
2. **Input por jogador**: ações no formato `p{N}_{ação}` (ex.: `p1_up`, `p1_interact`), registradas
   em `scripts/autoload/input_setup.gd`. Nunca ler teclas/botões direto; sempre usar ações.
   Isso sustenta split screen e multiplayer.
3. **Pronto para multiplayer**: lógica de jogo deve depender de `player_index`, não de
   singletons de "o jogador". Geração procedural usa seed fixa. Escolha de rede deve
   funcionar em browser (WebSocket/WebRTC, não ENet/UDP).
4. **Sem assets externos por ora**: toda a arte é pixel art gerada por código em `scripts/art/`
   (ver `docs/redesign-fase-1.md`). Use só cores de `Palette`, 1 texel = 2 px do mundo, e peça
   texturas ao `SpriteFactory` (cache) em vez de desenhar retângulos soltos com `ColorRect` ou `_draw`.
   Ao mexer no visual, abra o jogo e confira: `--path . -s tools/probe.gd -- <prefixo>` salva capturas
   em `docs/img/` e mede o desempenho.
5. **Estilo GDScript**: tipagem estática quando possível, `snake_case`, constantes em
   `UPPER_CASE`, comentários em português.

## Validação

Antes de concluir uma mudança, rode os testes e confirme `0 falha(s)`:

```bash
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s tests/run_tests.gd
```

Após adicionar scripts novos, rode antes `--headless --path . --import`.
Um aviso `Tipo de morte desconhecido` e avisos de "leaked" ao final são esperados.
