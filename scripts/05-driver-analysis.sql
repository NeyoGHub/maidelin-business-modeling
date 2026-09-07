-- ============================================
-- 麦得邻异动归因 · 数据层（量价拆 / 客户·产品·业务员贡献 / 头部集中度）
-- ★ 只算"构成与贡献"；"为什么"的四层归因推理见 SKILL.md 模块四
-- ★ 环比必须同期口径（本期 N 天 vs 同期 N 天，勿拿部分天数比整月）
-- ★ 数量 xssl 在明细表 zyxsdmx、金额 xsje 在单头 zyxsd：
--     数量/金额必须各自独立 CTE 聚合再合并，严禁单头 JOIN 明细后 SUM（笛卡尔放大）
-- ★ 客户池：通用 kh.sfyx=1；流通分级场景加 kh.sszgs='4' AND k.khlx=2
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）
-- ============================================

-- ============================================
-- ① 量价拆（全司，本期 vs 同期）
--    替换注释日期为你的窗口（本期/同期天数必须一致）
--    销售额=销量×均价×mix：
--      量差贡献=(本期量-同期量)×同期均价
--      价差贡献=(本期价-同期价)×本期量
--      结构差贡献=总额差-量差-价差（剩余归 mix）
-- ============================================
;WITH amt_cur AS (        -- 本期金额：单头聚合（每单一笔）
  SELECT SUM(xsje) amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-09-01' AND xsrq < '2026-09-05'
), amt_prv AS (           -- 同期金额
  SELECT SUM(xsje) amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-08-01' AND xsrq < '2026-08-05'
), qty_cur AS (           -- 本期数量：明细行聚合（join 单头仅取日期/状态过滤，不 SUM 单头字段）
  SELECT SUM(d.xssl) qty FROM zyxsdmx d JOIN zyxsd z ON d.xsdh=z.xsdh
  WHERE z.zt<>-1 AND z.xsrq >= '2026-09-01' AND z.xsrq < '2026-09-05'
), qty_prv AS (
  SELECT SUM(d.xssl) qty FROM zyxsdmx d JOIN zyxsd z ON d.xsdh=z.xsdh
  WHERE z.zt<>-1 AND z.xsrq >= '2026-08-01' AND z.xsrq < '2026-08-05'
)
SELECT
  ac.amt AS 本期金额, ap.amt AS 同期金额,
  qc.qty AS 本期数量, qp.qty AS 同期数量,
  ac.amt/NULLIF(qc.qty,0) AS 本期均价, ap.amt/NULLIF(qp.qty,0) AS 同期均价,
  ac.amt-ap.amt AS 总额差,
  -- 量/价/结构三拆
  (qc.qty-qp.qty) * ap.amt/NULLIF(qp.qty,0) AS 量差贡献,
  (ac.amt/NULLIF(qc.qty,0) - ap.amt/NULLIF(qp.qty,0)) * qc.qty AS 价差贡献,
  (ac.amt-ap.amt)
    - (qc.qty-qp.qty) * ap.amt/NULLIF(qp.qty,0)
    - (ac.amt/NULLIF(qc.qty,0) - ap.amt/NULLIF(qp.qty,0)) * qc.qty AS 结构差贡献
FROM amt_cur ac CROSS JOIN amt_prv ap
CROSS JOIN qty_cur qc CROSS JOIN qty_prv qp

-- ============================================
-- ② 客户因素贡献：本期 vs 同期，逐客户销售额差
--    用途：Top 掉量客户（负贡献大头）+ Top 增量客户；再叠加活跃度/利润档判断
--    替换注释日期为你的窗口（本期/同期天数一致）
-- ============================================
;WITH cur AS (
  SELECT khbh, SUM(xsje) amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-09-01' AND xsrq < '2026-09-05'
  GROUP BY khbh
), prv AS (
  SELECT khbh, SUM(xsje) amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-08-01' AND xsrq < '2026-08-05'
  GROUP BY khbh
)
SELECT TOP 15 k.dwmc,
  ISNULL(c.amt,0) 本期额, ISNULL(p.amt,0) 同期额,
  ISNULL(c.amt,0)-ISNULL(p.amt,0) 贡献差
FROM kh k
LEFT JOIN cur c ON c.khbh=k.khbh LEFT JOIN prv p ON p.khbh=k.khbh
WHERE k.sfyx=1 AND k.sszgs='4' AND k.khlx=2
  AND ISNULL(c.amt,0)-ISNULL(p.amt,0) <> 0
ORDER BY 贡献差 ASC          -- 负=掉量最大在前；看增量改 DESC

-- ============================================
-- ③ 产品因素贡献：本期 vs 同期，逐 SKU
--    结合 SKILL 商品 ABC（毛利×动销）判断是"利润黑洞/明星/长尾"在拖后腿
-- ============================================
;WITH cur AS (
  SELECT m.cpbh, SUM(m.xsje) amt FROM zyxsdmx m JOIN zyxsd z ON m.xsdh=z.xsdh
  WHERE z.zt<>-1 AND z.xsrq >= '2026-09-01' AND z.xsrq < '2026-09-05'
  GROUP BY m.cpbh
), prv AS (
  SELECT m.cpbh, SUM(m.xsje) amt FROM zyxsdmx m JOIN zyxsd z ON m.xsdh=z.xsdh
  WHERE z.zt<>-1 AND z.xsrq >= '2026-08-01' AND z.xsrq < '2026-08-05'
  GROUP BY m.cpbh
)
SELECT TOP 15 p.cpmc,
  ISNULL(c.amt,0) 本期额, ISNULL(pv.amt,0) 同期额,
  ISNULL(c.amt,0)-ISNULL(pv.amt,0) 贡献差
FROM cp p
LEFT JOIN cur c ON c.cpbh=p.cpbh LEFT JOIN prv pv ON pv.cpbh=p.cpbh
WHERE ISNULL(c.amt,0)-ISNULL(pv.amt,0) <> 0
ORDER BY 贡献差 ASC

-- ============================================
-- ④ 业务员因素贡献：本期 vs 同期，逐业务员
-- ============================================
;WITH cur AS (
  SELECT ywybh, SUM(xsje) amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-09-01' AND xsrq < '2026-09-05'
  GROUP BY ywybh
), prv AS (
  SELECT ywybh, SUM(xsje) amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-08-01' AND xsrq < '2026-08-05'
  GROUP BY ywybh
)
SELECT y.xm,
  ISNULL(c.amt,0) 本期额, ISNULL(p.amt,0) 同期额,
  ISNULL(c.amt,0)-ISNULL(p.amt,0) 贡献差
FROM ywy y
LEFT JOIN cur c ON c.ywybh=y.ywybh LEFT JOIN prv p ON p.ywybh=y.ywybh
WHERE y.sfywy=1 AND ISNULL(c.amt,0)-ISNULL(p.amt,0) <> 0
ORDER BY 贡献差 ASC

-- ============================================
-- ⑤ 头部集中度（业绩是否压在一两个客户/业务员上）
--    占比过高即提示集中度风险（阈值应用层判断，如 >40% 提示；客户/业务员各算）
-- ============================================
;WITH tot AS (
  SELECT SUM(xsje) amt FROM zyxsd WHERE zt<>-1 AND xsrq >= '2026-09-01' AND xsrq < '2026-09-05'
), topcust AS (
  SELECT TOP 3 k.dwmc, SUM(z.xsje) amt
  FROM zyxsd z JOIN kh k ON z.khbh=k.khbh
  WHERE z.zt<>-1 AND z.xsrq >= '2026-09-01' AND z.xsrq < '2026-09-05'
    AND k.sfyx=1 AND k.sszgs='4' AND k.khlx=2
  GROUP BY k.dwmc ORDER BY amt DESC
), topsal AS (
  SELECT TOP 3 y.xm, SUM(z.xsje) amt
  FROM zyxsd z JOIN ywy y ON z.ywybh=y.ywybh
  WHERE z.zt<>-1 AND z.xsrq >= '2026-09-01' AND z.xsrq < '2026-09-05'
  GROUP BY y.xm ORDER BY amt DESC
)
SELECT '客户Top1' AS 维度, (SELECT MAX(amt) FROM topcust)/(SELECT amt FROM tot)*100 AS 占比
UNION ALL SELECT '客户Top3', (SELECT SUM(amt) FROM topcust)/(SELECT amt FROM tot)*100
UNION ALL SELECT '业务员Top1', (SELECT MAX(amt) FROM topsal)/(SELECT amt FROM tot)*100
UNION ALL SELECT '业务员Top3', (SELECT SUM(amt) FROM topsal)/(SELECT amt FROM tot)*100
