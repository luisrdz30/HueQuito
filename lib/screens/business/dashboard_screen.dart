import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/widgets/business_onboarding_dialog.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/widgets/delete_hueca_dialog.dart';

class BusinessDashboardScreen extends ConsumerStatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  ConsumerState<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends ConsumerState<BusinessDashboardScreen> {
  String? _syncedHuecaId;
  String? _checkedTutorialHuecaId;

  Stream<DocumentSnapshot?> _getHuecaStream(String huecaId) {
    try {
      return FirebaseFirestore.instance.collection('huecas').doc(huecaId).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  void _triggerSyncIfNeeded(String huecaId) {
    if (_syncedHuecaId == huecaId) return;
    _syncedHuecaId = huecaId;
    Future.microtask(() {
      if (mounted) {
        try {
          ref.read(huecaRepositoryProvider).syncHuecaMetrics(huecaId);
        } catch (_) {}
      }
    });
  }

  void _checkFirstTimeTutorial(Hueca hueca) {
    if (_checkedTutorialHuecaId == hueca.id) return;
    _checkedTutorialHuecaId = hueca.id;
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasSeen = prefs.getBool('has_seen_business_tutorial_${hueca.id}') ?? false;
        if (!hasSeen && mounted) {
          showBusinessOnboardingDialog(context, hueca);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final huecaAsync = ref.watch(myHuecaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text('Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'Guía del Negocio',
            onPressed: () {
              final hueca = ref.read(myHuecaProvider).value;
              if (hueca != null) {
                showBusinessOnboardingDialog(context, hueca, markAsSeen: false);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Opciones de Negocio',
            onSelected: (val) {
              if (val == 'delete') {
                final hueca = ref.read(myHuecaProvider).value;
                if (hueca != null) {
                  showDeleteHuecaConfirmationDialog(
                    context: context,
                    ref: ref,
                    hueca: hueca,
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Eliminar Hueca',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: huecaAsync.when(
        data: (hueca) {
          if (hueca == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (FirebaseAuth.instance.currentUser == null && context.mounted) {
                context.go('/login');
              }
            });
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No tienes una Hueca asignada a esta cuenta.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar Sesión / Cambiar Cuenta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        ref.invalidate(currentUserProvider);
                        ref.invalidate(myHuecaProvider);
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Trigger automatic real metrics synchronization and first-time tutorial
          _triggerSyncIfNeeded(hueca.id);
          _checkFirstTimeTutorial(hueca);

          return StreamBuilder<DocumentSnapshot?>(
            stream: _getHuecaStream(hueca.id),
            builder: (context, snapshot) {
              final docData = snapshot.data?.data() as Map<String, dynamic>?;

              final metrics = (docData != null && docData['metrics'] is Map)
                  ? Map<String, dynamic>.from(docData['metrics'])
                  : hueca.metrics;

              final viewCount = metrics['viewCount'] ?? 0;
              final favoriteCount = metrics['favoriteCount'] ?? 0;
              final routeAdditions = metrics['routeAdditions'] ?? 0;
              final stampsGiven = metrics['stampsGiven'] ?? 0;
              final reviewCount = (docData != null && docData.containsKey('reviewCount'))
                  ? (docData['reviewCount'] ?? 0)
                  : hueca.reviewCount;

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(huecaRepositoryProvider).syncHuecaMetrics(hueca.id);
                  ref.invalidate(huecasProvider);
                  ref.invalidate(myHuecaProvider);
                },
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header gradient section
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(24, 32, 24, 48),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Resumen de Impacto',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Actualizado en tiempo real',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 32),
                            // Big View Count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility, color: Colors.white, size: 40),
                                SizedBox(width: 16),
                                Text(
                                  viewCount.toString(),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Vistas Totales del Perfil',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Shifted up grid
                      Transform.translate(
                        offset: Offset(0, -30),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      title: 'Favoritos',
                                      value: favoriteCount.toString(),
                                      icon: Icons.favorite,
                                      color: Colors.red,
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      title: 'En Rutas',
                                      value: routeAdditions.toString(),
                                      icon: Icons.map,
                                      color: Colors.green,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      title: 'Sellos Dados',
                                      value: stampsGiven.toString(),
                                      icon: Icons.local_activity,
                                      color: Colors.orange,
                                      isDark: isDark,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      title: 'Reseñas',
                                      value: reviewCount.toString(),
                                      icon: Icons.rate_review,
                                      color: Colors.blue,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Banner interactivo: Guía y tutorial para poner el negocio en orden
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.rocket_launch, color: Colors.amber, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '¿Cómo funciona tu panel?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Aprende a poner tu negocio en orden, subir fotos, digitalizar tu menú con IA y dar sellos.',
                                      style: TextStyle(color: Colors.blueGrey.shade200, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => showBusinessOnboardingDialog(context, hueca, markAsSeen: false),
                                child: const Text('Ver Guía', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Weekly Progress
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progreso Semanal',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850]! : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Meta de vistas (1000)', style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textMedium)),
                                      Text('${((viewCount / 1000) * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: (viewCount / 1000).clamp(0.0, 1.0),
                                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Meta de favoritos (100)', style: TextStyle(color: isDark ? Colors.white70 : AppTheme.textMedium)),
                                      Text('${((favoriteCount / 100) * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: (favoriteCount / 100).clamp(0.0, 1.0),
                                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color, required bool isDark}) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850]! : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
