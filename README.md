# 💅 Beauty Center

> Cross-platform (Windows & Android) app manager for beauty and wellness centers — powered by
> Flutter & Dart.

---

## 📊 Status & Metrics

[![Build](https://github.com/Fede22dev/beauty_center/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/Fede22dev/beauty_center/actions/workflows/build-and-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/Fede22dev/beauty_center?label=version&sort=semver)](https://github.com/Fede22dev/beauty_center/releases)
[![Downloads](https://img.shields.io/github/downloads/Fede22dev/beauty_center/total)](https://github.com/Fede22dev/beauty_center/releases)

[![License](https://img.shields.io/github/license/Fede22dev/beauty_center)](./LICENSE)
[![wakatime](https://wakatime.com/badge/user/4c30271a-c306-4489-9e2a-7b78bf7ef8cf/project/d191075f-f903-403e-ac53-e0b0daa63e97.svg)](https://wakatime.com/badge/user/4c30271a-c306-4489-9e2a-7b78bf7ef8cf/project/d191075f-f903-403e-ac53-e0b0daa63e97)
[![Last Commit](https://img.shields.io/github/last-commit/Fede22dev/beauty_center)](https://github.com/Fede22dev/beauty_center/commits)

---

## 🧰 Tech Stack

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-46D1FD.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2.svg?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E.svg?logo=supabase&logoColor=white)](https://supabase.com)

---

## ✨ What is Beauty Center?

**Beauty Center** is a **cross-platform app (Windows & Android)** built in **Flutter**.

It helps beauty and wellness centers manage:

- 📅 Appointments
- 🧍‍♀️ Clients
- 💆‍♀️ Treatments
- 📊 Statistics
- ⚙️ Settings

> 🧠 Designed for offline-first usage, with cloud sync.

---

## 🖼️ Architecture

The app follows **clean architecture** with **Riverpod for state management**:

- **Core**: domain models, repositories, services
- **Features**: modular UI screens & logic
- **Data layer**: SQLite Drift (local), Supabase (remote), R2 (cloud storage)

---

## 📦 Install & Run

Clone the repo and fetch dependencies:

```bash
git clone https://github.com/Fede22dev/beauty_center.git
cd beauty_center

flutter pub get

flutter gen-l10n # To generate localization files

dart run build_runner build --delete-conflicting-outputs

dart run flutter_launcher_icons

dart run flutter_native_splash:create

flutter run --dart-define=ADMIN_PIN=.env

flutter run -d windows --dart-define=ADMIN_PIN=.env
```

This app developed and tested only on **Windows** and **Android** especially with **dark theme**

---

## Author

Made with ❤️ by [Fede22dev](https://github.com/Fede22dev)
