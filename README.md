# 📬 AutoFlow – Complete AI Device Automation

<p align="center">
  <img src="assets/logo.png" width="120" alt="AutoFlow Logo" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white"/>
  <img src="https://img.shields.io/badge/Isar_DB-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white"/>
  <img src="https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge"/>
</p>

<p align="center">
  <strong>AutoFlow</strong> is a beautiful, highly polished automation scheduling app built in Flutter. It allows you to schedule device workflows like sending WhatsApp messages, interacting with Instagram, and creating custom routines to run at your desired time, completely hands-free.
</p>

---

## ✨ Features

- **Automated Workflow Execution:** Schedule tasks to run seamlessly in the background at your desired time.
- **Cross-Platform Scheduling:** Integrates with WhatsApp and Instagram for automated messaging and interactions.
- **Smart Unlocking Support:** Built to support background awakening and execution flows (requires Accessibility Service implementation).
- **Permanent History:** All scheduled automations and past logs are persistently saved to a beautifully animated dashboard.
- **Stunning Modern UI:** Built with a vibrant Primary Blue and Clean White aesthetic, featuring `flutter_animate` staggered lists and silky smooth bouncing scroll physics.
- **Local Storage Engine:** Utilizing Isar Database and SharedPreferences to keep all scheduled data persistently saved on your device offline.
- **Background Dispatcher:** WorkManager powered background execution to trigger your workflows reliably.

---

## ⚠️ Technical Note on Device Automation

AutoFlow's UI and scheduling engine are built in pure Flutter. However, deep OS-level device automation (like bypassing lock screens or simulating clicks inside third-party apps like WhatsApp/Instagram) requires native Android **AccessibilityService** and **DeviceAdmin** implementations, which are subject to strict OS security policies and are implemented at the native layer.

---

## 💻 How to Build (For Developers)

Before you begin, ensure you have the **Flutter SDK** installed on your system.

### Step 1 — Clone the Repository
```bash
git clone https://github.com/HelloWorld-Farhan/AutoFlow-Flutter.git
cd AutoFlow-Flutter
```

### Step 2 — Fetch Dependencies
```bash
flutter pub get
```

### Step 3 — Generate Isar Models
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 4 — Run Locally
```bash
flutter run
```

### Step 5 — Build the APK Release
```bash
flutter build apk --release
```
*Your `app-release.apk` file will be generated inside `build/app/outputs/flutter-apk/`.*

---

## 👨‍💻 Author

**Farhan Khalid**  
📧 farhankhalid17968@gmail.com  
🔗 [LinkedIn](https://www.linkedin.com/in/farhan-khalid-117514259/)  
🐙 [GitHub](https://github.com/HelloWorld-Farhan)  

---

## 📄 License

```text
MIT License

Copyright (c) 2026 Farhan Khalid

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

## 🌟 Support

If you found this app helpful, please consider giving it a ⭐ on GitHub!

<p align="center">Made with ❤️ in India</p>
