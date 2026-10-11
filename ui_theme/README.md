# Tema Fazenda Entre Ecos

`fazenda_theme.tres` é um recurso Godot 4, sem lógica de jogo. Aplicar como `theme` no Control raiz do HUD e de cada tela. Fontes, cores, botões, painéis, campos e tabs herdam o tema. Tipos de variação: `Title` (28), `SectionTitle` (22), `HUDLabel` (18), `Caption` (16).

`fazenda_high_contrast.tres` oferece painéis brancos, tinta quase preta e estados de botão com contornos mais diretos. A opção de contraste alto pode trocar o recurso no Control raiz. Para estados do mundo, conservar símbolos e reforçar outlines; trocar só o tema de UI não altera sprites do mundo.

O baseline corresponde a UI de 1080p. Em 720p, o corpo pode usar 16px; UI/texto 100/125/150% ajustam layout/tipografia no controlador, sem duplicar a multiplicação. Texto é vetorial e usa filtragem normal; nearest neighbor fica reservado ao mundo e ícones pixelados. Botões possuem 20px de padding vertical; com fonte 18 atingem altura de aproximadamente 42px. Atribuir tamanho mínimo explícito 40px, 56px a 150%.

Papel #F7F4EB e tinta #243C47 possuem contraste alto. Estados usam também texto/ícone/forma. Botões bloqueados precisam de explicação próxima ou tooltip com foco de teclado. O tema não fornece os ícones de pause/custo/culturas: estes são exports do projeto de assets.

Fonte DejaVu Sans copiada do pacote de sistema `fonts-dejavu-core`; licença em `FONT_LICENSE.txt`. Não usar a fonte para atribuir autoria do jogo. Não é fonte pixelada e inclui os acentos do português brasileiro.

`farm_minimap.gd` é um `Control` somente de leitura. API: `configure(simulation, player_tile, destination_tile=Vector2(-1,-1))`; `set_destination_name("...")` atualiza alternativa textual. Usa `GameData.BLOCKS` e `simulation.has(repair_id)`. Mostra cinco setores, seis blocos, posição do jogador e destino selecionado; setores fechados são listrados. A integração exibe após ESC5 e atualiza posição/destino a partir do HUD. A mínima é 180×112 com fonte16, 270×168 com fonte24, e o texto da legenda acompanha essa escala. O tooltip contém coordenadas, nome do destino e orientação; foco tem contorno visível. `minimap_preview_100.png` e `_150.png` são renders reais do componente.

Validação do recurso e contraste registrada em `theme_validation.json`. Esta validação técnica não substitui revisão do jogo em 720p/1080p, 100/150% ou teste humano.
