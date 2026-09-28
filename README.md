# TypePulse

Android companion for the **[AR Typing Platform](https://www.artypingplatform.com)** member area. Sign in with your AR Typing email and password and see your real typing data on your phone.

**Only website data is shown.** The app has no guest mode, no sample history and no locally invented scores — every number comes from artypingplatform.com.

## What's in the app (all from the member area)

| Tab | Website source | Shows |
|-----|----------------|-------|
| **Summary** | Typing History page stat cards + history | Total Tests Attempted · Avg. Gross Speed · Avg. Net Speed · Avg. Accuracy; graph of your last 7 / 15 / 30 results; latest results |
| **History** | Typing History table | Exam, passage, date, time used, keystrokes, target speed, gross, net (green/red vs target like the site); search; tap for **View Detail** with a word-by-word comparison of passage vs typed text |
| **Insight** | Typing Insight (`typing-progress`) | Passages typed, min-keystroke hits, avg / best speeds, daily best charts, exams attended, misspelled / added / deleted words (1–30 days) |
| **You** | Edit Profile + My Subscription | Name, email, phone, date of birth, city/state, address; plan, status, enrolled / valid until, days remaining; accounts, sync, sign out |

- **First launch:** welcome screen asking for your AR Typing login. Signing out returns there.
- **Missing data is never invented:** values the website shows as **NA** / "See In Detail" (e.g. target 0, speeds of tests before 13 Mar 2025) stay NA and are left **out of the graph**. The graph plots one point per real result, in order — days without tests are simply not on it.
- **Multi-account:** add several AR Typing logins; switch instantly.
- **Sync:** on open, refresh button, every 30 s while open, Workmanager ~15 min in the background, optional continuous background sync; notification when a new result appears.

## Download the APK (GitHub Actions)

Every push runs **Actions → Build APK**: analyze → tests → release APK.

1. Open the repo's **Actions** tab → latest **Build APK** run → **Artifacts** → download `TypePulse-v…apk` (it's zipped by GitHub; unzip, then install on the phone — allow "Install unknown apps").
2. Run it manually any time: **Actions → Build APK → Run workflow**.
3. Push a tag like `v1.3.0` to also attach the APK to a **GitHub Release**.

**Updating over an older install:** Android only accepts an update signed with the same key. Without secrets, CI signs with a temporary debug key, so you may need to uninstall first. To sign consistently, create a keystore once:

```bash
keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.jks   # copy the output
```

and add repository secrets (**Settings → Secrets and variables → Actions**): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`. Keep `upload.jks` safe — losing it means users must reinstall.

Toolchain: Flutter 3.47.5 · Gradle 8.14.3 · AGP 8.13.0 · Kotlin 2.2.20 · Java 17.

## AR API (verified against the member-area web app)

Base: `https://artypingplatform-efb5438ddb1b.herokuapp.com/api/v1` · header `Authorization: JWT <access>`

| Method | Path | Used for |
|--------|------|----------|
| POST | `/jwt/create/` | `{email, password}` → `{access, refresh}` |
| POST | `/jwt/refresh/` | `{refresh}` → `{access}` (rotated `refresh` stored if returned); 400/401 clears the session, 5xx/offline keeps it |
| POST | `/logout/` | `{refresh}` |
| GET | `/learning/typedPassages/?page=&page_size=` | **Typing History** (follows `next`) |
| GET | `/learning/memberTypingStats/` | Total tests · Avg gross · Avg net · Avg accuracy |
| GET | `/learning/typing-progress/?days=1\|2\|7\|15\|30` | **Typing Insight** (404 = no activity) |
| GET | `/users/me/` | Name + plan (`is_subscribed`, `subscription.title`) |
| GET | `/learning/students/profile/` | Profile |

History fields used: `exam_title`, `passage_title`, `typing_date`, `time_duration` (`HH:mm:ss` or seconds), `time_taken` (minutes), `key_strokes_given/typed/error`, `target_speed` (0 → NA), `gross_speed`, `net_speed`, `qualified`, `total_wrong_words`, `back_space_count`, `passage_text`, `typed_passage_text`. Accuracy per result = `(typed − error) ÷ typed` keystrokes, only when the site sends `key_strokes_error`.

## Background sync & battery / OS limits

Android does **not** allow arbitrary exact alarms for silent background work:

| Mode | Interval | Survives kill? | Notes |
|------|----------|----------------|-------|
| Foreground `Timer` | ~30s | No | Only while UI is resumed |
| Workmanager periodic | **≥ ~15 minutes** (OS floor) | Yes | Batch/Doze may delay further; needs network constraint |
| Foreground service (`flutter_background_service`) | ~30s | Yes (while FGS runs) | Requires ongoing notification; user must enable **You → Keep syncing in background** |

**Battery / OEM caveats**

- Some OEMs (Xiaomi, Oppo, Vivo, Huawei, Samsung) aggressively kill background apps unless the user disables battery optimization / allows “autostart” for TypePulse.
- Android 14+ requires `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC` for the continuous sync notification.
- Android 15+ may cap `dataSync` foreground services (~6 hours / 24h window); bring the app to the foreground periodically to reset.
- Workmanager timing is **best-effort**, not exact wall-clock every 15:00.
- The foreground service is **not** auto-started after a reboot (Android 14/15 forbid starting a `dataSync` service from `BOOT_COMPLETED`). Workmanager keeps running after reboot; the ~30s service resumes the next time you open the app.

## Run locally

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Package: `com.typepulse.typepulse`
