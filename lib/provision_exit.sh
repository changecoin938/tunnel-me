#!/usr/bin/env bash

provision_exit(){
  banner
  echo -e "  ${C_B}نصب نقش EXIT (سرور خارج)${C_RESET}\n"
  echo -e "  ${C_DIM}در این مدل، x-ui را خودتان روی این سرور نصب می‌کنید."
  echo -e "  این بخش فقط ساب‌دامین Cloudflare را تنظیم و راهنمای اینباند XHTTP را نشان می‌دهد.${C_RESET}\n"
  install_deps
  load_state

  ask_required "دامین کامل برای این سرور (مثلا s1.example.com)" CDN_DOMAIN "${CDN_DOMAIN:-}"

  local pub_ip
  pub_ip="$(curl -fsSL https://api.ipify.org 2>/dev/null || echo "")"
  ask_required "IP عمومی این سرور" pub_ip "${pub_ip:-}"

  save_state CDN_DOMAIN "$CDN_DOMAIN"
  save_state EXIT_IP "$pub_ip"
  save_state ROLE "exit"

  echo
  if ask_yesno "می‌خواهید ساب‌دامین به‌صورت خودکار در Cloudflare ساخته شود؟" "N"; then
    cf_setup_record "$CDN_DOMAIN" "$pub_ip"
  else
    warn "تنظیم دستی: یک رکورد A با نام ${CDN_DOMAIN} به ${pub_ip} بسازید و حالت Proxy (ابر نارنجی) را روشن کنید."
  fi

  show_xui_guide "$CDN_DOMAIN"
  echo
  read -rp "  Enter برای بازگشت ..." _
  main_menu
}

show_xui_guide(){
  local domain="$1"
  local path="/$(openssl rand -hex 6)"
  save_state XHTTP_PATH "$path"
  echo
  echo -e "  ${C_B}${C_GRN}راهنمای ساخت اینباند در x-ui:${C_RESET}"
  echo -e "  ${C_DIM}─────────────────────────────────────────────${C_RESET}"
  echo -e "   • Protocol      : ${C_B}vless${C_RESET}"
  echo -e "   • Port          : ${C_B}443${C_RESET}  ${C_DIM}(یا هر پورتی که می‌خواهید کاربر استفاده کند)${C_RESET}"
  echo -e "   • Transport     : ${C_B}xhttp${C_RESET}"
  echo -e "   • Host / SNI    : ${C_B}${domain}${C_RESET}"
  echo -e "   • Path          : ${C_B}${path}${C_RESET}"
  echo -e "   • TLS           : ${C_B}روشن${C_RESET} ${C_DIM}(Cloudflare گواهی را تأمین می‌کند)${C_RESET}"
  echo -e "   • domainStrategy: ${C_B}forceipv4${C_RESET} ${C_DIM}(IPv6 ایران مرده است)${C_RESET}"
  echo -e "  ${C_DIM}─────────────────────────────────────────────${C_RESET}"
  echo -e "  ${C_YLW}در کانفیگی که برای کاربر می‌سازید، فقط آدرس (address) را به IP سرور اروان تغییر دهید؛"
  echo -e "  باقی موارد (SNI، path، uuid) همان مقادیر x-ui می‌ماند.${C_RESET}"
}
