# Messenger Mini — macOS chat heads

A tiny, free macOS floating chat-heads panel for Facebook Messenger, inspired by
the classic Messenger chat heads. No third-party dependencies, no network access
from the app itself, no account login.

What it does:
- Shows a **vertical floating panel** on the right edge of the screen with your
  configured conversations as circular avatars (with unread badges).
- **Click an avatar** → a floating **chat window** opens next to the panel with
  that conversation's messages, like the screenshot. Click again to close it.
- Chats with unread messages show a small **preview bubble** next to their
  avatar (click it to open the chat).
- Drag the panel by its top handle to move it; its position is remembered.
- The **"..."** menu lets you collapse/expand the panel, reload the config,
  open the config folder, or quit.

What it does NOT do (yet):
- Message content is **static**, read from your config file. There is no live
  Messenger sync — that needs inbox access, which is not wired up.
- The app never sends messages. Anything that needs the real Messenger
  (replying, calling, the input box) **opens the conversation on
  messenger.com** in your default browser, where you are already logged in.

## Requirements
- macOS Tahoe 26 (also likely to work on recent macOS versions)
- Xcode Command Line Tools or Xcode

## Build & run
1. Open Terminal and move into this folder.
2. Run:
   `chmod +x build.sh`
   `./build.sh`
3. The app is created at `dist/Messenger Mini.app` and launched automatically.
   (If macOS warns because it is an unsigned local app, use Control-click >
   Open on `dist/Messenger Mini.app` in Finder and confirm, only if you built
   it yourself from this source.)
4. On first launch the app creates `~/.messenger-mini/chats.json` with sample
   conversations. Edit that file to add your own chats — the panel reloads
   automatically when you save (if auto-reload ever stops, use "..." > "Tải lại
   cấu hình").

The build script uses Apple's local `swiftc` compiler. It does not disable
Gatekeeper or change system security settings.

## Configuring your chats (`~/.messenger-mini/chats.json`)

```json
{
  "chats": [
    {
      "name": "Mèo Cam",
      "avatar": "/Users/ban/Pictures/meo-cam.png",
      "url": "https://www.messenger.com/t/123456789",
      "unread": 2,
      "preview": "Chà",
      "messages": [
        { "from": "them", "text": "Chà" },
        { "from": "me", "text": "Quá ngon luôn ấy chứ" }
      ]
    }
  ]
}
```

- `name`: shown under the avatar tooltip and in the chat window header.
- `avatar`: a local image path (`~/...` works) or an `https://` URL. Empty
  string (or omitted) falls back to a circle with the first letter of the name.
- `url`: the conversation's link. Open the chat on messenger.com in your
  browser and copy the URL — it looks like `https://www.messenger.com/t/…`.
  Clicking the avatar, the header, or pressing Enter in the input box opens
  this URL.
- `unread`: red badge count on the avatar (0 hides it).
- `preview`: small subtitle under the name in the chat window header. If `unread`
  is greater than 0, it is also shown in the popup bubble next to the avatar.
- `messages`: static messages shown in the chat window. `"from"` is `"them"`
  (grey bubble, left) or `"me"` (blue bubble, right).

## Quit
The app has no Dock icon. Use "..." > "Thoát" in the panel, or from Terminal:
`pkill -x 'Messenger Mini'`

## Notes and limitations
- The panel and chat windows use a floating window level and stay above
  ordinary windows. macOS can restrict floating windows in some full-screen,
  secure, or system-controlled contexts.
- To change the avatar size, edit the `diameter:` values in `Sources/main.swift`.
