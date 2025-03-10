-- Create a View from single table 
CREATE VIEW view_name AS
SELECT column1, column2, ...
FROM table_name
WHERE condition;


CREATE VIEW employee_view AS
SELECT employee_id, first_name, last_name, salary
FROM employees
WHERE department_id = 10;

--Modify a View (Alter View)

ALTER VIEW view_name AS
SELECT column1, column2, ...
FROM table_name
WHERE condition;

CREATE OR REPLACE VIEW view_name AS
SELECT column1, column2, ...
FROM table_name
WHERE condition;

CREATE OR REPLACE VIEW employee_view AS
SELECT employee_id, first_name, last_name, salary, department_id
FROM employees
WHERE department_id = 20;


--Drop a View
DROP VIEW view_name;

--Show All Views in a Database
SHOW FULL TABLES IN database_name WHERE TABLE_TYPE = 'VIEW';

--Show View Definition
SHOW CREATE VIEW view_name;

--Definer at the point of creation 
CREATE VIEW view_name AS SELECT ... WITH DEFINER='user'@'host';




