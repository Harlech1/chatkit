# ChatKit

Drop-in SwiftUI chat for iOS apps. Let your users message you directly from inside your app — feedback, bug reports, support — and read/reply from a web dashboard at [trychatkit.com](https://trychatkit.com).

- One line of setup
- One SwiftUI view
- No accounts on the user side — anonymous device IDs
- Markdown messages, smooth scroll, native look

## Requirements

- iOS 17+
- Swift 6 / Xcode 16+

## Install

In Xcode: **File → Add Package Dependencies…** and paste:

```
https://github.com/Harlech1/ChatKit
```

Pick **Up to Next Major** from `0.1.0`.

## Setup

1. Sign up at [trychatkit.com](https://trychatkit.com) and create an app to get your API key.
2. Configure ChatKit once at app launch:

```swift
import SwiftUI
import ChatKit

@main
struct MyApp: App {
    init() {
        ChatKit.configure(apiKey: "ck_live_xxxxxxxx")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Use

Drop `ChatKitView()` anywhere — usually behind a "Help" or "Contact us" button:

```swift
import SwiftUI
import ChatKit

struct ContentView: View {
    @State private var showChat = false

    var body: some View {
        Button("Contact support") {
            showChat = true
        }
        .sheet(isPresented: $showChat) {
            NavigationStack {
                ChatKitView()
            }
        }
    }
}
```

That's it. User messages flow to your dashboard, your replies flow back to the user — both ends use the same API key.

## Customizing

```swift
ChatKitView(
    title: "Talk to us",
    accentColor: .indigo
)
```

| Parameter     | Type    | Default  | What it does                       |
| ------------- | ------- | -------- | ---------------------------------- |
| `title`       | String  | `"Chat"` | Navigation bar title               |
| `accentColor` | Color   | `.blue`  | User-bubble color and send button  |

## How it works

- The first time `ChatKitView` appears, ChatKit generates an anonymous device ID and stores it in the Keychain. This ID identifies the user's conversation across launches and reinstalls within the same iCloud Keychain.
- Messages are sent to `https://trychatkit.com/api/v1/messages` with your API key as a Bearer token.
- ChatKit polls every 5 seconds for new replies — no push notifications or websockets to set up.

## Privacy

- No user accounts, emails, or names are collected by ChatKit.
- The only identifier is a random UUID generated on first use.
- Messages are end-to-end visible to you (the developer) on the dashboard.

If you want to attribute messages to your own user IDs, you can prepend that info to the first message — that's coming as a first-class API in a later version.

## Roadmap

- Image attachments (UI is in place; backend support coming)
- Push notifications when developer replies
- User identity API (link ChatKit conversations to your own user IDs)
- Themes / dark mode tuning

## License

MIT
