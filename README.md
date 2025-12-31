# SatsBuddy

*Experimental*

An iPhone app companion for SATSCARD.

Download on [TestFlight](https://testflight.apple.com/join/Pq7KwWzB).

## Dependencies

- [bdk-swift](https://github.com/bitcoindevkit/bdk-swift)

- [BitcoinUI](https://github.com/reez/BitcoinUI)

- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

- [rust-cktap](https://github.com/notmandatory/rust-cktap)

## Running SatsBuddy Locally

### Prerequisites

- Xcode (and Xcode Command Line Tools)
- Git
- Rust toolchain (via `rustup`) — required to build the CKTap Swift XCFramework

You can verify the required tools are installed with:

```bash
xcodebuild -version
git --version
rustc --version
cargo --version
```

### Repository Setup (Important Folder Layout)

SatsBuddy depends on the rust-cktap repository via a local Swift Package reference.
Both repositories must be cloned into the same parent directory.

```bash
cd ~/Documents
git clone https://github.com/reez/SatsBuddy.git
git clone https://github.com/bitcoindevkit/rust-cktap.git
```

Resulting folder structure:

```bash
~/Documents/
├─ SatsBuddy/
└─ rust-cktap/
   └─ cktap-swift/
```

### Build the CKTap XCFramework

The `rust-cktap/cktap-swift` package includes a script that builds the
`cktapFFI.xcframework` required by Swift Package Manager.

Run the following:

```bash
cd ~/Documents/rust-cktap/cktap-swift
chmod +x build-xcframework.sh
./build-xcframework.sh
```

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
