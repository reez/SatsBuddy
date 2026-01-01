//
//  SatsCardDetailViewModelTests.swift
//  SatsBuddyTests
//
//  Created by Chase Lewis on 1/1/26.
//

import Foundation
import Testing
import BitcoinDevKit
@testable import SatsBuddy

func makeBalance(sats: UInt64) -> Balance {
    let amount = Amount.fromSat(satoshi: sats)
    let zero = Amount.fromSat(satoshi: 0)
    return Balance(
        immature: zero,
        trustedPending: zero,
        untrustedPending: zero,
        confirmed: amount,
        trustedSpendable: amount,
        total: amount
    )
}

func makeSlots(activeIndex: Int) -> [SlotInfo] {
    [
        SlotInfo(
            slotNumber: 0,
            isActive: activeIndex == 0,
            isUsed: true,
            pubkey: "02" + String(repeating: "1", count: 64),
            pubkeyDescriptor: "wpkh(...)",
            address: "bc1qslot0",
            balance: nil
        ),
        SlotInfo(
            slotNumber: 1,
            isActive: activeIndex == 1,
            isUsed: true,
            pubkey: "02" + String(repeating: "2", count: 64),
            pubkeyDescriptor: "wpkh(...)",
            address: "bc1qslot1",
            balance: nil
        ),
    ]
}

func makeCard(address: String? = "bc1qtestaddress", slots: [SlotInfo]) -> SatsCardInfo {
    SatsCardInfo(
        version: "1.0.3",
        birth: 1,
        address: address,
        pubkey: "02" + String(repeating: "0", count: 64),
        cardIdent: "ABCDE-FGHJK-LMNOP-QRSTU",
        activeSlot: 1,
        totalSlots: 10,
        slots: slots,
        isActive: true
    )
}

// MARK: - Tests

@Suite("SatsCardDetailViewModel")
struct SatsCardDetailViewModelTests {

    @Test("loadSlotDetails: clears error, sets loading, copies slots immediately")
    @MainActor
    func loadSlotDetailsCopiesSlotsImmediately() async throws {
        let bdk = BdkClient.testing(getBalanceFromAddress: { _, _ in
            try await Task.sleep(for: .seconds(10)) // never completes during test
            return makeBalance(sats: 1)
        })

        let vm = SatsCardDetailViewModel(bdkClient: bdk)
        vm.errorMessage = "Old error"
        vm.isLoading = false
        vm.slots = []

        let card = makeCard(slots: makeSlots(activeIndex: 1))

        vm.loadSlotDetails(for: card, traceID: "T1")

        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == true)
        #expect(vm.slots.map(\.slotNumber) == card.slots.map(\.slotNumber))
        #expect(vm.slots.map(\.isActive) == card.slots.map(\.isActive))
    }

    @Test("missing address: skips balance fetch and ends loading")
    func missingAddressSkipsFetch() async throws {
        var fetchCalled = false
        let bdk = BdkClient.testing(getBalanceFromAddress: { _, _ in
            fetchCalled = true
            return makeBalance(sats: 1)
        })

        let vm = SatsCardDetailViewModel(bdkClient: bdk)
        let card = makeCard(address: nil, slots: makeSlots(activeIndex: 1))

        await MainActor.run {
            vm.loadSlotDetails(for: card, traceID: "T2")
        }

        try await eventually { vm.isLoading == false }

        #expect(fetchCalled == false)
        #expect(vm.errorMessage == nil)
        #expect(vm.slots.count == 2)
        #expect(vm.slots.first(where: { $0.isActive })?.balance == nil)
    }

    @Test("success: updates active slot balance and clears loading")
    func successUpdatesActiveSlotBalance() async throws {
        let expectedSats: UInt64 = 123_456
        let bdk = BdkClient.testing(getBalanceFromAddress: { address, network in
            #expect(address == "bc1qtestaddress")
            #expect(network == .bitcoin)
            return makeBalance(sats: expectedSats)
        })

        let vm = SatsCardDetailViewModel(bdkClient: bdk)
        let card = makeCard(address: "bc1qtestaddress", slots: makeSlots(activeIndex: 1))

        await MainActor.run {
            vm.loadSlotDetails(for: card, traceID: "T3")
        }

        try await eventually {
            vm.isLoading == false && vm.slots.first(where: { $0.isActive })?.balance != nil
        }

        let active = try #require(vm.slots.first(where: { $0.isActive }))
        #expect(active.balance == expectedSats)
        #expect(vm.errorMessage == nil)
    }

    @Test("no active slot: fetch completes but does not update any balance; loading ends")
    func noActiveSlotDoesNotUpdateBalance() async throws {
        let bdk = BdkClient.testing(getBalanceFromAddress: { _, _ in
            return makeBalance(sats: 50_000)
        })

        let vm = SatsCardDetailViewModel(bdkClient: bdk)

        let slots: [SlotInfo] = [
            SlotInfo(
                slotNumber: 0,
                isActive: false,
                isUsed: true,
                pubkey: "02" + String(repeating: "1", count: 64),
                pubkeyDescriptor: "wpkh(...)",
                address: "bc1qslot0",
                balance: nil
            ),
            SlotInfo(
                slotNumber: 1,
                isActive: false,
                isUsed: true,
                pubkey: "02" + String(repeating: "2", count: 64),
                pubkeyDescriptor: "wpkh(...)",
                address: "bc1qslot1",
                balance: nil
            ),
        ]

        let card = makeCard(address: "bc1qtestaddress", slots: slots)

        await MainActor.run {
            vm.loadSlotDetails(for: card, traceID: "T4")
        }

        try await eventually { vm.isLoading == false }

        #expect(vm.errorMessage == nil)
        #expect(vm.slots.allSatisfy { $0.balance == nil })
    }

    @Test("failure: sets error message and clears loading")
    func failureSetsErrorMessage() async throws {
        let bdk = BdkClient.testing(getBalanceFromAddress: { _, _ in
            throw TestError(message: "Boom")
        })

        let vm = SatsCardDetailViewModel(bdkClient: bdk)
        let card = makeCard(address: "bc1qtestaddress", slots: makeSlots(activeIndex: 1))

        await MainActor.run {
            vm.loadSlotDetails(for: card, traceID: "T5")
        }

        try await eventually { vm.isLoading == false && vm.errorMessage != nil }

        #expect(vm.errorMessage == "Failed to fetch balance: Boom")
        #expect(vm.slots.first(where: { $0.isActive })?.balance == nil)
    }

    @Test("token gating: second load wins, stale first result does not overwrite")
    func tokenGatingSecondLoadWins() async throws {
        let slow = makeBalance(sats: 1)
        let fast = makeBalance(sats: 9_999)

        let bdk = BdkClient.testing(getBalanceFromAddress: { address, _ in
            if address == "addr_slow" {
                try await Task.sleep(for: .milliseconds(200))
                return slow
            } else {
                try await Task.sleep(for: .milliseconds(20))
                return fast
            }
        })

        let vm = SatsCardDetailViewModel(bdkClient: bdk)
        let slowCard = makeCard(address: "addr_slow", slots: makeSlots(activeIndex: 1))
        let fastCard = makeCard(address: "addr_fast", slots: makeSlots(activeIndex: 1))

        await MainActor.run {
            vm.loadSlotDetails(for: slowCard, traceID: "T6A")
            vm.loadSlotDetails(for: fastCard, traceID: "T6B")
        }

        try await eventually {
            vm.isLoading == false && vm.slots.first(where: { $0.isActive })?.balance != nil
        }

        let active = try #require(vm.slots.first(where: { $0.isActive }))
        #expect(active.balance == fast.total.toSat())
        #expect(vm.errorMessage == nil)
    }
}

