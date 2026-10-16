from service_deployments.graphql_schema import Site, schema


def test_reference_rejects_an_invalid_key():
    assert Site.resolve_reference("7").id == "7"
    try:
        Site.resolve_reference("invalid")
    except ValueError:
        pass
    else:
        raise AssertionError("broken federation key was accepted")
    assert "deployments" in schema.as_str()
