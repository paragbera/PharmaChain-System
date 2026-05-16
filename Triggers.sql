
--- Trigger - 1 is based on material dispensing : this trigger is getting firee
-- when we deduct stock

-- =====================================================================
-- FUNCTION: Automate Warehouse Stock Deduction
-- DESCRIPTION: When a batch takes material, deduct it from the warehouse.
--              If there isn't enough stock, block the transaction.
-- =====================================================================

CREATE OR REPLACE FUNCTION automate_warehouse_stock()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_stock NUMERIC(10);
BEGIN
    -- 1. Find out how much stock we currently have for this specific item
    SELECT Stock INTO v_current_stock 
    FROM Warehouse 
    WHERE Item_ID = NEW.Item_ID;

    -- 2. Safety Check: Do we have enough stock to fulfill this request?
    IF v_current_stock < NEW.Quantity_Issued THEN
        RAISE EXCEPTION 'Transaction Blocked: Not enough stock! Item % only has % units left, but you tried to dispense %.', 
                        NEW.Item_ID, v_current_stock, NEW.Quantity_Issued;
    END IF;

    -- 3. If we have enough stock, safely deduct it from the Warehouse
    UPDATE Warehouse
    SET Stock = Stock - NEW.Quantity_Issued
    WHERE Item_ID = NEW.Item_ID;

    -- 4. Allow the original INSERT into Material_Dispensing to finish
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_deduct_stock_on_dispense
AFTER INSERT ON Material_Dispensing
FOR EACH ROW
EXECUTE FUNCTION automate_warehouse_stock();

--- This is an example of trigger when
INSERT INTO Material_Dispensing (Batch_No, Item_ID, Quantity_Issued) VALUES (5001, 2, 999999);


--- Trigger-2 :

-- =====================================================================
-- FUNCTION: FDA Compliance Enforcer
-- DESCRIPTION: Prevents the sale of any batch in FG_Transaction if it 
--              failed Quality Control or hasn't been tested yet.
-- =====================================================================

CREATE OR REPLACE FUNCTION enforce_quality_control()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_qa_result VARCHAR(30);
BEGIN
    -- 1. Look up the official lab result for the batch they are trying to sell
    SELECT Results INTO v_qa_result
    FROM Product_Quality_Check
    WHERE Batch_No = NEW.Batch_No;

    -- 2. Safety Rule A: Has it been tested at all?
    IF v_qa_result IS NULL THEN
        RAISE EXCEPTION 'COMPLIANCE BLOCK: Batch % has not been tested by the QC Lab yet. Sale is illegal!', NEW.Batch_No;
    END IF;

    -- 3. Safety Rule B: Did it fail the test?
    IF v_qa_result = 'FAILED' THEN
        RAISE EXCEPTION 'SAFETY BLOCK: Batch % FAILED quality control. This batch must be quarantined, not sold!', NEW.Batch_No;
    END IF;

    -- 4. If it exists and didn't fail (i.e., 'PASSED'), allow the sale to proceed
    RETURN NEW;
END;
$$;

-- Bind the trigger to fire BEFORE the sale is finalized
CREATE TRIGGER trg_prevent_bad_sales
BEFORE INSERT ON FG_Transaction
FOR EACH ROW
EXECUTE FUNCTION enforce_quality_control();


-- Trying to sell Batch 5003 to Invoice 2020
INSERT INTO FG_Transaction (Invoice_No, Batch_No, Sale_Qty, Val) 
VALUES (2020, 5003, 1000, 50000.00);

-- Trying to sell an unverified Batch 5000
INSERT INTO FG_Transaction (Invoice_No, Batch_No, Sale_Qty, Val) 
VALUES (2020, 5000, 1000, 50000.00);

-- Selling a safe batch
INSERT INTO FG_Transaction (Invoice_No, Batch_No, Sale_Qty, Val) 
VALUES (2020, 5001, 1000, 50000.00);

-- Trigger 3:
-- =====================================================================
-- FUNCTION: Strict Batch Date Enforcer
-- DESCRIPTION: Prevents setting manufacturing dates in the future, and 
--              ensures a minimum 6-month shelf life.
-- =====================================================================

CREATE OR REPLACE FUNCTION enforce_batch_dates()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    -- Rule 1: Prevent "Time Travel" (Manufacturing in the future)
    IF NEW.Mfg_Date > CURRENT_DATE THEN
        RAISE EXCEPTION 'TIME TRAVEL DETECTED: You cannot set a Manufacturing Date (%) in the future!', NEW.Mfg_Date;
    END IF;

    -- Rule 2: Ensure minimum 6-month shelf life
    -- (We add 6 months to the Mfg_Date and compare it to Exp_Date)
    IF NEW.Exp_Date < (NEW.Mfg_Date + INTERVAL '6 months') THEN
        RAISE EXCEPTION 'QUALITY BLOCK: The Expiry Date (%) must be at least 6 months after the Manufacturing Date (%).', NEW.Exp_Date, NEW.Mfg_Date;
    END IF;

    -- If both rules pass, allow the INSERT or UPDATE to finish
    RETURN NEW;
END;
$$;

-- Bind the trigger to fire BEFORE BOTH Inserts and Updates!
CREATE TRIGGER trg_strict_batch_dates
BEFORE INSERT OR UPDATE ON Batch
FOR EACH ROW
EXECUTE FUNCTION enforce_batch_dates();

UPDATE Batch  SET Mfg_Date = '2099-01-01' WHERE Batch_No = 5001;

INSERT INTO Batch (Batch_No, Batch_Size, Mfg_Date, Exp_Date, Product_ID, Stock_Qty) 
VALUES (9999, 10000, '2024-01-01', '2024-02-01', 'PRD001', 10000);


-- TRIGGER 4:
-- =====================================================================
-- FUNCTION: The Silent Auditor
-- DESCRIPTION: Tracks any modifications or deletions of Lab Results.
-- =====================================================================
CREATE OR REPLACE FUNCTION track_qc_changes()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    -- SCENARIO A: Someone is trying to UPDATE a lab result
    IF TG_OP = 'UPDATE' THEN
        -- If the result actually changed, log the evidence!
        IF OLD.Results IS DISTINCT FROM NEW.Results THEN
            INSERT INTO QC_Audit_Log (Report_ID, Action_Type, Old_Result, New_Result, Changed_By)
            VALUES (OLD.Report_ID, 'UPDATE', OLD.Results, NEW.Results, CURRENT_USER);
        END IF;
        RETURN NEW;

    -- SCENARIO B: Someone is trying to totally DELETE a lab record
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO QC_Audit_Log (Report_ID, Action_Type, Old_Result, New_Result, Changed_By)
        VALUES (OLD.Report_ID, 'DELETE', OLD.Results, 'RECORD DESTROYED', CURRENT_USER);
        RETURN OLD;
    END IF;
END;
$$;

-- Bind the trigger to listen AFTER someone touches the QC table
CREATE TRIGGER trg_audit_qc_changes
AFTER UPDATE OR DELETE ON Product_Quality_Check
FOR EACH ROW
EXECUTE FUNCTION track_qc_changes();


UPDATE Product_Quality_Check SET Results = 'PASSED' WHERE Report_ID = 'PQC003';

DELETE FROM Product_Quality_Check WHERE Report_ID = 'PQC005';

SELECT * FROM QC_Audit_Log;

