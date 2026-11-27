CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference STRING NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers (id),
    description STRING NOT NULL,
    price DECIMAL(12, 2) NOT NULL CHECK (price >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    INDEX orders_customer_id_idx (customer_id)
);
