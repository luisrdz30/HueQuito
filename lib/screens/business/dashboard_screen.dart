import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';

class BusinessDashboardScreen extends ConsumerWidget {
  const BusinessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final huecaAsync = ref.watch(myHuecaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Mi Negocio', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: huecaAsync.when(
        data: (hueca) {
          if (hueca == null) {
            return Center(child: Text('No tienes una Hueca asignada.'));
          }

          final metrics = hueca.metrics;
          final viewCount = metrics['viewCount'] ?? 0;
          final favoriteCount = metrics['favoriteCount'] ?? 0;
          final routeAdditions = metrics['routeAdditions'] ?? 0;
          final stampsGiven = metrics['stampsGiven'] ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myHuecaProvider);
            },
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de Impacto',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Métricas actualizadas en tiempo real sobre cómo los usuarios interactúan con tu Hueca.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppTheme.textMedium,
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildMetricCard(
                        context,
                        title: 'Vistas del Perfil',
                        value: viewCount.toString(),
                        icon: Icons.visibility,
                        color: Colors.blue,
                        isDark: isDark,
                      ),
                      _buildMetricCard(
                        context,
                        title: 'En Favoritos',
                        value: favoriteCount.toString(),
                        icon: Icons.favorite,
                        color: Colors.red,
                        isDark: isDark,
                      ),
                      _buildMetricCard(
                        context,
                        title: 'En Rutas',
                        value: routeAdditions.toString(),
                        icon: Icons.map,
                        color: Colors.green,
                        isDark: isDark,
                      ),
                      _buildMetricCard(
                        context,
                        title: 'Sellos Dados',
                        value: stampsGiven.toString(),
                        icon: Icons.local_activity,
                        color: Colors.orange,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 32),
                  
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.star, color: AppTheme.primary, size: 32),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calificación Promedio',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : AppTheme.textMedium,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    hueca.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppTheme.textDark,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '(${hueca.reviewCount} reseñas)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white54 : AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color, required bool isDark}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
