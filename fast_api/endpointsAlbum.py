from fastapi import APIRouter, HTTPException, Depends
import consultasAlbum
import funcionesSeguridad
import modeloDatos
router = APIRouter()

#~Endpoint para crear un nuevo album
@router.post("/album/crear")
def crear_nuevo_album(album: modeloDatos.AlbumCrear, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasAlbum.crear_album(album.nombre, album.descripcion, current_user_id, album.id_album_padre)
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

#~Endpoint para ver invitaciones pendientes de album
@router.get("/album/invitaciones")
def ver_invitaciones_album(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.ver_peticiones_pendientes_album(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return res

#~Endpoint para aceptar invitacion
@router.post("/album/invitacion/aceptar")
def aceptar_invitacion_album(datos: modeloDatos.RespuestaInvitacionAlbum, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # Nota: id_persona_invitadora es quien mandó la solicitud
    # current_user_id es quien la acepta
    exito, res = consultasAlbum.aceptar_peticion_album(datos.id_persona_invitadora, current_user_id, datos.id_album)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint para rechazar invitacion
@router.post("/album/invitacion/rechazar")
def rechazar_invitacion_album(datos: modeloDatos.RespuestaInvitacionAlbum, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.rechazar_peticion_album(datos.id_persona_invitadora, current_user_id, datos.id_album)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint para mover un album a un album hijo
@router.put("/album/mover")
def mover_album_endpoint(datos: modeloDatos.AlbumMover, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.mover_album(datos.id_album, datos.id_nuevo_padre, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}