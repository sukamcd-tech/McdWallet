# Rencana Fitur Pro & Bisnis (McdWallet Pro Features Plan)

Dokumen ini berisi rencana komprehensif, arsitektur sistem, dan backlog pengembangan untuk fitur-fitur premium **McdWallet Pro & Bisnis**. Paket Pro ditargetkan bagi kalangan freelancer, profesional, pemilik usaha kecil (UMKM), serta pengguna yang membutuhkan kolaborasi pembukuan multi-pengguna.

---

## 1. Perbandingan Fitur: Personal vs. Pro & Bisnis

| Fitur | Personal Plan (Free) | Pro & Bisnis Plan (Premium) |
| :--- | :--- | :--- |
| **Pencatatan Keuangan** | Penuh & Tanpa Batas (Dompet, Anggaran, Tabungan pribadi) | Penuh & Tanpa Batas |
| **Kolaborasi (Dompet Bersama)** | Tidak Tersedia (Hanya Lokal/Milik Sendiri) | **Tersedia (Shared Wallets / Collaborative)** |
| **Pemisahan Kas (Tagging)** | Semua transaksi digabung | **Pemisahan Kategori "Bisnis" & "Personal"** |
| **Jenis Laporan** | Grafik Standar & Ringkasan Teks | **Laporan Keuangan Profesional (PDF & Excel)** |
| **Multi-Mata Uang (Valas)** | Hanya IDR (Mata Uang Lokal) | **Dukungan Penuh Valas (Multi-Currency)** |
| **Invoice / Tanda Terima** | Tidak Tersedia | **Pembuat Invoice & Resi Digital** |
| **Asisten Keuangan AI** | Mode Konsultan Keuangan Pribadi | **Mode Analis Keuangan Bisnis & Proyeksi Cashflow** |

---

## 2. Rincian Fitur Premium Pro & Bisnis

### A. Dompet Bersama (Collaboration / Shared Wallet)
*   **Fungsionalitas**: Kolaborasi pembukuan secara real-time bersama pasangan, anggota keluarga, atau rekan bisnis. Setiap perubahan transaksi akan langsung tersinkronisasi ke seluruh perangkat anggota dompet.
*   **Strategi Arsitektur (Supabase Realtime)**:
    *   Membuat tabel relasi `wallet_members` untuk memetakan hak akses multi-user pada satu dompet:
        ```sql
        CREATE TABLE public.wallet_members (
          id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
          wallet_id uuid REFERENCES public.wallets(id) ON DELETE CASCADE NOT NULL,
          member_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
          role text CHECK (role IN ('viewer', 'editor')) DEFAULT 'editor' NOT NULL,
          created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
          UNIQUE (wallet_id, member_id)
        );
        ```
    *   Menerapkan **Row Level Security (RLS)** di Supabase untuk mengizinkan anggota membaca dan menulis transaksi di dompet terkait.
    *   Mengaktifkan channel **Supabase Realtime** pada tabel `transactions` untuk menangkap pembaruan instan di layar dashboard pengguna lain.

### B. Pemisahan Kas (Tagging Bisnis vs. Personal)
*   **Fungsionalitas**: Membantu pelaku UMKM dan freelancer memisahkan pengeluaran rumah tangga dengan modal usaha dalam satu akun tanpa perlu membuat akun terpisah.
*   **Strategi Arsitektur**:
    *   Menambahkan kolom boolean `is_business` di tabel `transactions` Supabase:
        ```sql
        ALTER TABLE public.transactions ADD COLUMN is_business boolean DEFAULT false NOT NULL;
        ```
    *   Menyediakan tombol toggle / sakelar minimalis di layar *Add/Edit Transaction* untuk menandai transaksi sebagai transaksi bisnis.
    *   Menyaring grafik pengeluaran bulanan agar pengguna dapat melihat grafik khusus pengeluaran personal, khusus usaha, atau gabungan keduanya.

### C. Laporan Akuntansi Profesional (P&L & General Ledger)
*   **Fungsionalitas**: Menyediakan berkas siap cetak untuk keperluan pelaporan pajak, pembukuan internal, atau pengajuan kredit modal ke bank.
*   **Strategi Arsitektur**:
    *   **Ekspor PDF (Profit & Loss / Laba Rugi)**: Menggunakan package `pdf` Flutter untuk merancang lembar Laba Rugi bersih, mengelompokkan pemasukan operasional, biaya pengeluaran (HPP, utilitas, sewa, gaji), serta laba kotor dan laba bersih.
    *   **Ekspor Excel (General Ledger / Buku Besar)**: Menggunakan package `excel` Flutter untuk menghasilkan berkas `.xlsx` terstruktur yang mencantumkan seluruh riwayat mutasi transaksi secara urut per tanggal, lengkap dengan formula saldo kumulatif otomatis.

### D. Manajemen Multi-Mata Uang & Valas (Multi-Currency)
*   **Fungsionalitas**: Memfasilitasi freelancer yang menerima pembayaran dalam valuta asing (seperti USD, SGD, JPY, EUR) dengan konversi otomatis ke mata uang utama (IDR) berdasarkan kurs terbaru.
*   **Strategi Arsitektur**:
    *   Menambahkan kolom `currency_code` (default 'IDR') pada skema tabel `wallets`.
    *   Menghubungkan aplikasi dengan API penyedia kurs valas real-time untuk memperbarui nilai tukar di database lokal secara berkala.
    *   Mengintegrasikan kalkulasi reaktif di dasbor utama di mana saldo dompet valas asing otomatis dikonversi ke IDR menggunakan nilai kurs terupdate guna menghitung total kekayaan bersih secara akurat.

### E. Pembuat Invoice & Resi Digital
*   **Fungsionalitas**: Membuat faktur penagihan profesional langsung dari dalam aplikasi dan mengirimkannya kepada klien via WhatsApp atau Email sebagai berkas PDF/Gambar.
*   **Strategi Arsitektur**:
    *   Menyediakan formulir input berisi data merchant, nama klien, rincian barang/jasa, kuantitas, harga, dan instruksi rekening pembayaran.
    *   Merender invoice menggunakan layout *clean minimalist* (Charcoal/Off-white) dan menyimpannya sebagai berkas PDF lokal atau langsung membagikannya via plugin `share_plus`.

### F. Analis Keuangan AI Bisnis (McdAI Pro)
*   **Fungsionalitas**: Asisten cerdas (McdAI) beralih peran menjadi konsultan bisnis yang menganalisis arus kas bulanan usaha, menghitung *Burn Rate* modal, memproyeksikan laba rugi di kuartal berikutnya, dan memberikan rekomendasi taktis efisiensi biaya operasional.
*   **Strategi Arsitektur**:
    *   Mengirimkan instruksi sistem (*system prompt*) khusus ke Groq/Gemini API yang menyematkan laporan rekapitulasi pengeluaran dan pemasukan bisnis pengguna dalam format terstruktur JSON.
    *   Menampilkan rekomendasi AI dalam format interaktif Markdown pada lembar obrolan McdAI Pro.

---

## 3. Sistem Pembayaran & Verifikasi Instan (Integrasi Xendit)

Untuk mengaktifkan paket Premium Pro & Bisnis, McdWallet mengintegrasikan gerbang pembayaran **Xendit** secara native (di dalam aplikasi):

### A. Metode Pembayaran yang Didukung
1.  **QRIS Dynamic**: Menghasilkan gambar kode QR dinamis yang dapat di-scan menggunakan GoPay, OVO, Dana, LinkAja, ShopeePay, dan aplikasi Mobile Banking (BCA, Mandiri, dll.).
2.  **Virtual Account (VA)**: Menyediakan nomor rekening unik pembayaran untuk transfer bank (Mandiri, BCA, BRI, BNI) lengkap dengan instruksi transfer ATM dan M-Banking.

### B. Simulasi Pembayaran & Pembaruan Status (Sandbox & Production)
*   Aplikasi dilengkapi dengan tombol simulasi sukses bayar untuk kebutuhan testing/sandbox.
*   **Perpanjangan Kumulatif (Subscription Renewal)**:
    *   Jika pengguna berstatus *Free*, pembelian paket baru (Bulanan = 30 hari, Tahunan = 365 hari) akan mulai berlaku dari waktu saat ini (`DateTime.now()`).
    *   Jika pengguna berstatus *Pro Aktif*, durasi paket baru akan ditambahkan langsung secara kumulatif ke sisa hari paket aktif sebelumnya (`subscriptionExpiresAt + durasi baru`) tanpa memotong sisa hari yang sudah dibayar.
*   **Pembatalan Aman (Terms & Conditions Bottom Sheet)**:
    *   Akses pembatalan dilindungi oleh Bottom Sheet interaktif berisi Ketentuan Pembatalan.
    *   Tombol konfirmasi dan kotak centang persetujuan terkunci rapat hingga pengguna menggulir (*scroll*) teks ketentuan hingga batas terbawah (*scroll-to-bottom validation*).
    *   Sukses pembatalan dikonfirmasi dengan SnackBar hijau sukses (`AppColors.success`), dan status akun segera dikembalikan ke Personal (Gratis) untuk kenyamanan siklus pengujian.
