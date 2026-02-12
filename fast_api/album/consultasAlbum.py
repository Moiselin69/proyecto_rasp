from fast_api import db
from mysql.connector import Error

# Utilizado en el endpoint 1 de Album --------------------------------------------------------------
def crear_album(nombre: str, descripcion:str, id_persona:int, id_album_padre: int = None):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            # Paso 1, verificamos jerarquía
            if id_album_padre is not None:
                check_padre = "SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
                cursor.execute(check_padre, (id_album_padre, id_persona))
                res = cursor.fetchone()
                if not res: 
                     return (False, "No tienes acceso al álbum padre indicado.")
                rol_en_padre = res[0]
                if rol_en_padre not in ['CREADOR', 'ADMINISTRADOR']:
                    return (False, "Permisos insuficientes: Solo administradores o creadores pueden crear subcarpetas aquí.")
            # Paso 2: Insertar el Álbum
            query_1 = "INSERT INTO Album (nombre, descripcion, id_album_padre) VALUES (%s, %s, %s);"
            valores = (nombre, descripcion, id_album_padre)
            cursor.execute(query_1, valores)
            if cursor.lastrowid:
                id_album = cursor.lastrowid
            else:
                cursor.execute("SELECT LAST_INSERT_ID();")
                resultado = cursor.fetchone()
                id_album = resultado[0] if resultado else 0
            if not id_album or id_album == 0:
                connection.rollback()
                return (False, "Error: No se pudo obtener el ID del álbum creado.")
            # Paso 3: Insertar al Creador en Miembro_Album
            query_2 = "INSERT INTO Miembro_Album (id_album, id_persona, rol) VALUES(%s, %s, 'CREADOR')"
            valores_miembro = (id_album, id_persona)
            cursor.execute(query_2, valores_miembro)
            connection.commit()
            return (True, id_album)
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en crear_album: {e}")
        return (False, str(e))
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()
# Utilizado en el endpoint 2 de Album -------------------------------------------------------------
def obtener_albumes_usuario(id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        query = """
            SELECT A.id, A.nombre, A.descripcion, A.fecha_creacion, A.id_album_padre, M.rol 
            FROM Album A
            JOIN Miembro_Album M ON A.id = M.id_album
            WHERE M.id_persona = %s
            ORDER BY A.fecha_creacion DESC;
        """
        cursor.execute(query, (id_persona,))
        resultados = cursor.fetchall()
        return (True, resultados)
    except Exception as e:
        print(f"Error en la consulta 'obtener_albumes_usuario': {e}")
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 3 de Album --------------------------------------------------------------
def obtener_recursos_album(id_album: int, id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        # Paso 1: verificamos que la persona que quiere obtener los recursos del album es miembro del album
        check_query = "SELECT COUNT(*) as count FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
        cursor.execute(check_query, (id_album, id_persona))
        if cursor.fetchone()['count'] == 0:
            return (False, "No tienes acceso a este album")
        # Paso 2: Realizamos la consulta para obtener los datos de los recursos a la base de datos
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
        print(f"Error en la consulta de 'obtener_recursos_album': {e}")
        return (False, e)
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 4 de Album --------------------------------------------------------------
def peticion_album(id_persona: int, id_persona_compartida: int, id_album:int, rol:str):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            # Paso 1: Verificamos que el usuario pertenece al album
            query_check = "SELECT rol FROM Miembro_Album WHERE id_album = %s AND id_persona = %s;"
            cursor.execute(query_check, (id_album, id_persona))
            resultado = cursor.fetchone()
            if not resultado:
                return (False, "Error: No perteneces a este álbum.")
            # Paso 2: Verificamos que el usuario tiene el rol de administrador o de creador
            rol_usuario = resultado[0]
            if rol_usuario not in ['CREADOR', 'ADMINISTRADOR']:
                return (False, "Permisos insuficientes: Solo administradores o creadores pueden invitar.")
            # Paso 3: Verificamos que el usuario al que se le quiere invitar ya pertenece al album o ya tiene invitación
            query_duplicado = """
                SELECT 
                    (SELECT COUNT(*) FROM Miembro_Album WHERE id_album=%s AND id_persona=%s) as es_miembro,
                    (SELECT COUNT(*) FROM Peticion_Album WHERE id_album=%s AND id_persona_compartida=%s) as ya_invitado;
            """
            cursor.execute(query_duplicado, (id_album, id_persona_compartida, id_album, id_persona_compartida))
            estado = cursor.fetchone()
            if estado[0] > 0:
                return (False, "Esta persona ya es miembro del álbum.")
            if estado[1] > 0:
                return (False, "Esta persona ya tiene una invitación pendiente.")
            # Paso 4: Ejecutamos
            query = "INSERT INTO Peticion_Album (id_persona, id_persona_compartida, id_album, rol) VALUES (%s, %s, %s, %s);"
            valores = (id_persona, id_persona_compartida, id_album, rol)
            cursor.execute(query, valores)
            connection.commit()
            return (True, "Petición enviada correctamente")
    except Error as e:
        print(f"Error en la consulta peticion_album: {e}")
        return (False, str(e))
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()
# Utilizado en el endpoint 5 de Album --------------------------------------------------------------
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
            # Paso 1: Comprobamos que el usuario es propietario del recurso
            cursor.execute(query_1, valores_1)
            if cursor.fetchone()[0] < 1:
                return (False, "No eres propietario de este recurso")
            # Paso 2: Comprobamos que el usuario pertenece al album
            cursor.execute(query_2, valores_2)
            if cursor.fetchone()[0] < 1:
                return (False, "No eres miembro de este album")
            # Paso 3: Ejecutamos acción
            cursor.execute(query_3, valores_3)
            connection.commit()
            return (True, (id_album,id_recurso))
    except Error as e:
        print(f"Error en la consulta de 'add_recurso_album': {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()
# Utilizado en el endpoint 6 de Album --------------------------------------------------------------
def borrar_recurso_album(id_recurso: int, id_album: int, id_persona:int):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor()
            # Paso 1: Comprobamos que el usuario que quiere borrar el recurso es administrador, creador o propietario del recurso
            query_check = """
                SELECT 
                    (SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s) as rol,
                    (SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s AND id_persona=%s) as es_dueno
            """
            cursor.execute(query_check, (id_album, id_persona, id_recurso, id_persona))
            res = cursor.fetchone()
            rol = res[0]
            es_dueno = res[1] > 0
            if (rol not in ['CREADOR', 'ADMINISTRADOR']) and (not es_dueno):
                return (False, "No tienes permiso para borrar esta foto")
            # Paso 2: Ejecutamos
            query_2 = "DELETE FROM Recurso_Album WHERE id_album=%s AND id_recurso=%s;"
            valores_2 = (id_album, id_recurso)
            cursor.execute(query_2, valores_2)
            connection.commit()
            return (True, (id_album,id_recurso))
    except Error as e:
        print(f"Error en la consulta 'borrar_recurso_album': {e}")
        return (False,e)
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()
# Utilizado en el endpoint 7 de Album ---------------------------------------------------------------
def salir_de_album(id_album: int, id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        cursor.callproc('salir_de_album', [id_album, id_persona])
        connection.commit()
        return (True, "Has salido del album correctamente")
    except Error as e:
        print(f"Error en la consulta 'salir_de_album': {e}")
        return (False, e)
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 8 de Album --------------------------------------------------------------
def ver_peticiones_pendientes_album(id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
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
        print(f"Error en la consulta 'ver_peticiones_pendientes_album': {e}")
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 9 de Album --------------------------------------------------------------
def aceptar_peticion_album(id_persona_invitadora: int, id_usuario_aceptando: int, id_album: int):
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()
        # Paso 1: Obtenemos el ROL original de la invitación (Seguridad)
        query_check = "SELECT rol FROM Peticion_Album WHERE id_persona=%s AND id_persona_compartida=%s AND id_album=%s"
        cursor.execute(query_check, (id_persona_invitadora, id_usuario_aceptando, id_album))
        resultado = cursor.fetchone()
        if not resultado:
            return (False, "No existe invitación pendiente para este álbum de esta persona")
        rol_asignado = resultado[0]
        # Paso 2: Borramos la petición
        query_delete = "DELETE FROM Peticion_Album WHERE id_persona=%s AND id_persona_compartida=%s AND id_album=%s;"
        cursor.execute(query_delete, (id_persona_invitadora, id_usuario_aceptando, id_album))
        # Paso 3: Insertamos al miembro con el rol que tenía asignado
        query_insert = "INSERT INTO Miembro_Album (id_album, id_persona, rol) VALUES (%s, %s, %s);"
        cursor.execute(query_insert, (id_album, id_usuario_aceptando, rol_asignado))
        connection.commit()
        return (True, "Invitación aceptada correctamente")
    except Exception as e:
        if connection: connection.rollback()
        print("Error en la consulta 'aceptar_peticion_album': {e}")
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 10 de Album -----------------------------------------------------------------
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
        print("Error en la consulta 'rechazar_peticion_album': {e}")
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 11 de Album -------------------------------------------------------------
def mover_album(id_album: int, id_nuevo_padre: int, id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        # Paso 1: Verificamos que el usuario tenga permisos (sea CREADOR o ADMINISTRADOR)
        query_permisos = "SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"  
        cursor.execute(query_permisos, (id_album, id_persona))
        resultado = cursor.fetchone()
        if not resultado or resultado[0] not in ['CREADOR', 'ADMINISTRADOR']:
            return (False, "No tienes permisos suficientes para mover este álbum")
        # Paso 2:  Llamamos al procedimiento almacenado MoverAlbumSeguro
        args = [id_album, id_nuevo_padre, ""]
        resultado_proc = cursor.callproc('MoverAlbumSeguro', args)
        mensaje_salida = resultado_proc[2] # El resultado del OUT está en la última posición de la lista devuelta por callproc
        if mensaje_salida == 'OK':
            connection.commit()
            return (True, "Álbum movido correctamente")
        else:
            return (False, mensaje_salida)
    except Error as e:
        if connection: connection.rollback()
        print("Error en la consulta 'mover_album': {e}")
        return (False, str(e))
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()
# Utilizado en el endpoint 12 de Album --------------------------------------------------------------------
def mover_recurso_de_album(id_recurso: int, id_album_origen: int, id_album_destino: int, id_persona: int):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        # Paso 1: Comprobamos que el usuario pertenece al álbum y que tiene permisos para mover este archivo
        query_check = """
            SELECT 
                (SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s AND id_persona=%s) as es_dueno,
                (SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s) as rol_origen,
                (SELECT COUNT(*) FROM Miembro_Album WHERE id_album=%s AND id_persona=%s) as en_destino
        """
        cursor.execute(query_check, (id_recurso, id_persona, id_album_origen, id_persona, id_album_destino, id_persona))
        res = cursor.fetchone()
        es_dueno = res[0] > 0
        rol_origen = res[1] 
        en_destino = res[2] > 0
        tiene_permiso_origen = es_dueno or (rol_origen in ['ADMINISTRADOR', 'CREADOR'])
        if not en_destino:
            return (False, "No perteneces al álbum de destino")
        if not tiene_permiso_origen:
             return (False, "No tienes permiso para mover este archivo (no eres el dueño ni admin)")
        # Paso 2: Ejecutar
        if id_album_origen is not None and id_album_destino is not None:
            query = "UPDATE Recurso_Album SET id_album=%s WHERE id_recurso=%s AND id_album=%s"
            cursor.execute(query, (id_album_destino, id_recurso, id_album_origen))
            if cursor.rowcount == 0:
                return (False, "No se encontró el recurso en el álbum origen")
            connection.commit()
            return (True, "Archivo movido correctamente")
        else:
            return (False, "Parámetros incorrectos para mover")
    except Exception as e:
        if connection: connection.rollback()
        print(f"Error mover recurso: {e}")
        return (False, str(e))
    finally:
        if connection: 
            cursor.close()
            connection.close()
# Utilizado en el endpoint 13 de Album ---------------------------------------------------------------------
def borrar_album_completo(id_album: int, id_persona: int):
    connection = None
    rutas_a_borrar = [] # Lista donde guardaremos los paths de los archivos a eliminar del disco
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        check = "SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"# 1. Verificar si es CREADOR
        cursor.execute(check, (id_album, id_persona))
        res = cursor.fetchone()
        if not res or res[0] != 'CREADOR':
            return (False, "Solo el creador puede eliminar la carpeta")
        def _borrar_recursivamente(id_actual): # --- FUNCIÓN RECURSIVA INTERNA ---
            cursor.execute("SELECT id FROM Album WHERE id_album_padre = %s", (id_actual,)) # A. Procesar sub-carpetas (primero los hijos)
            hijos = cursor.fetchall()
            for fila in hijos:
                _borrar_recursivamente(fila[0])
            cursor.execute("SELECT id_recurso FROM Recurso_Album WHERE id_album=%s", (id_actual,)) # B. Procesar recursos del álbum actual
            recursos = cursor.fetchall()
            for (id_rec,) in recursos:
                cursor.execute("SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s", (id_rec,)) # Antes de borrar, comprobamos si el archivo quedará huérfano (nadie más lo tiene)
                count = cursor.fetchone()[0] # Si el contador es 1 (solo yo), al borrarme a mí, el archivo debe morir.
                if count <= 1:
                    # Recuperamos la ruta física para borrarlo luego
                    cursor.execute("SELECT enlace FROM Recurso WHERE id=%s", (id_rec,))
                    fila_recurso = cursor.fetchone()
                    if fila_recurso:
                        rutas_a_borrar.append(fila_recurso[0]) # Guardamos ruta original
                cursor.execute("DELETE FROM Recurso_Persona WHERE id_recurso=%s AND id_persona=%s", (id_rec, id_persona)) # Borramos el permiso (el Trigger de SQL se encargará de borrar la fila de la tabla Recurso)
            cursor.execute("DELETE FROM Recurso_Album WHERE id_album=%s", (id_actual,))  # C. Limpiar relaciones y borrar álbum
            cursor.execute("DELETE FROM Miembro_Album WHERE id_album=%s", (id_actual,))
            cursor.execute("DELETE FROM Peticion_Album WHERE id_album=%s", (id_actual,))
            cursor.execute("DELETE FROM Album WHERE id=%s", (id_actual,))
        _borrar_recursivamente(id_album)# 2. Iniciar recursividad
        connection.commit()
        # Devolvemos True y la LISTA DE ARCHIVOS 
        return (True, rutas_a_borrar)
    except Exception as e:
        if connection: connection.rollback()
        print(f"Error borrando album: {e}")
        return (False, str(e))
    finally:
        if connection: 
            cursor.close()
            connection.close()
# Utilizado en el endpoint 14 de Album -------------------------------------------------------------
def ver_miembros_album(id_album: int, id_persona_solicitante: int): # <--- Añadir parámetro
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        # Paso 1: Verificar que quien pide los datos está dentro del álbum
        check = "SELECT COUNT(*) as c FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
        cursor.execute(check, (id_album, id_persona_solicitante))
        if cursor.fetchone()['c'] == 0:
             return (False, "No tienes permiso para ver los miembros de este álbum")
        # Paso 2: Ejecutar
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
        if connection:
            cursor.close()
            connection.close()
# Utilizado en el endpoint 15 de Album-----------------------------------------------------------------
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








