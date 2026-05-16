


-- =====================================================================
-- VIEW: FDA End-to-End Batch Traceability
-- DESCRIPTION: A complete lifecycle map of every batch, showing its 
--              ingredients, QC status, and market sales.
-- =====================================================================

CREATE OR REPLACE VIEW v_fda_batch_traceability AS
SELECT 
    B.Batch_No,
    PM.Product_Name,
    B.Mfg_Date,
    B.Exp_Date,
    COALESCE(QC.Results, 'UNTESTED') AS QC_Status,
    STRING_AGG(DISTINCT MM.Material_Name, ', ') AS Raw_Materials_Used,
    COALESCE(SUM(FGT.Sale_Qty), 0) AS Total_Sold_To_Market
FROM Batch B
JOIN Product_Master PM ON B.Product_ID = PM.Product_ID
LEFT JOIN Product_Quality_Check QC ON B.Batch_No = QC.Batch_No
LEFT JOIN Material_Dispensing MD ON B.Batch_No = MD.Batch_No
LEFT JOIN Warehouse W ON MD.Item_ID = W.Item_ID
LEFT JOIN Material_Master MM ON W.Material_ID = MM.Material_ID
LEFT JOIN FG_Transaction FGT ON B.Batch_No = FGT.Batch_No
GROUP BY 
    B.Batch_No, 
    PM.Product_Name, 
    B.Mfg_Date, 
    B.Exp_Date, 
    QC.Results;

SELECT * FROM v_fda_batch_traceability;

-- =====================================================================
-- VIEW: Procurement Dashboard (Low Stock Alert)
-- DESCRIPTION: Instantly shows the purchasing team exactly which 
--              materials have dropped below their safe reorder limit.
-- =====================================================================

CREATE OR REPLACE VIEW v_inventory_shortage AS
SELECT 
    w.Item_ID,
    m.Material_Name,
    m.Material_Type,
    w.Stock AS Current_Stock,
    m.Reorder_Level AS Minimum_Required,
    (m.Reorder_Level - w.Stock) AS Units_To_Order
FROM Warehouse w
JOIN Material_Master m ON w.Material_ID = m.Material_ID
WHERE w.Stock <= m.Reorder_Level;

SELECT * FROM v_inventory_shortage;


-- =====================================================================
-- VIEW: Expiry Risk & Inventory Liability Dashboard
-- DESCRIPTION: Tracks unsold finished goods, calculates days until 
--              expiry, and flags high-risk inventory using status codes.
-- =====================================================================

CREATE OR REPLACE VIEW v_inventory_expiry_risk AS
SELECT 
    B.Batch_No,
    PM.Product_Name,
    B.Exp_Date,
    (B.Exp_Date - CURRENT_DATE) AS Days_Remaining,
    
    -- Professional Status Codes
    CASE 
        WHEN (B.Exp_Date - CURRENT_DATE) < 0 THEN 'EXPIRED - DO NOT SELL'
        WHEN (B.Exp_Date - CURRENT_DATE) <= 30 THEN 'CRITICAL - UNDER 30 DAYS'
        WHEN (B.Exp_Date - CURRENT_DATE) <= 90 THEN 'WARNING - UNDER 90 DAYS'
        ELSE 'SAFE'
    END AS Risk_Status,
    
    B.Stock_Qty AS Manufactured_Qty,
    COALESCE(SUM(FGT.Sale_Qty), 0) AS Total_Sold_Qty,
    
    -- Calculate exactly how many units are sitting unsold on the shelf
    (B.Stock_Qty - COALESCE(SUM(FGT.Sale_Qty), 0)) AS Unsold_Inventory

FROM Batch B
JOIN Product_Master PM ON B.Product_ID = PM.Product_ID
LEFT JOIN FG_Transaction FGT ON B.Batch_No = FGT.Batch_No

GROUP BY 
    B.Batch_No, 
    PM.Product_Name, 
    B.Exp_Date, 
    B.Stock_Qty

-- ONLY show batches where we still have unsold inventory
HAVING (B.Stock_Qty - COALESCE(SUM(FGT.Sale_Qty), 0)) > 0

-- Sort the most dangerous (expiring soonest) to the top
ORDER BY Days_Remaining ASC;

SELECT * from v_inventory_expiry_risk;

-- 1. Test "CRITICAL" (Set Expiry to 15 days from today)
UPDATE Batch 
SET Exp_Date = CURRENT_DATE + INTERVAL '15 days' 
WHERE Batch_No = 5001;

-- 2. Test "WARNING" (Set Expiry to 60 days from today)
UPDATE Batch 
SET Exp_Date = CURRENT_DATE + INTERVAL '60 days' 
WHERE Batch_No = 5002;

-- 3. Test "SAFE" (Set Expiry to 1 year from today)
UPDATE Batch 
SET Exp_Date = CURRENT_DATE + INTERVAL '1 year' 
WHERE Batch_No = 5004;

