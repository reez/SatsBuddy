# SatsBuddy

A SwiftUI app for managing and viewing SatsCard NFC hardware wallet information.

## Features

- **NFC Scanning**: Scan SatsCard hardware wallets via NFC
- **Slot Management**: View all slots with their addresses, pubkeys, and status
- **Real Address Derivation**: Shows actual Bitcoin addresses for each slot
- **Card Deduplication**: Prevents duplicate entries when rescanning the same card
- **Refresh Capability**: Update card information when slot status changes
- **Export Options**: Copy addresses and pubkeys to clipboard, view on blockchain explorer

## Architecture Overview

### NFC Scanning Process

1. **NFC Session Initiation**
   - User taps the + button to begin scanning
   - `NFCTagReaderSession` starts looking for ISO14443 tags
   - `NFCTransport` handles low-level APDU communication with the card

2. **Card Detection & Status**
   - When a tag is detected, `CKTap.toCktap()` identifies the card type
   - For SatsCards, `card.status()` retrieves basic information:
     - Version, birth timestamp, active slot, total slots
   - `card.address()` gets the current active slot's address

3. **Slot Data Extraction**
   - **For each used slot** (0 to activeSlot):
     - `card.dump(slot: slotNumber, cvc: nil)` attempts to read slot data
     - **Unsealed slots**: Returns pubkey and descriptor successfully
     - **Sealed slots** (active slot): Fails with `SlotSealed` error, but we use the pre-fetched address
   - **For each unused slot**: Marked as unused, no data fetched

### Address Derivation Strategy

The app uses different methods to obtain Bitcoin addresses for each slot:

#### Active Slot (Currently Sealed)
- **Method**: `card.address()` 
- **Why**: The active slot is sealed and requires CVC to access via `dump()`
- **Result**: Real address for the active slot

#### Non-Active Unsealed Slots
- **Method**: BitcoinDevKit address derivation from wpkh descriptor
- **Process**:
  1. `card.dump(slot, cvc: nil)` returns `SlotDetails` with:
     - `pubkey`: The slot's public key
     - `pubkeyDescriptor`: wpkh descriptor (e.g., "wpkh(pubkey)#checksum")
  2. Create temporary BDK `Descriptor` from the descriptor string
  3. Create temporary BDK `Wallet` with in-memory persistence
  4. Use `wallet.peekAddress(keychain: .external, index: 0)` to derive the address
- **Why**: Historical slots are unsealed and provide full descriptor data
- **Result**: Real derived address from the slot's actual pubkey

#### Why BitcoinDevKit?

We use BitcoinDevKit for address derivation because:

1. **CKTap Limitations**: The `SlotDetails` struct only provides:
   - `pubkey: String`
   - `pubkeyDescriptor: String` 
   - `privkey: String?` (only with CVC)
   - **No direct address field**

2. **Descriptor Parsing**: The wpkh descriptor format contains all the information needed to derive addresses, but requires proper Bitcoin library support to parse and compute addresses

3. **Accuracy**: Using the same library that wallets use ensures we derive addresses correctly according to Bitcoin standards

### Card Identification & Deduplication

Cards are uniquely identified using:
```swift
var cardIdentifier: String {
    return "\(version)-\(birth ?? 0)-\(totalSlots ?? 0)"
}
```

- `version`: Card firmware version
- `birth`: Unix timestamp when card was manufactured (unique per card)
- `totalSlots`: Number of available slots

When scanning:
- If `cardIdentifier` matches existing card → **Update** existing entry
- If `cardIdentifier` is new → **Add** new card

### Refresh Functionality

The refresh feature allows users to update card information when:
- Active slot has changed (unsealed new slot)
- Card has been used on another device
- Data appears stale

**Process**:
1. User taps refresh button in detail view
2. Initiates new NFC session (`beginNFCSession()`)
3. Scans card and extracts fresh data
4. Updates existing `SatsCardInfo` object in-place
5. UI automatically reflects changes (SwiftUI reactivity)

### Data Flow

```
NFC Scan → CKTap → Card Status & Slots → Address Derivation → UI Display
    ↓            ↓                            ↓                    ↓
NFCTransport → SatsCard → SlotDetails → BitcoinDevKit → SatsCardDetailView
```

## Technical Dependencies

- **CKTap**: Rust-based library for SatsCard communication (via Swift bindings)
- **BitcoinDevKit**: Bitcoin library for descriptor parsing and address derivation
- **CoreNFC**: Apple's NFC framework for hardware communication
- **SwiftUI**: Modern declarative UI framework

## Key Components

### Models
- `SatsCardInfo`: Represents a scanned card with slots and metadata
- `SlotInfo`: Individual slot data (address, pubkey, status)

### ViewModels  
- `SatsCardViewModel`: Handles NFC scanning, card management, and refresh
- `SatsCardDetailViewModel`: Manages slot display logic

### Views
- `ContentView`: Main card list and scanning interface
- `SatsCardView`: Individual card summary display
- `SatsCardDetailView`: Detailed slot information with refresh capability

### Services
- `NFCTransport`: Low-level NFC communication with hardware
- Integrates with CKTap Rust bindings for SatsCard protocol

## Development Notes

- **NFC Required**: App requires physical iOS device with NFC capability for testing
- **Real Hardware**: Must use actual SatsCard hardware for development/testing
- **Address Verification**: All derived addresses can be verified against blockchain explorers
- **No Mock Data**: Production code contains no dummy/placeholder data (except SwiftUI previews)