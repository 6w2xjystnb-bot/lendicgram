import SwiftUI

// MARK: - Sticker Keyboard View

struct StickerKeyboardView: View {
    let packs: [VKStickerProduct]
    let onSelect: (Int) -> Void

    @State private var selectedPackIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // ── Sticker grid ───────────────────────────────────
            if packs.isEmpty {
                ProgressView("Загрузка стикеров…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                let stickers = packs[safe: selectedPackIndex]?.stickers ?? []
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                              spacing: 8) {
                        ForEach(stickers) { sticker in
                            Button {
                                onSelect(sticker.stickerId)
                            } label: {
                                stickerThumb(sticker)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(height: 260)
            }

            Divider()

            // ── Pack tabs ──────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(packs.enumerated()), id: \.element.id) { idx, pack in
                        Button {
                            selectedPackIndex = idx
                        } label: {
                            packTab(pack, isSelected: idx == selectedPackIndex)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func stickerThumb(_ sticker: VKProductSticker) -> some View {
        if let url = sticker.bestURL {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.quaternarySystemFill))
            }
            .frame(width: 72, height: 72)
        } else {
            Text("🎭")
                .font(.system(size: 36))
                .frame(width: 72, height: 72)
        }
    }

    @ViewBuilder
    private func packTab(_ pack: VKStickerProduct, isSelected: Bool) -> some View {
        if let url = pack.previews?.first.flatMap({ URL(string: $0.url) }) {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 32, height: 32)
            .padding(4)
            .background(isSelected ? Color(.systemFill) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
        } else {
            Text(String(pack.title?.prefix(2) ?? "?"))
                .font(.caption2.bold())
                .frame(width: 32, height: 32)
                .padding(4)
                .background(isSelected ? Color(.systemFill) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Safe subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
