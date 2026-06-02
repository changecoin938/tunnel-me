#!/usr/bin/env bash
# نصب tunnel-me از ریپوی خصوصی با توکن گیت‌هاب.
#
# استفاده (به‌صورت root):
#   GH_TOKEN=github_pat_xxx bash bootstrap.sh
#
# یا یک‌خطی روی سرور تازه:
#   sudo -i
#   GH_TOKEN=github_pat_xxx bash -c "$(curl -fsSL -H "Authorization: Bearer $GH_TOKEN" \
#     -H 'Accept: application/vnd.github.raw' \
#     https://api.github.com/repos/changecoin938/tunnel-me/contents/bootstrap.sh?ref=main)"
set -euo pipefail

REPO="changecoin938/tunnel-me"
REF="main"

: "${GH_TOKEN:?متغیر GH_TOKEN را با توکن گیت‌هاب خود تنظیم کنید}"
[[ $EUID -eq 0 ]] || { echo "این اسکریپت باید با root اجرا شود (sudo -i)"; exit 1; }

# پیش‌نیازهای حداقلی برای بوت‌استرپ
for bin in curl tar; do
  command -v "$bin" >/dev/null 2>&1 || {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y "$bin" >/dev/null 2>&1 || { echo "نصب $bin ناموفق بود"; exit 1; }
  }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> دریافت سورس از ریپوی خصوصی ${REPO} ..."
curl -fsSL \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/tarball/${REF}" \
  -o "$TMP/src.tar.gz" || { echo "دانلود سورس ناموفق بود (توکن/دسترسی را بررسی کنید)"; exit 1; }

mkdir -p "$TMP/src"
tar -xzf "$TMP/src.tar.gz" -C "$TMP/src" --strip-components=1

echo "==> اجرای installer ..."
# توکن را به installer هم می‌دهیم تا fallback آن هم روی ریپوی خصوصی کار کند.
GH_TOKEN="$GH_TOKEN" bash "$TMP/src/install.sh"
