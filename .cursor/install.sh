#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Vouch Godot 4.3 project.
# - Installs the Godot 4.3 engine (headless-capable, full editor binary).
# - Builds the project's .godot import cache so headless probes and the
#   editor can run immediately.
set -euo pipefail

GODOT_VERSION="4.3-stable"
GODOT_BIN_NAME="Godot_v4.3-stable_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_BIN_NAME}.zip"
INSTALL_DIR="${HOME}/.local/bin"
GODOT_PATH="${INSTALL_DIR}/godot4"

mkdir -p "${INSTALL_DIR}"

need_install=1
if [ -x "${GODOT_PATH}" ] && "${GODOT_PATH}" --headless --version 2>/dev/null | grep -q "4.3.stable"; then
  need_install=0
fi

if [ "${need_install}" -eq 1 ]; then
  echo "[install] Downloading Godot ${GODOT_VERSION}..."
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir}"' EXIT
  curl -fL --retry 4 --retry-delay 4 -o "${tmpdir}/godot.zip" "${GODOT_URL}"
  unzip -o "${tmpdir}/godot.zip" -d "${tmpdir}" >/dev/null
  install -m 0755 "${tmpdir}/${GODOT_BIN_NAME}" "${GODOT_PATH}"
  echo "[install] Installed Godot to ${GODOT_PATH}"
else
  echo "[install] Godot ${GODOT_VERSION} already present at ${GODOT_PATH}"
fi

# Make `godot4`/`godot` available on PATH for future shells.
if command -v sudo >/dev/null 2>&1; then
  sudo ln -sf "${GODOT_PATH}" /usr/local/bin/godot4 || true
  sudo ln -sf "${GODOT_PATH}" /usr/local/bin/godot || true
fi

"${GODOT_PATH}" --headless --version

# Build the import cache (.godot/). Godot exits non-zero on some benign
# resource warnings during a cold import, so don't let that abort setup.
echo "[install] Importing project resources (building .godot cache)..."
"${GODOT_PATH}" --headless --path "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" --import || true

echo "[install] Done."
