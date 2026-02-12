import os
import mysql.connector
from mysql.connector import pooling
from dotenv import load_dotenv
load_dotenv()
db_config = {
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'host': os.getenv('DB_HOST'),
    'database': 'moiselincloud',
    'port': 3306
}
connection_pool = mysql.connector.pooling.MySQLConnectionPool(
    pool_name="moiselin_pool",
    pool_size=100,
    pool_reset_session=True,
    **db_config
)
def get_connection():
    try:
        connection = connection_pool.get_connection()
        return connection
    except mysql.connector.Error as err:
        print(f"Error obteniendo conexión del pool: {err}")
        return None