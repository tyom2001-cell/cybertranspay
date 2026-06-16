# GitHub Codespaces ♥️ Jupyter Notebooks

Welcome to your shiny new codespace! We've got everything fired up and running for you to explore Python and Jupyter notebooks.

You've got a blank canvas to work on from a git perspective as well. There's a single initial commit with what you're seeing right now - where you go from here is up to you!

Everything you do here is contained within this one codespace. There is no repository on GitHub yet. If and when you’re ready you can click "Publish Branch" and we’ll create your repository and push up your project. If you were just exploring then and have no further need for this code then you can simply delete your codespace and it's gone forever.

## CyberTransPay Flask mock test

This workspace includes a CyberTransPay Flask proxy example under `integration/cybertranspay_flask` and a local mock server for testing without a real CyberTransPay backend.

To run the mock locally:

```bash
cd integration/cybertranspay_flask
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
python mock_server.py
```

In a second terminal, start the proxy app against the local mock backend:

```bash
cd integration/cybertranspay_flask
. .venv/bin/activate
CYBER_API_BASE=http://127.0.0.1:8080 CYBER_API_KEY=FAKEKEY FLASK_RUN_HOST=127.0.0.1 FLASK_RUN_PORT=5001 python app.py
```

Then open `http://127.0.0.1:5001` in your browser or test the endpoints with `curl`:

```bash
curl http://127.0.0.1:5001/api/assets
curl -X POST http://127.0.0.1:5001/api/quote -H 'Content-Type: application/json' -d '{"from":"USDT","to":"EUR","amount":100}'
curl -X POST http://127.0.0.1:5001/api/transfer -H 'Content-Type: application/json' -d '{"quote_id":"abc","recipient":"test"}'
```

This lets you verify the Flask proxy flow without a real CyberTransPay API key.
