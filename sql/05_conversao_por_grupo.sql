-- P4 (entrada). Conversão por grupo: sessões e sessões com compra, por dispositivo e por canal.
-- O teste de duas proporções roda em analise/teste_proporcoes.py sobre esta tabela.
-- Canal = traffic_source.medium (origem do primeiro acesso do usuário). Os valores mascarados
-- (<Other>, (data deleted), vazio) ficam de fora e entram como linha própria, para o README
-- mostrar quanto foi excluído.

WITH eventos AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sessao,
    device.category AS dispositivo,
    traffic_source.medium AS canal,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
sessoes AS (
  SELECT
    user_pseudo_id,
    sessao,
    ANY_VALUE(dispositivo) AS dispositivo,
    ANY_VALUE(canal) AS canal,
    LOGICAL_OR(event_name = 'purchase') AS comprou
  FROM eventos
  WHERE sessao IS NOT NULL
  GROUP BY user_pseudo_id, sessao
),
grupos AS (
SELECT 'dispositivo' AS dimensao, dispositivo AS grupo, COUNT(*) AS sessoes, COUNTIF(comprou) AS sessoes_com_compra
FROM sessoes
WHERE dispositivo IN ('desktop', 'mobile', 'tablet')
GROUP BY dispositivo

UNION ALL

SELECT
  'canal',
  CASE WHEN canal IN ('organic', '(none)', 'referral', 'cpc') THEN canal ELSE '(mascarado ou vazio)' END,
  COUNT(*),
  COUNTIF(comprou)
FROM sessoes
GROUP BY 2
)

-- Taxa e intervalo de 95% de cada grupo (aproximação normal), para o painel.
-- grupo_pt: o rótulo em português que o painel mostra.
SELECT
  *,
  CASE grupo
    WHEN 'organic' THEN 'Busca orgânica'
    WHEN '(none)' THEN 'Acesso direto'
    WHEN 'referral' THEN 'Indicação'
    WHEN 'cpc' THEN 'Mídia paga'
    WHEN 'desktop' THEN 'Computador'
    WHEN 'mobile' THEN 'Celular'
    WHEN 'tablet' THEN 'Tablet'
    ELSE 'Mascarado ou vazio'
  END AS grupo_pt,
  ROUND(sessoes_com_compra / sessoes, 5) AS taxa,
  ROUND(sessoes_com_compra / sessoes - 1.96 * SQRT(sessoes_com_compra / sessoes * (1 - sessoes_com_compra / sessoes) / sessoes), 5) AS ic_baixo,
  ROUND(sessoes_com_compra / sessoes + 1.96 * SQRT(sessoes_com_compra / sessoes * (1 - sessoes_com_compra / sessoes) / sessoes), 5) AS ic_alto
FROM grupos
ORDER BY dimensao, sessoes DESC
