# CyberTransPay — Flask proxy example

Легкий приклад інтеграції CyberTransPay через серверну проксі на Python/Flask.

Швидкий старт

1. Скопіюйте файл `.env.example` в `.env` і заповніть `CYBER_API_KEY` та `CYBER_API_BASE`.
2. Встановіть залежності:

```bash
python -m pip install -r requirements.txt
```

3. Запустіть сервер:

```bash
export FLASK_APP=app.py
export FLASK_ENV=development
flask run --host=0.0.0.0 --port=5000
```

4. Відкрийте у браузері http://localhost:5000 — простий фронтенд дозволяє створити котирування, створити трансфер та перевірити статус.

Файли

- `app.py` — Flask-проксі із маршрутами `/api/quote`, `/api/transfer`, `/api/transfer/<id>` та `/api/assets`.
- `templates/index.html` — мінімальний фронтенд, що викликає проксі.
- `requirements.txt` — залежності.
- `.env.example` — приклад змінних середовища.

Безпека

- Зберігайте `CYBER_API_KEY` у змінних середовища або секретному сховищі — ніколи не пуште ключі в репо.
- У продакшні обмежте CORS та додайте HTTPS.
