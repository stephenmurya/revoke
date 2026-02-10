# 🛡️ Project Revoke

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-0095D5?style=for-the-badge&logo=kotlin&logoColor=white)](https://kotlinlang.org)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com)

**Revoke** is a social time-management application for Android that replaces traditional "soft" app limits with a "hard" social locking mechanism. It doesn't just ask you to stop scrolling—it makes you answer to the squad.

## 🧠 The Philosophy
Traditional focus apps are easy to bypass. **Revoke** uses social accountability through friction, shame, and peer-governed access. When you're out of time, you don't just click "15 more minutes"—you beg for it.

---

## ✨ Key Features

### 🔍 The Monitor (Core Engine)
A persistent, high-performance Android background service that uses `UsageStatsManager` to track active apps in real-time.
- **Instant Detection**: Detects restricted apps within milliseconds.
- **Smart Caching**: Pre-fetches your app list for instant management.
- **Battery Efficient**: Optimized polling logic to keep your device running all day.

### 🚫 The "COOKED." Blocker
When you hit your limit or enter a restricted time block, Revoke takes over.
- **Hard Lock**: A native `SystemAlertWindow` overlay that sits above everything.
- **Gen Z Aesthetic**: A high-fidelity, pure black/orange "HUD" design.
- **Non-Bypassable**: Redirects you to the home screen if you try to cheat.

### 👥 Social Accountablity (The Squad)
- **Simp Protocol**: To get more time, you must type self-deprecating phrases accurately to prove your desperation.
- **The Squad**: Your friends see your failures. They can approve your time requests or reject them to keep you focused.
- **Vandalism Penalty**: Fail your focus goals? Your squad might just "vandalize" your wallpaper as a badge of shame.

---

## 🛠️ Technical Stack
- **Frontend**: Flutter (v3.x+) with Google Fonts (Space Grotesk & JetBrains Mono).
- **Native Bridge**: Kotlin utilizing `MethodChannels` for deep Android integration.
- **Service**: Foreground Service with `TYPE_APPLICATION_OVERLAY`.
- **Logic**: Real-time scheduling (Time Blocks & Usage Limits).

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK
- Android SDK (API 29+)
- A physical Android device (Overlays and Usage Stats behave best on hardware)

### Installation
1. Clone the repository
   ```bash
   git clone https://github.com/your-username/revoke.git
   ```
2. Get dependencies
   ```bash
   flutter pub get
   ```
3. Run the app
   ```bash
   flutter run
   ```

### Permissions Required
Revoke requires "God Mode" permissions to function:
1. **Usage Access**: To see which apps are currently "cooking" your brain.
2. **Display Over Other Apps**: To serve you the "COOKED." screen when necessary.

---

## 🗺️ Roadmap
- [x] **Phase 1: The Cage** (Local Blocking, Time Blocks, Core UI)
- [ ] **Phase 2: The Social Circle** (Firebase Integration, Squad Invites, Real-time Voting)
- [ ] **Phase 3: The Punishment** (Wallpaper Vandalism, Simp Protocol Validation)

---

## 🛡️ License
Built by the **Revoke Team**. All rights reserved to the Squad.
