import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/screens/preferences_screen.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/screens/settings/faq_screen.dart';
import 'package:hue_quito/screens/settings/terms_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isFavoritesExpanded = false;

  final Map<String, Map<String, String>> t = {
    'EC': {
      'profile_title': 'Mi Perfil',
      'profile_subtitle': 'Pasaporte Gastronómico',
      'edit_profile': 'Editar Perfil',
      'change_name': 'Cambiar Nombre',
      'change_photo': 'Cambiar Foto',
      'reset_pass': 'Restablecer Contraseña',
      'close': 'Cerrar',
      'favorites': 'Mis Favoritos',
      'see_more': 'Ver más',
      'see_less': 'Ver menos',
      'preferences': 'Mis Preferencias de Paladar',
      'edit_preferences': 'Modificar preferencias',
      'settings': 'Configuración y Experiencia',
      'language': 'Idioma de la Guía:',
      'accessibility': 'Accesibilidad y Lectura Andina:',
      'text_size': 'Tamaño de texto',
      'theme': 'Tema de visualización',
      'light': 'Claro',
      'dark': 'Oscuro',
      'high_contrast': 'Alto Contraste',
      'high_contrast_desc': 'Mayor accesibilidad visual',
      'account': 'Gestión de Cuenta',
      'connected': 'Conectada con Google',
      'support': 'Ayuda y Soporte Quiteño',
      'terms': 'Términos y Privacidad Patrimonial',
      'invite': 'Invitar a otros comensales',
      'logout': 'Cerrar Sesión',
    },
    'US': {
      'profile_title': 'My Profile',
      'profile_subtitle': 'Gastronomic Passport',
      'edit_profile': 'Edit Profile',
      'change_name': 'Change Name',
      'change_photo': 'Change Photo',
      'reset_pass': 'Reset Password',
      'close': 'Close',
      'favorites': 'My Favorites',
      'see_more': 'See more',
      'see_less': 'See less',
      'preferences': 'My Palate Preferences',
      'edit_preferences': 'Edit preferences',
      'settings': 'Settings & Experience',
      'language': 'Guide Language:',
      'accessibility': 'Accessibility & Andean Reading:',
      'text_size': 'Text Size',
      'theme': 'Visual Theme',
      'light': 'Light',
      'dark': 'Dark',
      'high_contrast': 'High Contrast',
      'high_contrast_desc': 'Increases visual accessibility',
      'account': 'Account Management',
      'connected': 'Connected with Google',
      'support': 'Quito Help & Support',
      'terms': 'Terms & Privacy',
      'invite': 'Invite other diners',
      'logout': 'Log Out',
    }
  };

  void _showEditProfile(BuildContext context, Map<String, String> lang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang['edit_profile']!, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.person), title: Text(lang['change_name']!), onTap: () { Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.photo_camera), title: Text(lang['change_photo']!), onTap: () { Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.lock_reset), title: Text(lang['reset_pass']!), onTap: () { Navigator.pop(context); }),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(lang['close']!))],
      )
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invitar Amigos', textAlign: TextAlign.center),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Comparte este enlace con tus amigos:'),
            SizedBox(height: 16),
            SelectableText('¡Ven a conocer conmigo la gastronomía de Quito y sus huecas! Únete a Hue-Quito: https://huequito.app/invite', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = t[settings.language]!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            const Icon(Icons.restaurant, color: AppTheme.primary, size: 32),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang['profile_title']!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(lang['profile_subtitle']!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium)),
              ],
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Identidad
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(radius: 36, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80')),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Camila Proaño', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: AppTheme.primary),
                                    onPressed: () => _showEditProfile(context, lang),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const Text('camila.quito@gmail.com', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(children: [Icon(Icons.storefront, color: AppTheme.primary), Text('14', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Huecas', style: TextStyle(fontSize: 10, color: Colors.grey))]),
                        Column(children: [Icon(Icons.bookmark, color: AppTheme.secondary), Text('8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Favoritos', style: TextStyle(fontSize: 10, color: Colors.grey))]),
                        Column(children: [Icon(Icons.redeem, color: AppTheme.secondary), Text('2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('Premios', style: TextStyle(fontSize: 10, color: Colors.grey))]),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Favoritos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [const Icon(Icons.favorite, color: AppTheme.secondary), const SizedBox(width: 8), Text(lang['favorites']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                        TextButton(
                          onPressed: () { setState(() { _isFavoritesExpanded = !_isFavoritesExpanded; }); },
                          child: Text(_isFavoritesExpanded ? lang['see_less']! : lang['see_more']!, style: const TextStyle(color: AppTheme.primary)),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_isFavoritesExpanded)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80', 'Hornado San Francisco', 'Centro Histórico'),
                            const SizedBox(width: 8),
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=150&q=80', 'Morocho La Floresta', 'La Floresta'),
                            const SizedBox(width: 8),
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=150&q=80', 'Empanadas de Viento', 'San Juan'),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=150&q=80', 'Hornado San Francisco', 'Centro Histórico'),
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=150&q=80', 'Morocho La Floresta', 'La Floresta'),
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=150&q=80', 'Empanadas de Viento', 'San Juan'),
                            _buildFavoriteCard(context, 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=150&q=80', 'Caldo de Gallina', 'La Marín'),
                        ],
                      )
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Preferencias
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.tune, color: AppTheme.primary), const SizedBox(width: 8), Text(lang['preferences']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 12),
                    _buildPreferenceItem(context, Icons.local_fire_department, 'Nivel de Picante', 'Medio (Ají de tomate de árbol con moderación)'),
                    _buildPreferenceItem(context, Icons.dinner_dining, 'Platos Favoritos Elegidos', 'Hornados, Sopas, Dulces'),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PreferencesScreen()));
                    }, child: Text(lang['edit_preferences']!))),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Configuracion y Experiencia
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.settings, color: AppTheme.primary), const SizedBox(width: 8), Text(lang['settings']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 24),
                    Text(lang['language']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildToggleButton(context, 'EC', 'Español (EC)', settings.language == 'EC', () { ref.read(settingsProvider.notifier).setLanguage('EC'); })),
                        const SizedBox(width: 8),
                        Expanded(child: _buildToggleButton(context, 'US', 'English', settings.language == 'US', () { ref.read(settingsProvider.notifier).setLanguage('US'); })),
                      ]
                    ),
                    const SizedBox(height: 24),
                    Text(lang['accessibility']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          const Icon(Icons.text_fields, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(lang['text_size']!, style: const TextStyle(fontSize: 14))),
                          GestureDetector(onTap: (){ ref.read(settingsProvider.notifier).setTextSize('A-'); }, child: Text('A-', style: TextStyle(fontWeight: FontWeight.bold, color: settings.textSize == 'A-' ? AppTheme.primary : Colors.grey))),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: (){ ref.read(settingsProvider.notifier).setTextSize('Normal'); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: settings.textSize == 'Normal' ? AppTheme.secondary : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text('Normal', style: TextStyle(fontWeight: FontWeight.bold, color: settings.textSize == 'Normal' ? Colors.white : Colors.grey)))),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: (){ ref.read(settingsProvider.notifier).setTextSize('A+'); }, child: Text('A+', style: TextStyle(fontWeight: FontWeight.bold, color: settings.textSize == 'A+' ? AppTheme.primary : Colors.grey))),
                        ],
                      )
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          const Icon(Icons.palette, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(lang['theme']!, style: const TextStyle(fontSize: 14))),
                          GestureDetector(onTap: (){ ref.read(settingsProvider.notifier).toggleDarkMode(false); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: !settings.isDarkMode ? AppTheme.secondary.withValues(alpha:0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.light_mode, size: 14, color: !settings.isDarkMode ? AppTheme.secondary : Colors.grey), const SizedBox(width: 4), Text(lang['light']!, style: TextStyle(fontWeight: FontWeight.bold, color: !settings.isDarkMode ? AppTheme.secondary : Colors.grey))]))),
                          const SizedBox(width: 4),
                          GestureDetector(onTap: (){ ref.read(settingsProvider.notifier).toggleDarkMode(true); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: settings.isDarkMode ? Colors.grey.withValues(alpha:0.4) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.dark_mode, size: 14, color: settings.isDarkMode ? Colors.white : Colors.grey), const SizedBox(width: 4), Text(lang['dark']!, style: TextStyle(fontWeight: FontWeight.bold, color: settings.isDarkMode ? Colors.white : Colors.grey))]))),
                        ],
                      )
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          const Icon(Icons.contrast, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lang['high_contrast']!, style: const TextStyle(fontSize: 14)), Text(lang['high_contrast_desc']!, style: const TextStyle(fontSize: 10, color: Colors.grey))])),
                          Switch(value: settings.isHighContrast, onChanged: (v){ ref.read(settingsProvider.notifier).toggleHighContrast(v); }, activeColor: AppTheme.primary),
                        ],
                      )
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Gestion de Cuenta
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lang['account']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4), 
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), 
                            child: Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png', width: 24, height: 24)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(lang['connected']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), 
                                const Text('camila.quito@gmail.com', style: TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)
                              ]
                            )
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_outline, color: Colors.green),
                        ],
                      )
                    ),
                    const SizedBox(height: 12),
                    ListTile(leading: const Icon(Icons.support_agent), title: Text(lang['support']!, style: const TextStyle(fontSize: 14)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen()))),
                    ListTile(leading: const Icon(Icons.policy), title: Text(lang['terms']!, style: const TextStyle(fontSize: 14)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
                    ListTile(leading: const Icon(Icons.share), title: Text(lang['invite']!, style: const TextStyle(fontSize: 14)), trailing: const Icon(Icons.chevron_right), onTap: () => _showInviteDialog(context)),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha:0.2) : Colors.red[50], foregroundColor: Colors.red, elevation: 0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.logout), const SizedBox(width: 8), Text(lang['logout']!)]))),
                    const SizedBox(height: 16),
                    const Center(child: Text('Hue-Quito v1.2.0', style: TextStyle(fontSize: 10, color: Colors.grey))),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(BuildContext context, String mainText, String subText, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(24)
        ),
        child: Column(
          children: [
            Text(mainText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black))),
            Text(subText, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black))),
          ],
        )
      ),
    );
  }

  Widget _buildFavoriteCard(BuildContext context, String imageUrl, String title, String location) {
    return Container(
      width: 140,
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network(imageUrl, height: 80, width: 140, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(location, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPreferenceItem(BuildContext context, IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: AppTheme.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
