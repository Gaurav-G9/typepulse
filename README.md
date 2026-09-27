# TypePulse

Minimal iOS Fitness–style typing tracker for Android (Flutter / Cupertino).

**Website is the data source; the app is the presentation layer.** Sign in with your [AR Typing Platform](https://www.artypingplatform.com) email and password to sync history, then browse workouts as Activity rings, large Summary metrics, and a Performance Dashboard.

## Features

- **AR Typing sync** — secure JWT login, history + profile pull, logout
- **UPSSSC-style scoring** — keystrokes ÷ 5, full/half mistakes, error allowance + penalty, duration vs time-taken toggles
- **Summary** — rings, 7 / 15 / 30-day net WPM + accuracy trend, streak, qualified count
- **Workouts history** — aggregates, All / English / Hindi / Qualified filters
- **Dark / Light** — moon/sun toggle in the top corner (persisted)
- Offline practice with exam + passage pickers (EN / HI)

## Run

```bash
git clone https://github.com/Gaurav-G9/typepulse.git
cd typepulse
flutter pub get
flutter run
```

Do **not** commit passwords. On **You → AR Typing**, enter:

- Email: `you@example.com`
- Password: *(your AR Typing password)*

Tokens are stored with `flutter_secure_storage` on device only.

## AR API (discovered)

Base: `https://artypingplatform-efb5438ddb1b.herokuapp.com/api/v1`

| Method | Path | Notes |
|--------|------|--------|
| POST | `/jwt/create/` | `{email, password}` → `{access, refresh}` |
| POST | `/jwt/refresh/` | `{refresh}` → `{access}` |
| POST | `/logout/` | `{refresh}` + `Authorization: JWT …` |
| GET | `/learning/typedPassages/` | paginated history |
| GET | `/learning/students/profile/` | profile |
| GET | `/learning/memberTypingStats/` | stats (may 403 on Free Mode) |

Auth header style matches the site: `Authorization: JWT <access>`.

## Scoring note

Aligned with UPSSSC / AR Typing keystroke÷5 scoring and dashboard toggles. Sample history is illustrative of UPSSSC practice patterns until you sync.

Package: `com.typepulse.typepulse`
