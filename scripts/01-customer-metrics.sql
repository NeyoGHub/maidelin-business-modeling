-- ============================================
-- 麦得邻客户核心指标（活跃度 / 客户利润 / 真实退货）
-- ★ 客户利润(完整损益, 必含商品成本) =
--    销售金额 - 商品成本 - 退货全额 + 退货成本 - 报损成本 - 费用(xsfy.fyje)
-- ★ 真实退货 = 退货单去向报损仓(0000000005) 的成本（仅报损是真损失，返厂/可再销售不算）
-- ★ 正确聚合：各指标用独立 CTE 聚合再 JOIN，严禁多表直接 JOIN（会笛卡尔积放大 SUM）
-- ⚠️ xsfy 费用单已含券/满减/返现/收款调整，净扣减只算一次
-- ⚠️ 客户池：通用 kh.sfyx=1；旺哥分级场景仅流通渠道终端 kh.sszgs='4' AND k.khlx=2
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）
-- ============================================
;WITH sales AS (
  -- 近90天销售：金额/单数（销售成本用 zyxsdmx 数量×jhj，勿用明细 JOIN 叠加 zyxsd.xsje）
  SELECT khbh, SUM(xsje) AS sale, COUNT(DISTINCT xsdh) AS cnt
  FROM zyxsd
  WHERE zt <> -1 AND xsrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  GROUP BY khbh
), costs AS (
  -- 商品成本（zyxsdmx.jhj 进货价；zyxsdmx 无 cbje，勿用它 join zyxsd 再 SUM(z.xsje) 会放大）
  SELECT z.khbh, SUM(d.xssl * ISNULL(d.jhj,0)) AS cst
  FROM zyxsdmx d JOIN zyxsd z ON d.xsdh = z.xsdh
  WHERE z.zt <> -1 AND z.xsrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  GROUP BY z.khbh
), lastbuy AS (
  -- 最近一次开单（全历史，用于活跃度四档；近90天窗口不够分 90~180 天）
  SELECT khbh, MAX(xsrq) AS last_date FROM zyxsd WHERE zt <> -1 GROUP BY khbh
), retfull AS (
  -- 退货全额(金额thje) + 退货成本(cbje，全去向；xsthdmx 有 cbje)
  SELECT h.khbh, SUM(m.thje) AS rje, SUM(m.cbje) AS rcb
  FROM xsthdmx m JOIN xsthd h ON m.thdh = h.thdh
  WHERE h.zt IN (1,2) AND h.thrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  GROUP BY h.khbh
), retbs AS (
  -- 报损退货（去向仓=报损 0000000005 的成本）——真实损失
  SELECT h.khbh, SUM(m.cbje) AS bs
  FROM xsthdmx m JOIN xsthd h ON m.thdh = h.thdh
  WHERE h.zt IN (1,2) AND h.thck = '0000000005'
    AND h.thrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  GROUP BY h.khbh
), expenses AS (
  -- 费用（已含券/满减/返现，不重复扣）
  SELECT khbh, SUM(fyje) AS exp
  FROM xsfy
  WHERE zt <> -1 AND fyrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  GROUP BY khbh
)
SELECT
  k.khbh, k.dwmc, k.ywybh,
  -- 活跃度：最近开单距今天数（应用层分档：<=45活跃 / 46~90潜在 / 91~180流失 / >180无效）
  CASE WHEN lb.last_date IS NULL THEN 9999 ELSE DATEDIFF(day, lb.last_date, GETDATE()) END AS r_days,
  ISNULL(s.sale,0) AS 销售金额,
  ISNULL(c.cst,0)  AS 商品成本,
  ISNULL(r.rje,0)  AS 退货全额,
  ISNULL(r.rcb,0)  AS 退货成本,
  ISNULL(b.bs,0)   AS 报损退货(真损失),
  ISNULL(e.exp,0)  AS 费用(已含券),
  -- ★ 客户利润(近90天, 完整损益含成本)
  ISNULL(s.sale,0) - ISNULL(c.cst,0) - ISNULL(r.rje,0) + ISNULL(r.rcb,0) - ISNULL(b.bs,0) - ISNULL(e.exp,0) AS 客户利润,
  -- 真实退货率(报损成本 / 销售额)
  CASE WHEN ISNULL(s.sale,0) > 0
    THEN ROUND(ISNULL(b.bs,0) / NULLIF(ISNULL(s.sale,0),0) * 100, 1) ELSE 0 END AS 真实退货率
FROM kh k
LEFT JOIN sales s ON s.khbh = k.khbh
LEFT JOIN costs c ON c.khbh = k.khbh
LEFT JOIN lastbuy lb ON lb.khbh = k.khbh
LEFT JOIN retfull r ON r.khbh = k.khbh
LEFT JOIN retbs b ON b.khbh = k.khbh
LEFT JOIN expenses e ON e.khbh = k.khbh
WHERE k.sfyx = 1
  -- 旺哥流通分级场景：AND k.sszgs = '4' AND k.khlx = 2（仅流通渠道终端门店；商超/母婴/批发渠道不参与）
ORDER BY 客户利润 DESC
