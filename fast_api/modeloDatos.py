from pydantic import BaseModel

class PersonaRegistro(BaseModel):
    nombre: str
    apellidos: str
    correo: str
    contra: str

class Login(BaseModel):
    correo: str
    contra: str

class PeticionAmistad(BaseModel):
    id_persona: int
    id_persona_solicitada: int

class AlbumCrear(BaseModel):
    nombre: str
    descripcion: str
    id_persona: int # Creador

class AlbumInvitacion(BaseModel):
    id_persona: int # Quien invita
    id_persona_compartida: int # A quien invitan
    id_album: int
    rol: str

class RecursoCompartir(BaseModel):
    id_persona: int
    id_persona_compartida: int
    id_recurso: int