#!/bin/bash

set -e

PROJECT_NAME="ZKTeco-to-zoho-people-devices-Integration"
VENV_DIR="zk-env"
PYTHON_BIN="$VENV_DIR/bin/python"
SCHEMA_FILE="schema.sql"
ENV_TEMPLATE=".env.example"
ENV_FILE="e.env"

# Colors for clarity
INFO="\033[1;34m"
SUCCESS="\033[1;32m"
RESET="\033[0m"

print_section() {
    echo -e "\n${INFO}$1${RESET}"
}

# 1. Install Git and clone project
print_section "📦 Installing Git and cloning project..."
sudo apt update
sudo apt install -y git
if [ ! -d "$PROJECT_NAME" ]; then
    git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
fi
cd "$PROJECT_NAME"

# 2. Install Python, MariaDB, and dependencies
print_section "🐍 Installing Python, MariaDB and dependencies..."
sudo apt install -y python3 python3-venv mariadb-server mariadb-client

# 3. Create Virtual Environment
print_section "⚙️ Setting up virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt
pip install pydrive python-dotenv

# 4. Set up MariaDB Database
print_section "🛢️ Creating MariaDB database..."
echo -n "Enter MariaDB root password: "
read -s DB_PASS
echo
mysql -u root -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS zk_attendance;"
mysql -u root -p"$DB_PASS" zk_attendance < "$SCHEMA_FILE"
echo -e "\n${SUCCESS}Database ready.${RESET}"

# 5. Prepare environment file
print_section "📝 Configuring .env file..."
cp "$ENV_TEMPLATE" "$ENV_FILE"
read -p "Enter ZKTeco device IP: " DEVICE_IP
read -p "Enter ZKTeco device password: " DEVICE_PASSWORD

sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" "$ENV_FILE"
sed -i "s/^DEVICE_IP=.*/DEVICE_IP=$DEVICE_IP/" "$ENV_FILE"
sed -i "s/^DEVICE_PASSWORD=.*/DEVICE_PASSWORD=$DEVICE_PASSWORD/" "$ENV_FILE"

# 6. Get access token
print_section "🔐 Launching Zoho authorization script..."
$PYTHON_BIN get_access_token.py

# 7. Google Drive instructions
print_section "🗂️ Google Drive Setup"
echo -e "1. Go to https://console.cloud.google.com/apis/credentials"
echo -e "2. Create OAuth client credentials for a Desktop app"
echo -e "3. Download the JSON and save it as: client_secrets.json"
echo -e "4. Run the backup script later using:"
echo -e "   source $VENV_DIR/bin/activate && python3 incremental_backup.py"

# 8. Final Instructions
print_section "✅ Setup Complete!"
echo "To start syncing:"
echo "  source $VENV_DIR/bin/activate && python3 run_all.py"
echo "To back up manually:"
echo "  python3 incremental_backup.py"

# 9. Optional Cron Setup
print_section "⏰ Cron Job Setup"
echo -n "Enter interval in minutes for run_all.py (e.g. 30): "
read RUN_INTERVAL
CRON_RUNALL="*/$RUN_INTERVAL * * * * cd $(pwd) && source $VENV_DIR/bin/activate && python3 run_all.py >> cron_run_all.log 2>&1"

echo -n "Enter daily time for backup (e.g. 00:00): "
read BACKUP_TIME
BACKUP_MIN=$(echo $BACKUP_TIME | cut -d: -f2)
BACKUP_HR=$(echo $BACKUP_TIME | cut -d: -f1)
CRON_BACKUP="$BACKUP_MIN $BACKUP_HR * * * cd $(pwd) && source $VENV_DIR/bin/activate && python3 incremental_backup.py >> cron_backup.log 2>&1"

( crontab -l 2>/dev/null; echo "$CRON_RUNALL"; echo "$CRON_BACKUP" ) | crontab -

print_section "📌 Cron jobs added successfully."
echo "✔ run_all.py every $RUN_INTERVAL min"
echo "✔ incremental_backup.py daily at $BACKUP_TIME"

exit 0
