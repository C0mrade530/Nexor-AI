import XCTest

final class NexorTests: XCTestCase {

    func testAPIClientInitialization() {
        let client = APIClient(baseURL: "http://localhost:8000/api/v1")
        XCTAssertNotNil(client)
    }

    func testEventTypeBadgeColors() {
        let meetingBadge = EventTypeBadge(type: "meeting")
        XCTAssertEqual(meetingBadge.icon, "person.2")

        let ideaBadge = EventTypeBadge(type: "idea")
        XCTAssertEqual(ideaBadge.icon, "lightbulb")

        let taskBadge = EventTypeBadge(type: "task")
        XCTAssertEqual(taskBadge.icon, "checkmark.square")
    }

    func testModelDecoding() throws {
        let json = """
        {
            "events": [],
            "total": 0,
            "page": 1,
            "page_size": 20
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let response = try decoder.decode(EventListResponse.self, from: json)
        XCTAssertEqual(response.total, 0)
        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.pageSize, 20)
        XCTAssertTrue(response.events.isEmpty)
    }

    func testSearchResponseDecoding() throws {
        let json = """
        {
            "query": "test query",
            "answer": "Here is the answer"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SearchResponse.self, from: json)
        XCTAssertEqual(response.query, "test query")
        XCTAssertEqual(response.answer, "Here is the answer")
    }

    func testImportantMarkerEncoding() throws {
        let marker = ImportantMarker(
            timestamp: Date(),
            offsetSeconds: 123.5,
            sessionId: "test-session"
        )
        let data = try JSONEncoder().encode(marker)
        let decoded = try JSONDecoder().decode(ImportantMarker.self, from: data)
        XCTAssertEqual(decoded.sessionId, "test-session")
        XCTAssertEqual(decoded.offsetSeconds, 123.5)
    }
}
