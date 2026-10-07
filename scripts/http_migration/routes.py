"""Demo-owned item contract and committed semantic effect evidence."""
import json
import re
from fastapi import Request
from fastapi.responses import JSONResponse
from opentelemetry import trace
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError, SQLAlchemyError
from .database import Session
from .models import Item


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
    def items():
        try:
            with Session() as session:
                return [{"id": item.id, "name": item.name}
                        for item in session.scalars(select(Item).order_by(Item.id))]
        except SQLAlchemyError:
            return JSONResponse({"error": "database unavailable"}, status_code=503)

    @app.post("/items")
    async def create(request: Request):
        try:
            value = json.loads((await request.body()).decode("utf-8"))
        except (ValueError, UnicodeError):
            value = None
        if not validate(value):
            return JSONResponse({"error": "invalid item"}, status_code=400)
        effect = {"operation": "insert", "table": "items", "values": value}
        with trace.get_tracer("items").start_as_current_span("items.write") as span:
            with Session() as session:
                try:
                    session.execute(text("SET LOCAL application_name = 'legacy'"))
                    session.add(Item(**value))
                    session.commit()
                except IntegrityError:
                    session.rollback()
                    return JSONResponse({"error": "item exists"}, status_code=409)
                except SQLAlchemyError:
                    session.rollback()
                    return JSONResponse({"error": "database unavailable"}, status_code=503)
            # Emit actual only after the transaction commits.
            span.set_attributes({"demo.write.mode": "actual", "demo.request.shadow": request.headers.get("x-mobilis-shadow") == "true",
                                 "demo.write.committed": True, "db.operation.name": "INSERT",
                                 "db.collection.name": "items", "demo.write.effect": json.dumps(effect, sort_keys=True)})
        return JSONResponse(value, status_code=201)
