#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/changecoin938/tunnel-me/main"
WORKDIR="/opt/spoof-tunnel"
STATE_DIR="$WORKDIR/state"
XRAY_BIN="/usr/local/bin/xray"
XRAY_CONF="/usr/local/etc/xray/config.json"
XRAY_SVC="xray"
DEFAULT_TUNNEL_PORT="8888"

C_RESET='\033[0m'; C_B='\033[1m'; C_GRN='\033[1;32m'; C_RED='\033[1;31m'
C_YLW='\033[1;33m'; C_CYN='\033[1;36m'; C_DIM='\033[2m'

msg(){ echo -e "${C_CYN}==>${C_RESET} $*"; }
ok(){ echo -e "${C_GRN}[OK]${C_RESET} $*"; }
warn(){ echo -e "${C_YLW}[!]${C_RESET} $*"; }
err(){ echo -e "${C_RED}[X]${C_RESET} $*" >&2; }
die(){ err "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "این اسکریپت باید با root اجرا شود (sudo -i)"

mkdir -p "$WORKDIR" "$STATE_DIR" "$WORKDIR/lib" "$WORKDIR/templates"

fetch_lib(){
  local f="$1"
  if [[ -f "$(dirname "$0")/lib/$f" ]]; then
    cp "$(dirname "$0")/lib/$f" "$WORKDIR/lib/$f"
  else
    curl -fsSL "$REPO_RAW/lib/$f" -o "$WORKDIR/lib/$f" || die "دانلود $f ناموفق بود"
  fi
  # shellcheck disable=SC1090
  source "$WORKDIR/lib/$f"
}

fetch_tpl(){
  local f="$1"
  if [[ -f "$(dirname "$0")/templates/$f" ]]; then
    cp "$(dirname "$0")/templates/$f" "$WORKDIR/templates/$f"
  else
    curl -fsSL "$REPO_RAW/templates/$f" -o "$WORKDIR/templates/$f" || die "دانلود قالب $f ناموفق بود"
  fi
}

load_modules(){
  for m in deps.sh creds.sh cloudflare.sh provision_exit.sh provision_relay.sh status.sh manage.sh; do
    fetch_lib "$m"
  done
  fetch_tpl xray-relay.json.tpl
}

banner(){
  clear
  echo -e "${C_B}${C_CYN}"
  echo "  ┌────────────────────────────────────────────┐"
  echo "  │      SPOOF-TUNNEL  ·  CDN Relay Installer    │"
  echo "  │      Iran-relay  ⇄  CDN  ⇄  Exit (x-ui)       │"
  echo "  └────────────────────────────────────────────┘"
  echo -e "${C_RESET}"
}

main_menu(){
  banner
  echo -e "  ${C_B}نقش این سرور را انتخاب کنید:${C_RESET}\n"
  echo -e "   ${C_GRN}1)${C_RESET} نصب نقش ${C_B}EXIT${C_RESET}   ${C_DIM}(سرور خارج، پشت Cloudflare، x-ui جدا)${C_RESET}"
  echo -e "   ${C_GRN}2)${C_RESET} نصب نقش ${C_B}RELAY${C_RESET}  ${C_DIM}(سرور ایران، لوله به سمت خارج)${C_RESET}"
  echo -e "   ${C_GRN}3)${C_RESET} نمایش ${C_B}وضعیت${C_RESET}"
  echo -e "   ${C_GRN}4)${C_RESET} ${C_B}مدیریت${C_RESET}    ${C_DIM}(ری‌استارت / آپدیت / حذف)${C_RESET}"
  echo -e "   ${C_GRN}0)${C_RESET} خروج\n"
  read -rp "  انتخاب [0-4]: " choice
  case "${choice:-}" in
    1) load_modules; provision_exit ;;
    2) load_modules; provision_relay ;;
    3) load_modules; show_status ;;
    4) load_modules; manage_menu ;;
    0) exit 0 ;;
    *) warn "انتخاب نامعتبر"; sleep 1; main_menu ;;
  esac
}

main_menu
