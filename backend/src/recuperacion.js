// Recuperar la contraseña con un código de 6 dígitos que llega por email.
//
// Reglas de seguridad:
// - La respuesta es la misma exista o no el email (nadie puede averiguar
//   qué cuentas hay).
// - El código se guarda como huella, vence a los 15 minutos, admite 5
//   intentos y se usa una sola vez. Pedir uno nuevo anula los anteriores.
import crypto from 'node:crypto';

import { enTransaccion, obtenerBd } from './bd.js';
import { ErrorDeValidacion } from './catalogo.js';
import { buscarPorEmail, cambiarClave } from './usuarios.js';

export const MINUTOS_DE_VALIDEZ = 15;
export const MAXIMOS_INTENTOS_CODIGO = 5;

export class CodigoInvalido extends ErrorDeValidacion {}

const huellaDeCodigo = (codigo, secreto) =>
  crypto.createHmac('sha256', secreto).update(String(codigo)).digest('hex');

/** Genera y envía el código. No avisa si el email no existe. */
export async function solicitarCodigo({ email, correo, secreto, ahora = Date.now() }) {
  const usuario = buscarPorEmail(email);
  if (!usuario) return;

  const codigo = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
  enTransaccion(() => {
    const bd = obtenerBd();
    bd.prepare('UPDATE recuperaciones_clave SET usado = 1 WHERE usuario_id = ? AND usado = 0').run(
      usuario.id,
    );
    bd.prepare(
      `INSERT INTO recuperaciones_clave (usuario_id, codigo_hash, vence_en, creado_en)
       VALUES (?, ?, ?, ?)`,
    ).run(usuario.id, huellaDeCodigo(codigo, secreto), ahora + MINUTOS_DE_VALIDEZ * 60_000, ahora);
  });

  await correo.enviarCodigo({
    email: usuario.email,
    nombre: usuario.nombre,
    codigo,
    minutos: MINUTOS_DE_VALIDEZ,
  });
}

/** Si el código es correcto, cambia la contraseña. Si no, lanza CodigoInvalido. */
export function confirmarCodigo({ email, codigo, claveNueva, secreto, ahora = Date.now() }) {
  const usuario = buscarPorEmail(email);
  const bd = obtenerBd();
  const pendiente = usuario
    ? bd
        .prepare(
          `SELECT * FROM recuperaciones_clave
           WHERE usuario_id = ? AND usado = 0 AND vence_en > ?
           ORDER BY id DESC LIMIT 1`,
        )
        .get(usuario.id, ahora)
    : null;
  if (!pendiente || pendiente.intentos >= MAXIMOS_INTENTOS_CODIGO) {
    throw new CodigoInvalido('El código no es válido o ya venció. Pedí uno nuevo.');
  }

  const esperado = Buffer.from(pendiente.codigo_hash, 'hex');
  const recibido = Buffer.from(huellaDeCodigo(String(codigo ?? '').trim(), secreto), 'hex');
  if (!crypto.timingSafeEqual(esperado, recibido)) {
    bd.prepare('UPDATE recuperaciones_clave SET intentos = intentos + 1 WHERE id = ?').run(
      pendiente.id,
    );
    throw new CodigoInvalido('El código no es correcto.');
  }

  enTransaccion(() => {
    cambiarClave(usuario.id, claveNueva);
    bd.prepare('UPDATE recuperaciones_clave SET usado = 1 WHERE id = ?').run(pendiente.id);
  });
}
