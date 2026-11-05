// Base de datos del backend: SQLite (viene con Node, no hay que instalar nada).
//
// Es un solo archivo, así que alcanza con un servidor. Si algún día hicieran
// falta varios servidores, se cambia este módulo por PostgreSQL.
import { DatabaseSync } from 'node:sqlite';

const PRIMER_NUMERO_DE_PEDIDO = 1001;

const PRODUCTOS_INICIALES = [
  ['p1', 'Fideos guiseros 500g', 1200, 'Almacén', '🍝'],
  ['p2', 'Yerba mate 1kg', 3800, 'Almacén', '🧉'],
  ['p3', 'Leche entera 1L', 1500, 'Lácteos', '🥛'],
  ['p4', 'Pan francés (kg)', 2200, 'Panadería', '🥖'],
  ['p5', 'Tomate (kg)', 1800, 'Verdulería', '🍅'],
  ['p6', 'Queso cremoso (kg)', 6500, 'Lácteos', '🧀'],
  ['p7', 'Gaseosa cola 2.25L', 2600, 'Bebidas', '🥤'],
  ['p8', 'Papel higiénico x4', 2100, 'Limpieza', '🧻'],
];

let bd = null;

/** Abre la base y crea lo que falte. ':memory:' no guarda nada en disco. */
export function abrirBd(ruta = ':memory:') {
  bd?.close();
  bd = new DatabaseSync(ruta);
  // WAL: las lecturas no esperan a las escrituras.
  if (ruta !== ':memory:') bd.exec('PRAGMA journal_mode = WAL');
  bd.exec(`
    CREATE TABLE IF NOT EXISTS productos (
      id TEXT PRIMARY KEY,
      nombre TEXT NOT NULL,
      precio INTEGER NOT NULL,
      categoria TEXT NOT NULL,
      emoji TEXT NOT NULL,
      descripcion TEXT NOT NULL DEFAULT '',
      disponible INTEGER NOT NULL DEFAULT 1
    );
    CREATE TABLE IF NOT EXISTS pedidos (
      numero INTEGER PRIMARY KEY AUTOINCREMENT,
      id TEXT NOT NULL UNIQUE,
      metodo_pago TEXT NOT NULL,
      items TEXT NOT NULL,
      total INTEGER NOT NULL,
      direccion TEXT NOT NULL,
      destino_lat REAL,
      destino_lng REAL,
      estado_pago TEXT NOT NULL,
      aprobado_en INTEGER,
      entregado INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE IF NOT EXISTS posiciones (
      pedido_id TEXT PRIMARY KEY,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      nombre TEXT NOT NULL,
      en INTEGER NOT NULL
    );
  `);
  sembrar();
  return bd;
}

export function obtenerBd() {
  if (!bd) throw new Error('La base de datos no está abierta.');
  return bd;
}

export function cerrarBd() {
  bd?.close();
  bd = null;
}

// Solo la primera vez: después manda lo que cambie Don Ceferino.
function sembrar() {
  const { cantidad } = bd.prepare('SELECT COUNT(*) AS cantidad FROM productos').get();
  if (cantidad > 0) return;

  const insertar = bd.prepare(
    'INSERT INTO productos (id, nombre, precio, categoria, emoji) VALUES (?, ?, ?, ?, ?)',
  );
  for (const producto of PRODUCTOS_INICIALES) insertar.run(...producto);
  // AUTOINCREMENT sigue desde el valor guardado acá: el primero es el 1001.
  bd.prepare("INSERT INTO sqlite_sequence (name, seq) VALUES ('pedidos', ?)").run(
    PRIMER_NUMERO_DE_PEDIDO - 1,
  );
}
