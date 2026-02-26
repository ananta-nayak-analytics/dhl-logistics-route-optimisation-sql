USE dhl_logistic;
                 -- TASK 1 --
-- Identify and delet duplicate Order_id,Shipment_id --
SELECT Shipment_ID, COUNT(*) AS total_records
FROM shipments GROUP BY Shipment_ID
HAVING COUNT(*) > 1;
SELECT Order_ID, COUNT(*) AS total_records
FROM orders GROUP BY Order_ID
HAVING COUNT(*) > 1;
-- Replace null or missing delay hours with average delay for the rout_id --
SELECT Shipment_ID, Route_ID
FROM shipments
WHERE Delay_Hours IS NULL;

UPDATE shipments s
JOIN (SELECT Route_ID, AVG(Delay_Hours) AS avg_delay
 FROM shipments
 WHERE Delay_Hours IS NOT NULL
 GROUP BY Route_ID)r ON s.Route_ID = r.Route_ID
 SET s.Delay_Hours = r.avg_delay
 WHERE s.Delay_Hours IS NULL;
 -- since there is no null value so update effect 0 row --
 -- converting all date column to YYYY-MMM-DDHH-MM-SS FORMAT --
 UPDATE orders
SET Order_Date = STR_TO_DATE(Order_Date, '%Y-%m-%d %H:%i:%s');
UPDATE shipments
SET Pickup_Date = STR_TO_DATE(Pickup_Date, '%Y-%m-%d %H:%i:%s'),
Delivery_Date = STR_TO_DATE(Delivery_Date, '%Y-%m-%d %H:%i:%s');
SELECT Shipment_ID, Pickup_Date, Delivery_Date
FROM shipments WHERE Delivery_Date < Pickup_Date;
-- all shipment record are follow correct time sequence --
--  Referential Integrity --
SELECT Shipment_ID, Order_ID
FROM shipments WHERE Order_ID IS NULL;
SELECT Shipment_ID, Route_ID
FROM shipments WHERE Route_ID IS NULL;
SELECT Shipment_ID,Warehouse_ID
FROM shipments WHERE Warehouse_ID IS NULL;
                   -- TASK 2 --
-- Calculating delivery delay (in hours) for each shipment --
ALTER TABLE shipments 
ADD COLUMN Calculated_Delay_Hours INT;
UPDATE shipments SET Calculated_Delay_Hours = TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date);
SELECT Shipment_ID,calculated_delay_hours AS Actual_Delay_Hours
FROM shipments;
-- Finding out the Top 10 delayed routes based on average delay hours --
SELECT Route_ID,AVG(delay_hours) AS Avg_Delay_Hours
FROM shipments GROUP BY Route_ID ORDER BY Avg_Delay_Hours DESC LIMIT 10;
-- By using window functions rank shipments by delay within each Warehouse_ID --
select shipment_id,warehouse_id,delay_hours, rank()over(partition by warehouse_id order by delay_hours desc) as Delay_rank
from shipments;
-- Identify the average delay per Delivery_Type --
SELECT o.Delivery_Type,AVG(s.Delay_Hours) AS Avg_Delay_Hours
FROM shipments s JOIN orders o ON s.Order_ID = o.Order_ID
GROUP BY o.Delivery_Type;
                       --- Task 3 ---
-- calculating average transit time (in hours) across all shipments --
select * from shipments;
SELECT Route_ID,AVG(Calculated_Delay_Hours) AS Avg_Transit_Time_Hours
FROM shipments GROUP BY Route_ID;
-- Average delay (in hours) per route --
SELECT Route_ID,AVG(Delay_Hours) AS Avg_Delay_Hours
FROM shipments GROUP BY Route_ID;
-- Calculating distance-to-time efficiency ratio --
select * from routes;
SELECT r.Route_ID,r.Distance_KM,AVG(s.Calculated_Delay_Hours) AS Avg_Actual_Transit_Time,
(r.Distance_KM / AVG(s.Calculated_Delay_Hours)) AS Efficiency_ratio
FROM routes r JOIN shipments s  ON r.Route_ID = s.Route_ID
GROUP BY r.Route_ID, r.Distance_KM order by Route_ID;
-- Top 3 routes with the worst efficiency ratio --
SELECT r.Route_ID,r.Distance_KM,AVG(s.Calculated_Delay_Hours) AS Avg_Actual_Transit_Time,
(r.Distance_KM / AVG(s.Calculated_Delay_Hours)) AS Efficiency_ratio
FROM routes r JOIN shipments s  ON r.Route_ID = s.Route_ID
GROUP BY r.Route_ID, r.Distance_KM order by Efficiency_ratio limit 3;
-- Routes with >20% of shipments delayed beyond expected transit time --
SELECT Route_ID,COUNT(*) AS Total_Shipments,COUNT(CASE WHEN Delay_Hours > 0 THEN 1 END) AS Delayed_Shipments,
(COUNT(CASE WHEN Delay_Hours > 0 THEN 1 END) * 100.0 / COUNT(*)) AS Delay_Percentage
FROM shipments GROUP BY Route_ID HAVING Delay_Percentage > 20;
                   --- Task 4 ---
-- Top 3 Warehouses with Highest Average Delay --
SELECT Warehouse_ID,AVG(Delay_Hours) AS Avg_Delay_Hours
FROM shipments GROUP BY Warehouse_ID ORDER BY Avg_Delay_Hours DESC LIMIT 3;
-- Total Shipments vs Delayed Shipments for Each Warehouse --
SELECT Warehouse_ID,COUNT(*) AS Total_Shipments,
COUNT(CASE WHEN Delay_Hours > 0 THEN 1 END) AS Delayed_Shipments
FROM shipments GROUP BY Warehouse_ID;
-- Warehouses Where Average Delay Exceeds Global Average --
WITH WarehouseAvg AS (SELECT Warehouse_ID,AVG(Delay_Hours) AS Avg_Delay FROM shipments GROUP BY Warehouse_ID),
GlobalAvg AS (SELECT AVG(Delay_Hours) AS Global_Avg_Delay FROM shipments)
SELECT w.Warehouse_ID,w.Avg_Delay,g.Global_Avg_Delay
FROM WarehouseAvg w CROSS JOIN GlobalAvg g
WHERE w.Avg_Delay > g.Global_Avg_Delay;
-- Ranking Warehouses by On-Time Delivery Percentage --
SELECT Warehouse_ID,(COUNT(CASE WHEN Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) AS OnTime_Percentage,
RANK() OVER (ORDER BY (COUNT(CASE WHEN Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) DESC) AS Warehouse_Rank
FROM shipments GROUP BY Warehouse_ID;
                              --- Task 5 ---
-- Ranking Delivery Agents (per Route) by On-Time Delivery --
SELECT s.Route_ID,s.Agent_ID,(COUNT(CASE WHEN s.Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) AS OnTime_Percentage,
RANK() OVER (PARTITION BY s.Route_ID ORDER BY (COUNT(CASE WHEN s.Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) DESC) AS Agent_Rank
FROM shipments s GROUP BY s.Route_ID, s.Agent_ID;
-- Finding agents whose on-time % is below 85% --
SELECT s.Agent_ID,(COUNT(CASE WHEN s.Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) AS OnTime_Percentage
FROM shipments s GROUP BY s.Agent_ID HAVING OnTime_Percentage < 85;
-- Compare Avg Rating & Experience of Top 5 vs Bottom 5 Agents based on on time delivery% --
SELECT 'Top 5 Agents' AS Category,AVG(d.Experience_Years) AS Avg_Experience,AVG(d.Avg_Rating) AS Avg_Rating
FROM delivery_agents d 
JOIN (SELECT Agent_ID FROM shipments GROUP BY Agent_ID 
     ORDER BY (COUNT(CASE WHEN Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) DESC LIMIT 5) t 
     ON d.Agent_ID = t.Agent_ID
UNION ALL
SELECT 'Bottom 5 Agents' AS Category,AVG(d.Experience_Years) AS Avg_Experience,AVG(d.Avg_Rating) AS Avg_Rating
FROM delivery_agents d
JOIN (SELECT Agent_ID FROM shipments GROUP BY Agent_ID 
     ORDER BY (COUNT(CASE WHEN Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) ASC LIMIT 5) b 
     ON d.Agent_ID = b.Agent_ID;
                              --- Task 6 ---
-- Latest Status of Each Shipment --
USE dhl_logistic;
SELECT s.Shipment_ID,s.Delivery_Status,s.Delivery_Date
FROM shipments s JOIN (SELECT Shipment_ID, MAX(Delivery_Date) AS Max_Date FROM shipments
GROUP BY Shipment_ID) t ON s.Shipment_ID = t.Shipment_ID AND s.Delivery_Date = t.Max_Date;
-- Routes where Majority of Shipments are in Transit or Returned --
SELECT Route_ID,COUNT(*) AS Total_Shipments,
COUNT(CASE WHEN Delivery_Status IN ('In Transit', 'Returned') THEN 1 END) AS Problem_Shipments
FROM shipments GROUP BY Route_ID HAVING COUNT(CASE WHEN Delivery_Status IN ('In Transit', 'Returned') THEN 1 END) > COUNT(*) / 2;
-- Identifying the Most Frequent Delay Reasons --
SELECT* FROM shipments;
SELECT Delay_Reason,COUNT(*) AS Frequency
FROM shipments GROUP BY Delay_Reason ORDER BY Frequency DESC;
-- Identify Orders with Exceptionally High Delay (> 120 Hours) --
SELECT Shipment_ID,Order_ID,Route_ID,Warehouse_ID,Agent_ID,Delay_Hours,Delivery_Status
FROM shipments WHERE Delay_Hours > 120;
               --- Task 7 --- 
-- Average Delivery Delay per Source Country --
USE dhl_logistic;
select r.source_country,avg(delay_hours) from shipments s
join routes r on s.route_id=r.route_id group by source_country;  
-- On-Time Delivery Percentage --
SELECT (COUNT(CASE WHEN Delay_Hours = 0 THEN 1 END) * 100.0 / COUNT(*)) AS OnTime_Delivery_Percentage
FROM shipments;
-- Average Delay per Route_ID --
SELECT Route_ID,AVG(Delay_Hours) AS Avg_Delay_Hours
FROM shipments GROUP BY Route_ID;
-- Warehouse Utilization Percentage --
SELECT w.Warehouse_ID,w.Capacity_per_day,COUNT(s.Shipment_ID) AS Shipments_Handled,
      (COUNT(s.Shipment_ID) * 100.0 / w.Capacity_per_day) AS Utilization_Percentag 
      FROM warehouses w LEFT JOIN shipments s ON w.Warehouse_ID = s.Warehouse_ID 
      GROUP BY w.Warehouse_ID, w.Capacity_per_day;
