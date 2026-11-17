# Issue: Batasi resolusi foto selfie presensi (samakan dengan foto profil WhatsApp)

## 1. Ringkasan Masalah

Aplikasi masih mengalami crash/restart saat mengirim data presensi. Setelah
dianalisa ulang, ditemukan penyebab baru yang lebih konkret dari
"process death" yang sudah diperbaiki sebelumnya:

File: **[lib/selfie_camera_page.dart:49-53](lib/selfie_camera_page.dart#L49)**

```dart
final XFile? photo = await _picker.pickImage(
  source: ImageSource.camera,
  preferredCameraDevice: CameraDevice.front,
  imageQuality: 85,
);
```

Parameter `imageQuality` cuma mengatur kompresi JPEG (0-100), **bukan**
dimensi/resolusi gambar. Karena `maxWidth`/`maxHeight` **tidak diisi**, foto
selfie diambil di **resolusi sensor kamera penuh** — di banyak HP kelas
menengah-bawah, kamera depan bisa 16-32 MP+.

Foto seresolusi itu, saat di-*decode* untuk ditampilkan di layar
(`Image.memory`), bisa membutuhkan puluhan-ratusan MB RAM sekaligus,
bertumpuk dengan proses simpan draft ke disk (`PresensiDraft.save`) dan
upload ke server (`PresensiUploader.upload`) yang sekarang berjalan otomatis
tanpa jeda. Di HP dengan RAM terbatas, ini berisiko memicu **crash native
out-of-memory** tepat di momen "mengirim presensi" — crash jenis ini
terjadi di level sistem/native, sehingga **tidak** tertangkap oleh
`try/catch` Dart maupun `FlutterError.onError`/`runZonedGuarded` yang sudah
ada di [lib/main.dart](lib/main.dart).

Sebagai perbandingan, [lib/siswa_detail_page.dart:81-85](lib/siswa_detail_page.dart#L81)
(upload foto profil dari galeri) **sudah benar** membatasi ukuran:

```dart
final picked = await picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: 800,
  maxHeight: 800,
  imageQuality: 80,
);
```

Developer sebelumnya sudah tahu pola ini untuk galeri, tapi terlewat untuk
kamera selfie presensi.

## 2. Keputusan Ukuran

Foto presensi ini **hanya untuk verifikasi wajah secara visual** (dilihat
guru/admin), bukan untuk cetak atau analisis detail — jadi tidak perlu
resolusi tinggi. Disepakati: **samakan dengan ukuran foto profil WhatsApp**,
yaitu **640×640 piksel** (bounding box, bukan crop paksa — aspect ratio foto
asli tetap terjaga, sisi terpanjang dibatasi maksimal 640px).

Estimasi hasil:
- Ukuran file: **~40-100 KB per foto** (dari sebelumnya bisa 3-8 MB tanpa
  batas) — jauh lebih ringan untuk storage server maupun kuota data siswa.
- Kebutuhan RAM saat decode gambar turun drastis (dari puluhan-ratusan MB
  jadi hanya beberapa MB) — inilah yang menghilangkan risiko crash
  out-of-memory di momen kirim presensi.
- Wajah tetap terlihat jelas untuk keperluan verifikasi (persis seperti
  foto profil WhatsApp yang biasa kita lihat sehari-hari).

## 3. Tujuan Perbaikan (Acceptance Criteria)

- [ ] Foto selfie presensi dibatasi maksimal 640×640 piksel (bounding box)
      saat diambil dari kamera.
- [ ] Ukuran file hasil foto jauh lebih kecil dari sebelumnya (bisa dicek
      langsung di device, target di bawah ~150 KB per foto).
- [ ] Wajah pada foto tetap terlihat jelas saat dibuka/di-zoom secukupnya.
- [ ] Presensi berulang kali (ambil foto → kirim, ambil foto → kirim, dst)
      tidak lagi menyebabkan aplikasi crash/restart, terutama di HP dengan
      RAM kecil.

## 4. Rencana Implementasi (Urut, Ikuti Sesuai Nomor)

> Kerjakan tiap Task secara berurutan. Tiap Task punya "Cara verifikasi" —
> jangan lanjut ke Task berikutnya sebelum verifikasi lolos.

### Task 0 — Persiapan

1. Buat branch baru dari `main`, misalnya `fix/batasi-resolusi-selfie`.

**Cara verifikasi:** `git status` bersih di branch baru.

---

### Task 1 — Batasi resolusi foto kamera presensi

File: **[lib/selfie_camera_page.dart](lib/selfie_camera_page.dart)**

Cari method `_takeSelfie()`, bagian pemanggilan `_picker.pickImage(...)`
(sekitar baris 49-53):

```dart
final XFile? photo = await _picker.pickImage(
  source: ImageSource.camera,
  preferredCameraDevice: CameraDevice.front,
  imageQuality: 85,
);
```

Ubah menjadi:

```dart
final XFile? photo = await _picker.pickImage(
  source: ImageSource.camera,
  preferredCameraDevice: CameraDevice.front,
  maxWidth: 640,
  maxHeight: 640,
  imageQuality: 80,
);
```

**Penjelasan tiap parameter baru:**
- `maxWidth: 640, maxHeight: 640` — membatasi sisi terpanjang foto maksimal
  640px (setara ukuran foto profil WhatsApp). `image_picker` otomatis
  menjaga aspect ratio asli, jadi foto tidak akan gepeng/terdistorsi.
- `imageQuality: 80` — diturunkan sedikit dari 85 ke 80 (masih sangat jelas
  secara visual di ukuran sekecil ini, tapi file jadi lebih ringan).

> Tidak ada file lain yang perlu diubah — `PresensiDraft`, `PresensiUploader`,
> `ResumePresensiPage`, dan server-side upload tetap menerima file JPEG
> apa pun ukurannya, jadi otomatis ikut lebih ringan tanpa perubahan
> tambahan di sana.

**Cara verifikasi:** `flutter analyze lib/selfie_camera_page.dart` — pastikan
tidak ada error/warning baru.

---

### Task 2 — Cek ukuran & kejernihan hasil foto di device asli

1. Jalankan aplikasi di HP Android asli (`flutter run` atau install APK/AAB
   hasil build).
2. Lakukan presensi seperti biasa (kamera otomatis terbuka → foto diambil
   → otomatis terkirim).
3. Cek ukuran file foto yang tersimpan sebagai draft, untuk memastikan
   benar-benar mengecil:
   ```bash
   adb shell run-as com.sahasika.skanida_student ls -la files/pending_presensi_selfie.jpg
   ```
   (kalau presensi sudah sukses terkirim, file ini otomatis terhapus oleh
   `PresensiDraft.clear()` — jalankan command ini **secepatnya** setelah
   foto diambil, sebelum upload selesai, atau uji sambil koneksi internet
   dimatikan sementara supaya file draft sempat dicek sebelum terhapus).
4. Pastikan ukurannya di kisaran puluhan-hingga-~150 KB (bukan lagi
   beberapa MB).
5. Buka hasil foto (misalnya dari halaman rekap/dashboard admin yang
   menampilkan foto presensi) dan pastikan wajah **masih terlihat jelas**
   dengan mata telanjang — tidak pecah/blur berlebihan.

**Cara verifikasi:** Ukuran file jauh lebih kecil dari sebelumnya, dan foto
masih jelas dilihat.

---

### Task 3 — Testing Manual: pastikan crash sudah tidak terjadi

Uji khusus di **HP dengan RAM kecil** (2-3 GB) kalau tersedia — di situlah
crash paling sering muncul sebelumnya:

1. Lakukan presensi berulang kali berturut-turut (ambil foto → kirim →
   berhasil, ulangi beberapa kali) — pastikan aplikasi **tidak** lagi
   crash/restart di momen pengiriman.
2. Kombinasikan dengan skenario "Don't keep activities" (Developer Options)
   dari perbaikan process-death sebelumnya — pastikan kombinasi kedua
   perbaikan (batasi resolusi + `PresensiDraft`/`ResumePresensiPage`) tetap
   saling bekerja dengan baik: foto tetap tersimpan sebagai draft, dan bisa
   dipulihkan lewat halaman "Lanjutkan Presensi" kalau proses sempat mati.
3. Uji juga skenario gagal kirim (matikan koneksi internet) → pastikan
   dialog "Presensi Gagal Terkirim" (Coba Lagi/Ambil Ulang/Batal) masih
   berfungsi normal dengan foto yang sudah lebih kecil ini.

**Cara verifikasi:** Presensi berulang kali berjalan mulus tanpa crash,
termasuk di HP RAM kecil.

---

### Task 4 — Build ulang & siap upload

1. Naikkan build number di [pubspec.yaml](pubspec.yaml) (misalnya dari versi
   sebelumnya `+14` jadi `+15`).
2. Build ulang:
   ```bash
   flutter build appbundle --release
   ```
3. Simpan hasil `.aab` untuk diupload ke Play Console (Internal Testing
   dulu direkomendasikan, supaya bisa dipantau beberapa hari sebelum rilis
   luas — terutama karena perbaikan ini menyasar bug crash, jadi penting
   dipastikan benar-benar hilang sebelum ke semua user).

**Cara verifikasi:** Build sukses tanpa error, versi baru di
`pubspec.yaml` sudah dinaikkan.

---

## 5. Ringkasan File yang Berubah

| File | Perubahan |
|---|---|
| `lib/selfie_camera_page.dart` | Tambah `maxWidth: 640, maxHeight: 640`, turunkan `imageQuality` ke 80 pada `pickImage()` kamera |
| `pubspec.yaml` | Naikkan build number sebelum upload ulang |

## 6. Catatan / Risiko

- Perubahan ini **tidak mengubah tampilan/alur UI apa pun** — cuma
  menurunkan resolusi foto yang diambil. Risiko regresi sangat kecil.
- Kalau ke depannya ternyata 640px dirasa kurang jelas untuk kebutuhan
  verifikasi tertentu (misal admin sering perlu zoom jauh), bisa dinaikkan
  ke 1024px — file tetap jauh lebih ringan dibanding tanpa batas sama
  sekali (foto resolusi kamera penuh).
- Ini melengkapi (bukan menggantikan) perbaikan *process-death* sebelumnya
  (`PresensiDraft`/`ResumePresensiPage`) — keduanya menangani jenis
  crash/kegagalan yang berbeda, jadi tetap dipertahankan bersamaan.
