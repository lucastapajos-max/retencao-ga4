"""P4. A taxa de conversão muda de verdade entre grupos, ou é acaso?

Lê resultados/05_conversao_por_grupo.csv (saída de sql/05_conversao_por_grupo.sql) e faz:
- computador x celular: teste z de duas proporções, intervalo de 95% para a diferença e h de Cohen;
- os quatro canais legíveis juntos: qui-quadrado de independência (são quatro grupos, e
  comparar par a par inflaria a chance de falso positivo).

É uma comparação observacional, não um teste A/B: ninguém sorteou quem usaria cada
dispositivo ou chegaria por cada canal. Uma diferença aqui não prova causa.

Uso: python analise/teste_proporcoes.py
"""
from math import asin, sqrt
from pathlib import Path

import pandas as pd
from scipy.stats import chi2_contingency, norm

RAIZ = Path(__file__).resolve().parent.parent
ENTRADA = RAIZ / "resultados" / "05_conversao_por_grupo.csv"
SAIDA = RAIZ / "resultados" / "06_testes.csv"
CANAIS = ["organic", "(none)", "referral", "cpc"]


def duas_proporcoes(x1, n1, x2, n2, confianca=0.95):
    """Teste z (bicaudal) para p1 - p2, com intervalo de Wald e h de Cohen."""
    p1, p2 = x1 / n1, x2 / n2
    p = (x1 + x2) / (n1 + n2)
    z = (p1 - p2) / sqrt(p * (1 - p) * (1 / n1 + 1 / n2))
    erro = sqrt(p1 * (1 - p1) / n1 + p2 * (1 - p2) / n2)
    margem = norm.ppf(1 - (1 - confianca) / 2) * erro
    return {"p1": p1, "p2": p2, "diferenca": p1 - p2, "z": z, "p_valor": 2 * norm.sf(abs(z)),
            "ic_baixo": p1 - p2 - margem, "ic_alto": p1 - p2 + margem,
            "h_cohen": 2 * asin(sqrt(p1)) - 2 * asin(sqrt(p2))}


def canais(tabela):
    """Qui-quadrado nos canais legíveis: a conversão depende do canal?"""
    t = tabela.set_index("grupo").loc[CANAIS]
    contingencia = [t["sessoes_com_compra"], t["sessoes"] - t["sessoes_com_compra"]]
    qui2, p_valor, gl, _ = chi2_contingency(contingencia)
    return {"qui2": qui2, "graus_de_liberdade": gl, "p_valor": p_valor}


def main():
    d = pd.read_csv(ENTRADA)
    disp = d[d["dimensao"] == "dispositivo"].set_index("grupo")
    r = duas_proporcoes(disp.loc["mobile", "sessoes_com_compra"], disp.loc["mobile", "sessoes"],
                        disp.loc["desktop", "sessoes_com_compra"], disp.loc["desktop", "sessoes"])
    c = canais(d[d["dimensao"] == "canal"])
    linhas = [
        {"teste": "celular x computador (z de duas proporções)", **{k: v if k == "p_valor" else round(v, 6) for k, v in r.items()}},
        {"teste": "4 canais legíveis (qui-quadrado)", **{k: v if k == "p_valor" else round(v, 6) for k, v in c.items()}},
    ]
    pd.DataFrame(linhas).to_csv(SAIDA, index=False)
    print(f"Celular {r['p1']:.2%} x computador {r['p2']:.2%}: diferença de {r['diferenca'] * 100:+.2f} p.p. "
          f"(IC 95%: {r['ic_baixo'] * 100:+.2f} a {r['ic_alto'] * 100:+.2f}), p = {r['p_valor']:.4f}, "
          f"h = {r['h_cohen']:.3f}")
    print(f"Canais: qui2 = {c['qui2']:.1f}, gl = {c['graus_de_liberdade']}, p = {c['p_valor']:.2g}")


if __name__ == "__main__":
    main()
