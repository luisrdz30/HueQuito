// Cloud Functions de HueQuito: publicación de avisos con límite diario y envío push (FCM).
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

admin.initializeApp();
const db = getFirestore();

// Misma región que la base de datos de Firestore
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 5 });

const MAX_AVISOS_POR_DIA = 2;
const APP_URL = 'https://huequito-b091a.web.app';

// Día calendario en Quito (UTC-5, sin horario de verano), p. ej. "2026-11-02"
function diaQuito(date = new Date()) {
  return new Date(date.getTime() - 5 * 3600 * 1000).toISOString().slice(0, 10);
}

// El comensal ve de qué hueca es el aviso (igual que la vista previa de la app)
function tituloPush(aviso) {
  const titulo = aviso.title || '';
  const hueca = aviso.huecaName || '';
  if (!titulo) return hueca;
  return !hueca || titulo.includes(hueca) ? titulo : `${hueca}: ${titulo}`;
}

// Avisos ya contados por día ({ "2026-11-04": 1 }). Acepta el formato anterior { day, count }.
function usadosPorDia(cuota) {
  if (!cuota.exists) return {};
  const dias = { ...(cuota.get('days') || {}) };
  const viejoDia = cuota.get('day');
  if (viejoDia && dias[viejoDia] == null) dias[viejoDia] = cuota.get('count') || 0;
  return dias;
}

// Gracia vencida sin pago: misma lógica que subscriptionExpired() en firestore.rules
// y evaluateHuecaSubscription() en la app
async function suscripcionVencida(huecaId) {
  const [hueca, ajustes] = await Promise.all([
    db.collection('huecas').doc(huecaId).get(),
    db.collection('settings').doc('subscription').get(),
  ]);
  const sub = (hueca.exists && hueca.get('subscription')) || {};
  const diasGracia = ((ajustes.exists && ajustes.get('gracePeriodDays')) || 7) * 24 * 3600 * 1000;
  const ahora = Date.now();
  // Las fechas pueden venir como Timestamp o como texto ISO
  const ms = (v) => (v && typeof v.toMillis === 'function' ? v.toMillis() : v ? Date.parse(v) : NaN);
  if (sub.status === 'suspended') return true;
  if (sub.status === 'active') return ahora > ms(sub.nextCutoffDate) + diasGracia;
  if (sub.status === 'under_review') return false;
  return ahora > ms(sub.gracePeriodStartDate) + diasGracia;
}

/**
 * Cuando una hueca crea un aviso ('pending'), se publica al instante si no pasó
 * del límite diario; si lo pasó, se rechaza. Los avisos del admin ya llegan aprobados.
 */
exports.publicarAviso = onDocumentCreated('notifications/{id}', async (event) => {
  const snap = event.data;
  if (!snap) return;
  const aviso = snap.data();

  if (aviso.status === 'approved') {
    await enviarSiCorresponde(snap.ref, aviso);
    return;
  }
  if (aviso.status !== 'pending' || !aviso.huecaId) return;

  // Una hueca suspendida por falta de pago sigue visible, pero no puede enviar avisos
  if (await suscripcionVencida(aviso.huecaId)) {
    await snap.ref.update({
      status: 'rejected',
      rejectedAt: FieldValue.serverTimestamp(),
      reviewedBy: 'auto_suspendida',
      rejectionReason: 'Tu hueca está suspendida por falta de pago. Sube tu comprobante desde el Panel para volver a enviar avisos.',
    });
    return;
  }

  // El aviso cuenta para el día en que les llega a los comensales: hoy si es inmediato,
  // o el día programado. Así nadie recibe más de 2 avisos de una hueca en un mismo día.
  const cuotaRef = db.collection('noticeQuota').doc(aviso.huecaId);
  const hoy = diaQuito();
  const programado = aviso.scheduledFor && aviso.scheduledFor.toMillis() > Date.now();
  const dia = programado ? diaQuito(aviso.scheduledFor.toDate()) : hoy;

  const aprobado = await db.runTransaction(async (tx) => {
    const cuota = await tx.get(cuotaRef);
    const dias = usadosPorDia(cuota);
    const usados = dias[dia] || 0;
    if (usados >= MAX_AVISOS_POR_DIA) {
      const [a, m, d] = dia.split('-');
      tx.update(snap.ref, {
        status: 'rejected',
        rejectedAt: FieldValue.serverTimestamp(),
        reviewedBy: 'auto_limite',
        rejectionReason: dia === hoy
          ? `Ya publicaste ${MAX_AVISOS_POR_DIA} avisos hoy. Podrás publicar otro mañana.`
          : `Ya tienes ${MAX_AVISOS_POR_DIA} avisos para el ${d}/${m}/${a}. Elige otro día.`,
      });
      return false;
    }
    // Solo se guardan los días de hoy en adelante
    const vigentes = Object.fromEntries(Object.entries(dias).filter(([k]) => k >= hoy));
    vigentes[dia] = usados + 1;
    tx.set(cuotaRef, { days: vigentes, updatedAt: FieldValue.serverTimestamp() });
    tx.update(snap.ref, {
      status: 'approved',
      approvedAt: Timestamp.now(),
      reviewedBy: 'auto_business',
      rejectionReason: null,
    });
    return true;
  });

  if (aprobado) {
    const actualizado = await snap.ref.get();
    await enviarSiCorresponde(snap.ref, actualizado.data());
  }
});

/** Respaldo: si el admin aprueba a mano un aviso pendiente, también se envía. */
exports.enviarAvisoAprobado = onDocumentUpdated('notifications/{id}', async (event) => {
  const antes = event.data?.before.data();
  const despues = event.data?.after.data();
  if (!antes || !despues) return;
  if (antes.status !== 'approved' && despues.status === 'approved' && despues.reviewedBy !== 'auto_business') {
    await enviarSiCorresponde(event.data.after.ref, despues);
  }
});

/** Cada 5 minutos envía los avisos programados cuya hora ya llegó. */
exports.enviarAvisosProgramados = onSchedule({ schedule: 'every 5 minutes', timeZone: 'America/Guayaquil' }, async () => {
  const ahora = Timestamp.now();
  const desde = Timestamp.fromMillis(ahora.toMillis() - 6 * 3600 * 1000);
  const programados = await db.collection('notifications')
    .where('scheduledFor', '<=', ahora)
    .where('scheduledFor', '>=', desde)
    .get();
  for (const doc of programados.docs) {
    const aviso = doc.data();
    if (aviso.status === 'approved' && !aviso.pushSentAt) {
      await enviarSiCorresponde(doc.ref, aviso);
    }
  }
});

async function enviarSiCorresponde(ref, aviso) {
  if (!aviso || aviso.pushSentAt) return;
  const programado = aviso.scheduledFor && aviso.scheduledFor.toMillis() > Date.now();
  if (programado) return; // lo enviará enviarAvisosProgramados

  // Marca primero para no enviar dos veces si se cruzan dos funciones
  const reservado = await db.runTransaction(async (tx) => {
    const actual = await tx.get(ref);
    if (!actual.exists || actual.get('pushSentAt')) return false;
    tx.update(ref, { pushSentAt: FieldValue.serverTimestamp() });
    return true;
  });
  if (!reservado) return;

  // Comensales suscritos a la hueca y sus dispositivos
  const usuarios = await db.collection('users').where('subscribedHuecas', 'array-contains', aviso.huecaId).get();
  const duenosDeToken = new Map();
  usuarios.forEach((u) => {
    for (const token of u.get('fcmTokens') || []) duenosDeToken.set(token, u.ref);
  });
  const tokens = [...duenosDeToken.keys()];

  let enviados = 0;
  for (let i = 0; i < tokens.length; i += 500) {
    const lote = tokens.slice(i, i + 500);
    const res = await getMessaging().sendEachForMulticast({
      tokens: lote,
      notification: { title: tituloPush(aviso), body: aviso.message || '' },
      data: { huecaId: aviso.huecaId, notificationId: ref.id },
      android: { priority: 'high', notification: { channelId: 'huequito_promotions' } },
      webpush: { fcmOptions: { link: `${APP_URL}/#/hueca_detail?id=${aviso.huecaId}` } },
    });
    enviados += res.successCount;

    // Borra los tokens de dispositivos que ya no existen
    const limpieza = [];
    res.responses.forEach((r, idx) => {
      const code = r.error?.code || '';
      if (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token')) {
        const token = lote[idx];
        limpieza.push(duenosDeToken.get(token).update({ fcmTokens: FieldValue.arrayRemove(token) }));
      }
    });
    await Promise.all(limpieza);
  }

  await ref.update({ pushCount: enviados });
  logger.info(`Aviso ${ref.id}: push enviado a ${enviados}/${tokens.length} dispositivos`);
}
