BEGIN;

-- Stable sample emails make this safe to run again without duplicating customers.
INSERT INTO customers (name, email)
SELECT
    'Customer ' || n::STRING,
    'customer' || n::STRING || '@example.com'
FROM generate_series(1, 100) AS seed(n)
ON CONFLICT (email) DO NOTHING;

-- Build a list of just the sample customers, then pick one per order at random.
WITH sample_customers AS (
    SELECT array_agg(c.id ORDER BY c.email) AS ids
    FROM customers AS c
    JOIN generate_series(1, 100) AS seed(n)
        ON c.email = 'customer' || n::STRING || '@example.com'
)
INSERT INTO orders (reference, customer_id, description, price)
SELECT
    'ORD-' || lpad(n::STRING, 4, '0'),
    ids[1 + floor(random() * array_length(ids, 1)::FLOAT)::INT],
    'Sample order ' || n::STRING,
    round((1 + random() * 499)::DECIMAL, 2)
FROM generate_series(1, 300) AS seed(n)
CROSS JOIN sample_customers
-- Existing sample orders keep their original customer and price on a rerun.
ON CONFLICT (reference) DO NOTHING;

COMMIT;
