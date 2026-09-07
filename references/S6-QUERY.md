# S6 数据查询参考（连接 / 执行 / 数据源速查）

供加载本 Skill 的**任意 Agent**（Hermes / Claude / Cursor / OpenCode 等）连接 S6 数据库、把自然语言问题转成正确 SQL 并执行返回。**只读查询，绝不写数据。**

> ⚠️ 文中仓库/渠道的编码与名称（如 0000000007 主仓、idWH 负编码）取自**典型部署示例**，不同客户 S6 的仓库、库名、编码可能不同——先按文末"数据溯源/反验"法对一次界面再全量跑，勿把示例编码当通用常量。

## 一、连接 S6

S6 = 麦得邻商超进销存系统（Microsoft SQL Server 2014）。连接凭据一律走环境变量/平台配置，**本文件不写明文**。

**方式 A：SQL Server MCP server**（推荐，Agent 支持 MCP 时用它提供 executeQuery 工具）
- 配一个 SQL Server MCP（stdio 或 StreamableHTTP），用 executeQuery 工具执行 `scripts/` 里的 SQL。
- 同一实例多库（如 S6 主库 + A8 拜访库）时，写跨库前缀 `x6_system.dbo.表名` 走同一连接即可，勿另建连接。

**方式 B：Python pymssql（脚本/自建执行）**
```python
import pymssql, os
conn = pymssql.connect(
    server=os.environ["S6_HOST"],      # 例 <你的S6服务器地址>
    port=int(os.environ.get("S6_PORT", 1433)),
    user=os.environ["S6_USER"], password=os.environ["S6_PASSWORD"],
    database=os.environ["S6_DB"],      # 例 [你的麦得邻S6数据库]
    tds_version="7.0",                 # 必须 7.0，否则连接失败
    charset="utf8",                    # nvarchar 中文 OK；varchar 中文需 charset='cp936'
    login_timeout=20, timeout=120)
```
- pymssql 须 `tds_version='7.0'`（否则连接失败）；node-mssql(tedious) 也可。
- **连接库名必须精确**：写错/写简库名会报 `18456 登录失败`，那不是密码错，是库名不对。

## 二、SQL Server 2014 语法限制（易踩坑）

| 想用的 | 替代 |
|---|---|
| `LIMIT n` | `SELECT TOP n ...`（SQL 2014 无 LIMIT） |
| `FOR JSON` | 应用层把行合并成 JSON/文本 |
| `STRING_AGG` | 无；用 `FOR XML PATH('')` 或代码聚合 |
| 批次表仓库过滤 | `bi_Stmt_SKU_InvBatch` 字段是 `idWH`（负编码，非 ckbh，须按部署实测对照，勿硬编码） |
| 日期条件 | `CONVERT(CHAR(10),GETDATE(),20)` = 'YYYY-MM-DD'；`CONVERT(CHAR(8),...,112)` = 'YYYYMMDD' |
| 中文列别名 | OK（`AS 销售金额`），SQL 节点/脚本按中文列名取 |
| 大表 | 批次表 bi_Stmt_SKU_InvBatch 全量千万行，务必 `dStmt=(SELECT MAX(dStmt)...)` 限当日 |
| 标量 COUNT | 单值 COUNT 经封装解析可能回空被当 0 → 用 `SELECT DISTINCT 目标列` + 应用层 len() |
| IN 长列表 | 含脏值会 Conversion failed → 改用子查询 `IN (SELECT col FROM 源表 WHERE ...)` |
| 同句聚合+标量子查询 | 混用 MIN(jdrq) 与含 apkwsj 的标量子查询会误报 Invalid column → 拆多条简单查询 |

## 三、数据源速查（查什么数 → 哪张表哪个字段）

| 要查 | 表 | 关键字段 | 注意 |
|---|---|---|---|
| 销售金额/单数 | `zyxsd` | xsje / xsdh / xsrq / zt | zt：1=已审核 / 0=未审核 / -1=作废；"含未审核"=zt<>-1；按客户 khbh、业务员 ywybh |
| 销售成本 | `zyxsdmx` | **xssl×jhj**(进货价) | zyxsdmx 无 cbje；明细 join 销售单勿 SUM(z.xsje)（笛卡尔放大） |
| 退货全额/去向 | `xsthd` | thje / **thck(去向仓库)** / thrq / khbh | 仓库在单头 thck；zt IN(1,2) 已审核；**按 thrq 归期勿用单号日期** |
| 退货成本 | `xsthdmx` | **cbje**(成本金额) / cbdj / thsl | 报损成本 = 去向 thck=报损仓 的行；`thsl<>0 AND thje=0` 行=不计退货额（赠品/无价） |
| 费用 | `xsfy` | fyje（**已含券/满减/返现**）/ khbh / fyrq | 只扣一次；用券明细 `zdy_xsfy_yhqje` 仅分析列 |
| 当前库存 | `cpkc` | cpsl / cbdj / ckbh(仓库) / cpbh | **净口径=SUM(cpsl) GROUP BY cpbh**，勿按 cpsl>0 单行筛；可售=主仓 + cp.sfyx=1 |
| 批次效期 | `bi_Stmt_SKU_InvBatch` | idWH(仓库) / MFG / DTE / **LifeLine** / a_Real | DTE=保质期天数非到期日；仅看主仓 idWH；快照 T+1 非实时 |
| 仓库字典 | `ck` | ckbh / ckmc | 主仓(唯一可售) / 报损仓 / 退货仓 / 返厂仓 / 办公铺货仓；编码按部署查 ck |
| 回款/收款 | `xsskd` | skje / skrq / shsj(审核) / zt | 链路：zyxsd→xsfhd.zyxsdh→xsskd_hxmx(djlx='f0')→xsskd；**zt=2 是历史归档非作废** |
| 客户档案 | `kh` | khbh / dwmc / ywybh / **sfyx** / **khlx** / **sszgs**(渠道根) / sjkh(上级) | 渠道：1商超/2母婴/**4流通**/5批发/6医院/10特殊；khlx 1=渠道主体 2=终端 |
| 业务员 | `ywy` | ywybh / xm(姓名) / sfywy / bmdm(部门) | 一级部门业务员可能归在特殊 bmdm，勿仅按 bmdm 圈客户 |
| 应收期末余额 | `TF_getKhyskQmzys(起,止,khbh)` 函数 | **qmzysk 期末应收**（qczysk 期初/qjyis 已收） | 查"客户还差多少钱/应收余额"唯一官方口径，勿手工拼单据 |
| 客户往来对账单 | `TF_getDjmxForKhYskDtb(khbh,起,止)` 函数 | 期初/票前调整/销售发货/收款/退货/费用/期末行；期末行 qjje | S6 应收款对账界面同源；勾稽=期初+销售+调整+退货+费用−收款 |
| 应收账龄 | `bi_Stmt_ARB` | Receivable / WO_Exp / WO_ExpD / d_dbTerm | **仅近约30天滚动窗口**，老欠款不在表内，勿当全量余额 |
| 拜访 | A8 `x6_system` 库 | business_visit_statistics / plan_user_cust_task_exec | 昨日数据凌晨4点生成 |

## 四、自然语言查数拆解示例

**例："上个月销售前 10 的流通客户，附毛利"**
1. 口径：客户毛利 = 销售金额 - 商品成本（退货暂按全额冲减或忽略按需）——若要完整客户利润见 SKILL.md 维度2（含成本+退货冲减+报损+费用）
2. 客户池：`kh.sszgs='4' AND k.khlx=2 AND sfyx=1`（流通终端）
3. SQL 模式（CTE 各自聚合防笛卡尔）：
```sql
;WITH sales AS (
  SELECT khbh, SUM(xsje) sale FROM zyxsd
  WHERE zt<>-1 AND xsrq >= CONVERT(CHAR(8),DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE())-1,0),20)
    AND xsrq <  CONVERT(CHAR(8),DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0),20)
  GROUP BY khbh
), costs AS (
  SELECT z.khbh, SUM(d.xssl*ISNULL(d.jhj,0)) cst
  FROM zyxsdmx d JOIN zyxsd z ON d.xsdh=z.xsdh
  WHERE z.zt<>-1 AND z.xsrq >= CONVERT(CHAR(8),DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE())-1,0),20)
    AND z.xsrq <  CONVERT(CHAR(8),DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE()),0),20)
  GROUP BY z.khbh)
SELECT TOP 10 k.dwmc, s.sale 销售, ISNULL(c.cst,0) 成本, ISNULL(s.sale,0)-ISNULL(c.cst,0) 毛利
FROM kh k
JOIN sales s ON s.khbh=k.khbh LEFT JOIN costs c ON c.khbh=k.khbh
WHERE k.sfyx=1 AND k.sszgs='4' AND k.khlx=2
ORDER BY 毛利 DESC
```
4. 时间窗口：月报用上月整月（DATEADD MONTH 上月1号~本月1号）；日报昨日；周报本周/近90天。**环比必须同期口径**（"本月几天 vs 上月整月"会虚报大跌）。

## 五、查数前必读口径（防返错数）

1. **客户利润必含商品成本**：销售 - 商品成本 - 退货全额 + 退货成本 - 报损成本 - 费用；漏成本毛利 96% 假象
2. **真实退货按去向仓**：thck=报损仓才算损失；返厂/可再销售不算；勿用退货理由文本（旧口径废弃）
3. **活跃度取全历史 MAX(xsrq)**：近90天窗口分不出 91~180 与 >180
4. **流通客户池 = sszgs='4' AND khlx=2**：勿按业务员 bmdm 过滤（漏一级部门业务员 + 混 KA 连锁）；勿把 khlx=1 分区主体当客户
5. **防笛卡尔积**：客户多销售单×退单×费单直接 JOIN 会 SUM 放大 → 各指标独立 CTE
6. **批次表仓库用 idWH**（负编码），不是 ckbh；且勿把示例仓库编码当通用常量
7. 全司真实退货含"退货仓移库入报损"(cpkclsz)；**客户/业务员维度移库无客户字段，只算直标报损**
8. S6 只读：只 SELECT
9. **客户欠款/应收余额只用官方函数** TF_getKhyskQmzys / TF_getDjmxForKhYskDtb；单据手工推算会被"已收款未核销勾单"误导（曾实测大额到账未核销 → 单据推算假欠、官方口径 0）
10. **bi_Stmt_ARB 仅近约30天滚动窗口**；表内无行≠无欠款
11. **xsskd_hxmx 按商品行同额冗余展开**；核销记录≠收款到账（到账以 xsskd.skje 为准）；收款单 zt=2 是历史归档非作废，按时间汇总收款勿 WHERE zt=1

## 六、输出规范（结果要可反验）

返回数字时附：
- **指标口径说明**：该数怎么算的（来源表/字段/筛选/公式）
- **数据溯源**：在 S6 哪个界面可核对（如"客户档案按流通渠道筛"、销售查询按客户+日期）
- 语言：纯中文，禁 emoji/箭头/数学符号（避免客户端乱码）
