# McdWallet — Deskripsi Proyek

McdWallet adalah aplikasi manajemen keuangan pribadi (*personal finance manager*) berbasis mobile yang dirancang untuk membantu pengguna mengelola transaksi keuangan, memantau batas anggaran, menganalisis arus kas melalui grafik interaktif, serta menyimpan data secara aman.

Aplikasi ini merupakan proyek **portfolio / indie project** yang dikembangkan secara mandiri di bawah ekosistem merek **"SukaMCD"** (bersama McdHub, platform web berbasis Next.js). Bukan merupakan proyek beasiswa, tugas akademik, maupun penugasan korporat. Rilis stabil pertama (v1.0.0) diterbitkan pada **3 Juni 2026** dengan pengembangan aktif berkelanjutan.

---

## Dibuat Pake Apa (Teknologi)

| Lapisan | Teknologi |
|---|---|
| **Framework** | Flutter (Dart SDK ^3.11.5) |
| **State Management** | Riverpod (`flutter_riverpod`) |
| **Backend / Database** | Supabase (PostgreSQL + Storage + Auth) |
| **Autentikasi** | Supabase Auth + Google Sign-In |
| **Notifikasi Push** | Firebase Cloud Messaging + `flutter_local_notifications` |
| **AI / LLM** | Groq API (LLaMA 3.3 70B), Google Gemini API (`gemini-1.5-flash`) |
| **ML On-Device** | Google ML Kit Text Recognition (OCR) |
| **Grafik** | `fl_chart` |
| **Keamanan Biometrik** | `local_auth` (sidik jari / pengenalan wajah) |
| **Penyimpanan Lokal** | `SharedPreferences` |
| **Kompresi Gambar** | `flutter_image_compress` |
| **Ikon** | Lucide Icons, Font Awesome |
| **Font** | Google Fonts |
| **Animasi** | `flutter_animate` |

**Arsitektur**: Struktur modular berbasis fitur (`core/`, `features/`) dengan 74 berkas Dart yang terorganisasi ke dalam:

- `core/` — provider bersama, layanan, widget, tema, utilitas
- `features/` — `ai_advisor`, `auth`, `budgets`, `dashboard`, `forex`, `savings`, `transactions`

---

## Fungsi Karya (Buat Apa)

McdWallet berfungsi sebagai **asisten keuangan pribadi digital** yang membantu pengguna:

- **Mencatat** setiap transaksi keuangan (pemasukan, pengeluaran, transfer antar-dompet)
- **Memantau** batas anggaran bulanan agar tidak boros
- **Menganalisis** pola pengeluaran melalui grafik interaktif
- **Mengamankan** data finansial dengan PIN, biometrik, dan auto-lock
- **Menyimpan** bukti struk/nota belanja secara digital
- **Memindai** struk kasir otomatis menggunakan AI sehingga tidak perlu mengetik manual
- **Memantau** kurs mata uang asing secara real-time
- **Mendapatkan rekomendasi** keuangan personal dari asisten AI

---

## Fitur Utama (10 Modul Besar)

### 1. Manajemen Transaksi Mutasi (CRUD)
- Pencatatan terpadu untuk **Pemasukan, Pengeluaran, dan Transfer** dalam satu form
- **Biaya admin transfer** antar-dompet
- **Upload lampiran struk** ke Supabase Storage dengan kompresi otomatis (maks 1080p, kualitas adaptif 35-80%, target 300-500 KB)
- **Swipe-to-delete** dengan pemulihan saldo otomatis (*rollback*)

### 2. Dasbor Analitik Keuangan
- **Grafik Arus Kas (Cashflow Line Chart)** — diagram garis ganda melengkung untuk tren pemasukan vs pengeluaran
- **Diagram Lingkaran Pengeluaran (Expense Pie Chart)** — distribusi pengeluaran per kategori beserta persentase
- **Filter periode** — 7 hari terakhir, bulan berjalan, atau keseluruhan

### 3. Sistem Pemantauan Anggaran (Budgeting)
- Pembuatan **batas anggaran bulanan** per kategori pengeluaran
- **Indikator warna dinamis** — Hijau (aman) → Kuning (peringatan) → Merah (terlampaui)
- **Notifikasi alarm** saat pengeluaran melampaui batas anggaran
- **Ambang batas kustom** (50%, 70%, 90%) via tombol pil multi-select
- Notifikasi 100% over-budget bersifat permanen (tidak bisa dimatikan)

### 4. Multi-Dompet & Saldo Historis
- Dukungan **banyak dompet** (Tunai, Bank, e-Wallet, dll.)
- Perhitungan **saldo awal & saldo akhir** bulanan menggunakan sistem *rollback* historis
- Ikon transaksi berkode warna: Hijau (pemasukan), Merah (pengeluaran), Abu-abu (transfer)
- **Dompet multi-mata uang** (sedang dalam pengembangan — dinonaktifkan sementara)

### 5. Keamanan & Privasi Berlapis
- **Kode PIN** wajib saat pertama kali daftar dan setiap buka aplikasi
- **Autentikasi biometrik** (sidik jari / pengenalan wajah via `local_auth`)
- **Auto-lock** otomatis setelah 3 menit di latar belakang (`WidgetsBindingObserver`)
- **Penutup layar privasi** — menyembunyikan konten di app switcher/recents menu
- **Sakelar master keamanan** — matikan semua pengaman sekaligus jika diinginkan
- **Pembersihan sesi otomatis** — riwayat chat AI terhapus saat keluar dari layar

### 6. Ekspor Laporan Finansial
- **Ekspor CSV** — kompatibel dengan Microsoft Excel / Google Sheets
- **Ringkasan teks indah** — format rapi siap salin ke WhatsApp

### 7. Pemindai Struk Otomatis (OCR Receipt Scanner)
- **Pipeline hibrida multi-LLM**: Groq (LLaMA 3.3 70B) utama (~100ms) → Gemini fallback → Google ML Kit offline
- **Filter noise cerdas** — menghapus teks status bar (baterai, jam, kecepatan internet) dan UI media sosial
- **Koreksi angka ribuan** — merekonstruksi angka terpotong OCR (contoh: `25.00` → `25.000`)
- **Pengisian form otomatis** — mengisi nominal, nama toko, tanggal, dan melampirkan foto struk

### 8. Pemantau Kurs Asing (Forex Monitoring)
- **Kartu carousel horizontal** bergaya Wise/Revolut di dasbor utama
- **API publik tanpa kunci** via `open.er-api.com` (stabilitas 100%, tanpa risiko habis limit)
- **Caching pintar** — TTL 1 jam via `SharedPreferences`, cooldown refresh manual 5 menit
- **Hingga 5 mata uang favorit** dengan pencarian dan seleksi dinamis
- **Kalkulator konversi valas** terintegrasi — konversi dua arah real-time dengan preset nilai cepat

### 9. Klasifikasi Kategori Cerdas (AI Auto-Categorization)
- **Hibrida lokal + cloud**: Pencocokan regex keyword (offline, instan) + Groq API (pemahaman semantik)
- **Debouncer 800ms** mencegah spam request API saat mengetik
- **Smart manual override** — lencana AI hilang jika pengguna mengubah kategori secara manual
- **Indikator visual** — label "Kategori dipilih otomatis oleh AI" di bawah dropdown

### 10. Asisten Keuangan Pintar (McdAI Advisor)
- **Chatbot interaktif** ditenagai Groq (LLaMA 3.3 70B)
- **Konteks finansial lengkap** — total kekayaan bersih, saldo per dompet, anggaran aktif, target tabungan, 15 transaksi terakhir
- **Floating Action Button** di dasbor dengan ikon sparkles
- **Pembersihan sesi otomatis** untuk keamanan privasi
- **Disclaimer AI** — peringatan verifikasi informasi penting

---

## Fitur UX Tambahan

- **Getaran taktil konfigurabel** — sakelar global di Pengaturan
- **Efek memuat shimmer premium** — placeholder berdenyut lembut menggantikan spinner
- **Target tabungan** — lacak progres dengan setoran dan interval menabung
- **Login via Google Sign-In**
- **Alur lupa password / reset password**
- **Layar profil & pengaturan** lengkap
- **Lembar umpan balik** untuk masukan pengguna

---

## Skema Database (Supabase PostgreSQL)

6 tabel utama dengan **Row Level Security (RLS)** penuh:

1. `profiles` — data profil pengguna
2. `wallets` — multi-dompet dengan dukungan mata uang
3. `categories` — kategori pemasukan/pengeluaran (auto-seed saat registrasi)
4. `transactions` — catatan mutasi lengkap dengan transfer & biaya admin
5. `budgets` — batas pengeluaran bulanan per kategori
6. `savings_goals` — target tabungan dengan interval

Dilengkapi **database trigger** untuk update saldo otomatis saat insert/delete transaksi dan **auto-seeding** kategori bawaan + dompet default saat pengguna baru mendaftar.

---

## Manfaat Buat Yang Pake

| Manfaat | Penjelasan |
|---|---|
| **Disiplin finansial** | Batas anggaran dengan notifikasi real-time mencegah pengeluaran berlebih |
| **Hemat waktu** | Pemindai struk OCR mengisi data transaksi otomatis tanpa ketik manual |
| **Kesadaran keuangan** | Grafik interaktif mengungkap pola pengeluaran yang tidak disadari |
| **Keamanan data** | PIN + biometrik + auto-lock + penutup privasi melindungi data sensitif |
| **Tangguh offline** | Kategorisasi AI & konverter valas tetap berfungsi tanpa koneksi internet |
| **Insight cerdas** | McdAI memberikan rekomendasi keuangan personal berdasarkan data nyata |
| **Fleksibilitas** | Multi-dompet, multi-kategori, ekspor laporan, dan kustomisasi penuh |

---

## Jenis Proyek

**Proyek portfolio / indie project** — aplikasi produk mobile full-stack yang dikembangkan secara mandiri di bawah merek **SukaMCD**. Bukan proyek beasiswa, tugas kenaikan kelas, maupun penugasan institusi. Merupakan karya pengembang independen yang menunjukkan kemampuan rekayasa perangkat lunak secara menyeluruh: mulai dari desain UI/UX, arsitektur aplikasi, integrasi AI/ML, manajemen database, hingga keamanan berlapis.

---

## Versi & Riwayat

- **v1.0.0** (3 Juni 2026) — Rilis stabil pertama dengan seluruh modul inti
