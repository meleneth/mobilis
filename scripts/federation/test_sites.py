from service_sites.graphql_schema import schema


def test_site_entity_and_mutation_are_in_the_federated_sdl():
    sdl = schema.as_str()
    assert 'type Site @key(fields: "id")' in sdl
    assert "createSite" in sdl
