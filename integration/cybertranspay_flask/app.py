from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import os
import requests
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__, template_folder='templates')
CORS(app)

CYBER_BASE = os.getenv('CYBER_API_BASE', 'http://localhost:8080')
CYBER_API_KEY = os.getenv('CYBER_API_KEY')

def cyber_headers():
    headers = {'Content-Type': 'application/json'}
    if CYBER_API_KEY:
        headers['X-API-Key'] = CYBER_API_KEY
    return headers

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/assets', methods=['GET'])
def get_assets():
    url = f"{CYBER_BASE}/v1/assets"
    resp = requests.get(url, headers=cyber_headers(), timeout=10)
    return (resp.content, resp.status_code, resp.headers.items())

@app.route('/api/quote', methods=['POST'])
def create_quote():
    payload = request.get_json(force=True)
    url = f"{CYBER_BASE}/v1/routes/quote"
    resp = requests.post(url, json=payload, headers=cyber_headers(), timeout=10)
    return (resp.content, resp.status_code, resp.headers.items())

@app.route('/api/transfer', methods=['POST'])
def create_transfer():
    payload = request.get_json(force=True)
    url = f"{CYBER_BASE}/v1/transfers"
    resp = requests.post(url, json=payload, headers=cyber_headers(), timeout=10)
    return (resp.content, resp.status_code, resp.headers.items())

@app.route('/api/transfer/<transfer_id>', methods=['GET'])
def get_transfer(transfer_id):
    url = f"{CYBER_BASE}/v1/transfers/{transfer_id}"
    resp = requests.get(url, headers=cyber_headers(), timeout=10)
    return (resp.content, resp.status_code, resp.headers.items())

if __name__ == '__main__':
    host = os.getenv('FLASK_RUN_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_RUN_PORT', 5000))
    app.run(host=host, port=port)
