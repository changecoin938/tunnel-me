#!/usr/bin/env bash

manage_menu(){
  banner
  echo -e "  ${C_B}مدیریت${C_RESET}\n"
  echo -e "   ${C_GRN}1)${C_RESET} ری‌استارت سرویس"
  echo -e "   ${C_GRN}2)${C_RESET} مشاهده لاگ زنده"
  echo -e "   ${C_GRN}3)${C_RESET} ویرایش/بازسازی کانفیگ"
  echo -e "   ${C_GRN}4)${C_RESET} حذف کامل (uninstall)"
  echo -e "   ${C_GRN}0)${C_RESET} بازگشت\n"
  read -rp "  انتخاب [0-4]: " m
  case "${m:-}" in
    1) systemctl restart ${XRAY_SVC} && ok "ری‌استارت شد"; sleep 1; manage_menu ;;
    2) echo -e "${C_DIM}(Ctrl+C برای خروج)${C_RESET}"; journalctl -u ${XRAY_SVC} -f ;;
    3) reconfigure ;;
    4) uninstall_all ;;
    0) main_menu ;;
    *) warn "نامعتبر"; sleep 1; manage_menu ;;
  esac
}

reconfigure(){
  load_state
  if [[ "${ROLE:-}" == "relay" ]]; then
    provision_relay
  elif [[ "${ROLE:-}" == "exit" ]]; then
    provision_exit
  else
    warn "نقشی ثبت نشده. ابتدا نصب کنید."
    sleep 1; main_menu
  fi
}

uninstall_all(){
  read -rp "  مطمئنید؟ سرویس و کانفیگ حذف می‌شود [y/N]: " c
  if [[ "${c,,}" == "y" ]]; then
    systemctl stop ${XRAY_SVC} 2>/dev/null || true
    systemctl disable ${XRAY_SVC} 2>/dev/null || true
    rm -f /etc/systemd/system/${XRAY_SVC}.service
    systemctl daemon-reload
    rm -f "$XRAY_CONF"
    rm -rf "$STATE_DIR"
    ok "حذف شد (باینری Xray دست‌نخورده ماند)"
  fi
  sleep 1; main_menu
}
