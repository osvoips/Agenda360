FROM python:3.12-slim

WORKDIR /srv

COPY . .
RUN pip install --no-cache-dir ".[dev]"

EXPOSE 8000

ENTRYPOINT ["./docker-entrypoint.sh"]
