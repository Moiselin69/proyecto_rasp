import shutil
import os
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends
from pydantic import BaseModel
from passlib.context import CryptContext

# Importamos tus módulos de base de datos
# Asumiendo que están en la misma carpeta o el path es accesible
import consultasPersona
import consultasAlbum
import consultasRecursos

app = FastAPI(title="MoiselinCloud API")

# --- CONFIGURACIÓN DE SEGURIDAD ---
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

def hashear_contra(contra: str) -> str:
    return pwd_context.hash(contra)

def verificar_contra(contra_plana: str, contra_cifrada: str) -> bool:
    return pwd_context.verify(contra_plana, contra_cifrada)

# --- MODELOS DE DATOS (PYDANTIC) ---
# Estos definen qué JSON debe enviar la aplicación

class PersonaRegistro(BaseModel):
    nombre: str
    apellidos: str
    correo: str
    contra: str

class Login(BaseModel):
    correo: str
    contra: str

class PeticionAmistad(BaseModel):
    id_persona: int
    id_persona_solicitada: int

class AlbumCrear(BaseModel):
    nombre: str
    descripcion: str
    id_persona: int # Creador

class AlbumInvitacion(BaseModel):
    id_persona: int # Quien invita
    id_persona_compartida: int # A quien invitan
    id_album: int
    rol: str

class RecursoCompartir(BaseModel):
    id_persona: int
    id_persona_compartida: int
    id_recurso: int

# --- ENDPOINTS: PERSONA ---

@app.post("/persona/registro")
def registrar_usuario(usuario: PersonaRegistro):
    contra_hash = hashear_contra(usuario.contra)
    exito, resultado = consultasPersona.guardar_persona(
        usuario.nombre, usuario.apellidos, usuario.correo, contra_hash
    )
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Usuario creado", "id": resultado}

@app.post("/persona/login")
def login_usuario(datos: Login):
    exito, usuario = consultasPersona.obtener_persona(datos.correo)
    if not exito or not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    
    # Verificar contraseña
    if not verificar_contra(datos.contra, usuario['contra_hash']):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
    
    # En un sistema real, aquí devolverías un Token JWT
    return {"mensaje": "Login exitoso", "usuario": usuario}

@app.get("/persona/buscar")
def buscar_personas(termino: str):
    exito, resultados = consultasPersona.buscar_personas(termino)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultados))
    return resultados

# --- ENDPOINTS: AMIGOS ---

@app.post("/amigos/solicitar")
def solicitar_amistad(peticion: PeticionAmistad):
    exito, resultado = consultasPersona.peticion_amistad(
        peticion.id_persona, peticion.id_persona_solicitada
    )
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": resultado}

@app.get("/amigos/pendientes/{id_persona}")
def ver_solicitudes_pendientes(id_persona: int):
    exito, resultado = consultasPersona.ver_peticiones_pendientes(id_persona)
    if not exito: return []
    return resultado

@app.post("/amigos/aceptar")
def aceptar_amistad(peticion: PeticionAmistad):
    # Nota: id_persona es quien acepta (el destinatario original)
    # id_persona_solicitada es quien envió (el remitente original) en tu logica de API
    exito, resultado = consultasPersona.aceptar_amistad(
        peticion.id_persona, peticion.id_persona_solicitada
    )
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": resultado}

@app.get("/amigos/listar/{id_persona}")
def listar_amigos(id_persona: int):
    exito, amigos = consultasPersona.ver_amigos(id_persona)
    if not exito: raise HTTPException(status_code=400, detail=str(amigos))
    return amigos

# --- ENDPOINTS: ALBUMES ---

@app.post("/album/crear")
def crear_nuevo_album(album: AlbumCrear):
    exito, resultado = consultasAlbum.crear_album(
        album.nombre, album.descripcion, album.id_persona
    )
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Album creado", "id_album": resultado}

@app.get("/album/usuario/{id_persona}")
def obtener_mis_albumes(id_persona: int):
    exito, albumes = consultasAlbum.obtener_albumes_usuario(id_persona)
    if not exito: raise HTTPException(status_code=400, detail=str(albumes))
    return albumes

@app.get("/album/contenido/{id_album}")
def ver_contenido_album(id_album: int, id_persona: int): # id_persona para validar permisos
    exito, recursos = consultasAlbum.obtener_recursos_album(id_album, id_persona)
    if not exito: 
        raise HTTPException(status_code=403, detail=str(recursos)) # 403 Forbidden
    return recursos

@app.post("/album/invitar")
def invitar_a_album(invitacion: AlbumInvitacion):
    exito, res = consultasAlbum.peticion_album(
        invitacion.id_persona, invitacion.id_persona_compartida, 
        invitacion.id_album, invitacion.rol
    )
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

# --- ENDPOINTS: RECURSOS (SUBIDA DE ARCHIVOS) ---

@app.post("/recurso/subir")
async def subir_archivo(
    id_creador: int = Form(...),
    tipo: str = Form(...), # IMAGEN, VIDEO, etc.
    file: UploadFile = File(...)
):
    # 1. Guardar el archivo físicamente en el servidor
    carpeta_destino = "static/uploads"
    os.makedirs(carpeta_destino, exist_ok=True)
    
    # Generar nombre único para evitar sobreescritura (timestamp + nombre)
    nombre_archivo = f"{int(datetime.now().timestamp())}_{file.filename}"
    ruta_completa = os.path.join(carpeta_destino, nombre_archivo)
    
    with open(ruta_completa, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # 2. Guardar en Base de Datos
    fecha_actual = datetime.now()
    # Usamos ruta_completa o una URL relativa como enlace
    enlace_db = ruta_completa 
    
    exito, id_recurso = consultasRecursos.subir_recurso(
        id_creador, tipo, enlace_db, file.filename, fecha_actual
    )
    
    if not exito:
        # Si falla la BD, borramos el archivo subido para no dejar basura
        os.remove(ruta_completa)
        raise HTTPException(status_code=500, detail=str(id_recurso))
        
    return {"mensaje": "Archivo subido", "id_recurso": id_recurso}

@app.get("/recurso/usuario/{id_persona}")
def mis_recursos(id_persona: int):
    exito, recursos = consultasRecursos.obtener_recursos(id_persona)
    if not exito: raise HTTPException(status_code=400, detail=str(recursos))
    return recursos

@app.delete("/recurso/borrar")
def borrar_recurso(id_recurso: int, id_persona: int):
    # Llamamos a tu función que devuelve el enlace si es el último dueño
    exito, resultado = consultasRecursos.borrar_recurso(id_recurso, id_persona)
    
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    
    # Si resultado tiene contenido, significa que era el último dueño y hay que borrar fichero
    if resultado: 
        try:
            if os.path.exists(resultado):
                os.remove(resultado)
                print(f"Archivo físico {resultado} eliminado.")
        except Exception as e:
            print(f"Error borrando archivo físico: {e}")
            
    return {"mensaje": "Recurso eliminado"}

@app.post("/recurso/compartir")
def compartir_recurso_endpoint(datos: RecursoCompartir):
    exito, res = consultasRecursos.pedir_compartir_recurso(
        datos.id_persona, datos.id_persona_compartida, datos.id_recurso
    )
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

# Iniciar servidor (si ejecutas este script directamente)
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


