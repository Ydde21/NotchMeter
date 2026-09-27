import SwiftUI

private func usageColor(_ pct: Double) -> Color {
    pct >= 95 ? .red : pct >= 80 ? .orange : .green
}

struct UsageRing: View {
    let percent: Double
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(percent / 100, 1))
                .stroke(usageColor(percent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent))")
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

struct CollapsedView: View {
    @ObservedObject var store: UsageStore
    var body: some View {
        HStack(spacing: 6) {
            if let worst = store.worst {
                UsageRing(percent: worst.worstUsedPercent)
                    .frame(width: 16, height: 16)
                Text("\(worst.name) \(Int(worst.worstUsedPercent))%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                Text("NotchMeter")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProviderRow: View {
    let snap: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(snap.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                if let plan = snap.plan {
                    Text(plan)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if let balance = snap.balanceText {
                    Text(balance)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            ForEach(snap.windows) { w in
                HStack(spacing: 8) {
                    Text(w.label)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 30, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule()
                                .fill(usageColor(w.usedPercent))
                                .frame(width: geo.size.width * min(w.usedPercent / 100, 1))
                        }
                    }
                    .frame(height: 5)
                    Text("\(Int(w.usedPercent))%")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(usageColor(w.usedPercent))
                        .frame(width: 32, alignment: .trailing)
                    if let r = w.resetsIn {
                        Text("↻ \(r)")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ExpandedView: View {
    @ObservedObject var store: UsageStore
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Usage")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                if store.demoMode {
                    Text("demo")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(.yellow.opacity(0.25), in: Capsule())
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.snapshots) { snap in
                        ProviderRow(snap: snap)
                    }
                    ForEach(store.errors.sorted(by: { $0.key < $1.key }), id: \.key) { name, msg in
                        HStack {
                            Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                            Spacer()
                            Text(msg).font(.system(size: 9)).foregroundStyle(.orange.opacity(0.9))
                                .lineLimit(1).truncationMode(.middle)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotchContentView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var viewModel: NotchViewModel
    var onRefresh: () -> Void

    var body: some View {
        Group {
            if viewModel.expanded {
                ExpandedView(store: store, onRefresh: onRefresh)
            } else {
                CollapsedView(store: store)
            }
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: viewModel.expanded ? 16 : 10,
                bottomTrailingRadius: viewModel.expanded ? 16 : 10, topTrailingRadius: 0
            )
            .fill(.black.opacity(0.92))
            .ignoresSafeArea()
        )
    }
}
