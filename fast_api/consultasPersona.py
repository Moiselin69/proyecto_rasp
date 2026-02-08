import db
from mysql.connector import Error
import shutil

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
        connection = db.get_connection()
        if connection and connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            query = "SELECT id, nombre, apellidos, correo_electronico, contra_hash, fecha_creacion FROM Persona WHERE correo_electronico=%s"
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

def obtener_info_admin(id_usuario):
    """Verifica si es admin."""
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
        total, used, free = shutil.disk_usage("static/uploads")
        respuesta = {
            "usuarios": usuarios,
            "disco": {
                "total": total,
                "usado": used,
                "libre": free
            }
        }
        return True, respuesta
    except Error as e:
        return False, str(e)
    finally:
        if connection: connection.close()

def actualizar_cuota(id_usuario: int, nueva_cuota: int):
    """
    1. Verifica que la nueva cuota no sea menor a lo que el usuario YA está usando.
    2. Verifica que la suma de todas las cuotas (incluida esta nueva) no supere el tamaño físico TOTAL del disco.
    """
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()

        # --- PASO 1: Obtener lo que el usuario ya está ocupando ---
        query_uso = """
            SELECT COALESCE(SUM(tamano), 0) 
            FROM Recurso 
            WHERE id_creador = %s AND fecha_eliminacion IS NULL
        """
        cursor.execute(query_uso, (id_usuario,))
        uso_actual_usuario = cursor.fetchone()[0]

        # VALIDACIÓN A: No reducir cuota por debajo de lo usado
        # (Solo aplicamos esto si nueva_cuota NO es ilimitada/None)
        if nueva_cuota is not None:
            if nueva_cuota < uso_actual_usuario:
                usado_gb = uso_actual_usuario / (1024**3)
                nuevo_gb = nueva_cuota / (1024**3)
                return False, f"Error: El usuario ya ocupa {usado_gb:.2f} GB. No puedes reducir su cuota a {nuevo_gb:.2f} GB sin borrar archivos antes."

            # --- PASO 2: Verificar Aprovisionamiento Físico ---
            
            # A. Obtener tamaño TOTAL del disco físico (Total, no libre)
            # 'total' incluye lo usado y lo libre. Es la capacidad real del hardware.
            total_disco, used_disco, free_disco = shutil.disk_usage("static/uploads")
            
            # B. Sumar cuotas de los OTROS usuarios
            query_suma_otros = """
                SELECT SUM(almacenamiento_maximo) 
                FROM Persona 
                WHERE id != %s AND almacenamiento_maximo IS NOT NULL
            """
            cursor.execute(query_suma_otros, (id_usuario,))
            res_otros = cursor.fetchone()
            suma_cuotas_otros = res_otros[0] if res_otros and res_otros[0] else 0
            
            # C. Verificación Matemática
            # Total Comprometido = (Lo que prometí a otros) + (Lo que prometo a este usuario)
            total_comprometido = suma_cuotas_otros + nueva_cuota
            
            if total_comprometido > total_disco:
                total_gb = total_disco / (1024**3)
                otros_gb = suma_cuotas_otros / (1024**3)
                disponible_para_asignar = (total_disco - suma_cuotas_otros) / (1024**3)
                
                # Si sale negativo, es que ya has prometido más de lo que existe (over-provisioning previo)
                if disponible_para_asignar < 0: disponible_para_asignar = 0
                
                return False, f"Error de Capacidad: El disco es de {total_gb:.2f} GB. Ya hay asignados {otros_gb:.2f} GB a otros usuarios. Máximo asignable: {disponible_para_asignar:.2f} GB."

        # --- PASO 3: Si pasa las validaciones, actualizamos ---
        query_update = "UPDATE Persona SET almacenamiento_maximo = %s WHERE id = %s"
        cursor.execute(query_update, (nueva_cuota, id_usuario))
        connection.commit()
        
        return True, "Cuota actualizada correctamente"

    except Error as e:
        return False, str(e)
    finally:
        if connection: connection.close()