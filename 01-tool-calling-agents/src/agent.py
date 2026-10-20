"""Agent loop: call the LLM with all tools, run the ones it decides to call, send the results back,
repeat until it answers.

CLI:  make ask q="Koľko je 17 * 23 / 4?"   (or: uv run src/agent.py "...")
"""

import json
import os
import sys

from dotenv import load_dotenv
from openai import OpenAI

from tools import TOOLS

load_dotenv()  # CLI on the host; in Docker the variables come from docker-compose.yml

# LiteLLM proxy speaks the OpenAI format for every provider, so one client covers them all.
client = OpenAI(
    base_url=os.getenv("LITELLM_BASE_URL", "http://localhost:4000"),
    api_key=os.environ["LITELLM_MASTER_KEY"],
)

MAX_STEPS = 5  # max LLM round-trips per question - caps cost if a model loops on tools
MAX_TOKENS = 1000

SYSTEM_PROMPT = (
    "Si asistent na recepty a výpočty. Odpovedáš po slovensky. "
    "Pomáhaš IBA s dvoma oblasťami: recepty a varenie, a matematické výpočty. "
    "Máš k dispozícii nástroje a sám sa rozhodneš, ktorý použiť: "
    "na každý výpočet použi calculate, na prepočet ingrediencií na iný počet porcií použi scale_recipe. "
    "Nikdy nepočítaj z hlavy. "
    "Na akúkoľvek inú tému (počasie, politika, programovanie...) slušne odpovedz, "
    "že sa vyznáš iba v receptoch a výpočtoch, a nič ďalšie k tej téme nepíš."
)
HINT = "Napr.: Koľko je (17 * 23) / 4? Alebo: Recept na palacinky pre 2 osoby, prepočítaj na 6."


def call_tool(name: str, raw_args: str):
    if name not in TOOLS:
        return {"error": f"unknown tool: {name}"}
    try:
        return TOOLS[name]["fn"](**json.loads(raw_args or "{}"))
    except Exception as e:  # the error goes back to the LLM, which can fix its call
        return {"error": str(e)}


def run_agent(model: str, history: list[dict]) -> tuple[str, list[dict]]:
    """history = [{"role": "user"|"assistant", "content": "..."}]. Returns (reply, tool trace)."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}, *history]
    tools = [t["schema"] for t in TOOLS.values()]
    trace = []

    for _ in range(MAX_STEPS):
        msg = client.chat.completions.create(
            model=model,
            messages=messages,
            tools=tools,
            tool_choice="auto",  # the LLM decides which tool to call, if any
            max_tokens=MAX_TOKENS,
        ).choices[0].message

        if not msg.tool_calls:  # the LLM answered - done
            return msg.content or "", trace

        messages.append(msg.model_dump(exclude_none=True))  # the assistant's tool request
        for call in msg.tool_calls:
            result = call_tool(call.function.name, call.function.arguments)
            trace.append({"name": call.function.name, "args": call.function.arguments, "result": result})
            messages.append({
                "role": "tool",
                "tool_call_id": call.id,
                "content": json.dumps(result, ensure_ascii=False),
            })

    return "Prepáč, nepodarilo sa mi dokončiť odpoveď (príliš veľa krokov).", trace


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit('Použitie: uv run src/agent.py "otázka"   (model: MODEL=..., default anthropic)')
    reply, trace = run_agent(os.getenv("MODEL", "anthropic"), [{"role": "user", "content": sys.argv[1]}])
    for t in trace:
        print(f"🔧 {t['name']}({t['args']}) -> {json.dumps(t['result'], ensure_ascii=False)}")
    print(reply)
