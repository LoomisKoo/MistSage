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
        SoftPanel(padding: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Image(systemName: record.kind.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tone)

                        MetaTag(text: record.kind.localizedName, fg: tone, bg: toneSoft)

                        if record.money > 0 {
                            Text("\(record.kind.moneyLabel) \(Theme.money(record.money))")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .monospacedDigit()
                        }
                        if record.minutes > 0 {
                            Text(Theme.duration(minutes: record.minutes))
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
                .padding(.vertical, 4)
                Spacer(minLength: 0)
            }
        }
    }
}
