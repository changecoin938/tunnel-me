#!/usr/bin/env bash

show_status(){
  banner
  load_state
  echo -e "  ${C_B}وضعیت سرور${C_RESET}\n"

  local role="${ROLE:-نامشخص}"
  echo -e "   نقش          : ${C_B}${role}${C_RESET}"

  if systemctl is-active --quiet ${XRAY_SVC} 2>/dev/null; then
    echo -e "   سرویس Xray   : ${C_GRN}فعال${C_RESET}"
  else
    echo -e "   سرویس Xray   : ${C_RED}غیرفعال${C_RESET}"
  fi

  if [[ -x "$XRAY_BIN" ]]; then
    echo -e "   نسخه Xray    : ${C_DIM}$($XRAY_BIN version 2>/dev/null | head -n1)${C_RESET}"
  fi

  if [[ "${role}" == "relay" ]]; then
    echo -e "   دامین CDN    : ${C_B}${CDN_DOMAIN:-?}${C_RESET}"
    echo -e "   پورت‌ها      : ${C_B}${XUI_PORTS:-?}${C_RESET}"
    echo
    echo -e "  ${C_B}پورت‌های در حال گوش‌دادن:${C_RESET}"
    ss -tlnp 2>/dev/null | grep -i xray | awk '{print "   • "$4}' || echo "   (یافت نشد)"
    echo
    cdn_healthcheck "${CDN_DOMAIN:-}" "${CDN_PORT:-443}"
  elif [[ "${role}" == "exit" ]]; then
    echo -e "   دامین        : ${C_B}${CDN_DOMAIN:-?}${C_RESET}"
    echo -e "   IP سرور      : ${C_B}${EXIT_IP:-?}${C_RESET}"
    echo
    cdn_healthcheck "${CDN_DOMAIN:-}" 443
  fi

  echo
  read -rp "  Enter برای بازگشت ..." _
  main_menu
}

cdn_healthcheck(){
  local domain="$1" port="$2"
  [[ -n "$domain" ]] || { warn "دامین تنظیم نشده"; return; }
  echo -e "  ${C_B}تست سلامت اتصال به CDN:${C_RESET}"
  local code
  code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 8 \
    "https://${domain}:${port}/" 2>/dev/null || echo "000")"
  if [[ "$code" != "000" ]]; then
    echo -e "   ${C_GRN}دسترسی به ${domain} برقرار است (HTTP ${code})${C_RESET}"
  else
    echo -e "   ${C_RED}اتصال به ${domain} برقرار نشد — DNS/Proxy/فایروال را بررسی کنید${C_RESET}"
  fi
}
