# CLAUDE.md

Panduan untuk Claude Code saat bekerja di repo ini.

## Ringkasan proyek
**Skanida Student** — aplikasi Flutter (Android & iOS) untuk siswa SMKN 2 Semarang:
presensi selfie berbasis GPS, pengajuan izin (presensi, meninggalkan kelas, sholat),
presensi sholat, riwayat/rekap, dan profil siswa.
- Package Android: `com.sahasika.skanida_student`; versi di `pubspec.yaml` (`version: x.y.z+build`).
- Backend: REST API di `https://apps.smkn2semarang.sch.id/api` (konstanta `API_BASE_URL` di `lib/main.dart`).
- Bahasa UI: Bahasa Indonesia. Pesan commit: conventional commits berbahasa Indonesia (`feat: ...`, `fix: ...`).

## Perintah umum
```bash
flutter pub get
flutter analyze                 # lint: flutter_lints (analysis_options.yaml)
flutter run                     # jalankan di device/emulator
flutter test                    # test/widget_test.dart masih template counter bawaan (akan gagal)
flutter build apk               # / flutter build appbundle / flutter build ipa
dart run flutter_launcher_icons # regenerasi ikon dari assets/images/skanida_student.png
```
Release Android ditandatangani dengan `~/upload-keystore.jks` (lihat `android/app/build.gradle.kts`);
`upload-keystore.jks` di root di-gitignore — jangan pernah di-commit.

## Arsitektur
Struktur datar: semua kode di `lib/`, satu file per halaman (`*_page.dart`). Tidak ada state
management library, routing generator, atau layer repository — tiap halaman adalah
`StatefulWidget` yang memanggil `http` langsung dan `setState`.

- `lib/main.dart` — `API_BASE_URL`, `AuthService.loginWithAPI`, `SessionManager`
  (state sesi statis + persist ke `SharedPreferences`: `auth_token`, `siswa_id`, `username`, dll),
  `formatDateIndonesian`, `MyApp`, dan dashboard `MyHomePage` (grid menu + dialog `/pesan-harian`).
  Halaman lain `import 'main.dart'` untuk mengakses `SessionManager` & `API_BASE_URL`.
- Auth: header `Authorization: Bearer ${SessionManager.authToken}` + `Accept: application/json`.
  `SessionManager.currentUsername` = NISN.
- `splash_screen.dart` — load sesi → Login / `ResumePresensiPage` (jika ada draft) / Home.

### Alur presensi (bagian paling sensitif)
`presensi_page.dart` (cek GPS, radius ≤ 25 m dari `schoolLocation`, peta flutter_map + OSM)
→ `selfie_camera_page.dart` (image_picker kamera depan, `maxWidth/maxHeight: 640`, quality 80)
→ `PresensiDraft.save` (`presensi_draft.dart`: simpan foto ke disk + SharedPreferences, kedaluwarsa 6 jam)
→ upload otomatis tanpa konfirmasi via `PresensiUploader.upload` (`presensi_uploader.dart`, multipart `POST /presensi`).
Jika Android membunuh proses saat kamera terbuka, splash menemukan draft dan membuka
`resume_presensi_page.dart` untuk melanjutkan upload. Draft dihapus (`PresensiDraft.clear`) setelah sukses/batal.
Gunakan helper bersama di `presensi_uploader.dart` (`showPresensiSuccessDialog`,
`formatDateTimeIndonesian` → WIB/UTC+7), jangan duplikasi.

Prinsip yang harus dijaga (hasil perbaikan crash sebelumnya, lihat git log & `issue.md`):
batasi resolusi gambar, hindari inisialisasi berat saat startup (Mobile Ads diinisialisasi lazy
di `AdsHelper`), dan pastikan data penting tahan process-death.

### Izin (permission)
Diminta per-fitur saat dibutuhkan, bukan di awal: `PermissionGuard.ensurePermission(context, RequiredPermission.camera|location)`
(`permission_guard.dart`) → menampilkan `PermissionPreAlertPage` bila belum diberikan.
Hanya kamera & lokasi. ATT/`NSUserTrackingUsageDescription` dan izin galeri sengaja dihapus — jangan ditambahkan lagi
tanpa alasan jelas (berpengaruh ke review App Store/Play Store).

### Fitur lain & endpoint
| File | Endpoint |
|---|---|
| `siswa_detail_page.dart` | `GET /siswa?siswaId=`, `POST /siswa/upload-foto` |
| `ijin_online_page.dart` | `POST /ijin` (multipart, lampiran via file_picker/image_picker) |
| `daftar_ijin_page.dart` | `GET /ijin?siswa_id=` |
| `keluar_kelas_page.dart` | `GET /jenis-ijin-kelas`, `GET /get_guru`, `POST /keluar-kelas` (+ iklan interstitial) |
| `riwayat_izin_page.dart` | `GET /riwayat-izin?id_siswa=` |
| `presensi_sholat_page.dart` | `GET /presensi-sholat?nisn=&bulan=&tahun=` |
| `ijin_sholat_page.dart` | `POST /ijin-sholat` |
| `rekap_presensi_page.dart` | `GET /presensi/{siswaId}/{bulan}/{tahun}` |

Iklan: `ads_helper.dart` (Google Mobile Ads interstitial, ID produksi hardcoded), saat ini hanya dipakai di `keluar_kelas_page.dart`.

## Konvensi
- Ikuti gaya yang ada: halaman baru = file `lib/<nama>_page.dart`, navigasi via
  `Navigator.push(MaterialPageRoute(...))`, tambahkan kartu menu di grid `MyHomePage`.
- Request HTTP pakai `.timeout(Duration(seconds: 10))`, tangani status 200/401/422, tampilkan error via SnackBar/dialog.
- Selalu cek `mounted` / `context.mounted` setelah `await` sebelum memakai `context`.
- Tema: ungu (`Colors.deepPurple.shade900` untuk AppBar, gradien deepPurple → purple).
- Tanggal ditampilkan dalam format Indonesia; waktu server (UTC) dikonversi ke WIB.

## File non-kode di root
- `APP_DESCRIPTION.md`, `RELEASE_NOTES.md`, `PRIVACY_POLICY.md` — materi store listing; perbarui jika fitur/izin berubah.
- `issue.md` — rencana implementasi yang ditulis untuk dikerjakan programmer junior/model lebih murah.
- `prompt.txt` (gitignored), `dump/` — catatan/scratch, abaikan.
