-- =====================================================================
-- FreshMarket: esquema de la base de datos (SQLite).
--
-- Se ejecuta al arrancar el backend (todo es IF NOT EXISTS, así que se
-- puede correr muchas veces) o a mano con:  npm run bd:crear
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- Catálogo del almacén. El precio es en pesos enteros.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS productos (
  id           TEXT    PRIMARY KEY,
  nombre       TEXT    NOT NULL CHECK (length(trim(nombre)) BETWEEN 1 AND 80),
  precio       INTEGER NOT NULL CHECK (precio > 0),
  categoria    TEXT    NOT NULL CHECK (categoria IN
                 ('Almacén', 'Lácteos', 'Panadería', 'Verdulería',
                  'Bebidas', 'Limpieza', 'Otros')),
  emoji        TEXT    NOT NULL DEFAULT '🛒',
  descripcion  TEXT    NOT NULL DEFAULT '',
  disponible   INTEGER NOT NULL DEFAULT 1 CHECK (disponible IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_productos_categoria ON productos (categoria);

-- ---------------------------------------------------------------------
-- Pedidos. "numero" es el que ve el cliente (#1001, #1002...).
-- "items" guarda una foto del pedido en JSON: si mañana cambia un precio,
-- el pedido de hoy no cambia.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pedidos (
  numero       INTEGER PRIMARY KEY AUTOINCREMENT,
  id           TEXT    NOT NULL UNIQUE,
  metodo_pago  TEXT    NOT NULL CHECK (metodo_pago IN
                 ('debito', 'credito', 'billeteraMercadoPago', 'efectivo')),
  items        TEXT    NOT NULL,
  total        INTEGER NOT NULL CHECK (total > 0),
  direccion    TEXT    NOT NULL,
  destino_lat  REAL    CHECK (destino_lat BETWEEN -90 AND 90),
  destino_lng  REAL    CHECK (destino_lng BETWEEN -180 AND 180),
  estado_pago  TEXT    NOT NULL CHECK (estado_pago IN
                 ('pendiente', 'aprobado', 'rechazado')),
  aprobado_en  INTEGER,
  entregado    INTEGER NOT NULL DEFAULT 0 CHECK (entregado IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_pedidos_estado ON pedidos (estado_pago, entregado);

-- ---------------------------------------------------------------------
-- Última posición GPS del repartidor para cada pedido en camino.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS posiciones (
  pedido_id  TEXT    PRIMARY KEY REFERENCES pedidos (id) ON DELETE CASCADE,
  lat        REAL    NOT NULL,
  lng        REAL    NOT NULL,
  nombre     TEXT    NOT NULL,
  en         INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- Cuentas del almacén (dueño y repartidores). Los clientes compran sin
-- cuenta, a propósito: muchos son personas mayores.
-- La contraseña NUNCA se guarda: se guarda su huella scrypt con sal.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  email       TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  nombre      TEXT    NOT NULL,
  rol         TEXT    NOT NULL CHECK (rol IN ('dueno', 'repartidor')),
  clave_hash  TEXT    NOT NULL,
  clave_sal   TEXT    NOT NULL,
  creado_en   INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- Códigos para recuperar la contraseña. El código de 6 dígitos tampoco se
-- guarda: se guarda su huella. Vence a los 15 minutos, admite pocos
-- intentos y se usa una sola vez.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recuperaciones_clave (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  usuario_id   INTEGER NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
  codigo_hash  TEXT    NOT NULL,
  vence_en     INTEGER NOT NULL,
  intentos     INTEGER NOT NULL DEFAULT 0,
  usado        INTEGER NOT NULL DEFAULT 0 CHECK (usado IN (0, 1)),
  creado_en    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recuperaciones_usuario
  ON recuperaciones_clave (usuario_id, usado, vence_en);

-- ---------------------------------------------------------------------
-- Caché de direcciones (coordenadas -> "calle y número"), para no
-- consultar el mismo punto dos veces al servicio de mapas.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS direcciones_cache (
  clave      TEXT    PRIMARY KEY,
  direccion  TEXT    NOT NULL,
  creado_en  INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- Celulares que reciben notificaciones push (token de Firebase).
-- Un cliente (sin cuenta) se anota para UN pedido; el dueño y el
-- repartidor se anotan por su rol al ingresar. Exactamente uno de los dos.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dispositivos (
  token      TEXT    NOT NULL CHECK (length(token) BETWEEN 10 AND 4096),
  pedido_id  TEXT    REFERENCES pedidos (id) ON DELETE CASCADE,
  rol        TEXT    CHECK (rol IN ('dueno', 'repartidor')),
  creado_en  INTEGER NOT NULL,
  CHECK ((pedido_id IS NULL) <> (rol IS NULL))
);

-- Un mismo celular no se anota dos veces para lo mismo.
CREATE UNIQUE INDEX IF NOT EXISTS idx_dispositivos_unico
  ON dispositivos (token, ifnull(pedido_id, ''), ifnull(rol, ''));
CREATE INDEX IF NOT EXISTS idx_dispositivos_pedido ON dispositivos (pedido_id);
