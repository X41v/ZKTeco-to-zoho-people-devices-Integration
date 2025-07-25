#!/bin/bash

echo "🔧 Starting ZKTeco to Zoho People Setup..."

# Update and install system packages
echo "📦 Installing required system packages..."
sudo apt update && sudo apt install -y python3-venv mariadb-client git

# Clone the repository
echo "🔁 Cloning project repo..."
git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
cd ZKTeco-to-zoho-people-devices-Integration || exit

# Create Python virtual environment
echo "🐍 Creating virtual environment..."
python3 -m venv zk-env
source zk-env/bin/activate

# Install Python packages
echo "📦 Installing Python requirements..."
pip install --upgrade pip
pip install -r requirements.txt

# Create .env file interactively
echo "📝 Creating .env file..."
read -p "Enter MySQL password: " DB_PASS
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET
read -p "Enter ZKTeco Device IP: " DEVICE_IP
read -p "Enter ZKTeco Port (default 4370): " DEVICE_PORT
DEVICE_PORT=${DEVICE_PORT:-4370}
read -p "Enter ZKTeco Device Password: " DEVICE_PASSWORD
read -p "Enter Google Drive Folder ID: " GDRIVE_FOLDER_ID

# Run token generator
echo "🌐 Launching Zoho token generator..."
python3 get_access_token.py
read -p "Paste your Zoho refresh token here: " ZOHO_REFRESH_TOKEN

cat <<EOF > .env
DB_HOST=localhost
DB_USER=root
DB_PASS=$DB_PASS
DB_NAME=zk_attendance

ZOHO_DOMAIN=zoho.com
ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID
ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET
ZOHO_REFRESH_TOKEN=$ZOHO_REFRESH_TOKEN

DEVICE_IP=$DEVICE_IP
DEVICE_PORT=$DEVICE_PORT
DEVICE_PASSWORD=$DEVICE_PASSWORD

GDRIVE_FOLDER_ID=$GDRIVE_FOLDER_ID
EOF

# Set up MySQL database
echo "🛢️ Creating MySQL database..."
sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS zk_attendance;
USE zk_attendance;
CREATE TABLE IF NOT EXISTS attendance_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    name VARCHAR(255),
    timestamp DATETIME,
    punch_type VARCHAR(20),
    source VARCHAR(50),
    synced BOOLEAN DEFAULT FALSE
);
MYSQL_SCRIPT

# Systemd service setup
echo "🖥️ Setting up systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/zkteco_sync.service
[Unit]
Description=ZKTeco Sync Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/zk-env/bin/python3 run_all.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable zkteco_sync.service
sudo systemctl start zkteco_sync.service

# Cron job for midnight backup
echo "🕛 Scheduling midnight backup..."
( crontab -l 2>/dev/null; echo "0 0 * * * cd $(pwd) && $(pwd)/zk-env/bin/python3 incremental_backup.py" ) | crontab -

echo "✅ Setup complete!"

echo "
📌 Final Checklist:
- Complete Google Drive authentication via get_access_token.py if not prompted
- Ensure ZKTeco device is connected at $DEVICE_IP:$DEVICE_PORT
- Reboot system to test auto-restart

🌙 Backups will run daily at midnight.
🔁 The sync service runs every 5 minutes continuously.
"
