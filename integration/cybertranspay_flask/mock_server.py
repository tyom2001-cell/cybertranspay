from flask import Flask, jsonify, request
import uuid

app = Flask(__name__)

@app.route('/v1/assets', methods=['GET'])
def assets():
    return jsonify([{"symbol": "USDT", "name": "Tether"}, {"symbol": "EUR", "name": "Euro"}])

@app.route('/v1/routes/quote', methods=['POST'])
def quote():
    data = request.get_json(force=True)
    return jsonify({
        "quote_id": str(uuid.uuid4()),
        "from": data.get('from'),
        "to": data.get('to'),
        "amount": data.get('amount'),
        "rate": 0.98
    })

@app.route('/v1/transfers', methods=['POST'])
def create_transfer():
    data = request.get_json(force=True)
    transfer_id = str(uuid.uuid4())
    return jsonify({
        "transfer_id": transfer_id,
        "status": "pending",
        "details": data
    }), 201

@app.route('/v1/transfers/<transfer_id>', methods=['GET'])
def get_transfer(transfer_id):
    return jsonify({
        "transfer_id": transfer_id,
        "status": "completed"
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8080)
