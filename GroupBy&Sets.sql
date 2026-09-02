-- Q1. How many products do we carry in each category?
SELECT
    category,
    COUNT(*) AS total_products
FROM products
GROUP BY category
ORDER BY total_products DESC;


-- Q2. What is the average price of products in each category?
SELECT
    category,
    ROUND(AVG(unit_price), 2) AS avg_price
FROM products
GROUP BY category
ORDER BY avg_price DESC;


-- Q3. What is the total quantity of stock sitting in each warehouse?
SELECT
    w.warehouse_name,
    SUM(s.quantity) AS total_units_stored
FROM stock s
JOIN warehouses w ON s.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_name
ORDER BY total_units_stored DESC;


-- Q4. For each product, what is the total quantity we hold across all warehouses combined?
SELECT
    p.product_name,
    SUM(s.quantity) AS total_quantity_all_warehouses
FROM stock s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_quantity_all_warehouses DESC;


-- Q5. Which categories have MORE than 8 different products?
SELECT
    category,
    COUNT(*) AS total_products
FROM products
GROUP BY category
HAVING COUNT(*) > 8
ORDER BY total_products DESC;


-- Q6. Which warehouses are running "thin" overall — total stock
--     quantity below 3000 units across everything they hold?
SELECT
    w.warehouse_name,
    SUM(s.quantity) AS total_units_stored
FROM stock s
JOIN warehouses w ON s.warehouse_id = w.warehouse_id
GROUP BY w.warehouse_name
HAVING SUM(s.quantity) < 3000
ORDER BY total_units_stored ASC;


-- Q7. Which movement types (INBOUND, OUTBOUND, TRANSFER, ADJUSTMENT) have moved a meaningful volume — more than 300 total units —since they were logged?
SELECT
    movement_type,
    COUNT(*)      AS number_of_movements,
    SUM(quantity) AS total_units_moved
FROM stock_movements
GROUP BY movement_type
HAVING SUM(quantity) > 300
ORDER BY total_units_moved DESC;


-- Q8. Which suppliers give us MORE than 4 products, and whose products average MORE than $100 in price? (our higher-value, higher-volume supplier relationships)
SELECT
    s.supplier_name,
    COUNT(p.product_id)        AS products_supplied,
    ROUND(AVG(p.unit_price),2) AS avg_product_price
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
GROUP BY s.supplier_name
HAVING COUNT(p.product_id) > 4 AND AVG(p.unit_price) > 100
ORDER BY avg_product_price DESC;


-- Q9. Build a single "watchlist" of product names that are either premium priced (over $300) OR flagged as high reorder-priority reorder_level 25 or higher) — each product listed only ONCE even if it qualifies for both reasons.
SELECT product_name FROM products WHERE unit_price > 300
UNION
SELECT product_name FROM products WHERE reorder_level >= 25
ORDER BY product_name;


-- Q10. Same watchlist as Q9, but this time we want to see a product TWICE if it qualifies for both reasons (premium price AND high reorder priority) — useful when we want to know how many separate reasons flagged an item, not just a clean list.
SELECT product_name FROM products WHERE unit_price > 300
UNION ALL
SELECT product_name FROM products WHERE reorder_level >= 25
ORDER BY product_name;


-- Q11. Which expensive products (over $200) are ALSO currently running low in at least one warehouse right now? These are our highest-value stockout risks and need priority reordering.
SELECT product_id, product_name
FROM products
WHERE unit_price > 200

INTERSECT

SELECT p.product_id, p.product_name
FROM products p
JOIN stock s ON p.product_id = s.product_id
WHERE s.quantity < p.reorder_level;


-- Q12. Which products have NEVER had a single stock movement logged (no inbound, outbound, transfer, or adjustment record at all)?
SELECT product_id, product_name
FROM products

EXCEPT

SELECT p.product_id, p.product_name
FROM products p
JOIN stock_movements sm ON p.product_id = sm.product_id;

