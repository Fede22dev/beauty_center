# 💅 Beauty Center

> Cross-platform (Windows & Android) app manager for beauty and wellness centers — powered by
> Flutter, Drift & Supabase.

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

[![Flutter](https://img.shields.io/badge/Flutter-3.41+-46D1FD.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2.svg?logo=dart&logoColor=white)](https://dart.dev)
[![Drift](https://img.shields.io/badge/Local_DB-Drift-6949ff.svg)](https://drift.simonbinder.eu/)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E.svg?logo=supabase&logoColor=white)](https://supabase.com)
[![Riverpod](https://img.shields.io/badge/State-Riverpod-204682.svg)](https://riverpod.dev)

---

## ✨ What is Beauty Center?

**Beauty Center** is a **cross-platform app (Windows & Android)** built in **Flutter** for managing
beauty and wellness centers.

### 🎯 Key Features

- 📅 **Appointments**: Schedule with drag-and-drop calendar, conflict detection, service bundles
- 🧍‍♀️ **Clients**: Complete CRM with phone sync, history tracking, notes
- 💆‍♀️ **Treatments**: Service catalog with customizable prices and durations
- 📋 **Quotes**: Create professional estimates, convert to packages
- 📦 **Packages**: Multi-session bundles with payment tracking
- 💳 **Fidelity Cards**: Prepaid credit system with transaction history
- 💰 **Payments**: Multi-method tracking (cash, card, transfer, fidelity)
- 🛍️ **Product Sales**: Inventory with locked pricing at sale time
- 📊 **Statistics**: Business insights and reporting
- ⚙️ **Settings**: Operators, cabins, work hours, blocked slots

### 🔌 Offline-First Architecture

> 🧠 **Read-Only Offline Mode**: When connection is lost, the app switches to read-only mode. All
> data remains accessible for viewing, but modifications are disabled until connection is restored.

---

## 🏗️ Architecture

```
lib/
├── core/                    # Foundation layer
│   ├── connectivity/        # Network state management
│   ├── database/            # Drift (SQLite) + Supabase schema
│   ├── providers/           # Global state (offline status, auth)
│   ├── sync/                # Sync orchestration
│   ├── theme/               # App theming
│   └── widgets/             # Shared UI components
│
├── features/                # Feature modules
│   ├── appointments/        # Calendar, scheduling, conflicts
│   ├── clients/             # CRM, contacts sync
│   ├── fidelity/            # Loyalty cards, transactions
│   ├── packages/            # Service bundles
│   ├── payments/            # Payment tracking
│   ├── product_sales/       # Product inventory
│   ├── products/            # Product catalog
│   ├── quotes/              # Estimates & proposals
│   ├── settings/            # Configuration
│   ├── statistics/          # Analytics
│   └── treatments/          # Services catalog
│
├── home/                    # Main dashboard
├── l10n/                    # Localization (i18n)
└── main.dart                # App entry point
```

### 🔧 Technical Design Patterns

| Layer                | Technology                   | Purpose                        |
|----------------------|------------------------------|--------------------------------|
| **State Management** | Riverpod + Code Generation   | Reactive, testable state       |
| **Local Database**   | Drift (SQLite)               | Offline data, fast queries     |
| **Remote Backend**   | Supabase (PostgreSQL)        | Cloud sync, realtime, auth     |
| **Sync Strategy**    | Delta sync + Realtime        | Efficient data synchronization |
| **UI Framework**     | Material 3 + FlexColorScheme | Modern, accessible design      |
| **Logging**          | Talker                       | Comprehensive debugging        |

---

## 📦 Install & Run

### Prerequisites

- Flutter SDK >= 3.41.6
- Dart SDK >= 3.11.0
- Android Studio / VS Code
- Windows 10+ or Android SDK

### Setup

```bash
# 1. Clone repository
git clone https://github.com/Fede22dev/beauty_center.git
cd beauty_center

# 2. Install dependencies
flutter pub get

# 3. Generate localization files
flutter gen-l10n

# 4. Generate code (Riverpod, Drift, etc.)
dart run build_runner build --delete-conflicting-outputs

# 5. Generate assets
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Database Setup

1. Create a [Supabase](https://supabase.com) project
2. Run the SQL script in `Supabase_SQL_Setup.sql` in the SQL Editor
3. Enable Realtime for all tables
4. Set Row Level Security (RLS) policies as defined in the SQL

### Configuration

Create a secure storage entry for Supabase credentials:

```bash
# Windows (PowerShell)
flutter run -d windows --dart-define=ADMIN_PIN=your_secure_pin

# Android
flutter run -d android --dart-define=ADMIN_PIN=your_secure_pin
```

For production builds, configure CI/CD secrets in GitHub Actions.

---

## 🔄 Data Synchronization

### Sync Architecture

1. **Local-First Writes**: All changes saved to Drift (SQLite) immediately
2. **Async Cloud Sync**: Non-blocking push to Supabase
3. **Delta Pull**: Only fetch changed records since last sync
4. **Realtime Updates**: Live sync from remote to local via WebSocket

### Sync Order (Dependencies)

```
1. Settings, Clients, Services, Products (base tables)
2. Operators, Blocked Slots, Appointments
3. Quotes, Packages, Fidelity Cards
4. Payments, Product Sales
```

---

## 🌐 Offline Behavior

| Mode                | Behavior        | Data Access              |
|---------------------|-----------------|--------------------------|
| **Online**          | Full read/write | All operations           |
| **Offline**         | Read-only       | View-only, no edits      |
| **Poor Connection** | Queued writes   | Optimistic UI with retry |

When offline:

- All creation buttons disabled
- All edit forms disabled
- All delete actions disabled
- Data remains fully viewable
- Automatic re-sync on reconnection

---

## 🧪 Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Check code analysis
flutter analyze

# Verify formatting
dart format --set-exit-if-changed .
```

---

## 📱 Supported Platforms

| Platform      | Status      | Notes                     |
|---------------|-------------|---------------------------|
| Windows 10/11 | ✅ Primary   | Full-featured desktop app |
| Android       | ✅ Supported | Mobile-optimized UI       |
| iOS           | ⚠️ Untested | Should work, not verified |
| macOS         | ⚠️ Untested | Should work, not verified |
| Linux         | ⚠️ Untested | Community testing welcome |

---

## 🛠️ Development Commands

```bash
# Generate code after model changes
dart run build_runner build --delete-conflicting-outputs

# Watch for changes during development
dart run build_runner watch

# Generate database schema visualization
dart run drift_dev schema dump

# Build release APK
flutter build apk --release

# Build Windows installer
flutter build windows --release
```

---

## 📝 Project Structure Notes

### Database Schema

The app uses a **unified schema** across Drift (local) and Supabase (remote):

- **Core Tables**: appointments, clients, services, operators, cabins
- **Business Tables**: quotes, packages, fidelity_cards, payments
- **Junction Tables**: appointment_services, package_items, quote_items
- **Transaction Tables**: fidelity_transactions, product_sales

All tables support:

- Soft deletes (`is_active` column)
- Timestamps (`created_at`, `updated_at`)
- UUID primary keys (v7 for local, gen_random_uuid() for remote)

### Constants & Validation

Validation limits are defined in `lib/core/constants/app_constants.dart`:

- String length constraints
- Numeric ranges
- Enum definitions (PaymentMethod, DiscountType)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file.

---

## 🙏 Acknowledgments

- [Flutter Team](https://flutter.dev) for the amazing framework
- [Supabase](https://supabase.com) for open-source Firebase alternative
- [Drift](https://drift.simonbinder.eu/) for type-safe SQLite
- [Riverpod](https://riverpod.dev) for elegant state management

---

## Author

Made with ❤️ by [Fede22dev](https://github.com/Fede22dev)

---
