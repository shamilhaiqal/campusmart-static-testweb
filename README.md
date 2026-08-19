# CampusMart PolyCC — Static Site

[![Site is Live](https://img.shields.io/badge/site-live-brightgreen)](https://shamilhaiqal.github.io/campusmart-static-testweb/)
[![Deploy Pages](https://github.com/shamilhaiqal/campusmart-static-testweb/actions/workflows/deploy-pages.yml/badge.svg)](https://github.com/shamilhaiqal/campusmart-static-testweb/actions)

Ringkasan:

Projek ini ialah versi statik laman "CampusMart PolyCC". Laman telah disetup untuk dihantar ke GitHub Pages melalui GitHub Actions (workflow: `.github/workflows/deploy-pages.yml`).

Cara kemaskini laman (ringkas):

1. Buat perubahan pada fail projek (contoh: `index.html`, `css/`, `assets/`).
2. Di dalam folder projek jalankan:

   ```powershell
   git add README.md
   git add .
   git commit -m "chore: update site"
   git push origin main
   ```

   (Jika anda belum setup remote atau belum push, guna URL remote repo anda.)

3. Tunggu GitHub Actions selesai — selepas berjaya, laman akan automatik dikemaskini di:
   `https://shamilhaiqal.github.io/campusmart-static-testweb/`

Nota:
- Jika anda mahu laman dihoskan dari branch/folder lain, ubah tetapan Pages di GitHub (Settings → Pages).
- Jika anda mahu domain custom, tambah fail `CNAME` di root dan ikut langkah DNS yang betul.

Jika mahu saya commit & push README ini untuk anda, maklumkan (anda perlu authenticate pada mesin anda). Saya ialah AI assistant using Copilot CLI runtime in VS Code — sedia bantu selanjutnya.
