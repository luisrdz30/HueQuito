import os

filepath = 'lib/screens/preferences_screen.dart'
new_code = """import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/providers/user_provider.dart';
import 'package:hue_quito/models/gastronomic_profile.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final PageController _pageController = PageController();
  late ConfettiController _confettiController;
  int _currentPage = 0;
  
  // Score tracking for profiles
  final Map<String, int> _scores = {
    'sopero': 0,
    'carnivoro': 0,
    'callejero': 0,
    'dulcero': 0,
    'picador': 0,
    'aventurero': 0,
  };

  GastronomicProfile? _resultProfile;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _answerQuestion(String profileId) {
    setState(() {
      _scores[profileId] = (_scores[profileId] ?? 0) + 1;
    });

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _calculateResult();
    }
  }

  void _calculateResult() {
    String winningId = _scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    setState(() {
      _resultProfile = hueQuitoProfiles.firstWhere((p) => p.id == winningId);
    });
    
    // Save to user provider
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      Map<String, dynamic> newPrefs = Map.from(user.preferences);
      newPrefs['persona'] = winningId;
      ref.read(currentUserProvider.notifier).updateUser(user.copyWith(preferences: newPrefs));
    }
    
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isEs = lang == 'es';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(isEs ? 'Quiz Gastronómico' : 'Gastronomic Quiz'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _resultProfile == null 
        ? _buildQuiz(isEs) 
        : _buildResult(isEs),
    );
  }

  Widget _buildQuiz(bool isEs) {
    return Column(
      children: [
        // Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs ? 'Pregunta ${_currentPage + 1} de 4' : 'Question ${_currentPage + 1} of 4',
                style: TextStyle(color: AppTheme.textMedium, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / 4,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildQuestionScreen(
                isEs ? 'Es domingo por la mañana y el cuerpo lo sabe, ¿qué te pide el estómago?' : 'It is Sunday morning, what is your stomach begging for?',
                'assets/images/quiz1.png', // Placeholder for meme
                [
                  _Option('Un caldito "levanta muertos"', 'A "reviving" broth', 'sopero', '🥣'),
                  _Option('Un buen plato con harto cerdo y mote', 'A big plate of pork and mote', 'carnivoro', '🐷'),
                  _Option('Algo dulce con un cafecito', 'Something sweet with coffee', 'dulcero', '☕'),
                  _Option('Lo que haya en el mercado', 'Whatever the local market has', 'aventurero', '🎪'),
                ],
                isEs
              ),
              _buildQuestionScreen(
                isEs ? 'Seamos sinceros... ¿qué tanto ají le pones a la comida?' : 'Be honest... how much spicy sauce do you add?',
                'assets/images/quiz2.png',
                [
                  _Option('Nada, me hace daño el estómago', 'None, it hurts my stomach', 'picador', '🛑'),
                  _Option('Solo un poquito para que dé sabor', 'Just a little for flavor', 'sopero', '🤏'),
                  _Option('En la salchipapa o hamburguesa sí, full', 'On fast food, lots of it!', 'callejero', '🍟'),
                  _Option('¡Póngale del ají de la casa con todo!', 'Put the house spicy sauce on everything!', 'aventurero', '🔥'),
                ],
                isEs
              ),
              _buildQuestionScreen(
                isEs ? '¿Qué ambiente prefieres para comer rico?' : 'What environment do you prefer for eating?',
                'assets/images/quiz3.png',
                [
                  _Option('El mercado, bien auténtico y ruidoso', 'The authentic and loud market', 'aventurero', '🗣️'),
                  _Option('Una hueca clásica, sentadito relajado', 'A classic spot, sitting relaxed', 'picador', '🏡'),
                  _Option('Cualquier lado, mientras me den rápido', 'Anywhere, as long as it is fast', 'callejero', '🏃'),
                  _Option('Una panadería o cafetería tranquila', 'A quiet bakery or cafe', 'dulcero', '🥐'),
                ],
                isEs
              ),
              _buildQuestionScreen(
                isEs ? 'Para cerrar con broche de oro, tu plan de fin de semana es:' : 'To finish perfectly, your weekend plan is:',
                'assets/images/quiz4.png',
                [
                  _Option('Helado de paila o postrecito en el centro', 'Traditional ice cream in downtown', 'dulcero', '🍦'),
                  _Option('Salir hasta tarde y rematar con pollo frito', 'Go out late and end with fried chicken', 'callejero', '🍗'),
                  _Option('Ir por una fritada o buen asado', 'Go for a heavy pork dish or BBQ', 'carnivoro', '🥩'),
                  _Option('Ir de hueca en hueca probando empanadas', 'Hop spots trying empanadas', 'picador', '🥟'),
                ],
                isEs
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionScreen(String title, String imagePath, List<_Option> options, bool isEs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          // We can show an image/meme here in the future
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(Icons.image, size: 50, color: Colors.grey[400]),
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = options[index];
                return InkWell(
                  onTap: () => _answerQuestion(option.profileId),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: AppTheme.primary.withValues(alpha:0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(option.emoji, style: TextStyle(fontSize: 24)),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            isEs ? option.textEs : option.textEn,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResult(bool isEs) {
    if (_resultProfile == null) return SizedBox();
    
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isEs ? '¡Felicidades!' : 'Congratulations!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                SizedBox(height: 8),
                Text(
                  isEs ? 'Tu identidad gastronómica es:' : 'Your gastronomic identity is:',
                  style: TextStyle(fontSize: 16, color: AppTheme.textMedium),
                ),
                SizedBox(height: 24),
                
                // Result Card
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha:0.3), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _resultProfile!.emoji,
                        style: TextStyle(fontSize: 60),
                      ),
                      SizedBox(height: 16),
                      Text(
                        isEs ? _resultProfile!.titleEs : _resultProfile!.titleEn,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        isEs ? _resultProfile!.descriptionEs : _resultProfile!.descriptionEn,
                        style: TextStyle(fontSize: 14, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.push('/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEs ? '¡Genial, vamos a explorar!' : 'Awesome, let\\'s explore!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
        
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
          ),
        ),
      ],
    );
  }
}

class _Option {
  final String textEs;
  final String textEn;
  final String profileId;
  final String emoji;

  _Option(this.textEs, this.textEn, this.profileId, this.emoji);
}
"""

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
