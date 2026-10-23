import 'package:hue_quito/widgets/brand_logo.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  int _selectedTab = 0; // 0 for Huecas, 1 for Sectores
  Map<String, dynamic>? _guestGamification;

  @override
  void initState() {
    super.initState();
    _loadGuestGamification();
    // Auto-sincronizar datos frescos del usuario al abrir el álbum
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(currentUserProvider);
      }
    });
  }

  Future<void> _loadGuestGamification() async {
    final data = await UserRepository.getGuestGamification();
    if (mounted) {
      setState(() {
        _guestGamification = data;
      });
    }
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(currentUserProvider);
    ref.invalidate(huecasProvider);
    await Future.wait([
      ref.read(currentUserProvider.future),
      ref.read(huecasProvider.future),
      _loadGuestGamification(),
    ]);
  }

  int _getUserStampsForHueca(Map<String, dynamic>? stampsMap, String huecaId) {
    if (stampsMap == null) return 0;
    final cleanId = huecaId.trim();
    if (stampsMap.containsKey(cleanId)) {
      return (stampsMap[cleanId] as num?)?.toInt() ?? 0;
    }
    if (stampsMap.containsKey(huecaId)) {
      return (stampsMap[huecaId] as num?)?.toInt() ?? 0;
    }
    for (final entry in stampsMap.entries) {
      if (entry.key.toString().trim() == cleanId) {
        return (entry.value as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const HueQuitoLogo(height: 32),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.chulpiCream.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.chulpiCream, width: 0.8),
              ),
              child: Text(
                lang == 'es' ? 'Mi Álbum' : 'My Album',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.deepEarthBrown,
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: userAsync.when(
        data: (user) {
          final isGuest = user == null;

          final displayUser = user ?? UserModel(
            uid: 'guest',
            email: '',
            name: lang == 'es' ? 'Invitado' : 'Guest',
            profilePicUrl: 'https://ui-avatars.com/api/?name=Invitado&background=random',
            gamification: _guestGamification ?? {
              'level': 1,
              'points': 0,
              'totalStamps': 0,
              'title': 'Explorador',
              'huecaStamps': <String, dynamic>{},
              'collectedStickers': <dynamic>[],
            },
            preferences: {},
            sectorAlbums: [],
          );

          // Filtrar y calcular sellos exclusivamente de huecas activas y confirmadas
          final allHuecas = huecasAsync.value ?? [];
          final userHuecaStamps = displayUser.gamification['huecaStamps'] is Map
              ? Map<String, dynamic>.from(displayUser.gamification['huecaStamps'])
              : null;

          int totalConfirmedStamps = 0;
          for (final h in allHuecas.where((h) => h.isActive && h.isSectorConfirmed)) {
            totalConfirmedStamps += _getUserStampsForHueca(userHuecaStamps, h.id);
          }

          final int totalStamps = huecasAsync.value != null
              ? totalConfirmedStamps
              : (displayUser.gamification['totalStamps'] ?? 0);

          return Column(
            children: [
              // User Status Section
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      backgroundImage: NetworkImage(displayUser.profilePicUrl),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayUser.name, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(displayUser.gamification['title'] ?? (lang == 'es' ? 'Novato' : 'Rookie'), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(lang == 'es' ? '$totalStamps Sellos Totales' : '$totalStamps Total Stamps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isGuest)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lang == 'es'
                              ? 'Progreso guardado en este celular. Inicia sesión para respaldar en la nube.'
                              : 'Progress saved on this device. Log in to sync to the cloud.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tabs
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.primary : Colors.white) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                          ),
                          child: Center(
                            child: Text(lang == 'es' ? 'Cartillas por Hueca' : 'Cards by Spot', style: TextStyle(
                              color: _selectedTab == 0 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? (Theme.of(context).brightness == Brightness.dark ? AppTheme.primary : Colors.white) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                          ),
                          child: Center(
                            child: Text(lang == 'es' ? 'Cromos por Sector' : 'Stickers by Sector', style: TextStyle(
                              color: _selectedTab == 1 ? (Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.primary) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Content List
              Expanded(
                child: _selectedTab == 0
                    ? _buildHuecasList(huecasAsync, displayUser, isGuest, lang)
                    : _buildSectorList(huecasAsync, displayUser, isGuest, lang),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      )),
    );
  }

  Widget _buildHuecasList(AsyncValue<List<Hueca>> huecasAsync, UserModel user, bool isGuest, String lang) {
    return huecasAsync.when(
      data: (huecas) {
        if (huecas.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: 300,
              alignment: Alignment.center,
              child: Text(lang == 'es' ? 'No hay huecas disponibles' : 'No huecas available'),
            ),
          );
        }

        final userStampsMap = user.gamification['huecaStamps'] is Map
            ? Map<String, dynamic>.from(user.gamification['huecaStamps'])
            : null;

        var activeHuecas = huecas.where((Hueca h) {
          // Los sellos de huecas no confirmadas o inactivas no deben salir ni contarse
          if (!h.isSectorConfirmed || !h.isActive) return false;
          return _getUserStampsForHueca(userStampsMap, h.id) > 0;
        }).toList();

        if (activeHuecas.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.loyalty_outlined,
                            size: 64,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            lang == 'es' ? '¡Tu cartilla está esperando!' : 'Your card is waiting!',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang == 'es'
                                ? 'Aún no tienes sellos en ninguna hueca.\n¡Visita un local y empieza a coleccionar!'
                                : 'You have no stamps yet in any spot.\nVisit a local and start collecting!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
          itemCount: activeHuecas.length,
          itemBuilder: (context, index) {
            final hueca = activeHuecas[index];
            final currentStamps = _getUserStampsForHueca(userStampsMap, hueca.id);
            int targetStamps = hueca.loyaltyCard['maxStamps'] ?? hueca.loyaltyCard['targetStamps'] ?? 5;
            String reward = '';
            if (hueca.loyaltyCard['rewardText'] is Map) {
              reward = hueca.loyaltyCard['rewardText'][lang]?.toString() ?? hueca.loyaltyCard['rewardText']['es']?.toString() ?? '';
            } else if (hueca.loyaltyCard['rewardText'] != null) {
              reward = hueca.loyaltyCard['rewardText'].toString();
            } else if (hueca.loyaltyCard['reward'] != null) {
              reward = hueca.loyaltyCard['reward'].toString();
            }
            if (reward.isEmpty) {
              reward = lang == 'es' ? 'Recompensa sorpresa' : 'Surprise reward';
            }
            final stampImageUrl = hueca.loyaltyCard['stampImage']?.toString() ??
                (hueca.loyaltyCard['image']?.toString() ?? '');
            final rewardImageUrl = hueca.loyaltyCard['rewardImage']?.toString() ?? '';

            return _buildHuecaCard(
              lang: lang,
              hueca: hueca,
              user: user,
              currentStamps: currentStamps,
              targetStamps: targetStamps,
              reward: reward,
              stampImageUrl: stampImageUrl.isNotEmpty ? stampImageUrl : null,
              rewardImageUrl: rewardImageUrl.isNotEmpty ? rewardImageUrl : null,
              isGuest: isGuest,
              context: context,
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(lang == 'es' ? 'Error cargando cartillas' : 'Error loading cards')),
    );
  }

  Widget _buildHuecaCard({
    required String lang,
    required Hueca hueca,
    required UserModel user,
    required int currentStamps,
    required int targetStamps,
    required String reward,
    String? stampImageUrl,
    String? rewardImageUrl,
    required bool isGuest,
    required BuildContext context,
  }) {
    final bool isCompleted = currentStamps >= targetStamps;
    final int cardStampsFilled = isCompleted ? targetStamps : currentStamps;
    final int extraStamps = isCompleted ? (currentStamps - targetStamps) : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: isCompleted ? Border.all(color: AppTheme.accentGreen.withOpacity(0.4), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hueca.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.accentGreen.withOpacity(0.18) : AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompleted
                      ? (extraStamps > 0
                          ? (lang == 'es' ? '¡Completa! (+$extraStamps extra)' : 'Full! (+$extraStamps extra)')
                          : (lang == 'es' ? '¡Completado!' : 'Completed!'))
                      : (lang == 'es' ? '$currentStamps/$targetStamps Sellos' : '$currentStamps/$targetStamps Stamps'),
                  style: TextStyle(
                    color: isCompleted ? Colors.green[800] : AppTheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Stamp visualization
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(targetStamps, (index) {
              bool isStamped = index < cardStampsFilled;
              return Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStamped
                      ? AppTheme.primary.withOpacity(0.1)
                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                  border: Border.all(
                    color: isStamped
                        ? AppTheme.primary
                        : (isDark ? Colors.grey[700] : Colors.grey[300])!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isStamped
                      ? ((stampImageUrl != null && stampImageUrl.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                stampImageUrl,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.check_circle, color: AppTheme.primary, size: 28),
                              ),
                            )
                          : Icon(Icons.check_circle, color: AppTheme.primary, size: 28))
                      : Icon(Icons.restaurant, color: Colors.grey[400], size: 20),
                ),
              );
            }),
          ),

          // Indicador de sellos guardados de más
          if (extraStamps > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.amber.withOpacity(0.12) : const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.amber.shade700 : Colors.amber.shade400,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.archive_outlined, color: Colors.amber.shade900, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              lang == 'es'
                                  ? '+$extraStamps ${extraStamps == 1 ? "sello guardado" : "sellos guardados"} de más'
                                  : '+$extraStamps extra ${extraStamps == 1 ? "stamp" : "stamps"} stored',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lang == 'es' ? 'SEGURO' : 'SAFE',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang == 'es'
                              ? 'Al reclamar tu premio, estos $extraStamps ${extraStamps == 1 ? "sello no se perderá y quedará" : "sellos no se perderán y quedarán"} en tu siguiente cartilla.'
                              : 'Upon claiming, your $extraStamps extra ${extraStamps == 1 ? "stamp" : "stamps"} will be preserved in your next card.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              if (rewardImageUrl != null && rewardImageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    rewardImageUrl,
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.card_giftcard, size: 18, color: AppTheme.accentRed),
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                Icon(Icons.card_giftcard, size: 18, color: AppTheme.accentRed),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  lang == 'es' ? 'Recompensa: $reward' : 'Reward: $reward',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.textMedium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Botón de Reclamar Recompensa
          if (isCompleted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _showClaimRewardDialog(
                  hueca: hueca,
                  user: user,
                  isGuest: isGuest,
                  currentStamps: currentStamps,
                  targetStamps: targetStamps,
                  extraStamps: extraStamps,
                  reward: reward,
                  rewardImageUrl: rewardImageUrl,
                  lang: lang,
                ),
                icon: const Icon(Icons.celebration, size: 18),
                label: Text(
                  lang == 'es' ? 'Reclamar Premio' : 'Claim Reward',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Diálogo interactivo para reclamar el premio y preservar los sellos de más
  Future<void> _showClaimRewardDialog({
    required Hueca hueca,
    required UserModel user,
    required bool isGuest,
    required int currentStamps,
    required int targetStamps,
    required int extraStamps,
    required String reward,
    String? rewardImageUrl,
    required String lang,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang == 'es' ? '¡Reclamar Premio!' : 'Claim Reward!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hueca.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (rewardImageUrl != null && rewardImageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        rewardImageUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 30, color: AppTheme.primary),
                      ),
                    )
                  else
                    const Icon(Icons.card_giftcard, size: 36, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es' ? 'Premio a recibir:' : 'Reward to claim:',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          reward,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'es' ? 'Detalle de sellos:' : 'Stamps breakdown:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang == 'es'
                        ? '• Sellos canjeados: $targetStamps sellos'
                        : '• Redeemed stamps: $targetStamps stamps',
                    style: TextStyle(fontSize: 11.5, color: Colors.green.shade900),
                  ),
                  Text(
                    lang == 'es'
                        ? '• Sellos que conservas: $extraStamps sellos'
                        : '• Retained stamps: $extraStamps stamps',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.green.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lang == 'es'
                  ? 'Muestra esta confirmación al personal del local para recibir tu beneficio.'
                  : 'Show this confirmation to the local staff to receive your benefit.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang == 'es' ? 'Cancelar' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(lang == 'es' ? 'Confirmar Canje' : 'Confirm Claim'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final userRepo = ref.read(userRepositoryProvider);
      final remaining = await userRepo.claimHuecaReward(
        uid: isGuest ? 'guest' : user.uid,
        huecaId: hueca.id,
        targetStamps: targetStamps,
        rewardText: reward,
      );

      if (isGuest) {
        await _loadGuestGamification();
      } else {
        ref.invalidate(currentUserProvider);
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 64),
                const SizedBox(height: 12),
                Text(
                  lang == 'es' ? '¡Premio Reclamado con Éxito!' : 'Reward Successfully Claimed!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'es'
                      ? 'Presenta esta pantalla a ${hueca.name} para disfrutar de tu: $reward.'
                      : 'Show this screen at ${hueca.name} to enjoy your: $reward.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    lang == 'es'
                        ? '⭐ Tu siguiente cartilla ya tiene $remaining ${remaining == 1 ? "sello" : "sellos"} acumulados.'
                        : '⭐ Your next card already has $remaining ${remaining == 1 ? "stamp" : "stamps"} accumulated.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(lang == 'es' ? '¡Listo!' : 'Done!'),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  bool _isHuecaStickerUnlocked(Hueca h, UserModel user, bool isGuest) {
    // Si la hueca no está confirmada o está inactiva, no debe desbloquearse ni contarse
    if (!h.isSectorConfirmed || !h.isActive) return false;
    final collected = List<String>.from(user.gamification['collectedStickers'] ?? []);
    final stickerId = h.secretSticker['id']?.toString() ?? '';
    final matrizKey = '${h.id}_matriz';
    if (collected.contains(h.id) ||
        collected.contains(matrizKey) ||
        (stickerId.isNotEmpty && collected.contains(stickerId))) {
      return true;
    }
    for (final b in h.branches) {
      if (collected.contains('${h.id}_${b.id}')) return true;
      if (b.secretSticker != null) {
        final bStickerId = b.secretSticker!['id']?.toString() ?? '';
        if (bStickerId.isNotEmpty && collected.contains(bStickerId)) return true;
      }
    }
    return false;
  }

  String _getSectorStickerName(Hueca h, String lang) {
    final s = h.secretSticker;
    if (s['name'] is Map) {
      return s['name'][lang]?.toString() ?? s['name']['es']?.toString() ?? (lang == 'es' ? 'Cromo Secreto' : 'Secret Sticker');
    }
    if (s['name'] != null && s['name'].toString().isNotEmpty) {
      return s['name'].toString();
    }
    return lang == 'es' ? 'Cromo de ${h.name}' : '${h.name} Sticker';
  }

  String _getSectorStickerImage(Hueca h) {
    final s = h.secretSticker;
    if (s['imageUrl'] != null && s['imageUrl'].toString().isNotEmpty) {
      return s['imageUrl'].toString();
    }
    if (h.images.isNotEmpty) {
      return h.images.first;
    }
    return '';
  }

  Widget _buildSectorList(AsyncValue<List<Hueca>> huecasAsync, UserModel user, bool isGuest, String lang) {
    return huecasAsync.when(
      data: (huecas) {
        if (huecas.isEmpty) {
          return Center(child: Text(lang == 'es' ? 'No hay huecas disponibles' : 'No huecas available'));
        }

        // Agrupar las huecas por sector (solo huecas confirmadas por admin y activas)
        final Map<String, List<Hueca>> sectorsMap = {};
        for (final h in huecas) {
          if (!h.isSectorConfirmed || !h.isActive) continue;
          final rawSector = h.sector.trim();
          final sectorName = rawSector.isNotEmpty && rawSector != 'Todo Quito' ? rawSector : 'Centro Histórico';
          sectorsMap.putIfAbsent(sectorName, () => []).add(h);
        }

        final sortedSectorNames = sectorsMap.keys.toList()..sort();

        if (sortedSectorNames.isEmpty) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            lang == 'es' ? 'Sin cromos por sector' : 'No sector stickers yet',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lang == 'es'
                                ? 'Aún no tienes cromos por sector.\n¡Explora diferentes zonas de Quito para desbloquearlos!'
                                : 'You have no stickers by sector yet.\nExplore different zones of Quito to unlock them!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium,
                              height: 1.4,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
          itemCount: sortedSectorNames.length,
          itemBuilder: (context, index) {
            final sectorName = sortedSectorNames[index];
            final huecasInSector = sectorsMap[sectorName]!;
            final totalStickers = huecasInSector.length;
            final unlockedCount = huecasInSector.where((h) => _isHuecaStickerUnlocked(h, user, isGuest)).length;
            final isCompleted = unlockedCount >= totalStickers && totalStickers > 0;

            return _buildSectorCard(
              lang: lang,
              sectorName: sectorName,
              stickersCount: unlockedCount,
              totalStickers: totalStickers,
              isCompleted: isCompleted,
              huecasInSector: huecasInSector,
              user: user,
              isGuest: isGuest,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(lang == 'es' ? 'Error cargando sectores' : 'Error loading sectors')),
    );
  }

  Widget _buildSectorCard({
    required String lang,
    required String sectorName,
    required int stickersCount,
    required int totalStickers,
    required bool isCompleted,
    required List<Hueca> huecasInSector,
    required UserModel user,
    required bool isGuest,
  }) {
    double progress = totalStickers > 0 ? (stickersCount / totalStickers) : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showSectorStickersModal(
        sectorName: sectorName,
        huecas: huecasInSector,
        user: user,
        isGuest: isGuest,
        lang: lang,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          border: isCompleted ? Border.all(color: AppTheme.accentGreen.withOpacity(0.4), width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted ? AppTheme.accentGreen.withOpacity(0.12) : AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCompleted ? Icons.verified : Icons.map_rounded,
                        color: isCompleted ? AppTheme.accentGreen : AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(sectorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.accentGreen.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCompleted
                            ? (lang == 'es' ? '¡Completo!' : 'Completed!')
                            : '$stickersCount / $totalStickers',
                        style: TextStyle(
                          color: isCompleted ? Colors.green.shade800 : (isDark ? Colors.white70 : AppTheme.textMedium),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang == 'es'
                      ? '$stickersCount de $totalStickers cromos desbloqueados'
                      : '$stickersCount of $totalStickers stickers unlocked',
                  style: TextStyle(
                    color: (isDark ? Colors.white70 : AppTheme.textMedium),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isCompleted ? AppTheme.accentGreen : AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: (isDark ? Colors.grey[800] : Colors.grey[200]),
                valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? AppTheme.accentGreen : AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectorStickersModal({
    required String sectorName,
    required List<Hueca> huecas,
    required UserModel user,
    required bool isGuest,
    required String lang,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalStickers = huecas.length;
    final unlockedHuecas = huecas.where((h) => _isHuecaStickerUnlocked(h, user, isGuest)).toList();
    final unlockedCount = unlockedHuecas.length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.collections_bookmark, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es' ? 'Cromos de $sectorName' : '$sectorName Stickers',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          lang == 'es'
                              ? '$unlockedCount de $totalStickers cromos coleccionados'
                              : '$unlockedCount of $totalStickers collected',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : AppTheme.textMedium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: huecas.length,
                  itemBuilder: (context, index) {
                    final hueca = huecas[index];
                    final isUnlocked = _isHuecaStickerUnlocked(hueca, user, isGuest);
                    final stickerName = _getSectorStickerName(hueca, lang);
                    final stickerImg = _getSectorStickerImage(hueca);

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/hueca_detail', extra: hueca);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUnlocked ? Colors.amber.shade400 : (isDark ? Colors.white12 : Colors.grey.shade300),
                            width: isUnlocked ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isUnlocked ? 0.08 : 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isUnlocked && stickerImg.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        stickerImg,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.amber.shade50,
                                          child: Icon(Icons.star, color: Colors.amber.shade700, size: 40),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          isUnlocked ? Icons.star : Icons.lock_outline,
                                          size: 40,
                                          color: isUnlocked ? Colors.amber : (isDark ? Colors.white24 : Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                  if (isUnlocked)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isUnlocked ? stickerName : (lang == 'es' ? 'Cromo Misterioso' : 'Mystery Sticker'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isUnlocked ? null : (isDark ? Colors.white54 : Colors.grey.shade600),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isUnlocked
                                  ? hueca.name
                                  : (lang == 'es' ? 'Visita ${hueca.name}' : 'Visit ${hueca.name}'),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : AppTheme.textMedium,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
