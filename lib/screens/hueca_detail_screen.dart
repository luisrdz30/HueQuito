import 'package:hue_quito/models/notification_model.dart';
import 'dart:async';
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
import 'package:hue_quito/utils/map_navigation_helper.dart';
import 'package:hue_quito/widgets/delete_hueca_dialog.dart';
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang == 'es' ? 'Deja tu opinión' : 'Leave your review',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                    onChanged: (v) => comment = v,
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: rating == 0
                          ? null
                          : () async {
                              Navigator.pop(context);

                              try {
                                await ref
                                    .read(huecaRepositoryProvider)
                                    .addReview(
                                      _currentHueca.id,
                                      rating,
                                      comment,
                                      user.name,
                                      user.profilePicUrl,
                                      userId: user.uid,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      lang == 'es'
                                          ? '¡Gracias por tu opinión!'
                                          : 'Thanks for your review!',
                                    ),
                                  ),
                                );
                                setState(
                                  () {},
                                ); // refresh the UI to fetch reviews
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      lang == 'es'
                                          ? 'Error al enviar reseña: $e'
                                          : 'Error submitting review: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(
                        lang == 'es' ? 'Enviar Reseña' : 'Submit Review',
                      ),
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
  int _selectedBranchIndex = 0;

  late Hueca _currentHueca;
  late final PageController _imagePageController;
  Timer? _autoPlayTimer;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
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
        metrics: {},
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
    _startAutoPlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordProfileView();
    });
  }

  void _recordProfileView() {
    if (!mounted) return;
    final huecaId = _currentHueca.id.trim();
    if (huecaId.isEmpty || huecaId == 'error') return;
    try {
      ref.read(huecaRepositoryProvider).incrementHuecaViews(huecaId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    final totalImages = _currentHueca.images.isNotEmpty ? _currentHueca.images.length : 1;
    if (totalImages > 1) {
      _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_imagePageController.hasClients) return;
        final nextIndex = (_currentImageIndex + 1) % totalImages;
        _imagePageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  void _onImagePageChanged(int index) {
    setState(() {
      _currentImageIndex = index;
    });
    _startAutoPlay();
  }

  void _openFullScreenGallery(BuildContext context, int initialIndex, {List<String>? customImages, String? title}) {
    final images = customImages ?? (_currentHueca.images.isNotEmpty
        ? _currentHueca.images
        : ['https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=800&q=80']);
    final lang = ref.read(settingsProvider).language;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _FullScreenGalleryViewer(
          images: images,
          initialIndex: initialIndex,
          title: title ?? _currentHueca.name,
          lang: lang,
        ),
      ),
    );
  }

  Future<void> _showNotificationSubscriptionDialog(BuildContext context, bool isSubscribed, String lang) async {
    if (!AuthUtils.checkAuthAndPrompt(context)) return;

    if (!isSubscribed) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active, color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang == 'es' ? '¿Activar notificaciones?' : 'Enable notifications?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'es'
                    ? 'Al activar las notificaciones de "${_currentHueca.name}", recibirás avisos de todas sus promociones, descuentos, nuevos platos y eventos directamente en tu celular.'
                    : 'By enabling notifications for "${_currentHueca.name}", you will receive alerts about promotions, discounts, new dishes, and special events directly on your phone.',
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang == 'es'
                            ? 'Solo te llegarán avisos de las huecas que tú decidas seguir.'
                            : 'You will only receive alerts from spots you choose to follow.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang == 'es' ? 'No, gracias' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lang == 'es' ? 'Sí, activar' : 'Yes, enable'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(userRepositoryProvider).toggleNotificationSubscription(_currentHueca.id);
        ref.invalidate(currentUserProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang == 'es'
                    ? '🔔 ¡Notificaciones activadas para ${_currentHueca.name}!'
                    : '🔔 Notifications enabled for ${_currentHueca.name}!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off_outlined, color: Colors.grey, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang == 'es' ? 'Notificaciones activas' : 'Notifications enabled',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            lang == 'es'
                ? 'Actualmente estás recibiendo noticias y promociones de "${_currentHueca.name}". ¿Deseas desactivarlas?'
                : 'You are currently receiving promotions and news from "${_currentHueca.name}". Do you want to disable them?',
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang == 'es' ? 'Mantener activas' : 'Keep enabled'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(lang == 'es' ? 'Desactivar' : 'Disable'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await ref.read(userRepositoryProvider).toggleNotificationSubscription(_currentHueca.id);
        ref.invalidate(currentUserProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang == 'es'
                    ? '🔕 Notificaciones desactivadas para esta hueca'
                    : '🔕 Notifications disabled for this spot',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final lang = ref.watch(settingsProvider).language;
    final bool isFavorite =
        user?.favoriteHuecas.contains(_currentHueca.id) ?? false;
    final bool isSubscribed =
        user?.subscribedHuecas.contains(_currentHueca.id) ?? false;
    final bool isHuecaOwner = (user != null && user.uid == _currentHueca.ownerId) ||
        user?.role == 'admin';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                lang == 'es' ? 'Detalles de Hueca' : 'Spot Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            color: isFavorite ? Colors.red : AppTheme.secondary,
            onPressed: () async {
              if (!AuthUtils.checkAuthAndPrompt(context)) return;
              await ref
                  .read(userRepositoryProvider)
                  .toggleFavorite(_currentHueca.id);
              ref.invalidate(currentUserProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      !isFavorite
                          ? (lang == 'es'
                                ? 'Añadido a favoritos'
                                : 'Added to favorites')
                          : (lang == 'es'
                                ? 'Eliminado de favoritos'
                                : 'Removed from favorites'),
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.share),
            color: (Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : AppTheme.textMedium),
            onPressed: () {
              Share.share(
                lang == 'es'
                    ? '¡Ven acompáñame a visitar ${_currentHueca.name} conmigo en Hue-Quito! 😋🥘\n\nMira dónde queda aquí: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}'
                    : 'Come visit ${_currentHueca.name} with me on Hue-Quito! 😋🥘\n\nSee where it is here: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}',
              );
            },
          ),
          if (isHuecaOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: lang == 'es' ? 'Eliminar Hueca' : 'Delete Hueca',
              onPressed: () => showDeleteHuecaConfirmationDialog(
                context: context,
                ref: ref,
                hueca: _currentHueca,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _openFullScreenGallery(context, _currentImageIndex),
                    child: PageView.builder(
                      controller: _imagePageController,
                      itemCount: _currentHueca.images.isNotEmpty
                          ? _currentHueca.images.length
                          : 1,
                      onPageChanged: _onImagePageChanged,
                      itemBuilder: (context, index) {
                        final imageUrl = _currentHueca.images.isNotEmpty
                            ? _currentHueca.images[index]
                            : 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=800&q=80';
                        return Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[700]
                                : Colors.grey[300]),
                            child: const Icon(
                              Icons.restaurant,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Fullscreen button (top right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _openFullScreenGallery(context, _currentImageIndex),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  // Dynamic Photo Counter Badge (bottom right)
                  Positioned(
                    bottom: 24,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _openFullScreenGallery(context, _currentImageIndex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              lang == 'es'
                                  ? '${_currentImageIndex + 1} de ${_currentHueca.images.isNotEmpty ? _currentHueca.images.length : 1} FOTOS'
                                  : '${_currentImageIndex + 1} of ${_currentHueca.images.isNotEmpty ? _currentHueca.images.length : 1} PHOTOS',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Progress Dots (bottom left)
                  if (_currentHueca.images.length > 1)
                    Positioned(
                      bottom: 28,
                      left: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _currentHueca.images.length,
                          (dotIdx) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: dotIdx == _currentImageIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: dotIdx == _currentImageIndex
                                  ? AppTheme.primary
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                  if (!_currentHueca.isActive) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pause_circle_filled, color: Colors.blueGrey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang == 'es'
                                  ? 'Esta hueca está pausada temporalmente por administración.'
                                  : 'This spot is temporarily paused by administration.',
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentHueca.name,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              lang == 'es' ? 'Tradición Quiteña' : 'Quito Tradition',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: lang == 'es' ? 'Avisos y Promociones' : 'Alerts & Deals',
                        style: IconButton.styleFrom(
                          backgroundColor: isSubscribed
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200]),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: Icon(
                          isSubscribed ? Icons.notifications_active : Icons.notifications_none,
                          color: isSubscribed
                              ? AppTheme.primary
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87),
                          size: 24,
                        ),
                        onPressed: () => _showNotificationSubscriptionDialog(context, isSubscribed, lang),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: AppTheme.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _currentHueca.reviewCount > 0
                                  ? _currentHueca.rating.toStringAsFixed(1)
                                  : (lang == 'es' ? 'Nuevo' : 'New'),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentHueca.reviewCount > 0
                            ? (lang == 'es'
                                ? '(${_currentHueca.reviewCount} ${_currentHueca.reviewCount == 1 ? 'reseña' : 'reseñas'})'
                                : '(${_currentHueca.reviewCount} ${_currentHueca.reviewCount == 1 ? 'review' : 'reviews'})')
                            : (lang == 'es' ? '(Sin reseñas aún)' : '(No reviews yet)'),
                        style: TextStyle(
                          color:
                              (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : AppTheme.textMedium),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[850]
                          : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.near_me,
                                color: AppTheme.primary,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _currentHueca.sector,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          lang == 'es'
                              ? 'Horario detallado abajo'
                              : 'Detailed schedule below',
                          style: TextStyle(
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : AppTheme.textMedium),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Botón principal: Cómo llegar (ancho y cómodo)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMapsSheet(context),
                      icon: const Icon(Icons.directions, size: 22),
                      label: Text(
                        lang == 'es' ? 'Cómo llegar' : 'Directions',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Acciones secundarias abajo: Llamar, Avisos, Compartir con nombres completos
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final Uri launchUri = Uri(
                              scheme: 'tel',
                              path: '0991234567',
                            );
                            await launchUrl(launchUri);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[200]),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.call, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                lang == 'es' ? 'Llamar' : 'Call',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showNotificationSubscriptionDialog(context, isSubscribed, lang),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSubscribed
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200]),
                            foregroundColor: isSubscribed
                                ? AppTheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: isSubscribed
                                ? const BorderSide(color: AppTheme.primary, width: 1.5)
                                : BorderSide.none,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSubscribed ? Icons.notifications_active : Icons.notifications_none,
                                size: 20,
                                color: isSubscribed ? AppTheme.primary : null,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lang == 'es'
                                    ? (isSubscribed ? 'Alertas' : 'Avisos')
                                    : (isSubscribed ? 'Alerts' : 'Alerts'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSubscribed ? AppTheme.primary : null,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Share.share(
                              lang == 'es'
                                  ? '¡Ven acompáñame a visitar ${_currentHueca.name} conmigo en Hue-Quito! 😋🥘\n\nMira dónde queda aquí: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}'
                                  : 'Come visit ${_currentHueca.name} with me on Hue-Quito! 😋🥘\n\nSee where it is here: https://maps.google.com/?q=${_currentHueca.location.latitude},${_currentHueca.location.longitude}',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[200]),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.share, size: 20),
                              const SizedBox(height: 4),
                              Text(
                                lang == 'es' ? 'Compartir' : 'Share',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Sección de Avisos Activos / Menú del Día (Visible únicamente si hay publicaciones en las últimas 4 horas)
            _buildActiveAnnouncementsSection(lang),

            // Tabs Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab(lang == 'en' ? 'About' : 'Sobre la Hueca', 0),
                  _buildTab(lang == 'en' ? 'Menu' : 'Menú Tradicional', 1),
                  _buildTab(
                    lang == 'en' ? 'Location & Hours' : 'Ubicación & Horario',
                    2,
                  ),
                  _buildTab(
                    lang == 'en'
                        ? 'Reviews (${_currentHueca.reviewCount})'
                        : 'Reseñas (${_currentHueca.reviewCount})',
                    3,
                  ),
                ],
              ),
            ),

            // Content Sections
            Padding(
              padding: EdgeInsets.all(16),
              child: _buildSelectedTabContent(lang),
            ),
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
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    lang == 'es' ? 'Sobre la Hueca' : 'About the Place',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                _currentHueca.description[lang] ??
                    _currentHueca.description['es'] ??
                    'Información no disponible.',
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textMedium),
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      case 1:
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    lang == 'es' ? 'Menú' : 'Menu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_currentHueca.menuItems.isEmpty)
                Text(
                  lang == 'es' ? 'Menú no disponible.' : 'Menu not available.',
                  style: TextStyle(
                    color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textMedium),
                  ),
                ),
              ..._currentHueca.menuItems.map((item) {
                final nameObj = item['name'];
                final name = nameObj is Map
                    ? (nameObj[lang] ?? nameObj['es'] ?? 'Plato')
                    : (nameObj ?? 'Plato');

                final descObj = item['description'];
                final desc = descObj is Map
                    ? (descObj[lang] ?? descObj['es'] ?? '')
                    : (descObj ?? '');

                final price = item['price'] != null
                    ? '\$${item['price']}'
                    : '\$0.00';
                final img =
                    item['image'] ??
                    'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80';
                return Column(
                  children: [
                    _buildMenuItem(
                      name.toString(),
                      desc.toString(),
                      price.toString(),
                      img.toString(),
                    ),
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
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    lang == 'es' ? 'Ubicación & Horarios' : 'Location & Hours',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_currentHueca.allBranches.length > 1) ...[
                Text(
                  lang == 'es' ? 'Selecciona una sucursal:' : 'Select a branch:',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_currentHueca.allBranches.length, (idx) {
                      final b = _currentHueca.allBranches[idx];
                      final isSelected = _selectedBranchIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(b.name),
                          selected: isSelected,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedBranchIndex = idx;
                              });
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Builder(
                builder: (context) {
                  final activeBranch = _currentHueca.allBranches[_selectedBranchIndex.clamp(0, _currentHueca.allBranches.length - 1)];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _openMapsForBranch(context, activeBranch),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.map,
                                color: (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : AppTheme.textMedium),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${activeBranch.address} (${activeBranch.sector})',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.directions,
                                size: 20,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (activeBranch.phone.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 18,
                              color: (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : AppTheme.textMedium),
                            ),
                            SizedBox(width: 8),
                            Text(
                              activeBranch.phone,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              GoogleMap(
                                key: ValueKey('map_${activeBranch.id}'),
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(
                                    activeBranch.location.latitude,
                                    activeBranch.location.longitude,
                                  ),
                                  zoom: 15.0,
                                ),
                                zoomControlsEnabled: false,
                                myLocationButtonEnabled: false,
                                onTap: (_) => _openMapsForBranch(context, activeBranch),
                                markers: {
                                  Marker(
                                    markerId: MarkerId('branch_${activeBranch.id}'),
                                    position: LatLng(
                                      activeBranch.location.latitude,
                                      activeBranch.location.longitude,
                                    ),
                                    onTap: () => _openMapsForBranch(context, activeBranch),
                                  ),
                                },
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: GestureDetector(
                                  onTap: () => _openMapsForBranch(context, activeBranch),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.navigation, size: 13, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          lang == 'es' ? 'Navegar' : 'Navigate',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule,
                    color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : AppTheme.textMedium),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final activeBranch = _currentHueca.allBranches[_selectedBranchIndex.clamp(0, _currentHueca.allBranches.length - 1)];
                        final orderedDaysEs = [
                          'Lunes',
                          'Martes',
                          'Miércoles',
                          'Jueves',
                          'Viernes',
                          'Sábado',
                          'Domingo',
                        ];
                        final orderedDaysEn = [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday',
                        ];

                        // Primero sacamos los horarios de la sucursal activa
                        Map<String, String> schedule = {};
                        if (activeBranch.schedule is Map && activeBranch.schedule.isNotEmpty) {
                          schedule = Map<String, String>.from(activeBranch.schedule);
                        } else if (_currentHueca.schedule is Map) {
                          schedule = Map<String, String>.from(
                            _currentHueca.schedule as Map,
                          );
                        }

                        // Vemos qué días mostrar
                        List<Widget> scheduleWidgets = [];
                        for (int i = 0; i < orderedDaysEs.length; i++) {
                          final esDay = orderedDaysEs[i];
                          final enDay = orderedDaysEn[i];
                          final enLower = enDay.toLowerCase();

                          // Buscar si existe el horario bajo la clave en español o en inglés
                          String? time =
                              schedule[esDay] ??
                              schedule[enDay] ??
                              schedule[enLower];

                          if (time != null && time.isNotEmpty) {
                            final displayDay = lang == 'es' ? esDay : enDay;
                            scheduleWidgets.add(
                              Text(
                                '$displayDay: $time',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            );
                          }
                        }

                        if (scheduleWidgets.isEmpty) {
                          scheduleWidgets.add(
                            Text(
                              lang == 'es'
                                  ? 'Horario no disponible'
                                  : 'Hours not available',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: scheduleWidgets,
                        );
                      },
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
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es' ? 'Reseñas Quiteñas' : 'Reviews',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          lang == 'es'
                              ? 'Calificación verificada por comensales'
                              : 'Verified rating by diners',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : AppTheme.textMedium),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showReviewDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200]),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 16, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(lang == 'es' ? 'Opinar' : 'Review'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              FutureBuilder<List<Review>>(
                future: ref
                    .read(huecaRepositoryProvider)
                    .getReviews(_currentHueca.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      lang == 'es'
                          ? 'Error al cargar reseñas.'
                          : 'Error loading reviews.',
                    );
                  }

                  final allReviews = snapshot.data ?? [];
                  if (allReviews.isEmpty) {
                    return Text(
                      lang == 'es'
                          ? 'Sé el primero en dejar una opinión sobre este local.'
                          : 'Be the first to leave a review for this spot.',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.textMedium),
                      ),
                    );
                  }

                  final goodReviews = allReviews
                      .where((r) => r.rating >= 4)
                      .toList();
                  final avgReviews = allReviews
                      .where((r) => r.rating == 3)
                      .toList();
                  final badReviews = allReviews
                      .where((r) => r.rating <= 2)
                      .toList();

                  goodReviews.shuffle();
                  avgReviews.shuffle();
                  badReviews.shuffle();

                  final displayReviews = <Review>[];
                  displayReviews.addAll(goodReviews.take(5));
                  if (avgReviews.isNotEmpty)
                    displayReviews.add(avgReviews.first);
                  if (badReviews.isNotEmpty)
                    displayReviews.add(badReviews.first);

                  return Column(
                    children: displayReviews
                        .map((r) => _buildReviewItem(r))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
    }
  }

  void _openMapsSheet(BuildContext context) {
    final lang = ref.read(settingsProvider).language;
    MapNavigationHelper.openDirections(
      context: context,
      hueca: _currentHueca,
      language: lang,
      initialBranchIndex: _selectedBranchIndex,
      onBranchSelected: (idx, branch) {
        if (mounted) {
          setState(() {
            _selectedBranchIndex = idx;
          });
        }
      },
    );
  }

  void _openMapsForBranch(BuildContext context, HuecaBranch branch) {
    final lang = ref.read(settingsProvider).language;
    MapNavigationHelper.openMapsForBranch(
      context: context,
      hueca: _currentHueca,
      branch: branch,
      language: lang,
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
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.tertiary
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textMedium),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    String desc,
    String price,
    String imageUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppTheme.textMedium),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Text(
                price,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            _openFullScreenGallery(
              context,
              0,
              customImages: [imageUrl],
              title: title,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[700]
                    : Colors.grey[300]),
                child: Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(Review r) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: r.userPic.isNotEmpty
                    ? NetworkImage(r.userPic)
                    : null,
                child: r.userPic.isEmpty
                    ? Text(
                        r.userName.isNotEmpty
                            ? r.userName[0].toUpperCase()
                            : 'U',
                      )
                    : null,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.userName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < r.rating ? Icons.star : Icons.star_border,
                    color: AppTheme.primary,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          if (r.comment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              r.comment,
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppTheme.textMedium),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveAnnouncementsSection(String lang) {
    final activeAsync = ref.watch(activeHuecaNotificationsProvider(_currentHueca.id));

    return activeAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang == 'es' ? 'AVISOS ACTIVOS / MENÚ DEL DÍA' : 'LIVE NOTICES / DAILY MENU',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.redAccent.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...notifications.map((n) => _buildAnnouncementCard(n, lang)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAnnouncementCard(NotificationModel n, String lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMenu = n.category == 'menu_del_dia';
    final isPromo = n.category == 'promocion';

    final Color accentColor = isMenu
        ? Colors.amber.shade800
        : (isPromo ? Colors.deepOrange : AppTheme.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner superior con categoría y tiempo restante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${n.categoryEmoji} ${n.categoryDisplay}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                if (n.branchName != null && n.branchName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black38 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📍 ${n.branchName}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Contenido principal
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (n.discountTag != null && n.discountTag!.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          n.discountTag!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  n.message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n.formattedAge(lang: lang),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Share.share(
                          '${n.title}\n\n${n.message}\n\nPublicado por ${_currentHueca.name} en HueQuito 🇪🇨',
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 14, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              lang == 'es' ? 'Compartir aviso' : 'Share notice',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}

class _FullScreenGalleryViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;
  final String lang;

  const _FullScreenGalleryViewer({
    required this.images,
    required this.initialIndex,
    required this.title,
    required this.lang,
  });

  @override
  State<_FullScreenGalleryViewer> createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<_FullScreenGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive PageView
            PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                });
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.images[index];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  clipBehavior: Clip.none,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          const SizedBox(height: 12),
                          Text(
                            widget.lang == 'es' ? 'No se pudo cargar la imagen' : 'Could not load image',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Top Bar Overlay
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: widget.lang == 'es' ? 'Cerrar' : 'Close',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.lang == 'es'
                            ? '${_currentIndex + 1} de $total'
                            : '${_currentIndex + 1} of $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Arrows if multiple images
            if (total > 1) ...[
              if (_currentIndex > 0)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              if (_currentIndex < total - 1)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
            ],

            // Bottom hint: "Pellizca para hacer zoom"
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pinch, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        widget.lang == 'es'
                            ? 'Pellizca para hacer zoom'
                            : 'Pinch to zoom',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
