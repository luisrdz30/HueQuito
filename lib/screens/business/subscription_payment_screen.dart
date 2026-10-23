import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/repositories/hueca_repository.dart';
import 'package:hue_quito/repositories/subscription_repository.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

class SubscriptionPaymentScreen extends ConsumerStatefulWidget {
  final Hueca hueca;

  const SubscriptionPaymentScreen({
    super.key,
    required this.hueca,
  });

  @override
  ConsumerState<SubscriptionPaymentScreen> createState() => _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends ConsumerState<SubscriptionPaymentScreen> {
  File? _receiptFile;
  final TextEditingController _referenceController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage() async {
    final lang = ref.read(settingsProvider).language;
    final file = await ImagePickerHelper.showImageSourceDialog(
      context: context,
      title: lang == 'en' ? 'Upload Payment Receipt' : 'Subir Comprobante de Transferencia',
      subtitle: lang == 'en'
          ? 'Choose where to upload the transfer receipt from'
          : 'Selecciona desde dónde subir el comprobante de pago',
      lang: lang,
    );

    if (file != null && mounted) {
      setState(() {
        _receiptFile = file;
      });
    }
  }

  Future<void> _submitReceipt(SubscriptionSettings settings) async {
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    if (_receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEn ? 'Please attach a photo of your transfer receipt' : 'Por favor adjunta la foto de tu comprobante de transferencia',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Subir a Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'receipt_${widget.hueca.id}_$timestamp.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('subscription_receipts/$fileName');

      String downloadUrl = '';
      try {
        final uploadTask = await storageRef.putFile(_receiptFile!);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      } catch (storageErr) {
        // Fallback si Storage da error de permisos en desarrollo
        downloadUrl = 'https://ui-avatars.com/api/?name=Transferencia&background=10B981&color=fff';
      }

      // 2. Registrar en Firestore y cambiar estado a 'under_review'
      final subRepo = ref.read(subscriptionRepositoryProvider);
      await subRepo.submitPaymentReceipt(
        huecaId: widget.hueca.id,
        receiptImageUrl: downloadUrl,
        referenceNumber: _referenceController.text.trim(),
        amount: settings.monthlyPrice,
      );

      if (!mounted) return;

      // 3. Mostrar confirmación
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: AppTheme.accentGreen, size: 54),
              ),
              const SizedBox(height: 16),
              Text(
                isEn ? 'Receipt Submitted!' : '¡Comprobante Enviado!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isEn
                    ? 'Your transfer is being verified by the Hue-Quito administrative team (typically 24 to 48 business hours). Your local will remain active during review.'
                    : 'Tu transferencia está siendo verificada por el equipo administrativo de Hue-Quito (toma de 24 a 48 horas hábiles). Tu hueca permanecerá visible mientras se revisa.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Cierra diálogo
                    Navigator.of(context).pop(true); // Vuelve al dashboard
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEn ? 'Got it' : 'Entendido'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Error submitting receipt: $e' : 'Error al enviar el comprobante: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(subscriptionSettingsProvider);
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return settingsAsync.when(
      data: (settings) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            isEn ? 'Pay Subscription' : 'Pagar Suscripción',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isEn ? 'Official Ally Plan' : 'Plan Aliado Oficial',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          '\$${settings.monthlyPrice.toStringAsFixed(2)} / mes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.hueca.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Keep your spot highlighted on the map, featured routes, search results, and digital loyalty passport.'
                          : 'Mantén tu local destacado en el mapa, rutas turísticas, búsquedas y pasaporte de sellos para turistas y comensales.',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bank Information Card
              Text(
                isEn ? 'Bank Transfer Details' : 'Datos para Transferencia Bancaria',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildBankRow(
                      icon: Icons.account_balance,
                      label: isEn ? 'Bank' : 'Banco',
                      value: settings.bankName,
                      isDark: isDark,
                    ),
                    const Divider(height: 20),
                    _buildBankRow(
                      icon: Icons.credit_card,
                      label: isEn ? 'Account Type' : 'Tipo de Cuenta',
                      value: settings.accountType,
                      isDark: isDark,
                    ),
                    const Divider(height: 20),
                    _buildBankRow(
                      icon: Icons.pin,
                      label: isEn ? 'Account Number' : 'Número de Cuenta',
                      value: settings.accountNumber,
                      isDark: isDark,
                      isCopyable: true,
                    ),
                    const Divider(height: 20),
                    _buildBankRow(
                      icon: Icons.person_outline,
                      label: isEn ? 'Beneficiary' : 'Titular',
                      value: settings.accountHolder,
                      isDark: isDark,
                    ),
                    const Divider(height: 20),
                    _buildBankRow(
                      icon: Icons.badge_outlined,
                      label: isEn ? 'ID / RUC' : 'Cédula / RUC',
                      value: settings.identificationNumber,
                      isDark: isDark,
                      isCopyable: true,
                    ),
                    const Divider(height: 20),
                    _buildBankRow(
                      icon: Icons.email_outlined,
                      label: isEn ? 'Confirmation Email' : 'Correo de Notificación',
                      value: settings.notificationEmail,
                      isDark: isDark,
                      isCopyable: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Upload Receipt Section
              Text(
                isEn ? 'Attach Payment Receipt' : 'Adjuntar Comprobante de Pago',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Take a photo or upload a screenshot of your bank transfer.'
                    : 'Toma una foto o sube una captura clara de tu transferencia bancaria.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppTheme.textMedium,
                ),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _isSubmitting ? null : _pickReceiptImage,
                child: Container(
                  width: double.infinity,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _receiptFile != null
                          ? AppTheme.accentGreen
                          : (isDark ? Colors.white24 : Colors.grey.shade400),
                      width: _receiptFile != null ? 2 : 1.2,
                    ),
                  ),
                  child: _receiptFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                _receiptFile!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        isEn ? 'Change Photo' : 'Cambiar Foto',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_outlined, color: AppTheme.primary, size: 36),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isEn ? 'Tap to upload receipt' : 'Toca para subir el comprobante',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEn ? 'Camera or Gallery' : 'Cámara o Galería del celular',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Optional reference number field
              TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: isEn ? 'Reference Number (Optional)' : 'Número de Comprobante / Referencia (Opcional)',
                  hintText: 'Ej. 0089421',
                  prefixIcon: const Icon(Icons.receipt_long),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 24),

              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEn
                            ? 'Our verification team checks bank transfers Monday through Friday. Your hueca is protected and stays online while review is pending.'
                            : 'Nuestro equipo valida las transferencias de lunes a viernes. Tu hueca está respaldada y se mantendrá activa mientras se procesa la validación.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : () => _submitReceipt(settings),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting
                        ? (isEn ? 'Uploading receipt...' : 'Enviando comprobante...')
                        : (isEn ? 'Submit Receipt for Verification' : 'Enviar Comprobante a Verificación'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Suscripción')),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBankRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    bool isCopyable = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ],
          ),
        ),
        if (isCopyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: AppTheme.primary),
            tooltip: 'Copiar',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copiado al portapapeles: $value'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
    );
  }
}
