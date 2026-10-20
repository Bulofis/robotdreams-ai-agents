# Tool Calling Agents

Webový chat s AI agentom, ktorý pomáha s receptami a výpočtami. Agent má k dispozícii nástroje a pri každej otázke sa sám rozhodne, či a ktorý z nich zavolá. Modely sa volajú cez [LiteLLM](https://docs.litellm.ai/) proxy, takže medzi poskytovateľmi (Anthropic, OpenAI, Google, OpenRouter) sa prepína jedným výberom v aplikácii.

| Nástroj | Použitie |
|:--|:--|
| `calculate` | matematické výpočty a slovné úlohy |
| `scale_recipe` | prepočet ingrediencií receptu na iný počet porcií |

Otázky mimo receptov a výpočtov agent odmietne.

## Požiadavky

| Požiadavka | Účel | Inštalácia |
|:--|:--|:--|
| Docker Desktop | beh aplikácie a LiteLLM proxy | [docker.com](https://www.docker.com/products/docker-desktop/) |
| make | spúšťanie príkazov projektu | macOS: `xcode-select --install` |
| uv | Python závislosti pre príkazový riadok | automaticky cez `make init` |
| API kľúč | prístup k modelom, stačí jeden poskytovateľ | [Anthropic](https://console.anthropic.com/) · [OpenAI](https://platform.openai.com/api-keys) · [Google AI Studio](https://aistudio.google.com/apikey) · [OpenRouter](https://openrouter.ai/keys) (aj bezplatné modely) |

## Inštalácia

```bash
make init
```

Príkaz nainštaluje závislosti, z `.env.example` vytvorí súbor `.env` (ak ešte neexistuje) a vygeneruje doň `LITELLM_MASTER_KEY` (ak chýba). Ostatné hodnoty v existujúcom `.env` nemení.

<details>
<summary>Ručne, bez <code>make init</code></summary>

```bash
uv sync                        # Python závislosti
cp .env.example .env           # konfigurácia
openssl rand -hex 16           # vygeneruje náhodný reťazec pre master kľúč
```

Vygenerovaný reťazec vlož do `.env` s prefixom `sk-`:

```bash
LITELLM_MASTER_KEY=sk-3f9a1c...
```

</details>

Do `.env` doplň API kľúče poskytovateľov, ktorých chceš používať:

| Premenná | Popis | Predvolená hodnota |
|:--|:--|:--|
| `LITELLM_MASTER_KEY` | kľúč LiteLLM proxy, vygeneruje `make init` | |
| `ANTHROPIC_API_KEY` | API kľúč Anthropic | |
| `ANTHROPIC_MODEL` | model Anthropic | `anthropic/claude-haiku-5-5` |
| `OPENAI_API_KEY` | API kľúč OpenAI | |
| `OPENAI_MODEL` | model OpenAI | `openai/gpt-5.4-nano` |
| `GEMINI_API_KEY` | API kľúč Google Gemini | |
| `GEMINI_MODEL` | model Gemini | `gemini/gemini-2.5-flash` |
| `OPENROUTER_API_KEY` | API kľúč OpenRouter | |
| `OPENROUTER_MODEL` | model OpenRouter | `openrouter/google/gemma-4-31b-it:free` |

Stačí jeden kľúč. Poskytovatelia bez kľúča sa v aplikácii zobrazia, ale vrátia chybu.

Názov modelu má tvar `<poskytovateľ>/<model>` podľa [LiteLLM](https://docs.litellm.ai/docs/providers). Model musí podporovať volanie nástrojov (tool calling).

## Spustenie

```bash
make build
```

Aplikácia beží na <http://localhost:8080>.

## Používanie

### Webový chat

1. V hornej lište vyber poskytovateľa modelu.
2. Napíš otázku a odošli ju klávesom **Enter** (nový riadok: **Shift+Enter**).
3. Volania nástrojov sa zobrazia nad odpoveďou agenta.

Agent si pamätá celú konverzáciu. **Nový chat** históriu vymaže.

### Príkazový riadok

Kým beží Docker, dá sa agentovi poslať otázka priamo z terminálu:

```bash
make ask q="Koľko je (17 * 23) / 4?"
make ask q="Recept na palacinky pre 2 osoby, prepočítaj na 6"
make ask model=gemini q="Ako dlho variť vajce natvrdo?"
```

| Parameter | Hodnoty | Predvolené |
|:--|:--|:--|
| `model` | `anthropic`, `openai`, `gemini`, `openrouter` | `anthropic` |

## Príkazy

| Príkaz | Popis |
|:--|:--|
| `make init` | nainštaluje závislosti a vytvorí `.env` |
| `make build` | postaví image a spustí aplikáciu |
| `make start` | spustí kontajnery |
| `make stop` | zastaví kontajnery |
| `make restart` | reštartuje kontajnery (po zmene kódu v `src/`) |
| `make rebuild` | zastaví, znova postaví a spustí (po zmene závislostí) |
| `make logs` | priebežné logy kontajnerov |
| `make clean` | odstráni kontajnery a lokálne image |
| `make test` | otestuje nástroje |
| `make ask q="..."` | otázka agentovi z terminálu |

## Konfigurácia

| Čo | Kde |
|:--|:--|
| API kľúče a modely | `.env` (šablóna: `.env.example`) |
| Poskytovatelia vo výbere | `docker/litellm/litellm_config.yaml` |
| Systémový prompt agenta | `SYSTEM_PROMPT` v `src/agent.py` |
| Nástroje | `src/tools.py` |
| Limity (max. tokenov, krokov, dĺžka histórie) | `MAX_TOKENS`, `MAX_STEPS` v `src/agent.py`, `MAX_HISTORY` v `src/server.py` |

**Zmena modelu:** uprav `*_MODEL` v `.env`, napr. `ANTHROPIC_MODEL=anthropic/claude-sonnet-5-5`, a spusti `make restart`.

**Pridanie poskytovateľa:** doplň záznam do `docker/litellm/litellm_config.yaml` s hodnotami `os.environ/<PREMENNÁ>`, premenné doplň do `.env` aj `.env.example` a spusti `make restart`. Nový poskytovateľ sa zobrazí vo výbere automaticky.

## Architektúra

```
prehliadač ──► app :8080 ──► litellm :4000 ──► Anthropic / OpenAI / Gemini / OpenRouter
               (Python)       (proxy)
```

| Služba | Popis |
|:--|:--|
| `app` | webový server a agent (`src/`). Agent pošle modelu otázku spolu so zoznamom všetkých nástrojov. Model sa rozhodne, či niektorý zavolá. Agent ho vykoná, vráti modelu výsledok a opakuje, kým model neodpovie. |
| `litellm` | proxy s jednotným OpenAI API pre všetkých poskytovateľov. API kľúče poskytovateľov má iba tento kontajner. |

Oba porty sú dostupné iba z `localhost`.

## Riešenie problémov

| Problém | Riešenie |
|:--|:--|
| `required variable LITELLM_MASTER_KEY is missing a value` | `LITELLM_MASTER_KEY` v `.env` je prázdny. Spusti `make init`, ktorý ho vygeneruje |
| „Nepodarilo sa načítať konfiguráciu“ v prehliadači | LiteLLM sa ešte spúšťa, počkaj pár sekúnd a obnov stránku. Stav: `make logs` |
| `AuthenticationError` / `Missing ... API Key` | vybraný poskytovateľ nemá kľúč v `.env`. Doplň ho a spusti `make restart` |
| `NotFoundError` / `model not found` | názov v `*_MODEL` neexistuje alebo ho poskytovateľ vypol. Oprav ho v `.env` a spusti `make restart` |
| `port is already allocated` | port 8080 alebo 4000 používa iná aplikácia, napr. iná LiteLLM inštancia. Zastav ju alebo zmeň port v `docker/docker-compose.yml` |
