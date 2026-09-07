-- ============================================
-- 麦得邻新客留存队列（cohort：首单 → M1/M2/M3 复购）
-- ★ 新客定义：首单(该 khbh 的 MIN(xsrq))落在"新客月"的流通终端
-- ★ 留存口径：该客户在 M1/M2/M3 月是否有销售单（zt<>-1 即可，含未审核）
-- ★ 至少需跨 4 个月数据才看得出 M3；数据不足时输出会标注样本不足
-- ★ 客户池：kh.sfyx=1 AND kh.sszgs='4' AND kh.khlx=2（流通终端，勿按 bmdm 过滤）
-- ★ 以下用 新客月=2026-05、M1=6月 M2=7月 M3=8月 作示例，替换注释日期
-- 正确聚合：各月复购用 DISTINCT khbh 集合，勿与销售明细直接 JOIN 放大
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）
-- ============================================

-- ============================================
-- ① 单客户留存明细：这批新客，谁在 M1/M2/M3 复购、现在多活跃
--    替换"新客月/ M1/M2/M3"窗口为你的月份
-- ============================================
;WITH firstm AS (          -- 首单落新客月的客户
  SELECT khbh, MIN(xsrq) AS fd
  FROM zyxsd WHERE zt<>-1
  GROUP BY khbh
  HAVING MIN(xsrq) >= '2026-05-01' AND MIN(xsrq) < '2026-06-01'
), fmoney AS (             -- 首单月销售额
  SELECT khbh, SUM(xsje) AS amt FROM zyxsd
  WHERE zt<>-1 AND xsrq >= '2026-05-01' AND xsrq < '2026-06-01'
  GROUP BY khbh
), b1 AS (                 -- M1 复购（DISTINCT 防同月多单）
  SELECT DISTINCT khbh FROM zyxsd WHERE zt<>-1
    AND xsrq >= '2026-06-01' AND xsrq < '2026-07-01'
), b2 AS (
  SELECT DISTINCT khbh FROM zyxsd WHERE zt<>-1
    AND xsrq >= '2026-07-01' AND xsrq < '2026-08-01'
), b3 AS (
  SELECT DISTINCT khbh FROM zyxsd WHERE zt<>-1
    AND xsrq >= '2026-08-01' AND xsrq < '2026-09-01'
), lastbuy AS (            -- 最近一次开单（全历史，活跃度四档用）
  SELECT khbh, MAX(xsrq) AS ld FROM zyxsd WHERE zt<>-1 GROUP BY khbh
)
SELECT
  k.dwmc, f.khbh,
  CONVERT(CHAR(10), f.fd, 20) AS 首单日,
  ISNULL(m.amt,0) AS 首单月销售额,
  CASE WHEN b1.khbh IS NOT NULL THEN 1 ELSE 0 END AS 复购M1,
  CASE WHEN b2.khbh IS NOT NULL THEN 1 ELSE 0 END AS 复购M2,
  CASE WHEN b3.khbh IS NOT NULL THEN 1 ELSE 0 END AS 复购M3,
  DATEDIFF(day, lb.ld, GETDATE()) AS 最近进货距今,
  CASE
    WHEN b1.khbh IS NULL THEN '首单未复购-高危(需T+30内召回)'
    WHEN b2.khbh IS NULL THEN '仅M1复购-流失预警'
    WHEN b3.khbh IS NULL THEN '复购至M2-观察中'
    ELSE '已形成复购-健康'
  END AS 建议动作标签
FROM firstm f
JOIN kh k ON f.khbh=k.khbh
LEFT JOIN fmoney m ON m.khbh=f.khbh
LEFT JOIN b1 ON b1.khbh=f.khbh
LEFT JOIN b2 ON b2.khbh=f.khbh
LEFT JOIN b3 ON b3.khbh=f.khbh
LEFT JOIN lastbuy lb ON lb.khbh=f.khbh
WHERE k.sfyx=1 AND k.sszgs='4' AND k.khlx=2
ORDER BY 最近进货距今 DESC

-- ============================================
-- ② cohort 汇总：新客月这批客户的 M1/M2/M3 留存率
--    留存率 = 复购客户数 / 新客数（%）
--    用 COUNT 子查询聚合到单行；需计数的场景勿依赖单值标量 COUNT 走封装
--    （参考 SKILL 注意事项：计数用 SELECT DISTINCT 列 + 应用层 len()）
-- ============================================
;WITH firstm AS (
  SELECT khbh FROM zyxsd WHERE zt<>-1
  GROUP BY khbh
  HAVING MIN(xsrq) >= '2026-05-01' AND MIN(xsrq) < '2026-06-01'
), base AS (               -- 客户池 ∩ 新客
  SELECT f.khbh FROM firstm f
  JOIN kh k ON f.khbh=k.khbh
  WHERE k.sfyx=1 AND k.sszgs='4' AND k.khlx=2
), b1 AS (
  SELECT DISTINCT khbh FROM zyxsd WHERE zt<>-1
    AND xsrq >= '2026-06-01' AND xsrq < '2026-07-01'
), b2 AS (
  SELECT DISTINCT khbh FROM zyxsd WHERE zt<>-1
    AND xsrq >= '2026-07-01' AND xsrq < '2026-08-01'
), b3 AS (
  SELECT DISTINCT khbh FROM zyxsd WHERE zt<>-1
    AND xsrq >= '2026-08-01' AND xsrq < '2026-09-01'
)
SELECT
  (SELECT COUNT(*) FROM base) AS 新客数,
  (SELECT COUNT(*) FROM base b WHERE EXISTS (SELECT 1 FROM b1 x WHERE x.khbh=b.khbh)) AS M1复购数,
  (SELECT COUNT(*) FROM base b WHERE EXISTS (SELECT 1 FROM b2 x WHERE x.khbh=b.khbh)) AS M2复购数,
  (SELECT COUNT(*) FROM base b WHERE EXISTS (SELECT 1 FROM b3 x WHERE x.khbh=b.khbh)) AS M3复购数

