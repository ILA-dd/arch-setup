#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_NAME=${1:-arch-windows-migration}
ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

if ! gh auth status >/dev/null 2>&1; then
  echo 'GitHub CLI is not authenticated. Run: gh auth login -h github.com' >&2
  exit 1
fi

if git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$ROOT_DIR" push -u origin main
else
  gh repo create "$REPOSITORY_NAME" --private --source="$ROOT_DIR" --push
fi

echo "Published private repository: $REPOSITORY_NAME"
