// Base de datos del backend: SQLite (viene con Node, no hay que instalar nada).
//
// Patrón Singleton: hay UNA sola conexión para todo el servidor. Se abre con
// abrirBd() y los demás módulos la piden con obtenerBd().
//
// Las tablas están en sql/schema.sql y los datos iniciales en sql/seed.sql,
// así el modelo de datos se puede leer y revisar sin abrir el código.
import fs from 'node:fs';
import { DatabaseSync } from 'node:sqlite';

const ESQUEMA = fs.readFileSync(new URL('../sql/schema.sql', import.meta.url), 'utf8');
const DATOS_INICIALES = fs.readFileSync(new URL('../sql/seed.sql', import.meta.url), 'utf8');

let bd = null;

/** Abre la base y crea lo que falte. ':memory:' no guarda nada en disco. */
export function abrirBd(ruta = ':memory:') {
  bd?.close();
  bd = new DatabaseSync(ruta);
  // WAL: las lecturas no esperan a las escrituras.
  if (ruta !== ':memory:') bd.exec('PRAGMA journal_mode = WAL');
  bd.exec(ESQUEMA);
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

/** Corre varias operaciones como una sola: o se guardan todas o ninguna. */
export function enTransaccion(operacion) {
  const conexion = obtenerBd();
  conexion.exec('BEGIN');
  try {
    const resultado = operacion();
    conexion.exec('COMMIT');
    return resultado;
  } catch (error) {
    conexion.exec('ROLLBACK');
    throw error;
  }
}

// Solo la primera vez: después manda lo que cambie Don Ceferino.
function sembrar() {
  const { cantidad } = bd.prepare('SELECT COUNT(*) AS cantidad FROM productos').get();
  if (cantidad === 0) bd.exec(DATOS_INICIALES);
}
