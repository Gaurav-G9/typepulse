# TypePulse

iOS-style typing tracker for **Android**, built with Flutter.

Personal stats, 5-minute exam practice, live rooms, weekly ranks, and a Performance Dashboard (gross / net WPM, full and half mistakes, backspaces, qualified).

## Run on Android

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.22+ and an Android emulator or phone.

```bash
git clone https://github.com/Gaurav-G9/typepulse.git
cd typepulse
flutter pub get
flutter run
```

If Gradle asks for a wrapper jar:

```bash
flutter create . --project-name typepulse --org com.typepulse
flutter pub get
flutter run
```

`flutter create .` fills platform folders and does **not** wipe `lib/`.

## App map

- **Summary** — Fitness rings, stacked averages, workout list
- **Live** — Rooms and a simulated heat
- **Ranks** — Weekly net WPM board
- **You** — Name, language, daily goal, target WPM

Tap any workout for the Performance Dashboard.

Sessions stay on the device. First launch includes one sample UPSSSC-style result.

Package: `com.typepulse.typepulse`
