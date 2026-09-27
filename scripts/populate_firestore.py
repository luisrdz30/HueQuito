import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
from google.cloud.firestore_v1 import GeoPoint
import os

# INSTRUCCIONES:
# 1. Instala firebase-admin: pip install firebase-admin
# 2. Ve a la Consola de Firebase -> Configuración del Proyecto -> Cuentas de Servicio -> Generar nueva clave privada.
# 3. Guarda el archivo .json descargado en esta misma carpeta y renómbralo a 'serviceAccountKey.json'
# 4. Ejecuta este script: python populate_firestore.py

CREDENTIAL_PATH = "serviceAccountKey.json"

if not os.path.exists(CREDENTIAL_PATH):
    print(f"Error: No se encontro el archivo de credenciales '{CREDENTIAL_PATH}'.")
    print("Por favor, descarga la clave privada desde la Consola de Firebase y guardala aqui.")
    exit(1)

# Inicializar Firebase
cred = credentials.Certificate(CREDENTIAL_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# DATOS DE HUECAS
huecas_data = [
    {
        "id": "hueca_001",
        "name": "Las Corvinas de Don Jimmy",
        "description": {
            "es": "Tradición de más de 60 años en el Mercado Central. Su corvina frita acompañada de ceviche de concha es un icono de la capital.",
            "en": "Over 60 years of tradition at the Central Market. Fried corvina with conch ceviche is an icon of the capital."
        },
        "address": "Mercado Central, Av. Pichincha y Manabí",
        "sector": "Centro Histórico",
        "location": GeoPoint(-0.2198, -78.5085),
        "phone": "+593 99 123 4567",
        "schedule": {
            "monday": "07:00 - 15:00",
            "tuesday": "07:00 - 15:00",
            "wednesday": "07:00 - 15:00",
            "thursday": "07:00 - 15:00",
            "friday": "07:00 - 15:00",
            "saturday": "07:00 - 16:00",
            "sunday": "07:00 - 16:00"
        },
        "mainDish": {
            "name": {
                "es": "Corvina Frita Especial",
                "en": "Special Fried Corvina"
            },
            "emoji": "🐟"
        },
        "loyaltyCard": {
            "maxStamps": 5,
            "rewardText": {
                "es": "1 Ceviche de Camarón Gratis",
                "en": "1 Free Shrimp Ceviche"
            },
            "qrSecret": "don_jimmy_sello_2026"
        },
        "secretSticker": {
            "id": "cromo_corvina_01",
            "name": {
                "es": "La Corvina Dorada",
                "en": "Golden Corvina"
            },
            "imageUrl": "https://images.unsplash.com/photo-1594732120468-b7d1587d10e5?auto=format&fit=crop&w=500&q=80",
            "qrSecret": "don_jimmy_cromo_secreto"
        },
        "menuItems": [
            {
                "name": {"es": "Corvina Frita Especial", "en": "Special Fried Corvina"},
                "price": 6.50,
                "imageUrl": "https://images.unsplash.com/photo-1594732120468-b7d1587d10e5?auto=format&fit=crop&w=200&q=80"
            },
            {
                "name": {"es": "Ceviche Mixto", "en": "Mixed Ceviche"},
                "price": 5.50,
                "imageUrl": "https://images.unsplash.com/photo-1536868516007-88ba30f2be4c?auto=format&fit=crop&w=200&q=80"
            }
        ],
        "tags": ["Mariscos", "Mercado", "Tradicional"],
        "priceLevel": "$$",
        "rating": 4.9,
        "reviewCount": 342,
        "images": [
            "https://images.unsplash.com/photo-1615719413546-198b25453f85?auto=format&fit=crop&w=800&q=80"
        ],
        "ownerId": "",
        "isActive": True
    },
    {
        "id": "hueca_002",
        "name": "Los Motes de San Juan",
        "description": {
            "es": "Con vista espectacular al centro de Quito, estos motes con fritada cocinados a la leña conservan la receta familiar intacta por décadas.",
            "en": "With a spectacular view of central Quito, these wood-fired motes and fritada keep the family recipe intact for decades."
        },
        "address": "Calle Riofrio y Nicaragua, San Juan",
        "sector": "San Juan",
        "location": GeoPoint(-0.2117, -78.5081),
        "phone": "+593 98 765 4321",
        "schedule": {
            "friday": "16:00 - 22:00",
            "saturday": "11:00 - 22:00",
            "sunday": "11:00 - 20:00"
        },
        "mainDish": {
            "name": {
                "es": "Mote Mixto con Fritada",
                "en": "Mixed Mote with Fritada"
            },
            "emoji": "🍲"
        },
        "loyaltyCard": {
            "maxStamps": 8,
            "rewardText": {
                "es": "1 Plato Pequeño de Fritada",
                "en": "1 Small Fritada Plate"
            },
            "qrSecret": "motes_sanjuan_sello"
        },
        "secretSticker": {
            "id": "cromo_mote_02",
            "name": {
                "es": "El Tiesto Mágico",
                "en": "The Magic Tiesto"
            },
            "imageUrl": "https://images.unsplash.com/photo-1626200419189-39c8eb010e9c?auto=format&fit=crop&w=500&q=80",
            "qrSecret": "motes_sanjuan_cromo"
        },
        "menuItems": [
            {
                "name": {"es": "Fritada Quiteña", "en": "Quito Fritada"},
                "price": 5.00,
                "imageUrl": "https://images.unsplash.com/photo-1626200419189-39c8eb010e9c?auto=format&fit=crop&w=200&q=80"
            },
            {
                "name": {"es": "Mote Pillo", "en": "Mote Pillo"},
                "price": 3.00,
                "imageUrl": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=200&q=80"
            }
        ],
        "tags": ["Cerdo", "Vista panorámica", "Tradicional"],
        "priceLevel": "$",
        "rating": 4.7,
        "reviewCount": 215,
        "images": [
            "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=800&q=80"
        ],
        "ownerId": "",
        "isActive": True
    },
    {
        "id": "hueca_003",
        "name": "Las Tripas de Doña Fabiolita",
        "description": {
            "es": "El epicentro de la comida callejera quiteña en el parque La Floresta. La mejor tripa mishqui asada al carbón de la ciudad.",
            "en": "The epicenter of Quito's street food in La Floresta park. The best charcoal-grilled tripa mishqui in the city."
        },
        "address": "Parque Navarro, La Floresta",
        "sector": "La Floresta",
        "location": GeoPoint(-0.2030, -78.4842),
        "phone": "Sin teléfono",
        "schedule": {
            "thursday": "17:00 - 23:00",
            "friday": "17:00 - 23:00",
            "saturday": "17:00 - 23:00",
            "sunday": "17:00 - 23:00"
        },
        "mainDish": {
            "name": {
                "es": "Tripa Mishqui",
                "en": "Tripa Mishqui"
            },
            "emoji": "🍢"
        },
        "loyaltyCard": {
            "maxStamps": 10,
            "rewardText": {
                "es": "1 Pincho de Tripa Mishqui + Empanada",
                "en": "1 Tripa Mishqui Skewer + Empanada"
            },
            "qrSecret": "fabiolita_sello"
        },
        "secretSticker": {
            "id": "cromo_tripa_03",
            "name": {
                "es": "Carbón de La Floresta",
                "en": "La Floresta Charcoal"
            },
            "imageUrl": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=500&q=80",
            "qrSecret": "fabiolita_cromo"
        },
        "menuItems": [
            {
                "name": {"es": "Plato de Tripa Mishqui", "en": "Tripa Mishqui Plate"},
                "price": 3.50,
                "imageUrl": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=200&q=80"
            },
            {
                "name": {"es": "Empanadas de Viento", "en": "Wind Empanadas"},
                "price": 1.00,
                "imageUrl": "https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=200&q=80"
            },
            {
                "name": {"es": "Morocho Dulce", "en": "Sweet Morocho"},
                "price": 1.50,
                "imageUrl": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=200&q=80"
            }
        ],
        "tags": ["Callejero", "Nocturno", "Carbón"],
        "priceLevel": "$",
        "rating": 4.8,
        "reviewCount": 412,
        "images": [
            "https://images.unsplash.com/photo-1518481352495-2eb4d57c1c1e?auto=format&fit=crop&w=800&q=80"
        ],
        "ownerId": "",
        "isActive": True
    }
]

# DATOS DE RUTAS
rutas_data = [
    {
        "id": "route_mercados",
        "name": {
            "es": "Ruta de los Mercados Históricos",
            "en": "Historical Markets Route"
        },
        "description": {
            "es": "Un recorrido caminando por el corazón del Centro Histórico, visitando las cocinas más auténticas de los mercados capitalinos. ¡Ven con apetito!",
            "en": "A walking tour through the heart of the Historic Center, visiting the most authentic kitchens of the capital's markets. Come hungry!"
        },
        "totalDistance": "2.5 km",
        "estimatedTime": "120 min",
        "transportMethod": {
            "es": "A pie",
            "en": "Walking"
        },
        "bannerImageUrl": "https://images.unsplash.com/photo-1596422846543-72c4efaca87d?auto=format&fit=crop&w=1000&q=80",
        "stops": [
            {
                "order": 1,
                "huecaId": "hueca_001",
                "description": {
                    "es": "Comenzamos en el Mercado Central para un buen ceviche y corvina frita que nos dará energía.",
                    "en": "We start at the Central Market for a good ceviche and fried corvina to give us energy."
                }
            }
            # Aqui se pueden agregar mas paradas si hubiera mas huecas
        ]
    },
    {
        "id": "route_nocturna",
        "name": {
            "es": "Ruta Nocturna de la Floresta",
            "en": "La Floresta Night Route"
        },
        "description": {
            "es": "Cuando el sol se oculta, las parrillas se encienden. Descubre la comida callejera más famosa de la movida nocturna.",
            "en": "When the sun goes down, the grills light up. Discover the most famous street food of the nightlife scene."
        },
        "totalDistance": "1.0 km",
        "estimatedTime": "60 min",
        "transportMethod": {
            "es": "A pie",
            "en": "Walking"
        },
        "bannerImageUrl": "https://images.unsplash.com/photo-1518481352495-2eb4d57c1c1e?auto=format&fit=crop&w=1000&q=80",
        "stops": [
            {
                "order": 1,
                "huecaId": "hueca_003",
                "description": {
                    "es": "Parada obligatoria en el Parque Navarro para comer unas deliciosas tripas mishqui.",
                    "en": "Mandatory stop at Navarro Park to eat some delicious tripa mishqui."
                }
            }
        ]
    }
]


print("Subiendo huecas a Firestore...")
for hueca in huecas_data:
    doc_id = hueca["id"]
    db.collection("huecas").document(doc_id).set(hueca)
    print(f"Hueca subida: {hueca['name']}")

print("\nSubiendo rutas a Firestore...")
for ruta in rutas_data:
    doc_id = ruta["id"]
    db.collection("routes").document(doc_id).set(ruta)
    print(f"Ruta subida: {ruta['name']['es']}")

print("\n¡Carga de datos exitosa!")
