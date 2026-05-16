


-- =====================================================================
-- PROCEDURE: Execute Emergency Product Recall (Tailored)
-- DESCRIPTION: Integrates exactly with the user's Product_Recall table,
--              enforcing all custom constraints and VARCHAR keys.
-- =====================================================================

CREATE OR REPLACE PROCEDURE execute_product_recall(
    p_recall_id VARCHAR(20),  -- Added to satisfy your Primary Key
    p_batch_no NUMERIC,
    p_reason VARCHAR(255)     -- Matched to your 255 character limit
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_unsold_qty NUMERIC;
BEGIN
    -- 1. Find out exactly how many units are currently in the warehouse
    SELECT Stock_Qty INTO v_unsold_qty 
    FROM Batch 
    WHERE Batch_No = p_batch_no;

    -- Safety Check A: Does this batch exist?
    IF v_unsold_qty IS NULL THEN
        RAISE EXCEPTION 'RECALL FAILED: Batch % does not exist in the system.', p_batch_no;
    END IF;

    -- Safety Check B: Satisfy your CHECK (Qty_Recalled > 0) constraint
    IF v_unsold_qty <= 0 THEN
         RAISE EXCEPTION 'RECALL FAILED: Batch % has 0 stock in the warehouse. Nothing left to quarantine!', p_batch_no;
    END IF;

    -- 2. Log the event into YOUR exact table
    INSERT INTO Product_Recall (Recall_ID, Batch_No, Date_Initiated, Reason, Qty_Recalled)
    VALUES (p_recall_id, p_batch_no, CURRENT_DATE, p_reason, v_unsold_qty);

    -- 3. Zero out the warehouse stock
    UPDATE Batch 
    SET Stock_Qty = 0 
    WHERE Batch_No = p_batch_no;

    -- 4. Overwrite the Quality Control lab result to quarantine the batch
    UPDATE Product_Quality_Check 
    SET Results = 'RECALLED' 
    WHERE Batch_No = p_batch_no;

END;
$$;

CALL execute_product_recall(
    'REC-5004-A', 
    5004, 
    'CRITICAL: Stability test failed at 6 months. Active ingredient degraded.'
);

SELECT * FROM Product_Recall;

