#!/bin/bash

# Project setup script for ZKTeco to Zoho People Integration

echo "🔧 Setting up project..."

# Determine project directory
PROJECT_DIR=$(pwd)
VENV_DIR="$PROJECT_DIR/zk-env"
ENV_FILE="$PROJECT_DIR/e.env"
SERVICE_FILE="/etc/systemd/system/zk_run_all.service"
TIMER_FILE="/etc/systemd/system/zk_run_all.timer"
BACKUP_SERVICE="/etc/systemd/system/zk_incremental_backup.service"
BACKUP_TIMER="/etc/systemd/system/zk_incremental_backup.timer"
DB_NAME="zk_attendance"

# Ensure system packages are updated
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv mariadb-server libmariadb-dev curl jq

# Create virtual environment
if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# Install Python requirements
pip install --upgrade pip
pip install -r "$PROJECT_DIR/requirements.txt"

# Create database if not exists
echo "CREATE DATABASE IF NOT EXISTS $DB_NAME;" | sudo mariadb
sudo mariadb "$DB_NAME" < "$PROJECT_DIR/schema.sql"

# Prompt for environment variables
echo "🔑 Creating .env file..."
read -p "Enter MySQL password: " MYSQL_PASSWORD
read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET

cat > "$ENV_FILE" <<EOF
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_DATABASE=$DB_NAME
ZOHO_CLIENT_ID=$ZOHO_CLIENT_ID
ZOHO_CLIENT_SECRET=$ZOHO_CLIENT_SECRET
EOF

# Systemd Service for run_all.py
echo "🛠️  Creating systemd service for run_all.py..."
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Run ZKTeco Integration Script
After=network.target mariadb.service

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'source $VENV_DIR/bin/activate && python3 $PROJECT_DIR/run_all.py'
EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF

# Timer for every 5 minutes
sudo bash -c "cat > $TIMER_FILE" <<EOF
[Unit]
Description=Run run_all.py every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Systemd Service for incremental_backup.py
echo "🛠️  Creating systemd service for backup..."
sudo bash -c "cat > $BACKUP_SERVICE" <<EOF
[Unit]
Description=Incremental Backup of Attendance DB
After=network.target mariadb.service

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=/bin/bash -c 'source $VENV_DIR/bin/activate && python3 $PROJECT_DIR/incremental_backup.py'
EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF

# Timer for daily backup at midnight
sudo bash -c "cat > $BACKUP_TIMER" <<EOF
[Unit]
Description=Run incremental backup at midnight

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload and enable all services/timers
echo "🔁 Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable zk_run_all.timer
sudo systemctl start zk_run_all.timer
sudo systemctl enable zk_incremental_backup.timer
sudo systemctl start zk_incremental_backup.timer

echo "✅ Setup complete!"
