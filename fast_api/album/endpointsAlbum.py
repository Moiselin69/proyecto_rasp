from fastapi import APIRouter, HTTPException, Depends
import fast_api.album.consultasAlbum as consultasAlbum
import fast_api.seguridad.funcionesSeguridad as funcionesSeguridad
from fast_api.album import modeloDatosAlbum
import os
router = APIRouter()

#~Endpoint 1. Crear un nuevo album
@router.post("/album/crear")
def crear_nuevo_album(album: modeloDatosAlbum.AlbumCrear, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasAlbum.crear_album(album.nombre, album.descripcion, current_user_id, album.id_album_padre)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Album creado", "id_album": resultado}

#~Endpoint 2. Usuario ve sus albunes
@router.get("/album/mis_albumes")
def obtener_mis_albumes(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, albumes = consultasAlbum.obtener_albumes_usuario(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(albumes))
    return albumes

#-Endpoint 3. Usuario ve contenido de un album
@router.get("/album/contenido/{id_album}")
def ver_contenido_album(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasAlbum.obtener_recursos_album(id_album, current_user_id)
    if not exito: 
        raise HTTPException(status_code=403, detail=str(recursos))
    return recursos

#-Endpoint 4. Usuario invita a otro usuario a un album
@router.post("/album/invitar")
def invitar_a_album(invitacion: modeloDatosAlbum.AlbumInvitacion, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.peticion_album(current_user_id, invitacion.id_persona_invitada, invitacion.id_album, invitacion.rol)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 5. Usuario añade un recurso a un album
@router.post("/album/anadir-recurso")
def anadir_recurso_album(datos: modeloDatosAlbum.AlbumRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.add_recurso_album(datos.id_recurso, datos.id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Recurso añadido correctamente", "datos": res}

#~Endpoint 6. Usuario borra un recurso de un album
@router.delete("/album/borrar-recurso/{id_album}/{id_recurso}")
def borrar_recurso_de_album(id_album: int, id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.borrar_recurso_album(id_recurso, id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Recurso eliminado del album"}

#~Endpoint 7. Usuario sale de un album
@router.post("/album/salir/{id_album}")
def salir_album(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.salir_de_album(id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 8. Usuario ve sus invitaciones
@router.get("/album/invitaciones")
def ver_invitaciones_album(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.ver_peticiones_pendientes_album(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return res

#~Endpoint 9. Usuario acepta una invitacion
@router.post("/album/invitacion/aceptar")
def aceptar_invitacion_album(datos: modeloDatosAlbum.RespuestaInvitacionAlbum, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.aceptar_peticion_album(datos.id_persona_invitadora, current_user_id, datos.id_album)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 10. Usuario rechaza invitacion
@router.post("/album/invitacion/rechazar")
def rechazar_invitacion_album(datos: modeloDatosAlbum.RespuestaInvitacionAlbum, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.rechazar_peticion_album(datos.id_persona_invitadora, current_user_id, datos.id_album)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 11. Usuario mueve un album dentro de otro album.
@router.put("/album/mover")
def mover_album_endpoint(datos: modeloDatosAlbum.AlbumMover, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.mover_album(datos.id_album, datos.id_nuevo_padre, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 12. Usuario mueve un recurso de un album a otro
@router.put("/album/mover-recurso")
def mover_recurso_endpoint(datos: modeloDatosAlbum.MoverRecursoAlbum, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.mover_recurso_de_album(datos.id_recurso, datos.id_album_origen, datos.id_album_destino, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 13. Usuario borra un album
@router.delete("/album/borrar/{id_album}")
def borrar_album_endpoint(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasAlbum.eliminar_album_definitivamente(id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    conteo = 0
    if isinstance(resultado, list):
        for ruta in resultado:
            try:
                if os.path.exists(ruta): os.remove(ruta)
                # Borrar thumb
                ruta_thumb = ruta.replace("uploads", "thumbnails")
                if os.path.exists(ruta_thumb): os.remove(ruta_thumb)
                conteo += 1
            except Exception as e:
                print(f"Error borrando archivo físico: {e}")
    return {"mensaje": f"Álbum eliminado definitivamente. {conteo} archivos liberados."}

#~Endpoint 14. Usuario ve los miembros de un album
@router.get("/album/miembros/{id_album}")
def ver_miembros_endpoint(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.ver_miembros_album(id_album, current_user_id)
    if not exito:
        raise HTTPException(status_code=403, detail=str(res))
    return res

#~Endpoint 15. Usuario cambia rol a otro miembro de un album
@router.put("/album/miembros/rol")
def cambiar_rol_miembro(datos: modeloDatosAlbum.CambioRolAlbum, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # current_user_id es quien EJECUTA la acción (debe ser Admin o Creador)
    # datos.id_persona_objetivo es a quien se le CAMBIA el rol
    exito, res = consultasAlbum.hacer_rol_album(current_user_id, datos.id_persona_objetivo, datos.id_album, datos.nuevo_rol)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}