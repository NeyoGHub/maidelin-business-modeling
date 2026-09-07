-- ============================================
-- 麦得邻业务员人效四象限 + 动销漏斗
-- ★ 目的：把业务员从"五维加权一个总分"变成两个管理视图
--   ① 人效四象限：横轴=客户数(规模)、纵轴=户均毛利(质量)
--      高质高量=标杆 / 高量低质=靠堆客户数 / 低量高质=精耕少 / 低量低质=待辅导
--   ② 动销漏斗：覆盖客户数 → 活跃客户数 → 动销客户数（覆盖→活跃、活跃→动销转化率）
-- ★ 客户归属按 kh.ywybh（客户维护业务员）；"近90天有销"算动销/活跃
--   活跃(进过货)≈近90天有销；动销≈近90天有销(可更严：有销且非仅赠品行)
-- ★ 客户池：名下客户全集 kh.sfyx=1 AND kh.ywybh=某业务员（勿用全量销售单客户集）
-- ★ 正确聚合：各指标独立 CTE 再 LEFT JOIN，严禁直接 JOIN 放大
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）+ A8 拜访可选
-- ============================================
;WITH cust AS (            -- 客户资产：每个业务员名下客户数
  SELECT ywybh, COUNT(*) AS 客户数
  FROM kh WHERE sfyx=1
  GROUP BY ywybh
), act AS (                -- 近90天有销客户数（活跃）
  SELECT k.ywybh, COUNT(DISTINCT k.khbh) AS 活跃客户数
  FROM kh k
  JOIN zyxsd z ON z.khbh=k.khbh AND z.zt<>-1
    AND z.xsrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  WHERE k.sfyx=1
  GROUP BY k.ywybh
), dyn AS (                -- 近90天有销(剔除纯赠品行) = 动销客户数
  SELECT k.ywybh, COUNT(DISTINCT k.khbh) AS 动销客户数
  FROM kh k
  JOIN zyxsd z ON z.khbh=k.khbh AND z.zt<>-1
    AND z.xsrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  JOIN zyxsdmx d ON d.xsdh=z.xsdh AND d.xssl>0
  WHERE k.sfyx=1
  GROUP BY k.ywybh
), sale AS (               -- 近90天销售额（单头聚合防放大）
  SELECT k.ywybh, SUM(z.xsje) AS 销售额
  FROM kh k
  JOIN zyxsd z ON z.khbh=k.khbh AND z.zt<>-1
    AND z.xsrq >= CONVERT(CHAR(8), DATEADD(day,-90,GETDATE()),112)
  WHERE k.sfyx=1
  GROUP BY k.ywybh
)
SELECT
  y.xm AS 业务员,
  ISNULL(c.客户数,0) AS 客户数,
  ISNULL(a.活跃客户数,0) AS 活跃客户数,
  ISNULL(d.动销客户数,0) AS 动销客户数,
  -- 动销漏斗转化率（覆盖→活跃→动销）
  CASE WHEN ISNULL(c.客户数,0)>0
    THEN ROUND(ISNULL(a.活跃客户数,0)*1.0/c.客户数*100,1) ELSE 0 END AS 覆盖到活跃PCT,
  CASE WHEN ISNULL(a.活跃客户数,0)>0
    THEN ROUND(ISNULL(d.动销客户数,0)*1.0/a.活跃客户数*100,1) ELSE 0 END AS 活跃到动销PCT,
  ISNULL(s.销售额,0) AS 销售额,
  -- 户均毛利（质量轴）：销售额/客户数作规模近似；如需真毛利用客户利润口径联 01 脚本
  CASE WHEN ISNULL(c.客户数,0)>0
    THEN ROUND(ISNULL(s.销售额,0)*1.0/c.客户数,1) ELSE 0 END AS 户均销售额
FROM ywy y
LEFT JOIN cust c ON c.ywybh=y.ywybh
LEFT JOIN act a ON a.ywybh=y.ywybh
LEFT JOIN dyn d ON d.ywybh=y.ywybh
LEFT JOIN sale s ON s.ywybh=y.ywybh
WHERE y.sfywy=1
ORDER BY ISNULL(c.客户数,0) DESC
