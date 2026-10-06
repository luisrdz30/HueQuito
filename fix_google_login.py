import re

with open('lib/screens/login_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

logic = '''
      final userRepo = ref.read(userRepositoryProvider);
      var userModel = await userRepo.getCurrentUser();

      if (_isBusinessOwner && userModel != null && userModel.role != 'business') {
        await FirebaseFirestore.instance.collection('users').doc(userModel.uid).update({'role': 'business'});
        userModel = await userRepo.getCurrentUser();
      }

      if (mounted) {
        if (userModel != null && userModel.role == 'business') {
          context.go('/business/dashboard');
        } else {
          context.go('/home');
        }
      }
'''

# Update Google sign in
c = c.replace('''      if (mounted) context.go('/home');''', logic)

with open('lib/screens/login_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
