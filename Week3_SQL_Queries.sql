-- ==========================================
-- WEEK 3: SQL & DATA QUERYING
-- AnalystLab Africa Internship
-- ==========================================

-- ==========================================
-- PART 1: CHINOOK DATABASE
-- ==========================================

-- Task 2: Core SQL Queries

-- Retrieving all album titles by artist_id 84, sorted Z to A
SELECT title
FROM album
WHERE artist_id = 84
ORDER BY title DESC;

-- Listing all customers with their city, sorted by city
SELECT first_name, last_name, city
FROM customer
ORDER BY city;

-- Finding cities that have more than 1 customer
SELECT city, COUNT(*) AS total_customers
FROM customer
GROUP BY city
HAVING COUNT(*) > 1
ORDER BY total_customers DESC;

-- Getting the total sales made from the invoice table
SELECT SUM(total) AS total_revenue
FROM invoice;

-- Getting the average length of a track
SELECT AVG(milliseconds) AS avg_track_length_ms
FROM track;

-- Getting the total number of tracks that have a composer listed
SELECT COUNT(composer) AS tracks_with_composer
FROM track;

-- Task 3: Advanced SQL Concepts

-- Showing all customers, including those who have never made a purchase
-- LEFT JOIN keeps every row from the left table (customer), even without a match
SELECT c.first_name, c.last_name, i.invoice_id, i.total
FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
ORDER BY c.last_name;

-- Showing which artist made each track, by joining through album
SELECT t.name AS track_name, al.title AS album_title, ar.name AS artist_name
FROM track t
INNER JOIN album al ON t.album_id = al.album_id
INNER JOIN artist ar ON al.artist_id = ar.artist_id
ORDER BY ar.name;

-- Showing every album, even ones with no tracks recorded (if any exist)
SELECT al.title, t.name AS track_name
FROM track t
RIGHT JOIN album al ON t.album_id = al.album_id
ORDER BY al.title;

-- Finding invoices above the average invoice total
SELECT invoice_id, customer_id, total
FROM invoice
WHERE total > (SELECT AVG(total) FROM invoice)
ORDER BY total DESC;

-- Assigning a sequential number to each customer's invoices, ordered by total spent
SELECT customer_id, invoice_id, total,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total DESC) AS invoice_rank
FROM invoice;

-- Ranking each customer's invoices by total, then filtering to just their top one
SELECT *
FROM (
    SELECT customer_id, invoice_id, total,
           RANK() OVER (PARTITION BY customer_id ORDER BY total DESC) AS invoice_rank
    FROM invoice
) ranked_invoices
WHERE invoice_rank = 1;

-- Comparing each invoice to that customer's own average invoice total
SELECT customer_id, invoice_id, total,
       AVG(total) OVER (PARTITION BY customer_id) AS customer_avg_total
FROM invoice
ORDER BY customer_id;

-- Ranking all invoices from highest to lowest, across every customer
SELECT customer_id, invoice_id, total,
       RANK() OVER (ORDER BY total DESC) AS overall_rank
FROM invoice;


-- ==========================================
-- PART 2: SALES DATASET
-- ==========================================

-- Task 2: Core SQL Queries

-- Initial look at the raw sales data after import
SELECT * FROM sales;

-- Finding all orders with a deal size of 'Large'
SELECT ordernumber, customername, sales, dealsize
FROM sales
WHERE dealsize = 'Large'
ORDER BY sales DESC;

-- Listing all orders sorted by sales amount, highest first
SELECT ordernumber, customername, sales
FROM sales
ORDER BY sales DESC;

-- Calculating total sales revenue by product line
SELECT productline, SUM(sales) AS total_sales
FROM sales
GROUP BY productline
ORDER BY total_sales DESC;

-- Finding countries that generated more than $500,000 in total sales
SELECT country, SUM(sales) AS total_sales
FROM sales
GROUP BY country
HAVING SUM(sales) > 500000
ORDER BY total_sales DESC;

-- Note: Sales is a single flat table with no foreign key relationships,
-- so joins and subqueries against related tables do not apply here the
-- way they do for Chinook. Aggregate and grouping queries above cover
-- Task 2 requirements for this dataset.


-- ==========================================
-- TASK 4: BUSINESS PROBLEM SOLVING
-- ==========================================

-- CHINOOK

-- Finding the top 10 customers by total amount spent
SELECT c.first_name, c.last_name, SUM(i.total) AS total_spent
FROM customer c
INNER JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_spent DESC
LIMIT 10;
-- Helena Holy is the highest spending customer with a total spend of 49.62
-- Astrid Grubler is the lowest spending customer in the top 10 with a value of 42.62

-- Finding the 10 best-selling tracks by quantity sold
SELECT t.name AS track_name, SUM(il.quantity) AS total_sold
FROM invoice_line il
INNER JOIN track t ON il.track_id = t.track_id
GROUP BY t.name
ORDER BY total_sold DESC
LIMIT 10;
-- The Tropper was the highest-selling track with a quantity of 5
-- Eruption, The Number Of The Beast, Untitled, Sure Know Something, and
-- Hallowed Be Thy Name follow closely behind with 4 each

-- Calculating total revenue by year
SELECT EXTRACT(YEAR FROM invoice_date) AS year, SUM(total) AS yearly_revenue
FROM invoice
GROUP BY EXTRACT(YEAR FROM invoice_date)
ORDER BY year;
-- Revenue stayed fairly consistent year over year (449-481), with 2022 slightly
-- ahead at 481.45. No strong growth or decline trend across the 5 year period.

-- SALES

-- Finding total quantity sold by product line
SELECT productline, SUM(quantityordered) AS total_quantity_sold
FROM sales
GROUP BY productline
ORDER BY total_quantity_sold DESC;
-- Classic Cars were the highest quantity product line (33,992 units sold),
-- followed by Vintage Cars and Motorcycles

-- Finding the top 10 customers by total sales revenue
SELECT customername, SUM(sales) AS total_spent
FROM sales
GROUP BY customername
ORDER BY total_spent DESC
LIMIT 10;
-- Euro Shopping Channel has the highest total spend of all customers

-- Comparing average sales amount across different deal sizes
SELECT dealsize, AVG(sales) AS avg_order_value, COUNT(*) AS number_of_orders
FROM sales
GROUP BY dealsize
ORDER BY avg_order_value DESC;
-- Large deals: highest average order value (8,293.75), but fewest orders (157)
-- Medium deals: most orders by far (1,384), moderate average (4,398.43)
-- Small deals: lowest average (2,061.68), but still a substantial 1,282 orders
-- Medium and Small deals drive order volume, while Large deals bring in
-- disproportionately more revenue per transaction


-- ==========================================
-- TASK 5: QUERY OPTIMIZATION
-- ==========================================

-- CHINOOK

-- Checking query performance before adding an index on customer_id
EXPLAIN ANALYZE
SELECT * FROM invoice WHERE customer_id = 5;

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'invoice';
-- Confirms invoice_customer_id_idx already existed from Chinook's original
-- setup script, this is why the customer_id query showed an Index Scan
-- from the start, not because we added anything ourselves.

-- Checking query performance before adding an index on billing_country
EXPLAIN ANALYZE
SELECT * FROM invoice WHERE billing_country = 'USA';
-- Baseline: Seq Scan, 91 rows matched, 321 rows filtered out,
-- Execution Time 0.164 ms. No index exists yet on billing_country.

-- Adding an index on billing_country to speed up country-based lookups
CREATE INDEX idx_invoice_billing_country ON invoice(billing_country);

-- Re-running the same query to compare performance after indexing
EXPLAIN ANALYZE
SELECT * FROM invoice WHERE billing_country = 'USA';
-- After creating idx_invoice_billing_country, Postgres still chose a Seq Scan
-- rather than using the new index. This is expected behaviour on a small
-- table (412 rows), the query planner calculated that scanning the whole
-- table directly was cheaper than the overhead of using an index. Indexes
-- provide their real performance benefit on large datasets, where skipping
-- most of the table saves meaningful time; on small tables like this one,
-- the planner correctly determines an index isn't worth using.

SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'invoice';
-- Confirms idx_invoice_billing_country was successfully created, three
-- indexes now exist on invoice: the primary key, the pre-existing
-- customer_id index, and our new billing_country index.

-- SALES
-- The Sales dataset is a single flat table with no foreign key relationships,
-- so joins and relational indexing don't apply the same way. The same
-- indexing principle still holds though, an index on a frequently filtered
-- column like productline or country would speed up WHERE and GROUP BY
-- queries as the dataset scales.
CREATE INDEX idx_sales_productline ON sales(productline);