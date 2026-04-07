import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    audioLevel: audioLevel,
                    index: index,
                    barCount: barCount
                )
            }
        }
        .frame(height: 48)
    }
}

private struct WaveformBar: View {
    let audioLevel: Float
    let index: Int
    let barCount: Int

    @State private var phase: Double = 0

    private var normalizedHeight: CGFloat {
        let baseHeight: CGFloat = 0.3
        let variation = sin(Double(index) * 0.8 + phase) * 0.3
        let level = CGFloat(audioLevel) * (0.7 + variation)
        return min(max(baseHeight + level, 0.15), 1.0)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.39, green: 0.4, blue: 0.95),
                        Color(red: 0.93, green: 0.3, blue: 0.6)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: 48 * normalizedHeight)
            .animation(.easeInOut(duration: 0.15), value: audioLevel)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
    }
}
