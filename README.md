# SeamlessTranslator

SeamlessTranslator is a macOS app that provides quick and easy text translation using either web APIs or local machine learning models.

## Features

### Quick Paste

The Quick Paste feature allows you to:
- Bring the translator window to your current desktop
- Automatically paste clipboard content for translation

**Keyboard shortcut:** ⌘+⇧+P (Command+Shift+P)

#### How to use:
1. Copy text with Command+C in any application
2. Press Command+Shift+P to open the translator with that text

This simple approach works reliably across all applications.

### Setup Instructions

1. **Install the HotKey package:**
   - Open the project in Xcode
   - Go to File > Add Packages...
   - Enter: https://github.com/soffes/HotKey
   - Select "Up to Next Major Version"
   - Click "Add Package"

### Settings

In the app's Settings tab, you can:
- Enable/disable automatic translation after Quick Paste
- Configure translation mode (Web API or Local Model)
- Setup API connections or download local models

## Translation Modes

### Web API
Connect to external translation services by configuring:
- API URL
- Port
- Model name

### Local Model
Use on-device translation with CoreML models:
- Downloads models as needed
- Works offline
- Provides secure, private translation

## Building the Project

1. Open SeamlessTranslator.xcodeproj in Xcode
2. Install the HotKey dependency as described above
3. Build and run the project 