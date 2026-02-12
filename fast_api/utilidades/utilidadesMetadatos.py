import re
from datetime import datetime
from PIL import Image, ExifTags
from pillow_heif import register_heif_opener
import ffmpeg 

# Registrar soporte HEIC
register_heif_opener()

def convertir_a_grados(value):
    """Convierte coordenadas EXIF de fotos (tupla) a decimal"""
    try:
        d = float(value[0])
        m = float(value[1])
        s = float(value[2])
        return d + (m / 60.0) + (s / 3600.0)
    except Exception:
        return 0.0

def parsear_gps_video(location_string):
    """Parsea formato ISO-6709 de vídeos (+37.77-122.41/)"""
    try:
        match = re.match(r"([+-][0-9.]+)([+-][0-9.]+)", location_string)
        if match:
            return float(match.group(1)), float(match.group(2))
    except Exception:
        pass
    return None, None

def parsear_fecha_imagen(fecha_str):
    """Convierte formato EXIF '2023:12:31 23:59:59' a objeto datetime"""
    try:
        # El formato estándar EXIF es YYYY:MM:DD HH:MM:SS
        return datetime.strptime(fecha_str, "%Y:%m:%d %H:%M:%S")
    except Exception:
        return None

def parsear_fecha_video(fecha_str):
    """Convierte formato ISO '2023-12-31T23:59:59.000000Z' a datetime"""
    try:
        # A veces viene con Z (UTC), a veces sin milisegundos.
        # Simplificamos reemplazando la T y quitando la Z para parsear
        limpia = fecha_str.replace("T", " ").replace("Z", "")
        # Quitamos milisegundos si los hay (cortamos en el punto)
        if "." in limpia: limpia = limpia.split(".")[0]
        return datetime.strptime(limpia, "%Y-%m-%d %H:%M:%S")
    except Exception:
        return None

def obtener_exif(ruta_archivo):
    metadatos = {
        "dispositivo": None, "iso": None, "apertura": None,
        "velocidad": None, "latitud": None, "longitud": None,
        "ancho": 0, "alto": 0,
        "fecha": None # <--- NUEVO CAMPO
    }

    es_video = ruta_archivo.lower().endswith(('.mp4', '.mov', '.avi', '.mkv'))

    if es_video:
        try:
            probe = ffmpeg.probe(ruta_archivo)
            video_stream = next((s for s in probe['streams'] if s['codec_type'] == 'video'), None)
            format_tags = probe.get('format', {}).get('tags', {})

            if video_stream:
                metadatos["ancho"] = int(video_stream.get('width', 0))
                metadatos["alto"] = int(video_stream.get('height', 0))
                # Intentar sacar fecha del stream si no está en format
                stream_tags = video_stream.get('tags', {})
                date_str = format_tags.get('creation_time') or stream_tags.get('creation_time')
                if date_str:
                    metadatos["fecha"] = parsear_fecha_video(date_str)
            
            make = format_tags.get('com.android.manufacturer') or format_tags.get('make') or ""
            model = format_tags.get('com.android.model') or format_tags.get('model') or ""
            if make or model: metadatos["dispositivo"] = f"{make} {model}".strip()

            location = format_tags.get('location') or format_tags.get('com.apple.quicktime.location.ISO6709')
            if location:
                lat, lon = parsear_gps_video(location)
                metadatos["latitud"] = lat
                metadatos["longitud"] = lon

        except Exception as e:
            print(f"Error metadatos video: {e}")
        return metadatos

    # --- IMAGEN ---
    try:
        with Image.open(ruta_archivo) as img:
            metadatos["ancho"], metadatos["alto"] = img.size
            exif_obj = img.getexif()
            
            if not exif_obj:
                if hasattr(img, '_getexif') and img._getexif(): exif_data_raw = img._getexif()
                else: return metadatos
            else:
                exif_data_raw = exif_obj

            exif_dict = { ExifTags.TAGS.get(k, k): v for k, v in exif_data_raw.items() }

            # 1. FECHA (DateTimeOriginal es ID 36867)
            # Primero buscamos por nombre, luego por ID si no sale
            fecha_str = exif_dict.get("DateTimeOriginal") or exif_dict.get(36867) or exif_dict.get("DateTime")
            if fecha_str:
                metadatos["fecha"] = parsear_fecha_imagen(str(fecha_str))

            # Resto de datos...
            make = exif_dict.get("Make", "").strip()
            model = exif_dict.get("Model", "").strip()
            if model: metadatos["dispositivo"] = f"{make} {model}".strip()
            
            metadatos["iso"] = exif_dict.get("ISOSpeedRatings")
            f_num = exif_dict.get("FNumber")
            if f_num: 
                try: metadatos["apertura"] = f"f/{float(f_num)}"
                except: pass
            exp = exif_dict.get("ExposureTime")
            if exp: metadatos["velocidad"] = f"{exp}s"

            gps_info = {}
            if "GPSInfo" in exif_dict and isinstance(exif_dict["GPSInfo"], dict): gps_info = exif_dict["GPSInfo"]
            elif hasattr(exif_obj, 'get_ifd'):
                try: gps_info = exif_obj.get_ifd(0x8825)
                except: pass

            if gps_info and isinstance(gps_info, dict):
                if 2 in gps_info and 1 in gps_info:
                    lat = convertir_a_grados(gps_info[2])
                    if gps_info[1] == 'S': lat = -lat
                    metadatos["latitud"] = lat
                if 4 in gps_info and 3 in gps_info:
                    lon = convertir_a_grados(gps_info[4])
                    if gps_info[3] == 'W': lon = -lon
                    metadatos["longitud"] = lon

    except Exception as e:
        print(f"Error metadatos imagen: {e}")
    
    return metadatos