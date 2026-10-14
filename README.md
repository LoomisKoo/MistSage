# 雾中仙（MistSage）

iOS 原生 App：记录决策的钱与时间代价，管理轻量资产柜。社交评审后续再加。

## 打开工程

```bash
cd /Users/loomiskoo/loomis/Project/XCodeProject/MistSage
# 若尚未生成 xcodeproj：
brew install xcodegen && xcodegen generate
open MistSage.xcodeproj
```

用 Xcode 选模拟器或真机 Run。

## MVP

- 首页：今日生活成本（可选）、本月省下的总代价、闲置提醒
- 记录：做了 / 没做 / 花了钱 / 省了钱 + 钱 + 分钟
- 资产柜：购入价、用了一次、充足/不多了/见底、闲置提示
- 设置：自定「一小时值多少钱」（不绑工资）

## 数据与同步

- 云端：CloudKit 公开库（容器 `iCloud.com.tincom.mistsage`），占开发者配额，不占用户 iCloud 空间
- 身份：直接用 iCloud 身份，`Identity` 表映射到 `User` 表；以后加登录只需多插一条 Identity
- 本地：SwiftData 只做当前账号的缓存；界面只读写本地，`Cloud/CloudSync.swift` 负责双向同步
- 未登录 iCloud：只能浏览广场

### 表结构

| 表 | 主键 | 字段 |
|----|------|------|
| Identity | `icloud_<iCloud用户ID>` | user → User |
| User | UUID | nickname, avatar → Image, gender, state, hourlyRate, timeCostAssist, monthlyIncome, dailyIncome, workDaysPerMonth, hoursPerDay, showDailyCost |
| Decision | UUID | owner → User, title, kind, topic, money, minutes, note, createdAt |
| Review | UUID | author → User, title, topic, money, minutes, reason, alternative, constraints, status, coolUntil, decidedAt, isPublic, region（cn / global）, createdAt |
| Vote | `<ReviewID>_<UserID>` | review → Review, voter → User, suggestion, comment, createdAt |
| Asset | UUID | owner → User, name, summary, price, estimatedUses, useCount, kind, stockStatus, iconName, cover → Image, isPublic, purchasedAt, lastUsedAt, createdAt |
| Image | UUID | owner → User, kind（avatar / asset）, parent, file, thumbnail, sortIndex, width, height |
| Block | `<我的UserID>_<对方UserID>` | blocker → User, blocked → User, createdAt |
| Report | UUID | reporter → User, targetType（review / vote / user）, target, targetUser → User, reason, detail, createdAt |
| Notice | UUID | recipient → User, actor → User, kind（vote / decided）, review → Review, reviewTitle, createdAt |

昵称、头像等用户信息只存在 User 表，其它表只存引用。资产可有多张图（最多 9 张），每张一条 Image，按 sortIndex 排序，Asset.cover 指向第一张。

- 分区：按 App Store 商店地区区分，中国区为 `cn`，其余为 `global`（`Cloud/AppRegion.swift`）。所有表上传时都写入 region（新建记录统一走 `CKRecord.outgoing`），征求建议的 region 在发布时固定。目前只有广场按 region 查询（只需给 Review 建 region 索引）；建议、用户主页只能从本区帖子进入。以后若拆成国内 / 海外两个容器，按 region 迁移即可
- 拉黑：只在本机过滤被拉黑者的帖子和建议，可在「设置 - 黑名单」解除
- 举报：写入 Report 表，开发者在 CloudKit Console 里查看处理
- 推送：互动时写一条 Notice，对方设备通过 CKQuerySubscription 收到推送；冷静期结束用本地通知

### CloudKit Dashboard 首次配置

1. Xcode → Signing & Capabilities 选开发者 Team，确认 iCloud / CloudKit 容器 `iCloud.com.tincom.mistsage` 已勾选
2. 在登录了 iCloud 的设备或模拟器上运行，随便记一笔、发一帖、给一条建议、登记一个带照片的资产，开发环境会自动建表
3. 在 [CloudKit Console](https://icloud.developer.apple.com/) → Schema → Indexes 添加：
   - Review：`isPublic` Queryable，`region` Queryable，`author` Queryable，`createdAt` Sortable
   - Decision：`owner` Queryable
   - Asset：`owner` Queryable，`isPublic` Queryable，`createdAt` Sortable
   - Vote：`review` Queryable，`voter` Queryable
   - Image：`owner` Queryable，`kind` Queryable，`parent` Queryable
   - Block：`blocker` Queryable
   - Notice：`recipient` Queryable，`kind` Queryable
   - 所有表的 `recordName` Queryable（订阅和按 ID 查询需要）
4. Schema → Security Roles：Report 去掉 `_world` 和 `_icloud` 的 Read，只保留 `_icloud` Create（举报内容只有开发者能看）；Notice 去掉 `_world` 的 Read，保留 `_icloud` Read（订阅推送需要）
5. Xcode → Signing & Capabilities 确认 Push Notifications 已开启（`aps-environment` 已写在 project.yml）
6. 上架前在 Console 里把 Schema 部署到 Production，并把 `aps-environment` 改成 `production`
