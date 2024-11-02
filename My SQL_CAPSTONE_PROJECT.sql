CREATE TABLE IF NOT EXISTS Stores (
	store_ID INT PRIMARY KEY,
	store_Name VARCHAR (200),
	store_city VARCHAR (200),
	store_location VARCHAR (150),
	store_open_date DATE
	);

CREATE TABLE sales (
	Sale_ID INT PRIMARY KEY,
	DATE DATE,
	Store_ID INT,
	Product_ID INT,
	Units INT
	
)

SELECT * FROM sales

	
SELECT * FROM inventory;

SELECT * FROM products;

SELECT * FROM stores;

/* QUESTION 1 Which product category drive the biggest profits? 
Is this the same across store location. */

-- Calculate total profit per product(Considering stock on Hand)
CREATE TABLE product_category_with_highest_product AS (
SELECT 
	p.product_category,
	SUM((p.product_price - p.product_cost) * sa.units) AS total_profit
FROM
	products p
JOIN
	sales sa 
ON
	p.product_id = sa.product_id  --Joining the two tables together using the common columns
GROUP BY 
	p.product_category
ORDER BY 
	total_profit DESC
LIMIT 1

);
--ANOTHER WAY OF SOLVING THIS

WITH product_category_profit AS(
	SELECT
		p.product_category,
		SUM((p.product_price - p.product_cost) * sa.units) AS total_profit
	FROM 
		sales sa
	JOIN
		products p ON sa.product_id = p.product_id
	GROUP BY 
		p.product_category
)
SELECT 
	product_category,
	total_profit
FROM 
	product_category_profit
ORDER BY
	total_profit DESC
LIMIT 1;

-- Answer: Toys is the product category that drives the biggest profit.

---Last step. Check profit per product category across store location

CREATE TABLE profit_across_store AS (
WITH profit_per_category AS (
	SELECT
		s.store_id,
		s.store_name,
		p.product_category,
		SUM((p.product_price - p.product_cost) * sa.units) AS total_profit
	FROM
		sales sa
	JOIN
		stores s ON s.store_id = sa.store_id
	JOIN
		products p ON p.product_id = sa.product_id
	GROUP BY
		s.store_id,s.store_name,p.product_category
),
ranked_profits AS (
	SELECT
		store_id,
		store_name,
		product_category,
		total_profit,
		RANK() OVER (PARTITION BY store_id ORDER BY total_profit DESC) AS profit_rank
	FROM
		profit_per_category
)
SELECT
	store_id,
	store_name,
	product_category,
	total_profit
FROM
	ranked_profits
WHERE
	profit_rank = 1
ORDER BY total_profit DESC

)
/* QUESTION NUMBER 2.

How much money is tied up in inventory at the toy stores? how long will it last? */
CREATE TABLE money_store_in_inventory_toy_store AS (
SELECT
	s.store_name,
	s.store_city,
	SUM(i.stock_on_hand * p.product_cost) AS inventory_by_value
FROM products p
JOIN 
	inventory i
ON
	p.product_id = i.product_id
JOIN
	stores s
ON 
	i.store_id = s.store_id
WHERE
	p.product_category = 'Toys'
GROUP BY 
	s.store_name, s.store_city
ORDER BY 
	inventory_by_value DESC
);

--How long will it last?

CREATE TABLE estimated_period AS (
WITH toy_inventory AS (
	SELECT
		s.store_id,
		s.store_name,
		p.product_id,
		p.product_category,
		i.stock_on_hand,
		p.product_cost,
		(p.product_cost * i.stock_on_hand) AS inventory_value
	FROM 
		inventory i
	JOIN
		stores s ON s.store_id = i.store_id
	JOIN
		products p ON p.product_id =i.product_id
	WHERE
		p.product_category = 'Toys'
),
total_sales_last_30_days AS (
	SELECT
		sa.store_id,
		sa.product_id,
		SUM(sa.units) AS total_units_sold
	FROM 
		sales sa
	WHERE 
		sa.date >= NOW() - INTERVAL '30 days'
	GROUP BY 
		sa.store_id, sa.product_id
)

SELECT 
	ti.store_id,
	ti.store_name,
	SUM(ti.stock_on_hand / COALESCE(ts.total_units_sold, 1)) AS estimated_days_of_inventory
FROM 
	toy_inventory ti
LEFT JOIN
	total_sales_last_30_days ts ON ti.store_id = ts.store_id AND ti.product_id = ts.product_id
GROUP BY ti.store_id, ti.store_name
);


/* Question 3
Are sales being lost with out_of_stock products at certain locations?
*/

select * from products

CREATE TABLE lost_sales_in_locations AS (
WITH out_of_stock_products AS (
	SELECT
		i.store_id,
		i.product_id,
		p.product_name,
		st.store_name,
		st.store_city,
		st.store_location
	FROM
		inventory i
	JOIN
		stores st ON i.store_id = st.store_id
	JOIN
		products p ON p.product_id = i.product_id 
	WHERE 
		i.stock_on_hand = 0 --These are product that are out of stock
),
sales_attempts AS (        
	SELECT 
		sa.store_id,
		sa.product_id,
		COUNT(sa.sale_id) AS sales_count
	FROM
		sales sa
	GROUP BY
		sa.store_id, sa.product_id
)
SELECT
	oos.store_id,
	oos.store_name,
	oos.store_city,
	oos.store_location,
	oos.product_name,
	oos.product_id,
	s.sales_count
FROM out_of_stock_products oos
JOIN 
	sales_attempts s ON oos.store_id = s.store_id AND
	oos.product_id = s.product_id
WHERE
	s.sales_count > 0  ---attempted sales for out of stock products
/* From the query above, we could see the count of out of stock product we have. This implies 
potential lost of sales as the stores have no stock for thos products when the sales attempts
were made*/
);
