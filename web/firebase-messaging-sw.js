// Service worker de Firebase Cloud Messaging: muestra los avisos de las huecas
// aunque la pestaña de HueQuito esté cerrada o en segundo plano.
// La configuración del proyecto la entrega Firebase Hosting (/__/firebase/init.js),
// así no queda ninguna clave escrita en el repositorio.
importScripts('/__/firebase/12.19.0/firebase-app-compat.js');
importScripts('/__/firebase/12.19.0/firebase-messaging-compat.js');
importScripts('/__/firebase/init.js');

// Los mensajes traen "notification", así que el navegador los muestra solo
firebase.messaging();
