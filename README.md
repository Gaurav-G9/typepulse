# TypePulse

Minimal iOS Fitness–style typing tracker for Android (Flutter / Cupertino).

**Website is the data source; the app is the presentation layer.** Sign in with your [AR Typing Platform](https://www.artypingplatform.com) email and password to sync history, then browse workouts as Activity rings, large Summary metrics, and a Performance Dashboard.

## Features

- **Multi-account** — multiple AR Typing logins on one device; switch accounts to swap history/stats instantly (theme stays device-wide)
- **AR Typing sync** — secure JWT (access + refresh) per account via `flutter_secure_storage`, paginated history (`page_size` up to 100), profile + member stats
- **Manual refresh** — arrow icon in the Summary top corner (beside light/dark toggle) re-fetches typedPassages, memberTypingStats, and profile
- **Auto-sync every 30s** — while the app is in the foreground; pauses when backgrounded (`WidgetsBindingObserver`)
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
| Notification | Title e.g. `New typing result` · body e.g. `UPSSSC … · Net 39.6 WPM` |
| Channel | `typepulse_results` / “Typing Results” |

Grant notification permission when prompted (Android 13+).

## Run

```bash
git clone https://github.com/Gaurav-G9/typepulse.git
cd typepulse
flutter pub get
flutter run
```

Do **not** commit passwords. On **You → AR Typing**, enter your AR Typing email and password. Tokens stay on device only.

## AR API (discovered)

Base: `https://artypingplatform-efb5438ddb1b.herokuapp.com/api/v1`

| Method | Path | Notes |
|--------|------|--------|
| POST | `/jwt/create/` | `{email, password}` → `{access, refresh}` |
| POST | `/jwt/refresh/` | `{refresh}` → `{access}`; failed refresh clears tokens |
| POST | `/logout/` | `{refresh}` + `Authorization: JWT …` |
| GET | `/learning/typedPassages/` | paginated history (`page`, `page_size`, follow `next`) |
| GET | `/learning/students/profile/` | profile |
| GET | `/learning/memberTypingStats/` | stats (may 403 on Free Mode) |

Auth header style matches the site: `Authorization: JWT <access>`. On **401**, the client refreshes once; if that fails, it clears the session and asks you to sign in again.

## Scoring note

Aligned with UPSSSC / AR Typing keystroke÷5 scoring and dashboard toggles. Sample history is illustrative until you sync.

Package: `com.typepulse.typepulse`
