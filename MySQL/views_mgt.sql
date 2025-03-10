-- File: mysql_views_examples.sql
-- Author: Emmanuel Olafusi
-- Date: March 10, 2025
-- Description: Demonstrates MySQL View creation, modification, and management with examples and technical notes.
-- Target MySQL Version: 8.0+
-- Reference: https://dev.mysql.com/doc/refman/8.0/en/views.html

-- Ensure a clean slate by dropping views if they exist 
DROP VIEW IF EXISTS employee_view;
DROP VIEW IF EXISTS secure_employee_view;
DROP VIEW IF EXISTS dept10_employees;

-- 1. Creating a Simple View from a Single Table
-- Purpose: Filters employees table to show only department 10 employees.
CREATE VIEW employee_view AS
SELECT 
    employee_id,
    first_name,
    last_name,
    salary
FROM 
    employees
WHERE 
    department_id = 10;

-- 2. Modifying a View with CREATE OR REPLACE
-- Purpose: Updates employee_view to include department_id and filter for department 20.
-- Note: Drops and recreates in one step; ensure new query is valid to avoid losing the view.
CREATE OR REPLACE VIEW employee_view AS
SELECT 
    employee_id,
    first_name,
    last_name,
    salary,
    department_id
FROM 
    employees
WHERE 
    department_id = 20;

-- 3. Creating a View with Security Context
-- Purpose: Runs with privileges of the caller (INVOKER), not creator (DEFINER).
-- Note: Useful for auditing or multi-tenant setups; caller needs table access.
CREATE VIEW secure_employee_view
WITH SQL SECURITY INVOKER AS
SELECT 
    employee_id,
    first_name,
    last_name
FROM 
    employees
WHERE 
    department_id = 10;

-- 4. Creating a View with CHECK OPTION
-- Purpose: Restricts INSERT/UPDATE to department 10 only.
CREATE VIEW dept10_employees AS
SELECT 
    employee_id,
    first_name,
    salary,
    department_id
FROM 
    employees
WHERE 
    department_id = 10
WITH CHECK OPTION;

-- 5. Example of Altering a View
-- Purpose: Redefines an existing view entirely.
-- Note: Preserves permissions but requires full rewrite; test before applying.
ALTER VIEW dept10_employees AS
SELECT 
    employee_id,
    first_name,
    salary,
    department_id
FROM 
    employees
WHERE 
    department_id = 10
    AND salary > 50000
WITH CHECK OPTION;

-- 6. Dropping a View
-- Purpose: Removes a view entirely.
-- Note: No data loss (virtual), but breaks dependent scripts/permissions.
DROP VIEW employee_view; 

-- 7. Utility Commands (Commented Out for Reference)
-- List all views in the database
SHOW FULL TABLES IN your_database_name WHERE TABLE_TYPE = 'VIEW';

-- Show view definition
SHOW CREATE VIEW employee_view;

-- Check view dependencies
SELECT TABLE_NAME, REFERENCED_TABLE_NAME
FROM INFORMATION_SCHEMA.VIEW_TABLE_USAGE
WHERE VIEW_NAME = 'employee_view';

-- View metadata from INFORMATION_SCHEMA
SELECT TABLE_NAME, VIEW_DEFINITION
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'your_database_name';

-- 8. Example with Definer (Optional)
-- Purpose: Sets execution context to a specific user.
-- Note: Ensure 'admin'@'localhost' exists and has privileges.
CREATE VIEW employee_view AS
SELECT employee_id, first_name, last_name
FROM employees
WHERE department_id = 10
WITH DEFINER = 'admin'@'localhost';

-- Updates might happen in the future