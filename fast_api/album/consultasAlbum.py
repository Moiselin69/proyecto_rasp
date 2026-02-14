from fast_api import db
from mysql.connector import Error
import os

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
def obtener_albumes_usuario(id_usuario: int):
    connection = None
    try:
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            # Obtenemos TODOS los álbumes donde soy miembro (Creador o Colaborador)
            sql = """
                SELECT A.id, A.nombre, A.descripcion, A.id_album_padre, A.fecha_creacion, MA.rol, A.fecha_eliminacion
                FROM Album A
                JOIN Miembro_Album MA ON A.id = MA.id_album
                WHERE MA.id_persona = %s
            """
            cursor.execute(sql, (id_usuario,))
            albumes = cursor.fetchall()
            
            # --- LÓGICA DE VISIBILIDAD EN RAÍZ ---
            # Creamos un set con los IDs de mis álbumes para búsqueda rápida
            mis_ids = {a['id'] for a in albumes}
            
            for album in albumes:
                padre = album['id_album_padre']
                # Si el álbum tiene padre, PERO yo no tengo acceso a ese padre (no está en mi lista),
                # entonces para mí este álbum debe comportarse como una carpeta raíz.
                if padre is not None and padre not in mis_ids:
                    album['id_album_padre'] = None
            
            return (True, albumes)  # <--- CORRECCIÓN AQUÍ: Devuelve tupla
    except Error as e:
        print(f"Error obteniendo albumes: {e}")
        return (False, str(e))      # <--- CORRECCIÓN AQUÍ: Devuelve tupla
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
        
        # Paso 1: Verificar acceso al álbum
        check_query = "SELECT COUNT(*) as count FROM Miembro_Album WHERE id_album=%s AND id_persona=%s"
        cursor.execute(check_query, (id_album, id_persona))
        if cursor.fetchone()['count'] == 0:
            return (False, "No tienes acceso a este album")
            
        # Paso 2: Obtener TODOS los recursos del álbum (sin importar quién los subió)
        # Añadimos r.favorito y r.id_creador que suelen ser necesarios
        query = """
            SELECT R.id, R.tipo, R.nombre, R.fecha_subida, R.fecha_real, R.favorito, R.id_creador, RA.id_album
            FROM Recurso R
            JOIN Recurso_Album RA ON R.id = RA.id_recurso
            WHERE RA.id_album = %s AND R.fecha_eliminacion IS NULL
            ORDER BY R.fecha_real DESC;
        """
        cursor.execute(query, (id_album,))
        resultados = cursor.fetchall()
        
        # CORRECCIÓN IMPORTANTE: Generar URLs para que Flutter las vea
        for recurso in resultados:
            recurso['url_visualizacion'] = f"/recurso/archivo/{recurso['id']}"
            recurso['url_thumbnail'] = f"/recurso/archivo/{recurso['id']}?size=small"
            # Ocultamos la ruta física del servidor
            if 'enlace' in recurso: del recurso['enlace']
            
        return (True, resultados)
    except Error as e:
        print(f"Error en obtener_recursos_album: {e}")
        return (False, str(e))
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
def salir_de_album(id_album: int, id_usuario: int):
    """
    EJECUTADA POR COLABORADORES.
    Simplemente te saca de la lista de miembros.
    """
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()

        # Verificar rol (opcional, pero bueno para seguridad)
        cursor.execute("SELECT rol FROM Miembro_Album WHERE id_album=%s AND id_persona=%s", (id_album, id_usuario))
        res = cursor.fetchone()
        if res and res[0] == 'CREADOR':
             return False, "El creador no puede 'salir'. Debe eliminar el álbum."

        cursor.execute("DELETE FROM Miembro_Album WHERE id_album = %s AND id_persona = %s", (id_album, id_usuario))
        
        if cursor.rowcount == 0:
            return False, "No eras miembro de este álbum"

        connection.commit()
        return True, "Has salido del álbum correctamente."

    except Exception as e:
        if connection: connection.rollback()
        return False, str(e)
    finally:
        if connection: connection.close()
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
def eliminar_album_definitivamente(id_album: int, id_usuario: int):
    """
    EJECUTADA POR EL CREADOR TRAS CONFIRMAR LA ALERTA.
    Borra el álbum, sus subcarpetas, y todos los recursos dentro (BD + Archivos físicos).
    """
    connection = None
    rutas_fisicas_a_borrar = []
    
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()

        # 1. Verificar que es CREADOR
        sql_rol = "SELECT rol FROM Miembro_Album WHERE id_album = %s AND id_persona = %s"
        cursor.execute(sql_rol, (id_album, id_usuario))
        res = cursor.fetchone()
        
        if not res or res[0] != 'CREADOR':
            return False, "No tienes permiso de propietario para eliminar este álbum."

        # 2. Obtener lista de TODOS los IDs de álbumes a borrar (Padre + Subcarpetas recursivas)
        ids_albumes = _obtener_arbol_albumes(cursor, id_album)
        ids_albumes.append(id_album) # Añadimos el álbum raíz
        
        # Convertir lista a string para SQL IN (...)
        format_strings = ','.join(['%s'] * len(ids_albumes))
        tuple_ids = tuple(ids_albumes)

        # 3. Recolectar rutas de archivos físicos antes de borrar la BD
        # Obtenemos los recursos que están en estos álbumes
        sql_recursos = f"""
            SELECT R.id, R.enlace 
            FROM Recurso R
            JOIN Recurso_Album RA ON R.id = RA.id_recurso
            WHERE RA.id_album IN ({format_strings})
        """
        cursor.execute(sql_recursos, tuple_ids)
        recursos = cursor.fetchall()
        
        ids_recursos = [r[0] for r in recursos]
        rutas_fisicas_a_borrar = [r[1] for r in recursos if r[1]] # Guardamos rutas válidas

        # 4. BORRADO EN CASCADA (Orden importante para evitar errores de FK)
        
        if ids_recursos:
            recursos_fmt = ','.join(['%s'] * len(ids_recursos))
            recursos_tuple = tuple(ids_recursos)

            # A. Borrar relaciones de recursos
            cursor.execute(f"DELETE FROM Recurso_Persona WHERE id_recurso IN ({recursos_fmt})", recursos_tuple)
            cursor.execute(f"DELETE FROM Recurso_Album WHERE id_recurso IN ({recursos_fmt})", recursos_tuple)
            # B. Borrar los recursos en sí
            cursor.execute(f"DELETE FROM Recurso WHERE id IN ({recursos_fmt})", recursos_tuple)

        # C. Borrar relaciones de álbumes (Miembros y Peticiones)
        cursor.execute(f"DELETE FROM Miembro_Album WHERE id_album IN ({format_strings})", tuple_ids)
        cursor.execute(f"DELETE FROM Peticion_Album WHERE id_album IN ({format_strings})", tuple_ids)
        
        # D. Borrar los álbumes (MySQL suele requerir borrar hijos antes que padres si no hay CASCADE, 
        # pero al borrarlos por ID en lote suele funcionar si no hay restricciones cíclicas)
        cursor.execute(f"DELETE FROM Album WHERE id IN ({format_strings})", tuple_ids)

        connection.commit()

        # 5. Borrado Físico (Solo si la transacción en BD fue exitosa)
        count_borrados = 0
        for ruta in rutas_fisicas_a_borrar:
            try:
                if os.path.exists(ruta):
                    os.remove(ruta)
                    count_borrados += 1
            except Exception as e:
                print(f"Warning borrando archivo {ruta}: {e}")

        return True, f"Eliminado álbum y {count_borrados} archivos definitivamente."

    except Exception as e:
        if connection: connection.rollback()
        print(f"Error fatal eliminando álbum: {e}")
        return False, f"Error interno: {str(e)}"
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

def _obtener_arbol_albumes(cursor, id_padre):
    """ Función auxiliar recursiva para obtener todos los IDs de subcarpetas """
    ids = []
    cursor.execute("SELECT id FROM Album WHERE id_album_padre = %s", (id_padre,))
    hijos = cursor.fetchall()
    
    for (id_hijo,) in hijos:
        ids.append(id_hijo)
        ids.extend(_obtener_arbol_albumes(cursor, id_hijo))
    
    return ids







