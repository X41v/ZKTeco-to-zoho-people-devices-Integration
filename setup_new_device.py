import os
import subprocess
import sys
import time
import mysql.connector
from mysql.connector import Error
from getpass import getpass
from pathlib import Path

SCHEMA_FILE = 'schema.sql'
ENV_TEMPLATE = '.env.example'
ENV_FILE = 'e.env'
VENV_DIR = 'zk-env'
PYTHON_BIN = f'{VENV_DIR}/bin/python'


def run_command(command, check=True):
    print(f"\n[RUNNING] {command}")
    result = subprocess.run(command, shell=True)
    if check and result.returncode != 0:
        print("[ERROR] Command failed.")
        sys.exit(1)


def install_system_dependencies():
    print("\n📦 Installing system dependencies (git, python3, mariadb)...")
    run_command('sudo apt update')
    run_command('sudo apt install -y git python3 python3-venv mariadb-server mariadb-client')
    run_command(f'{VENV_DIR}/bin/pip install pydrive python-dotenv')


def setup_virtualenv():
    print("\n🐍 Setting up Python virtual environment...")
    run_command(f'python3 -m venv {VENV_DIR}')
    run_command(f'{VENV_DIR}/bin/pip install --upgrade pip')
    run_command(f'{VENV_DIR}/bin/pip install -r requirements.txt')


def create_database():
    print("\n🛢️ Setting up MariaDB database `zk_attendance`...")
    db_password = getpass("Enter MariaDB root password: ")
    try:
        conn = mysql.connector.connect(
            host='localhost',
            user='root',
            password=db_password
        )
        if conn.is_connected():
            cursor = conn.cursor()
            cursor.execute("CREATE DATABASE IF NOT EXISTS zk_attendance;")
            print("✅ Database 'zk_attendance' created or already exists.")
            print("📥 Creating tables from schema.sql...")
            run_command(f"mysql -u root -p{db_password} zk_attendance < {SCHEMA_FILE}")
    except Error as e:
        print(f"[ERROR] Database error: {e}")
        sys.exit(1)


def prepare_env_file():
    print("\n⚙️ Configuring environment variables...")
    if not Path(ENV_FILE).exists():
        run_command(f'cp {ENV_TEMPLATE} {ENV_FILE}')

    device_ip = input("Enter ZKTeco device IP: ")
    device_password = input("Enter ZKTeco device password: ")
    db_password = getpass("Enter MariaDB root password again for .env setup: ")

    with open(ENV_FILE, 'r') as f:
        lines = f.readlines()

    with open(ENV_FILE, 'w') as f:
        for line in lines:
            if line.startswith('DB_PASSWORD='):
                f.write(f'DB_PASSWORD={db_password}\n')
            elif line.startswith('DEVICE_IP='):
                f.write(f'DEVICE_IP={device_ip}\n')
            elif line.startswith('DEVICE_PASSWORD='):
                f.write(f'DEVICE_PASSWORD={device_password}\n')
            else:
                f.write(line)

    print("✅ Environment file configured.")


def run_get_access_token():
    print("""
🔑 Running get_access_token.py to obtain Zoho People token
Steps:
 1️⃣ Provide Client ID, Client Secret, and Redirect URI when prompted.
 2️⃣ A URL will be generated — open it in your browser and grant access.
 3️⃣ Copy the authorization code from the browser and paste it back into the terminal.
 4️⃣ Access and refresh tokens will be saved to zoho_tokens.json
""")
    run_command(f'{PYTHON_BIN} get_access_token.py')


def print_drive_instructions():
    print("""
🗂️ Google Drive Backup Setup
To back up attendance data to Google Drive:

1️⃣ Go to https://console.cloud.google.com/apis/credentials
2️⃣ Create OAuth 2.0 Client ID (Desktop app)
3️⃣ Download the JSON and save it as: client_secrets.json
4️⃣ Run the backup script manually using:
     source zk-env/bin/activate
     python3 incremental_backup.py
""")


def setup_cron_jobs():
    print("\n⏰ Setting up cron jobs for automation")

    run_interval = input("Enter interval (in minutes) to run run_all.py (e.g., 30): ")
    backup_hour = input("Enter the hour to run incremental_backup.py daily (e.g., 0 for midnight): ")
    backup_minute = input("Enter the minute to run incremental_backup.py daily (e.g., 0): ")

    cron_line_run_all = f"*/{run_interval} * * * * cd {os.getcwd()} && {os.getcwd()}/{VENV_DIR}/bin/python run_all.py >> cron_run_all.log 2>&1"
    cron_line_backup = f"{backup_minute} {backup_hour} * * * cd {os.getcwd()} && {os.getcwd()}/{VENV_DIR}/bin/python incremental_backup.py >> cron_backup.log 2>&1"

    print("\n📝 Adding the following cron jobs:")
    print(cron_line_run_all)
    print(cron_line_backup)

    with open("temp_cron", "w") as f:
        existing_cron = subprocess.run("crontab -l", shell=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if existing_cron.returncode == 0:
            f.write(existing_cron.stdout.decode())
        f.write("\n" + cron_line_run_all + "\n")
        f.write(cron_line_backup + "\n")

    run_command("crontab temp_cron")
    os.remove("temp_cron")
    print("✅ Cron jobs installed.")


def print_final_instructions():
    print("""
🎉 Setup Complete!

👉 Now you can run the integration using:
  source zk-env/bin/activate
  python3 run_all.py

👉 To enable backup to Google Drive:
  python3 incremental_backup.py

Make sure you have placed your client_secrets.json and updated tokens if needed.
""")


if __name__ == '__main__':
    install_system_dependencies()
    setup_virtualenv()
    create_database()
    prepare_env_file()
    run_get_access_token()
    print_drive_instructions()
    setup_cron_jobs()
    print_final_instructions()
