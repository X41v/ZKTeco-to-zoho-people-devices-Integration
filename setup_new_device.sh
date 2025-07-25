#!/bin/bash

# ─────────────────────────────────────────────────────────────
# SETUP: ZKTeco-to-Zoho People Attendance System (Full Auto)
# After running this script and rebooting, everything will run
# automatically every 5 minutes with no manual steps.
# ─────────────────────────────────────────────────────────────

echo "🔧 Starting ZKTeco-Zoho People setup..."

# ────────────── 1. Prompt for required input ──────────────
read -p "Enter MySQL root password: " mysql_root_pass
read -p "Enter a new MySQL user password: " mysql_user_pass
read -p "Enter Zoho Client ID: " zoho_client_id
read -p "Enter Zoho Client Secret: " zoho_client_secret

# ────────────── 2. Install dependencies ──────────────
echo "📦 Installing dependencies..."
sudo apt update && sudo apt install -y python3 python3-pip python3-venv mariadb-server mariadb-client cron unzip

# ────────────── 3. Setup virtual environment ──────────────
echo "🐍 Setting up Python virtual environment..."
cd ~/ZKTeco-to-zoho-people-devices-Integration || exit 1
python3 -m venv zk-env
source zk-env/bin/activate
pip install -r requirements.txt

# ────────────── 4. Create and configure .env ──────────────
echo "📝 Creating .env file..."
cat > .env <<EOF
DB_HOST=localhost
DB_USER=zk_user
DB_PASSWORD=$mysql_user_pass
DB_NAME=zk_attendance
DEVICE_IP=192.168.68.52
DEVICE_PORT=4370
DEVICE_PASSWORD=123456
CLIENT_ID=$zoho_client_id
CLIENT_SECRET=$zoho_client_secret
REDIRECT_URI=http://localhost
EOF

# ────────────── 5. Configure MariaDB ──────────────
echo "🛠️ Configuring MariaDB..."
sudo mariadb -u root -p"$mysql_root_pass" <<EOF
CREATE DATABASE IF NOT EXISTS zk_attendance;
CREATE USER IF NOT EXISTS 'zk_user'@'localhost' IDENTIFIED BY '$mysql_user_pass';
GRANT ALL PRIVILEGES ON zk_attendance.* TO 'zk_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# ────────────── 6. Import schema ──────────────
echo "🧱 Importing database schema..."
mysql -u root -p"$mysql_root_pass" zk_attendance < schema.sql

# ────────────── 7. Add cronjob to run every 5 minutes ──────────────
echo "⏲️ Scheduling cronjob..."
(crontab -l 2>/dev/null; echo "*/5 * * * * cd $(pwd) && source zk-env/bin/activate && python3 run_all.py >> cronjob.log 2>&1") | crontab -

# ────────────── 8. Enable cron service ──────────────
sudo systemctl enable cron
sudo systemctl restart cron

echo "✅ Setup complete!"
echo "🔁 You can now reboot. After reboot, everything will run every 5 minutes automatically."
