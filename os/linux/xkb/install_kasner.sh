#!/usr/bin/env bash

set -euo pipefail

KASNER_REPO_RAW_BASE="https://raw.githubusercontent.com/rvkasner/keyboards"

KASNER_XKB_SYMBOLS_URL_DEFAULT="${KASNER_REPO_RAW_BASE}/main/os/linux/xkb/kasner"

DEST_XKB_SYMBOLS_DEFAULT="/usr/share/X11/xkb/symbols/kasner"
RULES_XML_DEFAULT="/usr/share/X11/xkb/rules/evdev.xml"
RULES_LST_DEFAULT="/usr/share/X11/xkb/rules/evdev.lst"

usage() {
  cat <<'EOF'
Install the Kasner XKB keyboard layouts and add them as input sources
for the current (non-root) user.

USAGE:
  ./install_kasner.sh [options]

LAYOUTS:
  --layouts en,ru,uk     Which Kasner layouts to enable for the user
                         (default: en,ru)

INSTALL OPTIONS:
  --xkb-url URL          Download URL for the XKB symbols file
  --dest-symbols PATH    Destination path for XKB symbols file
  --rules-xml PATH       Path to XKB rules XML (evdev.xml)
  --rules-lst PATH       Path to XKB rules list (evdev.lst)

UNINSTALL:
  --uninstall            Remove Kasner input sources from user and revert rules
  --purge                With --uninstall: also remove installed symbols and backups

BEHAVIOR:
  --dry-run              Print planned actions only
  --force                Overwrite existing system files and backups
  --no-user              Install system files only; do not touch user settings
  -h, --help             Show this help

NOTES:
  - Run this script as your normal user; it will ask for sudo only when needed.
  - GNOME uses gsettings (dconf). KDE may use different backends; this script
    supports GNOME directly and falls back to best-effort checks elsewhere.
  - After installation, a logout/login may be required for Wayland sessions.
EOF
}

log() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is not installed"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [ "${EUID}" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
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

backup_file_if_needed_root() {
  local path="$1"
  local backup_path="$2"

  if as_root test -e "$backup_path"; then
    return 0
  fi

  if as_root test -f "$path"; then
    as_root cp -a "$path" "$backup_path"
  else
    as_root sh -c ": > '$backup_path'"
  fi
}

restore_file_from_backup_root() {
  local path="$1"
  local backup_path="$2"

  as_root test -e "$backup_path" || die "Backup not found: $backup_path"

  if as_root test -s "$backup_path"; then
    as_root cp -a "$backup_path" "$path"
  else
    as_root rm -f "$path"
  fi
}

validate_layouts_list() {
  local layouts_csv="$1"

  # Accept en, ru, uk only (comma-separated).
  local part
  IFS=',' read -r -a parts <<<"$layouts_csv"
  [ "${#parts[@]}" -gt 0 ] || die "--layouts cannot be empty"
  for part in "${parts[@]}"; do
    case "$part" in
      en|ru|uk) ;;
      *) die "Unknown layout '$part' (expected en,ru,uk)" ;;
    esac
  done
}

python_render_sources_list() {
  local layouts_csv="$1"
  local layouts
  layouts="${layouts_csv}"

  python3 - <<PY
import sys
layouts = "${layouts}".split(',')

mapping = {
  'en': ('xkb', 'kasner+kasner(en)'),
  'ru': ('xkb', 'kasner+kasner(ru)'),
  'uk': ('xkb', 'kasner+kasner(uk)'),
}

out = []
for key in layouts:
  if key not in mapping:
    raise SystemExit(f"unknown layout: {key}")
  out.append(mapping[key])

def esc(s: str) -> str:
  return s.replace('\\\\', '\\\\\\\\').replace("'", "\\\\'")

items = ", ".join("('%s', '%s')" % (esc(a), esc(b)) for a,b in out)
print(f"[{items}]")
PY
}

gsettings_get_sources() {
  gsettings get org.gnome.desktop.input-sources sources 2>/dev/null || return 1
}

gsettings_set_sources() {
  local new_sources="$1"
  gsettings set org.gnome.desktop.input-sources sources "$new_sources"
}

gnome_add_sources() {
  local layouts_csv="$1"

  require_cmd gsettings
  require_cmd python3

  local current
  current="$(gsettings_get_sources)" || die "Failed to read GNOME input sources via gsettings"

  local kasner_sources
  kasner_sources="$(python_render_sources_list "$layouts_csv")"

  local merged
  merged="$(python3 - <<PY
import ast
current = ast.literal_eval("""${current}""")
kasner = ast.literal_eval("""${kasner_sources}""")

out = list(current)
for item in kasner:
  if item not in out:
    out.append(item)
print(out)
PY
)"

  gsettings_set_sources "$merged"
  log "GNOME: added Kasner input sources: ${layouts_csv}"
}

gnome_remove_sources() {
  require_cmd gsettings
  require_cmd python3

  local current
  current="$(gsettings_get_sources)" || die "Failed to read GNOME input sources via gsettings"

  local cleaned
  cleaned="$(python3 - <<'PY'
import ast

current = ast.literal_eval("""${current}""")

def is_kasner(item):
  if not isinstance(item, (list, tuple)) or len(item) != 2:
    return False
  t, v = item
  return t == 'xkb' and isinstance(v, str) and v.startswith('kasner')

out = [i for i in current if not is_kasner(i)]
print(out)
PY
)"

  gsettings_set_sources "$cleaned"
  log "GNOME: removed Kasner input sources"
}

install_system_files() {
  local xkb_url="$1"
  local dest_symbols="$2"
  local rules_xml="$3"
  local rules_lst="$4"
  local force="$5"

  require_cmd sed
  require_cmd grep

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  local tmp_symbols="$tmp_dir/kasner"
  download_file "$xkb_url" "$tmp_symbols"

  if ! head -n 50 "$tmp_symbols" | grep -q 'xkb_symbols'; then
    die "Downloaded file does not look like an XKB symbols file"
  fi

  if [ "$force" -ne 1 ] && as_root test -e "$dest_symbols"; then
    die "$dest_symbols already exists (use --force to overwrite)"
  fi

  log "Will install symbols: $dest_symbols"
  as_root install -m 0644 "$tmp_symbols" "$dest_symbols"

  local backup_xml="${rules_xml}.kasner.bak"
  local backup_lst="${rules_lst}.kasner.bak"

  if [ "$force" -eq 1 ]; then
    as_root rm -f "$backup_xml" "$backup_lst" || true
  fi

  backup_file_if_needed_root "$rules_xml" "$backup_xml"
  backup_file_if_needed_root "$rules_lst" "$backup_lst"

  # Register layouts in rules XML/LST.
  # This repo's XKB symbols file must define these variants:
  #   xkb_symbols "kasner"    (base)
  #   xkb_symbols "en"
  #   xkb_symbols "ru"
  #   xkb_symbols "uk"
  # If variants are missing, GUI selection and gsettings sources will fail.
  if ! grep -q '<name>kasner</name>' "$tmp_symbols" 2>/dev/null; then
    :
  fi

  local xml_block
  xml_block="$(cat <<'XML'
    <layout>
      <configItem>
        <name>kasner</name>
        <shortDescription>kas</shortDescription>
        <description>Kasner</description>
        <languageList>
          <iso639Id>eng</iso639Id>
          <iso639Id>rus</iso639Id>
          <iso639Id>ukr</iso639Id>
        </languageList>
      </configItem>
      <variantList>
        <variant>
          <configItem>
            <name>en</name>
            <description>Kasner En</description>
            <languageList><iso639Id>eng</iso639Id></languageList>
          </configItem>
        </variant>
        <variant>
          <configItem>
            <name>ru</name>
            <description>Kasner Ru</description>
            <languageList><iso639Id>rus</iso639Id></languageList>
          </configItem>
        </variant>
        <variant>
          <configItem>
            <name>uk</name>
            <description>Kasner Uk</description>
            <languageList><iso639Id>ukr</iso639Id></languageList>
          </configItem>
        </variant>
      </variantList>
    </layout>
XML
)"

  if as_root grep -q '<name>kasner</name>' "$rules_xml"; then
    log "XKB rules XML already contains kasner layout; skipping XML edit."
  else
    log "Registering kasner in: $rules_xml"
    as_root python3 - "$rules_xml" <<PY
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_text(encoding='utf-8', errors='replace')

needle = "</layoutList>"
idx = data.rfind(needle)
if idx == -1:
  raise SystemExit("Could not find </layoutList> in rules xml")

block = "\n" + ${xml_block!r} + "\n"
data = data[:idx] + block + data[idx:]
path.write_text(data, encoding='utf-8')
PY
  fi

  # Best-effort evdev.lst registration.
  if as_root grep -qE '^\s*kasner\s' "$rules_lst"; then
    log "XKB rules list already contains kasner; skipping LST edit."
  else
    log "Registering kasner in: $rules_lst"
    as_root python3 - "$rules_lst" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding='utf-8', errors='replace').splitlines(True)

out = []
inserted = False
in_layout = False

for line in lines:
  out.append(line)
  if line.strip() == '! layout':
    in_layout = True
    continue
  if in_layout and (line.startswith('!') and line.strip() != '! layout'):
    # Insert before next section.
    out.insert(len(out)-1, '  kasner          Kasner\n')
    inserted = True
    in_layout = False

if in_layout and not inserted:
  out.append('  kasner          Kasner\n')
  inserted = True

path.write_text(''.join(out), encoding='utf-8')
PY
  fi

  log "Clearing XKB cache: /var/lib/xkb/*.xkm"
  as_root rm -rf /var/lib/xkb/*.xkm || true
}

uninstall_system_files() {
  local dest_symbols="$1"
  local rules_xml="$2"
  local rules_lst="$3"
  local purge="$4"

  local backup_xml="${rules_xml}.kasner.bak"
  local backup_lst="${rules_lst}.kasner.bak"

  log "Restoring rules from backups (if present)"
  if as_root test -e "$backup_xml"; then
    restore_file_from_backup_root "$rules_xml" "$backup_xml"
  else
    log "No backup: $backup_xml (skipping)"
  fi
  if as_root test -e "$backup_lst"; then
    restore_file_from_backup_root "$rules_lst" "$backup_lst"
  else
    log "No backup: $backup_lst (skipping)"
  fi

  if [ "$purge" -eq 1 ]; then
    log "Purging: $dest_symbols"
    as_root rm -f "$dest_symbols" || true
    as_root rm -f "$backup_xml" "$backup_lst" || true
  fi

  as_root rm -rf /var/lib/xkb/*.xkm || true
}

LAYOUTS="en,ru"
XKB_URL="$KASNER_XKB_SYMBOLS_URL_DEFAULT"
DEST_SYMBOLS="$DEST_XKB_SYMBOLS_DEFAULT"
RULES_XML="$RULES_XML_DEFAULT"
RULES_LST="$RULES_LST_DEFAULT"

DRY_RUN=0
FORCE=0
NO_USER=0
UNINSTALL=0
PURGE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --layouts)
      [ "$#" -ge 2 ] || die "--layouts requires a value"
      LAYOUTS="$2"
      shift 2
      ;;
    --xkb-url)
      [ "$#" -ge 2 ] || die "--xkb-url requires a value"
      XKB_URL="$2"
      shift 2
      ;;
    --dest-symbols)
      [ "$#" -ge 2 ] || die "--dest-symbols requires a value"
      DEST_SYMBOLS="$2"
      shift 2
      ;;
    --rules-xml)
      [ "$#" -ge 2 ] || die "--rules-xml requires a value"
      RULES_XML="$2"
      shift 2
      ;;
    --rules-lst)
      [ "$#" -ge 2 ] || die "--rules-lst requires a value"
      RULES_LST="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --no-user)
      NO_USER=1
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

validate_layouts_list "$LAYOUTS"

if [ "${EUID}" -eq 0 ]; then
  die "Please run as a normal user (not root). The script will use sudo when needed."
fi

require_cmd python3

if [ "$UNINSTALL" -eq 1 ]; then
  log "Uninstall requested."
  log "Will restore: $RULES_XML and $RULES_LST from .kasner.bak backups (if present)"
  if [ "$PURGE" -eq 1 ]; then
    log "Will purge:   $DEST_SYMBOLS"
  fi
  if [ "$NO_USER" -ne 1 ]; then
    log "Will remove Kasner input sources for user: $USER"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    log "Dry-run: no changes made."
    exit 0
  fi

  if [ "$NO_USER" -ne 1 ] && have_cmd gsettings; then
    gnome_remove_sources || log "GNOME: failed to update gsettings (skipping)"
  fi

  uninstall_system_files "$DEST_SYMBOLS" "$RULES_XML" "$RULES_LST" "$PURGE"
  log "Done."
  exit 0
fi

log "Installing Kasner XKB symbols + rules (sudo required)."
log "Layouts to enable for user: $LAYOUTS"
log "Symbols URL: $XKB_URL"

if [ "$DRY_RUN" -eq 1 ]; then
  log "Would install: $DEST_SYMBOLS"
  log "Would edit:    $RULES_XML (backup: ${RULES_XML}.kasner.bak)"
  log "Would edit:    $RULES_LST (backup: ${RULES_LST}.kasner.bak)"
  if [ "$NO_USER" -ne 1 ]; then
    log "Would add GNOME sources for user: $USER"
  fi
  exit 0
fi

install_system_files "$XKB_URL" "$DEST_SYMBOLS" "$RULES_XML" "$RULES_LST" "$FORCE"

if [ "$NO_USER" -eq 1 ]; then
  log "Installed system files only (--no-user)."
  exit 0
fi

if have_cmd gsettings; then
  gnome_add_sources "$LAYOUTS"
  log "If you are on Wayland, you may need to log out and log back in."
else
  log "gsettings not found; cannot auto-add input sources."
  log "You can add layouts via your DE settings or test with: setxkbmap -layout kasner"
fi

log "Done!"

