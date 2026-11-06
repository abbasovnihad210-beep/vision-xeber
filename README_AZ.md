# VISION XƏBƏR — CANLI SAYT PAKETİ

Bu versiya əvvəlki lokal demo deyil: xəbərlər, müraciətlər, könüllülük və kabinet rolları Supabase üzərindən işləyir. İlkin konfiqurasiya edilmədən canlı deyil. GitHub və hostinq hesablarını avtomatik qoşmaq mümkün deyil; bunu hesab sahibi təsdiq etməlidir.

## 1. Supabase (verilənlər bazası)

1. https://supabase.com/dashboard ünvanında layihə yaradın.
2. SQL Editor > New query: `supabase/schema.sql` faylının **hamısını** yerləşdirib Run edin.
3. Project Settings / API Keys: **Project URL** və **Publishable/anon key** götürün.
4. `config.js` daxilində bu iki dəyəri yerləşdirin. **Service role və secret key heç vaxt bura yazılmamalıdır.**
5. Authentication > Users panelində öz e-poçtunuzla hesab yaradın (Dashboard > Add user, yaxud invite). Şifrəni yalnız Supabase idarə panelində qurun.
6. SQL Editor-dən aşağıdakı əmri **öz e-poçtunuzla** icra edin:

```sql
update public.profiles set role='head',status='active'
where id=(select id from auth.users where email='SIZIN_EMAIL@example.com');
```

7. Baş Admin əlavə admin dəvət etmək üçün Supabase Authentication > Users > Invite user istifadə edir. Yeni istifadəçi giriş məlumatı alandan sonra Baş Admin kabinetində onun rolunu `admin`, statusunu `active` edir. Admin kabinetinin özündə parol göndərilməsi yoxdur; bu məqsədli təhlükəsizlik tədbiridir.

## 2. GitHub

1. https://github.com/new ünvanında `vision-xeber` repository yaradın.
2. Bu ZIP içindəki **bütün faylları** (yalnız `index.html` yox) GitHub repository-nin kökünə yükləyin; Commit changes seçin.
3. `config.js` faylındakı publishable key açıq ola bilər, təhlükəsizlik Supabase RLS ilə təmin edilir. Secret key-ləri GitHub-a qoymayın.

## 3. Cloudflare Pages — GitHub-dan avtomatik yayım

1. https://dash.cloudflare.com > Workers & Pages > Create > Pages > Connect to Git.
2. GitHub-dan `vision-xeber` repository-ni seçin.
3. Framework: None, Build command: boş, Build output directory: `/` (və ya `.` platformanın qəbul etdiyi uyğun dəyər).
4. Deploy seçin. Sizə `*.pages.dev` ünvanı veriləcək.
5. Supabase > Authentication > URL Configuration: Site URL hissəsinə həmin ünvanı yazın, lazım olsa Redirect URLs-a da əlavə edin.
6. QR kod avtomatik olaraq yayımlanmış səhifəyə yönlənəcək.

## 4. Nələri yoxlayın

- Baş Admin ilə giriş, rol/status təyinatı.
- Yeni xəbər yaradın, `Dərc et` seçin: başqa cihazdan xəbəri açın, paylaşım linkini yoxlayın.
- Xəbəri siləndə ana səhifədən itdiyini yoxlayın.
- Oxucu müraciətinə şəkil əlavə edin, kabinetdə imzalı URL-lə açılmasını yoxlayın.
- Könüllü qeydiyyatını tamamlayın, statusunu kabinetdə dəyişin.

## Vacib məhdudiyyətlər

- Bu paket **əvvəlki 45 modulun tam server inteqrasiyası deyil**; təhlükəsiz canlı əsas funksiyalar (xəbər, giriş/rollar, müraciətlər, könüllülər, foto faylları) təqdim olunur.
- Vision AI hazırda sayt xəbərlərində axtarış edən virtual köməkçidir, xarici LLM qoşulmayıb.
- Müraciət kodunun sahibini təsdiqləyən ictimai status izləmə paneli daxil edilməyib.
- İstehsalatda spam/RPC və açıq fayl yükləmələri üçün Turnstile/CAPTCHA və server tərəfli rate limiting tövsiyə edilir. Fərdi məlumatların emalı ilə bağlı məxfilik mətni əlavə edin.
- Xəbərlər ana səhifədə yalnız faktiki dərc edildikdən sonra görünəcək; əvvəlki uydurma demo xəbərləri canlı bazaya köçürülməyib.
- `config.js` məlumatları olmadan sayt canlı verilənlər bazasına qoşulmur.
