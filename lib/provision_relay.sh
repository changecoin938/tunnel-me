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
  ask_required "دامین CDN (مثلا s1.example.com)" CDN_DOMAIN "${CDN_DOMAIN:-}"

  ask_required "پورت‌های x-ui که باید فوروارد شوند (با کاما، مثلا 443,8443,2056)" XUI_PORTS "${XUI_PORTS:-}"

  echo -e "  ${C_DIM}پورت اتصال به CDN = پورتی که رله روی آن به Cloudflare وصل می‌شود (HTTPS معمولاً 443).${C_RESET}"
  ask_required "پورت اتصال به CDN" CDN_PORT "${CDN_PORT:-443}"

  save_state CDN_DOMAIN "$CDN_DOMAIN"
  save_state XUI_PORTS "$XUI_PORTS"
  save_state CDN_PORT "$CDN_PORT"
  save_state ROLE "relay"

  build_relay_config "$CDN_DOMAIN" "$XUI_PORTS" "$CDN_PORT"
  # قبل از استارت: سرویس خودمان را متوقف و پورت‌های اشغال‌شده توسط بقیه را آزاد می‌کنیم.
  systemctl stop "$XRAY_SVC" 2>/dev/null || true
  free_busy_ports "$XUI_PORTS"
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

# پورت‌های اشغال‌شده توسط پروسه‌های دیگر را پیدا و با تأیید کاربر آزاد می‌کند.
free_busy_ports(){
  local ports="$1"
  command -v ss >/dev/null 2>&1 || apt-get install -y iproute2 >/dev/null 2>&1 || true
  IFS=',' read -ra PARR <<< "$ports"
  for p in "${PARR[@]}"; do
    p="$(echo "$p" | tr -d '[:space:]')"
    [[ "$p" =~ ^[0-9]+$ ]] || continue

    local lines
    lines="$(ss -ltnp 2>/dev/null | awk -v port="$p" 'NR>1 && $4 ~ (":" port "$")')"
    [[ -n "$lines" ]] || continue

    warn "پورت ${p} از قبل اشغال است:"
    echo "$lines" | sed 's/^/      /'

    local pids pid pname
    pids="$(echo "$lines" | grep -oP 'pid=\K[0-9]+' | sort -u)"
    if [[ -z "$pids" ]]; then
      warn "پروسه‌ی پورت ${p} تشخیص داده نشد؛ دستی بررسی کنید."
      continue
    fi
    for pid in $pids; do
      pname="$(ps -p "$pid" -o comm= 2>/dev/null || echo '?')"
      echo -e "      → PID ${pid} (${pname:-?})"
    done

    if ask_yesno "پورت ${p} آزاد شود؟ (پروسه‌های بالا متوقف می‌شوند)" "N"; then
      for pid in $pids; do kill "$pid" 2>/dev/null || true; done
      sleep 1
      for pid in $pids; do kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true; done
      ok "پورت ${p} آزاد شد"
    else
      warn "پورت ${p} آزاد نشد؛ ممکن است سرویس بالا نیاید."
    fi
  done
}
