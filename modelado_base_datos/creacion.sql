/* ==========================================================
   ORDEN DE BORRADO (Hijos primero para evitar errores de FK)
   ========================================================== */
DROP TRIGGER IF EXISTS borrar_recurso_huerfano;

-- Tablas dependientes de Recurso, Album o Persona
DROP TABLE IF EXISTS Metadatos;
DROP TABLE IF EXISTS EnlacePublico_Contenido;
DROP TABLE IF EXISTS EnlacePublico;
DROP TABLE IF EXISTS Recurso_Compartido;
DROP TABLE IF EXISTS Peticion_Recurso;
DROP TABLE IF EXISTS Recurso_Album;
DROP TABLE IF EXISTS Recurso_Persona;

-- Tablas dependientes de Album o Persona
DROP TABLE IF EXISTS Peticion_Album;
DROP TABLE IF EXISTS Miembro_Album;
DROP TABLE IF EXISTS Album;

-- Tablas de Relación de Personas y Seguridad
DROP TABLE IF EXISTS Amistad; -- Unificada (antes Peticion_Amistad y Persona_Amiga)
DROP TABLE IF EXISTS Control_Acceso;

-- Tablas Principales
DROP TABLE IF EXISTS Recurso;
DROP TABLE IF EXISTS Persona;


/* ==========================================================
   CREACIÓN DE TABLAS
   ========================================================== */

CREATE TABLE Persona(
    id INT AUTO_INCREMENT,
    correo_electronico VARCHAR(320) NOT NULL UNIQUE,
    contrasena VARCHAR(320) NOT NULL, -- Corregido: Coincide con consultasPersona.py
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100),
    nickname VARCHAR(50) UNIQUE,      -- Añadido: Se usa en registro y búsquedas
    fecha_nacimiento DATE,            -- Añadido: Se usa en registro
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_eliminacion DATETIME DEFAULT NULL,
    rol ENUM('USUARIO', 'ADMINISTRADOR') DEFAULT 'USUARIO',
    almacenamiento_maximo BIGINT DEFAULT NULL, -- NULL = Ilimitado
    CONSTRAINT pk_id PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE Amistad(
    id_persona1 INT NOT NULL,
    id_persona2 INT NOT NULL,
    estado ENUM('PENDIENTE', 'ACEPTADA') DEFAULT 'PENDIENTE',
    fecha_accion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_amistad PRIMARY KEY(id_persona1, id_persona2),
    CONSTRAINT fk_amistad_1 FOREIGN KEY(id_persona1) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT fk_amistad_2 FOREIGN KEY(id_persona2) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT chk_no_auto_amistad CHECK (id_persona1 <> id_persona2)
) ENGINE=InnoDB;

CREATE TABLE Recurso(
    id INT AUTO_INCREMENT NOT NULL,
    id_creador INT,
    tipo ENUM ('IMAGEN','VIDEO','AUDIO','ARCHIVO') NOT NULL,
    enlace VARCHAR(320) NOT NULL,
    nombre VARCHAR(100),
    fecha_real DATETIME,
    fecha_subida TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_eliminacion DATETIME DEFAULT NULL,
    tamano BIGINT DEFAULT 0,
    favorito BOOLEAN DEFAULT 0,
    CONSTRAINT pk_recurso PRIMARY KEY(id),
    CONSTRAINT fk_recurso_creador FOREIGN KEY (id_creador) REFERENCES Persona(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE Recurso_Persona(
    id_recurso INT NOT NULL,
    id_persona INT NOT NULL,
    CONSTRAINT pk_recurso_persona PRIMARY KEY(id_recurso, id_persona),
    CONSTRAINT fk_recurso_persona_recurso FOREIGN KEY(id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE,
    CONSTRAINT fk_recurso_persona_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Album(
    id INT AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(300),
    id_album_padre INT NULL,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_eliminacion DATETIME DEFAULT NULL,
    CONSTRAINT pk_album PRIMARY KEY(id),
    CONSTRAINT fk_album_padre FOREIGN KEY(id_album_padre) REFERENCES Album(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Miembro_Album(
    id_album INT NOT NULL,
    id_persona INT NOT NULL,
    rol ENUM('CREADOR', 'ADMINISTRADOR', 'COLABORADOR') NOT NULL DEFAULT 'COLABORADOR',
    fecha_union TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_miembro_album PRIMARY KEY(id_album, id_persona),
    CONSTRAINT fk_miembro_album_album FOREIGN KEY(id_album) REFERENCES Album(id) ON DELETE CASCADE,
    CONSTRAINT fk_miembro_album_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Recurso_Album(
    id_album INT NOT NULL,
    id_recurso INT NOT NULL,
    CONSTRAINT pk_recurso_album PRIMARY KEY(id_album, id_recurso),
    CONSTRAINT fk_recurso_album_album FOREIGN KEY(id_album) REFERENCES Album(id) ON DELETE CASCADE,
    CONSTRAINT fk_recurso_album_recurso FOREIGN KEY(id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Peticion_Album(
    id_persona INT NOT NULL,
    id_persona_compartida INT NOT NULL,
    id_album INT NOT NULL,
    rol ENUM('CREADOR', 'ADMINISTRADOR', 'COLABORADOR') NOT NULL DEFAULT 'COLABORADOR',
    CONSTRAINT pk_peticion_album PRIMARY KEY(id_persona,id_persona_compartida,id_album),
    CONSTRAINT fk_peticion_album_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT fk_peticion_album_compartida FOREIGN KEY(id_persona_compartida) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT fk_peticion_album_album FOREIGN KEY(id_album) REFERENCES Album(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Peticion_Recurso(
    id_persona INT NOT NULL,
    id_persona_compartida INT NOT NULL,
    id_recurso INT NOT NULL,
    estado ENUM('PENDIENTE', 'ACEPTADA', 'RECHAZADA') DEFAULT 'PENDIENTE',
    fecha_solicitud DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_peticion_recurso PRIMARY KEY(id_persona,id_persona_compartida,id_recurso),
    CONSTRAINT fk_peticion_recurso_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT fk_peticion_recurso_compartida FOREIGN KEY(id_persona_compartida) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT fk_peticion_recurso_recurso FOREIGN KEY(id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Control_Acceso (
    ip VARCHAR(45) NOT NULL,
    intentos INT DEFAULT 0,
    bloqueado_hasta DATETIME DEFAULT NULL,
    ultimo_intento TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (ip)
) ENGINE=InnoDB;

CREATE TABLE Recurso_Compartido (
    id_recurso INT NOT NULL,
    id_emisor INT NOT NULL,
    id_receptor INT NOT NULL,
    fecha_compartido DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_recurso_compartido PRIMARY KEY(id_recurso, id_emisor, id_receptor),
    CONSTRAINT fk_recurso_compartido_recurso FOREIGN KEY (id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE,
    CONSTRAINT fk_recurso_compartido_emisor FOREIGN KEY (id_emisor) REFERENCES Persona(id) ON DELETE CASCADE,
    CONSTRAINT fk_recurso_compartido_receptor FOREIGN KEY (id_receptor) REFERENCES Persona(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE EnlacePublico (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token VARCHAR(64) UNIQUE NOT NULL,
    id_recurso INT NULL,
    id_album INT NULL,
    id_creador INT NOT NULL,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME NULL,
    password_hash VARCHAR(255) NULL,
    veces_usado INT DEFAULT 0,
    CONSTRAINT fk_enlace_recurso FOREIGN KEY (id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE,
    CONSTRAINT fk_enlace_album FOREIGN KEY (id_album) REFERENCES Album(id) ON DELETE CASCADE,
    CONSTRAINT fk_enlace_creador FOREIGN KEY (id_creador) REFERENCES Persona(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE EnlacePublico_Contenido (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_enlace INT NOT NULL,
    id_recurso INT NULL,
    id_album INT NULL,
    CONSTRAINT fk_contenido_enlace FOREIGN KEY (id_enlace) REFERENCES EnlacePublico(id) ON DELETE CASCADE,
    CONSTRAINT fk_contenido_recurso FOREIGN KEY (id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE,
    CONSTRAINT fk_contenido_album FOREIGN KEY (id_album) REFERENCES Album(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Metadatos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_recurso INT NOT NULL,
    dispositivo VARCHAR(100) NULL,
    iso INT NULL,
    apertura VARCHAR(20) NULL,
    velocidad VARCHAR(20) NULL,
    latitud DECIMAL(10, 8) NULL,
    longitud DECIMAL(11, 8) NULL,
    ancho INT NULL,
    alto INT NULL,
    CONSTRAINT fk_metadatos_recurso FOREIGN KEY (id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE
) ENGINE=InnoDB;

DELIMITER //

CREATE TRIGGER crear_relacion_autor
AFTER INSERT ON Recurso
FOR EACH ROW
BEGIN
    IF NEW.id_creador IS NOT NULL THEN
        INSERT INTO Recurso_Persona (id_recurso, id_persona) 
        VALUES (NEW.id, NEW.id_creador);
    END IF;
END //

CREATE TRIGGER borrar_recurso_huerfano
AFTER DELETE ON Recurso_Persona
FOR EACH ROW
BEGIN
    DECLARE conteo INT;
    SELECT COUNT(*) INTO conteo FROM Recurso_Persona WHERE id_recurso = OLD.id_recurso;
    IF conteo = 0 THEN
        DELETE FROM Recurso WHERE id = OLD.id_recurso;
    END IF;
END //

CREATE PROCEDURE MoverAlbumSeguro(IN p_album_id INT, IN p_nuevo_padre_id INT,OUT p_resultado VARCHAR(255))
BEGIN
    DECLARE v_padre_actual INT;
    DECLARE v_error BOOL DEFAULT FALSE;
    IF p_album_id = p_nuevo_padre_id THEN -- 1. Verificación básica: No mover dentro de sí mismo
        SET p_resultado = 'ERROR: No puedes mover una carpeta dentro de sí misma.';
        SET v_error = TRUE;
    END IF;
    SET v_padre_actual = p_nuevo_padre_id;-- 2. Verificación de Bucle: Subir por el árbol genealógico
    WHILE v_padre_actual IS NOT NULL AND v_error = FALSE DO -- Empezamos mirando el destino donde queremos poner la carpeta
        IF v_padre_actual = p_album_id THEN -- Si en algún momento subiendo hacia arriba nos encontramos con la carpeta que estamos moviendo...
            SET p_resultado = 'ERROR: Movimiento circular detectado. No puedes mover un padre dentro de su hijo.';
            SET v_error = TRUE;
        END IF;
        IF v_error = FALSE THEN -- Subimos un nivel más (buscamos al abuelo)
            SELECT album_padre_id INTO v_padre_actual 
            FROM albumes 
            WHERE id = v_padre_actual;
        END IF;
    END WHILE;
    IF v_error = FALSE THEN -- 3. Si no hubo error, hacemos el UPDATE
        UPDATE albumes SET album_padre_id = p_nuevo_padre_id WHERE id = p_album_id;
        SET p_resultado = 'OK';
    END IF;
END //

CREATE PROCEDURE salir_de_album(IN p_id_album INT, IN p_id_persona INT)
BEGIN
    DECLARE v_rol_usuario ENUM('CREADOR', 'ADMINISTRADOR', 'COLABORADOR');
    DECLARE v_conteo_admins INT;
    DECLARE v_miembros_restantes INT;

    -- 1. Guardamos el rol antes de borrar, por si hay que promover a alguien
    SELECT rol INTO v_rol_usuario 
    FROM Miembro_Album 
    WHERE id_album = p_id_album AND id_persona = p_id_persona;

    -- 2. Eliminamos al usuario del álbum
    DELETE FROM Miembro_Album 
    WHERE id_album = p_id_album AND id_persona = p_id_persona;

    -- 3. Comprobamos cuántas personas quedan (LÓGICA NUEVA)
    SELECT COUNT(*) INTO v_miembros_restantes 
    FROM Miembro_Album 
    WHERE id_album = p_id_album;

    IF v_miembros_restantes = 0 THEN
        -- CASO A: Si no queda nadie, eliminamos el álbum por completo
        -- (El ON DELETE CASCADE de la BBDD limpiará peticiones y otros datos vinculados)
        DELETE FROM Album WHERE id = p_id_album;
    ELSE
        -- CASO B: Si queda gente, ejecutamos la lógica de herencia de administración
        IF v_rol_usuario IN ('CREADOR', 'ADMINISTRADOR') THEN
            SELECT COUNT(*) INTO v_conteo_admins 
            FROM Miembro_Album 
            WHERE id_album = p_id_album AND rol IN ('ADMINISTRADOR', 'CREADOR');
            
            -- Si no quedan administradores, el miembro más antiguo hereda el rol
            IF v_conteo_admins = 0 THEN
                UPDATE Miembro_Album 
                SET rol = 'ADMINISTRADOR' 
                WHERE id_album = p_id_album AND id_persona = 
                    ( SELECT id_persona FROM 
                        (SELECT id_persona FROM Miembro_Album WHERE id_album = p_id_album ORDER BY fecha_union ASC LIMIT 1) AS subquery
                    );
            END IF;
        END IF;
    END IF;

END //

DELIMITER ;	