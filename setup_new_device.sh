#!/bin/bash

set -e

echo "🔧 Updating and installing dependencies..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip mariadb-server mariadb-client git cron systemd

echo "📁 Cloning project repository..."
cd ~
rm -rf ZKTeco-to-zoho-people-devices-Integration
git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
cd ZKTeco-to-zoho-people-devices-Integration

echo "🐍 Setting up Python virtual environment..."
python3 -m venv zk-env
source zk-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install pydrive python-dotenv

echo "📝 Creating .env file interactively..."
read -p "Enter MySQL password: " MYSQL_PASS
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET
read -p "Enter Zoho Refresh Token: " ZOHO_REFRESH_TOKEN
read -p "Enter ZKTeco Device IP (e.g., 192.168.68.52): " DEVICE_IP
read -p "Enter ZKTeco Device Port (default: 4370): " DEVICE_PORT
read -p "Enter ZKTeco Device Password: " DEVICE_PASS
read -p "Enter Google Drive Folder ID (or leave blank): " GDRIVE_ID

cat > .env <<EOF
# MySQL Database
DB_HOST=localhost
DB_USER=root
DB_PASS=$MYSQL_PASS
DB_NAME=zk_attendance

# Zoho People API
ZOHO_DOMAIN=zoho.com
ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID
ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET
ZOHO_REFRESH_TOKEN=$ZOHO_REFRESH_TOKEN

# ZKTeco Device
DEVICE_IP=$DEVICE_IP
DEVICE_PORT=${DEVICE_PORT:-4370}
DEVICE_PASSWORD=$DEVICE_PASS

# Google Drive
GDRIVE_FOLDER_ID=$GDRIVE_ID
EOF

echo -e "\n✅ .env file created."

echo "🗃️ Creating database and tables..."
mysql -uroot -p"$MYSQL_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS zk_attendance;
USE zk_attendance;

CREATE TABLE IF NOT EXISTS attendance_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    name VARCHAR(255),
    punch_time DATETIME,
    punch_type VARCHAR(10),
    source VARCHAR(50),
    synced BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS user_mapping (
    id INT AUTO_INCREMENT PRIMARY KEY,
    device_user_id VARCHAR(255),
    zoho_employee_id VARCHAR(255)
);
EOF

echo "✅ Database ready."

echo "🛠️ Creating systemd service and timer..."
SERVICE_FILE=/etc/systemd/system/zk_sync.service
TIMER_FILE=/etc/systemd/system/zk_sync.timer

sudo tee "$SERVICE_FILE" > /dev/null <<EOL
[Unit]
Description=ZKTeco to Zoho People Sync Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/zk_int/ZKTeco-to-zoho-people-devices-Integration
ExecStart=/home/zk_int/ZKTeco-to-zoho-people-devices-Integration/zk-env/bin/python run_all.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

sudo tee "$TIMER_FILE" > /dev/null <<EOL
[Unit]
Description=Run ZK Sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=zk_sync.service

[Install]
WantedBy=timers.target
EOL

echo "🔄 Enabling systemd service and timer..."
sudo systemctl daemon-reload
sudo systemctl enable zk_sync.service zk_sync.timer
sudo systemctl start zk_sync.timer

echo "🗃️ Configuring Google Drive backup..."

echo "📁 Copying Google client_secrets.json to project directory..."
read -p "Paste the full path to your Google client_secrets.json file: " GOOGLE_SECRET
cp "$GOOGLE_SECRET" ./client_secrets.json

echo "🔐 First-time Google Drive setup..."
echo "➡️ When prompted, follow the link, sign in with your Google account, and paste the verification code."

python first_drive_auth.py || true

echo "🕛 Setting up cron job for daily midnight backup..."
CRON_CMD="/home/zk_int/ZKTeco-to-zoho-people-devices-Integration/zk-env/bin/python /home/zk_int/ZKTeco-to-zoho-people-devices-Integration/incremental_backup.py >> /var/log/zk_backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v 'incremental_backup.py'; echo "0 0 * * * $CRON_CMD") | crontab -

echo -e "\n✅ Midnight backup scheduled."

echo "🎉 Setup is complete!"

echo -e "\n📍 Steps you must complete manually (only once):"
echo "1. Go to https://console.cloud.google.com/apis/credentials"
echo "   - Create a Desktop OAuth 2.0 client"
echo "   - Download and rename the credentials file to: client_secrets.json"
echo "   - Put it somewhere safe and enter its path when prompted"
echo
echo "2. Enable the Google Drive API:"
echo "   https://console.developers.google.com/apis/library/drive.googleapis.com"
echo
echo "3. Add your email as a test user under OAuth consent screen"
echo "   (This fixes 'access_denied' errors)"
echo
echo "📝 Logs:"
echo " - Sync:   journalctl -u zk_sync.service -f"
echo " - Backup: tail -f /var/log/zk_backup.log"
