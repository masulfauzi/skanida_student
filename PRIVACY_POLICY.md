# Kebijakan Privasi - Skanida Student

**Tanggal Berlaku:** Februari 2026

## 1. Pendahuluan

Kebijakan Privasi ini menjelaskan bagaimana aplikasi Skanida Student ("Aplikasi") mengumpulkan, menggunakan, dan melindungi data pribadi pengguna. Kami berkomitmen untuk menjaga privasi dan keamanan data Anda.

## 2. Informasi yang Kami Kumpulkan

Aplikasi Skanida Student mengumpulkan informasi berikut:

### 2.1 Informasi Akun
- Nama pengguna (NISN/Username)
- Kata sandi (disimpan terenkripsi)
- Nama lengkap
- User ID dari sistem sekolah
- Token autentikasi

### 2.2 Data Akademik
- Riwayat presensi siswa
- Data izin meninggalkan kelas
- Riwayat izin (dengan status persetujuan)
- Data presensi sholat
- Riwayat izin sholat

### 2.3 Data Lokasi
- Lokasi geografis (hanya saat pengguna mengaktifkan fitur presensi lokasi)
- Koordinat GPS untuk keperluan presensi

### 2.4 Data Perangkat
- Informasi perangkat (model, versi OS)
- Identifier unik perangkat
- Log aktivitas aplikasi

### 2.5 Token Notifikasi
- Token perangkat dari Firebase Cloud Messaging (FCM), hanya jika Anda login
- Jenis platform perangkat (Android/iOS)
- Token ini disimpan di server sekolah dan dikaitkan dengan akun Anda, semata-mata untuk mengirim notifikasi

## 3. Bagaimana Kami Menggunakan Data

Data yang dikumpulkan digunakan untuk:

- **Autentikasi dan Akses:** Memverifikasi identitas pengguna dan memberikan akses ke fitur aplikasi
- **Manajemen Presensi:** Mencatat dan melacak presensi siswa
- **Manajemen Izin:** Memproses permintaan izin dan menampilkan riwayat izin
- **Pelaporan:** Membuat laporan akademik dan administratif
- **Komunikasi:** Mengirimkan notifikasi status pengajuan izin (disetujui/ditolak) dan pengumuman sekolah
- **Perbaikan Layanan:** Menganalisis penggunaan aplikasi untuk perbaikan berkelanjutan
- **Keamanan:** Mencegah penggunaan yang tidak sah dan melindungi dari ancaman keamanan

## 4. Penyimpanan Data

### 4.1 Penyimpanan Lokal
Data berikut disimpan secara lokal di perangkat Anda menggunakan SharedPreferences:
- Status login
- Token autentikasi
- Riwayat notifikasi yang diterima (maksimal 100 terakhir) beserta status sudah/belum dibaca
- Nama pengguna
- ID pengguna
- Informasi siswa

### 4.2 Penyimpanan Server
Data akademik dan riwayat disimpan di server aplikasi dengan enkripsi:
- Semua komunikasi dengan server menggunakan protokol HTTPS
- Data sensitif terenkripsi

### 4.3 Retensi Data
- Data sesi disimpan selama pengguna terdaftar
- Data akademik disimpan sesuai kebijakan sekolah
- Pengguna dapat menghapus data lokal dengan logout

## 5. Keamanan Data

Kami mengimplementasikan langkah-langkah keamanan berikut:

- **Enkripsi Transportasi:** Semua data ditransmisikan melalui HTTPS
- **Autentikasi Bearer Token:** Setiap permintaan ke API dilindungi dengan token autentikasi
- **Penyimpanan Aman:** Data sensitif disimpan dengan aman di perangkat
- **Akses Terbatas:** Hanya personel yang berwenang yang dapat mengakses data

## 6. Pembagian Data dengan Pihak Ketiga

Kami **tidak membagikan** data pribadi Anda dengan pihak ketiga kecuali:

- Dengan sekolah/institusi pendidikan untuk keperluan administrasi akademik
- Ketika diperlukan oleh hukum atau otoritas pemerintah
- Untuk melindungi hak, privasi, keamanan Anda atau pihak lain

## 7. Layanan Pihak Ketiga

Aplikasi menggunakan layanan pihak ketiga berikut:

- **Google Play Services:** Untuk distribusi aplikasi
- **HTTP Client Library:** Untuk komunikasi dengan server
- **SharedPreferences:** Untuk penyimpanan data lokal
- **Flutter Framework:** Untuk menjalankan aplikasi
- **Firebase Cloud Messaging (Google):** Untuk mengirimkan push notification. Isi notifikasi tidak memuat data sensitif (misalnya alasan izin atau NISN); detail hanya ditampilkan di dalam aplikasi

Kami tidak membagikan data pribadi Anda dengan layanan-layanan ini di luar kebutuhan fungsional.

### 7.1 Notifikasi
- Izin notifikasi bersifat **opsional**. Aplikasi tetap dapat digunakan sepenuhnya tanpa izin ini
- Izin notifikasi diminta saat relevan (misalnya setelah mengajukan izin), bukan saat aplikasi pertama kali dibuka
- Token notifikasi dihapus dari server dan dinonaktifkan di perangkat saat Anda logout
- **Riwayat notifikasi** (menu Notifikasi) disimpan **hanya di perangkat Anda**, terpisah per akun, dan tidak dikirim ke server. Riwayat ikut terhapus bila data aplikasi dihapus atau aplikasi di-uninstall
- Anda dapat mematikan notifikasi kapan saja melalui pengaturan perangkat, termasuk per kategori (Status Izin / Pengumuman Sekolah) di Android

## 8. Hak Pengguna

Sebagai pengguna, Anda memiliki hak untuk:

- Mengakses data pribadi Anda
- Memperbaiki data yang tidak akurat
- Menghapus akun Anda dan data terkait
- Menarik persetujuan kapan saja
- Mengajukan keluhan tentang penggunaan data

Untuk melaksanakan hak-hak ini, hubungi administrator sekolah atau kontak di bagian 11.

## 9. Privasi Anak-Anak

Aplikasi ini dirancang untuk siswa berusia 12 tahun ke atas. Kami tidak secara sengaja mengumpulkan informasi dari anak-anak di bawah 12 tahun. Jika kami menyadari bahwa kami telah mengumpulkan data dari anak di bawah 12 tahun, kami akan menghapusnya segera.

## 10. Perubahan Kebijakan Privasi

Kami dapat memperbarui kebijakan privasi ini dari waktu ke waktu. Perubahan material akan dikomunikasikan melalui:
- Pembaruan di aplikasi
- Email ke alamat yang terdaftar
- Pemberitahuan dalam aplikasi

Penggunaan berkelanjutan aplikasi setelah perubahan berarti Anda menerima kebijakan yang diperbarui.

## 11. Hubungi Kami

Jika Anda memiliki pertanyaan, kekhawatiran, atau permintaan terkait privasi, silakan hubungi:

**Sekolah/Institusi Pendidikan:**
- Hubungi administrator atau guru pembimbing Anda
- Kunjungi kantor sekolah untuk informasi lebih lanjut

**Pengembang Aplikasi:**
- Hubungi melalui email yang disediakan oleh sekolah
- Ajukan pertanyaan melalui portal sekolah

## 12. Kepatuhan Hukum

Kebijakan Privasi ini mematuhi:
- Undang-Undang Nomor 27 Tahun 2022 tentang Perlindungan Data Pribadi (Indonesia)
- Peraturan perundang-undangan terkait privasi data di Indonesia

## 13. Penerimaan Kebijakan

Dengan menggunakan aplikasi Skanida Student, Anda menerima kebijakan privasi ini. Jika Anda tidak setuju dengan kebijakan ini, mohon jangan gunakan aplikasi ini.

---

**Versi:** 1.1
**Tanggal Pembaruan Terakhir:** November 2026
**Status:** Aktif
