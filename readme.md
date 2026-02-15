# Neuro: The Neurodivergent-First AI Assistant 

> **Empowering minds with ADHD, Autism, Dyslexia, and Anxiety through Offline AI and Executive Function Prosthetics.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6-blue.svg)](https://dart.dev)
[![Gemini](https://img.shields.io/badge/Powered%20by-Gemini-orange)](https://deepmind.google/technologies/gemini/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

---

## 📖 Table of Contents
- [About The Project](#-about-the-project)
- [Key Features](#-key-features)
- [Technical Architecture](#-technical-architecture)
- [Installation & Setup (VS Code)](#-installation--setup-vs-code)
- [Mobile Deployment](#-mobile-deployment)
- [Docker Deployment](#-docker-deployment)
- [Privacy & Security](#-privacy--security)

---

## 💡 About The Project

**Neuro** is not just another to-do list; it is an **Executive Function Prosthesis**.

For individuals with neurodivergent conditions (ADHD, Autism, Dyslexia, Anxiety), the gap between *intent* ("I need to clean my room") and *action* is often paralyzed by overwhelm, sensory issues, or executive dysfunction.

Unlike standard to-do lists, Neuro bridges this gap using a **Hybrid AI Approach**:
1.  **Visual Intelligence:** Users snap a photo of their "chaos" (messy room, confusing document).
2.  **Contextual Analysis:** The AI identifies objects and context.
3.  **Micro-Tasking:** It breaks the scene down into tiny, dopamine-rewarding steps adapted to the user's specific neuro-profile (e.g., "Gamified" for ADHD, "Literal" for Autism).

**Uniquely, Neuro features an "Offline Brain" capability, allowing it to function privately and without internet using on-device Large Language Models.**

---

## 🌟 Key Features

### 1. Hybrid AI Engine (Cloud + Edge)
* **Cloud Mode:** Uses Google Gemini Pro for complex reasoning and high-speed planning.
* **Offline Mode (Beta):** Runs a quantized **Gemma 2B** model locally on the device's NPU/GPU. No internet required.

### 2. Visual & Voice Deconstruction
* **See It:** Don't know where to start? Just take a picture. Neuro sees "a pile of laundry" and converts it into: *"Step 1: Find all the socks."*
* **Say It:** Overwhelmed? Just speak your mind. The AI listens and organizes your verbal brain dump into a clear checklist.

### 3. Neuro-Adaptive Interface
* **Visual Deconstruction:** Uses ML Kit to identify objects in photos and convert "chaos" into checklists.
* **Gamification:** Features progress bars and confetti rewards to provide dopamine hits for task completion.
* **Voice Integration:** Includes Speech-to-Text for verbal brain dumps and Text-to-Speech (TTS) for audible guidance.

### 4. Dynamic Neuro-Adaptation
The AI creates a psychological profile based on the user's diagnosis:
* **ADHD:** Steps are gamified quests with time estimates and dopamine rewards (streaks).
* **Autism:** Instructions are literal, logical, and sensory-aware.
* **Dyslexia:** Text is formatted with bullet points, high-contrast fonts (OpenDyslexic), and emojis.
* **Anxiety:** Tone is grounding, reassuring, and focuses on "Micro-Wins."

### 5. Accessibility & Localization
* **Dyslexia Support:** Includes the `OpenDyslexic` font and high-contrast modes.
* **Panic Mode:** A grounding interface designed to reduce anxiety in real-time.

### 6. Zero-Knowledge Privacy
* **Client-Side Encryption:** All chat history and images are encrypted with AES-256 *before* leaving the device.
* **PII Masking:** Automatically detects and redacts names, emails, and phone numbers before sending data to the AI.

---

## 🛠 Technical Architecture

* **Framework:** Flutter 3.41+ (Dart 3.6+)
* **State Management:** Provider
* **On-Device AI:** `flutter_gemma` (MediaPipe GenAI), `google_mlkit_image_labeling`
* **Cloud AI:** Google Gemini API
* **Backend/Sync:** Firebase Firestore (Encrypted Storage), Firebase Auth
* **Security:** `flutter_secure_storage` (Keystore/Keychain), AES-256 Encryption (via `encrypt` package)

---

## 💻 Installation & Setup (VS Code)

Follow these steps to run the source code on your local machine.

### Prerequisites
1.  **Flutter SDK:** Installed and added to PATH ([Guide](https://docs.flutter.dev/get-started/install)). Ensure `flutter doctor` shows version 3.41 or higher.
2.  **VS Code:** With the "Flutter" and "Dart" extensions installed.
3.  **Android Studio / Xcode:** For emulators or physical device drivers.
4.  **Gemini API Key:** Get one from [Google AI Studio](https://aistudio.google.com/).
5.  **Docker:** Required if you want to run the containerized Web Server or host the APK locally.

### Steps

1.  **Clone the Repository**
    Open your terminal and run:
    ```bash
    git clone https://github.com/Newt-Shadow/Neura.git
    cd neura
    ```

2.  **Install Dependencies**
    Download all required packages listed in `pubspec.yaml`:
    ```bash
    flutter pub get
    ```

3.  **Configure Environment Variables**
    Create a `.env` file in the root directory:
    ```env
    GEMINI_API_KEY=your_actual_api_key_here
    ```

4.  **Firebase Setup**
    * This project uses `flutterfire`. You may need to configure your own Firebase project if the existing `firebase_options.dart` is restricted.
    * Run `flutterfire configure` if you have the CLI installed.

5.  **Run the App**
    * Connect a physical device (Recommended for AI features) or start an emulator.
    * Press `F5` in VS Code or run:
    ```bash
    flutter run
    ```

> **Note:** The "Offline AI" feature requires a physical device with decent RAM (min 8GB) and GPU capabilities (Pixel 6+, Samsung S21+, iPhone 12+).

---

## 🐳 Docker Deployment (Web + Android Host)

We provide a specialized Docker setup that serves both the **Web Version** of Neuro and hosts the **Android APK** for easy download to your mobile device.

1.  **Build the Image**
    ```bash
    docker build -t neuro-app .
    ```

2.  **Run the Container (Interactive Mode)**
    * **Note:** You must use the `-it` flag to see the interactive menu and download instructions.
    ```bash
    docker run -it -p 8080:80 --name neuro-container neuro-app
    ```

3.  **Interactive Launch Menu**
    The container will launch a terminal menu allowing you to review Beta warnings and launch the dual-mode server.

4.  **Access the App**
    * **Web Interface:** Open `http://localhost:8080` in Chrome. Nginx will serve the application automatically.
    * **Download APK:** On the web interface, look for an option at the **bottom right** of the screen to download the APK.
    * **Transfer to Mobile:** You can download the APK to your laptop and then transfer it to your mobile device, or access the web server directly from your phone (via your computer's local IP) to download it.

> **Note:** The Web version running in Docker defaults to **Cloud Mode** (API) to ensure stability, as browser-based local LLMs require specific hardware acceleration.

---

## 📱 Installing on Mobile

To judge the full experience, installing on a physical device is recommended.

### Connecting a Physical Device (Android)
1.  **Enable Developer Options:** Go to Settings > About Phone > Tap "Build Number" 7 times.
2.  **Enable USB Debugging:** Go to Settings > System > Developer Options > Enable "USB Debugging".
3.  **Connect:** Plug your phone into your PC via USB.
4.  **Verify:** Run `flutter devices` in your terminal to ensure your phone is recognized.

### Android (APK)
1.  Navigate to the build directory after running the release command:
    ```bash
    flutter build apk --release
    ```
2.  Locate the file at: `build/app/outputs/flutter-apk/app-release.apk`
3.  Transfer `app-release.apk` to your phone via USB or Google Drive.
4.  Tap to install (Enable "Install from Unknown Sources" in settings if prompted).

### iOS (IPA)
1.  Open `ios/Runner.xcworkspace` in Xcode.
2.  Select your Development Team in **Signing & Capabilities**.
3.  Connect your iPhone via USB.
4.  Select your device as the target and click the **Play** (Run) button.

---

## 🎮 How to Use

1.  **Onboarding:** Create a profile. Be honest about your neuro-type (e.g., "ADHD", "Anxiety"). This tunes the AI's personality.
2.  **The Dashboard:**
    * **Task Assistant:** Tap the camera icon to snap a photo of a messy area, or type/speak your goal. The AI will break it down into micro-steps.
    * **Secure History:** Review past plans and chats in the encrypted vault.
    * **Profile:** Toggle "Dyslexia Font" or "Offline Mode" here.
3.  **Offline Mode:** Go to Profile -> Toggle "Use Offline AI". Wait for the model (1.5GB) to download. Once done, you can turn off Wi-Fi and still get planning help!

---

## 🛡️ Privacy & Security

We take safety seriously.
* **Data Redaction:** Before any text is analyzed, a local algorithm scans for patterns like emails (`[REDACTED_EMAIL]`) and phone numbers to ensure they never reach the cloud.
* **Secure Storage:** Chat logs and images are encrypted with AES-256 before being stored. When synced to the cloud for backup, they are encrypted with a key that **is stored in the device's hardware-backed Keystore (Android) or Keychain (iOS)**.
---

**Built with Neurological >_< for the Hackathon.**