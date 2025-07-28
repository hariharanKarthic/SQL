USE PIZZA_RUNNER;
-- How many pizzas were ordered?
SELECT COUNT(*) AS NO_OF_PIZZAS 
 FROM (SELECT * FROM customer_orders
GROUP BY order_id, customer_id, pizza_id, exclusions, extras, order_time)X;

-- How many unique customer orders were made?
SELECT COUNT(DISTINCT customer_id) AS UNIQUE_CUSTOMERS 
FROM customer_orders;

-- How many successful orders were delivered by each runner?
SELECT RUNNER_ID, COUNT(DISTINCT ORDER_ID) AS ORDERS_DELIVERED 
FROM RUNNER_ORDERS
WHERE CANCELLATION IS NULL
GROUP BY RUNNER_ID;

-- How many of each type of pizza was delivered?
SELECT p1.pizza_name, count(c.order_id)
FROM customer_orders C  join runner_orders r on c.order_id=r.order_id
join pizza_names p1 on c.pizza_id=p1.pizza_id
where cancellation is null
GROUP BY p1.pizza_name;
-- How many Vegetarian and Meatlovers were ordered by each customer?
select customer_id, 
sum(case when pizza_id=1 then 1 else 0  end) as meat_lovers,
sum(case when pizza_id=2 then 1 else 0  end) as Vegetarian
from customer_orders
group by customer_id;

-- What was the maximum number of pizzas delivered in a single order?
select order_id, count(order_id) 
from customer_orders
group by order_id
order by count(order_id) desc
limit 1;

-- For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_id,sum(case when exclusions is null and extras is null then 1 else 0 end ) as pizzas_delivered_without_change,
sum(case when exclusions is not null or extras is not null then 1 else 0 end ) as pizzas_delivered_with_change
from customer_orders
where order_id in (select order_id from runner_orders where cancellation is null)
group by customer_id;

-- How many pizzas were delivered that had both exclusions and extras?
select sum(case when exclusions <> 0 and extras <> 0 then 1 else 0 end ) no_of_pizzas
from customer_orders 
where order_id in (select order_id from runner_orders where cancellation is null);


-- What was the total volume of pizzas ordered for each hour of the day?
select hour(order_time),count(pizza_id) 
from customer_orders
group by hour(order_time)
order by hour(order_time);

-- What was the volume of orders for each day of the week
select weekday(order_time),count(pizza_id) from customer_orders
group by weekday(order_time)
order by weekday(order_time);

SET SQL_SAFE_UPDATES = 0;
update customer_orders
set exclusions= null
where exclusions="";
update customer_orders
set extras= null
where extras="";
update runner_orders
set cancellation= null
where cancellation="";

select * from customer_orders;
select * from runner_orders;

-- How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select weekofyear(registration_date), count(distinct runner_id) from runners
group by weekofyear(registration_date);

-- What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select runner_id,time_format(avg(timediff(pickup_time,order_time)),"%i") as Avg_time_to_pickup
from customer_orders c join runner_orders r on c.order_id=r.order_id
group by 1;

-- Is there any relationship between the number of pizzas and how long the order takes to prepare?
with cte as(
select c.order_id, count(c.order_id) as PizzaCount, round((timestampdiff(minute, order_time, pickup_time))) as Avgtime
from customer_orders as c
inner join runner_orders as r
on c.order_id = r.order_id
where distance is not null 
group by c.order_id)

 select PizzaCount, Avgtime
from cte
group by PizzaCount;

-- What was the average distance travelled for each customer?
select customer_id, round(avg(distance),2)as avg_distance 
from customer_orders c join runner_orders r 
on c.order_id=r.order_id
group by 1;

-- What was the difference between the longest and shortest delivery times for all orders?
with cte as(
select c.order_id, order_time, pickup_time, timestampdiff(minute, order_time,pickup_time) as TimeDiff1
from customer_orders as c
inner join runner_orders as r
on c.order_id = r.order_id
where distance is not null
group by c.order_id, order_time, pickup_time)

 select max(TimeDiff1) - min(TimeDiff1) as DifferenceTime from cte;

-- What was the average speed for each runner for each delivery and do you notice any trend for these values?
with cte as (
select runner_id, order_id, round(distance *60/duration,1) as speedKMH
from runner_orders
where distance is not null)

 select * from cte
order by runner_id;

-- What is the successful delivery percentage for each runner?
with cte as(select runner_id, count(order_id) as total_orders from runner_orders r1
group by runner_id),
cte1 as (select runner_id, count(order_id) as delivered_orders from runner_orders 
where cancellation is null
group by runner_id)

 select c.runner_id,total_orders,delivered_orders,round(((delivered_orders/total_orders)*100),2) as successful_delivery_percentage
from cte c join cte1 c1 on c.runner_id=c1.runner_id;

-- What are the standard ingredients for each pizza?

SELECT pizza_name, group_concat(topping_name) FROM PIZZA_RECIPES1 PR 
JOIN PIZZA_TOPPINGS PT ON PR.TOPPINGS=PT.TOPPING_ID 
JOIN PIZZA_NAMES PN ON PR.PIZZA_ID=PN.PIZZA_ID
group by pizza_name;

-- What was the most commonly added extra?
with cte as (SELECT n.num, SUBSTRING_INDEX(SUBSTRING_INDEX(all_tags, ',', num), ',', -1) as one_tag
FROM (
  SELECT
    GROUP_CONCAT(extras SEPARATOR ',') AS all_tags,
    LENGTH(GROUP_CONCAT(extras SEPARATOR ',')) - LENGTH(REPLACE(GROUP_CONCAT(extras SEPARATOR ','), ',', '')) + 1 AS count_tags
  FROM customer_orders
) t
JOIN numbers n
ON n.num <= t.count_tags)

select one_tag as Extras,pizza_toppings.topping_name as ExtraTopping, count(one_tag) as Occurrencecount
from cte
inner join pizza_toppings
on pizza_toppings.topping_id = cte.one_tag
where one_tag != 0
group by one_tag,pizza_toppings.topping_name;


-- What was the most common exclusion?
with cte as (SELECT n.num, SUBSTRING_INDEX(SUBSTRING_INDEX(all_tags, ',', num), ',', -1) as one_tag
FROM (
  SELECT
    GROUP_CONCAT(exclusions SEPARATOR ',') AS all_tags,
    LENGTH(GROUP_CONCAT(exclusions SEPARATOR ',')) - LENGTH(REPLACE(GROUP_CONCAT(exclusions SEPARATOR ','), ',', '')) + 1 AS count_tags
  FROM customer_orders
) t
JOIN numbers n
ON n.num <= t.count_tags)

 select one_tag as Exclusions,pizza_toppings.topping_name as ExclusionTopping, count(one_tag) as Occurrencecount
from cte
inner join pizza_toppings
on pizza_toppings.topping_id = cte.one_tag
where one_tag != 0
group by one_tag,pizza_toppings.topping_name 
order by Occurrencecount desc;

-- Generate an order item for each record in the customers_orders table in the format of one of the following:
select customer_orders.order_id, customer_orders.pizza_id, pizza_names.pizza_name, customer_orders.exclusions, customer_orders.extras, 
case
when customer_orders.pizza_id = 1 and (exclusions is null or exclusions=0) and (extras is null or extras=0) then 'Meat Lovers'
when customer_orders.pizza_id = 2 and (exclusions is null or exclusions=0) and (extras is null or extras=0) then 'Veg Lovers'
when customer_orders.pizza_id = 2 and (exclusions =4 ) and (extras is null or extras=0) then 'Veg Lovers - Exclude Cheese'
when customer_orders.pizza_id = 1 and (exclusions =4 ) and (extras is null or extras=0) then 'Meat Lovers - Exclude Cheese'
when customer_orders.pizza_id=1 and (exclusions like '%3%' or exclusions =3) and (extras is null or extras=0) then 'Meat Lovers - Exclude Beef'
when customer_orders.pizza_id =1 and (exclusions is null or exclusions=0) and (extras like '%1%' or extras =1) then 'Meat Lovers - Extra Bacon'
when customer_orders.pizza_id=1 and (exclusions like '1, 4' ) and (extras like '6, 9') then 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers'
when customer_orders.pizza_id=1 and (exclusions like '2, 6' ) and (extras like '1, 4') then 'Meat Lovers - Exclude BBQ Sauce,Mushroom - Extra Bacon, Cheese'
when customer_orders.pizza_id=1 and (exclusions =4) and (extras like '1, 5') then 'Meat Lovers - Exclude Cheese - Extra Bacon, Chicken'
end as OrderItem
from customer_orders
inner join pizza_names
on pizza_names.pizza_id = customer_orders.pizza_id;

-- Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
-- What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

select * from customer_orders c cross 
apply pizza_toppings p 

