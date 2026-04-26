# scientist_ai

An AI that creates an experiment plan for a theory to be proved. This repository is a **monorepo** with two main parts: a **backend** service and a **Flutter frontend** that consumes it.

## Project parts

- **`backend/`** — A **Python [FastAPI](https://fastapi.tiangolo.com/)** service that runs literature review and experiment planning pipelines (OpenAI, Tavily, structured outputs, persistence). It exposes HTTP APIs (for example `POST /literature-review`, `POST /experiment-plan`, `GET /health`).

- **`frontend/`** — A **Flutter** app (**Marie Query**) that provides the product UI. It can call the real backend when configured with a base URL, or use a local mock for UI development.

Other folders (for example **`docs/`**) hold API notes and design references.

## How to run the project

Run the **backend** first, then the **frontend**. The app expects the API where you point it (the backend README uses port **8000** by default).

1. **Backend** — Open a terminal, follow install and run steps in [`backend/README.md`](backend/README.md) (Python venv, environment variables, `uvicorn` on `http://localhost:8000` or your chosen port).

2. **Frontend** — In another terminal, follow [`frontend/README.md`](frontend/README.md) (install Flutter, `flutter pub get`, `flutter run`, and use `--dart-define=SCIENTIST_API_BASE_URL=...` to connect to the running API).

**Detailed instructions**

| Part | Readme |
|------|--------|
| Backend (FastAPI) | [`backend/README.md`](backend/README.md) |
| Frontend (Flutter) | [`frontend/README.md`](frontend/README.md) |

## More in this repo

- **`docs/api_contract.md`** — API contract summary.
- **`FRONTEND_TODO.md`** — notes on aligning the Flutter app with the backend.
