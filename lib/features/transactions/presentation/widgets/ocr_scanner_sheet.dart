import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/ocr_result_model.dart';
import '../../services/ocr_service.dart';

class OcrScannerSheet extends StatefulWidget {
  const OcrScannerSheet({Key? key}) : super(key: key);

  @override
  State<OcrScannerSheet> createState() => _OcrScannerSheetState();
}

class _OcrScannerSheetState extends State<OcrScannerSheet> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  File? _imageFile;
  bool _isScanning = false;
  String _scanStatus = '';
  OcrResultModel? _ocrResult;

  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _ocrService.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _isScanning = true;
        _scanStatus = 'Membaca citra struk...';
        _ocrResult = null;
      });

      // Proses scanning OCR
      final result = await _ocrService.scanReceipt(pickedFile.path);

      setState(() {
        _ocrResult = result;
        _isScanning = false;
        
        // Populate text controller
        _merchantController.text = result.merchantName;
        
        // Format nominal ke ribuan rupiah
        final doubleVal = result.amount;
        if (doubleVal > 0) {
          final cleanString = doubleVal.toInt().toString();
          // Gunakan formatter lokal
          final formatted = IndonesianCurrencyInputFormatter().formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: cleanString),
          ).text;
          _amountController.text = formatted;
        } else {
          _amountController.text = '';
        }
        
        _selectedDate = result.date;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanStatus = 'Pemindaian gagal: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membaca struk: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _selectedDate.hour,
            _selectedDate.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
        padding: EdgeInsets.only(bottom: keyboardPadding),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _ocrResult == null ? 'Pindai Struk Belanja' : 'Verifikasi Hasil Pemindaian',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                _ocrResult == null
                    ? 'Ambil foto struk belanja untuk mencatat nominal dan tanggal secara otomatis'
                    : 'Silakan periksa kembali hasil ekstraksi teks di bawah ini sebelum menyimpan',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),

              // ── KONDISI 1: Belum Memilih Gambar ──
              if (_imageFile == null && !_isScanning) ...[
                _buildSourceSelector(),
              ],

              // ── KONDISI 2: Sedang Scanning / Loading ──
              if (_isScanning) ...[
                _buildScanningPreview(),
              ],

              // ── KONDISI 3: Hasil OCR Siap Diverifikasi ──
              if (_ocrResult != null && !_isScanning) ...[
                _buildVerificationForm(),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildSelectorButton(
            icon: LucideIcons.camera,
            title: 'Kamera',
            subtitle: 'Foto Struk Fisik',
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSelectorButton(
            icon: LucideIcons.image,
            title: 'Galeri',
            subtitle: 'Pilih dari Album',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0, duration: 350.ms);
  }

  Widget _buildSelectorButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningPreview() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Preview image with scanning overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 140,
                height: 180,
                color: AppColors.surfaceAlt,
                child: _imageFile != null
                    ? Image.file(_imageFile!, fit: BoxFit.cover)
                    : const Icon(LucideIcons.receipt, size: 40, color: AppColors.textMuted),
              ),
            ),
            
            // Scanning laser effect anim
            Container(
              width: 140,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 0.5, 1.0],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .slideY(begin: -0.8, end: 0.8, duration: 1.5.seconds, curve: Curves.easeInOut),
          ],
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          _scanStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildVerificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              CustomTextField(
                label: 'NAMA MERCHANT / TOKO',
                controller: _merchantController,
                hintText: 'Masukkan nama toko...',
                prefixIcon: LucideIcons.store,
              ),
              const SizedBox(height: 16),
              
              CustomTextField(
                label: 'TOTAL NOMINAL',
                controller: _amountController,
                hintText: 'Rp 0',
                prefixIcon: LucideIcons.coins,
                keyboardType: TextInputType.number,
                inputFormatters: [IndonesianCurrencyInputFormatter()],
              ),
              const SizedBox(height: 16),

              // Date Picker row
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TANGGAL & WAKTU STRUK',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.formatDateTime(_selectedDate),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronDown, color: AppColors.textMuted, size: 16),
                    ],
                  ),
                ),
              ),

              // Category Suggestion badge if any
              if (_ocrResult?.suggestedCategoryName != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.tag, color: AppColors.primary, size: 14),
                        const SizedBox(width: 8),
                        const Text(
                          'Rekomendasi Kategori: ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text(
                        _ocrResult!.suggestedCategoryName!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: '',
                icon: LucideIcons.camera,
                isOutlined: true,
                onPressed: () {
                  setState(() {
                    _imageFile = null;
                    _ocrResult = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: CustomButton(
                text: 'Gunakan Data',
                icon: LucideIcons.checkCircle2,
                onPressed: () {
                  final rawAmountText = _amountController.text.replaceAll('.', '');
                  final amount = double.tryParse(rawAmountText) ?? 0.0;
                  
                  Navigator.pop(context, {
                    'result': OcrResultModel(
                      merchantName: _merchantController.text.trim(),
                      amount: amount,
                      date: _selectedDate,
                      suggestedCategoryName: _ocrResult?.suggestedCategoryName,
                    ),
                    'imagePath': _imageFile!.path,
                  });
                },
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}
