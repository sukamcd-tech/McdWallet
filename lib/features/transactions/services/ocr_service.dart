import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/config.dart';
import '../domain/ocr_result_model.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Memproses file gambar struk belanja untuk diekstraksi datanya secara otomatis.
  /// Mendukung online parser (Groq & Gemini AI) dan offline parser (RegExp).
  Future<OcrResultModel> scanReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      final String rawText = recognizedText.text;
      debugPrint('OCR Raw Text: \n$rawText');

      if (rawText.trim().isEmpty) {
        return OcrResultModel(
          merchantName: 'Struk Tidak Terbaca',
          amount: 0.0,
          date: DateTime.now(),
        );
      }

      // 1. Coba gunakan Groq API terlebih dahulu karena super cepat dan handal
      if (AppConfig.groqApiKey.isNotEmpty) {
        try {
          return await _parseWithGroq(rawText);
        } catch (e) {
          debugPrint('Groq parsing failed, trying Gemini... Error: $e');
        }
      }

      // 2. Coba gunakan Gemini API jika Groq tidak tersedia atau gagal
      if (AppConfig.geminiApiKey.isNotEmpty) {
        try {
          return await _parseWithGemini(rawText);
        } catch (e) {
          debugPrint('Gemini parsing failed, falling back to local RegExp parser. Error: $e');
        }
      }

      // 3. Fallback ke local RegExp parser jika semua online API gagal/tidak aktif
      return _parseWithLocalRegex(recognizedText);
    } catch (e) {
      debugPrint('OCR Scan failed: $e');
      rethrow;
    }
  }

  /// Menutup inisialisasi mesin recognizer untuk mencegah kebocoran memori.
  void dispose() {
    _textRecognizer.close();
  }

  /// Parsing menggunakan Groq API (llama-3.3-70b-versatile) secara cerdas dan super cepat
  Future<OcrResultModel> _parseWithGroq(String rawText) async {
    final prompt = '''
Anda adalah asisten ekstraksi data struk belanja keuangan. Tugas Anda adalah menganalisis teks struk hasil pindaian OCR berikut dan mengekstrak informasi penting secara akurat ke dalam format JSON.

Format JSON yang HARUS dikembalikan wajib memiliki key berikut:
{
  "merchant": "Nama Toko/Merchant (String)",
  "amount": nominal_total_belanja_angka_saja (double/numeric, tanpa titik pemisah ribuan, misal 125000),
  "date": "tanggal dan waktu transaksi format ISO 8601 YYYY-MM-DDTHH:mm:ss (String), gabungkan tanggal dan waktu dari struk jika ada. Jika waktu tidak tertera di struk, gunakan jam 00:00:00 (misal: 2026-06-03T14:30:00 atau 2026-06-03T00:00:00)",
  "category": "Kategori belanja yang paling cocok (pilih salah satu dari: 'Makanan & Minuman', 'Belanja & Hiburan', 'Transportasi', 'WiFi & Internet', 'Kos & Rumah', 'Kesehatan', 'Lainnya')"
}

Teks mentah struk belanja:
---
$rawText
---

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

    debugPrint('Groq Response: $responseText');
    final Map<String, dynamic> data = json.decode(responseText.trim());

    final String merchant = data['merchant'] ?? 'Merchant Tidak Terdeteksi';
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    
    DateTime parsedDate = DateTime.now();
    if (data['date'] != null) {
      try {
        parsedDate = DateTime.parse(data['date']);
      } catch (_) {}
    }

    final String? category = data['category'];

    return OcrResultModel(
      merchantName: merchant,
      amount: amount,
      date: parsedDate,
      suggestedCategoryName: category,
    );
  }

  /// Parsing menggunakan Gemini API (gemini-1.5-flash) secara cerdas
  Future<OcrResultModel> _parseWithGemini(String rawText) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: AppConfig.geminiApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    final prompt = '''
Anda adalah asisten ekstraksi data struk belanja keuangan. Tugas Anda adalah menganalisis teks struk hasil pindaian OCR berikut dan mengekstrak informasi penting secara akurat ke dalam format JSON.

Format JSON yang HARUS dikembalikan wajib memiliki key berikut:
{
  "merchant": "Nama Toko/Merchant (String)",
  "amount": nominal_total_belanja_angka_saja (double/numeric, tanpa titik pemisah ribuan, misal 125000),
  "date": "tanggal dan waktu transaksi format ISO 8601 YYYY-MM-DDTHH:mm:ss (String), gabungkan tanggal dan waktu dari struk jika ada. Jika waktu tidak tertera di struk, gunakan jam 00:00:00 (misal: 2026-06-03T14:30:00 atau 2026-06-03T00:00:00)",
  "category": "Kategori belanja yang paling cocok (pilih salah satu dari: 'Makanan & Minuman', 'Belanja & Hiburan', 'Transportasi', 'WiFi & Internet', 'Kos & Rumah', 'Kesehatan', 'Lainnya')"
}

Teks mentah struk belanja:
---
$rawText
---

Kembalikan HANYA teks JSON tersebut tanpa penjelasan tambahan apa pun.
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text;
    
    if (responseText == null || responseText.isEmpty) {
      throw Exception('Gemini API returned an empty response');
    }

    debugPrint('Gemini Response: $responseText');
    final Map<String, dynamic> data = json.decode(responseText.trim());

    final String merchant = data['merchant'] ?? 'Merchant Tidak Terdeteksi';
    final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    
    DateTime parsedDate = DateTime.now();
    if (data['date'] != null) {
      try {
        parsedDate = DateTime.parse(data['date']);
      } catch (_) {}
    }

    final String? category = data['category'];

    return OcrResultModel(
      merchantName: merchant,
      amount: amount,
      date: parsedDate,
      suggestedCategoryName: category,
    );
  }

  /// Parsing offline lokal menggunakan ekspresi reguler (RegExp) yang dioptimasi
  OcrResultModel _parseWithLocalRegex(RecognizedText recognizedText) {
    String merchantName = 'Struk Tidak Terdeteksi';
    double amount = 0.0;
    DateTime date = DateTime.now();
    String? suggestedCategory;

    // Kumpulkan seluruh baris teks
    final List<String> lines = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        if (line.text.trim().isNotEmpty) {
          lines.add(line.text.trim());
        }
      }
    }

    if (lines.isEmpty) {
      return OcrResultModel(merchantName: merchantName, amount: amount, date: date);
    }

    // ── 1. Ekstraksi Nama Toko (Merchant) ──
    // Toko biasanya berada di 1-2 baris paling atas, abaikan baris metadata/angka.
    for (int i = 0; i < lines.length && i < 3; i++) {
      if (_isNoiseLine(lines[i], i, lines.length)) continue;
      final cleanLine = lines[i].replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      // Skip jika baris tersebut didominasi angka atau tanggal
      if (cleanLine.isNotEmpty && 
          !cleanLine.contains(RegExp(r'\d{2,4}')) && 
          cleanLine.length > 2) {
        merchantName = lines[i];
        break;
      }
    }

    // ── 2. Ekstraksi Tanggal & Waktu Transaksi ──
    final dateRegex = RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b');
    final isoDateRegex = RegExp(r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b');
    final timeRegex = RegExp(r'\b([01]?\d|2[0-3])[:.]([0-5]\d)(?:[:.]([0-5]\d))?\b');

    int day = DateTime.now().day;
    int month = DateTime.now().month;
    int year = DateTime.now().year;
    int hour = 0;
    int minute = 0;
    int second = 0;
    bool timeFound = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isNoiseLine(line, i, lines.length)) continue;

      // Coba format DD/MM/YYYY
      var match = dateRegex.firstMatch(line);
      if (match != null) {
        day = int.tryParse(match.group(1)!) ?? day;
        month = int.tryParse(match.group(2)!) ?? month;
        var y = int.tryParse(match.group(3)!) ?? year;
        if (y < 100) y += 2000; // Konversi YY ke YYYY
        year = y;
        
        // Cari jam di baris yang sama terlebih dahulu
        final lineWithoutDate = line.replaceAll(match.group(0)!, '');
        var timeMatch = timeRegex.firstMatch(lineWithoutDate);
        if (timeMatch != null) {
          hour = int.tryParse(timeMatch.group(1)!) ?? hour;
          minute = int.tryParse(timeMatch.group(2)!) ?? minute;
          if (timeMatch.group(3) != null) {
            second = int.tryParse(timeMatch.group(3)!) ?? second;
          }
          timeFound = true;
        }
        break;
      }

      // Coba format YYYY-MM-DD
      match = isoDateRegex.firstMatch(line);
      if (match != null) {
        year = int.tryParse(match.group(1)!) ?? year;
        month = int.tryParse(match.group(2)!) ?? month;
        day = int.tryParse(match.group(3)!) ?? day;
        
        // Cari jam di baris yang sama terlebih dahulu
        final lineWithoutDate = line.replaceAll(match.group(0)!, '');
        var timeMatch = timeRegex.firstMatch(lineWithoutDate);
        if (timeMatch != null) {
          hour = int.tryParse(timeMatch.group(1)!) ?? hour;
          minute = int.tryParse(timeMatch.group(2)!) ?? minute;
          if (timeMatch.group(3) != null) {
            second = int.tryParse(timeMatch.group(3)!) ?? second;
          }
          timeFound = true;
        }
        break;
      }
    }

    // Jika jam belum ketemu di baris tanggal, cari di seluruh baris
    if (!timeFound) {
      for (int i = 0; i < lines.length; i++) {
        // Skip status bar clock noise
        if (_isNoiseLine(lines[i], i, lines.length)) continue;
        
        var timeMatch = timeRegex.firstMatch(lines[i]);
        if (timeMatch != null) {
          final matchedStr = timeMatch.group(0)!;
          if (matchedStr.contains('.')) {
            // Jika ada 3 angka di belakang titik, itu ribuan bukan menit (misal 10.000)
            final parts = matchedStr.split('.');
            if (parts.length > 1 && parts[1].length == 3) {
              continue;
            }
          }
          
          hour = int.tryParse(timeMatch.group(1)!) ?? hour;
          minute = int.tryParse(timeMatch.group(2)!) ?? minute;
          if (timeMatch.group(3) != null) {
            second = int.tryParse(timeMatch.group(3)!) ?? second;
          }
          timeFound = true;
          break;
        }
      }
    }

    try {
      date = DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      date = DateTime.now();
    }

    // ── 3. Ekstraksi Nominal Total Belanja ──
    final totalKeywords = ['TOTAL', 'GRAND', 'JUMLAH', 'BAYAR', 'NETTO', 'DIBAYAR'];
    final List<double> amountCandidates = [];
    final List<double> totalProximityCandidates = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Lewati baris yang dideteksi sebagai noise UI atau screenshot
      if (_isNoiseLine(line, i, lines.length)) continue;

      // Lewati baris yang dideteksi berisi tanggal transaksi agar tidak rancu dengan nominal
      final hasDate = dateRegex.hasMatch(line) || isoDateRegex.hasMatch(line);
      if (hasDate) continue;

      final List<double> parsedAmounts = _extractAmountsFromLine(line);
      
      if (parsedAmounts.isNotEmpty) {
        amountCandidates.addAll(parsedAmounts);
        
        // Cek kedekatan dengan kata kunci total
        final lineUpper = line.toUpperCase();
        bool isNearTotalKeyword = totalKeywords.any((kw) => lineUpper.contains(kw));
        
        // Juga cek 1 baris sebelumnya untuk kata kunci total
        if (!isNearTotalKeyword && i > 0) {
          isNearTotalKeyword = totalKeywords.any((kw) => lines[i - 1].toUpperCase().contains(kw));
        }

        if (isNearTotalKeyword) {
          totalProximityCandidates.addAll(parsedAmounts);
        }
      }
    }

    if (totalProximityCandidates.isNotEmpty) {
      // Ambil yang terbesar di antara kandidat yang dekat dengan kata kunci total
      totalProximityCandidates.sort();
      amount = totalProximityCandidates.last;
    } else if (amountCandidates.isNotEmpty) {
      // Jika tidak ada kata kunci total yang cocok, ambil angka terbesar di struk (biasanya total belanja)
      amountCandidates.sort();
      amount = amountCandidates.last;
    }

    // ── 4. Ekstraksi Kategori Otomatis ──
    final fullTextUpper = recognizedText.text.toUpperCase();
    if (fullTextUpper.contains(RegExp(r'(MAKAN|MINUM|RESTO|CAF|KOPI|FOOD|BEVERAGE|WARUNG|BAKSO|MIE|STEAK|AYAM)'))) {
      suggestedCategory = 'Makanan & Minuman';
    } else if (fullTextUpper.contains(RegExp(r'(PERTAMINA|BENSIN|SHELL|SPBU|PARKIR|GRAB|GOJEK|OJOL|BENSIN|TRANSPORT|TRANSIT)'))) {
      suggestedCategory = 'Transportasi';
    } else if (fullTextUpper.contains(RegExp(r'(WIFI|INTERNET|INDIHOME|BIZNET|SPEEDY)'))) {
      suggestedCategory = 'WiFi & Internet';
    } else if (fullTextUpper.contains(RegExp(r'(INDOMARET|ALFAMART|ALFAMI|MART|SUPERMARKET|HYPERMARKET|MALL|BELANJA|GROCERY|PASAR|MINIMARKET|BIOSKOP|XXI|TIKET|NONTON|GAME|PLAYSTATION|KARAOKE|REFLEKSI)'))) {
      suggestedCategory = 'Belanja & Hiburan';
    } else if (fullTextUpper.contains(RegExp(r'(APOTEK|OBAT|KLINIK|DOKTER|RUMAH SAKIT|HERBAL|MEDIS)'))) {
      suggestedCategory = 'Kesehatan';
    } else if (fullTextUpper.contains(RegExp(r'(KOS|KONTRAKAN|Sewa|RUMAH|APARTEMEN)'))) {
      suggestedCategory = 'Kos & Rumah';
    } else {
      suggestedCategory = 'Lainnya';
    }

    return OcrResultModel(
      merchantName: merchantName,
      amount: amount,
      date: date,
      suggestedCategoryName: suggestedCategory,
    );
  }

  /// Mendeteksi apakah baris teks merupakan noise UI status bar,
  /// media sosial, atau informasi non-transaksi lainnya.
  bool _isNoiseLine(String line, int index, int totalLines) {
    final upper = line.toUpperCase().trim();
    
    // 1. Suffix kecepatan internet di status bar
    if (upper.contains(RegExp(r'\b\d+([,.]\d+)?\s*(K/S|KB/S|M/S|MB/S|B/S|KBPS|MBPS)\b'))) {
      return true;
    }
    
    // 2. Indikator sinyal / status bar
    if (upper.contains('VOLTE') || 
        upper.contains('4G') || 
        upper.contains('5G') || 
        upper.contains('LTE') ||
        upper.contains('3G')) {
      return true;
    }
    
    // 3. Persentase baterai di status bar
    if (upper.contains(RegExp(r'\b\d{1,2}\s*%\b'))) {
      return true;
    }
    
    // 4. Jam di status bar (biasanya di 3 baris pertama, format HH.MM atau HH:MM murni)
    if (index < 3) {
      final timeMatch = RegExp(r'^\b\d{1,2}[.:]\d{2}\b$').hasMatch(upper);
      if (timeMatch) return true;
    }
    
    // 5. Elemen UI Media Sosial / Screenshot (LinkedIn, Instagram, tombol action)
    if (upper == 'LINKEDIN' || 
        upper.contains('BUKA >') || 
        upper.contains('BAGIKAN') || 
        upper.contains('SIMPAN') || 
        upper.contains('CHATGPT') || 
        upper.contains('GAMBAR MUNGKIN DILINDUNGI HAK CIPTA') || 
        upper.contains('PELAJARI LEBIH LANJUT') ||
        upper.contains('PAGI INI, SAYA MENGGUNAKAN') ||
        upper.contains('TERIMA KASIH SELAMAT JALAN') ||
        upper.contains('TERIMA KASIH') ||
        upper.contains('SELAMAT JALAN')) {
      return true;
    }
    
    return false;
  }

  /// Ekstraksi semua nominal angka yang memungkinkan dari sebuah baris teks struk belanja.
  /// Mengembalikan list kandidat angka yang valid.
  List<double> _extractAmountsFromLine(String line) {
    final List<double> candidates = [];
    
    // 1. Bersihkan noise karakter, simbol mata uang Rp, dll
    String cleanText = line.toUpperCase();
    cleanText = cleanText.replaceAll(RegExp(r'[Rr]?[Pp]\.?\s*'), ''); // Hapus Rp
    cleanText = cleanText.replaceAll(RegExp(r',[-=]'), '');          // Hapus ,- atau ,=
    
    // 2. Ganti spasi pemisah ribuan atau spasi setelah titik/koma karena noise OCR
    cleanText = cleanText.replaceAllMapped(RegExp(r'(\d)\s+(\d)'), (match) {
      return '${match.group(1)}${match.group(2)}';
    });
    cleanText = cleanText.replaceAllMapped(RegExp(r'(\d)[.,]\s+(\d)'), (match) {
      return '${match.group(1)}.${match.group(2)}';
    });

    // 3. Temukan semua angka dalam baris teks tersebut
    final numberRegex = RegExp(r'\b\d+(?:[.,]\d+)+\b|\b\d+\b');
    final matches = numberRegex.allMatches(cleanText);

    for (var match in matches) {
      final rawNumStr = match.group(0)!;
      
      // Jika angka murni tanpa pemisah titik/koma
      if (!rawNumStr.contains('.') && !rawNumStr.contains(',')) {
        final val = double.tryParse(rawNumStr);
        if (val != null && val > 0) {
          candidates.add(val);
          // Jika angka murni sangat kecil (< 100), bisa jadi ribuan yang kehilangan nol
          if (val < 100) {
            candidates.add(val * 1000);
          }
        }
        continue;
      }

      // Cari posisi pemisah terakhir untuk menganalisis ribuan vs desimal
      final lastSeparatorIdx = rawNumStr.lastIndexOf(RegExp(r'[.,]'));
      final beforeSeparator = rawNumStr.substring(0, lastSeparatorIdx);
      final afterSeparator = rawNumStr.substring(lastSeparatorIdx + 1);

      final baseStr = beforeSeparator.replaceAll(RegExp(r'[.,]'), '');
      final baseVal = double.tryParse(baseStr) ?? 0.0;

      if (afterSeparator.length == 3) {
        // Pemisah ribuan (3 digit di belakang)
        final fullStr = rawNumStr.replaceAll(RegExp(r'[.,]'), '');
        final val = double.tryParse(fullStr);
        if (val != null && val > 0) {
          candidates.add(val);
        }
      } else if (afterSeparator.length == 2) {
        // Pemisah desimal sen (2 digit di belakang)
        if (baseVal >= 100) {
          // Angka besar di depannya, kemungkinan desimal sen
          if (baseVal > 0) candidates.add(baseVal);
        } else {
          // Angka kecil, bisa desimal murni ATAU ribuan yang kepotong OCR (misal "25.00" untuk "25.000")
          final decimalVal = double.tryParse(rawNumStr.replaceAll(',', '.')) ?? 0.0;
          if (decimalVal > 0) candidates.add(decimalVal);
          
          final thousandsVal = baseVal * 1000;
          if (thousandsVal > 0) candidates.add(thousandsVal);
        }
      } else {
        // Format lainnya, bersihkan semua pemisah dan ambil nilai murni
        final fullStr = rawNumStr.replaceAll(RegExp(r'[.,]'), '');
        final val = double.tryParse(fullStr);
        if (val != null && val > 0) {
          candidates.add(val);
        }
      }
    }

    return candidates;
  }
}
