from pydantic import BaseModel, EmailStr

class PersonaRegistro(BaseModel):
    nombre: str
    apellidos: str
    correo: EmailStr
    contra: str

class Login(BaseModel):
    correo: EmailStr
    contra: str

class AmigoRequest(BaseModel):
    id_persona_objetivo: int 