from pydantic import BaseModel, EmailStr
from datetime import date

class PersonaRegistro(BaseModel):
    nombre: str
    apellidos: str
    nickname: str           
    correo: EmailStr
    contra: str
    fecha_nacimiento: date  

class Login(BaseModel):
    correo: EmailStr
    contra: str

class AmigoRequest(BaseModel):
    id_persona_objetivo: int 

class RespuestaAmistad(BaseModel): # <--- Faltaba esta clase completa
    id_otro_usuario: int
    accion: str

class CambioCuota(BaseModel):
    id_usuario: int
    nueva_cuota_bytes: int