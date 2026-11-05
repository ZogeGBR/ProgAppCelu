// Punto de entrada: lee la configuración del entorno y levanta el servidor.
//
//   cp .env.example .env   (completar las claves)
//   node --env-file=.env src/server.js
import { crearApp } from './app.js';

const puerto = Number(process.env.PORT ?? 3000);

const app = crearApp({
  mpAccessToken: process.env.MP_ACCESS_TOKEN,
  mpSandbox: process.env.MP_SANDBOX === 'true',
  mpWebhookSecret: process.env.MP_WEBHOOK_SECRET,
  geminiApiKey: process.env.GEMINI_API_KEY,
  geminiModelo: process.env.GEMINI_MODELO,
  urlPublica: process.env.URL_PUBLICA,
  claveRepartidor: process.env.CLAVE_REPARTIDOR,
});

app.listen(puerto, () => {
  console.log(`FreshMarket backend escuchando en http://localhost:${puerto}`);
});
