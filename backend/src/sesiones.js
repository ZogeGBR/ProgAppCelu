// Quién puede hacer qué: el dueño y el repartidor entran con su email y su
// contraseña (ver usuarios.js) y reciben una sesión firmada. Los clientes
// compran sin cuenta, a propósito: muchos son personas mayores y un registro
// sería una traba.
import crypto from 'node:crypto';

const DURACION_SESION = 12 * 60 * 60 * 1000;
const MAXIMOS_INTENTOS = 10;
const VENTANA_INTENTOS = 60 * 1000;

function firmar(contenido, secreto) {
  return crypto.createHmac('sha256', secreto).update(contenido).digest('base64url');
}

export function crearToken(rol, secreto, ahora = Date.now()) {
  const contenido = Buffer.from(
    JSON.stringify({ rol, vence: ahora + DURACION_SESION }),
  ).toString('base64url');
  return `${contenido}.${firmar(contenido, secreto)}`;
}

/** Devuelve el rol si el token es válido y no venció; si no, null. */
export function rolDeToken(token, secreto, ahora = Date.now()) {
  const [contenido, firma] = String(token ?? '').split('.');
  if (!contenido || !firma) return null;

  const esperada = Buffer.from(firmar(contenido, secreto));
  const recibida = Buffer.from(firma);
  if (esperada.length !== recibida.length || !crypto.timingSafeEqual(esperada, recibida)) {
    return null;
  }
  const { rol, vence } = JSON.parse(Buffer.from(contenido, 'base64url').toString());
  return vence > ahora ? rol : null;
}

/** Middleware: deja pasar solo a los roles indicados. */
export function exigirRol(secreto, ...roles) {
  return (req, res, next) => {
    const token = req.get('authorization')?.replace(/^Bearer /, '');
    const rol = rolDeToken(token, secreto);
    if (!rol) return res.status(401).json({ error: 'Hay que ingresar con la clave.' });
    if (!roles.includes(rol)) return res.status(403).json({ error: 'No tenés permiso.' });
    return next();
  };
}

/** Frena a quien prueba claves al azar: pocos intentos por minuto por IP. */
export function crearLimitadorDeIntentos(ahora = Date.now) {
  const intentos = new Map();
  return (ip) => {
    const momento = ahora();
    const registro = intentos.get(ip);
    if (!registro || momento - registro.desde > VENTANA_INTENTOS) {
      intentos.set(ip, { desde: momento, cantidad: 1 });
      return true;
    }
    registro.cantidad += 1;
    return registro.cantidad <= MAXIMOS_INTENTOS;
  };
}
