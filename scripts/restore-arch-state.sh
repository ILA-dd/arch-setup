#!/usr/bin/env bash
set -euo pipefail

ARCHIVE=${1:-}
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  echo "Usage: $0 /path/to/arch-home-*.tar.zst.age" >&2
  exit 2
fi

for command in age zstd rsync tar; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Missing required command: $command" >&2
    exit 1
  }
done

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
BACKUP_ROOT="$HOME/.migration-backups/$(date +%Y%m%d-%H%M%S)"

echo 'Decrypting archive; age will ask for its password.'
age --decrypt "$ARCHIVE" | zstd --decompress --stdout | tar --extract --file=- --directory="$STAGING"

for source in "$STAGING/.config" "$STAGING/.local/share"; do
  [[ -d "$source" ]] || continue
  relative=${source#"$STAGING/"}
  destination="$HOME/$relative"
  if [[ -e "$destination" ]]; then
    mkdir -p "$(dirname "$BACKUP_ROOT/$relative")"
    rsync -a "$destination/" "$BACKUP_ROOT/$relative/"
  fi
  mkdir -p "$destination"
  rsync -a "$source/" "$destination/"
done

printf 'Settings restored. The prior files, if any, are in %s\n' "$BACKUP_ROOT"
