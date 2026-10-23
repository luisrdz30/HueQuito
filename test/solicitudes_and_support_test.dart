import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hue_quito/repositories/hueca_request_repository.dart';
import 'package:hue_quito/repositories/support_repository.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/screens/hueca_request_screen.dart';
import 'package:hue_quito/screens/admin/admin_solicitudes_screen.dart';
import 'package:hue_quito/screens/business/business_support_screen.dart';
import 'package:hue_quito/screens/admin/admin_support_screen.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  group('HuecaRequest Model & Serialization Tests', () {
    test('HuecaRequest initializes correctly and generates valid map', () {
      final now = DateTime.now();
      final req = HuecaRequest(
        id: 'req123',
        huecaName: 'Secos Don Pepe',
        address: 'García Moreno N5-42',
        sector: 'Centro Histórico',
        phone: '0991234567',
        description: 'Tradición de seco de chivo desde 1990',
        mainDish: 'Seco de Chivo',
        ownerName: 'Pepe Morales',
        ownerEmail: 'pepe@gmail.com',
        photoUrl: 'https://example.com/foto.jpg',
        requestedBy: 'user_xyz',
        status: 'pending',
        createdAt: now,
      );

      expect(req.id, 'req123');
      expect(req.huecaName, 'Secos Don Pepe');
      expect(req.status, 'pending');

      final map = req.toMap();
      expect(map['huecaName'], 'Secos Don Pepe');
      expect(map['sector'], 'Centro Histórico');
      expect(map['ownerEmail'], 'pepe@gmail.com');
      expect(map['status'], 'pending');
      expect(map['photoUrl'], 'https://example.com/foto.jpg');
    });
  });

  group('SupportMessage Model & Serialization Tests', () {
    test('SupportMessage initializes correctly and generates valid map', () {
      final now = DateTime.now();
      final msg = SupportMessage(
        id: 'msg123',
        huecaId: 'h1',
        huecaName: 'Hornado Doña Rosita',
        senderUid: 'user_rosita',
        senderName: 'Rosita Morales',
        senderEmail: 'rosita@hornado.ec',
        subject: 'Consulta General',
        message: '¿Cómo puedo cambiar la foto de portada de mi local?',
        status: 'new',
        createdAt: now,
      );

      expect(msg.id, 'msg123');
      expect(msg.subject, 'Consulta General');
      expect(msg.status, 'new');

      final map = msg.toMap();
      expect(map['huecaId'], 'h1');
      expect(map['huecaName'], 'Hornado Doña Rosita');
      expect(map['subject'], 'Consulta General');
      expect(map['status'], 'new');
    });
  });

  group('UI Widget Tests for Solicitudes & Soporte', () {
    testWidgets('HuecaRequestScreen renders form fields and submit button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HuecaRequestScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sé Parte de HueQuito'), findsOneWidget);
      expect(find.text('¿Tienes una Hueca?'), findsOneWidget);
      expect(find.text('1. Datos de la Hueca'), findsOneWidget);
      expect(find.text('2. Sazón y Especialidad'), findsOneWidget);
      expect(find.text('3. Contacto del Propietario'), findsOneWidget);
      expect(find.text('Aviso importante sobre tu cuenta:'), findsOneWidget);
      expect(find.text('Enviar Solicitud de Registro'), findsOneWidget);
    });

    testWidgets('AdminSolicitudesScreen renders tabs and search bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allHuecaRequestsProvider.overrideWith((ref) => Stream.value([
                  HuecaRequest(
                    id: 'r1',
                    huecaName: 'La Fritada de Doña Rosa',
                    address: 'Calle Sucre 123',
                    sector: 'Centro Histórico',
                    phone: '0987654321',
                    description: 'Fritada tradicional bien servida',
                    mainDish: 'Fritada completa',
                    ownerName: 'Rosa Martínez',
                    ownerEmail: 'rosa@gmail.com',
                    requestedBy: 'u1',
                    status: 'pending',
                    createdAt: DateTime.now(),
                  ),
                ])),
            pendingHuecaRequestsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: AdminSolicitudesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Solicitudes de Huecas'), findsOneWidget);
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Aprobadas'), findsOneWidget);
      expect(find.text('Rechazadas'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('La Fritada de Doña Rosa'), findsOneWidget);
      expect(find.text('Aprobar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    });

    testWidgets('BusinessSupportScreen renders form and empty history message', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myHuecaSupportMessagesProvider('').overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: BusinessSupportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Contactar al Superadmin'), findsOneWidget);
      expect(find.text('Mesa de Ayuda Directa'), findsOneWidget);
      expect(find.text('Nuevo Mensaje'), findsOneWidget);
      expect(find.text('Asunto o Motivo *'), findsOneWidget);
      expect(find.text('Enviar al Administrador'), findsOneWidget);
    });

    testWidgets('AdminSupportScreen renders tabs, search bar and message cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allSupportMessagesProvider.overrideWith((ref) => Stream.value([
                  SupportMessage(
                    id: 'm1',
                    huecaId: 'h1',
                    huecaName: 'Hornado Doña Rosita',
                    senderUid: 'u2',
                    senderName: 'Rosita Dueña',
                    senderEmail: 'rosita@hornado.ec',
                    subject: 'Problema Técnico en la App',
                    message: 'No puedo ver las fotos de la galería.',
                    status: 'new',
                    createdAt: DateTime.now(),
                  ),
                ])),
            newSupportMessagesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: AdminSupportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bandeja de Soporte a Huecas'), findsOneWidget);
      expect(find.text('Nuevos'), findsOneWidget);
      expect(find.text('Leídos'), findsOneWidget);
      expect(find.text('Respondidos'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Hornado Doña Rosita'), findsOneWidget);
      expect(find.text('Marcar Leído'), findsOneWidget);
      expect(find.text('Responder'), findsOneWidget);
    });
  });
}
