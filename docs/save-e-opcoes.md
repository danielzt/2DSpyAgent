# Save, opções e corpo a corpo (E2 e E4, parte)

## Save (E2)

- **Arquivo:** `user://save.json` (no navegador, o armazenamento do site). Um só, sem slots.
- **Conteúdo:** `version`, `seed`, `clock` (relógio do mundo), `points`, `position` (onde reaparece) e `players`
  (por índice: `profile` e `inventory`). O mundo não é gravado: é regenerado pela seed, que o `GameState` guarda.
- **Ficha (`PlayerProfile.to_dict/from_dict`):** nome, características, nível, XP, pontos a gastar, atributos,
  dinheiro, banco, presos, vida, cor do carro, dias de treino/briefing/baú, NPCs com quem falou, prédios
  conhecidos, quarteirões explorados e pontos do mapa. Campos que faltam mantêm o valor padrão; atributos
  respeitam o teto ao carregar.
- **Inventário (`Inventory.to_dict/from_dict`):** pilhas e mãos; itens que não existem mais são descartados.
- **Quando grava (`GameState.autosave`):** ao entrar e sair de prédios (isso cobre dormir em casa) e ao abrir a
  pausa. O autosave só liga quando uma partida começa pelo título (`start_game` ou `continue_game`), então
  testes e ferramentas nunca gravam. Dentro de um prédio, a posição salva é a porta.
- **Continuar:** `GameState.continue_game()` carrega o save com a íris fechada e abre o mundo na posição salva.
- **Versão:** `SaveGame.migrate` aceita versões de 1 até a atual (passos de migração entram aqui) e devolve `{}`
  para arquivo sem versão, de versão futura ou corrompido; o jogo trata `{}` como "sem save".

## Opções (E2)

`Options` (`user://options.cfg`): tela cheia, volume (0 a 10, de 2 em 2, vale para o bus principal; ainda não há
áudio) e tremor de câmera. Estão no título (**Opções**) e na pausa. F11 continua alternando a tela cheia.

## Corpo a corpo (E4, parte)

- **Cassetete** (`baton`, tipo `melee`): dano 1, intervalo 0,45 s, alcance 64 px, arco de 1,6 rad à frente. Vem no kit
  inicial e é vendido na armaria. Usa-se com o botão da mão em que está equipado.
- **Socos:** com a mão esquerda vazia, o botão esquerdo dá um soco (dano 0,5, alcance 48 px). Não é um item.
- A Força multiplica o dano dos golpes como o das armas. Matar inocentes continua tirando pontos.
- **Ainda não:** o jogo não começa sem arma de fogo (depende de a história liberar as armas), munição, recarga,
  barra de itens, ruído.

## Testes

`tests/unit/test_save_melee.gd`. O runner de testes aponta `SaveGame.path` e `Options.path` para `user://test_*` e
limpa o save entre os testes.
