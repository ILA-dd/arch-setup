#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST_DIR="$ROOT_DIR/manifests"

if [[ ! -r /etc/os-release ]] || ! grep -qx 'ID=arch' /etc/os-release; then
  echo 'This installer is for Arch Linux only.' >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo 'sudo is required to install packages.' >&2
  exit 1
fi

sudo pacman -Syu --needed --noconfirm base-devel git rsync age zstd

if ! command -v yay >/dev/null 2>&1; then
  WORK_DIR=$(mktemp -d)
  trap 'rm -rf "$WORK_DIR"' EXIT
  git clone https://aur.archlinux.org/yay.git "$WORK_DIR/yay"
  (cd "$WORK_DIR/yay" && makepkg -si --noconfirm)
fi

mapfile -t OFFICIAL < <(grep -Ev '^(intel-ucode|lib32-vulkan-radeon|vulkan-radeon)$' "$MANIFEST_DIR/arch-official-explicit.txt")
if ((${#OFFICIAL[@]})); then
  sudo pacman -S --needed --noconfirm "${OFFICIAL[@]}"
fi

# Hardware packages are only useful on matching hardware. The current source
# system used an Intel CPU and AMD graphics; detect the target before installing.
if grep -q 'GenuineIntel' /proc/cpuinfo; then
  sudo pacman -S --needed --noconfirm intel-ucode
fi
if command -v lspci >/dev/null 2>&1 && lspci | grep -Eqi '(VGA|3D).*AMD|ATI'; then
  sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon
fi

mapfile -t AUR < "$MANIFEST_DIR/arch-aur-explicit.txt"
if ((${#AUR[@]})); then
  yay -S --needed --noconfirm "${AUR[@]}"
fi

if [[ -s "$MANIFEST_DIR/flatpak-apps.txt" ]]; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  mapfile -t FLATPAKS < "$MANIFEST_DIR/flatpak-apps.txt"
  if ((${#FLATPAKS[@]})); then
    flatpak install --user --noninteractive flathub "${FLATPAKS[@]}"
  fi
fi

if [[ -s "$MANIFEST_DIR/npm-global.txt" ]] && command -v npm >/dev/null 2>&1; then
  mapfile -t NPM_PACKAGES < "$MANIFEST_DIR/npm-global.txt"
  if ((${#NPM_PACKAGES[@]})); then
    npm install --global "${NPM_PACKAGES[@]}"
  fi
fi

shopt -s nullglob
ARCHIVES=("$ROOT_DIR"/archive/*.age)
if ((${#ARCHIVES[@]} == 1)); then
  "$ROOT_DIR/scripts/restore-arch-state.sh" "${ARCHIVES[0]}"
elif ((${#ARCHIVES[@]} > 1)); then
  printf 'Several archives found. Run manually, for example:\n  %q %q\n' \
    "$ROOT_DIR/scripts/restore-arch-state.sh" "${ARCHIVES[0]}"
else
  echo 'Packages installed. No encrypted settings archive found in archive/.'
fi

echo 'Arch restoration finished. Log in to cloud services and browser sync again.'
