--32

--Question (a) and (c)

--Need to restart the server without using either one of the databases.

/*Create temporary table #OrderDataFromWWI to store the data from WWI OLTP database*/
DROP TABLE IF EXISTS #OrderDataFromWWI;
CREATE TABLE #OrderDataFromWWI (
	OrderID INT,
	DeliveryCityID INT,
	CustomerID INT,
	StockItemID INT,
	OrderDate datetime,
	PickingCompletedWhen datetime,
	SalespersonPersonID INT,
	PickedByPersonID INT,
	BackorderOrderID INT,
	Description nvarchar(MAX),
	PackageTypeID INT,
	Quantity INT,
	UnitPrice DEC(18,2),
	TaxRate DEC(18,3),
	AmountExcludingTax DEC(18,2),
	TaxAmount DEC(18,2),
	TransactionAmount DEC(18,2),
	InvoiceID INT
);

/* Create a stored procedure to collect all the data that need to be migrated from the WWI OLTP database. 
In order to migrate the needed data to ODS, we need to join multiple tables in WWI OLTP database to get the resulting table.
This procedure is about joining tables in OLTP database and generate the resulting table. */
CREATE OR ALTER PROC CollectDataFromOLTP AS
BEGIN
WITH temp AS(SELECT SI.InvoiceID, SI.CustomerID, SI.OrderID, SCT.AmountExcludingTax, SCT.TaxAmount, 
SCT.TransactionAmount FROM 
WideWorldImporters.Sales.CustomerTransactions SCT JOIN WideWorldImporters.Sales.Invoices SI
ON SCT.InvoiceID = SI.InvoiceID),
temp2 AS(SELECT temp.InvoiceID, temp.CustomerID, temp.OrderID, temp.AmountExcludingTax, temp.TaxAmount, 
temp.TransactionAmount, SO.SalespersonPersonID, SO.PickedByPersonID, SO.OrderDate, SO.PickingCompletedWhen,
SO.BackorderOrderID FROM temp JOIN WideWorldImporters.Sales.Orders SO ON temp.OrderID = SO.OrderID),
temp3 AS(SELECT temp2.InvoiceID,temp2.CustomerID, temp2.OrderID, temp2.AmountExcludingTax, temp2.TaxAmount, temp2.TransactionAmount,
temp2.SalespersonPersonID, temp2.PickedByPersonID, temp2.OrderDate, temp2.PickingCompletedWhen,
temp2.BackorderOrderID ,SOL.StockItemID, SOL.Description,SOL.PackageTypeID, SOL.Quantity, SOL.UnitPrice,
SOL.TaxRate FROM temp2 JOIN 
WideWorldImporters.Sales.OrderLines SOL ON temp2.OrderID = SOL.OrderID),
temp4 AS(SELECT temp3.InvoiceID, temp3.CustomerID, temp3.OrderID, temp3.AmountExcludingTax, temp3.TaxAmount, temp3.TransactionAmount,
temp3.SalespersonPersonID, temp3.PickedByPersonID, temp3.OrderDate, temp3.PickingCompletedWhen,
temp3.BackorderOrderID ,temp3.StockItemID, temp3.Description,temp3.PackageTypeID, temp3.Quantity, 
temp3.UnitPrice, temp3.TaxRate, SC.DeliveryCityID FROM temp3 JOIN WideWorldImporters.Sales.Customers SC ON 
temp3.CustomerID = SC.CustomerID)
INSERT INTO #OrderDataFromWWI SELECT OrderID, DeliveryCityID, CustomerID, StockItemID, OrderDate, PickingCompletedWhen, SalespersonPersonID,
PickedByPersonID, BackorderOrderID, Description, PackageTypeID, Quantity, UnitPrice, TaxRate,
AmountExcludingTax, TaxAmount, TransactionAmount,InvoiceID  FROM temp4;
END;

/* Create a stored procedure to migrate the data from OLTP database to ODS. In addition to the resulting table from the last step,
we also need to join the resulting table with multiple dimension tables in the WWI Data Warehouse in order to get the keys such as 
[City Key], [Stock Item Key], [Customer Key], etc. This procedure is about joining the resulting table from the last procedure
with multiple dimension tables from WWI Data Warehouse in order to get keys, and insert the results into Order_Staging ODS table under
Integration scehma.*/
CREATE OR ATER PROC MigratingDataToODS AS
BEGIN
SET IDENTITY_INSERT WideWorldImportersDW.Integration.StockItem_Staging ON;
WITH temp AS(SELECT DD.Date AS [Order Date Key], t.* FROM WideWorldImportersDW.Dimension.Date DD JOIN 
#OrderDataFromWWI t ON DD.Date = CONVERT(date,t.OrderDate)),
temp2 AS(SELECT  DD.Date AS[Picked Date Key], temp.* FROM WideWorldImportersDW.Dimension.Date DD JOIN 
temp ON
DD.Date = CONVERT(date,temp.PickingCompletedWhen)),
temp3 AS(SELECT WD.[Stock Item Key],temp2.* FROM WideWorldImportersDW.Dimension.[Stock Item] WD JOIN temp2
ON wd.[WWI Stock Item ID] = temp2.StockItemID),
temp4 AS(SELECT  WC.[Customer Key] AS [Picker Key],temp3.* FROM WideWorldImportersDW.Dimension.Customer WC JOIN temp3 ON
WC.[WWI Customer ID]=temp3.PickedByPersonID),
temp5 AS(SELECT DC.[City Key],temp4.* FROM WideWorldImportersDW.Dimension.City DC JOIN temp4 ON
temp4.DeliveryCityID = DC.[WWI City ID]),
temp6 AS(SELECT DE.[Employee Key] AS[Salesperson Key], temp5.* FROM WideWorldImportersDW.Dimension.Employee DE JOIN
temp5 ON temp5.SalespersonPersonID = DE.[WWI Employee ID] WHERE DE.[Is Salesperson]=1),
temp7 AS(SELECT WC.[Customer Key] AS [Customer Key],temp6.* FROM WideWorldImportersDW.Dimension.Customer WC 
JOIN temp6 ON WC.[WWI Customer ID]=temp6.CustomerID),
temp8 AS(SELECT FS.[Lineage Key], temp7.* FROM WideWorldImportersDW.Fact.Sale FS JOIN temp7 ON
FS.[WWI Invoice ID] = temp7.InvoiceID)
INSERT INTO WideWorldImportersDW.Integration.Order_Staging SELECT temp8.[City Key],temp8.[Customer Key],temp8.[Stock Item Key],
temp8.[Order Date Key],temp8.[Picked Date Key],temp8.[Salesperson Key],temp8.[Picker Key],  temp8.OrderID AS [WWI Order ID], 
temp8.BackorderOrderID AS[WWI Backorder ID],temp8.Description, CAST(temp8.PackageTypeID AS nvarchar(50)) AS Package, 
temp8.Quantity, temp8.UnitPrice, temp8.TaxRate AS[Tax Rate], temp8.Quantity*UnitPrice AS [Total Excluding Tax],
(temp8.Quantity*temp8.UnitPrice)*TaxRate AS [Tax Amount], (temp8.Quantity*temp8.UnitPrice)*(1+temp8.TaxRate) AS [Total Including Tax], 
temp8.[Lineage Key],temp8.DeliveryCityID, temp8.CustomerID, temp8.StockItemID, temp8.SalespersonPersonID, 
temp8.PickedByPersonID, GETDATE() FROM temp8;
SET IDENTITY_INSERT WideWorldImportersDW.Integration.StockItem_Staging OFF;
END;


/* Create a stored procedure to migrate data from the ODS table from the last step to the Order table under Fact schema.
After the last procedure, we have migrated data in the ODS Order_Staging table. This step is to migrate data from there to
the Fact.[Order] table. And in the meantime, we create the surrogate key here named [Order Key] to act as the primary key
for the Fact.[Order] table. We also add the ingested DateTime which consists of two columns: ValidFrom and ValidTo. We set
their data type as datetime. After this stored procedure, we finally update the Fact.[Order] table in the WWI Data Warehouse. */
CREATE OR ALTER PROC MigratingDataToFactTable AS
BEGIN
DELETE FROM WideWorldImportersDW.Fact.[Order];
SET IDENTITY_INSERT WideWorldImportersDW.Fact.[Order] ON;
INSERT INTO WideWorldImportersDW.Fact.[Order] SELECT newid() AS[Order Key], [City Key], [Customer Key],[Stock Item Key],[Order Date Key],
[Picked Date Key],[Salesperson Key],[Picker Key], [WWI Order ID],[WWI Backorder ID],Description,Package,Quantity,UnitPrice,
[Tax Rate],[Total Excluding Tax],[Tax Amount],[Total Including Tax],[Lineage Key], GETDATE() AS ValidFrom, 
GETDATE()+36500 AS ValidTo FROM WideWorldImportersDW.Integration.StockItem_Staging;
SET IDENTITY_INSERT WideWorldImportersDW.Fact.[Order] OFF;
END;

/* Execute the three stored procedures defined above.*/
EXEC CollectDataFromOLTP;
EXEC MigratingDataToODS;
EXEC MigratingDataToFactTable;

--Question (b)

/* Create a dimension table named CountryOfManufacture with information from StockItem table.*/
USE WideWorldImportersDW;
DROP TABLE IF EXISTS Dimension.CountryOfManufacture;
CREATE TABLE Dimension.CountryOfManufacture (
	StockItemID int,
	StockItemName nvarchar(100),
	TotalQuan int,
	Country nvarchar(50)
);
 WITH temp AS(SELECT SI.StockItemID, SUM(SOL.Quantity) as TotalQuan, JSON_VALUE(SI.CustomFields, '$.CountryOfManufacture')
AS Country FROM WideWorldImporters.Warehouse.StockItems SI JOIN WideWorldImporters.Sales.OrderLines SOL ON  SOL.StockItemID = SI.StockItemID
GROUP BY SI.StockItemID, JSON_VALUE(SI.CustomFields, '$.CountryOfManufacture'))
INSERT INTO Dimension.CountryOfManufacture SELECT temp.StockItemID, SI.StockItemName, temp.TotalQuan, 
temp.Country FROM WideWorldImporters.Warehouse.StockItems SI JOIN temp ON SI.StockItemID = temp.StockItemID;
SELECT * FROM Dimension.CountryOfManufacture;
