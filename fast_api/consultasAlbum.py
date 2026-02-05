import db
from mysql.connector import Error

def crear_album(nombre: str, descripcion:str, id_persona:int, id_album_padre: int = None):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            
            # 1. Insertar el Álbum
            query_1 = "INSERT INTO Album (nombre, descripcion, id_album_padre) VALUES (%s, %s, %s);"
            valores = (nombre, descripcion, id_album_padre)
            cursor.execute(query_1, valores)
            
            # 2. Recuperar el ID generado de forma robusta
            if cursor.lastrowid:
                id_album = cursor.lastrowid
            else:
                # Plan B: Si lastrowid falla, pedimos el ID explícitamente a la BD
                cursor.execute("SELECT LAST_INSERT_ID();")
                resultado = cursor.fetchone()
                id_album = resultado[0] if resultado else 0

            # Verificación de seguridad
            if not id_album or id_album == 0:
                connection.rollback()
                return (False, "Error: No se pudo obtener el ID del álbum creado.")

            # 3. Insertar al Creador en Miembro_Album
            query_2 = "INSERT INTO Miembro_Album (id_album, id_persona, rol) VALUES(%s, %s, 'CREADOR')"
            valores_miembro = (id_album, id_persona)
            cursor.execute(query_2, valores_miembro)
            
            connection.commit()
            return (True, id_album)
            
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        # Corregido el mensaje de log para que sea más claro
        print(f"Error en crear_album (MySQL): {e}")
        return (False, str(e))
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def peticion_album(id_persona: int, id_persona_compartida: int, id_album:int, rol:str):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query = "INSERT INTO Peticion_Album (id_persona, id_persona_compartida, id_album, rol) VALUES (%s, %s, %s, %s);"
            valores = (id_persona, id_persona_compartida, id_album, rol)
            cursor.execute(query, valores)
            connection.commit()
            return (True, "Peticion enviada")
    except Error as e:
        print(f"Error en guardar persona en MySql: {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def aceptar_peticion_album(id_persona_invitadora: int, id_usuario_aceptando: int, id_album: int):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()
        
        # 1. Obtenemos el ROL original de la invitación (Seguridad)
        query_check = "SELECT rol FROM Peticion_Album WHERE id_persona=%s AND id_persona_compartida=%s AND id_album=%s"
        cursor.execute(query_check, (id_persona_invitadora, id_usuario_aceptando, id_album))
        resultado = cursor.fetchone()
        
        if not resultado:
            return (False, "No existe invitación pendiente para este álbum de esta persona")
        
        rol_asignado = resultado[0]

        # 2. Borramos la petición
        query_delete = "DELETE FROM Peticion_Album WHERE id_persona=%s AND id_persona_compartida=%s AND id_album=%s;"
        cursor.execute(query_delete, (id_persona_invitadora, id_usuario_aceptando, id_album))

        # 3. Insertamos al miembro con el rol que tenía asignado
        query_insert = "INSERT INTO Miembro_Album (id_album, id_persona, rol) VALUES (%s, %s, %s);"
        cursor.execute(query_insert, (id_album, id_usuario_aceptando, rol_asignado))
        
        connection.commit()
        return (True, "Invitación aceptada correctamente")
    except Exception as e:
        if connection: connection.rollback()
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def add_recurso_album(id_recurso:int, id_album:int, id_persona:int):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s AND id_persona=%s;"
            query_2 = "SELECT COUNT(*) FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
            query_3 = "INSERT INTO Recurso_Album (id_album, id_recurso) VALUES (%s, %s);"
            valores_1 = (id_recurso, id_persona)
            valores_2 = (id_album, id_persona)
            valores_3 = (id_album, id_recurso)
            cursor.execute(query_1, valores_1)
            if cursor.fetchone()[0] < 1:
                return (False, "No eres propietario de este recurso")
            cursor.execute(query_2, valores_2)
            if cursor.fetchone()[0] < 1:
                return (False, "No eres miembro de este album")
            cursor.execute(query_3, valores_3)
            connection.commit()
            return (True, (id_album,id_recurso))
    except Error as e:
        print(f"Error en guardar persona en MySql: {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def borrar_recurso_album(id_recurso: int, id_album: int, id_persona:int):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "SELECT COUNT(*) FROM Miembro_Album WHERE id_album=%s AND id_persona=%s AND (rol='CREADOR' OR rol='ADMINISTRADOR')"
            query_2 = "DELETE FROM Recurso_Album WHERE id_album=%s AND id_recurso=%s;"
            valores_1 = (id_album, id_persona)
            valores_2 = (id_album, id_recurso)
            cursor.execute(query_1, valores_1)
            if cursor.fetchone()[0] < 1:
                return (False, "Permisos insuficientes para eliminar recursos")
            cursor.execute(query_2, valores_2)
            connection.commit()
            return (True, (id_album,id_recurso))
    except Error as e:
        print(f"Error en guardar persona en MySql: {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def hacer_rol_album(id_persona:int, id_persona_implicada:int, id_album:int ,nuevo_rol:str):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
            query_2 = "SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
            query_3 = "UPDATE Miembro_Album SET rol=%s WHERE id_album=%s AND id_persona=%s"
            valores_1 = (id_album, id_persona)
            valores_2 = (id_album, id_persona_implicada)
            valores_3 = (nuevo_rol, id_album, id_persona_implicada)
            cursor.execute(query_1, valores_1)
            resultado_1 = cursor.fetchone()
            cursor.execute(query_2, valores_2)
            resultado_2 = cursor.fetchone()
            if not resultado_1:
                return (False, "No perteneces al album")
            if not resultado_2:
                return (False, "El usuario implicado no pertenece al album")
            rol_persona = resultado_1[0]
            rol_persona_implicada = resultado_2[0]
            if rol_persona == "COLABORADOR":
                return (False, "Los colaboradores no pueden cambiar roles")
            if rol_persona == "ADMINISTRADOR" and rol_persona_implicada in ["ADMINISTRADOR", "CREADOR"]:
                return (False, "Un administrador no puede modificar a otro administrador o al creador")
            cursor.execute(query_3, valores_3)
            connection.commit()
            return (True, (id_album, None))
    except Error as e:
        print(f"Error en guardar persona en MySql: {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def obtener_albumes_usuario(id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        
        query = """
            SELECT A.id, A.nombre, A.descripcion, A.fecha_creacion, M.rol 
            FROM Album A
            JOIN Miembro_Album M ON A.id = M.id_album
            WHERE M.id_persona = %s
            ORDER BY A.fecha_creacion DESC;
        """
        cursor.execute(query, (id_persona,))
        resultados = cursor.fetchall()
        return (True, resultados)
    except Exception as e: # Cambiado de Error a Exception para capturar todo
        print(f"Error en obtener_albumes_usuario: {e}")
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def obtener_recursos_album(id_album: int, id_persona: int):
    # id_persona se pide para verificar que tenga permiso de ver el album
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        
        # Primero verificamos si es miembro
        check_query = "SELECT COUNT(*) as count FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
        cursor.execute(check_query, (id_album, id_persona))
        if cursor.fetchone()['count'] == 0:
            return (False, "No tienes acceso a este album")

        query = """
            SELECT R.id, R.enlace, R.tipo, R.nombre, R.fecha_subida
            FROM Recurso R
            JOIN Recurso_Album RA ON R.id = RA.id_recurso
            WHERE RA.id_album = %s;
        """
        cursor.execute(query, (id_album,))
        resultados = cursor.fetchall()
        return (True, resultados)
    except Error as e:
        return (False, e)
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def salir_de_album(id_album: int, id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        
        # Llamar al procedimiento almacenado
        cursor.callproc('salir_de_album', [id_album, id_persona])
        connection.commit()
        
        return (True, "Has salido del album correctamente")
    except Error as e:
        print(f"Error: {e}")
        return (False, e)
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def ver_miembros_album(id_album: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        
        query = """
            SELECT P.id, P.nombre, P.apellidos, P.correo_electronico, M.rol, M.fecha_union
            FROM Persona P
            JOIN Miembro_Album M ON P.id = M.id_persona
            WHERE M.id_album = %s
            ORDER BY FIELD(M.rol, 'CREADOR', 'ADMINISTRADOR', 'COLABORADOR');
        """
        cursor.execute(query, (id_album,))
        return (True, cursor.fetchall())
    except Error as e:
        return (False, e)
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def ver_peticiones_pendientes_album(id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        # Obtenemos nombre del álbum y nombre de quien invita
        query = """
            SELECT PA.id_album, A.nombre as nombre_album, 
                   PA.id_persona as id_invitador, P.nombre as nombre_invitador, 
                   PA.rol, PA.id_persona_compartida
            FROM Peticion_Album PA
            JOIN Album A ON PA.id_album = A.id
            JOIN Persona P ON PA.id_persona = P.id
            WHERE PA.id_persona_compartida = %s
        """
        cursor.execute(query, (id_persona,))
        return (True, cursor.fetchall())
    except Exception as e:
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def rechazar_peticion_album(id_persona_invitadora: int, id_usuario_rechazando: int, id_album: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        
        query = "DELETE FROM Peticion_Album WHERE id_persona=%s AND id_persona_compartida=%s AND id_album=%s"
        cursor.execute(query, (id_persona_invitadora, id_usuario_rechazando, id_album))
        
        if cursor.rowcount == 0:
            return (False, "No se encontró la invitación")
            
        connection.commit()
        return (True, "Invitación rechazada")
    except Exception as e:
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def mover_album(id_album: int, id_nuevo_padre: int, id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        query_permisos = "SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"  # 1. Verificamos que el usuario tenga permisos (sea CREADOR o ADMINISTRADOR)
        cursor.execute(query_permisos, (id_album, id_persona))
        resultado = cursor.fetchone()
        
        if not resultado or resultado[0] not in ['CREADOR', 'ADMINISTRADOR']:
            return (False, "No tienes permisos suficientes para mover este álbum")

        args = [id_album, id_nuevo_padre, ""]  # 2. Llamamos al procedimiento almacenado MoverAlbumSeguro
        resultado_proc = cursor.callproc('MoverAlbumSeguro', args)
        
        mensaje_salida = resultado_proc[2] # El resultado del OUT está en la última posición de la lista devuelta por callproc
        
        if mensaje_salida == 'OK':
            connection.commit()
            return (True, "Álbum movido correctamente")
        else:
            return (False, mensaje_salida)

    except Error as e:
        if connection: connection.rollback()
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
