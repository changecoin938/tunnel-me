#!/usr/bin/env bash

install_deps(){
  msg "نصب پیش‌نیازها ..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y curl jq openssl iptables ca-certificates socat >/dev/null 2>&1 \
    || die "نصب پیش‌نیازها ناموفق بود"
  ok "پیش‌نیازها نصب شد"
}

install_xray(){
  if [[ -x "$XRAY_BIN" ]]; then
    ok "Xray از قبل نصب است ($($XRAY_BIN version 2>/dev/null | head -n1))"
    return
  fi
  msg "نصب هسته‌ی Xray ..."
  bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1 \
    || die "نصب Xray ناموفق بود"
  [[ -x "$XRAY_BIN" ]] || die "باینری Xray پیدا نشد"
  ok "Xray نصب شد ($($XRAY_BIN version 2>/dev/null | head -n1))"
}

enable_ip_forward(){
  if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
  sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
}

install_service(){
  cat > /etc/systemd/system/${XRAY_SVC}.service << UNIT
[Unit]
Description=Xray Service (spoof-tunnel)
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=${XRAY_BIN} run -config ${XRAY_CONF}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable ${XRAY_SVC} >/dev/null 2>&1 || true
  ok "سرویس systemd نصب شد (ری‌استارت خودکار بعد از قطع برق)"
}

start_service(){
  systemctl restart ${XRAY_SVC}
  sleep 1
  if systemctl is-active --quiet ${XRAY_SVC}; then
    ok "سرویس فعال است"
  else
    err "سرویس فعال نشد — برای جزئیات: journalctl -u ${XRAY_SVC} -n50"
  fi
}
