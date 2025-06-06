import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import CatURLImageModel
import SwiftData
import XCTest

final class CatImagePrefetcherTests: XCTestCase {
    private var mockRepository: MockCatImageURLRepository!
    private var mockLoader: MockCatImageLoader!
    private var mockScreener: MockCatImageScreener!
    private var modelContainer: ModelContainer!
    private var prefetcher: CatImagePrefetcher!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockRepository = MockCatImageURLRepository(apiClient: MockCatAPIClient())
        mockLoader = MockCatImageLoader()
        mockScreener = MockCatImageScreener()
        modelContainer = try ModelContainer(for: PrefetchedCatImageURL.self)
        prefetcher = CatImagePrefetcher(
            repository: mockRepository,
            imageLoader: mockLoader,
            screener: mockScreener,
            modelContainer: modelContainer
        )
    }

    override func tearDown() {
        mockRepository = nil
        mockLoader = nil
        mockScreener = nil
        modelContainer = nil
        prefetcher = nil
        super.tearDown()
    }

    /// プリフェッチを実行すると画像が取得できることを確認
    func testStartPrefetching() async throws {
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }

    /// 指定した枚数分の画像を取得できることを確認
    func testGetRequestedImageCount() async throws {
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let images = try await prefetcher.getPrefetchedImages(imageCount: 2)
        XCTAssertEqual(images.count, 2)

        let remainingCount = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(remainingCount, 0)
    }

    /// プリフェッチの重複実行を防止できることを確認
    func testIgnoreDuplicatePrefetching() async throws {
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        try await prefetcher.startPrefetchingIfNeeded()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機

        let count = try await prefetcher.getPrefetchedCount()
        XCTAssertGreaterThan(count, 0)
    }
}
