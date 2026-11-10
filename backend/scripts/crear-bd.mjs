// Crea la base de datos con el esquema y los datos iniciales.
//   npm run bd:crear            -> freshmarket.db
//   npm run bd:crear -- otra.db
import { abrirBd, cerrarBd, obtenerBd } from '../src/bd.js';

const ruta = process.argv[2] ?? process.env.RUTA_BD ?? 'freshmarket.db';
abrirBd(ruta);
const tablas = obtenerBd()
  .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")
  .all()
  .map((fila) => fila.name);
cerrarBd();
console.log(`Base lista en ${ruta}. Tablas: ${tablas.join(', ')}`);
