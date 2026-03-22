# SatsBuddy

*Experimental*

An iPhone app companion for SATSCARD.

Download on [TestFlight](https://testflight.apple.com/join/Pq7KwWzB).

## Dependencies

- [bdk-swift](https://github.com/bitcoindevkit/bdk-swift)

- [BitcoinUI](https://github.com/reez/BitcoinUI)

- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

- [rust-cktap](https://github.com/bitcoindevkit/rust-cktap)

## Running SatsBuddy Locally

### Prerequisites

- Xcode (and Xcode Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Git

You can verify the required tools are installed with:

```bash
xcodebuild -version
xcodegen --version
git --version
```

Install XcodeGen via Homebrew if needed:

```bash
brew install xcodegen
```

### Repository Setup

Clone SatsBuddy, generate the Xcode project, and open it:

```bash
git clone https://github.com/reez/SatsBuddy.git
cd SatsBuddy
xcodegen generate
open SatsBuddy.xcodeproj
```

The `.xcodeproj` is not checked into version control — it is generated from `project.yml` and the xcconfig files in `Configs/`. You need to run `xcodegen generate` after cloning and whenever source files are added or removed.

SatsBuddy resolves `CKTap` from the remote `rust-cktap` Swift Package (`v0.2.2`).

## SwiftUI Previews

This project links native / FFI-heavy dependencies (CKTap, BitcoinDevKit).
On some Xcode versions, SwiftUI previews may crash using the default preview
execution mode, even though the app runs correctly in the simulator.

To fix this:
From inside a SwiftUI View code file,
Select Editor -> Canvas -> Enable “Use Legacy Previews Execution”
After enabling this option, SwiftUI previews should render normally.

## About

Made in Nashville.
