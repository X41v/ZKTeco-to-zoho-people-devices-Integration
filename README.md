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

##  Pre-requisites

Ensure Python 3, pip, and Git are installed:

```bash
sudo apt update
sudo apt install python3 python3-venv python3-pip git mariadb-server mariadb-client -y
```

---

##  Setup Instructions for a New Device

### 1. Clone the Repository

```bash
git clone https://github.com/X41v/ZKTeco-to-zoho-people-devices-Integration.git
cd ZKTeco-to-zoho-people-devices-Integration
```

### 2. Create Python Virtual Environment and Install Dependencies

```bash
python3 -m venv zk-env
source zk-env/bin/activate
```

Run the auto-setup script:

```bash
python3 auto_setup.py
```

This will:
- Install required libraries
- Prompt you to create and initialize the database
- Run the Google Drive OAuth token generation script (`get_access_token.py`)
- Set up `.env` file with required config
- Prompt you to enter the ZKTeco device info
- Guide you through connecting to Google Drive for backups


---

##  Manual Commands (Optional / For Debugging)

If needed, you can manually run individual scripts:

```bash
source zk-env/bin/activate
python3 insert_log_to_db.py     # Pull logs from ZKTeco device to local DB
python3 zoholog_to_db.py        # Import Zoho attendance logs to DB
python3 order_table.py          # Remove duplicate logs
python3 sync_to_zoho.py         # Push unsynced logs to Zoho People
python3 incremental_backup.py   # Backup DB tables to Google Drive
```

---

##  Database Setup (Manual Option)

If not using `auto_setup.py`, you can set up the DB manually:

```bash
sudo service mariadb start
mysql -u root -p -e "CREATE DATABASE zk_attendance;"
mysql -u root -p zk_attendance < schema.sql
```

---

##  Environment Variables

Copy and configure the `.env` file:

```bash
cp .env.example e.env
nano e.env
```

This contains DB credentials, Zoho OAuth details, and ZKTeco device config.

---

##  Project Structure Overview

- `insert_log_to_db.py` – Fetch logs from ZKTeco device
- `zoholog_to_db.py` – Fetch logs from Zoho People API
- `order_table.py` – Compare and remove duplicates
- `sync_to_zoho.py` – Push local logs to Zoho People
- `incremental_backup.py` – Backup to Google Drive
- `get_access_token.py` – Run once to authorize Zoho API access
- `run_all.py` – Executes all core scripts in order
- `auto_setup.py` – NEW: Automates full setup and configuration
- `schema.sql` – DB schema to create required tables
- `e.env` – Your actual working environment file
- `.env.example` – Template for `.env`
- `README.md` – Setup documentation

---

##  Updating Your Codebase

To update from GitHub:

```bash
cd ZKTeco-to-zoho-people-devices-Integration
git pull
```

---

##  You're Ready!

After setup, use `run_all.py` to execute the whole sync process:

```bash
python3 run_all.py
```

Let the automation take care of attendance tracking! 
