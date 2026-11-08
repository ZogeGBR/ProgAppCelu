// Punto de entrada: lee la configuración del entorno y levanta el servidor.
//
//   cp .env.example .env   (completar las claves)
//   node --env-file=.env src/server.js
import { crearApp } from './app.js';
import { crearPush } from './push.js';

const puerto = Number(process.env.PORT ?? 3000);

// Notificaciones push: con FIREBASE_CREDENCIALES se mandan por Firebase;
// sin eso, se muestran en la consola.
const push = await crearPush({ credenciales: process.env.FIREBASE_CREDENCIALES });

const app = crearApp({
  push,
  mpAccessToken: process.env.MP_ACCESS_TOKEN,
  mpSandbox: process.env.MP_SANDBOX === 'true',
  mpWebhookSecret: process.env.MP_WEBHOOK_SECRET,
  geminiApiKey: process.env.GEMINI_API_KEY,
  geminiModelo: process.env.GEMINI_MODELO,
  urlPublica: process.env.URL_PUBLICA,
  // Las cuentas se crean la primera vez; después la contraseña se cambia
  // desde la app ("¿Olvidaste tu contraseña?") y el .env ya no manda.
  usuariosIniciales: [
    {
      email: process.env.DUENO_EMAIL,
      clave: process.env.DUENO_CLAVE,
      nombre: 'Don Ceferino',
      rol: 'dueno',
    },
    {
      email: process.env.REPARTIDOR_EMAIL,
      clave: process.env.REPARTIDOR_CLAVE,
      nombre: 'Repartidor',
      rol: 'repartidor',
    },
  ],
  smtpUrl: process.env.SMTP_URL,
  remitenteCorreo: process.env.CORREO_REMITENTE,
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
  contactoMapas: process.env.CONTACTO_MAPAS,
  geocodificacion: process.env.GEOCODIFICACION ?? 'nominatim',
  rutaBd: process.env.RUTA_BD ?? 'freshmarket.db',
  secretoSesion: process.env.SECRETO_SESION || undefined,
  // Sin definir, se simula solo si Mercado Pago también está simulado.
  simularReparto: process.env.SIMULAR_REPARTO
    ? process.env.SIMULAR_REPARTO === 'true'
    : undefined,
});

app.listen(puerto, () => {
  console.log(`FreshMarket backend escuchando en http://localhost:${puerto}`);
});
