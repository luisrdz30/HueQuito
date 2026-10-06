import os

filepath = 'lib/screens/preferences_screen.dart'
new_code = """import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/settings_provider.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final Set<String> _selectedCravings = {'soups', 'mains'};
  final Set<String> _selectedZones = {'Centro Histórico', 'Conocoto'};
  bool _locationEnabled = true;
  bool _treasureMode = true;
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final isEs = lang == 'es';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(isEs ? 'Paso 2 de 2' : 'Step 2 of 2'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEs ? 'Tu Pasaporte Culinario' : 'Your Culinary Passport', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(isEs ? '¿Qué sabores te mueven el apetito?' : 'What flavors move your appetite?', style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 24),
            
            Text(isEs ? 'Tus antojitos preferidos' : 'Your favorite cravings', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            _buildCravingItem('soups', isEs ? 'Sopas' : 'Soups', Icons.ramen_dining, isEs ? 'Locro de papa, Caldo de patas' : 'Locro de papa, Cow Feet Broth'),
            _buildCravingItem('mains', isEs ? 'Platos Fuertes' : 'Main Dishes', Icons.kebab_dining, 'Hornado, Fritada'),
            _buildCravingItem('sweets', isEs ? 'Dulces' : 'Sweets', Icons.icecream, isEs ? 'Helados de paila, Colada morada' : 'Paila Ice Cream, Colada morada'),
            
            SizedBox(height: 24),
            Text(isEs ? '¿Qué zonas sueles recorrer?' : 'What zones do you usually visit?', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildZonePill('Centro Histórico', isEs ? 'Centro Histórico' : 'Historic Center'),
                _buildZonePill('Conocoto', 'Conocoto'),
                _buildZonePill('La Floresta', 'La Floresta'),
                _buildZonePill('Cumbayá', 'Cumbayá'),
              ],
            ),
            
            SizedBox(height: 24),
            Text(isEs ? 'Ajustes de Exploración' : 'Exploration Settings', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text(isEs ? 'Ubicación precisa' : 'Precise location'),
              subtitle: Text(isEs ? 'Para huecas y cromos cercanos' : 'For nearby spots and stickers'),
              value: _locationEnabled,
              onChanged: (v) => setState(() => _locationEnabled = v),
              activeThumbColor: AppTheme.primary,
            ),
            SwitchListTile(
              title: Text(isEs ? 'Buscador de Tesoros' : 'Treasure Hunter'),
              subtitle: Text(isEs ? 'Alértame de QRs escondidos' : 'Alert me of hidden QRs'),
              value: _treasureMode,
              onChanged: (v) => setState(() => _treasureMode = v),
              activeThumbColor: AppTheme.primary,
            ),
            SwitchListTile(
              title: Text(isEs ? 'Modo Offline' : 'Offline Mode'),
              subtitle: Text(isEs ? 'Guarda datos sin conexión' : 'Save data offline'),
              value: _offlineMode,
              onChanged: (v) => setState(() => _offlineMode = v),
              activeThumbColor: AppTheme.primary,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEs ? 'Preferencias guardadas exitosamente.' : 'Preferences saved successfully.')));
              } else {
                context.push('/login');
              }
            },
            child: Text(context.canPop() 
                ? (isEs ? 'Guardar preferencias' : 'Save preferences') 
                : (isEs ? 'Comenzar a explorar huecas' : 'Start exploring spots')),
          ),
        ),
      ),
    );
  }

  Widget _buildCravingItem(String id, String title, IconData icon, String subtitle) {
    final isSelected = _selectedCravings.contains(id);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCravings.remove(id);
          } else {
            _selectedCravings.add(id);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tertiary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300])!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.tertiary),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: isSelected ? Colors.white70 : Theme.of(context).colorScheme.onSurface.withValues(alpha:0.6), fontSize: 12)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.add_circle_outline, color: isSelected ? AppTheme.primary : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildZonePill(String id, String title) {
    final isSelected = _selectedZones.contains(id);
    return FilterChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _selectedZones.add(id);
          } else {
            _selectedZones.remove(id);
          }
        });
      },
      selectedColor: AppTheme.tertiary,
      backgroundColor: Theme.of(context).cardColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface),
      checkmarkColor: Colors.white,
    );
  }
}
"""

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_code)
