-- Q1. List every product's SKU, name and price, but show the
SELECT
    sku            AS product_code,
    product_name   AS name,
    unit_price     AS price_usd
FROM products;


-- Q2. Show just the first 10 rows of the products table
SELECT *
FROM products
LIMIT 10;


-- Q3. Find all products priced above $200.
SELECT product_name, unit_price
FROM products
WHERE unit_price > 200;


-- Q4. Find all Electronics products that also cost less than $150.
SELECT product_name, category, unit_price
FROM products
WHERE category = 'Electronics' AND unit_price < 150;


-- Q5. Find products that belong to either Furniture or Hardware & Tools.
SELECT product_name, category
FROM products
WHERE category = 'Furniture' OR category = 'Hardware & Tools';


-- Q6. Find every product that is NOT in the Grocery category.
SELECT product_name, category
FROM products
WHERE NOT category = 'Grocery';


-- Q7. Find products priced between $50 and $150 (inclusive).
SELECT product_name, unit_price
FROM products
WHERE unit_price BETWEEN 50 AND 150;


-- Q8. Find stock records held in Warehouse 1, 3 or 5 only.
SELECT stock_id, product_id, warehouse_id, quantity
FROM stock
WHERE warehouse_id IN (1, 3, 5);


-- Q9. Find every product whose name starts with the letter "C".
SELECT product_name
FROM products
WHERE product_name LIKE 'C%';


-- Q10. List all products sorted alphabetically by category, and within each category, most expensive first.
SELECT product_name, category, unit_price
FROM products
ORDER BY category ASC, unit_price DESC;


-- Q11. Find the 5 most expensive products in the entire catalog.
SELECT product_name, unit_price
FROM products
ORDER BY unit_price DESC
LIMIT 5;


-- Q12. Show each product's price rounded to a whole dollar, andwhat a 10-unit purchase would cost (price * quantity math).
SELECT
    product_name,
    unit_price,
    ROUND(unit_price)              AS price_rounded,
    ROUND(unit_price * 10, 2)      AS cost_for_10_units
FROM products;


-- Q13. Display product names in ALL CAPS and category names inlowercase, for a uniform label format.
SELECT
    UPPER(product_name)  AS name_upper,
    LOWER(category)      AS category_lower
FROM products;


-- Q14. Build a single readable label combining SKU and productname, and show how many characters are in each name.
SELECT
    CONCAT(sku, ' - ', product_name)  AS product_label,
    LENGTH(product_name)              AS name_length
FROM products;


-- Q15. Show only the first 3 letters of each product name(useful for generating short internal codes).
SELECT
    product_name,
    SUBSTRING(product_name FROM 1 FOR 3) AS short_code
FROM products;


-- Q16. For every stock movement, show how many days ago it happened and extract just the year it occurred in.
SELECT
    movement_id,
    movement_date,
    AGE(CURRENT_DATE, movement_date::date)   AS time_since_movement,
    EXTRACT(YEAR FROM movement_date)         AS movement_year
FROM stock_movements;


-- Q17. List products and their supplier_id, but displayNo Supplier Assigned" instead of a blank/NULL value.
SELECT
    product_name,
    COALESCE(supplier_id::text, 'No Supplier Assigned') AS supplier_info
FROM products
WHERE supplier_id IS NULL
   OR supplier_id IS NOT NULL;


-- Q18. Find the 5 cheapest Electronics or Hardware & Tools products that are NOT priced below $10 — a combined filter using
SELECT
    product_name,
    category,
    unit_price
FROM products
WHERE (category = 'Electronics' OR category = 'Hardware & Tools')
  AND unit_price >= 10
ORDER BY unit_price ASC
LIMIT 5;

