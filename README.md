# ZKTeco to Zoho People Devices Integration

This project automates attendance tracking by integrating ZKTeco biometric devices with Zoho People. It collects biometric punch logs, stores them locally in a MariaDB database, and synchronizes attendance records bidirectionally with Zoho People via their API.

---

##  Features

- Fetch attendance logs from ZKTeco MB20-VL biometric devices
- Store logs in a local MariaDB database (`zk_attendance`)
- Import attendance logs from Zoho People into local DB
- Deduplicate logs across device and Zoho sources
- Push unsynced attendance logs from local DB to Zoho People
- Incremental backups of attendance tables to Google Drive in `.sql` format
- Modular Python scripts for maintainability
- Optional Docker deployment
- Fully configurable with environment variables in `.env`

---

## 📦 Setup Instructions for a New Device

### 1. Install Dependencies

Update your OS and install required packages:

```bash
sudo apt update
sudo apt install git python3 python3-venv mariadb-server mariadb-client

## 2. Clone the Repository
 
git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
cd ZKTeco-to-zoho-people-devices-Integration

## 3. Create Python Virtual Environment and Install Libraries

python3 -m venv zk-env
source zk-env/bin/activate
pip install -r requirements.txt

## 4. Generate requirement.txt with

pip install mysql-connector-python python-dotenv google-api-python-client google-auth-httplib2 google-auth-oauthlib
pip freeze > requirements.txt

## 5. Setup the MariaDB Database
Start MariaDB service:
sudo service mariadb start
OR 
sudo service mariadb start

Create the attendance database:
mysql -u root -p -e "CREATE DATABASE zk_attendance;"


Create tables from schema:
mysql -u root -p zk_attendance < schema.sql

## 6. Configure Environment Variables
Copy the example environment config and edit it:
cp .env.example .env
nano .env

## 7. Running the Attendance Scripts

python3 run_all.py

Or run individually:
python3 insert_log_to_db.py     # Pull logs from ZKTeco device to local DB
python3 zoholog_to_db.py        # Import Zoho attendance logs to DB
python3 order_table.py          # Remove duplicate logs
python3 sync_to_zoho.py         # Push unsynced logs to Zoho People


## 8. For backing up the database tables to Google Drive:

python3 incremental_backup.py


## 10. Automate with Cron (Optional)
Set up cron jobs to automate the running of these scripts regularly.

Example crontab (crontab -e):
# Run every hour
0 * * * * cd /path/to/ZKTeco-to-zoho-people-devices-Integration && source zk-env/bin/activate && python3 run_all.py >> run_all.log 2>&1
