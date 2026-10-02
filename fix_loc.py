import io
import re

file_path = 'lib/screens/home_screen.dart'
with io.open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("Text('Explorar',", "Text(lang == 'es' ? 'Explorar' : 'Explore',")
content = content.replace("Text('PLATO INSIGNIA'", "Text(lang == 'es' ? 'PLATO INSIGNIA' : 'SIGNATURE DISH'")

with io.open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

file_path2 = 'lib/screens/hueca_detail_screen.dart'
with io.open(file_path2, 'r', encoding='utf-8') as f:
    content2 = f.read()

content2 = content2.replace("Text('Spot Details',", "Text(lang == 'es' ? 'Detalles de Hueca' : 'Spot Details',")
content2 = content2.replace("Text('1 / 5 FOTOS',", "Text(lang == 'es' ? '1 / 5 FOTOS' : '1 / 5 PHOTOS',")
content2 = content2.replace("Text('De Doña Rosa',", "Text(lang == 'es' ? 'Tradición Quiteña' : 'Quito Tradition',")
content2 = content2.replace("Share.share('¡Ven acompáñame a visitar", "Share.share(lang == 'es' ? '¡Ven acompáñame a visitar \ conmigo en Hue-Quito! ??????\\n\\nMira dónde queda aquí: https://maps.google.com/?q=\,\' : 'Come visit \ with me on Hue-Quito! ??????\\n\\nSee where it is here: https://maps.google.com/?q=\,\') //")

with io.open(file_path2, 'w', encoding='utf-8') as f:
    f.write(content2)
print('Done!')
