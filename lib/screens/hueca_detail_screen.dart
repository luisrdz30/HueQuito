import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/utils/auth_utils.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HuecaDetailScreen extends ConsumerStatefulWidget {
  final Object? hueca;
  const HuecaDetailScreen({super.key, this.hueca});

  @override
  ConsumerState<HuecaDetailScreen> createState() => _HuecaDetailScreenState();
}

class _HuecaDetailScreenState extends ConsumerState<HuecaDetailScreen> {

  void _showReviewDialog(BuildContext context) {
    final lang = ref.read(settingsProvider).language;
    if (!AuthUtils.checkAuthAndPrompt(context)) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    
    int rating = 0;
    String comment = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(lang == 'es' ? 'Deja tu opinión' : 'Leave your review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setStateSB(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: '¿Qué te pareció? (Opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                    onChanged: (v) => comment = v,
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: rating == 0 ? null : () async {
                        Navigator.pop(context);
                        
                        try {
                          await ref.read(huecaRepositoryProvider).addReview(
                            _currentHueca.id,
                            rating,
                            comment,
                            user.name,
                            user.profilePicUrl,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'es' ? '¡Gracias por tu opinión!' : 'Thanks for your review!')));
                          setState(() {}); // refresh the UI to fetch reviews
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'es' ? 'Error al enviar reseña: $e' : 'Error submitting review: $e')));
                        }
                      },
                      child: Text(lang == 'es' ? 'Enviar Reseña' : 'Submit Review'),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _selectedTabIndex = 1;
  

  late Hueca _currentHueca;

  @override
  void initState() {
    super.initState();
    if (widget.hueca != null && widget.hueca is Hueca) {
      _currentHueca = widget.hueca as Hueca;
    } else {
      // Fallback
      _currentHueca = Hueca(
        id: 'error',
        name: 'Hueca no encontrada',
        description: {'es': 'Error al cargar los datos'},
        address: 'N/A',
        sector: 'N/A',
        location: GeoPoint(-0.22, -78.51),
        phone: 'N/A',
        schedule: {'Lunes - Viernes': 'Cerrado'},
        mainDish: {'name': 'N/A', 'price': 0.0, 'emoji': '🍽️'},
        loyaltyCard: {},
        secretSticker: {},
        menuItems: [],
        tags: [],
        priceLevel: '\$',
        rating: 0.0,
        reviewCount: 0,
        images: ['https://via.placeholder.com/400x300'],
        ownerId: '',
        isActive: true,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final lang = ref.watch(settingsProvider).language;
    final bool isFavorite = user?.favoriteHuecas.contains(_currentHueca.id) ?? false;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            SizedBox(width: 8),
            Text(lang == 'es' ? 'Detalles de Hueca' : 'Spot Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
                      IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              color: isFavorite ? Colors.red : AppTheme.secondary,
              onPressed: () async {
                if (!AuthUtils.checkAuthAndPrompt(context)) return;
                await ref.read(userRepositoryProvider).toggleFavorite(_currentHueca.id);
                ref.invalidate(currentUserProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!isFavorite ? (lang == 'es' ? 'Añadido a favoritos' : 'Added to favorites') : (lang == 'es' ? 'Eliminado de favoritos' : 'Removed from favorites')), duration: Duration(seconds: 1)));
                }
              },
            ),
          IconButton(
            icon: Icon(Icons.share),
            color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
            onPressed: () {
              Share.share(lang == 'es' ? '¡Ven acompáñame a visitar ${_currentHueca.name} conmigo en Hue-Quito! 😋🥘\n\nMira dónde queda aquí: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}' : 'Come visit ${_currentHueca.name} with me on Hue-Quito! 😋🥘\n\nSee where it is here: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel Placeholder
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Image.network(
                        'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=800&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), child: Icon(Icons.restaurant, size: 50, color: Colors.grey)),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: Text(lang == 'es' ? '1 / 5 FOTOS' : '1 / 5 PHOTOS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            
            // Header Info
            Container(
              transform: Matrix4.translationValues(0, -20, 0),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_currentHueca.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(lang == 'es' ? 'Tradición Quiteña' : 'Quito Tradition', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [Icon(Icons.star, color: AppTheme.primary, size: 16), SizedBox(width: 4), Text('4.8', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))]),
                      ),
                      SizedBox(width: 8),
                      Text('(124 reseñas)', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Row(children: [Icon(Icons.near_me, color: AppTheme.primary, size: 16), SizedBox(width: 4), Expanded(child: Text(_currentHueca.sector, style: TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis))])),
                        SizedBox(width: 8),
                        Text(_currentHueca.schedule[lang] ?? _currentHueca.schedule['es'] ?? '08:00 - 16:00', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _openMapsSheet(context),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions), SizedBox(width: 8), Text(lang == 'es' ? 'Cómo llegar' : 'Directions', style: TextStyle(fontSize: 12))]),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final Uri launchUri = Uri(scheme: 'tel', path: '0991234567');
                            await launchUrl(launchUri);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]), foregroundColor: Theme.of(context).colorScheme.onSurface, elevation: 0),
                          child: Column(children: [Icon(Icons.call, size: 20), Text(lang == 'es' ? 'Llamar' : 'Call', style: TextStyle(fontSize: 10))]),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Share.share(lang == 'es' ? '¡Ven acompáñame a visitar ${_currentHueca.name} conmigo en Hue-Quito! 😋🥘\n\nMira dónde queda aquí: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}' : 'Come visit ${_currentHueca.name} with me on Hue-Quito! 😋🥘\n\nSee where it is here: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]), foregroundColor: Theme.of(context).colorScheme.onSurface, elevation: 0),
                          child: Column(children: [Icon(Icons.share, size: 20), Text(lang == 'es' ? 'Enviar' : 'Share', style: TextStyle(fontSize: 10))]),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            // Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab(lang == 'en' ? 'About' : 'Sobre la Hueca', 0),
                  _buildTab(lang == 'en' ? 'Menu' : 'Menú Tradicional', 1),
                  _buildTab(lang == 'en' ? 'Location & Hours' : 'Ubicación & Horario', 2),
                  _buildTab(lang == 'en' ? 'Reviews (${_currentHueca.reviewCount})' : 'Reseñas (${_currentHueca.reviewCount})', 3),
                ],
              ),
            ),
            
            // Content Sections
            Padding(
              padding: EdgeInsets.all(16),
              child: _buildSelectedTabContent(lang),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(String lang) {
    switch (_selectedTabIndex) {
      case 0:
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.info, color: AppTheme.primary), SizedBox(width: 8), Text(lang == 'es' ? 'Sobre la Hueca' : 'About the Place', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              SizedBox(height: 16),
              Text(
                _currentHueca.description[lang] ?? _currentHueca.description['es'] ?? 'Información no disponible.',
                style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), height: 1.5),
              ),
            ],
          ),
        );
      case 1:
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.restaurant_menu, color: AppTheme.primary), SizedBox(width: 8), Text(lang == 'es' ? 'Menú' : 'Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              SizedBox(height: 16),
              if (_currentHueca.menuItems.isEmpty)
                Text(lang == 'es' ? 'Menú no disponible.' : 'Menu not available.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium))),
              ..._currentHueca.menuItems.map((item) {
                final nameObj = item['name'];
                final name = nameObj is Map ? (nameObj[lang] ?? nameObj['es'] ?? 'Plato') : (nameObj ?? 'Plato');
                
                final descObj = item['description'];
                final desc = descObj is Map ? (descObj[lang] ?? descObj['es'] ?? '') : (descObj ?? '');
                
                final price = item['price'] != null ? '\$${item['price']}' : '\$0.00';
                final img = item['image'] ?? 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80';
                return Column(
                  children: [
                    _buildMenuItem(name.toString(), desc.toString(), price.toString(), img.toString()),
                    Divider(),
                  ],
                );
              }),
            ],
          ),
        );
      case 2:
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.location_on, color: AppTheme.primary), SizedBox(width: 8), Text(lang == 'es' ? 'Ubicación & Horarios' : 'Location & Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.map, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium)),
                  SizedBox(width: 8),
                  Expanded(child: Text(_currentHueca.address, style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                height: 150,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_currentHueca.location.latitude, _currentHueca.location.longitude),
                      zoom: 15.0,
                    ),
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    markers: {
                      Marker(
                        markerId: MarkerId('hueca'),
                        position: LatLng(_currentHueca.location.latitude, _currentHueca.location.longitude),
                      )
                    },
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _currentHueca.schedule.entries.isEmpty 
                        ? [Text(lang == 'es' ? 'Horario no disponible' : 'Hours not available', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))]
                        : _currentHueca.schedule.entries.map((e) => Text('${e.key}: ${e.value}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 3:
      default:
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lang == 'es' ? 'Reseñas Quiteñas' : 'Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(lang == 'es' ? 'Calificación verificada por comensales' : 'Verified rating by diners', style: TextStyle(fontSize: 12, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium)))])),
                  SizedBox(width: 8),
                  ElevatedButton(onPressed: () => _showReviewDialog(context), style: ElevatedButton.styleFrom(backgroundColor: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]), foregroundColor: Theme.of(context).colorScheme.onSurface, elevation: 0), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.edit, size: 16, color: AppTheme.primary), SizedBox(width: 4), Text(lang == 'es' ? 'Opinar' : 'Review')])),
                ],
              ),
              SizedBox(height: 16),
              FutureBuilder<List<Review>>(
                future: ref.read(huecaRepositoryProvider).getReviews(_currentHueca.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(lang == 'es' ? 'Error al cargar reseñas.' : 'Error loading reviews.');
                  }
                  
                  final allReviews = snapshot.data ?? [];
                  if (allReviews.isEmpty) {
                    return Text(lang == 'es' ? 'Sé el primero en dejar una opinión sobre este local.' : 'Be the first to leave a review for this spot.', style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium)));
                  }
                  
                  final goodReviews = allReviews.where((r) => r.rating >= 4).toList();
                  final avgReviews = allReviews.where((r) => r.rating == 3).toList();
                  final badReviews = allReviews.where((r) => r.rating <= 2).toList();
                  
                  goodReviews.shuffle();
                  avgReviews.shuffle();
                  badReviews.shuffle();
                  
                  final displayReviews = <Review>[];
                  displayReviews.addAll(goodReviews.take(5));
                  if (avgReviews.isNotEmpty) displayReviews.add(avgReviews.first);
                  if (badReviews.isNotEmpty) displayReviews.add(badReviews.first);
                  
                  return Column(
                    children: displayReviews.map((r) => _buildReviewItem(r)).toList(),
                  );
                },
              ),
            ],
          ),
        );
    }
  }

  void _openMapsSheet(BuildContext context) async {
    final lang = ref.read(settingsProvider).language;
    final availableMaps = await MapLauncher.installedMaps;
    if (!context.mounted) return;
    if (availableMaps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang == 'es' ? 'No hay mapas instalados' : 'No maps installed')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(lang == 'es' ? 'Abrir ubicación con' : 'Open location with', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Wrap(
                  children: <Widget>[
                    for (var map in availableMaps)
                      ListTile(
                        onTap: () => map.showMarker(
                          coords: Coords(_currentHueca.location.latitude, _currentHueca.location.longitude),
                          title: _currentHueca.name,
                          description: _currentHueca.address,
                        ),
                        title: Text(map.mapName),
                        leading: Icon(Icons.map),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isActive ? AppTheme.tertiary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200]), borderRadius: BorderRadius.circular(20)),
        child: Text(title, style: TextStyle(color: isActive ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMenuItem(String title, String desc, String price, String imageUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 4),
              Text(desc, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              SizedBox(height: 8),
              Text(price, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        SizedBox(width: 12),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 60, height: 60, color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]), child: Icon(Icons.fastfood, color: Colors.grey)))),
      ],
    );
  }

  Widget _buildReviewItem(Review r) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100]), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16, 
                backgroundImage: r.userPic.isNotEmpty ? NetworkImage(r.userPic) : null,
                child: r.userPic.isEmpty ? Text(r.userName.isNotEmpty ? r.userName[0].toUpperCase() : 'U') : null,
              ),
              SizedBox(width: 8),
              Expanded(child: Text(r.userName, style: TextStyle(fontWeight: FontWeight.bold))),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < r.rating ? Icons.star : Icons.star_border, 
                  color: AppTheme.primary, 
                  size: 12
                )),
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(r.comment, style: TextStyle(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium), fontSize: 12)),
          ]
        ],
      ),
    );
  }
}
