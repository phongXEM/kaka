#!/bin/bash
set -e
exec 2>&1

# =========================
# ENV
# =========================
export HOME=/root
export PATH=/www/server/nodejs/v24.12.0/bin:$PATH

# =========================
# CONFIG
# =========================
APP_NAME="test"
PORT=3001
APP_DIR="/www/wwwroot/a.1sio.com"
GIT_BRANCH="main"
PM2="/www/server/nodejs/v24.12.0/bin/pm2"
# =========================

git config --global --add safe.directory "$APP_DIR" || true
cd "$APP_DIR" || exit 1

echo ">> Pull"
git fetch origin "$GIT_BRANCH" >/dev/null 2>&1 || true
git reset --hard "origin/$GIT_BRANCH" >/dev/null 2>&1
git clean -fd >/dev/null 2>&1

echo ">> Install deps"
# ưu tiên install theo lockfile để deploy ổn định
if [ -f package-lock.json ]; then
  npm ci --no-fund --no-audit
else
  npm install --no-fund --no-audit
fi

echo ">> Clear Next.js cache"
# an toàn và hiệu quả: xóa cache build + fetch cache của Next
rm -rf .next

echo ">> Build"
npm run build

echo ">> PM2 (hard restart)"
# hard restart để tránh giữ memory cache; vẫn suppress output để aaPanel không match "error"
if $PM2 describe "$APP_NAME" >/dev/null 2>&1; then
  $PM2 delete "$APP_NAME" >/dev/null 2>&1
fi
$PM2 start npm --name "$APP_NAME" -- start -- -p "$PORT" >/dev/null 2>&1
echo "PM2 OK"

echo ">> Healthcheck"
# cho app có thời gian warm-up; retry vài lần cho ổn định
for i in 1 2 3 4 5; do
  sleep 1
  if curl -fsS "http://127.0.0.1:$PORT/" >/dev/null; then
    echo "Healthcheck OK"
    echo "🚀 Done"
    exit 0
  fi
done

echo "Healthcheck FAILED"
exit 1