FROM node:20-bookworm-slim AS frontend-build

WORKDIR /app/frontend

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend/ ./
ENV VITE_API_BASE_URL=
RUN npm run build


FROM python:3.11-slim

# Copy uv from the official image for fast dependency installs.
COPY --from=ghcr.io/astral-sh/uv:0.9.26 /uv /uvx /bin/

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    FLASK_DEBUG=false \
    FLASK_HOST=0.0.0.0 \
    FLASK_PORT=5001

COPY backend/requirements.txt ./backend/requirements.txt
RUN uv pip install --system -r backend/requirements.txt

COPY backend/ ./backend/
COPY --from=frontend-build /app/frontend/dist ./frontend/dist

# Railway sets PORT dynamically, FLASK_PORT falls back to 5001 for local Docker
EXPOSE ${FLASK_PORT:-5001}

CMD ["python", "backend/run.py"]
