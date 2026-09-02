-- ============================================
-- 商品指标（毛利贡献 + 动销率 + 退货率）
-- 口径：毛利额来自 zyxsdmx.mle（明细行自带，无需折算）
-- 数据库：麦得邻 S6（[你的麦得邻S6数据库]）
-- ============================================
SELECT
  m.cpbh,
  p.cpmc,
  SUM(m.xsje) AS 销售额,
  SUM(m.mle)  AS 毛利额,            -- 毛利贡献（商品ABC分级依据）
  COUNT(DISTINCT z.khbh) AS 覆盖客户数,  -- 动销（覆盖广度）
  -- 动销率 = 覆盖客户数 / 有效客户池（应用层计算）
  -- 退货率(质量预警) = 去向报损仓(0000000005)的退货成本 / 销售额（勿用全退金额，返厂/可再销售不算损失）
FROM zyxsdmx m
JOIN zyxsd z ON m.xsdh = z.xsdh
  AND z.zt <> -1
  AND z.xsrq >= CONVERT(CHAR(8), DATEADD(day, -90, GETDATE()), 112)
LEFT JOIN cp p ON m.cpbh = p.cpbh
GROUP BY m.cpbh, p.cpmc
ORDER BY 毛利额 DESC

-- 商品ABC：前20%毛利贡献=核心品(A) / 中60%=常规品(B) / 后20%=长尾品(C)
-- 结合动销：高毛利+高动销=明星品 | 高毛利+低动销=潜力品 | 低毛利+高动销=走量品 | 低毛利+低动销=淘汰品
