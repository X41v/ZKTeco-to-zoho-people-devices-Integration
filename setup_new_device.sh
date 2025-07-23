#!/bin/bash

set -e

PROJECT_NAME="ZKTeco-to-zoho-people-devices-Integration"
VENV_DIR="zk-env"
PYTHON_BIN="$VENV_DIR/bin/python"
SCHEMA_FILE="schema.sql"
ENV_TEMPLATE=".env.example"
ENV_FILE="e.env"
REQUIREMENTS_FILE="requirements.txt"

# Colors
INFO="\033[1;34m"
SUCCESS="\033[1;32m"
RESET="\033[0m"

print_section() {
    echo -e "\n${INFO}$1${RESET}"
}

# 1. Install system packages
print_section "📦 Installing system packages..."
sudo apt update
sudo apt install -y git python3 python3-venv mariadb-server mariadb-client systemd

# 2. Clone project if not exists
print_section "⬇️ Cloning project..."
if [ ! -d "$PROJECT_NAME" ]; then
    git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
fi
cd "$PROJECT_NAME"

# 3. Generate requirements.txt if missing
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    print_section "🛠️ Generating requirements.txt..."
    cat <<EOL > $REQUIREMENTS_FILE
mysql-connector-python
requests
python-dotenv
pydrive
zk==0.9.4
EOL
    echo -e "${SUCCESS}requirements.txt generated successfully.${RESET}"
fi

# 4. Setup virtual environment
print_section "⚙️ Setting up virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r $REQUIREMENTS_FILE

# 5. MariaDB setup
print_section "🛢️ Configuring MariaDB (no root password)..."
sudo service mariadb start
sudo mysql -e "CREATE DATABASE IF NOT EXISTS zk_attendance;"
sudo mysql zk_attendance < "$SCHEMA_FILE"
echo -e "${SUCCESS}Database ready.${RESET}"

# 6. Configure .env file
print_section "📝 Configuring .env file..."
cp "$ENV_TEMPLATE" "$ENV_FILE"
read -p "Enter ZKTeco device IP: " DEVICE_IP
read -p "Enter ZKTeco device password: " DEVICE_PASSWORD
sed -i "s|^DEVICE_IP=.*|DEVICE_IP=$DEVICE_IP|" "$ENV_FILE"
sed -i "s|^DEVICE_PASSWORD=.*|DEVICE_PASSWORD=$DEVICE_PASSWORD|" "$ENV_FILE"

# 7. Zoho Authorization
print_section "🔐 Running Zoho authorization..."
$PYTHON_BIN get_access_token.py

# 8. Google Drive instructions
print_section "🗂️ Google Drive Setup Instructions"
echo -e "1. Go to https://console.cloud.google.com/apis/credentials"
echo -e "2. Create OAuth client for Desktop app"
echo -e "3. Download JSON as client_secrets.json"
echo -e "4. Run: source $VENV_DIR/bin/activate && python3 incremental_backup.py"

# 9. Systemd service for run_all.py
print_section "⚙️ Creating systemd service for run_all.py..."
sudo tee /etc/systemd/system/zk_sync.service > /dev/null <<EOL
[Unit]
Description=ZKTeco to Zoho People Sync Service
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/$VENV_DIR/bin/python run_all.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# 10. Timer for run_all.py (5 min)
sudo tee /etc/systemd/system/zk_sync.timer > /dev/null <<EOL
[Unit]
Description=Run run_all.py every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=zk_sync.service

[Install]
WantedBy=timers.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable zk_sync.timer
sudo systemctl start zk_sync.timer

# 11. Systemd service for daily backup
print_section "⚙️ Creating systemd service for backups..."
sudo tee /etc/systemd/system/zk_backup.service > /dev/null <<EOL
[Unit]
Description=ZKTeco Database Backup
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/$VENV_DIR/bin/python incremental_backup.py
EOL

# 12. Timer for daily backup
sudo tee /etc/systemd/system/zk_backup.timer > /dev/null <<EOL
[Unit]
Description=Run backup daily at 00:00

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true
Unit=zk_backup.service

[Install]
WantedBy=timers.target
EOL

sudo systemctl enable zk_backup.timer
sudo systemctl start zk_backup.timer

# 13. Final info
print_section "✅ Setup Complete!"
echo "run_all.py will now run every 5 minutes."
echo "incremental_backup.py will run daily at midnight."
echo "You can check status with: sudo systemctl status zk_sync.timer"

exit 0
