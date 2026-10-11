# Contrato de integração v1

## Propriedade de arquivos

| Responsável | Arquivos exclusivos |
|---|---|
| Orquestrador | `tests/`, `tools/` fora de `north_asset_forge_2d/`, `README.md`, `docs/ARCHITECTURE.md`, este contrato, `docs/VALIDATION.md`, artefatos de distribuição |
| Arte/design | `docs/ART_UX.md`, `ui_theme/` |
| Produção | `tools/north_asset_forge_2d/`, `assets/`, `docs/ASSET_PRODUCTION.md` |
| Programação | `project.godot`, `export_presets.cfg`, `scripts/`, `scenes/`, `data/` |

Nenhum subagente subdelega. Mudanças entre áreas são combinadas por mensagem. Orquestrador revisa e corrige integração após comunicação, sem mudanças simultâneas no mesmo arquivo.

## API de regras

`GameData` contém definições; `FarmSimulation extends RefCounted` contém estado e regras; `FarmSaveStore` salva slots e preferências. A interface não faz cálculos econômicos próprios.

Estado da simulação: `coins_cents`, `inventory` (C1..C6, wood, stone, fiber, fish_1..3, compost), `repairs`, `clues`, `upgrades`, `listen_points`, `tool_level`, `blocks` (B1..B6), `plots` (24), clocks, posição e flags finais. Um plot guarda `id`, `block`, `position`, `crop`, `state`, `remaining`, `remainders`, `pattern_bonus`, `lot`. Um bloco guarda `preferred_crop`, `armed_pattern`, máquinas com `owned/enabled/timer` e sinais pendentes.

Comandos: `new_game(slot_id=1)`, `seed(plot_id,crop_id)`, `water(plot_id)`, `harvest(plot_id)`, `advance(seconds,offline=false)`, `sell_excess()`, `sell(item,qty)`, `repair(id)`, `buy_upgrade(id)`, `buy_tool()`, `arm_pattern(block,id)`, `inspect_clue(id)`, `install_machine(block,kind)`, `configure_block(...)`, `collect_material(id,seconds)`, `craft(id,batches)`, `apply_compost(block)`, `valve(index)`, `apply_offline(now)`, `export_state()`, `import_state(data)`.

Resultados de comandos: Dictionary `{ok:bool,message:String,...}`. Eventos: `changed(reason)` e `reward(kind,item,qty,block)`. A apresentação pode emitir eventos de animação imediata sem adiar a transação lógica para o fim do clipe.

`FarmSaveStore`: `save_slot(slot,state)`, `load_slot(slot,recover_backup=false)`, `load_preferences()`, `save_preferences(...)`. Erros explícitos, jamais reset silencioso.

## Assets

Manifest em `assets/manifest.json`: caminhos relativos ao projeto, frame size, pivô, animações e autoria. O produtor e programador acertam o schema preciso antes da integração; o programador não adivinha índices ausentes. IDs estáveis seguem GDD.

- Culturas: `assets/crops/crop_C1.png` .. C6; grid 5×1, frame 32×40, pivô (16,38). Índices 0 semente, 1 broto, 2 crescendo, 3/4 madura. Ícones `assets/ui/crop_C*.png` 24×24.
- Jogador: `assets/characters/player.png`, grid 25×8, frame32×48, pivô (16,47). Colunas idle0..1, andar2..7, semear8..11, irrigar12..15, colher16..21, interagir22..24. Ordem de oito direções acordada no manifest, não inferida pelo consumidor. Três camisas preservam pivô/frame/collision.
- NPCs: 5×4 frames (idle2, fala3), Lia/Rui; ecos 12×2 frames, três gestos de quatro frames.
- Máquinas: 5×1, idle1+ação4. Aspersor32×32, coletor48×40, semeador40×40; estados de pausa e saldo são overlays com símbolo+texto.
- Terreno64×32: 24 variantes +12 bordas. Construções com estados danificado/restaurado e footprint invariável: casa192×176, oficina160×144, cisterna128×112.
- Narrativa: oito ícones de pistas e oito imagens-chave; quatro retratos. UI: três árvores, seis reparos, doze ações. Decoração: seis compras fixas e até20 adereços.
- Áudio: seis SFX cultivo, três máquinas, três ambiente, quatro mistério, três músicas, quatro UI. Fonte WAV na ferramenta; export compatível Godot; autoria própria e licença explícita. Sem clipping ou áudio essencial sem legenda.

PNG alpha real, pixel coordinates, nearest, fontes e exports separados. Referências dos DOCX não entram nos sprites finais.

## Aceite

Fatia primeira colheita→P3 precisa venda com reserva, R1, upgrade, save/retomar, R2, oito canteiros, aspersor e PA1. Depois campanha inteira, final e cultivo livre. Cada pista dá três pontos uma só vez; custo total de Escuta=24. UI com foco preso no modal; teclado e mouse; decisões de bloqueio textuais. Validar render de verdade em 720p/1080p, UI100/150% e grayscale; screenshots por si não provam física, economia ou save.
