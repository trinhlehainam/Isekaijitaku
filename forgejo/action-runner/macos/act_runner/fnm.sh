#!/usr/bin/bash
# Beucase "curl -fsSL https://fnm.vercel.app/install | bash" use brew to install fnm
# fnm will already on PATH
# https://github.com/Schniz/fnm?tab=readme-ov-file#upgrade
if command -v fnm &>/dev/null; then
  eval "$(fnm env --shell bash)"
fi