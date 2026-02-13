import os
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
from dotenv import load_dotenv
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials, OAuth2PasswordBearer
from passlib.context import CryptContext
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/persona/login")
load_dotenv()
security = HTTPBearer()
SECRET_KEY = os.getenv('SECRET_KEY') # es un conjunto de caracteres para generar los token
ALGORITHM = "HS256" # el algoritmo utilizada para generar los token
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 # El tiempo que va a durar el token vivo, que va a ser un día
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
def hashear_contra(password: str) -> str:
    return pwd_context.hash(password)

def verificar_contra(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

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
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])# Decodificamos el token
        user_id = payload.get("id")# Leemos el ID. Puede venir como "id" (nuestro código) o "sub" (estándar)
        if user_id is None:
            user_id = payload.get("sub")    
        if user_id is None:
            raise credentials_exception
        return int(user_id) # IMPORTANTE: Convertimos a int porque la base de datos espera un número
    except (JWTError, ValueError):
        raise credentials_exception # Si el token está mal formado, caducado o el ID no es un número