#!/usr/bin/env bash

provision_relay(){
  banner
  echo -e "  ${C_B}نصب نقش RELAY (سرور ایران)${C_RESET}\n"
  install_deps
  install_xray
  enable_ip_forward
  load_state

  echo
  echo -e "  ${C_DIM}دامین CDN همان دامینی است که در Cloudflare برای x-ui (روی سرور خارج) proxy کرده‌اید.${C_RESET}"
  read -rp "  دامین CDN (مثلا s1.example.com): " CDN_DOMAIN
  [[ -n "$CDN_DOMAIN" ]] || die "دامین CDN الزامی است"

  read -rp "  پورت‌های x-ui که باید فوروارد شوند (با کاما، مثلا 443,8443,2056): " XUI_PORTS
  [[ -n "$XUI_PORTS" ]] || die "حداقل یک پورت لازم است"

  read -rp "  پورت اتصال به CDN [443]: " CDN_PORT
  CDN_PORT="${CDN_PORT:-443}"

  save_state CDN_DOMAIN "$CDN_DOMAIN"
  save_state XUI_PORTS "$XUI_PORTS"
  save_state CDN_PORT "$CDN_PORT"
  save_state ROLE "relay"

  build_relay_config "$CDN_DOMAIN" "$XUI_PORTS" "$CDN_PORT"
  install_service
  start_service

  echo
  ok "RELAY آماده شد"
  echo -e "  ${C_DIM}کاربران به این آدرس وصل می‌شوند:${C_RESET} ${C_B}<IP این سرور اروان>${C_RESET} روی پورت‌های ${C_B}${XUI_PORTS}${C_RESET}"
  echo -e "  ${C_DIM}در کانفیگ x-ui، آدرس (address) را IP همین سرور اروان و SNI/host را ${CDN_DOMAIN} بگذارید.${C_RESET}"
  echo
  read -rp "  Enter برای بازگشت ..." _
  main_menu
}

build_relay_config(){
  local domain="$1" ports="$2" cdn_port="$3"
  local inbounds="[]"
  IFS=',' read -ra PARR <<< "$ports"
  for p in "${PARR[@]}"; do
    p="$(echo "$p" | tr -d '[:space:]')"
    [[ "$p" =~ ^[0-9]+$ ]] || continue
    local ib
    ib=$(jq -n --argjson port "$p" --arg addr "$domain" --argjson dport "$cdn_port" '{
      listen: "0.0.0.0",
      port: $port,
      protocol: "dokodemo-door",
      settings: { address: $addr, port: $dport, network: "tcp" },
      tag: ("in-" + ($port|tostring))
    }')
    inbounds=$(jq --argjson ib "$ib" '. + [$ib]' <<< "$inbounds")
  done

  [[ "$inbounds" != "[]" ]] || die "هیچ پورت معتبری ساخته نشد"

  mkdir -p "$(dirname "$XRAY_CONF")"
  sed "s|__INBOUNDS__|$(echo "$inbounds" | jq -c .)|" \
    "$WORKDIR/templates/xray-relay.json.tpl" > "$XRAY_CONF"

  "$XRAY_BIN" -test -config "$XRAY_CONF" >/dev/null 2>&1 \
    || die "کانفیگ تولیدشده نامعتبر است"
  ok "کانفیگ RELAY ساخته و اعتبارسنجی شد"
}
