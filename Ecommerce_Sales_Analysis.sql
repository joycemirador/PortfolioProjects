-- BRAZILIAN E-COMMERCE SALES ANALYSIS DATA PREPARATION

SELECT * FROM customers;
SELECT * FROM geolocation;
SELECT * FROM order_items;
SELECT * FROM order_payments;
SELECT * FROM orders;
SELECT * FROM products;
SELECT * FROM product_category_translation;


-- COMBINE TABLES

-- Check if the sum of product price and freight value is equal to customers' transaction value
WITH t1 AS 
(
	SELECT *, (payment_value - total_order_value) AS difference
	FROM (
		SELECT oi.order_id, 
			ROUND(((oi.price * oi.order_item_id) + (oi.freight_value * oi.order_item_id)),2) AS total_order_value,
			op.payment_value,
			(CASE WHEN op.payment_installments > 1 THEN 'Yes' ELSE 'No' END) AS installment
		FROM order_items as oi
		LEFT JOIN order_payments AS op ON oi.order_id = op.order_id
        ) AS oi_op
	WHERE total_order_value != payment_value
)
SELECT COUNT(*)
FROM t1
WHERE installment = 'No';

/* 24,703 out of 117,601 rows, or 21% of the data, have a different total order value from customers' transaction value. 
It has no relationship with payment installments since 13,702 out of 24,703 rows have no installments. 

Sales will be represented by the total item price only since freight value is paid to the logistic partner. */


-- Create a new table that has all the key columns needed to conduct the analysis

	-- Investigate duplicates under the geolocation table
SELECT *, ROUND(geolocation_lat, 2) AS rnd_lat, ROUND(geolocation_lng, 2) AS rnd_lng
FROM geolocation
WHERE geolocation_zip_code_prefix = 1031;
    
	/* There are multiple entries of latitude and longitude recorded for a single zip code.
	When these columns are rounded off, the only difference between the entries is -0.01. */
  
DROP TABLE IF EXISTS sales_data;

CREATE TABLE sales_data AS
WITH geolocation AS
(
	SELECT geolocation_zip_code_prefix, 
	AVG(geolocation_lat) AS geolocation_lat, -- to retain only one entry per zip code
    AVG(geolocation_lng) AS geolocation_lng,
    MAX(geolocation_city) AS geolocation_city,
    MAX(geolocation_state) AS geolocation_state
	FROM geolocation
	GROUP BY geolocation_zip_code_prefix
)
SELECT p.product_id, pct.product_category_name_english AS product_category_name,
	oi.order_id, oi.order_item_id, oi.price, oi.freight_value,
    o.order_purchase_timestamp, o.customer_id,
    c.customer_unique_id, c.customer_zip_code_prefix AS customer_zip_code,
    g.geolocation_lat, g.geolocation_lng, g.geolocation_city, g.geolocation_state
FROM product_category_translation AS pct
RIGHT JOIN products AS p
ON pct.product_category_name = p.product_category_name
RIGHT JOIN order_items AS oi
ON p.product_id = oi.product_id
LEFT JOIN orders AS o
ON oi.order_id = o.order_id
LEFT JOIN customers AS c
ON o.customer_id = c.customer_id
LEFT JOIN geolocation AS g
ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix;



-- DATA CLEANING AND TRANSFORMATION

-- Delete rows with null values
DELETE FROM sales_data
WHERE product_category_name IS NULL OR
	price IS NULL OR
	order_purchase_timestamp IS NULL OR 
	customer_zip_code IS NULL OR
	product_category_name = '' OR
	price = '' OR
	order_purchase_timestamp = '' OR 
	customer_zip_code = '';
    

-- Update geolocation data
/* Brazil zip code data was from back4app.com and was processed in Python.
See the 'BR_zipcodes.ipynb' file for the data cleaning process. */
    
    -- Load the BR zip code data into the br_zipcode table
LOAD DATA LOCAL INFILE '../../../../../../br_zipcodes.csv'
INTO TABLE br_zipcodes
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(postalCode, placeName, latitude, longitude);

UPDATE sales_data AS sd
LEFT JOIN br_zipcodes AS zc ON sd.customer_zip_code = zc.postalCode
SET sd.geolocation_lat = zc.latitude, sd.geolocation_lng = zc.longitude, sd.geolocation_city = zc.placeName
WHERE sd.geolocation_lat IS NULL OR
	sd.geolocation_lng IS NULL OR
    sd.geolocation_city IS NULL OR
	sd.geolocation_state IS NULL OR
    sd.geolocation_lat = '' OR
	sd.geolocation_lng = '' OR
    sd.geolocation_city = '' OR
	sd.geolocation_state = '';

/* There is no available record for the geolocation state in the br_zipcodes table.
A Brazil state and city file will be saved to update the geolocation state. */	
SELECT DISTINCT(geolocation_state), geolocation_city
FROM sales_data
WHERE geolocation_state IS NOT NULL AND
	geolocation_city IS NOT NULL;

UPDATE sales_data AS sd
LEFT JOIN br_state_city AS sc ON sd.geolocation_city = sc.geolocation_city
SET sd.geolocation_state = sc.geolocation_state
WHERE sd.geolocation_state IS NULL OR
	sd.geolocation_state = '';
/* Only 8 out of 13 rows are updated. */

UPDATE sales_data
SET geolocation_state = 'SP'
WHERE geolocation_city = 'borá';
UPDATE sales_data
SET geolocation_state = 'PB'
WHERE geolocation_city = 'passagem';
UPDATE sales_data
SET geolocation_state = 'RS'
WHERE geolocation_city = 'mampituba';
UPDATE sales_data
SET geolocation_state = 'SE'
WHERE geolocation_city = 'itabi';
UPDATE sales_data
SET geolocation_state = 'MA'
WHERE geolocation_city = 'sambaíba';

	-- Delete remaining null values
DELETE FROM sales_data
WHERE geolocation_lat IS NULL OR
	geolocation_lng IS NULL OR
    geolocation_city IS NULL OR
	geolocation_state IS NULL OR
    geolocation_lat = '' OR
	geolocation_lng = '' OR
    geolocation_city = '' OR
	geolocation_state = '';


-- Remove duplicates
/* Having the same order_id and order_purchase_timestamp means that the data are duplicates. 
Create another table for all the order_ids with duplicates as a workaround for MySQL GROUP BY fetching time. */
SELECT order_id
FROM sales_data
GROUP BY order_id
HAVING COUNT(order_id) > 1;

SELECT *
FROM sales_data
WHERE order_id IN 
(
	SELECT order_id
    FROM order_id_duplicates
);
/* Upon inspecting the duplicates, order_item_ids are an identifier for the different products included in a single order. 
Some rows look duplicates because the customer bought more than one quantity of the same product. */


-- Convert order_purchase_timestamp into a datetime data type
ALTER TABLE sales_data
MODIFY order_purchase_timestamp DATETIME;



-- EXPLORATORY DATA ANALYSIS

-- Number of product categories
SELECT COUNT(DISTINCT(product_category_name))
FROM sales_data;


-- Top 10 Product Categories with the Highest Revenue
SELECT product_category_name, ROUND(SUM(price), 2) AS revenue
FROM sales_data
GROUP BY product_category_name
ORDER BY revenue DESC
LIMIT 10;


-- Top 10 Product Categories with the Highest Number of Orders
SELECT product_category_name, COUNT(price) AS num_of_orders
FROM sales_data
GROUP BY product_category_name
ORDER BY num_of_orders DESC
LIMIT 10;


-- Number of orders
SELECT COUNT(DISTINCT(order_id))
FROM sales_data;


-- Average Order Value (AOV)
SELECT ROUND(AVG(t2.total_price), 2) AS avg_order_value
FROM sales_data AS sd
LEFT JOIN (
	SELECT order_id, SUM(price) AS total_price
	FROM sales_data
	GROUP BY order_id
) AS t2
ON sd.order_id = t2.order_id;


-- Sales Trends over Time
	-- Yearly sales
SELECT YEAR(order_purchase_timestamp) AS `year`, ROUND(SUM(price), 2) AS total_sales, 
	COUNT(DISTINCT(order_id)) AS num_of_orders
FROM sales_data
GROUP BY `year`;

	-- Monthly sales
SELECT YEAR(order_purchase_timestamp) AS `year`, MONTH(order_purchase_timestamp) AS `month`,
	ROUND(SUM(price), 2) AS total_sales, COUNT(DISTINCT(order_id)) AS num_of_orders
FROM sales_data
GROUP BY `year`, `month`
ORDER BY `year`, `month`;
/* Based on the results, there are only a few orders from 2016 and one order from Sept. 2018. Conducting the monthly 
sales analysis is more accurate since only 2017 has adequate data for all months. */


-- Customer Segmentation by Sales
/* High Spenders: Total_spent > R$1000
Medium Spenders: Total_spent between R$500 and R$1000
Low Spenders: Total_spent < R$500 

Frequent Buyers: More than 10 orders
Occasional Buyers: 5 to 10 orders
Rare Buyers: Less than 5 orders
*/
DROP TABLE IF EXISTS customer_segment_sales_data;

CREATE TABLE customer_segment_sales_data AS
SELECT customer_segment.*,
	MAX(sd.customer_zip_code) AS customer_zip_code, 
	MAX(sd.geolocation_city) AS geolocation_city, 
    MAX(sd.geolocation_state) AS geolocation_state,
    MAX(sd.geolocation_lat) AS geolocation_lat, 
    MAX(sd.geolocation_lng) AS geolocation_lng
FROM (
	SELECT customer_unique_id, 
		ROUND(SUM(price), 2) AS total_spending, 
		(CASE 
			WHEN SUM(price) > 1000 THEN 'High'
			WHEN SUM(price) <= 1000 AND SUM(price) >= 500 THEN 'Medium'
			ELSE 'Low'
		END) AS spending_segment,
		COUNT(order_id) AS num_of_orders,
		(CASE 
			WHEN COUNT(order_id) > 10 THEN 'Frequent'
			WHEN COUNT(order_id) <= 10 AND COUNT(order_id) >= 5 THEN 'Occassional'
			ELSE 'Rare'
		END) AS frequency_segment
	FROM sales_data
	GROUP BY customer_unique_id
) AS customer_segment
LEFT JOIN sales_data AS sd
ON customer_segment.customer_unique_id = sd.customer_unique_id
GROUP BY customer_segment.customer_unique_id;
	
	-- Count spending segments
SELECT spending_segment, COUNT(*)
FROM customer_segment_sales_data
GROUP BY spending_segment;

	-- Count frequency segments
SELECT frequency_segment, COUNT(*)
FROM customer_segment_sales_data
GROUP BY frequency_segment;
/* Over 90,000 of customers are low spenders and rare buyers. */


-- Regional Sales Performance
	-- Total Revenue, Orders and Customers per State
SELECT geolocation_state, ROUND(SUM(total_spending), 2) AS total_revenue, COUNT(num_of_orders) AS total_orders
FROM customer_segment_sales_data
GROUP BY geolocation_state
ORDER BY total_revenue DESC;

	-- Top 20 Cities with the Highest Revenue
SELECT geolocation_city, geolocation_state, 
	ROUND(SUM(total_spending), 2) AS total_revenue, COUNT(num_of_orders) AS total_orders
FROM customer_segment_sales_data
GROUP BY geolocation_city, geolocation_state
ORDER BY total_revenue DESC
LIMIT 20;

		-- Top 20 Cities with the Highest Orders
SELECT geolocation_city, geolocation_state, COUNT(num_of_orders) AS total_orders
FROM customer_segment_sales_data
GROUP BY geolocation_city, geolocation_state
ORDER BY total_orders DESC
LIMIT 20;




