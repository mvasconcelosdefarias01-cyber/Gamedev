# Produção de assets

## Origem e separação

Os documentos GDD e Direção de Arte foram lidos integralmente, incluindo as três imagens do documento visual. Não havia checkout de North Asset Forge 2D. Após autorização “crie dentro do Git”, foi criado **um projeto local novo** em `tools/north_asset_forge_2d/`; suas capacidades reais estão descritas no README e implementadas em `forge.py`. O jogo consome exclusivamente exports de `assets/`.

Foi lida a skill `game-development-studio:game-asset-production` e sua referência de comandos para verificar a aplicabilidade. O CLI `game-dev` não está instalado; nenhum workflow desse plugin, provedor externo, GPU ou Blender foi executado. O pipeline aprovado é local Python/Pillow, numpy e ffmpeg, disponíveis nesta máquina.

## Contrato raster

PNG RGBA transparente; sem antialiasing; coordenadas inteiras; fonte editável em Python; licença CC0-1.0. Metadata JSON registra IDs, caminho, `frame_size`, pivô local, colunas/linhas, animações, orientação, duração e hash SHA-256. O manifest exportado é a autoridade dos caminhos reais.

| Pacote | Frames / dimensão | Pivô e leitura |
|---|---|---|
| `crop_C1` a `crop_C6` | 5 frames 32×40, horizontal | (16,38); semente, broto, crescendo, madura A/B |
| ícones das seis culturas | 24×24 | centro; silhuetas reconhecíveis sem cor |
| jogador | 200 frames 32×48, 25 colunas × 8 linhas | (16,47); S,SW,W,NW,N,NE,E,SE |
| jogador, variantes de camisa | três sheets, mesmos frames/pivôs | sem mudança de colisão |
| Lia e Rui | 20 frames cada, 5 colunas × 4 linhas | pés; idle 2 + fala 3 |
| ecos Tomás | 24 frames, 12 colunas × 2 linhas | três gestos de 4 frames por direção |
| terreno | 32 variantes + 12 bordas 64×32 | centro do diamond; conexão 2:1, sangria de 1px nos biomas |
| aspersor/coletor/semeador | 5 frames cada; 32×32/48×40/40×40 | encaixe fixo; idle 1 + ativo 4 |
| casa/oficina/cisterna | 192×176/160×144/128×112 | contato com chão; footprint antes/depois idêntico |
| narrativa | 8 ícones 24×24 + 8 imagens-chave 160×90 | nenhuma condição transmitida só pela imagem |
| UI | culturas 6, árvores 3, reparos 6, ações 12, ícones 16px e painéis 9-slice | texto alternativo implementado pelo jogo |
| decoração | 6 compráveis + 20 props e 11 variantes | footprint não bloqueia rota |
| áudio | 6 cultivo + 3 máquinas + 3 ambiente + 4 mistério + 3 música + 4 UI | WAV fonte; OGG loops; sem clipping |

O jogador tem 25 frames por orientação: idle 2 + andar 6 + semear 4 + irrigar 4 + colher 6 + interagir 3, totalizando 200. Frames de ação não alteram o pivô; a ferramenta se move dentro do canvas.

## Revisão e aceite

Primeiro export: seis culturas, estados de canteiro, jogador e UI para avaliar um bloco. A geração do inventário restante depende de revisão visual desse bloco. Prévia normal e em escala de cinza não prova avaliação no jogo: o orquestrador deve inspecionar capturas integradas em 720p/1080p e UI 100%/150%.

Distinguem-se: (1) validação técnica automatizada de PNG, frames, hashes e áudio; (2) inspeção visual de contato sheets e capturas; (3) teste humano de leitura, ritmo e game feel, ainda não realizado. Duração de campanha, desempenho GPU e qualidade percebida não são inferidos pelo pipeline.

## Entrega e verificações efetivas

Amostra do bloco revisada e aprovada pelo agente de direção antes da produção completa. Revisão posterior das pranchas `structures.png`, `narrative_P1_P4.png`, `narrative_P5_P8.png` e `full_inventory.png` aprovou o pacote visual para integração: cultivos distintos em cinza, diferença antes/depois, tom rural, pistas sem insinuação de morte. A prancha geral é grande e foi reduzida pelo visualizador; isso não equivale a inspecionar todos os pixels/frames em movimento no jogo.

Foram exportados **203 PNGs e 23 áudios**, com **921 frames raster incluindo três camisas**. Inventário atualizado: 32 variantes de terreno + 12 bordas; 30 frames de culturas + seis ícones; jogador 200 frames por camisa, NPCs 40, ecos 24; três máquinas/15 frames; estruturas e estados antes/depois; oito ícones e oito imagens-chave; quatro retratos com três expressões cada; três árvores/seis reparos/doze ações; seis cosméticos e 20 props com 11 variantes. Extras: ícones 16px com estado bloqueado, partículas, painéis, três peixes, quatro materiais e seis estados. Pranchas e capturas comparativas estão em `docs/art/`.

As três músicas autorais são esboços instrumentais de **32 segundos** em loop, ambiente de 8 segundos e máquinas de 2 segundos. Áudio sintetizado localmente, sem gravação/cópia/provedor externo. `validation.json` decodifica cada áudio exportado com ffmpeg e mede PCM: 23 arquivos válidos, zero amostras com clipping; maior pico aproximadamente 0,30 de amplitude total. Não houve audição humana nem avaliação de fadiga musical. Volumes, proximidade, crossfade de 2s e ducking são responsabilidade da integração.

Verificações automáticas reais: hashes dos bytes exportados, PNG RGBA/transparência, dimensões de sheet/frame, índices de animação, pivôs válidos, footprints iguais antes/depois, duração e decodificação de áudio e picos PCM. `reproducibility.json` registra exportações determinísticas; OGG usa flags bitexact no muxer e no encoder. Fontes WAV e código editável ficam na ferramenta; sprites do jogo e metadados ficam em `assets/`.

## Pendências de avaliação integrada

- Capturas reais do jogo em 720p/1080p, UI100/150% foram revisadas pelo orquestrador; avaliação humana de oclusão e sprites em movimento permanece pendente.
- Animações precisam permanecer com pés estáveis no consumidor; contagem e pivô no manifest não provam a implementação de render.
- O estado maduro usa silhueta e glint no sprite, sem marca flutuante; o estado `state_memory` permanece contextual ao bloco. Movimento reduzido, recompensa/áudio e estados textuais são respeitados na integração.
- Teste humano de legibilidade, compreensão, game feel, ritmo e duração de campanha não foi realizado pela produção.
