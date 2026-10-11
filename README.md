# Fazenda Entre Ecos

Jogo local em português para PC, feito em Godot 4.6.3 / GDScript: cultivo, restauração e investigação em pixel art isométrica. Tomás deixou uma fazenda e instruções; recuperar os canais revela registros do passado. A campanha tem seis culturas, seis reparos, oito pistas e um final, seguido de cultivo livre.

## Jogar

Downloads pelo GitHub: [projeto Godot atualizado (Código → Download ZIP)](https://github.com/mvasconcelosdefarias01-cyber/Gamedev) e [pacote executável atualizado para Windows 11](https://github.com/mvasconcelosdefarias01-cyber/Gamedev/raw/windows-11-visual/artifacts/FazendaEntreEcos-Windows11-visual.zip). O SHA-256 do ZIP Windows é `7cf30cb45b68ebd4d5dd7f7d71d810291d81feb68f7760c6f95fe2d06f3c2763`.

No Windows 11 (64 bits), use o pacote Windows: extraia os arquivos na mesma pasta e abra `FazendaEntreEcos.exe`. O `FazendaEntreEcos.pck` precisa ficar ao lado do executável; Godot 4.6.3 está incluído. Por ser uma distribuição local sem assinatura digital, o Windows pode pedir confirmação na primeira abertura. Os saves ficam em `%APPDATA%\Godot\app_userdata\Fazenda Entre Ecos\saves`.

Se o ZIP de 80 MB falhar, use o projeto fonte pelo botão **Código → Download ZIP**: extraia, abra `Gamedev/project.godot` no Godot 4.6.3 e pressione **F5**. Quem já tem o executável Godot 4.6.3 pode baixar apenas o [PCK atualizado de 1,3 MB](https://github.com/mvasconcelosdefarias01-cyber/Gamedev/raw/main/artifacts/FazendaEntreEcos-godot4-visual.pck), SHA-256 `cf5e2f0444ac6cdd3f8fb4b92e21a5b2606a667ca3ad08ed52b2eeb06867cf08`, e executá-lo com `Godot_v4.6.3-stable_win64.exe --main-pack FazendaEntreEcos-godot4-visual.pck` no PowerShell dentro da pasta dos arquivos.

No pacote Linux, extraia o ZIP e execute `./FazendaEntreEcos`. Mantenha o arquivo `FazendaEntreEcos.pck` ao lado do executável. O pacote inclui a engine oficial Godot 4.6.3 e não exige instalar Godot ou Python. Requer Linux x86_64, glibc, desktop X11/Wayland e OpenGL 3.3. Se o gerenciador de arquivos não preservar a permissão: `chmod +x FazendaEntreEcos`.

O projeto fonte já inclui os sprites integrados e o gerador editável. [Veja as pranchas antes/depois e três capturas comparáveis](docs/art/STYLE.md).

Para editar, importe [project.godot](project.godot) no Godot 4.6.3 padrão e pressione F5. Pelo terminal: `bash run.sh`, ou `GODOT_BIN=/caminho/godot bash run.sh`. O launcher usa diretórios XDG graváveis quando está na nuvem e respeita os diretórios usuais no desktop.

| Ação | Controle inicial |
|---|---|
| Mover em relação à tela | WASD / setas |
| Semear, irrigar ou colher | Mirar e segurar botão esquerdo, a até um tile |
| Interagir com placa, estação, pessoa ou pista | E |
| Escolher cultura | 1–6 |
| Alternar cultivo / inspeção | Tab |
| Melhorias / caderno / pausa | U / J / Esc |
| Mover câmera / zoom / centralizar | Arrasto do meio / roda / Home |
| Completar texto em exibição | Enter |

Comece em B1: semeie nabo, irrigue uma vez, aguarde o ✓ e colha. Venda pela caixa, preserve os materiais do objetivo e reinvista. Depois da primeira colheita, inspecione a casa. O caderno explica pistas e receitas de padrões; no painel do bloco, arme o padrão antes de plantar. Plantas não estragam. Água, madeira e pedra são inesgotáveis; existe nabo de emergência no estado de falta total de recursos.

## Conteúdo e opções

24 parcelas em seis blocos; árvores Cultivo, Engenho e Escuta com 30 melhorias; quatro níveis adicionais de ferramenta; aspersores, coletores e semeadores; reservas globais e venda automática opcional; fabricação, composto, decoração, pesca e conversas com Lia/Rui. A investigação se completa sem comprar melhorias de Escuta. O lote final exige as sete pistas anteriores, colheita de PA3 em B6 e válvulas I→II→III.

Opções incluem remapeamento de teclado/mouse, UI e texto 100/125/150%, contraste alto, movimentos/partículas reduzidos, ferramenta por toque, texto instantâneo/velocidade, pesca assistida, camisas e três grupos de volume. Informações essenciais têm símbolos e texto. Offline, após ENG9, calcula até 30 minutos reais a 25% da velocidade e não avança a narrativa.

## Saves

Três slots locais, autosave após compras/pistas/configuração e a cada 30 segundos ativos, backup do save anterior e recuperação explícita. Preferências são independentes. O menu pede confirmação para substituir slot ocupado. Recuperar backup preserva o arquivo danificado; nunca inicia um jogo novo silenciosamente em erro. Posições obstruídas são recuperadas em corredor seguro.

Dados ficam em `user://saves`: normalmente `~/.local/share/godot/app_userdata/Fazenda Entre Ecos/saves` no Linux. Faça backup dessa pasta antes de atualizar. Na nuvem, `run.sh` usa `/workspace/scratch/fazenda-runtime/data/godot/app_userdata/Fazenda Entre Ecos/saves`, salvo configuração XDG explícita. Nenhum teste automatizado usa os saves da campanha do jogador.

## Produzir e verificar

O projeto jogável está na raiz. O projeto novo de produção [North Asset Forge 2D](tools/north_asset_forge_2d/README.md) fica separado em `tools/north_asset_forge_2d/`, com gerador editável, fontes WAV e validação; seus exports integrados ficam em `assets/`. Foi criado localmente conforme autorizado, sem depender de uma ferramenta externa homônima.

```bash
# Lógica, campanha, economia, automação, saves e recuperação
bash tools/verify.sh
# Interface renderizada, após o comando anterior; requer display real ou Xvfb
bash tools/verify_ui.sh
# Pacote Linux com engine disponível e PCK
bash tools/build_linux.sh
# Pacote Windows 11 com binário oficial verificado por SHA-512
bash tools/build_windows.sh
# Validação/reprodução dos assets, requer Pillow, numpy e ffmpeg
python3 tools/north_asset_forge_2d/forge.py validate
python3 tools/north_asset_forge_2d/forge.py full
```

Os testes escrevem relatórios em `${TMPDIR:-/tmp}/fazenda-qa`; `FAZENDA_QA_DIR` e `FAZENDA_UI_QA_DIR` permitem outros caminhos. `verify_ui.sh` usa áudio Dummy por padrão; `FAZENDA_AUDIO_DRIVER` permite outro driver. Godot, Python 3 e `rg` são necessários aos testes; Python não é dependência para jogar. A distribuição usa o binário oficial com capacidades de editor como runtime, pois esta nuvem não tem templates de export instalados.

Decisões e revisão de lacunas: [arquitetura](docs/ARCHITECTURE.md). IDs, estados e formatos: [contrato](docs/INTEGRATION.md). Resultados e limites dos testes: [validação](docs/VALIDATION.md). Os documentos originais podem estar no checkout local em `docs/source/`; seus diagramas serviram de referência e não são sprites do jogo.

Arte e áudio originais: CC0, [licença](assets/LICENSE.txt). Fonte Pixelify Sans: [OFL 1.1](ui_theme/FONT_LICENSE.txt). Godot: [MIT](docs/GODOT_LICENSE.txt), com [avisos de terceiros](docs/GODOT_COPYRIGHT.txt).
