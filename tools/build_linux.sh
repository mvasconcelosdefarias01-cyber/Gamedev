#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT_BIN:-godot}"
build_dir="$PWD/builds/linux"
mkdir -p "$build_dir"
qa_root="${TMPDIR:-/tmp}/fazenda-build"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$qa_root/cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$qa_root/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$qa_root/data}"
mkdir -p "$XDG_CACHE_HOME/fontconfig" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
if timeout 180s "$godot_bin" --headless --editor --path . --export-pack Linux "$build_dir/FazendaEntreEcos.pck" > "$build_dir/export.log" 2>&1; then
  if rg 'SCRIPT ERROR|^ERROR:' "$build_dir/export.log"; then cat "$build_dir/export.log"; exit 1; fi
else
  command_status=$?
  cat "$build_dir/export.log"
  exit "$command_status"
fi
# Bundle the existing official engine runtime. Export templates are not needed
# for a PCK. This build uses the editor-capable binary as the game runtime.
cp "$(readlink -f "$(command -v "$godot_bin")")" "$build_dir/FazendaEntreEcos"
chmod +x "$build_dir/FazendaEntreEcos"
cp ui_theme/FONT_LICENSE.txt "$build_dir/FONT_LICENSE.txt"
cp assets/LICENSE.txt "$build_dir/ASSET_LICENSE.txt"
cp docs/GODOT_LICENSE.txt "$build_dir/GODOT_LICENSE.txt"
cp docs/GODOT_COPYRIGHT.txt "$build_dir/GODOT_COPYRIGHT.txt"
cat > "$build_dir/LEIA-ME.txt" <<'BUNDLE_README'
Fazenda Entre Ecos — Linux x86_64

Execute ./FazendaEntreEcos em um desktop Linux com X11 ou Wayland.
Mantenha FazendaEntreEcos.pck ao lado do executável.
Runtime oficial Godot 4.6.3 incluído; binário com capacidades de editor.
Não precisa instalar Godot, Python, Node ou templates para jogar este pacote.
Dependências de sistema: Linux x86_64, glibc, display X11/Wayland e driver OpenGL3.
Validação local realizada com Xvfb/Mesa llvmpipe; compatibilidade Windows/macOS
e GPU de hardware não foi testada nesta entrega.

Controles: WASD/setas mover; mouse mirar; clique/segurar cultivar;
E interagir; 1–6 culturas; Tab inspeção; U melhorias; J caderno;
Esc pausa; botão do meio/roda pan/zoom; Home centralizar.

Três slots locais, backup e preferências. Para backup manual, copie a pasta
de dados Godot/app_userdata/Fazenda Entre Ecos de seu usuário antes de atualizar.
As opções e os saves não estão dentro do pacote distribuído.

Arte e áudio próprios CC0; Godot MIT; fonte Pixelify Sans (OFL) com sua licença incluída.
BUNDLE_README
python3 - <<'PY'
from pathlib import Path
import hashlib
p=Path('builds/linux')
rows=[]
for name in ('FazendaEntreEcos','FazendaEntreEcos.pck'):
    f=p/name
    rows.append(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+name)
(p/'SHA256SUMS.txt').write_text('\n'.join(rows)+'\n')
print('Linux bundle prepared:',p.resolve())
PY
