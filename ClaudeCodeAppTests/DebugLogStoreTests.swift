import XCTest
@testable import ClaudeCodeApp

@MainActor
final class DebugLogStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        resetStore()
    }

    override func tearDown() {
        resetStore()
        super.tearDown()
    }

    private func resetStore() {
        let store = DebugLogStore.shared
        store.entries = []
        store.isEnabled = false
        store.typeFilter = Set(DebugLogType.allCases)
        store.searchText = ""
    }

    func test_debugLogType_metadata_isCorrect() {
        XCTAssertEqual(DebugLogType.sent.icon, "arrow.up.circle")
        XCTAssertEqual(DebugLogType.received.icon, "arrow.down.circle")
        XCTAssertEqual(DebugLogType.error.icon, "exclamationmark.triangle")
        XCTAssertEqual(DebugLogType.info.icon, "info.circle")
        XCTAssertEqual(DebugLogType.connection.icon, "wifi")

        XCTAssertEqual(DebugLogType.sent.colorName, "blue")
        XCTAssertEqual(DebugLogType.received.colorName, "green")
        XCTAssertEqual(DebugLogType.error.colorName, "red")
        XCTAssertEqual(DebugLogType.info.colorName, "gray")
        XCTAssertEqual(DebugLogType.connection.colorName, "orange")
    }

    func test_debugLogEntry_formattedMessage_prettyPrintsJson() {
        let entry = DebugLogEntry(
            timestamp: Date(),
            type: .info,
            message: "{\"name\":\"value\"}",
            details: nil
        )

        XCTAssertEqual(entry.formattedMessage, "{\n  \"name\" : \"value\"\n}")
    }

    func test_debugLogEntry_formattedMessage_nonJson_returnsOriginal() {
        let message = "not json"
        let entry = DebugLogEntry(
            timestamp: Date(),
            type: .info,
            message: message,
            details: nil
        )

        XCTAssertEqual(entry.formattedMessage, message)
    }

    func test_debugLogEntry_formattedTimestamp_usesExpectedFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2025
        components.month = 1
        components.day = 2
        components.hour = 3
        components.minute = 4
        components.second = 5
        components.nanosecond = 678_000_000

        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create test date")
            return
        }

        let entry = DebugLogEntry(
            timestamp: date,
            type: .info,
            message: "Message",
            details: nil
        )

        XCTAssertEqual(entry.formattedTimestamp, "03:04:05.678")
    }

    func test_debugLogStore_log_disabled_doesNotAppend() {
        let store = DebugLogStore.shared
        store.isEnabled = false

        store.log("Message", type: .info)

        XCTAssertTrue(store.entries.isEmpty)
    }

    func test_debugLogStore_log_enabled_appendsEntryWithDetails() {
        let store = DebugLogStore.shared
        store.isEnabled = true

        store.log("Message", type: .error, details: "Details")

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.message, "Message")
        XCTAssertEqual(store.entries.first?.type, .error)
        XCTAssertEqual(store.entries.first?.details, "Details")
    }

    func test_debugLogStore_log_trimsToMaxEntries() {
        let store = DebugLogStore.shared
        store.isEnabled = true

        let totalEntries = store.maxEntries + 5
        for index in 0..<totalEntries {
            store.log("message-\(index)", type: .info)
        }

        XCTAssertEqual(store.entries.count, store.maxEntries)
        XCTAssertEqual(store.entries.first?.message, "message-5")
        XCTAssertEqual(store.entries.last?.message, "message-\(totalEntries - 1)")
    }

    func test_debugLogStore_filteredEntries_respectsTypeAndSearchFilters() {
        let store = DebugLogStore.shared
        let timestamp = Date()

        store.entries = [
            DebugLogEntry(timestamp: timestamp, type: .sent, message: "Hello world", details: "Alpha"),
            DebugLogEntry(timestamp: timestamp, type: .error, message: "Network down", details: "Timeout"),
            DebugLogEntry(timestamp: timestamp, type: .info, message: "Status OK", details: nil)
        ]

        store.typeFilter = [.error, .info]
        store.searchText = "net"

        let filtered = store.filteredEntries
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.type, .error)

        store.searchText = ""
        XCTAssertEqual(store.filteredEntries.count, 2)
    }

    func test_debugLogStore_exportAsText_formatsEntries() {
        let store = DebugLogStore.shared
        let timestamp = Date()

        let entryOne = DebugLogEntry(timestamp: timestamp, type: .sent, message: "Ping", details: nil)
        let entryTwo = DebugLogEntry(timestamp: timestamp.addingTimeInterval(1), type: .error, message: "Fail", details: nil)

        store.entries = [entryOne, entryTwo]
        store.typeFilter = Set(DebugLogType.allCases)
        store.searchText = ""

        let expected = """
        [\(entryOne.formattedTimestamp)] [\(entryOne.type.rawValue)] \(entryOne.message)

        ---

        [\(entryTwo.formattedTimestamp)] [\(entryTwo.type.rawValue)] \(entryTwo.message)
        """

        XCTAssertEqual(store.exportAsText(), expected)
    }
}
