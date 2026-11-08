// Notificaciones push con Firebase Cloud Messaging (FCM).
//
// Patrón Strategy, igual que correo.js: con FIREBASE_CREDENCIALES (la ruta
// al JSON de la cuenta de servicio de Firebase) se manda de verdad; sin
// eso, el aviso se escribe en la consola, para la demo y las pruebas.
//
// Cada aviso lleva:
// - notification: título y texto. Con la app cerrada o en segundo plano,
//   Android la muestra solo, sin que corra código de la app.
// - data: para qué es (tipo y pedido). Al tocarla, la app abre la sección
//   que corresponde.
import fs from 'node:fs';

/** Canal de Android donde caen los avisos (la app lo crea con ese id). */
export const CANAL_ANDROID = 'pedidos';

export async function crearPush({ credenciales } = {}) {
  if (!credenciales) return pushEnConsola();

  const { cert, initializeApp } = await import('firebase-admin/app');
  const { getMessaging } = await import('firebase-admin/messaging');
  const cuenta = JSON.parse(fs.readFileSync(credenciales, 'utf8'));
  const mensajeria = getMessaging(initializeApp({ credential: cert(cuenta) }, 'freshmarket'));

  /** Devuelve los tokens que ya no sirven (app desinstalada), para borrarlos. */
  return async (tokens, { titulo, cuerpo, datos = {} }) => {
    if (tokens.length === 0) return [];
    const respuesta = await mensajeria.sendEachForMulticast({
      tokens,
      notification: { title: titulo, body: cuerpo },
      data: datos,
      android: { priority: 'high', notification: { channelId: CANAL_ANDROID } },
    });
    return respuesta.responses.flatMap((resultado, i) =>
      tokenVencido(resultado.error) ? [tokens[i]] : [],
    );
  };
}

function tokenVencido(error) {
  return [
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ].includes(error?.code);
}

/** Sin Firebase: se muestra en la consola lo que se habría mandado. */
export function pushEnConsola() {
  const enviados = [];
  const enviar = async (tokens, aviso) => {
    enviados.push({ tokens, ...aviso });
    console.log(`[push simulado] a ${tokens.length} celular(es): ${aviso.titulo} — ${aviso.cuerpo}`);
    return [];
  };
  enviar.enviados = enviados;
  return enviar;
}
