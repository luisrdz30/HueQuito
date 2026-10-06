import os
import re

filepath = 'lib/screens/album_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import for settings_provider if not exists
if 'settings_provider.dart' not in content:
    content = content.replace("import 'package:hue_quito/providers/huecas_provider.dart';", "import 'package:hue_quito/providers/huecas_provider.dart';\nimport 'package:hue_quito/providers/settings_provider.dart';")

# 2. Add `final lang = ref.watch(settingsProvider).language;` in `build`
if 'final lang = ref.watch(settingsProvider).language;' not in content:
    content = content.replace('final huecasAsync = ref.watch(huecasProvider);', 'final huecasAsync = ref.watch(huecasProvider);\n    final lang = ref.watch(settingsProvider).language;')

# 3. Translate texts in build method
content = content.replace("Text('Mi Álbum', style:", "Text(lang == 'es' ? 'Mi Álbum' : 'My Album', style:")
content = content.replace("Text('Progreso', style:", "Text(lang == 'es' ? 'Progreso' : 'Progress', style:")
content = content.replace("Text('$totalStamps Sellos Totales', style:", "Text(lang == 'es' ? '$totalStamps Sellos Totales' : '$totalStamps Total Stamps', style:")
content = content.replace("Text('Colección', style:", "Text(lang == 'es' ? 'Colección' : 'Collection', style:")
content = content.replace("Text('$completedSectors Sectores completados', style:", "Text(lang == 'es' ? '$completedSectors Sectores completados' : '$completedSectors Completed Sectors', style:")
content = content.replace("Text('Cartillas', style:", "Text(lang == 'es' ? 'Cartillas' : 'Cards', style:")
content = content.replace("Text('Sectores', style:", "Text(lang == 'es' ? 'Sectores' : 'Sectors', style:")

# 4. Pass lang to helper methods
content = content.replace("_buildHuecasList(huecasAsync, displayUser, isGuest)", "_buildHuecasList(huecasAsync, displayUser, isGuest, lang)")
content = content.replace("_buildSectorList(displayUser.sectorAlbums)", "_buildSectorList(displayUser.sectorAlbums, lang)")
content = content.replace("Widget _buildHuecasList(AsyncValue<List<Hueca>> huecasAsync, UserModel user, bool isGuest) {", "Widget _buildHuecasList(AsyncValue<List<Hueca>> huecasAsync, UserModel user, bool isGuest, String lang) {")
content = content.replace("Widget _buildSectorList(List<dynamic> sectorAlbums) {", "Widget _buildSectorList(List<dynamic> sectorAlbums, String lang) {")

content = content.replace("_buildHuecaCard(", "_buildHuecaCard(lang: lang, ")
content = content.replace("Widget _buildHuecaCard({required String title", "Widget _buildHuecaCard({required String lang, required String title")

content = content.replace("_buildSectorCard(", "_buildSectorCard(lang: lang, ")
content = content.replace("Widget _buildSectorCard({required String sectorName", "Widget _buildSectorCard({required String lang, required String sectorName")

# 5. Translate helper method texts
content = content.replace("Text('No hay huecas disponibles')", "Text(lang == 'es' ? 'No hay huecas disponibles' : 'No huecas available')")

# Fix the "feito" message and translate it
ugly_message = "return Center(child: Text('Aǧn no tienes sellos en ninguna hueca. Empieza a explorar!'));"
# Let's find exactly how it's written in the file, it might have weird chars due to encoding
import re
content = re.sub(r"return Center\(child: Text\('A[^\']*!'\)\);", 
"""return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              lang == 'es' 
                ? 'Aún no tienes sellos en ninguna hueca.\\n¡Empieza a explorar!'
                : 'You have no stamps yet.\\nStart exploring!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMedium, height: 1.5),
            ),
          ),
        );""", content)

content = content.replace("'Recompensa sorpresa'", "lang == 'es' ? 'Recompensa sorpresa' : 'Surprise reward'")
content = content.replace("'Completado!' : '$currentStamps/$targetStamps Sellos'", "isCompleted ? (lang == 'es' ? '¡Completado!' : 'Completed!') : (lang == 'es' ? '$currentStamps/$targetStamps Sellos' : '$currentStamps/$targetStamps Stamps')")
content = content.replace("isCompleted ? 'Completado!' : '$currentStamps/$targetStamps Sellos'", "isCompleted ? (lang == 'es' ? '¡Completado!' : 'Completed!') : (lang == 'es' ? '$currentStamps/$targetStamps Sellos' : '$currentStamps/$targetStamps Stamps')")
# There was an encoding issue, so I might need to match it more broadly
content = re.sub(r"isCompleted \? '[^']*' : '\$currentStamps/\$targetStamps Sellos'", "isCompleted ? (lang == 'es' ? '¡Completado!' : 'Completed!') : (lang == 'es' ? '$currentStamps/$targetStamps Sellos' : '$currentStamps/$targetStamps Stamps')", content)

content = content.replace("'Recompensa: $reward'", "lang == 'es' ? 'Recompensa: $reward' : 'Reward: $reward'")

ugly_sector_msg = "Text('Aǧn no tienes cromos por sector.', style: TextStyle(color: AppTheme.textMedium))"
content = re.sub(r"Text\('A[^\']*sector\.', style: TextStyle\(color: AppTheme\.textMedium\)\)", 
                 "Text(lang == 'es' ? 'Aún no tienes cromos por sector.' : 'No sector stickers yet.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMedium))", content)

content = content.replace("Text('$stickersCount de $totalStickers cromos'", "Text(lang == 'es' ? '$stickersCount de $totalStickers cromos' : '$stickersCount of $totalStickers stickers'")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
