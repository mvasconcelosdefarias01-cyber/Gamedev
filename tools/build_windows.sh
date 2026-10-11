#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

godot_bin="${GODOT_BIN:-godot}"
cache_dir="${FAZENDA_GODOT_WIN_CACHE:-${TMPDIR:-/tmp}/fazenda-godot-windows}"
build_dir="$PWD/builds/windows"
archive="Godot_v4.6.3-stable_win64.exe.zip"
release="https://github.com/godotengine/godot/releases/download/4.6.3-stable"
mkdir -p "$cache_dir" "$build_dir"

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${TMPDIR:-/tmp}/fazenda-build/cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${TMPDIR:-/tmp}/fazenda-build/config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${TMPDIR:-/tmp}/fazenda-build/data}"
mkdir -p "$XDG_CACHE_HOME/fontconfig" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"

curl -fsSL --retry 3 --max-time 60 "$release/SHA512-SUMS.txt" -o "$cache_dir/SHA512-SUMS.txt"
if [ ! -f "$cache_dir/$archive" ]; then
  curl -fsSL --retry 3 --max-time 180 "$release/$archive" -o "$cache_dir/$archive"
fi
(cd "$cache_dir" && sha512sum -c SHA512-SUMS.txt --ignore-missing | rg --fixed-strings "$archive: OK")

if timeout 180s "$godot_bin" --headless --editor --path . --export-pack Windows "$build_dir/FazendaEntreEcos.pck" > "$build_dir/export.log" 2>&1; then
  if rg 'SCRIPT ERROR|^ERROR:' "$build_dir/export.log"; then cat "$build_dir/export.log"; exit 1; fi
else
  command_status=$?
  cat "$build_dir/export.log"
  exit "$command_status"
fi

unzip -p "$cache_dir/$archive" Godot_v4.6.3-stable_win64.exe > "$build_dir/FazendaEntreEcos.exe"
cp ui_theme/FONT_LICENSE.txt "$build_dir/FONT_LICENSE.txt"
cp assets/LICENSE.txt "$build_dir/ASSET_LICENSE.txt"
cp docs/GODOT_LICENSE.txt "$build_dir/GODOT_LICENSE.txt"
cp docs/GODOT_COPYRIGHT.txt "$build_dir/GODOT_COPYRIGHT.txt"
cat > "$build_dir/LEIA-ME-WINDOWS.txt" <<'README'
Fazenda Entre Ecos — Windows 11 (64 bits)

1. Extraia todos os arquivos deste ZIP na mesma pasta.
2. Abra FazendaEntreEcos.exe. Mantenha FazendaEntreEcos.pck ao lado dele.

O Godot 4.6.3 oficial está incluído; não é necessário instalar Godot ou Python.
Este executável local não tem assinatura digital de distribuição. O Windows
pode pedir uma confirmação de segurança na primeira abertura.

WASD/setas: mover; botão esquerdo: cultivar; E: interagir; 1–6: culturas;
Tab: inspeção; U: melhorias; J: caderno; Esc: pausa.

Os três slots e as opções ficam em
%APPDATA%\Godot\app_userdata\Fazenda Entre Ecos\saves
Copie essa pasta para fazer backup manual antes de atualizações.

Arte/áudio CC0; fonte Pixelify Sans (OFL) e runtime Godot possuem licenças anexas.
README

python3 - <<'PY'
from pathlib import Path
import hashlib
p=Path('builds/windows')
names=('FazendaEntreEcos.exe','FazendaEntreEcos.pck')
(p/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256((p/n).read_bytes()).hexdigest()+'  '+n+'\n' for n in names))
print('Windows bundle prepared:',p.resolve())
PY
