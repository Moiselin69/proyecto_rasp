from fast_api import db
from mysql.connector import Error
import shutil 

# ==========================================
#  GESTIÓN DE USUARIOS (REGISTRO Y LOGIN)
# ==========================================

def crear_persona(nombre, apellidos, nickname, correo, contrasena_hash, fecha_nacimiento):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        
        # Validación: Verificar duplicados
        check_query = "SELECT COUNT(*) FROM Persona WHERE correo_electronico = %s OR nickname = %s"
        cursor.execute(check_query, (correo, nickname))
        if cursor.fetchone()[0] > 0:
            return (False, "El correo o el nickname ya están en uso.")

        # Insertar
        query = """
            INSERT INTO Persona (nombre, apellidos, nickname, correo_electronico, contrasena, fecha_nacimiento, rol) 
            VALUES (%s, %s, %s, %s, %s, %s, 'USUARIO')
        """
        # Nota: Asumo rol 'USUARIO' por defecto. Ajusta si tu BD tiene otro default.
        valores = (nombre, apellidos, nickname, correo, contrasena_hash, fecha_nacimiento)
        cursor.execute(query, valores)
        connection.commit()
        return (True, cursor.lastrowid)

    except Error as e:
        return (False, str(e))
    finally:
        if connection: cursor.close(); connection.close()

def verificar_credenciales(correo):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        # Recuperamos contrasena para validarla fuera y rol para el token
        query = "SELECT id, nombre, nickname, contrasena, rol FROM Persona WHERE correo_electronico = %s"
        cursor.execute(query, (correo,))
        usuario = cursor.fetchone()
        
        if not usuario: return (False, "Usuario no encontrado")
        return (True, usuario)
            
    except Error as e:
        return (False, str(e))
    finally:
        if connection: cursor.close(); connection.close()

# ==========================================
#  GESTIÓN DE AMISTADES
# ==========================================

def buscar_personas_filtro(texto_busqueda: str, id_usuario_solicitante: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        query = """
            SELECT id, nickname, nombre, apellidos, correo_electronico
            FROM Persona 
            WHERE (nickname LIKE %s OR correo_electronico LIKE %s OR nombre LIKE %s) 
            AND id != %s
            LIMIT 20
        """
        param = f"%{texto_busqueda}%"
        cursor.execute(query, (param, param, param, id_usuario_solicitante))
        return (True, cursor.fetchall())
    except Error as e:
        return (False, str(e))
    finally:
        if connection: cursor.close(); connection.close()

def enviar_solicitud_amistad(id_emisor, id_receptor):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        
        if id_emisor == id_receptor: return (False, "No puedes enviarte solicitud a ti mismo")

        # Verificar existencia previa
        check = "SELECT estado FROM Amistad WHERE (id_persona1=%s AND id_persona2=%s) OR (id_persona1=%s AND id_persona2=%s)"
        cursor.execute(check, (id_emisor, id_receptor, id_receptor, id_emisor))
        res = cursor.fetchone()
        
        if res:
            if res[0] == 'ACEPTADA': return (False, "Ya sois amigos")
            if res[0] == 'PENDIENTE': return (False, "Ya hay una solicitud pendiente")

        query = "INSERT INTO Amistad (id_persona1, id_persona2, estado) VALUES (%s, %s, 'PENDIENTE')"
        cursor.execute(query, (id_emisor, id_receptor))
        connection.commit()
        return (True, "Solicitud enviada")
    except Error as e:
        return (False, str(e))
    finally:
        if connection: cursor.close(); connection.close()

def obtener_amistades(id_persona):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        
        # Amigos ACEPTADOS
        query_amigos = """
            SELECT P.id, P.nickname, P.nombre, P.apellidos, 'AMIGO' as estado
            FROM Persona P
            JOIN Amistad A ON (P.id = A.id_persona1 OR P.id = A.id_persona2)
            WHERE (A.id_persona1 = %s OR A.id_persona2 = %s)
            AND A.estado = 'ACEPTADA'
            AND P.id != %s
        """
        # Solicitudes RECIBIDAS (pendientes de aceptar)
        query_solicitudes = """
            SELECT P.id, P.nickname, P.nombre, P.apellidos, 'SOLICITUD_RECIBIDA' as estado
            FROM Persona P
            JOIN Amistad A ON P.id = A.id_persona1
            WHERE A.id_persona2 = %s AND A.estado = 'PENDIENTE'
        """
        cursor.execute(query_amigos, (id_persona, id_persona, id_persona))
        amigos = cursor.fetchall()
        cursor.execute(query_solicitudes, (id_persona,))
        solicitudes = cursor.fetchall()
        
        return (True, amigos + solicitudes)
    except Error as e:
        return (False, str(e))
    finally:
        if connection: cursor.close(); connection.close()

def responder_amistad(id_usuario_accion, id_otro_usuario, accion):
    # accion: 'ACEPTAR', 'RECHAZAR', 'ELIMINAR'
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()

        if accion == 'ACEPTAR':
            # Solo acepta si yo soy el receptor (persona2)
            query = "UPDATE Amistad SET estado='ACEPTADA' WHERE id_persona1=%s AND id_persona2=%s AND estado='PENDIENTE'"
            cursor.execute(query, (id_otro_usuario, id_usuario_accion))
        elif accion == 'RECHAZAR':
            query = "DELETE FROM Amistad WHERE id_persona1=%s AND id_persona2=%s AND estado='PENDIENTE'"
            cursor.execute(query, (id_otro_usuario, id_usuario_accion))
        elif accion == 'ELIMINAR':
            query = "DELETE FROM Amistad WHERE ((id_persona1=%s AND id_persona2=%s) OR (id_persona1=%s AND id_persona2=%s)) AND estado='ACEPTADA'"
            cursor.execute(query, (id_usuario_accion, id_otro_usuario, id_otro_usuario, id_usuario_accion))
        else:
            return (False, "Acción desconocida")

        if cursor.rowcount == 0:
            return (False, "No se encontró la solicitud o amistad para procesar")
            
        connection.commit()
        return (True, "Acción realizada correctamente")
    except Error as e:
        return (False, str(e))
    finally:
        if connection: cursor.close(); connection.close()

# ==========================================
#  ADMINISTRACIÓN (CUOTAS Y USUARIOS)
# ==========================================

def obtener_info_admin(id_usuario):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT rol FROM Persona WHERE id = %s", (id_usuario,))
        row = cursor.fetchone()
        return row and row['rol'] == 'ADMINISTRADOR'
    except: return False
    finally: 
        if connection: connection.close()

def listar_usuarios_con_uso():
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        # Calcula espacio usado por usuario sumando sus recursos
        query = """
            SELECT 
                P.id, P.nombre, P.apellidos, P.correo_electronico, P.rol, 
                P.almacenamiento_maximo,
                COALESCE(SUM(R.tamano), 0) as espacio_usado
            FROM Persona P
            LEFT JOIN Recurso R ON P.id = R.id_creador AND R.fecha_eliminacion IS NULL
            GROUP BY P.id
        """
        cursor.execute(query)
        usuarios = cursor.fetchall()
        
        # Espacio físico del servidor
        total, used, free = shutil.disk_usage("static/uploads") # Asegúrate que esta ruta existe
        respuesta = {
            "usuarios": usuarios,
            "disco": { "total": total, "usado": used, "libre": free }
        }
        return (True, respuesta)
    except Exception as e:
        return (False, str(e))
    finally:
        if connection: connection.close()

def actualizar_cuota(id_usuario: int, nueva_cuota: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()

        # 1. Verificar uso actual del usuario
        query_uso = "SELECT COALESCE(SUM(tamano), 0) FROM Recurso WHERE id_creador = %s AND fecha_eliminacion IS NULL"
        cursor.execute(query_uso, (id_usuario,))
        res = cursor.fetchone()
        uso_actual = res[0] if res else 0

        if nueva_cuota is not None and nueva_cuota < uso_actual:
            return (False, f"No puedes reducir la cuota por debajo de lo usado ({uso_actual/1024**3:.2f} GB).")

        # 2. Verificar espacio físico global
        total_disco, _, _ = shutil.disk_usage("static/uploads")
        
        query_otros = "SELECT SUM(almacenamiento_maximo) FROM Persona WHERE id != %s AND almacenamiento_maximo IS NOT NULL"
        cursor.execute(query_otros, (id_usuario,))
        res_otros = cursor.fetchone()
        suma_otros = res_otros[0] if res_otros and res_otros[0] else 0
        
        if (suma_otros + nueva_cuota) > total_disco:
             return (False, "Error: La suma de cuotas superaría el tamaño físico del disco.")

        # 3. Actualizar
        query_upd = "UPDATE Persona SET almacenamiento_maximo = %s WHERE id = %s"
        cursor.execute(query_upd, (nueva_cuota, id_usuario))
        connection.commit()
        
        return (True, "Cuota actualizada")
    except Exception as e:
        return (False, str(e))
    finally:
        if connection: connection.close()

def obtener_uso_almacenamiento_usuario(id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)

        # 1. Obtener la Cuota Máxima del usuario
        cursor.execute("SELECT almacenamiento_maximo FROM Persona WHERE id = %s", (id_persona,))
        usuario = cursor.fetchone()
        
        if not usuario:
            return (False, "Usuario no encontrado")
        
        maximo = usuario['almacenamiento_maximo'] # Puede ser None (ilimitado) o un número en bytes

        # 2. Calcular el espacio usado (Suma de archivos activos)
        # COALESCE asegura que si no tiene archivos devuelva 0 en vez de None
        query_uso = """
            SELECT COALESCE(SUM(tamano), 0) as usado 
            FROM Recurso 
            WHERE id_creador = %s AND fecha_eliminacion IS NULL
        """
        cursor.execute(query_uso, (id_persona,))
        resultado_uso = cursor.fetchone()
        usado = float(resultado_uso['usado']) # Convertimos a float/int asegurado

        return (True, {
            "maximo": maximo, 
            "usado": usado
        })

    except Exception as e:
        return (False, str(e))
    finally:
        if connection: connection.close()