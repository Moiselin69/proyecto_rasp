import shutil
import os
import uuid
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends, Body
from fastapi.responses import FileResponse
from PIL import Image
import consultasRecursos
import funcionesSeguridad
import modeloDatos
import cv2
router = APIRouter()

#~Endpoint para subir recursos
@router.post("/recurso/subir")
async def subir_archivo(
    tipo: str = Form(...), 
    fecha: Optional[datetime] = Form(None), 
    file: UploadFile = File(...), 
    id_album: Optional[str] = Form(None), # Recibimos como str para limpiar
    reemplazar: bool = Form(False),
    current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)
):
    # 1. Limpieza de id_album
    id_album_int = None
    if id_album and id_album.strip() != "" and id_album.lower() != "null":
        try:
            id_album_int = int(id_album)
        except ValueError:
            id_album_int = None
    # 2. Verificar existencia ANTES de guardar
    id_existente = consultasRecursos.check_recurso_existe_en_album(current_user_id, file.filename, id_album_int)

    if id_existente and not reemplazar:
         raise HTTPException(status_code=409, detail="El archivo ya existe")

    # 3. Guardar archivo físico (temporalmente si es reemplazo)
    carpeta_original = "static/uploads"
    carpeta_miniatura = "static/thumbnails" 
    os.makedirs(carpeta_original, exist_ok=True)
    os.makedirs(carpeta_miniatura, exist_ok=True)
    
    nombre_original, extension = os.path.splitext(file.filename)
    nombre_archivo_fisico = f"{uuid.uuid4()}{extension}"
    ruta_completa_original = os.path.join(carpeta_original, nombre_archivo_fisico)
    
    with open(ruta_completa_original, "wb") as buffer: 
        shutil.copyfileobj(file.file, buffer)
        
    try:
        # Generar Miniatura
        if tipo == "IMAGEN":
            ruta_completa_miniatura = os.path.join(carpeta_miniatura, nombre_archivo_fisico)
            with Image.open(ruta_completa_original) as img:
                img.thumbnail((300, 300))
                if img.mode in ("RGBA", "P"): img = img.convert("RGB")
                img.save(ruta_completa_miniatura)
        elif tipo == "VIDEO":
            nombre_thumb = os.path.splitext(nombre_archivo_fisico)[0] + ".jpg" 
            ruta_completa_miniatura = os.path.join(carpeta_miniatura, nombre_thumb)
            cam = cv2.VideoCapture(ruta_completa_original) 
            try:
                cam.set(cv2.CAP_PROP_POS_FRAMES, 10)  
                ret, frame = cam.read()
                if not ret:
                    cam.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ret, frame = cam.read()
                if ret:
                    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) 
                    with Image.fromarray(frame_rgb) as img:
                        img.thumbnail((300, 300))
                        img.save(ruta_completa_miniatura, format="JPEG")
            finally:
                cam.release()
    except Exception as e:
        print(f"Error creando miniatura: {e}")    
    
    enlace_db = ruta_completa_original

    # 4. LÓGICA DE BD
    if id_existente and reemplazar:
        # CASO A: REEMPLAZO SIMPLE (Sin historial)
        print("DEBUG: Reemplazando archivo existente...")
        exito, resultado = consultasRecursos.reemplazar_recurso_simple(
            id_recurso=id_existente,
            nuevo_enlace=enlace_db,
            nuevo_tipo=tipo,
            nueva_fecha_real=fecha,
            id_usuario=current_user_id
        )
        
        if not exito:
            if os.path.exists(ruta_completa_original): os.remove(ruta_completa_original)
            raise HTTPException(status_code=500, detail=f"Error al reemplazar: {resultado}")
            
        # Borrar archivo viejo físico para ahorrar espacio
        ruta_vieja = resultado
        if ruta_vieja and ruta_vieja != enlace_db:
            try:
                if os.path.exists(ruta_vieja): os.remove(ruta_vieja)
                # Borrar miniatura vieja
                ruta_thumb_vieja = ruta_vieja.replace("uploads", "thumbnails")
                if os.path.exists(ruta_thumb_vieja): os.remove(ruta_thumb_vieja)
                else:
                    nombre_sin_ext = os.path.splitext(ruta_thumb_vieja)[0]
                    if os.path.exists(nombre_sin_ext + ".jpg"): os.remove(nombre_sin_ext + ".jpg")
            except Exception as e:
                print(f"No se pudo borrar físico viejo: {e}")

        return {"mensaje": "Archivo reemplazado correctamente", "id_recurso": id_existente}

    else:
        # CASO B: NUEVO
        print("DEBUG: Subiendo nuevo archivo...")
        exito, id_recurso = consultasRecursos.subir_recurso(current_user_id, tipo, enlace_db, file.filename, fecha, id_album_int)
        
        if not exito:
            if os.path.exists(ruta_completa_original): os.remove(ruta_completa_original)
            raise HTTPException(status_code=500, detail=str(id_recurso))
            
        return {"mensaje": "Archivo subido correctamente", "id_recurso": id_recurso}

#~Endpoint para comprobar que una carpeta no hay dos recursos que se llamen exactamente igual
@router.get("/recurso/verificar-duplicado")
def verificar_duplicado(nombre: str, id_album: Optional[int] = None, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    id_existente = consultasRecursos.check_recurso_existe_en_album(current_user_id, nombre, id_album)
    return {"existe": id_existente is not None}

#~Endpoint para que el usuario vea sus propios recursos
@router.get("/recurso/mis_recursos")
def mis_recursos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasRecursos.obtener_recursos(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(recursos))
    return recursos

#~Endpoint para borrar un recurso de manera definitiva en la cloud
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

#~Endpoint para compartir recursos
@router.post("/recurso/compartir")
def compartir_recurso(datos: modeloDatos.CompartirRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, mensaje = consultasRecursos.compartir_recurso_bd(datos.id_recurso, current_user_id, datos.id_amigo_receptor)
    if not exito:
        raise HTTPException(status_code=400, detail=mensaje)
    return {"mensaje": mensaje}

#~Endpoint para visualizar o descargar un archivo
@router.get("/recurso/archivo/{id_recurso}")
def ver_archivo_recurso(id_recurso: int, size:str = "full",current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.obtener_recurso_por_id(id_recurso, current_user_id)
    if not exito or not res:
        raise HTTPException(status_code=404, detail="Recurso no encontrado o acceso denegado")
    ruta_original = res['enlace']
    if size == "small" and (res['tipo'] == "IMAGEN" or res['tipo'] == "VIDEO"):
        ruta_miniatura = ruta_original.replace("uploads", "thumbnails")
        if os.path.exists(ruta_miniatura):
            return FileResponse(ruta_miniatura)
        nombre_sin_ext = os.path.splitext(ruta_miniatura)[0]
        ruta_thumb_jpg = nombre_sin_ext + ".jpg"
        if os.path.exists(ruta_thumb_jpg):
            return FileResponse(ruta_thumb_jpg)
        return FileResponse(ruta_original)
    if not os.path.exists(ruta_original):
        raise HTTPException(status_code=404, detail="El archivo físico se ha perdido")
    return FileResponse(ruta_original)

#~Endpoint para ver los recursos compartidos conmigo
@router.get("/recurso/compartidos-conmigo")
def ver_compartidos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.obtener_compartidos_conmigo(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return resultado

#~Endpoint para ver quién te quiere compartir archivos
@router.get("/recurso/peticiones-recepcion")
def ver_peticiones_recepcion(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.obtener_peticiones_recurso_pendientes(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return resultado

#~Endpoint para responder a una petiicon de compartir recurso
@router.post("/recurso/peticiones-recepcion/responder")
def responder_solicitud_recurso(datos: modeloDatos.RespuestaPeticionRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, mensaje = consultasRecursos.responder_peticion_recurso(datos.id_emisor, current_user_id, datos.id_recurso, datos.aceptar)
    if not exito:
        raise HTTPException(status_code=400, detail=mensaje)
    return {"mensaje": mensaje}

#~Endpoint para editar el nombre de un recursos
@router.put("/recurso/editar/nombre/{id_recurso}")
def editar_nombre_recurso(
    id_recurso: int, 
    datos: modeloDatos.SolicitudNombre, 
    current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)
):
    exito, res = consultasRecursos.renombrar_recurso_seguro(
        id_recurso, 
        datos.nombre, 
        current_user_id, 
        datos.reemplazar
    )
    
    if not exito:
        if res == "DUPLICADO":
            raise HTTPException(status_code=409, detail="El nombre ya existe")
        raise HTTPException(status_code=400, detail=str(res))
        
    return {"mensaje": "Nombre actualizado"}

@router.put("/recurso/editar/fecha/{id_recurso}")
def editar_fecha_recurso(id_recurso: int, datos: modeloDatos.SolicitudFecha, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.cambiar_fecha_recurso(id_recurso, datos.fecha, current_user_id) 
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Fecha actualizada"}

#~Endpoint para editar fecha
@router.put("/recurso/editar/fecha/{id_recurso}")
def editar_fecha_recurso(id_recurso: int, datos: modeloDatos.SolicitudFecha, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.cambiar_fecha_recurso(id_recurso, datos.fecha, current_user_id) 
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Fecha actualizada"}

#~Endpoint que sirve para mover un archivo a la papelera
@router.delete("/recurso/borrar/{id_recurso}")
def borrar_recurso_papelera(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.mover_a_papelera(id_recurso, current_user_id)
    if not exito:
        if resultado == "No se encontró el recurso o no eres el creador":
             raise HTTPException(status_code=404, detail=resultado)
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Recurso movido a la papelera"}

#~Endpoint que sirve para listar todos recursos que hay en la papelera
@router.get("/recurso/papelera")
def ver_papelera(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasRecursos.obtener_papelera_bd(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(recursos))
    return recursos

#~Endpoint que sirve para restaurar un recurso que está en la papelera
@router.put("/recurso/restaurar/{id_recurso}")
def restaurar_recurso(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    """Recupera un recurso de la papelera."""
    exito, mensaje = consultasRecursos.restaurar_recurso_bd(id_recurso, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=mensaje)
    return {"mensaje": "Recurso restaurado correctamente"}