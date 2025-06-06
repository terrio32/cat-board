import CatAPIClient
import CatImageLoader
import CatImagePrefetcher
import CatImageScreener
import CatImageURLRepository
import SwiftData
import SwiftUI
import TieredGridLayout

struct CatImageGallery: View {
    private static let minImageCountForRefresh = 30

    private let modelContainer: ModelContainer
    @StateObject private var viewModel: GalleryViewModel

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let imageClient = CatAPIClient()
        let repository = CatImageURLRepository(modelContainer: modelContainer, apiClient: imageClient)
        let screener = CatImageScreener()
        let imageLoader = CatImageLoader()
        let prefetcher = CatImagePrefetcher(
            repository: repository,
            imageLoader: imageLoader,
            screener: screener,
            modelContainer: modelContainer
        )
        _viewModel = StateObject(wrappedValue: GalleryViewModel(
            repository: repository,
            imageLoader: imageLoader,
            screener: screener,
            prefetcher: prefetcher
        ))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.errorMessage != nil || (!viewModel.isInitializing && viewModel.imageURLsToShow.isEmpty) {
                    errorContent
                        .transition(.opacity)
                } else {
                    ZStack(alignment: .top) {
                        scrollContent
                            .transition(.opacity)

                        // 初期ロード時の ProgressView
                        if viewModel.isInitializing, viewModel.imageURLsToShow.isEmpty {
                            VStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                Text("Loading...")
                                    .font(.headline)
                                    .padding(.top, 8)
                                Spacer()
                            }
                            .transition(.opacity)
                        }
                    }
                }
            }
            .animation(.easeOut(duration: 0.3), value: viewModel.errorMessage)
            .navigationTitle("Cat Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(
                        action: {
                            withAnimation {
                                viewModel.clearDisplayedImages()
                                viewModel.loadInitialImages()
                            }
                        },
                        label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.primary)
                        }
                    )
                    .opacity(
                        !viewModel.isInitializing && !viewModel.isAdditionalFetching && viewModel.imageURLsToShow
                            .count >= Self
                            .minImageCountForRefresh ? 1 : 0
                    )
                    .animation(.easeOut(duration: 0.3), value: viewModel.isInitializing)
                    .animation(.easeOut(duration: 0.3), value: viewModel.isAdditionalFetching)
                    .animation(.easeOut(duration: 0.3), value: viewModel.imageURLsToShow.count)
                }
            }
            .onAppear {
                viewModel.loadInitialImages()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var errorContent: some View {
        VStack(spacing: 16) {
            Text("エラーが発生しました")
                .font(.headline)
            Text(viewModel.errorMessage ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                withAnimation {
                    viewModel.clearDisplayedImages()
                    viewModel.loadInitialImages()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            galleryGrid

            // ProgressView
            if viewModel.isAdditionalFetching || viewModel.isInitializing,
               !viewModel.imageURLsToShow.isEmpty
            {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.bottom, 16)
            }
        }
        .rotationEffect(.degrees(180))
        // 上スクロールできるようにするために回転
        // galleryGrid の中身の要素も回転させている
    }

    @ViewBuilder
    var galleryGrid: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.imageURLsToShow.chunked(into: 10), id: \.self) { chunk in
                TieredGridLayout {
                    ForEach(chunk, id: \.id) { image in
                        SquareGalleryImageAsync(url: URL(string: image.imageURL))
                            .padding(2)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                            .rotationEffect(.degrees(180))
                            .onAppear {
                                if image.id == viewModel.imageURLsToShow.last?.id {
                                    Task {
                                        await viewModel.fetchAdditionalImages()
                                    }
                                }
                            }
                    }
                }
            }
        }
        .padding(2)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
