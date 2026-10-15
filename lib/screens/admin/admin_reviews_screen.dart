import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';

class AdminReviewsScreen extends ConsumerStatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  ConsumerState<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends ConsumerState<AdminReviewsScreen> {
  int? _ratingFilter; // null = all, 1, 2, 3, 4, 5

  Future<void> _deleteReview(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('¿Eliminar Reseña?', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Esta acción borrará la reseña permanentemente y recalculará la calificación promedio de la hueca.',
          style: TextStyle(color: Colors.blueGrey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.blueGrey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(huecaRepositoryProvider).deleteReview(review.huecaId, review.id);
        ref.invalidate(globalReviewsProvider);
        ref.invalidate(allHuecasStreamProvider);
        ref.invalidate(huecasProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🗑️ Reseña eliminada exitosamente'), backgroundColor: Colors.redAccent),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar reseña: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(globalReviewsProvider);
    final huecasList = ref.watch(allHuecasStreamProvider).value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Moderación de Reseñas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(globalReviewsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros por estrellas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade100)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStarFilterChip('Todas', null),
                  const SizedBox(width: 8),
                  _buildStarFilterChip('⭐ 1 Estrella', 1),
                  const SizedBox(width: 8),
                  _buildStarFilterChip('⭐ 2 Estrellas', 2),
                  const SizedBox(width: 8),
                  _buildStarFilterChip('⭐ 3 Estrellas', 3),
                  const SizedBox(width: 8),
                  _buildStarFilterChip('⭐ 4 Estrellas', 4),
                  const SizedBox(width: 8),
                  _buildStarFilterChip('⭐ 5 Estrellas', 5),
                ],
              ),
            ),
          ),

          // Listado de reseñas
          Expanded(
            child: reviewsAsync.when(
              data: (reviewsList) {
                final filtered = reviewsList.where((r) {
                  if (_ratingFilter != null && r.rating != _ratingFilter) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 54, color: Colors.blueGrey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay reseñas para mostrar',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final review = filtered[index];
                    final hueca = huecasList.firstWhere(
                      (h) => h.id == review.huecaId,
                      orElse: () => Hueca(
                        id: review.huecaId,
                        name: 'Hueca ID: ${review.huecaId}',
                        description: {},
                        address: '',
                        sector: '',
                        location: GeoPoint(0, 0),
                        phone: '',
                        schedule: {},
                        mainDish: {},
                        loyaltyCard: {},
                        secretSticker: {},
                        menuItems: [],
                        tags: [],
                        priceLevel: '',
                        rating: 0.0,
                        reviewCount: 0,
                        images: [],
                        ownerId: '',
                        isActive: true,
                        metrics: {},
                      ),
                    );

                    return _buildReviewCard(review, hueca);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
              error: (err, _) => Center(
                child: Text('Error cargando reseñas: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarFilterChip(String label, int? rating) {
    final isSelected = _ratingFilter == rating;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _ratingFilter = rating),
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFF0F172A) : Colors.transparent),
      ),
    );
  }

  Widget _buildReviewCard(Review review, Hueca hueca) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: review.rating <= 2 ? Colors.redAccent.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF0F172A),
                backgroundImage: review.userPic.isNotEmpty ? NetworkImage(review.userPic) : null,
                child: review.userPic.isEmpty
                    ? Text(review.userName.isNotEmpty ? review.userName[0] : 'U', style: const TextStyle(color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'En: ${hueca.name}',
                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(color: Color(0xFF334155), fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.createdAt != null
                    ? '${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}'
                    : 'Reciente',
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Eliminar Reseña',
                onPressed: () => _deleteReview(review),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
