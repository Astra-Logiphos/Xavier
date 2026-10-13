FROM python:3.12-slim
ENV HOST=0.0.0.0 PORT=8080 DATABASE_PATH=/app/runtime/xinghui.db PYTHONDONTWRITEBYTECODE=1
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server server
COPY data/sample/persona_eval_cases.json data/sample/persona_eval_cases.json
RUN useradd --uid 10001 --create-home app && mkdir runtime && chown app:app runtime
USER app
EXPOSE 8080
CMD ["python", "-m", "server.api.app"]
