import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';

class TourModeSelectionDialog extends StatelessWidget {
  final String language;

  const TourModeSelectionDialog({
    super.key,
    this.language = 'es',
  });

  static Future<void> show(BuildContext context, {String language = 'es'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TourModeSelectionDialog(language: language),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = language == 'en';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Create your own Tour' : 'Crea tu Propio Tour',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? 'How would you like to plan your route today?' : '¿Cómo prefieres armar tu recorrido hoy?',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Option 1: Wizard / Asistido
          _buildOptionCard(
            context,
            isDark: isDark,
            isRecommended: true,
            badge: isEn ? '⭐ Recommended' : '⭐ Recomendado',
            icon: Icons.auto_awesome,
            iconBg: AppTheme.primary,
            title: isEn ? 'Question-guided Tour' : 'Tour Asistido por Preguntas',
            subtitle: isEn
                ? 'Answer a few quick cravings questions. We recommend top spots ordered by driving proximity from your previous stop.'
                : 'Responde qué antojos tienes y cuántas paradas harás. Te sugerimos huecas priorizando las más cercanas para ahorrar tiempo en auto.',
            onTap: () {
              Navigator.pop(context);
              context.push('/tour_wizard');
            },
          ),
          const SizedBox(height: 14),

          // Option 2: Libre / A mi manera
          _buildOptionCard(
            context,
            isDark: isDark,
            isRecommended: false,
            badge: isEn ? '🛠️ Total freedom' : '🛠️ Total libertad',
            icon: Icons.tune_rounded,
            iconBg: const Color(0xFF10B981),
            title: isEn ? 'Build it My Way' : 'Armar a mi Manera',
            subtitle: isEn
                ? 'Freely pick huecas from the catalog, drag and reorder stops, and get estimated distance and driving time.'
                : 'Elige libremente las huecas de la lista, reordena las paradas arrastrándolas y mira la distancia y tiempo en carro.',
            onTap: () {
              Navigator.pop(context);
              context.push('/create_tour');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required bool isDark,
    required bool isRecommended,
    required String badge,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRecommended
                  ? AppTheme.primary.withOpacity(0.6)
                  : (isDark ? Colors.grey[800]! : Colors.grey[250] ?? Colors.grey[300]!),
              width: isRecommended ? 1.8 : 1.0,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconBg, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isRecommended
                                ? AppTheme.primary.withOpacity(0.12)
                                : (isDark ? Colors.grey[800] : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isRecommended ? AppTheme.primary : (isDark ? Colors.white70 : AppTheme.textMedium),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white70 : AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isRecommended ? AppTheme.primary : (isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
