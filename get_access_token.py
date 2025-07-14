import requests
import json
import logging
from typing import Dict

def configure_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('zoho_auth.log'),
            logging.StreamHandler()
        ]
    )

class ZohoAuthManager:
    def __init__(self, client_id: str, client_secret: str, redirect_uri: str):
        self.config = {
            'client_id': client_id,
            'client_secret': client_secret,
            'redirect_uri': redirect_uri,
            'token_file': 'zoho_tokens.json'
        }
        self.refresh_token = None

    def save_tokens(self, tokens: Dict) -> None:
        with open(self.config['token_file'], 'w') as f:
            json.dump(tokens, f, indent=2)
        self.refresh_token = tokens.get('refresh_token')
        logging.info("✅ Tokens saved successfully.")

    def get_authorization_url(self) -> str:
        # ✅ Updated scope to include employee record access
        scope = "ZohoPeople.attendance.ALL,ZohoPeople.forms.READ"
        return (
            "https://accounts.zoho.com/oauth/v2/auth?"
            f"scope={scope}&"
            f"client_id={self.config['client_id']}&"
            "response_type=code&"
            "access_type=offline&"
            f"redirect_uri={self.config['redirect_uri']}&"
            "prompt=consent"
        )

    def initial_auth_flow(self, auth_code: str) -> Dict:
        response = requests.post(
            "https://accounts.zoho.com/oauth/v2/token",
            data={
                "code": auth_code,
                "client_id": self.config['client_id'],
                "client_secret": self.config['client_secret'],
                "redirect_uri": self.config['redirect_uri'],
                "grant_type": "authorization_code"
            }
        )
        try:
            response.raise_for_status()
            tokens = response.json()
            self.save_tokens(tokens)
            logging.info("✅ Initial authorization successful.")
            return tokens
        except Exception as e:
            logging.error(f"❌ Failed to complete auth flow: {e}")
            raise

# ==== MAIN ====
if __name__ == "__main__":
    configure_logging()

    print("\n🔧 Enter your Zoho API credentials:")
    client_id = input("Client ID: ").strip()
    client_secret = input("Client Secret: ").strip()
    redirect_uri = input("Redirect URI: ").strip()

    auth_manager = ZohoAuthManager(client_id, client_secret, redirect_uri)

    # Step 1: Show Authorization URL
    print("\n📎 Copy this URL and paste it into your browser to authorize:")
    print("\n" + auth_manager.get_authorization_url() + "\n")

    # Step 2: Prompt for auth code
    auth_code = input("🔐 Paste the authorization code from Zoho here: ").strip()

    # Step 3: Exchange code for tokens
    try:
        tokens = auth_manager.initial_auth_flow(auth_code)
        print("\n✅ Tokens received and saved:")
        print(json.dumps(tokens, indent=2))
    except Exception as e:
        print(f"\n❌ Error exchanging authorization code: {e}")
