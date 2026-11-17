import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "analise"))
import teste_proporcoes as tp  # noqa: E402


def test_duas_proporcoes_bate_com_conta_feita_a_mao():
    # 50/1000 x 30/1000: p agrupado 0,04; erro = raiz(0,04*0,96*2/1000) = 0,0087636;
    # z = 0,02 / 0,0087636 = 2,2822; p bicaudal = 0,0225.
    r = tp.duas_proporcoes(50, 1000, 30, 1000)
    assert r["z"] == pytest.approx(2.2822, abs=1e-3)
    assert r["p_valor"] == pytest.approx(0.0225, abs=5e-4)
    assert r["ic_baixo"] < r["diferenca"] < r["ic_alto"]


def test_grupos_iguais_nao_mostram_diferenca():
    r = tp.duas_proporcoes(40, 1000, 40, 1000)
    assert r["z"] == 0 and r["p_valor"] == pytest.approx(1.0)


def test_canais_usa_so_os_quatro_legiveis():
    t = pd.DataFrame({"grupo": ["organic", "(none)", "referral", "cpc", "(mascarado ou vazio)"],
                      "sessoes": [1000] * 5, "sessoes_com_compra": [10] * 4 + [999]})
    assert tp.canais(t)["p_valor"] == pytest.approx(1.0)  # o grupo mascarado, muito diferente, não entra
