# maidelin-business-modeling

> 麦得邻商贸流通客户业务建模量化 · 通用 Agent Skill（agentskills.io 标准）
> Business modeling & quantification for Maidelin S6+A8+BI distribution customers

基于麦得邻 **S6（ERP）+ A8（外勤拜访）+ BI（商业智能）** 三件套数据，把商贸流通/经销商客户的业务**量化成可计算的模型**，为 AI 驱动业务员（该跑哪家、推什么货、精力放哪）提供数据引擎。

---

## ✨ 功能特性

### 模块一 · 客户建模（七维画像）
| 维度 | 说明 |
|---|---|
| 活跃度 | 最近开单四档(45内活跃/46-90潜在/91-180流失/180以上无效) |
| 新客留存(cohort) | 首单月→M1/M2/M3 复购率，标出流失环节（脚本 06） |
| 客户利润 | 销售金额 - 商品成本 - 退货全额 + 退货成本 - 报损成本 - 费用(已含券) |
| 退货率 | 虚假繁荣客户预警 |
| 回款周期 | 销售单→收款单链路，首笔到账，180 天窗口 |
| 返利模式 | 协议(2%/3.5%阶梯) / 普通(券包) 自动识别 |
| 客情关系 | 拜访响应 + 新品 45 天接受度 |
| ABC 分级 | 按客户利润前 20% A / 中 50% B / 后 30% C |

### 模块二 · 商品建模
- 商品 ABC 分级（毛利 + 动销交叉：明星/潜力/走量/淘汰品）
- 按客户类型输出推货策略（A 类推高毛利核心品 / B 类推潜力新品 / C 类推特价清库）
- 高退货产品预警、临期库存清库、新品表现追踪

### 模块三 · 业务员建模
- 五维画像（客户资产/业绩/拜访/回款/开发）
- 人效四象限 + 动销漏斗：堆客户数 vs 靠客户质量，覆盖→活跃→动销（脚本 07）
- 考核评分：拜访数量 30% + 有效产出 70%
- 每日 20 家拜访清单生成（A 类流失预警优先）+ 每店推货策略

### 模块四 · 异动归因（新增）
- 量价拆（量/价/结构三拆）+ 客户/产品/业务员因素贡献 + 头部集中度（脚本 05）
- 四层归因（外部→策略→执行→人员）落到数据支撑，根因追 2 层
- P0/P1/P2 动作闭环：诊断→可派活任务单（数据依据/根因/动作/量化目标/责任岗/时间/验证指标，见 ACTION-FRAMEWORK.md）

---

## 📥 安装

本 Skill 是 agentskills.io 标准结构（SKILL.md + references/ + scripts/），可装到**任意支持该标准的 Agent**（Hermes / Claude / Cursor / OpenCode 等）：

```bash
git clone https://github.com/<your-name>/maidelin-business-modeling.git
# 放到你的 Agent 的 skills 目录（各平台路径见 references/AGENT-INTEGRATION.md）
# 例：Hermes ~/.hermes/skills/ | Claude ~/.claude/skills/ | Cursor .cursor/skills/ | OpenCode ~/.config/opencode/skills/
```

重启/刷新后自动识别。连接 S6 的凭据经环境变量或平台配置注入（见 references/S6-QUERY.md），不写明文。

## 🚀 使用方法

| 方式 | 操作 |
|---|---|
| 对话 | "帮我评估 XX 客户值不值得重点维护"、"做客户 ABC 分级" |
| 命令 | `/maidelin-business-modeling` |
| 自动 | 涉及麦得邻客户/商品/业务员分析时自动加载 |

完整案例见 [`references/USAGE.md`](references/USAGE.md)

## 📁 目录结构

```
maidelin-business-modeling/
├── SKILL.md               # 核心指令（三大模块方法论）
├── README.md              # 本说明
├── references/
│   ├── USAGE.md           # 使用手册（可用案例）
│   ├── FEATURES.md        # 功能说明书（当前 + 未来扩展规划）
│   ├── S6-QUERY.md        # 连接/执行/数据源速查/查数示例
│   ├── QUERY-RUNBOOK.md   # 实测 runbook：A8拜访/实时口径/库存超储/批次/沉默客户
│   └── ACTION-FRAMEWORK.md # P0/P1/P2 动作闭环：诊断→可派活任务单模板
└── scripts/
    ├── 01-customer-metrics.sql   # 客户基础指标（活跃/客户利润/退货率）
    ├── 02-collection-cycle.sql   # 客户回款周期（严谨算法）
    ├── 03-product-metrics.sql    # 商品指标（毛利+动销）
    ├── 04-salesman-metrics.sql   # 业务员指标（五维）
    ├── 05-driver-analysis.sql    # 异动归因：量价拆+客户/产品/业务员贡献+头部集中度
    ├── 06-new-customer-retention.sql  # 新客留存 cohort：首单→M1/M2/M3 复购
    └── 07-salesman-efficiency.sql     # 人效四象限 + 动销漏斗
```

## 🗄️ 数据源（麦得邻三件套）

| 系统 | 用途 |
|---|---|
| **S6** | 商贸 ERP：销售/退货/费用/优惠券/客户/商品/回款（SQL Server） |
| **A8** | 外勤拜访：拜访记录/进店时长/照片（x6_system 库） |
| **BI** | 商业智能：客户应收/逾期（bi_Stmt_ARB 等预计算表） |

> ⚠️ 只读原则：SKILL 只读数据、输出分析，不修改任何业务数据。

## 📄 许可证

MIT License

---

**相关文档**：[功能说明书](references/FEATURES.md) · [使用手册](references/USAGE.md) · [多 Agent 平台对接教程](references/AGENT-INTEGRATION.md)

## 🤖 多 Agent 平台支持

SKILL.md 开放标准（[agentskills.io](https://agentskills.io)），一份 SKILL 跨平台运行：**Claude Code / OpenClaw / WorkBuddy / Codex CLI / Cursor** 等。详细对接见 [AGENT-INTEGRATION.md](references/AGENT-INTEGRATION.md)。
