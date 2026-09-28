# TypePulse

Minimal iOS Fitness–style typing tracker for Android (Flutter / Cupertino).

**Website is the data source; the app is the presentation layer.** Sign in with your [AR Typing Platform](https://www.artypingplatform.com) email and password to sync history, then browse workouts as Activity rings, large Summary metrics, and a Performance Dashboard.

## Features

- **Multi-account** — multiple AR Typing logins on one device; switch accounts to swap history/stats instantly (theme stays device-wide)
- **AR Typing sync** — secure JWT (access + refresh) per account via `flutter_secure_storage`, paginated history (`page_size` up to 100), profile + member stats
- **Manual refresh** — arrow icon in the Summary top corner (beside light/dark toggle) re-fetches typedPassages, memberTypingStats, and profile
- **Foreground auto-sync (30s)** — `Timer` while the app is resumed; pauses when backgrounded
- **Background sync (Android)** — Workmanager periodic (~15 min OS minimum) always when signed in; optional foreground service for ~30s polls while backgrounded/killed
- **Local notifications** — when genuinely new typing results appear (`flutter_local_notifications`, Android channel `typepulse_results`, `POST_NOTIFICATIONS` on API 33+)
- **UPSSSC-style scoring** — keystrokes ÷ 5, full/half mistakes, error allowance + penalty, duration vs time-taken toggles
- **Summary** — rings, AR member stats cards, 7 / 15 / 30-day trends, streak, qualified count
- **Dark / Light** — moon/sun toggle (persisted globally, not per account)
- Offline practice with exam + passage pickers (EN / HI)

## Multi-account

1. **You → Accounts** (or the people icon) → **Add account** — sign in with another AR Typing email.
2. **Switch** loads that account’s JWT, synced sessions, profile, and member stats immediately (`activeAccountId` persisted).
3. **Remove** deletes tokens + per-account cache for that login on this device.
4. Tokens: `ar_access_<accountId>` / `ar_refresh_<accountId>` in secure storage. Sessions/profile/stats keyed by account id in SharedPreferences.

## Refresh & notifications

| Action | Behavior |
|--------|----------|
| Tap refresh (Summary) | Sync typedPassages + memberTypingStats + profile; brief spinner |
| Auto every 30s (foreground) | Quiet sync; if new session ids appear → local notification |
| Workmanager ~15 min | Runs even if app is backgrounded/killed (Android OS minimum interval ≈ 15 minutes) |
| Keep syncing in background (Profile) | Starts a low-priority **foreground service** with ongoing notification “TypePulse is syncing”; polls ~every 30s while allowed |
| Notification | Title e.g. `New typing result` · body e.g. `UPSSSC … · Net 39.6 WPM` |
| Channel | `typepulse_results` / “Typing Results” |

Grant notification permission when prompted (Android 13+).

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

Toggle path: **You → Keep syncing in background** (requires an AR account signed in). Preference key: `tp_background_sync`.

Background isolates load the active account JWT from secure storage, call `typedPassages` + `memberTypingStats`, detect new session ids, show a local notification, and persist to the same SharedPreferences keys as the in-app `AppStore`.

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

## Run

```bash
git clone https://github.com/Gaurav-G9/typepulse.git
cd typepulse
flutter pub get
flutter run
```

Do **not** commit passwords. On **You → AR Typing**, enter your AR Typing email and password. Tokens stay on device only.

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

History row fields mapped: `exam_title`, `passage_title`, `typing_date`, `time_duration` (`HH:mm:ss` or seconds), `time_taken` (minutes), `key_strokes_given/typed/error`, `target_speed` (0 → **NA**), `gross_speed`, `net_speed`, `qualified`, `total_wrong_words`, `back_space_count`, `passage_text`, `typed_passage_text`.

Like the website: gross falls back to `keystrokes ÷ (time_taken × 5)` when 0, and rows before 13 Mar 2025 with net 0 (shown as "See In Detail" on the site) get net recalculated on device from the passage texts. Accuracy = `(typed − error) ÷ typed` keystrokes.

## Screens

- **Summary** — rings, AR member stats (same 4 cards as the member area), 7/15/30-day trend, streak, workouts
- **Typing Insight** (Summary → Typing Insight) — passages typed, min-keystroke hits, avg/best gross & net, daily best charts, exams attended, misspelled / added / deleted words
- **Workouts** — full history with language / qualified filters; tap for the dashboard with word-by-word comparison
- **You** — accounts, AR plan, sync, background sync, goals

## Scoring note

Aligned with UPSSSC / AR Typing keystroke÷5 scoring and dashboard toggles.

Typed text is aligned to the passage **word by word** (edit-distance alignment), so:

- the **untyped rest of the passage is never penalised** — a timed test that stops half-way scores on what you actually typed;
- a **skipped** or **extra** word costs exactly one full mistake instead of shifting every following word out of place;
- a word within one character edit of the original is a **half mistake**;
- a last word cut off by the timer (a prefix of the original) is not a mistake.

The Detailed Comparison on the dashboard shows each word as correct, ½, full, *missed*, or *extra*. AR-synced results keep AR Typing's own mistake counts.

Sample history is shown only while no AR account is signed in; a signed-in account always shows its real history.

## Tests

```bash
flutter analyze
flutter test
```

Covers the scoring engine, AR API parsing / token refresh / paging, store sync (concurrency, account switching, corrupt prefs) and key widget flows.

Package: `com.typepulse.typepulse`
