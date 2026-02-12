from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
import fast_api.persona.endpointsPersona as endpointsPersona
import fast_api.album.endpointsAlbum as endpointsAlbum
import fast_api.recurso.endpointsRecursos as endpointsRecursos
import fast_api.recurso.endpointsEnlaces as endpointsEnlaces
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from contextlib import asynccontextmanager
import fast_api.recurso.consultasRecursos as consultasRecursos

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = AsyncIOScheduler()
    scheduler.add_job(consultasRecursos.purgar_papelera_automatica, 'interval', hours=24)
    scheduler.start()
    yield
    scheduler.shutdown()

app = FastAPI(
    title="MoiselinCloud API",
    description="API para gestión de archivos y álbumes tipo nube privada",
    version="1.0.0",
    lifespan=lifespan
)
if not os.path.exists(STATIC_DIR):
    os.makedirs(STATIC_DIR)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
origins = ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(endpointsPersona.router)
app.include_router(endpointsAlbum.router)
app.include_router(endpointsRecursos.router)
app.include_router(endpointsEnlaces.router)
@app.get("/")
def home():
    return {"mensaje": "Bienvenido a la API de MoiselinCloud. Todo funciona correctamente."}
if __name__ == "__main__":
    uvicorn.run("fast_api.main:app", host="0.0.0.0", port=8000, reload=True, ssl_keyfile="key.pem", ssl_certfile="cert.pem")