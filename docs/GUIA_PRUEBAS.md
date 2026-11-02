# Guía rápida de pruebas (fases 1 a 8)

Necesitas: la app nueva instalada (rama `fase8-zonas-menu`, que ya incluye todas las fases), las reglas desplegadas y tres cuentas: **comensal**, **dueño** de una hueca y **admin**. Lo ideal son dos teléfonos (uno muestra el QR y el otro escanea).

Marca cada punto. Si algo falla, anota la pantalla y el mensaje.

## 0. Antes de empezar (admin)
- [ ] Panel admin → **Suscripciones**: la meta de sellos gratis dice **100** (si dice 50, cámbiala y guarda).

## 1. Comensal
- [ ] Registro con correo nuevo: si el correo ya existe, el error sale en español.
- [ ] Como **invitado**: haz el quiz y crea un tour. Luego regístrate: tu perfil gastronómico y tu tour siguen ahí.
- [ ] Cierra sesión y entra con **otra cuenta** en el mismo teléfono: **no** aparecen los tours de la cuenta anterior.
- [ ] Marca y desmarca una hueca como favorita.
- [ ] Deja una reseña (solo se permite una por hueca).
- [ ] Escanea el **QR de sellos** del negocio: se suma el sello. Escanea el mismo QR otra vez: dice que ya fue usado.
- [ ] Escanea el **cromo secreto** impreso de una hueca: se agrega al álbum (+50 pts).
- [ ] Escanea un QR cualquiera (por ejemplo, de una página web): dice que no es válido y **no** da cromo.
- [ ] Perfil → **Eliminar cuenta** (con una cuenta de prueba): pide tu contraseña (o tu cuenta de Google), borra todo y vuelve al inicio. Con una contraseña incorrecta **no** se borra.

## 2. Dueño de hueca
- [ ] El Panel muestra "X / 100 sellos" en la fase gratuita.
- [ ] **Mi QR**: cambia la cantidad de sellos, genera el código y escanéalo desde el otro teléfono: aparece "Sello escaneado".
- [ ] **Mi QR → Historial** (icono de reloj): muestra los sellos entregados hoy, con la hora.
- [ ] Edita la sucursal, el horario y la descripción: se guardan sin errores ni pantallas rojas.
- [ ] Sube un comprobante de pago: el estado pasa a "en revisión".
- [ ] Como **encargado** de sucursal (invitado por el dueño): entra al panel y ve solo su sucursal en Mi QR.

## 3. Admin
- [ ] Aprueba o rechaza un comprobante: el dueño ve el aviso con su texto en su **historial de avisos** (como "Aviso de Hue-Quito"), y ese aviso **no** aparece en la cola de moderación.
- [ ] Revisa usuarios, solicitudes y reseñas: todo carga.
- [ ] Eliminar usuario: el diálogo aclara que la cuenta de inicio de sesión no se borra.
- [ ] Ya **no** existe la sección de rutas oficiales en el menú del admin.

## 4. Navegación (fase 7)
- [ ] Bienvenida → **Saltar cuestionario e iniciar sesión**: va directo al login sin pasar por el quiz.
- [ ] En el quiz, **Saltar** (arriba a la derecha) también lleva al login.
- [ ] Prueba la flecha de regresar en: detalle de hueca, detalle de ruta, crear tour, asistente de tour, solicitar hueca, preguntas frecuentes, términos, y en el panel de negocio (soporte, galería, platos, sucursales). Siempre regresa, nunca se queda pegada ni cierra la app.
- [ ] Dueño: pestaña **Ver app** (abajo a la derecha) → entra a la app normal con sus favoritos y sellos. En **Perfil → Administrar … → Entrar** vuelve al panel. Nunca pide cerrar sesión.
- [ ] Admin convierte en dueño a una cuenta que ya era comensal: conserva sus favoritos, sellos y álbum.
- [ ] Dueño: cierra y vuelve a abrir la app al día siguiente: sigue con la sesión abierta. Solo el **admin** debe volver a iniciar sesión pasadas 24 horas.

## 4b. Zonas y menú (fase 8)
- [ ] Admin → Huecas → **Cargar huecas de Quito**: confirma y espera. Quedan solo las 20 huecas nuevas (5 por zona), activas y sin dueño.
- [ ] Quiz inicial: el primer paso muestra solo **Centro, Norte, Sur y Valles** (más "Otro sector").
- [ ] Inicio y mapa: el filtro de zona tiene esas 4 opciones; al elegir **Valles** salen Conocoto, Sangolquí y Cumbayá juntas.
- [ ] Álbum → Cromos por sector: aparecen las 4 zonas.
- [ ] Detalle de una hueca con varios platos (ej. El Pretil): en Menú hay **lupa** para buscar y chips por categoría (Desayunos, Bebidas…).
- [ ] Dueño → Menú: el botón ✨ **Organizar por categorías con IA** agrupa los platos y los guarda en orden. Al crear un plato se puede elegir **➕ Nueva categoría**.

## 5. Suscripción vencida (opcional, usa una hueca de prueba)
Para simularlo, en la consola de Firebase, en la hueca de prueba: `metrics.stampsGiven` = 100 y `subscription.gracePeriodStartDate` = una fecha de hace 8 días.
- [ ] Panel del dueño: "Cuenta suspendida por pago pendiente".
- [ ] Mi QR: "Entrega de sellos pausada" (no muestra código).
- [ ] Al escanear un QR viejo de esa hueca: "no puede entregar sellos por ahora".
- [ ] El admin aprueba el pago: vuelve a funcionar.

## 6. Publicar la versión web (Firebase Hosting, gratis en el plan Spark)
`firebase.json` ya tiene configurado Hosting para publicar `build/web`. Desde la carpeta `hue_quito`:
1. Compila: doble clic en `build_web.bat` (toma la clave de Maps de `android/local.properties`).
2. Publica: `firebase deploy --only hosting --project huequito-b091a`
3. Abre `https://huequito-b091a.web.app` y prueba lo básico: login (correo y Google), mapa y detalle de huecas (escanear QR es solo en el celular).

Si prefieres Netlify (ya está `netlify.toml`), arrastra la carpeta `build/web` a app.netlify.com/drop. En ese caso agrega el dominio de Netlify en Firebase → Authentication → Configuración → **Dominios autorizados**, o el login falla.

## 7. Pendientes en la consola (solo los puedes hacer tú)
- [ ] **Firebase → AI Logic**: que esté activado (lo usa la lectura de menús con IA). Si al escanear un menú sale error de permisos o de API, actívalo ahí.
- [ ] **Google Cloud → Credenciales**: revoca o elimina la clave vieja de Gemini que estaba en el código.
- [ ] **Google Cloud → Credenciales → clave de Maps**: restríngela por referente HTTP (`huequito-b091a.web.app/*`, `huequito-b091a.firebaseapp.com/*`, `localhost/*` y tu dominio de Netlify si lo usas) y por app Android.
- [ ] Panel admin → Suscripciones: meta de sellos gratis en **100** (punto 0).
- [ ] Cuando termines de probar: unir `fase8-zonas-menu` a `main` (me dices y lo hago).
