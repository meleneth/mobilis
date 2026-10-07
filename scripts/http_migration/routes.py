"""Demo-owned item contract and committed semantic effect evidence."""
import json
import re
from fastapi import Depends, Request
from fastapi.responses import JSONResponse
from opentelemetry import trace
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from .items import ItemStore, get_item_store, determine_effect
from . import items as item_logic


def validate(value):
    return (type(value) is dict and set(value) == {"id", "name"}
            and type(value["id"]) is int and 1 <= value["id"] <= 2147483647
            and type(value["name"]) is str
            and re.fullmatch(r"[A-Za-z0-9_-]{1,80}", value["name"]) is not None)


def register(app):
    @app.middleware("http")
    async def identify(request, call_next):
        trace.get_current_span().set_attribute("demo.request.shadow", request.headers.get("x-mobilis-shadow") == "true")
        response = await call_next(request)
        response.headers["X-Served-By"] = "legacy"
        return response

    @app.get("/items")
    def items(store: ItemStore = Depends(get_item_store)):
        try:
            return store.list_items()
        except SQLAlchemyError:
            return JSONResponse({"error": "database unavailable"}, status_code=503)

    @app.post("/items")
    async def create(request: Request, store: ItemStore = Depends(get_item_store)):
        try:
            value = json.loads((await request.body()).decode("utf-8"))
        except (ValueError, UnicodeError):
            value = None
        if not validate(value):
            return JSONResponse({"error": "invalid item"}, status_code=400)
        effect = determine_effect(value)
        with trace.get_tracer("items").start_as_current_span("items.write") as span:
            try:
                store.commit(effect)
            except IntegrityError:
                return JSONResponse({"error": "item exists"}, status_code=409)
            except SQLAlchemyError:
                return JSONResponse({"error": "database unavailable"}, status_code=503)
            # Evidence represents a completed transaction, never an attempted one.
            span.set_attributes(item_logic.effect_attributes(effect,
                shadow=request.headers.get("x-mobilis-shadow") == "true", committed=True))
        return JSONResponse(value, status_code=201)
