# 💅 Beauty Center

> Cross-platform appointment manager for beauty and wellness centers — powered by Flutter & Dart.

---

## 📊 Status & Metrics

[![Build](https://github.com/Fede22dev/beauty_center/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/Fede22dev/beauty_center/actions/workflows/build-and-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/Fede22dev/beauty_center?label=version&sort=semver)](https://github.com/Fede22dev/beauty_center/releases)
[![Downloads](https://img.shields.io/github/downloads/Fede22dev/beauty_center/total)](https://github.com/Fede22dev/beauty_center/releases)
[![License](https://img.shields.io/github/license/Fede22dev/beauty_center)](./LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Fede22dev/beauty_center)](https://github.com/Fede22dev/beauty_center/commits)

---

## 🧰 Tech Stack

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-46D1FD.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2.svg?logo=dart&logoColor=white)](https://dart.dev)
[![Drift](https://img.shields.io/badge/Database-Drift-0A84FF.svg?logo=sqlite&logoColor=white)](https://drift.simonbinder.eu/)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E.svg?logo=supabase&logoColor=white)](https://supabase.com)

---

## ✨ What is Beauty Center?

**Beauty Center** is a sleek and modular **cross-platform app** built in **Flutter**.  
It helps beauty and wellness centers manage:

- 🧍‍♀️ Clients
- 📅 Appointments
- 💆‍♀️ Treatments
- 📊 Statistics
- ⚙️ Settings

> 🧠 Designed for offline-first usage, with optional cloud sync in future releases.

---

## 🖼️ Architecture

The app follows **clean architecture** with **Riverpod for state management**:

- **Core**: domain models, repositories, services
- **Features**: modular UI screens & logic
- **Data layer**: Drift (local), Supabase (remote)

---

## 🔮 Roadmap

- [ ] ☁️ **Cloud Sync** via [Supabase](https://supabase.com)
- [ ] 🖥️ **Desktop builds** (Windows)
- [ ] 📱 **Mobile builds** (Android)
- [ ] 📊 **Client Analytics** & shop statistics

---

## 📦 Install & Run

Clone the repo and fetch dependencies:

```bash
git clone https://github.com/Fede22dev/beauty_center.git
cd beauty_center
flutter pub get

flutter gen-l10n # To generate localization files

flutter run

flutter run -d windows

flutter build windows

flutter build apk
```

This app developed and tested only on **Windows** and **Android**

---

## Author

Made with ❤️ by [Fede22dev](https://github.com/Fede22dev)
