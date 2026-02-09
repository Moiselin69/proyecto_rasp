from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
import endpointsPersona
import endpointsAlbum
import endpointsRecursos
import endpointsEnlaces
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from contextlib import asynccontextmanager
import consultasRecursos
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
if not os.path.exists("static"):
    os.makedirs("static")

app.mount("/static", StaticFiles(directory="static"), name="static")
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
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, ssl_keyfile="key.pem", ssl_certfile="cert.pem")