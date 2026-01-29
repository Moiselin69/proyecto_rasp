from pydantic import BaseModel

class PersonaRegistro(BaseModel):
    nombre: str
    apellidos: str
    correo: str
    contra: str

class Login(BaseModel):
    correo: str
    contra: str

class AmigoRequest(BaseModel):
    id_persona_objetivo: int 

class AlbumCrear(BaseModel):
    nombre: str
    descripcion: str

class AlbumInvitacion(BaseModel):
    id_persona_invitada: int 
    id_album: int
    rol: str

class RecursoCompartir(BaseModel):
    id_persona_destino: int
    id_recurso: int

class AlbumRecurso(BaseModel):
    id_album: int
    id_recurso: int

class RespuestaInvitacionAlbum(BaseModel):
    id_album: int
    id_persona_invitadora: int

class RespuestaPeticionRecurso(BaseModel):
    id_recurso: int
    id_persona_emisora: int