import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'Hue-Quito',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: Text(
                      'Skip',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMedium),
                    ),
                  )
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Header
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(width: 32, height: 6, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(3))),
                              SizedBox(width: 4),
                              Container(width: 10, height: 6, decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), borderRadius: BorderRadius.circular(3))),
                            ],
                          ),
                          Text(
                            'PASO 1 DE 2: BIENVENIDA',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                    
                    // Hero Card
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage('https://images.unsplash.com/photo-1541518763669-27fef04b14ea?q=80&w=600&auto=format&fit=crop'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                          ),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                                  child: Text('Turismo Gastronómico 🇪🇨', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppTheme.tertiary, borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text('Tradición Viva en los Andes', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Value Proposition
                    Text(
                      'Descubre los secretos mejor guardados de Quito',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.2),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Una aventura culinaria para saborear la historia en cada hueca, plaza y rincón patrimonial.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    
                    SizedBox(height: 24),
                    
                    // Value Columns
                    _buildValueRow(
                      context,
                      Icons.ramen_dining,
                      AppTheme.primary,
                      'Huecas Auténticas',
                      'Encuentra los mejores hornados crujientes, locros humeantes y empanadas de viento de antaño.',
                      tag: '100% Caseras',
                    ),
                    SizedBox(height: 12),
                    _buildValueRow(
                      context,
                      Icons.explore,
                      AppTheme.tertiary,
                      'Rutas y Búsqueda del Tesoro',
                      'Escanea códigos QR en barrios emblemáticos como San Marcos o La Ronda y desbloquea cromos coleccionables.',
                    ),
                    SizedBox(height: 12),
                    _buildValueRow(
                      context,
                      Icons.card_membership,
                      AppTheme.secondary,
                      'Recompensas Reales',
                      'Acumula sellos en tu pasaporte virtual con cada visita y canjea platos gratis o premios del sector.',
                      tag: 'Pasaporte',
                    ),
                    
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Bottom Actions
            Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: Offset(0, -5))
                ]
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/preferences'), // Next step in onboarding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Personalizar mi experiencia'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Text(
                      'Saltar y explorar como invitado',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.textMedium),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueRow(BuildContext context, IconData icon, Color color, String title, String desc, {String? tag}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (tag != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tag, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
