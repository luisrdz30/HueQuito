import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  int _selectedTab = 0; // 0 for Huecas, 1 for Sectores

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
            Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hue-Quito', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                Text(lang == 'es' ? 'Mi Álbum' : 'My Album', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
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
                          Text(displayUser.gamification['title'] ?? 'Novato', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
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
                            color: _selectedTab == 0 ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
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

              SizedBox(height: 16),

              // Content List
              Expanded(
                child: _selectedTab == 0
                    ? _buildHuecasList(huecasAsync, displayUser, isGuest, lang)
                    : _buildSectorList(displayUser.sectorAlbums, lang),
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildHuecasList(AsyncValue<List<Hueca>> huecasAsync, UserModel user, bool isGuest, String lang) {
    return huecasAsync.when(
      data: (huecas) {
        if (huecas.isEmpty) return Center(child: Text(lang == 'es' ? 'No hay huecas disponibles' : 'No huecas available'));

        var activeHuecas = huecas.where((Hueca h) {
          if (isGuest || user.gamification['huecaStamps'] == null) return false;
          return (user.gamification['huecaStamps'][h.id] ?? 0) > 0;
        }).toList();

        if (activeHuecas.isEmpty) {
          return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              lang == 'es' 
                ? 'Aún no tienes sellos en ninguna hueca.
¡Empieza a explorar!'
                : 'You have no stamps yet.
Start exploring!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMedium, height: 1.5),
            ),
          ),
        );
        }

        return ListView.builder(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 80),
          itemCount: activeHuecas.length,
          itemBuilder: (context, index) {
            final hueca = activeHuecas[index];
            int currentStamps = 0;
            if (!isGuest && user.gamification['huecaStamps'] != null) {
              currentStamps = user.gamification['huecaStamps'][hueca.id] ?? 0;
            }
            int targetStamps = hueca.loyaltyCard['targetStamps'] ?? 5;
            String reward = hueca.loyaltyCard['reward'] ?? lang == 'es' ? 'Recompensa sorpresa' : 'Surprise reward';
            return _buildHuecaCard(lang: lang, 
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
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error cargando cartillas')),
    );
  }

  Widget _buildHuecaCard(lang: lang, {required String title, required int currentStamps, required int targetStamps, required String reward, required bool isGuest, required BuildContext context}) {
    bool isCompleted = currentStamps >= targetStamps;
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
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
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.accentGreen.withOpacity(0.2) : AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCompleted ? (lang == 'es' ? '¡Completado!' : 'Completed!') : (lang == 'es' ? '$currentStamps/$targetStamps Sellos' : '$currentStamps/$targetStamps Stamps'),
                  style: TextStyle(color: isCompleted ? Colors.green[800] : AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              )
            ],
          ),
          SizedBox(height: 16),
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
                  color: isStamped ? AppTheme.primary.withOpacity(0.1) : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
                  border: Border.all(color: isStamped ? AppTheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300])!, width: 2),
                ),
                child: Center(
                  child: isStamped 
                    ? Icon(Icons.check_circle, color: AppTheme.primary, size: 28)
                    : Icon(Icons.restaurant, color: Colors.grey[400], size: 20),
                ),
              );
            }),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.card_giftcard, size: 16, color: AppTheme.accentRed),
              SizedBox(width: 8),
              Text(
                lang == 'es' ? 'Recompensa: $reward' : 'Reward: $reward',
                style: TextStyle(color: AppTheme.textMedium, fontSize: 12),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectorList(List<dynamic> sectorAlbums, String lang) {
    if (sectorAlbums.isEmpty) {
      return Center(child: Text(lang == 'es' ? 'Aún no tienes cromos por sector.' : 'No sector stickers yet.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMedium)));
    }

    return ListView.builder(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 80),
      itemCount: sectorAlbums.length,
      itemBuilder: (context, index) {
        final album = sectorAlbums[index];
        return _buildSectorCard(lang: lang, 
          sectorName: album['sectorName'] ?? 'Sector',
          stickersCount: (album['foundStickers'] as List).length,
          totalStickers: 10, // hardcoded max for now
          isCompleted: album['isCompleted'] ?? false,
        );
      },
    );
  }

  Widget _buildSectorCard(lang: lang, {required String sectorName, required int stickersCount, required int totalStickers, required bool isCompleted}) {
    double progress = stickersCount / totalStickers;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
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
                  Icon(Icons.map, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(sectorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              if (isCompleted)
                Icon(Icons.verified, color: AppTheme.accentGreen)
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang == 'es' ? '$stickersCount de $totalStickers cromos' : '$stickersCount of $totalStickers stickers', style: TextStyle(color: AppTheme.textMedium, fontSize: 12)),
              Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          )
        ],
      ),
    );
  }
}
