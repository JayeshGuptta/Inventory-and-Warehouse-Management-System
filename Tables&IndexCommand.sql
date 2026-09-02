-- TABLE 1: SUPPLIERS
CREATE TABLE suppliers (
    supplier_id     SERIAL PRIMARY KEY,
    supplier_name   VARCHAR(100) NOT NULL,
    contact_person  VARCHAR(100),
    email           VARCHAR(100) NOT NULL UNIQUE,
    phone           VARCHAR(20),
    address         VARCHAR(200),
    country         VARCHAR(50) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- TABLE 2: WAREHOUSES
CREATE TABLE warehouses (
    warehouse_id    SERIAL PRIMARY KEY,
    warehouse_name  VARCHAR(100) NOT NULL,
    location        VARCHAR(150) NOT NULL,
    city            VARCHAR(50) NOT NULL,
    capacity        INT NOT NULL CHECK (capacity > 0),
    manager_name    VARCHAR(100),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- TABLE 3: PRODUCTS
CREATE TABLE products (
    product_id      SERIAL PRIMARY KEY,
    sku             VARCHAR(20) NOT NULL UNIQUE,
    product_name    VARCHAR(150) NOT NULL,
    category        VARCHAR(50) NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    reorder_level   INT NOT NULL DEFAULT 10 CHECK (reorder_level >= 0),
    supplier_id     INT REFERENCES suppliers(supplier_id) ON DELETE SET NULL ON UPDATE CASCADE,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- TABLE 4: STOCK
CREATE TABLE stock (
    stock_id        SERIAL PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE ON UPDATE CASCADE,
    warehouse_id    INT NOT NULL REFERENCES warehouses(warehouse_id) ON DELETE CASCADE ON UPDATE CASCADE,
    quantity        INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    last_updated    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_warehouse UNIQUE (product_id, warehouse_id)
);

-- TABLE 5: STOCK_MOVEMENTS
CREATE TABLE stock_movements (
    movement_id         SERIAL PRIMARY KEY,
    product_id          INT NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    from_warehouse_id   INT REFERENCES warehouses(warehouse_id) ON DELETE SET NULL,
    to_warehouse_id     INT REFERENCES warehouses(warehouse_id) ON DELETE SET NULL,
    quantity            INT NOT NULL CHECK (quantity > 0),
    movement_type       VARCHAR(20) NOT NULL CHECK (movement_type IN ('INBOUND','OUTBOUND','TRANSFER','ADJUSTMENT')),
    movement_date       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    remarks             VARCHAR(200),
    CONSTRAINT chk_transfer_warehouses CHECK (
        (movement_type = 'TRANSFER' AND from_warehouse_id IS NOT NULL AND to_warehouse_id IS NOT NULL AND from_warehouse_id <> to_warehouse_id)
        OR (movement_type <> 'TRANSFER')
    )
);

-- Helpful indexes for lookup-heavy columns (FKs are not auto-indexed in Postgres except PK)
CREATE INDEX idx_products_supplier ON products(supplier_id);
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_stock_product ON stock(product_id);
CREATE INDEX idx_stock_warehouse ON stock(warehouse_id);
CREATE INDEX idx_movements_product ON stock_movements(product_id);
CREATE INDEX idx_movements_date ON stock_movements(movement_date);
