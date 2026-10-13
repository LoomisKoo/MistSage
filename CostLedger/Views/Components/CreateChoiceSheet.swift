import SwiftUI

/// 全局悬浮 + ：三个扁平选项
struct CreateChoiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showAddAsset = false
    @State private var showPublish = false
    @State private var showAddDecision = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                choiceCard(
                    icon: "lightbulb.fill",
                    title: "征求建议",
                    subtitle: "纠结事项：冷静期 + 广场收集建议"
                ) {
                    showPublish = true
                }

                choiceCard(
                    icon: "square.and.pencil",
                    title: "直接记录",
                    subtitle: "小事不征求建议，做了 / 没做记一笔"
                ) {
                    showAddDecision = true
                }

                choiceCard(
                    icon: "shippingbox.fill",
                    title: "登记资产",
                    subtitle: "消耗品、耐用品等物品入库"
                ) {
                    showAddAsset = true
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AtmosphereBackground())
            .navigationTitle("新建")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(Theme.inkSoft)
                }
            }
            .sheet(isPresented: $showAddAsset) {
                NavigationStack { AddAssetView() }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPublish) {
                NavigationStack { PublishReviewView() }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddDecision) {
                NavigationStack { AddDecisionView() }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: showAddAsset) { _, open in if !open { dismiss() } }
            .onChange(of: showPublish) { _, open in if !open { dismiss() } }
            .onChange(of: showAddDecision) { _, open in if !open { dismiss() } }
        }
    }

    private func choiceCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SoftPanel(padding: 16) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accentSoft)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.placeholder)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle(pressedScale: 0.98))
    }
}
