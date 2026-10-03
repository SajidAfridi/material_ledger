"""Inspect the effective migration-defined notification producers.

This is deliberately a static inventory, not a SQL interpreter. It projects the
last CREATE/REPLACE definition, DROP and RENAME for each function signature, then
reads the event_code expression of actual v1_notifications INSERT statements.
Unsupported dynamic event expressions fail the check rather than disappearing
from coverage. Historical one-time backfills and superseded bodies are excluded.
"""

import re
from pathlib import Path


CREATE = re.compile(
    r"create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*"
    r"\((.*?)\)(?:(?!\bcreate\b).)*?\bas\s*(\$\w*\$)(.*?)\3",
    re.IGNORECASE | re.DOTALL,
)
DROP = re.compile(
    r"drop\s+function\s+(?:if\s+exists\s+)?public\.(\w+)\s*\((.*?)\)",
    re.IGNORECASE | re.DOTALL,
)
RENAME = re.compile(
    r"alter\s+function\s+public\.(\w+)\s*\((.*?)\)\s+rename\s+to\s+(\w+)",
    re.IGNORECASE | re.DOTALL,
)
INSERT = re.compile(r"insert\s+into\s+public\.v1_notifications\s*\(", re.IGNORECASE)
LITERAL = re.compile(r"'((?:[^']|'')*)'")


def without_comments(source):
    """Keep SQL strings intact while excluding commented-out producer DDL."""
    result, index = [], 0
    while index < len(source):
        if source[index] in "'\"":
            quote = source[index]
            start = index
            index += 1
            while index < len(source):
                if source[index] == quote:
                    index += 1
                    if index < len(source) and source[index] == quote:
                        index += 1
                        continue
                    break
                index += 1
            result.append(source[start:index])
        elif source.startswith("--", index):
            end = source.find("\n", index)
            if end == -1:
                end = len(source)
            result.append(" " * (end - index))
            index = end
        elif source.startswith("/*", index):
            start, depth = index, 1
            index += 2
            while index < len(source) and depth:
                if source.startswith("/*", index):
                    depth += 1
                    index += 2
                elif source.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            result.append("".join("\n" if char == "\n" else " " for char in source[start:index]))
        else:
            result.append(source[index])
            index += 1
    return "".join(result)


def split_expressions(value):
    """Split SQL lists without splitting function calls, CASE or string literals."""
    parts, start, depth, case_depth, index = [], 0, 0, 0, 0
    while index < len(value):
        char = value[index]
        if char == "'":
            index += 1
            while index < len(value):
                if value[index] == "'":
                    if index + 1 < len(value) and value[index + 1] == "'":
                        index += 2
                        continue
                    break
                index += 1
        elif char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif char.isalpha() or char == "_":
            word = re.match(r"\w+", value[index:])[0]
            if word.lower() == "case":
                case_depth += 1
            elif word.lower() == "end" and case_depth:
                case_depth -= 1
            index += len(word) - 1
        elif char == "," and depth == 0 and case_depth == 0:
            parts.append(value[start:index].strip())
            start = index + 1
        index += 1
    parts.append(value[start:].strip())
    return parts


def projection_list(value, values=False):
    depth, case_depth, index = 0, 0, 0
    while index < len(value):
        char = value[index]
        if char == "'":
            index += 1
            while index < len(value):
                if value[index] == "'":
                    if index + 1 < len(value) and value[index + 1] == "'":
                        index += 2
                        continue
                    break
                index += 1
        elif char in "([":
            depth += 1
        elif char in ")]":
            if values and char == ")" and depth == 0:
                return value[:index]
            depth -= 1
        elif char.isalpha() or char == "_":
            word = re.match(r"\w+", value[index:])[0]
            if word.lower() == "case":
                case_depth += 1
            elif word.lower() == "end" and case_depth:
                case_depth -= 1
            elif word.lower() == "from" and depth == 0 and case_depth == 0:
                return value[:index]
            index += len(word) - 1
        index += 1
    return value


def signature(name, parameters, declaration=False):
    types = []
    for parameter in split_expressions(parameters):
        if not parameter:
            continue
        parameter = re.split(r"\s+default\s+|\s*=\s*", parameter, flags=re.IGNORECASE)[0]
        parameter = re.sub(r"^\s*(?:inout|in|variadic)\s+", "", parameter, flags=re.IGNORECASE)
        if re.match(r"\s*out\s+", parameter, re.IGNORECASE):
            continue
        # Repository declarations name all notification producer parameters.
        if declaration and len(parameter.split()) > 1:
            parameter = parameter.split(None, 1)[1]
        types.append(re.sub(r"\s+", " ", parameter.strip().lower()))
    return name.lower(), tuple(types)


def active_functions(migrations):
    functions = {}
    for path in sorted(migrations):
        source = without_comments(path.read_text())
        creates = list(CREATE.finditer(source))
        # Ignore apparent DDL inside function bodies, such as maintenance RPCs.
        inside = lambda offset: any(m.start(4) <= offset < m.end(4) for m in creates)
        operations = [(m.start(), "create", m) for m in creates]
        operations += [(m.start(), "drop", m) for m in DROP.finditer(source) if not inside(m.start())]
        operations += [(m.start(), "rename", m) for m in RENAME.finditer(source) if not inside(m.start())]
        for _, operation, match in sorted(operations, key=lambda item: item[0]):
            key = signature(match[1], match[2], declaration=operation == "create")
            if operation == "create":
                functions[key] = (path.name, match[4])
            elif operation == "drop":
                functions.pop(key, None)
            elif key in functions:
                functions[(match[3].lower(), key[1])] = functions.pop(key)
    return functions


def event_expressions(body):
    for match in INSERT.finditer(body):
        end_columns = body.index(")", match.end())
        columns = [column.strip().lower() for column in body[match.end():end_columns].split(",")]
        if "event_code" not in columns:
            raise ValueError("Notification INSERT has no explicit event_code column")
        statement = body[end_columns + 1:body.index(";", end_columns)]
        values = re.match(r"\s*values\s*\((.*)", statement, re.IGNORECASE | re.DOTALL)
        select = re.match(r"\s*select\s+(?:distinct\s+)?(.*)", statement, re.IGNORECASE | re.DOTALL)
        if not values and not select:
            raise ValueError("Unsupported notification INSERT shape")
        expressions = split_expressions(projection_list((values or select)[1], values=bool(values)))
        yield expressions[columns.index("event_code")]


def literal_values(expression):
    # In CASE expressions, conditions can contain audit codes and entity names.
    # Only THEN/ELSE results are notification codes.
    if re.search(r"\bcase\b", expression, re.IGNORECASE):
        return set(re.findall(r"\b(?:then|else)\s+'([^']+)'", expression, re.IGNORECASE))
    return {match[1].replace("''", "'") for match in LITERAL.finditer(expression)}


def resolve_event(expression, body):
    expression = expression.strip()
    # Expanding a committed notification to another recipient introduces no code.
    if expression.lower() == "new.event_code":
        return set()
    concatenated = re.fullmatch(r"'([^']+)'\s*\|\|\s*(\w+)", expression)
    if concatenated:
        prefix, variable = concatenated.groups()
        allowed = re.search(rf"\b{variable}\s+not\s+in\s*\((.*?)\)", body, re.IGNORECASE | re.DOTALL)
        if not allowed:
            raise ValueError(f"Unbounded notification event suffix: {expression}")
        return {prefix + match[1] for match in LITERAL.finditer(allowed[1])}
    if re.fullmatch(r"\w+", expression):
        assignments = re.findall(rf"\b{expression}\s*:=\s*(.*?);", body, re.IGNORECASE | re.DOTALL)
        if not assignments:
            raise ValueError(f"Unresolved notification event variable: {expression}")
        return set().union(*(resolve_event(value, body) for value in assignments))
    if expression.lower() == "v_pair.event_code":
        # The Workforce bridge emits the first VALUES column in its event /
        # capability pairs. Read CASE result literals, not audit input codes.
        pair = re.search(r"for\s+v_pair\s+in\s+select.*?\(values(.*?)\)\s+as\s+x\(event_code", body, re.IGNORECASE | re.DOTALL)
        if not pair:
            raise ValueError("Unresolved notification event/capability pairs")
        return {code for code in literal_values(pair[1]) if code.startswith("workforce_")}
    values = literal_values(expression)
    if not values or any(not re.fullmatch(r"[a-z][a-z0-9_]+", value) for value in values):
        raise ValueError(f"Unsupported dynamic notification event: {expression}")
    return values


def inventory(migrations):
    producers = {}
    for (name, parameters), (path, body) in active_functions(migrations).items():
        for expression in event_expressions(body):
            try:
                codes = resolve_event(expression, body)
            except ValueError as error:
                raise ValueError(f"{path}: {name}({', '.join(parameters)}): {error}") from error
            for code in codes:
                producers.setdefault(code, set()).add(f"{path}:{name}")
    return producers


def validate_coverage(root, catalogue):
    producers = inventory((root / "supabase/migrations").glob("*.sql"))
    missing = sorted(set(producers) - set(catalogue))
    if missing:
        details = "\n".join(f"  {code}: {', '.join(sorted(producers[code]))}" for code in missing)
        raise SystemExit("Active SQL notification producers lack reviewed catalogue copy:\n" + details)
    print(f"Notification producer coverage verified: {len(producers)} active event codes")
    return producers
