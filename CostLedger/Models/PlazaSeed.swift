import Foundation
import SwiftData

enum PlazaSeed {
    private static let flagKey = "plazaDemoSeeded_v3"
    private static let migrateKey = "migratedReviewOwnership_v1"

    static func resetFlags() {
        UserDefaults.standard.removeObject(forKey: flagKey)
        UserDefaults.standard.removeObject(forKey: "plazaDemoSeeded_v1")
        UserDefaults.standard.removeObject(forKey: "plazaDemoSeeded_v2")
        UserDefaults.standard.removeObject(forKey: migrateKey)
        UserDefaults.standard.removeObject(forKey: "restoredClosedToPlaza_v1")
    }

    static func bootstrapIfNeeded(context: ModelContext) {
        migrateLegacyIfNeeded(context: context)
        // 旧逻辑裁定后会下架；现改为留在广场，启动时把已决的重新挂回
        restoreClosedToPlazaIfNeeded(context: context)
        backfillDemoVotesIfNeeded(context: context)
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let existingDemos = ((try? context.fetch(FetchDescriptor<ReviewRequest>())) ?? []).filter(\.isDemo)
        if !existingDemos.isEmpty {
            for demo in existingDemos where demo.topicRaw.isEmpty {
                demo.topic = .other
            }
            try? context.save()
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        let samples: [(String, String, Double, String, String, DecisionTopic, [(String, ReviewSuggestion, String)])] = [
            (
                "路过的人",
                "纠结要不要买 299 的蓝牙耳机",
                299,
                "旧的还能用，但降噪一般，通勤很吵。",
                "先用着旧的，或等大促再看。",
                .digital,
                [
                    ("冷傲劝退", .skip, "还能用就别换，把钱留给耳机坏的那天。"),
                    ("数码爱好者", .wait, "先盯一周降价，别今晚下单。"),
                    ("打工人小陈", .doIt, "通勤每天戴，降噪值这个价。"),
                ]
            ),
            (
                "一位冷静的朋友",
                "周末想去吃人均 280 的餐厅",
                280,
                "发工资想犒劳自己，但这个月已经下馆子三次了。",
                "换家人均 80 的，或自己做顿好的。",
                .food,
                [
                    ("省钱搭子", .skip, "这个月第三次了，真的可以缓缓。"),
                    ("美食家阿柚", .doIt, "发工资奖励一下不过分，去吧。"),
                    ("路过吃货", .wait, "看看有没有午市套餐再决定。"),
                ]
            ),
            (
                "匿名用户",
                "要不要报一门 1980 的线上课",
                1980,
                "怕冲动报课吃灰，但又觉得该学点新东西。",
                "先看免费试听和书，真用上再报。",
                .learn,
                [
                    ("课程避雷侠", .skip, "先把收藏夹里未看完的课清掉再说。"),
                    ("学习委员", .wait, "试听两节，写得出笔记再掏钱。"),
                ]
            ),
        ]

        for (author, title, money, reason, alt, topic, votes) in samples {
            let item = ReviewRequest(
                title: title,
                money: money,
                reason: reason,
                alternative: alt,
                status: .pending,
                topic: topic,
                authorName: author,
                isMine: false,
                isPublicOnPlaza: true,
                isDemo: true
            )
            context.insert(item)
            seedVotes(for: [item], context: context, presets: votes)
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    private static func backfillDemoVotesIfNeeded(context: ModelContext) {
        let demos = ((try? context.fetch(FetchDescriptor<ReviewRequest>())) ?? []).filter(\.isDemo)
        guard !demos.isEmpty else { return }
        let votes = (try? context.fetch(FetchDescriptor<ReviewVote>())) ?? []
        let missing = demos.filter { demo in
            !votes.contains { $0.reviewId == demo.id }
        }
        guard !missing.isEmpty else { return }
        seedVotes(for: missing, context: context)
        try? context.save()
    }

    private static func seedVotes(
        for reviews: [ReviewRequest],
        context: ModelContext,
        presets: [(String, ReviewSuggestion, String)]? = nil
    ) {
        let defaultPresets: [(String, ReviewSuggestion, String)] = [
            ("冷傲劝退", .skip, "能不买就不买，先忍一周。"),
            ("路过的人", .wait, "再想想有没有平替。"),
            ("热心网友", .doIt, "理由充分的话可以买。"),
        ]
        for (index, review) in reviews.enumerated() {
            let votes = presets ?? defaultPresets
            for (i, vote) in votes.enumerated() {
                let hoursAgo = Double(index * 2 + i * 3 + 1)
                context.insert(
                    ReviewVote(
                        reviewId: review.id,
                        suggestion: vote.1,
                        comment: vote.2,
                        isMine: false,
                        authorName: vote.0,
                        createdAt: Date().addingTimeInterval(-hoursAgo * 3600)
                    )
                )
            }
        }
    }

    private static func restoreClosedToPlazaIfNeeded(context: ModelContext) {
        let key = "restoredClosedToPlaza_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let all = (try? context.fetch(FetchDescriptor<ReviewRequest>())) ?? []
        for review in all where review.isClosed {
            review.isPublicOnPlaza = true
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    private static func migrateLegacyIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrateKey) else { return }
        let all = (try? context.fetch(FetchDescriptor<ReviewRequest>())) ?? []
        for review in all where !review.isDemo {
            if review.authorName.isEmpty {
                review.authorName = "我"
                review.isMine = true
                review.isPublicOnPlaza = true
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: migrateKey)
    }
}
