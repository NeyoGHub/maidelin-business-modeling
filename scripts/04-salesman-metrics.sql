-- ============================================
-- 业务员指标（五维画像）
-- 维度：客户资产 / 业绩产出 / 拜访效率(A8) / 回款能力 / 开发能力
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）+ A8（[你的麦得邻A8数据库]）
-- ============================================
SELECT
  y.ywybh,
  y.xm AS 业务员,
  y.bmdm AS 部门,

  -- ★ 客户资产
  COUNT(DISTINCT CASE WHEN k.sfyx = 1 THEN k.khbh END) AS 有效客户数,
  COUNT(DISTINCT CASE WHEN k.sfyx = 1 AND s.近90天销售额 > 0 THEN k.khbh END) AS 活跃客户数,

  -- ★ 业绩产出（近90天）
  ISNULL(SUM(CASE WHEN z.xsrq >= CONVERT(CHAR(8),DATEADD(day,-90,GETDATE()),112)
    AND z.zt <> -1 THEN z.xsje END), 0) AS 近90天销售额

FROM ywy y
LEFT JOIN kh k ON k.ywybh = y.ywybh
LEFT JOIN zyxsd z ON z.ywybh = y.ywybh
WHERE y.sfywy = 1
GROUP BY y.ywybh, y.xm, y.bmdm
ORDER BY 近90天销售额 DESC

-- 补充：拜访效率从 A8 [你的麦得邻A8数据库].business_visit_statistics 取
--       回款能力 = 名下客户平均回款周期（见 02-collection-cycle.sql）
--       考核权重：拜访数量30% + 有效产出70%（应用层加权）
