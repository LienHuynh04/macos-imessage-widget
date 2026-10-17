# iMessage Mini — macOS

A tiny, free macOS floating bubble prototype. Click the blue bubble to open Apple's Messages app; drag it to move it. It does **not** read or send messages itself.

## Requirements
- macOS Tahoe 26 (also likely to work on recent macOS versions)
- Xcode Command Line Tools or Xcode
- No third-party dependencies, network access, account login, or special permissions

## Build the app
1. Open Terminal.
2. Move into this folder, for example:
   `cd ~/Downloads/iMessageMini`
3. Run:
   `chmod +x build.sh`
   `./build.sh`
4. The app will be created at `dist/iMessage Mini.app`.
5. Double-click it in Finder. If macOS warns because it is an unsigned local app, use Control-click > Open and confirm, only if you built it yourself from this source.

The build script uses Apple's local `swiftc` compiler and creates an unsigned local app. It does not disable Gatekeeper or change system security settings.

## Quit
Because this is a small accessory app without a Dock icon, use Activity Monitor to quit `iMessage Mini`, or quit it from Terminal:
`pkill -x 'iMessage Mini'`

## Notes and limitations
- The bubble uses a floating window level and is intended to stay above ordinary windows.
- macOS can restrict floating windows in some full-screen, secure, or system-controlled contexts.
- This prototype opens Messages; it does not create a real iMessage chat head, show message previews, or send/receive messages independently.
- To change the bubble's size, edit `let size: CGFloat = 66` in `Sources/main.swift`.
# macos-imessage-widget
