# Changelog — McdWallet

Semua perubahan penting pada proyek **McdWallet** didokumentasikan di berkas ini. Format rilis ini merujuk pada standar [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) dan menggunakan [Semantic Versioning](https://semver.org/).

---

## [1.0.0] — 2026-06-03

Rilis stabil pertama aplikasi McdWallet dengan seluruh modul inti manajemen transaksi bulanan, sistem pemantauan limit anggaran reaktif, asisten AI terintegrasi, pemindai struk otomatis (OCR Receipt Scanner), pemantau kurs asing (Forex Monitoring), getaran taktil mikro (haptic feedback), optimasi efek memuat (shimmer loading skeleton), serta keamanan PIN biometrik modern.

### Ditambahkan

*   **Klasifikasi Kategori Transaksi Cerdas (AI Smart Auto-Categorization)**:
    *   **Hibrida Cerdas Lokal & Cloud**: Mengintegrasikan analisis hibrida cepat: pencocokan lokal dengan engine regex yang dinamis, didukung panggilan asinkron ke Groq Cloud API (`llama-3.3-70b-versatile`) menggunakan model LLM yang sangat cepat untuk pemahaman kalimat semantik yang deterministik (`temperature: 0.1`, `json_object`).
    *   **Debouncer Waktu 800ms**: Memasang debouncer 800ms pada masukan teks catatan/deskripsi transaksi agar mencegah banjir request API saat pengguna masih aktif mengetik.
    *   **Akurasi Lokal Tanpa Kuota**: Secara instan memprediksi kategori transaksi offline menggunakan pustaka kata kunci yang selaras dengan daftar kategori pengguna (misal: "makan", "bakso", "kopi" -> Makanan & Minuman; "grab", "gojek", "bensin" -> Transportasi).
    *   **Smart Manual Override**: Membatalkan status AI secara halus jika pengguna memutuskan untuk mengubah atau memilih kategori lain secara manual.
    *   **Visual Status Cerdas Minimalis**: Menampilkan status visual yang menawan *"Kategori dipilih otomatis oleh AI"* bernuansa Charcoal minimalis di bawah dropdown ketika kategori diset otomatis oleh AI.
*   **Asisten Keuangan Pintar Interaktif (McdAI Advisor)**:
    *   **Akses Anggaran & Tabungan Real-Time**: McdAI kini memiliki akses penuh dan aman ke data anggaran (*budgets*) aktif serta target tabungan (*savings goals*) pengguna untuk menyajikan analisis finansial yang komprehensif, rekomendasi penghematan taktis, dan pemantauan batas anggaran yang presisi.
    *   **Integrasi FAB Reaktif pada Dashboard**: Memindahkan akses McdAI dari bilah tab navigasi bawah menjadi tombol mengambang (*Floating Action Button*) reaktif di layar dasbor utama, menyesuaikan posisi dan warna sesuai dengan standar UI anggaran.
    *   **Antarmuka Premium Black/Off-white**: Mendesain layar obrolan interaktif glassmorphic minimalis dengan tema premium Charcoal & Off-white, lengkap dengan bar judul tengah (*centered*), tombol navigasi kembali berupa ikon panah minimalis (`<`), serta tombol saran/pertanyaan cepat.
    *   **Disclaimer Keamanan AI**: Menambahkan baris pesan peringatan responsif *"McdAI dapat membuat kesalahan. Harap verifikasi informasi penting."* tepat di bawah kolom input teks pesan untuk menjamin transparansi informasi.
    *   **Pembersihan Sesi Aman**: Riwayat obrolan secara otomatis dihapus dari memori lokal setiap kali pengguna keluar dari layar obrolan untuk menjamin 100% keamanan privasi data finansial.
*   **Pemantau Kurs Asing (Forex Monitoring)**:
    *   **Wise/Revolut-Style Dashboard**: Panel horizontal scrollable card minimalis premium yang menampilkan kartu kurs mata uang asing pilihan secara dinamis lengkap dengan bendera visual, nama mata uang, nilai tukar real-time terhadap IDR, serta panah indikator tren pergerakan nilai tukar.
    *   **Kalkulator Konversi Cepat (Converter Sheet)**: Mengintegrasikan deteksi ketukan pada setiap kartu kurs asing untuk memunculkan modal bottom sheet kalkulator konversi valas interaktif. Mendukung sinkronisasi reaktif dua arah (input Valas <-> IDR) secara *real-time* saat pengguna mengetik, tombol preset nilai instan (+10, +50, +100, +500, +1.000 valas, dan Rp50k, Rp100k, Rp500k, Rp1jt, Rp5jt IDR), serta 100% aman digunakan secara offline/luring menggunakan data cache lokal terbaru.
    *   **Integrasi API Bebas Kunci (Keyless)**: Menggunakan public API dari `open.er-api.com` (didukung ExchangeRate-API via Cloudflare CDN) sebagai sumber data real-time berkinerja tinggi, menjamin stabilitas 100% tanpa risiko kegagalan otentikasi kunci API komersial.
    *   **Auto-Update Latar Belakang & Caching Pintar**: Sistem refresh otomatis latar belakang berbasis durasi cache 1 jam menggunakan `SharedPreferences` untuk menyimpan data kurs secara lokal. Dilengkapi cooldown refresh manual selama 5 menit guna mencegah pemborosan pemanggilan API dan menghemat kuota internet pengguna.
    *   **Pencarian & Seleksi Reaktif**: Lembar pilihan (bottom sheet) dinamis untuk mencari, memilih, dan membatasi pemantauan hingga 5 mata uang asing favorit secara reaktif (disimpan secara permanen dalam memori lokal perangkat).
    *   **Model Data Adaptif & Presisi**: Konversi dan pembulatan dinamis untuk nominal besar (>= Rp100 dibulatkan tanpa desimal agar pas dalam kartu visual yang sempit, sedangkan nominal kecil tetap presisi dengan 2 digit desimal).
*   **Pemindai Struk Otomatis (OCR Receipt Scanner)**:
    *   **Hibrida Cerdas Multi-LLM**: Mengintegrasikan API super cepat **Groq (LLaMA 3.3 70B)** sebagai pemroses utama online (~100ms) untuk pengenalan JSON terstruktur yang sangat presisi, didukung oleh fallback **Gemini API (gemini-1.5-flash)**.
    *   **Offline-First Google ML Kit**: Layanan offline on-device menggunakan `google_mlkit_text_recognition` sebagai pemindai mandiri tanpa membutuhkan kuota atau jaringan internet.
    *   **Filter Noise Status Bar & UI Screenshot**: Modul filter `_isNoiseLine` pada `ocr_service.dart` untuk otomatis mengabaikan teks kecepatan internet ponsel (`53,1 K/s`), carrier state (`VoLTE`, `4G`), baterai (`69%`), jam, dan elemen UI screenshot media sosial (seperti `LinkedIn`, `Bagikan`, `Simpan`, `Buka >`).
    *   **Koreksi Cerdas Angka Ribuan**: Pemrosesan `_extractAmountsFromLine` yang secara cerdas merekonstruksi angka ribuan yang terpotong desimal sen akibat keterbatasan OCR (misal `10.000` atau `25.000` terbaca `10.00` atau `25.00`), menjamin nominal belanja tetap terbaca tepat.
    *   **Penyaringan Konteks Tanggal**: Mengabaikan angka tanggal transaksi struk (seperti tanggal `04` dan `2025` dari `04/04/2025`) dari daftar kandidat nominal belanja agar tidak menimbulkan kerancuan.
    *   **Tombol Ikon Murni "Foto Ulang"**: Mengubah tombol foto ulang menjadi icon-only button berbasis ikon kamera minimalis (`LucideIcons.camera`) untuk keselarasan desain visual yang seimbang.
    *   **Lembar Scanner Interaktif Glassmorphic**: Modal bottom sheet modern dilengkapi denyutan laser hijau saat proses pemindaian sedang berlangsung, picker galeri/kamera, dan formulir verifikasi pra-isi.
    *   **Pengisian Formulir Otomatis**: Tombol pemindai cepat pada AppBar transaksi yang secara otomatis mengisi nominal, nama toko, tanggal struk, dan otomatis melampirkan berkas foto ke dalam Supabase Storage.
    *   **Ketergantungan Baru**: Menambahkan paket `google_mlkit_text_recognition`, `google_generative_ai`, dan `http: ^1.2.1` ke dalam berkas `pubspec.yaml`.
*   **Getaran Taktil Global Konfigurabel (Global Haptic Feedback Toggle)**:
    *   **Sakelar Switch.adaptive Premium**: Menyediakan toggle sakelar haptic premium dalam kartu *Privasi & Tampilan* pada layar Pengaturan (*Settings*) agar pengguna dapat memilih kenyamanan personal dalam mengaktifkan/menonaktifkan efek getaran fisik mikro.
    *   **Modul Getaran Terpusat (AppHaptics)**: Menyusun class pembungkus `AppHaptics` yang secara selektif memicu getaran mikro (`lightImpact`, `mediumImpact`, `heavyImpact`, `selectionClick`) di seluruh aplikasi (seperti tombol utama `CustomButton` dan interaksi penting) secara bersyarat sesuai preferensi pengguna.
    *   **Sinkronisasi Riverpod & SharedPreferences**: Menghubungkan Riverpod StateNotifier `hapticProvider` dengan persistensi penyimpanan `SharedPreferences` agar preferensi getaran taktil tersimpan secara permanen.
*   **Kustomisasi Ambang Batas Peringatan Anggaran (Custom Budget Alert Threshold)**:
    *   **Pill Selector Multi-Select di Settings**: Membuat modul antarmuka premium berupa 3 tombol pil persentase reaktif (50%, 70%, 90%) pada halaman Pengaturan (*Settings*) untuk mengaktifkan atau menonaktifkan ambang batas alarm peringatan anggaran secara fleksibel (pengguna dapat memilih lebih dari satu ambang batas secara bersamaan).
    *   **Pemicu Notifikasi Momentum Crossing**: Mengintegrasikan kalkulasi dinamis antara nominal transaksi saat ini dengan pengeluaran sebelumnya (`previousSpent`) untuk mendeteksi momentum penembusan limit secara presisi, mencegah notifikasi spam berulang-ulang setiap kali transaksi baru ditambahkan setelah melampaui batas.
    *   **Notifikasi Pengeluaran Melebihi Batas Permanen**: Menetapkan notifikasi pengeluaran yang melampaui batas maksimal anggaran (>= 100%) sebagai notifikasi wajib/permanen (*fixed always-on*), memastikan alarm kritis tetap berbunyi demi perlindungan finansial walaupun opsi peringatan lainnya dinonaktifkan di pengaturan.
*   **Penyempurnaan Kenyamanan Pengguna (Haptic Feedback)**:
    *   **Getaran Mikro pada FAB Utama**: Menambahkan getaran ringan (*light haptic feedback*) reaktif di setiap Floating Action Button utama aplikasi (FAB McdAI di Dashboard, FAB Tambah Dompet di Wallets Screen, FAB Tambah Transaksi di Transactions Screen, dan FAB Tambah Anggaran/Tabungan di Budgets Screen) untuk meningkatkan sensasi fisik taktil saat pengguna menekan tombol aksi utama.
*   **Efek Memuat Shimmer Premium (Shimmer Loading Skeleton)**:
    *   **Komponen Shimmer Reusable**: Membuat widget `ShimmerLoading` & `ShimmerSkeleton` yang berkinerja tinggi menggunakan pustaka `flutter_animate` bawaan untuk menggantikan loading melingkar bawaan.
    *   **Dashboard Shimmer Skeletons**: Mengubah pemuatan grafik analitik menjadi kartu shimmer skeleton adaptif (height 120), serta memuat daftar transaksi mutasi terakhir dengan 3 baris placeholder teks dan ikon sirkular berdenyut.
    *   **Transactions & Budgets Shimmer Lists**: Mengganti pemuatan daftar transaksi penuh di *Transactions Screen* dan daftar progres anggaran/tabungan di *Budgets Screen* menjadi daftar kerangka placeholder (skeleton list) premium yang berdenyut lembut.
*   **Manajemen Transaksi Mutasi (CRUD)**: Pencatatan mutasi pengeluaran, pemasukan, dan transfer dalam satu form terpadu dengan reload balance reaktif.
*   **Biaya Admin Transfer**: Fasilitas penambahan biaya administrasi ketika melakukan transfer saldo antar-dompet lengkap dengan trigger database update saldo di Supabase PostgreSQL.
*   **Visualisasi Saldo Awal & Saldo Akhir**: Monthly Summary Card pada daftar riwayat transaksi yang secara matematis menghitung saldo awal dan saldo akhir historis bulanan menggunakan sistem rollback transaksi.
*   **True Lazy Scroll Virtualization**: Struktur list riwayat transaksi datar (*flattening*) dengan viewport virtualization memanfaatkan single `ListView.builder` untuk menjamin performa gulir super mulus (60/120 FPS).
*   **Sistem Limit Anggaran (Budgeting)**: Progress bar limit anggaran bulanan reaktif yang berubah warna secara dinamis (Hijau/Kuning/Merah) dilengkapi pemicuan local notification status bar saat batas pengeluaran terlampaui.
*   **Dasbor Analitik Keuangan**: Grafik tren garis arus kas melengkung ganda (*Cashflow Line Chart*) dan diagram lingkaran distribusi pengeluaran (*Pie Chart*) interaktif berbasis `fl_chart`.
*   **Keamanan PIN & Biometrik**: Proteksi kode keamanan PIN lokal yang diintegrasikan secara native dengan pemindaian biometrik (`local_auth`).
*   **Ekspor Data Laporan**: Bottom sheet pengeksporan mutasi transaksi ke berkas standard CSV dan ringkasan teks indah yang siap disalin untuk dibagikan ke WhatsApp.

### Diperbaiki

*   **Keyboard Layout Bottom Overflow**: Merancang ulang layout modal bottom sheet `OcrScannerSheet` dengan menggunakan `SingleChildScrollView` dan transisi `AnimatedPadding` bermedium kurva *Ease-Out Quad* berdurasi 150 milidetik. Bug overflow sebesar 68px saat keyboard aktif kini **teratasi 100%**.
*   **Pencegahan Horizontal Layout Overflow**: Mengganti baris mendatar `Row` pada kolom Rekomendasi Kategori menjadi widget `Wrap` reaktif (`spacing: 8` dan `runSpacing: 6`). Masalah visual `Right Overflowed by 5.8 pixels` pada rasio layar smartphone sempit kini **teratasi 100%** dengan melipat badge ke bawah secara alami.
*   **Optimasi Centering Ikon Button**: Meningkatkan widget global `CustomButton` agar secara cerdas tidak menyisipkan jarak spasi pemisah jika teks diset kosong (`text: ''`), menjamin posisi ikon murni berada tepat di tengah-tengah tombol.
*   **Penonaktifan Sementara Dompet Multi-Valas (Multi-Currency)**: Menonaktifkan sementara pilihan mata uang asing non-IDR saat membuat dompet baru, serta menonaktifkan pemilihan dompet valas pada formulir transaksi/tabungan dengan label penjelasan *"Sedang dalam pengembangan"* untuk menjaga integritas saldo database selama proses pengembangan berjalan.
