# 🎙️ VoiceFlow

> [!IMPORTANT]
> ### `v0.6.0` is here — Memory that works.
>
> VoiceFlow is a macOS menu-bar voice typing app for people who think faster
> than they type. Hold `Fn`, speak naturally, release, and your words land in
> the focused app as clean text.
>
> → [**Download the latest DMG**](https://github.com/Raunaks068619/VoiceFlow/releases/latest) · [Install with Homebrew](#-quickstart) · [Fix permissions](#-permissions)

> **The local-first voice typing app for macOS.** Fast English dictation on the
> free Groq path, multilingual/Hinglish workflows with your OpenAI key, local
> run logs for every dictation, Magic Words for spoken commands, and a Memory
> graph that turns past transcripts into searchable context.

<p align="center">
  <a href="https://github.com/Raunaks068619/VoiceFlow/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=ffd700&logo=github&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/network/members"><img alt="Forks" src="https://img.shields.io/github/forks/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=2ecc71&logo=github&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/issues"><img alt="Issues" src="https://img.shields.io/github/issues/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=ff6b6b&logo=github&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/pulls"><img alt="Pull Requests" src="https://img.shields.io/github/issues-pr/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=9b59b6&logo=github&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/graphs/contributors"><img alt="Contributors" src="https://img.shields.io/github/contributors/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=3498db&logo=github&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/commits/main"><img alt="Commit activity" src="https://img.shields.io/github/commit-activity/m/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=e67e22&logo=git&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/Raunaks068619/VoiceFlow?style=for-the-badge&labelColor=0d1117&color=8e44ad&logo=git&logoColor=white" /></a>
</p>

<p align="center">
  <a href="https://github.com/Raunaks068619/VoiceFlow/releases/latest"><img alt="Download" src="https://img.shields.io/badge/download-latest%20DMG-ff6b35?style=flat-square&logo=github&logoColor=white" /></a>
  <a href="https://github.com/Raunaks068619/VoiceFlow/releases"><img alt="Latest release" src="https://img.shields.io/github/v/release/Raunaks068619/VoiceFlow?style=flat-square&color=blueviolet&label=release&display_name=tag" /></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" /></a>
  <a href="#-quickstart"><img alt="Quickstart" src="https://img.shields.io/badge/quickstart-brew%20install-brightgreen?style=flat-square" /></a>
  <a href="#-permissions"><img alt="Permissions" src="https://img.shields.io/badge/permissions-mic%20%2B%20accessibility%20%2B%20input%20monitoring-111111?style=flat-square&logo=apple&logoColor=white" /></a>
  <a href="#-at-a-glance"><img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-111111?style=flat-square&logo=apple&logoColor=white" /></a>
  <a href="#-at-a-glance"><img alt="Language" src="https://img.shields.io/badge/language-Swift-f05138?style=flat-square&logo=swift&logoColor=white" /></a>
  <a href="#-transcription-pipeline"><img alt="Providers" src="https://img.shields.io/badge/providers-Groq%20%2B%20OpenAI%20%2B%20local-008080?style=flat-square" /></a>
  <a href="#-hotkeys"><img alt="Hotkeys" src="https://img.shields.io/badge/hotkeys-Fn%20%2F%20Right%20Option-3498db?style=flat-square" /></a>
  <a href="#-output-modes"><img alt="Output modes" src="https://img.shields.io/badge/output-4%20modes-8e44ad?style=flat-square" /></a>
</p>

---

## 🧭 Why this exists

macOS dictation is fine until you need real workflow speed: a global hotkey,
cleanup that respects intent, bilingual output, reliable insertion, and a way
to debug what the model actually heard.

VoiceFlow is built for that gap:

- **Speak anywhere** — Slack, Cursor, Notes, Mail, browser fields, terminals.
- **Choose the output** — raw transcript, cleaned text, Hinglish, or English translation.
- **Keep the receipts** — run logs save audio, raw STT, prompts, final text, timing, and errors locally.
- **Command the app by voice** — Magic Words turn phrases into repeatable actions.
- **Remember the work** — Memory indexes past runs into a graph and chat surface.

## ⚡ At a glance

| | What you get |
|---|---|
| **Trigger** | Hold `Fn` anywhere on macOS, speak, release to type into the active app. |
| **Fallback hotkey** | `Right Option` when the `Fn` / globe key is owned by macOS. |
| **Transcription** | Groq for fast English dictation; OpenAI for multilingual and Hinglish workflows. |
| **Polish** | Groq, OpenAI, LM Studio, or Ollama through OpenAI-compatible chat endpoints. |
| **Output modes** | `Verbatim`, `Clean`, `Hinglish`, and `English` translation. |
| **Processing modes** | `Dictation` preserves phrasing; `Rewrite` tightens final intent. |
| **Run Log** | Local audit trail for audio, raw text, final text, prompts, model, latency, and errors. |
| **Memory** | Knowledge graph and chat over past dictations. |
| **Magic Words** | Spoken command aliases with editable triggers. |
| **Packaging** | Homebrew cask, unsigned DMG, and signed/notarized release script support. |
| **Platform** | macOS 13+, SwiftUI + AppKit, menu-bar app with no Dock icon by design. |

## 🖼️ Demo

<table>
<tr>
<td width="50%" valign="top">
<img width="299" alt="VoiceFlow menu bar popover" src="https://github.com/user-attachments/assets/ebc1b997-a68b-48a8-947c-ec3a7d0255bd" /><br/>
<sub><b>Menu bar popover</b> — lightweight control surface for recording and status.</sub>
</td>
<td width="50%" valign="top">
<img width="471" alt="VoiceFlow settings" src="https://github.com/user-attachments/assets/b404a794-d1c3-42d9-a53b-af5d75ef8db9" /><br/>
<sub><b>Settings</b> — provider keys, language, output style, and permission health.</sub>
</td>
</tr>
<tr>
<td width="50%" valign="top">
<img width="472" alt="VoiceFlow advanced settings" src="https://github.com/user-attachments/assets/d4e89312-a0c6-4f2b-a536-d4c1a18a1296" /><br/>
<sub><b>Advanced settings</b> — tune mic filtering and local workflow details.</sub>
</td>
<td width="50%" valign="top">
<img width="521" alt="VoiceFlow onboarding flow" src="https://github.com/user-attachments/assets/b87bebd1-1d53-4f86-a7ca-bf342eeacdda" /><br/>
<sub><b>Onboarding</b> — permission setup stays visible until the app is actually usable.</sub>
</td>
</tr>
<tr>
<td width="50%" valign="top">
<img width="764" alt="English transcription example" src="https://github.com/user-attachments/assets/41bb65bd-d3f4-45d5-9410-030d93679b4b" /><br/>
<sub><b>English dictation</b> — clean transcript output with paste-based insertion.</sub>
</td>
<td width="50%" valign="top">
<img width="700" alt="Hindi English Hinglish example" src="https://github.com/user-attachments/assets/9da697fd-1575-49cc-b339-2396dfd0c1f4" /><br/>
<sub><b>Hinglish mode</b> — Hindi + English speech normalized into readable Latin script.</sub>
</td>
</tr>
</table>

## 🚀 Quickstart

### Homebrew install

```bash
brew install --cask raunaks068619/voiceflow/voiceflow
```

### Manual DMG install

1. Download the latest DMG from [Releases](https://github.com/Raunaks068619/VoiceFlow/releases/latest).
2. Drag `VoiceFlow.app` to `/Applications`.
3. Right-click → Open on first launch.
4. If macOS blocks the unsigned build, run:

```bash
xattr -dr com.apple.quarantine /Applications/VoiceFlow.app
codesign --force --deep --sign - /Applications/VoiceFlow.app
open /Applications/VoiceFlow.app
```

### Run from source

1. Open `VoiceFlow.xcodeproj` in Xcode 15+.
2. Select the `VoiceFlow` scheme.
3. Run `Product -> Run`.

VoiceFlow runs as a menu-bar app, so it intentionally does not show a Dock icon.

## 🔐 Permissions

VoiceFlow needs three macOS permissions:

| Permission | Why it is needed |
|---|---|
| **Microphone** | Capture audio while the hotkey is held. |
| **Accessibility** | Insert transcribed text into the focused app. |
| **Input Monitoring** | Listen for the global `Fn` / fallback hotkey. |

If any permission is missing, hotkeys are disabled, the menu shows a warning,
and Settings surfaces a quick-fix action.

For a full walkthrough, including managed Mac / MDM edge cases, read
[PERMISSIONS.md](./PERMISSIONS.md).

## ⌨️ Hotkeys

| Hotkey | Use |
|---|---|
| `Fn` | Primary hold-to-talk trigger. |
| `Right Option` | Fallback when macOS owns the globe / `Fn` key. |

If `Fn` does not work:

1. Set `System Settings -> Keyboard -> Press 🌐 key to` to `Do Nothing`.
2. Disable or reassign the Dictation shortcut from `Press 🌐 Twice`.
3. Use the `Right Option` fallback.

## ✍️ Output modes

| Mode | Best for |
|---|---|
| `Verbatim` | Closest possible output to the raw transcript. |
| `Clean` | English cleanup: remove fillers, fix punctuation, preserve meaning. |
| `Hinglish` | Hindi + English speech normalized into readable Latin script. |
| `English` | Translate spoken input into natural English. |

Processing mode changes how much VoiceFlow rewrites:

- `Dictation` preserves your phrasing.
- `Rewrite` tightens grammar and collapses restarts.

## 🧠 Transcription pipeline

```text
Hotkey -> Audio capture -> Voice activity filtering -> STT provider
      -> Output mode router -> Optional polish / translation -> Text injection
      -> Local run log -> Memory index
```

Provider behavior:

| Provider | Use it for |
|---|---|
| **Groq** | Fast English dictation with the free path. |
| **OpenAI** | Hindi, Hinglish, translation, and multilingual workflows. |
| **LM Studio / Ollama** | Local polish and Memory chat through OpenAI-compatible endpoints. |

## 🪄 Magic Words

Magic Words are voice-triggered command aliases. They are designed for short,
repeatable phrases like `git wip`, `list namespaces`, `describe pods`, or a
personal workflow command you want VoiceFlow to expand reliably.

The app exposes them as a first-class dashboard tab so supported commands are
discoverable instead of hidden in code.

## 🧾 Run Log + Memory

Every dictation can be saved locally with:

- raw transcription
- final text
- output mode and model
- prompt metadata
- latency
- source audio path
- error details

Memory builds on that local history with searchable runs, entity extraction,
a graph view, and chat over previous dictations.

## 📦 Releases

### Signed + notarized DMG

Use the release script when you have Apple Developer ID credentials:

```bash
scripts/release_dmg.sh \
  --version v1.0.0 \
  --app-path dist/VoiceFlow.app \
  --bundle-id com.voiceflow.app
```

Required environment:

- `DEVELOPER_ID_APP_CERT`
- `NOTARYTOOL_KEYCHAIN_PROFILE`, or
- `APPLE_ID` + `APPLE_APP_SPECIFIC_PASSWORD` + `TEAM_ID`

### Unsigned build

Unsigned builds are supported for open-source testing, but macOS quarantine
must be cleared once after install. See [INSTALL.md](./INSTALL.md) for the
full explanation and friend-testing flow.

## 🛠️ Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Hotkey does nothing | Input Monitoring missing or `Fn` is remapped | Grant Input Monitoring, then check Keyboard settings. |
| Recording works but no text appears | Accessibility missing or no focused text field | Grant Accessibility and click into a text field before recording. |
| No audio captured | Microphone missing or wrong input device | Grant Microphone and verify the selected input. |
| `Fn` conflicts with macOS | Globe key behavior is assigned to another action | Set `Press 🌐 key to` to `Do Nothing`, or use `Right Option`. |
| Wrong language/script style | Output mode or provider mismatch | Use `Hinglish` / `English` with an OpenAI key for multilingual workflows. |
| App says damaged or will not reopen | Unsigned build quarantined by Gatekeeper | Run the `xattr` + `codesign --sign -` fix from Quickstart. |

## 📁 Project structure

```text
Sources/App        App lifecycle, hotkey handling, menu-bar behavior
Sources/Services   audio, transcription, memory, Magic Words, text injection
Sources/Views      dashboard, onboarding, settings, run log, memory graph
Resources          plist, entitlements, app resources
scripts            build, install, release, signing, verification helpers
docs               planning notes and feature documentation
```

## 📄 License

MIT — see [LICENSE](./LICENSE).

MIT covers source-code copyright. It does not replace Apple Developer ID
signing or notarization for a frictionless macOS DMG install.
