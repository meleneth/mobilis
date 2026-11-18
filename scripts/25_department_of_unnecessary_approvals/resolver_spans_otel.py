"""Named resolver spans inherit the active FastAPI/Grafbase HTTP context."""
from functools import wraps
from opentelemetry import trace


def traced_resolver(name):
    def decorate(resolver):
        @wraps(resolver)
        async def wrapped(*args, **kwargs):
            with trace.get_tracer("dua.resolvers").start_as_current_span(name):
                return await resolver(*args, **kwargs)
        return wrapped
    return decorate
