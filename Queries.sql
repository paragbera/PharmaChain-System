set search_path to pharma_manufacturing


-- Which product are currently making us the most money?

SELECT 
    pm.Product_Name,
    pm.Product_Type,
    COUNT(DISTINCT fgt.Batch_No) AS Batches_Sold,
    SUM(fgt.Sale_Qty) AS Total_Units_Sold,
    SUM(fgt.Val) AS Total_Revenue_INR
FROM FG_Transaction fgt
JOIN Batch b ON fgt.Batch_No = b.Batch_No
JOIN Product_Master pm ON b.Product_ID = pm.Product_ID
GROUP BY pm.Product_Name, pm.Product_Type
ORDER BY Total_Revenue_INR DESC;

--The QA Audit: "Show me a timeline of failed batches and who evaluated them."
SELECT 
    pqc.Analysis_Date,
    pqc.Batch_No,
    pm.Product_Name,
    pqc.Test,
    pqc.Limits,
    pqc.Results,
    em.Emp_Name AS Evaluated_By
FROM Product_Quality_Check pqc
JOIN Batch b ON pqc.Batch_No = b.Batch_No
JOIN Product_Master pm ON b.Product_ID = pm.Product_ID
JOIN Employee_Master em ON pqc.Emp_ID = em.Emp_ID
WHERE pqc.Results = 'FAILED'
ORDER BY pqc.Analysis_Date DESC;

-- The Supply Chain Check: "Who are our suppliers and what materials are they under contract to give us?"

SELECT 
    am.Account_Name AS Supplier_Name,
    am.Phone_No,
    mm.Material_Name,
    sc.Agreed_Price,
    sc.Valid_Until
FROM Supplier_Contract sc
JOIN Account_Master am ON sc.Account_No = am.Account_No
JOIN Material_Master mm ON sc.Material_ID = mm.Material_ID
WHERE sc.Valid_Until >= CURRENT_DATE
ORDER BY am.Account_Name;

--The Maintenance Alarm: "Which machines cost us the most money in repairs?"
SELECT 
    eq.Equipment_ID,
    eq.Equipment_Name,
    eq.Equipment_Type,
    COUNT(ml.Maintenance_ID) AS Times_Repaired,
    SUM(ml.Cost) AS Total_Repair_Cost
FROM Maintenance_Log ml
JOIN Equipment_Master eq ON ml.Equipment_ID = eq.Equipment_ID
GROUP BY eq.Equipment_ID, eq.Equipment_Name, eq.Equipment_Type
ORDER BY Total_Repair_Cost DESC;

--The Manufacturing Efficiency Trap: "Which production stages take the longest time to finish?"
SELECT 
    Process_Stage,
    COUNT(Log_ID) AS Total_Runs_Logged,
    AVG(End_Time - Start_Time) AS Average_Processing_Duration
FROM Production_Log
GROUP BY Process_Stage
ORDER BY Average_Processing_Duration DESC;

--The Compliance Drill: "Show me all active audit trail evidence logs."

SELECT 
    Change_Date,
    Report_ID,
    Action_Type,
    Old_Result AS Before_Change,
    New_Result AS After_Change,
    Changed_By AS Database_User
FROM QC_Audit_Log
ORDER BY Change_Date DESC;

--The Financial Leak Tracker: "What are our total financial losses from recalled batches?"
SELECT 
    pr.Recall_ID,
    pr.Date_Initiated,
    pr.Batch_No,
    pm.Product_Name,
    pr.Qty_Recalled AS Units_Destroyed,
    pr.Reason
FROM Product_Recall pr
JOIN Batch b ON pr.Batch_No = b.Batch_No
JOIN Product_Master pm ON b.Product_ID = pm.Product_ID
ORDER BY pr.Date_Initiated DESC;

--The Warehouse Audit: "What is our current storage profile for hazardous or inflammable raw chemicals?"
SELECT 
    w.Item_ID,
    mm.Material_Name,
    w.Stock AS Current_Stock,
    mm.UOM,
    mm.Storage_Condition,
    mm.isHazardous,
    mm.isInflammable
FROM Warehouse w
JOIN Material_Master mm ON w.Material_ID = mm.Material_ID
WHERE mm.isHazardous = TRUE OR mm.isInflammable = TRUE
ORDER BY w.Stock DESC;