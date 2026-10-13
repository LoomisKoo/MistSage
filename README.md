# 代价账本（CostLedger）

iOS 原生 App：记录决策的钱与时间代价，管理轻量资产柜。社交评审后续再加。

## 打开工程

```bash
cd /Users/loomiskoo/loomis/Project/XCodeProject/CostLedger
# 若尚未生成 xcodeproj：
brew install xcodegen && xcodegen generate
open CostLedger.xcodeproj
```

用 Xcode 选模拟器或真机 Run。

## MVP

- 首页：今日生活成本（可选）、本月省下的总代价、闲置提醒
- 记录：做了 / 没做 / 花了钱 / 省了钱 + 钱 + 分钟
- 资产柜：购入价、用了一次、充足/不多了/见底、闲置提示
- 设置：自定「一小时值多少钱」（不绑工资）

数据：SwiftData 本地存储（暂未接 CloudKit）。
