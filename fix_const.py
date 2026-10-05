import os
import glob

for filepath in glob.glob('lib/screens/**/*.dart', recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # remove const before Text(lang == 'es'
    content = content.replace("const Text(lang == 'es'", "Text(lang == 'es'")
    content = content.replace("const SnackBar(content: Text(lang == 'es'", "SnackBar(content: Text(lang == 'es'")
    content = content.replace("const Text(!_isFavorite", "Text(!_isFavorite")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
