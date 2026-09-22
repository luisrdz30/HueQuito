import 'package:flutter/material.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  int _selectedTab = 0; // 0 for Huecas, 1 for Sectores

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
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
        actions: const [],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Passport Hero Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary, Color(0xFF6C0F00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: AppTheme.secondary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.workspace_premium, color: Colors.white, size: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PASAPORTE GASTRONÓMICO · QUITO 2024', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                            const Text('Saboreador Quiteño', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Text('Nivel 3', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('14 de 30 Huecas Selladas', style: TextStyle(color: Colors.white, fontSize: 12)),
                      Text('46% General', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(value: 0.46, backgroundColor: Colors.black26, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(children: [Text('350', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('Puntos', style: TextStyle(color: Colors.white70, fontSize: 10))]),
                        Column(children: [Text('14', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('Sellos', style: TextStyle(color: Colors.white70, fontSize: 10))]),
                        Column(children: [Text('Nivel 3', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)), Text('Rango', style: TextStyle(color: Colors.white70, fontSize: 10))]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.loyalty, size: 16, color: _selectedTab == 0 ? Colors.white : AppTheme.textMedium),
                              const SizedBox(width: 4),
                              Text('Cartillas por Hueca', style: TextStyle(color: _selectedTab == 0 ? Colors.white : AppTheme.textMedium, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? AppTheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.explore, size: 16, color: _selectedTab == 1 ? Colors.white : AppTheme.textMedium),
                              const SizedBox(width: 4),
                              Text('Cromos de Sector', style: TextStyle(color: _selectedTab == 1 ? Colors.white : AppTheme.textMedium, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Tab Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _selectedTab == 0 ? _buildHuecasTab() : _buildSectoresTab(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHuecasTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Icon(Icons.storefront, color: AppTheme.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Fidelidad con tu negocio favorito: Cada hueca define su cartilla. Al llenarla, ganas tu premio.', style: TextStyle(fontSize: 12))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLoyaltyCard(
          context: context,
          imageUrl: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80',
          title: 'Hornado San Francisco',
          location: 'Mercado San Francisco #04',
          currentStamps: 7,
          maxStamps: 10,
          reward: '1 Hornado Especial Gratis',
        ),
        const SizedBox(height: 16),
        _buildLoyaltyCard(
          context: context,
          imageUrl: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=150&q=80',
          title: 'Morocho de La Floresta',
          location: 'Parque Navarro, La Floresta',
          currentStamps: 4,
          maxStamps: 4,
          reward: '1 Vaso de Morocho + 2 Empanadas',
        ),
      ],
    );
  }

  Widget _buildSectoresTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.tertiary, Color(0xFF3B5347)]), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.pin_drop, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Álbum de Sectores', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Escanea todos los QR escondidos en cada zona para ganar premios del sector.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectorCard(
          title: 'Sector Conocoto',
          completed: 3,
          total: 5,
        ),
      ],
    );
  }

  Widget _buildLoyaltyCard({required String imageUrl, required String title, required String location, required int currentStamps, required int maxStamps, required String reward, required BuildContext context}) {
    bool isCompleted = currentStamps >= maxStamps;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(imageUrl)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.location_on, size: 12, color: AppTheme.secondary), const SizedBox(width: 4), Text(location, style: const TextStyle(fontSize: 10, color: AppTheme.textMedium))]),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isCompleted ? AppTheme.secondary.withValues(alpha: 0.1) : AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text('$currentStamps / $maxStamps', style: TextStyle(color: isCompleted ? AppTheme.secondary : AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 16),
          if (isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3))),
              child: Column(
                children: [
                  const Icon(Icons.verified, color: AppTheme.secondary, size: 40),
                  const SizedBox(height: 8),
                  const Text('¡Cartilla Completada!', style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _showRewardQR(context, title, reward);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary, foregroundColor: Colors.white),
                    child: const Text('Reclamar premio'),
                  )
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(maxStamps, (index) {
                  if (index < currentStamps) {
                    return Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primary, width: 2),
                        image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                      ),
                    );
                  } else if (index == maxStamps - 1) {
                    return Container(width: 44, height: 44, decoration: BoxDecoration(border: Border.all(color: AppTheme.secondary, width: 2), shape: BoxShape.circle), child: const Icon(Icons.card_giftcard, color: AppTheme.secondary, size: 20));
                  } else {
                    return Container(width: 44, height: 44, decoration: BoxDecoration(border: Border.all(color: Colors.grey, width: 2), shape: BoxShape.circle), child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))));
                  }
                }),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: AppTheme.secondary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Recompensa: $reward', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          )
        ],
      ),
    );
  }

  void _showRewardQR(BuildContext context, String title, String reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código de Reclamo', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Muestra este QR en $title para recibir tu premio:', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: '{"type":"reward", "business":"$title", "reward":"$reward"}',
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(reward, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cartilla reiniciada con éxito.')));
            },
            child: const Text('Simular Escaneo (Reiniciar)', style: TextStyle(color: AppTheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          )
        ],
      ),
    );
  }

  Widget _buildSectorCard({required String title, required int completed, required int total}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$title ($completed / $total)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: completed / total, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation(AppTheme.primary)),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('${(completed / total * 100).toInt()}%', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Dummy grid for stickers
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSticker(true, 'Empanadas', 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=150&q=80'),
                      _buildSticker(true, 'Hornado', 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80'),
                      _buildSticker(true, 'Caldo', 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=150&q=80'),
                      _buildSticker(false, 'Misterio 1'),
                      _buildSticker(false, 'Misterio 2'),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSticker(bool unlocked, String name, [String imageUrl = '']) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: unlocked ? Colors.amber[200] : Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(color: unlocked ? Colors.amber : Colors.grey, width: 2),
            image: unlocked && imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
          ),
          child: unlocked && imageUrl.isNotEmpty ? null : Icon(unlocked ? Icons.restaurant : Icons.lock, color: unlocked ? Colors.deepOrange : Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
