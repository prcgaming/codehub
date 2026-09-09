#!/bin/bash
#
# PRC GAMING CODE HUB — interactive multi-tool installer menu
# Usage: bash <(curl -s https://raw.githubusercontent.com/prcgaming/codehub/refs/heads/main/installer.sh)
#
# To add a new simple apt-based tool, add a line to PANELS below:
#   "Display Name|apt-package-name|command-to-check-if-installed"
#
# To add a new script-based panel (like Pterodactyl / JTG), add a line
# to SPECIAL_PANELS:
#   "Display Name|install-script-url|candidate-path-1,candidate-path-2,...|service-name"
# (candidate paths / service name are used only for best-effort status detection)
#

set -uo pipefail

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Simple apt-based panels ───────────────────────────────────
PANELS=(
  "fastfetch|fastfetch|fastfetch"
  "neofetch|neofetch|neofetch"
)

# ── Script-based panels (custom installers) ──────────────────
# Format: "Display Name|script-url|comma,separated,candidate,paths|service-name"
SPECIAL_PANELS=(
  "Pterodactyl|https://pterodactyl-installer.se|/var/www/pterodactyl,/etc/pterodactyl|pteroq"
  "JTG Panel|https://raw.githubusercontent.com/JishnuTheGamer/Jtg/refs/heads/main/install.sh|/var/www/jtg,/opt/jtg|jtg"
)

# ── Helpers ───────────────────────────────────────────────────
pause() {
  read -rp $'\nPress Enter to continue...' _
}

need_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}This action requires sudo privileges.${NC}"
    SUDO="sudo"
  else
    SUDO=""
  fi
}

is_installed() {
  command -v "$1" &>/dev/null
}

hr() {
  echo -e "${DIM}─────────────────────────────────────${NC}"
}

# ── Status for simple apt tools ──────────────────────────────
show_status() {
  local name="$1" check_cmd="$2"
  echo -e "\n${BOLD}== $name status ==${NC}"
  if is_installed "$check_cmd"; then
    echo -e "${GREEN}● Installed${NC}"
    echo -e "Path: $(command -v "$check_cmd")"
    if "$check_cmd" --version &>/dev/null; then
      echo -e "Version: $("$check_cmd" --version | head -n1)"
    fi
  else
    echo -e "${RED}● Not installed${NC}"
  fi
}

install_pkg() {
  local name="$1" pkg="$2"
  need_root
  echo -e "\n${CYAN}Installing $name...${NC}"
  $SUDO apt update -y && $SUDO apt install -y "$pkg"
  echo -e "${GREEN}Done.${NC}"
}

uninstall_pkg() {
  local name="$1" pkg="$2"
  need_root
  echo -e "\n${CYAN}Uninstalling $name...${NC}"
  $SUDO apt remove -y "$pkg"
  echo -e "${GREEN}Done.${NC}"
}

reinstall_pkg() {
  local name="$1" pkg="$2"
  need_root
  echo -e "\n${CYAN}Reinstalling $name...${NC}"
  $SUDO apt install --reinstall -y "$pkg"
  echo -e "${GREEN}Done.${NC}"
}

# ── Submenu for a simple apt-based panel ─────────────────────
panel_menu() {
  local name="$1" pkg="$2" check_cmd="$3"
  while true; do
    clear
    print_subheader "$name"
    echo "1) Status"
    echo "2) Install"
    echo "3) Reinstall"
    echo "4) Uninstall"
    echo "0) Back to main menu"
    hr
    read -rp "Select an option: " choice
    case "$choice" in
      1) show_status "$name" "$check_cmd"; pause ;;
      2) install_pkg "$name" "$pkg"; pause ;;
      3) reinstall_pkg "$name" "$pkg"; pause ;;
      4) uninstall_pkg "$name" "$pkg"; pause ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Best-effort status check for script-based panels ─────────
# We can't know exactly how a third-party script installs things,
# so this checks a list of common install paths and an optional
# systemd service name. It's a best-effort detector, not a guarantee.
script_panel_status() {
  local name="$1" paths_csv="$2" service="$3"
  echo -e "\n${BOLD}== $name status (best-effort) ==${NC}"
  local found=0
  IFS=',' read -ra paths <<< "$paths_csv"
  for p in "${paths[@]}"; do
    if [[ -e "$p" ]]; then
      echo -e "${GREEN}● Found:${NC} $p"
      found=1
    fi
  done
  if [[ -n "$service" ]] && command -v systemctl &>/dev/null; then
    if systemctl list-unit-files 2>/dev/null | grep -q "^${service}\."; then
      local state
      state=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
      echo -e "${GREEN}● Service '$service' found${NC} — state: $state"
      found=1
    fi
  fi
  if [[ "$found" -eq 0 ]]; then
    echo -e "${RED}● Not detected${NC} ${DIM}(no known install paths or service found — it may still be installed in a custom location)${NC}"
  fi
}

# ── Submenu for a script-based panel (Pterodactyl, JTG, etc.) ─
script_panel_menu() {
  local name="$1" url="$2" paths_csv="$3" service="$4"
  while true; do
    clear
    print_subheader "$name"
    echo "1) Status"
    echo "2) Install (default script)"
    echo "3) Reinstall (re-run default script)"
    echo "4) Uninstall info"
    echo "0) Back to main menu"
    hr
    read -rp "Select an option: " choice
    case "$choice" in
      1)
        script_panel_status "$name" "$paths_csv" "$service"
        pause
        ;;
      2)
        echo -e "\n${CYAN}Running $name default install script...${NC}"
        echo -e "${YELLOW}Source: $url${NC}\n"
        bash <(curl -s "$url")
        pause
        ;;
      3)
        echo -e "\n${CYAN}Re-running $name install script (acts as reinstall/update for most installers)...${NC}"
        echo -e "${YELLOW}Source: $url${NC}\n"
        bash <(curl -s "$url")
        pause
        ;;
      4)
        echo -e "\n${YELLOW}$name does not have a single standard uninstall command.${NC}"
        echo "Check the project's official docs/repo for uninstall steps, as it"
        echo "usually involves removing web files, a database, and services."
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Headers ───────────────────────────────────────────────────
print_subheader() {
  local title="$1"
  echo -e "${BOLD}${MAGENTA}╭──────────────────────────────╮${NC}"
  printf "${BOLD}${MAGENTA}│${NC} ${BOLD}%-30s${NC} ${BOLD}${MAGENTA}│${NC}\n" "$title"
  echo -e "${BOLD}${MAGENTA}╰──────────────────────────────╯${NC}\n"
}

print_header() {
  echo -e "${GREEN}"
  cat << "EOF"
          .--.
         |o_o |
         |:_/ |
        //   \ \
       (|     | )
      /'\_   _/`\
      \___)=(___/
EOF
  echo -e "${NC}"
  echo -e "${BOLD}${CYAN}╔═══════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║${NC}      ${BOLD}${BLUE}PRC GAMING CODE HUB${NC}          ${BOLD}${CYAN}║${NC}"
  echo -e "${BOLD}${CYAN}╚═══════════════════════════════════╝${NC}\n"
}

# ── Main menu ─────────────────────────────────────────────────
main_menu() {
  while true; do
    clear
    print_header

    local i=1
    for panel in "${PANELS[@]}"; do
      IFS='|' read -r name pkg check_cmd <<< "$panel"
      if is_installed "$check_cmd"; then
        echo -e "  ${BOLD}$i)${NC} $name ${GREEN}[installed]${NC}"
      else
        echo -e "  ${BOLD}$i)${NC} $name ${RED}[not installed]${NC}"
      fi
      ((i++))
    done

    local special_start=$i
    for panel in "${SPECIAL_PANELS[@]}"; do
      IFS='|' read -r name _ _ _ <<< "$panel"
      echo -e "  ${BOLD}$i)${NC} ${MAGENTA}$name${NC}"
      ((i++))
    done

    echo -e "  ${BOLD}0)${NC} Exit"
    hr
    read -rp "Select an option: " sel

    if [[ "$sel" == "0" ]]; then
      echo -e "${CYAN}Bye!${NC}"
      exit 0
    fi

    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#PANELS[@]} )); then
      IFS='|' read -r name pkg check_cmd <<< "${PANELS[$((sel-1))]}"
      panel_menu "$name" "$pkg" "$check_cmd"
    elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= special_start && sel < i )); then
      IFS='|' read -r name url paths_csv service <<< "${SPECIAL_PANELS[$((sel-special_start))]}"
      script_panel_menu "$name" "$url" "$paths_csv" "$service"
    else
      echo -e "${RED}Invalid option${NC}"
      sleep 1
    fi
  done
}

main_menu
