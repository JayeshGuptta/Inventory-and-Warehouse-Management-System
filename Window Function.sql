-- Q1. Within each category, rank products from most to least
SELECT
    product_name,
    category,
    unit_price,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price DESC) AS price_rank_in_category
FROM products
ORDER BY category, price_rank_in_category;


-- Q2. Rank ALL products in the catalog by price, highest first.
--     If two products share the exact same price, they should
--     share the same rank (and the next rank number is skipped).
SELECT
    product_name,
    unit_price,
    RANK() OVER (ORDER BY unit_price DESC) AS price_rank
FROM products
ORDER BY price_rank;


-- Q3. Rank warehouses by their total stock quantity, but this time
--     tied warehouses should share a rank WITHOUT skipping the next
--     number (1,1,2,3... instead of 1,1,3,4...).
WITH warehouse_totals AS (
    SELECT
        w.warehouse_name,
        SUM(s.quantity) AS total_quantity
    FROM stock s
    JOIN warehouses w ON s.warehouse_id = w.warehouse_id
    GROUP BY w.warehouse_name
)
SELECT
    warehouse_name,
    total_quantity,
    DENSE_RANK() OVER (ORDER BY total_quantity DESC) AS stock_rank
FROM warehouse_totals
ORDER BY stock_rank;


-- Q4. Split all products into 4 equal-sized pricing tiers
--     (budget, mid, upper-mid, premium) for a pricing report.
SELECT
    product_name,
    unit_price,
    NTILE(4) OVER (ORDER BY unit_price) AS price_quartile
FROM products
ORDER BY price_quartile, unit_price;


-- Q5. For each product's movement history, show the quantity from
--     the PREVIOUS movement right next to the current one, so we
--     can eyeball how quantity handled is changing over time.
SELECT
    product_id,
    movement_id,
    movement_date,
    quantity,
    LAG(quantity) OVER (PARTITION BY product_id ORDER BY movement_date) AS previous_movement_qty
FROM stock_movements
ORDER BY product_id, movement_date;


-- Q6. Same idea in reverse: for each movement, show the quantity
--     of the NEXT movement for that product (useful for spotting
--     what happened right after a big outbound shipment, say).
SELECT
    product_id,
    movement_id,
    movement_date,
    quantity,
    LEAD(quantity) OVER (PARTITION BY product_id ORDER BY movement_date) AS next_movement_qty
FROM stock_movements
ORDER BY product_id, movement_date;


-- Q7. For each product, show a RUNNING TOTAL of quantity moved
--     over time (each row adds to the total moved so far), so we
--     can see cumulative movement volume build up chronologically.
SELECT
    product_id,
    movement_date,
    quantity,
    SUM(quantity) OVER (
        PARTITION BY product_id
        ORDER BY movement_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_qty
FROM stock_movements
ORDER BY product_id, movement_date;


-- Q8. Show every product's price next to its OWN category's
--     average price, plus how far above/below average it sits —
--     without collapsing the detail rows the way GROUP BY would.
SELECT
    product_name,
    category,
    unit_price,
    ROUND(AVG(unit_price) OVER (PARTITION BY category), 2)               AS category_avg_price,
    ROUND(unit_price - AVG(unit_price) OVER (PARTITION BY category), 2)  AS diff_from_category_avg
FROM products
ORDER BY category, unit_price DESC;


-- Q9. For every product row, also show the name of the CHEAPEST
--     product in that same category — handy for "compare to our
--     entry-level option" style reporting.
SELECT
    product_name,
    category,
    unit_price,
    FIRST_VALUE(product_name) OVER (
        PARTITION BY category ORDER BY unit_price ASC
    ) AS cheapest_in_category
FROM products
ORDER BY category, unit_price;


-- Q10. For every product row, also show the name of the MOST
--      EXPENSIVE product in that same category. LAST_VALUE needs
--      an explicit full-partition frame, otherwise it only looks
--      at rows up to the current one and gives the wrong answer.
SELECT
    product_name,
    category,
    unit_price,
    LAST_VALUE(product_name) OVER (
        PARTITION BY category
        ORDER BY unit_price ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS most_expensive_in_category
FROM products
ORDER BY category, unit_price;


-- Q11. For each product, show what PERCENTAGE of the catalog is
--      priced at or below it (0 = cheapest, close to 1 = priciest)
--      — a quick way to see relative price positioning at a glance.
SELECT
    product_name,
    unit_price,
    ROUND(PERCENT_RANK() OVER (ORDER BY unit_price)::numeric, 3) AS price_percentile
FROM products
ORDER BY unit_price;

