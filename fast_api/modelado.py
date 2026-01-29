from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import List, Optional, Literal
TipoDato = Literal['IMAGEN', 'VIDEO', 'MUSICA', 'ARCHIVO']
RolAlbum = Literal['CREADOR', 'ADMINISTRADOR', 'COLABORADOR']
#-----------------------------------------------------------------------------------------------------#
#        Modelos para las posibles interacciones al regsitrar e iniciar sesion de un usuario          #
#-----------------------------------------------------------------------------------------------------#

# -------------------- Modelos para el inicio de sesion de una persona
class PersonaIniciarSesion(BaseModel):
    correo_electronico: EmailStr
    contra: str
class RespuestaIniciarSesion(BaseModel):
    id_persona: int # id de la persona que se acaba de iniciar sesion
    nombre: str # nombre de la persona que acaba de iniciar sesion
    apellidos: str # apellidos de la persona que acaba de iniciar sesion
    token_acceso: Optional[str] = None
    error: Optional[str] = None # si ha surgido un error el motivo estará aquí guardado
# -------------------- FIN

# --------------------- Modelos para registrar a una persona
class PersonaRegistrar(BaseModel):
    nombre: str # es el nombre real del usuario
    apellidos: str # son los apellidos reales del usuario
    contra: str # es la contraseña sin cifrar
    correo_electronico: EmailStr # es el correo electronico de la persona que se va a registrar
class RespuestaRegistrar(BaseModel):
    id_persona: Optional[int] = None
    error: Optional[int] = None # si ha surgido un error el motivo estará aquí guardado
# --------------------- FIN


#-----------------------------------------------------------------------------------------------------#
#          Modelos para las posibles interacciones con los datos guardados de una persona             #
#-----------------------------------------------------------------------------------------------------#

# --------------------- Modelos para que una persona suba datos (imagenes, archivos, videos, musica)
class PersonaSubeDatos(BaseModel):
    id_persona: int # el id de la persona que sube la imagen
    contra: str # la contraseña en plano de esta persona
    nombre: str # nombre de la imagen
    tipo: TipoDato # necesario para saber que tipo de dato va a subir
class RespuestaSubeDatos(BaseModel):
    error: Optional[int] # si ha surgido un error el motivo estará aquí guardado
# ---------------------- FIN

#----------------------- Modelos para que una persona pueda obtener sus datos
class PersonaObtieneDatos(BaseModel):
    id_persona: int # el id de la persona que solicita los datos
    contra: str # es la contraseña en plano del usuario
class Dato(BaseModel):
    id_dato: int # id del dato que quiere obtener
    id_persona: int # es el id de la persona que es posedora de este dato
    fecha_subida: datetime # es la fecha de subida del dato
    fecha_real: datetime # es la fecha real del dato (el usuario la puede actualizar)
    nombre: str #nombre del dato
class RespuestaObtieneDatos(BaseModel):
    total: int # total de datos
    datos: List[Dato] # es la lista de los datos totales que se han pedido
    error: str # si ha surgido un error se pondrá aquí
# ----------------------- FIN

# ------------------------ Modelo para cambiar el nombre de un dato
class PersonaCambiaNombreDato(BaseModel):
    id_dato: int # el id del dato que se quiere cambiar el nombre
    id_persona: int # el id de la persona que quiere cambiar el dato
    contra: str # la contra en plano del usuario para verficiar que es el
    nombre_nuevo: str # el nuevo nombre 
class RespuestaCambiaNombreDato(BaseModel):
    error: str # si ha surgido un error se pondrá aquí dicho error
#-------------------------- FIN

# ------------------------- Modelo para cambiar la fecha real de un dato
class PersonaCambiaFechaRealDato(BaseModel):
    id_dato: int # el id del dato que se quiere cambiar el nombre
    id_persona: int # el id de la persona que quiere cambiar el dato
    contra: str # la contra en plano del usuario para verficiar que es el
    fecha_real_nuevo: datetime # la nueva fecha real de la imagen
class RespuestaCambiaFechaRealDato(BaseModel):
    error: str # si ha surgido
# ------------------------- FIN

class PersonaComparteDato(BaseModel):
    datos: List[Dato] # los ids de los datos que se quieren compartir
    id_persona: int # el id de la persona que quiere compartir el dato
    contra: str # el id de la persona que va a compartir la contraseña
    id_persona_compartida: int # el id de la persona a la que se quiere compartir el dato
class RespuestaComparteDAto(BaseModel):
    error: str # si ha surgido un error será guardado aquí

# -------------------------- Modelo para borrar uno o varios datos
class PersonaBorraDato(BaseModel):
    id_dato: List[int] # una lista de los ids de los datos
    id_persona: int # el id de la persona que quiere cambiar el dato
    contra: str # la contra en plano del usuario para verficiar que es el
class RespuestaBorraDato(BaseModel):
    error: str # si ha surgido un error se pondrá aquí
# ------------------------- FIN


#-----------------------------------------------------------------------------------------------------#
#     Modelos para las posibles interacciones con los datos y albumes compartidos de una persona      #
#-----------------------------------------------------------------------------------------------------#

# ----------------------- Modelo para la creación de un album compartido (lo puede ser o no)
class PersonaCreaAlbum(BaseModel):
    id_persona: int # el id de la persona que crea el album
    contra: str # la contra en plano de la persona que crea el album
    datos: List[Dato] # los posibles datos que una persona ha podido meter al iniciar un album
class RespuestaPersonaCreaAlbum(BaseModel):
    error: str # si ha surgido un error se pondrá aquí
# ----------------------- FIN

# ------------------------ Modelo para que una persona pueda añadir datos a un album
class PersonaAddDatosAlbum(BaseModel):
    id_persona: int # el id de la persona que añade el dato al album
    contra: str # la contra en plano de la persona que añade el dato
    datos: List[Dato] # los posibles datos que una persona ha podido meter al album
class RespuestaAddDatosAlbum(BaseModel):
    error: str # si ha surgido un error se pondrá aquí
# ------------------------- FIN

# ------------------------- Modelo para que una persona pueda editar borrar datos a un album
class PersonaBorraDatosAlbum(BaseModel):
    id_persona: int # el id de la persona que quiere borrar esos datos del album
    contra: str # la contra en plano de la persona que quiere borrar 
    datos: List[Dato] # los posibles datos que una persona quiere sacar del album
class RespuestaBorrarDatosAlbum(BaseModel):
    error: str # si ha surgido un error al borrar los datos se pondrá aquí
# -------------------------- FIN

# ------------------------- Modelo para que una persona pueda compartir un album
class PersonaComparteAlbumPersona(BaseModel):
    id_persona: int # el id de la persona que quiere compartir un album
    contra: str # la contraseña en plano de la persona que quiere compartir el album
    id_persona_compartida: int # el id de la persona que quiere compartir el album
    rol: str # el rol que va a tener esa persona sobre el album
class RespuestaComparteAlbumPersona(BaseModel):
    error: str # si ha surgido un error borrar aquí está explicado porqué
# ------------------------- FIN

# -------------------------- Modelo para que una persona pueda aceptar o rechazar estar en un album
class PersonaAceptaAlbum(BaseModel):
    id_persona: int # el id de la persona que quiere aceptar estar en el album
    contra: str # contraseña de la persona que quiere estar en el album
    acepta: bool # si es true significa que ha aceptado, si es false significa que ha rechazado
class RespuestaPersonaRechazaAlbum(BaseModel):
    error: str # si ha surgido un error aquí estará contemplado
# --------------------------- FIN