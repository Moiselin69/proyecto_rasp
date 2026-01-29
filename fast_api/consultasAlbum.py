import db
from mysql.connector import Error

def crear_album(nombre: str, descripcion:str, id_persona:int):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "INSERT INTO Album (nombre, descripcion) VALUES (%s, %s);"
            valores = (nombre, descripcion)
            query_2 = "INSERT INTO Miembro_Album (id_album, id_persona, rol) VALUES(%s, %s, 'CREADOR')"
            cursor.execute(query_1, valores)
            id_album = cursor.lastrowid
            valores = (id_persona, id_album)
            cursor.execute(query_2, valores)
            if cursor.rowcount == 0:
                connection.rollback()
                return (False, "No se ha podido crear la relacion, vuelva a intentarlo más tarde")
            connection.commit()
            return (True,id_album)
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en guardar persona en MySql: {e}")
        return (False,e)
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

def aceptar_peticion_album(id_persona: int, id_persona_compartida: int, id_album: int, rol:str):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "DELETE FROM Peticion_Album WHERE id_persona=%s AND id_persona_compartida=%s AND id_album=%s;"
            query_2 = "INSERT INTO Miembro_Album (id_album, id_persona, rol) VALUES (%s, %s, %s);"
            valores = (id_persona, id_persona_compartida, id_album)
            cursor.execute(query_1, valores)
            if cursor.rowcount == 0:
                connection.rollback()
                return (False, "No se ha encontrado la petición para entrar al album")
            valores = (id_album, id_persona_compartida, rol)
            cursor.execute(query_2, valores)
            connection.commit()
            return (True, id_album)
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en guardar persona en MySql: {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
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
        cursor = connection.cursor(dictionary=True) # dictionary=True devuelve resultados como JSON/dict
        
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
    except Error as e:
        return (False, e)
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