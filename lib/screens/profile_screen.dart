import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hue_quito/repositories/user_repository.dart';
import 'package:hue_quito/repositories/auth_repository.dart';
import 'package:hue_quito/providers/auth_provider.dart' hide currentUserProvider;
import 'package:hue_quito/screens/preferences_screen.dart';
import 'package:hue_quito/screens/edit_profile_screen.dart';
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
    'es': {
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
    'en': {
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

  void _showInviteDialog(BuildContext context) {
    Share.share('¡Ven a conocer conmigo la gastronomía de Quito y sus huecas! Únete a Hue-Quito: https://huequito.app/invite');
  }

  Future<void> _applySettingWithRestart(VoidCallback updateSetting) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    updateSetting();
    ref.invalidate(huecasProvider);
    ref.invalidate(routesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final lang = t[settings.language] ?? t['es']!;

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
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (user) {
          final isGuest = user == null;
          final huecasList = ref.watch(huecasProvider).value ?? [];
          final displayUser = user ?? UserModel(
            uid: 'guest',
            email: 'invitado@huequito.com',
            name: 'Invitado',
            profilePicUrl: 'https://ui-avatars.com/api/?name=Invitado&background=random',
            gamification: {'level': 1, 'totalStamps': 0, 'title': 'Explorador'},
            preferences: {}, sectorAlbums: [],
          );
          return SingleChildScrollView(
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
                        CircleAvatar(radius: 36, backgroundImage: NetworkImage(displayUser.profilePicUrl)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(displayUser.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20, color: AppTheme.primary),
                                    onPressed: () => context.push('/edit_profile'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              Text(displayUser.email, style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                            if (displayUser.favoriteHuecas.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('No tienes huecas favoritas.', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ...displayUser.favoriteHuecas.map((id) {
                                final h = huecasList.where((hueca) => hueca.id == id).firstOrNull;
                                if (h == null) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: _buildFavoriteCard(context, h.images.isNotEmpty ? h.images.first : 'https://placehold.co/150x150.png', h.name, h.sector),
                                );
                              }).toList(),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          if (displayUser.favoriteHuecas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('No tienes huecas favoritas.', style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ...displayUser.favoriteHuecas.map((id) {
                              final h = huecasList.where((hueca) => hueca.id == id).firstOrNull;
                              if (h == null) return const SizedBox.shrink();
                              return _buildFavoriteCard(context, h.images.isNotEmpty ? h.images.first : 'https://placehold.co/150x150.png', h.name, h.sector);
                            }).toList(),
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
                    _buildPreferenceItem(context, Icons.local_fire_department, 'Nivel de Picante', displayUser.preferences['spiceLevel']?.toString() ?? 'Medio'),
                    _buildPreferenceItem(context, Icons.dinner_dining, 'Platos Favoritos Elegidos', (displayUser.preferences['favoriteDishes'] as List<dynamic>? ?? []).isEmpty ? 'Ninguno' : (displayUser.preferences['favoriteDishes'] as List<dynamic>).join(', ')),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
                      context.push('/preferences');
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
                        Expanded(child: _buildToggleButton(context, 'es', 'Español (EC)', settings.language == 'es', () { 
                            _applySettingWithRestart(() => ref.read(settingsProvider.notifier).setLanguage('es'));
                          })),
                        const SizedBox(width: 8),
                        Expanded(child: _buildToggleButton(context, 'en', 'English', settings.language == 'en', () { 
                            _applySettingWithRestart(() => ref.read(settingsProvider.notifier).setLanguage('en'));
                          })),
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
                          GestureDetector(onTap: (){ _applySettingWithRestart(() => ref.read(settingsProvider.notifier).setTextSize('A-')); }, child: Text('A-', style: TextStyle(fontWeight: FontWeight.bold, color: settings.textSize == 'A-' ? AppTheme.primary : Colors.grey))),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: (){ _applySettingWithRestart(() => ref.read(settingsProvider.notifier).setTextSize('Normal')); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: settings.textSize == 'Normal' ? AppTheme.secondary : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text('Normal', style: TextStyle(fontWeight: FontWeight.bold, color: settings.textSize == 'Normal' ? Colors.white : Colors.grey)))),
                          const SizedBox(width: 12),
                          GestureDetector(onTap: (){ _applySettingWithRestart(() => ref.read(settingsProvider.notifier).setTextSize('A+')); }, child: Text('A+', style: TextStyle(fontWeight: FontWeight.bold, color: settings.textSize == 'A+' ? AppTheme.primary : Colors.grey))),
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
                          GestureDetector(onTap: (){ _applySettingWithRestart(() => ref.read(settingsProvider.notifier).toggleDarkMode(false)); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: !settings.isDarkMode ? AppTheme.secondary.withValues(alpha:0.2) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.light_mode, size: 14, color: !settings.isDarkMode ? AppTheme.secondary : Colors.grey), const SizedBox(width: 4), Text(lang['light']!, style: TextStyle(fontWeight: FontWeight.bold, color: !settings.isDarkMode ? AppTheme.secondary : Colors.grey))]))),
                          const SizedBox(width: 4),
                          GestureDetector(onTap: (){ _applySettingWithRestart(() => ref.read(settingsProvider.notifier).toggleDarkMode(true)); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: settings.isDarkMode ? Colors.grey.withValues(alpha:0.4) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.dark_mode, size: 14, color: settings.isDarkMode ? Colors.white : Colors.grey), const SizedBox(width: 4), Text(lang['dark']!, style: TextStyle(fontWeight: FontWeight.bold, color: settings.isDarkMode ? Colors.white : Colors.grey))]))),
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
                          Switch(value: settings.isHighContrast, onChanged: (v){ _applySettingWithRestart(() => ref.read(settingsProvider.notifier).toggleHighContrast(v)); }, activeColor: AppTheme.primary),
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
                            decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle), 
                            child: const Icon(Icons.g_mobiledata, size: 32, color: Colors.blue)
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(lang['connected']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), 
                                Text(displayUser.email, style: TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)
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
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      ref.invalidate(currentUserProvider);
                      if (context.mounted) context.go('/login');
                    }, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.red.withValues(alpha:0.2) : Colors.red[50], foregroundColor: Colors.red, elevation: 0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.logout), const SizedBox(width: 8), Text(lang['logout']!)]))),
                    const SizedBox(height: 16),
                    const Center(child: Text('Hue-Quito v1.2.0', style: TextStyle(fontSize: 10, color: Colors.grey))),
                  ],
                ),
              ),

            ],
          ),
        ),
      );
        },
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
