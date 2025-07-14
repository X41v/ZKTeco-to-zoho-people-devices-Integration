import os
import subprocess
import json
from pathlib import Path

def install_packages():
    print("🔧 Installing required Python packages...")
    packages = [
        "mysql-connector-python",
        "python-dotenv",
        "google-api-python-client",
        "google-auth-httplib2",
        "google-auth-oauthlib",
        "zkpy"
    ]
    subprocess.run(["pip", "install"] + packages, check=True)
    subprocess.run(["pip", "freeze"], stdout=open("requirements.txt", "w"))
    print("✅ Packages installed and requirements.txt generated.\n")

def create_database_and_tables():
    print("🗃️ Creating MariaDB database and tables...")
    root_pass = input("🔑 Enter MySQL root password: ")

    # Create database
    create_db = subprocess.run(
        ["mysql", "-u", "root", f"-p{root_pass}", "-e", "CREATE DATABASE IF NOT EXISTS zk_attendance;"],
        stderr=subprocess.DEVNULL
    )
    if create_db.returncode != 0:
        print("❌ Failed to create database. Please check your MySQL root password.")
        exit(1)

    # Apply schema.sql
    schema_path = Path("schema.sql")
    if not schema_path.exists():
        print("❌ schema.sql file is missing.")
        exit(1)

    load_schema = subprocess.run(
        f"mysql -u root -p{root_pass} zk_attendance < schema.sql",
        shell=True
    )

    if load_schema.returncode != 0:
        print("❌ Failed to import schema.sql.")
        exit(1)

    print("✅ Database and tables created.\n")
    return root_pass

def run_get_token():
    print("🌐 Opening browser to generate Zoho access token...")
    subprocess.run(["python3", "get_access_token.py"])
    print("✅ Token generated.\n")

def generate_env_file(db_pass):
    print("📝 Creating `.env` configuration file...")
    zk_ip = input("🔌 Enter ZKTeco device IP address: ")
    zk_port = input("📡 Enter ZKTeco device port (default 4370): ") or "4370"
    zk_pass = input("🔒 Enter ZKTeco device password (or leave blank): ")

    folder_id = input("🗂️ Enter your Google Drive Folder ID (or write 'skip' to configure later): ")

    env_content = f"""
DB_HOST=localhost
DB_USER=root
DB_PASSWORD={db_pass}
DB_NAME=zk_attendance

ZK_IP={zk_ip}
ZK_PORT={zk_port}
ZK_DEVICE_PASS={zk_pass}

GOOGLE_FOLDER_ID={folder_id if folder_id != "skip" else ""}
""".strip()

    with open("e.env", "w") as f:
        f.write(env_content + "\n")
    print("✅ `.env` file created.\n")

def create_client_secrets():
    if not Path("client_secrets.json").exists():
        print("📄 Generating placeholder client_secrets.json...")
        placeholder = {
            "installed": {
                "client_id": "your_client_id_here",
                "project_id": "your_project_id_here",
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                "client_secret": "your_client_secret_here",
                "redirect_uris": ["http://localhost:8090"]
            }
        }
        with open("client_secrets.json", "w") as f:
            json.dump(placeholder, f, indent=2)
        print("✅ Sample `client_secrets.json` created. Replace it with your real one.\n")
    else:
        print("✅ `client_secrets.json` already exists.\n")

def guide_google_backup():
    print("""
📂 To set up Google Drive for automatic backups:

1. Open https://console.cloud.google.com/apis/library/drive.googleapis.com
2. Enable the Drive API for your project
3. Download your `client_secrets.json` from the credentials section
4. Replace the placeholder file in this folder
5. When you're ready, run:

   python3 incremental_backup.py

It will open a browser where you approve Google Drive access.
After that, backups will be uploaded to the specified folder.

🔔 Make sure to update `GOOGLE_FOLDER_ID` in your `.env` file with the correct ID.
""")

def main():
    print("⚙️ Starting full setup for ZKTeco-Zoho attendance system...\n")
    install_packages()
    db_pass = create_database_and_tables()
    run_get_token()
    generate_env_file(db_pass)
    create_client_secrets()
    guide_google_backup()
    print("\n🎉 Setup complete! You can now run `python3 run_all.py` to begin syncing.")

if __name__ == "__main__":
    main()
