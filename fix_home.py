import sys

with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

insert_idx = -1
for i, line in enumerate(lines):
    if 'children: [' in line and 'crossAxisAlignment: CrossAxisAlignment.start,' in lines[i-1]:
        insert_idx = i + 1
        break

if insert_idx == -1:
    print("Could not find insertion point!")
    sys.exit(1)

new_code = '''
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() { _searchQuery = val; });
                      },
                      decoration: InputDecoration(
                        hintText: lang == 'es' ? 'Locales, platos y productos' : 'Places, dishes and products',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMedium),
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  // Recomendaciones
                  if (user != null && user.preferences.containsKey('persona'))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang == 'es' ? 'Nuestra recomendación para ti' : 'Recommended for you', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            String persona = user.preferences['persona'] ?? '';
                            List<String> targetTags = [];
                            if (persona == 'aventurero') targetTags = ['mercado', 'tradicional', 'tripa mishqui', 'guatita'];
                            else if (persona == 'picador') targetTags = ['empanadas', 'snack', 'cafe', 'morocho'];
                            else if (persona == 'carnivoro') targetTags = ['cerdo', 'hornado', 'fritada', 'asado', 'parrillada'];
                            else if (persona == 'sopero') targetTags = ['sopa', 'caldo', 'locro', 'yahuarlocro', 'encebollado'];
                            else if (persona == 'dulcero') targetTags = ['dulce', 'postre', 'helado', 'higos', 'pristiños'];
                            else if (persona == 'callejero') targetTags = ['salchipapa', 'hamburguesa', 'pollo frito', 'comida rapida'];
                            
                            var recs = huecasAsync.value?.where((h) => 
                              h.tags.any((t) => targetTags.any((tt) => t.toLowerCase().contains(tt)))
                            ).toList() ?? [];
                            
                            if (recs.isEmpty) {
                               recs = huecasAsync.value?.take(3).toList() ?? [];
                            } else {
                               recs.shuffle();
                            }
                            
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: recs.take(5).map((h) => SizedBox(width: 300, child: _buildHuecaCard(context, hueca: h, lang: lang, width: 280))).toList(),
                              ),
                            );
                          }
                        ),
                        SizedBox(height: 24),
                      ],
                    ),
'''

lines.insert(insert_idx, new_code)

with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
