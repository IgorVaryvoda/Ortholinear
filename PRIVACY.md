# Privacy policy

Effective September 5, 2026.

Ortholinear is a Ukrainian and English keyboard for iPhone and iPad, maintained by Igor Varyvoda. Typing works on-device. Optional voice input uses Groq.

## Your typing

Ortholinear does not collect, retain, or transmit what you type. The keyboard delivers input to the app you are typing in; that app handles your text under its own privacy policy. Text in Ortholinear’s test fields stays in memory and is not saved by Ortholinear.

## Settings

Keyboard geometry and your starting language are saved locally in a shared App Group container so the keyboard extension can read them. They are not sent to the developer.

## No tracking or Full Access

The app and keyboard include no analytics, advertising, accounts, or tracking SDKs. The keyboard does not request Full Access and makes no network requests.

## Optional voice input

Voice input records only after you tap Start recording and grant microphone permission in the containing app. Recordings stop when you leave the app or cancel, and are limited to two minutes. Stop and transcribe sends the recording directly over HTTPS to Groq's transcription API using `whisper-large-v3-turbo`. Reaching the two-minute limit also finishes and transcribes the recording. Your selected language is included; surrounding keyboard text is never sent. The developer operates no transcription server and does not receive your recordings or Groq key.

You provide your own Groq API key. It is stored in the containing app's Keychain, accessible only while the device is unlocked, without device migration or iCloud Keychain synchronization. It is not shared with the keyboard extension. It is sent only to Groq to authorize transcription; usage is associated with your Groq account and billed under that account's terms. Remove it with Remove key in Voice input.

Groq receives the audio, produces its transcript, and processes account/request metadata. These requests are linked to your Groq account. Groq may retain inputs and outputs for system reliability or abuse monitoring for up to 30 days, depending on your account's data controls. You may enable Zero Data Retention in Groq's console. See [Groq's current data policy](https://console.groq.com/docs/your-data).

Temporary recordings are deleted after transcription, cancellation, or an error. A transcript stays in memory until you choose Use in keyboard, which saves the latest transcript in the on-device shared App Group with file protection. It is eligible for insertion for ten minutes and inserted only when you tap Insert dictation. The extension keeps a local receipt to avoid inserting it twice. The shared transcript is replaced by the next recording or cleared when Voice input is next opened after expiry; you can also remove it with Clear pending dictation. Local storage is not an automatic ten-minute deletion guarantee. The app does not upload edits you make to a transcript.

## External links and support

Opening support, source code, or this policy in a browser visits GitHub, which has its own privacy policy. Information you choose to include in a public GitHub issue is publicly visible. Do not include private typing, passwords, or other sensitive information in issues.

## Contact and changes

For privacy questions, use [project support](https://github.com/IgorVaryvoda/Ortholinear/issues). Policy changes will be published here with an updated effective date.
