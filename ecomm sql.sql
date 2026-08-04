create database ondc_analytics;
use ondc_analytics;


CREATE TABLE ondc (
    transaction_id VARCHAR(50),
    search_id VARCHAR(50),
    date DATE,              
    bnp_name VARCHAR(100),
    snp_name VARCHAR(100),
    pincode INT,
    category VARCHAR(50),
    api_stage VARCHAR(50),
    item_price_inr DECIMAL(10, 2),
    delivery_fee_inr DECIMAL(10, 2),
    logistics_partner VARCHAR(50) NULL, 
    order_status VARCHAR(50),
    api_latency_ms INT,
    latency_flag VARCHAR(50)
);
truncate table ondc_transactions;
select* from ondc;
select count(*)
from ondc;

-- Funnel Stage Volume
SELECT api_stage, COUNT(*) AS total_events
FROM ondc
GROUP BY api_stage
ORDER BY CASE api_stage
    WHEN 'search'  THEN 1
    WHEN 'select'  THEN 2
    WHEN 'init'    THEN 3
    WHEN 'confirm' THEN 4
END;


--  Stage-to-Stage Drop-off Rate
WITH stage_counts AS (
  SELECT api_stage, COUNT(*) AS cnt,
    CASE api_stage
      WHEN 'search'  THEN 1
      WHEN 'select'  THEN 2
      WHEN 'init'    THEN 3
      WHEN 'confirm' THEN 4
    END AS stage_order
  FROM ondc
  GROUP BY api_stage
)
SELECT curr.api_stage, 
       curr.cnt AS current_stage_count, 
       prev.cnt AS previous_stage_count, 
       ROUND((1 - (curr.cnt * 1.0 / prev.cnt)) * 100, 2) AS drop_off_pct
FROM stage_counts curr
LEFT JOIN stage_counts prev ON curr.stage_order = prev.stage_order + 1
ORDER BY curr.stage_order;


-- Category-wise Conversion Rate
SELECT category,
  SUM(CASE WHEN api_stage = 'search'  THEN 1 ELSE 0 END) AS total_searches,
  SUM(CASE WHEN api_stage = 'confirm' THEN 1 ELSE 0 END) AS total_confirmed,
  ROUND(
    SUM(CASE WHEN api_stage = 'confirm' THEN 1 ELSE 0 END) * 100.0 / 
    NULLIF(SUM(CASE WHEN api_stage = 'search' THEN 1 ELSE 0 END), 0), 2
  ) AS conversion_pct
FROM ondc
GROUP BY category
ORDER BY conversion_pct DESC;


-- Buyer App (BNP) Delivery Success Rate
SELECT bnp_name AS buyer_app,
  COUNT(*) AS confirmed_orders,
  SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_orders,
  ROUND(
    SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
  ) AS delivery_success_pct
FROM ondc
WHERE api_stage = 'confirm'
GROUP BY bnp_name
ORDER BY delivery_success_pct DESC;


-- SNP SLA Breach Rate
SELECT snp_name,
  COUNT(*) AS total_api_calls,
  SUM(CASE WHEN latency_flag = 'SLA Breach (>1000ms)' THEN 1 ELSE 0 END) AS breaches,
  ROUND(
    SUM(CASE WHEN latency_flag = 'SLA Breach (>1000ms)' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2
  ) AS sla_breach_pct
FROM ondc
GROUP BY snp_name
ORDER BY sla_breach_pct DESC;




-- Top Pincodes by Transaction Volume
SELECT pincode, COUNT(*) AS total_transactions
FROM ondc
GROUP BY pincode
ORDER BY total_transactions DESC
LIMIT 5;


--  Monthly Transaction Trend
SELECT DATE_FORMAT(date, '%Y-%m') AS month, COUNT(*) AS transactions
FROM ondc
GROUP BY DATE_FORMAT(date, '%Y-%m')
ORDER BY month;


-- Revenue & Average Order Value (Delivered Orders)
SELECT COUNT(*) AS delivered_orders,
  ROUND(SUM(item_price_inr), 2) AS total_item_revenue,
  SUM(delivery_fee_inr) AS total_delivery_fee_revenue,
  ROUND(AVG(item_price_inr + delivery_fee_inr), 2) AS avg_order_value
FROM ondc
WHERE order_status = 'Delivered';


-- Cancellation Split by Category
SELECT category,
  SUM(CASE WHEN order_status = 'Cancelled_Buyer'  THEN 1 ELSE 0 END) AS buyer_cancelled,
  SUM(CASE WHEN order_status = 'Cancelled_Seller' THEN 1 ELSE 0 END) AS seller_cancelled
FROM ondc_transactions
WHERE api_stage = 'confirm'
GROUP BY category
ORDER BY (buyer_cancelled + seller_cancelled) DESC;

