-- P1. Funil: em que etapa do caminho até a compra mais gente desiste?
-- Unidade: sessão (user_pseudo_id + ga_session_id). A sessão conta numa etapa se teve pelo
-- menos um evento dela; o GA4 não garante a ordem dos eventos, então as etapas não são
-- exigidas em sequência. Saída em formato longo, pronta para o Looker Studio.

WITH eventos AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS sessao,
    device.category AS dispositivo,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
sessoes AS (
  SELECT
    user_pseudo_id,
    sessao,
    ANY_VALUE(dispositivo) AS dispositivo,
    LOGICAL_OR(event_name = 'view_item') AS viu_produto,
    LOGICAL_OR(event_name = 'add_to_cart') AS pos_no_carrinho,
    LOGICAL_OR(event_name = 'begin_checkout') AS iniciou_checkout,
    LOGICAL_OR(event_name = 'purchase') AS comprou
  FROM eventos
  WHERE sessao IS NOT NULL
  GROUP BY user_pseudo_id, sessao
),
contagem AS (
  SELECT
    dispositivo,  -- NULL = linha do total do ROLLUP (o WHERE já tirou os NULL reais)
    COUNT(*) AS sessoes,
    COUNTIF(viu_produto) AS viu_produto,
    COUNTIF(pos_no_carrinho) AS pos_no_carrinho,
    COUNTIF(iniciou_checkout) AS iniciou_checkout,
    COUNTIF(comprou) AS comprou
  FROM sessoes
  WHERE dispositivo IN ('desktop', 'mobile', 'tablet')
  GROUP BY ROLLUP(dispositivo)
)

SELECT IFNULL(dispositivo, 'todos') AS dispositivo, etapa, ordem, sessoes_na_etapa,
  ROUND(SAFE_DIVIDE(sessoes_na_etapa, LAG(sessoes_na_etapa) OVER (PARTITION BY dispositivo ORDER BY ordem)), 4) AS passagem_da_etapa_anterior,
  ROUND(SAFE_DIVIDE(sessoes_na_etapa, FIRST_VALUE(sessoes_na_etapa) OVER (PARTITION BY dispositivo ORDER BY ordem)), 4) AS parcela_das_sessoes
FROM contagem,
UNNEST([
  STRUCT('1. Sessão' AS etapa, 1 AS ordem, sessoes AS sessoes_na_etapa),
  STRUCT('2. Viu produto', 2, viu_produto),
  STRUCT('3. Pôs no carrinho', 3, pos_no_carrinho),
  STRUCT('4. Iniciou checkout', 4, iniciou_checkout),
  STRUCT('5. Comprou', 5, comprou)
])
ORDER BY dispositivo, ordem
