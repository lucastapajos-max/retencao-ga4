-- Fase 0: perfil do dataset antes de qualquer análise.
-- Responde: quantos eventos, usuários, sessões e compras existem; quais eventos do funil
-- aparecem e em que volume; quanto dos campos de canal e dispositivo vem mascarado;
-- e quantas compras cada comprador faz (decide se o F do RFM varia o bastante).
-- Cada bloco é uma linha (metrica, chave, valor) para caber numa tabela só.

WITH eventos AS (
  SELECT
    event_name,
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sessao,
    device.category AS dispositivo,
    traffic_source.medium AS canal,
    ecommerce.transaction_id AS transacao
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
compras_por_usuario AS (
  SELECT user_pseudo_id, COUNT(DISTINCT transacao) AS compras
  FROM eventos
  WHERE event_name = 'purchase' AND transacao IS NOT NULL AND transacao NOT IN ('', '(not set)')
  GROUP BY user_pseudo_id
)

SELECT 'total' AS metrica, 'eventos' AS chave, COUNT(*) AS valor FROM eventos
UNION ALL SELECT 'total', 'usuarios', COUNT(DISTINCT user_pseudo_id) FROM eventos
UNION ALL SELECT 'total', 'sessoes', COUNT(DISTINCT CONCAT(user_pseudo_id, CAST(sessao AS STRING))) FROM eventos
UNION ALL SELECT 'total', 'compradores', COUNT(*) FROM compras_por_usuario

UNION ALL
SELECT 'evento_funil', event_name, COUNT(*)
FROM eventos
WHERE event_name IN ('session_start', 'view_item', 'add_to_cart', 'begin_checkout', 'purchase')
GROUP BY event_name

UNION ALL
SELECT 'dispositivo', IFNULL(NULLIF(dispositivo, ''), '(vazio)'), COUNT(DISTINCT user_pseudo_id)
FROM eventos GROUP BY 2

UNION ALL
SELECT 'canal', IFNULL(NULLIF(canal, ''), '(vazio)'), COUNT(DISTINCT user_pseudo_id)
FROM eventos GROUP BY 2

UNION ALL
SELECT 'compras_por_comprador', CAST(LEAST(compras, 5) AS STRING), COUNT(*)  -- 5 = "5 ou mais"
FROM compras_por_usuario GROUP BY 2

ORDER BY metrica, valor DESC
