#!/bin/bash
#
# Interactive multi-tool installer menu
# Usage: bash <(curl -s https://your-domain.com/installer.sh)
#
# To add a new "panel" (menu option), just add a new entry to the
# PANELS array below in the format:
#   "Display Name|apt-package-name|command-to-check-if-installed"
#

set -uo pipefail

# ── Color helpers ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Panels config (add more tools here) ──────────────────────
# Format: "Display Name|package-name|check-command"
PANELS=(
  "fastfetch|fastfetch|fastfetch"
  "neofetch|neofetch|neofetch"
)

# ── Special panels (custom submenus, not simple apt packages) ─
# Format: "Display Name|handler-function-name"
SPECIAL_PANELS=(
  "Pterodactyl|pterodactyl_menu"
)

# URL for the Pterodactyl default install script — change as needed
PTERODACTYL_SCRIPT_URL="https://pterodactyl-installer.se"

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
  local check_cmd="$1"
  command -v "$check_cmd" &>/dev/null
}

show_status() {
  local name="$1" check_cmd="$2"
  echo -e "\n${BOLD}== $name status ==${NC}"
  if is_installed "$check_cmd"; then
    echo -e "${GREEN}Installed${NC}"
    echo -e "Path: $(command -v "$check_cmd")"
    if "$check_cmd" --version &>/dev/null; then
      echo -e "Version: $("$check_cmd" --version | head -n1)"
    fi
  else
    echo -e "${RED}Not installed${NC}"
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

# ── Submenu for a single panel ───────────────────────────────
panel_menu() {
  local name="$1" pkg="$2" check_cmd="$3"
  while true; do
    clear
    echo -e "${BOLD}${CYAN}=== $name ===${NC}\n"
    echo "1) Status"
    echo "2) Install"
    echo "3) Reinstall"
    echo "4) Uninstall"
    echo "0) Back to main menu"
    echo
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

# ── Pterodactyl special panel ─────────────────────────────────
pterodactyl_menu() {
  while true; do
    clear
    echo -e "${BOLD}${CYAN}=== Pterodactyl ===${NC}\n"
    echo "1) Install (default script)"
    echo "0) Back to main menu"
    echo
    read -rp "Select an option: " choice
    case "$choice" in
      1)
        echo -e "\n${CYAN}Running default Pterodactyl install script...${NC}"
        echo -e "${YELLOW}Source: $PTERODACTYL_SCRIPT_URL${NC}\n"
        bash <(curl -s "$PTERODACTYL_SCRIPT_URL")
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Header ────────────────────────────────────────────────────
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
  echo -e "${BOLD}${CYAN}=============================${NC}"
  echo -e "${BOLD}${CYAN}   PRC GAMING CODE HUB${NC}"
  echo -e "${BOLD}${CYAN}=============================${NC}\n"
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
        echo -e "$i) $name ${GREEN}[installed]${NC}"
      else
        echo -e "$i) $name ${RED}[not installed]${NC}"
      fi
      ((i++))
    done

    local special_start=$i
    for panel in "${SPECIAL_PANELS[@]}"; do
      IFS='|' read -r name _ <<< "$panel"
      echo -e "$i) $name"
      ((i++))
    done

    echo "0) Exit"
    echo
    read -rp "Select an option: " sel

    if [[ "$sel" == "0" ]]; then
      echo "Bye!"
      exit 0
    fi

    if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#PANELS[@]} )); then
      IFS='|' read -r name pkg check_cmd <<< "${PANELS[$((sel-1))]}"
      panel_menu "$name" "$pkg" "$check_cmd"
    elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= special_start && sel < i )); then
      IFS='|' read -r name handler <<< "${SPECIAL_PANELS[$((sel-special_start))]}"
      "$handler"
    else
      echo -e "${RED}Invalid option${NC}"
      sleep 1
    fi
  done
}

main_menu
