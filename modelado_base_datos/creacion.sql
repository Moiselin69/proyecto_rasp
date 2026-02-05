DROP TRIGGER IF EXISTS borrar_recurso_huerfano;
DROP TABLE IF EXISTS Peticion_Amistad;
DROP TABLE IF EXISTS Peticion_Recurso;
DROP TABLE IF EXISTS Peticion_Album;
DROP TABLE IF EXISTS Persona_Amiga; 
DROP TABLE IF EXISTS Recurso_Album;
DROP TABLE IF EXISTS Miembro_Album;
DROP TABLE IF EXISTS Recurso_Persona;
DROP TABLe IF EXISTS Control_Acceso;
DROP TABLE IF EXISTS Recurso;
DROP TABLE IF EXISTS Album;
DROP TABLE IF EXISTS Persona;


CREATE TABLE Persona(
	id INT AUTO_INCREMENT,
	correo_electronico VARCHAR(320) NOT NULL UNIQUE,
	contra_hash VARCHAR(320) NOT NULL,
	nombre VARCHAR(100) NOT NULL,
	apellidos VARCHAR(100),
	fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT pk_id PRIMARY KEY (id)
)ENGINE=InnoDB;

CREATE TABLE Persona_Amiga(
	id_persona_1 INT NOT NULL,
	id_persona_2 INT NOT NULL,
	CONSTRAINT pk_persona_amiga PRIMARY KEY(id_persona_1, id_persona_2),
	CONSTRAINT fk_persona_amiga_1 FOREIGN KEY(id_persona_1) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT fk_persona_amiga_2 FOREIGN KEY(id_persona_2) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT chk_no_auto_amistad CHECK (id_persona_1 <> id_persona_2)
)ENGINE=InnoDB;

CREATE TABLE Recurso(
	id INT AUTO_INCREMENT NOT NULL,
	id_creador INT,
	tipo ENUM ('IMAGEN','VIDEO','AUDIO','ARCHIVO') NOT NULL,
	enlace VARCHAR(320) NOT NULL,
	nombre VARCHAR(100),
	fecha_real DATETIME,
	fecha_subida TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT pk_recurso PRIMARY KEY(id),
	CONSTRAINT fk_recurso_creador FOREIGN KEY (id_creador) REFERENCES Persona(id) ON DELETE SET NULL
)ENGINE=InnoDB;

CREATE TABLE Recurso_Persona(
	id_recurso INT NOT NULL,
	id_persona INT NOT NULL,
	CONSTRAINT pk_recurso_persona PRIMARY KEY(id_recurso, id_persona),
	CONSTRAINT fk_recurso_persona_recurso FOREIGN KEY(id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE,
	CONSTRAINT fk_recurso_persona_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Album(
	id INT AUTO_INCREMENT,
	nombre VARCHAR(100) NOT NULL,
	descripcion VARCHAR(300),
	id_album_padre INT NULL,
	fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT pk_album PRIMARY KEY(id),
	CONSTRAINT fk_album_padre FOREIGN KEY(id_album_padre) REFERENCES Album(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Miembro_Album(
	id_album INT NOT NULL,
	id_persona INT NOT NULL,
	rol ENUM('CREADOR', 'ADMINISTRADOR', 'COLABORADOR') NOT NULL DEFAULT 'COLABORADOR',
	fecha_union TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	CONSTRAINT pk_miembro_album PRIMARY KEY(id_album, id_persona),
	CONSTRAINT fk_miembro_album_album FOREIGN KEY(id_album) REFERENCES Album(id) ON DELETE CASCADE,
	CONSTRAINT fk_miembro_album_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Recurso_Album(
	id_album INT NOT NULL,
	id_recurso INT NOT NULL,
	CONSTRAINT pk_recurso_album PRIMARY KEY(id_album, id_recurso),
	CONSTRAINT fk_recurso_album_album FOREIGN KEY(id_album) REFERENCES Album(id) ON DELETE CASCADE,
	CONSTRAINT fk_recurso_album_recurso FOREIGN KEY(id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Peticion_Amistad(
	id_persona INT NOT NULL,
	id_persona_solicitada INT NOT NULL,
	CONSTRAINT pk_peticion_amistad PRIMARY KEY(id_persona,id_persona_solicitada),
	CONSTRAINT fk_peticion_amistad_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT fk_peticion_amistad_persona_solicitada FOREIGN KEY(id_persona_solicitada) REFERENCES Persona(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Peticion_Album(
	id_persona INT NOT NULL,
	id_persona_compartida INT NOT NULL,
	id_album INT NOT NULL,
	rol ENUM('CREADOR', 'ADMINISTRADOR', 'COLABORADOR') NOT NULL DEFAULT 'COLABORADOR',
	CONSTRAINT pk_peticion_album PRIMARY KEY(id_persona,id_persona_compartida,id_album),
	CONSTRAINT fk_peticion_album_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT fk_peticion_album_persona_compartida FOREIGN KEY(id_persona_compartida) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT fk_peticion_album_album FOREIGN KEY(id_album) REFERENCES Album(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Peticion_Recurso(
	id_persona INT NOT NULL,
	id_persona_compartida INT NOT NULL,
	id_recurso INT NOT NULL,
	CONSTRAINT pk_peticion_recurso PRIMARY KEY(id_persona,id_persona_compartida,id_recurso),
	CONSTRAINT fk_peticion_recurso_persona FOREIGN KEY(id_persona) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT fk_peticion_recurso_persona_compartida FOREIGN KEY(id_persona_compartida) REFERENCES Persona(id) ON DELETE CASCADE,
	CONSTRAINT fk_peticion_recurso_recurso FOREIGN KEY(id_recurso) REFERENCES Recurso(id) ON DELETE CASCADE
)ENGINE=InnoDB;

CREATE TABLE Control_Acceso (
    ip VARCHAR(45) NOT NULL,
    intentos INT DEFAULT 0,
    bloqueado_hasta DATETIME DEFAULT NULL,
    ultimo_intento TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (ip)
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

CREATE PROCEDURE salir_de_album(IN p_id_album INT, IN p_id_persona INT)
BEGIN
    DECLARE v_rol_usuario ENUM('CREADOR', 'ADMINISTRADOR', 'COLABORADOR');
    DECLARE v_conteo_admins INT;
    SELECT rol INTO v_rol_usuario FROM Miembro_Album WHERE id_album = p_id_album AND id_persona = p_id_persona;
    DELETE FROM Miembro_Album WHERE id_album = p_id_album AND id_persona = p_id_persona;
    IF v_rol_usuario IN ('CREADOR', 'ADMINISTRADOR') THEN
        SELECT COUNT(*) INTO v_conteo_admins 
        FROM Miembro_Album 
        WHERE id_album = p_id_album AND rol IN ('ADMINISTRADOR', 'CREADOR');
        IF v_conteo_admins = 0 THEN
            UPDATE Miembro_Album SET rol = 'ADMINISTRADOR' WHERE id_album = p_id_album AND id_persona = 
				( SELECT id_persona FROM 
					(SELECT id_persona FROM Miembro_Album WHERE id_album = p_id_album ORDER BY fecha_union ASC LIMIT 1) AS subquery
            	);
        END IF;
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

DELIMITER ;	