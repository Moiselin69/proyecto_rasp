import shutil
import os
from datetime import datetime
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from passlib.context import CryptContext
from modelado import PersonaRegistrar
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
app = FastAPI()

def hashear_contra (contra: str) -> str:
    return pwd_context.hash(contra)
def verificar_contra (contra_cifrada: str) -> str:
    return pwd_context.verify(contra_cifrada)

@app.post("/registrar")
async def registrar_persona(datos: PersonaRegistrar):
    nombre = datos.nombre
    apellidos = datos.apellidos
    contra = hashear_contra(datos.contra)
    correo_electronico = datos.correo_electronico
