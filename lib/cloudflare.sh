#!/usr/bin/env bash

cf_setup_record(){
  local fqdn="$1" ip="$2"
  read -rp "  Cloudflare API Token: " CF_TOKEN
  [[ -n "$CF_TOKEN" ]] || { warn "توکن وارد نشد، از تنظیم خودکار صرف‌نظر شد"; return 1; }

  local root zone_id
  root="$(echo "$fqdn" | awk -F. '{print $(NF-1)"."$NF}')"

  zone_id="$(curl -fsSL -X GET \
    "https://api.cloudflare.com/client/v4/zones?name=${root}" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id // empty')"

  [[ -n "$zone_id" ]] || { err "Zone برای ${root} پیدا نشد. دامین را در Cloudflare اضافه کنید."; return 1; }

  local existing
  existing="$(curl -fsSL -X GET \
    "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${fqdn}&type=A" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id // empty')"

  local payload
  payload="$(jq -n --arg name "$fqdn" --arg content "$ip" \
    '{type:"A", name:$name, content:$content, ttl:1, proxied:true}')"

  if [[ -n "$existing" ]]; then
    curl -fsSL -X PUT \
      "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${existing}" \
      -H "Authorization: Bearer ${CF_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$payload" >/dev/null && ok "رکورد به‌روزرسانی شد (proxied)" \
      || { err "به‌روزرسانی رکورد ناموفق"; return 1; }
  else
    curl -fsSL -X POST \
      "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
      -H "Authorization: Bearer ${CF_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$payload" >/dev/null && ok "رکورد ساخته شد (proxied)" \
      || { err "ساخت رکورد ناموفق"; return 1; }
  fi
  ok "${fqdn} → ${ip} با حالت Proxy فعال شد"
}
