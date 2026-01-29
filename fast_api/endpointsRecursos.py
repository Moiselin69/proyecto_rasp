import shutil
import os
import uuid
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Depends
from fastapi.responses import FileResponse
import consultasRecursos
import funcionesSeguridad
import modeloDatos
router = APIRouter()

#~Endpoint para subir recursos
@router.post("/recurso/subir")
async def subir_archivo(tipo: str = Form(...), fecha: Optional[datetime] = Form(None), file: UploadFile = File(...), current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    carpeta_destino = "static/uploads"# 1. Guardar archivo físico
    os.makedirs(carpeta_destino, exist_ok=True)
    nombre_original, extension = os.path.splitext(file.filename)
    nombre_archivo = f"{uuid.uuid4()}{extension}"
    ruta_completa = os.path.join(carpeta_destino, nombre_archivo)
    with open(ruta_completa, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    enlace_db = ruta_completa # 2. Guardar en BD (El dueño es el del token)
    exito, id_recurso = consultasRecursos.subir_recurso(current_user_id, tipo, enlace_db, file.filename, fecha)
    if not exito:
        os.remove(ruta_completa)
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
            if os.path.exists(resultado):
                os.remove(resultado)
                print(f"Archivo físico eliminado: {resultado}")
        except Exception as e:
            print(f"Error borrando archivo físico: {e}")
    return {"mensaje": "Recurso eliminado"}

#~Endpoint para compartir recursos
@router.post("/recurso/compartir")
def compartir_recurso_endpoint(datos: modeloDatos.RecursoCompartir, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.pedir_compartir_recurso(current_user_id, datos.id_persona_destino, datos.id_recurso)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint para visualizar o descargar un archivo
@router.get("/recurso/archivo/{id_recurso}")
def ver_archivo_recurso(id_recurso: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.obtener_recurso_por_id(id_recurso, current_user_id)
    if not exito or not res:
        raise HTTPException(status_code=404, detail="Recurso no encontrado o acceso denegado")
    ruta_archivo = res['enlace']
    if not os.path.exists(ruta_archivo):
        raise HTTPException(status_code=404, detail="El archivo físico se ha perdido")
    return FileResponse(ruta_archivo)

#~Endpoint para ver quién te quiere compartir archivos
@router.get("/recurso/peticiones")
def ver_peticiones_recursos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # Usamos la función que YA EXISTÍA en tu archivo consultasRecursos.py
    exito, res = consultasRecursos.ver_peticiones_recurso_pendientes(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return res

#~Endpoint para aceptar un archivo compartido
@router.post("/recurso/peticion/aceptar")
def aceptar_recurso_compartido(datos: modeloDatos.RespuestaPeticionRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # id_persona_emisora: quien envió la solicitud (el dueño original)
    # current_user_id: quien la acepta (tú)
    exito, res = consultasRecursos.aceptar_compartir_recurso(datos.id_persona_emisora, current_user_id, datos.id_recurso)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": "Recurso aceptado. Ahora aparecerá en 'Mis Recursos'", "id_recurso": res}

#~Endpoint para rechazar un archivo compartido
@router.post("/recurso/peticion/rechazar")
def rechazar_recurso_compartido(datos: modeloDatos.RespuestaPeticionRecurso, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasRecursos.rechazar_peticion_recurso(datos.id_persona_emisora, current_user_id, datos.id_recurso)
    if not exito:
        raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

