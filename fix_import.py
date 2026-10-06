import os

filepath = 'lib/screens/preferences_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'package:hue_quito/providers/user_provider.dart';", "import 'package:hue_quito/providers/data_provider.dart';")

# Also, currentUserProvider is a FutureProvider returning UserModel?, so we must read its value using `ref.read(currentUserProvider).value` (already done)
# But we cannot update it using `ref.read(currentUserProvider.notifier).updateUser(...)` because it's a FutureProvider without a notifier.
# Usually to update user we do `ref.read(userRepositoryProvider).updateUser(...)`
# Let's fix the update logic in preferences_screen:

content = content.replace(
    "ref.read(currentUserProvider.notifier).updateUser(user.copyWith(preferences: newPrefs));",
    "ref.read(userRepositoryProvider).updateUser(user.copyWith(preferences: newPrefs));\\n      ref.invalidate(currentUserProvider);"
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
