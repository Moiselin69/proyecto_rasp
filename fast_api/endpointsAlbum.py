from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, status, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
import consultasAlbum
import funcionesSeguridad
import modeloDatos
app = FastAPI(title="MoiselinCloud API")

#~Endpoint para crear un nuevo album
@app.post("/album/crear")
def crear_nuevo_album(album: modeloDatos.AlbumCrear, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, resultado = consultasAlbum.crear_album(album.nombre, album.descripcion, current_user_id)
    if not exito:
        raise HTTPException(status_code=400, detail=str(resultado))
    return {"mensaje": "Album creado", "id_album": resultado}

#~Endpoint para ver mis albunes
@app.get("/album/mis_albumes")
def obtener_mis_albumes(current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, albumes = consultasAlbum.obtener_albumes_usuario(current_user_id)
    if not exito: raise HTTPException(status_code=400, detail=str(albumes))
    return albumes

#-Endpoint para ver el contenido de un album
@app.get("/album/contenido/{id_album}")
def ver_contenido_album(id_album: int, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, recursos = consultasAlbum.obtener_recursos_album(id_album, current_user_id)
    if not exito: 
        raise HTTPException(status_code=403, detail=str(recursos))
    return recursos

#-Endpoint para invitar a una persona al album
@app.post("/album/invitar")
def invitar_a_album(invitacion: modeloDatos.AlbumInvitacion, current_user_id: int = Depends(funcionesSeguridad.get_current_user_id)):
    exito, res = consultasAlbum.peticion_album(current_user_id, invitacion.id_persona_invitada, invitacion.id_album, invitacion.rol)
    if not exito: raise HTTPException(status_code=400, detail=str(res))
    return {"mensaje": res}