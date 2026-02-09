from PIL import Image, ExifTags
from pillow_heif import register_heif_opener
import os
register_heif_opener()
def convertir_a_grados(value):
    """Ayuda a convertir la tupla GPS (Grados, Minutos, Segundos) a float"""
    d = float(value[0])
    m = float(value[1])
    s = float(value[2])
    return d + (m / 60.0) + (s / 3600.0)

def obtener_exif(ruta_archivo):
    metadatos = {
        "dispositivo": None,
        "iso": None,
        "apertura": None,
        "velocidad": None,
        "latitud": None,
        "longitud": None,
        "ancho": 0,
        "alto": 0
    }

    try:
        with Image.open(ruta_archivo) as img:
            metadatos["ancho"], metadatos["alto"] = img.size
            exif_data = img._getexif()

            if not exif_data:
                return metadatos

            # Mapeamos los IDs numéricos de EXIF a nombres legibles
            exif = {
                ExifTags.TAGS[k]: v
                for k, v in exif_data.items()
                if k in ExifTags.TAGS
            }

            # 1. Dispositivo (Marca + Modelo)
            make = exif.get("Make", "").strip()
            model = exif.get("Model", "").strip()
            if model:
                metadatos["dispositivo"] = f"{make} {model}".strip()

            # 2. Datos Fotográficos
            metadatos["iso"] = exif.get("ISOSpeedRatings")
            
            f_number = exif.get("FNumber")
            if f_number:
                metadatos["apertura"] = f"f/{float(f_number)}"

            exposure = exif.get("ExposureTime")
            if exposure:
                metadatos["velocidad"] = f"{exposure}s"

            # 3. GPS (Esto es lo complicado)
            gps_info = exif.get("GPSInfo")
            if gps_info:
                # GPSInfo devuelve un diccionario con llaves numéricas
                # 1: 'N'/'S', 2: ((grados),(min),(seg)), 3: 'E'/'W', 4: ((grados)...)
                
                # Latitud
                if 2 in gps_info and 1 in gps_info:
                    lat = convertir_a_grados(gps_info[2])
                    if gps_info[1] == 'S': lat = -lat
                    metadatos["latitud"] = lat

                # Longitud
                if 4 in gps_info and 3 in gps_info:
                    lon = convertir_a_grados(gps_info[4])
                    if gps_info[3] == 'W': lon = -lon
                    metadatos["longitud"] = lon

    except Exception as e:
        print(f"Error extrayendo EXIF de {ruta_archivo}: {e}")
    
    return metadatos