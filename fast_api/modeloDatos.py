from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import List, Optional

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

class AlbumCrear(BaseModel):
    nombre: str
    descripcion: str
    id_album_padre: int | None = None

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

class SolicitudNombre(BaseModel):
    nombre: str
    reemplazar: bool = False

class SolicitudFecha(BaseModel):
    fecha: datetime

class AlbumMover(BaseModel):
    id_album: int
    id_nuevo_padre: int | None = None

class CompartirRecurso(BaseModel):
    id_recurso: int
    id_amigo_receptor: int

class RespuestaPeticionRecurso(BaseModel):
    id_emisor: int
    id_recurso: int
    aceptar: bool

class CambioCuota(BaseModel):
    id_usuario: int
    nueva_cuota_bytes: int | None = None

class LoteRecursos(BaseModel):
    ids: List[int] # Lista de IDs [1, 5, 20, 44]

class LoteMover(BaseModel):
    ids: List[int]
    id_album_destino: Optional[int] # Puede ser None si va a la raíz