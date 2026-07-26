from fastapi import FastAPI

from app.api.admin_routes import router as admin_router
from app.api.auth_routes import router as auth_router
from app.api.barbershop_routes import hours_router
from app.api.barbershop_routes import router as barbershop_router
from app.api.client_routes import router as client_router

app = FastAPI(title="Agenda360 API", version="0.1.0")

app.include_router(client_router)
app.include_router(auth_router)
app.include_router(barbershop_router)
app.include_router(hours_router)
app.include_router(admin_router)


@app.get("/health", tags=["infra"])
async def health() -> dict:
    return {"status": "ok"}
