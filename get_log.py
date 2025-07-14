from zk import ZK, const
import logging
from datetime import datetime

def configure_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('zk_device_logs.log'),
            logging.StreamHandler()
        ]
    )

def get_attendance_records(ip: str, port: int, password: int) -> list:
    zk = ZK(
        ip=ip,
        port=port,
        password=password,
        force_udp=True,
        timeout=5,
        ommit_ping=False
    )
    
    conn = None
    try:
        conn = zk.connect()
        conn.disable_device()
        logging.info("Successfully connected to device")
        
        attendance = conn.get_attendance()
        logging.info(f"Retrieved {len(attendance)} attendance records")
        
        # Format records for better readability
        formatted_records = []
        for record in attendance:
            formatted_records.append({
                'user_id': record.user_id,
                'timestamp': record.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                'status': 'Check-In' if record.punch == 0 else 'Check-Out',
                'device_ip': ip
            })
        
        return formatted_records
        
    except Exception as e:
        logging.error(f"Error retrieving attendance: {str(e)}")
        return []
    finally:
        if conn:
            conn.enable_device()
            conn.disconnect()
            logging.info("Device connection closed")

def main():
    configure_logging()
    
    # Device configuration
    device_config = {
        'ip': '192.168.68.52',
        'port': 4370,
        'password': 123456
    }
    
    records = get_attendance_records(**device_config)
    
    # Print records in readable format
    for idx, record in enumerate(records, 1):
        logging.info(
            f"Record {idx}: User {record['user_id']} "
            f"{record['status']} at {record['timestamp']}"
        )

if __name__ == "__main__":
    main()
