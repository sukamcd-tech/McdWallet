import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/savings_goal_model.dart';
import '../../providers/savings_provider.dart';

class AddSavingsGoalBottomSheet extends ConsumerStatefulWidget {
  const AddSavingsGoalBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<AddSavingsGoalBottomSheet> createState() => _AddSavingsGoalBottomSheetState();
}

class _AddSavingsGoalBottomSheetState extends ConsumerState<AddSavingsGoalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _allocationController = TextEditingController();
  
  DateTime? _targetDate;
  String _selectedColor = '#FF9500'; // Orange default
  String _selectedIcon = 'piggyBank'; // Piggy bank default
  bool _isSaving = false;

  bool _useAllocationPlan = false;
  String _selectedInterval = 'daily';

  @override
  void initState() {
    super.initState();
    _targetController.addListener(_onFieldChanged);
    _allocationController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  final List<String> _colors = const [
    '#FF9500', // Orange
    '#FF2D55', // Pink
    '#5856D6', // Indigo
    '#007AFF', // Blue
    '#34C759', // Green
    '#FFCC00', // Yellow
    '#AF52DE', // Purple
    '#8E8E93', // Gray
  ];

  final Map<String, IconData> _icons = const {
    'piggyBank': LucideIcons.wallet,
    'home': LucideIcons.home,
    'car': LucideIcons.car,
    'plane': LucideIcons.plane,
    'laptop': LucideIcons.laptop,
    'gift': LucideIcons.gift,
    'smartphone': LucideIcons.smartphone,
    'gamepad': LucideIcons.gamepad2,
    'shopping': LucideIcons.shoppingBag,
    'trending': LucideIcons.trendingUp,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _allocationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)), // 10 years max
    );
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  Future<void> _handleSaveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    final targetStr = _targetController.text.replaceAll('.', '');
    final targetAmount = double.parse(targetStr);

    String savingInterval = 'custom';
    double savingAmountPerInterval = 0.0;
    DateTime? targetDate = _targetDate;

    if (_useAllocationPlan) {
      savingInterval = _selectedInterval;
      final allocStr = _allocationController.text.replaceAll('.', '');
      savingAmountPerInterval = double.parse(allocStr);

      final intervals = (targetAmount / savingAmountPerInterval).ceil();
      final now = DateTime.now();
      if (savingInterval == 'daily') {
        targetDate = now.add(Duration(days: intervals));
      } else if (savingInterval == 'weekly') {
        targetDate = now.add(Duration(days: intervals * 7));
      } else if (savingInterval == 'monthly') {
        targetDate = DateTime(now.year, now.month + intervals, now.day);
      }
    }

    try {
      final newGoal = SavingsGoalModel(
        id: '', // Di-generate oleh database / provider
        userId: user.id,
        name: _nameController.text.trim(),
        targetAmount: targetAmount,
        currentAmount: 0.0,
        targetDate: targetDate,
        color: _selectedColor,
        icon: _selectedIcon,
        savingInterval: savingInterval,
        savingAmountPerInterval: savingAmountPerInterval,
        createdAt: DateTime.now(),
      );

      await ref.read(savingsProvider.notifier).addSavingsGoal(newGoal);

      if (mounted) {
        Navigator.pop(context); // Tutup bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Target tabungan baru berhasil dibuat!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat target tabungan: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Buat Target Tabungan',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 24),

                // NAMA TARGET
                CustomTextField(
                  controller: _nameController,
                  label: 'NAMA TABUNGAN / IMPIAN',
                  hintText: 'Contoh: Pembelian laptop baru, liburan ke Bali',
                  prefixIcon: LucideIcons.award,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama impian tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // TARGET NOMINAL
                CustomTextField(
                  controller: _targetController,
                  label: 'NOMINAL TARGET TABUNGAN',
                  hintText: 'Masukkan nominal target rupiah, contoh: 5.000.000',
                  prefixIcon: LucideIcons.target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    IndonesianCurrencyInputFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nominal target tidak boleh kosong';
                    }
                    final cleanValue = value.replaceAll('.', '');
                    final numVal = double.tryParse(cleanValue);
                    if (numVal == null || numVal <= 0) {
                      return 'Masukkan nominal target yang valid (> 0)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // METODE SELECTION (Segmented toggle)
                const Text(
                  'METODE TARGET TABUNGAN',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = constraints.maxWidth / 2;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.fastOutSlowIn,
                            left: _useAllocationPlan ? tabWidth : 0,
                            top: 0,
                            bottom: 0,
                            width: tabWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _useAllocationPlan = false),
                                  behavior: HitTestBehavior.opaque,
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 150),
                                      style: TextStyle(
                                        color: !_useAllocationPlan ? Colors.white : AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        fontFamily: 'Outfit',
                                      ),
                                      child: const Text('Target Waktu'),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _useAllocationPlan = true),
                                  behavior: HitTestBehavior.opaque,
                                  child: Center(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 150),
                                      style: TextStyle(
                                        color: _useAllocationPlan ? Colors.white : AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        fontFamily: 'Outfit',
                                      ),
                                      child: const Text('Alokasi Rutin'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                if (_useAllocationPlan) ...[
                  // Pemilih Frekuensi (Harian, Mingguan, Bulanan)
                  const Text(
                    'FREKUENSI ALOKASI',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildIntervalChip('daily', 'Harian', LucideIcons.calendarDays),
                      const SizedBox(width: 8),
                      _buildIntervalChip('weekly', 'Mingguan', LucideIcons.calendarRange),
                      const SizedBox(width: 8),
                      _buildIntervalChip('monthly', 'Bulanan', LucideIcons.calendarDays),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Input Nominal Alokasi
                  CustomTextField(
                    controller: _allocationController,
                    label: 'NOMINAL ALOKASI PER PERIODE',
                    hintText: 'Masukkan jumlah tabungan rutin, contoh: 50.000',
                    prefixIcon: LucideIcons.coins,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      IndonesianCurrencyInputFormatter(),
                    ],
                    validator: (value) {
                      if (_useAllocationPlan) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nominal alokasi tidak boleh kosong';
                        }
                        final cleanValue = value.replaceAll('.', '');
                        final numVal = double.tryParse(cleanValue);
                        if (numVal == null || numVal <= 0) {
                          return 'Masukkan nominal alokasi yang valid (> 0)';
                        }
                        final targetStr = _targetController.text.replaceAll('.', '');
                        final targetAmount = double.tryParse(targetStr) ?? 0.0;
                        if (numVal > targetAmount) {
                          return 'Alokasi tidak boleh melebihi total target';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // TARGET SELESAI (DATE PICKER)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TANGGAL TARGET PENCAPAIAN (OPSIONAL)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _targetDate != null 
                                    ? Formatters.formatDateShort(_targetDate!) 
                                    : 'Pilih tanggal target pencapaian', 
                                style: TextStyle(
                                  color: _targetDate != null ? AppColors.textPrimary : AppColors.textMuted, 
                                  fontSize: 14
                                )
                              ),
                              const Icon(LucideIcons.calendar, size: 18, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // KARTU KALKULATOR DINAMIS
                if (_useAllocationPlan) ...[
                  Builder(
                    builder: (context) {
                      final targetStr = _targetController.text.replaceAll('.', '');
                      final targetAmount = double.tryParse(targetStr) ?? 0.0;
                      final allocStr = _allocationController.text.replaceAll('.', '');
                      final allocAmount = double.tryParse(allocStr) ?? 0.0;

                      if (targetAmount > 0 && allocAmount > 0) {
                        final intervals = (targetAmount / allocAmount).ceil();
                        final now = DateTime.now();
                        DateTime estDate = now;
                        String durationLabel = '';

                        if (_selectedInterval == 'daily') {
                          estDate = now.add(Duration(days: intervals));
                          durationLabel = '$intervals Hari';
                        } else if (_selectedInterval == 'weekly') {
                          estDate = now.add(Duration(days: intervals * 7));
                          durationLabel = '$intervals Minggu';
                        } else if (_selectedInterval == 'monthly') {
                          estDate = DateTime(now.year, now.month + intervals, now.day);
                          durationLabel = '$intervals Bulan';
                        }

                        final formattedEstDate = Formatters.formatDate(estDate);

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(LucideIcons.calculator, size: 16, color: AppColors.textSecondary),
                                  SizedBox(width: 8),
                                  Text(
                                    'ESTIMASI RENCANA TABUNGAN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Durasi Terkumpul:',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    durationLabel,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Estimasi Target Selesai:',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    formattedEstDate,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // PEMILIH WARNA
                const Text('PILIH AKSEN WARNA', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final hex = _colors[index];
                      final color = Color(int.parse(hex.replaceAll('#', '0xFF')));
                      final isSelected = _selectedColor == hex;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected 
                                ? Border.all(color: AppColors.primary, width: 3) 
                                : Border.all(color: Colors.transparent),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ] : null,
                          ),
                          child: isSelected 
                              ? const Icon(LucideIcons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // PEMILIH IKON
                const Text('PILIH IKON', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _icons.keys.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final key = _icons.keys.elementAt(index);
                      final iconData = _icons[key]!;
                      final isSelected = _selectedIcon == key;
                      final accentColor = Color(int.parse(_selectedColor.replaceAll('#', '0xFF')));

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = key),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? accentColor.withOpacity(0.12) : AppColors.surfaceAlt.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? accentColor : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Icon(
                            iconData, 
                            color: isSelected ? accentColor : AppColors.textSecondary, 
                            size: 18
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // TOMBOL SIMPAN
                CustomButton(
                  text: 'Buat Target Tabungan',
                  isLoading: _isSaving,
                  onPressed: _handleSaveGoal,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalChip(String value, String label, IconData icon) {
    final isSelected = _selectedInterval == value;
    final accentColor = Color(int.parse(_selectedColor.replaceAll('#', '0xFF')));
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedInterval = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? accentColor : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? accentColor : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
