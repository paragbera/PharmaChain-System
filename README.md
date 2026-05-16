# PharmaChain-DB 🏥💊

This project is a clean, production-ready database built for pharmaceutical factories. It uses PostgreSQL to automatically track raw materials, handle expiry risks, and manage safe product recalls. With smart automation built right in, it keeps data accurate and ensures strict quality standards without messy manual updates.

A production-ready PostgreSQL database system built for pharmaceutical manufacturing and automated warehouse operations. Designed to meet strict compliance standards, it handles complex inventory and logistics workflows directly inside the database using `PL/pgSQL`. The system ensures reliable data integrity, safely processes multi-step warehouse transactions, and keeps a secure, tamper-proof audit trail to support FDA compliance—all managed at the database level.

## 🚀 System Architecture & BCNF Design

The database architecture is designed to satisfy **Boyce-Codd Normal Form (BCNF)** to eliminate data redundancy, structured across 5 distinct operational layers:

### Core Schema Blueprint
1. **Master Registries:** `Material_Master`, `Account_Master`, `Employee_Master`, `Equipment_Master`, `Product_Master`.
2. **Financials & Logistics:** `Transactions` (unified buy/sell accounting) and `Supplier_Contract`.
3. **Inventory Pipeline:** `Warehouse` (serialized tracking with unique key pairing), `RM_Transaction`, and `Material_Quality_Check`.
4. **Production Floor:** `Formula_Master`, `Batch`, `Material_Dispensing`, and `Production_Log` (with asynchronous clock validation).
5. **Post-Production Compliance:** `Product_Quality_Check`, `FG_Transaction`, `Product_Recall`, and `Maintenance_Log`.

---

## 🛡️ Active Automation & Advanced PL/pgSQL Layers

Instead of relying on unstable frontend logic, this system is **self-defending**—using reactive database triggers and atomic transactional scripts to maintain corporate security.

### 1. Smart Warehouse Auto-Deduction (`trg_deduct_stock_on_dispense`)
* **Mechanism:** Listens `AFTER INSERT` on `Material_Dispensing`.
* **Action:** Automatically subtracts quantities issued to a batch from raw material storage. 
* **Fail-Safe:** Intercepts the transaction and throws a hard rollback if warehouse stock drops below the requested allocation amount.

### 2. FDA Sales Compliance Blocker (`trg_prevent_bad_sales`)
* **Mechanism:** Listens `BEFORE INSERT` on `FG_Transaction`.
* **Action:** Validates the targeted batch against the `Product_Quality_Check` laboratory data registry.
* **Fail-Safe:** Blocks commercial invoicing with custom exceptions if a batch is completely untested (`NULL`) or explicitly flagged as `FAILED`.

### 3. Dynamic Date & Shelf-Life Validator (`trg_strict_batch_dates`)
* **Mechanism:** Protects the `Batch` table `BEFORE INSERT OR UPDATE`.
* **Action:** Restricts temporal anomalies (manufacturing dates cannot exist in the future) and strictly mandates a minimum 6-month product expiration shelf-life window.

### 4. Decoupled Compliance Audit Vault (`trg_audit_qc_changes`)
* **Mechanism:** Listens `AFTER UPDATE OR DELETE` on `Product_Quality_Check`.
* **Action:** Captures and pushes old vs. new grading metrics, the specific system action, and the current session user into an independent, immutable ledger (`QC_Audit_Log`). Designed to fulfill **FDA 21 CFR Part 11** guidelines by completely isolating logs from cascading deletions.

---

## 📊 Analytical Views (Real-Time Dashboards)

* **`v_fda_batch_traceability`**: Pulls an absolute end-to-end trace map of every batch—aggregating raw ingredients used into a single row using string arrays (`STRING_AGG`), checking lab statuses, and displaying overall market sales distribution.
* **`v_inventory_shortage`**: A real-time purchasing engine dashboard that monitors active storage capacities against reorder boundaries, calculating precise inventory gaps.
* **`v_inventory_expiry_risk`**: A financial liability manager that utilizes dynamic calendar day subtraction math (`Exp_Date - CURRENT_DATE`) and conditional matrix logic (`CASE WHEN`) to instantly categorize un-shipped goods into `CRITICAL`, `WARNING`, or `SAFE` statuses.

---

## ⚙️ Transaction Operations (Procedures)

### Emergency Product Recall System (`execute_product_recall`)
An advanced PL/pgSQL stored procedure designed to cleanly manage multi-table crisis events in a single transaction block. 
```sql
CALL execute_product_recall('REC-5004-A', 5004, 'CRITICAL: Structural instability noted.');
```

When invoked, this transaction completely automates:

1. Validating asset parameters and checking safety constraints (Qty_Recalled > 0).

2. Logging the incident details into the active regulatory registry (Product_Recall).

3. Dropping available inventory stock directly to 0 inside the Batch table.

4. Forcing lab statuses to RECALLED to instantly wake up the downstream sales block trigger.


## 🚀 Getting Started & Local Schema Deployment
Prerequisites
PostgreSQL v12 or higher installed.

### 1.Setup Instructions
Clone the repository:

```Bash
git clone [https://github.com/your-username/PharmaChain-DB.git](https://github.com/your-username/PharmaChain-DB.git)
```

### 2.Run the initialization script inside your terminal or pgAdmin Query Tool to create the schema, build the logic tables, and populate the seed dataset:

```Bash
psql -U postgres -d your_database_name -f schema_and_data.sql
```
