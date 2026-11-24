# No-code agenti

Dvaja AI agenti postavení v no-code platformách, [n8n](https://n8n.io/) a [LangFlow](https://www.langflow.org/), nad tou istou PostgreSQL databázou e-shopu s outdoorovým vybavením. Agent dostane otázku v bežnej reči, sám si napíše SQL, spustí ho nástrojom a odpovie. Modely sa volajú cez [LiteLLM](https://docs.litellm.ai/) proxy, takže oba agenty používajú toho istého poskytovateľa (Anthropic, OpenAI, Google, OpenRouter) a žiadny z nich nepozná jeho API kľúč.

| | n8n | LangFlow |
|:--|:--|:--|
| Definícia agenta | `n8n/shop-agent.json` | `langflow/shop-agent.json` |
| Čítanie z databázy | nástroj `Run SQL query` | nástroj `run_sql` (vlastný komponent) |
| Zápis do databázy | nástroj `Add order note`, iba poznámka k objednávke | nie, spojenie je iba na čítanie |
| Výpočty | nástroj `Calculator` | kalkulačka komponentu Agent |
| Aktuálny dátum | `CURRENT_DATE` v SQL | nástroj komponentu Agent |
| Pamäť konverzácie | `Simple Memory`, posledných 10 správ | história správ komponentu Agent |
| Chat | verejná stránka chatu | Playground |

Jeden príkaz, `make init`, vytvorí databázu, naplní ju dátami a nahrá oboch agentov. V prehliadači netreba nič nastavovať.

## Požiadavky

| Požiadavka | Účel | Inštalácia |
|:--|:--|:--|
| Docker Desktop | beh n8n, LangFlow, PostgreSQL a LiteLLM proxy | [docker.com](https://www.docker.com/products/docker-desktop/) |
| make | spúšťanie príkazov projektu | macOS: `xcode-select --install` |
| jq | otázky z terminálu a `make test` | automaticky cez `make init` (Homebrew) |
| API kľúč | prístup k modelom, stačí jeden poskytovateľ | [Anthropic](https://console.anthropic.com/) · [OpenAI](https://platform.openai.com/api-keys) · [Google AI Studio](https://aistudio.google.com/apikey) · [OpenRouter](https://openrouter.ai/keys) (aj bezplatné modely) |

Prvé spustenie stiahne približne 5 GB image, z toho LangFlow 2,3 GB.

## Inštalácia

```bash
make init
```

Príkaz:

1. z `.env.example` vytvorí súbor `.env` (ak ešte neexistuje) a vygeneruje doň chýbajúce tajomstvá: `LITELLM_MASTER_KEY`, `POSTGRES_PASSWORD`, `AGENT_DB_PASSWORD` a `N8N_OWNER_PASSWORD`. Ostatné hodnoty v existujúcom `.env` nemení,
2. spustí kontajnery. PostgreSQL si pri prvom štarte vytvorí schému, dáta a rolu agenta z `docker/postgres/init.sql`, LangFlow si nahrá flow z priečinka `langflow/`,
3. v n8n vytvorí účet správcu, prihlasovacie údaje (credentials) k LiteLLM a k databáze, nahrá workflow z priečinka `n8n/` a publikuje ho.

Dá sa spustiť opakovane, napríklad po úprave workflowu.

Súbor `.env` z úlohy `01-tool-calling-agents` sa dá použiť aj tu, názvy premenných sú rovnaké. Skopíruj ho pred `make init`, ten doplní iba to, čo chýba.

<details>
<summary>Ručne, bez <code>make init</code></summary>

```bash
cp .env.example .env           # konfigurácia
openssl rand -hex 16           # náhodný reťazec, spusti štyrikrát
```

Do `.env` doplň štyri tajomstvá. Heslo do n8n musí mať 8 až 64 znakov, číslicu a veľké písmeno:

```bash
LITELLM_MASTER_KEY=sk-3f9a1c...
POSTGRES_PASSWORD=7b21e0...
AGENT_DB_PASSWORD=c94d55...
N8N_OWNER_PASSWORD=Aa1e83f0...
```

Potom spusti kontajnery a nastav n8n:

```bash
docker compose -f docker/docker-compose.yml --env-file .env up -d --wait
docker compose -f docker/docker-compose.yml --env-file .env exec -T n8n sh /import/import.sh
docker compose -f docker/docker-compose.yml --env-file .env restart n8n
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
| `POSTGRES_PASSWORD` | heslo správcu databázy, vygeneruje `make init` | |
| `AGENT_DB_PASSWORD` | heslo roly `shop_agent`, ktorou sa pripájajú oba agenty, vygeneruje `make init` | |
| `N8N_OWNER_EMAIL` | prihlasovací e-mail do editora n8n | `admin@example.com` |
| `N8N_OWNER_PASSWORD` | heslo do editora n8n, vygeneruje `make init` | |

Oba agenty volajú alias `anthropic`, preto bez ďalších úprav stačí `ANTHROPIC_API_KEY`. Kľúč doplnený až po `make init` sa prejaví po `make restart`.

Názov modelu má tvar `<poskytovateľ>/<model>` podľa [LiteLLM](https://docs.litellm.ai/docs/providers). Model musí podporovať volanie nástrojov (tool calling).

## Používanie

### n8n

Chat beží na <http://localhost:5679/webhook/shop-agent/chat>, bez prihlásenia.

Workflow **Shop Agent** sa dá prezrieť a upraviť v editore na <http://localhost:5679>. Prihlasovacie údaje sú `N8N_OWNER_EMAIL` a `N8N_OWNER_PASSWORD` z `.env`. Po každej otázke je v záložke **Executions** vidieť, ktoré nástroje agent zavolal a s akým SQL.

### LangFlow

Flow **Shop Agent** je na <http://localhost:7860/flow/6b0d3c9e-5a41-4f7b-9c2d-1e8f7a6b5c40>, bez prihlásenia. Chat sa otvorí tlačidlom **Playground**, volania nástrojov je vidieť priamo v odpovedi.

### Príkazový riadok

Kým beží Docker, dá sa obom agentom poslať otázka priamo z terminálu:

```bash
make ask-n8n q="Ktorých 5 produktov je najdrahších?"
make ask-langflow q="Ktorý zákazník minul najviac a na koľkých objednávkach?"
```

Každé volanie je nová konverzácia. Históriu si držia chaty v prehliadači.

### Čo sa opýtať

- Ktoré produkty sú vypredané?
- Aká je priemerná hodnota doručenej objednávky?
- Koľko objednávok bolo vytvorených za posledných 30 dní a v akej hodnote?
- Koľko by stála objednávka OBJ-2026-0007 po zľave 15 %?
- Pridaj k objednávke OBJ-2026-0005 poznámku: zákazník žiada doručenie po 16:00. (iba n8n)

## Príkazy

| Príkaz | Popis |
|:--|:--|
| `make init` | vytvorí `.env`, spustí kontajnery, naplní databázu a nahrá workflow do n8n |
| `make start` | spustí kontajnery a vypíše adresy |
| `make stop` | zastaví kontajnery, dáta ostávajú |
| `make restart` | reštartuje kontajnery (po zmene `.env` alebo flowu LangFlow) |
| `make logs` | priebežné logy kontajnerov |
| `make clean` | odstráni kontajnery aj dáta: databázu, účet n8n a dáta LangFlow |
| `make test` | skontroluje oba JSON súbory a práva databázovej roly agenta |
| `make ask-n8n q="..."` | otázka agentovi v n8n z terminálu |
| `make ask-langflow q="..."` | otázka agentovi v LangFlow z terminálu |

## Konfigurácia

| Čo | Kde | Po zmene |
|:--|:--|:--|
| API kľúče, modely, heslá | `.env` (šablóna: `.env.example`) | `make restart` |
| Aliasy modelov | `docker/litellm/litellm_config.yaml` | `make restart` |
| Agent v n8n: prompt, nástroje, model | `n8n/shop-agent.json` | `make init` |
| Agent v LangFlow: prompt, nástroje, model | `langflow/shop-agent.json` | `make restart` |
| Schéma a dáta databázy, práva agenta | `docker/postgres/init.sql` | `make clean` a `make init` |

**Zmena modelu:** uprav `ANTHROPIC_MODEL` v `.env`, napr. `ANTHROPIC_MODEL=anthropic/claude-sonnet-5-5`, a spusti `make restart`.

**Iný poskytovateľ:** agenty volajú alias z `docker/litellm/litellm_config.yaml` (`anthropic`, `openai`, `gemini`, `openrouter`). V n8n sa mení v uzle `LiteLLM Chat Model`, pole **Model** (v JSON `parameters.model.value`). V LangFlow je v JSON v poli `model` komponentu Agent (`"name": "anthropic"`).

**Úpravy v editore:** zdrojom pravdy sú JSON súbory. `make init` prepíše workflow v n8n súborom `n8n/shop-agent.json` a LangFlow si pri každom štarte znova nahrá `langflow/shop-agent.json`. Zmenu spravenú v editore preto exportuj (n8n: **Download**, LangFlow: **Export** bez uloženia API kľúčov) a súbor ňou prepíš.

## Dáta

Databáza `shop` vzniká z `docker/postgres/init.sql`. Dáta sú vymyslené a pri každom vytvorení rovnaké (generátor má pevný seed).

| Tabuľka | Obsah | Riadkov |
|:--|:--|:--|
| `users` | zákazníci zo Slovenska a Česka | 12 |
| `products` | produkty v 7 kategóriách, ceny v EUR, sklad, hodnotenie | 30 |
| `orders` | objednávky od januára do novembra 2026 v stavoch `pending`, `paid`, `shipped`, `delivered`, `cancelled` | 40 |
| `order_items` | položky objednávok, sumy objednávok z nich sedia na cent | 100 |
| `order_notes` | poznámky k objednávkam, jediná tabuľka, do ktorej agent smie zapisovať | 2 |

## Architektúra

```
               ┌─► n8n :5679 ──────┐      ┌─► litellm :4000 ──► Anthropic / OpenAI / Gemini / OpenRouter
prehliadač ────┤   (workflow)      ├──────┤   (proxy)
               └─► langflow :7860 ─┘      └─► postgres :5432
                   (flow)                     (databáza shop)
```

| Služba | Popis |
|:--|:--|
| `n8n` | agent č. 1. Uzol AI Agent dostane správu z chatu, model si vyberie nástroj, n8n ho vykoná a výsledok vráti modelu, kým model neodpovie. |
| `langflow` | agent č. 2. To isté s komponentom Agent, databázový nástroj je vlastný komponent uložený priamo vo flowe. |
| `litellm` | proxy s jednotným OpenAI API pre všetkých poskytovateľov. API kľúče poskytovateľov má iba tento kontajner. |
| `postgres` | databáza e-shopu. Agenty sa pripájajú rolou `shop_agent`. |

Z `localhost` sú dostupné iba n8n a LangFlow. LiteLLM a PostgreSQL nemajú publikovaný port, vidia ich len ostatné kontajnery.

## Bezpečnosť

SQL píše model, preto sa naň nedá spoliehať. Ochrana je v databáze, nie v prompte:

| Opatrenie | Popis |
|:--|:--|
| Rola s najmenšími právami | `shop_agent` smie `SELECT` na všetkých tabuľkách a `INSERT` iba do stĺpcov `order_id` a `note` tabuľky `order_notes`. `UPDATE`, `DELETE` ani zmena schémy neprejdú, nech model napíše čokoľvek. Overuje to `make test`. |
| Spojenie iba na čítanie | komponent v LangFlow otvára spojenie s `read_only = True`. |
| Limit výsledku a času | nástroje vracajú najviac 50 riadkov, dopyt roly `shop_agent` sa po 10 sekundách preruší. |
| Parametrizovaný zápis | `Add order note` vkladá hodnoty od modelu ako parametre `$1` a `$2`, nie do textu SQL. |
| Žiadne tajomstvá v JSON | workflow n8n sa na credentials iba odkazuje, flow LangFlow číta kľúč a adresu databázy z prostredia kontajnera. Všetky tajomstvá sú len v `.env`, ktorý sa necommituje. |
| Oddelené kľúče | API kľúče poskytovateľov má iba LiteLLM. n8n a LangFlow poznajú len `LITELLM_MASTER_KEY`. |

Projekt je určený na lokálne použitie: chat n8n aj LangFlow sú bez prihlásenia, preto sú porty dostupné iba z `localhost`.

## Odovzdávané súbory

| Súbor | Platforma |
|:--|:--|
| `n8n/shop-agent.json` | n8n 2.45 |
| `langflow/shop-agent.json` | LangFlow 1.13 |

Oba súbory sa dajú nahrať aj do inej inštalácie. V n8n treba po importe vytvoriť credentials `LiteLLM` (typ OpenAI, Base URL proxy) a `Shop Postgres`. LangFlow potrebuje premenné prostredia `OPENAI_API_KEY`, `OPENAI_BASE_URL` a `SHOP_DATABASE_URL`.

## Riešenie problémov

| Problém | Riešenie |
|:--|:--|
| `required variable ... is missing a value` | niektoré tajomstvo v `.env` je prázdne. Spusti `make init`, ktorý ho vygeneruje |
| `Error in workflow` (n8n) alebo `Missing ... API Key` (LangFlow) | poskytovateľ nemá kľúč v `.env`. Doplň ho a spusti `make restart`. Podrobnosti: `make logs` alebo záložka **Executions** v n8n |
| `NotFoundError` / `model not found` | názov v `*_MODEL` neexistuje alebo ho poskytovateľ vypol. Oprav ho v `.env` a spusti `make restart` |
| chat n8n vracia 404 | workflow nie je publikovaný. Spusti `make init` |
| `port is already allocated` | port 5679 alebo 7860 používa iná aplikácia. Zastav ju alebo zmeň port v `docker/docker-compose.yml` |
| `password authentication failed for user "shop_agent"` | heslo v `.env` sa zmenilo po vytvorení databázy. Vráť pôvodné, alebo spusti `make clean` a `make init` |
| zmena v `init.sql` sa neprejavila | skript beží iba na prázdnej databáze. Spusti `make clean` a `make init` |
| agent si vymýšľa alebo nevolá nástroje | model je na volanie nástrojov slabý. Nastav v `*_MODEL` silnejší |
| `make init` dlho čaká | pri prvom spustení sa sťahujú image, LangFlow potom štartuje približne minútu |
