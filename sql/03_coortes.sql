-- P2. Coortes de retenção: quem compra volta a comprar? Quanto tempo depois?
-- Coorte = semana (segunda a domingo) da primeira compra no período. Para cada coorte,
-- quantos compradores compraram de novo em cada semana depois da primeira.
-- Semanas sem observação (depois de 31/01/2021) simplesmente não aparecem: no painel,
-- isso fica em branco ("sem dado"), não como zero.

WITH compras AS (
  SELECT DISTINCT
    user_pseudo_id,
    ecommerce.transaction_id AS transacao,
    PARSE_DATE('%Y%m%d', event_date) AS dia
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id NOT IN ('', '(not set)')
),
primeira AS (
  SELECT user_pseudo_id, DATE_TRUNC(MIN(dia), WEEK(MONDAY)) AS coorte
  FROM compras
  GROUP BY user_pseudo_id
),
tamanho AS (
  SELECT coorte, COUNT(*) AS compradores_na_coorte
  FROM primeira
  GROUP BY coorte
),
atividade AS (
  SELECT DISTINCT
    p.coorte,
    DATE_DIFF(DATE_TRUNC(c.dia, WEEK(MONDAY)), p.coorte, WEEK(MONDAY)) AS semana,
    c.user_pseudo_id
  FROM compras c
  JOIN primeira p USING (user_pseudo_id)
)

SELECT
  a.coorte,
  a.semana,
  t.compradores_na_coorte,
  COUNT(*) AS compradores_ativos,
  ROUND(COUNT(*) / t.compradores_na_coorte, 4) AS taxa
FROM atividade a
JOIN tamanho t USING (coorte)
-- A semana 0 (a própria primeira compra, sempre 100%) fica na saída para toda coorte
-- aparecer com o seu tamanho, mesmo as que não tiveram recompra.
GROUP BY a.coorte, a.semana, t.compradores_na_coorte
ORDER BY a.coorte, a.semana
