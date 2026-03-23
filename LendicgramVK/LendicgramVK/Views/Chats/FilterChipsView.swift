import SwiftUI

struct FilterChip: Identifiable {
    let id = UUID()
    let title: String
    let count: Int?
}

struct FilterChipsView: View {
    @Binding var selected: String
    let chips: [FilterChip]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selected = chip.title
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if chip.title == "Все" {
                                Image(systemName: "circle.grid.2x2.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(
                                        selected == chip.title
                                        ? Color(red: 0.18, green: 0.22, blue: 0.18)
                                        : Color(white: 0.6)
                                    )
                            } else {
                                Text(chip.title)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            if let count = chip.count {
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(selected == chip.title
                                                  ? Color(red: 0.18, green: 0.22, blue: 0.18).opacity(0.35)
                                                  : Color(red: 0.25, green: 0.55, blue: 0.35))
                                    )
                                    .foregroundColor(selected == chip.title
                                                     ? Color(red: 0.18, green: 0.22, blue: 0.18)
                                                     : .white)
                            }
                        }
                        .padding(.horizontal, chip.title == "Все" ? 10 : 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selected == chip.title
                                      ? Color(red: 0.45, green: 0.85, blue: 0.55)
                                      : Color(white: 0.15))
                        )
                        .foregroundColor(selected == chip.title
                                         ? Color(red: 0.1, green: 0.2, blue: 0.12)
                                         : Color(white: 0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
