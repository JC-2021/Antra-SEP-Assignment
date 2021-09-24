-- Assignments
USE WideWorldImporters;
--Q1 
SELECT APT.FullName, tab.PersonPhoneNum, tab.PersonFaxNum, tab.CustomerPhoneNum, tab.CustomerFaxNum FROM 
Application.People APT LEFT JOIN
((SELECT AP.PersonID, AP.FullName, AP.PhoneNumber AS PersonPhoneNum, AP.FaxNumber AS PersonFaxNum,  
SC.PhoneNumber AS CustomerPhoneNum, SC.FaxNumber AS CustomerFaxNum FROM Application.People AP JOIN Sales.Customers SC ON
AP.PersonID = SC.PrimaryContactPersonID)
UNION
(
SELECT AP.PersonID, AP.FullName, AP.PhoneNumber AS PersonPhoneNum, AP.FaxNumber AS PersonFaxNum,  
SC.PhoneNumber AS CustomerPhoneNum, SC.FaxNumber AS CustomerFaxNum FROM Application.People AP JOIN Sales.Customers SC ON
AP.PersonID = SC.AlternateContactPersonID
)) tab ON APT.PersonID = tab.PersonID;


--Q2

SELECT SC.CustomerName AS CustomerCompany FROM Sales.Customers SC JOIN Application.People P ON 
SC.PrimaryContactPersonID = P.PersonID WHERE SC.PhoneNumber = P.PhoneNumber;

--Q3
/*Idea:
	For all customers to whom we made sales, we partition the data by CustomerID and order the data by OrderDate in desceding
	order. This means we want to show all the orders for each customer in descending order of OrderDate. After doing so,
	we take the rank 1 order for each customer. The rank 1 order's OrderDate must be prior to 2016-01-01 according to
	the question. After picking rank 1 order for each customer and filter the customers by OrderDate less than 2016-01-01,
	we get the empty set of customers. This means all customers to whom we made sales have at least one sale happening 
	after 2016-01-01.
*/
WITH temp AS(SELECT CustomerID, SO.OrderDate, row_number() over(PARTITION BY SO.CustomerID ORDER BY SO.OrderDate DESC) AS ranking 
FROM Sales.Orders SO) SELECT temp.CustomerID FROM temp WHERE YEAR(temp.OrderDate) < '2016' AND temp.ranking=1;

--Q4
WITH temp AS (SELECT POL.StockItemID, SUM(POL.OrderedOuters) AS SumOuters FROM Purchasing.PurchaseOrders PO JOIN 
Purchasing.PurchaseOrderLines POL ON PO.PurchaseOrderID = POL.PurchaseOrderID WHERE OrderDate >= 
'2013-01-01' AND OrderDate <'2014-01-01' GROUP BY POL.StockItemID),
temp2 AS (SELECT SI.StockItemName, SI.QuantityPerOuter, temp.SumOuters FROM temp JOIN Warehouse.StockItems 
SI ON temp.StockItemID = SI.StockItemID) SELECT StockItemName, QuantityPerOuter*SumOuters AS TotalQuantity
FROM temp2;

--Q5
SELECT DISTINCT SI.StockItemName, POL.Description FROM Purchasing.PurchaseOrderLines POL JOIN Warehouse.StockItems SI ON POL.StockItemID
= SI.StockItemID WHERE LEN(POL.Description) >= 10;


--Q6
/*
	Idea:
	
	First, select all the stock items that are sold in either Alabama or Georgia in 2014.

		For this part, a table variable @StockItemsAlabamaGeorgia  is declared.
		We use OrderLines table to join with Orders table to get StockItemID as well as the 
		OrderDate, we filter the data with OrderDate within Year 2014.
		Then we join the resulting table with Customers table to get deliveryCityID.
		Then we join the resulting table with Cities table to get StateProvinceID.
		Then we join the resulting table with StateProvinces table to get StateProvinceName.
		Then we filter the data with StateProvinceName being either Alabama or Georgia.
		Then we select the distinct StockItemID and insert the result into the 
		declared table variable.
	
	Secondly, select all possible StockItemIDs from the StockItems table in the Warehouse schema,
	excluding those StockItemIDs which are stored in the table variable @StockItemsAlabamaGeorgia.

*/
BEGIN
DECLARE @StockItemsAlabamaGeorgia TABLE (
	StockItemID INT
);
WITH temp AS(SELECT SOL.OrderLineID, SOL.StockItemID, SO.OrderDate, SO.CustomerID FROM Sales.OrderLines SOL JOIN 
Sales.Orders SO ON SOL.OrderID = SO.OrderID WHERE YEAR(SO.OrderDate) = '2014'),
temp2 AS(SELECT temp.OrderLineID, temp.StockItemID, temp.OrderDate, SC.DeliveryCityID FROM temp
JOIN Sales.Customers SC ON temp.CustomerID = SC.CustomerID),
temp3 AS(SELECT temp2.OrderLineID, temp2.StockItemID, temp2.OrderDate, AC.StateProvinceID FROM
temp2 JOIN Application.Cities AC ON temp2.DeliveryCityID = AC.CityID),
temp4 AS(SELECT temp3.OrderLineID, temp3.StockItemID, temp3.OrderDate FROM temp3 JOIN 
Application.StateProvinces ASP ON temp3.StateProvinceID = ASP.StateProvinceID 
WHERE ASP.StateProvinceName = 'Alabama' OR  ASP.StateProvinceName = ' Georgia') 
INSERT INTO @StockItemsAlabamaGeorgia SELECT DISTINCT StockItemID FROM temp4;
SELECT  StockItemID FROM Warehouse.StockItems WHERE StockItemID NOT IN
(SELECT * FROM @StockItemsAlabamaGeorgia);
END;


--Q7

/* 
	Idea:
		For ConfirmedDeliveryDate, we use ConfirmedDeliveryTime from Sales.Invoices.
		For OrderDate, we use OrderDate from Sales.Orders.
		First, join Sales.Invoices and Sales.Orders.
		Secondly, join the result with Sales.Customers. 
		Then, join with Application.Cities and GROUP BY StateProvinceID.
		Finally, join with Application.StateProvinceName to get the names of the states.
*/
WITH temp AS(SELECT SC.OrderID, SC.CustomerID, SC.OrderDate, SI.ConfirmedDeliveryTime, DATEDIFF(day,SC.OrderDate,
SI.ConfirmedDeliveryTime) AS ProcessingDate FROM Sales.Orders SC JOIN Sales.Invoices SI 
ON SC.OrderID = SI.OrderID),
temp2 AS(SELECT temp.OrderID, temp.ProcessingDate, SC.DeliveryCityID FROM temp JOIN Sales.Customers SC ON 
temp.CustomerID = SC.CustomerID),
temp3 AS(SELECT AVG(temp2.ProcessingDate) AS AvgDate, AC.StateProvinceID FROM temp2 JOIN Application.Cities AC ON 
temp2.DeliveryCityID = AC.CityID GROUP BY AC.StateProvinceID)
SELECT ASP.StateProvinceName, temp3.AvgDate FROM temp3 JOIN Application.StateProvinces ASP ON temp3.StateProvinceID = 
ASP.StateProvinceID;

-- Q8 
/*
	Idea:
		The idea is the same as the previous question. But this time we need to group the data by 
		both state and month. In this way, we can compute the average processing days given a certain state
		and a certain month.

*/
WITH temp AS(SELECT SC.OrderID, SC.CustomerID, SC.OrderDate, SI.ConfirmedDeliveryTime, MONTH(SC.OrderDate) 
AS OrderMonth, DATEDIFF(day,SC.OrderDate, SI.ConfirmedDeliveryTime) AS ProcessingDate FROM Sales.Orders SC 
JOIN Sales.Invoices SI ON SC.OrderID = SI.OrderID),
temp2 AS(SELECT temp.OrderID, temp.ProcessingDate, temp.OrderMonth, SC.DeliveryCityID FROM temp JOIN 
Sales.Customers SC ON temp.CustomerID = SC.CustomerID),
temp3 AS(SELECT AVG(temp2.ProcessingDate) AS AvgDate, temp2.OrderMonth, AC.StateProvinceID FROM temp2 JOIN 
Application.Cities AC ON temp2.DeliveryCityID = AC.CityID GROUP BY AC.StateProvinceID, temp2.OrderMonth)
SELECT ASP.StateProvinceName, temp3.OrderMonth, temp3.AvgDate FROM temp3 JOIN Application.StateProvinces ASP ON 
temp3.StateProvinceID = ASP.StateProvinceID ORDER BY ASP.StateProvinceID, temp3.OrderMonth;

--Q9
/*
	Idea:
	First, we join the PurchaseOrders table with PurchaseOrderLines table to get the StockItemID, OrderedOuters
	and the we group by the data by StockItemID to compute the sum of al, OrderedOuters for each stock item,
	and at the same time we filter the data with OrderDate in the year of 2015.
	Secondly, we compute the actual quantities that the company purchased in 2015 by multiplying number of OrderedOuters
	by the quantity per outer.
	Then, by joining Orders table and OrderLines table, we compute the total quantities 
	for each stock item that the company sold in 2015. Here, again we group the data by StockItemID and filter the data
	by the year of 2015.
	Lastly, we do a full outer join between two resulting tables above (Purchase and Sold). The reason why a full outer
	join is performed is because some stock items that are sold in 2015 may not be purchased at all in 2015 and vice versa.
	Therefore, after a full outer join, if for a stock item, the purchased number is larger than the sold number, then 
	we select it. If for a stock item, the sold number is NULL, we also select it because it means this stock item is 
	purchased in 2015 but is sold at all.

*/
WITH Purchase1 AS(SELECT POL.StockItemID, SUM(POL.OrderedOuters) AS NumOfOuters FROM Purchasing.PurchaseOrderLines POL 
JOIN Purchasing.PurchaseOrders PO ON POL.PurchaseOrderID = PO.PurchaseOrderID WHERE PO.OrderDate>='2015-01-01' 
AND PO.OrderDate<'2016-01-01' GROUP BY POL.StockItemID),
Purchase2 AS(SELECT Purchase1.StockItemID, (Purchase1.NumOfOuters)*(WS.QuantityPerOuter) AS TotalQuantity FROM Purchase1 JOIN 
Warehouse.StockItems WS ON Purchase1.StockItemID = WS.StockItemID),
Sold AS(SELECT SOL.StockItemID, SUM(SOL.Quantity) AS TotalQuantity FROM Sales.OrderLines SOL JOIN Sales.Orders SO ON SOL.OrderID = SO.OrderID 
WHERE SO.OrderDate >='2015-01-01' AND SO.OrderDate <'2016-01-01' GROUP BY SOL.StockItemID)
SELECT Purchase2.StockItemID FROM Purchase2 FULL OUTER JOIN 
Sold ON Purchase2.StockItemID = Sold.StockItemID WHERE Sold.TotalQuantity IS NULL OR Purchase2.TotalQuantity > Sold.TotalQuantity;

--Q10
/*
	Idea:
	we filter the stock items by using IN operator to filter all stock items that are in a group of stock items
	which contain 'mug' characters on their names. And also use LIKE operator on StockItemName to filter the stock items.
	And meanwhile we filter the data by the year of 2016 and group the data by the customerID with 
	a HAVING condition to limit the number of sold quantities within 10 or less. In this way, we can know which customers
	sold no more than 10 mugs in 2016. And finally we join the resulting table with Customers table and People table to get
	their information.

	In this question, I learned something important and useful:
	ORDER BY CANNOT be used in CTE, subqueries, temporary tabes, or view.

*/
WITH temp AS(SELECT SO.CustomerID, SUM(SOL.Quantity) AS TotalQuantity FROM Sales.Orders SO JOIN Sales.OrderLines SOL ON 
SO.OrderID = SOL.OrderID WHERE YEAR(SO.OrderDate)='2016'
AND SOL.StockItemID IN (SELECT StockItemID FROM Warehouse.StockItems WHERE StockItemName LIKE '%mug%') GROUP BY SO.CustomerID
HAVING SUM(SOL.Quantity) <=10) 
SELECT temp2.CustomerID, temp2.PhoneNumber AS CustomerPhoneNum, AP.FullName AS PrimaryContactPerson 
FROM (SELECT temp.CustomerID, SC.PhoneNumber, 
SC.PrimaryContactPersonID, temp.TotalQuantity FROM temp JOIN Sales.Customers SC ON 
temp.CustomerID = SC.CustomerID) temp2 JOIN Application.People AP ON temp2.PrimaryContactPersonID = AP.PersonID 
ORDER BY CustomerID;



--Q11
select * from Application.Cities where ValidFrom > '2015-01-01';


--Q12 

WITH temp AS(SELECT SOL.OrderLineID, SOL.StockItemID, SOL.Quantity, SO.CustomerID, SO.OrderDate FROM Sales.OrderLines SOL JOIN Sales.Orders SO ON
SO.OrderID = SOL.OrderID WHERE SO.OrderDate = '2014-07-01'),
temp2 AS(SELECT temp.OrderLineID, temp.StockItemID, temp.Quantity, SC.CustomerName, SC.PrimaryContactPersonID,
SC.AlternateContactPersonID, SC.PhoneNumber, 
SC.DeliveryAddressLine1, SC.DeliveryAddressLine2, SC.DeliveryCityID
FROM temp JOIN Sales.Customers SC ON SC.CustomerID = temp.CustomerID),
temp4
AS(SELECT temp2.StockItemID, temp2.DeliveryAddressLine1, temp2.DeliveryAddressLine2, temp3.StateProvinceName,
temp3.CityName, temp3.CountryID, temp2.CustomerName, temp2.PrimaryContactPersonID, temp2.AlternateContactPersonID,
temp2.PhoneNumber,temp2.Quantity FROM temp2 JOIN (SELECT AC.CityID, AC.CityName,SP.StateProvinceName, SP.CountryID FROM 
Application.StateProvinces SP JOIN Application.Cities AC ON SP.StateProvinceID = AC.StateProvinceID) temp3 ON 
temp2.DeliveryCityID = temp3.CityID),
temp5 AS(SELECT WS.StockItemName, temp4.DeliveryAddressLine1, temp4.DeliveryAddressLine2, temp4.StateProvinceName,
temp4.CityName, temp4.CountryID, temp4.CustomerName, temp4.PrimaryContactPersonID, temp4.AlternateContactPersonID,
temp4.PhoneNumber,temp4.Quantity FROM temp4 JOIN Warehouse.StockItems WS ON temp4.StockItemID = WS.StockItemID),
temp6 AS(SELECT temp5.StockItemName, temp5.DeliveryAddressLine1, temp5.DeliveryAddressLine2, temp5.StateProvinceName,
temp5.CityName, temp5.CountryID, temp5.CustomerName, AP.FullName AS PrimaryContactPersonName, temp5.AlternateContactPersonID,
temp5.PhoneNumber,temp5.Quantity FROM temp5 LEFT JOIN Application.People AP ON temp5.PrimaryContactPersonID
= AP.PersonID) SELECT temp6.StockItemName, temp6.DeliveryAddressLine1, temp6.DeliveryAddressLine2, temp6.StateProvinceName,
temp6.CityName, temp6.CountryID, temp6.CustomerName, temp6.PrimaryContactPersonName, AP.FullName AS AlternateContactPersonName,
temp6.PhoneNumber,temp6.Quantity FROM temp6 LEFT JOIN Application.People AP ON temp6.AlternateContactPersonID = AP.PersonID;




/*13.	List of stock item groups and total quantity purchased, total quantity sold, 
and the remaining stock quantity (quantity purchased – quantity sold)*/


WITH temp AS(SELECT POL.StockItemID, (POL.OrderedOuters)*(WS.QuantityPerOuter) AS TotalQuantity
FROM Purchasing.PurchaseOrderLines POL JOIN Warehouse.StockItems WS
ON POL.StockItemID = WS.StockItemID),
temp2 AS(SELECT SISG.StockGroupID, SUM(temp.TotalQuantity) AS SumQuantity FROM temp JOIN Warehouse.StockItemStockGroups SISG ON
temp.StockItemID = SISG.StockItemID GROUP BY SISG.StockGroupID),
temp3 AS(SELECT SISG.StockGroupID, SUM(SO.Quantity) AS SumQuantity FROM Sales.OrderLines SO JOIN Warehouse.StockItemStockGroups SISG ON 
SO.StockItemID = SISG.StockItemID GROUP BY SISG.StockGroupID)
SELECT temp2.StockGroupID, temp2.SumQuantity AS PurchasedQuan, temp3.SumQuantity AS SoldQuan, 
(temp2.SumQuantity -  temp3.SumQuantity) AS RemainingQuan FROM temp2 JOIN temp3 ON temp2.StockGroupID = temp3.StockGroupID
ORDER BY temp2.StockGroupID;

/*14.	List of Cities in the US and the stock item that the city got the most deliveries in 2016. 
If the city did not purchase any stock items in 2016, print “No Sales”.*/

-- Create a view named AllCities. This view contains all cities in US.


-- Create a view named MostDelievered. This view contains all the cities which participate in the delivery in 2016, 
-- as well as the stock item that got most deliveries for each participated city. For each participated city, we may 
-- have more than one most delivered stock items, if so, all most-delivered stock items are selected.

-- First, join Customer with Order to get OrderID and the DeliveryCity for each OrderID in 2016;
-- Then, join the resulting table with OrderLines table to get the DeliveryCity for each Stock Item because each OrderID may
-- have more than one Stock Items, and we need to know every single Stock Item which are delivered in a certain city;
-- Then, we group the resulting table by both DeliveryCity and Stock Item, and for aggregation function, we simply count the rows
-- by using COUNT(*) which means the number of delivered times. Because in this way we can know that for a certain DeliveryCity 
-- and a certain Stock Item, how many times are this Stock Item delivered in this particular city;
-- Then, we apply a window function. We partition the resulting table by DeliveryCity and do a ranking of number of delivered times
-- in descending order, and then we take the Stock Item with the first ranking for each DeliveryCity. Note that there may be more than
-- one Stock Items with the first ranking(most deliveries), in that case we take them all.

CREATE TABLE #AllCities (
CityID INT);
INSERT INTO #AllCities SELECT AC.CityID FROM Application.Cities AC JOIN Application.StateProvinces ASP ON
AC.StateProvinceID = ASP.StateProvinceID WHERE ASP.CountryID = (SELECT ACo.CountryID FROM Application.Countries ACo 
WHERE ACo.CountryName='United States');


CREATE TABLE #MostDelivered (
DeliveryCityID INT,
StockItemID INT,
ranking INT
);
WITH temp AS(SELECT SO.OrderID, SC.DeliveryCityID FROM Sales.Customers SC JOIN Sales.Orders SO ON SC.CustomerID = SO.CustomerID
WHERE YEAR(SO.OrderDate) = '2016' AND SC.DeliveryCityID IN (SELECT ALC.CityID FROM #AllCities ALC)),
temp2 AS(SELECT temp.DeliveryCityID, SOL.StockItemID FROM Sales.OrderLines SOL JOIN temp ON temp.OrderID = SOL.OrderID),
temp3 AS(SELECT temp2.DeliveryCityID, temp2.StockItemID, COUNT(*) AS NumOfStockItems FROM temp2 GROUP BY temp2.DeliveryCityID, temp2.StockItemID),
temp4 AS(SELECT *, rank() over (PARTITION BY DeliveryCityID ORDER BY NumOfStockItems DESC) AS ranking FROM temp3 DC)
INSERT INTO #MostDelivered SELECT temp4.DeliveryCityID, temp4.StockItemID, temp4.ranking FROM temp4 WHERE temp4.ranking = 1;
ALTER TABLE #MostDelivered ALTER COLUMN StockItemID sql_variant;

MERGE #MostDelivered
USING #AllCities
ON #MostDelivered.DeliveryCityID = #AllCities.CityID
WHEN NOT MATCHED BY TARGET THEN
INSERT (DeliveryCityID, StockItemID, ranking) VALUES(#AllCities.CityID,'No Sales',NULL);

SELECT DeliveryCityID, StockItemID FROM #MostDelivered ORDER BY DeliveryCityID;




--15.	List any orders that had more than one delivery attempt (located in invoice table).

SELECT JSON_QUERY(SI.ReturnedDeliveryData,'$.Events[2]') AS MoreThanOneAttempt FROM Sales.Invoices SI
WHERE JSON_QUERY(SI.ReturnedDeliveryData,'$.Events[2]') IS NOT NULL;

--16.	List all stock items that are manufactured in China. (Country of Manufacture)

SELECT StockItemID, JSON_VALUE(WSI.CustomFields,'$.CountryOfManufacture') AS CountryOfManufacure 
FROM Warehouse.StockItems WSI WHERE JSON_VALUE(WSI.CustomFields,'$.CountryOfManufacture')='China';

-- 17.	Total quantity of stock items sold in 2015, group by country of manufacturing.
WITH temp AS(SELECT SOL.StockItemID, SUM(SOL.Quantity) AS TotalQuanPerStockItem FROM Sales.Orders SO 
JOIN Sales.OrderLines SOL ON SO.OrderID = SOL.OrderID WHERE YEAR(SO.OrderDate)=2015 GROUP BY StockItemID)
SELECT JSON_VALUE(WSI.CustomFields,'$.CountryOfManufacture') AS CountryOfManufacture, 
SUM(temp.TotalQuanPerStockItem) AS TotalQuantity FROM Warehouse.StockItems WSI JOIN temp ON 
WSI.StockItemID = temp.StockItemID GROUP BY JSON_VALUE(WSI.CustomFields,'$.CountryOfManufacture');


--18. Create a view that shows the total quantity of stock items of each stock group sold (in orders) 
-- by year 2013-2017. [Stock Group Name, 2013, 2014, 2015, 2016, 2017]
--
CREATE OR ALTER VIEW TotalQuantites AS
WITH temp AS(SELECT SOL.StockItemID, SUM(SOL.Quantity) AS TotalQuanPerStockItem,YEAR(SO.OrderDate) 
AS OrderYear FROM Sales.Orders SO 
JOIN Sales.OrderLines SOL ON SO.OrderID=SOL.OrderID WHERE YEAR(SO.OrderDate) BETWEEN '2013' AND '2017'
GROUP BY StockItemID,YEAR(SO.OrderDate)),
temp2 AS(SELECT SISG.StockGroupID, temp.OrderYear, SUM(temp.TotalQuanPerStockItem) AS TotalQuanPerGroupYear 
FROM Warehouse.StockItemStockGroups SISG JOIN temp ON SISG.StockItemID = temp.StockItemID 
GROUP BY SISG.StockGroupID, temp.OrderYear)
SELECT StockGroupID, [2013],[2014],[2015],[2016],[2017] FROM
(SELECT StockGroupID, OrderYear, TotalQuanPerGroupYear FROM temp2) AS SourceTable
PIVOT
(
MIN(TotalQuanPerGroupYear) FOR OrderYear IN ([2013],[2014],[2015],[2016],[2017])
) AS PivotTable;

SELECT * FROM TotalQuantites ORDER BY StockGroupID;

--19.Create a view that shows the total quantity of stock items of each stock group sold (in orders) 
-- by year 2013-2017. 
-- [Year, Stock Group Name1, Stock Group Name2, Stock Group Name3, … , Stock Group Name10] 

CREATE OR ALTER VIEW TotalQuantities2 AS
WITH temp AS(SELECT SOL.StockItemID, SUM(SOL.Quantity) AS TotalQuanPerStockItem,YEAR(SO.OrderDate) 
AS OrderYear FROM Sales.Orders SO 
JOIN Sales.OrderLines SOL ON SO.OrderID=SOL.OrderID WHERE YEAR(SO.OrderDate) BETWEEN '2013' AND '2017'
GROUP BY StockItemID,YEAR(SO.OrderDate)),
temp2 AS(SELECT SISG.StockGroupID, temp.OrderYear, SUM(temp.TotalQuanPerStockItem) AS TotalQuanPerGroupYear 
FROM Warehouse.StockItemStockGroups SISG JOIN temp ON SISG.StockItemID = temp.StockItemID 
GROUP BY SISG.StockGroupID, temp.OrderYear)
SELECT OrderYear, [1] AS Group1, [2] AS Group2, [3] AS Group3, [4] AS Group4,
[5] AS Group5, [6] AS Group6, [7] AS Group7, [8] AS Group8, [9] AS Group9, [10] AS Group10 FROM
(SELECT * FROM temp2) AS SourceTable 
PIVOT(
MIN(TotalQuanPerGroupYear) FOR StockGroupID IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10])
) AS PivotTable;
SELECT * FROM TotalQuantities2 ORDER BY OrderYear;

--20.Create a function, input: order id; return: total of that order. 
-- List invoices and use that function to attach the order total to the other fields of invoices. 
-- 

-- join Invoices with SCT to get, for each OrderID in Invoices, what is the amount for this order (in SCT).
CREATE OR ALTER FUNCTION dbo.udf20(
	@OrderId INT
) RETURNS DEC(18,2) AS
BEGIN
DECLARE @OrderTotal DEC(18,2);
/*SET @TotalAmount = (SELECT SCT.TransactionAmount FROM Sales.Invoices SI JOIN Sales.CustomerTransactions SCT ON
SI.InvoiceID = SCT.InvoiceID WHERE SI.OrderID = @OrderId);*/ -- Two ways to write the syntax for passing the value for TotalAmount
SELECT @OrderTotal = SUM((Quantity*UnitPrice)) FROM Sales.OrderLines SOL 
WHERE SOL.OrderID = @OrderId;
RETURN @OrderTotal;
END;

--Extended Price
SELECT * FROM Sales.Invoices SI CROSS APPLY (SELECT dbo.udf20(SI.OrderID)) AS TAB(OrderTotal);


/*	21. Create a new table called ods.Orders. Create a stored procedure, 
with proper error handling and transactions, that input is a date; when executed, 
it would find orders of that day, calculate order total, 
and save the information (order id, order date, order total, customer id) into the new table. 
If a given date is already existing in the new table, throw an error and roll back. 
Execute the stored procedure 5 times using different dates. */
--SELECT * FROM Sales.Invoices;
CREATE SCHEMA ods;
DROP TABLE ods.Orders;
CREATE TABLE ods.Orders (
OrderId INT NOT NULL PRIMARY KEY,
OrderDate datetime,
OrderTotal DEC(10,2),
CustomerId INT
)
CREATE TABLE #temp2 (
 OrderId INT,
 OrderTotal DEC(10,2)
 )
 INSERT INTO #temp2 SELECT SO.OrderID, SUM(SOL.Quantity*SOL.UnitPrice) AS OrderTotal FROM Sales.OrderLines SOL 
JOIN Sales.Orders SO ON SOL.OrderID = SO.OrderID GROUP BY SO.OrderID;
SELECT * FROM #temp2;

CREATE PROC ErrorHandling AS
BEGIN
SELECT ERROR_LINE() AS ErrorLine,
ERROR_NUMBER() AS ErrorNumber,
ERROR_PROCEDURE() AS ErrorProcedure,
ERROR_STATE() AS ErrorState,
ERROR_SEVERITY() AS ErrorSeverity,
ERROR_MESSAGE() AS ErrorMessage;
END;

CREATE OR ALTER PROC Details(
	@DateInput datetime
) AS 
BEGIN
	BEGIN TRY
	BEGIN TRANSACTION;
	INSERT INTO ods.Orders SELECT #temp2.OrderID, SO.OrderDate, #temp2.OrderTotal, SO.CustomerID FROM #temp2 JOIN Sales.Orders SO ON
	#temp2.OrderID = SO.OrderID WHERE SO.OrderDate = @DateInput;
	COMMIT;
	END TRY

	BEGIN CATCH
	EXEC ErrorHandling;

	IF XACT_STATE() = -1
	BEGIN
		PRINT 'The transaction is in an uncommittable state. Rollback
		the transaction.';
		ROLLBACK;
	END;

	IF (XACT_STATE()) = 1
	BEGIN 
		PRINT 'The transaction is committable. Commit the transaction';
		COMMIT;
	END;
	END CATCH;	
END;
EXEC Details @DateInput = '2013-01-01';
EXEC Details @DateInput = '2013-01-02';
EXEC Details @DateInput = '2013-01-03';
EXEC Details @DateInput = '2013-01-04';
EXEC Details @DateInput = '2013-01-05';
SELECT * FROM ods.Orders;


--22
DROP TABLE IF EXISTS ods.StockItem;
CREATE TABLE ods.StockItem (
StockItem INT,
StockItemName nvarchar(100),
SupplierID INT,
ColorID INT,
UnitPackageID INT,
OuterPackageID INT,
Brand nvarchar(50),
Size nvarchar(20),
LeadTimeDays INT,
QuantityPerOuter INT,
IsChillerStock BIT,
Barcode nvarchar(50),
TaxRate DEC(18,2),
UnitPrice DEC(18,2),
RecommendedRetailPrice DEC(18,2),
TypicalWeightPerUnit DEC(18,3),
MarketingComments nvarchar(MAX),
InternalComments nvarchar(MAX),
CountryOfManufacture nvarchar(MAX),
Range nvarchar(MAX),
Shelflife nvarchar(MAX)
);

INSERT INTO ods.StockItem
SELECT StockItemID, StockItemName , SupplierID, ColorID, UnitPackageID,OuterPackageID,Brand, Size, LeadTimeDays,
QuantityPerOuter,IsChillerStock,Barcode,TaxRate, UnitPrice, RecommendedRetailPrice,TypicalWeightPerUnit,MarketingComments,
InternalComments,JSON_VALUE(WSI.CustomFields,'$.CountryOfManufacture') AS CountryOfManufacture,
JSON_VALUE(WSI.CustomFields, '$.Range') AS Range, JSON_VALUE(WSI.CustomFields,'$.ShelfLife')
AS ShelfLife FROM Warehouse.StockItems WSI;

SELECT * FROM ods.StockItem;

--23
DROP TABLE IF EXISTS ods.Orders2;
CREATE TABLE ods.Orders2 (
OrderId INT NOT NULL PRIMARY KEY,
OrderDate datetime,
OrderTotal DEC(10,2),
CustomerId INT
)
CREATE TABLE #temp3 (
 OrderId INT,
 OrderTotal DEC(10,2)
 )
 INSERT INTO #temp3 SELECT SO.OrderID, SUM(SOL.Quantity*SOL.UnitPrice) AS OrderTotal FROM Sales.OrderLines SOL 
JOIN Sales.Orders SO ON SOL.OrderID = SO.OrderID GROUP BY SO.OrderID;
SELECT * FROM #temp3;

CREATE OR ALTER PROC ErrorHandling AS
BEGIN
SELECT ERROR_LINE() AS ErrorLine,
ERROR_NUMBER() AS ErrorNumber,
ERROR_PROCEDURE() AS ErrorProcedure,
ERROR_STATE() AS ErrorState,
ERROR_SEVERITY() AS ErrorSeverity,
ERROR_MESSAGE() AS ErrorMessage;
END;

CREATE OR ALTER PROC Details2(
	@DateInput datetime
) AS 
BEGIN
	BEGIN TRY
	BEGIN TRANSACTION;
	INSERT INTO ods.Orders2 SELECT DISTINCT #temp3.OrderId, SO.OrderDate, #temp3.OrderTotal, SO.CustomerID FROM #temp3 JOIN Sales.Orders SO ON
	#temp3.OrderId = SO.OrderID WHERE SO.OrderDate = @DateInput;
	DELETE FROM ods.Orders2 WHERE OrderDate < @DateInput;
	INSERT INTO ods.Orders2 SELECT DISTINCT	#temp3.OrderId, SO.OrderDate, #temp3.OrderTotal, SO.CustomerID FROM #temp3 JOIN Sales.Orders SO ON
	#temp3.OrderId = SO.OrderID WHERE SO.OrderDate BETWEEN DATEADD(dd,1, @DateInput) AND DATEADD(dd,7, @DateInput);
	COMMIT;
	END TRY

	BEGIN CATCH
	EXEC ErrorHandling;

	IF XACT_STATE() = -1
	BEGIN
		PRINT 'The transaction is in an uncommittable state. Rollback
		the transaction.';
		ROLLBACK;
	END;

	IF (XACT_STATE()) = 1
	BEGIN 
		PRINT 'The transaction is committable. Commit the transaction';
		COMMIT;
	END;
	END CATCH;	
END;
EXEC Details2 @DateInput = '2013-01-01';
EXEC Details2 @DateInput = '2013-01-02';
EXEC Details2 @DateInput = '2013-01-03';
EXEC Details2 @DateInput = '2013-01-04';
EXEC Details2 @DateInput = '2013-01-10';
SELECT * FROM ods.Orders2;
DROP TABLE ods.Orders2; 

--24
DECLARE @json nvarchar(4000) = N'
{
   "PurchaseOrders":[
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"7",
         "UnitPackageId":"1",
         "OuterPackageId":[
            6,
            7
         ],
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-01",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"WWI2308"
      },
      {
         "StockItemName":"Panzer Video Game",
         "Supplier":"5",
         "UnitPackageId":"1",
         "OuterPackageId":"7",
         "Brand":"EA Sports",
         "LeadTimeDays":"5",
         "QuantityPerOuter":"1",
         "TaxRate":"6",
         "UnitPrice":"59.99",
         "RecommendedRetailPrice":"69.99",
         "TypicalWeightPerUnit":"0.5",
         "CountryOfManufacture":"Canada",
         "Range":"Adult",
         "OrderDate":"2018-01-025",
         "DeliveryMethod":"Post",
         "ExpectedDeliveryDate":"2018-02-02",
         "SupplierReference":"269622390"
      }
   ]
}';

(SELECT * FROM OPENJSON(@json, '$')
WITH  (
        [StockItemName]    nvarchar(50) '$.PurchaseOrders[0].StockItemName',  
        [Supplier]  int     '$.PurchaseOrders[0].Supplier', 
        [UnitPackageId]       int      '$.PurchaseOrders[0].UnitPackageId', 
        [OuterPackageId]      int  '$.PurchaseOrders[0].OuterPackageId[0]',
		[Brand]      nvarchar(50)  '$.PurchaseOrders[0].Brand',
		[LeadTimeDays]      int  '$.PurchaseOrders[0].LeadTimeDays',
		[QuantityPerOuter]      int  '$.PurchaseOrders[0].QuantityPerOuter',
		[TaxRate]      int  '$.PurchaseOrders[0].TaxRate',
		[UnitPrice]      DEC(10,2)  '$.PurchaseOrders[0].UnitPrice',
		[RecommendedRetailPrice]      DEC(10,2)  '$.PurchaseOrders[0].RecommendedRetailPrice',
		[TypicalWeightPerUnit]      DEC(10,2)  '$.PurchaseOrders[0].TypicalWeightPerUnit',
		[CountryOfManufacture]      nvarchar(50)  '$.PurchaseOrders[0].CountryOfManufacture',
		[Range]      nvarchar(50)  '$.PurchaseOrders[0].Range',
		[OrderDate]      datetime '$.PurchaseOrders[0].OrderDate',
		[DeliveryMethod]      nvarchar(10)  '$.PurchaseOrders[0].DeliveryMethod',
		[ExpectedDeliveryDate]      datetime '$.PurchaseOrders[0].ExpectedDeliveryDate',
		[SupplierReference]      nvarchar(MAX)  '$.PurchaseOrders[0].SupplierReference'
    )
) UNION 
(
SELECT * FROM OPENJSON(@json, '$')
WITH  (
        [StockItemName]    nvarchar(50) '$.PurchaseOrders[0].StockItemName',  
        [Supplier]  int     '$.PurchaseOrders[0].Supplier', 
        [UnitPackageId]       int      '$.PurchaseOrders[0].UnitPackageId', 
        [OuterPackageId]      int  '$.PurchaseOrders[0].OuterPackageId[1]',
		[Brand]      nvarchar(50)  '$.PurchaseOrders[0].Brand',
		[LeadTimeDays]      int  '$.PurchaseOrders[0].LeadTimeDays',
		[QuantityPerOuter]      int  '$.PurchaseOrders[0].QuantityPerOuter',
		[TaxRate]      int  '$.PurchaseOrders[0].TaxRate',
		[UnitPrice]      DEC(10,2)  '$.PurchaseOrders[0].UnitPrice',
		[RecommendedRetailPrice]      DEC(10,2)  '$.PurchaseOrders[0].RecommendedRetailPrice',
		[TypicalWeightPerUnit]      DEC(10,2)  '$.PurchaseOrders[0].TypicalWeightPerUnit',
		[CountryOfManufacture]      nvarchar(50)  '$.PurchaseOrders[0].CountryOfManufacture',
		[Range]      nvarchar(50)  '$.PurchaseOrders[0].Range',
		[OrderDate]      datetime '$.PurchaseOrders[0].OrderDate',
		[DeliveryMethod]      nvarchar(10)  '$.PurchaseOrders[0].DeliveryMethod',
		[ExpectedDeliveryDate]      datetime '$.PurchaseOrders[0].ExpectedDeliveryDate',
		[SupplierReference]      nvarchar(MAX)  '$.PurchaseOrders[0].SupplierReference'
    )
) UNION

(
SELECT * FROM OPENJSON(@json, '$')
WITH  (
        [StockItemName]    nvarchar(50) '$.PurchaseOrders[1].StockItemName',  
        [Supplier]  int     '$.PurchaseOrders[1].Supplier', 
        [UnitPackageId]       int      '$.PurchaseOrders[1].UnitPackageId', 
        [OuterPackageId]      int  '$.PurchaseOrders[1].OuterPackageId',
		[Brand]      nvarchar(50)  '$.PurchaseOrders[1].Brand',
		[LeadTimeDays]      int  '$.PurchaseOrders[1].LeadTimeDays',
		[QuantityPerOuter]      int  '$.PurchaseOrders[1].QuantityPerOuter',
		[TaxRate]      int  '$.PurchaseOrders[1].TaxRate',
		[UnitPrice]      DEC(10,2)  '$.PurchaseOrders[1].UnitPrice',
		[RecommendedRetailPrice]      DEC(10,2)  '$.PurchaseOrders[1].RecommendedRetailPrice',
		[TypicalWeightPerUnit]      DEC(10,2)  '$.PurchaseOrders[1].TypicalWeightPerUnit',
		[CountryOfManufacture]      nvarchar(50)  '$.PurchaseOrders[1].CountryOfManufacture',
		[Range]      nvarchar(50)  '$.PurchaseOrders[1].Range',
		[OrderDate]      datetime '$.PurchaseOrders[1].OrderDate',
		[DeliveryMethod]      nvarchar(10)  '$.PurchaseOrders[1].DeliveryMethod',
		[ExpectedDeliveryDate]      datetime '$.PurchaseOrders[1].ExpectedDeliveryDate',
		[SupplierReference]      nvarchar(MAX)  '$.PurchaseOrders[1].SupplierReference'
    )
)







--25
BEGIN
DECLARE @json nvarchar(MAX);
SET @json = (SELECT OrderYear,
(SELECT Group1,Group2,Group3,Group4,ISNULL(Group5,0) AS Group5,Group6,Group7,Group8,Group9,Group10 FROM TotalQuantities2 TQIn
WHERE TQIn.OrderYear = TQOut.OrderYear FOR JSON PATH) 
AS [QuantitiesSold.Groups]
FROM TotalQuantities2 TQOut FOR JSON PATH,INCLUDE_NULL_VALUES);
DROP TABLE if EXISTS dbo.jsonInfo;
CREATE TABLE dbo.jsonInfo(
		id INT,
		logs nvarchar(MAX)

);

INSERT INTO dbo.jsonInfo(id,logs) VALUES (1,@json);
SELECT * FROM dbo.jsonInfo;
END;
ALTER TABLE dbo.jsonInfo
ADD CONSTRAINT [logs record should be formatted as JSON]
				CHECK (ISJSON(logs) = 1)




--26
BEGIN
DROP TABLE IF EXISTS dbo.XMLInfo;
CREATE TABLE dbo.XMLInfo(
	id INT,
	Content XML
);
DECLARE @XMLContent XML;
SET @XMLContent = (SELECT OrderYear AS '@OrderYear',Group1,Group2,Group3,Group4,Group5,Group6,Group7,Group8,Group9,Group10 
FROM TotalQuantities2 ORDER BY OrderYear FOR XML PATH, ROOT('QuantitiesSold'),ELEMENTS XSINIL);
INSERT INTO dbo.XMLInfo(id,Content) VALUES(1,@XMLContent);
SELECT * FROM dbo.XMLInfo;
END;






--27.	
/*Create a new table called ods.ConfirmedDeviveryJson with 3 columns (id, date, value) . 
Create a stored procedure, input is a date. The logic would load invoice information (all columns) 
as well as invoice line information (all columns) and forge them into a JSON string and then insert into
the new table just created. Then write a query to run the stored procedure for each DATE that 
customer id 1 got something delivered to him.*/
DROP TABLE IF EXISTS NewTable;
--Create a table to stored the values.
CREATE TABLE NewTable (
id INT,
date datetime,
value nvarchar(MAX)
);

--Create a stored procedure to generate json string given a date with customer id being 1 by default.
-- Json string is the output parameter.
CREATE OR ALTER PROC GenJSON(
	@InputDate datetime,
	@CustomerId INT = 1,
	@json nvarchar(MAX) OUTPUT
)AS
BEGIN
SET @json = (
SELECT DISTINCT SI.CustomerID as [customer.id],(SELECT SI.BillToCustomerID,
SI.DeliveryMethodID,
SIL.InvoiceLineID, SIL.Description  FROM  Sales.Invoices SI JOIN Sales.InvoiceLines SIL ON 
SI.InvoiceID = SIL.InvoiceID WHERE SI.CustomerID = 1 AND 
CONVERT(date,SI.ConfirmedDeliveryTime) = @InputDate FOR JSON PATH) as [customer.deliveries]
FROM Sales.Invoices SI WHERE SI.CustomerID=1 FOR JSON PATH);
END;
/*From above, the reason why I want to use nested "FOR JSON PATH" method is because
-- for customer id = 1, in a given date, this customer may have multiple deliveries 
--(i.e., multiple invoiceLineID). Therefore, I want to set 'customer' as the root element
-- the 'customer' root element has two attributes: id and deliveries. 
-- Inside 'deliveries', there are multiple deliveries(i.e., InvoiceLineID).
-- These multiple deliveries are stored in a list*/



-- Create a stored procedure to load all invoice information and invoice line information and insert 
-- them into the new table created above. 
-- We use while loop and @@ROWCOUNT to make sure that each distinct date is traversed through
-- on which the customer 1 got something delivered.
-- And we call the above stored procedure at each date in order to form the JSON string for each date
-- and pass the information into the NewTable created above.
CREATE OR ALTER PROC GenerateAnswer AS
BEGIN 
DECLARE @dTime TABLE(
	deliveredDates datetime,
	numbers INT);
DECLARE @json nvarchar(MAX);
DECLARE @totalRow INT = 0;
DECLARE @rowCounter INT = 0;
DECLARE @curTime datetime;
INSERT INTO @dTime SELECT tt.deliveredDates,tt.numbers FROM (SELECT DISTINCT CONVERT(date, SI.ConfirmedDeliveryTime) 
as deliveredDates,
row_number() over(ORDER BY CONVERT(date, SI.ConfirmedDeliveryTime)) AS numbers FROM Sales.Invoices SI 
WHERE SI.CustomerID=1) tt
SET @totalRow =  @@ROWCOUNT;

WHILE @rowCounter < @totalRow
	BEGIN
	SET @curTime = (SELECT CONVERT(date,deliveredDates) FROM @dTime
	WHERE numbers = @rowCounter+1);
	EXEC GenJSON @InputDate = @curTime,@json=@json OUTPUT;
	INSERT INTO NewTable (id, date, value) VALUES(@rowCounter+1, @curTime, @json);
	SET @rowCounter = @rowCounter + 1;
	END;
END;
EXEC GenerateAnswer;
SELECT * FROM NewTable;





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

