from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional

class RecursoCompartir(BaseModel):
    id_persona_destino: int
    id_recurso: int

class RespuestaPeticionRecurso(BaseModel):
    id_recurso: int
    id_persona_emisora: int

class SolicitudNombre(BaseModel):
    nombre: str
    reemplazar: bool = False

class SolicitudFecha(BaseModel):
    fecha: datetime

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
    ids: List[int] 

class LoteMover(BaseModel):
    ids: List[int]
    id_album_destino: Optional[int] 

class CrearEnlace(BaseModel):
    ids_recursos: List[int] = []
    ids_albumes: List[int] = []
    password: Optional[str] = None
    dias_expiracion: Optional[int] = None

class RecursoFavorito(BaseModel):
    id_recurso: int
    es_favorito: bool