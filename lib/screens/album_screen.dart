import 'package:hue_quito/repositories/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  int _selectedTab = 0; // 0 for Huecas, 1 for Sectores

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final huecasAsync = ref.watch(huecasProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                Text('Mi Álbum', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
              ],
            )
          ],
        ),
      ),
      body: userAsync.when(
        data: (user) {
          final isGuest = user == null;
          // ignore: unused_local_variable

          final displayUser = user ?? UserModel(
            uid: 'guest',
            email: '',
            name: 'Invitado',
            profilePicUrl: 'https://ui-avatars.com/api/?name=Invitado&background=random',
            gamification: {'level': 1, 'totalStamps': 0, 'title': 'Explorador'},
            preferences: {}, sectorAlbums: [],
          );

          int totalStamps = displayUser.gamification['totalStamps'] ?? 0;

          return Column(
            children: [
              // User Status Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      backgroundImage: NetworkImage(displayUser.profilePicUrl),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayUser.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(displayUser.gamification['title'] ?? 'Novato', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('$totalStamps Sellos Totales', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                          ),
                          child: Center(
                            child: Text('Cartillas por Hueca', style: TextStyle(
                              color: _selectedTab == 0 ? AppTheme.primary : AppTheme.textMedium,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                          ),
                          child: Center(
                            child: Text('Cromos por Sector', style: TextStyle(
                              color: _selectedTab == 1 ? AppTheme.primary : AppTheme.textMedium,
                              fontWeight: FontWeight.bold,
                            )),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Content List
              Expanded(
                child: _selectedTab == 0
                    ? _buildHuecasList(huecasAsync, displayUser, isGuest)
                    : _buildSectorList(displayUser.sectorAlbums),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHuecasList(AsyncValue huecasAsync, user, bool isGuest) {
    return huecasAsync.when(
      data: (huecas) {
        if (huecas.isEmpty) return const Center(child: Text('No hay huecas disponibles'));
        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
          itemCount: huecas.length,
          itemBuilder: (context, index) {
            final hueca = huecas[index];
            int currentStamps = 0;
            if (!isGuest && user.gamification['huecaStamps'] != null) {
              currentStamps = user.gamification['huecaStamps'][hueca.id] ?? 0;
            }
            int targetStamps = hueca.loyaltyCard['targetStamps'] ?? 5;
            String reward = hueca.loyaltyCard['reward'] ?? 'Recompensa sorpresa';
            return _buildHuecaCard(
              title: hueca.name,
              currentStamps: currentStamps,
              targetStamps: targetStamps,
              reward: reward,
              isGuest: isGuest,
              context: context,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const Center(child: Text('Error cargando cartillas')),
    );
  }

  Widget _buildHuecaCard({required String title, required int currentStamps, required int targetStamps, required String reward, required bool isGuest, required BuildContext context}) {
    bool isCompleted = currentStamps >= targetStamps;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompleted ? '¡Completado!' : '$currentStamps/$targetStamps Sellos',
                  style: TextStyle(color: isCompleted ? Colors.green[800] : AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Stamp visualization
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(targetStamps, (index) {
              bool isStamped = index < currentStamps;
              return Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStamped ? AppTheme.primary.withOpacity(0.1) : Colors.grey[200],
                  border: Border.all(color: isStamped ? AppTheme.primary : Colors.grey[300]!, width: 2),
                ),
                child: Center(
                  child: isStamped 
                    ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 28)
                    : Icon(Icons.restaurant, color: Colors.grey[400], size: 20),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.card_giftcard, size: 16, color: AppTheme.accentRed),
              const SizedBox(width: 8),
              Text(
                'Recompensa: $reward',
                style: const TextStyle(color: AppTheme.textMedium, fontSize: 12),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectorList(List<dynamic> sectorAlbums) {
    if (sectorAlbums.isEmpty) {
      return const Center(child: Text('Aún no tienes cromos por sector.', style: TextStyle(color: AppTheme.textMedium)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
      itemCount: sectorAlbums.length,
      itemBuilder: (context, index) {
        final album = sectorAlbums[index];
        return _buildSectorCard(
          sectorName: album['sectorName'] ?? 'Sector',
          stickersCount: (album['foundStickers'] as List).length,
          totalStickers: 10, // hardcoded max for now
          isCompleted: album['isCompleted'] ?? false,
        );
      },
    );
  }

  Widget _buildSectorCard({required String sectorName, required int stickersCount, required int totalStickers, required bool isCompleted}) {
    double progress = stickersCount / totalStickers;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(sectorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (isCompleted)
                const Icon(Icons.verified, color: AppTheme.accentGreen)
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$stickersCount de $totalStickers cromos', style: const TextStyle(color: AppTheme.textMedium, fontSize: 12)),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          )
        ],
      ),
    );
  }
}
