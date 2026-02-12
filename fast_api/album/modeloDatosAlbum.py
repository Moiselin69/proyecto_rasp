from pydantic import BaseModel

class AlbumCrear(BaseModel): # utilizado en el endpoint 1 de Album
    nombre: str
    descripcion: str
    id_album_padre: int | None = None

class AlbumInvitacion(BaseModel): # utilizado en el endpoint 4 de Album
    id_persona_invitada: int 
    id_album: int
    rol: str

class AlbumRecurso(BaseModel): # utilizado en el endpoint 5 de Album
    id_album: int
    id_recurso: int

class RespuestaInvitacionAlbum(BaseModel): # utilizado en el endpoint 9 y 10 de Album
    id_album: int
    id_persona_invitadora: int # es el id del usuario que realizó la invitación

class AlbumMover(BaseModel): # utilizado en el endpoint 11 de Album
    id_album: int
    id_nuevo_padre: int | None = None

class MoverRecursoAlbum(BaseModel): # utilizado en el endpoint 12 de Album
    id_recurso: int
    id_album_origen: int
    id_album_destino: int

class CambioRolAlbum(BaseModel): # utilizado en el endpoint 15 de Album
    id_album: int
    id_persona_objetivo: int  
    nuevo_rol: str

     