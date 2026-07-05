#!/usr/bin/env bash
# Mac mini storage cleanup — approved targets only.
# Usage: ./scripts/cleanup-mac-storage.sh [--dry-run|--phase N|--all]

set -euo pipefail

DRY_RUN=false
PHASE=""
HOME_DIR="${HOME}"

log() { printf '[cleanup] %s\n' "$*"; }

size_of() {
  if [[ -e "$1" ]]; then
    du -sh "$1" 2>/dev/null | awk '{print $1}'
  else
    echo "missing"
  fi
}

run_rm() {
  local target="$1"
  if [[ ! -e "$target" ]]; then
    log "skip (not found): $target"
    return 0
  fi
  log "size before: $(size_of "$target") — $target"
  if $DRY_RUN; then
    log "dry-run: would remove $target"
  else
    rm -rf "$target"
    log "removed: $target"
  fi
}

phase1_apps() {
  log "=== Phase 1: App data (~25 GB) ==="
  run_rm "${HOME_DIR}/Library/Application Support/Wondershare Filmora 10"
  run_rm "${HOME_DIR}/Library/Application Support/Wondershare Filmora9"
  run_rm "${HOME_DIR}/Library/Application Support/Wondershare Filmora Mac"
  run_rm "${HOME_DIR}/Library/Application Support/Wondershare Filmora"
  run_rm "${HOME_DIR}/Applications/NovaGerbil Story"
  run_rm "${HOME_DIR}/Applications/Gerbil"
  run_rm "${HOME_DIR}/Library/DataScienceStudio"
  run_rm "${HOME_DIR}/.lmstudio"
}

phase2_dev() {
  log "=== Phase 2: Dev tools (~15 GB) ==="
  run_rm "${HOME_DIR}/Library/Android"
  run_rm "${HOME_DIR}/.android"
  run_rm "${HOME_DIR}/Library/Application Support/Google/AndroidStudio2025.1.3/caches"

  if $DRY_RUN; then
    log "dry-run: would run xcrun simctl delete unavailable && xcrun simctl erase all"
    log "dry-run: would remove /Library/Developer/CoreSimulator/Caches (sudo)"
  else
    if command -v xcrun >/dev/null 2>&1; then
      xcrun simctl delete unavailable 2>/dev/null || true
      xcrun simctl erase all 2>/dev/null || true
      log "iOS simulators erased"
    fi
    if [[ -d /Library/Developer/CoreSimulator/Caches ]]; then
      sudo rm -rf /Library/Developer/CoreSimulator/Caches
      log "removed system CoreSimulator caches"
    fi
    run_rm "${HOME_DIR}/Library/Developer/CoreSimulator/Devices"
  fi

  if command -v docker >/dev/null 2>&1 && ! $DRY_RUN; then
    docker system prune -a --volumes -f 2>/dev/null || true
  fi
  run_rm "${HOME_DIR}/Library/Containers/com.docker.docker"
  run_rm "${HOME_DIR}/.docker"
}

phase3_system() {
  log "=== Phase 3: System level (sudo) ==="
  if $DRY_RUN; then
    log "dry-run: would remove /Library/Updates/*"
    tmutil listlocalsnapshots / 2>/dev/null || true
    log "dry-run: would delete OS update APFS snapshots via tmutil"
  else
    if [[ -d /Library/Updates ]] && [[ -n "$(ls -A /Library/Updates 2>/dev/null)" ]]; then
      sudo rm -rf /Library/Updates/*
      log "removed /Library/Updates contents"
    fi
    while IFS= read -r snap; do
      [[ -z "$snap" ]] && continue
      sudo tmutil deletelocalsnapshots "$snap" 2>/dev/null || true
      log "deleted snapshot: $snap"
    done < <(tmutil listlocalsnapshots / 2>/dev/null | grep 'com.apple.os.update' || true)
  fi
}

verify() {
  log "=== Verification ==="
  df -h /
  du -sh "${HOME_DIR}/Library" "${HOME_DIR}/.android" "${HOME_DIR}/Applications" 2>/dev/null || true
}

usage() {
  cat <<'EOF'
Usage: cleanup-mac-storage.sh [OPTIONS]

Options:
  --dry-run       Show targets and sizes without deleting
  --phase 1|2|3   Run a single phase
  --all           Run phases 1–3 then verify
  --verify        Run verification only
  -h, --help      Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --phase) PHASE="$2"; shift 2 ;;
    --all) PHASE="all"; shift ;;
    --verify) verify; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

case "${PHASE:-all}" in
  1) phase1_apps ;;
  2) phase2_dev ;;
  3) phase3_system ;;
  all)
    phase1_apps
    phase2_dev
    phase3_system
    verify
    ;;
  *)
    usage
    exit 1
    ;;
esac

log "Done."
