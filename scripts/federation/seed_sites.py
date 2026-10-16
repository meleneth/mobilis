from sqlalchemy import select

from service_sites.database import get_engine, get_session
from service_sites.models import Base, SiteRecord


Base.metadata.create_all(get_engine())
with get_session() as session:
    if session.scalar(select(SiteRecord).where(SiteRecord.id == 1)) is None:
        session.add(SiteRecord(id=1, name="North"))
    if session.scalar(select(SiteRecord).where(SiteRecord.id == 2)) is None:
        session.add(SiteRecord(id=2, name="South"))
    session.commit()
