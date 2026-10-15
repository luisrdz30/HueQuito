import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/hueca_repository.dart';
import '../theme/theme.dart';

class MapNavigationHelper {
  /// Opens directions for a Hueca. If the hueca has multiple branches,
  /// displays a branch picker bottom sheet first before opening map apps (Waze, Google Maps).
  static void openDirections({
    required BuildContext context,
    required Hueca hueca,
    required String language,
    int initialBranchIndex = 0,
    void Function(int branchIndex, HuecaBranch branch)? onBranchSelected,
  }) {
    final branches = hueca.allBranches;
    if (branches.length > 1) {
      showBranchSelectionSheet(
        context: context,
        hueca: hueca,
        branches: branches,
        language: language,
        selectedBranchIndex: initialBranchIndex,
        onBranchSelected: onBranchSelected,
      );
    } else if (branches.isNotEmpty) {
      openMapsForBranch(
        context: context,
        hueca: hueca,
        branch: branches.first,
        language: language,
      );
    } else {
      openMapsForCoordinates(
        context: context,
        lat: hueca.location.latitude,
        lng: hueca.location.longitude,
        title: hueca.name,
        address: hueca.address,
        language: language,
      );
    }
  }

  /// Displays a modal bottom sheet allowing the user to select which branch to visit.
  static void showBranchSelectionSheet({
    required BuildContext context,
    required Hueca hueca,
    required List<HuecaBranch> branches,
    required String language,
    int selectedBranchIndex = 0,
    void Function(int branchIndex, HuecaBranch branch)? onBranchSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: AppTheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language == 'es'
                                ? '¿A cuál sucursal deseas ir?'
                                : 'Which branch do you want to visit?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            language == 'es'
                                ? 'Selecciona una sucursal para abrir en Waze o Google Maps'
                                : 'Choose a location to open Waze or Google Maps',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: branches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final branch = branches[idx];
                      final isSelected = selectedBranchIndex == idx;
                      final isMatriz = branch.id == 'matriz' ||
                          branch.name.toLowerCase().contains('matriz');

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            if (onBranchSelected != null) {
                              onBranchSelected(idx, branch);
                            }
                            Navigator.pop(sheetContext);
                            openMapsForBranch(
                              context: context,
                              hueca: hueca,
                              branch: branch,
                              language: language,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.08)
                                  : (isDark ? Colors.grey[850] : Colors.grey[50]),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppTheme.primary
                                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                  child: Icon(
                                    Icons.location_on,
                                    color: isSelected ? Colors.white : AppTheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              branch.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isSelected ? AppTheme.primary : null,
                                              ),
                                            ),
                                          ),
                                          if (isMatriz)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                language == 'es' ? 'Matriz' : 'Main',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        branch.address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[300] : AppTheme.textMedium,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (branch.sector.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sector: ${branch.sector}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the map sheet for a specific branch.
  static void openMapsForBranch({
    required BuildContext context,
    required Hueca hueca,
    required HuecaBranch branch,
    required String language,
  }) {
    openMapsForCoordinates(
      context: context,
      lat: branch.location.latitude,
      lng: branch.location.longitude,
      title: '${hueca.name} (${branch.name})',
      address: branch.address,
      language: language,
    );
  }

  /// Opens the map selection sheet (Waze, Google Maps, Apple Maps) for given coordinates.
  static void openMapsForCoordinates({
    required BuildContext context,
    required double lat,
    required double lng,
    required String title,
    required String address,
    required String language,
  }) async {
    final availableMaps = await MapLauncher.installedMaps;
    if (!context.mounted) return;

    if (availableMaps.isEmpty) {
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == 'es'
                  ? 'No hay aplicaciones de mapas instaladas'
                  : 'No map applications installed',
            ),
          ),
        );
      }
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).cardColor,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      Text(
                        language == 'es' ? 'Abrir ubicación con' : 'Open location with',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : AppTheme.textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Wrap(
                  children: <Widget>[
                    for (var map in availableMaps)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          map.showMarker(
                            coords: Coords(lat, lng),
                            title: title,
                            description: address,
                          );
                        },
                        leading: _getMapIcon(map.mapType),
                        title: Text(
                          map.mapName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Text(
                          language == 'es' ? 'Navegar hacia este local' : 'Navigate to this location',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : AppTheme.textMedium,
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _getMapIcon(MapType mapType) {
    if (mapType == MapType.google || mapType == MapType.googleGo) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.pin_drop, color: Colors.red, size: 22),
      );
    } else if (mapType == MapType.waze) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.cyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.navigation, color: Colors.cyan, size: 22),
      );
    } else if (mapType == MapType.apple) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.explore, color: Colors.blueGrey, size: 22),
      );
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.directions, color: AppTheme.primary, size: 22),
    );
  }
}
