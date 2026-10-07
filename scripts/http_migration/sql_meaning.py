"""Fail-closed SQL comparison for the demo's single-table item contract.

This is deliberately bounded: unsupported forms are drift, never silently
accepted. SQLGlot supplies a PostgreSQL AST; driver spelling is not meaning.
"""
from sqlglot import exp, parse
from sqlglot.optimizer.normalize_identifiers import normalize_identifiers
from sqlglot.optimizer.qualify import qualify
import re

SCHEMA = {"items": {"id": "INT", "name": "VARCHAR"}}


def is_control_sql(statement):
    # Transaction transport and the deliberate writer identity are not item SQL.
    # Every other statement, even one naming another table, requires comparison.
    return re.fullmatch(r"\s*(?:(?:BEGIN|COMMIT|ROLLBACK)|SET\s+LOCAL\s+application_name\s*=\s*'(?:legacy|candidate)')\s*;?\s*",
                        statement, flags=re.IGNORECASE) is not None


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def sql_meaning(statement, parameters):
    try:
        statements = parse(statement, read="postgres")
        require(len(statements) == 1 and statements[0] is not None, "expected one SQL statement")
        tree = normalize_identifiers(statements[0], dialect="postgres")
        used = set()

        def bind(node):
            if isinstance(node, exp.Placeholder):
                key = node.this.name if isinstance(node.this, exp.Identifier) else node.this
                require(isinstance(parameters, dict) and key in parameters, "missing named SQL binding")
            elif isinstance(node, exp.Parameter):
                require(isinstance(node.this, exp.Literal) and node.this.is_int,
                        "unsupported SQL parameter")
                key = int(node.this.this) - 1
                require(isinstance(parameters, list) and 0 <= key < len(parameters), "missing positional SQL binding")
            else:
                return node
            used.add(key)
            value = parameters[key]
            require(type(value) in (int, str), "unsupported SQL binding type")
            return exp.convert(value)

        tree = tree.transform(bind)
        require(used == (set(parameters) if isinstance(parameters, dict) else set(range(len(parameters)))),
                "unused SQL bindings")
        if isinstance(tree, exp.Select):
            tables = list(tree.find_all(exp.Table))
            require(len(tables) == 1 and tables[0].name == "items" and not tables[0].db and not tables[0].catalog,
                    "unsupported SELECT table")
            require(len(list(tree.find_all(exp.Select))) == 1 and not tree.args.get("joins")
                    and not tree.args.get("with"), "unsupported SELECT scope")
            # Resolve harmless table qualifications/aliases with the actual schema.
            tree = qualify(tree, dialect="postgres", schema=SCHEMA)
            table = next(tree.find_all(exp.Table))
            alias = table.alias_or_name
            projections = {node.alias: node.this for node in tree.expressions if isinstance(node, exp.Alias)}
            if tree.args.get("order"):
                for column in list(tree.args["order"].find_all(exp.Column)):
                    if not column.table and column.name in projections:
                        column.replace(projections[column.name].copy())
            for column in tree.find_all(exp.Column):
                if column.table == alias:
                    column.set("table", exp.to_identifier("items", quoted=True))
            table.set("alias", exp.TableAlias(this=exp.to_identifier("items", quoted=True)))
            for ordered in tree.find_all(exp.Ordered):
                if ordered.args.get("desc") is False:
                    ordered.set("desc", None)
            return {"operation": "select", "sql": tree.sql(dialect="postgres", comments=False)}
        require(isinstance(tree, exp.Insert), "unsupported SQL operation")
        require(all(not value for key, value in tree.args.items() if key not in ("this", "expression")),
                "unsupported INSERT clause")
        target, rows = tree.this, tree.expression
        require(isinstance(target, exp.Schema) and isinstance(target.this, exp.Table), "unsupported INSERT target")
        table = target.this
        require(table.name == "items" and not table.db and not table.catalog and not table.args.get("alias"),
                "unsupported INSERT table")
        require(all(not value for key, value in table.args.items() if key != "this"),
                "unsupported INSERT table modifier")
        columns = [column.name for column in target.expressions]
        require(len(columns) == len(set(columns)) and set(columns) == {"id", "name"}, "INSERT column drift")
        require(isinstance(rows, exp.Values) and len(rows.expressions) == 1, "unsupported INSERT rows")
        values = rows.expressions[0].expressions
        require(len(values) == len(columns), "INSERT value count drift")
        result = {}
        for column, node in zip(columns, values):
            # SQLAlchemy adds these schema-preserving parameter casts. Other
            # casts (including VARCHAR lengths) are retained as unsupported drift.
            if isinstance(node, exp.Cast):
                allowed = "INT" if column == "id" else "VARCHAR"
                require(node.args["to"].sql(dialect="postgres") == allowed, "INSERT cast drift")
                node = node.this
            require(isinstance(node, exp.Literal), "unsupported INSERT expression")
            require(node.is_int if column == "id" else node.is_string, "INSERT value type drift")
            result[column] = int(node.this) if column == "id" else node.this
        return {"operation": "insert", "table": "items", "values": result}
    except AssertionError:
        raise
    except Exception as error:
        raise AssertionError(f"unsupported SQL evidence: {statement!r}: {error}") from error
