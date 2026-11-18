#!/usr/bin/env python3
"""Run inside the generated sites container after both databases are seeded."""
import json
from uuid import uuid4
from urllib.request import Request, urlopen


def query(url, document):
    request = Request(url, data=json.dumps({"query": document}).encode(),
                      headers={"Content-Type": "application/json"}, method="POST")
    with urlopen(request, timeout=15) as response:
        return json.load(response)


gateway = "http://gateway:5000/graphql"
result = query(gateway, "{ sites { id name deployments { id status } } }")
assert "errors" not in result, result
assert [site for site in result["data"]["sites"] if site["id"] in ("1", "2")] == [
    {"id": "1", "name": "North", "deployments": [{"id": "1", "status": "active"}]},
    {"id": "2", "name": "South", "deployments": [{"id": "2", "status": "pending"}]},
], result

subgraph = query("http://deployments:8000/graphql", """
  query { _entities(representations: [{__typename: "Site", id: "broken"}]) { ... on Site { id } } }
""")
assert subgraph.get("errors"), subgraph
new_name = "West-" + uuid4().hex[:8]
created = query(gateway, f'mutation {{ createSite(name: "{new_name}") {{ id name }} }}')
assert "errors" not in created, created
assert created["data"]["createSite"]["name"] == new_name, created
print("Federation composed and resolved Site -> Deployment across two SQL-backed subgraphs")
