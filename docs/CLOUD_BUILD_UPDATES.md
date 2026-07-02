# Обновление routing-engine через Cloud Build

**Проект:** `cybertranspay` · **сервис:** `routing-engine`  
**URL:** https://routing-engine-1079379369218.europe-west1.run.app

---

## Первоначальная настройка автодеплоя (один раз)

### Шаг 1 — IAM для Cloud Build

```cmd
scripts\grant-cloudbuild-permissions.cmd
```

### Шаг 2 — Подключить GitHub к Cloud Build

1. Открой: https://console.cloud.google.com/cloud-build/triggers/connect?project=cybertranspay  
2. Выбери **GitHub** → авторизуйся  
3. Репозиторий: **`tyom2001-cell/cybertranspay`**

### Шаг 3 — Создать trigger

```cmd
scripts\setup-cloudbuild-trigger.cmd
```

Готово. Каждый **push в `main`** автоматически: build → push образа → update Cloud Run.

Проверить trigger:

```cmd
gcloud builds triggers list --region=europe-west1 --project=cybertranspay
```

---

## Быстрое обновление вручную (Windows)

После изменений в `backend/`:

```cmd
cd C:\Users\tyom2001\Desktop\cybertranspay-deploy
scripts\update-routing-engine.cmd
```

Или вручную:

```cmd
git pull origin main
gcloud builds submit --config=cloudbuild.yaml --project=cybertranspay
```

---

## Что делает `cloudbuild.yaml`

| Шаг | Действие |
|-----|----------|
| `docker-build` | Rust → Docker-образ |
| `docker-push` | Push в `europe-west1-docker.pkg.dev/cybertranspay/cybertranspay/routing-engine` |
| `update-cloud-run` | `gcloud run services update routing-engine --image=...:latest` |

> **Не использует** `--allow-unauthenticated` (org policy блокирует `allUsers`).

---

## Проверка после обновления

**Proxy** (окно 1 — не закрывать):

```cmd
gcloud run services proxy routing-engine --region=europe-west1 --project=cybertranspay --port=8081
```

> На Windows порт **8080** часто занят — используй **8081**.

**Проверка** (окно 2):

```cmd
curl http://127.0.0.1:8081/health
```

**Статус последней сборки:**

```cmd
gcloud builds list --region=europe-west1 --project=cybertranspay --limit=5
```

---

## Только build + push (без auto-deploy)

Если шаг `update-cloud-run` падает — используйте build-only и деплой вручную:

```cmd
gcloud builds submit --config=cloudbuild.build-only.yaml --project=cybertranspay
```

```cmd
gcloud run deploy routing-engine --image=europe-west1-docker.pkg.dev/cybertranspay/cybertranspay/routing-engine:latest --region=europe-west1 --project=cybertranspay --port=8080 --memory=512Mi
```

---

## Автозапуск при push (альтернатива скрипту)

Если `setup-cloudbuild-trigger.cmd` не сработал — создай trigger вручную в Console:  
https://console.cloud.google.com/cloud-build/triggers?project=cybertranspay

- Branch: `^main$`
- Config file: `cloudbuild.yaml`

Или CLI (после подключения GitHub):

```cmd
gcloud builds triggers create github --name=routing-engine-main --repo-name=cybertranspay --repo-owner=tyom2001-cell --branch-pattern=^main$ --build-config=cloudbuild.yaml --region=europe-west1 --project=cybertranspay
```

---

## IAM (один раз)

```cmd
scripts\grant-cloudbuild-permissions.cmd
```

Дополнительно для deploy из Cloud Build:

```cmd
gcloud iam service-accounts add-iam-policy-binding 1079379369218-compute@developer.gserviceaccount.com --member=serviceAccount:1079379369218-compute@developer.gserviceaccount.com --role=roles/iam.serviceAccountUser --project=cybertranspay
```

---

## Доступ к API

| Способ | Команда |
|--------|---------|
| Локально (dev) | `gcloud run services proxy` → `http://127.0.0.1:8080` |
| С токеном | `gcloud auth print-identity-token` + `Authorization: Bearer` |
| Публичный URL | Заблокирован org policy (`allUsers`) |

Flutter dev:
```cmd
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080
```
