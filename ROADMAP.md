# Rencana Pengembangan Sistem (Roadmap & Backlog) — McdWallet

Dokumen ini berisi rencana pengembangan jangka panjang, perbaikan sistem (*improvements*), serta gagasan fitur baru untuk aplikasi **McdWallet** guna meningkatkan kualitas rekayasa, performa, keamanan, dan kegunaan sistem (*user experience*).

---

## 1. Optimalisasi Sistem & Perbaikan Arsitektur (*System Improvements*)

Daftar perbaikan teknis pada modul yang sudah ada untuk menjamin skalabilitas aplikasi:

### [x] Kompresi Gambar Lampiran Struk (*Image Compression*)
*   **Status**: **SELESAI (v2.2.0)**
*   **Deskripsi**: Mengurangi ukuran resolusi dan kapasitas file foto struk/nota belanja yang diambil langsung dari kamera ponsel secara asinkron sebelum diunggah ke Supabase Storage.
*   **Hasil Implementasi**:
    *   **Kecepatan Tinggi (Native Thread)**: Sukses mengintegrasikan package `flutter_image_compress` untuk melakukan proses kompresi asinkron di tingkat native (Kotlin/Swift) guna menjamin UI aplikasi tetap responsif (0% lag).
    *   **Kompresi Dinamis & Adaptif**: Algoritma cerdas yang membatasi resolusi maksimum ke **1080p** (max 1920px) dan secara otomatis menyesuaikan kualitas gambar secara adaptif (mulai dari kualitas 80% turun bertahap hingga batas aman 35%) agar berkas nota belanja berada di target aman **300 KB - 500 KB** tanpa merusak keterbacaan teks/OCR.
    *   **Penyelamat Kegagalan (Fail-safe)**: Fallback otomatis menggunakan berkas asli jika terjadi kendala pada modul kompresi native di device pengguna.
*   **Kompleksitas**: Rendah (Low)

### [ ] Sistem Penyimpanan Lokal & Mode Offline (*Offline Caching*)
*   **Deskripsi**: Menjamin pencatatan keuangan tetap dapat dilakukan ketika pengguna berada di area tanpa koneksi internet.
*   **Strategi Implementasi**:
    *   Memasang local database yang ringan dan aman seperti `Hive` atau `Isar`.
    *   Menyimpan transaksi baru secara lokal dengan bendera status `is_synced: false`.
    *   Membuat modul sinkronisasi latar belakang yang mendeteksi jaringan menggunakan `connectivity_plus` dan mengunggah data tertunda ke Supabase secara otomatis saat koneksi pulih.
*   **Kompleksitas**: Tinggi (High)

### [x] Otomatisasi Kunci Aplikasi (*Auto-Lock Timeout*)
*   **Status**: **SELESAI (v2.6.0)**
*   **Deskripsi**: Mengamankan data finansial pengguna secara otomatis jika aplikasi ditinggalkan dalam kondisi terbuka.
*   **Hasil Implementasi**:
    *   **Observer Daur Hidup Aplikasi (WidgetsBindingObserver)**: Menerapkan pemantauan status daur hidup aplikasi secara reaktif di tingkat `MyApp` (root widget) guna menangkap pergeseran status aplikasi ke `paused` atau `inactive` saat dikirim ke latar belakang.
    *   **Pencatatan Waktu & Lock Otomatis**: Secara asinkron mencatat timestamp jeda dan secara otomatis mengunci aplikasi (`ref.read(securityProvider.notifier).lock()`) saat pengguna kembali ke aplikasi (`resumed`) jika durasi jeda telah melebihi batas aman **3 menit**.
    *   **Integrasi Lock Screen Mulus**: State reaktif `securityProvider` mendeteksi status penguncian dan secara instan merender ulang antarmuka ke `PinEntryScreen` guna melindungi privasi data finansial.
*   **Kompleksitas**: Sedang (Medium)

### [x] Pelindung Tampilan Aplikasi Latar Belakang (*Secure App Switcher Overlay & Privacy Switch*)
*   **Status**: **SELESAI (v2.7.0)**
*   **Deskripsi**: Melindungi data finansial sensitif (seperti saldo, riwayat transaksi, dan grafik analitik) agar tidak terlihat oleh orang lain atau tertangkap snapshot sistem saat aplikasi berada di daftar aplikasi aktif (*app switcher / recents menu*), terintegrasi dengan tombol sakelar master privasi di halaman pengaturan.
*   **Hasil Implementasi**:
    *   **Overlay Penutup Layar Penuh (*Full-Screen Cover*)**: Merancang penutup layar premium berwarna putih bersih (`Colors.white`) dengan logo aplikasi `logo.png` minimalis di bagian tengah yang presisi.
    *   **Integrasi Lifecycle & MaterialApp.builder**: Memanfaatkan daur hidup aplikasi reaktif (`WidgetsBindingObserver`) untuk mendeteksi status `paused` atau `inactive` seketika saat aplikasi diminimalkan atau digeser ke atas.
    *   **Sakelar Master Keamanan & Privasi (*Master Switch*)**: Menambahkan switch premium "Kunci & Privasi Latar Belakang" di halaman pengaturan yang bersinergi dengan `SharedPreferences`. Jika dimatikan, semua pengaman (kode PIN, sidik jari/biometrik, dan penutup layar app switcher) secara otomatis dinonaktifkan dan dilewati secara dinamis demi kenyamanan pengguna.
    *   **Penyematan Global via Stack Navigator**: Menghubungkan visual penutup secara global menggunakan `MaterialApp.builder` agar melingkupi seluruh struktur navigasi halaman secara dinamis tanpa mengganggu performa rendering dan langsung menutup data seketika sebelum sistem merekam gambar *snapshot*.
*   **Kompleksitas**: Rendah (Low)

### [x] Sakelar Getaran Taktil Global (*Global Haptic Feedback Toggle*)
*   **Status**: **SELESAI (v2.5.0)**
*   **Deskripsi**: Memberikan kebebasan penuh bagi pengguna untuk mengaktifkan atau menonaktifkan getaran fisik taktil mikro di seluruh aplikasi demi efisiensi baterai atau kenyamanan personal.
*   **Hasil Implementasi**:
    *   **Wrapper Getaran Terpusat (AppHaptics)**: Membuat class pembungkus `AppHaptics` yang menangani pemicuan getaran taktil mikro secara bersyarat dan terpusat.
    *   **Sinkronisasi Riverpod & SharedPreferences**: Mengintegrasikan `hapticProvider` berbasis `StateNotifier` yang menyimpan data secara persisten di memori lokal agar setting bertahan lama meskipun aplikasi ditutup.
    *   **Switch Switch.adaptive Premium**: Menyediakan sakelar toggle yang harmonis dengan gaya UI Off-white/Charcoal McdWallet di halaman Pengaturan (*Settings*) di bawah tab Privasi & Tampilan.
*   **Kompleksitas**: Rendah (Low)

---

## 2. Rencana Fitur Baru (*New Features Backlog*)

Daftar fungsionalitas baru untuk memperluas jangkauan penggunaan aplikasi McdWallet:

### [ ] Pengingat & Pencatatan Transaksi Berulang (*Recurring & Subscription Manager*)
*   **Deskripsi**: Fasilitas otomatisasi untuk mencatat tagihan periodik rutin bulanan atau tahunan seperti layanan berlangganan (Netflix, Spotify), tagihan listrik, BPJS, maupun kosan.
*   **Strategi Implementasi**:
    *   Membuat tabel `recurring_templates` di Supabase untuk menampung template transaksi rutin.
    *   Menggunakan local notification scheduler untuk memicu alarm pengingat pembayaran pada H-1 tanggal jatuh tempo.
    *   Menyediakan opsi otomatisasi persetujuan pencatatan saldo dompet saat tanggal jatuh tempo terlewati.
*   **Kompleksitas**: Sedang (Medium)

### [x] Pemindai Struk Otomatis (*OCR Receipt Scanner*)
*   **Status**: **SELESAI (v2.1.0)**
*   **Deskripsi**: Kemudahan mencatat transaksi pengeluaran secara cepat hanya dengan memfoto struk kasir fisik tanpa perlu mengetik nominal secara manual.
*   **Hasil Implementasi**:
    *   **Hibrida Cerdas**: Sukses mengintegrasikan API **Groq (LLaMA 3.3 70B)** super cepat (~100ms) sebagai pemroses utama, didukung fallback sekunder **Gemini API (gemini-1.5-flash)**, serta parser offline lokal **Google ML Kit Text Recognition** untuk pemindaian mandiri tanpa koneksi internet.
    *   **Filter Noise Status Bar**: Algoritma reaktif yang otomatis menyaring data screenshot seperti jam, baterai, status bar (`VoLTE`, `4G`), kecepatan internet (`53,1 K/s`), dan UI media sosial (seperti `LinkedIn`, `Bagikan`, `Simpan`).
    *   **Koreksi Cerdas Ribuan**: Algoritma reaktif yang otomatis merekonstruksi angka ribuan yang terpotong oleh OCR (misal `25.000` terbaca `25.00`), menjamin ekstraksi nominal belanja tetap akurat secara presisi.
    *   **Keyboard Overflow Fix**: Desain layout modal bottom sheet scrollable interaktif yang dilindungi oleh `SingleChildScrollView` dan `AnimatedPadding` (durasi 150ms) untuk menjamin 0% bug keyboard layout bottom overflow.
    *   **Tombol Ikon Minimalis**: Tombol "Foto Ulang" berbasis ikon kamera murni (*icon-only*) untuk tampilan estetika visual yang seimbang dan modern.
*   **Kompleksitas**: Tinggi (High)

### [ ] Alat Bantu Pembagian Tagihan (*Split Bill Manager*)
*   **Deskripsi**: Membantu pengguna membagi tagihan pembayaran pengeluaran kelompok secara adil saat melakukan aktivitas makan atau belanja bersama rekan-rekan.
*   **Strategi Implementasi**:
    *   Mendesain modul antarmuka kalkulator pembagi tagihan yang fleksibel (pembagian rata atau berdasarkan item pesanan masing-masing individu).
    *   Menyimpan status pembayaran piutang (*settled* / *unsettled*) per kontak nama teman.
    *   Mencatat porsi bayar pribadi secara otomatis sebagai pengeluaran transaksi di dalam dompet terpilih.
*   **Kompleksitas**: Sedang (Medium)

### [ ] Dashboard Analitik Perbandingan Bulanan (*Month-over-Month Analytics*)
*   **Deskripsi**: Laporan grafik komparatif mendalam untuk membantu pengguna mengevaluasi efisiensi penghematan finansial dari bulan ke bulan.
*   **Strategi Implementasi**:
    *   Merancang chart bar komparatif (`BarChart` dari library `fl_chart`) untuk menyandingkan pengeluaran total bulan ini dengan bulan lalu.
    *   Menampilkan metrik persentase kenaikan/penurunan mutasi bersih secara deskriptif (misal: "Pengeluaran Anda menurun 12% dibanding bulan April").
*   **Kompleksitas**: Sedang (Medium)

### [ ] Sinkronisasi Mutasi BNI Otomatis via Email Reader (`wondr@bni.co.id`)
*   **Deskripsi**: Fitur otomatisasi pencatatan transaksi BNI wondr sekecil apa pun nominalnya dengan cara membaca email bukti transaksi masuk secara aman dari alamat pengirim resmi BNI `wondr@bni.co.id`, memecahkan masalah notifikasi SMS/Push wondr BNI yang hanya muncul untuk nominal di atas Rp500.000.
*   **Strategi Implementasi**:
    *   Mengintegrasikan Google Sign-In (`OAuth2`) dengan cakupan (*scope*) `https://www.googleapis.com/auth/gmail.readonly` untuk meminta izin akses baca email transaksi secara aman.
    *   Membuat *background sync worker* (menggunakan `workmanager` atau alarm scheduler) yang berjalan berkala untuk memeriksa inbox email terbaru dari pengirim `wondr@bni.co.id`.
    *   Mendesain parser teks HTML e-notification BNI wondr menggunakan modul RegExp dinamis untuk mengekstrak data penting:
        *   **Nominal Mutasi** (Debit / Kredit)
        *   **Tanggal & Waktu Transaksi** secara presisi.
        *   **Jenis Transaksi** (Transfer, QRIS, Tarik Tunai, Biaya Admin).
        *   **Nama Merchant / Rekening Tujuan**.
    *   Memasukkan data transaksi secara otomatis ke dompet BNI di dalam McdWallet dan memicu sinkronisasi lokal.
*   **Kompleksitas**: Tinggi (High)

### [ ] Pemantau Notifikasi Transaksi GoPay & E-Wallet (`GoPay Push Notification Listener`)
*   **Deskripsi**: Pencatatan otomatis mutasi pengeluaran e-wallet harian (GoPay, ShopeePay, OVO) bernominal mikro melalui bilah status notifikasi ponsel Android secara gratis dan *real-time*.
*   **Strategi Implementasi**:
    *   Memanfaatkan layanan sistem Android resmi `NotificationListenerService` di Flutter melalui integrasi native platform channel.
    *   Menyaring notifikasi masuk khusus dari aplikasi Gojek (`com.gojek.app`), OVO (`id.ovo`), dan Shopee (`com.shopee.id`).
    *   Mengekstrak data transaksi (nominal, jenis transaksi masuk/keluar, nama merchant) menggunakan parser regex lokal yang cepat.
    *   Menampilkan *background banner / silent local notification* ketika transaksi berhasil diimpor otomatis ke e-wallet terkait di McdWallet.
*   **Kompleksitas**: Sedang (Medium)

### [x] Kalkulator Konversi Valas Terintegrasi (*Forex Converter Calculator*)
*   **Status**: **SELESAI (v1.0.0)**
*   **Deskripsi**: Pengguna dapat mengetuk salah satu kartu kurs asing pada dasbor utama untuk membuka modal konverter cepat secara instan.
*   **Hasil Implementasi**:
    *   **Konversi Reaktif Dua Arah**: Field input valas asing dan IDR sinkron secara dinamis secara *real-time* saat pengguna mengetik angka di salah satu kolom.
    *   **Preset Konversi Cepat**: Menyediakan tombol pintas nilai preset populer (seperti +10, +50, +100, +500, +1.000 untuk valas, serta Rp50K, Rp100K, Rp500K, Rp1jt untuk IDR) guna memudahkan perhitungan cepat.
    *   **100% Offline-Safe**: Menggunakan data cache lokal terakhir yang tersimpan di `SharedPreferences` sehingga kalkulasi berjalan instan tanpa bergantung koneksi internet.
    *   **Antarmuka Keyboard-Safe**: Lembar modal bottom sheet yang didesain secara adaptif dengan `AnimatedPadding` dan `SingleChildScrollView` untuk memastikan 0% bug keyboard overlap.
*   **Kompleksitas**: Rendah (Low)

### [/] Manajemen Dompet Multi-Mata Uang (*Multi-Currency Wallet*)
*   **Status**: **SEDANG DALAM PENGEMBANGAN (UI & pilihan valas dinonaktifkan sementara untuk proteksi stabilitas saldo)**
*   **Deskripsi**: Memperluas sistem multi-dompet aplikasi agar mendukung saldo dalam mata uang asing (misalnya saldo USD di Wise, cash SGD, dll.).
*   **Strategi Implementasi**:
    *   Menambahkan kolom `currency_code` (default 'IDR') pada skema tabel dompet di basis data Supabase.
    *   Mengintegrasikan kalkulasi reaktif di dasbor utama di mana saldo dompet ber-valas asing otomatis dikonversi ke IDR menggunakan nilai kurs terupdate untuk menghitung total kekayaan bersih secara real-time.
*   **Kompleksitas**: Sedang (Medium)

### [ ] Alarm Notifikasi Target Kurs (*Forex Price Alert*)
*   **Deskripsi**: Layanan alarm reaktif di mana pengguna dapat menentukan ambang batas target nilai kurs mata uang asing tertentu.
*   **Strategi Implementasi**:
    *   Menambahkan antarmuka bagi pengguna untuk mendaftarkan target alarm (misal: alarm ketika USD turun di bawah Rp16.000 atau JPY turun di bawah Rp98).
    *   Mengecek kondisi target harga saat proses auto-sync latar belakang berjalan setiap 1 jam, dan memicu notifikasi lokal reaktif di bilah status bar jika target terlampaui.
*   **Kompleksitas**: Sedang (Medium)

### [x] Asisten Keuangan Pintar Interaktif (*AI Financial Advisor - McdAI*)
*   **Status**: **SELESAI (v2.3.0)**
*   **Deskripsi**: Fasilitas obrolan interaktif (*chatbot*) premium minimalis Charcoal/Off-white di mana pengguna bisa berdiskusi langsung mengenai kondisi kesehatan keuangannya dengan McdAI yang ditenagai oleh Groq API (LLaMA 3.3 70B).
*   **Hasil Implementasi**:
    *   **Akses Anggaran & Tabungan Real-Time**: AI secara cerdas dibekali konteks data keuangan pengguna secara lengkap (total kekayaan bersih, saldo aktif per dompet, batas anggaran aktif, target tabungan, dan 15 transaksi mutasi terakhir) untuk analisis finansial yang komprehensif.
    *   **Dashboard FAB Integration**: Akses AI diletakkan pada Floating Action Button melambung dengan ikon sparkles minimalis di layar dasbor utama, selaras dengan FAB anggaran.
    *   **Desain Premium Black/Off-white & Centered Title**: Antarmuka lembar obrolan minimalis dengan skema warna Charcoal & Off-white premium, bilah judul tengah, dan tombol navigasi kembali berupa ikon panah kiri `<` minimalis.
    *   **AI Warning Disclaimer**: Penambahan pesan peringatan *"McdAI dapat membuat kesalahan. Harap verifikasi informasi penting."* di bawah kolom input obrolan demi akurasi informasi.
    *   **Pembersihan Sesi Otomatis**: Riwayat chat otomatis dibersihkan saat screen ditutup untuk keamanan privasi data keuangan pengguna.
*   **Kompleksitas**: Sedang (Medium)

### [x] Klasifikasi Kategori Transaksi Cerdas (*AI Smart Auto-Categorization*)
*   **Status**: **SELESAI (v1.0.0)**
*   **Deskripsi**: Pengisian otomatis kategori transaksi secara instan berbasis AI semantik saat pengguna mengetik deskripsi transaksi secara manual.
*   **Hasil Implementasi**:
    *   **Hibrida Cerdas**: Mengintegrasikan analisis hibrida cepat: pencocokan lokal dengan engine regex yang dinamis, didukung panggilan asinkron ke Groq Cloud API (llama-3.3-70b-versatile) untuk pemahaman kalimat semantik yang deterministik (temperature 0.1, response format JSON).
    *   **Debouncer Waktu**: Memasang debouncer 800ms pada masukan teks catatan/deskripsi transaksi agar mencegah banjir request API saat pengguna masih aktif mengetik.
    *   **Premium Visual Sparkles**: Menambahkan pil lencana visual Charcoal Sparkles premium ("AI") di dekat judul kategori serta stempel status informatif ("Kategori dipilih otomatis oleh AI") di bawah dropdown picker kategori.
    *   **Smart Manual Override**: Membatalkan status AI secara halus jika pengguna memutuskan untuk mengubah atau memilih kategori lain secara manual.
*   **Kompleksitas**: Sedang (Medium)

### [x] Kustomisasi Ambang Batas Alarm Anggaran (*Custom Budget Alert Threshold*)
*   **Status**: **SELESAI (v2.4.0)**
*   **Deskripsi**: Memberikan fleksibilitas penuh bagi pengguna untuk mengatur sendiri pada persentase berapa alarm/notifikasi limit anggaran bulanan mulai dipicu dengan sistem pemilihan multi-select (bisa memilih lebih dari satu dari opsi 50%, 70%, dan 90%).
*   **Hasil Implementasi**:
    *   **Pill Selector Multi-Select**: Menampilkan 3 tombol pil persentase reaktif (50%, 70%, 90%) di halaman Pengaturan (*Settings*) dengan getaran haptic taktil dan penyimpanan persentase dinamis terintegrasi di *SharedPreferences* lokal.
    *   **Logic Pencegah Duplikasi Notifikasi**: Algoritma reaktif yang membandingkan saldo mutasi saat ini vs sebelum transaksi (`previousSpent`) untuk mendeteksi momentum penembusan ambang batas secara presisi agar tidak memicu notifikasi berulang-ulang.
    *   **Notifikasi Pengeluaran Maksimal 100% Permanen**: Notifikasi saat pengeluaran melampaui batas anggaran (>= 100%) didesain selalu aktif (*fixed/always on*) demi menjaga keamanan dan perlindungan finansial pengguna tanpa dipengaruhi opsi setting warning yang dimatikan.
*   **Kompleksitas**: Sedang (Medium)

---

## 3. Mesin Rekonsiliasi Transaksi Pintar (*Cross-Wallet Smart Reconciliation*)

Untuk menghindari **pencatatan ganda (*double-counting*)** ketika pengguna memindahkan uang antar-rekening milik sendiri (misalnya transfer dari BNI ke GoPay, atau sebaliknya), McdWallet akan dilengkapi dengan **Smart Reconciliation Engine** yang bekerja di latar belakang.

### [ ] Sistem Rekonsiliasi Aliran Transfer Antar-Dompet
*   **Mekanisme Kerja**:
    1. **Skenario A: Transfer BNI wondr ke GoPay (Top-Up)**
       * *Deteksi Debit BNI*: Sistem membaca email dari `wondr@bni.co.id` yang menyatakan ada *debit keluar* sebesar Rp100.000 untuk transfer ke VA GoPay.
       * *Deteksi Kredit GoPay*: Listener mendeteksi notifikasi masuk dari `com.gojek.app` berupa *saldo bertambah* sebesar Rp100.000 (atau Rp99.000 setelah dipotong biaya admin).
       * *Pencocokan Rekonsiliasi*: Sistem secara otomatis membandingkan timestamp kedua kejadian. Jika selisih waktu `< 3 menit` dan nominal dasar cocok, kedua mutasi tersebut **TIDAK** dicatat sebagai 1 Pengeluaran BNI + 1 Pemasukan GoPay secara terpisah.
       * *Penyatuan Data (Merge)*: Kedua entri disatukan menjadi **1 Transaksi Transfer** tunggal (Dari: Dompet BNI -> Ke: Dompet GoPay) dengan nominal bersih Rp100.000, serta otomatis mencatat selisih (misal Rp1.000) sebagai biaya admin pengeluaran terpisah.
    2. **Skenario B: Penarikan Saldo GoPay ke BNI wondr (Cashout)**
       * *Deteksi Debit GoPay*: Listener mendeteksi notifikasi pengeluaran GoPay sebesar Rp50.000 dengan tujuan BNI.
       * *Deteksi Kredit BNI*: Sistem mendeteksi email masuk dari `wondr@bni.co.id` berupa transfer masuk (kredit) sebesar Rp50.000.
       * *Penyatuan Data (Merge)*: Otomatis terkonversi menjadi **1 Transaksi Transfer** tunggal (Dari: Dompet GoPay -> Ke: Dompet BNI) bernominal Rp50.000.
*   **Keunggulan Sistem**:
    *   **Akurasi Saldo 100%**: Menjamin grafik total pengeluaran dan pemasukan bulanan tetap akurat tanpa tergelembung oleh aktivitas pemindahan saldo sendiri.
    *   **Otomatisasi Penuh**: Pengguna tidak perlu menghapus secara manual atau mengubah tipe transaksi secara berulang.
*   **Kompleksitas**: Tinggi (High)
