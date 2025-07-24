#!/bin/bash

echo "🔧 Starting ZKTeco to Zoho People Integration Setup..."

# Exit on error
set -e

# Step 1: Update & install system packages
echo "📦 Installing system packages..."
sudo apt update && sudo apt install -y git python3-venv mariadb-client mariadb-server cron

# Step 2: Clone the GitHub repo
echo "📥 Cloning the project..."
git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
cd ZKTeco-to-zoho-people-devices-Integration

# Step 3: Setup virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv zk-env
source zk-env/bin/activate

# Step 4: Install Python dependencies
echo "📦 Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt

# Step 5: Prompt for .env values
echo "📝 Creating .env file..."
cat <<EOF > .env
DB_HOST=localhost
DB_USER=root
EOF

read -p "Enter MySQL password: " DB_PASS
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET
read -p "Enter Device IP (e.g. 192.168.1.201): " DEVICE_IP
read -p "Enter Device Port (default 4370): " DEVICE_PORT
read -p "Enter Device Password: " DEVICE_PASSWORD
read -p "Enter Google Drive Folder ID: " GDRIVE_FOLDER_ID

echo "DB_PASS=$DB_PASS" >> .env
echo "DB_NAME=zk_attendance" >> .env
echo "ZOHO_DOMAIN=zoho.com" >> .env
echo "ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID" >> .env
echo "ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET" >> .env
echo "ZOHO_REFRESH_TOKEN=" >> .env
echo "DEVICE_IP=$DEVICE_IP" >> .env
echo "DEVICE_PORT=${DEVICE_PORT:-4370}" >> .env
echo "DEVICE_PASSWORD=$DEVICE_PASSWORD" >> .env
echo "GDRIVE_FOLDER_ID=$GDRIVE_FOLDER_ID" >> .env

# Step 6: Run Zoho Token Setup
echo "🔑 Run Zoho OAuth to get refresh token..."
python3 get_access_token.py
echo "✅ Paste the refresh token into .env file manually if not auto-inserted."

# Step 7: Setup MySQL DB
echo "🛢️ Creating MySQL database..."
mysql -u root -p$DB_PASS -e "CREATE DATABASE IF NOT EXISTS zk_attendance;"
mysql -u root -p$DB_PASS zk_attendance < schema.sql

# Step 8: Setup systemd timer for run_all.py
echo "⏱️ Setting up systemd service and timer..."

cat <<EOF | sudo tee /etc/systemd/system/zk_sync.service
[Unit]
Description=ZKTeco to Zoho Sync Service
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/zk-env/bin/python3 run_all.py
Restart=always
Environment="PATH=$(pwd)/zk-env/bin"

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /etc/systemd/system/zk_sync.timer
[Unit]
Description=Run ZK Sync every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=zk_sync.service

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable zk_sync.timer
sudo systemctl start zk_sync.timer

# Step 9: Add midnight cron job for backup
echo "🕛 Scheduling backup at midnight..."
croncmd="$(pwd)/zk-env/bin/python3 $(pwd)/incremental_backup.py >> $(pwd)/backups/backup.log 2>&1"
( crontab -l 2>/dev/null; echo "0 0 * * * $croncmd" ) | crontab -

# Step 10: Final Instructions
echo "✅ Setup complete!"
echo "➡️ Your system is now configured to run attendance sync every 5 minutes."
echo "➡️ Backups are scheduled for midnight every day."
echo "➡️ Check the .env file to ensure the Zoho refresh token is correctly set."
echo "➡️ Link your Google Drive account if prompted on first backup run."
