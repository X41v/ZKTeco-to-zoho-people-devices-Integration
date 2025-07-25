#!/bin/bash

echo "🔧 Starting ZKTeco-to-Zoho setup..."

# ---- 1. Update system & install dependencies ----
echo "📦 Updating packages and installing dependencies..."
sudo apt update && sudo apt install -y \
    python3 python3-pip python3-venv mariadb-server mariadb-client git curl unzip

# ---- 2. Clone the GitHub repo ----
echo "📁 Cloning project..."
git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
cd ZKTeco-to-zoho-people-devices-Integration

# ---- 3. Set up virtual environment ----
echo "🐍 Setting up Python virtual environment..."
python3 -m venv zk-env
source zk-env/bin/activate

# ---- 4. Install Python packages ----
echo "📦 Installing Python packages..."
pip install --upgrade pip
pip install -r requirements.txt

# ---- 5. Prompt for .env values and generate the .env file ----
echo "📝 Creating .env configuration..."
read -p "Enter MySQL root password (you'll be asked again for DB setup): " DB_PASS
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET
read -p "Enter Device IP: " DEVICE_IP
read -p "Enter Device Port [Default: 4370]: " DEVICE_PORT
DEVICE_PORT=${DEVICE_PORT:-4370}
read -p "Enter Device Password: " DEVICE_PASSWORD
read -p "Enter Google Drive Folder ID: " GDRIVE_FOLDER_ID

# ---- 6. Get Zoho Refresh Token ----
echo "🔐 Generating Zoho refresh token..."
python3 get_access_token.py "$ZOHO_CLIENT_ID" "$ZOHO_CLIENT_SECRET"
read -p "Paste the generated refresh token here: " ZOHO_REFRESH_TOKEN

# Save .env file
cat > .env <<EOF
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

# ---- 7. Secure MySQL and create the database ----
echo "🛢️ Creating MySQL database..."
sudo mysql -u root <<MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASS';
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS zk_attendance;
MYSQL_SCRIPT

# ---- 8. Load schema ----
mysql -u root -p"$DB_PASS" zk_attendance < schema.sql
echo "✅ Database and schema ready."

# ---- 9. Systemd service for syncing ----
echo "🖥️ Setting up systemd service..."
SERVICE_PATH="/etc/systemd/system/zk_sync.service"
sudo bash -c "cat > $SERVICE_PATH" <<EOF
[Unit]
Description=Run run_all.py every 5 minutes
After=network.target mariadb.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/zk-env/bin/python3 $(pwd)/run_all.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable zk_sync.service
sudo systemctl start zk_sync.service

# ---- 10. Cron job for nightly backup ----
echo "🕛 Scheduling midnight backup..."
(crontab -l 2>/dev/null; echo "0 0 * * * cd $(pwd) && $(pwd)/zk-env/bin/python3 incremental_backup.py") | crontab -

# ---- 11. Final message ----
echo ""
echo "✅ Setup complete!"
echo ""
echo "📌 Please make sure to:"
echo "   - Complete Google Drive authentication (follow prompts from get_access_token.py)"
echo "   - Ensure your device is reachable at $DEVICE_IP:$DEVICE_PORT"
echo ""
echo "🌀 Rebooting the system will auto-restart everything."
