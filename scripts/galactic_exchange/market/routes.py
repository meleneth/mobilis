import os

import redis
from fastapi import HTTPException
from sqlalchemy import text

from .database import get_engine


def register(app):
    @app.get("/markets")
    def markets():
        with get_engine().connect() as connection:
            rows = connection.execute(text("SELECT commodity, price_cents, volume, trade_count FROM market_state ORDER BY commodity"))
            return [dict(row._mapping) for row in rows]

    @app.get("/leaderboard")
    def leaderboard():
        state = markets()
        try:
            cache = redis.from_url(os.environ["LEADERBOARD_URL"], socket_timeout=2)
            cache.zadd("exchange:volume", {item["commodity"]: item["volume"] for item in state})
            return [{"commodity": name.decode(), "volume": int(score)}
                    for name, score in cache.zrevrange("exchange:volume", 0, -1, withscores=True)]
        except redis.RedisError as error:
            raise HTTPException(status_code=503, detail="leaderboard cache unavailable") from error
