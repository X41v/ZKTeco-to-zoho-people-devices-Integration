#!/bin/bash

echo "🔧 Setting up ZKTeco to Zoho Integration Environment..."

# Setup variables
PROJECT_DIR="$HOME/ZKTeco-to-zoho-people-devices-Integration"
ENV_FILE="$PROJECT_DIR/.env"
SERVICE_FILE="/etc/systemd/system/zk_sync.service"

# Ask for inputs
read -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET
read -p "Enter Zoho Refresh Token (or leave blank to insert later): " ZOHO_REFRESH_TOKEN

# Install system dependencies
sudo apt update
sudo apt install -y python3 python3-venv python3-pip mariadb-server unzip curl git

# Create virtual environment
cd "$PROJECT_DIR"
python3 -m venv zk-env
source zk-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Create .env file
echo "Creating .env file..."
cat <<EOF > "$ENV_FILE"
MYSQL_HOST=localhost
MYSQL_USER=root
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=attendance
DEVICE_IP=192.168.68.52
DEVICE_PORT=4370
DEVICE_PASSWORD=123456
ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID
ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET
ZOHO_REFRESH_TOKEN=$ZOHO_REFRESH_TOKEN
EOF

# Create database and schema
echo "🛢️ Creating MySQL database..."
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS attendance;"
sudo mysql -u root attendance < schema.sql

# Setup Google Drive auth
echo "🔑 Authenticating Google Drive..."
source zk-env/bin/activate
python3 get_access_token.py

# Create systemd service
echo "🖥️ Setting up systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=ZKTeco-Zoho Sync Service
After=network.target mariadb.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/zk-env/bin/python3 $PROJECT_DIR/run_all.py
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable zk_sync.service

# Schedule backup at midnight
echo "🕛 Scheduling midnight backup..."
(crontab -l 2>/dev/null; echo "0 0 * * * cd $PROJECT_DIR && source zk-env/bin/activate && python3 incremental_backup.py") | crontab -

echo ""
echo "✅ Setup complete!"
echo ""
echo "📌 On reboot, the sync system will start automatically."
echo "🌀 Reboot now with: sudo reboot"
