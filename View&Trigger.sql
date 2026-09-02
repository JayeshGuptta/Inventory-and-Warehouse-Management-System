-- 1. Create a view that shows current stock with the product name
--     and warehouse name spelled out, instead of raw IDs, so
--     anyone browsing the data doesn't need to know the schema.
CREATE OR REPLACE VIEW vw_current_stock AS
SELECT
    s.stock_id,
    p.product_name,
    p.category,
    w.warehouse_name,
    s.quantity,
    p.reorder_level,
    s.last_updated
FROM stock s
JOIN products p   ON s.product_id = p.product_id
JOIN warehouses w ON s.warehouse_id = w.warehouse_id;

-- Try it:
SELECT * FROM vw_current_stock ORDER BY warehouse_name;


-- 2. Create a view that only shows stock rows CURRENTLY below
--     their product's reorder level — a ready-made alert list the
--     purchasing team can query any time without writing SQL.
CREATE OR REPLACE VIEW vw_low_stock_alert AS
SELECT
    p.product_name,
    w.warehouse_name,
    s.quantity,
    p.reorder_level,
    (p.reorder_level - s.quantity) AS units_short
FROM stock s
JOIN products p   ON s.product_id = p.product_id
JOIN warehouses w ON s.warehouse_id = w.warehouse_id
WHERE s.quantity < p.reorder_level;

-- Try it:
SELECT * FROM vw_low_stock_alert ORDER BY units_short DESC;


-- 3. Create a view summarizing the total inventory VALUE
--     (quantity × unit price) held in each warehouse — a quick
--     financial snapshot for management.
CREATE OR REPLACE VIEW vw_warehouse_inventory_value AS
SELECT
    w.warehouse_name,
    SUM(s.quantity * p.unit_price) AS total_inventory_value
FROM stock s
JOIN products p   ON s.product_id = p.product_id
JOIN warehouses w ON s.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_name;

-- Try it:
SELECT * FROM vw_warehouse_inventory_value ORDER BY total_inventory_value DESC;


-- 4. Create a view listing each supplier with how many products
--     they supply and the average price of those products — useful
--     for reviewing supplier relationships at a glance.
CREATE OR REPLACE VIEW vw_supplier_summary AS
SELECT
    s.supplier_name,
    s.country,
    COUNT(p.product_id)         AS products_supplied,
    ROUND(AVG(p.unit_price), 2) AS avg_price
FROM suppliers s
LEFT JOIN products p ON s.supplier_id = p.supplier_id
GROUP BY s.supplier_name, s.country;

-- Try it:
SELECT * FROM vw_supplier_summary ORDER BY products_supplied DESC;


-- 5. Create a view that turns the raw stock_movements audit log
--     into a readable report — product and warehouse names instead
--     of numeric IDs — for non-technical staff to review.
CREATE OR REPLACE VIEW vw_movement_log AS
SELECT
    sm.movement_id,
    p.product_name,
    fw.warehouse_name AS from_warehouse,
    tw.warehouse_name AS to_warehouse,
    sm.quantity,
    sm.movement_type,
    sm.movement_date,
    sm.remarks
FROM stock_movements sm
JOIN products p        ON sm.product_id = p.product_id
LEFT JOIN warehouses fw ON sm.from_warehouse_id = fw.warehouse_id
LEFT JOIN warehouses tw ON sm.to_warehouse_id = tw.warehouse_id;

-- Try it:
SELECT * FROM vw_movement_log ORDER BY movement_date DESC;

-- 6. Automatically stamp last_updated on the stock table whenever
--     a row's quantity actually changes, so nobody has to remember
--     to set that column by hand from the application side.
CREATE OR REPLACE FUNCTION fn_touch_stock_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_touch_stock_timestamp
BEFORE UPDATE ON stock
FOR EACH ROW
WHEN (OLD.quantity IS DISTINCT FROM NEW.quantity)
EXECUTE FUNCTION fn_touch_stock_timestamp();


-- 7. Whenever someone updates a stock row's quantity directly
--     (not through the transfer procedure), automatically log that
--     change into stock_movements as an ADJUSTMENT — so the audit
--     trail never has a gap, even for manual edits.
CREATE OR REPLACE FUNCTION fn_log_stock_adjustment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantity <> OLD.quantity THEN
        INSERT INTO stock_movements
            (product_id, from_warehouse_id, to_warehouse_id, quantity, movement_type, remarks)
        VALUES
            (NEW.product_id, NEW.warehouse_id, NULL,
             ABS(NEW.quantity - OLD.quantity), 'ADJUSTMENT',
             'Auto-logged: direct stock quantity edit');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_stock_adjustment
AFTER UPDATE ON stock
FOR EACH ROW
EXECUTE FUNCTION fn_log_stock_adjustment();


-- 8. Block anyone from ever setting a stock quantity below zero,
--     with a clear custom error message. (The CHECK constraint
--     already blocks this at the column level — this trigger shows
--     how you'd do the same validation with custom, friendlier
--     error text instead of a generic constraint violation.)
CREATE OR REPLACE FUNCTION fn_prevent_negative_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantity < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative for product_id=%, attempted value=%',
            NEW.product_id, NEW.quantity;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_negative_stock
BEFORE INSERT OR UPDATE ON stock
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_negative_stock();


-- 9. Whenever a stock update causes quantity to drop below the
--     product's reorder level, automatically create a low-stock
--     alert record so purchasing gets notified without manually
--     checking every product/warehouse combination.
CREATE TABLE IF NOT EXISTS low_stock_alerts (
    alert_id           SERIAL PRIMARY KEY,
    product_id         INT NOT NULL REFERENCES products(product_id),
    warehouse_id       INT NOT NULL REFERENCES warehouses(warehouse_id),
    quantity_at_alert  INT NOT NULL,
    reorder_level      INT NOT NULL,
    alert_date         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION fn_low_stock_alert()
RETURNS TRIGGER AS $$
DECLARE
    v_reorder_level INT;
BEGIN
    SELECT reorder_level INTO v_reorder_level
    FROM products WHERE product_id = NEW.product_id;

    IF NEW.quantity < v_reorder_level THEN
        INSERT INTO low_stock_alerts (product_id, warehouse_id, quantity_at_alert, reorder_level)
        VALUES (NEW.product_id, NEW.warehouse_id, NEW.quantity, v_reorder_level);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_low_stock_alert
AFTER UPDATE ON stock
FOR EACH ROW
WHEN (NEW.quantity < OLD.quantity)
EXECUTE FUNCTION fn_low_stock_alert();


-- 10. Prevent a supplier from being deleted while they still have
--     products linked to them, so we never silently lose the trail
--     of who supplied what.
CREATE OR REPLACE FUNCTION fn_prevent_supplier_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM products WHERE supplier_id = OLD.supplier_id) THEN
        RAISE EXCEPTION 'Cannot delete supplier "%": products are still linked to this supplier',
            OLD.supplier_name;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_supplier_delete
BEFORE DELETE ON suppliers
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_supplier_delete();


-- 11. Prevent a warehouse from being deleted while it still holds
--     stock (quantity > 0 in any product), so we never accidentally
--     erase inventory records that are still "live".
CREATE OR REPLACE FUNCTION fn_prevent_warehouse_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM stock
        WHERE warehouse_id = OLD.warehouse_id AND quantity > 0
    ) THEN
        RAISE EXCEPTION 'Cannot delete warehouse "%": it still holds stock on hand',
            OLD.warehouse_name;
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_warehouse_delete
BEFORE DELETE ON warehouses
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_warehouse_delete();

