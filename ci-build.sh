#!/usr/bin/env bash
# Выполняется ВНУТРИ контейнера Arch Linux (запускается из GitHub Actions).
set -euxo pipefail

pacman -Syu --noconfirm archiso || pacman -Syu --noconfirm --disable-sandbox archiso

cd /work
bash ./build-cyberdeck.sh
