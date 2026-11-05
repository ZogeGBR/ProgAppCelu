// IA para armar la etiqueta de un producto a partir de una foto (Gemini).
//
// La clave (GEMINI_API_KEY) vive solo en el servidor. Sin clave, devuelve
// una etiqueta de ejemplo para poder mostrar el flujo.
import { CATEGORIAS, ErrorDeValidacion } from './catalogo.js';

const MAXIMO_BYTES_IMAGEN = 5 * 1024 * 1024;
const TIPOS_PERMITIDOS = ['image/jpeg', 'image/png', 'image/webp'];

const INSTRUCCIONES = `Sos el asistente de un almacén de barrio en Mendoza, Argentina.
Mirá la foto de un producto y armá su etiqueta para el catálogo.
Respondé SOLO con un JSON con estas claves:
- "nombre": nombre comercial corto con marca y tamaño si se ven (ej. "Yerba mate Playadito 1kg").
- "categoria": una de ${JSON.stringify(CATEGORIAS)}.
- "precioSugerido": precio de venta estimado en pesos argentinos, número entero.
- "descripcion": una oración simple, sin datos inventados.
- "emoji": un emoji que represente el producto.
Si no se reconoce un producto, devolvé "nombre": "" y "precioSugerido": 0.`;

const ETIQUETA_DE_EJEMPLO = {
  nombre: 'Aceite de girasol 1.5L',
  categoria: 'Almacén',
  precioSugerido: 3200,
  descripcion: 'Botella de aceite de girasol de litro y medio.',
  emoji: '🫒',
};

export async function armarEtiqueta({ imagenBase64, tipo = 'image/jpeg', apiKey, modelo }) {
  if (typeof imagenBase64 !== 'string' || imagenBase64.length === 0) {
    throw new ErrorDeValidacion('Falta la foto.');
  }
  if (!TIPOS_PERMITIDOS.includes(tipo)) throw new ErrorDeValidacion('Formato de foto no soportado.');
  if (Buffer.byteLength(imagenBase64, 'base64') > MAXIMO_BYTES_IMAGEN) {
    throw new ErrorDeValidacion('La foto es muy pesada.');
  }
  if (!apiKey) return ETIQUETA_DE_EJEMPLO;

  const respuesta = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: INSTRUCCIONES },
              { inline_data: { mime_type: tipo, data: imagenBase64 } },
            ],
          },
        ],
        generationConfig: { response_mime_type: 'application/json', temperature: 0.2 },
      }),
      signal: AbortSignal.timeout(25_000),
    },
  );
  if (!respuesta.ok) throw new Error(`Gemini respondió ${respuesta.status}`);

  const datos = await respuesta.json();
  const texto = datos.candidates?.[0]?.content?.parts?.[0]?.text ?? '{}';
  return normalizar(JSON.parse(texto));
}

/** Nunca confiar en lo que devuelve la IA: se limpia cada campo. */
export function normalizar(etiqueta) {
  const precio = Math.round(Number(etiqueta?.precioSugerido));
  return {
    nombre: String(etiqueta?.nombre ?? '').trim().slice(0, 80),
    categoria: CATEGORIAS.includes(etiqueta?.categoria) ? etiqueta.categoria : 'Otros',
    precioSugerido: Number.isFinite(precio) && precio > 0 ? precio : 0,
    descripcion: String(etiqueta?.descripcion ?? '').trim().slice(0, 200),
    emoji: typeof etiqueta?.emoji === 'string' && etiqueta.emoji ? etiqueta.emoji.slice(0, 8) : '🛒',
  };
}
