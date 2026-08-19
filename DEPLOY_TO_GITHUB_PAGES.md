Panduan ringkas: Deploy static site ke GitHub Pages (Bahasa Melayu)

Apa yang dibuat di projek ini:
- Fail workflow GitHub Actions (.github/workflows/deploy-pages.yml) ditambah supaya setiap kali anda push ke branch `main`, GitHub Actions akan memuat naik semua fail di repository dan deploy ke GitHub Pages secara automatik.

Langkah untuk deploy (anda boleh ikut arahan ini di mesin anda):

1) (Jika belum) Inisialisasi Git dan commit projek:

   cd "C:\Users\Admin\OneDrive - National Defence University of Malaysia\Desktop\Project-Mirul"
   git init
   git add .
   git commit -m "Initial commit for GitHub Pages deploy"

2) Buat repository baru di GitHub (melalui github.com):
   - Log masuk ke GitHub, klik "New" untuk buat repo baru.
   - Namakan repo ikut kehendak anda (contoh: campusmart-static).
   - Boleh pilih Public (lebih mudah) atau Private.

3) Sambungkan repo remote dan push (contoh jika nama remote "origin"):

   git remote add origin https://github.com/USERNAME/REPO_NAME.git
   git branch -M main
   git push -u origin main

4) Selepas push, Actions akan berjalan (lihat tab "Actions" di repo GitHub anda). Workflow yang ditambah akan:
   - Checkout kod
   - Muat naik semua fail sebagai artifact
   - Deploy ke GitHub Pages

5) Lihat status Pages:
   - Pergi ke Settings -> Pages di repo GitHub untuk lihat URL laman anda.
   - URL biasanya: https://USERNAME.github.io/REPO_NAME/  (atau jika anda set custom domain, ikut yang anda tetapkan)

Nota & pilihan lain:
- Jika anda ingin serverless functions atau backend, ini hanya untuk laman statik. Untuk aplikasi dengan server (Node/Express), gunakan host lain seperti Render, Railway, Vercel.
- Jika anda suka, boleh guna Netlify (drag & drop) tanpa perlu GitHub, tetapi anda ada akaun GitHub jadi Pages adalah percuma dan mudah.
- Jika index.html anda terletak di subfolder (contoh: /dist), edit workflow dan gantikan `path: './'` dengan `path: 'dist'`.

Masalah biasa:
- Pastikan branch utama nama `main` atau edit workflow untuk branch yang anda guna.
- Jika anda mahu URL root (https://USERNAME.github.io) gunakan repo bernama `USERNAME.github.io` dan push ke main.

Bantuan lanjut:
- Mahu saya buat commit awal dan sediakan repo git di folder projek untuk anda? (Saya hanya akan buat perubahan tempatan — anda perlu push ke GitHub dari mesin anda kerana saya tidak ada akses ke akaun GitHub anda.)
