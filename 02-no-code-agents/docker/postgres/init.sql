-- Runs once, on the first start of an empty Postgres volume
-- (every *.sql file in /docker-entrypoint-initdb.d does).
-- To change the data: edit this file, run `make clean` and `make init`.

-- -----------------------------------------------------------------
-- Schema
-- -----------------------------------------------------------------

CREATE TABLE users (
    id                INT PRIMARY KEY,
    email             VARCHAR(255) UNIQUE NOT NULL,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    city              VARCHAR(100),
    country           VARCHAR(100),
    is_premium        BOOLEAN DEFAULT FALSE,
    registration_date DATE
);

CREATE TABLE products (
    id             INT PRIMARY KEY,
    sku            VARCHAR(50) UNIQUE,
    name           VARCHAR(255) NOT NULL,
    description    TEXT,
    category       VARCHAR(100),
    brand          VARCHAR(100),
    price          NUMERIC(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    rating         NUMERIC(3, 1),
    review_count   INT DEFAULT 0,
    is_active      BOOLEAN DEFAULT TRUE
);

CREATE TABLE orders (
    id               INT PRIMARY KEY,
    order_number     VARCHAR(20) UNIQUE NOT NULL,
    user_id          INT NOT NULL REFERENCES users (id),
    order_date       TIMESTAMP NOT NULL,
    status           VARCHAR(50) NOT NULL,
    payment_method   VARCHAR(50),
    subtotal         NUMERIC(10, 2) NOT NULL DEFAULT 0,
    shipping_cost    NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_amount     NUMERIC(10, 2) NOT NULL DEFAULT 0,
    shipping_city    VARCHAR(100),
    shipping_country VARCHAR(100)
);

CREATE TABLE order_items (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     INT NOT NULL REFERENCES orders (id),
    product_id   INT NOT NULL REFERENCES products (id),
    product_name VARCHAR(255) NOT NULL,
    quantity     INT NOT NULL,
    unit_price   NUMERIC(10, 2) NOT NULL,
    total_price  NUMERIC(10, 2) NOT NULL
);

-- The only table the agent may write to.
CREATE TABLE order_notes (
    id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id   INT NOT NULL REFERENCES orders (id),
    note       TEXT NOT NULL CHECK (length(note) BETWEEN 1 AND 500),
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------
-- Data: a small Slovak outdoor shop, prices in EUR
-- -----------------------------------------------------------------

INSERT INTO users (id, email, first_name, last_name, city, country, is_premium, registration_date) VALUES
    (1,  'jana.kovacova@example.com',    'Jana',     'Kováčová',  'Bratislava',      'Slovensko', TRUE,  '2024-03-12'),
    (2,  'peter.horvath@example.com',    'Peter',    'Horváth',   'Košice',          'Slovensko', FALSE, '2024-05-02'),
    (3,  'martin.novak@example.com',     'Martin',   'Novák',     'Žilina',          'Slovensko', TRUE,  '2024-06-21'),
    (4,  'zuzana.tothova@example.com',   'Zuzana',   'Tóthová',   'Nitra',           'Slovensko', FALSE, '2024-09-08'),
    (5,  'tomas.balaz@example.com',      'Tomáš',    'Baláž',     'Banská Bystrica', 'Slovensko', FALSE, '2024-11-30'),
    (6,  'katarina.vargova@example.com', 'Katarína', 'Vargová',   'Prešov',          'Slovensko', TRUE,  '2025-01-17'),
    (7,  'michal.molnar@example.com',    'Michal',   'Molnár',    'Trnava',          'Slovensko', FALSE, '2025-04-04'),
    (8,  'lucia.simkova@example.com',    'Lucia',    'Šimková',   'Poprad',          'Slovensko', FALSE, '2025-07-19'),
    (9,  'petr.svoboda@example.com',     'Petr',     'Svoboda',   'Brno',            'Česko',     FALSE, '2025-09-01'),
    (10, 'tereza.dvorakova@example.com', 'Tereza',   'Dvořáková', 'Ostrava',         'Česko',     TRUE,  '2025-10-26'),
    (11, 'marek.polak@example.com',      'Marek',    'Polák',     'Trenčín',         'Slovensko', FALSE, '2026-02-14'),
    (12, 'eva.kucerova@example.com',     'Eva',      'Kučerová',  'Liptovský Mikuláš', 'Slovensko', FALSE, '2026-06-03');

INSERT INTO products (id, sku, name, description, category, brand, price, stock_quantity, rating, review_count, is_active) VALUES
    (1,  'STN-001', 'Stan Kriváň 2 Ultralight',            'Dvojmiestny ultraľahký stan, 1,4 kg, vodný stĺpec 3000 mm.',      'Stany',     'Kriváň',  329.00, 12,  4.7, 58,  TRUE),
    (2,  'STN-002', 'Stan Rysy 3 Family',                  'Trojmiestny stan s veľkou predsieňou na batohy.',                 'Stany',     'Rysy',    249.90, 8,   4.4, 31,  TRUE),
    (3,  'STN-003', 'Stan Chopok 1 Solo',                  'Jednomiestny stan na rýchle prechody hrebeňov, 980 g.',           'Stany',     'Chopok',  189.00, 5,   4.5, 22,  TRUE),
    (4,  'STN-004', 'Tarp Roháče 3x3',                     'Ľahká plachta 3 x 3 m s ôsmimi kotviacimi bodmi.',                'Stany',     'Roháče',  69.90,  20,  4.2, 14,  TRUE),
    (5,  'SPC-001', 'Spacák Ďumbier -10 páperový',         'Páperový spacák do mrazu, komfort -10 °C, 1,1 kg.',               'Spacáky',   'Ďumbier', 279.00, 7,   4.8, 44,  TRUE),
    (6,  'SPC-002', 'Spacák Rysy Comfort +5',              'Letný syntetický spacák, komfort +5 °C.',                         'Spacáky',   'Rysy',    89.90,  25,  4.3, 67,  TRUE),
    (7,  'SPC-003', 'Spacák Chopok Light 0',               'Trojsezónny spacák, komfort 0 °C, 850 g.',                        'Spacáky',   'Chopok',  149.00, 0,   4.5, 29,  TRUE),
    (8,  'SPC-004', 'Karimatka Kriváň samonafukovacia',    'Samonafukovacia karimatka s hrúbkou 3,8 cm.',                     'Spacáky',   'Kriváň',  74.90,  18,  4.4, 51,  TRUE),
    (9,  'SPC-005', 'Karimatka Roháče UL nafukovacia',     'Nafukovacia karimatka, 420 g, R-hodnota 3,2.',                    'Spacáky',   'Roháče',  119.00, 9,   4.6, 37,  TRUE),
    (10, 'BAT-001', 'Batoh Kriváň Trek 55 l',              'Trekový batoh s nastaviteľným chrbtovým systémom.',               'Batohy',    'Kriváň',  179.00, 14,  4.7, 83,  TRUE),
    (11, 'BAT-002', 'Batoh Rysy Daypack 22 l',             'Jednodňový batoh s pláštenkou a vreckom na vak s vodou.',         'Batohy',    'Rysy',    64.90,  30,  4.5, 120, TRUE),
    (12, 'BAT-003', 'Batoh Ďumbier Alpine 38 l',           'Horolezecký batoh s úchytmi na cepíny a lano.',                   'Batohy',    'Ďumbier', 139.00, 6,   4.6, 41,  TRUE),
    (13, 'BAT-004', 'Bežecká vesta Chopok 8 l',            'Vesta na horský beh s dvoma mäkkými fľašami.',                    'Batohy',    'Chopok',  99.00,  11,  4.3, 19,  TRUE),
    (14, 'OBU-001', 'Turistická obuv Rysy Mid GTX',        'Členková obuv s nepremokavou membránou.',                         'Obuv',      'Rysy',    169.00, 16,  4.6, 95,  TRUE),
    (15, 'OBU-002', 'Trailové tenisky Chopok Run',         'Bežecká obuv do terénu s hrubým vzorom podrážky.',                'Obuv',      'Chopok',  129.90, 22,  4.4, 73,  TRUE),
    (16, 'OBU-003', 'Trekové topánky Ďumbier Pro',         'Vysoké kožené topánky na náročné túry s ťažkým batohom.',         'Obuv',      'Ďumbier', 229.00, 4,   4.8, 36,  TRUE),
    (17, 'OBU-004', 'Sandále Roháče River',                'Turistické sandále do vody aj na prechádzky.',                    'Obuv',      'Roháče',  59.90,  0,   4.1, 28,  TRUE),
    (18, 'OBL-001', 'Nepremokavá bunda Kriváň Storm',      'Trojvrstvová bunda, vodný stĺpec 20 000 mm.',                     'Oblečenie', 'Kriváň',  199.00, 10,  4.7, 64,  TRUE),
    (19, 'OBL-002', 'Páperová bunda Ďumbier Down',         'Ľahká páperová bunda, zbalí sa do vlastného vrecka.',             'Oblečenie', 'Ďumbier', 219.00, 7,   4.8, 52,  TRUE),
    (20, 'OBL-003', 'Merino tričko Rysy 150',              'Tričko s krátkym rukávom zo 100 % merino vlny.',                  'Oblečenie', 'Rysy',    54.90,  40,  4.6, 110, TRUE),
    (21, 'OBL-004', 'Softshellové nohavice Chopok',        'Pružné nohavice na túry od jari do jesene.',                      'Oblečenie', 'Chopok',  89.00,  15,  4.3, 47,  TRUE),
    (22, 'OBL-005', 'Merino ponožky Roháče Hike',          'Turistické ponožky, balenie 2 párov.',                            'Oblečenie', 'Roháče',  19.90,  60,  4.5, 150, TRUE),
    (23, 'VAR-001', 'Plynový varič Kriváň Mini',           'Skladací varič s hmotnosťou 85 g.',                               'Varenie',   'Kriváň',  34.90,  26,  4.6, 88,  TRUE),
    (24, 'VAR-002', 'Varná súprava Rysy Titan 900 ml',     'Titánový hrniec s pokrievkou a skladacími uškami.',               'Varenie',   'Rysy',    59.00,  13,  4.7, 33,  TRUE),
    (25, 'VAR-003', 'Plynová kartuša Roháče 230 g',        'Kartuša so závitom, zmes propán a izobután.',                     'Varenie',   'Roháče',  6.90,   100, 4.4, 61,  TRUE),
    (26, 'VAR-004', 'Termoska Ďumbier 1 l',                'Nerezová termoska, udrží teplo 24 hodín.',                        'Varenie',   'Ďumbier', 32.90,  19,  4.5, 76,  TRUE),
    (27, 'DOP-001', 'Čelovka Chopok 400 lm',               'Nabíjateľná čelovka s červeným svetlom.',                         'Doplnky',   'Chopok',  39.90,  35,  4.6, 132, TRUE),
    (28, 'DOP-002', 'Trekingové palice Kriváň Carbon',     'Skladacie karbónové palice, pár 380 g.',                          'Doplnky',   'Kriváň',  89.90,  17,  4.5, 58,  TRUE),
    (29, 'DOP-003', 'Filter na vodu Rysy Squeeze',         'Filter s dutými vláknami, 0,1 mikrometra.',                       'Doplnky',   'Rysy',    44.90,  3,   4.7, 49,  TRUE),
    (30, 'DOP-004', 'Lekárnička Roháče Outdoor',           'Vodotesná lekárnička na túry. Výroba ukončená.',                  'Doplnky',   'Roháče',  24.90,  0,   4.2, 17,  FALSE);

-- 40 orders across 2026, always the same ones: setseed() makes random() repeatable.
SELECT setseed(0.42);

WITH picked AS MATERIALIZED (
    SELECT i,
           -- power() skews towards low ids: a few regulars, a few customers with no order
           1 + floor(power(random(), 1.6) * 12)::int AS user_id,
           timestamp '2026-01-03 08:00' + i * interval '8 days'
               + floor(random() * 600) * interval '1 minute' AS order_date,
           random() AS cancel_roll,
           (ARRAY['card', 'card', 'bank_transfer', 'cash_on_delivery'])[1 + floor(random() * 4)::int] AS payment_method
    FROM generate_series(1, 40) AS i
)
INSERT INTO orders (id, order_number, user_id, order_date, status, payment_method, shipping_city, shipping_country)
SELECT p.i,
       'OBJ-2026-' || lpad(p.i::text, 4, '0'),
       p.user_id,
       p.order_date,
       CASE
           WHEN p.i > 38 THEN 'pending'
           WHEN p.i > 36 THEN 'paid'
           WHEN p.i > 33 THEN 'shipped'
           WHEN p.cancel_roll < 0.12 THEN 'cancelled'
           ELSE 'delivered'
       END,
       p.payment_method,
       u.city,
       u.country
FROM picked p
JOIN users u ON u.id = p.user_id
ORDER BY p.i;

-- 1 to 4 different products per order. The LIMIT depends on the order,
-- so the subquery (and its random()) runs again for every order.
INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
SELECT o.id, p.id, p.name, p.quantity, p.price, p.quantity * p.price
FROM (SELECT id FROM orders ORDER BY id) AS o
CROSS JOIN LATERAL (
    SELECT id, name, price, 1 + floor(power(random(), 2) * 3)::int AS quantity
    FROM products
    ORDER BY random()
    LIMIT 1 + o.id % 4
) AS p;

-- Order totals come from the items, so they always match. Free shipping from 100 EUR.
UPDATE orders o
SET subtotal      = s.subtotal,
    shipping_cost = CASE WHEN s.subtotal >= 100 THEN 0 ELSE 4.90 END,
    total_amount  = s.subtotal + CASE WHEN s.subtotal >= 100 THEN 0 ELSE 4.90 END
FROM (SELECT order_id, sum(total_price) AS subtotal FROM order_items GROUP BY order_id) AS s
WHERE s.order_id = o.id;

INSERT INTO order_notes (order_id, note) VALUES
    (3,  'Zákazník prosí doručenie po 16:00.'),
    (17, 'Darček, nepribaľovať faktúru.');

-- Self-check: the init fails loudly if the generated data is inconsistent.
DO $$
BEGIN
    ASSERT (SELECT count(*) FROM orders) = 40, 'expected 40 orders';
    ASSERT NOT EXISTS (
        SELECT 1
        FROM orders o
        WHERE o.subtotal <> (SELECT sum(i.total_price) FROM order_items i WHERE i.order_id = o.id)
           OR o.total_amount <> o.subtotal + o.shipping_cost
    ), 'order totals do not match their items';
END $$;

-- -----------------------------------------------------------------
-- Role for the agents: read everything, write only order notes
-- -----------------------------------------------------------------

-- The password comes from the container environment, it is never stored in this file.
\getenv agent_password AGENT_DB_PASSWORD
CREATE ROLE shop_agent LOGIN PASSWORD :'agent_password';

GRANT SELECT ON ALL TABLES IN SCHEMA public TO shop_agent;
GRANT INSERT (order_id, note) ON order_notes TO shop_agent;

-- A query written by a model must not run forever.
ALTER ROLE shop_agent SET statement_timeout = '10s';
