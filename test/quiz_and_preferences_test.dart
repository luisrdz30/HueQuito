import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/models/gastronomic_profile.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/screens/admin/admin_quiz_screen.dart';
import 'package:hue_quito/screens/preferences_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gastronomic Profile & Quiz Model Unit Tests', () {
    test('QuizOption serialization toMap and fromMap works accurately', () {
      final option = QuizOption(
        id: 'opt_test_1',
        textEs: 'Un hornado con cuero reventado',
        textEn: 'Roast pork with crispy crackling',
        profileId: 'carnivoro',
        emoji: '🍖',
      );

      final map = option.toMap();
      expect(map['id'], 'opt_test_1');
      expect(map['textEs'], 'Un hornado con cuero reventado');
      expect(map['textEn'], 'Roast pork with crispy crackling');
      expect(map['profileId'], 'carnivoro');
      expect(map['emoji'], '🍖');

      final deserialized = QuizOption.fromMap(map, 'fallback_id');
      expect(deserialized.id, 'opt_test_1');
      expect(deserialized.textEs, 'Un hornado con cuero reventado');
      expect(deserialized.profileId, 'carnivoro');
      expect(deserialized.emoji, '🍖');
    });

    test('QuizQuestion serialization preserves nested options and properties', () {
      final question = QuizQuestion(
        id: 'q_custom_100',
        order: 5,
        titleEs: '¿Qué tomas para acompañar tu comida?',
        titleEn: 'What do you drink with your meal?',
        imageUrl: 'https://images.unsplash.com/photo-example',
        options: [
          QuizOption(
            id: 'opt_1',
            textEs: 'Un morocho caliente',
            textEn: 'Hot morocho',
            profileId: 'picador',
            emoji: '🥤',
          ),
          QuizOption(
            id: 'opt_2',
            textEs: 'Una gaseosa bien fría',
            textEn: 'An ice-cold soda',
            profileId: 'callejero',
            emoji: '🥤',
          ),
        ],
      );

      final map = question.toMap();
      expect(map['id'], 'q_custom_100');
      expect(map['order'], 5);
      expect(map['titleEs'], '¿Qué tomas para acompañar tu comida?');
      expect(map['options'].length, 2);

      final restored = QuizQuestion.fromMap(map, 'q_custom_100');
      expect(restored.id, 'q_custom_100');
      expect(restored.order, 5);
      expect(restored.options.length, 2);
      expect(restored.options.first.profileId, 'picador');
      expect(restored.options.last.profileId, 'callejero');
    });

    test('defaultQuizQuestions has 4 complete questions with valid profile assignments', () {
      expect(defaultQuizQuestions.length, 4);

      final validProfileIds = hueQuitoProfiles.map((p) => p.id).toSet();

      for (var q in defaultQuizQuestions) {
        expect(q.titleEs.isNotEmpty, true);
        expect(q.titleEn.isNotEmpty, true);
        expect(q.imageUrl.startsWith('http'), true);
        expect(q.options.length, greaterThanOrEqualTo(4));

        for (var opt in q.options) {
          expect(validProfileIds.contains(opt.profileId), true,
              reason: 'Option ${opt.textEs} has invalid profileId: ${opt.profileId}');
          expect(opt.emoji.isNotEmpty, true);
        }
      }
    });

    test('Scoring algorithm accurately maps answers to winning profile', () {
      final Map<String, int> scores = {
        'sopero': 3,
        'carnivoro': 1,
        'callejero': 0,
        'dulcero': 0,
        'picador': 0,
        'aventurero': 0,
      };

      String winningId = scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      expect(winningId, 'sopero');

      final profile = hueQuitoProfiles.firstWhere((p) => p.id == winningId);
      expect(profile.titleEs, 'El Sopero');
      expect(profile.emoji, '🥣');
    });

    test('Scoring algorithm handles ties or zero points by fallback to aventurero', () {
      final Map<String, int> scores = {
        'sopero': 0,
        'carnivoro': 0,
        'callejero': 0,
        'dulcero': 0,
        'picador': 0,
        'aventurero': 0,
      };

      String winningId = scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      if ((scores[winningId] ?? 0) == 0) {
        winningId = 'aventurero';
      }
      expect(winningId, 'aventurero');

      final profile = hueQuitoProfiles.firstWhere((p) => p.id == winningId);
      expect(profile.titleEs, 'El Aventurero');
    });
  });

  group('PreferencesScreen and AdminQuizScreen Widget Tests', () {
    testWidgets('PreferencesScreen renders with Quito badge, language toggle, and questions',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizQuestionsStreamProvider.overrideWith((ref) => Stream.value(defaultQuizQuestions)),
          ],
          child: const MaterialApp(
            home: PreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Quito badge
      expect(find.text('Quito • ADN Gastronómico'), findsOneWidget);

      // Check skip button
      expect(find.text('Saltar'), findsOneWidget);

      // Check Step 1: Sector selection step
      expect(find.text('Paso 1 de 5 • Tu Sector'), findsOneWidget);
      expect(find.text('¿De qué sector de Quito eres?'), findsOneWidget);
      expect(find.text('Centro Histórico'), findsOneWidget);
      expect(find.text('Otro sector'), findsOneWidget);

      // Advance to food questions
      await tester.tap(find.text('Continuar al Quiz Gastronómico'));
      await tester.pumpAndSettle();

      // Check progress bar header for food questions
      expect(find.text('Pregunta 1 de 4'), findsWidgets);

      // Check first question title
      expect(find.text(defaultQuizQuestions.first.titleEs), findsOneWidget);

      // Check options rendered
      expect(find.text(defaultQuizQuestions.first.options.first.textEs), findsOneWidget);
    });

    testWidgets('PreferencesScreen completion in guest mode displays Login / Register button',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizQuestionsStreamProvider.overrideWith((ref) => Stream.value(defaultQuizQuestions)),
          ],
          child: const MaterialApp(
            home: PreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Select sector and continue to food questions
      expect(find.text('¿De qué sector de Quito eres?'), findsOneWidget);
      await tester.tap(find.text('Continuar al Quiz Gastronómico'));
      await tester.pumpAndSettle();

      // Answer all 4 food questions by tapping an option text
      for (int i = 0; i < defaultQuizQuestions.length; i++) {
        final optionText = defaultQuizQuestions[i].options.first.textEs;
        await tester.tap(find.text(optionText));
        await tester.pumpAndSettle();
      }

      // Check that the completion screen offers login to continue and guest option
      expect(find.text('¡Quiz Completado!'), findsOneWidget);
      expect(find.text('Tu Zona: Centro Histórico'), findsOneWidget);
      expect(find.text('Iniciar Sesión / Registrarme'), findsOneWidget);
      expect(find.text('O continuar como invitado'), findsOneWidget);
      expect(find.text('Repetir Quiz'), findsOneWidget);
    });

    testWidgets('AdminQuizScreen renders banner, guide, and question cards with profile badges',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quizQuestionsStreamProvider.overrideWith((ref) => Stream.value(defaultQuizQuestions)),
          ],
          child: const MaterialApp(
            home: AdminQuizScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Header Banner
      expect(find.text('Configuración del Quiz'), findsOneWidget);

      // Check Educational Guide
      expect(find.text('¿Cómo funciona la asignación automática?'), findsOneWidget);

      // Check Add Question Button
      expect(find.text('Nueva Pregunta'), findsOneWidget);

      // Check questions list
      expect(find.text('Pregunta #1'), findsOneWidget);
      expect(find.text('Pregunta #2'), findsOneWidget);
      expect(find.text('Pregunta #3'), findsOneWidget);
      expect(find.text('Pregunta #4'), findsOneWidget);

      // Check profile assignment pills
      expect(find.text('Sopero'), findsWidgets);
      expect(find.text('Carnívoro'), findsWidgets);
    });
  });
}
