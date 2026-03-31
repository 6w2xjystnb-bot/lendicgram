import SwiftUI
import UIKit

// MARK: - Enable swipe-back with hidden navigation back button

/// When `navigationBarBackButtonHidden(true)` is used, iOS disables the
/// interactive pop gesture. This modifier re-enables it by accessing the
/// underlying UINavigationController's gesture recognizer.
struct SwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(SwipeBackHelper())
    }
}

private struct SwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackViewController()
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

private final class SwipeBackViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Walk up to find the NavigationController and re-enable swipe
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        modifier(SwipeBackModifier())
    }
}
