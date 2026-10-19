import XCTest
@testable import HeyDrum

final class JSONHistoryRepositoryTests: XCTestCase {
    private func date(_ s: Double) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + s) }

    // T-013
    func test101stAppendKeepsExactly100AndDropsOldestLastPlayed() async throws {
        let repo = JSONHistoryRepository(store: MemoryHistoryStore())
        var first: HistoryEntry!
        for i in 0..<101 {
            let e = try await repo.appendNew(text: "t\(i)", at: date(Double(i)))
            if i == 0 { first = e }
        }
        let list = try await repo.list()
        XCTAssertEqual(list.count, 100)
        XCTAssertFalse(list.contains(where: { $0.id == first.id }), "the oldest entry must be pruned")
        XCTAssertEqual(list.first?.text, "t100")
    }

    // T-014
    func testReplayKeepsIDAndCountAndMovesToTop() async throws {
        let repo = JSONHistoryRepository(store: MemoryHistoryStore())
        let a = try await repo.appendNew(text: "a", at: date(1))
        _ = try await repo.appendNew(text: "b", at: date(2))
        _ = try await repo.appendNew(text: "c", at: date(3))
        try await repo.markPlayed(id: a.id, at: date(10))
        let list = try await repo.list()
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list.first?.id, a.id)
        XCTAssertEqual(list.first?.createdAt, a.createdAt)
        XCTAssertEqual(Set(list.map(\.id)).count, 3)
    }

    // T-042
    func testRecentlyPlayedOldEntrySurvivesPruning() async throws {
        let repo = JSONHistoryRepository(store: MemoryHistoryStore())
        var oldest: HistoryEntry!
        for i in 0..<100 {
            let e = try await repo.appendNew(text: "t\(i)", at: date(Double(i)))
            if i == 0 { oldest = e }
        }
        try await repo.markPlayed(id: oldest.id, at: date(500))        // oldest becomes the most recently used
        _ = try await repo.appendNew(text: "new", at: date(600))
        let list = try await repo.list()
        XCTAssertEqual(list.count, 100)
        XCTAssertTrue(list.contains(where: { $0.id == oldest.id }), "recently played entry must stay")
        XCTAssertFalse(list.contains(where: { $0.text == "t1" }), "the least recently used entry is pruned instead")
    }

    func testSameTextTwiceCreatesTwoDistinctRows() async throws {
        let repo = JSONHistoryRepository(store: MemoryHistoryStore())
        let a = try await repo.appendNew(text: "同じ", at: date(1))
        let b = try await repo.appendNew(text: "同じ", at: date(2))
        XCTAssertNotEqual(a.id, b.id)
        let count = try await repo.list().count
        XCTAssertEqual(count, 2)
    }

    func testInvalidTextIsRejectedWithoutWriting() async throws {
        let store = MemoryHistoryStore()
        let repo = JSONHistoryRepository(store: store)
        for bad in ["", "   \n", String(repeating: "x", count: 501)] {
            do { _ = try await repo.appendNew(text: bad, at: date(1)); XCTFail("should throw") }
            catch { XCTAssertEqual(error as? HistoryError, .invalidText) }
        }
        XCTAssertEqual(store.writeCount, 0)
    }

    // T-015 (restart: a second repository instance reads the same bytes)
    func testPersistsAcrossRepositoryInstances() async throws {
        let store = MemoryHistoryStore()
        let first = JSONHistoryRepository(store: store)
        let a = try await first.appendNew(text: "本日は晴天なり", at: date(1))
        _ = try await first.appendNew(text: "二番目", at: date(2))
        try await first.markPlayed(id: a.id, at: date(3))
        let second = JSONHistoryRepository(store: store)
        let list = try await second.list()
        XCTAssertEqual(list.map(\.text), ["本日は晴天なり", "二番目"])
        XCTAssertEqual(list.first?.lastPlayedAt, date(3))
    }

    func testFileBackedRepositoryRoundTripsOnDisk() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("heydrum-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("HeyDrum/history-v1.json")
        let one = JSONHistoryRepository(store: FileHistoryStore(url: url))
        _ = try await one.appendNew(text: "disk", at: date(1))
        let two = JSONHistoryRepository(store: FileHistoryStore(url: url))
        let list = try await two.list()
        XCTAssertEqual(list.map(\.text), ["disk"])
        let json = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(json.contains("\"schemaVersion\" : 1"))
    }

    // T-017
    func testWriteFailureThrowsKeepsMemoryAndFileUntouched() async throws {
        let store = MemoryHistoryStore()
        let repo = JSONHistoryRepository(store: store)
        _ = try await repo.appendNew(text: "keep", at: date(1))
        let before = store.current
        store.failWrites = true
        do { _ = try await repo.appendNew(text: "lost", at: date(2)); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? HistoryError, .writeFailed) }
        XCTAssertEqual(store.current, before, "existing file must be untouched")
        let list = try await repo.list()
        XCTAssertEqual(list.map(\.text), ["keep"], "memory must not run ahead of disk")
        store.failWrites = false
        _ = try await repo.appendNew(text: "ok", at: date(3))
        let count = try await repo.list().count
        XCTAssertEqual(count, 2)
    }

    // T-018
    func testCorruptJSONIsNeverOverwritten() async throws {
        let garbage = Data("{ not json".utf8)
        let store = MemoryHistoryStore(data: garbage)
        let repo = JSONHistoryRepository(store: store)
        do { _ = try await repo.list(); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? HistoryError, .corrupt) }
        do { _ = try await repo.appendNew(text: "x", at: date(1)); XCTFail("must refuse to overwrite") }
        catch { XCTAssertEqual(error as? HistoryError, .corrupt) }
        XCTAssertEqual(store.current, garbage)
        XCTAssertEqual(store.writeCount, 0)
    }

    func testUnsupportedSchemaIsPreservedAndReported() async throws {
        let future = Data(#"{"schemaVersion": 2, "items": []}"#.utf8)
        let store = MemoryHistoryStore(data: future)
        let repo = JSONHistoryRepository(store: store)
        do { _ = try await repo.list(); XCTFail("should throw") }
        catch { XCTAssertEqual(error as? HistoryError, .unsupportedSchema(2)) }
        XCTAssertEqual(store.current, future)
    }

    func testDuplicateIDsOrOversizeTextCountAsCorrupt() async throws {
        let id = UUID().uuidString
        let dup = """
        {"schemaVersion":1,"items":[
         {"id":"\(id)","text":"a","createdAt":"2026-10-19T12:00:00Z","lastPlayedAt":"2026-10-19T12:00:00Z"},
         {"id":"\(id)","text":"b","createdAt":"2026-10-19T12:00:00Z","lastPlayedAt":"2026-10-19T12:00:00Z"}]}
        """
        let repo = JSONHistoryRepository(store: MemoryHistoryStore(data: Data(dup.utf8)))
        do { _ = try await repo.list(); XCTFail("should throw") } catch { XCTAssertEqual(error as? HistoryError, .corrupt) }

        let long = String(repeating: "あ", count: 501)
        let big = #"{"schemaVersion":1,"items":[{"id":"\#(UUID().uuidString)","text":"\#(long)","createdAt":"2026-10-19T12:00:00Z","lastPlayedAt":"2026-10-19T12:00:00Z"}]}"#
        let repo2 = JSONHistoryRepository(store: MemoryHistoryStore(data: Data(big.utf8)))
        do { _ = try await repo2.list(); XCTFail("should throw") } catch { XCTAssertEqual(error as? HistoryError, .corrupt) }
    }

    func testExplicitResetQuarantinesCorruptFileThenWorks() async throws {
        let garbage = Data("oops".utf8)
        let store = MemoryHistoryStore(data: garbage)
        let repo = JSONHistoryRepository(store: store)
        try await repo.resetCorruptStore()
        XCTAssertEqual(store.quarantined.count, 1)
        XCTAssertTrue(store.quarantined[0].hasPrefix(".corrupt-"))
        _ = try await repo.appendNew(text: "fresh", at: date(1))
        let list = try await repo.list()
        XCTAssertEqual(list.map(\.text), ["fresh"])
    }

    func testDeleteAndDeleteAll() async throws {
        let repo = JSONHistoryRepository(store: MemoryHistoryStore())
        let a = try await repo.appendNew(text: "a", at: date(1))
        _ = try await repo.appendNew(text: "b", at: date(2))
        try await repo.delete(id: a.id)
        let afterDelete = try await repo.list()
        XCTAssertEqual(afterDelete.map(\.text), ["b"])
        do { try await repo.delete(id: a.id); XCTFail("should throw") } catch { XCTAssertEqual(error as? HistoryError, .notFound) }
        try await repo.deleteAll()
        let afterDeleteAll = try await repo.list()
        XCTAssertTrue(afterDeleteAll.isEmpty)
    }

    func testSortIsDeterministicOnTies() async throws {
        let ids = (0..<5).map { _ in UUID() }
        var queue = ids
        let repo = JSONHistoryRepository(store: MemoryHistoryStore(), makeID: { queue.removeFirst() })
        for _ in 0..<5 { _ = try await repo.appendNew(text: "same", at: date(1)) }
        let list = try await repo.list()
        XCTAssertEqual(list.map(\.id.uuidString), ids.map(\.uuidString).sorted())
    }

    // T-043
    func test50ConcurrentOperationsLoseNothing() async throws {
        let store = MemoryHistoryStore()
        let repo = JSONHistoryRepository(store: store)
        let seeded = try await repo.appendNew(text: "seed", at: date(0))
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...49 {
                group.addTask { _ = try await repo.appendNew(text: "t\(i)", at: self.date(Double(i))) }
            }
            group.addTask { try await repo.markPlayed(id: seeded.id, at: self.date(1000)) }
            try await group.waitForAll()
        }
        let list = try await repo.list()
        XCTAssertEqual(list.count, 50)
        XCTAssertEqual(Set(list.map(\.id)).count, 50, "no duplicate IDs")
        XCTAssertEqual(list.first?.id, seeded.id)
        let reloaded = try await JSONHistoryRepository(store: store).list()
        XCTAssertEqual(reloaded, list, "disk equals memory")
    }

    func test200ConcurrentAppendsStayAtOrBelow100() async throws {
        let repo = JSONHistoryRepository(store: MemoryHistoryStore())
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<200 { group.addTask { _ = try await repo.appendNew(text: "t\(i)", at: self.date(Double(i))) } }
            try await group.waitForAll()
        }
        let count = try await repo.list().count
        XCTAssertEqual(count, 100)
    }
}
