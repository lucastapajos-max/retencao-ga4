# Especificação: clientes e retenção numa loja online (projeto 2)

Versão 1, 16/11/2026.

## 1. Pergunta

Quais clientes valem a pena reter, e onde a loja perde os outros?

Ela se divide em quatro perguntas menores, uma por análise:

| # | Pergunta | Análise |
|---|---|---|
| P1 | Em que etapa do caminho até a compra mais gente desiste? | Funil |
| P2 | Quem compra volta a comprar? Quanto tempo depois? | Coortes de retenção |
| P3 | Quem são os clientes mais valiosos, e quantos estão sumindo? | Segmentação RFM |
| P4 | A taxa de conversão muda de verdade entre dispositivos ou canais, ou é acaso? | Teste de duas proporções |

## 2. Dados

- **Tabela:** `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`, exportação de eventos do GA4 da Google Merchandise Store, de 01/11/2020 a 31/01/2021 (três meses).
- **Fonte:** documentação oficial do Google Analytics ("BigQuery sample dataset for Google Analytics ecommerce web implementation").
- **Limitações declaradas pela própria fonte:** os dados são mascarados; alguns campos trazem `<Other>`, `NULL` ou texto vazio, e a consistência interna é limitada. O projeto mostra quanto cada análise perde com isso, em vez de esconder.
- **Campos usados:** `event_date`, `event_timestamp`, `event_name`, `user_pseudo_id`, `ga_session_id` (em `event_params`), `device.category`, `traffic_source.medium` e `traffic_source.source` (origem do primeiro acesso do usuário), `geo.country`, `ecommerce.transaction_id`, `ecommerce.purchase_revenue_in_usd`.
- **Eventos do funil:** `session_start` → `view_item` → `add_to_cart` → `begin_checkout` → `purchase`. A Fase 0 confere se esses nomes existem e em que volume, antes de fechar o funil.

## 3. Métodos

### P1. Funil
- **Unidade:** sessão (`user_pseudo_id` + `ga_session_id`).
- Uma sessão conta numa etapa se tiver pelo menos um evento dela. As etapas não precisam estar em ordem, porque o GA4 não garante a ordem; isso fica dito no README.
- **Saída:** sessões por etapa, taxa de passagem entre etapas e a maior queda, no total e por dispositivo.

### P2. Coortes de retenção
- **Coorte:** semana da primeira compra (três meses dão só três coortes mensais, pouco para ler; por semana são cerca de 13).
- **Retenção:** a parcela da coorte que compra de novo na semana 1, 2, 3… depois da primeira compra.
- **Cuidado:** coortes do fim do período têm menos semanas de observação. A matriz mostra esses buracos como "sem dado", não como zero.

### P3. Segmentação RFM
- Só compradores (pelo menos um `purchase` com `transaction_id`).
- **R:** dias entre a última compra e 31/01/2021. **F:** número de compras distintas. **M:** receita total em USD.
- R e M em notas de 1 a 5 por quintil, calculadas pela posição (`RANK`), para empates ganharem a mesma nota; F em três faixas (1, 2, 3 ou mais compras), pela decisão da seção 8. Notas combinadas em segmentos nomeados (por exemplo Campeões, Fiéis, Em risco, Perdidos, Novos) por uma tabela de regras explícita no SQL.
- **Cuidado:** com três meses, muitos compradores têm uma compra só. A Fase 0 mede isso; se a frequência quase não variar, R e M carregam a segmentação, e o README diz isso.

### P4. Teste de duas proporções
- **Comparação principal:** taxa de conversão (sessões com `purchase` ÷ sessões) entre `mobile` e `desktop`. A comparação por canal entra se a Fase 0 mostrar volume suficiente fora de `<Other>`.
- **Teste:** z de duas proporções, com intervalo de confiança de 95% para a diferença e tamanho do efeito. O texto chama de "comparação observacional": não é um experimento A/B, porque ninguém sorteou os grupos.
- Feito em Python (SciPy) sobre o resultado agregado do SQL, com teste automatizado da função contra um caso calculado à mão.

## 4. Entregas

```
retencao-ga4/
  sql/
    00_perfil_dos_dados.sql      # Fase 0: volumes, nulos, <Other>, eventos existentes
    01_sessoes.sql               # base por sessão
    02_funil.sql                 # P1
    03_coortes.sql               # P2
    04_rfm.sql                   # P3
    05_conversao_por_grupo.sql   # entrada do P4
  analise/
    teste_proporcoes.py          # P4
    rodar.py                     # roda as consultas e salva os resultados em CSV
  resultados/                    # CSVs pequenos, versionados (o que o README cita)
  tests/test_teste_proporcoes.py
  docs/especificacao.md
  README.md
```

### Painel em Looker Studio (link público)
1. **Visão geral:** sessões, compradores, receita e taxa de conversão do período, com o aviso sobre dados mascarados.
2. **Funil:** barras por etapa, com filtro de dispositivo.
3. **Retenção:** mapa de calor das coortes semanais.
4. **Clientes (RFM):** tamanho e receita de cada segmento.
5. **Conversão por grupo:** taxas com intervalo de confiança e a conclusão do teste em uma frase.

## 5. Decisão técnica: o painel não depende de tabelas no sandbox

No sandbox do BigQuery, tabelas e views apagam sozinhas depois de 60 dias (documentação do BigQuery, "Try BigQuery using the sandbox"). Um painel ligado a tabelas salvas pararia de funcionar.

**Decisão:** cada fonte do Looker Studio é uma **consulta personalizada** sobre a tabela pública. Nada fica salvo no projeto do Lucas. A Fase 0 mede quantos bytes cada consulta lê, para confirmar que as atualizações do painel cabem na cota gratuita.

**Alternativa, se a cota apertar:** ativar a cobrança no projeto (o nível gratuito continua valendo) para tirar a expiração e salvar tabelas resumidas. Isso só acontece com o ok do Lucas, porque envolve cadastrar um meio de pagamento, que é ele quem faz.

## 6. Fases

| Fase | O que sai | Pronto quando |
|---|---|---|
| 0. Acesso e perfil | Projeto no Google Cloud (Lucas entra), `00_perfil_dos_dados.sql` rodado | Volumes, eventos e campos mascarados conhecidos; bytes lidos por consulta anotados |
| 1. SQL das análises | `01` a `05` rodando, CSVs em `resultados/` | Cada pergunta P1 a P4 tem um número com origem |
| 2. Teste estatístico | `teste_proporcoes.py` e o teste dele | pytest passa; conclusão escrita em uma frase |
| 3. Painel | Looker Studio com as 5 páginas e link público | Abre sem login, nas larguras de computador e celular |
| 4. Publicação | Repositório, README com prints, bloco no portfólio | humanizer-pt e reviewer-pt no README; rodada de design no portfólio |

## 7. Critérios de pronto

- Todo número no README e no painel sai de uma consulta do repositório, e o README diz qual.
- O README diz o que os dados mascarados impedem de concluir.
- Nenhum dado inventado ou simulado.
- O painel abre por link público, sem login.
- Os textos públicos passam por humanizer-pt e reviewer-pt.

## 8. Decisões da Fase 0 (16/11/2026)

Resultado de `sql/00_perfil_dos_dados.sql` em [resultados/00_perfil.csv](../resultados/00_perfil.csv). A consulta leu 1,01 GB, então cada consulta do painel cabe com folga na cota gratuita de 1 TB por mês.

- **Volume:** 4.295.584 eventos, 270.154 usuários, 360.129 sessões e 3.713 compradores. Todos os eventos do funil existem.
- **Canal entra no P4, sem os mascarados.** `<Other>` e `(data deleted)` somam 21,1% das contagens por canal. Ficam quatro canais legíveis: organic, (none) (acesso direto), referral e cpc. O README mostra a parcela excluída.
- **F do RFM em três faixas, não em quintis.** 88,1% dos compradores (3.273 de 3.713) compraram uma vez só nos três meses. Quintis de frequência não separariam ninguém, então F vira 1 compra, 2 compras e 3 ou mais; R e M seguem em quintis.
- **Retenção vai ser baixa e isso é resultado, não defeito.** Só 440 compradores voltaram a comprar. As coortes semanais mostram isso com o tamanho de cada coorte à vista.
- **Dispositivo serve bem ao P4:** 158.917 usuários no computador e 109.195 no celular.
- **Em aberto:** nome final do repositório.
