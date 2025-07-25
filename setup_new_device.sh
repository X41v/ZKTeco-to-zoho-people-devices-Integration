#!/bin/bash

set -e

# Detect project path
echo "🔍 Detecting project directory..."
PROJECT_PATH=$(pwd)
echo "📁 Project Path: $PROJECT_PATH"

# Update and install system packages
echo "📦 Installing required packages..."
sudo apt update && sudo apt install -y python3 python3-pip python3-venv mariadb-server mariadb-client git cron

# Setup Python virtual environment
echo "🐍 Setting up Python virtual environment..."
python3 -m venv zk-env
source zk-env/bin/activate
pip install -r requirements.txt

# Secure MariaDB and set root password
echo "🔐 Configuring MariaDB..."
read -s -p "Enter password for MySQL root user: " DB_PASSWORD
echo

# Secure installation (assume fresh)
sudo systemctl start mariadb
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASSWORD'; FLUSH PRIVILEGES;"

# Create database and import schema
DB_NAME="zk_attendance"
echo "🛢️ Creating MySQL database $DB_NAME..."
sudo mysql -u root -p$DB_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
sudo mysql -u root -p$DB_PASSWORD $DB_NAME < schema.sql

# Collect .env information
read -p "Enter ZKTeco IP Address (e.g., 192.168.68.52): " DEVICE_IP
read -p "Enter ZKTeco device password: " DEVICE_PASSWORD
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET

# Create .env file
echo "✅ Creating .env file..."
cat > e.env <<EOF
DB_NAME=$DB_NAME
DB_USER=root
DB_PASSWORD=$DB_PASSWORD
DEVICE_IP=$DEVICE_IP
DEVICE_PORT=4370
DEVICE_PASSWORD=$DEVICE_PASSWORD
ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID
ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET
EOF

# Run Python to fetch access token and update .env
echo "🔑 Running access token fetch script..."
source zk-env/bin/activate
python3 get_access_token.py

# Ensure e.env includes the refresh token
echo "✅ Please confirm e.env contains ZOHO_REFRESH_TOKEN. If not, paste it manually."

# Setup systemd service for run_all.py
echo "🖥️ Setting up systemd service for run_all.py..."
SERVICE_NAME="zk_run_all"
TIMER_NAME="$SERVICE_NAME.timer"

cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=Run ZKTeco Integration Script
After=network.target mariadb.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_PATH
ExecStart=$PROJECT_PATH/zk-env/bin/python3 $PROJECT_PATH/run_all.py
EnvironmentFile=$PROJECT_PATH/e.env

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/$TIMER_NAME <<EOF
[Unit]
Description=Run zk_run_all.py every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
EOF

# Setup systemd service for incremental_backup.py
BACKUP_SERVICE="zk_backup"
BACKUP_TIMER="$BACKUP_SERVICE.timer"

cat > /etc/systemd/system/$BACKUP_SERVICE.service <<EOF
[Unit]
Description=Run Backup Script
After=network.target mariadb.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_PATH
ExecStart=$PROJECT_PATH/zk-env/bin/python3 $PROJECT_PATH/incremental_backup.py
EnvironmentFile=$PROJECT_PATH/e.env

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/$BACKUP_TIMER <<EOF
[Unit]
Description=Run Backup Script at Midnight

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true
Unit=$BACKUP_SERVICE.service

[Install]
WantedBy=timers.target
EOF

# Enable and start services and timers
echo "🔄 Enabling systemd services and timers..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME.service $TIMER_NAME $BACKUP_SERVICE.service $BACKUP_TIMER
sudo systemctl start $TIMER_NAME $BACKUP_TIMER

# Final message
echo -e "\n✅ Setup complete!"
echo "📌 After reboot, everything will start automatically."
echo "🔁 You can test now by running: python3 run_all.py"
echo "🌀 Reboot the device to confirm full automation."
