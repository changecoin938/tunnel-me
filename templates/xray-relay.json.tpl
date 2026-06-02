{
  "log": { "loglevel": "warning" },
  "inbounds": __INBOUNDS__,
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "to-cdn",
      "settings": { "domainStrategy": "UseIP" }
    }
  ],
  "dns": {
    "servers": [ "1.1.1.1", "8.8.8.8" ]
  }
}
