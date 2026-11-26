#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
PROJECT_DIR=""
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" && pwd -P)"
  candidate_project_dir="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
  if [[ -f "$candidate_project_dir/shell.qml" && -d "$candidate_project_dir/configs" ]]; then
    PROJECT_DIR="$candidate_project_dir"
  fi
fi
readonly SCRIPT_DIR PROJECT_DIR
readonly CONFIG_DIR="$HOME/.cache/wisp-desktop"
readonly USER_PROJECT_DIR="$HOME/.config/quickshell/wisp-desktop"
readonly GREETER_QML="$USER_PROJECT_DIR/greeter.qml"
readonly DESKTOP_HOME="$HOME"
REPOSITORY_URL="https://github.com/2K24CSE5/wisp-desktop.git"
if [[ -n "$PROJECT_DIR" ]] && command -v git >/dev/null 2>&1 &&
  git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  detected_origin="$(git -C "$PROJECT_DIR" config --get remote.origin.url || true)"
  if [[ "$detected_origin" =~ ^git@github\.com:(.*)$ ]]; then
    detected_origin="https://github.com/${BASH_REMATCH[1]}"
  fi
  if [[ -n "$detected_origin" ]]; then
    REPOSITORY_URL="$detected_origin"
  fi
fi
readonly REPOSITORY_URL
readonly GREETER_LAUNCHER="/usr/local/bin/wisp-greeter"
readonly GREETER_NIRI_CONFIG="/etc/greetd/niri-greeter.kdl"
readonly GREETD_CONFIG="/etc/greetd/config.toml"

SKIP_PACKAGES=false
ENABLE_GREETD=true
GREETER_USER="${GREETER_USER:-}"
FONT_TMP=""
SUDO_KEEP_ALIVE_PID=""

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_BOLD=$'\033[1m'
  readonly C_BLUE=$'\033[38;2;177;204;195m'
  readonly C_CYAN=$'\033[38;2;133;214;192m'
  readonly C_GREEN=$'\033[32m'
  readonly C_YELLOW=$'\033[33m'
  readonly C_RED=$'\033[31m'
else
  readonly C_RESET=""
  readonly C_BOLD=""
  readonly C_BLUE=""
  readonly C_CYAN=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_RED=""
fi

if [[ "${LANG:-}" =~ [Uu][Tt][Ff]-?8 || "${LC_ALL:-}" =~ [Uu][Tt][Ff]-?8 || "${LC_CTYPE:-}" =~ [Uu][Tt][Ff]-?8 ]]; then
  readonly ICON_DOT="●"
  readonly ICON_CROSS="✖"
  readonly ICON_WARN="⚠"
else
  readonly ICON_DOT="*"
  readonly ICON_CROSS="[FAIL]"
  readonly ICON_WARN="[!]"
fi

print_banner() {
  printf '%s\n' \
    "${C_BLUE}╭───────────────────────────────────────────────╮" \
    "│                                               │" \
    "│        ${C_CYAN}██╗    ██╗██╗███████╗██████╗${C_BLUE}           │" \
    "│        ${C_CYAN}██║    ██║██║██╔════╝██╔══██╗${C_BLUE}          │" \
    "│        ${C_CYAN}██║ █╗ ██║██║███████╗██████╔╝${C_BLUE}          │" \
    "│        ${C_CYAN}██║███╗██║██║╚════██║██╔═══╝${C_BLUE}           │" \
    "│        ${C_CYAN}╚███╔███╔╝██║███████║██║${C_BLUE}               │" \
    "│        ${C_CYAN} ╚══╝╚══╝ ╚═╝╚══════╝╚═╝${C_BLUE}               │" \
    "│                                               │" \
    "│             ${C_CYAN}Wayland Desktop${C_BLUE}                   │" \
    "│                                               │" \
    "╰───────────────────────────────────────────────╯${C_RESET}"
  echo
}

step_header() {
  local num="$1"
  local total="$2"
  local title="$3"
  printf '%s\n' "${C_CYAN}${ICON_DOT}${C_RESET} ${C_BOLD}[${num}/${total}] ${title}${C_RESET}"
}

log_warn() {
  printf '  %s %s\n' "${C_YELLOW}${ICON_WARN}${C_RESET}" "$*" >&2
}

log_fail() {
  printf '  %s %s\n' "${C_RED}${ICON_CROSS}${C_RESET}" "$*" >&2
}

fail() {
  log_fail "$*"
  exit 1
}

on_error() {
  local line_no="${1:-unknown}"
  log_fail "Installer failed unexpectedly at line ${line_no}."
}

cleanup() {
  if [[ -n "$FONT_TMP" && -f "$FONT_TMP" ]]; then
    rm -f -- "$FONT_TMP"
  fi
  if [[ -n "$SUDO_KEEP_ALIVE_PID" ]]; then
    kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap 'on_error "$LINENO"' ERR

run_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command '$1' is not installed."
}

show_help() {
  cat <<'EOF'
Wisp Desktop installer

Usage: ./scripts/installation/install.sh [OPTIONS]

Options:
  --skip-packages  Do not install system packages or fonts
  --no-enable      Configure greetd without enabling it or disabling other display managers
  -h, --help       Show this help

Installs Wisp Desktop, Niri integration, GTK/Flatpak theme support, and greetd on Fedora.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --skip-packages)
        SKIP_PACKAGES=true
        ;;
      --no-enable)
        ENABLE_GREETD=false
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        fail "Unknown option: $1 (use --help for usage)"
        ;;
    esac
    shift
  done
}

verify_system() {
  step_header 1 7 "Checking System Compatibility"

  [[ -f /etc/os-release ]] || fail "Cannot identify this operating system (/etc/os-release is missing)."
  local os_id="" os_id_like="" os_pretty=""
  os_id="$(. /etc/os-release 2>/dev/null && echo "${ID:-}" || true)"
  os_id_like="$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-}" || true)"
  os_pretty="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-}" || true)"
  if [[ "$os_id" != "fedora" && "$os_id_like" != *"fedora"* ]]; then
    printf '\n%s\n' \
      "${C_RED}╭─────────────────── Distribution Error ──────────────────────╮" \
      "│                                                             │" \
      "│  Wisp Desktop installer is designed exclusively for Fedora. │" \
      "│                                                             │" \
      "│  Requirements: Fedora Linux 40+ and DNF                     │" \
      "│                                                             │" \
      "│  For other distributions, manual setup is required.         │" \
      "│                                                             │" \
      "╰─────────────────────────────────────────────────────────────╯${C_RESET}" >&2
    printf '\n%s\n' "${C_YELLOW}Detected system:${C_RESET} ${os_pretty:-$os_id}" >&2
    exit 1
  fi

  if [[ $EUID -eq 0 ]]; then
    fail "Run this installer as your regular user; it will request sudo when needed."
  fi
  need_command sudo
  if ! sudo -n true 2>/dev/null; then
    sudo -v || fail "Could not authenticate with sudo."
  fi

  while true; do
    sudo -n true 2>/dev/null || true
    sleep 30
  done 2>/dev/null &
  SUDO_KEEP_ALIVE_PID=$!

}

enable_copr() {
  local repo="$1"
  local repo_glob="$2"
  if compgen -G "$repo_glob" >/dev/null; then
    return 0
  fi

  run_root dnf copr enable -y "$repo" || fail "Could not enable COPR repository '$repo'."
}

install_packages() {
  step_header 2 7 "Installing Packages"

  if [[ "$SKIP_PACKAGES" == "true" ]]; then
    return 0
  fi

  need_command dnf
  enable_copr "errornointernet/quickshell" "/etc/yum.repos.d/*errornointernet*quickshell*.repo"
  enable_copr "scottames/ghostty" "/etc/yum.repos.d/*scottames*ghostty*.repo"

  local -a packages=(
    git
    curl
    findutils
    gawk
    python3
    nautilus-python
    acl
    polkit
    glib2
    fontconfig
    rsms-inter-fonts
    brightnessctl
    pulseaudio-utils
    wireplumber
    quickshell
    greetd
    greetd-selinux
    niri
    matugen
    ghostty
    wl-mirror
    adw-gtk3-theme
    flatpak
  )
  local -a missing=()
  local package

  for package in "${packages[@]}"; do
    if ! rpm -q "$package" >/dev/null 2>&1; then
      missing+=("$package")
    fi
  done

  if ((${#missing[@]})); then
    if ! run_root dnf install -y "${missing[@]}"; then
      log_warn "Standard package installation failed; retrying with --skip-unavailable."
      run_root dnf install -y --skip-unavailable "${missing[@]}" ||
        fail "Could not install required packages: ${missing[*]}"
    fi
  fi

  install_matugen_fallback
  install_material_symbols_font
}

install_matugen_fallback() {
  if command -v matugen >/dev/null 2>&1; then
    return 0
  fi

  export PATH="$HOME/.cargo/bin:$PATH"
  if command -v matugen >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    run_root dnf install -y cargo || fail "Could not install Cargo."
  fi
  command -v cargo >/dev/null 2>&1 || fail "Cargo is unavailable after installation."

  cargo install matugen || fail "Could not install Matugen via Cargo."
  if [[ -x "$HOME/.cargo/bin/matugen" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
    run_root ln -sf "$HOME/.cargo/bin/matugen" /usr/local/bin/matugen
  else
    fail "Cargo completed but the Matugen binary was not found."
  fi
}

install_material_symbols_font() {
  local font_dir="/usr/local/share/fonts/google-material-symbols"
  local font_file="$font_dir/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
  local font_url="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"

  if fc-list : family 2>/dev/null | grep -qi "Material Symbols Rounded"; then
    return 0
  fi

  FONT_TMP="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$font_url" -o "$FONT_TMP" || fail "Could not download the Material Symbols Rounded font with curl."
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$FONT_TMP" "$font_url" || fail "Could not download the Material Symbols Rounded font with wget."
  else
    fail "Neither curl nor wget is available to download the Material Symbols Rounded font."
  fi
  run_root install -D -o root -g root -m 0644 "$FONT_TMP" "$font_file"
  run_root fc-cache -f "$font_dir"
  rm -f -- "$FONT_TMP"
  FONT_TMP=""
}

setup_gtk_and_flatpak_theming() {
  local gtk3_dir="$HOME/.config/gtk-3.0"
  local gtk4_dir="$HOME/.config/gtk-4.0"
  local user_themes_dir="$HOME/.local/share/themes"
  local legacy_themes_dir="$HOME/.themes"

  mkdir -p "$gtk3_dir" "$gtk4_dir" "$user_themes_dir" "$legacy_themes_dir"

  if [[ ! -f "$gtk3_dir/settings.ini" ]]; then
    cat > "$gtk3_dir/settings.ini" <<'EOF'
[Settings]
gtk-theme-name = adw-gtk3-dark
gtk-application-prefer-dark-theme = 1
EOF
  fi

  if [[ ! -f "$gtk4_dir/settings.ini" ]]; then
    cat > "$gtk4_dir/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme = 1
EOF
  fi

  touch "$gtk3_dir/gtk.css" "$gtk4_dir/gtk.css"

  if command -v gsettings >/dev/null 2>&1; then
    if ! gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' ||
      ! gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'; then
      log_warn "Could not update GNOME interface settings in this session."
    fi
  fi

  local theme
  for theme in adw-gtk3 adw-gtk3-dark; do
    if [[ -d "/usr/share/themes/$theme" ]]; then
      if [[ ! -d "$user_themes_dir/$theme" ]]; then
        cp -a -- "/usr/share/themes/$theme" "$user_themes_dir/" ||
          fail "Could not install the $theme theme for the current user."
      fi
      if [[ ! -d "$legacy_themes_dir/$theme" ]]; then
        cp -a -- "/usr/share/themes/$theme" "$legacy_themes_dir/" ||
          fail "Could not install the $theme theme in the legacy themes directory."
      fi
    fi
  done

  if command -v flatpak >/dev/null 2>&1; then
    if ! flatpak override --user \
      --filesystem=xdg-config/gtk-3.0:ro \
      --filesystem=xdg-config/gtk-4.0:ro \
      --filesystem=xdg-data/themes:ro \
      --filesystem="$HOME/.themes:ro"; then
      log_warn "Could not apply Flatpak GTK theme filesystem overrides."
    fi

    if flatpak remotes 2>/dev/null | grep -qw "flathub"; then
      local -a missing_themes=()
      local theme_package
      for theme_package in org.gtk.Gtk3theme.adw-gtk3 org.gtk.Gtk3theme.adw-gtk3-dark; do
        if ! flatpak list --runtime 2>/dev/null | grep -qw "$theme_package"; then
          missing_themes+=("$theme_package")
        fi
      done
      if ((${#missing_themes[@]})); then
        if ! flatpak install -y --noninteractive flathub "${missing_themes[@]}"; then
          log_warn "Could not install one or more Flatpak GTK theme runtimes."
        fi
      fi
    fi
  fi
}

setup_ghostty_configuration() {
  local ghostty_dir="$HOME/.config/ghostty"
  local ghostty_config="$ghostty_dir/config"

  mkdir -p "$ghostty_dir"
  if [[ ! -f "$ghostty_config" ]]; then
    cat > "$ghostty_config" <<'EOF'
window-padding-x = 12
window-padding-y = 12
confirm-close-surface = false
config-file = ?theme.conf
EOF
  else
    local setting key
    for setting in \
      "window-padding-x = 12" \
      "window-padding-y = 12" \
      "confirm-close-surface = false"; do
      key="${setting%% =*}"
      if ! grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$ghostty_config"; then
        printf '%s\n' "$setting" >> "$ghostty_config"
      fi
    done
    if ! grep -q "theme.conf" "$ghostty_config"; then
      printf '\nconfig-file = ?theme.conf\n' >> "$ghostty_config"
    fi
  fi
}

setup_niri_configuration() {
  step_header 4 7 "Configuring Desktop Integration"

  local niri_dir="$HOME/.config/niri"
  local niri_config="$niri_dir/config.kdl"
  local alternate_config="$niri_dir/niri.kdl"
  local wisp_config="$niri_dir/wisp-desktop.kdl"

  mkdir -p "$niri_dir"
  if [[ ! -f "$niri_config" && -f "$alternate_config" ]]; then
    niri_config="$alternate_config"
  fi

  if [[ ! -f "$wisp_config" ]]; then
    cat > "$wisp_config" <<'EOF'
// Auto-generated by wisp-desktop
spawn-sh-at-startup "quickshell -p ~/.config/quickshell/wisp-desktop"
prefer-no-csd

hotkey-overlay {
  skip-at-startup
}

input {
  touchpad {
    tap
    natural-scroll
  }
  mouse {
    natural-scroll
  }
}

layer-rule {
  match namespace="^wisp-wallpaper$"
  place-within-backdrop true
}

overview {
  workspace-shadow {
    off
  }
}

recent-windows {
  highlight {
    active-color "#85d6c0"
    urgent-color "#ffb4ab"
    corner-radius 12
  }
}

layout {
  background-color "transparent"
  focus-ring {
    off
    active-color "#85d6c0"
    inactive-color "#3f4945"
    urgent-color "#ffb4ab"
  }

  border {
    off
    active-color "#85d6c0"
    inactive-color "#3f4945"
    urgent-color "#ffb4ab"
  }
}

window-rule {
    geometry-corner-radius 12
    clip-to-geometry true
    open-maximized true
}

binds {
  Mod+T {spawn-sh "ghostty"; }
  Mod+Q { close-window; }
  Mod+Left { focus-column-left; }
  Mod+Right { focus-column-right; }
  Mod+O { toggle-overview; }
  Mod+Page_Up { focus-workspace-up; }
  Mod+Page_Down { focus-workspace-down; }
}
EOF
  fi

  if [[ ! -f "$niri_config" ]]; then
    printf 'include "wisp-desktop.kdl"\n' > "$niri_config"
  elif grep -qE '^[[:space:]]*include[[:space:]]+"[./]*wisp-shell\.kdl"' "$niri_config"; then
    if grep -qE '^[[:space:]]*include[[:space:]]+"[./]*wisp-desktop\.kdl"' "$niri_config"; then
      sed -i -E '/^[[:space:]]*include[[:space:]]+"[./]*wisp-shell\.kdl"/d' "$niri_config"
    else
      sed -i -E 's|^([[:space:]]*include[[:space:]]+")[./]*wisp-shell\.kdl(".*)$|\1wisp-desktop.kdl\2|' "$niri_config"
    fi
  elif ! grep -qE '^[[:space:]]*include[[:space:]]+"[./]*wisp-desktop\.kdl"' "$niri_config"; then
    if [[ -s "$niri_config" ]] && [[ -n "$(tail -c 1 "$niri_config")" ]]; then
      printf '\n' >> "$niri_config"
    fi
    printf '\ninclude "wisp-desktop.kdl"\n' >> "$niri_config"
  fi

  if grep -qE '^[[:space:]]*spawn-at-startup[[:space:]]+"waybar"' "$niri_config"; then
    sed -i -E 's/^([[:space:]]*)(spawn-at-startup[[:space:]]+"waybar")/\1\/\/ Disabled for Wisp Desktop: \2/' "$niri_config" ||
      fail "Could not disable the Waybar startup entry."
  fi

  setup_gtk_and_flatpak_theming
  setup_ghostty_configuration

  if command -v niri >/dev/null 2>&1; then
    if ! niri validate -c "$niri_config" >/dev/null 2>&1; then
      log_warn "Niri configuration validation reported issues; run 'niri validate' to inspect."
    fi
  fi
}

deploy_project() {
  step_header 3 7 "Deploying Wisp Desktop Files"

  mkdir -p "$(dirname -- "$USER_PROJECT_DIR")"
  if [[ "$PROJECT_DIR" != "$USER_PROJECT_DIR" &&
    ! -d "$USER_PROJECT_DIR/.git" &&
    ( ! -f "$USER_PROJECT_DIR/shell.qml" || ! -f "$USER_PROJECT_DIR/greeter.qml" ) ]]; then
    if [[ -e "$USER_PROJECT_DIR" && ! -d "$USER_PROJECT_DIR" ]]; then
      fail "Destination exists and is not a directory: $USER_PROJECT_DIR"
    fi
    if [[ -d "$USER_PROJECT_DIR" ]] &&
      [[ -n "$(find "$USER_PROJECT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
      fail "Destination exists but is not an empty directory or Wisp Desktop checkout: $USER_PROJECT_DIR"
    fi

    need_command git
    git clone "$REPOSITORY_URL" "$USER_PROJECT_DIR" ||
      fail "Could not clone Wisp Desktop into $USER_PROJECT_DIR."
  fi

  for required in shell.qml greeter.qml components configs modules services; do
    [[ -e "$USER_PROJECT_DIR/$required" ]] ||
      fail "Project file or directory is missing: $USER_PROJECT_DIR/$required"
  done
}

install_greeter_launcher() {
  step_header 5 7 "Installing Wisp Greeter"

  cat <<EOF | run_root install -o root -g root -m 0755 /dev/stdin "$GREETER_LAUNCHER"
#!/usr/bin/env bash
set -Eeuo pipefail

unset DISPLAY WAYLAND_DISPLAY WAYLAND_SOCKET
umask 0077
export HOME="$DESKTOP_HOME"

runtime_dir="/run/user/\$(id -u)"
if [[ ! -d "\$runtime_dir" || ! -w "\$runtime_dir" ]]; then
  runtime_dir="/tmp/greetd-runtime-\$(id -u)"
  mkdir -p "\$runtime_dir"
  chmod 0700 "\$runtime_dir"
fi

export XDG_RUNTIME_DIR="\$runtime_dir"
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORM=wayland
export XDG_DATA_DIRS="/usr/local/share:/usr/share"

exec niri --config "$GREETER_NIRI_CONFIG" -- quickshell -p "$GREETER_QML"
EOF

  cat <<'EOF' | run_root install -o root -g root -m 0644 /dev/stdin "$GREETER_NIRI_CONFIG"
input {
    touchpad {
        tap
        natural-scroll
    }
}

prefer-no-csd
screenshot-path null

layout {
    background-color "#000000"
    focus-ring {
        off
    }
    border {
        off
    }
}

hotkey-overlay {
    skip-at-startup
}
EOF
}

setup_security_and_display_managers() {
  step_header 6 7 "Configuring Greeter"

  GREETER_USER="$(detect_greeter_user)"
  [[ "$GREETER_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] ||
    fail "Invalid greetd service account name: $GREETER_USER"

  if ! id -u "$GREETER_USER" >/dev/null 2>&1; then
    run_root useradd -r -M -d /var/lib/greetd -s /sbin/nologin -G video,input "$GREETER_USER" ||
      fail "Could not create greetd service account '$GREETER_USER'."
  else
    local -a groups
    read -r -a groups <<< "$(id -nG "$GREETER_USER")"
    if [[ ! " ${groups[*]} " =~ [[:space:]]video[[:space:]] ]] ||
      [[ ! " ${groups[*]} " =~ [[:space:]]input[[:space:]] ]]; then
      run_root usermod -aG video,input "$GREETER_USER" ||
        fail "Could not add '$GREETER_USER' to the video and input groups."
    fi
  fi

  run_root usermod -e "" "$GREETER_USER" ||
    fail "Could not clear the account expiry for '$GREETER_USER'."
  run_root usermod -L "$GREETER_USER" ||
    fail "Could not lock the password for '$GREETER_USER'."

  local target_owner="$GREETER_USER"
  if [[ -f /usr/lib/tmpfiles.d/greetd.conf ]]; then
    local tmpfile_owner
    tmpfile_owner="$(awk '/\/var\/lib\/greetd/ {print $4; exit}' /usr/lib/tmpfiles.d/greetd.conf)"
    if [[ -n "$tmpfile_owner" ]] && id -u "$tmpfile_owner" >/dev/null 2>&1; then
      target_owner="$tmpfile_owner"
    fi
  fi

  run_root install -d -o root -g root -m 0755 /etc/greetd
  run_root mkdir -p /var/lib/greetd
  run_root chown -R "$target_owner:$target_owner" /var/lib/greetd ||
    fail "Could not set ownership on /var/lib/greetd."
  run_root chmod 0750 /var/lib/greetd ||
    fail "Could not set permissions on /var/lib/greetd."

  need_command setfacl
  mkdir -p "$HOME/.config/quickshell" "$HOME/.cache" "$CONFIG_DIR"

  apply_acls_for_user() {
    local user="$1"
    setfacl -m "u:$user:x" "$HOME" "$HOME/.config" "$HOME/.config/quickshell" "$HOME/.cache" ||
      fail "Could not grant '$user' access through the user configuration directories."
    setfacl -R -m "u:$user:rX,d:u:$user:rX" "$USER_PROJECT_DIR" ||
      fail "Could not grant '$user' read access to the project files."
    setfacl -R -m "u:$user:rwX,d:u:$user:rwx" "$CONFIG_DIR" ||
      fail "Could not grant '$user' access to Wisp Desktop settings."
  }

  apply_acls_for_user "$GREETER_USER"
  local related_user
  for related_user in greeter greetd; do
    if [[ "$GREETER_USER" != "$related_user" ]] && id -u "$related_user" >/dev/null 2>&1; then
      apply_acls_for_user "$related_user"
    fi
  done
}

detect_greeter_user() {
  if [[ -n "$GREETER_USER" ]]; then
    printf '%s\n' "$GREETER_USER"
    return
  fi

  if [[ -f "$GREETD_CONFIG" ]]; then
    local configured
    configured="$(awk '
      /^\[default_session\][[:space:]]*$/ { in_default = 1; next }
      /^\[/ { in_default = 0 }
      in_default && /^[[:space:]]*user[[:space:]]*=/ {
        line = $0
        sub(/^[^=]*=[[:space:]]*"/, "", line)
        sub(/".*$/, "", line)
        print line
        exit
      }
    ' "$GREETD_CONFIG")"
    if [[ -n "$configured" ]]; then
      printf '%s\n' "$configured"
      return
    fi
  fi

  if id -u greetd >/dev/null 2>&1; then
    printf '%s\n' greetd
  elif id -u greeter >/dev/null 2>&1; then
    printf '%s\n' greeter
  else
    printf '%s\n' greetd
  fi
}

configure_greetd() {
  GREETER_USER="$(detect_greeter_user)"
  [[ "$GREETER_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] ||
    fail "Invalid greetd service account name: $GREETER_USER"
  id -u "$GREETER_USER" >/dev/null 2>&1 ||
    fail "The greetd service account '$GREETER_USER' does not exist."

  run_root install -d -o root -g root -m 0755 /etc/greetd
  if [[ -f "$GREETD_CONFIG" && ! -f "$GREETD_CONFIG.orig" ]]; then
    run_root cp -a -- "$GREETD_CONFIG" "$GREETD_CONFIG.orig"
  fi

  local updated_config
  local current_config="$GREETD_CONFIG"
  updated_config="$(mktemp)"
  [[ -f "$current_config" ]] || current_config="/dev/null"
  awk -v launcher="$GREETER_LAUNCHER" -v user="$GREETER_USER" '
    function finish_default() {
      if (!seen_command) print "command = \"" launcher "\""
      if (!seen_user) print "user = \"" user "\""
    }
    BEGIN { in_default = 0; skip_section = 0; saw_default = 0 }
    /^[[:space:]]*\[/ {
      if (in_default) finish_default()
      in_default = 0
      skip_section = 0

      if ($0 ~ /^[[:space:]]*\[initial_session\][[:space:]]*$/) {
        skip_section = 1
        next
      }
      if ($0 ~ /^[[:space:]]*\[default_session\][[:space:]]*$/) {
        if (saw_default) {
          skip_section = 1
          next
        }
        saw_default = 1
        in_default = 1
        seen_command = 0
        seen_user = 0
        print
        next
      }
      print
      next
    }
    skip_section { next }
    in_default && /^[[:space:]]*command[[:space:]]*=/ {
      print "command = \"" launcher "\""
      seen_command = 1
      next
    }
    in_default && /^[[:space:]]*user[[:space:]]*=/ {
      print "user = \"" user "\""
      seen_user = 1
      next
    }
    { print }
    END {
      if (in_default) finish_default()
      if (!saw_default) {
        print ""
        print "[default_session]"
        print "command = \"" launcher "\""
        print "user = \"" user "\""
      }
    }
  ' "$current_config" > "$updated_config" || {
    rm -f -- "$updated_config"
    fail "Could not generate greetd configuration."
  }
  run_root install -o root -g root -m 0644 "$updated_config" "$GREETD_CONFIG"
  rm -f -- "$updated_config"
}

enable_greetd() {
  if [[ "$ENABLE_GREETD" != "true" ]]; then
    return 0
  fi

  local service
  for service in gdm.service sddm.service lightdm.service lxdm.service ly.service lemurs.service emptty.service; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
      log_warn "Disabling conflicting display manager $service."
      run_root systemctl disable "$service"
    fi
  done
  run_root systemctl enable greetd.service || fail "Could not enable greetd.service."
  run_root systemctl set-default graphical.target
}

verify_installation() {
  step_header 7 7 "Verifying Installation"

  local command
  for command in quickshell niri greetd matugen python3; do
    command -v "$command" >/dev/null 2>&1 ||
      fail "Required command '$command' is missing; rerun without --skip-packages."
  done
  for command in ghostty wl-mirror; do
    command -v "$command" >/dev/null 2>&1 ||
      log_warn "Optional command '$command' is not installed."
  done

  [[ -x "$GREETER_LAUNCHER" ]] || fail "Greeter launcher was not installed."
  [[ -f "$GREETER_QML" ]] || fail "Greeter QML file was not installed."
  grep -Fq "command = \"$GREETER_LAUNCHER\"" "$GREETD_CONFIG" ||
    fail "The greetd default session does not use the Wisp Desktop launcher."
  fc-list : family | grep -qi "Material Symbols Rounded" ||
    fail "The Material Symbols Rounded font is not available."
  if command -v flatpak >/dev/null 2>&1; then
    local flatpak_overrides
    flatpak_overrides="$(flatpak override --user --show 2>/dev/null || true)"
    if [[ ! "$flatpak_overrides" =~ xdg-config/gtk-4\.0 || ! "$flatpak_overrides" =~ xdg-config/gtk-3\.0 ]]; then
      log_warn "Flatpak GTK theme overrides may not be active."
    fi
  fi
}

print_summary() {
  echo
  printf '%s\n' \
    "${C_GREEN}╭─────────────────────────────────────────────────────────────╮" \
    "│ ${C_BOLD}Installation Complete${C_RESET}${C_GREEN}                                       │" \
    "│ ${C_CYAN}Reboot your system for the changes to take effect.${C_RESET}${C_GREEN}          │" \
    "╰─────────────────────────────────────────────────────────────╯${C_RESET}"
  echo
}

main() {
  parse_args "$@"
  print_banner
  verify_system
  install_packages
  deploy_project
  setup_niri_configuration
  install_greeter_launcher
  setup_security_and_display_managers
  configure_greetd
  enable_greetd
  verify_installation
  print_summary
}

main "$@"
