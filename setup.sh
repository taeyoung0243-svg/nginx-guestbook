#!/usr/bin/env bash
# 리눅스 방명록 설치 스크립트 (Ubuntu 24.04 / 26.04)
# 사용법: sudo ./setup.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "root 권한이 필요합니다: sudo ./setup.sh" >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR=/opt/guestbook
WEB_DIR=/var/www/guestbook

step() { echo; echo "==> $*"; }

step "1/7 패키지 설치 (nginx, python3-venv, ufw)"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx python3-venv ufw curl

step "2/7 서비스 전용 사용자 만들기 (로그인 불가 시스템 계정)"
id guestbook &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin guestbook

step "3/7 API 코드 복사 + 파이썬 가상환경 만들기"
mkdir -p "$APP_DIR"
cp -r "$SRC/api" "$APP_DIR/"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --quiet -r "$APP_DIR/api/requirements.txt"
chown -R root:root "$APP_DIR"
chmod -R go-w "$APP_DIR"

step "4/7 정적 웹 파일 복사"
mkdir -p "$WEB_DIR"
cp -r "$SRC/web/." "$WEB_DIR/"
chown -R www-data:www-data "$WEB_DIR"
find "$WEB_DIR" -type d -exec chmod 755 {} +   # 폴더: rwxr-xr-x
find "$WEB_DIR" -type f -exec chmod 644 {} +   # 파일: rw-r--r-- (실행 권한 불필요)

step "5/7 systemd 서비스 등록 (부팅 시 자동 실행)"
cp "$SRC/deploy/systemd/guestbook-api.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now guestbook-api
systemctl restart guestbook-api

step "6/7 Nginx 사이트 설정"
cp "$SRC/deploy/nginx/guestbook.conf" /etc/nginx/sites-available/guestbook
ln -sf /etc/nginx/sites-available/guestbook /etc/nginx/sites-enabled/guestbook
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

step "7/7 방화벽(ufw): SSH(22)와 HTTP(80)만 허용"
ufw allow OpenSSH
ufw allow 'Nginx HTTP'
ufw --force enable
ufw status verbose

step "동작 확인"
for i in {1..10}; do
  curl -fsS http://127.0.0.1/api/health && break
  sleep 1
done
echo
IP=$(hostname -I | awk '{print $1}')
echo "완료! 브라우저에서 http://$IP/ 로 접속하세요."
