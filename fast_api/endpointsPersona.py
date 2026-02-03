from fastapi import APIRouter, HTTPException, Depends, Request
import consultasPersona
import consultasSeguridad
import funcionesSeguridad
import modeloDatos
router = APIRouter()

#~Endpoint para registrar una persona
@router.post("/persona/registro")
def registrar_usuario(usuario: modeloDatos.PersonaRegistro):
    contra_hash = funcionesSeguridad.hashear_contra(usuario.contra)
    exito, resultado = consultasPersona.guardar_persona(usuario.nombre, usuario.apellidos, usuario.correo, contra_hash)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Usuario creado", "id": resultado}

#~Endpoint para loggear a una persona 
@router.post("/persona/login")
def login_usuario(datos: modeloDatos.Login, request: Request):
    client_ip = request.client.host # obtenemos el io del cliente
    puede_pasar, mensaje_bloqueo = consultasSeguridad.verificar_ip_bloqueada(client_ip) # verificamos si la ip está bloqueada
    if not puede_pasar: # si está bloqueada lo detallamos en la respuesta
        raise HTTPException(status_code=429, detail=mensaje_bloqueo) # 429 Too Many Requests
    exito, usuario = consultasPersona.obtener_persona(datos.correo) # Aquí vericamos que la persona es quien dice ser
    credenciales_validas = False # siempre vamos a dar por echo de primera que las credenciales están mal
    if exito and usuario: # para así luego verificarlas y ver si están bien como aquí abajo
        if funcionesSeguridad.verificar_contra(datos.contra, usuario['contra_hash']):
            credenciales_validas = True
    if not credenciales_validas:
        consultasSeguridad.registrar_intento_fallido(client_ip) # Si hubo fallo en las credenciales lo registramos
        raise HTTPException(status_code=401, detail="Credenciales incorrectas") # por motivos de seguridad no se específica el qué fallo
    consultasSeguridad.limpiar_intentos(client_ip) # si el loggin consiguió ser exitoso borramos el historial de intentos
    access_token = funcionesSeguridad.crear_token_acceso( data={"id": str(usuario['id']), "correo_electronico": usuario['correo_electronico'], "nombre": usuario['nombre'], "apellidos": usuario['apellidos'], "fecha_creacion": str(usuario["fecha_creacion"])})
    return { "access_token": access_token, "token_type": "bearer"} # devolvemos el token para verificar al usuario cada vez que quiera hacer una accion

#~Endpoint para buscar personas en el sistema   
@router.get("/persona/buscar")
def buscar_personas(termino: str, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultados = consultasPersona.buscar_personas(termino)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultados))
    return resultados

#-Endpoint para solicitar amistad a una persona
@router.post("/amigos/solicitar")
def solicitar_amistad(datos: modeloDatos.AmigoRequest, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasPersona.peticion_amistad(current_user_id, datos.id_persona_objetivo)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": resultado}

#-Endpoint para ver peticiones pendientes de aceptar o de rechazar
@router.get("/amigos/pendientes")
def ver_solicitudes_pendientes(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasPersona.ver_peticiones_pendientes(current_user_id)
    if not exito: return []
    return resultado

#-Endpoint para aceptar peticiones de amistad
@router.post("/amigos/aceptar")
def aceptar_amistad(datos: modeloDatos.AmigoRequest, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasPersona.aceptar_amistad(current_user_id, datos.id_persona_objetivo)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": resultado}

#-Endpoint para listar los amigos de una persona
@router.get("/amigos/listar")
def listar_amigos(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, amigos = consultasPersona.ver_amigos(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(amigos))
    return amigos

#~Endpoint para rechazar una solicitud de amistad
@router.post("/amigos/rechazar")
def rechazar_solicitud_amistad(datos: modeloDatos.AmigoRequest, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    # id_persona_objetivo es la persona que te envió la solicitud (y que quieres rechazar)
    exito, resultado = consultasPersona.rechazar_amistad(current_user_id, datos.id_persona_objetivo)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": resultado}

#~Endpoint para eliminar a un amigo existente
@router.delete("/amigos/eliminar/{id_amigo}")
def eliminar_amigo(id_amigo: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasPersona.eliminar_amigo(current_user_id, id_amigo)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": resultado}