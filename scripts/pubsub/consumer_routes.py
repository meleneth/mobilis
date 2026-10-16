import os
from fastapi import HTTPException
from pydantic import BaseModel
from .pubsub_client import pull


class ConsumeRequest(BaseModel):
    fail: bool = False


def register(app):
    @app.post("/consume")
    def consume(request: ConsumeRequest):
        subscription = os.environ["MOBILIS_PUBSUB_SUBSCRIPTIONS"]
        try:
            deliveries = pull(subscription, timeout=3)
            if not deliveries:
                return {"message": None}

            def handle(delivery):
                result = {"message_id": delivery.message_id,
                          "value": delivery.data.decode("utf-8"),
                          "delivery_attempt": delivery.delivery_attempt}
                if request.fail:
                    delivery.nack()
                    result["outcome"] = "nacked"
                else:
                    delivery.ack()
                    result["outcome"] = "acked"
                return result

            return {"message": deliveries[0].process(handle)}
        except Exception as error:
            raise HTTPException(status_code=503, detail="Pub/Sub subscriber unavailable") from error
