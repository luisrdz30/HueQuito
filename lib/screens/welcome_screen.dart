import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Spacer(),
              // Logo/Image
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                  image: DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1541518763669-27fef04b14ea?q=80&w=600&auto=format&fit=crop'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 48),
              // Titles
              Text(
                'Bienvenido a HueQuito',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Listo para comenzar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textMedium,
                ),
              ),
              Spacer(),
              // Button
              ElevatedButton(
                onPressed: () => context.go('/preferences'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Continuar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
