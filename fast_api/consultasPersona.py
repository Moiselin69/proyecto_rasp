import db
from mysql.connector import Error

def guardar_persona(nombre, apellidos, correo, contra_hash):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query = "INSERT INTO Persona (nombre, apellidos, correo_electronico, contra_hash) VALUES (%s, %s, %s, %s);"
            valores = (nombre, apellidos, correo, contra_hash)
            cursor.execute(query, valores)
            connection.commit()
            return (True, cursor.lastrowid)
    except Error as e:
        print(f"Error en guardar persona: {e}")
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def obtener_persona(correo):
    connection = None
    cursor = None
    try:
        connection = db.get_connection() # Asumiendo que ya hiciste el cambio del Apartado D (db.py)
        if connection and connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            query = "SELECT id, nombre, apellidos, correo_electronico, contra_hash FROM Persona WHERE correo_electronico=%s"
            cursor.execute(query, (correo, ))
            return (True, cursor.fetchone())
    except Error as e:
        print(f"Error en obtener persona: {e}")
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def peticion_amistad(id_persona: int, id_persona_solicitada: int):
    # id_persona: Quién envía la solicitud
    # id_persona_solicitada: Quién la recibe
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query = "INSERT INTO Peticion_Amistad(id_persona, id_persona_solicitada) VALUES (%s,%s)"
            valores = (id_persona, id_persona_solicitada)
            cursor.execute(query, valores)
            connection.commit()
            return (True, "Petición enviada")
    except Error as e:
        print(f"Error en pedir amistad: {e}")
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def aceptar_amistad(id_persona_que_acepta: int, id_persona_que_envio: int):
    # Nota: id_persona_que_acepta es quien recibió la solicitud originalmente
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            
            # 1. Borrar la petición (donde el solicitante es el que envió, y el solicitado soy yo)
            query_1 = "DELETE FROM Peticion_Amistad WHERE id_persona=%s AND id_persona_solicitada=%s"
            valores_1 = (id_persona_que_envio, id_persona_que_acepta)
            cursor.execute(query_1, valores_1)
            
            # CORRECCIÓN: rowcount sin paréntesis
            if cursor.rowcount == 0:
                connection.rollback()
                return (False, "La petición de amistad no existe.")
            
            # 2. Insertar en tabla de amigos
            # CORRECCIÓN: Usar nombres de columnas correctos (id_persona_1, id_persona_2)
            query_2 = "INSERT INTO Persona_Amiga(id_persona_1, id_persona_2) VALUES (%s,%s)"
            valores_2 = (id_persona_que_acepta, id_persona_que_envio)
            cursor.execute(query_2, valores_2)
            
            connection.commit()
            return (True, "Amistad aceptada")
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en aceptar amistad: {e}")
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def ver_amigos(id_persona: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            
            # CORRECCIÓN MAYOR DE LÓGICA:
            # 1. Buscamos en Persona_Amiga donde yo sea el 1 O el 2.
            # 2. Hacemos JOIN con Persona para obtener LOS DATOS de mi amigo.
            # 3. Filtramos para no obtener mis propios datos (P.id != id_persona).
            query = """
                SELECT P.id, P.nombre, P.apellidos, P.correo_electronico
                FROM Persona_Amiga PA
                JOIN Persona P ON (P.id = PA.id_persona_1 OR P.id = PA.id_persona_2)
                WHERE (PA.id_persona_1 = %s OR PA.id_persona_2 = %s)
                AND P.id != %s
            """
            valores = (id_persona, id_persona, id_persona)
            cursor.execute(query, valores)
            return (True, cursor.fetchall())
    except Error as e:
        print(f"Error en ver amigos: {e}")
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def ver_peticiones_pendientes(id_persona: int):
    # Muestra quién quiere ser mi amigo
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            query = """
                SELECT P.id, P.nombre, P.apellidos, P.correo_electronico, PA.id_persona as id_solicitante
                FROM Peticion_Amistad PA
                JOIN Persona P ON PA.id_persona = P.id
                WHERE PA.id_persona_solicitada = %s
            """
            cursor.execute(query, (id_persona,))
            return (True, cursor.fetchall())
    except Error as e:
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection: connection.close()

def rechazar_amistad(id_persona_que_rechaza: int, id_persona_que_envio: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            # Simplemente borramos la petición
            query = "DELETE FROM Peticion_Amistad WHERE id_persona=%s AND id_persona_solicitada=%s"
            # id_persona es quien envió (el otro), solicitada soy yo (que rechazo)
            cursor.execute(query, (id_persona_que_envio, id_persona_que_rechaza))
            connection.commit()
            if cursor.rowcount == 0:
                return (False, "No había petición pendiente")
            return (True, "Solicitud rechazada")
    except Error as e:
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection: connection.close()

def eliminar_amigo(id_persona: int, id_ex_amigo: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            # Como no sabemos si está guardado como (Yo, Él) o (Él, Yo), chequeamos ambas combinaciones
            query = """
                DELETE FROM Persona_Amiga 
                WHERE (id_persona_1=%s AND id_persona_2=%s) 
                   OR (id_persona_1=%s AND id_persona_2=%s)
            """
            valores = (id_persona, id_ex_amigo, id_ex_amigo, id_persona)
            cursor.execute(query, valores)
            connection.commit()
            if cursor.rowcount == 0:
                return (False, "No eran amigos")
            return (True, "Amigo eliminado")
    except Error as e:
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection: connection.close()

def buscar_personas(termino_busqueda: str):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            # Buscamos por nombre, apellido o correo usando LIKE
            query = """
                SELECT id, nombre, apellidos, correo_electronico 
                FROM Persona 
                WHERE nombre LIKE %s OR apellidos LIKE %s OR correo_electronico LIKE %s
                LIMIT 20
            """
            busqueda = f"%{termino_busqueda}%" # Añadimos comodines para SQL
            valores = (busqueda, busqueda, busqueda)
            cursor.execute(query, valores)
            return (True, cursor.fetchall())
    except Error as e:
        return (False, str(e))
    finally: 
        if cursor: cursor.close()
        if connection: connection.close()