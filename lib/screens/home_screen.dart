import 'package:hue_quito/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/auth_utils.dart';

import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/utils/map_navigation_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hue_quito/widgets/client_onboarding_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLocation = 'Todo Quito';
  String _selectedFilter = '🍽️ Todos';
  final String _selectedSort = 'Más cerca (km)';
  bool _checkedTutorial = false;
  bool _hasAppliedUserPreferences = false;
  bool _userManuallyChangedLocation = false;
  bool _userManuallyChangedFilter = false;
  String? _guestPersona;
  String? _guestSector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeClientTutorial();
      _initUserPreferences();
    });
  }

  Future<void> _initUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _guestPersona = prefs.getString('guest_persona') ?? prefs.getString('last_selected_persona');
      _guestSector = prefs.getString('guest_sector') ?? prefs.getString('last_selected_sector');

      final user = ref.read(currentUserProvider).value;
      final savedSector = (user?.preferences['sector']?.toString().isNotEmpty == true)
          ? user!.preferences['sector'].toString()
          : _guestSector;
      final savedPersona = (user?.preferences['persona']?.toString().isNotEmpty == true)
          ? user!.preferences['persona'].toString()
          : _guestPersona;

      if (mounted) {
        setState(() {
          if (!_userManuallyChangedLocation && savedSector != null && savedSector.isNotEmpty && savedSector != 'Todo Quito') {
            _selectedLocation = savedSector;
          }
          if (!_userManuallyChangedFilter && savedPersona != null && savedPersona.isNotEmpty) {
            _applyPersonaToFilter(savedPersona);
          }
          _hasAppliedUserPreferences = true;
        });
      }
    } catch (_) {}
  }

  void _applyPersonaToFilter(String persona) {
    switch (persona.toLowerCase()) {
      case 'sopero':
        _selectedFilter = '🍲 Sopas';
        break;
      case 'carnivoro':
        _selectedFilter = '🍛 Platos Fuertes';
        break;
      case 'dulcero':
        _selectedFilter = '🍰 Dulces';
        break;
      case 'callejero':
        _selectedFilter = '🍔 Callejero';
        break;
      case 'picador':
        _selectedFilter = '🥟 Empanadas';
        break;
      case 'aventurero':
      default:
        _selectedFilter = '🍽️ Todos';
        break;
    }
  }

  bool _matchesLocation(Hueca h, String loc) {
    if (loc == 'Todo Quito' || loc == 'All Quito') return true;
    final locLower = loc.toLowerCase().trim();
    final hSector = h.sector.toLowerCase().trim();
    final hAddr = h.address.toLowerCase().trim();

    if (hSector.contains(locLower) || locLower.contains(hSector) || hAddr.contains(locLower)) {
      return true;
    }

    if (locLower.contains('centro')) {
      return hSector.contains('centro') || hSector.contains('san roque') || hSector.contains('la ronda') ||
             hSector.contains('san blas') || hSector.contains('san juan') || hSector.contains('la tola') ||
             hSector.contains('el tejar') || hSector.contains('san marcos') || hSector.contains('panecillo') ||
             hAddr.contains('centro') || hAddr.contains('san roque') || hAddr.contains('la ronda') || hAddr.contains('san juan');
    }
    if (locLower.contains('floresta') || locLower.contains('mariscal')) {
      return hSector.contains('floresta') || hSector.contains('mariscal') || hSector.contains('guapulo') ||
             hSector.contains('guápulo') || hSector.contains('gonzalez') || hSector.contains('gonzález') ||
             hSector.contains('vicentina') || hSector.contains('pradera') || hSector.contains('foch') ||
             hAddr.contains('floresta') || hAddr.contains('mariscal') || hAddr.contains('guapulo') || hAddr.contains('guápulo');
    }
    if (locLower.contains('carolina') || locLower.contains('iñaquito') || locLower.contains('inaquito')) {
      return hSector.contains('carolina') || hSector.contains('iñaquito') || hSector.contains('inaquito') ||
             hSector.contains('bellavista') || hSector.contains('batán') || hSector.contains('batan') ||
             hSector.contains('granda centeno') || hSector.contains('salvador') ||
             hAddr.contains('carolina') || hAddr.contains('iñaquito') || hAddr.contains('inaquito') || hAddr.contains('bellavista');
    }
    if (locLower.contains('norte')) {
      return hSector.contains('norte') || hSector.contains('carcelen') || hSector.contains('carcelén') ||
             hSector.contains('cotocollao') || hSector.contains('calderon') || hSector.contains('calderón') ||
             hSector.contains('ponceano') || hSector.contains('san carlos') || hSector.contains('inca') ||
             hSector.contains('monteserr') || hSector.contains('kennedy') || hSector.contains('pomasqui') ||
             hSector.contains('comité') || hSector.contains('comite') ||
             hAddr.contains('norte') || hAddr.contains('carcelen') || hAddr.contains('cotocollao') || hAddr.contains('calderon');
    }
    if (locLower.contains('sur')) {
      return hSector.contains('sur') || hSector.contains('solanda') || hSector.contains('villaflora') ||
             hSector.contains('chillogallo') || hSector.contains('magdalena') || hSector.contains('chimbacalle') ||
             hSector.contains('pintado') || hSector.contains('recreo') || hSector.contains('guamani') ||
             hSector.contains('guamaní') || hSector.contains('quitumbe') || hSector.contains('san bartolo') ||
             hSector.contains('la mena') || hSector.contains('santa rita') || hSector.contains('ferroviaria') ||
             hAddr.contains('sur') || hAddr.contains('solanda') || hAddr.contains('villaflora') || hAddr.contains('chillogallo');
    }
    if (locLower.contains('valle') || locLower.contains('cumbay') || locLower.contains('tumbaco') || locLower.contains('chillos')) {
      return hSector.contains('valle') || hSector.contains('cumbay') || hSector.contains('tumbaco') ||
             hSector.contains('chillos') || hSector.contains('conocoto') || hSector.contains('sangolqu') ||
             hSector.contains('san rafael') || hSector.contains('puembo') || hSector.contains('pifo') ||
             hAddr.contains('valle') || hAddr.contains('cumbay') || hAddr.contains('tumbaco') || hAddr.contains('chillos') || hAddr.contains('conocoto');
    }

    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeClientTutorial() async {
    if (_checkedTutorial) return;
    _checkedTutorial = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_client_tutorial') ?? false;
      if (!hasSeen && mounted) {
        final currentLang = ref.read(settingsProvider).language;
        await showClientOnboardingDialog(context, markAsSeen: true, lang: currentLang);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios de preferencias del usuario si inicia sesión o actualiza perfil
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
      final u = next.value;
      if (u != null) {
        final savedSector = u.preferences['sector']?.toString();
        final savedPersona = u.preferences['persona']?.toString();
        if (mounted) {
          setState(() {
            if (!_userManuallyChangedLocation && savedSector != null && savedSector.isNotEmpty && savedSector != 'Todo Quito') {
              _selectedLocation = savedSector;
            }
            if (!_userManuallyChangedFilter && savedPersona != null && savedPersona.isNotEmpty) {
              _applyPersonaToFilter(savedPersona);
            }
          });
        }
      }
    });

    final user = ref.watch(currentUserProvider).value;
    final huecasAsync = ref.watch(huecasProvider);
    final lang = ref.watch(settingsProvider).language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<String> locations = lang == 'es' ? ['Todo Quito'] : ['All Quito'];

    final isEn = lang == 'en';
    final allChip = isEn ? '🍽️ All' : '🍽️ Todos';
    final carnesChip = isEn ? '🍛 Main Dishes' : '🍛 Platos Fuertes';
    final sopasChip = isEn ? '🍲 Soups' : '🍲 Sopas';
    final callejeroChip = isEn ? '🍔 Street Food' : '🍔 Callejero';
    final empanadasChip = isEn ? '🥟 Empanadas' : '🥟 Empanadas';
    final dulcesChip = isEn ? '🍰 Sweets' : '🍰 Dulces';
    final tradicionChip = isEn ? '⭐ Tradition' : '⭐ Tradición';

    List<String> filters = [
      allChip,
      carnesChip,
      sopasChip,
      callejeroChip,
      empanadasChip,
      dulcesChip,
      tradicionChip,
    ];

    if (huecasAsync.value != null && huecasAsync.value!.isNotEmpty) {
      final huecas = huecasAsync.value!;
      final dbSectors = huecas
          .where((h) => h.isActive && h.isSectorConfirmed)
          .map((h) => h.sector.trim())
          .where((s) => s.isNotEmpty && s.toLowerCase() != 'todo quito' && s.toLowerCase() != 'all quito')
          .toSet()
          .toList()
        ..sort();

      for (final s in dbSectors) {
        if (!locations.contains(s)) locations.add(s);
      }

      Map<String, int> tagCounts = {};
      for (var h in huecas) {
        if (!h.isActive) continue;
        for (var t in h.tags) {
          tagCounts[t] = (tagCounts[t] ?? 0) + 1;
        }
      }
      var sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var topTags = sortedTags.take(8).map((e) => e.key).toList();

      for (var tag in topTags) {
        String tLower = tag.toLowerCase();
        if (tLower.contains('sopa') || tLower.contains('plato fuerte') || tLower.contains('dulce') || tLower.contains('empanada')) {
          continue;
        }
        String emoji = '🏷️';
        if (tLower.contains('marisco') || tLower.contains('pescado') || tLower.contains('ceviche')) {
          emoji = '🐟';
        } else if (tLower.contains('carne') || tLower.contains('cerdo') || tLower.contains('hornado') || tLower.contains('fritada')) {
          emoji = '🍖';
        } else if (tLower.contains('tradici') || tLower.contains('mercado')) {
          emoji = '⭐';
        } else if (tLower.contains('snack') || tLower.contains('comida rapida') || tLower.contains('hamburguesa')) {
          emoji = '🍔';
        }

        final tagChip = '$emoji $tag';
        if (!filters.contains(tagChip)) {
          filters.add(tagChip);
        }
      }
    }

    if (!locations.contains(_selectedLocation)) {
      locations.add(_selectedLocation);
    }

    // Asegurar que el filtro activo SIEMPRE esté presente en la barra de chips
    if (!filters.contains(_selectedFilter)) {
      filters.insert(1, _selectedFilter);
    }

    final activePersona = (user != null && (user.preferences['persona']?.toString().isNotEmpty == true))
        ? user.preferences['persona']?.toString()
        : _guestPersona;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: HueQuitoLogo(height: 36, alignment: Alignment.centerLeft),
        ),
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[800]
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLocation,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                  size: 16,
                ),
                isDense: true,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLocation = newValue;
                      _userManuallyChangedLocation = true;
                    });
                  }
                },
                items: locations.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          ref.invalidate(allHuecasStreamProvider);
          ref.invalidate(huecasProvider);
          await ref.read(huecaRepositoryProvider).getHuecas();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: lang == 'es'
                            ? 'Locales, platos y productos'
                            : 'Places, dishes and products',
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.search,
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Recomendaciones
                  if (activePersona != null && activePersona.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'es'
                              ? 'Nuestra recomendación para ti'
                              : 'Recommended for you',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            String persona = activePersona;
                            List<String> targetTags = [];
                            if (persona == 'aventurero')
                              targetTags = [
                                'mercado',
                                'tradicional',
                                'tripa mishqui',
                                'guatita',
                              ];
                            else if (persona == 'picador')
                              targetTags = [
                                'empanadas',
                                'snack',
                                'cafe',
                                'morocho',
                              ];
                            else if (persona == 'carnivoro')
                              targetTags = [
                                'cerdo',
                                'hornado',
                                'fritada',
                                'asado',
                                'parrillada',
                              ];
                            else if (persona == 'sopero')
                              targetTags = [
                                'sopa',
                                'caldo',
                                'locro',
                                'yahuarlocro',
                                'encebollado',
                              ];
                            else if (persona == 'dulcero')
                              targetTags = [
                                'dulce',
                                'postre',
                                'helado',
                                'higos',
                                'pristiños',
                              ];
                            else if (persona == 'callejero')
                              targetTags = [
                                'salchipapa',
                                'hamburguesa',
                                'pollo frito',
                                'comida rapida',
                              ];

                            var recs =
                                huecasAsync.value
                                    ?.where(
                                      (h) => h.isActive && targetTags.any(
                                        (tt) => h.matchesSearch(tt, lang: lang),
                                      ),
                                    )
                                    .toList() ??
                                [];

                            if (recs.isEmpty) {
                              recs = huecasAsync.value?.where((h) => h.isActive).take(3).toList() ?? [];
                            } else {
                              if (_selectedLocation != 'Todo Quito' && _selectedLocation != 'All Quito') {
                                final inSector = recs.where((h) => _matchesLocation(h, _selectedLocation)).toList();
                                if (inSector.isNotEmpty) {
                                  recs = [...inSector, ...recs.where((h) => !inSector.contains(h))];
                                }
                              }
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: recs
                                    .take(5)
                                    .map(
                                      (h) => SizedBox(
                                        width: 300,
                                        child: _buildHuecaCard(
                                          context,
                                          hueca: h,
                                          lang: lang,
                                          width: 260,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
                  Text(
                    '¿Qué se te antoja hoy?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: filters
                          .map((f) => _buildFilterChip(f, _selectedFilter == f))
                          .toList(),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
          huecasAsync.when(
            data: (huecas) {
              var filtered = huecas.where((h) => h.isActive).toList();
              if (_selectedLocation != 'Todo Quito' &&
                  _selectedLocation != 'All Quito') {
                filtered = filtered
                    .where((h) => _matchesLocation(h, _selectedLocation))
                    .toList();
              }
              if (_searchQuery.isNotEmpty) {
                filtered = filtered
                    .where((h) => h.matchesSearch(_searchQuery, lang: lang))
                    .toList();
              }

              if (!_selectedFilter.contains('Todos') &&
                  !_selectedFilter.contains('All')) {
                final filterLower = _selectedFilter.toLowerCase();
                List<String> targetKeywords = [];

                if (filterLower.contains('sopa') || filterLower.contains('soup')) {
                  targetKeywords = ['sopa', 'caldo', 'locro', 'encebollado', 'yahuarlocro', 'sancocho'];
                } else if (filterLower.contains('plato') || filterLower.contains('carne') || filterLower.contains('main dish')) {
                  targetKeywords = ['plato', 'carne', 'hornado', 'fritada', 'asado', 'parrillada', 'cerdo', 'churrasco', 'menestra', 'seco', 'costilla', 'res'];
                } else if (filterLower.contains('callejero') || filterLower.contains('street') || filterLower.contains('snack')) {
                  targetKeywords = ['snack', 'comida rapida', 'comida rápida', 'hamburguesa', 'salchipapa', 'alitas', 'pizza', 'pollo frito', 'papas', 'frito', 'agachadito'];
                } else if (filterLower.contains('dulce') || filterLower.contains('sweet') || filterLower.contains('postre')) {
                  targetKeywords = ['dulce', 'postre', 'helado', 'caf', 'quesadilla', 'chocolate', 'pristiño', 'higos', 'espumilla'];
                } else if (filterLower.contains('empanada') || filterLower.contains('picad')) {
                  targetKeywords = ['empanada', 'humita', 'corvina', 'tamal', 'mote', 'antojito', 'quimbolito', 'picad'];
                } else if (filterLower.contains('tradici') || filterLower.contains('aventurero')) {
                  targetKeywords = ['tradici', 'mercado', 'tripa', 'mishqui', 'guatita', 'ceviche', 'cuy', 'menudencia'];
                } else {
                  final rawTag = _selectedFilter.split(' ').skip(1).join(' ').toLowerCase().trim();
                  targetKeywords = [rawTag.isNotEmpty ? rawTag : filterLower];
                }

                filtered = filtered
                    .where(
                      (h) => targetKeywords.any(
                        (kw) =>
                            h.tags.any((t) => t.toLowerCase().contains(kw)) ||
                            h.searchTags.any((st) => st.toLowerCase().contains(kw)) ||
                            h.matchesSearch(kw, lang: lang),
                      ),
                    )
                    .toList();
              }

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 54, color: AppTheme.primary.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          Text(
                            lang == 'es'
                                ? 'No encontramos huecas con estos filtros en $_selectedLocation.'
                                : 'No spots found with these filters in $_selectedLocation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : AppTheme.textMedium,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedLocation = 'Todo Quito';
                                _selectedFilter = lang == 'es' ? '🍽️ Todos' : '🍽️ All';
                                _userManuallyChangedLocation = true;
                                _userManuallyChangedFilter = true;
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(lang == 'es' ? 'Ver todas las huecas' : 'View all spots'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildHuecaCard(
                    context,
                    hueca: filtered[index],
                    lang: lang,
                  );
                }, childCount: filtered.length),
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: ')),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildFilterChip(String text, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = text;
        _userManuallyChangedFilter = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? AppTheme.surfaceDark : AppTheme.chulpiCream.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? Colors.white12 : AppTheme.chulpiCream),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.textLight : AppTheme.textDark),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHuecaCard(
    BuildContext context, {
    required Hueca hueca,
    String lang = 'es',
    double? width,
  }) {
    final user = ref.watch(currentUserProvider).value;
    final imageUrl = hueca.images.isNotEmpty
        ? hueca.images[0]
        : 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: hueca.tags
                            .map(
                              (t) => Container(
                                margin: EdgeInsets.only(bottom: 4),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (!AuthUtils.checkAuthAndPrompt(context)) return;
                          await ref
                              .read(userRepositoryProvider)
                              .toggleFavorite(hueca.id);
                          ref.invalidate(currentUserProvider);
                        },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (user?.favoriteHuecas.contains(hueca.id) ?? false)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 18,
                            color:
                                (user?.favoriteHuecas.contains(hueca.id) ??
                                    false)
                                ? Colors.red
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.near_me,
                                  color: AppTheme.primary,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '2.5 km',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payments,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '\$${hueca.mainDish["price"] ?? "5.0"}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            if (hueca.reviewCount > 0) ...[
                              Icon(Icons.star, color: AppTheme.primary, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '${hueca.rating}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 2),
                              Text(
                                '(${hueca.reviewCount})',
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                  fontSize: 10,
                                ),
                              ),
                            ] else ...[
                              Icon(Icons.star_border, color: AppTheme.primary, size: 14),
                              SizedBox(width: 3),
                              Text(
                                lang == 'es' ? 'Nuevo' : 'New',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hueca.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppTheme.tertiary, size: 14),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hueca.address,
                        style: TextStyle(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey[800]
                        : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${hueca.mainDish["emoji"] ?? "🍲"}',
                        style: TextStyle(fontSize: 24),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang == 'es'
                                  ? 'PLATO INSIGNIA'
                                  : 'SIGNATURE DISH',
                              style: TextStyle(
                                color: (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textMedium),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              hueca.mainDish['name'] is Map
                                  ? (hueca.mainDish['name'][lang] ??
                                        hueca.mainDish['name']['es'] ??
                                        hueca.mainDish['name'].values.first)
                                  : (hueca.mainDish['name'].toString().contains(
                                          '$lang:',
                                        )
                                        ? hueca.mainDish['name']
                                              .toString()
                                              .split('$lang:')[1]
                                              .split('}')[0]
                                              .trim()
                                        : (hueca.mainDish['name']
                                                  .toString()
                                                  .contains('es:')
                                              ? hueca.mainDish['name']
                                                    .toString()
                                                    .split('es:')[1]
                                                    .split('}')[0]
                                                    .trim()
                                              : hueca.mainDish['name']
                                                    .toString())),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          MapNavigationHelper.openDirections(
                            context: context,
                            hueca: hueca,
                            language: lang,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200]),
                          foregroundColor: AppTheme.secondary,
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions, size: 16),
                            SizedBox(width: 4),
                            Expanded(child: Text(lang == 'es' ? 'Cómo llegar' : 'Directions', style: TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/hueca_detail', extra: hueca);
                        },
                        style: ElevatedButton.styleFrom(elevation: 4, backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(child: Text(lang == 'es' ? 'Ver Hueca' : 'View Spot', style: TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16),
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
