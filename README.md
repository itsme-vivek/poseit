# 📸 PoseIt — AI Photo Pose Guide & Aesthetic Camera

**PoseIt** is a modern Flutter mobile application designed to eliminate awkward photo moments. By combining real-time on-device AI pose detection with high-fidelity realistic line-art silhouette overlays, PoseIt guides subjects and photographers into effortless, natural, and aesthetic poses.

---

## ✨ Features

- **🎯 Real-Time AI Pose Matching**:
  - Live on-device human pose detection using Google ML Kit.
  - Dynamic pose match meter (0–100%) that turns vibrant cyan/green when your posture aligns with the silhouette.
  - Multi-gender & scene matching for Men, Women, and Couples.

- **🎨 Curated Pose Library (90+ Poses)**:
  - **Men**: Casual polo stances, phone scroll & chin touch, arms crossed in cap, moody umbrella walk, seated forward lean, table rest, and more.
  - **Women**: Streetwear crouches, stool chill, portrait tilts, hair tucks, candid walks.
  - **Couples**: Romantic forehead leans, back-to-back, walking hand-in-hand, sunset silhouettes.
  - **Aesthetic (Gen-Z & Streetwear)**: 0.5x ultra-wide high-angle shots, yo-yo / prop reaches, Y2K framing, low-angle kick showcases.

- **📐 Anatomical Body Mapping Aids**:
  - One-tap framing presets: `🧍 Full Body` (0.8x), `🪑 Seated / Mid` (1.0x), `👤 Bust Portrait` (1.4x).
  - Visual guides: Eye-level guide line, Seat/Base guideline, Center alignment crosshair.
  - Interactive 5-step numbered physical cues accessible directly within the viewfinder.

- **🎞️ Aesthetic Filters & Retro Camera FX**:
  - Vintage Y2K digital camera orange date stamp (`'00 11 17`).
  - Curated color grades: Retro 90s, Film Noir, Golden Hour, Cyber Glow.

- **🔒 100% Offline & Private**:
  - Zero cloud dependencies or external server calls. All machine learning inference runs directly on your device.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24.0 or higher)
- Android SDK (API level 24 / Android 7.0 or higher)
- Real Android device or emulator with camera support

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/itsme-vivek/poseit.git
   cd poseit
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run static analysis & tests**:
   ```bash
   flutter analyze --no-fatal-infos
   flutter test
   ```

4. **Run on connected device**:
   ```bash
   flutter run
   ```

5. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **Computer Vision**: [Google ML Kit Pose Detection](https://developers.google.com/ml-kit/vision/pose-detection)
- **Camera Engine**: CameraX (`camera` plugin)
- **Vector Graphics**: `flutter_svg`
- **State Management**: Reactive Flutter setState & ValueNotifiers
- **Styling**: Cyber / Dark Aesthetic UI with glassmorphism overlays

---

## 📄 License
This project is open-source under the MIT License.
