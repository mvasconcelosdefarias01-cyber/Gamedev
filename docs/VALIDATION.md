# Validação integrada

## Resultado executado

- `bash tools/verify.sh`: **207 verificações aprovadas, 0 falhas**. Inclui cultivo, economia em centavos, reservas, padrões, automação, máquinas, fabricação, reparos R1–R6, pistas P1–P8, pesca, offline, final, persistência, backups, corrupção, migração de campos e normalização de posição.
- `bash tools/verify_ui.sh` com Xvfb, Mesa llvmpipe, áudio Dummy: **142 verificações aprovadas, 0 falhas**. Inclui 720p/1080p, UI e texto 100/150%, foco, teclado, remapeamento, pesca, memória, minimapa, contraste alto, recuperação e retorno ao cultivo livre. Capturas comparáveis em `docs/art/`.
- `python3 tools/north_asset_forge_2d/forge.py validate`: **203 PNGs, 921 frames incluindo camisas e 23 áudios**, com hashes, paleta, dimensões, pivôs, transparência, decodificação e clipping verificados. `reproducibility.json` registra exportações determinísticas.
- `bash tools/build_linux.sh`: PCK e runtime Linux x86_64 gerados em `builds/linux/`.
- `bash tools/build_windows.sh`: PCK e executável oficial Windows x86_64 atualizados em `builds/windows/`. O ZIP original do Godot foi confirmado com SHA-512 da lista oficial. O PCK atualizado passou em **238 verificações headless** e **239 verificações renderizadas**, incluindo os 226 recursos do manifest, quando carregado fora do checkout pelo Godot 4.6.3 Linux. A abertura nativa do `.exe` no Windows 11 ainda exige validação no computador do usuário.
- O teste final do pacote confirma que testes e fontes de produção foram excluídos, carrega os recursos, cultiva, vende, salva e retoma: **239 verificações aprovadas, 0 falhas** no renderizador Mesa/Xvfb. O saldo esperado nessa prova é 30 moedas: 24 iniciais − 2 de sementes + 8 da venda de quatro nabos. As capturas de revisão visual estão em `docs/art/`.

## O que esses testes não provam

As capturas foram revisadas visualmente em software renderizado, incluindo contraste, escala, cinza, plantas maduras, P6 e P8. Isso não substitui teste humano de conforto, ritmo, compreensão, game feel, duração ou audição musical. A duração de 3–5 horas e o balanceamento descritos no GDD continuam hipóteses. GPU física, execução nativa no Windows e macOS não foram testados nesta máquina.

O teste de áudio usa driver ALSA nulo para verificar criação e encerramento dos players; não é uma avaliação de qualidade acústica. Não houve cinco jogadores novos nem playtest externo.
