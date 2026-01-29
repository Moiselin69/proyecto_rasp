import shutil
import os
import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, Request
from passlib.context import CryptContext
from datetime import timedelta
from jose import jwt
import consultasPersona
import consultasAlbum
import consultasRecursos
import consultasSeguridad
from modeloDatos import PersonaRegistro, Login, PeticionAmistad, AlbumCrear, AlbumInvitacion, RecursoCompartir
app = FastAPI(title="MoiselinCloud API")

#~Funciones utilizadas para la seguridad
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
def hashear_contra(contra: str) -> str:
    return pwd_context.hash(contra)
def verificar_contra(contra_plana: str, contra_cifrada: str) -> bool:
    return pwd_context.verify(contra_plana, contra_cifrada)
SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
def crear_token_acceso(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- ENDPOINTS: PERSONA ---
#~Endpoint para registrar a una persona
@app.post("/persona/registro")
def registrar_usuario(usuario: PersonaRegistro):
    contra_hash = hashear_contra(usuario.contra)
    exito, resultado = consultasPersona.guardar_persona(
        usuario.nombre, usuario.apellidos, usuario.correo, contra_hash
    )
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Usuario creado", "id": resultado}

#~Endpoint para loggear a una persona 
@app.post("/persona/login")
def login_usuario(datos: Login, request: Request):
    client_ip = request.client.host # obtenemos el io del cliente
    puede_pasar, mensaje_bloqueo = consultasSeguridad.verificar_ip_bloqueada(client_ip) # verificamos si la ip está bloqueada
    if not puede_pasar: # si está bloqueada lo detallamos en la respuesta
        raise HTTPException(status_code=429, detail=mensaje_bloqueo) # 429 Too Many Requests
    exito, usuario = consultasPersona.obtener_persona(datos.correo) # Aquí vericamos que la persona es quien dice ser
    credenciales_validas = False # siempre vamos a dar por echo de primera que las credenciales están mal
    if exito and usuario: # para así luego verificarlas y ver si están bien como aquí abajo
        if verificar_contra(datos.contra, usuario['contra_hash']):
            credenciales_validas = True
    if not credenciales_validas:
        consultasSeguridad.registrar_intento_fallido(client_ip) # Si hubo fallo en las credenciales lo registramos
        raise HTTPException(status_code=401, detail="Credenciales incorrectas") # por motivos de seguridad no se específica el qué fallo
    consultasSeguridad.limpiar_intentos(client_ip) # si el loggin consiguió ser exitoso borramos el historial de intentos
    access_token = crear_token_acceso( data={"sub": str(usuario['id']), "correo": usuario['correo_electronico']})
    return { "access_token": access_token, "token_type": "bearer"} # devolvemos el token para verificar al usuario cada vez que quiera hacer una accion

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
    tipo: str = Form(...),
    file: UploadFile = File(...)
):
    # 1. Guardar el archivo físicamente en el servidor
    carpeta_destino = "static/uploads"
    os.makedirs(carpeta_destino, exist_ok=True)
    
    # Obtenemos la extensión del archivo original (ej: .jpg, .pdf)
    nombre_original, extension = os.path.splitext(file.filename)
    
    # Generamos un UUID y le pegamos la extensión
    nombre_archivo = f"{uuid.uuid4()}{extension}"
    # -------------------

    ruta_completa = os.path.join(carpeta_destino, nombre_archivo)
    
    with open(ruta_completa, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # 2. Guardar en Base de Datos
    fecha_actual = datetime.now()
    enlace_db = ruta_completa 
    
    # Nota: Guardamos 'file.filename' (nombre original) en la BD para mostrarlo bonito al usuario,
    # pero en el disco ('enlace_db') guardamos el UUID.
    exito, id_recurso = consultasRecursos.subir_recurso(
        id_creador, tipo, enlace_db, file.filename, fecha_actual
    )
    
    if not exito:
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


