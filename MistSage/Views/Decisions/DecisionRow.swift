import SwiftUI

struct DecisionRow: View {
    let record: DecisionRecord
    let hourlyRate: Double

    private var tone: Color {
        record.kind == .skipped ? Theme.accentDeep : Theme.inkSoft
    }

    private var toneSoft: Color {
        record.kind == .skipped ? Theme.accentSoft : Theme.paperDeep
    }

    var body: some View {
        SoftPanel(padding: 16) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(toneSoft)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: record.kind.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(tone)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text(record.kind.localizedName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tone)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(toneSoft))

                        if record.money > 0 {
                            Text("\(record.kind.moneyLabel) \(Theme.money(record.money))")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .monospacedDigit()
                        }
                        if record.minutes > 0 {
                            Text("\(record.minutes) 分")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }

                    if hourlyRate > 0, record.minutes > 0 {
                        Text("时间代价 \(Theme.money(record.timeCost(hourlyRate: hourlyRate)))")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
