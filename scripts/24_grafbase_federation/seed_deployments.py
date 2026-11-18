from sqlalchemy import select

from service_deployments.database import get_engine, get_session
from service_deployments.models import Base, DeploymentRecord


Base.metadata.create_all(get_engine())
with get_session() as session:
    if session.scalar(select(DeploymentRecord).where(DeploymentRecord.id == 1)) is None:
        session.add(DeploymentRecord(id=1, site_id=1, status="active"))
    if session.scalar(select(DeploymentRecord).where(DeploymentRecord.id == 2)) is None:
        session.add(DeploymentRecord(id=2, site_id=2, status="pending"))
    session.commit()
