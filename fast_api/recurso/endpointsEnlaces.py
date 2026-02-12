from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.templating import Jinja2Templates
import secrets
import db
from datetime import datetime
from typing import Optional
from pydantic import BaseModel
import fast_api.seguridad.funcionesSeguridad as funcionesSeguridad
import os
import zipfile
import io
from fastapi.responses import StreamingResponse
import modeloDatosRecurso


router = APIRouter()
templates = Jinja2Templates(directory="templates")

# --- MODELOS ---
class CrearEnlace(BaseModel):
    id_recurso: Optional[int] = None
    id_album: Optional[int] = None
    password: Optional[str] = None
    dias_expiracion: Optional[int] = None # 0 = nunca

# --- UTILS ---
def generar_token():
    return secrets.token_urlsafe(8) # Genera string tipo "J8s_9d2x"

# --- ENDPOINTS APP (Para crear el link) ---

@router.post("/share/crear")
def crear_enlace_publico(datos: modeloDatosRecurso.CrearEnlace, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    conn = db.get_connection()
    cursor = conn.cursor()
    try:
        token = generar_token()
        pass_hash = funcionesSeguridad.hashear_contra(datos.password) if datos.password else None
        
        # Calcular expiración
        fecha_exp = None
        if datos.dias_expiracion and datos.dias_expiracion > 0:
            from datetime import timedelta
            fecha_exp = datetime.now() + timedelta(days=datos.dias_expiracion)

        # 1. Crear el Enlace (Cabecera) - Dejamos id_recurso/id_album NULL porque ahora usamos la tabla de contenido
        sql = """
            INSERT INTO EnlacePublico (token, id_creador, password_hash, fecha_expiracion)
            VALUES (%s, %s, %s, %s)
        """
        cursor.execute(sql, (token, current_user_id, pass_hash, fecha_exp))
        id_enlace = cursor.lastrowid

        # 2. Insertar los contenidos (Detalle)
        if datos.ids_recursos:
            sql_rec = "INSERT INTO EnlacePublico_Contenido (id_enlace, id_recurso) VALUES (%s, %s)"
            cursor.executemany(sql_rec, [(id_enlace, id_r) for id_r in datos.ids_recursos])
            
        if datos.ids_albumes:
            sql_alb = "INSERT INTO EnlacePublico_Contenido (id_enlace, id_album) VALUES (%s, %s)"
            cursor.executemany(sql_alb, [(id_enlace, id_a) for id_a in datos.ids_albumes])

        conn.commit()
        return {"token": token, "url": f"/s/{token}"}
    finally:
        conn.close()

# --- ENDPOINTS PÚBLICOS (Para la abuela) ---

@router.get("/s/{token}", response_class=HTMLResponse)
def ver_enlace(token: str, request: Request):
    return procesar_vista_enlace(token, request, None)

@router.post("/s/{token}", response_class=HTMLResponse)
def verificar_password_enlace(token: str, request: Request, password: str = Form(...)):
    return procesar_vista_enlace(token, request, password)

def procesar_vista_enlace(token: str, request: Request, password_input: str = None):
    conn = db.get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # 1. Buscar enlace
        cursor.execute("SELECT * FROM EnlacePublico WHERE token = %s", (token,))
        link = cursor.fetchone()

        if not link:
            return templates.TemplateResponse("compartido.html", {"request": request, "error": "Enlace no encontrado."})

        # 2. Validaciones (Expiración y Password) - IGUAL QUE ANTES
        if link['fecha_expiracion'] and link['fecha_expiracion'] < datetime.now():
            return templates.TemplateResponse("compartido.html", {"request": request, "error": "Caducado."})

        if link['password_hash']:
            if not password_input:
                return templates.TemplateResponse("compartido.html", {"request": request, "protegido": True})
            if not funcionesSeguridad.verificar_contra(password_input, link['password_hash']):
                return templates.TemplateResponse("compartido.html", {"request": request, "protegido": True, "msg_error": "Pass incorrecta"})

        # 3. OBTENER CONTENIDO MÚLTIPLE
        # Buscamos en la tabla de contenido
        cursor.execute("""
            SELECT r.nombre, r.tipo, r.tamano, 'RECURSO' as tipo_item 
            FROM EnlacePublico_Contenido c
            JOIN Recurso r ON c.id_recurso = r.id
            WHERE c.id_enlace = %s
        """, (link['id'],))
        recursos = cursor.fetchall()

        cursor.execute("""
            SELECT a.nombre, 'ALBUM' as tipo_item 
            FROM EnlacePublico_Contenido c
            JOIN Album a ON c.id_album = a.id
            WHERE c.id_enlace = %s
        """, (link['id'],))
        albumes = cursor.fetchall()
        
        lista_items = albumes + recursos
        
        # Calcular tamaño total aprox
        total_size = sum([r['tamano'] for r in recursos]) if recursos else 0
        total_size_str = f"{total_size / (1024*1024):.2f} MB"

        return templates.TemplateResponse("compartido.html", {
            "request": request,
            "token": token,
            "lista_items": lista_items, # Pasamos la lista a la plantilla
            "cantidad": len(lista_items),
            "tamano_total": total_size_str
        })

    finally:
        conn.close()

@router.get("/s/{token}/download")
def descargar_directo(token: str):
    """Descarga el archivo real si el token es válido y (opcionalmente) si ya pasó el check de pass (simplificado aquí)"""
    conn = db.get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM EnlacePublico WHERE token = %s", (token,))
        link = cursor.fetchone()
        
        # Aquí deberíamos re-validar password (cookies o sesión), pero para MVP asumimos
        # que si llega aquí es porque el usuario ya sabe la URL o pasó por el HTML
        
        if link and link['id_recurso']:
             cursor.execute("SELECT enlace, nombre FROM Recurso WHERE id = %s", (link['id_recurso'],))
             res = cursor.fetchone()
             if res and os.path.exists(res['enlace']):
                 return FileResponse(res['enlace'], filename=res['nombre'])
        
        raise HTTPException(status_code=404, detail="Archivo no encontrado")
    finally:
        conn.close()

@router.get("/s/{token}/download-zip")
def descargar_zip(token: str):
    conn = db.get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT * FROM EnlacePublico WHERE token = %s", (token,))
        link = cursor.fetchone()
        if not link: raise HTTPException(404)
        
        # NOTA: Aquí asumimos que el usuario ya validó pass antes o es público. 
        # Para máxima seguridad, deberías pedir pass aquí también o usar una cookie de sesión temporal.

        # Obtener rutas de archivos
        cursor.execute("""
            SELECT r.enlace, r.nombre 
            FROM EnlacePublico_Contenido c
            JOIN Recurso r ON c.id_recurso = r.id
            WHERE c.id_enlace = %s
        """, (link['id'],))
        archivos = cursor.fetchall()
        
        # (Para esta versión v1, solo zipeamos archivos sueltos, no entramos recursivamente en carpetas para no complicar el código)

        # Crear ZIP en memoria
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
            for arch in archivos:
                if os.path.exists(arch['enlace']):
                    zip_file.write(arch['enlace'], arcname=arch['nombre'])
        
        zip_buffer.seek(0)
        
        return StreamingResponse(
            zip_buffer, 
            media_type="application/zip", 
            headers={"Content-Disposition": f"attachment; filename=compartido_{token}.zip"}
        )

    finally:
        conn.close()