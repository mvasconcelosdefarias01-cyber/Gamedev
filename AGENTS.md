# Fazenda Entre Ecos

Godot 4.6.3 padrão, GDScript, pixel art isométrica 2:1. Documentos de intenção fornecidos pelo usuário podem estar localmente em `docs/source/`; decisões em `docs/ARCHITECTURE.md`; contrato em `docs/INTEGRATION.md`.

- O projeto jogável está na raiz. Produção de assets é o projeto local separado `tools/north_asset_forge_2d/`; leia suas próprias instruções antes de editar o gerador.
- IDs C1..C6, R1..R6, P1..P8, B1..B6, PA1..PA3 e 30 upgrades são persistentes. Traduções não podem virar chaves lógicas.
- Economia e progressão pertencem a `FarmSimulation`; UI não duplica fórmulas. Não apague saves automaticamente em erro.
- Rode `bash tools/verify.sh` depois de mudar regras/salvamento. Confirme contagem de testes; Godot pode sair com0 mesmo com SCRIPT ERROR.
- `bash run.sh` inicia o projeto; `bash tools/build_linux.sh` e `bash tools/build_windows.sh` produzem pacotes por plataforma. A versão Windows usa executável oficial Godot 4.6.3 confirmado contra SHA-512 publicada. Não desative verificações TLS, hashes ou assinatura de pacotes.
- A nuvem já isola cada tarefa; use o checkout existente. Não crie worktree sem pedido explícito.
- Mudanças visuais exigem renderização real e inspeção; lógica headless e metadados de sprites não provam legibilidade ou game feel.
- Preserve arquivos do usuário e separe arte original de referências. Não reivindique plugin/pipeline externo que não foi usado.
- Se houver delegação, no máximo três subagentes, sem subdelegação, com propriedade de arquivos conforme contrato.
- Duração de3–5h e preços iniciais são hipóteses. Não reporte teste humano, GPU de hardware ou compatibilidade não executados.
