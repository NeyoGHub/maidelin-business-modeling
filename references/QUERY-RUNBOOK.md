# S6/A8 实操 Runbook（真实环境实测沉淀）

> 本文件是 S6-QUERY.md 的补充：记录真实环境验证过的表结构、口径坑与可用 SQL 模板。适合：A8 拜访数据、销售单含未审核/实时状态、品牌判定、库存超储分析、批次查询、大批量明细导出 Excel。

> 数据访问统一走 **s6_mcp 通道**（只读 execute_query），任何 Agent/脚本不得绕过 MCP 另开数据库直连。大批量明细需导出 Excel 时，用 s6_mcp 封装的游标脚本（兼容 `fetchall`/`fetchone` + 数字转 float + 空表兜底），不允许手工 pymssql 直连。

## 1. A8 拜访数据（x6_system 库）

- 用户：`Users.userID`(GUID) / `userName`=中文姓名。业务员 type=0
- 每日汇总：`business_visit_statistics`（date='YYYY-MM-DD' 文本，**凌晨4点生成昨日数据**，昨天用 GETDATE()-1）：
  - `unplan_*`=临时拜访，`plan_*`=计划内拜访；`visit_total` 拜访次数，`unplan_visit_customer_total` 客户数
  - `in_store_total_time`/`on_way_total_time` 单位**分钟**；`transactions_total` 成交单数，`acceptance_amount` 成交金额
- 逐客户明细：`plan_user_cust_task_exec`(exec) JOIN `plan_user_cust`(p) ON planUserCustId=p.id，p.userId=拜访人 GUID，p.customerId→`Customers.customerID/customerName`
  - `plan_user_cust.createDate`≈建档/到店动作时间（门店打卡 7 的单与到店同步到毫秒）
  - **⚠️ exec.status 三态（2026-09-06 踩坑，勿只认 2=完成）**：`status=2`=已完成(可带 finishDate)、`status=1`=**进行中/在店未离店**、`status=0`=未签到/待办。查"某人当前在哪家/今天拜访了哪些店"**必须含 status=1 和无 finishDate 的行**——只按 status=2 或有 finishDate 过滤会漏掉大量在店未离/未填离店的拜访。实时位置结论以 status=1 且最新 createDate 的行为准，勿以"缺 finishDate"下结论
  - exec.planTaskId 任务字典（`plan_task`）：**7=门店打卡、35=巡店打卡、34=巡店抄单、55=(付费)陈列照片、56=专项脆辣条陈列、57=某品牌陈列照片**
  - 每客户每次到店 = 一个 plan_user_cust + 打卡 exec(7/35)，陈列/抄单为附加 exec；同客户一天可能多条；同店一天可能多条执行记录
- 空表/勿用：`business_visit_punch`（实测空）、`user_visit_record`（userId 是 int 非 GUID）
- 客户档案会被改名/合并（A8 Customers 与 S6 kh 的显示名随档案更新变，长会话内同一客户名可能变），对账以编码为准
- **⚠️ A8 Customers.s6khbh 不能桥接 S6 终端门店**（2026-09-07 实测）：Customers 表的 `s6khbh` 字段存的是**大系统/渠道主体**的编码（连锁系统、对公费用往来、渠道分区主体等），**不是终端门店的 khbh**——终端门店通过 s6khbh 等值 join 一条都对不上。**A8 拜访客户 ↔ S6 终端门店只能靠 customerName 精确匹配**（容错：A8 名 vs S6 dwmc strip 后相等）。名字不完全一致（改名/加括号/空格）会漏配→把"其实拜访了"误判成沉默——**属保守口径，实际沉默数比名单可能略少**，交付时说明

## 2. 直营销售单实时口径（zyxsd，含未审核）

- 状态：**zt: 1=已审核、0=未审核、-1=作废**；"含未审核"=`zt<>-1`；"只看已审核"=zt=1
- 时间三口径（最易踩坑）：
  - `xsrq`=业务/开单日期（'YYYY-MM-DD' 文本列，字符串区间比较）；单号 YD-业务日期-序号。查"某日开单"用它
  - `jdrq`=手机录单时间（当晚单均在业务日当天）；`apkwsj`=手机**同步到服务器**时间：夜单（19-22 点录）可能次日凌晨~9:2x 才同步 → 按服务器接收时间归类会把它们算成次日，"昨天"单数和金额对不上
  - `shsj`=审核时间（未审核为空）
- **审核滚动**：次日上午 9:5x 起审核员逐张审昨日单（几分钟一张），"已审/未审"拆分实时变，**总量 zt<>-1 不变**。交付时标注拉取时刻，提示以系统实时为准
- **界面漏单**：销售查询默认视图可能不带"已审核且已进入装车/发货环节"的单（实测有单号界面查不到）。反验：按单号直接搜、把单据状态（已审核/已发货等）勾全
- 逐单对账：`zyxsdmx` SUM(xsje) 逐单 = 单头 xsje（一致）；赠品行 xssl=0 且 xsje=0 不影响合计
- 金额双口径：`xsje`=折后应收（界面默认），`yxsje`=折前原单金额（整单优惠前）
- 业务员口径：单据业务员 `zyxsd.ywybh` vs 客户维护业务员 `kh.ywybh`——界面"按业务员"可能用后者；两者不一致的单要交叉验证

## 3. 商品历史销售（某商品某年开过几单/多少量）

```sql
SELECT m.cpbh, p.cpmc, COUNT(DISTINCT z.xsdh) 单数, SUM(m.xssl) 数量, SUM(m.xsje) 金额
FROM zyxsdmx m JOIN zyxsd z ON m.xsdh=z.xsdh JOIN cp p ON m.cpbh=p.cpbh
WHERE m.cpbh='<编码>' AND z.xsrq>='2025-01-01' AND z.xsrq<'2026-01-01' AND z.zt<>-1
GROUP BY m.cpbh, p.cpmc
```
- 先 `cp WHERE cpmc LIKE '%关键词%'` 定位商品再查；数量/金额可再加 `AND m.xssl>0` 剔除纯赠品行

## 4. 品牌判定（b_kim_SKU.ID_Brand 的坑）

- 商品→品牌映射：`b_kim_SKU`（kID / code3rd=cpbh / ID_Brand）
- **警告**：ID_Brand 档案可能混入大量非该品牌商品（实测某品牌编码挂数百个编码，但品名带该品牌名的仅十几个）→ 判定品牌先做"品名 LIKE + 品牌编码"双口径交叉，确认差异后按用户口径剔除，勿单信任一
- 剔除 SQL：`NOT EXISTS (SELECT 1 FROM b_kim_SKU bk WHERE bk.code3rd=k.cpbh AND bk.ID_Brand=X)`
- 品牌字典是 **`pp`** 表：键 `wwwPPBH`(品牌编码)/`wwwPPMC`(品牌名)/`ppbz`(自营标记)；`cp` 表品牌字段 = `wwwppbh`。按品牌查商品用 `cp.wwwppbh=pp.wwwPPBH`，按品牌名定位先用 `wwwPPMC LIKE '%关键字%'` 拿到品牌编码

## 5. 库存超储分析（库存 vs 60 天需求）

- 库存：`cpkc`（主仓）。⚠️ **净口径=SUM(cpsl) GROUP BY cpbh**（可为负），勿按 `cpsl>0` 单行筛——一正一负抵消、账面已清零的商品按行筛会被虚算有货；成本金额=净库存×cbdj。**可用库存（账面−开单占用）口径见 5b**
- 销量仓库口径：真实销售仓 = **主仓 + 配送仓**（合计占出货大头）；办公铺货仓、报损仓、返厂仓、退货仓的出库**不算销售**（`zyxsdmx.ckbh` 按行带仓）
- 窗口：近半年取前 6 个自然月并注明天数
- 指标：日均=半年销量/天数；60天需求=日均×60；**库存>60天需求=超储**；可售天数=库存/日均；近半年销量=0 → 死库存（可售天数=无销售）

## 5b. 可用库存口径（账面−开单占用）——2026-09 实测验证

- **可用库存 = cpkc 账面净库存(SUM(cpsl)) − 已开单未出库占用**，与 S6 界面"可用库存"一致
- cpkc 行结构：(ckbh, cpbh, ph批次, kwbh库位, cpsl结存, cbdj成本, zjxgsj最近变动)；同品多行（多批/多库位）属正常
- 占用判定（必须**单+商品行级**）：近 90 天 `zyxsd`(zt<>-1) 的明细行，在 `cpkclsz` 里**没有**对应出库扣减记录 → 计入占用
```sql
SELECT m.cpbh, SUM(m.xssl) 占用
FROM zyxsdmx m JOIN zyxsd z ON m.xsdh=z.xsdh
WHERE z.zt<>-1 AND z.xsrq>=CONVERT(CHAR(10),DATEADD(DAY,-90,GETDATE()),120)
  AND NOT EXISTS (SELECT 1 FROM cpkclsz l
    WHERE l.djlx='ZYXSD' AND l.djbh=z.xsdh AND l.cpbh=m.cpbh AND l.sl<0)
GROUP BY m.cpbh
```
  - ⚠️ 勿用整单级 EXISTS（只判单号）：同单其它商品已出库、本品未出时会把本品误剔除（须行级判断）
- `cpkclsz` 库存流水：djlx='ZYXSD'=销售出库(sl 负数)，'YKCK'/'YKRK'=移库出/入；czsj=扣减时刻，kcjc=扣后结存；覆盖全史
- **S6 出库与审核解耦**：销售单未审核也可能已拣货出库扣库存（拣货即扣），"未出库"=未拣货，**勿拿 zt=0 当未出库**；可辅看 zyxsd.jhzt(拣货进度)、zcr/zcsj(装车人/时间)
- 时效：本口径为实时快照，出库/开单实时发生；交付标注拉取时刻
- 校验法：先拿一个单品对用户界面数字（账面−占用=界面可用）验证口径，再跑全量

## 6. 批次查询（bi_Stmt_SKU_InvBatch）

- 快照过滤：`dStmt=(SELECT MAX(dStmt) FROM bi_Stmt_SKU_InvBatch WHERE idWH=<主库idWH>)` AND `idWH=<主库idWH>`（**idWH 负编码不是 ckbh**，需按仓库实测对照）
- 行过滤：`q_Real>0 AND snBatch<>'.'`（批号 "." 是商品汇总行）；每日约凌晨 2 点生成快照（**T+1：当日出库不在快照内**），部分商品无批次管理（无行正常）
- 字段语义补充：`q_Real`=数量 / `q_Free`=可用 / `q_FRZ`=冻结（可见于汇总行）；快照非实时，**不可当实时可用库存**（实时可用口径见 5b）
- 关联：kID → `b_kim_SKU.kID`，取 code3rd=cpbh（商品编码）
- 字段语义：`MFG`=生产日期；**`DTE`=保质期天数（不是到期日）**，到期日=MFG+DTE；`LifeLine`=剩余比例，slDsc='剩余天数/总天数'；`q_Real`=批次数量，`Cost`=成本单价，a_Real=q_Real×Cost
- 业务口径：临期=剩余天数≤90，已过期=到期日<今天；同品多批按到期日升序先出

## 7. 沉默客户 / 流失预警（2026-09 业务方定义口径）

**口径**（业务方明确定义）：客户池内，**近90天有销售**（曾经在卖 / 老客户）+ **近30天既无销售、也无业务员拜访** = 沉默客户 / 正在流失预警。正面即：该客户 90 天前还在进货，但最近 30 天既不进货也没人去店里碰——要跟线激活。

- 三层都要算在**名下客户全集**上（勿用全量销售单客户集）：`kh.sfyx=1 AND kh.ywybh=某业务员` 为全集，逐个判断每家是否命中"90有销 ∧ 非30销 ∧ 非30访"
  - 近90天有销：`zyxsd`(zt<>-1) 90天内对该 khbh 开过单
  - 近30天无销：30天内无该 khbh 销售单
  - 近30天无拜访：A8 `plan_user_cust`(userId=业务员GUID, createDate≥30天前) 里该客户（**customerName 匹配**，见 §1 s6khbh 坑）无记录
- **⚠️ 勿用旧口径**：早期按全渠道或不同口径算，会把沉默率算得虚高。交付前用 `SELECT khbh,dwmc FROM kh WHERE ywybh=...` 直接确认名下客户数，别拿会话旧数字
- **⚠️ 标量 COUNT 坑**（2026-09-07 实测）：单值标量 COUNT 结果经 MCP 封装解析**可能回空**（被当成 0）。**规避**：需要计数的用 `SELECT DISTINCT 列` + 应用层 `len()`，或直接 SELECT 目标列（如 khbh）再数行——不要依赖返回的单值 COUNT
- 沉默客户交付：按人分 sheet（编码/名称/最近销售日期/最近拜访日期/上次金额），口径说明 sheet 注明"名字匹配是保守口径"。沉淀技能：把口径写回本 SKILL

## 8. 超储×批次合并交付

- 用户要"产品带批次"时做**产品×批次展开表**（一行=一产品的某一批，产品字段+批次字段同排），不要产品和批次分两个 sheet；无批次产品单列一行标"无批次记录"
- Excel 交付惯例：多 sheet（汇总 / 明细 / 口径说明），表头冻结，未审核行橙底、已审核行绿底，临期黄底、过期橙底；**口径说明 sheet 必备（可反验）**；活数据标注拉取时刻
