# Fazenda Entre Ecos — direção operacional de arte e UX

Status: especificação para implementação e revisão visual. Ambos os documentos-fonte foram lidos integralmente; as três imagens da direção de arte foram inspecionadas. Os diagramas são referências funcionais, não assets finais. Não existem `AGENTS.md` locais neste checkout nesta inspeção. Nenhuma skill disponível corresponde especificamente a UX 2D; a produção de assets cabe ao agente responsável pelo North Asset Forge 2D.

## Intenção que rege as decisões

O jogador cuida de uma propriedade que melhora fisicamente. O cultivo financia reparos; a disposição das culturas faz a água conservar gestos de Tomás. A apresentação deve permitir entender, nesta ordem: **qual ação executar, qual o resultado, qual o próximo objetivo**. A anomalia acrescenta curiosidade depois que o cultivo básico está compreendido. Tomás está vivo e saiu voluntariamente: nada na ambientação deve insinuar violência, cadáver ou ameaça.

Escopo preservado: 48×48 tiles, cinco setores, seis blocos de quatro canteiros, seis culturas, dois NPCs estáticos, três peixes, seis reparos, três árvores com 30 nós, oito pistas e um final seguido de cultivo livre. Valores econômicos e campanha de 3–5 horas são hipóteses iniciais. Aritmética correta não comprova ritmo, diversão ou duração.

## Lacunas e decisões operacionais

| Questão dos documentos | Decisão de apresentação e integração |
|---|---|
| Velocidade de “3 tiles/s” com movimento relativo à tela | Recomendar 96 pixels lógicos/s na tela, diagonais normalizadas. Converter posição para tile lógico separadamente para colisão e alcance. Root decide a métrica final e registra; nunca usar largura de sprite para alcance. |
| Câmera 640×360, mundo pixelado e UI em 720p/1080p | Mundo renderizado com pixels inteiros; UI em coordenadas físicas independentes. Texto não deve ser escalado como pixel art. Em formatos que não comportam escala inteira, barras discretas preservam o aspecto. |
| UI 150% e texto 150% independentes | Aplicar escala UI a dimensões/padding e escala de texto ao tamanho base uma única vez; não multiplicar texto duas vezes. Refluxo e rolagem antes de truncar ou reduzir texto. |
| “Mesma posição” ao fechar painel | Preservar personagem, pan e zoom ao fechar; Home recentraliza deliberadamente. Entrada que abriu painel não vaza como ação de cultivo ao fechá-lo. |
| Identificação das quatro posições | A = topo, B = direita, C = esquerda, D = baixo, conforme ordem de tela; mostrar letra e cultura em inspeção e receita. Não usar ordem matricial convencional A/B/C/D. |
| Arme um padrão e “semear manualmente” | PA1/PA2/PA3 geram stencil persistente por posição. Sem ESC6, o jogador escolhe cultura normalmente; ESC6 escolhe apenas semente contextual. Cada posição continua exigindo a ação paga. |
| Colheita precoce ou cultura errada no padrão | Estado “prepare novo lote” com explicação concreta. Não destruir plantas; só oferecer remover com confirmação separada que explicita perda. Desarmar preserva cultivo. |
| P5 ainda não lida quando PA3 amadurece em B5 | Conservar reconhecimento do lote/sinal local e avaliar requisito de P6 quando P5 for lida; evitar precisar cultivar novamente por uma ordem narrativa não anunciada. Se a implementação exigir P5 antes, o caderno deve avisar explicitamente antes de armar PA3. |
| Automação pode retirar o lote antes da inspeção | Sinal de pista pertence ao bloco/flag persistente, não à existência dos sprites das plantas. Mostrar “memória registrada — Tab, depois E”. |
| PA3 final em B6 usa mesma receita de P6 | Diferenciar objetivo “Último lote da cisterna” e estado “colha este lote para liberar válvulas”; não apresentar como P6 repetida. Final inicia por E na terceira válvula, não por evento automático de colheita. |
| Conversas de NPC versus pistas | Conversas contextuais curtas, três marcos + epílogo para cada NPC; pistas independentes. Ignorar Lia/Rui nunca bloqueia reparo, cultivo ou final. |
| Zero moedas e pilhas infinitas vendáveis | Explicar alternativa de coleta gratuita se a emergência não se aplicar. Mensagem distingue “sementes de emergência” de moeda gratuita; não prometer fonte que o save não contém. |
| Reserva global vista no painel de bloco | Rótulo explícito “Reserva para toda a fazenda”; referência ao objetivo e quantidade protegida. Não duplicar a reserva ao copiar configuração ENG10. |
| Confirmação de compra de máquina | Antes: “Pesquisa 700”; depois: “Instalar coletor 600 por bloco”. Não sugerir que o nó instala máquinas. |
| Sombra/oclusão em casas grandes | Colisão definida pelo footprint. Opacidade 35% só na parte visual que cobre jogador/alvo. Manter contorno para que o objeto continue localizável. |
| Memórias puláveis e replay ESC8 | Pular registra pista, pontos, texto e imagem-chave igual ao término normal. ESC8 habilita replay; reproduzir não reaplica prêmios. |
| Falha de save | Aviso persistente “Não foi possível salvar. Seu arquivo anterior foi preservado.” com tentar novamente/voltar, sem impedir cultivar. Não usar toast de sucesso antes de commit. |
| Primeira melhoria ≤5min, mas R1 é alvo de 6–10min e habilita todas melhorias iniciais | Tratar isso como conflito de metas temporais, não alterar desbloqueios automaticamente. Recomendar o primeiro ganho permanente (R1) como marco e medir sua chegada real; informar root para revisão posterior. |

Essas decisões complementam a intenção dos documentos. A resolução econômica, de dependências e persistência pertence à arquitetura do root; nenhuma mudança de balanceamento foi feita neste arquivo.

## Contrato visual

Projeção dimétrica 2:1: `screenX=(tileX-tileY)*32`, `screenY=(tileX+tileY)*16-height`. Tile 64×32, luz vinda do alto à esquerda, sombras curtas. Ordenar por ponto de contato com solo, não por origem da spritesheet. Sprites usam nearest neighbor, render com posição quantizada, física contínua. Não esticar um eixo sozinho.

| Família | Frame lógico | Pivô e regras |
|---|---:|---|
| Jogador | 32×48 | Pés (16,47); 8 direções; idle 2, walk 6, sow 4, water 4, harvest 6, interact 3 = 200 frames. |
| Lia/Rui | 32×48 sugerido | Pés (16,47); 4 direções; idle 2, talk 3 = 20 frames por NPC. |
| Culturas C1–C6 | 32×40 | Base (16,38); seed/sprout/grow/mature_0/mature_1; recorte não cobre centro da parcela vizinha. |
| Aspersor/coletor/semeador | 32×32 / 48×40 / 40×40 | Ponto de contato em metadata, fixo nos cinco frames. 1 idle + 4 activity; pausa e sem saldo acrescentados por UI, não sprite recolorido. |
| Casa/oficina/cisterna | 192×176 / 160×144 / 128×112 | Pivô do footprint separado e fixo antes/depois. Portas visuais alinham com estação interativa. |
| Ecos | Frame com base fixa | Três gestos, duas direções, quatro frames = 24. Contorno interrompido, sem flash ou bloom. |
| Ícones de cultura | 24×24 | Produto colhido, não miniatura da planta inteira; transparência real. Rótulo/tooltip externo. |
| Pistas e imagens-chave | Ícone e ilustração próprios | Oito de cada, com IDs P1–P8; imagem do recibo não pode sugerir óbito. |

Paleta de produção: papel `#F7F4EB`, tinta `#243C47`, solo `#AA865F`, folha `#80916C`, maduro `#E2B55F`, água `#6B9293`, eco `#A8C9C4`. Três a cinco tons por material. Não usar dourado/eco como texto sobre papel: devem receber contorno/tinta ou estar em fundo escuro. Interface usa tinta sobre papel; contraste alto pode trocar para quase preto sobre branco e engrossar outlines sem alterar significado.

### Estados imediatamente distinguíveis

| Estado | Forma, símbolo e texto | Movimento |
|---|---|---|
| Bloqueado | Cobertura baixa + “R3: recupere oficina”; contorno do tile existente | Nenhum pulso |
| Vazio | Sulcos, centro desocupado; preview mostra cultura/custo | Nenhum |
| Aguardando água | Broto pequeno + gota vazada, “Irrigar” | Gota estática |
| Crescendo | Duas alturas perceptíveis; foco mostra segundos restantes | Animação suave opcional |
| Maduro | Produto/silhueta grande + símbolo de foice/check, “Colher” | Dois frames lentos; congeláveis |
| Padrão armado | Letras A–D + cultura esperada; erro escreve nome correto | Marcas estáticas |
| Padrão registrado | Quatro marcas conectadas + ícone de caderno | Sinal breve até 3s, depois estático |
| Máquina ativa | Manivela/arco/carrinho e ícone de funcionamento | Animação curta só no tick |
| Máquina pausada | Duas barras + “Pausada” | Congelada |
| Sem saldo | Moeda e “Saldo reservado: faltam X” | Sem pulso vermelho |

Não esconder estados em números de recompensa. Cores são apoio, nunca a única diferença. Gota, check e pausa devem continuar reconhecíveis em cinza.

## Composição de mundo

S1 é a área mais quente/limpa. S2 tem solo acessível após R1. R2 usa canal como linha de orientação; o aspersor B1 deve estar visível no retorno à fazenda. S3 agrupa oficina e B3/B4. S4 tem lago e píer, sem exigir pesca para achar P5/P6. S5 revela convergência de canais. Os setores são contíguos e continuam visualmente uma propriedade.

Construções altas e copas preferencialmente ao norte/oeste; corredores de três tiles e zonas livres à frente de estações. Um reparo não altera footprint nem bloqueia rota. Comparação antes/depois em painel usa mesma escala/enquadramento. Protagonista sempre nasce em posição segura entre casa e B1, voltado ao primeiro cultivo. Objetos não disponíveis podem ser vistos e oferecer motivo quando inspecionados.

Placa do bloco, reparo, evidência e NPC têm silhuetas diferentes. Seleção escolhe um candidato por vez com hierarquia: interação disponível sob foco, alvo mais próximo, desempate estável por ID. O prompt deve nomear o alvo (“E — vender excedente”), não só “E”. Nunca mudar candidato repetidamente por jitter de um pixel.

## Layout independente da resolução

Margem física segura: 32px a 100%, 24px em 720p com UI 150% se necessário. Botões ≥40px físicos a 100% e ≥56px a 150%; distâncias entre alvos ≥8px. Corpo 16px em 720p, 18px em 1080p; títulos curtos 24/28px; texto suplementar não menor que 14/16px. A UI usa sans legível com acentos. Sem fonte pixelada obrigatória.

HUD fora de modal:

1. Topo esquerdo: saldo disponível, ícone de reserva e no máximo duas produções relevantes ao objetivo. Inventário completo abre modal pela caixa/atalho. Fração de venda não ocupa HUD.
2. Topo direito: objetivo único, próximo requisito, duas linhas de custos e botão/rótulo “Ver detalhes”. Max. 280×118 em 720p/100%, 340×150 em 1080p/100%. A 150% pode expandir em altura, preservando o centro.
3. Inferior: seis culturas em linha, número, ícone, nome curto e cadeado com tooltip específico. C6 pode usar “Flor de sino” em duas linhas. Linha secundária de comandos Tab/U/J/Esc.
4. Prompt contextual: próximo ao alvo, deslocado para não cobrir planta. Limitar uma instrução local + uma no objetivo. Toasts no canto inferior esquerdo, máximo quatro simultâneos e agrupados por ação.
5. Minimap só quando necessário (ESC5), recolhível. Escuta, objetivos e alertas não duplicam o mesmo aviso em três cantos.

Em 720p/150% a barra de culturas pode dividir 3+3 num painel baixo; não reduzir ícone a menos de 24px ou texto a menos do tamanho configurado. O HUD inteiro deve ocupar menos de metade da janela por área, fora dos modais. A região central deve conter jogador + um bloco 2×2 e preview sem coberturas.

Modal único com largura até `min(1120px, janela-64px)`, altura até `janela-64px`. Em 720p/150% usar rolagem e substituir coluna secundária por subpágina. Fechar no canto superior direito + Esc; foco inicial no título/primeiro comando seguro, restaurado ao botão de origem ao sair. Foco não escapa para o mundo. Textos longos quebram linhas; nomes, custos e bloqueios nunca são cortados.

## Telas e comportamento

| Tela | Hierarquia e operações | Estados que devem estar claros |
|---|---|---|
| T0 início | Título curto; continuar; três slots com último reparo/pista, tempo ativo e data; novo; opções; sair | Vazio, válido, backup disponível, corrompido. Novo em slot ocupado pede confirmação com nome do slot. |
| T1 fazenda | Cultivo contextual + HUD | Cultivo/inspeção visível; “Tab para voltar ao cultivo” em inspeção. |
| T2 bloco | Nome Bx/setor, estado de quatro canteiros; cultura; máquinas; padrão; reserva; limpar | Comportamento de cada máquina, custo de instalação, pausa, saldo, fila, reserva GLOBAL; limpar confirma custo perdido. |
| T3 melhorias | Cultivo/Engenho/Escuta; nós por ordem/dependência; detalhe ao lado | Comprado check+nível; disponível com botão/custo; bloqueado com texto. Mostrar base → resultado, teto e pesquisa versus máquina. Setas e Enter funcionam. |
| T4 caderno | Oito pistas à esquerda; texto, imagem e condições à direita; padrões em aba própria | Desconhecida não contém spoiler. Receita já disponível mostra A–D. P7 mostra I→II→III por texto. Histórico e tutorial separados. |
| T5 reparo | Antes/depois, resultado primeiro, custos segundo, confirmar no fim | Requisitos de pistas/recursos faltantes concretos; botão “Fixar e reservar requisitos” antes de obter tudo. |
| T6 venda | Produto, quantidade total/protegida/excedente, valor; vender quantidade ou excedente | Reserva preservada; compra madeira/pedra/fibra claramente diferente de venda. Confirmar somente quando há quantidade. |
| T7 oficina | Três receitas com insumos e resultado por lote; cosméticos fixos após R3 | Linho 6→fibra 3; composto nomeia próximos quatro plantios e teto; placa só visual. Sem necessidade de XP. |
| T8 pesca | Espera 6s; recolher 2s; assistência e cancelar | Sinal visual+legenda+som; falha não custa nem muda sequência; sucesso mostra peixe e coleção. |
| T9 pausa/opções | Retomar, salvar, opções, menu | Feedback de salvamento verdadeiro; preferências independem do slot e estão acessíveis antes de novo. |
| T10 memória | Legenda e nome; pular; retorno ao local | Cultivo pausado; pular equivale a concluir; registro de recompensa único. |
| T11 offline | Tempo real limitado, tempo simulado, unidades produzidas e moedas vendidas | “25% da velocidade ativa; até 30 minutos reais”; não contar pesquisa ou reparos; resumo só uma vez. |
| T12 fim | Explicação canônica, créditos/licenças, continuar cultivando | Tomás vivo, partida voluntária, contato por Lia. Slot marcado final concluído; botão não reinicia. |

## Movimento, ação e feedback sincronizado

WASD/setas movem em relação à tela, diagonal normalizada. Sprite mira pelo vetor real de movimento; idle mantém última direção, ação mira alvo. Animação de ferramenta não trava movimento além do requisito operacional de alcance. Parar ao colidir conserva slide pelos footprints, sem prender nos vértices dos tiles.

Segurar ação repete ao intervalo F0–F4; opção de toque contínuo alterna o mesmo comportamento, e Esc/modal/foco perdido o cancela com segurança. Apontar canteiro crescente nunca gasta moeda. Fora de alcance mostra “Aproxime-se” e contorno tracejado, sem caminho automático.

Preview antecede ação: contorno do tile apontado + vizinhos compatíveis, operação, quantidade e custo; semeadura parcial escreve “2 de 4: moedas insuficientes”. Determinar operação pelo alvo principal, sem misturar colheita/água/semente no mesmo gesto. Em reserva manual, mostrar “Saldo depois: X (reserva Y)”; usar reserva permitido conforme GDD.

Sincronização da ação: antecipação 40–80ms, frame de contato aplica regra/inventário/SFX, resolução em 100–180ms. Intervalo acelerado amostra clipe, não espera o clip completo. Semear desloca terra em poucos pixels; água usa arco curto; colher produz varredura e ícone que sobe rumo ao HUD, máximo quatro mensagens. Efeitos de recompensa não geram itens físicos coletáveis. Nenhum shake obrigatório; movimento reduzido substitui trajetórias por fade curto.

Reparo: debitar/registrar numa transação, animação 3s pulável/abreviável para movimento reduzido, comparação clara do objeto e do benefício. Não simular demora de trabalho como bloqueio econômico adicional.

Áudio: seis efeitos cultivo, três loops máquina de proximidade, vento/aves/água, três sinais memória+transição final, três músicas e quatro efeitos UI conforme documento. Volume não aumenta com ganho; duck suave em leitura; transições música 2s. Sinal essencial acompanha legenda e ícone. Mix sem clipping. Falta de áudio final deve ser registrada como pendência, não ocultada por silêncio.

## Ritmo e assistência

Tutorial avança por flags: alcançar B1 → semear/irrigar → primeira colheita → P1 → venda/reserva R1 → R1/P2 → R2 → PA1/P3. Não disparar conversas longas ao colher; deixar evidência marcada. R1 ensina expansão; R2 ensina automação e identidade; R3 ensina materiais; R4 varia ritmo; R5 aponta convergência; R6 resolve.

Objetivo padrão recomenda o próximo reparo/pista viável e permite trocar. Depois de dois ciclos sem objetivo fixado, sugerir uma vez, sem repetição constante. Quando faltam só moedas, oferecer melhoria de produção útil ou tarefa material; se houver mais de 90s sem ação útil, registrar para revisão de ritmo. Não ajustar custos só para atingir 3–5h.

Ferramenta/árvores devem produzir diferença visível imediatamente: preview de área cresce, gesto acelera, movimento melhora, máquina trabalha. Recomendação de nó é opcional e nunca vira requisito oculto da campanha.

## Aceite integrado e matriz de revisão

Executar a mesma captura/cenário em **1280×720 e 1920×1080**, UI **100% e 150%**, texto **100% e 150%**, cores normais e cinza. O teste principal usa bloco com seis culturas por rotações, estados vazio/seco/crescendo/maduro, uma máquina ativa/pausada/sem saldo, padrão armado/registrado, todas as modalidades e oficina cobrindo jogador. Uma captura isolada da tela inicial não substitui essa matriz.

| Verificação | Critério observável |
|---|---|
| Seleção | Cursor identifica o losango correto e vizinhos; área fora de alcance distinta; nenhuma confusão entre A/B/C/D. |
| Planta e máquina | Estado reconhecível em cinza e 1× pelo ícone/silhueta. Timer apenas no foco; sem pulso permanente. |
| Texto/layout | Sem sobreposição/corte, nomes com acentos corretos, botões ≥40px, rolagem alcança todas opções a 150%. |
| HUD | Mais de metade da janela disponível para mundo; personagem e um bloco completos visíveis sem prompt cobrindo plantas. |
| Oclusão | Jogador/alvo detrás da oficina/copa continuam visíveis; opacity 35%; footprint não some. |
| Pivôs | Conferir todos os frames lado a lado: pés não oscilam de posição na troca de estado/direção. Sem frames com recorte incorreto. |
| Fluxo até P3 | Novo → colheita → reserva/venda → R1/P2 → compra → R2 → padrão → inspeção → caderno → save/retomada sem instrução humana extra. |
| Automação | Padrão permanece sinalizado após coletor colher; máquina pausa sem apagar planta; desarmar não destrói lote. |
| Final | PA3 B6 colhido libera válvulas; erro só reinicia válvulas; pular registra P8; continuar preserva fazenda. |
| Áudio/acessibilidade | Sem áudio, com movimento reduzido e contraste alto, pistas e ações continuam compreensíveis. |

Verificação automática cobre importação/metadata, contrastes, dimensões, IDs, regras e fluxos simulados. Avaliação visual exige observar capturas renderizadas com os cenários acima; teste humano exige pessoa nova jogando, especialmente navegação, tempo/entendimento de reserva e ritmo. Registrar separadamente o que ocorreu. Nenhum teste humano foi realizado ao escrever esta especificação.

## Arquivos e responsabilidade

Agente de direção: este documento e `ui_theme/` (tema, fontes licenciadas e prévia). Assets finais, fontes editáveis/export, metadata/licenças são propriedade do agente de produção. Scripts/cenas/input/configuração são propriedade do agente programação. Root integra contratos e registra alterações de design. Usuário autorizou projeto local novo em `tools/north_asset_forge_2d/`; seus comandos reais serão documentados pelo produtor, sem reivindicar ferramenta externa preexistente.

Tema reutilizável: `res://ui_theme/fazenda_theme.tres`; DejaVu Sans distribuída com licença para acentos e consistência. Não coloca lógica de progressão nos elementos gráficos. Aplicar no Control raiz de cada tela; ajustar layout/fontes conforme resolução e opções sem editar o recurso global em runtime. `ui_theme/README.md` documenta variantes.

## Revisões realizadas

Primeiro gate de produção aprovado por inspeção visual das pranchas `sample_crops.png`, `sample_crops_gray.png`, `sample_block.png`, `sample_block_gray.png` e `sample_player.png` do projeto local de assets. Culturas maduras têm produtos/silhuetas distintos em cor e cinza; gota, colheita e máquinas têm sinais redundantes. Solicitado reforço do contorno tinta do sinal de memória e uso constante de indicador maduro no feijão/flor de sino. Essa revisão é estática e mostra frames amostrados: não comprova movimento, sincronização ou todos os pivôs.

Tema importado e carregado em Godot 4.6.3, acentos á/ã disponíveis, cena de componentes carregada. Contraste computado tinta/papel 10,54:1; tinta do botão desabilitado/fundo 5,34:1. É verificação técnica do recurso, não aceite da interface integrada.

Prévia de componentes renderizada em 1280×720 por Godot Compatibility/Mesa llvmpipe, salva em `ui_theme/theme_preview.png` e inspecionada: tabs nomeadas, título, acentos, custos e botão desabilitado legíveis, sem cortes na cena. Não é captura do jogo e não completa a matriz integrada.

Segundo gate aprovado por inspeção de `structures.png`, `narrative_P1_P4.png`, `narrative_P5_P8.png` e `full_inventory.png`: estruturas danificadas/restauradas mantêm massa e acesso; imagens P5/P6/P8 representam viagem, reflexo temporal e estabilização, sem contradizer Tomás vivo. A prancha de inventário foi reduzida na visualização; detalhes dos menores ícones e todos os frames continuam dependendo de scan/capturas. Os 23 arquivos de áudio exportados não foram avaliados por audição neste gate.

Primeira rodada integrada por render real em 720p/1080p, UI+texto 100/150%, telas Fazenda, Bloco e Melhorias, revelou redimensionamento indevido do SubViewport e corte da barra inferior a 150%. Programação corrigiu para mundo640×360 com `stretch_shrink=2` e barra com altura suficiente. Segunda rodada dos mesmos 12 cenários confirmou pixels2×/3×, barra inteira com margem20px, textos legíveis e modais roláveis. Prompt foi reposicionado acima da barra; sua sobreposição em cultivos maduros ainda depende da revisão de estados. Capturas temporárias em `/tmp/{initial,block,upgrades}_{720,1080}_{100,150}.png`; esse smoke usa save isolado em `/tmp`, não a campanha do usuário.

Componente minimapa em `ui_theme/farm_minimap.gd` implementado, compilado e renderizado em tamanho180×112/font16 e270×168/font24. Marca jogador com círculo e destino com cruz; setores fechados listrados e blocos desbloqueados com quadrados; tooltip e descrição acessível incluem posição/destino. As duas prévias foram inspecionadas sem cortes. É leitura do estado e não interfere na progressão; integração/condição ESC5 pertence à programação.

## Pendências de avaliação

- Aguardam protótipo: capturas da matriz, pivôs, seleção, oclusão e percurso até P3.
- Aguardam teste humano: compreensão sem ajuda, agência com automação, espera sem tarefa, duração completa.
- Aguardam assets finais: qualidade de arte e áudio, quantidade de frames, quatro retratos, oito imagens-chave, licenças e conteúdo visual de todas as estruturas.
- Se a produção de assets não atingir o inventário do documento, registrar a diferença explicitamente na entrega; não chamar placeholder de asset final validado.
