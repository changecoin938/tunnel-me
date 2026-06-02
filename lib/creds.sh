#!/usr/bin/env bash

gen_uuid(){
  if [[ -x "$XRAY_BIN" ]]; then "$XRAY_BIN" uuid; else cat /proc/sys/kernel/random/uuid; fi
}

gen_reality_keys(){
  "$XRAY_BIN" x25519
}

gen_shortid(){
  openssl rand -hex 8
}

save_state(){
  local key="$1" val="$2"
  touch "$STATE_DIR/env"
  if grep -q "^${key}=" "$STATE_DIR/env" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$STATE_DIR/env"
  else
    echo "${key}=${val}" >> "$STATE_DIR/env"
  fi
  chmod 600 "$STATE_DIR/env"
}

load_state(){
  [[ -f "$STATE_DIR/env" ]] && set -a && source "$STATE_DIR/env" && set +a || true
}

# connection string: base64 of "host;tunnel_port;uuid;pubkey;shortid;sni;xui_ports"
encode_conn(){
  local host="$1" tport="$2" uuid="$3" pub="$4" sid="$5" sni="$6" ports="$7"
  printf '%s;%s;%s;%s;%s;%s;%s' "$host" "$tport" "$uuid" "$pub" "$sid" "$sni" "$ports" \
    | base64 -w0
}

decode_conn(){
  local blob="$1"
  echo "$blob" | base64 -d
}
