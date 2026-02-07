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
# ~Endpoint para subir recursos
@router.post("/recurso/subir")
async def subir_archivo(tipo: str = Form(...), fecha: Optional[datetime] = Form(None), file: UploadFile = File(...), id_album: Optional[int] = Form(None),current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    carpeta_original = "static/uploads"
    carpeta_miniatura = "static/thumbnails" 
    os.makedirs(carpeta_original, exist_ok=True)
    os.makedirs(carpeta_miniatura, exist_ok=True)
    nombre_original, extension = os.path.splitext(file.filename)
    nombre_archivo = f"{uuid.uuid4()}{extension}"
    ruta_completa_original = os.path.join(carpeta_original, nombre_archivo)
    with open(ruta_completa_original, "wb") as buffer: # 1. Guardar el archivo original
        shutil.copyfileobj(file.file, buffer)
    try:# 2. Generar Miniatura según el tipo
        if tipo == "IMAGEN":# Caso A: Es una IMAGEN
            ruta_completa_miniatura = os.path.join(carpeta_miniatura, nombre_archivo)
            with Image.open(ruta_completa_original) as img:
                img.thumbnail((300, 300))
                if img.mode in ("RGBA", "P"): 
                    img = img.convert("RGB")
                img.save(ruta_completa_miniatura)
        elif tipo == "VIDEO":# Caso B: Es un VIDEO (NUEVO)
            nombre_thumb = os.path.splitext(nombre_archivo)[0] + ".jpg" # El thumbnail de video.mp4 será video.jpg
            ruta_completa_miniatura = os.path.join(carpeta_miniatura, nombre_thumb)
            cam = cv2.VideoCapture(ruta_completa_original) # Usamos OpenCV para sacar un frame
            try:
                cam.set(cv2.CAP_PROP_POS_FRAMES, 10)  # Intentamos leer el frame 10 para evitar pantallas negras del inicio, o el 0 si falla
                ret, frame = cam.read()
                if not ret:
                    cam.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    ret, frame = cam.read()
                if ret:
                    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) # Convertimos de BGR (OpenCV) a RGB (PIL)
                    with Image.fromarray(frame_rgb) as img:
                        img.thumbnail((300, 300))
                        img.save(ruta_completa_miniatura, format="JPEG")
            finally:
                cam.release()
    except Exception as e:
        print(f"Error creando miniatura: {e}")    
    enlace_db = ruta_completa_original
    exito, id_recurso = consultasRecursos.subir_recurso(current_user_id, tipo, enlace_db, file.filename, fecha, id_album)
    if not exito:
        os.remove(ruta_completa_original)# Limpieza de miniatura si falló la BD
        posible_thumb_jpg = os.path.join(carpeta_miniatura, os.path.splitext(nombre_archivo)[0] + ".jpg")
        posible_thumb_orig = os.path.join(carpeta_miniatura, nombre_archivo)
        if os.path.exists(posible_thumb_jpg): os.remove(posible_thumb_jpg)
        if os.path.exists(posible_thumb_orig): os.remove(posible_thumb_orig)
        raise HTTPException(status_code=500, detail=str(id_recurso))
    return {"mensaje": "Archivo subido", "id_recurso": id_recurso}

#~Endpoint para que el usuario vea sus propios recursos
@router.get("/recurso/mis_recursos")
def mis_recursos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasRecursos.obtener_recursos(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(recursos))
    return recursos

#~Endpoint para que un usuario borre sus propios recursos
@router.delete("/recurso/borrar/{id_recurso}")
def borrar_recurso(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasRecursos.borrar_recurso(id_recurso, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    if resultado and isinstance(resultado, str): 
        try:
            if os.path.exists(resultado):# 1. Borrar archivo original (ej: static/uploads/foto.jpg)
                os.remove(resultado)
            ruta_thumbnail = resultado.replace("uploads", "thumbnails")# 2. Borrar Thumbnail (ej: static/thumbnails/foto.jpg)
            if os.path.exists(ruta_thumbnail):
                os.remove(ruta_thumbnail)
            else:
                nombre_sin_ext = os.path.splitext(ruta_thumbnail)[0]
                ruta_thumb_jpg = nombre_sin_ext + ".jpg"
                if os.path.exists(ruta_thumb_jpg):
                    os.remove(ruta_thumb_jpg)
        except Exception as e:
            print(f"Error borrando archivos físicos: {e}")
    return {"mensaje": "Recurso eliminado"}

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
def editar_nombre_recurso(id_recurso: int, datos: modeloDatos.SolicitudNombre, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.cambiar_nombre_recurso(id_recurso, datos.nombre, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Nombre actualizado"}

#~Endpoint para editar fecha
@router.put("/recurso/editar/fecha/{id_recurso}")
def editar_fecha_recurso(id_recurso: int, datos: modeloDatos.SolicitudFecha, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.cambiar_fecha_recurso(id_recurso, datos.fecha, current_user_id) 
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Fecha actualizada"}
