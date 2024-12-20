import XCTest
@testable import LoadingView

struct CustomError: Error, LocalizedError {
    var errorDescription: String? {
        return "Custom error occurred"
    }
}

final class LoadingStateTests: XCTestCase {
    func testErrorStateOutputsLocalizedDescription() {
        let error = CustomError()
        let loadingState: LoadingState<String> = .error(error)
        XCTAssertEqual(
            loadingState.description,
            "Custom error occurred",
            "The description of the error state should output the localized description of the custom error"
        )
    }
}

