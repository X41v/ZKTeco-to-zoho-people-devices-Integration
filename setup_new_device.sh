#!/bin/bash

set -e

PROJECT_NAME="ZKTeco-to-zoho-people-devices-Integration"
VENV_DIR="zk-env"
PYTHON_BIN="$VENV_DIR/bin/python"
SCHEMA_FILE="schema.sql"
ENV_TEMPLATE=".env.example"
ENV_FILE=".env"
REQUIREMENTS_FILE="requirements.txt"
SERVICE_NAME="zk_sync"
BACKUP_SERVICE_NAME="zk_backup"

INFO="\033[1;34m"
SUCCESS="\033[1;32m"
RESET="\033[0m"

print_section() {
    echo -e "\n${INFO}$1${RESET}"
}

# 1. Install necessary packages
print_section "📦 Installing system packages..."
sudo apt update
sudo apt install -y git python3 python3-venv mariadb-server mariadb-client systemd

# 2. Clone project repo if not present
print_section "⬇️ Cloning project repository..."
if [ ! -d "$PROJECT_NAME" ]; then
    git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
fi
cd "$PROJECT_NAME"

# 3. Create virtual environment and install dependencies
print_section "⚙️ Setting up Python environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    cat <<EOL > "$REQUIREMENTS_FILE"
mysql-connector-python
requests
python-dotenv
pydrive
zk==0.9.4
EOL
fi

pip install --upgrade pip
pip install -r "$REQUIREMENTS_FILE"

# 4. Configure MariaDB
print_section "🛢️ Setting up MariaDB..."
sudo service mariadb start
sudo mysql -e "CREATE DATABASE IF NOT EXISTS zk_attendance;"
sudo mysql zk_attendance < "$SCHEMA_FILE"

# 5. Configure .env file
print_section "📝 Setting up .env file..."
cp "$ENV_TEMPLATE" "$ENV_FILE"
read -p "Enter ZKTeco device IP: " DEVICE_IP
read -p "Enter ZKTeco device password: " DEVICE_PASSWORD
sed -i "s|^DEVICE_IP=.*|DEVICE_IP=$DEVICE_IP|" "$ENV_FILE"
sed -i "s|^DEVICE_PASSWORD=.*|DEVICE_PASSWORD=$DEVICE_PASSWORD|" "$ENV_FILE"

# 6. Get Zoho token
print_section "🔐 Authorizing Zoho..."
$PYTHON_BIN get_access_token.py

# 7. Systemd service to run run_all.py every 5 minutes
print_section "⚙️ Creating systemd service for sync..."

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOL
[Unit]
Description=ZKTeco to Zoho People Sync
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/$VENV_DIR/bin/python run_all.py
Restart=always
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOL

sudo tee /etc/systemd/system/${SERVICE_NAME}.timer > /dev/null <<EOL
[Unit]
Description=Run run_all.py every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=${SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOL

# 8. Systemd service for daily backup at midnight
print_section "🗂️ Creating systemd service for backup..."

sudo tee /etc/systemd/system/${BACKUP_SERVICE_NAME}.service > /dev/null <<EOL
[Unit]
Description=ZKTeco DB Backup
After=network.target

[Service]
Type=simple
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/$VENV_DIR/bin/python incremental_backup.py
Environment="PYTHONUNBUFFERED=1"
EOL

sudo tee /etc/systemd/system/${BACKUP_SERVICE_NAME}.timer > /dev/null <<EOL
[Unit]
Description=Run DB backup daily at midnight

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true
Unit=${BACKUP_SERVICE_NAME}.service

[Install]
WantedBy=timers.target
EOL

# 9. Enable all timers and services
print_section "📅 Enabling systemd timers and services..."

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}.timer
sudo systemctl start ${SERVICE_NAME}.timer
sudo systemctl enable ${BACKUP_SERVICE_NAME}.timer
sudo systemctl start ${BACKUP_SERVICE_NAME}.timer

# 10. Final notes
print_section "✅ SETUP COMPLETE!"
echo -e "${SUCCESS}✔ run_all.py scheduled every 5 mins"
echo -e "${SUCCESS}✔ Backup scheduled daily at 00:00"
echo -e "${SUCCESS}✔ All will resume after reboot"
echo -e "Check services with: sudo systemctl status ${SERVICE_NAME}.timer"

exit 0
