-- ============================================
-- 客户平均回款周期（严谨算法）
-- 口径（旺哥拍板）：
--   ① 时间窗：销售审核时间 ∈ [查询日-180天, 查询日]
--   ② 每张直营销售单，通过 xsfhd.zyxsdh → xsskd_hxmx → xsskd 找到收款
--   ③ 多张收款单时取最早收款审核（首笔到账）
--   ④ 该单回款 = 首笔收款审核 − 销售审核；客户平均 = AVG
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）
-- ============================================
SELECT
  k.dwmc,
  d.khbh,
  COUNT(*) AS 销售单数,
  ROUND(AVG(d.days), 1) AS 平均回款周期
FROM (
  SELECT
    z.khbh,
    z.xsdh,
    DATEDIFF(day, z.shsj, MIN(kk.shsj)) AS days
  FROM zyxsd z
  JOIN xsfhd f ON f.zyxsdh = z.xsdh AND f.zt <> -1
  JOIN xsskd_hxmx h ON h.djhm = f.fhdh AND h.djlx = 'f0'
  JOIN xsskd kk ON kk.skdh = h.skdh AND kk.shsj IS NOT NULL AND kk.zt <> -1
  WHERE z.zt = 1
    AND z.shsj >= DATEADD(day, -180, GETDATE())
  GROUP BY z.khbh, z.xsdh, z.shsj
) d
LEFT JOIN kh k ON d.khbh = k.khbh
GROUP BY k.dwmc, d.khbh
HAVING COUNT(*) >= 10          -- 过滤样本太少的客户
ORDER BY 平均回款周期 DESC

-- 分档参考：0-3天现结 | 3-30天正常 | >60天高危欠款
