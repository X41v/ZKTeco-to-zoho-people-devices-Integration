#!/bin/bash

set -e

echo "🔧 Installing system dependencies..."
sudo apt update
sudo apt install -y python3-venv mariadb-client cron

echo "🐍 Setting up Python virtual environment..."
python3 -m venv zk-env
source zk-env/bin/activate

echo "📦 Installing required Python packages..."
pip install --upgrade pip
pip install -r requirements.txt
pip install pydrive python-dotenv

echo "🔑 Creating .env file..."
read -p "Enter MySQL password: " DB_PASS
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET

echo "🌐 Opening Zoho authorization page..."
python3 get_access_token.py
read -p "Paste the Zoho Refresh Token you received: " ZOHO_REFRESH_TOKEN

read -p "Enter ZKTeco Device IP: " DEVICE_IP
read -p "Enter ZKTeco Device Port [default 4370]: " DEVICE_PORT
DEVICE_PORT=${DEVICE_PORT:-4370}
read -p "Enter ZKTeco Device Password: " DEVICE_PASSWORD
read -p "Enter Google Drive Folder ID: " GDRIVE_FOLDER_ID

cat > e.env <<EOF
# MySQL Database
DB_HOST=localhost
DB_USER=root
DB_PASS=$DB_PASS
DB_NAME=zk_attendance

# Zoho People API
ZOHO_DOMAIN=zoho.com
ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID
ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET
ZOHO_REFRESH_TOKEN=$ZOHO_REFRESH_TOKEN

# ZKTeco Device
DEVICE_IP=$DEVICE_IP
DEVICE_PORT=$DEVICE_PORT
DEVICE_PASSWORD=$DEVICE_PASSWORD

# Google Drive
GDRIVE_FOLDER_ID=$GDRIVE_FOLDER_ID
EOF

echo "✅ .env file created."

echo "⚙️ Setting up systemd service..."

cat | sudo tee /etc/systemd/system/zk_sync.service > /dev/null <<EOF
[Unit]
Description=ZKTeco-Zoho Integration Sync Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/zk-env/bin/python3 run_all.py
Environment="PYTHONUNBUFFERED=1"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable zk_sync.service
sudo systemctl start zk_sync.service

echo "⏰ Setting up cron job for incremental backup..."

( crontab -l 2>/dev/null; echo "0 0 * * * cd $(pwd) && $(pwd)/zk-env/bin/python3 incremental_backup.py >> $(pwd)/backup.log 2>&1" ) | crontab -

echo "✅ Cron job added for nightly backup."

echo "📎 Final Instructions:"
echo "1. Make sure Google Drive API is enabled on https://console.developers.google.com/apis/library/drive.googleapis.com"
echo "2. Add your Google account as a test user in the OAuth consent screen"
echo "3. Make sure your client_secrets.json is in place"
echo "4. You can test backup manually using:"
echo "   source zk-env/bin/activate && python3 incremental_backup.py"

echo "🎉 Setup complete! The system will auto-start after reboot."
