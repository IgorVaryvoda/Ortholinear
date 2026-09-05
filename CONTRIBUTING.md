# Contributing

Bug reports and focused pull requests are welcome. For larger changes, open an issue first to discuss the approach.

Use Xcode with Swift 6 and the iOS 17+ SDK. The project has no third-party dependencies. Run `swift test` for core tests, then the relevant simulator tests documented in the README. Keep layout and input behavior covered by focused tests. Do not add networking, typed-text logging, or Full Access requirements without discussing the privacy implications first.

`project.yml` is the XcodeGen source of truth. If project configuration changes, regenerate and commit the Xcode project as well. Use your own signing team locally; do not commit credentials, provisioning profiles, build outputs, or Xcode user settings.

By contributing, you agree that your contributions are licensed under the project’s MIT license.
