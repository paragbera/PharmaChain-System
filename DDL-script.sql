CREATE SCHEMA IF NOT EXISTS pharma_manufacturing;

SET search_path TO pharma_manufacturing;

-- 1. Master Tables
CREATE TABLE Material_Master (
    Material_ID          VARCHAR(20)   PRIMARY KEY,
    Material_Name        VARCHAR(30)   NOT NULL,
    Material_Type        VARCHAR(20)   NOT NULL,
    Storage_Condition    VARCHAR(100)  NOT NULL,
    Shelf_Life           NUMERIC(3)    NOT NULL CHECK (Shelf_Life > 0),
    Therapeutic_Category VARCHAR(30)   NOT NULL,
    Material_State       VARCHAR(10)   NOT NULL,
    isHazardous          BOOLEAN       NOT NULL,
    isInflammable        BOOLEAN       NOT NULL,
    UOM                  VARCHAR(3)    NOT NULL,
    Reorder_Level        NUMERIC(10)   DEFAULT 1000 CHECK (Reorder_Level > 0)
);

CREATE TABLE Account_Master (
    Account_No   VARCHAR(11)  PRIMARY KEY,
    Account_Name VARCHAR(50)  NOT NULL,
    Phone_No     VARCHAR(13)  NOT NULL,
    Address      VARCHAR(100) NOT NULL,
    Account_Type VARCHAR(20)  DEFAULT 'Distributor' CHECK (Account_Type IN ('Supplier', 'Distributor', 'Hospital'))
);

CREATE TABLE Employee_Master (
    Emp_ID       VARCHAR(20) PRIMARY KEY,
    Emp_Name     VARCHAR(50) NOT NULL,
    Department   VARCHAR(30) NOT NULL,
    Role         VARCHAR(30) NOT NULL,
    Hire_Date    DATE NOT NULL
);

CREATE TABLE Equipment_Master (
    Equipment_ID          VARCHAR(20) PRIMARY KEY,
    Equipment_Name        VARCHAR(50) NOT NULL,
    Equipment_Type        VARCHAR(30) NOT NULL,
    Last_Calibration_Date DATE NOT NULL,
    Status                VARCHAR(20) NOT NULL CHECK (Status IN ('Active', 'Maintenance'))
);

CREATE TABLE Product_Master (
    Product_ID       VARCHAR(20) PRIMARY KEY,
    Product_Name     VARCHAR(20) NOT NULL,
    Generic_Name     VARCHAR(100) NOT NULL,
    Product_Type     VARCHAR(20) NOT NULL,
    Packing_Type     VARCHAR(10) NOT NULL,
    Packing_Size     VARCHAR(5)  NOT NULL,
    SalableorSample  VARCHAR(1)  NOT NULL CHECK (SalableorSample IN ('M','S')),
    GenericorBranded VARCHAR(1)  NOT NULL CHECK (GenericorBranded IN ('G','B'))
);

-- 2. Transaction & Contract Tables
CREATE TABLE Transactions (
    Invoice_No       NUMERIC(10)   PRIMARY KEY,
    Transaction_Date DATE          NOT NULL,
    Currency         VARCHAR(3)    NOT NULL,
    Transaction_Type VARCHAR(4)    NOT NULL CHECK (Transaction_Type IN ('buy','sell')),
    Paid_Received    BOOLEAN       NOT NULL,
    Account_No       VARCHAR(11)   REFERENCES Account_Master(Account_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Total_Value      NUMERIC(10,2) NOT NULL CHECK (Total_Value > 0)
);

CREATE TABLE Supplier_Contract (
    Contract_ID   VARCHAR(20) PRIMARY KEY,
    Account_No    VARCHAR(11) NOT NULL REFERENCES Account_Master(Account_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Material_ID   VARCHAR(20) NOT NULL REFERENCES Material_Master(Material_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Agreed_Price  NUMERIC(10,2) NOT NULL CHECK (Agreed_Price > 0),
    Valid_Until   DATE NOT NULL
);

-- 3. Warehouse & Inventory
CREATE TABLE Warehouse (
    Item_ID     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Material_ID VARCHAR(20) NOT NULL REFERENCES Material_Master(Material_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Invoice_No  NUMERIC(10) NOT NULL REFERENCES Transactions(Invoice_No) ON DELETE CASCADE ON UPDATE CASCADE,
    UT_Q_A      VARCHAR(2)  NOT NULL,
    Stock       NUMERIC(10) NOT NULL CHECK (Stock > 0),
    CONSTRAINT uq_warehouse_mat_inv UNIQUE (Material_ID, Invoice_No)
);

CREATE TABLE RM_Transaction (
    Invoice_No NUMERIC(10) NOT NULL REFERENCES Transactions(Invoice_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Item_ID    BIGINT      NOT NULL REFERENCES Warehouse(Item_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    RM_Qty     NUMERIC(10)   NOT NULL CHECK (RM_Qty > 0),
    Val        NUMERIC(10,2) NOT NULL CHECK (Val > 0),
    CONSTRAINT pk_rm_transaction PRIMARY KEY (Invoice_No, Item_ID)
);

CREATE TABLE Material_Quality_Check (
    Report_ID     VARCHAR(20)  PRIMARY KEY,
    Item_ID       BIGINT       NOT NULL,
    Analysis_Date DATE         NOT NULL,
    Analyst_Name  VARCHAR(20)  NOT NULL,
    Sample_Size   NUMERIC(10)  NOT NULL CHECK (Sample_Size > 0),
    Test          VARCHAR(20)  NOT NULL,
    Limits        VARCHAR(20)  NOT NULL,
    Results       VARCHAR(30)  NOT NULL,
    Emp_ID        VARCHAR(20)  REFERENCES Employee_Master(Emp_ID) ON DELETE SET NULL,
    CONSTRAINT fk_mqc_warehouse FOREIGN KEY (Item_ID) REFERENCES Warehouse(Item_ID) ON DELETE CASCADE ON UPDATE CASCADE
);

-- 4. Manufacturing & Production
CREATE TABLE Formula_Master (
    Product_ID        VARCHAR(20) NOT NULL REFERENCES Product_Master(Product_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Material_ID       VARCHAR(20) NOT NULL REFERENCES Material_Master(Material_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Weight_per_tablet NUMERIC(10) NOT NULL CHECK (Weight_per_tablet > 0),
    CONSTRAINT pk_formula_master PRIMARY KEY (Product_ID, Material_ID)
);

CREATE TABLE Batch (
    Batch_No         NUMERIC(10) PRIMARY KEY,
    Batch_Size       NUMERIC(10) NOT NULL CHECK (Batch_Size > 0),
    Mfg_Date         DATE        NOT NULL,
    Exp_Date         DATE,
    Product_ID       VARCHAR(20) REFERENCES Product_Master(Product_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Stock_Qty        NUMERIC(10) NOT NULL CHECK (Stock_Qty >= 0),
    UT_Q_A           VARCHAR(2)  NOT NULL,
    Yield_Percentage NUMERIC(5,2) DEFAULT 98.50 CHECK (Yield_Percentage >= 0 AND Yield_Percentage <= 100)
);

CREATE TABLE Material_Dispensing (
    Batch_No         NUMERIC(10) NOT NULL REFERENCES Batch(Batch_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Item_ID          BIGINT      NOT NULL REFERENCES Warehouse(Item_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Quantity_Issued  NUMERIC(10) NOT NULL CHECK (Quantity_Issued > 0),
    CONSTRAINT pk_material_dispensing PRIMARY KEY (Batch_No, Item_ID)
);

CREATE TABLE Production_Log (
    Log_ID        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    Batch_No      NUMERIC(10) NOT NULL REFERENCES Batch(Batch_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Equipment_ID  VARCHAR(20) REFERENCES Equipment_Master(Equipment_ID) ON DELETE SET NULL ON UPDATE CASCADE,
    Emp_ID        VARCHAR(20) REFERENCES Employee_Master(Emp_ID) ON DELETE SET NULL ON UPDATE CASCADE,
    Process_Stage VARCHAR(30) NOT NULL,
    Start_Time    TIMESTAMP NOT NULL,
    End_Time      TIMESTAMP NOT NULL,
    CONSTRAINT chk_time CHECK (End_Time > Start_Time)
);

-- 5. Final Quality & Post-Production
CREATE TABLE Product_Quality_Check (
    Report_ID     VARCHAR(20)  PRIMARY KEY,
    Batch_No      NUMERIC(10)  REFERENCES Batch(Batch_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Analysis_Date DATE         NOT NULL,
    Analyst_Name  VARCHAR(20)  NOT NULL,
    Sample_Size   NUMERIC(10)  NOT NULL CHECK (Sample_Size > 0),
    Process_State VARCHAR(20)  NOT NULL,
    Test          VARCHAR(20)  NOT NULL,
    Limits        VARCHAR(20)  NOT NULL,
    Results       VARCHAR(30)  NOT NULL,
    Emp_ID        VARCHAR(20)  REFERENCES Employee_Master(Emp_ID) ON DELETE SET NULL
);

CREATE TABLE FG_Transaction (
    Invoice_No NUMERIC(10) NOT NULL REFERENCES Transactions(Invoice_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Batch_No   NUMERIC(10) NOT NULL REFERENCES Batch(Batch_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Sale_Qty   NUMERIC(10)   NOT NULL CHECK (Sale_Qty > 0),
    Val        NUMERIC(10,2) NOT NULL CHECK (Val > 0),
    CONSTRAINT pk_fg_transaction PRIMARY KEY (Invoice_No, Batch_No)
);

CREATE TABLE Product_Recall (
    Recall_ID      VARCHAR(20) PRIMARY KEY,
    Batch_No       NUMERIC(10) NOT NULL REFERENCES Batch(Batch_No) ON DELETE CASCADE ON UPDATE CASCADE,
    Date_Initiated DATE NOT NULL,
    Reason         VARCHAR(255) NOT NULL,
    Qty_Recalled   NUMERIC(10) NOT NULL CHECK (Qty_Recalled > 0)
);

CREATE TABLE Maintenance_Log (
    Maintenance_ID   VARCHAR(20) PRIMARY KEY,
    Equipment_ID     VARCHAR(20) NOT NULL REFERENCES Equipment_Master(Equipment_ID) ON DELETE CASCADE ON UPDATE CASCADE,
    Emp_ID           VARCHAR(20) REFERENCES Employee_Master(Emp_ID) ON DELETE SET NULL ON UPDATE CASCADE,
    Maintenance_Date DATE NOT NULL,
    Cost             NUMERIC(10,2) NOT NULL CHECK (Cost >= 0)
);

-- =====================================================================
-- TABLE: Quality Control Audit Log (The Hidden Vault)
-- =====================================================================
CREATE TABLE QC_Audit_Log (
    Audit_ID SERIAL PRIMARY KEY,      -- Auto-increments 1, 2, 3...
    Report_ID VARCHAR(20),            -- Which report was altered?
    Action_Type VARCHAR(10),          -- Was it an UPDATE or a DELETE?
    Old_Result VARCHAR(50),           -- What was the original grade?
    New_Result VARCHAR(50),           -- What did they change it to?
    Changed_By VARCHAR(50),           -- Who is logged into the database?
    Change_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Exact millisecond it happened
);


