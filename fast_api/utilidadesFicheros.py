import os
import shutil

UPLOAD_TEMP_DIR = "static/temp_chunks"

def iniciar_carga_chunk(upload_id: str):
    path = os.path.join(UPLOAD_TEMP_DIR, upload_id)
    os.makedirs(path, exist_ok=True)
    return path

def guardar_chunk(upload_id: str, index: int, file_bytes):
    path = os.path.join(UPLOAD_TEMP_DIR, upload_id)
    # Guardamos como part_0, part_1, etc.
    chunk_name = f"part_{index}"
    with open(os.path.join(path, chunk_name), "wb") as f:
        f.write(file_bytes)

def ensamblar_archivo(upload_id: str, nombre_final: str, total_chunks: int) -> str:
    temp_path = os.path.join(UPLOAD_TEMP_DIR, upload_id)
    final_dir = "static/uploads"
    os.makedirs(final_dir, exist_ok=True)
    
    # Generar nombre único final (manteniendo extensión)
    import uuid
    _, ext = os.path.splitext(nombre_final)
    nombre_fisico = f"{uuid.uuid4()}{ext}"
    ruta_final = os.path.join(final_dir, nombre_fisico)

    with open(ruta_final, "wb") as outfile:
        for i in range(total_chunks):
            chunk_path = os.path.join(temp_path, f"part_{i}")
            if not os.path.exists(chunk_path):
                raise Exception(f"Falta el trozo {i}")
            
            with open(chunk_path, "rb") as infile:
                shutil.copyfileobj(infile, outfile)
    
    # Limpiar temporales
    shutil.rmtree(temp_path)
    return ruta_final