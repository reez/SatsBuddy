# SatsBuddy

*Experimental iPhone companion for SATSCARD.*

[Download on TestFlight](https://testflight.apple.com/join/Pq7KwWzB).

## What It Does

- Scan and save SATSCARDs over NFC
- View slot details, receive addresses, and balances
- Set up the next slot or sweep funds from the active slot

## Dependencies

- [bdk-swift](https://github.com/bitcoindevkit/bdk-swift)
- [BitcoinUI](https://github.com/reez/BitcoinUI)
- [CodeScanner](https://github.com/twostraws/CodeScanner.git)
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)
- [rust-cktap](https://github.com/bitcoindevkit/rust-cktap)

## SwiftUI Previews

This project links native and FFI-heavy dependencies (`CKTap`, `BitcoinDevKit`).
On some Xcode versions, SwiftUI previews may crash in the default execution mode
even when the app itself runs normally.

If that happens, open a SwiftUI view file and enable
`Editor > Canvas > Use Legacy Previews Execution`.

## About

Made in Nashville.
