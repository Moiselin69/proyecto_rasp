import db
from mysql.connector import Error
from datetime import datetime
from typing import Optional

def subir_recurso(id_creador: int, tipo: str, enlace: str, nombre: str, fecha_real: Optional[datetime] = None):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "INSERT INTO Recurso (id_creador, tipo, enlace, nombre, fecha_real) VALUES(%s,%s,%s,%s,%s)"
            valores = (id_creador, tipo, enlace, nombre, fecha_real)
            cursor.execute(query_1, valores)
            id_recurso = cursor.lastrowid
            connection.commit()
            return (True, id_recurso)
    except Error as e:
        print(f"Error en subir recurso en MySql: {e}")
        return (False, str(e))
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def obtener_recursos(id_persona:int):
    connection = None
    try: 
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            query = "SELECT id, id_creador, tipo, enlace, nombre, fecha_real, fecha_subida FROM Recurso r JOIN Recurso_Persona rp ON r.id=rp.id_recurso WHERE rp.id_persona=%s"
            valores = (id_persona, )
            cursor.execute(query, valores)
            return (True, cursor.fetchall())
    except Error as e:
        print(f"Error en obtener recursos en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def borrar_recurso(id_recurso:int, id_persona:int):
    connection = None
    try: 
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "SELECT enlace FROM Recurso r JOIN Recurso_Persona rp ON r.id=rp.id_recurso WHERE r.id=%s AND rp.id_persona=%s"
            query_2 = "SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s"
            query_3 = "DELETE FROM Recurso_Persona WHERE id_recurso=%s and id_persona=%s"
            valores = (id_recurso, id_persona)
            valores_2 =(id_recurso, )
            cursor.execute(query_1, valores)
            resultado = cursor.fetchone()
            if resultado:
                enlace = resultado[0]
                cursor.execute(query_2, valores_2)
                total = cursor.fetchone()[0]
                cursor.execute(query_3, valores)
                connection.commit()
                if total == 1:
                    return (True, enlace)
                else:
                    return (True, None)
            else:
                return (False, "El recurso no existe")
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en borrar recursos en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def cambiar_nombre_recurso(id_recurso:int, nombre:str, id_persona:int):
    connection = None
    try: 
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query = "UPDATE Recurso r JOIN Recurso_Persona rp ON r.id=rp.id_recurso SET r.nombre=%s WHERE r.id=%s and rp.id_persona=%s"
            valores = (nombre, id_recurso, id_persona)
            cursor.execute(query, valores)
            if cursor.rowcount == 0:
                connection.rollback()
                return (False, "No se encontró el recurso")
            connection.commit()
            return (True, f"Recurso {id_recurso} actualizado correctamente")
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en cambiar nombre Recurso en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def cambiar_fecha_recurso(id_recurso:int, fecha:datetime, id_persona:int):
    connection = None
    try: 
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query = "UPDATE Recurso r JOIN Recurso_Persona rp on r.id=rp.id_recurso SET fecha_real=%s WHERE r.id=%s and rp.id_persona=%s"
            valores = (fecha, id_recurso, id_persona)
            cursor.execute(query, valores)
            if cursor.rowcount == 0:
                connection.rollback()
                return (False, "No se encontró el recurso")
            connection.commit()
            return (True, f"Recurso {id_recurso} actualizada correctamente")
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en cambiar nombre fecha en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def pedir_compartir_recurso(id_persona: int, id_persona_compartida: int, id_recurso:int):
    connection = None
    try: 
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            query = "INSERT INTO Peticion_recurso (id_persona, id_persona_compartida, id_recurso) VALUES (%s, %s, %s)"
            query_check = "SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso = %s AND id_persona = %s"
            valores = (id_persona, id_persona_compartida, id_recurso)
            valores_check = (id_recurso, id_persona)
            cursor.execute(query_check, valores_check)
            if cursor.fetchone()[0] == 0:
                return (False, "No puedes compartir una recurso que no te pertenece")
            cursor.execute(query, valores)
            connection.commit()
            return (True, "Peticion enviada")
    except Error as e:
        print(f"Error en pedir compartir recurso en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()    

def aceptar_compartir_recurso(id_persona: int, id_persona_compartida: int, id_recurso: int):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "DELETE FROM Peticion_Recurso where id_persona=%s and id_persona_compartida=%s and id_recurso=%s"
            query_2 = "INSERT INTO Recurso_Persona (id_recurso, id_persona) VALUES(%s,%s)"
            valores_1 = (id_persona, id_persona_compartida, id_recurso)
            valores_2 = (id_recurso, id_persona_compartida)
            cursor.execute(query_1, valores_1)
            if cursor.rowcount == 0:
                connection.rollback()
                return (False, "No existe ninguna petición de amistad para este recurso o ya fue aceptada.")
            cursor.execute(query_2, valores_2)
            connection.commit()
            return (True, id_recurso)
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en pedir compartir recurso en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def ver_peticiones_recurso_pendientes(id_persona_compartida: int):
    # Muestra quien te quiere mandar qué cosa
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        query = """
            SELECT P.nombre as remitente, R.nombre as recurso, R.tipo, PR.id_recurso, PR.id_persona as id_remitente
            FROM Peticion_Recurso PR
            JOIN Persona P ON PR.id_persona = P.id
            JOIN Recurso R ON PR.id_recurso = R.id
            WHERE PR.id_persona_compartida = %s
        """
        cursor.execute(query, (id_persona_compartida,))
        return (True, cursor.fetchall())
    except Error as e:
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection: connection.close()

def rechazar_peticion_recurso(id_persona: int, id_persona_compartida: int, id_recurso: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        query = "DELETE FROM Peticion_Recurso WHERE id_persona=%s AND id_persona_compartida=%s AND id_recurso=%s"
        cursor.execute(query, (id_persona, id_persona_compartida, id_recurso))
        connection.commit()
        if cursor.rowcount == 0:
            return (False, "No se encontró la petición")
        return (True, "Petición rechazada")
    except Error as e:
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection: connection.close()

def obtener_recurso_por_id(id_recurso: int, id_persona: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        query = """
            SELECT R.* FROM Recurso R
            JOIN Recurso_Persona RP ON R.id = RP.id_recurso
            WHERE R.id = %s AND RP.id_persona = %s
        """
        cursor.execute(query, (id_recurso, id_persona))
        resultado = cursor.fetchone()
        if not resultado:
            return (False, "Recurso no encontrado o sin acceso")
        return (True, resultado)
    except Error as e:
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection: connection.close()

def revocar_acceso_recurso(id_recurso: int, id_propietario: int, id_usuario_a_eliminar: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        
        # 1. Verificar si tiene permiso (Usando Recurso_Persona para permitir gestión compartida)
        check = "SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s AND id_persona=%s"
        cursor.execute(check, (id_recurso, id_propietario))
        if cursor.fetchone()[0] == 0:
             return (False, "No eres propietario de este recurso")

        # 2. Eliminar al otro usuario
        delete = "DELETE FROM Recurso_Persona WHERE id_recurso=%s AND id_persona=%s"
        cursor.execute(delete, (id_recurso, id_usuario_a_eliminar))
        
        if cursor.rowcount == 0:
            return (False, "El usuario no tenía acceso a este recurso")
            
        connection.commit()
        return (True, "Acceso revocado")
    except Error as e:
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection: connection.close()

def revocar_todos_accesos_recurso(id_recurso: int, id_persona: int):
    """
    Elimina el acceso al recurso de TODAS las personas, excepto del creador original.
    Solo el creador original puede ejecutar esta acción.
    """
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        connection.autocommit = False # Usamos transacción por seguridad
        if connection.is_connected():
            cursor = connection.cursor()

            # 1. VERIFICACIÓN: Comprobamos en la tabla 'Recurso' quién es el creador real.
            # No miramos en Recurso_Persona porque ahí todos son "dueños",
            # necesitamos la autoridad del 'id_creador' original.
            query_check = "SELECT id_creador FROM Recurso WHERE id = %s"
            cursor.execute(query_check, (id_recurso,))
            resultado = cursor.fetchone()

            if not resultado:
                return (False, "El recurso no existe")

            id_creador_real = resultado[0]

            # Si el que pide la acción no es el creador, bloqueamos.
            if id_creador_real != id_persona:
                return (False, "Acción denegada: Solo el creador original puede revocar todos los accesos")

            # 2. EJECUCIÓN: Borramos a todos de la tabla intermedia MENOS al creador.
            # El operador '!=' significa "diferente de".
            query_delete = "DELETE FROM Recurso_Persona WHERE id_recurso = %s AND id_persona != %s"
            cursor.execute(query_delete, (id_recurso, id_persona))
            
            personas_eliminadas = cursor.rowcount
            
            connection.commit()
            
            if personas_eliminadas == 0:
                return (True, "Nadie más tenía acceso, no se realizaron cambios.")
                
            return (True, f"Se ha revocado el acceso a {personas_eliminadas} personas. Tú sigues siendo el propietario.")

    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en revocar todos los accesos: {e}")
        return (False, str(e))
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()