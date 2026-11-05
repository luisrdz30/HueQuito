// Service worker de Firebase Cloud Messaging: muestra los avisos de las huecas
// aunque la pestaña de HueQuito esté cerrada o en segundo plano.
// La configuración del proyecto la entrega Firebase Hosting (/__/firebase/init.js),
// así no queda ninguna clave escrita en el repositorio.
importScripts('/__/firebase/12.19.0/firebase-app-compat.js');
importScripts('/__/firebase/12.19.0/firebase-messaging-compat.js');

// init.js no incluye el appId (esta app web no está vinculada al sitio de Hosting)
// y Messaging lo exige; el appId no es secreto.
const initializeApp = firebase.initializeApp.bind(firebase);
firebase.initializeApp = (config, name) =>
  initializeApp({ ...config, appId: '1:637645450526:web:5f7d36cc54d24c23206d0f' }, name);
importScripts('/__/firebase/init.js');

// Los mensajes traen "notification", así que el navegador los muestra solo
firebase.messaging();
