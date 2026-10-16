#!/usr/bin/env python3
"""Run inside the generated sites container after both databases are seeded."""
import json
from urllib.request import Request, urlopen


def query(url, document):
    request = Request(url, data=json.dumps({"query": document}).encode(),
                      headers={"Content-Type": "application/json"}, method="POST")
    with urlopen(request, timeout=15) as response:
        return json.load(response)


gateway = "http://gateway:5000/graphql"
result = query(gateway, "{ sites { id name deployments { id status } } }")
assert "errors" not in result, result
assert result["data"]["sites"] == [
    {"id": "1", "name": "North", "deployments": [{"id": "1", "status": "active"}]},
    {"id": "2", "name": "South", "deployments": [{"id": "2", "status": "pending"}]},
], result

subgraph = query("http://deployments:8000/graphql", """
  query { _entities(representations: [{__typename: "Site", id: "broken"}]) { ... on Site { id } } }
""")
assert subgraph.get("errors"), subgraph
created = query(gateway, 'mutation { createSite(name: "West") { id name } }')
assert "errors" not in created, created
assert created["data"]["createSite"]["name"] == "West", created
print("Federation composed and resolved Site -> Deployment across two SQL-backed subgraphs")
