import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: VKUser?
    @Published var isLoading = false
    @Published var error: String?

    func load() async {
        isLoading = true
        do { user = try await VKAPIService.shared.getCurrentUser() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
