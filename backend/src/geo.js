// Geocodificación inversa: de un punto del mapa a "calle y número".
//
// Patrón Adapter: la app siempre recibe { direccion }, venga de donde venga.
// - Google Geocoding, si hay GOOGLE_MAPS_API_KEY.
// - Nominatim (OpenStreetMap), gratis y sin clave. Su política pide un
//   User-Agent que identifique la app y como mucho 1 consulta por segundo.
// - Simulado, para las pruebas y para trabajar sin internet.
//
// Las respuestas se guardan en la tabla direcciones_cache: el mismo punto
// no se consulta dos veces.
import { obtenerBd } from './bd.js';
import { ErrorDeValidacion } from './catalogo.js';

const DECIMALES_CACHE = 5; // ~1 metro
const ESPERA_ENTRE_CONSULTAS = 1100;
const LIMITE_RESPUESTA = 8000;

export function crearGeocodificador({ modo = 'nominatim', googleApiKey, contacto } = {}) {
  const proveedor =
    modo === 'simulado'
      ? simulado
      : googleApiKey
        ? google(googleApiKey)
        : nominatim(contacto);

  return async function direccionDe(lat, lng) {
    const latitud = Number(lat);
    const longitud = Number(lng);
    const valido =
      Number.isFinite(latitud) && Math.abs(latitud) <= 90 &&
      Number.isFinite(longitud) && Math.abs(longitud) <= 180;
    if (!valido) throw new ErrorDeValidacion('Coordenadas inválidas.');

    const clave = `${latitud.toFixed(DECIMALES_CACHE)},${longitud.toFixed(DECIMALES_CACHE)}`;
    const bd = obtenerBd();
    const guardada = bd.prepare('SELECT direccion FROM direcciones_cache WHERE clave = ?').get(clave);
    if (guardada) return { direccion: guardada.direccion, lat: latitud, lng: longitud };

    const direccion = await proveedor(latitud, longitud);
    if (direccion) {
      bd.prepare(
        'INSERT OR REPLACE INTO direcciones_cache (clave, direccion, creado_en) VALUES (?, ?, ?)',
      ).run(clave, direccion, Date.now());
    }
    return { direccion: direccion ?? '', lat: latitud, lng: longitud };
  };
}

/** "Calle 1234, Barrio" con lo que haya. */
export function armarDireccion({ calle, numero, barrio, ciudad }) {
  const primera = [calle, numero].filter(Boolean).join(' ');
  return [primera, barrio || ciudad].filter(Boolean).join(', ');
}

async function simulado(lat, lng) {
  // Siempre la misma dirección para el mismo punto: sirve para las pruebas.
  const numero = 100 + Math.round(Math.abs(lat * lng * 1000)) % 1900;
  return armarDireccion({ calle: 'San Martín', numero, ciudad: 'Mendoza' });
}

function nominatim(contacto = 'freshmarket-app') {
  let ultima = 0;
  return async (lat, lng) => {
    // Respeta el máximo de 1 consulta por segundo.
    const espera = ultima + ESPERA_ENTRE_CONSULTAS - Date.now();
    if (espera > 0) await new Promise((resolver) => setTimeout(resolver, espera));
    ultima = Date.now();

    const url = new URL('https://nominatim.openstreetmap.org/reverse');
    url.search = new URLSearchParams({
      lat: String(lat),
      lon: String(lng),
      format: 'jsonv2',
      addressdetails: '1',
      'accept-language': 'es',
      zoom: '18',
    }).toString();
    const respuesta = await fetch(url, {
      headers: { 'User-Agent': `FreshMarket/1.0 (${contacto})` },
      signal: AbortSignal.timeout(LIMITE_RESPUESTA),
    });
    if (!respuesta.ok) throw new Error(`Nominatim respondió ${respuesta.status}`);
    const { address = {} } = await respuesta.json();
    return armarDireccion({
      calle: address.road ?? address.pedestrian ?? address.footway,
      numero: address.house_number,
      barrio: address.neighbourhood ?? address.suburb,
      ciudad: address.city ?? address.town ?? address.village,
    });
  };
}

function google(apiKey) {
  return async (lat, lng) => {
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.search = new URLSearchParams({
      latlng: `${lat},${lng}`,
      language: 'es',
      result_type: 'street_address|premise|route',
      key: apiKey,
    }).toString();
    const respuesta = await fetch(url, { signal: AbortSignal.timeout(LIMITE_RESPUESTA) });
    if (!respuesta.ok) throw new Error(`Google respondió ${respuesta.status}`);
    const { results = [] } = await respuesta.json();
    const componentes = results[0]?.address_components ?? [];
    const de = (tipo) => componentes.find((c) => c.types.includes(tipo))?.long_name;
    return armarDireccion({
      calle: de('route'),
      numero: de('street_number'),
      barrio: de('sublocality') ?? de('neighborhood'),
      ciudad: de('locality'),
    });
  };
}
