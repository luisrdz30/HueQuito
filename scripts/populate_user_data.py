import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import os
import datetime

# INSTRUCCIONES:
# Asegúrate de tener el archivo serviceAccountKey.json en esta carpeta
# y ejecuta: python scripts/populate_user_data.py

CREDENTIAL_PATH = "scripts/serviceAccountKey.json"

if not os.path.exists(CREDENTIAL_PATH):
    # Intentar en el directorio actual si se ejecuta desde scripts/
    CREDENTIAL_PATH = "serviceAccountKey.json"
    if not os.path.exists(CREDENTIAL_PATH):
        print(f"Error: No se encontro el archivo '{CREDENTIAL_PATH}'.")
        exit(1)

# Inicializar Firebase
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate(CREDENTIAL_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()

# ID DEL USUARIO DE PRUEBA
# Para pruebas, puedes usar un ID fijo o reemplazarlo con el UID real generado por Google Auth
TEST_USER_ID = "test_user_001"

print("Creando usuario de prueba...")

# 1. Crear perfil del usuario
user_data = {
    "uid": TEST_USER_ID,
    "name": "Camila Proaño",
    "email": "camila.quito@gmail.com",
    "profilePicUrl": "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80",
    "role": "comensal",
    "preferences": {
        "favoriteDishes": ["Hornado", "Ceviche", "Tripa Mishqui"],
        "dietaryRestrictions": ["Ninguna"]
    },
    "gamification": {
        "totalStamps": 14,
        "level": 3,
        "title": "Saboreador Quiteño"
    },
    "fcmTokens": ["mock_token_para_push_notifications"],
    "createdAt": firestore.SERVER_TIMESTAMP
}

db.collection("users").document(TEST_USER_ID).set(user_data)
print(f"Usuario {TEST_USER_ID} creado exitosamente.")

# 2. Agregar favoritos
print("Agregando favoritos...")
favoritos = ["hueca_001", "hueca_002"]
for hueca_id in favoritos:
    db.collection("users").document(TEST_USER_ID).collection("favorites").document(hueca_id).set({
        "huecaId": hueca_id,
        "addedAt": firestore.SERVER_TIMESTAMP
    })

# 3. Agregar progreso de cartillas (Loyalty Cards)
print("Agregando cartillas de lealtad...")
cartillas = [
    {
        "huecaId": "hueca_001",
        "currentStamps": 4, # A 1 sello de ganar
        "lastVisitedAt": firestore.SERVER_TIMESTAMP,
        "completedTimes": 0
    },
    {
        "huecaId": "hueca_002",
        "currentStamps": 8, # Ya completada, lista para reclamar premio
        "lastVisitedAt": firestore.SERVER_TIMESTAMP,
        "completedTimes": 1
    }
]

for cartilla in cartillas:
    db.collection("users").document(TEST_USER_ID).collection("loyalty_cards").document(cartilla["huecaId"]).set(cartilla)

# 4. Agregar progreso del Álbum por Sector
print("Agregando cromos del álbum...")
album_centro = {
    "sectorName": "Centro Histórico",
    "foundStickers": ["cromo_corvina_01"],
    "isCompleted": False,
    "rewardClaimed": False
}
db.collection("users").document(TEST_USER_ID).collection("sector_albums").document("Centro Historico").set(album_centro)

# 5. Agregar un Log de Auditoría (Audit Log) de prueba
print("Registrando actividad en Audit Logs...")
audit_log = {
    "id": "log_001",
    "actionType": "TEST_USER_CREATED",
    "userId": TEST_USER_ID,
    "targetId": "system",
    "details": "Se generó el usuario de prueba con datos mockeados.",
    "timestamp": firestore.SERVER_TIMESTAMP,
    "ipAddress": "127.0.0.1"
}
db.collection("audit_logs").document("log_001").set(audit_log)

print("\n¡Datos de usuario, favoritos, cartillas, álbum y logs cargados exitosamente!")
