import db
from mysql.connector import Error
from datetime import datetime, timedelta

def verificar_ip_bloqueada(ip: str):
    """
    Retorna (True, None) si la IP puede intentar loggearse.
    Retorna (False, mensaje) si la IP está bloqueada.
    """
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor(dictionary=True)
        
        query = "SELECT intentos, bloqueado_hasta FROM Control_Acceso WHERE ip = %s"
        cursor.execute(query, (ip,))
        resultado = cursor.fetchone()
        
        if not resultado:
            return (True, None) # No tiene registro, pase
            
        bloqueado_hasta = resultado['bloqueado_hasta']
        
        # Si tiene fecha de bloqueo, verificamos si ya expiró
        if bloqueado_hasta:
            if datetime.now() < bloqueado_hasta:
                tiempo_restante = int((bloqueado_hasta - datetime.now()).total_seconds() / 60)
                return (False, f"IP bloqueada temporalmente. Intente en {tiempo_restante} minutos.")
            else:
                # El bloqueo expiró, reseteamos
                limpiar_intentos(ip)
                return (True, None)
                
        return (True, None)

    except Error as e:
        print(f"Error verificando IP: {e}")
        # En caso de error de BD, por seguridad solemos dejar pasar o bloquear según política.
        # Aquí dejaremos pasar para no bloquear servicio por fallo de BD.
        return (True, None) 
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def registrar_intento_fallido(ip: str):
    """
    Incrementa el contador de fallos. Si llega a 5, bloquea por 30 minutos.
    """
    connection = None
    try:
        connection = db.get_connection()
        connection.autocommit = False
        cursor = connection.cursor()
        
        # 1. Verificar si ya existe
        check_query = "SELECT intentos FROM Control_Acceso WHERE ip = %s"
        cursor.execute(check_query, (ip,))
        resultado = cursor.fetchone()
        
        if resultado:
            nuevos_intentos = resultado[0] + 1
            if nuevos_intentos >= 5:
                # BLOQUEAR: Fecha actual + 30 minutos
                fecha_bloqueo = datetime.now() + timedelta(minutes=30)
                update_query = "UPDATE Control_Acceso SET intentos=%s, bloqueado_hasta=%s WHERE ip=%s"
                cursor.execute(update_query, (nuevos_intentos, fecha_bloqueo, ip))
            else:
                # Solo incrementar
                update_query = "UPDATE Control_Acceso SET intentos=%s WHERE ip=%s"
                cursor.execute(update_query, (nuevos_intentos, ip))
        else:
            # Crear primer registro
            insert_query = "INSERT INTO Control_Acceso (ip, intentos) VALUES (%s, 1)"
            cursor.execute(insert_query, (ip,))
            
        connection.commit()
    except Error as e:
        print(f"Error registrando fallo: {e}")
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

def limpiar_intentos(ip: str):
    """
    Borra el registro o resetea contador tras un login exitoso.
    """
    connection = None
    try:
        connection = db.get_connection()
        cursor = connection.cursor()
        query = "DELETE FROM Control_Acceso WHERE ip = %s"
        cursor.execute(query, (ip,))
        connection.commit()
    except Error as e:
        print(f"Error limpiando intentos: {e}")
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()