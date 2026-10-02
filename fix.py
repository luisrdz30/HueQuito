import io

file_path = 'lib/screens/profile_screen.dart'
with io.open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

content = content.replace(\"'EC'\", \"'es'\")
content = content.replace(\"'US'\", \"'en'\")

with io.open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
