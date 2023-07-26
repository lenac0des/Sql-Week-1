-- Creating the tables

CREATE TABLE sales (
customer_id varchar(1),
order_date date,
product_id int
);

CREATE TABLE menu (
product_id int,
product_name varchar(5),
price int
);


CREATE TABLE members (
customer_id varchar(1),
join_date date
);


-- Inserting values into the tables

INSERT INTO sales
(customer_id, order_date, product_id)
VALUES
('A', '2021-01-01', '1'),
('A', '2021-01-01', '2'),
('A', '2021-01-07', '2'),
('A', '2021-01-10', '3'),
('A', '2021-01-11', '3'),
('A', '2021-01-11', '3'),
('B', '2021-01-01', '2'),
('B', '2021-01-02', '2'),
('B', '2021-01-04', '1'),
('B', '2021-01-11', '1'),
('B', '2021-01-16', '3'),
('B', '2021-02-01', '3'),
('C', '2021-01-01', '3'),
('C', '2021-01-01', '3'),
('C', '2021-01-07', '3')


INSERT INTO menu 
(product_id, product_name, price)
VALUES
('1', 'sushi', '10'),
('2', 'curry', '15'),
('3', 'ramen', '12')



INSERT INTO members
(customer_id, join_date)
VALUES
('A', '2021-01-07'),
('B', '2021-01-09')

-- Case Study Questions

-- 1. What is the total amount each customer spent at the restaurant?
SELECT sales.customer_id, SUM(menu.price) AS total_sales
FROM sales
JOIN menu
	ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS visit_count
FROM sales
GROUP BY customer_id;


-- 3. What was the first item from the menu purchased by each customer?
WITH ordered_sales AS (
  SELECT 
    sales.customer_id, 
    sales.order_date, 
    menu.product_name,
    DENSE_RANK() OVER(
      PARTITION BY sales.customer_id 
      ORDER BY sales.order_date) AS rank
  FROM sales
  JOIN menu
    ON sales.product_id = menu.product_id
)

SELECT 
  customer_id, 
  product_name
FROM ordered_sales
WHERE rank = 1
GROUP BY customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT 
  menu.product_name,
  COUNT(sales.product_id) AS most_purchased_item
FROM sales
JOIN menu
  ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY most_purchased_item DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH most_popular AS (
  SELECT 
    sales.customer_id, 
    menu.product_name, 
    COUNT(menu.product_id) AS order_count,
    DENSE_RANK() OVER(
      PARTITION BY sales.customer_id 
      ORDER BY COUNT(sales.customer_id) DESC) AS rank
  FROM menu
  JOIN sales
    ON menu.product_id = sales.product_id
  GROUP BY sales.customer_id, menu.product_name
)

SELECT 
  customer_id, 
  product_name, 
  order_count
FROM most_popular 
WHERE rank = 1;


-- 6. Which item was purchased first by the customer after they became a member?
WITH joined_as_member AS (
  SELECT
    members.customer_id, 
    sales.product_id,
    ROW_NUMBER() OVER(
      PARTITION BY members.customer_id
      ORDER BY sales.order_date) AS row_num
  FROM members
  JOIN sales
    ON members.customer_id = sales.customer_id
    AND sales.order_date > members.join_date
)

SELECT 
  customer_id, 
  product_name 
FROM joined_as_member
JOIN menu
  ON joined_as_member.product_id = menu.product_id
WHERE row_num = 1
ORDER BY customer_id ASC;

-- 7. Which item was purchased just before the customer became a member?
WITH purchased_prior_member AS (
  SELECT 
    members.customer_id, 
    sales.product_id,
    ROW_NUMBER() OVER(
       PARTITION BY members.customer_id
       ORDER BY sales.order_date DESC) AS rank
  FROM members
  JOIN sales
    ON members.customer_id = sales.customer_id
    AND sales.order_date < members.join_date
)

SELECT 
  p_member.customer_id, 
  menu.product_name 
FROM purchased_prior_member AS p_member
JOIN menu
  ON p_member.product_id = menu.product_id
WHERE rank = 1
ORDER BY p_member.customer_id ASC;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT 
  sales.customer_id, 
  COUNT(sales.product_id) AS total_items, 
  SUM(menu.price) AS total_sales
FROM sales
JOIN members
  ON sales.customer_id = members.customer_id
  AND sales.order_date < members.join_date
JOIN menu
  ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_cte AS (
  SELECT 
    menu.product_id, 
    CASE
      WHEN product_id = 1 THEN price * 20
      ELSE price * 10
    END AS points
  FROM menu
)

SELECT 
  sales.customer_id, 
  SUM(points_cte.points) AS total_points
FROM sales
JOIN points_cte
  ON sales.product_id = points_cte.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH dates_cte AS (
  SELECT 
    customer_id, 
    join_date, 
    join_date + 6 AS valid_date, 
    DATE_TRUNC(
      'month', '2021-01-31'::DATE)
      + interval '1 month' 
      - interval '1 day' AS last_date
  FROM members
)

SELECT 
  sales.customer_id, 
  SUM(CASE
    WHEN menu.product_name = 'sushi' THEN 2 * 10 * menu.price
    WHEN sales.order_date BETWEEN dates.join_date AND dates.valid_date THEN 2 * 10 * menu.price
    ELSE 10 * menu.price END) AS points
FROM sales
JOIN dates_cte AS dates
  ON sales.customer_id = dates.customer_id
  AND sales.order_date <= dates.last_date
JOIN menu
  ON sales.product_id = menu.product_id
GROUP BY sales.customer_id;