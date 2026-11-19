-- P3. Segmentação RFM: quem são os clientes mais valiosos, e quantos estão sumindo?
-- R = dias desde a última compra até 31/01/2021 (fim do período).
-- F = compras distintas, em três faixas (1, 2, 3+): 88% compraram uma vez só, e quintis
--     de frequência não separariam ninguém (decisão da Fase 0).
-- M = receita total em USD; cada transação conta uma vez.
-- R e M viram notas de 1 a 5 por quintil (5 = melhor). Os segmentos saem das regras abaixo.
-- Notas pela posição (RANK), não por NTILE: quem empata (mesmo dia, mesmo valor) ganha a
-- mesma nota, em vez de ser separado por um critério sem sentido, como o id do usuário.

WITH transacoes AS (
  SELECT
    user_pseudo_id,
    ecommerce.transaction_id AS transacao,
    MAX(PARSE_DATE('%Y%m%d', event_date)) AS dia,
    MAX(IFNULL(ecommerce.purchase_revenue_in_usd, 0)) AS receita
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id NOT IN ('', '(not set)')
  GROUP BY user_pseudo_id, transacao
),
clientes AS (
  SELECT
    user_pseudo_id,
    DATE_DIFF(DATE '2021-01-31', MAX(dia), DAY) AS recencia_dias,
    COUNT(*) AS compras,
    SUM(receita) AS receita
  FROM transacoes
  GROUP BY user_pseudo_id
),
notas AS (
  SELECT
    *,
    1 + CAST(FLOOR(5 * (RANK() OVER (ORDER BY recencia_dias DESC) - 1) / COUNT(*) OVER ()) AS INT64) AS r,  -- comprou há menos tempo, nota maior
    CASE WHEN compras = 1 THEN 1 WHEN compras = 2 THEN 2 ELSE 3 END AS f,
    1 + CAST(FLOOR(5 * (RANK() OVER (ORDER BY receita) - 1) / COUNT(*) OVER ()) AS INT64) AS m
  FROM clientes
),
segmentos AS (
  SELECT
    *,
    CASE
      WHEN f >= 2 AND r >= 4 AND m >= 4 THEN '1. Campeões'
      WHEN f >= 2 THEN '2. Fiéis'
      WHEN r >= 4 THEN '3. Novos'
      WHEN r <= 2 AND m >= 4 THEN '4. Em risco (alto valor)'
      WHEN r <= 2 THEN '5. Perdidos'
      ELSE '6. Ocasionais'
    END AS segmento
  FROM notas
)

SELECT
  segmento,
  COUNT(*) AS clientes,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS parcela_dos_clientes,
  ROUND(SUM(receita), 2) AS receita,
  ROUND(SUM(receita) / SUM(SUM(receita)) OVER (), 4) AS parcela_da_receita,
  ROUND(AVG(receita), 2) AS receita_media,
  ROUND(AVG(recencia_dias), 1) AS recencia_media_dias,
  ROUND(AVG(compras), 2) AS compras_medias
FROM segmentos
GROUP BY segmento
ORDER BY segmento
