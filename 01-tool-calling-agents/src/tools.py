"""Tools the agents can call. Each tool = a plain Python function + its JSON schema for the LLM."""

import ast
import math
import operator

_OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
    ast.USub: operator.neg,
    ast.UAdd: operator.pos,
}
_FUNCS = {"sqrt": math.sqrt, "abs": abs, "round": round}
_CONSTS = {"pi": math.pi, "e": math.e}


def calculate(expression: str) -> dict:
    """Safely evaluate an arithmetic expression. No eval(): only whitelisted AST nodes."""
    if len(expression) > 200:
        raise ValueError("expression too long")

    def ev(node):
        match node:
            case ast.Constant(value=int() | float() as v) if not isinstance(v, bool):
                return v
            case ast.Name(id=name) if name in _CONSTS:
                return _CONSTS[name]
            case ast.UnaryOp(op, operand) if type(op) in _OPS:
                return _OPS[type(op)](ev(operand))
            case ast.BinOp(left, op, right) if type(op) in _OPS:
                a, b = ev(left), ev(right)
                if isinstance(op, ast.Pow) and abs(b) > 100:
                    raise ValueError("exponent too large")
                return _OPS[type(op)](a, b)
            case ast.Call(func=ast.Name(id=name), args=args, keywords=[]) if name in _FUNCS:
                return _FUNCS[name](*map(ev, args))
        raise ValueError(f"unsupported expression: {ast.unparse(node)}")

    return {"expression": expression, "result": ev(ast.parse(expression, mode="eval").body)}


def scale_recipe(ingredients: list[dict], servings_from: int, servings_to: int) -> dict:
    """Recalculate ingredient amounts for a different number of servings."""
    if servings_from <= 0 or servings_to <= 0:
        raise ValueError("servings must be positive")
    k = servings_to / servings_from
    return {
        "servings": servings_to,
        "ingredients": [{**i, "amount": round(i["amount"] * k, 2)} for i in ingredients],
    }


TOOLS = {
    "calculate": {
        "fn": calculate,
        "schema": {
            "type": "function",
            "function": {
                "name": "calculate",
                "description": "Evaluate an arithmetic expression. Supports + - * / // % **, "
                "parentheses, sqrt(), abs(), round(), pi, e. Example: '(17 * 23) / 4'.",
                "parameters": {
                    "type": "object",
                    "properties": {"expression": {"type": "string", "description": "Python-style arithmetic expression"}},
                    "required": ["expression"],
                },
            },
        },
    },
    "scale_recipe": {
        "fn": scale_recipe,
        "schema": {
            "type": "function",
            "function": {
                "name": "scale_recipe",
                "description": "Recalculate recipe ingredient amounts from one number of servings to another.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "ingredients": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string"},
                                    "amount": {"type": "number"},
                                    "unit": {"type": "string"},
                                },
                                "required": ["name", "amount", "unit"],
                            },
                        },
                        "servings_from": {"type": "integer", "description": "Servings the recipe is written for"},
                        "servings_to": {"type": "integer", "description": "Servings wanted"},
                    },
                    "required": ["ingredients", "servings_from", "servings_to"],
                },
            },
        },
    },
}


if __name__ == "__main__":  # self-check: make test
    assert calculate("(17 * 23) / 4")["result"] == 97.75
    assert calculate("sqrt(16) + 2**3 - -1")["result"] == 13
    assert calculate("round(pi, 2)")["result"] == 3.14
    for bad in ["__import__('os')", "2 ** 1000", "open('x')", "True + 1", "x"]:
        try:
            calculate(bad)
            raise AssertionError(f"should reject: {bad}")
        except ValueError:
            pass
    scaled = scale_recipe([{"name": "múka", "amount": 300, "unit": "g"}], 4, 6)
    assert scaled["ingredients"][0]["amount"] == 450
    print("tools OK")
