import re

with open('lib/screens/login_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Fix duplicates
c = c.replace('''import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';''', '''import 'package:cloud_firestore/cloud_firestore.dart';''')

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

# Update email sign in
c = c.replace('''    final userRepo = ref.read(userRepositoryProvider);
    final userModel = await userRepo.getCurrentUser();

    if (mounted) {
      if (userModel != null && userModel.role == 'business') {
        context.go('/business/dashboard');
      } else {
        context.go('/home');
      }
    }''', logic)

with open('lib/screens/login_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
