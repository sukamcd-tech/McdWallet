import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/utils/haptics.dart';

class UpgradeSuccessScreen extends StatefulWidget {
  const UpgradeSuccessScreen({Key? key}) : super(key: key);

  @override
  State<UpgradeSuccessScreen> createState() => _UpgradeSuccessScreenState();
}

class _UpgradeSuccessScreenState extends State<UpgradeSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    AppHaptics.vibrate();
    
    // Inisialisasi controller untuk partikel konfeti
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        _updateParticles();
      });

    _generateParticles();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _generateParticles() {
    for (int i = 0; i < 80; i++) {
      _particles.add(
        _ConfettiParticle(
          x: _random.nextDouble() * 400,
          y: -_random.nextDouble() * 200,
          size: _random.nextDouble() * 8 + 4,
          color: [
            const Color(0xFFF1C40F), // Emas
            const Color(0xFFF39C12), // Oranye Emas
            const Color(0xFF34C759), // Hijau Sukses
            const Color(0xFF30D158), // Hijau Muda
            const Color(0xFF0A84FF), // Biru
            const Color(0xFFBF5AF2), // Ungu
          ][_random.nextInt(6)],
          speedY: _random.nextDouble() * 3 + 2,
          speedX: _random.nextDouble() * 2 - 1,
          rotation: _random.nextDouble() * 360,
          rotationSpeed: _random.nextDouble() * 5 - 2.5,
        ),
      );
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (var particle in _particles) {
        particle.y += particle.speedY;
        particle.x += particle.speedX;
        particle.rotation += particle.rotationSpeed;
        
        // Loop partikel jika keluar layar bawah
        if (particle.y > MediaQuery.of(context).size.height) {
          particle.y = -20;
          particle.x = _random.nextDouble() * MediaQuery.of(context).size.width;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Off-white
      body: Stack(
        children: [
          // ── CONFETTI PARTICLES LAYER ──
          CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(particles: _particles),
          ),

          // ── CONTENT LAYER ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ── GLOWING GOLD CHECKMARK ──
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34C759), Color(0xFF30D158)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF34C759).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        color: Colors.white,
                        size: 48,
                      ),
                    )
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.easeOutBack)
                    .then()
                    .shake(duration: 300.ms),
                  ),

                  const SizedBox(height: 32),

                  // ── CONGRATS TITLES ──
                  const Text(
                    'Pembayaran Sukses!',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 8),

                  const Text(
                    'Akun Anda telah ditingkatkan menjadi McdWallet Bisnis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 36),

                  // ── FEATURE SUMMARY LIST ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface, // Putih
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FITUR PRO YANG SEKARANG AKTIF:',
                          style: TextStyle(
                            color: AppColors.primary, // Charcoal
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildActiveFeatureRow('Kolaborasi Dompet Bersama Aktif'),
                        _buildActiveFeatureRow('Pemisahan Kas Bisnis vs. Personal Terbuka'),
                        _buildActiveFeatureRow('Ekspor PDF Laba Rugi & Excel Ledger Terbuka'),
                        _buildActiveFeatureRow('Dukungan Multi-Mata Uang (Valas) Terbuka'),
                        _buildActiveFeatureRow('Pembuat Invoice & Resi Digital Aktif'),
                        _buildActiveFeatureRow('Asisten AI Mode Bisnis Terbuka'),
                      ],
                    ),
                  ).animate().fadeIn(delay: 450.ms, duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),

                  const Spacer(),

                  // ── DISMISS BUTTON ──
                  CustomButton(
                    text: 'Mulai Nikmati Fitur Pro',
                    color: AppColors.primary, // Sleek charcoal
                    textColor: Colors.white,
                    onPressed: () {
                      AppHaptics.mediumImpact();
                      Navigator.pop(context); // Kembali ke ProfileScreen
                    },
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle2, color: Color(0xFF34C759), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PARTIKEL KONFETI ──
class _ConfettiParticle {
  double x;
  double y;
  final double size;
  final Color color;
  final double speedY;
  final double speedX;
  double rotation;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speedY,
    required this.speedX,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      paint.color = particle.color;
      canvas.save();
      
      // Geser canvas ke partikel
      canvas.translate(particle.x, particle.y);
      canvas.rotate(particle.rotation * pi / 180);
      
      // Gambar bentuk persegi kecil konfeti
      final rect = Rect.fromLTWH(-particle.size / 2, -particle.size / 2, particle.size, particle.size / 2);
      canvas.drawRect(rect, paint);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
