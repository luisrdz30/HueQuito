import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/models/gastronomic_profile.dart';

class QuitoZoneOption {
  final String id;
  final String nameEs;
  final String nameEn;
  final String icon;
  final String descriptionEs;
  final String descriptionEn;

  const QuitoZoneOption({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.icon,
    required this.descriptionEs,
    required this.descriptionEn,
  });
}

const List<QuitoZoneOption> quitoZoneOptions = [
  QuitoZoneOption(
    id: 'Centro Histórico',
    nameEs: 'Centro Histórico',
    nameEn: 'Historic Center',
    icon: '🏛️',
    descriptionEs: 'La Ronda, San Roque, Plaza Grande, San Blas',
    descriptionEn: 'La Ronda, San Roque, Plaza Grande, San Blas',
  ),
  QuitoZoneOption(
    id: 'La Floresta / La Mariscal',
    nameEs: 'La Floresta / La Mariscal',
    nameEn: 'La Floresta / La Mariscal',
    icon: '🌳',
    descriptionEs: 'González Suárez, Guápulo, Plaza Foch',
    descriptionEn: 'González Suárez, Guápulo, Plaza Foch',
  ),
  QuitoZoneOption(
    id: 'Iñaquito / La Carolina',
    nameEs: 'Iñaquito / La Carolina',
    nameEn: 'Iñaquito / La Carolina',
    icon: '🏢',
    descriptionEs: 'Bellavista, El Batán, Parque La Carolina',
    descriptionEn: 'Bellavista, El Batán, Carolina Park',
  ),
  QuitoZoneOption(
    id: 'Norte',
    nameEs: 'Norte de Quito',
    nameEn: 'North Quito',
    icon: '🏔️',
    descriptionEs: 'Carcelén, Cotocollao, Ponceano, Calderón',
    descriptionEn: 'Carcelén, Cotocollao, Ponceano, Calderón',
  ),
  QuitoZoneOption(
    id: 'Sur',
    nameEs: 'Sur de Quito',
    nameEn: 'South Quito',
    icon: '🏘️',
    descriptionEs: 'Solanda, Villaflora, Chillogallo, Magdalena',
    descriptionEn: 'Solanda, Villaflora, Chillogallo, Magdalena',
  ),
  QuitoZoneOption(
    id: 'Valles',
    nameEs: 'Valles (Cumbayá / Chillos)',
    nameEn: 'Valleys (Cumbayá / Chillos)',
    icon: '🌄',
    descriptionEs: 'Cumbayá, Tumbaco, Valle de los Chillos, Conocoto',
    descriptionEn: 'Cumbayá, Tumbaco, Los Chillos, Conocoto',
  ),
  QuitoZoneOption(
    id: 'Todo Quito',
    nameEs: 'Todo Quito',
    nameEn: 'All Quito',
    icon: '🗺️',
    descriptionEs: 'Explorador de todas las huecas de la ciudad',
    descriptionEn: 'Explorer across all traditional spots in Quito',
  ),
];

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final PageController _pageController = PageController();
  late ConfettiController _confettiController;
  int _currentPage = 0;

  // Score tracking for the 6 gastronomic profiles
  final Map<String, int> _scores = {
    'sopero': 0,
    'carnivoro': 0,
    'callejero': 0,
    'dulcero': 0,
    'picador': 0,
    'aventurero': 0,
  };

  GastronomicProfile? _resultProfile;
  String _selectedSector = 'Centro Histórico';

  bool get _isUserLoggedIn {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _answerQuestion(String profileId, int totalFoodQuestions) {
    setState(() {
      _scores[profileId] = (_scores[profileId] ?? 0) + 1;
    });

    final totalPages = 1 + totalFoodQuestions;
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _calculateResult();
    }
  }

  Future<void> _calculateResult() async {
    // Find the winning profile
    String winningId = _scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    if ((_scores[winningId] ?? 0) == 0) {
      winningId = 'aventurero';
    }

    final matched = hueQuitoProfiles.firstWhere(
      (p) => p.id == winningId,
      orElse: () => hueQuitoProfiles.first,
    );

    setState(() {
      _resultProfile = matched;
    });

    // Save to SharedPreferences for guest and persistent access
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_persona', winningId);
      await prefs.setString('last_selected_persona', winningId);
      if (_selectedSector.isNotEmpty) {
        await prefs.setString('guest_sector', _selectedSector);
        await prefs.setString('last_selected_sector', _selectedSector);
      }
    } catch (_) {}

    // Save to user provider if logged in
    try {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        Map<String, dynamic> newPrefs = Map.from(user.preferences);
        newPrefs['persona'] = winningId;
        if (_selectedSector.isNotEmpty) {
          newPrefs['sector'] = _selectedSector;
        }
        await ref.read(userRepositoryProvider).updatePreferences(newPrefs);
        ref.invalidate(currentUserProvider);
      }
    } catch (_) {}

    _confettiController.play();
  }

  Future<void> _skipQuiz() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_persona', 'aventurero');
      await prefs.setString('last_selected_persona', 'aventurero');
      if (_selectedSector.isNotEmpty) {
        await prefs.setString('guest_sector', _selectedSector);
        await prefs.setString('last_selected_sector', _selectedSector);
      }
    } catch (_) {}

    if (_isUserLoggedIn) {
      try {
        final user = ref.read(currentUserProvider).value;
        if (user != null) {
          Map<String, dynamic> newPrefs = Map.from(user.preferences);
          newPrefs['persona'] = 'aventurero';
          if (_selectedSector.isNotEmpty) {
            newPrefs['sector'] = _selectedSector;
          }
          await ref.read(userRepositoryProvider).updatePreferences(newPrefs);
          ref.invalidate(currentUserProvider);
        }
      } catch (_) {}

      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } else {
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _resetQuiz() {
    setState(() {
      _scores.updateAll((key, value) => 0);
      _currentPage = 0;
      _selectedSector = 'Centro Histórico';
      _resultProfile = null;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    // Dynamic questions from Firestore with default fallback
    final questionsAsync = ref.watch(quizQuestionsStreamProvider);
    final questions = questionsAsync.value?.isNotEmpty == true
        ? questionsAsync.value!
        : defaultQuizQuestions;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // 1. Photographic background with layered gradient (matching WelcomeScreen)
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200&auto=format&fit=crop&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      bgColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // 2. High readability dark-amber gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (isDark ? Colors.black : Colors.black).withValues(alpha: 0.45),
                    bgColor.withValues(alpha: 0.88),
                    bgColor,
                  ],
                  stops: const [0.0, 0.35, 0.70],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. Quiz content or Result
          SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () {
                          if (_currentPage > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                            );
                          } else {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              if (_isUserLoggedIn) {
                                context.go('/home');
                              } else {
                                context.go('/');
                              }
                            }
                          }
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),

                      // Quito Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restaurant_menu, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              isEn ? 'Quito • Flavor DNA' : 'Quito • ADN Gastronómico',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Language Toggle & Skip
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Segmented Language Toggle
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    if (isEn) ref.read(settingsProvider.notifier).setLanguage('es');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: !isEn ? AppTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '🇪🇸 ES',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: !isEn ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    if (!isEn) ref.read(settingsProvider.notifier).setLanguage('en');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isEn ? AppTheme.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '🇺🇸 EN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: isEn ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_resultProfile == null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: TextButton(
                                onPressed: _skipQuiz,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  isEn ? 'Skip' : 'Saltar',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main Body: Questions or Result
                Expanded(
                  child: _resultProfile == null
                      ? _buildQuiz(context, isDark, isEn, questions)
                      : _buildResult(context, isDark, isEn),
                ),
              ],
            ),
          ),

          // Confetti overlay on victory
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 35,
              colors: const [
                Color(0xFFEA580C),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Color(0xFF3B82F6),
                Color(0xFF8B5CF6),
                Color(0xFFEC4899),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz(
    BuildContext context,
    bool isDark,
    bool isEn,
    List<QuizQuestion> questions,
  ) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);

    final totalSteps = 1 + questions.length;
    final progress = (_currentPage + 1) / totalSteps;

    return Column(
      children: [
        // Stepped modern progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _currentPage == 0
                              ? (isEn ? 'Step 1 of $totalSteps • Your Area' : 'Paso 1 de $totalSteps • Tu Sector')
                              : (isEn
                                  ? 'Question $_currentPage of ${questions.length}'
                                  : 'Pregunta $_currentPage de ${questions.length}'),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),

        // PageView for sector selection + questions
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalSteps,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildSectorStep(context, isDark, isEn, questions.length);
              }
              final q = questions[index - 1];
              return _buildQuestionStep(context, isDark, isEn, q, index, questions.length);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectorStep(
    BuildContext context,
    bool isDark,
    bool isEn,
    int totalQuestions,
  ) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.88);
    final cardBorder = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07);

    final huecas = ref.watch(huecasProvider).value ?? [];
    final dbSectors = huecas
        .where((h) => h.isActive && h.isSectorConfirmed)
        .map((h) => h.sector.trim())
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'todo quito' && s.toLowerCase() != 'all quito')
        .toSet()
        .toList()
      ..sort();

    final sectors = dbSectors.isNotEmpty
        ? dbSectors
        : ['Centro Histórico', 'La Floresta', 'Conocoto'];

    if (!sectors.contains(_selectedSector) && _selectedSector != 'Todo Quito') {
      _selectedSector = sectors.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Title
          Text(
            isEn ? 'Which sector of Quito are you in?' : '¿De qué sector de Quito eres?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEn
                ? 'Select your area to discover huecas near you, or choose Other to explore all Quito.'
                : 'Elige tu zona para recomendarte huecas cercanas, o elige Otro para explorar toda la ciudad.',
            style: TextStyle(
              fontSize: 13.5,
              color: subtitleColor,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          // Sectores dinámicos basados en la base de datos (sin stickers)
          ...sectors.map((sector) {
            final isSelected = _selectedSector == sector;
            final count = huecas.where((h) => h.sector.trim().toLowerCase() == sector.toLowerCase()).length;
            final countText = count > 0
                ? (isEn ? '$count spots available' : '$count huecas registradas')
                : (isEn ? 'Available zone' : 'Zona disponible');

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedSector = sector;
                  });
                  Future.delayed(const Duration(milliseconds: 260), () {
                    if (mounted && _pageController.hasClients) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                        : cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : cardBorder,
                      width: isSelected ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : (isDark ? Colors.white10 : Colors.blueGrey.shade50),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: isSelected ? AppTheme.primary : (isDark ? Colors.white70 : AppTheme.textMedium),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sector,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.primary : titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              countText,
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isSelected ? AppTheme.primary : subtitleColor.withValues(alpha: 0.5),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Opción "Otro" para explorar todo Quito
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedSector = 'Todo Quito';
                });
                Future.delayed(const Duration(milliseconds: 260), () {
                  if (mounted && _pageController.hasClients) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedSector == 'Todo Quito'
                      ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                      : cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedSector == 'Todo Quito' ? AppTheme.primary : cardBorder,
                    width: _selectedSector == 'Todo Quito' ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _selectedSector == 'Todo Quito'
                            ? AppTheme.primary.withValues(alpha: 0.2)
                            : (isDark ? Colors.white10 : Colors.blueGrey.shade50),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: _selectedSector == 'Todo Quito' ? AppTheme.primary : (isDark ? Colors.white70 : AppTheme.textMedium),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Other sector' : 'Otro sector',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: _selectedSector == 'Todo Quito' ? AppTheme.primary : titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEn
                                ? 'Explore all traditional spots across Quito'
                                : 'Explorar todas las huecas de Quito',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _selectedSector == 'Todo Quito' ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _selectedSector == 'Todo Quito' ? AppTheme.primary : subtitleColor.withValues(alpha: 0.5),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Continuar button
          ElevatedButton.icon(
            onPressed: () {
              if (_pageController.hasClients) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              isEn ? 'Continue to Food Quiz' : 'Continuar al Quiz Gastronómico',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuestionStep(
    BuildContext context,
    bool isDark,
    bool isEn,
    QuizQuestion q,
    int index,
    int totalQuestions,
  ) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.88);
    final cardBorder = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question Title
          Text(
            isEn ? q.titleEn : q.titleEs,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          // Visual Image Card with curated photography
          Container(
            height: 165,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (q.imageUrl.isNotEmpty)
                    Image.network(
                      q.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.6),
                              const Color(0xFF0F172A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.restaurant, size: 48, color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.6),
                            const Color(0xFF0F172A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant, size: 48, color: Colors.white70),
                      ),
                    ),

                  // Overlay gradient on photo bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt, color: Colors.amber, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isEn ? 'Question $index of $totalQuestions' : 'Pregunta $index de $totalQuestions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Options list
          ...q.options.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _answerQuestion(option.profileId, totalQuestions),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cardBorder,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Emoji circle badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          option.emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Option text
                      Expanded(
                        child: Text(
                          isEn ? option.textEn : option.textEs,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                            height: 1.3,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: AppTheme.primary.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, bool isDark, bool isEn) {
    if (_resultProfile == null) return const SizedBox();

    final profile = _resultProfile!;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFCBD5E1);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Celebration Icon Emblem
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              profile.emoji,
              style: const TextStyle(fontSize: 48),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            isEn ? '¡Quiz Completed!' : '¡Quiz Completado!',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEn ? 'Your authentic Quito foodie profile is:' : 'Tu perfil culinario quiteño es:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 20),

          // Main Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isEn ? profile.titleEn : profile.titleEs,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isEn ? profile.descriptionEn : profile.descriptionEs,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: subtitleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Sector preference pill
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 15, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        isEn
                            ? (_selectedSector == 'Todo Quito' ? 'Your Zone: All Quito' : 'Your Zone: $_selectedSector')
                            : (_selectedSector == 'Todo Quito' ? 'Tu Zona: Todo Quito' : 'Tu Zona: $_selectedSector'),
                        style: TextStyle(
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tags chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: profile.matchingTags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary Call to Action: Login if not logged in, or explore if already logged in
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (_isUserLoggedIn) {
                  context.go('/home');
                } else {
                  context.go('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isUserLoggedIn
                        ? (isEn ? 'Explore Recommended Huecas' : '¡Explorar Huecas Recomendadas!')
                        : (isEn ? 'Log In / Sign Up to Continue' : 'Iniciar Sesión / Registrarme'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isUserLoggedIn ? Icons.arrow_forward : Icons.login_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (!_isUserLoggedIn) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(
                isEn ? 'Or continue as Guest' : 'O continuar como invitado',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Secondary: Retake Quiz
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _resetQuiz,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cardBorder),
                foregroundColor: titleColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEn ? 'Retake Quiz' : 'Repetir Quiz',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
