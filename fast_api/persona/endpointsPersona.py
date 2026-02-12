from fastapi import APIRouter, HTTPException, Depends, Request
from passlib.context import CryptContext
import fast_api.persona.consultasPersona as consultasPersona
import fast_api.seguridad.consultasSeguridad as consultasSeguridad
import fast_api.seguridad.funcionesSeguridad as funcionesSeguridad
import fast_api.persona.modeloDatosPersona as modeloDatos

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ==========================================
#  DEPENDENCIA DE SEGURIDAD (SOLO ADMIN)
# ==========================================

#~Endpoint 1. Verifica si el usuario actual es administrador antes de dejarle pasar.
def requerir_admin(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    es_admin = consultasPersona.obtener_info_admin(current_user_id)
    if not es_admin:
        raise HTTPException(status_code=403, detail="Acceso denegado: Se requieren permisos de administrador")
    return current_user_id

# ==========================================
#  REGISTRO Y LOGIN
# ==========================================

#~Endpoint 2. Registro de usuario 
@router.post("/persona/registro")
def registrar_usuario(usuario: modeloDatos.PersonaRegistro):
    hashed_password = pwd_context.hash(usuario.contra)
    # Asumimos que modeloDatos.PersonaRegistro tiene: nombre, apellidos, nickname, correo, contra, fecha_nacimiento
    exito, res = consultasPersona.crear_persona(
        usuario.nombre, usuario.apellidos, usuario.nickname, 
        usuario.correo, hashed_password, usuario.fecha_nacimiento
    )
    if not exito: raise HTTPException(status_code=400, detail=res)
    return {"mensaje": "Usuario creado", "id": res}

#~Endpoint 3. Loggeo de Usuario
@router.post("/persona/login")
def login_usuario(datos: modeloDatos.Login, request: Request):
    client_ip = request.client.host
    bloqueado, msg = consultasSeguridad.verificar_ip_bloqueada(client_ip)
    if not bloqueado: raise HTTPException(status_code=429, detail=msg)
    exito, usuario_db = consultasPersona.verificar_credenciales(datos.correo)
    valido = False
    if exito and usuario_db:
        if pwd_context.verify(datos.contra, usuario_db['contrasena']):
            valido = True
    if not valido:
        consultasSeguridad.registrar_intento_fallido(client_ip)
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    consultasSeguridad.limpiar_intentos(client_ip)
    token = funcionesSeguridad.crear_token_acceso(
        data={
            "sub": str(usuario_db['id']), 
            "rol": usuario_db['rol'],
            "nombre": usuario_db['nombre']
        }
    )
    del usuario_db['contrasena']
    return {"access_token": token, "token_type": "bearer", "usuario": usuario_db}

# ==========================================
#  AMISTADES Y BÚSQUEDA
# ==========================================

#~Endpoint 4. Busqueda de personas
@router.get("/persona/buscar")
def buscar_personas(termino: str, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasPersona.buscar_personas_filtro(termino, current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return res

#~Endpoint 5. Devuelve tanto amigos como solicitudes pendientes en una sola llamada eficiente
@router.get("/persona/amistades")
def ver_amistades_y_solicitudes(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasPersona.obtener_amistades(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return res

#~Endpoint 6. Solicitud de amistad
@router.post("/persona/amistad/solicitar")
def solicitar_amistad(datos: modeloDatos.AmigoRequest, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasPersona.enviar_solicitud_amistad(current_user_id, datos.id_persona_objetivo)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

#~Endpoint 7. Respuesta a una solicitud de amistad
@router.post("/persona/amistad/responder")
def responder_amistad(datos: modeloDatos.RespuestaAmistad, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # datos.accion: 'ACEPTAR', 'RECHAZAR', 'ELIMINAR'
    exito, res = consultasPersona.responder_amistad(current_user_id, datos.id_otro_usuario, datos.accion)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}

# ==========================================
#  ADMINISTRACIÓN (PROTEGIDO)
# ==========================================

#~Endpoint 8. Sirve para que la aplicacion sepa si el usuario es admin
@router.get("/admin/soy-admin")
def verificar_soy_admin(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    return {"es_admin": consultasPersona.obtener_info_admin(current_user_id)}

#~Endpoint 9. Saber usuarios y el espacio consumido de cada uno
@router.get("/admin/usuarios")
def listar_usuarios_admin(admin_id: int = Depends(requerir_admin)):
    exito, datos = consultasPersona.listar_usuarios_con_uso()
    if not exito: raise HTTPException(status_code=400, detail=str(datos))
    return datos

#~Endpoint 10. Cambiar la cuota de un usuario
@router.put("/admin/cambiar-cuota")
def cambiar_cuota_usuario(datos: modeloDatos.CambioCuota, admin_id: int = Depends(requerir_admin)):
    exito, msg = consultasPersona.actualizar_cuota(datos.id_usuario, datos.nueva_cuota_bytes)
    if not exito: raise HTTPException(status_code=400, detail=msg)
    return {"mensaje": msg}

#~Endpoint 11. Sirve para que un usuario pueda ver el almacenamiento restante
@router.get("/persona/almacenamiento")
def ver_mi_almacenamiento(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, datos = consultasPersona.obtener_uso_almacenamiento_usuario(current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(datos))
    return datos