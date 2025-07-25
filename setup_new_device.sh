#!/bin/bash

set -e

echo "🚀 Starting ZKTeco to Zoho People Integration Setup..."

# Update and install system packages
echo "📦 Installing required packages..."
sudo apt update
sudo apt install -y python3 python3-venv python3-pip mariadb-server mariadb-client git curl

# Enable and start MariaDB service
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Ask user for MySQL root password to create DB and user
echo ""
echo "🛢️ MariaDB setup"
echo "Please enter your MySQL root user password to proceed with database setup."
echo "If you have no password set, just press Enter."

read -sp "MySQL root password: " MYSQL_ROOT_PASS
echo ""

DB_NAME="zk_attendance"
DB_USER="zk_user"
DB_PASS="zkpass123"  # You can prompt for this if you want later

# Create database and user
echo "⏳ Creating database and user..."

if [ -z "$MYSQL_ROOT_PASS" ]; then
  sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
  sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
  sudo mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
  sudo mysql -e "FLUSH PRIVILEGES;"
else
  mysql -uroot -p"$MYSQL_ROOT_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
  mysql -uroot -p"$MYSQL_ROOT_PASS" -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
  mysql -uroot -p"$MYSQL_ROOT_PASS" -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
  mysql -uroot -p"$MYSQL_ROOT_PASS" -e "FLUSH PRIVILEGES;"
fi

echo "✅ Database and user created: $DB_NAME / $DB_USER"

# Clone the repo
echo ""
echo "📂 Cloning project repository..."
REPO_URL="https://github.com/your-username/ZKTeco-to-zoho-people-devices-Integration.git"
if [ -d "ZKTeco-to-zoho-people-devices-Integration" ]; then
  echo "Repository already cloned. Pulling latest changes..."
  cd ZKTeco-to-zoho-people-devices-Integration
  git pull
else
  git clone "$REPO_URL"
  cd ZKTeco-to-zoho-people-devices-Integration
fi

# Setup Python virtual environment and install dependencies
echo ""
echo "🐍 Setting up Python virtual environment and installing dependencies..."
python3 -m venv zk-env
source zk-env/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Interactive creation of .env file
echo ""
echo "📝 Configuring .env file with your input."

read -p "Enter your ZKTeco device IP (default 192.168.68.52): " DEVICE_IP
DEVICE_IP=${DEVICE_IP:-192.168.68.52}

read -p "Enter your ZKTeco device port (default 4370): " DEVICE_PORT
DEVICE_PORT=${DEVICE_PORT:-4370}

read -p "Enter your ZKTeco device password: " DEVICE_PASSWORD

read -p "Enter Zoho domain (default zoho.com): " ZOHO_DOMAIN
ZOHO_DOMAIN=${ZOHO_DOMAIN:-zoho.com}

read -p "Enter Zoho Client ID: " ZOHO_CLIENT_ID
read -p "Enter Zoho Client Secret: " ZOHO_CLIENT_SECRET

echo ""
echo "🚦 Starting Zoho OAuth token generation process..."
echo "This will open instructions to generate authorization code."

# Run get_access_token.py to get refresh token interactively
echo ""
echo "Please run the following command to get your Zoho Refresh Token:"
echo "  source zk-env/bin/activate && python3 get_access_token.py"
echo ""
echo "Follow the on-screen instructions, and after obtaining the refresh token,"
echo "paste it here."

read -p "Enter your Zoho Refresh Token: " ZOHO_REFRESH_TOKEN

read -p "Enter Google Drive folder ID for backups (or leave empty if none): " GDRIVE_FOLDER_ID

# Write .env file
cat > e.env << EOF
# MySQL Database
DB_HOST=localhost
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_NAME=$DB_NAME

# Zoho People API
ZOHO_DOMAIN=$ZOHO_DOMAIN
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

# Import schema to DB
echo ""
echo "📥 Importing database schema..."
if [ -z "$MYSQL_ROOT_PASS" ]; then
  sudo mysql $DB_NAME < schema.sql
else
  mysql -uroot -p"$MYSQL_ROOT_PASS" $DB_NAME < schema.sql
fi

echo "✅ Database schema imported."

# Setup systemd service and timer for run_all.py every 5 minutes

SERVICE_FILE="/etc/systemd/system/zk_run_all.service"
TIMER_FILE="/etc/systemd/system/zk_run_all.timer"

sudo bash -c "cat > $SERVICE_FILE" << EOL
[Unit]
Description=Run ZKTeco-to-Zoho run_all.py service
After=network.target mariadb.service

[Service]
Type=oneshot
WorkingDirectory=$PWD
ExecStart=$PWD/zk-env/bin/python3 $PWD/run_all.py
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOL

sudo bash -c "cat > $TIMER_FILE" << EOL
[Unit]
Description=Run zk_run_all.service every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable zk_run_all.timer
sudo systemctl start zk_run_all.timer

echo "✅ Systemd service and timer for run_all.py set to run every 5 minutes."

# Setup cron job for incremental_backup.py at midnight
CRON_JOB="0 0 * * * $PWD/zk-env/bin/python3 $PWD/incremental_backup.py >> $PWD/backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v -F "$PWD/incremental_backup.py"; echo "$CRON_JOB") | crontab -

echo "✅ Cron job scheduled for incremental_backup.py at midnight."

echo ""
echo "🎉 Setup complete! Please reboot your device to start the system automatically."
echo "After reboot, the integration system will run every 5 minutes automatically."
echo ""
echo "You can manually test the system anytime by running:"
echo "  source zk-env/bin/activate"
echo "  python3 run_all.py"
echo ""
echo "Google Drive backup requires OAuth token setup via get_access_token.py if not done already."
echo "If needed, run:"
echo "  source zk-env/bin/activate"
echo "  python3 get_access_token.py"
echo ""
