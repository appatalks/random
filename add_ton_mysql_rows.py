import subprocess
import uuid
import json
import random
from datetime import datetime, timedelta

# Function to generate random data for a row
def generate_row():
    guid = str(uuid.uuid4())
    parent = f"repository-{random.randint(1, 100)}"
    hook_id = random.randint(1, 10)
    repo_id = random.randint(1, 100)
    installation_id = 'NULL'
    url = ""
    content_type = "json"
    event = "ping"
    action = 'NULL'
    redelivery = 0
    requested_public_key_signature = 0
    allowed_insecure_ssl = 0
    secret = 'NULL'
    status = 200
    message = "OK"
    duration = random.randint(100, 2000)
    github_request_id = str(uuid.uuid4())
    created_at = (datetime.now() - timedelta(days=random.randint(0, 365))).strftime('%Y-%m-%d %H:%M:%S')
    request_headers = json.dumps({
        "Accept": ["*/*"],
        "Content-Type": ["application/json"],
        "User-Agent": ["GitHub-Hookshot/13d1f6a"],
        "X-GitHub-Delivery": [guid],
        "X-GitHub-Enterprise-Host": ["git.example.com"],
        "X-GitHub-Enterprise-Version": ["3.12.4"],
        "X-GitHub-Event": [event],
        "X-GitHub-Hook-ID": [str(hook_id)],
        "X-GitHub-Hook-Installation-Target-ID": [str(repo_id)],
        "X-GitHub-Hook-Installation-Target-Type": ["repository"]
    })
    response_headers = json.dumps({
        "Access-Control-Allow-Origin": ["*"],
        "Content-Length": ["0"],
        "Date": [created_at],
        "Request-Context": ["appId=cid-v1:"],
        "Set-Cookie": [
            "ARRAffinity=bb6300a5f84b8ebe6bb8a7303f8de7d352ecc90f205802ed080b7d9e6f2f5e07;Path=/;HttpOnly;Secure;Domain=",
            "ARRAffinitySameSite=bb6300a5f84b8ebe6bb8a7303f8de7d352ecc90f205802ed080b7d9e6f2f5e07;Path=/;HttpOnly;SameSite=None;Secure;Domain="
        ],
        "X-Powered-By": ["Express"]
    })
    response_body = 'NULL'

    return (guid, parent, hook_id, repo_id, installation_id, url, content_type, event, action, redelivery, requested_public_key_signature, allowed_insecure_ssl, secret, status, message, duration, github_request_id, created_at, request_headers, response_headers, response_body)

# Generate and insert data in batches
num_rows = 20000
batch_size = 100

for _ in range(0, num_rows, batch_size):
    rows = [generate_row() for _ in range(batch_size)]
    
    values = ", ".join(
        f"('{row[0]}', '{row[1]}', {row[2]}, {row[3]}, {row[4]}, '{row[5]}', '{row[6]}', '{row[7]}', {row[8]}, {row[9]}, {row[10]}, {row[11]}, {row[12]}, {row[13]}, '{row[14]}', {row[15]}, '{row[16]}', '{row[17]}', '{row[18]}', '{row[19]}', {row[20]})"
        for row in rows
    )
    
    query = f"""
    INSERT INTO webhook_deliveries (
        guid, parent, hook_id, repo_id, installation_id, url, content_type, event, action, redelivery, requested_public_key_signature, allowed_insecure_ssl, secret, status, message, duration, github_request_id, created_at, request_headers, response_headers, response_body
    ) VALUES {values};
    """
    
    # Use sudo to run the query with the specified database
    subprocess.run(['sudo', 'mysql', 'github_enterprise', '-e', query], check=True)

print("Data insertion complete.")
