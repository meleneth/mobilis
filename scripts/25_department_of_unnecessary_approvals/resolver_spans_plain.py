"""Resolver decorator for projects without a collector connection."""


def traced_resolver(_name):
    return lambda resolver: resolver
