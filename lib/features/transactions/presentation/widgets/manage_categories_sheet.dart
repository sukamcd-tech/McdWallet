import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/category_model.dart';
import '../../providers/transactions_provider.dart';

class ManageCategoriesBottomSheet extends ConsumerStatefulWidget {
  final String initialType; // 'expense' or 'income'

  const ManageCategoriesBottomSheet({
    Key? key,
    this.initialType = 'expense',
  }) : super(key: key);

  @override
  ConsumerState<ManageCategoriesBottomSheet> createState() => _ManageCategoriesBottomSheetState();
}

class _ManageCategoriesBottomSheetState extends ConsumerState<ManageCategoriesBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isFormMode = false;
  CategoryModel? _editingCategory;
  late String _currentType;
  
  String _selectedColor = '#FF9500'; // Default Orange
  String _selectedIcon = 'tag'; // Default Tag
  bool _isSaving = false;

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
    'utensils': LucideIcons.utensils,
    'shoppingBag': LucideIcons.shoppingBag,
    'car': LucideIcons.car,
    'zap': LucideIcons.zap,
    'wallet': LucideIcons.wallet,
    'activity': LucideIcons.activity,
    'graduationCap': LucideIcons.graduationCap,
    'gift': LucideIcons.gift,
    'tag': LucideIcons.tag,
  };

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _getIconData(String name) {
    return _icons[name] ?? LucideIcons.tag;
  }

  void _enterFormMode(CategoryModel? category) {
    setState(() {
      _isFormMode = true;
      _editingCategory = category;
      if (category != null) {
        _nameController.text = category.name;
        _selectedColor = category.color;
        _selectedIcon = category.icon;
        _currentType = category.type;
      } else {
        _nameController.clear();
        _selectedColor = '#FF9500';
        _selectedIcon = 'tag';
      }
    });
  }

  void _exitFormMode() {
    setState(() {
      _isFormMode = false;
      _editingCategory = null;
      _nameController.clear();
    });
  }

  Future<void> _handleSaveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (_editingCategory == null) {
        // Create new category
        final newCategory = CategoryModel(
          id: '',
          userId: user.id,
          name: _nameController.text.trim(),
          type: _currentType,
          color: _selectedColor,
          icon: _selectedIcon,
          createdAt: DateTime.now(),
        );
        await ref.read(categoriesProvider.notifier).addCategory(newCategory);
      } else {
        // Update existing category
        final updatedCategory = _editingCategory!.copyWith(
          name: _nameController.text.trim(),
          type: _currentType,
          color: _selectedColor,
          icon: _selectedIcon,
        );
        await ref.read(categoriesProvider.notifier).updateCategory(updatedCategory.id, updatedCategory);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingCategory == null ? 'Kategori berhasil dibuat!' : 'Kategori berhasil diperbarui!'),
            backgroundColor: AppColors.success,
          ),
        );
        _exitFormMode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan kategori: $e'),
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

  Future<void> _handleDeleteCategory(CategoryModel category) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hapus Kategori?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Apakah Anda yakin ingin menghapus kategori "${category.name}"?\nKategori yang terikat transaksi aktif tidak bisa dihapus.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Hapus Kategori',
              color: AppColors.danger,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Batal',
              isOutlined: true,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(categoriesProvider.notifier).removeCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kategori "${category.name}" berhasil dihapus.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menghapus: Kategori ini sedang digunakan oleh transaksi atau anggaran Anda.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isFormMode ? _buildFormView() : _buildListView(categoriesAsync),
        ),
      ),
    );
  }

  Widget _buildListView(AsyncValue<List<CategoryModel>> categoriesAsync) {
    return Column(
      key: const ValueKey('list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kelola Kategori',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        const SizedBox(height: 16),

        // Type Selector Segmented Toggle
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
              final isExpense = _currentType == 'expense';

              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    left: isExpense ? 0 : tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentType = 'expense'),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                color: isExpense ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                              child: const Text('Pengeluaran'),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentType = 'income'),
                          behavior: HitTestBehavior.opaque,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                color: !isExpense ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                              child: const Text('Pemasukan'),
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

        // List categories
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Center(child: Text('Gagal memuat kategori: $err')),
            data: (categories) {
              final filtered = categories.where((c) => c.type == _currentType).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.tag, size: 48, color: AppColors.secondary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada kategori.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1.0),
                itemBuilder: (context, index) {
                  final cat = filtered[index];
                  final catColor = Color(int.parse(cat.color.replaceAll('#', '0xFF')));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: catColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getIconData(cat.icon),
                                color: catColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              cat.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.pencil, color: AppColors.textSecondary, size: 18),
                              onPressed: () => _enterFormMode(cat),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, color: AppColors.danger, size: 18),
                              onPressed: () => _handleDeleteCategory(cat),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Add New Button
        CustomButton(
          text: 'Tambah Kategori Baru',
          onPressed: () => _enterFormMode(null),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildFormView() {
    final title = _editingCategory == null ? 'Tambah Kategori' : 'Edit Kategori';

    return SingleChildScrollView(
      key: const ValueKey('form'),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary, size: 20),
                  onPressed: _exitFormMode,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Name Input
            CustomTextField(
              controller: _nameController,
              label: 'NAMA KATEGORI',
              hintText: 'Contoh: Makanan & Minuman, Pajak, Gaji',
              prefixIcon: LucideIcons.tag,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama kategori tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Segmented Type Selector inside Form
            const Text(
              'TIPE TRANSAKSI',
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
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentType = 'expense'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentType == 'expense' ? AppColors.expense.withOpacity(0.08) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentType == 'expense' ? AppColors.expense : AppColors.border,
                          width: _currentType == 'expense' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.arrowUpRight,
                            size: 14,
                            color: _currentType == 'expense' ? AppColors.expense : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pengeluaran',
                            style: TextStyle(
                              color: _currentType == 'expense' ? AppColors.expense : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentType = 'income'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _currentType == 'income' ? AppColors.income.withOpacity(0.08) : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentType == 'income' ? AppColors.income : AppColors.border,
                          width: _currentType == 'income' ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.arrowDownLeft,
                            size: 14,
                            color: _currentType == 'income' ? AppColors.income : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pemasukan',
                            style: TextStyle(
                              color: _currentType == 'income' ? AppColors.income : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Color selector
            const Text('AKSEN WARNA KATEGORI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

            // Icon selector
            const Text('IKON KATEGORI', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

            // Save Button
            CustomButton(
              text: _editingCategory == null ? 'Buat Kategori' : 'Simpan Perubahan',
              isLoading: _isSaving,
              onPressed: _handleSaveCategory,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
