-- Общая статистика
SELECT COUNT(*) AS total_records, COUNT(DISTINCT order_id) AS unique_orders,
       COUNT(DISTINCT user_id) AS unique_users, COUNT(DISTINCT product) AS unique_products,
       MIN(order_date) AS earliest_date, MAX(order_date) AS latest_date,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue
FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL;


-- ============================================================================
-- 1. КОГОРТНЫЙ АНАЛИЗ И RETENTION
-- ============================================================================

-- Активность клиентов по месяцам
SELECT order_month, COUNT(DISTINCT user_id) AS active_users, COUNT(DISTINCT order_id) AS total_orders
FROM (SELECT user_id, order_id, SUBSTRING(CAST(order_date AS String), 1, 7) AS order_month
      FROM `data-zuma` WHERE order_date IS NOT NULL)
GROUP BY order_month ORDER BY order_month;


-- Retention Rate
SELECT 'All Customers' AS period, COUNT(DISTINCT user_id) AS users, 100.0 AS retention_pct FROM `data-zuma`
UNION ALL
SELECT 'Repeat Customers' AS period, COUNT(DISTINCT user_id) AS users,
       COUNT(DISTINCT user_id) * 100.0 / (SELECT COUNT(DISTINCT user_id) FROM `data-zuma`) AS retention_pct
FROM (SELECT user_id FROM `data-zuma` GROUP BY user_id HAVING COUNT(DISTINCT order_id) > 1);


-- Метрики retention по месяцам
SELECT order_month, COUNT(DISTINCT user_id) AS total_users, COUNT(DISTINCT order_id) AS total_orders,
       COUNT(DISTINCT order_id) * 1.0 / COUNT(DISTINCT user_id) AS orders_per_user
FROM (SELECT user_id, order_id, SUBSTRING(CAST(order_date AS String), 1, 7) AS order_month
      FROM `data-zuma` WHERE order_date IS NOT NULL)
GROUP BY order_month ORDER BY order_month;


-- ============================================================================
-- 2. СЕГМЕНТАЦИЯ КЛИЕНТОВ И ТОВАРОВ
-- ============================================================================

-- RFM-анализ клиентов
SELECT user_id, last_order_date, frequency, monetary,
       CASE WHEN last_order_date >= CAST('2023-11-01' AS Date) AND frequency >= 3 AND monetary >= 3000 THEN 'Champions'
            WHEN last_order_date >= CAST('2023-09-01' AS Date) AND frequency >= 2 AND monetary >= 2000 THEN 'Loyal'
            WHEN last_order_date >= CAST('2023-11-01' AS Date) AND frequency <= 2 THEN 'Promising'
            WHEN last_order_date >= CAST('2023-08-01' AS Date) AND frequency <= 2 THEN 'Need Attention'
            WHEN last_order_date < CAST('2023-08-01' AS Date) AND frequency >= 2 THEN 'At Risk'
            WHEN last_order_date < CAST('2023-08-01' AS Date) AND frequency <= 2 THEN 'Lost'
            ELSE 'Other' END AS customer_segment
FROM (SELECT user_id, MAX(order_date) AS last_order_date, COUNT(DISTINCT order_id) AS frequency,
             SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS monetary
      FROM `data-zuma` WHERE order_date IS NOT NULL AND price IS NOT NULL AND quantity IS NOT NULL
      GROUP BY user_id)
ORDER BY monetary DESC;


-- Статистика по RFM-сегментам
SELECT customer_segment, COUNT(*) AS customers_count, AVG(frequency) AS avg_frequency,
       AVG(monetary) AS avg_monetary, SUM(monetary) AS total_revenue
FROM (SELECT user_id, COUNT(DISTINCT order_id) AS frequency,
             SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS monetary,
             CASE WHEN MAX(order_date) >= CAST('2023-11-01' AS Date) AND COUNT(DISTINCT order_id) >= 3
                       AND SUM(CAST(price AS Double) * CAST(quantity AS Int32)) >= 3000 THEN 'Champions'
                  WHEN MAX(order_date) >= CAST('2023-09-01' AS Date) AND COUNT(DISTINCT order_id) >= 2
                       AND SUM(CAST(price AS Double) * CAST(quantity AS Int32)) >= 2000 THEN 'Loyal'
                  WHEN MAX(order_date) >= CAST('2023-11-01' AS Date) AND COUNT(DISTINCT order_id) <= 2 THEN 'Promising'
                  WHEN MAX(order_date) >= CAST('2023-08-01' AS Date) AND COUNT(DISTINCT order_id) <= 2 THEN 'Need Attention'
                  WHEN MAX(order_date) < CAST('2023-08-01' AS Date) AND COUNT(DISTINCT order_id) >= 2 THEN 'At Risk'
                  WHEN MAX(order_date) < CAST('2023-08-01' AS Date) AND COUNT(DISTINCT order_id) <= 2 THEN 'Lost'
                  ELSE 'Other' END AS customer_segment
      FROM `data-zuma` WHERE order_date IS NOT NULL AND price IS NOT NULL AND quantity IS NOT NULL
      GROUP BY user_id)
GROUP BY customer_segment ORDER BY total_revenue DESC;


-- ABC-анализ товаров
SELECT product, category, total_revenue, cumulative_revenue, cumulative_pct,
       CASE WHEN cumulative_pct <= 80 THEN 'A' WHEN cumulative_pct <= 95 THEN 'B' ELSE 'C' END AS abc_class
FROM (SELECT product, category, total_revenue,
             SUM(total_revenue) OVER (ORDER BY total_revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue,
             SUM(total_revenue) OVER (ORDER BY total_revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 /
                 SUM(total_revenue) OVER () AS cumulative_pct
      FROM (SELECT product, category, SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue
            FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL
            GROUP BY product, category))
ORDER BY total_revenue DESC;


-- Статистика по ABC-классам
SELECT abc_class, COUNT(*) AS products_count, SUM(total_revenue) AS total_revenue,
       SUM(total_revenue) * 100.0 / (SELECT SUM(CAST(price AS Double) * CAST(quantity AS Int32))
                                      FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL) AS revenue_pct
FROM (SELECT product, category, total_revenue,
             CASE WHEN cumulative_pct <= 80 THEN 'A' WHEN cumulative_pct <= 95 THEN 'B' ELSE 'C' END AS abc_class
      FROM (SELECT product, category, total_revenue,
                   SUM(total_revenue) OVER (ORDER BY total_revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 /
                       SUM(total_revenue) OVER () AS cumulative_pct
            FROM (SELECT product, category, SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue
                  FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL
                  GROUP BY product, category)))
GROUP BY abc_class ORDER BY abc_class;


-- Сегментация по категориям
SELECT category, COUNT(DISTINCT order_id) AS orders_count, COUNT(DISTINCT user_id) AS unique_customers,
       SUM(CAST(quantity AS Int32)) AS total_quantity,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue,
       AVG(CAST(price AS Double)) AS avg_price, AVG(CAST(rating AS Double)) AS avg_rating
FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL AND category IS NOT NULL
GROUP BY category ORDER BY total_revenue DESC;


-- ============================================================================
-- 3. МАРЖИНАЛЬНОСТЬ И ПРИБЫЛЬНОСТЬ
-- ============================================================================

-- Выручка по месяцам
SELECT month, COUNT(DISTINCT order_id) AS orders_count, COUNT(DISTINCT user_id) AS unique_customers,
       SUM(order_value) AS total_revenue, AVG(order_value) AS avg_order_value, SUM(quantity) AS total_items_sold
FROM (SELECT SUBSTRING(CAST(order_date AS String), 1, 7) AS month, order_id, user_id,
             CAST(price AS Double) * CAST(quantity AS Int32) AS order_value, CAST(quantity AS Int32) AS quantity
      FROM `data-zuma` WHERE order_date IS NOT NULL AND price IS NOT NULL AND quantity IS NOT NULL)
GROUP BY month ORDER BY month;


-- Прибыльность по странам
SELECT country, COUNT(DISTINCT order_id) AS orders_count, COUNT(DISTINCT user_id) AS unique_customers,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue,
       AVG(CAST(price AS Double) * CAST(quantity AS Int32)) AS avg_order_value,
       AVG(CAST(rating AS Double)) AS avg_rating
FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL AND country IS NOT NULL
GROUP BY country ORDER BY total_revenue DESC;


-- Прибыльность по способам оплаты
SELECT payment_method, COUNT(DISTINCT order_id) AS orders_count, COUNT(DISTINCT user_id) AS unique_customers,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue,
       AVG(CAST(price AS Double) * CAST(quantity AS Int32)) AS avg_order_value,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) * 100.0 /
           (SELECT SUM(CAST(price AS Double) * CAST(quantity AS Int32)) FROM `data-zuma`
            WHERE price IS NOT NULL AND quantity IS NOT NULL AND payment_method IS NOT NULL) AS revenue_share_pct
FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL AND payment_method IS NOT NULL
GROUP BY payment_method ORDER BY total_revenue DESC;


-- Топ-10 прибыльных товаров
SELECT product, category, COUNT(DISTINCT order_id) AS orders_count,
       SUM(CAST(quantity AS Int32)) AS total_quantity_sold,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue,
       AVG(CAST(price AS Double)) AS avg_price, AVG(CAST(rating AS Double)) AS avg_rating
FROM `data-zuma` WHERE price IS NOT NULL AND quantity IS NOT NULL
GROUP BY product, category ORDER BY total_revenue DESC LIMIT 10;


-- ============================================================================
-- 4. ВЫЯВЛЕНИЕ АНОМАЛИЙ И ТОП-ПРОБЛЕМ
-- ============================================================================

-- Качество данных
SELECT 'Missing Price' AS anomaly_type, COUNT(*) AS count,
       COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `data-zuma`) AS percentage
FROM `data-zuma` WHERE price IS NULL
UNION ALL
SELECT 'Missing Payment Method', COUNT(*), COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `data-zuma`)
FROM `data-zuma` WHERE payment_method IS NULL
UNION ALL
SELECT 'Missing Rating', COUNT(*), COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `data-zuma`)
FROM `data-zuma` WHERE rating IS NULL
UNION ALL
SELECT 'Missing Country', COUNT(*), COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `data-zuma`)
FROM `data-zuma` WHERE country IS NULL
ORDER BY count DESC;


-- Заказы с низкими рейтингами
SELECT order_id, user_id, product, category,
       CAST(price AS Double) * CAST(quantity AS Int32) AS order_value,
       rating, order_date, country, payment_method
FROM `data-zuma`
WHERE CAST(rating AS Double) <= 2.0 AND rating IS NOT NULL AND price IS NOT NULL AND quantity IS NOT NULL
ORDER BY rating ASC, order_value DESC LIMIT 50;


-- Низкие рейтинги по категориям
SELECT category, COUNT(*) AS low_rating_count,
       COUNT(*) * 100.0 / (SELECT COUNT(*) FROM `data-zuma` WHERE rating IS NOT NULL) AS pct_of_total,
       AVG(CAST(price AS Double) * CAST(quantity AS Int32)) AS avg_order_value,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS lost_revenue_potential
FROM `data-zuma`
WHERE CAST(rating AS Double) <= 2.0 AND rating IS NOT NULL AND price IS NOT NULL
      AND quantity IS NOT NULL AND category IS NOT NULL
GROUP BY category ORDER BY low_rating_count DESC;


-- Товары с частыми низкими рейтингами
SELECT product, category, COUNT(*) AS total_orders,
       SUM(CASE WHEN CAST(rating AS Double) <= 2.0 THEN 1 ELSE 0 END) AS low_rating_count,
       SUM(CASE WHEN CAST(rating AS Double) <= 2.0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS low_rating_pct,
       AVG(CAST(rating AS Double)) AS avg_rating,
       SUM(CAST(price AS Double) * CAST(quantity AS Int32)) AS total_revenue
FROM `data-zuma` WHERE rating IS NOT NULL AND price IS NOT NULL AND quantity IS NOT NULL
GROUP BY product, category
HAVING COUNT(*) >= 3 AND SUM(CASE WHEN CAST(rating AS Double) <= 2.0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 30.0
ORDER BY low_rating_pct DESC, total_orders DESC;


-- Аномально большие заказы
SELECT order_id, user_id, product, category, CAST(price AS Double) AS price, quantity,
       CAST(price AS Double) * CAST(quantity AS Int32) AS order_value,
       order_date, country, payment_method, rating
FROM `data-zuma`
WHERE CAST(quantity AS Int32) >= 5 AND price IS NOT NULL AND quantity IS NOT NULL
ORDER BY quantity DESC, order_value DESC LIMIT 50;
