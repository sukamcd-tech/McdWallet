import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/config.dart';
import '../domain/category_model.dart';

class AiCategoryService {
  /// Memprediksi kategori transaksi yang paling cocok berdasarkan deskripsi
  /// Menggunakan metode Hybrid: Pencocokan Regex Lokal terlebih dahulu,
  /// jika tidak ditemukan, memanggil Groq Cloud API.
  Future<CategoryModel?> predictCategory({
    required String description,
    required List<CategoryModel> availableCategories,
    required String transactionType,
  }) async {
    final cleanDesc = description.trim();
    if (cleanDesc.isEmpty || availableCategories.isEmpty) {
      return null;
    }

    debugPrint('AI Category Service: Memulai prediksi untuk "$cleanDesc" ($transactionType)');

    // ── 1. Pencocokan Lokal (Fast & Offline) ──
    try {
      final String? localMatchName = _predictCategoryLocal(cleanDesc, availableCategories);
      if (localMatchName != null) {
        final matchedCategory = _findCategoryByName(localMatchName, availableCategories);
        if (matchedCategory != null) {
          debugPrint('AI Category Service: Berhasil dicocokkan secara LOKAL -> ${matchedCategory.name}');
          return matchedCategory;
        }
      }
    } catch (e) {
      debugPrint('AI Category Service: Kesalahan pada pencocokan lokal: $e');
    }

    // ── 2. Panggilan Groq API (Fallback Online) ──
    if (AppConfig.groqApiKey.isEmpty) {
      debugPrint('AI Category Service: Groq API Key kosong, membatalkan panggilan API.');
      return null;
    }

    try {
      final String? apiMatchName = await _predictWithGroq(
        description: cleanDesc,
        availableCategories: availableCategories,
        transactionType: transactionType,
      );

      if (apiMatchName != null) {
        final matchedCategory = _findCategoryByName(apiMatchName, availableCategories);
        if (matchedCategory != null) {
          debugPrint('AI Category Service: Berhasil dicocokkan via GROQ API -> ${matchedCategory.name}');
          return matchedCategory;
        }
      }
    } catch (e) {
      debugPrint('AI Category Service: Panggilan Groq API gagal: $e');
    }

    return null;
  }

  /// Membantu mencocokkan nama kategori (case-insensitive & toleran terhadap substring)
  CategoryModel? _findCategoryByName(String name, List<CategoryModel> categories) {
    final search = name.toLowerCase().trim();
    
    // Cocokkan persis
    try {
      return categories.firstWhere(
        (c) => c.name.toLowerCase().trim() == search,
      );
    } catch (_) {}

    // Cocokkan sebagian (contains)
    try {
      return categories.firstWhere(
        (c) => c.name.toLowerCase().contains(search) || search.contains(c.name.toLowerCase()),
      );
    } catch (_) {}

    return null;
  }

  /// Pencocokan cepat dengan Regex lokal
  String? _predictCategoryLocal(String description, List<CategoryModel> categories) {
    final desc = description.toLowerCase();

    // A. Cek kecocokan langsung dengan nama kategori
    for (final cat in categories) {
      final catName = cat.name.toLowerCase().trim();
      if (catName.length > 3 && !catName.contains('lain')) {
        if (desc.contains(catName)) {
          return cat.name;
        }
      }
    }

    // B. Pustaka kata kunci umum bahasa Indonesia & Inggris
    final keywordMapping = <String, List<String>>{
      'Makanan & Minuman': [
        'makan', 'minum', 'resto', 'cafe', 'kopi', 'warung', 'bakso', 'mie', 'nasi', 
        'food', 'beverage', 'kuliner', 'dinner', 'breakfast', 'lunch', 'jajan', 
        'snack', 'gofood', 'grabfood', 'shopeefood', 'kfc', 'mcd', 'starbucks', 'momoyo', 'sate',
        'martabak', 'teh', 'boba', 'jus', 'roti', 'donat', 'kantin', 'catering'
      ],
      'Transportasi': [
        'bensin', 'pertamina', 'shell', 'spbu', 'grab', 'gojek', 'go-jek', 'ojek', 
        'taksi', 'taxi', 'parkir', 'tol', 'kereta', 'krl', 'mrt', 'lrt', 'bus', 
        'tiket pesawat', 'travel', 'ojol', 'angkut', 'go-ride', 'grabcar', 'gocar'
      ],
      'Belanja & Hiburan': [
        'belanja', 'indomaret', 'alfamart', 'alfamidi', 'supermarket', 'hypermart', 
        'transmart', 'mall', 'tokopedia', 'shopee', 'lazada', 'baju', 'celana', 
        'sepatu', 'kaos', 'grocery', 'pasar', 'minimarket', 'watsons', 'guardian', 
        'wardah', 'makeup', 'skincare', 'jaket', 'tas', 'aksesoris',
        'hiburan', 'nonton', 'bioskop', 'cinema', 'xxi', 'cgv', 'game', 'topup game', 
        'karaoke', 'rekreasi', 'liburan', 'wisata', 'healing', 'traveling', 'tiket masuk',
        'dufan', 'pantai', 'hotel', 'staycation', 'konser', 'playstation'
      ],
      'WiFi & Internet': [
        'wifi', 'internet', 'indihome', 'biznet', 'speedy', 'pulsa', 'kuota', 'telkom', 'token'
      ],
      'Kos & Rumah': [
        'kosan', 'kontrakan', 'iuran', 'tagihan', 'sewa', 'rumah', 'apartemen', 'kos'
      ],
      'Kesehatan': [
        'obat', 'apotek', 'sakit', 'dokter', 'klinik', 'puskesmas', 'vitamin', 
        'masker', 'rs', 'rumah sakit', 'bpjs kesehatan', 'periksa', 'ambulan'
      ],
      'Pendidikan': [
        'sekolah', 'kuliah', 'spp', 'buku', 'kursus', 'seminar', 'les', 'udemy', 
        'coursera', 'pendaftaran', 'sks', 'wisuda', 'atk', 'pulpen', 'pensil', 'kas', 'uang kas'
      ],
      'Gaji': [
        'gaji', 'salary', 'payday', 'upah', 'honor', 'omset', 'omzet', 'revenue',
        'gajian', 'tunjangan', 'thr'
      ],
      'Investasi': [
        'investasi', 'saham', 'crypto', 'kripto', 'reksadana', 'reksa dana', 
        'deposito', 'emas', 'bibit', 'bareksa', 'pluang', 'trading', 'dividen'
      ],
    };

    for (final entry in keywordMapping.entries) {
      final targetCategory = entry.key;
      final keywords = entry.value;

      // Cari kategori yang memiliki kemiripan dengan targetCategory
      final matchedCat = _findCategoryByName(targetCategory, categories);

      if (matchedCat != null) {
        for (final keyword in keywords) {
          if (desc.contains(keyword)) {
            return matchedCat.name;
          }
        }
      }
    }

    return null;
  }

  /// Panggilan Groq API (llama-3.3-70b-versatile) untuk analisis semantik
  Future<String?> _predictWithGroq({
    required String description,
    required List<CategoryModel> availableCategories,
    required String transactionType,
  }) async {
    final categoriesListText = availableCategories.map((c) => "- ${c.name}").join('\n');
    final String typeLabel = transactionType == 'expense' ? 'Pengeluaran' : 'Pemasukan';

    final prompt = '''
Anda adalah asisten cerdas pengelola keuangan. Tugas Anda adalah memprediksi kategori transaksi yang paling cocok berdasarkan deskripsi/catatan transaksi yang diberikan oleh pengguna.

Daftar kategori yang tersedia dalam aplikasi saat ini (pilih salah satu yang paling cocok dari daftar ini saja!):
$categoriesListText

Tipe Transaksi: $typeLabel
Deskripsi Transaksi: "$description"

Format JSON yang HARUS dikembalikan wajib memiliki key berikut:
{
  "category_name": "Nama Kategori Yang Paling Cocok (Harus sama persis dengan salah satu nama dari daftar kategori di atas)"
}

Kembalikan HANYA teks JSON tersebut tanpa penjelasan tambahan apa pun.
''';

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.1,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API returned status code ${response.statusCode}: ${response.body}');
    }

    final responseData = json.decode(response.body);
    final String? responseText = responseData['choices']?[0]?['message']?['content'];

    if (responseText == null || responseText.isEmpty) {
      throw Exception('Groq API returned an empty response');
    }

    debugPrint('AI Category Service (Groq Response): $responseText');
    final Map<String, dynamic> data = json.decode(responseText.trim());
    return data['category_name'] as String?;
  }
}
