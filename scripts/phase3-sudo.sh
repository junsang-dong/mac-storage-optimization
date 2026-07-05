#!/usr/bin/env bash
# Phase 3 — requires admin password. Run in Terminal:
#   ./scripts/phase3-sudo.sh
#
# Note: /Library/Updates may be SIP-protected on recent macOS.
# If rm fails with "Operation not permitted", use:
#   softwareupdate --list
# and wait for macOS to purge stale update payloads after a reboot.

set -euo pipefail

echo "[phase3] Removing macOS update leftovers..."
sudo rm -rf /Library/Updates/* || echo "[phase3] warn: some /Library/Updates files are SIP-protected"
echo "[phase3] Removing system CoreSimulator caches..."
sudo rm -rf /Library/Developer/CoreSimulator/Caches

echo "[phase3] Deleting OS update APFS snapshots..."
while IFS= read -r snap; do
  [[ -z "$snap" ]] && continue
  echo "  deleting: $snap"
  sudo tmutil deletelocalsnapshots "$snap" || true
done < <(tmutil listlocalsnapshots / 2>/dev/null | grep 'com.apple.os.update' || true)

echo "[phase3] Done. Remaining snapshots:"
tmutil listlocalsnapshots / 2>/dev/null || true
