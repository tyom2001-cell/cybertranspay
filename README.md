# cybertranspay

![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)
![Status](https://img.shields.io/badge/Status-Pre--MVP-orange.svg)
![Owner](https://img.shields.io/badge/Owner-tyom2001--cell-blue.svg)

**Глобальная платформа мгновенных трансграничных платежей (crypto ↔ fiat) в одном клике.**

### Основные возможности
- Мгновенные P2P и B2B переводы  
- Умная маршрутизация (crypto, fiat, stablecoins, CBDC, BRICS)  
- Mass payments и recurring payments  
- Полный compliance (KYC/AML, Travel Rule, санкции)

**Репозиторий:** [tyom2001-cell/cybertranspay](https://github.com/tyom2001-cell/cybertranspay)  
**Владелец:** [tyom2001-cell](https://github.com/tyom2001-cell)

---

## Структура проекта
- `backend/` — Rust core (routing engine + AI)
- `frontend/` — Flutter (мобильное + десктоп + web)
- `smart-contracts/` — Multi-chain
- `terraform/` — Google Cloud + Developer Connect
- `docs/` — Документация

**Статус:** Pre-MVP | Активная разработка

**Деплой в GCP:** [docs/DEPLOY_GCP.md](docs/DEPLOY_GCP.md)

**Лицензия кода:** Apache 2.0  
**Торговая марка:** Принадлежит tyom2001-cell (все права защищены)

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
