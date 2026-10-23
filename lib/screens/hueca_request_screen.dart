import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hue_quito/theme/theme.dart';
import 'package:hue_quito/providers/data_provider.dart';
import 'package:hue_quito/providers/settings_provider.dart';
import 'package:hue_quito/utils/image_picker_helper.dart';

class HuecaRequestScreen extends ConsumerStatefulWidget {
  const HuecaRequestScreen({super.key});

  @override
  ConsumerState<HuecaRequestScreen> createState() => _HuecaRequestScreenState();
}

class _HuecaRequestScreenState extends ConsumerState<HuecaRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mainDishController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();

  String _selectedSector = 'Centro Histórico';
  File? _selectedImage;
  bool _isSubmitting = false;

  final List<String> _sectors = [
    'Centro Histórico',
    'La Mariscal',
    'La Floresta',
    'Guápulo',
    'Cumbayá',
    'Tumbaco',
    'Villaflora',
    'Chimbacalle',
    'San Antonio / Mitad del Mundo',
    'Calderón',
    'Cotocollao',
    'El Pintado',
    'La Magdalena',
    'Solanda',
    'Chillogallo',
    'Norte',
    'Sur',
    'Valles',
  ];

  @override
  void initState() {
    super.initState();
    // Prefill user data if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider).value;
      if (user != null) {
        if (_ownerNameController.text.isEmpty && user.name.isNotEmpty && user.name != 'Usuario' && user.name != 'Invitado') {
          _ownerNameController.text = user.name;
        }
        if (_ownerEmailController.text.isEmpty && user.email.isNotEmpty && !user.email.contains('invitado')) {
          _ownerEmailController.text = user.email;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _mainDishController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';
    try {
      final file = await ImagePickerHelper.showImageSourceDialog(
        context: context,
        title: isEn ? 'Photo of your Hueca or Dish' : 'Foto de tu Hueca o Plato',
        subtitle: isEn ? 'Choose where to select the photo from' : 'Elige de dónde quieres cargar la foto',
        lang: lang,
        includeRemove: _selectedImage != null,
        onRemove: () => setState(() => _selectedImage = null),
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Could not select image: $e' : 'No se pudo seleccionar la imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Please complete all required fields (*)' : 'Por favor completa todos los campos obligatorios (*)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider).value;
      final userId = user?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';

      String? photoUrl;
      if (_selectedImage != null) {
        photoUrl = await ref
            .read(huecaRequestRepositoryProvider)
            .uploadRequestPhoto(_selectedImage!, userId);
      }

      await ref.read(huecaRequestRepositoryProvider).submitRequest(
            huecaName: _nameController.text.trim(),
            address: _addressController.text.trim(),
            sector: _selectedSector,
            phone: _phoneController.text.trim(),
            description: _descriptionController.text.trim(),
            mainDish: _mainDishController.text.trim(),
            ownerName: _ownerNameController.text.trim(),
            ownerEmail: _ownerEmailController.text.trim(),
            photoUrl: photoUrl,
            requestedBy: userId,
          );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Error submitting request: $e' : 'Error al enviar solicitud: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    final lang = ref.read(settingsProvider).language;
    final isEn = lang == 'en';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEn ? 'Request Received!' : '¡Solicitud Recibida!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn
                  ? 'Thank you for wanting to be part of the HueQuito family!\n\nWe have received the request to register "${_nameController.text.trim()}". Our admin team will verify the details and notify you by email (${_ownerEmailController.text.trim()}) to activate your business account.'
                  : '¡Gracias por querer formar parte de la familia HueQuito!\n\nHemos recibido la solicitud para registrar "${_nameController.text.trim()}". Nuestro equipo administrativo verificará los datos y te notificará a tu correo (${_ownerEmailController.text.trim()}) para habilitar tu cuenta de negocio.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Estimated review time: 24 to 48 business hours.'
                          : 'Tiempo estimado de revisión: 24 a 48 horas laborables.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.green.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Reminder: Registration and your first 50 loyalty stamps are 100% free!'
                          : 'Recuerda: ¡Tu registro y tus primeros 50 sellos de fidelidad son 100% gratuitos!',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            child: Text(isEn ? 'Understood' : 'Entendido', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = ref.watch(settingsProvider).language;
    final isEn = lang == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEn ? 'Join HueQuito' : 'Sé Parte de HueQuito',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: isEn ? 'Back' : 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner
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
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Own a Food Spot?' : '¿Tienes una Hueca?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEn
                                ? 'Register for free and connect your traditional flavors with thousands of locals and tourists.'
                                : 'Regístrala gratis y conecta tu sazón tradicional con miles de quiteños y turistas.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Banner informativo: Gratuidad de inicio y plan escalable
              _buildPricingInfoCard(isDark: isDark, isEn: isEn),

              const SizedBox(height: 8),

              // Sección 1: Datos del Local
              _buildSectionTitle(isEn ? '1. Hueca Information' : '1. Datos de la Hueca', Icons.restaurant),
              const SizedBox(height: 10),

              _buildCardContainer(
                isDark: isDark,
                children: [
                  _buildLabel(isEn ? 'Hueca / Business Name *' : 'Nombre de la Hueca *'),
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      isEn ? 'E.g. Secos de Chivo Don Pepe' : 'Ej. Secos de Chivo Don Pepe',
                      Icons.storefront,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEn ? 'Enter the business name' : 'Ingresa el nombre del local')
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel(isEn ? 'Quito Sector / Area *' : 'Sector de Quito *'),
                  DropdownButtonFormField<String>(
                    value: _selectedSector,
                    isExpanded: true,
                    decoration: _inputDecoration('', Icons.location_on),
                    items: _sectors.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedSector = v);
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildLabel(isEn ? 'Exact address or landmark *' : 'Dirección exacta o referencia *'),
                  TextFormField(
                    controller: _addressController,
                    decoration: _inputDecoration(
                      isEn ? 'E.g. Garcia Moreno N5-42 and Sucre, across from the plaza' : 'Ej. García Moreno N5-42 y Sucre, frente a la plaza',
                      Icons.map_outlined,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEn ? 'Enter address or landmark' : 'Ingresa la dirección o referencia')
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel(isEn ? 'Contact Phone or WhatsApp *' : 'Teléfono o WhatsApp de contacto *'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      isEn ? 'E.g. 0991234567 or (02) 2589-123' : 'Ej. 0991234567 o (02) 2589-123',
                      Icons.phone,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEn ? 'Enter a contact phone number' : 'Ingresa un teléfono de contacto')
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sección 2: Sazón y Especialidad
              _buildSectionTitle(isEn ? '2. Heritage & Specialties' : '2. Sazón y Especialidad', Icons.local_fire_department),
              const SizedBox(height: 10),

              _buildCardContainer(
                isDark: isDark,
                children: [
                  _buildLabel(isEn ? 'Signature Dish / Specialty *' : 'Plato Estrella o Especialidad *'),
                  TextFormField(
                    controller: _mainDishController,
                    decoration: _inputDecoration(
                      isEn ? 'E.g. Traditional Hornado with mote, llapingachos & agrio' : 'Ej. Hornado pastuso con mote, llapingachos y agrio',
                      Icons.restaurant_menu,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEn ? 'Indicate your signature dish' : 'Indica el plato principal de tu hueca')
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel(isEn ? 'Story or Description of the Hueca *' : 'Historia o Descripción de la Hueca *'),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: isEn
                          ? 'Tell us about your tradition, years in business, secret ingredients, or why diners keep coming back...'
                          : 'Cuéntanos un poco sobre tu tradición, años de preparación, ingredientes secretos o por qué los comensales vuelven siempre...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(Icons.description_outlined, color: AppTheme.primary, size: 20),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().length < 10)
                        ? (isEn ? 'Please write at least a brief description (10+ characters)' : 'Por favor escribe al menos una breve descripción (10+ letras)')
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sección 3: Datos del Propietario / Representante
              _buildSectionTitle(isEn ? '3. Owner Contact Information' : '3. Contacto del Propietario', Icons.badge_outlined),
              const SizedBox(height: 10),

              _buildCardContainer(
                isDark: isDark,
                children: [
                  _buildLabel(isEn ? 'Owner or Representative Name *' : 'Nombre del Dueño o Representante *'),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: _inputDecoration(
                      isEn ? 'E.g. Rosa Elena Morales' : 'Ej. Doña Rosa Elena Morales',
                      Icons.person_outline,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (isEn ? 'Enter owner name' : 'Ingresa el nombre del propietario')
                        : null,
                  ),
                  const SizedBox(height: 14),

                  _buildLabel(isEn ? 'Email Address (for your business account) *' : 'Correo Electrónico (para tu cuenta de negocio) *'),
                  TextFormField(
                    controller: _ownerEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      isEn ? 'E.g. business@gmail.com' : 'Ej. negocio@gmail.com',
                      Icons.email_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return isEn ? 'Enter an email address' : 'Ingresa un correo electrónico';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return isEn ? 'Enter a valid email' : 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'Important notice about your account:' : 'Aviso importante sobre tu cuenta:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isEn
                                    ? 'The email entered will be used exclusively to manage your hueca on HueQuito. If you already have a customer/explorer account with this email (via Google or password), once approved that account will transition into your Business Panel and diner history will be reset to focus on managing your spot.'
                                    : 'El correo ingresado será de uso exclusivo para administrar tu hueca en HueQuito. Si ya tienes una cuenta de cliente/explorador con este correo (por Google o contraseña), al ser aprobada tu solicitud esa cuenta pasará a ser tu Panel de Negocio y se reiniciará el historial de comensal para enfocarse en la gestión de tu local.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: isDark ? Colors.white70 : Colors.brown.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sección 4: Foto del Local o Plato (Opcional)
              _buildSectionTitle(isEn ? '4. Photo of the Spot or Dish (Optional)' : '4. Foto del Local o Plato (Opcional)', Icons.camera_alt_outlined),
              const SizedBox(height: 10),

              _buildCardContainer(
                isDark: isDark,
                children: [
                  if (_selectedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: Icon(_selectedImage == null ? Icons.add_a_photo : Icons.replay, size: 20),
                    label: Text(
                      _selectedImage == null
                          ? (isEn ? 'Attach Hueca Photo' : 'Adjuntar Foto de la Hueca')
                          : (isEn ? 'Change Photo' : 'Cambiar Foto'),
                    ),
                    onPressed: _pickImage,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEn
                        ? 'You can attach a photo of your facade, sign, or signature dish for faster verification.'
                        : 'Puedes adjuntar una foto del letrero, del local o de tu plato estrella para verificar más rápido.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Botón de Enviar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isEn ? 'Submitting request...' : 'Enviando solicitud...',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send_rounded, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isEn ? 'Submit Registration Request' : 'Enviar Solicitud de Registro',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint.isNotEmpty ? hint : null,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
      filled: true,
      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildPricingInfoCard({required bool isDark, required bool isEn}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.green.shade800 : Colors.green.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      isEn ? '100% FREE START' : 'COMIENZO 100% GRATIS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                isEn ? 'No registration fee' : 'Sin costo de registro',
                style: TextStyle(
                  color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEn
                ? 'Try HueQuito without upfront costs or risks'
                : 'Prueba HueQuito sin costo inicial ni compromisos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEn
                ? 'We support local gastronomy with a generous free start so you can see real customer growth:'
                : 'Apoyamos la gastronomía local con un generoso inicio gratuito para que compruebes cómo atraes nuevos comensales:',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          _buildPricingBullet(
            icon: Icons.card_giftcard,
            text: isEn
                ? 'First 50 loyalty stamps free: Deliver stamps and points to diners without paying a single cent.'
                : 'Primeros 50 sellos de cortesía: Otorga sellos y puntos de fidelidad sin pagar ni un solo centavo.',
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _buildPricingBullet(
            icon: Icons.verified,
            text: isEn
                ? 'Zero setup cost: Profile review, publishing, and inclusion on Quito routes are 100% free.'
                : 'Cero costos de entrada: La revisión, alta y aparición en el mapa y rutas de Quito son gratis.',
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _buildPricingBullet(
            icon: Icons.savings_outlined,
            text: isEn
                ? 'Accessible subscription after: Only after reaching 50 stamps, a \$9.99/month subscription activates with a 7-day grace period.'
                : 'Suscripción accesible posterior: Solo al alcanzar 50 sellos entregados, se habilitará el plan de \$9.99/mes con 7 días de gracia para continuar.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.blueGrey.shade700 : Colors.green.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildPricingMiniPill(
                    label: isEn ? 'Start' : 'Inicio',
                    value: isEn ? 'Free' : 'Gratis',
                    color: Colors.green,
                  ),
                ),
                Container(height: 22, width: 1, color: Colors.blueGrey.shade200),
                Expanded(
                  child: _buildPricingMiniPill(
                    label: isEn ? 'Courtesy' : 'Cortesía',
                    value: isEn ? '50 stamps' : '50 sellos',
                    color: Colors.teal,
                  ),
                ),
                Container(height: 22, width: 1, color: Colors.blueGrey.shade200),
                Expanded(
                  child: _buildPricingMiniPill(
                    label: isEn ? 'After 50' : 'Luego de 50',
                    value: '\$9.99 / mes',
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingBullet({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white70 : Colors.blueGrey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingMiniPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
