# Neura: The Neurodivergent-First AI Assistant 🧠✨

> **Empowering minds with ADHD, Autism, Dyslexia, and Anxiety through Offline AI and Executive Function Prosthetics.**

[![Flutter](https://img.shields.io/badge/Flutter-3.27-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.6-blue.svg)](https://dart.dev)
[![Gemini](https://img.shields.io/badge/Powered%20by-Gemini-orange)](https://deepmind.google/technologies/gemini/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

---

## 📖 Table of Contents
- [Neura: The Neurodivergent-First AI Assistant 🧠✨](#neura-the-neurodivergent-first-ai-assistant-)
  - [📖 Table of Contents](#-table-of-contents)
  - [💡 About The Project](#-about-the-project)
  - [🌟 Key Features](#-key-features)
    - [1. 🤖 Hybrid AI Engine (Cloud + Edge)](#1--hybrid-ai-engine-cloud--edge)
    - [2. 👁️ Visual Deconstruction](#2-️-visual-deconstruction)
    - [3. 🧬 Dynamic Neuro-Adaptation](#3--dynamic-neuro-adaptation)
    - [4. 🔒 Zero-Knowledge Privacy](#4--zero-knowledge-privacy)
  - [🛠 Technical Architecture](#-technical-architecture)
  - [💻 Installation \& Setup (VS Code)](#-installation--setup-vs-code)
    - [Prerequisites](#prerequisites)
    - [Steps](#steps)
  - [🐳 Running with Docker](#-running-with-docker)
  - [📱 Installing on Mobile](#-installing-on-mobile)
    - [Android (APK)](#android-apk)
    - [iOS (IPA)](#ios-ipa)
  - [🎮 How to Use](#-how-to-use)
  - [🛡️ Privacy \& Security](#️-privacy--security)

---

## 💡 About The Project

**Neura** is not just another to-do list; it is an **Executive Function Prosthesis**.

For individuals with neurodivergent conditions (ADHD, Autism, Dyslexia, Anxiety), the gap between *intent* ("I need to clean my room") and *action* is often paralyzed by overwhelm, sensory issues, or executive dysfunction.

Neura bridges this gap using a **Hybrid AI Approach**:
1.  **Visual Intelligence:** Users snap a photo of their "chaos" (messy room, confusing document).
2.  **Contextual Analysis:** The AI identifies objects and context.
3.  **Micro-Tasking:** It breaks the scene down into tiny, dopamine-rewarding steps adapted to the user's specific neuro-profile (e.g., "Gamified" for ADHD, "Literal" for Autism).

**Uniquely, Neura features an "Offline Brain" capability, allowing it to function privately and without internet using on-device Large Language Models.**

---

## 🌟 Key Features

### 1. 🤖 Hybrid AI Engine (Cloud + Edge)
* **Cloud Mode:** Uses Google Gemini Pro for complex reasoning and high-speed planning.
* **Offline Mode (Beta):** Runs a quantized **Gemma 2B** model locally on the device's NPU/GPU. No internet required.

### 2. 👁️ Visual Deconstruction
* Don't know where to start? Just take a picture.
* Neura sees "a pile of laundry" and converts it into: *"Step 1: Find all the socks."*

### 3. 🧬 Dynamic Neuro-Adaptation
The AI creates a psychological profile based on the user's diagnosis:
* **ADHD:** Steps are gamified quests with time estimates.
* **Autism:** Instructions are literal, logical, and sensory-aware.
* **Dyslexia:** Text is formatted with bullet points, high-contrast fonts (OpenDyslexic), and emojis.
* **Anxiety:** Tone is grounding, reassuring, and focuses on "Micro-Wins."

### 4. 🔒 Zero-Knowledge Privacy
* **Client-Side Encryption:** All chat history and images are encrypted with AES-256 *before* leaving the device.
* **PII Masking:** Automatically detects and redacts names, emails, and phone numbers before sending data to the AI.

---

## 🛠 Technical Architecture

* **Framework:** Flutter (Dart)
* **State Management:** Provider
* **On-Device AI:** `flutter_gemma` (MediaPipe GenAI), `google_mlkit_image_labeling`
* **Cloud AI:** Google Gemini API
* **Backend/Sync:** Firebase Firestore (Encrypted Storage), Firebase Auth
* **Security:** `flutter_secure_storage` (Keystore/Keychain), `encrypt` package

---

## 💻 Installation & Setup (VS Code)

Follow these steps to run the source code on your local machine.

### Prerequisites
1.  **Flutter SDK:** Installed and added to PATH ([Guide](https://docs.flutter.dev/get-started/install)).
2.  **VS Code:** With the "Flutter" and "Dart" extensions installed.
3.  **Android Studio / Xcode:** For emulators or physical device drivers.
4.  **Gemini API Key:** Get one from [Google AI Studio](https://aistudio.google.com/).

### Steps

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/your-username/neura.git](https://github.com/your-username/neura.git)
    cd neura
    ```

2.  **Install Dependencies**
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

> **Note:** The "Offline AI" feature requires a physical device with decent RAM (min 4GB) and GPU capabilities (Pixel 6+, Samsung S21+, iPhone 12+).

---

## 🐳 Running with Docker

If you want to build the web version or run a clean containerized environment for development.

1.  **Build the Image**
    ```bash
    docker build -t neura-app .
    ```

2.  **Run the Container**
    ```bash
    docker run -d -p 8080:80 --name neura-container neura-app
    ```

3.  **Access App**
    Open `http://localhost:8080` in your browser.
    *(Note: Offline LLM features are disabled in the web/docker version due to browser limitations).*

---

## 📱 Installing on Mobile

### Android (APK)
1.  Navigate to the `build/app/outputs/flutter-apk/` directory after running:
    ```bash
    flutter build apk --release
    ```
2.  Transfer `app-release.apk` to your phone.
3.  Tap to install (Enable "Install from Unknown Sources" in settings).

### iOS (IPA)
1.  Open `ios/Runner.xcworkspace` in Xcode.
2.  Select your Development Team in Signing & Capabilities.
3.  Connect your iPhone.
4.  Product -> Archive (or run directly via Play button).

---

## 🎮 How to Use

1.  **Onboarding:** Create a profile. Be honest about your neuro-type (e.g., "ADHD", "Anxiety"). This tunes the AI.
2.  **The Dashboard:**
    * **Task Assistant:** Tap the camera icon. Take a photo of a messy desk. The AI will break it down.
    * **Translator:** Use the AR translator for confusing documents.
    * **Profile:** Toggle "Dyslexia Font" or "Offline Mode" here.
3.  **Offline Mode:** Go to Profile -> Toggle "Use Offline AI". Wait for the model (1.5GB) to download. Once done, you can turn off Wi-Fi and still get planning help!

---

## 🛡️ Privacy & Security

We take safety seriously.
* **Data Redaction:** Before any text is analyzed, a local algorithm scans for patterns like emails (`[REDACTED_EMAIL]`) and phone numbers to ensure they never reach the cloud.
* **Secure History:** Chat logs are stored locally. When synced to the cloud for backup, they are encrypted with a key that **only exists on your device**. We cannot read your chats.

---

**Built with Neurological >_< for the Hackathon.**