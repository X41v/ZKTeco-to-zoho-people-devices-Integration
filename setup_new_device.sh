#!/bin/bash

set -e

PROJECT_NAME="ZKTeco-to-zoho-people-devices-Integration"
VENV_DIR="zk-env"
PYTHON_BIN="$VENV_DIR/bin/python"
SCHEMA_FILE="schema.sql"
ENV_TEMPLATE=".env.example"
ENV_FILE="e.env"
REQUIREMENTS_FILE="requirements.txt"
SYSTEMD_SERVICE="/etc/systemd/system/zk_sync.service"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

# Colors
INFO="\033[1;34m"
SUCCESS="\033[1;32m"
RESET="\033[0m"

print_section() {
    echo -e "\n${INFO}$1${RESET}"
}

# 1. Install Git and clone project
print_section "📦 Installing Git and cloning project..."
sudo apt update
sudo apt install -y git python3 python3-venv mariadb-server mariadb-client
if [ ! -d "$PROJECT_NAME" ]; then
    git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
fi
cd "$PROJECT_NAME"

# 2. Create requirements.txt if missing
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

# 3. Create Virtual Environment
print_section "⚙️ Setting up virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r $REQUIREMENTS_FILE

# 4. Set up MariaDB Database
print_section "🛢️ Configuring MariaDB (no root password)..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS zk_attendance;"
sudo mysql zk_attendance < "$SCHEMA_FILE"
echo -e "${SUCCESS}Database ready.${RESET}"

# 5. Prepare .env file
print_section "📝 Configuring .env file..."
cp "$ENV_TEMPLATE" "$ENV_FILE"
read -p "Enter ZKTeco device IP: " DEVICE_IP
read -p "Enter ZKTeco device password: " DEVICE_PASSWORD

sed -i "s/^DEVICE_IP=.*/DEVICE_IP=$DEVICE_IP/" "$ENV_FILE"
sed -i "s/^DEVICE_PASSWORD=.*/DEVICE_PASSWORD=$DEVICE_PASSWORD/" "$ENV_FILE"

# 6. Get Zoho access token
print_section "🔐 Running Zoho authorization..."
$PYTHON_BIN get_access_token.py

# 7. Google Drive setup instructions
print_section "🗂️ Google Drive Setup Instructions"
echo -e "1. Go to https://console.cloud.google.com/apis/credentials"
echo -e "2. Create OAuth client for Desktop app"
echo -e "3. Download JSON as client_secrets.json"
echo -e "4. Run: python3 incremental_backup.py"

# 8. Add virtual environment auto-activation for SSH sessions
print_section "🔄 Adding virtual environment auto-activation..."
BASHRC="$HOME/.bashrc"
if ! grep -q "source $PROJECT_DIR/$VENV_DIR/bin/activate" "$BASHRC"; then
    echo "source $PROJECT_DIR/$VENV_DIR/bin/activate" >> "$BASHRC"
    echo -e "${SUCCESS}Virtual environment will auto-activate on SSH login.${RESET}"
fi

# 9. Create systemd service for auto-start
print_section "⚙️ Creating systemd service for auto-sync..."
sudo bash -c "cat > $SYSTEMD_SERVICE" <<EOL
[Unit]
Description=ZKTeco-Zoho Sync Service
After=network.target mariadb.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'source $PROJECT_DIR/$VENV_DIR/bin/activate && python3 run_all.py'
Restart=always
User=$USER

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable zk_sync.service
sudo systemctl start zk_sync.service
echo -e "${SUCCESS}Systemd service created and started.${RESET}"

# 10. Optional Cron setup for backups
print_section "⏰ Cron Job Setup"
echo -n "Enter daily time for backup (e.g., 00:00): "
read BACKUP_TIME
BACKUP_MIN=$(echo $BACKUP_TIME | cut -d: -f2)
BACKUP_HR=$(echo $BACKUP_TIME | cut -d: -f1)
CRON_BACKUP="$BACKUP_MIN $BACKUP_HR * * * cd $PROJECT_DIR && source $PROJECT_DIR/$VENV_DIR/bin/activate && python3 incremental_backup.py >> cron_backup.log 2>&1"

( crontab -l 2>/dev/null; echo "$CRON_BACKUP" ) | crontab -

print_section "📌 Cron job added for backup at $BACKUP_TIME daily."

# Final message
print_section "✅ Setup Complete!"
echo "✔ Virtual environment auto-activates on SSH login"
echo "✔ run_all.py runs automatically at reboot"
echo "✔ Backup runs daily at $BACKUP_TIME"
echo "✔ To check sync logs: journalctl -u zk_sync.service -f"
