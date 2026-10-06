import os
import glob
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Replace hardcoded textDark with adaptive onSurface
    content = content.replace('AppTheme.textDark', 'Theme.of(context).colorScheme.onSurface')
    
    # Replace Colors.white backgrounds in Containers/BoxDecorations with cardColor
    content = re.sub(r'color:\s*Colors\.white\b', 'color: Theme.of(context).cardColor', content)
    
    # Fix instances where Colors.white was used for text or icons inside TextStyle or Icon.
    # This regex looks for TextStyle or Icon with Theme.of(context).cardColor and changes it back.
    # Since regexes with arbitrarily nested parentheses are hard, we'll just do a simpler fix:
    content = re.sub(r'TextStyle\(([^)]*?)color:\s*Theme\.of\(context\)\.cardColor([^)]*?)\)', r'TextStyle(\1color: Colors.white\2)', content)
    content = re.sub(r'Icon\(([^)]*?)color:\s*Theme\.of\(context\)\.cardColor([^)]*?)\)', r'Icon(\1color: Colors.white\2)', content)

    # Some widgets use AppTheme.backgroundLight directly. We should use Theme.of(context).scaffoldBackgroundColor
    content = content.replace('AppTheme.backgroundLight', 'Theme.of(context).scaffoldBackgroundColor')
    
    # Adaptive greys
    content = re.sub(r'Colors\.grey\[200\]', '(Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200])', content)
    content = re.sub(r'Colors\.grey\[100\]', '(Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[100])', content)
    content = re.sub(r'Colors\.grey\[300\]', '(Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300])', content)

    # Segmented controls inside route_list_screen
    content = content.replace('_selectedTab == 0 ? Theme.of(context).cardColor : Colors.transparent', '_selectedTab == 0 ? Theme.of(context).colorScheme.surface : Colors.transparent')
    content = content.replace('_selectedTab == 1 ? Theme.of(context).cardColor : Colors.transparent', '_selectedTab == 1 ? Theme.of(context).colorScheme.surface : Colors.transparent')

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, _, files in os.walk('lib/screens'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

for root, _, files in os.walk('lib/widgets'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
