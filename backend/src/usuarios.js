// Cuentas del almacén: Don Ceferino (dueño) y los repartidores.
//
// Las contraseñas se guardan como huella scrypt con una sal distinta por
// usuario: si alguien se roba la base, no puede leerlas.
import crypto from 'node:crypto';

import { ErrorDeValidacion } from './catalogo.js';
import { obtenerBd } from './bd.js';

export const LARGO_MINIMO_CLAVE = 8;
const LARGO_HUELLA = 64;
const ROLES = ['dueno', 'repartidor'];

// Huella falsa para comparar cuando el email no existe: así la respuesta
// tarda lo mismo y nadie puede averiguar qué emails tienen cuenta.
const SAL_FALSA = crypto.randomBytes(16).toString('hex');
const HUELLA_FALSA = huellaDe('clave-falsa', SAL_FALSA);

function huellaDe(clave, sal) {
  return crypto.scryptSync(String(clave), sal, LARGO_HUELLA).toString('hex');
}

function iguales(a, b) {
  const bufferA = Buffer.from(a, 'hex');
  const bufferB = Buffer.from(b, 'hex');
  return bufferA.length === bufferB.length && crypto.timingSafeEqual(bufferA, bufferB);
}

export function normalizarEmail(email) {
  return String(email ?? '').trim().toLowerCase();
}

function validarClave(clave) {
  if (typeof clave !== 'string' || clave.length < LARGO_MINIMO_CLAVE) {
    throw new ErrorDeValidacion(
      `La contraseña tiene que tener al menos ${LARGO_MINIMO_CLAVE} caracteres.`,
    );
  }
}

export function buscarPorEmail(email) {
  return obtenerBd()
    .prepare('SELECT * FROM usuarios WHERE email = ?')
    .get(normalizarEmail(email));
}

/** Crea la cuenta si no existe. Se usa al arrancar, con los datos del .env. */
export function asegurarUsuario({ email, clave, rol, nombre }) {
  const limpio = normalizarEmail(email);
  if (!limpio || !clave || !ROLES.includes(rol)) return false;
  if (buscarPorEmail(limpio)) return false;

  validarClave(clave);
  const sal = crypto.randomBytes(16).toString('hex');
  obtenerBd()
    .prepare(
      `INSERT INTO usuarios (email, nombre, rol, clave_hash, clave_sal, creado_en)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .run(limpio, nombre ?? rol, rol, huellaDe(clave, sal), sal, Date.now());
  return true;
}

/** Devuelve el usuario si email y contraseña coinciden; si no, null. */
export function verificarCredenciales(email, clave) {
  const usuario = buscarPorEmail(email);
  if (!usuario) {
    iguales(huellaDe(String(clave ?? ''), SAL_FALSA), HUELLA_FALSA);
    return null;
  }
  const correcta = iguales(huellaDe(String(clave ?? ''), usuario.clave_sal), usuario.clave_hash);
  return correcta ? usuario : null;
}

export function cambiarClave(usuarioId, claveNueva) {
  validarClave(claveNueva);
  const sal = crypto.randomBytes(16).toString('hex');
  obtenerBd()
    .prepare('UPDATE usuarios SET clave_hash = ?, clave_sal = ? WHERE id = ?')
    .run(huellaDe(claveNueva, sal), sal, usuarioId);
}
