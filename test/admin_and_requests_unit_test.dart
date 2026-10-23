import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_request_repository.dart';
import 'package:hue_quito/repositories/support_repository.dart';
import 'package:hue_quito/repositories/user_repository.dart';

void main() {
  group('Admin, Solicitudes & Support Unit Tests', () {
    test('HuecaRequest serialization toMap produces correct Firestore schema', () {
      final now = DateTime(2026, 10, 20, 15, 30);
      final request = HuecaRequest(
        id: 'req_123',
        huecaName: 'Empanadas de Morocho La Ronda',
        address: 'Calle Guayaquil N4-12',
        sector: 'Centro Histórico',
        phone: '0981122334',
        description: 'Empanadas tradicionales de morocho y queso',
        mainDish: 'Empanada de morocho',
        ownerName: 'Carlos Benítez',
        ownerEmail: 'carlos.benitez@gmail.com',
        photoUrl: 'https://example.com/empanada.jpg',
        requestedBy: 'user_carlos',
        status: 'pending',
        createdAt: now,
      );

      final map = request.toMap();
      expect(map['huecaName'], equals('Empanadas de Morocho La Ronda'));
      expect(map['ownerEmail'], equals('carlos.benitez@gmail.com'));
      expect(map['status'], equals('pending'));
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['photoUrl'], equals('https://example.com/empanada.jpg'));
      expect(map['rejectionReason'], isNull);
    });

    test('HuecaRequest approved and rejected states properly preserve metadata and notes', () {
      final now = DateTime.now();
      final approvedRequest = HuecaRequest(
        id: 'req_approved',
        huecaName: 'Picantería Don Mario',
        address: 'Calle Loja',
        sector: 'Centro Histórico',
        phone: '099000111',
        description: 'Comida criolla',
        mainDish: 'Yahuarlocro',
        ownerName: 'Mario',
        ownerEmail: 'mario@test.com',
        requestedBy: 'user_mario',
        status: 'approved',
        createdAt: now.subtract(const Duration(days: 1)),
        reviewedAt: now,
        reviewedBy: 'admin_super',
        createdHuecaId: 'hueca_mario_generated',
        adminNotes: 'Verificado personalmente',
      );

      final map = approvedRequest.toMap();
      expect(map['status'], equals('approved'));
      expect(map['reviewedBy'], equals('admin_super'));
      expect(map['createdHuecaId'], equals('hueca_mario_generated'));
      expect(map['adminNotes'], equals('Verificado personalmente'));
      expect(map['rejectionReason'], isNull);

      final rejectedRequest = HuecaRequest(
        id: 'req_rejected',
        huecaName: 'Local Sin Permiso',
        address: 'Sector Norte',
        sector: 'La Floresta',
        phone: '099',
        description: 'Prueba',
        mainDish: 'Nada',
        ownerName: 'Test',
        ownerEmail: 'test@test.com',
        requestedBy: 'user_test',
        status: 'rejected',
        createdAt: now.subtract(const Duration(hours: 5)),
        reviewedAt: now,
        reviewedBy: 'admin_super',
        rejectionReason: 'No cumple con los requisitos de hueca tradicional',
      );

      final rejMap = rejectedRequest.toMap();
      expect(rejMap['status'], equals('rejected'));
      expect(rejMap['rejectionReason'], equals('No cumple con los requisitos de hueca tradicional'));
      expect(rejMap['createdHuecaId'], isNull);
    });

    test('SupportMessage status transitions and response serialization', () {
      final now = DateTime.now();
      final msg = SupportMessage(
        id: 'msg_001',
        huecaId: 'hueca_1',
        huecaName: 'Hornados Dieguito',
        branchId: 'matriz',
        branchName: 'Matriz Principal',
        senderUid: 'owner_diego',
        senderName: 'Diego Morales',
        senderEmail: 'diego@hornados.ec',
        subject: 'Cambio de horario para feriado',
        message: 'Hola, deseamos actualizar el horario de apertura este viernes.',
        status: 'responded',
        createdAt: now.subtract(const Duration(hours: 3)),
        readAt: now.subtract(const Duration(hours: 2)),
        readBy: 'admin_uid',
        adminResponse: 'Horario actualizado en el sistema.',
        respondedAt: now.subtract(const Duration(hours: 1)),
        respondedBy: 'admin_uid',
      );

      final map = msg.toMap();
      expect(map['status'], equals('responded'));
      expect(map['adminResponse'], equals('Horario actualizado en el sistema.'));
      expect(map['senderEmail'], equals('diego@hornados.ec'));
      expect(map['branchName'], equals('Matriz Principal'));
      expect(map['readAt'], isNotNull);
      expect(map['respondedAt'], isNotNull);
    });

    test('User deduplication logic prioritizes authentic Firebase UID over email-based placeholders', () {
      final userList = [
        UserModel(
          uid: 'claudio@test.ec', // Placeholder from email
          email: 'claudio@test.ec',
          name: 'Usuario',
          profilePicUrl: '',
          role: 'user',
          gamification: {},
          preferences: {},
          sectorAlbums: [],
        ),
        UserModel(
          uid: 'auth_uid_claudio_real', // Real Firebase Auth UID
          email: 'claudio@test.ec',
          name: 'Claudio Real',
          profilePicUrl: 'https://example.com/claudio.jpg',
          role: 'business',
          gamification: {},
          preferences: {},
          sectorAlbums: [],
        ),
      ];

      // Simulate deduplication logic from UserRepository
      final Map<String, UserModel> usersByEmail = {};
      for (final user in userList) {
        final emailKey = user.email.trim().toLowerCase();
        if (!usersByEmail.containsKey(emailKey)) {
          usersByEmail[emailKey] = user;
        } else {
          final existing = usersByEmail[emailKey]!;
          final existingIsEmailId = existing.uid.contains('@');
          final userIsEmailId = user.uid.contains('@');
          if (existingIsEmailId && !userIsEmailId) {
            usersByEmail[emailKey] = user;
          }
        }
      }

      final deduplicated = usersByEmail.values.toList();
      expect(deduplicated.length, equals(1));
      expect(deduplicated.first.uid, equals('auth_uid_claudio_real'));
      expect(deduplicated.first.name, equals('Claudio Real'));
      expect(deduplicated.first.role, equals('business'));
    });
  });
}
