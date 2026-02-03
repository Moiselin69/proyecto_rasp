import os
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta
from typing import Optional
from dotenv import load_dotenv
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials, OAuth2PasswordBearer
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/persona/login")

load_dotenv()
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")

security = HTTPBearer()

def hashear_contra(contra: str) -> str: # función utilizada para hashear la contraseña de un usuario
    return pwd_context.hash(contra)
def verificar_contra(contra_plana: str, contra_cifrada: str) -> bool: # funcion utilizada para verificar la contraseña de un usuario
    return pwd_context.verify(contra_plana, contra_cifrada)

SECRET_KEY = os.getenv('SECRET_KEY') # es un conjunto de caracteres para generar los token
ALGORITHM = "HS256" # el algoritmo utilizada para generar los token
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 # El tiempo que va a durar el token vivo, que va a ser un día

def crear_token_acceso(data: dict, expires_delta: Optional[timedelta] = None): # funcion que sirve para crear el token de acceso
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user_id(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudieron validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # Decodificamos el token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # Leemos el ID. Puede venir como "id" (nuestro código) o "sub" (estándar)
        user_id = payload.get("id")
        if user_id is None:
            user_id = payload.get("sub")
            
        if user_id is None:
            raise credentials_exception
        
        # IMPORTANTE: Convertimos a int porque la base de datos espera un número
        return int(user_id)
        
    except (JWTError, ValueError):
        # Si el token está mal formado, caducado o el ID no es un número
        raise credentials_exception