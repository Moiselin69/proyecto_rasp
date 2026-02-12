import os
import uuid
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends, Body
import fast_api.recurso.consultasRecursos as consultasRecursos
import fast_api.seguridad.funcionesSeguridad as funcionesSeguridad
from fast_api.recurso import modeloDatosRecurso
import fast_api.utilidades.utilidadesFicheros as utilidadesFicheros
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATIC_DIR = os.path.join(BASE_DIR, "static")
UPLOADS_DIR = os.path.join(STATIC_DIR, "uploads")
THUMBNAILS_DIR = os.path.join(STATIC_DIR, "thumbnails")
router = APIRouter()

#-----------------------------------------------------------------------------------------------------
#                               ENDPOINTS PARA OBTENER DATOS
#--------------------------------------------------------------------------------------------------

#~Endpoint 1. Usuario ve sus propios recursos
@router.get("/recurso/mis_recursos")
def mis_recursos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasRecursos.obtener_recursos(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(recursos))
    return recursos

#~Endpoint 2. Usuario obtiene metadatos de un recurso
@router.get("/recurso/metadatos/{id_recurso}")
def get_metadatos(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # Primero verificamos que el usuario tenga permiso de ver el recurso
    permiso, _ = consultasRecursos.obtener_recurso_por_id(id_recurso, current_user_id)
    if not permiso:
        raise HTTPException(status_code=403, detail="No tienes acceso")
    meta = consultasRecursos.obtener_metadatos(id_recurso)
    if not meta:
        return {} # Devuelve vacío si no tiene EXIF
    return meta

#--------------------------------------------------------------------------------------------------------------------
#                               ENDPOINTS PARA COMPARTIR RECURSOS
#------------------------------------------------------------------------------------------------------

#~Endpoint 3. Usuario comparte recursos
@router.post("/recurso/compartir")
def compartir_recurso(datos: modeloDatosRecurso.CompartirRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, mensaje = consultasRecursos.compartir_recurso_bd(datos.id_recurso, current_user_id, datos.id_amigo_receptor)
    if not exito:
        raise HTTPException(status_code=400, detail=mensaje)
    return {"mensaje": mensaje}

#~Endpoint 4. Usuario ve los recursos compartidos con él
@router.get("/recurso/compartidos-conmigo")
def ver_compartidos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.obtener_compartidos_conmigo(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return resultado

#~Endpoint 5. Usuario ve las peticiones que tiene pendientes
@router.get("/recurso/peticiones-recepcion")
def ver_peticiones_recepcion(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.obtener_peticiones_recurso_pendientes(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return resultado

#~Endpoint 6. Usuario respondee a una petiicon de compartir recurso
@router.post("/recurso/peticiones-recepcion/responder")
def responder_solicitud_recurso(datos: modeloDatosRecurso.RespuestaPeticionRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, mensaje = consultasRecursos.responder_peticion_recurso(datos.id_emisor, current_user_id, datos.id_recurso, datos.aceptar)
    if not exito:
        raise HTTPException(status_code=400, detail=mensaje)
    return {"mensaje": mensaje}

#-----------------------------------------------------------------------------------------------------
#                               ENDPOINTS PARA EDITAR META DATOS
#------------------------------------------------------------------------------------------------------

#~Endpoint 7. Usuario edita el nombre de un recursos
@router.put("/recurso/editar/nombre/{id_recurso}")
def editar_nombre_recurso(id_recurso: int, datos: modeloDatosRecurso.SolicitudNombre, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.renombrar_recurso_seguro(id_recurso, datos.nombre, current_user_id, datos.reemplazar)
    if not exito:
        if res == "DUPLICADO":
            raise HTTPException(status_code=409, detail="El nombre ya existe")
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Nombre actualizado"}

#~Endpoint 8. Usuario editar fecha
@router.put("/recurso/editar/fecha/{id_recurso}")
def editar_fecha_recurso(id_recurso: int, datos: modeloDatosRecurso.SolicitudFecha, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.cambiar_fecha_recurso(id_recurso, datos.fecha, current_user_id) 
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Fecha actualizada"}

#~Endpoint 9. Usuario marca un recurso como favorito
@router.put("/recurso/favorito")
def cambiar_favorito(datos: modeloDatosRecurso.RecursoFavorito, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, msg = consultasRecursos.marcar_favorito_bd(datos.id_recurso, current_user_id, datos.es_favorito)
    if not exito:
        raise HTTPException(status_code=400, detail=msg)
    return {"mensaje": msg}

#------------------------------------------------------------------------------------------------------------------
#                               ENDPOINT PARA MOVER Y BORRAR RECURSOS
#------------------------------------------------------------------------------------------------------------

#~Endpoint 10. Usuario mueve un archivo a la papelera
@router.delete("/recurso/borrar/{id_recurso}")
def borrar_recurso_papelera(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.mover_a_papelera(id_recurso, current_user_id)
    if not exito:
        if resultado == "No se encontró el recurso o no eres el creador":
             raise HTTPException(status_code=404, detail=resultado)
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Recurso movido a la papelera"}

#~Endpoint 11. Usuario lista todos recursos que hay en la papelera
@router.get("/recurso/papelera")
def ver_papelera(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasRecursos.obtener_papelera_bd(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(recursos))
    return recursos

#~Endpoint 12. Usuario restaura un recurso que está en la papelera
@router.put("/recurso/restaurar/{id_recurso}")
def restaurar_recurso(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    """Recupera un recurso de la papelera."""
    exito, mensaje = consultasRecursos.restaurar_recurso_bd(id_recurso, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=mensaje)
    return {"mensaje": "Recurso restaurado correctamente"}

#~Endpoint 13. Usuario mueve varios archivos a la papelera
@router.put("/recurso/lote/papelera")
def lote_papelera(lote: modeloDatosRecurso.LoteRecursos, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, msg = consultasRecursos.mover_a_papelera_lote(lote.ids, current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=msg)
    return {"mensaje": msg}

#~Endpoint 14. Usuario mueve varios archivos a una carpeta
@router.put("/recurso/lote/mover")
def lote_mover(lote: modeloDatosRecurso.LoteMover,current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, msg = consultasRecursos.mover_recursos_lote(lote.ids, lote.id_album_destino, current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=msg)
    return {"mensaje": msg}

#---------------------------------------------------------------------------------------------------------
#                              Cargas y eliminaciones de recursos
#------------------------------------------------------------------------------------------------------------------

#Endpoint 15. Usuario empieza la carga por chunks de un recurso
@router.post("/upload/init")
def init_upload(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    """Paso 1: Solicitar un ID de subida"""
    upload_id = str(uuid.uuid4())
    utilidadesFicheros.iniciar_carga_chunk(upload_id)
    return {"upload_id": upload_id}

#~Endpoint 16. Usuario carga un nuevo chunk del recurso
@router.post("/upload/chunk")
async def upload_chunk(
    upload_id: str = Form(...),
    chunk_index: int = Form(...),
    file: UploadFile = File(...),
    current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)
):
    """Paso 2: Subir un trocito"""
    content = await file.read()
    utilidadesFicheros.guardar_chunk(upload_id, chunk_index, content)
    return {"mensaje": "Chunk recibido"}

#~Endpoint 17. Usuario ha completado la carga de un recurso
@router.post("/upload/complete")
def complete_upload(
    upload_id: str = Form(...),
    nombre_archivo: str = Form(...),
    total_chunks: int = Form(...),
    tipo: str = Form(...),
    id_album: Optional[str] = Form(None),
    reemplazar: bool = Form(False),
    fecha: Optional[datetime] = Form(None),
    current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)
):
    """Paso 3: Ensamblar y procesar"""
    try:
        # 1. Ensamblar
        ruta_final = utilidadesFicheros.ensamblar_archivo(upload_id, nombre_archivo, total_chunks)
        
        # Limpieza id_album
        id_album_int = None
        if id_album and id_album.strip() != "" and id_album.lower() != "null":
            try: id_album_int = int(id_album)
            except: pass

        # 2. Procesar (BD, Cuota, Miniaturas, Hash Check)
        exito, res = consultasRecursos.procesar_archivo_local(
            current_user_id, ruta_final, nombre_archivo, tipo, fecha, id_album_int, reemplazar
        )

        if not exito:
            # Si es duplicado, lanzamos 409
            if res == "DUPLICADO": 
                raise HTTPException(status_code=409, detail="El archivo ya existe")
            
            # Si falló por otra razón (ej: cuota), borramos el ensamblado
            if os.path.exists(ruta_final): os.remove(ruta_final)
            
            # Usamos 507 si es espacio, 500 si es otra cosa
            code = 507 if "cuota" in str(res).lower() or "espacio" in str(res).lower() else 500
            raise HTTPException(status_code=code, detail=str(res))

        return {"mensaje": "Subida completada exitosamente", "info": res}

    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error completando subida: {e}")
        raise HTTPException(status_code=500, detail=str(e))

#~Endpoint 18. Usuario borra un recurso de manera definitiva en la cloud
@router.delete("/recurso/eliminar-definitivo/{id_recurso}")
def eliminar_recurso_definitivo(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.eliminar_definitivamente_bd(id_recurso, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    if resultado and isinstance(resultado, str): 
        try:
            if os.path.exists(resultado):
                os.remove(resultado)
            ruta_thumbnail = resultado.replace("uploads", "thumbnails")
            if os.path.exists(ruta_thumbnail):
                os.remove(ruta_thumbnail)
            else:
                nombre_sin_ext = os.path.splitext(ruta_thumbnail)[0]
                ruta_thumb_jpg = nombre_sin_ext + ".jpg"
                if os.path.exists(ruta_thumb_jpg):
                    os.remove(ruta_thumb_jpg)   
        except Exception as e:
            print(f"Error borrando archivos físicos (BD ya limpia): {e}")
    return {"mensaje": "Recurso eliminado permanentemente"}




