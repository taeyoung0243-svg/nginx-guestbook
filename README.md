# 리눅스 방명록 — Nginx로 웹서비스 배포하고 운영하기

AI컴퓨터 및 Linux 운영체제 2차 과제. Ubuntu 서버에 Nginx를 설치하고, 정적 웹페이지와 FastAPI 백엔드를 **리버스 프록시**로 묶어 배포한 뒤 systemd·ufw·로그로 운영하는 과정을 정리했다.

## 구조

```
브라우저 ──HTTP:80──▶ Nginx ─┬─ /        → /var/www/guestbook (정적 HTML/CSS/JS)
                             └─ /api/    → 127.0.0.1:8000 FastAPI ──▶ SQLite
                                           (systemd: guestbook-api.service)
```

- 외부에는 80번 포트(Nginx)만 열려 있고, FastAPI는 `127.0.0.1`에서만 받는다.
- FastAPI는 로그인할 수 없는 전용 시스템 계정 `guestbook`으로 실행된다.

## 폴더

| 경로 | 내용 | 서버에 설치되는 위치 |
|---|---|---|
| `web/` | 방명록 화면 (HTML/CSS/JS) | `/var/www/guestbook` |
| `api/` | FastAPI 서버 (`main.py`) | `/opt/guestbook/api` |
| `deploy/nginx/guestbook.conf` | Nginx 사이트 설정 | `/etc/nginx/sites-available/guestbook` |
| `deploy/systemd/guestbook-api.service` | 백엔드 자동 실행 설정 | `/etc/systemd/system/` |
| `setup.sh` | 설치 스크립트 | — |

## 설치 (Ubuntu 24.04 / 26.04, WSL2·VM 모두 가능)

```bash
git clone <이 레포 주소>
cd nginx-guestbook
chmod +x setup.sh
sudo ./setup.sh
```

끝나면 `hostname -I`로 나온 IP를 브라우저에 입력한다: `http://<서버IP>/`

> WSL2에서 `systemctl`이 안 되면 `/etc/wsl.conf`에 `[boot]` / `systemd=true`를 넣고 PowerShell에서 `wsl --shutdown` 후 다시 연다.

## 운영 명령어

```bash
# 서비스 상태
systemctl status nginx guestbook-api
sudo systemctl restart guestbook-api

# 설정 검사 후 무중단 반영
sudo nginx -t && sudo systemctl reload nginx

# 로그
sudo tail -f /var/log/nginx/guestbook.access.log
sudo journalctl -u guestbook-api -f

# 방화벽 / 포트
sudo ufw status verbose
sudo ss -tlnp            # 80은 nginx, 8000은 127.0.0.1에서만 열린 것 확인

# API 직접 호출
curl http://localhost/api/health
curl http://localhost/api/messages
curl -X POST http://localhost/api/messages -H 'Content-Type: application/json' -d '{"name":"태영","content":"안녕"}'

# DB 확인
sudo apt install -y sqlite3
sudo sqlite3 /var/lib/guestbook/guestbook.db 'SELECT * FROM messages;'
```

## API

| 메서드 | 경로 | 설명 |
|---|---|---|
| GET | `/api/health` | 서버 상태 |
| GET | `/api/messages` | 글 목록 (최신순, 최대 100개) |
| POST | `/api/messages` | 글 작성 `{"name": "...", "content": "..."}` |
| GET | `/api/whoami` | Nginx가 넘겨준 헤더 확인 (프록시 동작 확인) |
| GET | `/api/docs` | 자동 생성 API 문서 (Swagger UI) |
