import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/settings_provider.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Terms & Privacy' : 'Términos y Privacidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: isEn ? 'Back' : 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn ? 'Terms & Conditions' : 'Términos y Condiciones',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              isEn
                  ? 'Welcome to Hue-Quito. By using our application, you agree to share your location anonymously for restaurant recommendations and gastronomic passport features.'
                  : 'Bienvenido a Hue-Quito. Al usar nuestra aplicación, aceptas compartir tu ubicación de manera anónima para sugerencias de restaurantes y funciones del pasaporte gastronómico.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 32),
            Text(
              isEn ? 'Heritage Privacy Policy' : 'Política de Privacidad Patrimonial',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),
            Text(
              isEn
                  ? 'We take your privacy very seriously. Your gastronomic preferences and data are never shared with third parties, except with participating huecas in an anonymized manner.'
                  : 'Nos tomamos muy en serio tu privacidad. Tus datos de preferencias gastronómicas no se comparten con terceros, salvo con las huecas participantes de forma anonimizada.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 100),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isEn ? 'Accept & Go Back' : 'Aceptar y Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
