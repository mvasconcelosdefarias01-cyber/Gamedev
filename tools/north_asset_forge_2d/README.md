# North Asset Forge 2D — ferramenta local de Fazenda Entre Ecos

Este é um projeto **novo, criado neste repositório por autorização do usuário**. Não é uma cópia, instalação ou integração com um produto/repositório externo de mesmo nome. Seus comandos e capacidades estão implementados em `forge.py`; não existem provedores pagos ou credenciais envolvidos.

Produz pixel art raster original usando desenho determinístico em Python/Pillow, spritesheets, metadata JSON, inventário com hashes e áudio sintetizado autoral. O código é a fonte editável. A exportação fica separada em `../../assets`; prévias e fontes WAV ficam neste diretório.

```sh
python3 tools/north_asset_forge_2d/forge.py sample
python3 tools/north_asset_forge_2d/forge.py full
python3 tools/north_asset_forge_2d/forge.py validate
```

Requer Python 3.10+, Pillow, numpy e ffmpeg. Não instalar dependências globais nem alterar o jogo para operar a ferramenta. As exportações usam PNG RGBA sem antialiasing, escala 1×, metadados de pivô em pixels locais; WAV PCM 16-bit de fonte e OGG Vorbis para loops. Nearest neighbor deve ser selecionado no Godot.

`sample` exporta as seis culturas, ícones, personagem, estados dos canteiros e uma prévia do bloco; ao repetir depois de `full`, preserva no manifest o inventário completo. `full` amplia o inventário após a avaliação do bloco. `validate` verifica os bytes realmente exportados, dimensões, frames, pivôs, hashes e PCM decodificado dos áudios. A validação técnica não substitui revisão visual/humana.

Fonte/licença: arte e áudio originais específicos deste projeto, disponibilizados sob CC0-1.0. Imagens dos documentos de briefing não são exportadas nem redistribuídas como assets.
