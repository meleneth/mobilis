from decimal import Decimal
import pytest
from mobilis_domain import InvalidRecord, normalize, summarize


def test_normalization_and_aggregation():
    sales = [normalize({"id": 1, "region": " west ", "amount": "1.235"}),
             normalize({"id": 2, "region": "WEST", "amount": "2"})]
    assert sales[0].amount == Decimal("1.24")
    assert summarize(sales) == {"WEST": (2, Decimal("3.24"))}


def test_rejects_invalid_sale():
    with pytest.raises(InvalidRecord):
        normalize({"id": 0, "region": "west", "amount": "2"})
