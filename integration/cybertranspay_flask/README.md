# CyberTransPay — Flask proxy example

Легкий приклад інтеграції CyberTransPay через серверну проксі на Python/Flask.

## Швидкий старт

1. Скопіюйте файл `.env.example` в `.env` і заповніть `CYBER_API_KEY` та `CYBER_API_BASE`.
2. Встановіть залежності:

```bash
python3 -m pip install -r requirements.txt
```

3. Запустіть сервер:

```bash
python app.py
```

4. Відкрийте у браузері http://localhost:5000 — простий фронтенд дозволяє створити котирування, створити трансфер та перевірити статус.

## Локальний mock для тестування

Цей приклад також має простий локальний mock-сервер для імітації CyberTransPay API.

```bash
python mock_server.py
```

За замовчуванням mock слухає на `http://127.0.0.1:8080`.

У другому терміналі запустіть проксі, вказавши локальний mock як бекенд:

```bash
CYBER_API_BASE=http://127.0.0.1:8080 CYBER_API_KEY=FAKEKEY python app.py
```

Потім відкрийте `http://127.0.0.1:5000` або протестуйте API з `curl`:

```bash
curl http://127.0.0.1:5000/api/assets
curl -X POST http://127.0.0.1:5000/api/quote -H 'Content-Type: application/json' -d '{"from":"USDT","to":"EUR","amount":100}'
curl -X POST http://127.0.0.1:5000/api/transfer -H 'Content-Type: application/json' -d '{"quote_id":"abc","recipient":"test"}'
```

## Файли

- `app.py` — Flask-проксі із маршрутами `/api/quote`, `/api/transfer`, `/api/transfer/<id>` та `/api/assets`.
- `mock_server.py` — простий локальний mock CyberTransPay сервіс.
- `templates/index.html` — мінімальний фронтенд, що викликає проксі.
- `requirements.txt` — залежності.
- `.env.example` — приклад змінних середовища.

## Безпека

- Зберігайте `CYBER_API_KEY` у змінних середовища або секретному сховищі — ніколи не пуште ключі в репо.
- У продакшні обмежте CORS та додайте HTTPS.
