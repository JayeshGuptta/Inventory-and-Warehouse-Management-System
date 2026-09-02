# Inventory and Warehouse Management System

**Platform:** PostgreSQL (pgAdmin4)
**Status:** Schema, data, core queries, views, and triggers complete. Stored procedure (stock transfer) pending.

---

## 1. Business Problem

A company operating multiple warehouses needs one reliable system to answer:

- What products do we stock, and who supplies them?
- How much of each product is sitting in each warehouse right now?
- Which items are running low and need to be reordered?
- When stock moves — in, out, between warehouses, or gets corrected — is there a record of it?

This project builds that system as a relational database: clean schema, realistic sample data, and a growing library of queries, views, and automation (triggers) that answer the questions above without manual spreadsheet work.

---

## 2. Schema Overview (ER Diagram)

The diagram (`ER_Diagram.png`, generated from pgAdmin4's ERD tool) shows five tables and four relationships:

```
suppliers ──1:M── products ──1:M── stock ──M:1── warehouses
                                       │
                                       │ (also referenced by)
                                       │
                                stock_movements ──M:1── warehouses (x2: from / to)
```

| Table | What it represents | Primary Key | Foreign Keys |
|---|---|---|---|
| `suppliers` | Vendors the company buys from | `supplier_id` | — |
| `warehouses` | Physical storage locations | `warehouse_id` | — |
| `products` | Product catalog | `product_id` | `supplier_id` → `suppliers` |
| `stock` | How much of a product sits in a given warehouse (junction table) | `stock_id` | `product_id` → `products`, `warehouse_id` → `warehouses` |
| `stock_movements` | Audit log of every inbound, outbound, transfer, or adjustment | `movement_id` | `product_id` → `products`, `from_warehouse_id` → `warehouses`, `to_warehouse_id` → `warehouses` |

**Why `stock` is its own table:** a product can exist in multiple warehouses, and a warehouse holds many products — that's a many-to-many relationship. `stock` resolves it into two one-to-many relationships, with a `UNIQUE(product_id, warehouse_id)` constraint so the same product/warehouse pair can never be duplicated — there's exactly one row of "truth" for how much of a product sits in a given warehouse.

**Why `stock_movements` is separate from `stock`:** `stock` only holds the *current* quantity. `stock_movements` is the *history* — every event that changed that quantity, when it happened, and why (`INBOUND`, `OUTBOUND`, `TRANSFER`, `ADJUSTMENT`). Without this table, there'd be no way to answer "what happened to this stock over time," only "what is true right now."

### Constraints doing real work
- `CHECK (quantity >= 0)` on `stock` — stock can never go negative
- `CHECK (unit_price >= 0)` and `CHECK (reorder_level >= 0)` on `products`
- `UNIQUE (sku)` and `UNIQUE (email)` — no duplicate product codes or supplier emails
- A compound `CHECK` on `stock_movements` ensures a `TRANSFER` row always has two *different* warehouses filled in — you can't "transfer" stock to nowhere or to itself
- `ON DELETE SET NULL` on `products.supplier_id` — deleting a supplier doesn't delete their products, it just clears the link
- `ON DELETE CASCADE` on `stock.product_id`/`warehouse_id` — deleting a product or warehouse cleans up its stock rows automatically

---

## 3. Sample Data

Loaded via `InsertCommand.sql` — sized deliberately mid-range so aggregate queries (GROUP BY, window functions) return meaningful, varied results instead of trivial 2-3 row outputs:

| Table | Row count | Notes |
|---|---|---|
| `suppliers` | 10 | Spread across 10 countries |
| `warehouses` | 5 | India-based distribution network |
| `products` | 50 | 5 categories: Electronics, Grocery, Apparel, Furniture, Hardware & Tools |
| `stock` | 134 | Each product sits in 2–4 warehouses; ~20% of rows intentionally below the product's `reorder_level`, so low-stock queries have real matches to return |
| `stock_movements` | 35 | Mix of all four movement types, so `GROUP BY movement_type` and time-based window functions have something to work with |

---

## 4. What Each Delivered File Does

### `Tables&IndexCommand.sql` — Schema
All five `CREATE TABLE` statements with full constraints, plus indexes on foreign key and frequently-filtered columns (`category`, `movement_date`) — Postgres does **not** auto-index foreign keys the way primary keys are indexed, so these were added deliberately for join/lookup performance.

### `InsertCommand.sql` — Sample Data
The mid-size dataset described above, loaded in dependency order (suppliers → warehouses → products → stock → stock_movements) so every foreign key reference is valid.

### `BasicCommands.sql` — 18 Core SQL Questions
Covers the fundamentals: `SELECT`/`FROM`/`AS` (column renaming), `WHERE` with comparison operators (`>`, `BETWEEN`, `IN`) and logical operators (`AND`, `OR`, `NOT`), `ORDER BY`, `LIMIT`, and numeric (`ROUND`), text (`UPPER`, `LOWER`, `CONCAT`, `LENGTH`, `SUBSTRING`, `LIKE`), and date (`EXTRACT`, `AGE`, `CURRENT_DATE`) functions. Also demonstrates `COALESCE` for handling `NULL` supplier links gracefully.

### `GroupBy&Sets.sql` — 12 Aggregation & Set-Operation Questions
- **Q1–Q8:** `GROUP BY` and `HAVING` — counting products per category, average pricing, total stock per warehouse, and filtering aggregated results (e.g., "warehouses holding under 3,000 total units," "suppliers with more than 4 products averaging over $100").
- **Q9–Q12:** Set operations — `UNION` (combine + dedupe), `UNION ALL` (combine + keep duplicates, shown side-by-side with UNION for contrast), `INTERSECT` (products that are both expensive *and* currently low-stock — the highest-priority reorder candidates), `EXCEPT` (products that have never had a single movement logged — a data-quality/dead-stock check).

### `Window Function.sql` — 11 Window Function Questions
Covers ranking (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`), row-to-row comparison (`LAG`, `LEAD`), running totals (`SUM() OVER` with an explicit frame), group comparison without collapsing rows (`AVG() OVER (PARTITION BY ...)`), boundary values (`FIRST_VALUE`, `LAST_VALUE` — including the classic gotcha where `LAST_VALUE` needs an explicit full-partition frame or it silently returns the wrong answer), and relative positioning (`PERCENT_RANK`).

### `View&Trigger.sql` — 5 Views + 6 Triggers
**Views** (read-only, reusable "saved queries"):
- `vw_current_stock` — stock levels with names instead of raw IDs
- `vw_low_stock_alert` — pre-filtered list of understocked items
- `vw_warehouse_inventory_value` — total inventory value per warehouse
- `vw_supplier_summary` — supplier product counts and average pricing
- `vw_movement_log` — readable version of the movement audit trail

**Triggers** (automated reactions to data changes):
- Auto-stamp `last_updated` when a stock quantity changes
- Auto-log manual quantity edits into `stock_movements` as an `ADJUSTMENT`, so the audit trail never has gaps
- Block negative stock quantities with a clear custom error
- **Auto-insert into `low_stock_alerts`** whenever a stock update drops quantity below the product's reorder level — this is the low-stock notification trigger from the original project brief
- Block deleting a supplier that still has linked products
- Block deleting a warehouse that still holds stock

---

## 5. Outcomes Achieved So Far

- ✅ A normalized, constraint-enforced relational schema (5 tables, all keys and relationships in place)
- ✅ A realistic mid-size dataset suitable for meaningful analysis, not just toy examples
- ✅ 18 foundational queries covering filtering, sorting, and text/date/numeric functions
- ✅ 12 queries covering aggregation (`GROUP BY`/`HAVING`) and set operations
- ✅ 11 queries covering window functions for ranking, trends, and comparisons
- ✅ 5 views that turn raw joined data into ready-to-use reports
- ✅ 6 triggers automating timestamping, audit logging, validation, and — the project's core automation requirement — **low-stock notifications**

## 6. Still Outstanding

- ⬜ **Stored procedure** to transfer stock between warehouses (atomic, transaction-safe — deduct from source, add to destination, log the movement)
- ⬜ Final consolidated schema/query documentation pass (this README covers it at a project level; per-query inline comments already exist in each `.sql` file)

---

*Run order for a fresh database: `Tables&IndexCommand.sql` → `InsertCommand.sql` → `View&Trigger.sql` → then any of the query files.*
