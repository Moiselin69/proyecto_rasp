import os
from PIL import Image
import cv2
from fast_api import db
from mysql.connector import Error
from datetime import datetime
from typing import Optional, Tuple, Any, List
import shutil
import fast_api.utilidades.utilidadesMetadatos as utilidadesMetadatos

# ------------- CHECKEAR Y REMPLAZAR ARCHIVOS ---------------------------------



#-------------------------------------------------------------------------------------------------------
#                                    OBTENCION DE RECURSOS
#--------------------------------------------------------------------------------------------------------

def obtener_recursos(id_persona:int):
    connection = None
    try: 
        connection = db.get_connection()
        if connection.is_connected():
            cursor = connection.cursor(dictionary=True)
            query = """
                SELECT r.id, r.tipo, r.nombre, r.fecha_real, r.fecha_subida, ra.id_album, r.favorito
                FROM Recurso r 
                JOIN Recurso_Persona rp ON r.id=rp.id_recurso 
                LEFT JOIN Recurso_Album ra ON r.id = ra.id_recurso
                WHERE rp.id_persona=%s AND r.fecha_eliminacion IS NULL
                ORDER BY r.fecha_real DESC
            """
            valores = (id_persona, )
            cursor.execute(query, valores)
            recursos = cursor.fetchall()
            for recurso in recursos:
                recurso['url_visualizacion'] = f"/recurso/archivo/{recurso['id']}"
                recurso['url_thumbnail'] = f"/recurso/archivo/{recurso['id']}?size=small"
            return (True, recursos)
    except Error as e:
        print(f"Error en obtener recursos en MySql: {e}")
        return (False, str(e))
    finally: 
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

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

def eliminar_definitivamente_bd(id_recurso: int, id_usuario: int) -> Tuple[bool, Any]:
    connection = None
    try: 
        connection = db.get_connection()
        connection.autocommit = False
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "SELECT enlace FROM Recurso r JOIN Recurso_Persona rp ON r.id=rp.id_recurso WHERE r.id=%s AND rp.id_persona=%s"
            query_2 = "SELECT COUNT(*) FROM Recurso_Persona WHERE id_recurso=%s"
            query_3 = "DELETE FROM Recurso_Persona WHERE id_recurso=%s and id_persona=%s"
            valores = (id_recurso, id_usuario)
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


# ---------------------------------------------------------------------------------------
#                               LOGICA DE COMPARTIR RECURSOS
#----------------------------------------------------------------------------------------

def compartir_recurso_bd(id_recurso, id_emisor, id_receptor):
    conexion = db.get_connection()
    try:
        with conexion.cursor() as cursor:
            sql_owner = "SELECT id FROM Recurso WHERE id = %s AND id_creador = %s"
            cursor.execute(sql_owner, (id_recurso, id_emisor))
            if not cursor.fetchone():
                return False, "Error: No puedes compartir un recurso que no es tuyo."
            sql_amigos = """
                SELECT 1 FROM Persona_Amiga 
                WHERE (id_persona_1 = %s AND id_persona_2 = %s) 
                   OR (id_persona_1 = %s AND id_persona_2 = %s)
            """
            cursor.execute(sql_amigos, (id_emisor, id_receptor, id_receptor, id_emisor))
            es_amigo = cursor.fetchone()
            if es_amigo:
                sql_check = "SELECT 1 FROM Recurso_Compartido WHERE id_recurso=%s AND id_emisor=%s AND id_receptor=%s"
                cursor.execute(sql_check, (id_recurso, id_emisor, id_receptor))
                if cursor.fetchone():
                     return False, "Ya habías compartido este recurso con esta persona."
                sql_insert = "INSERT INTO Recurso_Compartido (id_recurso, id_emisor, id_receptor) VALUES (%s, %s, %s)"
                cursor.execute(sql_insert, (id_recurso, id_emisor, id_receptor))
                conexion.commit()
                return True, "Recurso compartido exitosamente."
            else:
                sql_check_pet = """
                    SELECT 1 FROM Peticion_Recurso 
                    WHERE id_recurso=%s AND id_persona=%s AND id_persona_compartida=%s
                """
                cursor.execute(sql_check_pet, (id_recurso, id_emisor, id_receptor))
                if cursor.fetchone():
                    return False, "Ya existe una solicitud pendiente para compartir este archivo."
                sql_pet = """
                    INSERT INTO Peticion_Recurso (id_persona, id_persona_compartida, id_recurso, estado) 
                    VALUES (%s, %s, %s, 'PENDIENTE')
                """
                cursor.execute(sql_pet, (id_emisor, id_receptor, id_recurso))
                conexion.commit()
                return True, "No sois amigos. Se ha enviado una solicitud para compartir."
    except Exception as e:
        return False, str(e)
    finally:
        conexion.close()

def obtener_compartidos_conmigo(id_receptor):
    """Devuelve los recursos que otros han compartido contigo."""
    conexion = db.get_connection()
    try:
        with conexion.cursor(dictionary=True) as cursor:
            sql = """
                SELECT R.*, P.nombre as nombre_emisor, P.apellidos as apellidos_emisor, RC.fecha_compartido
                FROM Recurso R
                JOIN Recurso_Compartido RC ON R.id = RC.id_recurso
                JOIN Persona P ON RC.id_emisor = P.id
                WHERE RC.id_receptor = %s
                ORDER BY RC.fecha_compartido DESC
            """
            cursor.execute(sql, (id_receptor,))
            return True, cursor.fetchall()
    except Exception as e:
        return False, str(e)
    finally:
        if conexion: conexion.close()

def obtener_peticiones_recurso_pendientes(id_receptor):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        # Usamos buffered=True para evitar conflictos con otras consultas
        cursor = connection.cursor(dictionary=True, buffered=True)
        sql = """
            SELECT R.nombre as nombre_recurso, R.tipo, P.nombre as nombre_emisor, P.apellidos as apellidos_emisor, 
                   PR.id_recurso, PR.id_persona as id_emisor, PR.fecha_solicitud
            FROM Peticion_Recurso PR
            JOIN Recurso R ON PR.id_recurso = R.id
            JOIN Persona P ON PR.id_persona = P.id
            WHERE PR.id_persona_compartida = %s AND PR.estado = 'PENDIENTE'
        """
        cursor.execute(sql, (id_receptor,))
        resultados = cursor.fetchall()
        # Convertimos fecha_solicitud a string si es datetime, para evitar errores de serialización JSON
        for row in resultados:
            if row.get('fecha_solicitud'):
                row['fecha_solicitud'] = str(row['fecha_solicitud'])
        return True, resultados
        
    except Exception as e:
        print(f"Error obteniendo peticiones: {e}")
        return False, str(e)
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def responder_peticion_recurso(id_emisor, id_receptor, id_recurso, aceptar):
    """Acepta o rechaza una solicitud de recurso."""
    conexion = db.get_connection()
    try:
        with conexion.cursor() as cursor:
            nuevo_estado = 'ACEPTADA' if aceptar else 'RECHAZADA'
            sql_update = """
                UPDATE Peticion_Recurso 
                SET estado = %s 
                WHERE id_persona = %s AND id_persona_compartida = %s AND id_recurso = %s
            """
            cursor.execute(sql_update, (nuevo_estado, id_emisor, id_receptor, id_recurso))
            if aceptar:
                sql_insert = """
                    INSERT IGNORE INTO Recurso_Compartido (id_recurso, id_emisor, id_receptor) 
                    VALUES (%s, %s, %s)
                """
                cursor.execute(sql_insert, (id_recurso, id_emisor, id_receptor))
            conexion.commit()
            return True, f"Solicitud {nuevo_estado.lower()} correctamente."
    except Exception as e:
        return False, str(e)
    finally:
        if conexion: conexion.close()

#-----------------------------------------------------------------------------------------------------
#                OBTENCION Y CAMBIO DE METADATOS COMO NOMBRE ARCHIVO, FECHA FAVORITO
#--------------------------------------------------------------------------------------------------

def renombrar_recurso_seguro(id_recurso: int, nuevo_nombre_completo: str, id_usuario: int, reemplazar: bool) -> Tuple[bool, Any]:
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        connection.autocommit = False 
        cursor = connection.cursor(dictionary=True, buffered=True)

        # 1. Obtener datos del archivo actual
        sql_info = """
            SELECT r.id, ra.id_album 
            FROM Recurso r
            LEFT JOIN Recurso_Album ra ON r.id = ra.id_recurso
            WHERE r.id = %s AND r.id_creador = %s
        """
        cursor.execute(sql_info, (id_recurso, id_usuario))
        mi_archivo = cursor.fetchone()
        
        if not mi_archivo:
            return False, "Archivo no encontrado"

        id_album = mi_archivo['id_album']

        # 2. Verificar duplicados (Añadido LIMIT 1)
        if id_album is not None:
            sql_check = """
                SELECT r.id FROM Recurso r
                JOIN Recurso_Album ra ON r.id = ra.id_recurso
                WHERE r.nombre = %s AND ra.id_album = %s AND r.id_creador = %s 
                AND r.fecha_eliminacion IS NULL AND r.id != %s
                LIMIT 1
            """
            cursor.execute(sql_check, (nuevo_nombre_completo, id_album, id_usuario, id_recurso))
        else:
            sql_check = """
                SELECT r.id FROM Recurso r
                WHERE r.nombre = %s AND r.id_creador = %s 
                AND r.fecha_eliminacion IS NULL AND r.id != %s
                AND NOT EXISTS (SELECT 1 FROM Recurso_Album ra WHERE ra.id_recurso = r.id)
                LIMIT 1
            """
            cursor.execute(sql_check, (nuevo_nombre_completo, id_usuario, id_recurso))

        otro_archivo = cursor.fetchone()

        # 3. Lógica de Colisión
        if otro_archivo:
            if not reemplazar:
                return False, "DUPLICADO"
            else:
                # El usuario confirmó reemplazar: BORRAMOS el otro archivo de la BD
                cursor.execute("DELETE FROM Recurso WHERE id = %s", (otro_archivo['id'],))
        
        # 4. Renombrar el nuestro
        sql_update = "UPDATE Recurso SET nombre = %s WHERE id = %s"
        cursor.execute(sql_update, (nuevo_nombre_completo, id_recurso))
        
        connection.commit()
        return True, "Nombre actualizado correctamente"

    except Exception as e:
        if connection: connection.rollback()
        return False, str(e)
    finally:
        if cursor: cursor.close()
        if connection: connection.close()

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

def marcar_favorito_bd(id_recurso: int, id_usuario: int, estado: bool):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        # Solo el creador puede marcar como favorito su recurso
        sql = "UPDATE Recurso SET favorito = %s WHERE id = %s AND id_creador = %s"
        cursor.execute(sql, (1 if estado else 0, id_recurso, id_usuario))
        connection.commit()
        
        if cursor.rowcount > 0:
            return True, "Estado de favorito actualizado"
        return False, "No se encontró el recurso o no tienes permiso"
    except Error as e:
        return False, str(e)
    finally:
        if connection: connection.close()

def obtener_metadatos(id_recurso: int):
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        # Usamos dictionary=True para que devuelva un JSON bonito
        cursor = connection.cursor(dictionary=True)
        
        sql = """
            SELECT dispositivo, iso, apertura, velocidad, latitud, longitud, ancho, alto 
            FROM Metadatos 
            WHERE id_recurso = %s
        """
        cursor.execute(sql, (id_recurso,))
        
        # --- LA SOLUCIÓN AL ERROR ---
        # Tienes que leer el resultado SIEMPRE, aunque sea None.
        resultado = cursor.fetchone()
        
        # Si hubiera más resultados pendientes (imposible por ser PK, pero por seguridad),
        # esto limpia el buffer:
        try: cursor.fetchall() 
        except: pass 
        
        return resultado

    except Exception as e:
        print(f"Error obteniendo metadatos: {e}")
        return None
    finally:
        # Es CRÍTICO cerrar primero el cursor y luego la conexión
        if cursor: 
            try: cursor.close()
            except: pass
        if connection and connection.is_connected(): 
            connection.close()

#------------------------------------------------------------------------------------------------------------------------
#                       BORRADO DE ARCHIVOS Y GESTION DE PAPELERA
#------------------------------------------------------------------------------------------------------

def mover_a_papelera(id_recurso: int, id_usuario: int) -> Tuple[bool, Any]:
    """Soft Delete: Marca el recurso como eliminado pero no lo borra."""
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        # Actualizamos la fecha de eliminación
        sql = "UPDATE Recurso SET fecha_eliminacion = NOW() WHERE id = %s AND id_creador = %s"
        cursor.execute(sql, (id_recurso, id_usuario))
        connection.commit()
        
        if cursor.rowcount > 0:
            return True, "Recurso movido a la papelera"
        else:
            return False, "No se encontró el recurso o no eres el creador"
    except Exception as e:
        return False, str(e)
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def obtener_papelera_bd(id_usuario: int) -> Tuple[bool, Any]:
    """Obtiene solo los recursos que ESTÁN en la papelera."""
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        sql = """
            SELECT * FROM Recurso 
            WHERE id_creador = %s AND fecha_eliminacion IS NOT NULL 
            ORDER BY fecha_eliminacion DESC
        """
        cursor.execute(sql, (id_usuario,))
        resultado = cursor.fetchall()
        
        # Opcional: Agregar URLs también aquí por si quieres mostrar miniaturas en la papelera
        for recurso in resultado:
            recurso['url_thumbnail'] = f"/recurso/archivo/{recurso['id']}?size=small"

        return True, resultado
    except Exception as e:
        return False, str(e)
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def restaurar_recurso_bd(id_recurso: int, id_usuario: int) -> Tuple[bool, Any]:
    """Recupera un recurso de la papelera."""
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        sql = "UPDATE Recurso SET fecha_eliminacion = NULL WHERE id = %s AND id_creador = %s"
        cursor.execute(sql, (id_recurso, id_usuario))
        connection.commit()
        
        if cursor.rowcount > 0:
            return True, "Restaurado"
        return False, "No se encontró en la papelera"
    except Exception as e:
        return False, str(e)
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()

def mover_a_papelera_lote(ids: List[int], id_usuario: int) -> Tuple[bool, str]:
    """Mueve una lista de recursos a la papelera en una sola transacción."""
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False 
        cursor = connection.cursor()
        
        # Convertimos la lista de ints a string para SQL: (1, 2, 3)
        # Usamos placeholders %s para seguridad
        format_strings = ','.join(['%s'] * len(ids))
        
        # Query masiva
        query = f"""
            UPDATE Recurso 
            SET fecha_eliminacion = NOW() 
            WHERE id IN ({format_strings}) AND id_creador = %s
        """
        
        # Pasamos los IDs + el id_usuario al final
        valores = tuple(ids) + (id_usuario,)
        
        cursor.execute(query, valores)
        filas_afectadas = cursor.rowcount
        
        connection.commit()
        return True, f"{filas_afectadas} archivos movidos a la papelera"
        
    except Error as e:
        if connection: connection.rollback()
        return False, str(e)
    finally:
        if connection: connection.close()

def mover_recursos_lote(ids: List[int], id_album_destino: Optional[int], id_usuario: int) -> Tuple[bool, str]:
    """
    Mueve una lista de recursos a otro álbum (o a la raíz).
    Esta lógica es más compleja porque algunos recursos pueden estar ya en álbumes y otros no.
    """
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()
        
        format_strings = ','.join(['%s'] * len(ids))
        
        # 1. Borramos las asociaciones previas de estos recursos con cualquier álbum
        # (Para sacarlos de donde estén)
        sql_delete = f"""
            DELETE FROM Recurso_Album 
            WHERE id_recurso IN ({format_strings}) 
            AND id_recurso IN (SELECT id FROM Recurso WHERE id_creador = %s)
        """
        cursor.execute(sql_delete, tuple(ids) + (id_usuario,))
        
        # 2. Si el destino NO es la raíz, insertamos las nuevas asociaciones
        if id_album_destino is not None:
            sql_insert = "INSERT INTO Recurso_Album (id_recurso, id_album) VALUES (%s, %s)"
            # Preparamos tuplas (id_recurso, id_album) para executemany
            datos_insertar = [(id_r, id_album_destino) for id_r in ids]
            cursor.executemany(sql_insert, datos_insertar)
            
        connection.commit()
        dest = "la raíz" if id_album_destino is None else "la carpeta destino"
        return True, f"Archivos movidos a {dest}"

    except Error as e:
        if connection: connection.rollback()
        return False, str(e)
    finally:
        if connection: connection.close()

#--------------------------------------------------------------------------------------------------------
#                                   SUBIDA DE ARCHIVOS
#----------------------------------------------------------------------------------------------------

def procesar_archivo_local(id_usuario: int, ruta_fisica: str, nombre_original: str, tipo: str, fecha: Optional[datetime], id_album: Optional[int], reemplazar: bool) -> Tuple[bool, Any]:
    # 1. Verificar Cuota
    try:
        tamano = os.path.getsize(ruta_fisica)
        puede, msg = verificar_espacio_usuario(id_usuario, tamano)
        if not puede:
            os.remove(ruta_fisica)
            return False, msg # Error 507
    except Exception as e:
        return False, f"Error verificando espacio: {e}"

    # 2. Verificar Duplicado (Si no es reemplazar)
    id_existente = check_recurso_existe_en_album(id_usuario, nombre_original, id_album)
    if id_existente and not reemplazar:
        os.remove(ruta_fisica)
        return False, "DUPLICADO" # Señal para error 409

    # 3. Generar Miniatura (Lógica reutilizada)
    carpeta_miniatura = "static/thumbnails"
    os.makedirs(carpeta_miniatura, exist_ok=True)
    nombre_fisico = os.path.basename(ruta_fisica)
    
    try:
        if tipo == "IMAGEN":
            ruta_thumb = os.path.join(carpeta_miniatura, nombre_fisico)
            with Image.open(ruta_fisica) as img:
                img.thumbnail((300, 300))
                if img.mode in ("RGBA", "P"): img = img.convert("RGB")
                img.save(ruta_thumb)
        elif tipo == "VIDEO":
            nombre_thumb_jpg = os.path.splitext(nombre_fisico)[0] + ".jpg"
            ruta_thumb = os.path.join(carpeta_miniatura, nombre_thumb_jpg)
            cam = cv2.VideoCapture(ruta_fisica)
            try:
                cam.set(cv2.CAP_PROP_POS_FRAMES, 10)
                ret, frame = cam.read()
                if ret:
                    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    with Image.fromarray(frame_rgb) as img:
                        img.thumbnail((300, 300))
                        img.save(ruta_thumb, format="JPEG")
            finally:
                cam.release()
    except Exception as e:
        print(f"Warning miniatura: {e}")

    metadatos_extraidos = None
    if tipo in ["IMAGEN", "VIDEO"]:
        try:
            metadatos_extraidos = utilidadesMetadatos.obtener_exif(ruta_fisica)
            if metadatos_extraidos and metadatos_extraidos.get("fecha"):
                fecha = metadatos_extraidos['fecha']
            else:
                print("No tiene fecha")
        except Exception as e:
            print(f"Error extrayendo metadatos en chunk upload: {e}")
    # 5. Guardar en BD
    if id_existente and reemplazar:
        # En caso de reemplazo, usamos el ID existente
        exito, resultado = reemplazar_recurso_simple(id_existente, ruta_fisica, tipo, tamano, fecha, id_usuario)
        if exito and metadatos_extraidos:
             # Opcional: Podrías borrar metadatos viejos antes, pero para v1 insertamos los nuevos
             guardar_metadatos(id_existente, metadatos_extraidos)
        return exito, resultado
    else:
        # Caso nuevo recurso
        exito, id_recurso = subir_recurso(id_usuario, tipo, ruta_fisica, nombre_original, tamano, fecha, id_album)
        
        # SI LA SUBIDA FUE ÉXITOSA, GUARDAMOS LOS METADATOS
        if exito and metadatos_extraidos:
            guardar_metadatos(id_recurso, metadatos_extraidos) # <--- AQUÍ SE GUARDAN
            
        return exito, id_recurso

def subir_recurso(id_creador: int, tipo: str, enlace: str, nombre: str, tamano: int, fecha_real: Optional[datetime] = None, id_album: Optional[int] = None ) -> Tuple[bool, Any]:
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False 
        if connection.is_connected():
            cursor = connection.cursor()
            query_1 = "INSERT INTO Recurso (id_creador, tipo, enlace, nombre, tamano, fecha_real) VALUES(%s,%s,%s,%s,%s,%s)"
            valores = (id_creador, tipo, enlace, nombre, tamano, fecha_real)
            cursor.execute(query_1, valores)
            id_recurso = cursor.lastrowid
            if id_album is not None:
                query_3 = "INSERT INTO Recurso_Album (id_album, id_recurso) VALUES (%s, %s)"
                cursor.execute(query_3, (id_album, id_recurso))
            connection.commit()
            return (True, id_recurso)
    except Error as e:
        if connection and connection.is_connected():
            connection.rollback()
        print(f"Error en subir recurso en MySql: {e}")
        return (False, str(e))
    finally:
        if connection is not None and connection.is_connected():
            if 'cursor' in locals(): cursor.close()
            connection.close()

def verificar_espacio_usuario(id_usuario: int, tamano_nuevo_archivo: int) -> Tuple[bool, str]:
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        sql_user = """
            SELECT P.almacenamiento_maximo, COALESCE(SUM(R.tamano), 0) as usado
            FROM Persona P
            LEFT JOIN Recurso R ON P.id = R.id_creador AND R.fecha_eliminacion IS NULL
            WHERE P.id = %s
            GROUP BY P.id
        """
        cursor.execute(sql_user, (id_usuario,))
        datos = cursor.fetchone()
        if not datos: return False, "Usuario no encontrado"
        limite_usuario = datos['almacenamiento_maximo'] # Puede ser None (Ilimitado)
        usado_usuario = datos['usado']
        total, used, free = shutil.disk_usage("static/uploads")
        if tamano_nuevo_archivo > free:
            return False, "El servidor está lleno (Espacio físico agotado)."
        if limite_usuario is not None:
            if (usado_usuario + tamano_nuevo_archivo) > limite_usuario:
                return False, "Has superado tu cuota de almacenamiento asignada."
        return True, "OK"
    except Error as e:
        return False, str(e)
    finally:
        if connection: connection.close()

def check_recurso_existe_en_album(id_usuario: int, nombre: str, id_album: Optional[int]) -> Optional[int]:
    connection = None
    cursor = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(buffered=True) 
        if id_album is not None:
            query = """
                SELECT r.id 
                FROM Recurso r
                JOIN Recurso_Album ra ON r.id = ra.id_recurso
                WHERE r.id_creador = %s 
                  AND r.nombre = %s 
                  AND ra.id_album = %s
                  AND r.fecha_eliminacion IS NULL
                LIMIT 1
            """
            cursor.execute(query, (id_usuario, nombre, id_album))
        else:
            query = """
                SELECT r.id 
                FROM Recurso r
                WHERE r.id_creador = %s 
                  AND r.nombre = %s 
                  AND r.fecha_eliminacion IS NULL
                  AND NOT EXISTS (
                      SELECT 1 FROM Recurso_Album ra WHERE ra.id_recurso = r.id
                  )
                LIMIT 1
            """
            cursor.execute(query, (id_usuario, nombre))
        row = cursor.fetchone()
        if row:
            return row[0]
        return None
    except Error as e:
        print(f"Error checking existencia: {e}")
        return None
    finally:
        if cursor: cursor.close()
        if connection and connection.is_connected(): connection.close()
    
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

def reemplazar_recurso_simple(id_recurso: int, nuevo_enlace: str, nuevo_tipo: str, nuevo_tamano: int, nueva_fecha_real: Optional[datetime], id_usuario: int) -> Tuple[bool, Any]:
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()

        cursor.execute("SELECT enlace FROM Recurso WHERE id = %s AND id_creador = %s", (id_recurso, id_usuario))
        resultado = cursor.fetchone()
        
        if not resultado:
            return False, "Recurso original no encontrado"
        ruta_vieja = resultado[0]

        # Actualizamos Hash también
        sql_update = """
            UPDATE Recurso 
            SET enlace = %s, tipo = %s, tamano = %s, fecha_real = %s, hash_archivo = %s, fecha_subida = NOW(), fecha_eliminacion = NULL
            WHERE id = %s AND id_creador = %s
        """
        cursor.execute(sql_update, (nuevo_enlace, nuevo_tipo, nuevo_tamano, nueva_fecha_real, id_recurso, id_usuario))
        
        connection.commit()
        return True, ruta_vieja

    except Error as e:
        if connection: connection.rollback()
        return False, str(e)
    finally:
        if connection: connection.close()

def guardar_metadatos(id_recurso, meta):
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        sql = """
            INSERT INTO Metadatos (id_recurso, dispositivo, iso, apertura, velocidad, latitud, longitud, ancho, alto)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(sql, (
            id_recurso, 
            meta["dispositivo"], 
            meta["iso"], 
            meta["apertura"], 
            meta["velocidad"], 
            meta["latitud"], 
            meta["longitud"],
            meta["ancho"],
            meta["alto"]
        ))
        connection.commit()
    except Exception as e:
        print(f"Error guardando metadatos: {e}")
    finally:
        if connection: connection.close()

#-------------------------------------------------------------------------------------------------------
#                       Funciones que se ejecutan de manera temporal
#----------------------------------------------------------------------------------------------------

def purgar_papelera_automatica(dias_retencion: int = 30):
    """
    Busca recursos que llevan más de 'dias_retencion' en la papelera 
    y los elimina físicamente y de la BD.
    """
    import os
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        
        # 1. Buscar archivos caducados (MySQL syntax)
        print(f"[{datetime.now()}] Ejecutando purga automática de papelera...")
        
        sql_buscar = """
            SELECT id, enlace, tipo 
            FROM Recurso 
            WHERE fecha_eliminacion IS NOT NULL 
              AND fecha_eliminacion < DATE_SUB(NOW(), INTERVAL %s DAY)
        """
        cursor.execute(sql_buscar, (dias_retencion,))
        archivos_a_borrar = cursor.fetchall()
        
        if not archivos_a_borrar:
            print("Papelera limpia. No hay archivos antiguos para borrar.")
            return

        print(f"Encontrados {len(archivos_a_borrar)} archivos antiguos para eliminar permanentemente.")

        # 2. Borrar archivos físicos
        ids_a_borrar = []
        for recurso in archivos_a_borrar:
            ids_a_borrar.append(recurso['id'])
            
            # Borrar Original
            ruta_original = recurso['enlace']
            try:
                if os.path.exists(ruta_original):
                    os.remove(ruta_original)
            except Exception as e:
                print(f"Error borrando físico {ruta_original}: {e}")

            # Borrar Miniatura
            try:
                ruta_thumb = ruta_original.replace("uploads", "thumbnails")
                if os.path.exists(ruta_thumb):
                    os.remove(ruta_thumb)
                else:
                    # Intentar con extensión jpg por si acaso (para videos)
                    nombre_sin_ext = os.path.splitext(ruta_thumb)[0]
                    ruta_thumb_jpg = nombre_sin_ext + ".jpg"
                    if os.path.exists(ruta_thumb_jpg):
                        os.remove(ruta_thumb_jpg)
            except Exception as e:
                print(f"Error borrando thumbnail de {recurso['id']}: {e}")

        # 3. Borrar de la Base de Datos (En lote)
        if ids_a_borrar:
            format_strings = ','.join(['%s'] * len(ids_a_borrar))
            sql_delete = f"DELETE FROM Recurso WHERE id IN ({format_strings})"
            cursor.execute(sql_delete, tuple(ids_a_borrar))
            connection.commit()
            print(f"Eliminados {cursor.rowcount} registros de la base de datos correctamente.")

    except Exception as e:
        print(f"Error CRÍTICO en purga automática: {e}")
    finally:
        if connection and connection.is_connected():
            connection.close()