// Envío del código para recuperar la contraseña.
//
// Patrón Strategy: hay dos formas de "mandar el correo" con la misma firma.
// - Con SMTP_URL configurado, se manda un email de verdad (nodemailer).
// - Sin configurar (demo y pruebas), el código se muestra en la consola.
import nodemailer from 'nodemailer';

export function crearCorreo({ smtpUrl, remitente = 'FreshMarket <no-responder@freshmarket.local>' } = {}) {
  if (!smtpUrl) return correoDeConsola();

  const transporte = nodemailer.createTransport(smtpUrl);
  return {
    tipo: 'smtp',
    async enviarCodigo({ email, nombre, codigo, minutos }) {
      await transporte.sendMail({
        from: remitente,
        to: email,
        subject: `Tu código de FreshMarket: ${codigo}`,
        text:
          `Hola ${nombre}:\n\nTu código para cambiar la contraseña es ${codigo}.\n` +
          `Vence en ${minutos} minutos. Si no lo pediste, ignorá este mensaje.\n`,
      });
    },
  };
}

function correoDeConsola() {
  const enviados = [];
  return {
    tipo: 'consola',
    /** Solo para las pruebas: los últimos códigos "enviados". */
    enviados,
    async enviarCodigo({ email, codigo, minutos }) {
      enviados.push({ email, codigo });
      console.log(`[correo simulado] Código para ${email}: ${codigo} (vence en ${minutos} min)`);
    },
  };
}
