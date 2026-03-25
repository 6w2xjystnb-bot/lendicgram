import SwiftUI

// MARK: - Chat Background with Formulas

/// Graphite wallpaper with scattered math/physics formulas — dirty sketch style.
struct ChatBackgroundView: View {

    // Pre-computed formula positions (seeded once per view lifetime)
    @State private var items: [FormulaItem] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base color — dark graphite (not OLED black)
                Color(red: 0.09, green: 0.09, blue: 0.10) // #161618

                // Soft blobs — very muted graphite tones
                Canvas { ctx, size in
                    let blobs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                        (0.15, 0.1,  250, 0.04),
                        (0.8,  0.25, 300, 0.03),
                        (0.3,  0.6,  280, 0.035),
                        (0.7,  0.75, 260, 0.04),
                    ]
                    for (rx, ry, r, op) in blobs {
                        let center = CGPoint(x: size.width * rx, y: size.height * ry)
                        let rect = CGRect(x: center.x - r, y: center.y - r,
                                          width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(Color(red: 0.35, green: 0.35, blue: 0.38).opacity(op)))
                    }
                }

                // Scattered formulas — subtle graphite pencil look
                ForEach(items) { item in
                    Text(item.text)
                        .font(.system(size: item.size, weight: .regular, design: .serif))
                        .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.27).opacity(item.opacity * 4))
                        .rotationEffect(.degrees(item.rotation))
                        .position(x: geo.size.width * item.rx,
                                  y: geo.size.height * item.ry)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                if items.isEmpty {
                    items = Self.generateItems()
                }
            }
        }
    }

    // MARK: - Layout generation

    private static let formulas: [String] = [
        "E = mc²", "∫ f(x) dx", "∑ aₙ", "∇×B", "Δx·Δp ≥ ℏ/2",
        "F = ma", "a² + b² = c²", "eiπ + 1 = 0", "∂f/∂x",
        "λ = h/p", "PV = nRT", "∮ E·dl", "sin²θ + cos²θ = 1",
        "lim x→∞", "dx/dt", "∏ xₙ", "∇²ψ", "log₂ n",
        "φ = (1+√5)/2", "σ = √(Σ(x−μ)²/n)", "∞", "π ≈ 3.14",
        "∂²u/∂t²", "R = V/I", "ΔS ≥ 0", "∫₀^∞ e⁻ˣ dx = 1",
    ]

    private static func generateItems() -> [FormulaItem] {
        var result: [FormulaItem] = []
        var rng = SystemRandomNumberGenerator()

        for formula in formulas {
            let item = FormulaItem(
                text: formula,
                rx: CGFloat.random(in: 0.05...0.95, using: &rng),
                ry: CGFloat.random(in: 0.02...0.98, using: &rng),
                rotation: Double.random(in: -18...18, using: &rng),
                size: CGFloat.random(in: 11...16, using: &rng),
                opacity: Double.random(in: 0.06...0.12, using: &rng)
            )
            result.append(item)
        }
        return result
    }
}

// MARK: - Formula item model

private struct FormulaItem: Identifiable {
    let id = UUID()
    let text: String
    let rx: CGFloat      // relative X (0…1)
    let ry: CGFloat      // relative Y (0…1)
    let rotation: Double // degrees
    let size: CGFloat    // font size
    let opacity: Double  // 0…1
}
