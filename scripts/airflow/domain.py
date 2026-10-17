"""Validated records and deterministic business rules."""
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from contextlib import contextmanager
from opentelemetry import context as otel_context
from opentelemetry import trace
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator


class InvalidRecord(ValueError):
    pass


@contextmanager
def _operation(name):
    token = None
    try:
        from airflow.sdk import get_current_context
        carrier = get_current_context()["ti"].context_carrier
        if carrier and not trace.get_current_span().get_span_context().is_valid:
            parent = TraceContextTextMapPropagator().extract(carrier)
            if trace.get_current_span(parent).get_span_context().is_valid:
                token = otel_context.attach(parent)
    except (ImportError, RuntimeError, KeyError, AttributeError):
        pass
    try:
        with trace.get_tracer(__name__).start_as_current_span(name) as span:
            yield span
    finally:
        if token is not None:
            otel_context.detach(token)


@dataclass(frozen=True)
class Sale:
    record_id: int
    region: str
    amount: Decimal


def normalize(raw: dict) -> Sale:
    with _operation("domain.normalize_sale") as span:
        return _normalize(raw, span)


def _normalize(raw: dict, span) -> Sale:
    try:
        record_id = int(raw["id"])
        region = str(raw["region"]).strip().upper()
        amount = Decimal(str(raw["amount"])).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except (KeyError, ValueError, ArithmeticError) as error:
        raise InvalidRecord("invalid sale") from error
    if record_id <= 0 or not region.isalpha() or len(region) > 16 or amount < 0:
        raise InvalidRecord("invalid sale fields")
    span.set_attribute("demo.record_id", record_id)
    span.set_attribute("demo.region", region)
    return Sale(record_id, region, amount)


def summarize(sales: list[Sale]) -> dict[str, tuple[int, Decimal]]:
    with _operation("domain.summarize_sales") as span:
        span.set_attribute("demo.record_count", len(sales))
        result = {}
        for sale in sales:
            count, total = result.get(sale.region, (0, Decimal("0.00")))
            result[sale.region] = (count + 1, total + sale.amount)
        return dict(sorted(result.items()))
