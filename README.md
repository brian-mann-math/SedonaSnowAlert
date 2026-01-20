# SedonaSnowAlert

A macOS menu bar app that monitors weather forecasts and alerts you when snow is expected in your tracked locations.

## Features

- Monitor multiple cities for snow conditions
- 11-day snow forecast with daily breakdown
- Menu bar icon shows highest snow probability across all locations
- Optional notifications when snow is predicted (>20% chance)
- Automatic weather checks every 6 hours

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building from source)

## Building from Source

### 1. Clone the repository

```bash
git clone https://github.com/brian-mann-math/SedonaSnowAlert.git
cd SedonaSnowAlert
```

### 2. Build with Xcode

**Option A: Using Xcode GUI**

1. Open `SedonaSnowAlert.xcodeproj` in Xcode
2. Select Product > Build (or press Cmd+B)
3. To run, select Product > Run (or press Cmd+R)

**Option B: Using command line**

```bash
xcodebuild -project SedonaSnowAlert.xcodeproj \
           -scheme SedonaSnowAlert \
           -configuration Release \
           -derivedDataPath build
```

The built app will be at `build/Build/Products/Release/SedonaSnowAlert.app`

### 3. Run the app

```bash
open build/Build/Products/Release/SedonaSnowAlert.app
```

## Creating a DMG for Distribution

To create a DMG file that others can use to install the app:

```bash
# Create a temporary folder with the app and Applications symlink
mkdir -p /tmp/SedonaSnowAlert-dmg
cp -R build/Build/Products/Release/SedonaSnowAlert.app /tmp/SedonaSnowAlert-dmg/
ln -sf /Applications /tmp/SedonaSnowAlert-dmg/Applications

# Create the DMG
hdiutil create -volname "SedonaSnowAlert" \
               -srcfolder /tmp/SedonaSnowAlert-dmg \
               -ov -format UDZO \
               SedonaSnowAlert.dmg

# Clean up
rm -rf /tmp/SedonaSnowAlert-dmg
```

## Installation from DMG

1. Download the DMG file from the [Releases](https://github.com/brian-mann-math/SedonaSnowAlert/releases) page
2. Open the DMG file
3. Drag SedonaSnowAlert to your Applications folder
4. Launch from Applications

**Note:** Since the app is not signed with an Apple Developer certificate, you may need to right-click the app and select "Open" the first time you launch it to bypass Gatekeeper.

## Usage

1. Click the snowflake icon in the menu bar to see your tracked locations
2. Click "Add City..." to add new locations to monitor
3. Hover over a location to see the detailed forecast
4. Click on a location to see the 11-day forecast and toggle alerts

## License

MIT License
