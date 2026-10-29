# Plan de corrección de HueQuito

Documento de traspaso: resume la auditoría del código (28-oct-2026), lo que ya se corrigió y lo que falta.
Quien continúe el trabajo (persona o asistente) debe leerlo completo antes de tocar código.

## Reglas de trabajo acordadas

- **Preguntar antes de cambiar.** Luis confirma cada bloque antes de implementarlo.
- **Una rama por fase** (`fase1-seguridad`, `fase2-datos`, ...). Commits pequeños y descriptivos en español.
- **No subir secretos.** `lib/services/gemini_menu_service.dart` tiene una API key escrita en el código: no commitear ese archivo con la clave (ver Fase 5).
- **Saltos de línea:** el repo guarda LF y el working tree de Windows usa CRLF (`core.autocrlf=true`). Mantener ese formato.
- Después de cada fase: `flutter analyze`, `flutter test` (142 tests pasan al inicio) y prueba manual en el teléfono.
- Las reglas se despliegan con `firebase deploy --only firestore` desde `hue_quito/`.

## Decisiones del proyecto

- **Rutas:** ya no las crea el admin. Cada usuario crea sus propios tours, que se guardan solo en su perfil (`users/{uid}/custom_tours`). La colección `routes` y las pantallas de rutas del admin son código heredado y se van a eliminar (Fase 3).
- Admin: `admin@huequito.com` o usuario con `role == 'admin'` (el rol ya no lo puede cambiar el propio usuario).

## Arquitectura (resumen)

- Flutter + Riverpod + GoRouter + Firebase (Auth, Firestore, Storage).
- `lib/router.dart`: 3 shells — usuario (`MainLayout`, StatefulShellRoute con 5 pestañas), negocio (`BusinessLayout`) y admin (`AdminLayout`). El `redirect` protege `/business` y `/admin` según `currentUserProvider` (de `data_provider.dart`).
- Datos en `lib/repositories/*`, providers en `lib/providers/data_provider.dart`.
- Graphify: `graphify-out/GRAPH_REPORT.md` (en la carpeta padre `D:\TFI\HueQuito`).

---

## Fase 1 — Seguridad ✅ (rama `fase1-seguridad`)

Hecho:
- `firestore.rules` reescrito con mínimo privilegio:
  - `users`: solo el dueño o el admin leen y escriben. No se puede cambiar `role`, `managedHuecaId` ni `managedBranchId` salvo: bajar a `user`, subir a `business` si es `ownerId` real de la hueca, o si tiene invitación vigente en `branch_invitations/{correo}`.
  - Encargado de sucursal = invitación vigente en `branch_invitations` (al borrarla pierde el acceso al instante). Solo el admin o el dueño general crean invitaciones.
  - `huecas`: el staff no toca `isActive`, `isSectorConfirmed` ni `subscription` (salvo subir comprobante → `under_review`). `metrics.stampsGiven` y `rewardsRedeemed` solo suben (≤10 y ≤1 por escritura).
  - `settings`, `notifications`, `admin_notifications`, `support_messages` y `branch_invitations` protegidos.
  - Reseñas: una por usuario (ID del doc = uid, con campo `userId`). Regla `/{path=**}/reviews` + `firestore.indexes.json` para el collectionGroup del admin.
- Código adaptado: `toggleFavorite` atómico, `UserRepository.syncBusinessRole()` usado en login y registro (espera el perfil antes de navegar), invitaciones con `branchId`, `syncHuecaMetrics` usa contadores (ya no lee perfiles ni tours ajenos), editar sucursal conserva su `secretSticker`.

Pendiente de la fase:
- [ ] Luis: `firebase deploy --only firestore` y prueba manual (comensal, dueño, admin).
- [ ] `flutter analyze` / `flutter test` sobre esta rama.
- Nota: encargados creados antes de este cambio no tienen invitación → el dueño debe volver a guardar la sucursal o el admin reasignarlos.
- Limitación conocida: el usuario aún puede editar sus propios sellos en su doc (se resuelve en Fase 5).

## Fase 2 — Errores de datos (pendiente)

1. **Periodo de gracia infinito** — `subscription_repository.evaluateHuecaSubscription`: `gracePeriodStartDate` nunca se guarda (usa "ahora"), nunca suspende. `suspendHueca()` no se llama nunca. Guardar la fecha al detectar el exceso y ocultar/bloquear sellos de huecas suspendidas. El texto "50 sellos" está fijo en `dashboard_screen.dart` aunque el admin cambie `freeTierMaxStamps`.
2. **Eliminar cuenta** — `auth_repository.deleteAccount` y `profile_screen` borran Firestore antes que Auth; si Auth pide reautenticación, se pierde el progreso pero la cuenta sigue. Orden correcto: reautenticar → borrar Auth → borrar datos (subcolecciones incluidas).
3. **Migración de invitado** — `user_repository.migrateGuestDataToUser`: el paso 5 (sector) sobrescribe `preferences` con datos viejos y borra la `persona` del paso 4.
4. **Tours en teléfono compartido** — `route_repository.saveUserTour/getUserTours` guardan en `guest_custom_tours` también para usuarios logueados; otra cuenta en el mismo teléfono hereda esos tours. Separar la caché local por uid.
5. **Avisos de suscripción** — `approvePayment`/`rejectPayment` escriben en `notifications` con `body` (no `message`) y sin `status`: el dueño no los ve y aparecen vacíos en su historial.
6. **Admin elimina usuario** — `deleteUser` solo borra Firestore; la cuenta de Auth sigue (requiere Admin SDK → Fase 5). Ajustar el texto del diálogo mientras tanto.
7. `HuecaBranch.fromMap` genera un id con `DateTime.now()` si falta → id inestable entre lecturas.
8. `register_screen`: mensaje de error crudo (sin traducir) y contraseña con `trim()` (el login no lo hace).

## Fase 3 — Funcionalidad (pendiente)

1. Botón **Historial** de `qr_generator_screen.dart` muestra "Próximamente": implementar con `stamp_history`.
2. Eliminar código de rutas del admin (decisión de Luis): `admin_routes_screen.dart`, `admin_route_edit_screen.dart`, `utils/seed_routes.dart`, `routesProvider`, `allRoutesStreamProvider`, rutas `/admin/routes/*` y regla `routes` (verificar antes que nada más lo use; `deleteHueca` limpia `routes`).
3. Código muerto: `SplashScreen`, `RewardScreen`, `NavigationScreen` (`/navigation`), `AuthRepository.signInAnonymously/syncUserToFirestore`, `_showStaticQrDialog`.

## Fase 4 — Estabilidad (pendiente; según `flutter analyze`, 425 avisos, 0 errores)

1. 40 × `use_build_context_synchronously` (sobre todo `profile_management_screen`, `admin_solicitudes_screen`, `login_screen`, `profile_screen`).
2. Declarar en `pubspec.yaml` paquetes usados sin declarar: `uuid`, `path`, `path_provider`.
3. 25 imports sin usar, dead code y variables sin uso que reporta el analyzer.

## Fase 5 — Validación en servidor (pendiente; requiere plan Blaze de Firebase)

Cloud Functions para:
1. **QR de sellos falsificables**: hoy el QR es JSON con `points` y `token` y la app confía en ambos; el negocio no registra los tokens que emite. Emitir tokens firmados/registrados y canjear en el servidor (transacción).
2. Sumar sellos, canjear premios y otorgar cromos desde el servidor (hoy el usuario puede editar su `gamification`). Cromo secreto: hoy se acepta el ID público de la hueca o cualquier QR con "sticker"/"cromo".
3. Borrar cuentas en Auth al eliminar usuarios (admin).
4. Suspensión automática programada de suscripciones vencidas.
5. Llamar a Gemini desde el servidor (sacar la API key del APK y revocar la actual).
- Si no hay plan Blaze: alternativas solo-cliente documentadas como limitación en la tesis.

## Fase 6 — Limpieza (pendiente)

`withOpacity` → `withValues` (189), `print` → `debugPrint` (42), `__` innecesarios, borrar `fix.dart` y `fix_lang.dart` (raíz de `hue_quito`, UTF-16).

## Otros puntos para la tesis

- `AiGenerationService` no usa IA (plantillas aleatorias): no presentarlo como IA.
- `TranslationService` usa un endpoint no oficial de Google (`client=gtx`).
- Notificaciones solo con la app abierta (no hay FCM).
- El build release cae a firma debug si falta `key.properties`.
