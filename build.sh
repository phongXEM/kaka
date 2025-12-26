#!/bin/bash
export HOME=/root
export PATH=/www/server/nodejs/v24.12.0/bin:$PATH

APP_DIR="/www/wwwroot/a.1sio.com"
git config --global --add safe.directory "$APP_DIR" || true
cd "$APP_DIR" || exit 1

echo ">> Pull"
git pull origin main || exit 1

echo ">> Install deps"
npm install
rm -rf .next
echo ">> Build"
node node_modules/next/dist/bin/next build || exit 1

echo ">> PM2"
if pm2 describe test >/dev/null 2>&1; then
  pm2 restart test --update-env
else
  pm2 start node_modules/next/dist/bin/next \
    --name test \
    -- start -p 3000
fi

echo "🚀 Done"