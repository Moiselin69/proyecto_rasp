from fastapi import APIRouter, HTTPException, Depends
import consultasAlbum
import funcionesSeguridad
import modeloDatos
router = APIRouter()

#~Endpoint para crear un nuevo album
@router.post("/album/crear")
def crear_nuevo_album(album: modeloDatos.AlbumCrear, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasAlbum.crear_album(album.nombre, album.descripcion, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Album creado", "id_album": resultado}

#~Endpoint para ver mis albunes
@router.get("/album/mis_albumes")
def obtener_mis_albumes(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, albumes = consultasAlbum.obtener_albumes_usuario(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(albumes))
    return albumes

#-Endpoint para ver el contenido de un album
@router.get("/album/contenido/{id_album}")
def ver_contenido_album(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasAlbum.obtener_recursos_album(id_album, current_user_id)
    if not exito: 
        raise HTTPException(status_code=403, detail=str(recursos))
    return recursos

#-Endpoint para invitar a una persona al album
@router.post("/album/invitar")
def invitar_a_album(invitacion: modeloDatos.AlbumInvitacion, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.peticion_album(current_user_id, invitacion.id_persona_invitada, invitacion.id_album, invitacion.rol)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint para añadir un recurso (foto/video) a un album
@router.post("/album/anadir-recurso")
def anadir_recurso_album(datos: modeloDatos.AlbumRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.add_recurso_album(datos.id_recurso, datos.id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Recurso añadido correctamente", "datos": res}

#~Endpoint para borrar un recurso de un album
@router.delete("/album/borrar-recurso/{id_album}/{id_recurso}")
def borrar_recurso_de_album(id_album: int, id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.borrar_recurso_album(id_recurso, id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Recurso eliminado del album"}

#~Endpoint para salir de un album
@router.post("/album/salir/{id_album}")
def salir_album(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.salir_de_album(id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}