#!/usr/bin/env bash

set -euo pipefail

KASNER_REPO_RAW_BASE="https://raw.githubusercontent.com/rvkasner/keyboards"

KASNER_KMAP_URL_DEFAULT="${KASNER_REPO_RAW_BASE}/main/os/linux/kmap/kasner.kmap"
KASNER_XKB_URL_DEFAULT="${KASNER_REPO_RAW_BASE}/main/os/linux/xkb/kasner"

DEST_KMAP_DEFAULT="/etc/console-setup/kasner.kmap"
DEST_XKB_DEFAULT="/usr/share/X11/xkb/symbols/kasner"
KEYBOARD_DEFAULT_FILE_DEFAULT="/etc/default/keyboard"

usage() {
  cat <<'EOF'
Install or uninstall the Kasner console keyboard layout.

USAGE:
  sudo ./install_kasner.sh [options]

MODES:
  --method kmap|xkb        Install method:
                            - kmap: download precompiled kasner.kmap
                            - xkb : download XKB file and compile to .kmap
                          (default: kmap)

UNINSTALL:
  --uninstall              Revert changes (restore previous /etc/default/keyboard if possible)
  --purge                  With --uninstall: also remove installed files and backup

INSTALL OPTIONS:
  --kmap-url URL           Download URL for kasner.kmap (method=kmap)
  --xkb-url URL            Download URL for XKB symbols file (method=xkb)
  --dest-kmap PATH         Destination path for compiled .kmap
  --dest-xkb PATH          Destination path for XKB symbols (method=xkb)
  --keyboard-default PATH  Path to /etc/default/keyboard
  --download-only          Only download (and/or compile) files; do not change config or apply
  --no-apply               Do not run setupcon/update-initramfs
  --dry-run                Print planned actions only
  --force                  Overwrite existing files
  -h, --help               Show this help

NOTES:
  - This script must run as root to write under /etc and /usr/share and apply console settings.
  - For safety, prefer pinning URLs to a commit SHA or tag once your layout is stable.
EOF
}

log() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not installed"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

download_file() {
  local url="$1"
  local dest="$2"

  if have_cmd curl; then
    curl -fsSL --retry 3 --retry-delay 1 -o "$dest" "$url"
    return 0
  fi

  require_cmd wget
  wget -q --show-progress -O "$dest" "$url"
}

ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

backup_file_if_needed() {
  local path="$1"
  local backup_path="$2"

  if [ -e "$backup_path" ]; then
    return 0
  fi

  if [ -f "$path" ]; then
    cp -a "$path" "$backup_path"
  else
    : > "$backup_path"
  fi
}

set_kmap_in_keyboard_default() {
  local keyboard_default_file="$1"
  local kmap_path="$2"
  local backup_path="$3"

  if [ ! -f "$keyboard_default_file" ]; then
    die "$keyboard_default_file not found (is console-setup installed?)"
  fi

  backup_file_if_needed "$keyboard_default_file" "$backup_path"

  local kmap_line
  kmap_line="KMAP=\"${kmap_path}\""

  if grep -qE '^KMAP=' "$keyboard_default_file"; then
    sed -i "s|^KMAP=.*|${kmap_line}|" "$keyboard_default_file"
  else
    printf '\n%s\n' "$kmap_line" >> "$keyboard_default_file"
  fi
}

restore_keyboard_default() {
  local keyboard_default_file="$1"
  local backup_path="$2"

  if [ ! -e "$backup_path" ]; then
    die "Backup not found: $backup_path"
  fi

  if [ -s "$backup_path" ]; then
    cp -a "$backup_path" "$keyboard_default_file"
  else
    rm -f "$keyboard_default_file"
  fi
}

apply_console_settings() {
  require_cmd setupcon
  setupcon

  if have_cmd update-initramfs; then
    update-initramfs -u
  else
    log "Note: update-initramfs not found; skipping initramfs update."
  fi
}

METHOD="kmap"
KMAP_URL="$KASNER_KMAP_URL_DEFAULT"
XKB_URL="$KASNER_XKB_URL_DEFAULT"

DEST_KMAP="$DEST_KMAP_DEFAULT"
DEST_XKB="$DEST_XKB_DEFAULT"
KEYBOARD_DEFAULT_FILE="$KEYBOARD_DEFAULT_FILE_DEFAULT"

DOWNLOAD_ONLY=0
NO_APPLY=0
DRY_RUN=0
FORCE=0
UNINSTALL=0
PURGE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --method)
      [ "$#" -ge 2 ] || die "--method requires a value"
      METHOD="$2"
      shift 2
      ;;
    --kmap-url)
      [ "$#" -ge 2 ] || die "--kmap-url requires a value"
      KMAP_URL="$2"
      shift 2
      ;;
    --xkb-url)
      [ "$#" -ge 2 ] || die "--xkb-url requires a value"
      XKB_URL="$2"
      shift 2
      ;;
    --dest-kmap)
      [ "$#" -ge 2 ] || die "--dest-kmap requires a value"
      DEST_KMAP="$2"
      shift 2
      ;;
    --dest-xkb)
      [ "$#" -ge 2 ] || die "--dest-xkb requires a value"
      DEST_XKB="$2"
      shift 2
      ;;
    --keyboard-default)
      [ "$#" -ge 2 ] || die "--keyboard-default requires a value"
      KEYBOARD_DEFAULT_FILE="$2"
      shift 2
      ;;
    --download-only)
      DOWNLOAD_ONLY=1
      shift
      ;;
    --no-apply)
      NO_APPLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --uninstall)
      UNINSTALL=1
      shift
      ;;
    --purge)
      PURGE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (use --help)"
      ;;
  esac
done

if [ "$EUID" -ne 0 ]; then
  die "Please run as root (sudo)."
fi

case "$METHOD" in
  kmap|xkb) ;;
  *) die "Invalid --method: $METHOD (expected kmap or xkb)" ;;
esac

require_cmd sed
require_cmd grep

BACKUP_KEYBOARD_DEFAULT_FILE="${KEYBOARD_DEFAULT_FILE}.kasner.bak"

if [ "$UNINSTALL" -eq 1 ]; then
  log "Uninstall requested."
  log "Will restore: $KEYBOARD_DEFAULT_FILE from $BACKUP_KEYBOARD_DEFAULT_FILE"

  if [ "$PURGE" -eq 1 ]; then
    log "Will purge:   $DEST_KMAP"
    log "Will purge:   $DEST_XKB"
    log "Will purge:   $BACKUP_KEYBOARD_DEFAULT_FILE"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run: no changes made."
    exit 0
  fi

  restore_keyboard_default "$KEYBOARD_DEFAULT_FILE" "$BACKUP_KEYBOARD_DEFAULT_FILE"

  if [ "$PURGE" -eq 1 ]; then
    rm -f "$DEST_KMAP" "$BACKUP_KEYBOARD_DEFAULT_FILE"
    rm -f "$DEST_XKB"
  fi

  if [ "$NO_APPLY" -eq 1 ]; then
    log "Uninstalled, but not applied (--no-apply)."
    log "To apply now: setupcon && update-initramfs -u"
    exit 0
  fi

  log "Applying configuration..."
  apply_console_settings
  log "Done! Reverted console keyboard settings."
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

if [ "$METHOD" = "kmap" ]; then
  if [ "$FORCE" -ne 1 ] && [ -e "$DEST_KMAP" ]; then
    die "$DEST_KMAP already exists (use --force to overwrite)"
  fi

  log "Method: kmap (download precompiled .kmap)"
  log "Will download: $KMAP_URL"
  log "Will write:    $DEST_KMAP"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run: no changes made."
    exit 0
  fi

  tmp_kmap="$tmp_dir/kasner.kmap"
  download_file "$KMAP_URL" "$tmp_kmap"

  if ! head -n 1 "$tmp_kmap" | grep -qE '^(keymaps|include)'; then
    die "Downloaded file does not look like a Linux console keymap (.kmap)"
  fi

  ensure_parent_dir "$DEST_KMAP"
  install -m 0644 "$tmp_kmap" "$DEST_KMAP"

elif [ "$METHOD" = "xkb" ]; then
  require_cmd ckbcomp

  if [ "$FORCE" -ne 1 ] && { [ -e "$DEST_XKB" ] || [ -e "$DEST_KMAP" ]; }; then
    die "Destination file exists (use --force to overwrite)"
  fi

  log "Method: xkb (download XKB and compile to .kmap)"
  log "Will download: $XKB_URL"
  log "Will write:    $DEST_XKB"
  log "Will compile:  $DEST_KMAP"

  if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run: no changes made."
    exit 0
  fi

  tmp_xkb="$tmp_dir/kasner"
  download_file "$XKB_URL" "$tmp_xkb"

  if have_cmd rg; then
    if ! rg -q '^xkb_symbols\s+"kasner"' "$tmp_xkb" 2>/dev/null; then
      if ! head -n 20 "$tmp_xkb" | grep -q 'xkb_symbols'; then
        die "Downloaded file does not look like an XKB symbols file"
      fi
    fi
  else
    if ! head -n 50 "$tmp_xkb" | grep -q 'xkb_symbols'; then
      die "Downloaded file does not look like an XKB symbols file"
    fi
  fi

  ensure_parent_dir "$DEST_XKB"
  install -m 0644 "$tmp_xkb" "$DEST_XKB"

  ensure_parent_dir "$DEST_KMAP"
  ckbcomp kasner > "$DEST_KMAP"
fi

if [ "$DOWNLOAD_ONLY" -eq 1 ]; then
  if [ "$METHOD" = "kmap" ]; then
    log "Download-only complete: $DEST_KMAP"
  else
    log "Download-only complete: $DEST_XKB"
    log "Compile complete:       $DEST_KMAP"
  fi
  exit 0
fi

log "Configuring $KEYBOARD_DEFAULT_FILE..."
set_kmap_in_keyboard_default "$KEYBOARD_DEFAULT_FILE" "$DEST_KMAP" "$BACKUP_KEYBOARD_DEFAULT_FILE"

if [ "$NO_APPLY" -eq 1 ]; then
  log "Installed, but not applied (--no-apply)."
  log "To apply now: setupcon && update-initramfs -u"
  exit 0
fi

log "Applying configuration..."
apply_console_settings
log "Done! The kasner layout has been installed system-wide."
