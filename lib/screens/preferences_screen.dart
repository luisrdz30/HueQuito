import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/theme/theme.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Set<String> _selectedCravings = {'Sopas', 'Platos Fuertes'};
  final Set<String> _selectedZones = {'Centro Histórico', 'Conocoto'};
  bool _locationEnabled = true;
  bool _treasureMode = true;
  bool _offlineMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Paso 2 de 2'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu Pasaporte Culinario', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('¿Qué sabores te mueven el apetito?', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            
            Text('Tus antojitos preferidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildCravingItem('Sopas', Icons.ramen_dining, 'Locro de papa, Caldo de patas'),
            _buildCravingItem('Platos Fuertes', Icons.kebab_dining, 'Hornado, Fritada'),
            _buildCravingItem('Dulces', Icons.icecream, 'Helados de paila, Colada morada'),
            
            const SizedBox(height: 24),
            Text('¿Qué zonas sueles recorrer?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildZonePill('Centro Histórico'),
                _buildZonePill('Conocoto'),
                _buildZonePill('La Floresta'),
                _buildZonePill('Cumbayá'),
              ],
            ),
            
            const SizedBox(height: 24),
            Text('Ajustes de Exploración', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Ubicación precisa'),
              subtitle: const Text('Para huecas y cromos cercanos'),
              value: _locationEnabled,
              onChanged: (v) => setState(() => _locationEnabled = v),
              activeThumbColor: AppTheme.primary,
            ),
            SwitchListTile(
              title: const Text('Buscador de Tesoros'),
              subtitle: const Text('Alértame de QRs escondidos'),
              value: _treasureMode,
              onChanged: (v) => setState(() => _treasureMode = v),
              activeThumbColor: AppTheme.primary,
            ),
            SwitchListTile(
              title: const Text('Modo Offline'),
              subtitle: const Text('Guarda datos sin conexión'),
              value: _offlineMode,
              onChanged: (v) => setState(() => _offlineMode = v),
              activeThumbColor: AppTheme.primary,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              if (context.canPop()) {
                // editing from profile
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferencias guardadas exitosamente.')));
              } else {
                // onboarding
                context.push('/login');
              }
            },
            child: Text(context.canPop() ? 'Guardar preferencias' : 'Comenzar a explorar huecas'),
          ),
        ),
      ),
    );
  }

  Widget _buildCravingItem(String title, IconData icon, String subtitle) {
    final isSelected = _selectedCravings.contains(title);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCravings.remove(title);
          } else {
            _selectedCravings.add(title);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tertiary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.tertiary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textDark, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: isSelected ? Colors.white70 : AppTheme.textMedium, fontSize: 12)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.check_circle : Icons.add_circle_outline, color: isSelected ? AppTheme.primary : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildZonePill(String title) {
    final isSelected = _selectedZones.contains(title);
    return FilterChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _selectedZones.add(title);
          } else {
            _selectedZones.remove(title);
          }
        });
      },
      selectedColor: AppTheme.tertiary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textDark),
      checkmarkColor: Colors.white,
    );
  }
}
