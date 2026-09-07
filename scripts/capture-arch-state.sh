#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/capture-arch-state.sh [--manifests-only]

Updates package manifests. Without --manifests-only, also writes an encrypted
user-settings archive to archive/. The archive deliberately excludes credentials,
browser sessions, caches, logs, and ephemeral application state.
EOF
}

MANIFESTS_ONLY=false
case "${1:-}" in
  "") ;;
  --manifests-only) MANIFESTS_ONLY=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

if [[ ! -r /etc/os-release ]] || ! grep -qx 'ID=arch' /etc/os-release; then
  echo 'This capture script must run on Arch Linux.' >&2
  exit 1
fi

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST_DIR="$ROOT_DIR/manifests"
mkdir -p "$MANIFEST_DIR" "$ROOT_DIR/archive"

pacman -Qqen | LC_ALL=C sort > "$MANIFEST_DIR/arch-official-explicit.txt"
pacman -Qqem | LC_ALL=C sort > "$MANIFEST_DIR/arch-aur-explicit.txt"
pacman -Qq | LC_ALL=C sort > "$MANIFEST_DIR/arch-all-installed.txt"

if command -v flatpak >/dev/null 2>&1; then
  flatpak list --app --columns=application 2>/dev/null | LC_ALL=C sort > "$MANIFEST_DIR/flatpak-apps.txt" || :
fi

if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
  npm --global ls --depth=0 --json 2>/dev/null | node -e '
    let input = ""; process.stdin.on("data", d => input += d).on("end", () => {
      const dependencies = JSON.parse(input).dependencies || {};
      Object.entries(dependencies).sort(([a], [b]) => a.localeCompare(b))
        .forEach(([name, value]) => console.log(`${name}@${value.version}`));
    });
  ' > "$MANIFEST_DIR/npm-global.txt" || :
fi

printf 'Updated package manifests in %s\n' "$MANIFEST_DIR"

if "$MANIFESTS_ONLY"; then
  exit 0
fi

if ! command -v age >/dev/null 2>&1; then
  echo 'Installing age for encrypted backup…'
  sudo pacman -S --needed --noconfirm age zstd
fi

ARCHIVE="$ROOT_DIR/archive/arch-home-$(hostname)-$(date +%Y%m%d-%H%M%S).tar.zst.age"
EXCLUDES=$(mktemp)
trap 'rm -f "$EXCLUDES"' EXIT

cat > "$EXCLUDES" <<'EOF'
.config/**/Cookies
.config/**/Cookies-*
.config/**/Login Data
.config/**/Login Data-*
.config/**/Trust Tokens*
.config/**/Sessions/**
.config/**/Session Storage/**
.config/**/Local Storage/**
.config/**/Service Worker/**
.config/**/Cache/**
.config/**/Code Cache/**
.config/**/GPUCache/**
.config/**/ShaderCache/**
.config/**/logs/**
.config/**/*.log
.config/**/session.json
.config/**/sessionData/**
.config/**/keyring/**
.config/gh/hosts.yml
.config/pulse/cookie
.local/share/keyrings/**
.local/share/Steam/**
.local/share/Steam_backup/**
.local/share/Trash/**
.local/share/flatpak/**
.cache/**
EOF

echo 'Creating encrypted archive. age will ask you for a new archive password.'
INCLUDE_PATHS=(.config)
for path in \
  .local/share/applications \
  .local/share/color-schemes \
  .local/share/easyeffects \
  .local/share/fish \
  .local/share/fonts \
  .local/share/icons \
  .local/share/nvim; do
  [[ -e "$HOME/$path" ]] && INCLUDE_PATHS+=("$path")
done

tar \
  --create \
  --file=- \
  --directory="$HOME" \
  --wildcards \
  --wildcards-match-slash \
  --exclude-from="$EXCLUDES" \
  --ignore-failed-read \
  "${INCLUDE_PATHS[@]}" \
  2>/dev/null \
  | zstd --threads=0 --quiet \
  | age --passphrase --output "$ARCHIVE"

printf '\nEncrypted settings archive created:\n%s\n' "$ARCHIVE"
printf 'Copy it to an external drive or secure cloud. It is excluded from Git.\n'
