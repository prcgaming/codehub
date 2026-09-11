#!/usr/bin/env bash
# ==============================================================================
#  PRC GAMING CODE HUB — Interactive Multi-Tool & Server Installer
#  Repository: https://github.com/prcgaming/codehub
#  Usage: bash <(curl -s https://raw.githubusercontent.com/prcgaming/codehub/refs/heads/main/installer.sh)
# ==============================================================================

set -uo pipefail

# ── Color Palette & Styling ───────────────────────────────────────────────────
ESC="\033"
NC="${ESC}[0m"
BOLD="${ESC}[1m"
DIM="${ESC}[2m"
ITALIC="${ESC}[3m"

# Primary Colors
CYAN="${ESC}[1;36m"
MAGENTA="${ESC}[1;35m"
BLUE="${ESC}[1;34m"
GREEN="${ESC}[1;32m"
YELLOW="${ESC}[1;33m"
RED="${ESC}[1;31m"
WHITE="${ESC}[1;37m"
GRAY="${ESC}[38;5;244m"

# ── Cursor & Terminal Safety ──────────────────────────────────────────────────
hide_cursor() {
  tput civis 2>/dev/null || printf "\033[?25l"
}

restore_cursor() {
  tput cnorm 2>/dev/null || printf "\033[?25h"
}

# Trap terminal exits so cursor is always restored
trap 'restore_cursor; echo -e "\n\n${CYAN}Exiting PRC Gaming Code Hub. Goodbye!${NC}"; exit 0' INT TERM EXIT

# ── Animation & Loading System ────────────────────────────────────────────────
# 1. Timed Spinner for steps / transitions
spinner_step() {
  local msg="$1"
  local duration="${2:-0.6}"
  local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local steps=8
  local delay
  delay=$(awk -v d="$duration" -v s="$steps" 'BEGIN {print d/s}' 2>/dev/null || echo "0.08")

  hide_cursor
  for ((i=0; i<steps; i++)); do
    local char="${spin_chars[$(( i % 10 ))]}"
    printf "\r  ${CYAN}%s${NC} %s " "$char" "$msg"
    sleep "$delay" 2>/dev/null || sleep 0.08
  done
  printf "\r  ${GREEN}✔${NC} %s ${GREEN}[Done]${NC}\n" "$msg"
  restore_cursor
}

# 2. Command Execution with Live Spinner
spinner_run() {
  local msg="$1"
  shift
  local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  local log_file="/tmp/prc_cmd_$$.log"

  hide_cursor
  "$@" > "$log_file" 2>&1 &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    local char="${spin_chars[$(( i % 10 ))]}"
    printf "\r  ${CYAN}%s${NC} %s " "$char" "$msg"
    sleep 0.08
    ((i++))
  done

  wait "$pid"
  local code=$?
  restore_cursor

  if [[ $code -eq 0 ]]; then
    printf "\r  ${GREEN}✔${NC} %s ${GREEN}[Success]${NC}\n" "$msg"
    rm -f "$log_file"
    return 0
  else
    printf "\r  ${RED}✖${NC} %s ${RED}[Failed (Exit Code: $code)]${NC}\n" "$msg"
    if [[ -s "$log_file" ]]; then
      echo -e "    ${GRAY}Error output:${NC}"
      tail -n 6 "$log_file" | sed 's/^/      /'
    fi
    rm -f "$log_file"
    return "$code"
  fi
}

# 3. Futuristic Cyberpunk Progress Bar
progress_loader() {
  local title="$1"
  local total_steps="${2:-24}"
  local step_delay="${3:-0.03}"

  hide_cursor
  echo -e "  ${BOLD}${WHITE}${title}${NC}"
  for ((step=1; step<=total_steps; step++)); do
    local pct=$(( (step * 100) / total_steps ))
    local bar=""
    for ((f=0; f<step; f++)); do bar+="█"; done
    for ((e=step; e<total_steps; e++)); do bar+="░"; done
    printf "\r  ${MAGENTA}❲${CYAN}%s${MAGENTA}❳ ${WHITE}%3d%%${NC}" "$bar" "$pct"
    sleep "$step_delay"
  done
  printf " ${GREEN}✔ Ready${NC}\n\n"
  restore_cursor
}

# ── Utility & Helper Functions ────────────────────────────────────────────────
pause() {
  echo ""
  read -rp "$(echo -e "${GRAY}Press ${CYAN}[Enter]${GRAY} to return...${NC}")" _
}

need_root() {
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
      SUDO="sudo"
    else
      echo -e "\n${RED}Error: This action requires root privileges, but 'sudo' was not found.${NC}"
      pause
      return 1
    fi
  else
    SUDO=""
  fi
  return 0
}

is_installed() {
  command -v "$1" &>/dev/null
}

get_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)        echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armhf)  echo "armhf" ;;
    i386|i686)     echo "386" ;;
    *)             echo "$arch" ;;
  esac
}

get_os_info() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${PRETTY_NAME:-$NAME}"
  elif command -v lsb_release &>/dev/null; then
    lsb_release -ds
  else
    uname -sr
  fi
}

get_ram_info() {
  if command -v free &>/dev/null; then
    free -h 2>/dev/null | awk '/^Mem:/ {print $3 " / " $2}'
  else
    echo "Unknown"
  fi
}

get_uptime_info() {
  if command -v uptime &>/dev/null; then
    uptime -p 2>/dev/null | sed 's/up //' || uptime | awk -F'( |,|:)+' '{print $6 "h " $7 "m"}'
  else
    echo "Unknown"
  fi
}

get_ip_info() {
  local ip
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -z "$ip" ]]; then
    ip=$(hostname 2>/dev/null || echo "127.0.0.1")
  fi
  echo "$ip"
}

hr() {
  echo -e "${GRAY}───────────────────────────────────────────────────────────────────${NC}"
}

box_title() {
  local title="$1"
  echo -e "\n${MAGENTA}╭─────────────────────────────────────────────────────────────────╮${NC}"
  printf "${MAGENTA}│${NC}  ${BOLD}${WHITE}%-61s${NC} ${MAGENTA}│${NC}\n" "$title"
  echo -e "${MAGENTA}╰─────────────────────────────────────────────────────────────────╯${NC}\n"
}

# ── Header & Banner ───────────────────────────────────────────────────────────
print_banner() {
  echo -e "${CYAN}"
  cat << "EOF"
  ██████╗ ██████╗  ██████╗     ██████╗  █████╗ ███╗   ███╗██╗███╗   ██╗ ██████╗ 
  ██╔══██╗██╔══██╗██╔════╝    ██╔════╝ ██╔══██╗████╗ ████║██║████╗  ██║██╔════╝ 
  ██████╔╝██████╔╝██║         ██║  ███╗███████║██╔████╔██║██║██╔██╗ ██║██║  ███╗
  ██╔═══╝ ██╔══██╗██║         ██║   ██║██╔══██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║
  ██║     ██║  ██║╚██████╗    ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝
  ╚═╝     ╚═╝  ╚═╝ ╚═════╝     ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
EOF
  echo -e "                   ${MAGENTA}⚡ ${BOLD}${WHITE}C O D E   H U B  —  I N S T A L L E R${NC} ${MAGENTA}⚡${NC}"
  echo ""

  # System Telemetry HUD Card
  local os_name ram_usage uptime_str server_ip
  os_name=$(get_os_info)
  ram_usage=$(get_ram_info)
  uptime_str=$(get_uptime_info)
  server_ip=$(get_ip_info)

  echo -e "${BLUE}╭─${GRAY}──[ ${CYAN}${BOLD}SYSTEM TELEMETRY${NC}${GRAY} ]${BLUE}────────────────────────────────────────────╮${NC}"
  printf "${BLUE}│${NC}  ${BOLD}OS:${NC} %-28s ${BLUE}│${NC} ${BOLD}Uptime:${NC} %-20s ${BLUE}│${NC}\n" "${os_name:0:28}" "${uptime_str:0:20}"
  printf "${BLUE}│${NC}  ${BOLD}RAM:${NC} %-27s ${BLUE}│${NC} ${BOLD}IP:${NC} %-24s ${BLUE}│${NC}\n" "${ram_usage:0:27}" "${server_ip:0:24}"
  echo -e "${BLUE}╰─────────────────────────────────────────────────────────────────╯${NC}"
}

# ── Splash / Loading Screen on Launch ─────────────────────────────────────────
splash_screen() {
  clear
  echo -e "${CYAN}"
  cat << "EOF"
  ██████╗ ██████╗  ██████╗     ██████╗  █████╗ ███╗   ███╗██╗███╗   ██╗ ██████╗ 
  ██╔══██╗██╔══██╗██╔════╝    ██╔════╝ ██╔══██╗████╗ ████║██║████╗  ██║██╔════╝ 
  ██████╔╝██████╔╝██║         ██║  ███╗███████║██╔████╔██║██║██╔██╗ ██║██║  ███╗
  ██╔═══╝ ██╔══██╗██║         ██║   ██║██╔══██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║
  ██║     ██║  ██║╚██████╗    ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝
  ╚═╝     ╚═╝  ╚═╝ ╚═════╝     ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ 
EOF
  echo -e "                   ${MAGENTA}⚡ ${BOLD}${WHITE}C O D E   H U B  —  I N S T A L L E R${NC} ${MAGENTA}⚡${NC}\n"

  progress_loader "Bootstrapping PRC Gaming Code Hub System..." 24 0.025
  spinner_step "Querying host kernel and hardware architecture..." 0.35
  spinner_step "Checking network adapters & public interface..." 0.35
  spinner_step "Scanning installed game panels & background services..." 0.4
  echo ""
  sleep 0.2
}

# ── Reusable Status Viewers ───────────────────────────────────────────────────
show_pkg_status() {
  local name="$1" cmd="$2" service="${3:-}"
  echo ""
  spinner_step "Inspecting $name status and binaries..." 0.3
  echo -e "\n${BOLD}${CYAN}=== $name Status Inspection ===${NC}\n"
  if is_installed "$cmd"; then
    echo -e "  ${GREEN}✔ Status:${NC}       ${BOLD}Installed${NC}"
    echo -e "  ${WHITE}📁 Binary Path:${NC}  $(command -v "$cmd")"
    if "$cmd" --version &>/dev/null; then
      echo -e "  ${WHITE}🏷️  Version:${NC}      $("$cmd" --version 2>&1 | head -n1)"
    elif "$cmd" -v &>/dev/null; then
      echo -e "  ${WHITE}🏷️  Version:${NC}      $("$cmd" -v 2>&1 | head -n1)"
    fi
  else
    echo -e "  ${RED}✖ Status:${NC}       ${GRAY}Not Installed${NC}"
  fi

  if [[ -n "$service" ]] && command -v systemctl &>/dev/null; then
    echo ""
    if systemctl list-unit-files 2>/dev/null | grep -qE "^${service}(\.service|\.socket)?"; then
      local state
      state=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
      local enabled
      enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
      echo -e "  ${BLUE}⚙️  Service '${service}':${NC} state: ${GREEN}$state${NC} | auto-start: ${YELLOW}$enabled${NC}"
    else
      echo -e "  ${GRAY}⚙️  Service '${service}': Not registered${NC}"
    fi
  fi
}

show_script_panel_status() {
  local name="$1" paths_csv="$2" services_csv="$3"
  echo ""
  spinner_step "Running deep filesystem & service audit for $name..." 0.4
  echo -e "\n${BOLD}${CYAN}=== $name Status (Deep Inspection) ===${NC}\n"
  local found=0

  IFS=',' read -ra paths <<< "$paths_csv"
  for p in "${paths[@]}"; do
    if [[ -e "$p" ]]; then
      echo -e "  ${GREEN}✔ Detected Path:${NC} $p"
      found=1
    fi
  done

  if [[ -n "$services_csv" ]] && command -v systemctl &>/dev/null; then
    IFS=',' read -ra srvs <<< "$services_csv"
    for srv in "${srvs[@]}"; do
      if systemctl list-unit-files 2>/dev/null | grep -qE "^${srv}(\.service|\.socket)?"; then
        local state
        state=$(systemctl is-active "$srv" 2>/dev/null || echo "inactive")
        echo -e "  ${GREEN}✔ Service '${srv}':${NC} active state: ${BOLD}$state${NC}"
        found=1
      fi
    done
  fi

  if [[ "$found" -eq 0 ]]; then
    echo -e "  ${RED}✖ Not detected${NC} ${GRAY}(Checked paths: $paths_csv)${NC}"
  fi
}

# ==============================================================================
#  SECTION 1: GAME & HOSTING PANELS (Pterodactyl, Pelican, Puffer, Skyport, JTG)
# ==============================================================================
menu_game_panels() {
  while true; do
    clear
    print_banner
    box_title "🎮 Game & Hosting Panels"

    local ptero_stat="${GRAY}[✖ Not Installed]${NC}"
    if [[ -d /var/www/pterodactyl || -d /etc/pterodactyl ]] || (command -v wings &>/dev/null); then
      ptero_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local pelican_stat="${GRAY}[✖ Not Installed]${NC}"
    if [[ -d /var/www/pelican || -d /etc/pelican ]] || (command -v pelican &>/dev/null); then
      pelican_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local puffer_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed pufferpanel || [[ -d /var/lib/pufferpanel || -d /etc/pufferpanel ]]; then
      puffer_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local skyport_stat="${GRAY}[✖ Not Installed]${NC}"
    if [[ -d /var/www/skyport || -d /opt/skyport || -d /etc/skyport ]] || (command -v skyport &>/dev/null); then
      skyport_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local jtg_stat="${GRAY}[✖ Not Installed]${NC}"
    if [[ -d /var/www/jtg || -d /opt/jtg ]]; then
      jtg_stat="${GREEN}[✔ Installed]${NC}"
    fi

    echo -e "  ${BOLD}${CYAN}1)${NC} Pterodactyl Panel & Wings       $ptero_stat"
    echo -e "  ${BOLD}${CYAN}2)${NC} Pelican Panel (Next-Gen)        $pelican_stat"
    echo -e "  ${BOLD}${CYAN}3)${NC} PufferPanel (Lightweight Web)   $puffer_stat"
    echo -e "  ${BOLD}${CYAN}4)${NC} Skyport Panel (Node.js & Docker)$skyport_stat"
    echo -e "  ${BOLD}${CYAN}5)${NC} JTG Panel                       $jtg_stat"
    echo ""
    echo -e "  ${BOLD}${WHITE}0)${NC} ⬅ Back to Main Menu"
    hr
    read -rp "Select an option [0-5]: " choice

    case "$choice" in
      1) submenu_pterodactyl ;;
      2) submenu_pelican ;;
      3) submenu_pufferpanel ;;
      4) submenu_skyport ;;
      5) submenu_jtg ;;
      0) return ;;
      *) echo -e "${RED}Invalid selection${NC}"; sleep 1 ;;
    esac
  done
}

# ── Pterodactyl ───────────────────────────────────────────────────────────────
submenu_pterodactyl() {
  while true; do
    clear
    print_banner
    box_title "Pterodactyl Panel & Wings"
    echo -e "  ${BOLD}1)${NC} Check Status & Detection"
    echo -e "  ${BOLD}2)${NC} Run Official Installer Script (pterodactyl-installer.se)"
    echo -e "  ${BOLD}3)${NC} Reinstall / Update (Re-run script)"
    echo -e "  ${BOLD}4)${NC} Uninstall Guidance"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_script_panel_status "Pterodactyl" "/var/www/pterodactyl,/etc/pterodactyl" "pteroq,wings"
        pause
        ;;
      2|3)
        echo -e "\n${CYAN}Launching Pterodactyl installer script...${NC}"
        echo -e "${YELLOW}Source: https://pterodactyl-installer.se${NC}\n"
        bash <(curl -s https://pterodactyl-installer.se)
        pause
        ;;
      4)
        echo -e "\n${YELLOW}Pterodactyl Uninstall Guide:${NC}"
        echo "To completely wipe Pterodactyl:"
        echo "  1. Stop services: sudo systemctl stop pteroq wings"
        echo "  2. Remove web files: sudo rm -rf /var/www/pterodactyl /etc/pterodactyl /etc/systemd/system/wings.service"
        echo "  3. Remove database: drop database panel from MySQL/MariaDB."
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Pelican ───────────────────────────────────────────────────────────────────
submenu_pelican() {
  while true; do
    clear
    print_banner
    box_title "Pelican Panel (Next-Gen Game Hosting)"
    echo -e "  ${BOLD}1)${NC} Check Status"
    echo -e "  ${BOLD}2)${NC} Install Pelican Panel (Official Script)"
    echo -e "  ${BOLD}3)${NC} Pelican Panel Official Docs"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_script_panel_status "Pelican Panel" "/var/www/pelican,/etc/pelican" "pelican,wings"
        pause
        ;;
      2)
        echo -e "\n${CYAN}Launching Pelican Panel installer...${NC}"
        echo -e "${YELLOW}Source: https://pelican.dev${NC}\n"
        if curl -sSL https://pelican.dev/installer.sh | bash; then
          echo -e "\n${GREEN}Pelican installation completed!${NC}"
        else
          echo -e "\n${RED}Installer exited with an error. Check requirements.${NC}"
        fi
        pause
        ;;
      3)
        echo -e "\n${CYAN}Pelican Documentation:${NC} https://pelican.dev/docs"
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── PufferPanel ───────────────────────────────────────────────────────────────
install_pufferpanel() {
  need_root || return 1
  echo ""
  spinner_step "Configuring PufferPanel PackageCloud repository..." 1.0
  curl -s https://packagecloud.io/install/repositories/pufferpanel/pufferpanel/script.deb.sh | $SUDO bash

  echo -e "\n${CYAN}Installing PufferPanel package...${NC}"
  $SUDO apt-get update -y && $SUDO apt-get install -y pufferpanel

  spinner_run "Starting and enabling PufferPanel service..." $SUDO systemctl enable --now pufferpanel

  echo -e "\n${GREEN}PufferPanel service started on port 8080!${NC}"
  echo -e "${YELLOW}Creating administrative user now...${NC}\n"
  $SUDO pufferpanel user add
  echo -e "\n${GREEN}Access your panel at: http://$(get_ip_info):8080${NC}"
}

uninstall_pufferpanel() {
  need_root || return 1
  echo ""
  spinner_run "Stopping PufferPanel service..." $SUDO systemctl stop pufferpanel
  echo -e "\n${CYAN}Uninstalling PufferPanel...${NC}"
  $SUDO apt-get remove --purge -y pufferpanel
  $SUDO rm -rf /var/lib/pufferpanel /etc/pufferpanel
  echo -e "${GREEN}PufferPanel removed.${NC}"
}

submenu_pufferpanel() {
  while true; do
    clear
    print_banner
    box_title "PufferPanel (Lightweight Game Server Panel)"
    echo -e "  ${BOLD}1)${NC} Check Status & Service"
    echo -e "  ${BOLD}2)${NC} Install PufferPanel"
    echo -e "  ${BOLD}3)${NC} Add / Create Admin User ('pufferpanel user add')"
    echo -e "  ${BOLD}4)${NC} Restart PufferPanel Service"
    echo -e "  ${BOLD}5)${NC} Uninstall PufferPanel"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "PufferPanel" "pufferpanel" "pufferpanel"
        if is_installed pufferpanel || [[ -d /var/lib/pufferpanel ]]; then
          echo -e "\n  ${CYAN}Web Interface:${NC} http://$(get_ip_info):8080"
        fi
        pause
        ;;
      2)
        install_pufferpanel
        pause
        ;;
      3)
        if is_installed pufferpanel; then
          need_root || continue
          $SUDO pufferpanel user add
        else
          echo -e "\n${RED}PufferPanel is not installed.${NC}"
        fi
        pause
        ;;
      4)
        need_root || continue
        spinner_run "Restarting PufferPanel service..." $SUDO systemctl restart pufferpanel
        pause
        ;;
      5)
        uninstall_pufferpanel
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Skyport Panel ─────────────────────────────────────────────────────────────
install_skyport() {
  need_root || return 1
  echo ""
  spinner_step "Initializing Skyport Panel deployment..." 0.8
  if curl -fsSL https://skyport.akashhalder.in/installer.sh &>/dev/null; then
    echo -e "${CYAN}Executing Skyport installer script...${NC}"
    curl -fsSL https://skyport.akashhalder.in/installer.sh | bash
  else
    echo -e "${YELLOW}Official web script unreachable, performing automatic git setup...${NC}"
    $SUDO apt-get update -y && $SUDO apt-get install -y git curl nodejs npm
    $SUDO mkdir -p /var/www/skyport
    cd /var/www/skyport
    $SUDO git clone https://github.com/skyport-team/panel .
    $SUDO npm install --production
    $SUDO npm run seed
    $SUDO npm run createUser
    echo -e "${GREEN}Skyport files installed in /var/www/skyport.${NC}"
  fi
  echo -e "${GREEN}Skyport installation completed!${NC}"
}

uninstall_skyport() {
  need_root || return 1
  echo ""
  spinner_run "Stopping Skyport background processes..." $SUDO systemctl stop skyport
  $SUDO rm -rf /var/www/skyport /opt/skyport /etc/systemd/system/skyport.service
  $SUDO systemctl daemon-reload 2>/dev/null || true
  echo -e "${GREEN}Skyport files removed.${NC}"
}

submenu_skyport() {
  while true; do
    clear
    print_banner
    box_title "Skyport Panel (Node.js & Docker)"
    echo -e "  ${BOLD}1)${NC} Check Status"
    echo -e "  ${BOLD}2)${NC} Install Skyport Panel"
    echo -e "  ${BOLD}3)${NC} Skyport Documentation & GitHub"
    echo -e "  ${BOLD}4)${NC} Uninstall Skyport"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_script_panel_status "Skyport Panel" "/var/www/skyport,/opt/skyport,/etc/skyport" "skyport"
        pause
        ;;
      2)
        install_skyport
        pause
        ;;
      3)
        echo -e "\n${CYAN}Skyport Documentation:${NC} https://skyport.akashhalder.in"
        echo -e "${CYAN}Skyport GitHub:${NC}        https://github.com/skyport-team/panel"
        pause
        ;;
      4)
        uninstall_skyport
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── JTG Panel ─────────────────────────────────────────────────────────────────
submenu_jtg() {
  while true; do
    clear
    print_banner
    box_title "JTG Panel Installer"
    echo -e "  ${BOLD}1)${NC} Check Status"
    echo -e "  ${BOLD}2)${NC} Run JTG Installer Script"
    echo -e "  ${BOLD}3)${NC} Re-run / Update Script"
    echo -e "  ${BOLD}4)${NC} Uninstall Guidance"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_script_panel_status "JTG Panel" "/var/www/jtg,/opt/jtg" "jtg"
        pause
        ;;
      2|3)
        echo -e "\n${CYAN}Launching JTG Panel installer...${NC}"
        echo -e "${YELLOW}Source: JishnuTheGamer/Jtg repo${NC}\n"
        bash <(curl -s https://raw.githubusercontent.com/JishnuTheGamer/Jtg/refs/heads/main/install.sh)
        pause
        ;;
      4)
        echo -e "\n${YELLOW}JTG Panel Uninstall Guide:${NC}"
        echo "Remove files in /var/www/jtg or /opt/jtg and stop any associated systemd service."
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ==============================================================================
#  SECTION 2: TUNNELING & NETWORKING (Cloudflare, Playit.gg, Tailscale)
# ==============================================================================
menu_tunnels() {
  while true; do
    clear
    print_banner
    box_title "🌐 Tunneling & Remote Access"

    local cf_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed cloudflared; then
      cf_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local playit_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed playit; then
      playit_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local ts_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed tailscale; then
      ts_stat="${GREEN}[✔ Installed]${NC}"
    fi

    echo -e "  ${BOLD}${CYAN}1)${NC} Cloudflare Tunnel (cloudflared)   $cf_stat"
    echo -e "  ${BOLD}${CYAN}2)${NC} Playit.gg Agent (Game Tunnel)     $playit_stat"
    echo -e "  ${BOLD}${CYAN}3)${NC} Tailscale (Mesh VPN)              $ts_stat"
    echo ""
    echo -e "  ${BOLD}${WHITE}0)${NC} ⬅ Back to Main Menu"
    hr
    read -rp "Select an option [0-3]: " choice

    case "$choice" in
      1) submenu_cloudflared ;;
      2) submenu_playit ;;
      3) submenu_tailscale ;;
      0) return ;;
      *) echo -e "${RED}Invalid selection${NC}"; sleep 1 ;;
    esac
  done
}

# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────
install_cloudflared() {
  need_root || return 1
  local arch deb_arch
  arch=$(get_arch)
  case "$arch" in
    amd64) deb_arch="amd64" ;;
    arm64) deb_arch="arm64" ;;
    386)   deb_arch="386" ;;
    armhf) deb_arch="arm" ;;
    *)     deb_arch="amd64" ;;
  esac

  echo ""
  spinner_step "Querying Cloudflare release servers for ${deb_arch} package..." 0.6
  local tmp_deb="/tmp/cloudflared.deb"
  local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${deb_arch}.deb"

  if curl -fL --progress-bar -o "$tmp_deb" "$url"; then
    echo -e "${CYAN}Installing package...${NC}"
    $SUDO dpkg -i "$tmp_deb" || $SUDO apt-get install -f -y
    rm -f "$tmp_deb"
    echo -e "${GREEN}Cloudflare Tunnel installed successfully!${NC}"
    cloudflared --version
  else
    echo -e "${RED}Failed to download cloudflared deb from $url${NC}"
    echo -e "${YELLOW}Attempting fallback via Cloudflare APT repository...${NC}"
    $SUDO mkdir -p --mode=0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | $SUDO tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs 2>/dev/null || echo "jammy") main" | $SUDO tee /etc/apt/sources.list.d/cloudflared.list
    $SUDO apt-get update -y && $SUDO apt-get install -y cloudflared
  fi
}

uninstall_cloudflared() {
  need_root || return 1
  echo ""
  spinner_run "Stopping cloudflared daemon..." $SUDO systemctl stop cloudflared
  $SUDO apt-get remove --purge -y cloudflared
  $SUDO rm -f /etc/apt/sources.list.d/cloudflared.list
  echo -e "${GREEN}cloudflared removed.${NC}"
}

quick_test_cloudflared() {
  if ! is_installed cloudflared; then
    echo -e "${RED}cloudflared is not installed!${NC}"
    return 1
  fi
  read -rp "Enter local port to expose (e.g. 80, 8080, 7681, 25565): " lport
  if [[ -n "$lport" ]]; then
    echo -e "\n${CYAN}Creating temporary Cloudflare quick tunnel for http://localhost:${lport}...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the tunnel at any time.${NC}\n"
    cloudflared tunnel --url "http://localhost:${lport}"
  fi
}

submenu_cloudflared() {
  while true; do
    clear
    print_banner
    box_title "Cloudflare Tunnel (cloudflared)"
    echo -e "  ${BOLD}1)${NC} Status & Version"
    echo -e "  ${BOLD}2)${NC} Install / Update to Latest Release"
    echo -e "  ${BOLD}3)${NC} Quick Tunnel Test (Expose local port instantly)"
    echo -e "  ${BOLD}4)${NC} Authenticate Tunnel ('cloudflared tunnel login')"
    echo -e "  ${BOLD}5)${NC} Uninstall cloudflared"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Cloudflare Tunnel" "cloudflared" "cloudflared"
        pause
        ;;
      2)
        install_cloudflared
        pause
        ;;
      3)
        quick_test_cloudflared
        pause
        ;;
      4)
        if is_installed cloudflared; then
          echo -e "\n${CYAN}Starting Cloudflare authentication...${NC}"
          cloudflared tunnel login
        else
          echo -e "\n${RED}cloudflared is not installed.${NC}"
        fi
        pause
        ;;
      5)
        uninstall_cloudflared
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Playit.gg ─────────────────────────────────────────────────────────────────
install_playit() {
  need_root || return 1
  echo ""
  spinner_step "Configuring Playit.gg APT PPA repository..." 0.8
  curl -SsL https://playit-cloud.github.io/ppa/key.gpg | gpg --dearmor | $SUDO tee /etc/apt/trusted.gpg.d/playit.gpg >/dev/null
  echo "deb [signed-by=/etc/apt/trusted.gpg.d/playit.gpg] https://playit-cloud.github.io/ppa/data ./" | $SUDO tee /etc/apt/sources.list.d/playit.list
  $SUDO apt-get update -y && $SUDO apt-get install -y playit
  echo -e "${GREEN}Playit.gg agent installed successfully!${NC}"
}

uninstall_playit() {
  need_root || return 1
  echo ""
  spinner_run "Stopping Playit agent service..." $SUDO systemctl stop playit
  $SUDO apt-get remove --purge -y playit
  $SUDO rm -f /etc/apt/sources.list.d/playit.list /etc/apt/trusted.gpg.d/playit.gpg
  echo -e "${GREEN}Playit.gg removed.${NC}"
}

submenu_playit() {
  while true; do
    clear
    print_banner
    box_title "Playit.gg (Game Server Port Forwarding)"
    echo -e "  ${BOLD}1)${NC} Status & Service State"
    echo -e "  ${BOLD}2)${NC} Install Playit.gg Agent"
    echo -e "  ${BOLD}3)${NC} Start Playit Claim Setup ('playit')"
    echo -e "  ${BOLD}4)${NC} Enable & Start Playit Background Service"
    echo -e "  ${BOLD}5)${NC} Uninstall Playit.gg"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Playit.gg Agent" "playit" "playit"
        pause
        ;;
      2)
        install_playit
        pause
        ;;
      3)
        if is_installed playit; then
          echo -e "\n${CYAN}Running playit claim flow (Copy URL into browser to link)...${NC}"
          playit
        else
          echo -e "\n${RED}Playit is not installed.${NC}"
        fi
        pause
        ;;
      4)
        need_root || continue
        spinner_run "Enabling and starting Playit service..." $SUDO systemctl enable --now playit
        pause
        ;;
      5)
        uninstall_playit
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Tailscale ─────────────────────────────────────────────────────────────────
install_tailscale() {
  need_root || return 1
  echo ""
  spinner_step "Executing Tailscale official setup script..." 0.8
  curl -fsSL https://tailscale.com/install.sh | sh
  echo -e "${GREEN}Tailscale installed successfully!${NC}"
}

uninstall_tailscale() {
  need_root || return 1
  echo ""
  spinner_run "Disconnecting Tailscale mesh network..." $SUDO tailscale down
  $SUDO apt-get remove --purge -y tailscale
  echo -e "${GREEN}Tailscale removed.${NC}"
}

submenu_tailscale() {
  while true; do
    clear
    print_banner
    box_title "Tailscale (Mesh VPN & Private Networking)"
    echo -e "  ${BOLD}1)${NC} Status & Connection"
    echo -e "  ${BOLD}2)${NC} Install Tailscale"
    echo -e "  ${BOLD}3)${NC} Connect Server ('tailscale up')"
    echo -e "  ${BOLD}4)${NC} Disconnect ('tailscale down')"
    echo -e "  ${BOLD}5)${NC} Uninstall Tailscale"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Tailscale" "tailscale" "tailscaled"
        if is_installed tailscale; then
          echo -e "\n${CYAN}Tailscale IP / Status:${NC}"
          tailscale status 2>/dev/null || true
        fi
        pause
        ;;
      2)
        install_tailscale
        pause
        ;;
      3)
        need_root || continue
        echo -e "\n${CYAN}Initiating Tailscale login...${NC}"
        $SUDO tailscale up
        pause
        ;;
      4)
        need_root || continue
        spinner_run "Disconnecting Tailscale..." $SUDO tailscale down
        pause
        ;;
      5)
        uninstall_tailscale
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ==============================================================================
#  SECTION 3: WEB TERMINALS & SHELL SHARING (ttyd, tmate, Cockpit, Starship)
# ==============================================================================
menu_terminals() {
  while true; do
    clear
    print_banner
    box_title "🖥️  Web Terminals & Remote Access"

    local ttyd_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed ttyd; then
      ttyd_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local tmate_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed tmate; then
      tmate_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local cockpit_stat="${GRAY}[✖ Not Installed]${NC}"
    if command -v cockpit-bridge &>/dev/null || (command -v systemctl &>/dev/null && systemctl list-unit-files 2>/dev/null | grep -q "cockpit.socket"); then
      cockpit_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local starship_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed starship; then
      starship_stat="${GREEN}[✔ Installed]${NC}"
    fi

    echo -e "  ${BOLD}${CYAN}1)${NC} ttyd (Web Browser Terminal)        $ttyd_stat"
    echo -e "  ${BOLD}${CYAN}2)${NC} tmate (Instant SSH & Web Sharing)  $tmate_stat"
    echo -e "  ${BOLD}${CYAN}3)${NC} Cockpit Web Console & Terminal     $cockpit_stat"
    echo -e "  ${BOLD}${CYAN}4)${NC} Starship Prompt (Futuristic Shell) $starship_stat"
    echo ""
    echo -e "  ${BOLD}${WHITE}0)${NC} ⬅ Back to Main Menu"
    hr
    read -rp "Select an option [0-4]: " choice

    case "$choice" in
      1) submenu_ttyd ;;
      2) submenu_tmate ;;
      3) submenu_cockpit ;;
      4) submenu_starship ;;
      0) return ;;
      *) echo -e "${RED}Invalid selection${NC}"; sleep 1 ;;
    esac
  done
}

# ── ttyd ──────────────────────────────────────────────────────────────────────
install_ttyd() {
  need_root || return 1
  echo ""
  spinner_step "Checking package repositories for ttyd..." 0.5
  if $SUDO apt-get update -y && $SUDO apt-get install -y ttyd; then
    echo -e "${GREEN}ttyd installed via package manager!${NC}"
    ttyd --version
    return 0
  fi

  # Fallback to official GitHub binary download
  local arch
  arch=$(uname -m)
  echo -e "${YELLOW}Apt package not available. Downloading prebuilt binary for ${arch}...${NC}"
  local url="https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${arch}"
  if curl -fsSL -o /tmp/ttyd "$url"; then
    $SUDO mv /tmp/ttyd /usr/local/bin/ttyd
    $SUDO chmod +x /usr/local/bin/ttyd
    echo -e "${GREEN}ttyd binary installed to /usr/local/bin/ttyd successfully!${NC}"
    /usr/local/bin/ttyd --version
  else
    echo -e "${RED}Failed to download ttyd from $url.${NC}"
  fi
}

start_quick_ttyd() {
  if ! is_installed ttyd; then
    echo -e "${RED}ttyd is not installed. Please install it first.${NC}"
    return 1
  fi
  read -rp "Enter port to run web terminal on [default 7681]: " port
  port="${port:-7681}"

  read -rp "Enable password protection? (y/n) [n]: " need_auth
  local auth_flag=""
  if [[ "$need_auth" =~ ^[Yy]$ ]]; then
    read -rp "Enter username: " tty_user
    read -rsp "Enter password: " tty_pass
    echo ""
    auth_flag="-c ${tty_user}:${tty_pass}"
  fi

  echo -e "\n${CYAN}Starting ttyd on http://$(get_ip_info):${port} ...${NC}"
  echo -e "${YELLOW}Open http://$(get_ip_info):${port} in your browser to access the terminal!${NC}"
  echo -e "${GRAY}Press Ctrl+C in this window to stop the session.${NC}\n"
  # shellcheck disable=SC2086
  ttyd -p "$port" $auth_flag bash
}

setup_ttyd_service() {
  need_root || return 1
  if ! is_installed ttyd; then
    echo -e "${RED}ttyd is not installed. Please install it first.${NC}"
    return 1
  fi
  read -rp "Enter port for persistent web terminal [default 7681]: " port
  port="${port:-7681}"

  read -rp "Enable password protection? (y/n) [y]: " need_auth
  need_auth="${need_auth:-y}"
  local auth_flag=""
  if [[ "$need_auth" =~ ^[Yy]$ ]]; then
    read -rp "Enter web terminal username: " tty_user
    read -rsp "Enter web terminal password: " tty_pass
    echo ""
    auth_flag="-c ${tty_user}:${tty_pass}"
  fi

  local ttyd_bin
  ttyd_bin=$(command -v ttyd)

  cat << EOF | $SUDO tee /etc/systemd/system/ttyd.service >/dev/null
[Unit]
Description=ttyd - Web Terminal Server
After=network.target

[Service]
Type=simple
ExecStart=${ttyd_bin} -p ${port} ${auth_flag} bash
Restart=always
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF

  spinner_run "Enabling and starting persistent ttyd service..." $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now ttyd
  echo -e "\n${GREEN}ttyd systemd service active!${NC}"
  echo -e "Access your browser terminal at: ${CYAN}http://$(get_ip_info):${port}${NC}"
}

uninstall_ttyd() {
  need_root || return 1
  echo ""
  spinner_run "Stopping ttyd background service..." $SUDO systemctl stop ttyd
  $SUDO systemctl disable ttyd 2>/dev/null || true
  $SUDO rm -f /etc/systemd/system/ttyd.service
  $SUDO systemctl daemon-reload 2>/dev/null || true
  $SUDO apt-get remove --purge -y ttyd 2>/dev/null || true
  $SUDO rm -f /usr/local/bin/ttyd
  echo -e "${GREEN}ttyd removed.${NC}"
}

submenu_ttyd() {
  while true; do
    clear
    print_banner
    box_title "ttyd (Web Browser Terminal Server)"
    echo -e "  ${BOLD}1)${NC} Check Status"
    echo -e "  ${BOLD}2)${NC} Install ttyd"
    echo -e "  ${BOLD}3)${NC} Launch Instant Web Terminal (Interactive)"
    echo -e "  ${BOLD}4)${NC} Install Persistent Background Service (systemd on port 7681)"
    echo -e "  ${BOLD}5)${NC} Stop Background Service"
    echo -e "  ${BOLD}6)${NC} Uninstall ttyd"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "ttyd" "ttyd" "ttyd"
        if command -v systemctl &>/dev/null && systemctl is-active ttyd &>/dev/null; then
          echo -e "\n  ${GREEN}🌐 Active Web Terminal:${NC} http://$(get_ip_info):7681"
        fi
        pause
        ;;
      2)
        install_ttyd
        pause
        ;;
      3)
        start_quick_ttyd
        pause
        ;;
      4)
        setup_ttyd_service
        pause
        ;;
      5)
        need_root || continue
        spinner_run "Stopping ttyd service..." $SUDO systemctl stop ttyd
        $SUDO systemctl disable ttyd 2>/dev/null || true
        pause
        ;;
      6)
        uninstall_ttyd
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── tmate ─────────────────────────────────────────────────────────────────────
install_tmate() {
  need_root || return 1
  echo ""
  spinner_step "Updating package sources for tmate..." 0.5
  $SUDO apt-get update -y && $SUDO apt-get install -y tmate
  echo -e "${GREEN}tmate installed successfully!${NC}"
}

generate_tmate_session() {
  if ! is_installed tmate; then
    echo -e "${RED}tmate is not installed. Please install it first.${NC}"
    return 1
  fi
  echo ""
  spinner_step "Initializing local session socket..." 0.3
  local sock="/tmp/tmate_prc_$$.sock"
  tmate -S "$sock" new-session -d

  spinner_step "Negotiating cryptographic relay handshake with tmate servers..." 1.0
  tmate -S "$sock" wait-for-client-ready 2>/dev/null || sleep 2

  local ssh_url web_url ssh_ro web_ro
  ssh_url=$(tmate -S "$sock" display -p '#{tmate_ssh}' 2>/dev/null)
  web_url=$(tmate -S "$sock" display -p '#{tmate_web}' 2>/dev/null)
  ssh_ro=$(tmate -S "$sock" display -p '#{tmate_ssh_ro}' 2>/dev/null)
  web_ro=$(tmate -S "$sock" display -p '#{tmate_web_ro}' 2>/dev/null)

  echo -e "\n${BOLD}${GREEN}╭──[ INSTANT TERMINAL ACCESS GRANTED ]───────────────────────────╮${NC}"
  echo -e "${BOLD}${WHITE}  ▶ Full Control (Read/Write):${NC}"
  echo -e "    ${CYAN}SSH:${NC}  $ssh_url"
  echo -e "    ${CYAN}Web:${NC}  $web_url"
  echo ""
  echo -e "${BOLD}${WHITE}  ▶ Read-Only (Safe Viewer):${NC}"
  echo -e "    ${GRAY}SSH:${NC}  $ssh_ro"
  echo -e "    ${GRAY}Web:${NC}  $web_ro"
  echo -e "${BOLD}${GREEN}╰────────────────────────────────────────────────────────────────╯${NC}"
  echo -e "\n${YELLOW}Share the SSH command or Web URL with anyone who needs terminal access!${NC}"
  echo -e "${GRAY}Type 'attach' to connect locally, or press Enter to terminate session.${NC}"
  read -rp "Selection: " act
  if [[ "$act" == "attach" ]]; then
    tmate -S "$sock" attach
  fi
  tmate -S "$sock" kill-session 2>/dev/null || true
  rm -f "$sock"
}

uninstall_tmate() {
  need_root || return 1
  echo ""
  spinner_step "Removing tmate package..." 0.5
  $SUDO apt-get remove --purge -y tmate
  echo -e "${GREEN}tmate removed.${NC}"
}

submenu_tmate() {
  while true; do
    clear
    print_banner
    box_title "tmate (Instant Terminal Sharing & SSH)"
    echo -e "  ${BOLD}1)${NC} Check Status"
    echo -e "  ${BOLD}2)${NC} Install tmate"
    echo -e "  ${BOLD}3)${NC} 🚀 Generate Instant Terminal Sharing Link (Web & SSH)"
    echo -e "  ${BOLD}4)${NC} Launch Interactive tmate Session"
    echo -e "  ${BOLD}5)${NC} Uninstall tmate"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "tmate" "tmate"
        pause
        ;;
      2)
        install_tmate
        pause
        ;;
      3)
        generate_tmate_session
        pause
        ;;
      4)
        if is_installed tmate; then
          tmate
        else
          echo -e "\n${RED}tmate is not installed.${NC}"
          pause
        fi
        ;;
      5)
        uninstall_tmate
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Cockpit ───────────────────────────────────────────────────────────────────
install_cockpit() {
  need_root || return 1
  echo ""
  spinner_step "Updating package repositories..." 0.5
  $SUDO apt-get update -y && $SUDO apt-get install -y cockpit
  spinner_run "Enabling and starting Cockpit web socket..." $SUDO systemctl enable --now cockpit.socket
  echo -e "\n${GREEN}Cockpit Web Console installed & activated!${NC}"
  echo -e "Open in your browser: ${CYAN}https://$(get_ip_info):9090${NC}"
  echo -e "${YELLOW}Note: Login with your server's Linux username and password.${NC}"
}

uninstall_cockpit() {
  need_root || return 1
  echo ""
  spinner_run "Stopping Cockpit service and socket..." $SUDO systemctl stop cockpit.socket cockpit
  $SUDO apt-get remove --purge -y cockpit cockpit-bridge cockpit-ws
  $SUDO apt-get autoremove -y
  echo -e "${GREEN}Cockpit removed.${NC}"
}

submenu_cockpit() {
  while true; do
    clear
    print_banner
    box_title "Cockpit (Web Server Manager & Terminal)"
    echo -e "  ${BOLD}1)${NC} Status & Service Info"
    echo -e "  ${BOLD}2)${NC} Install Cockpit Web Console"
    echo -e "  ${BOLD}3)${NC} Restart Cockpit Service"
    echo -e "  ${BOLD}4)${NC} Uninstall Cockpit"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Cockpit" "cockpit-bridge" "cockpit.socket"
        if command -v systemctl &>/dev/null && systemctl is-active cockpit.socket &>/dev/null; then
          echo -e "\n  ${GREEN}🌐 Cockpit Web Dashboard & Terminal:${NC} https://$(get_ip_info):9090"
        fi
        pause
        ;;
      2)
        install_cockpit
        pause
        ;;
      3)
        need_root || continue
        spinner_run "Restarting Cockpit socket..." $SUDO systemctl restart cockpit.socket
        pause
        ;;
      4)
        uninstall_cockpit
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Starship Prompt ───────────────────────────────────────────────────────────
install_starship() {
  need_root || return 1
  echo ""
  spinner_step "Downloading Starship installer..." 0.8
  curl -sS https://starship.rs/install.sh | sh -s -- -y

  local bashrc_file="${HOME}/.bashrc"
  if [[ -f "$bashrc_file" ]] && ! grep -q "starship init bash" "$bashrc_file"; then
    echo 'eval "$(starship init bash)"' >> "$bashrc_file"
    echo -e "${GREEN}Configured Starship in ${bashrc_file}!${NC}"
  fi
  echo -e "${GREEN}Starship installed! Run 'source ~/.bashrc' or restart shell to see your new prompt.${NC}"
}

uninstall_starship() {
  need_root || return 1
  echo ""
  spinner_step "Removing Starship binary and shell hooks..." 0.4
  $SUDO rm -f /usr/local/bin/starship
  sed -i '/starship init bash/d' "${HOME}/.bashrc" 2>/dev/null || true
  echo -e "${GREEN}Starship removed.${NC}"
}

submenu_starship() {
  while true; do
    clear
    print_banner
    box_title "Starship Prompt (Ultra-Fast Shell Aesthetics)"
    echo -e "  ${BOLD}1)${NC} Status & Version"
    echo -e "  ${BOLD}2)${NC} Install Starship Prompt"
    echo -e "  ${BOLD}3)${NC} Starship Official Presets & Docs"
    echo -e "  ${BOLD}4)${NC} Uninstall Starship"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Starship" "starship"
        pause
        ;;
      2)
        install_starship
        pause
        ;;
      3)
        echo -e "\n${CYAN}Starship Website & Presets:${NC} https://starship.rs"
        pause
        ;;
      4)
        uninstall_starship
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ==============================================================================
#  SECTION 4: DEVOPS, WEB & DATABASE STACK (Docker, Node.js, Nginx, MariaDB)
# ==============================================================================
menu_devops_stack() {
  while true; do
    clear
    print_banner
    box_title "🐳 DevOps, Web & Database Stack"

    local docker_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed docker; then
      docker_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local node_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed node; then
      node_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local nginx_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed nginx; then
      nginx_stat="${GREEN}[✔ Installed]${NC}"
    fi

    local mariadb_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed mariadb || is_installed mysql; then
      mariadb_stat="${GREEN}[✔ Installed]${NC}"
    fi

    echo -e "  ${BOLD}${CYAN}1)${NC} Docker & Docker Compose           $docker_stat"
    echo -e "  ${BOLD}${CYAN}2)${NC} Node.js (LTS) & npm               $node_stat"
    echo -e "  ${BOLD}${CYAN}3)${NC} Nginx Web Server & Certbot SSL    $nginx_stat"
    echo -e "  ${BOLD}${CYAN}4)${NC} MariaDB / MySQL Database Server   $mariadb_stat"
    echo ""
    echo -e "  ${BOLD}${WHITE}0)${NC} ⬅ Back to Main Menu"
    hr
    read -rp "Select an option [0-4]: " choice

    case "$choice" in
      1) submenu_docker ;;
      2) submenu_nodejs ;;
      3) submenu_nginx ;;
      4) submenu_mariadb ;;
      0) return ;;
      *) echo -e "${RED}Invalid selection${NC}"; sleep 1 ;;
    esac
  done
}

# ── Docker ────────────────────────────────────────────────────────────────────
install_docker() {
  need_root || return 1
  echo ""
  spinner_step "Downloading Docker convenience installer..." 0.8
  curl -fsSL https://get.docker.com | sh
  spinner_run "Enabling and starting Docker service..." $SUDO systemctl enable --now docker
  if [[ -n "${SUDO_USER:-}" ]]; then
    $SUDO usermod -aG docker "$SUDO_USER" 2>/dev/null || true
    echo -e "${YELLOW}Added user '$SUDO_USER' to docker group.${NC}"
  elif [[ -n "${USER:-}" && "$USER" != "root" ]]; then
    $SUDO usermod -aG docker "$USER" 2>/dev/null || true
    echo -e "${YELLOW}Added user '$USER' to docker group.${NC}"
  fi
  echo -e "${GREEN}Docker & Compose installed successfully!${NC}"
}

uninstall_docker() {
  need_root || return 1
  echo ""
  spinner_run "Stopping Docker services..." $SUDO systemctl stop docker
  echo -e "\n${CYAN}Removing Docker packages...${NC}"
  $SUDO apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io || true
  $SUDO apt-get autoremove -y
  echo -e "${GREEN}Docker uninstalled.${NC}"
}

submenu_docker() {
  while true; do
    clear
    print_banner
    box_title "Docker & Docker Compose"
    echo -e "  ${BOLD}1)${NC} Status & Container Check"
    echo -e "  ${BOLD}2)${NC} Install Latest Docker Engine & Compose"
    echo -e "  ${BOLD}3)${NC} Restart Docker Service"
    echo -e "  ${BOLD}4)${NC} Clean Unused Containers & Images (docker prune)"
    echo -e "  ${BOLD}5)${NC} Uninstall Docker"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Docker Engine" "docker" "docker"
        if is_installed docker; then
          echo ""
          docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || true
          echo -e "\n${CYAN}Active Containers:${NC}"
          docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
        fi
        pause
        ;;
      2)
        install_docker
        pause
        ;;
      3)
        need_root || continue
        spinner_run "Restarting Docker service..." $SUDO systemctl restart docker
        pause
        ;;
      4)
        if is_installed docker; then
          need_root || continue
          spinner_run "Pruning Docker system images, containers, and volumes..." $SUDO docker system prune -af --volumes
        else
          echo -e "${RED}Docker is not installed.${NC}"
        fi
        pause
        ;;
      5)
        uninstall_docker
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Node.js ───────────────────────────────────────────────────────────────────
install_nodejs() {
  need_root || return 1
  echo ""
  spinner_step "Setting up NodeSource LTS repository..." 0.8
  curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash -
  $SUDO apt-get install -y nodejs
  echo -e "${GREEN}Node.js and npm installed successfully!${NC}"
}

uninstall_nodejs() {
  need_root || return 1
  echo ""
  spinner_step "Uninstalling Node.js and npm..." 0.5
  $SUDO apt-get remove --purge -y nodejs
  $SUDO rm -f /etc/apt/sources.list.d/nodesource.list
  echo -e "${GREEN}Node.js removed.${NC}"
}

submenu_nodejs() {
  while true; do
    clear
    print_banner
    box_title "Node.js (LTS) & npm"
    echo -e "  ${BOLD}1)${NC} Status & Versions"
    echo -e "  ${BOLD}2)${NC} Install Latest Node.js LTS via NodeSource"
    echo -e "  ${BOLD}3)${NC} Update npm to Latest Version ('npm install -g npm')"
    echo -e "  ${BOLD}4)${NC} Install PM2 Process Manager globally"
    echo -e "  ${BOLD}5)${NC} Uninstall Node.js"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Node.js" "node"
        if is_installed npm; then
          echo -e "  ${WHITE}📦 npm Version:${NC}     $(npm -v)"
        fi
        if is_installed pm2; then
          echo -e "  ${GREEN}⚡ PM2 Process Mgr:${NC} Installed ($(pm2 -v))"
        fi
        pause
        ;;
      2)
        install_nodejs
        pause
        ;;
      3)
        if is_installed npm; then
          need_root || continue
          spinner_step "Upgrading npm to latest..." 0.8
          $SUDO npm install -g npm@latest
          echo -e "${GREEN}npm updated to $(npm -v).${NC}"
        else
          echo -e "${RED}npm is not installed.${NC}"
        fi
        pause
        ;;
      4)
        if is_installed npm; then
          need_root || continue
          spinner_step "Installing PM2 process manager globally..." 1.0
          $SUDO npm install -g pm2
          echo -e "${GREEN}PM2 installed successfully!${NC}"
        else
          echo -e "${RED}Node.js / npm not found.${NC}"
        fi
        pause
        ;;
      5)
        uninstall_nodejs
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── Nginx & SSL ───────────────────────────────────────────────────────────────
install_nginx() {
  need_root || return 1
  echo ""
  spinner_step "Updating repository index..." 0.5
  $SUDO apt-get update -y
  $SUDO apt-get install -y nginx certbot python3-certbot-nginx
  spinner_run "Enabling and starting Nginx..." $SUDO systemctl enable --now nginx
  echo -e "${GREEN}Nginx and Certbot installed successfully!${NC}"
}

uninstall_nginx() {
  need_root || return 1
  echo ""
  spinner_run "Stopping Nginx service..." $SUDO systemctl stop nginx
  $SUDO apt-get remove --purge -y nginx nginx-common certbot python3-certbot-nginx
  $SUDO apt-get autoremove -y
  echo -e "${GREEN}Nginx uninstalled.${NC}"
}

submenu_nginx() {
  while true; do
    clear
    print_banner
    box_title "Nginx Web Server & Certbot SSL"
    echo -e "  ${BOLD}1)${NC} Status & Service Info"
    echo -e "  ${BOLD}2)${NC} Install Nginx & Certbot"
    echo -e "  ${BOLD}3)${NC} Test Configuration ('nginx -t')"
    echo -e "  ${BOLD}4)${NC} Reload / Restart Nginx"
    echo -e "  ${BOLD}5)${NC} Issue Free SSL Certificate ('certbot --nginx')"
    echo -e "  ${BOLD}6)${NC} Uninstall Nginx"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "Nginx" "nginx" "nginx"
        pause
        ;;
      2)
        install_nginx
        pause
        ;;
      3)
        if is_installed nginx; then
          need_root || continue
          $SUDO nginx -t
        else
          echo -e "${RED}Nginx is not installed.${NC}"
        fi
        pause
        ;;
      4)
        if is_installed nginx; then
          need_root || continue
          spinner_run "Restarting Nginx service..." $SUDO systemctl restart nginx
        else
          echo -e "${RED}Nginx is not installed.${NC}"
        fi
        pause
        ;;
      5)
        if is_installed certbot; then
          need_root || continue
          echo -e "\n${CYAN}Running interactive Certbot wizard...${NC}"
          $SUDO certbot --nginx
        else
          echo -e "${RED}Certbot is not installed. Choose option 2 first.${NC}"
        fi
        pause
        ;;
      6)
        uninstall_nginx
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ── MariaDB ───────────────────────────────────────────────────────────────────
install_mariadb() {
  need_root || return 1
  echo ""
  spinner_step "Updating repository index..." 0.5
  $SUDO apt-get update -y
  $SUDO apt-get install -y mariadb-server mariadb-client
  spinner_run "Starting MariaDB database service..." $SUDO systemctl enable --now mariadb
  echo -e "${GREEN}MariaDB installed successfully!${NC}"
  echo -e "${YELLOW}Tip: Run option 3 to secure your installation with 'mariadb-secure-installation'.${NC}"
}

uninstall_mariadb() {
  need_root || return 1
  echo ""
  spinner_run "Stopping database daemon..." $SUDO systemctl stop mariadb
  $SUDO apt-get remove --purge -y mariadb-server mariadb-client
  $SUDO apt-get autoremove -y
  echo -e "${GREEN}MariaDB removed.${NC}"
}

submenu_mariadb() {
  while true; do
    clear
    print_banner
    box_title "MariaDB / MySQL Database"
    echo -e "  ${BOLD}1)${NC} Status & Service Info"
    echo -e "  ${BOLD}2)${NC} Install MariaDB Server"
    echo -e "  ${BOLD}3)${NC} Run Secure Installation ('mariadb-secure-installation')"
    echo -e "  ${BOLD}4)${NC} Restart MariaDB Service"
    echo -e "  ${BOLD}5)${NC} Uninstall MariaDB"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "MariaDB" "mariadb" "mariadb"
        pause
        ;;
      2)
        install_mariadb
        pause
        ;;
      3)
        need_root || continue
        if command -v mariadb-secure-installation &>/dev/null; then
          $SUDO mariadb-secure-installation
        elif command -v mysql_secure_installation &>/dev/null; then
          $SUDO mysql_secure_installation
        else
          echo -e "${RED}MariaDB is not installed.${NC}"
        fi
        pause
        ;;
      4)
        need_root || continue
        spinner_run "Restarting MariaDB service..." $SUDO systemctl restart mariadb
        pause
        ;;
      5)
        uninstall_mariadb
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ==============================================================================
#  SECTION 5: SYSTEM INFO & MONITORING (Fastfetch, Btop, Htop, Neofetch)
# ==============================================================================
menu_monitoring() {
  while true; do
    clear
    print_banner
    box_title "📊 System Info & Performance Monitors"

    local ff_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed fastfetch; then ff_stat="${GREEN}[✔ Installed]${NC}"; fi

    local btop_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed btop; then btop_stat="${GREEN}[✔ Installed]${NC}"; fi

    local htop_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed htop; then htop_stat="${GREEN}[✔ Installed]${NC}"; fi

    local neo_stat="${GRAY}[✖ Not Installed]${NC}"
    if is_installed neofetch; then neo_stat="${GREEN}[✔ Installed]${NC}"; fi

    echo -e "  ${BOLD}${CYAN}1)${NC} Fastfetch (Modern Hardware Fetcher)   $ff_stat"
    echo -e "  ${BOLD}${CYAN}2)${NC} Btop (Futuristic Terminal Monitor)    $btop_stat"
    echo -e "  ${BOLD}${CYAN}3)${NC} Htop (Interactive Process Viewer)     $htop_stat"
    echo -e "  ${BOLD}${CYAN}4)${NC} Neofetch (Classic CLI Fetcher)        $neo_stat"
    echo ""
    echo -e "  ${BOLD}${WHITE}0)${NC} ⬅ Back to Main Menu"
    hr
    read -rp "Select an option [0-4]: " choice

    case "$choice" in
      1) submenu_fastfetch ;;
      2) submenu_generic_tool "btop" "btop" "btop" ;;
      3) submenu_generic_tool "htop" "htop" "htop" ;;
      4) submenu_generic_tool "neofetch" "neofetch" "neofetch" ;;
      0) return ;;
      *) echo -e "${RED}Invalid selection${NC}"; sleep 1 ;;
    esac
  done
}

install_fastfetch() {
  need_root || return 1
  echo ""
  spinner_step "Querying repositories for fastfetch..." 0.5
  if $SUDO apt-get update -y && $SUDO apt-get install -y fastfetch; then
    echo -e "${GREEN}fastfetch installed successfully!${NC}"
    return 0
  fi

  # Fallback for older Ubuntu/Debian releases
  echo -e "${YELLOW}Not found in standard apt. Installing via PPA / GitHub release...${NC}"
  if command -v add-apt-repository &>/dev/null; then
    $SUDO add-apt-repository -y ppa:zhangsongcui3371/fastfetch 2>/dev/null || true
    $SUDO apt-get update -y && $SUDO apt-get install -y fastfetch && return 0
  fi

  local arch
  arch=$(get_arch)
  local deb_url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${arch}.deb"
  echo -e "${CYAN}Downloading $deb_url...${NC}"
  if curl -fL -o /tmp/fastfetch.deb "$deb_url"; then
    $SUDO dpkg -i /tmp/fastfetch.deb || $SUDO apt-get install -f -y
    rm -f /tmp/fastfetch.deb
    echo -e "${GREEN}fastfetch installed!${NC}"
  else
    echo -e "${RED}Failed to automatically install fastfetch.${NC}"
  fi
}

submenu_fastfetch() {
  while true; do
    clear
    print_banner
    box_title "Fastfetch Hardware Info"
    echo -e "  ${BOLD}1)${NC} Status & Check"
    echo -e "  ${BOLD}2)${NC} Install Fastfetch"
    echo -e "  ${BOLD}3)${NC} Run Fastfetch Now"
    echo -e "  ${BOLD}4)${NC} Uninstall Fastfetch"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "fastfetch" "fastfetch"
        pause
        ;;
      2)
        install_fastfetch
        pause
        ;;
      3)
        if is_installed fastfetch; then
          echo ""
          fastfetch
        else
          echo -e "\n${RED}fastfetch is not installed.${NC}"
        fi
        pause
        ;;
      4)
        need_root || continue
        spinner_step "Removing fastfetch..." 0.4
        $SUDO apt-get remove -y fastfetch
        echo -e "${GREEN}fastfetch removed.${NC}"
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

submenu_generic_tool() {
  local name="$1" pkg="$2" cmd="$3"
  while true; do
    clear
    print_banner
    box_title "$name Inspection & Setup"
    echo -e "  ${BOLD}1)${NC} Status & Check"
    echo -e "  ${BOLD}2)${NC} Install $name"
    echo -e "  ${BOLD}3)${NC} Launch $name Now"
    echo -e "  ${BOLD}4)${NC} Reinstall $name"
    echo -e "  ${BOLD}5)${NC} Uninstall $name"
    echo ""
    echo -e "  ${BOLD}0)${NC} Back"
    hr
    read -rp "Select an option: " c
    case "$c" in
      1)
        show_pkg_status "$name" "$cmd"
        pause
        ;;
      2)
        need_root || continue
        $SUDO apt-get update -y && $SUDO apt-get install -y "$pkg"
        echo -e "${GREEN}$name installed!${NC}"
        pause
        ;;
      3)
        if is_installed "$cmd"; then
          "$cmd"
        else
          echo -e "\n${RED}$name is not installed.${NC}"
          pause
        fi
        ;;
      4)
        need_root || continue
        $SUDO apt-get install --reinstall -y "$pkg"
        echo -e "${GREEN}$name reinstalled!${NC}"
        pause
        ;;
      5)
        need_root || continue
        spinner_step "Removing $name..." 0.4
        $SUDO apt-get remove -y "$pkg"
        echo -e "${GREEN}$name uninstalled.${NC}"
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
    esac
  done
}

# ==============================================================================
#  SECTION 6: SYSTEM TOOLS & MAINTENANCE
# ==============================================================================
menu_maintenance() {
  while true; do
    clear
    print_banner
    box_title "🛠️ System Utilities & Maintenance"
    echo -e "  ${BOLD}${CYAN}1)${NC} 📦 Install Essential Tools (curl, wget, git, jq, tmux, ufw, etc.)"
    echo -e "  ${BOLD}${CYAN}2)${NC} 🚀 Full System Upgrade (apt update & upgrade)"
    echo -e "  ${BOLD}${CYAN}3)${NC} 🧹 Clean Cache & Free Disk Space (apt, journal, docker)"
    echo -e "  ${BOLD}${CYAN}4)${NC} 🛡️  Quick Firewall Setup (UFW Enable & Open Ports)"
    echo ""
    echo -e "  ${BOLD}${WHITE}0)${NC} ⬅ Back to Main Menu"
    hr
    read -rp "Select an option [0-4]: " choice

    case "$choice" in
      1)
        need_root || continue
        echo -e "\n${CYAN}Installing essential server utilities...${NC}"
        $SUDO apt-get update -y
        $SUDO apt-get install -y curl wget git jq tmux screen unzip tar software-properties-common ca-certificates ufw htop
        echo -e "${GREEN}Essentials installed successfully!${NC}"
        pause
        ;;
      2)
        need_root || continue
        echo -e "\n${CYAN}Updating and upgrading system packages...${NC}"
        $SUDO apt-get update -y && $SUDO apt-get upgrade -y && $SUDO apt-get autoremove -y
        echo -e "${GREEN}System is fully up to date!${NC}"
        pause
        ;;
      3)
        need_root || continue
        echo ""
        spinner_run "Cleaning APT package archive caches..." $SUDO apt-get clean -y
        spinner_run "Removing obsolete downloaded archives..." $SUDO apt-get autoclean -y
        if command -v journalctl &>/dev/null; then
          spinner_run "Trimming systemd journal logs to last 3 days..." $SUDO journalctl --vacuum-time=3d
        fi
        if is_installed docker; then
          spinner_run "Pruning dangling Docker resources..." $SUDO docker system prune -f
        fi
        echo -e "\n${GREEN}Cleanup finished! Current disk space:${NC}"
        df -h / | tail -n 1
        pause
        ;;
      4)
        need_root || continue
        echo ""
        spinner_step "Configuring UFW rules..." 0.4
        $SUDO ufw allow 22/tcp
        $SUDO ufw allow 80/tcp
        $SUDO ufw allow 443/tcp
        $SUDO ufw allow 7681/tcp
        $SUDO ufw allow 9090/tcp
        spinner_run "Activating UFW firewall..." $SUDO ufw --force enable
        $SUDO ufw status verbose
        echo -e "\n${GREEN}UFW active with ports 22, 80, 443, 7681, and 9090 allowed.${NC}"
        pause
        ;;
      0) return ;;
      *) echo -e "${RED}Invalid selection${NC}"; sleep 1 ;;
    esac
  done
}

# ==============================================================================
#  MAIN DASHBOARD
# ==============================================================================
main_menu() {
  # Run animated splash screen on initial startup
  splash_screen

  while true; do
    clear
    print_banner

    echo -e "${BOLD}${WHITE}  SELECT A CATEGORY:${NC}\n"
    echo -e "  ${BOLD}${CYAN}1)${NC} 🎮  Game & Hosting Panels        ${GRAY}(Pterodactyl, Pelican, Puffer, Skyport, JTG)${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} 🌐  Tunneling & Remote Access     ${GRAY}(Cloudflare Tunnel, Playit.gg, Tailscale)${NC}"
    echo -e "  ${BOLD}${CYAN}3)${NC} 🖥️   Web Terminals & Remote Access ${GRAY}(ttyd, tmate, Cockpit, Starship)${NC}"
    echo -e "  ${BOLD}${CYAN}4)${NC} 🐳  DevOps, Web & Database       ${GRAY}(Docker, Node.js, Nginx, MariaDB)${NC}"
    echo -e "  ${BOLD}${CYAN}5)${NC} 📊  Monitoring & System Info      ${GRAY}(Fastfetch, Btop, Htop, Neofetch)${NC}"
    echo -e "  ${BOLD}${CYAN}6)${NC} 🛠️   System Tools & Maintenance    ${GRAY}(1-Click Essentials, Upgrades, Clean)${NC}"
    echo ""
    echo -e "  ${BOLD}${RED}0)${NC} 🚪  Exit"
    hr
    read -rp "$(echo -e "${BOLD}Enter choice [0-6]: ${NC}")" sel

    case "$sel" in
      1) menu_game_panels ;;
      2) menu_tunnels ;;
      3) menu_terminals ;;
      4) menu_devops_stack ;;
      5) menu_monitoring ;;
      6) menu_maintenance ;;
      0)
        echo -e "\n${CYAN}Thank you for using PRC GAMING CODE HUB! Happy hosting! 🚀${NC}\n"
        exit 0
        ;;
      *)
        echo -e "${RED}Invalid option. Please choose between 0 and 6.${NC}"
        sleep 1
        ;;
    esac
  done
}

# Launch the installer
main_menu
