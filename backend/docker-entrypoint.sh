#!/bin/sh
# Roda as migrations antes de subir a API — necessário em produção (Railway
# não dá um passo de "release" separado sem plano pago) e também simplifica
# o docker-compose local (não precisa mais rodar `alembic upgrade head` à mão).
set -e

alembic upgrade head
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
