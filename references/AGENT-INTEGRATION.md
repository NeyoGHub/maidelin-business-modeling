# maidelin-business-modeling · AI Agent 对接使用教程

本 SKILL 采用 **SKILL.md 开放标准**（Anthropic 发布，[agentskills.io](https://agentskills.io)），**同一份 SKILL.md 无需修改**即可在 Claude Code、OpenClaw、WorkBuddy、Codex CLI、Cursor 等主流 Agent 系统中运行。

---

## 一、SKILL 本质与跨平台原理

```
SKILL.md = 给 AI 的"专业方法说明书"
  frontmatter: name + description（Agent 用来判断何时触发）
  正文: 分步骤的方法论（三大模块建模指令）
```

**渐进式披露**：Agent 启动时只加载每个技能的 name/description，仅当任务匹配时才加载完整 SKILL.md——所以技能再多也不占上下文。

## 二、各主流 Agent 平台对接

### 1️⃣ Claude Code（本 SKILL 开发环境）

```bash
mkdir -p ~/.claude/skills
cp -r maidelin-business-modeling ~/.claude/skills/
```
重启后自动识别。使用：对话直接说 / `/maidelin-business-modeling`。

### 2️⃣ OpenClaw（开源 Agent 平台）

**方式 A：本地技能目录**（推荐）
```bash
mkdir -p ~/.openclaw/skills
cp -r maidelin-business-modeling ~/.openclaw/skills/
```

**方式 B：Claude 插件机制**（OpenClaw 原生识别 Claude 技能格式）
```
在 OpenClaw 中执行：
/plugin add <本技能路径>
```

**方式 C：MCP 桥接**（把技能转成 MCP 工具，供任何 MCP 客户端）
```bash
npx @effectorhq/skill-mcp serve ./maidelin-business-modeling/
# 在 Agent 的 mcpServers 配置中指向该 MCP 服务器
```

**方式 D：ClawHub 注册中心**（发布后他人可搜索安装）
- 将技能发布到 [ClawHub](https://hub.openclaw.ai)，用户通过 `/plugin install maidelin-business-modeling` 安装

### 3️⃣ WorkBuddy（腾讯 OpenClaw Agent 桌面工作台）

**方式 A：拖拽导入**（最简单）
- 打开 WorkBuddy → 聊天框输入"导入技能"或**直接拖拽 SKILL.md 文件** → 30 秒生效

**方式 B：本地技能目录**
```bash
# Linux/macOS
mkdir -p ~/.workbuddy/skills
cp -r maidelin-business-modeling ~/.workbuddy/skills/
# Windows
copy maidelin-business-modeling %USERPROFILE%\.workbuddy\skills\
```
重启 WorkBuddy 生效。

**方式 C：SkillHub 搜索安装**（已发布后）
- 左侧"技能"面板 → SkillHub Tab → 搜索 `maidelin-business-modeling`

> ⚠️ 注意：WorkBuddy 的 Skill 支持 `version/author/tags/trigger_keywords` 字段，如需增强触发可参考其 YAML 规范补充 frontmatter。

### 4️⃣ 其他 Agent（Codex CLI / Cursor / OpenCode / Hermes）

SKILL.md 开放标准保证兼容，安装到对应技能目录即可：

| 平台 | 技能目录 |
|---|---|
| Codex CLI | `~/.codex/skills/` |
| Cursor | `.cursor/skills/`（项目级） |
| OpenCode | `~/.config/opencode/skills/` |
| Hermes Agent | `~/.hermes/skills/` |

**一键同步工具**（bohrium-skills-cli）：
```bash
npx bohrium-skills-cli install maidelin-business-modeling
# 自动同步到 ~/.agents/skills、~/.claude/skills、~/.codex/skills 等
```

## 三、数据源配置（关键）

本 SKILL 的 SQL 查询基于**麦得邻三件套**表结构，但**不含任何连接信息**（IP/账号/密码已脱敏为占位符）。使用前需为 Agent 配置数据访问：

| 数据 | 需要配置 | 配置方式 |
|---|---|---|
| **S6 ERP** | SQL Server 连接（主机/库/只读账号） | 各平台的数据库 MCP 工具（如 mssql MCP）|
| **A8 外勤** | x6_system 库连接 | 同上（或同一 SQL Server 实例）|
| **BI** | 预计算表访问 | 同上 |

**推荐**：为 Agent 配置一个 **mssql MCP 服务器**（只读），指向麦得邻 S6 实例，SKILL 里的 SQL 脚本即可直接执行。

## 四、使用方式（各平台通用）

接入后，用自然语言触发（无需记命令）：

| 需求 | 问法示例 |
|---|---|
| 客户评估 | "帮我评估 XX 客户值不值得重点维护" |
| 客户分级 | "把我名下客户做 ABC 分级" |
| 风险排查 | "找出回款超过 60 天的客户" |
| 商品策略 | "这个新品该推给哪些客户" |
| 拜访清单 | "生成今天的 20 家拜访清单" |
| 业务员考核 | "评估各业务员本月表现" |

完整案例见 [USAGE.md](USAGE.md)

## 五、常见问题

**Q1：SKILL 加载了但 SQL 连不上数据库？**
→ 需先为 Agent 配置麦得邻数据库的 MCP 连接器（见"数据源配置"），SKILL 只提供 SQL 逻辑，不负责连接。

**Q2：不同平台 frontmatter 字段有差异？**
→ SKILL.md 核心是 name+description（开放标准），其他平台的可选字段（tags/version 等）不兼容时忽略即可，不影响运行。

**Q3：如何分享给其他麦得邻客户？**
→ 发布到 ClawHub / GitHub，其他人通过 SkillHub 或复制技能目录安装。

---

**Sources**：
- [What Are Agent Skills? SKILL.md Explained](https://parallel.ai/articles/what-are-agent-skills)
- [OpenClaw 技能系统文档](https://inbounter.com/learn/claude/skills/skills-system)
- [OpenClaw 插件套件组合](https://docs.openclaw.ai/zh-TW/plugins/bundles)
- [openclaw-bridge-skills (GitHub)](https://github.com/JIRBOY/openclaw-bridge-skills)
- [skill-mcp (npm)](https://www.npmjs.com/package/@effectorhq/skill-mcp)
- [WorkBuddy 使用教程](https://cloud.tencent.com.cn/developer/article/2722703)
- [WorkBuddy Skill 与 MCP 区别](https://cloud.tencent.com.cn/developer/article/2709319)
