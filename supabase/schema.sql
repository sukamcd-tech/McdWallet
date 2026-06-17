-- SUPABASE DATABASE SCHEMA FOR MCDWALLET
-- Jalankan script ini di SQL Editor pada Supabase Dashboard Anda.

-- ========================================================
-- 1. TABEL: profiles
-- ========================================================
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  updated_at timestamp with time zone,
  username text unique,
  full_name text,
  avatar_url text,
  currency text default 'IDR' not null,
  subscription_tier text default 'free' check (subscription_tier in ('free', 'pro')) not null,
  subscription_status text default 'inactive' check (subscription_status in ('active', 'inactive', 'canceled', 'past_due')) not null,
  subscription_expires_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Mengaktifkan Row Level Security (RLS)
alter table public.profiles enable row level security;

-- Kebijakan RLS (Policies)
create policy "User dapat melihat profil mereka sendiri"
  on public.profiles for select
  using (auth.uid() = id);

create policy "User dapat memperbarui profil mereka sendiri"
  on public.profiles for update
  using (auth.uid() = id);

-- ========================================================
-- 2. TABEL: wallets (Rekening / Dompet)
-- ========================================================
create table public.wallets (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  balance numeric(15, 2) default 0.00 not null,
  color text default '#4CAF50' not null, -- Hex warna (misal: #4CAF50)
  icon text default 'account_balance_wallet' not null,  -- Nama icon material
  currency_code text default 'IDR' not null,            -- Kode mata uang dasar dompet (e.g., IDR, USD)
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.wallets enable row level security;

create policy "User dapat melihat dompet mereka sendiri"
  on public.wallets for select
  using (auth.uid() = user_id);

create policy "User dapat menambah dompet mereka sendiri"
  on public.wallets for insert
  with check (auth.uid() = user_id);

create policy "User dapat mengubah dompet mereka sendiri"
  on public.wallets for update
  using (auth.uid() = user_id);

create policy "User dapat menghapus dompet mereka sendiri"
  on public.wallets for delete
  using (auth.uid() = user_id);

-- ========================================================
-- 3. TABEL: categories (Kategori Pengeluaran/Pemasukan)
-- ========================================================
create table public.categories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  type text check (type in ('income', 'expense')) not null,
  color text default '#607D8B' not null,
  icon text default 'category' not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.categories enable row level security;

create policy "User dapat melihat kategori mereka sendiri"
  on public.categories for select
  using (auth.uid() = user_id);

create policy "User dapat menambah kategori mereka sendiri"
  on public.categories for insert
  with check (auth.uid() = user_id);

create policy "User dapat mengubah kategori mereka sendiri"
  on public.categories for update
  using (auth.uid() = user_id);

create policy "User dapat menghapus kategori mereka sendiri"
  on public.categories for delete
  using (auth.uid() = user_id);

-- ========================================================
-- 4. TABEL: transactions (Mutasi Keuangan)
-- ========================================================
create table public.transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  wallet_id uuid references public.wallets(id) on delete restrict not null,
  category_id uuid references public.categories(id) on delete restrict, -- Null jika tipe = 'transfer'
  amount numeric(15, 2) not null check (amount > 0),
  amount_in_idr numeric(15, 2),                                         -- Setara Rupiah saat transaksi terjadi (untuk valas)
  target_amount numeric(15, 2),                                         -- Nilai nominal terkonversi yang diterima di dompet tujuan (untuk transfer valas)
  type text check (type in ('income', 'expense', 'transfer')) not null,
  description text,
  date timestamp with time zone default timezone('utc'::text, now()) not null,
  attachment_path text, -- Path gambar nota di Supabase Storage
  to_wallet_id uuid references public.wallets(id) on delete restrict, -- Hanya terisi jika type = 'transfer'
  admin_fee numeric(15, 2) default 0.00, -- Biaya admin transfer
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.transactions enable row level security;

create policy "User dapat melihat transaksi mereka sendiri"
  on public.transactions for select
  using (auth.uid() = user_id);

create policy "User dapat menambah transaksi mereka sendiri"
  on public.transactions for insert
  with check (auth.uid() = user_id);

create policy "User dapat mengubah transaksi mereka sendiri"
  on public.transactions for update
  using (auth.uid() = user_id);

create policy "User dapat menghapus transaksi mereka sendiri"
  on public.transactions for delete
  using (auth.uid() = user_id);

-- ========================================================
-- 5. TABEL: budgets (Batas Pengeluaran Maksimum)
-- ========================================================
create table public.budgets (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  category_id uuid references public.categories(id) on delete cascade, -- Null berarti anggaran global bulanan
  amount_limit numeric(15, 2) not null check (amount_limit > 0),
  period text check (period in ('weekly', 'monthly', 'yearly')) default 'monthly' not null,
  start_date date not null,
  end_date date not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.budgets enable row level security;

create policy "User dapat melihat anggaran mereka sendiri"
  on public.budgets for select
  using (auth.uid() = user_id);

create policy "User dapat menambah anggaran mereka sendiri"
  on public.budgets for insert
  with check (auth.uid() = user_id);

create policy "User dapat mengubah anggaran mereka sendiri"
  on public.budgets for update
  using (auth.uid() = user_id);

create policy "User dapat menghapus anggaran mereka sendiri"
  on public.budgets for delete
  using (auth.uid() = user_id);

-- ========================================================
-- 6. AUTOMATION: Trigger Registrasi Baru & Seeding Kategori
-- ========================================================

-- Trigger function yang otomatis berjalan ketika user baru melakukan registrasi di Supabase Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  -- 1. Masukkan data ke profile publik
  insert into public.profiles (id, username, full_name, avatar_url, currency)
  values (
    new.id,
    new.raw_user_meta_data->>'username',
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'username', 'User Baru'),
    new.raw_user_meta_data->>'avatar_url',
    coalesce(new.raw_user_meta_data->>'currency', 'IDR')
  );

  -- 2. Seeding Kategori Pemasukan Bawaan Indonesia
  insert into public.categories (user_id, name, type, color, icon) values
    (new.id, 'Gaji', 'income', '#4CAF50', 'payments'),
    (new.id, 'Investasi', 'income', '#00BCD4', 'trending_up'),
    (new.id, 'Uang Saku', 'income', '#FFEB3B', 'account_balance_wallet'),
    (new.id, 'Freelance', 'income', '#9C27B0', 'work');

  -- 3. Seeding Kategori Pengeluaran Bawaan Indonesia
  insert into public.categories (user_id, name, type, color, icon) values
    (new.id, 'Makanan & Minuman', 'expense', '#FF5722', 'restaurant'),
    (new.id, 'Transportasi', 'expense', '#03A9F4', 'directions_car'),
    (new.id, 'WiFi & Internet', 'expense', '#3F51B5', 'wifi'),
    (new.id, 'Kos & Rumah', 'expense', '#E91E63', 'home'),
    (new.id, 'Belanja & Hiburan', 'expense', '#9C27B0', 'shopping_bag'),
    (new.id, 'Kesehatan', 'expense', '#E91E63', 'medical_services'),
    (new.id, 'Lainnya', 'expense', '#607D8B', 'more_horiz');

  -- 4. Seeding Dompet Bawaan (Uang Tunai)
  insert into public.wallets (user_id, name, balance, color, icon) values
    (new.id, 'Uang Tunai', 0.00, '#4CAF50', 'money');

  return new;
end;
$$ language plpgsql security definer;

-- Trigger function untuk otomatis konfirmasi email bagi user baru di Supabase Auth
create or replace function public.handle_auto_confirm_email()
returns trigger as $$
begin
  new.email_confirmed_at := now();
  new.confirmed_at := now();
  return new;
end;
$$ language plpgsql security definer;

-- Daftarkan trigger BEFORE INSERT ke auth.users untuk otomatis konfirmasi email
drop trigger if exists on_auth_user_created_confirm on auth.users;
create trigger on_auth_user_created_confirm
  before insert on auth.users
  for each row execute procedure public.handle_auto_confirm_email();

-- Daftarkan trigger ke auth.users untuk profiles & seeding
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ========================================================
-- 7. OTOMATISASI UPDATE SALDO DOMPET (DATABASE TRIGGERS)
-- ========================================================

-- Trigger function untuk memperbarui balance wallet ketika ada transaksi baru
create or replace function public.update_wallet_balance()
returns trigger as $$
begin
  -- Pengeluaran: Kurangi saldo
  if new.type = 'expense' then
    update public.wallets
    set balance = balance - new.amount
    where id = new.wallet_id;
  
  -- Pemasukan: Tambah saldo
  elseif new.type = 'income' then
    update public.wallets
    set balance = balance + new.amount
    where id = new.wallet_id;
  
  -- Transfer: Kurangi saldo dompet asal (nominal + biaya admin), tambah saldo dompet tujuan (menggunakan target_amount terkonversi)
  elseif new.type = 'transfer' and new.to_wallet_id is not null then
    update public.wallets
    set balance = balance - (new.amount + coalesce(new.admin_fee, 0))
    where id = new.wallet_id;

    update public.wallets
    set balance = balance + coalesce(new.target_amount, new.amount)
    where id = new.to_wallet_id;
  end if;
  
  return new;
end;
$$ language plpgsql security definer;

create trigger on_transaction_inserted
  after insert on public.transactions
  for each row execute procedure public.update_wallet_balance();

-- Trigger function untuk menangani perubahan jika transaksi dihapus (roll back balance)
create or replace function public.rollback_wallet_balance()
returns trigger as $$
begin
  if old.type = 'expense' then
    update public.wallets
    set balance = balance + old.amount
    where id = old.wallet_id;
  
  elseif old.type = 'income' then
    update public.wallets
    set balance = balance - old.amount
    where id = old.wallet_id;
  
  elseif old.type = 'transfer' and old.to_wallet_id is not null then
    update public.wallets
    set balance = balance + (old.amount + coalesce(old.admin_fee, 0))
    where id = old.wallet_id;

    update public.wallets
    set balance = balance - coalesce(old.target_amount, old.amount)
    where id = old.to_wallet_id;
  end if;
  
  return old;
end;
$$ language plpgsql security definer;

create trigger on_transaction_deleted
  after delete on public.transactions
  for each row execute procedure public.rollback_wallet_balance();

-- ========================================================
-- 8. STORAGE: Konfigurasi Bucket & Kebijakan RLS (receipts)
-- ========================================================

-- Jalankan bagian ini untuk membuat bucket 'receipts' secara otomatis via SQL jika belum dibuat.
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

-- RLS untuk Bucket Objects
-- Catatan: RLS pada storage.objects biasanya sudah aktif secara default di Supabase.
alter table storage.objects enable row level security;

-- Kebijakan RLS 1: Mengizinkan user yang terautentikasi untuk mengunggah berkas ke foldernya sendiri (auth.uid())
create policy "User dapat mengunggah struk mereka sendiri"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

-- Kebijakan RLS 2: Mengizinkan semua orang melihat struk belanja menggunakan Public URL
create policy "Semua orang dapat melihat struk belanja"
  on storage.objects for select
  to public
  using (bucket_id = 'receipts');

-- Kebijakan RLS 3: Mengizinkan user menghapus struk belanja milik mereka sendiri
create policy "User dapat menghapus struk mereka sendiri"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

-- ========================================================
-- 9. TABEL: savings_goals (Target Tabungan)
-- ========================================================
create table if not exists public.savings_goals (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  name text not null,
  target_amount numeric(15, 2) not null check (target_amount > 0),
  current_amount numeric(15, 2) default 0.00 not null,
  target_date date,
  color text default '#FF9500' not null,
  icon text default 'savings' not null,
  saving_interval text check (saving_interval in ('custom', 'daily', 'weekly', 'monthly')) default 'custom' not null,
  saving_amount_per_interval numeric(15, 2) default 0.00 not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.savings_goals enable row level security;

-- Drop policies if exist to prevent duplicate errors on schema rerun
drop policy if exists "User dapat melihat target tabungan mereka sendiri" on public.savings_goals;
create policy "User dapat melihat target tabungan mereka sendiri"
  on public.savings_goals for select
  using (auth.uid() = user_id);

drop policy if exists "User dapat menambah target tabungan mereka sendiri" on public.savings_goals;
create policy "User dapat menambah target tabungan mereka sendiri"
  on public.savings_goals for insert
  with check (auth.uid() = user_id);

drop policy if exists "User dapat mengubah target tabungan mereka sendiri" on public.savings_goals;
create policy "User dapat mengubah target tabungan mereka sendiri"
  on public.savings_goals for update
  using (auth.uid() = user_id);

drop policy if exists "User dapat menghapus target tabungan mereka sendiri" on public.savings_goals;
create policy "User dapat menghapus target tabungan mereka sendiri"
  on public.savings_goals for delete
  using (auth.uid() = user_id);
