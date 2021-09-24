
-- 1. List of Persons’ full name, all their fax and phone numbers, 
-- as well as the phone number and fax of the company they are working for (if any). 

/* reference
SELECT * FROM Application.People; -- PersonID, FullName, PhoneNumber, FaxNumber

SELECT * FROM Sales.Customers;
*/

/* Answer

CREATE NONCLUSTERED INDEX [_dta_index_StateProvinces_6_290100074__K1_3_4] ON [Application].[StateProvinces]
(
	[StateProvinceID] ASC
)
INCLUDE([StateProvinceName],[CountryID]) WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [USERDATA]

-- I assume, that the PrimaryContactPersonID and AlternateContactPersonID are the person who working for the customer (company)
WITH
q1t1 AS
(
SELECT AP.PersonID, AP.FullName, AP.PhoneNumber AS PersonTel, AP.FaxNumber AS PersonFax, SC.PhoneNumber AS Company1Tel, SC.FaxNumber AS Company1Fax
FROM Application.People AS AP
LEFT JOIN Sales.Customers AS SC
ON SC.PrimaryContactPersonID = AP.PersonID
)
SELECT q1t1.FullName, q1t1.PersonTel, q1t1.PersonFax, q1t1.Company1Tel, q1t1.Company1Fax, SC.PhoneNumber AS Company2Tel, SC.FaxNumber AS Company2Tel
FROM q1t1 
LEFT JOIN Sales.Customers AS SC
ON q1t1.PersonID = SC.AlternateContactPersonID
*/

-- 2. If the customer's primary contact person has the same phone number as the customer’s phone number, list the customer companies. 

/* reference
SELECT * FROM Sales.Customers; -- CustomerID, PrimaryContactPersonID, PhoneNumber

SELECT * FROM Application.People; -- PersonID, PhoneNumber   
*/

/* Answer
SELECT SC.CustomerName
FROM Sales.Customers AS SC
LEFT JOIN Application.People AS AP
ON SC.PrimaryContactPersonID = AP.PersonID
WHERE SC.PhoneNumber = AP.PhoneNumber;
*/

-- 3. List of customers to whom we made a sale prior to 2016 but no sale since 2016-01-01.

/*Answer
-- SELECT DISTINCT CustomerID FROM Sales.Customers ORDER BY CustomerID DESC;
-- We have 663 rows in total means we have 663 customers in the system.

-- SELECT DISTINCT CustomerID FROM Sales.Orders ORDER BY CustomerID DESC;
-- We have record shows that there's 663 people in total who have ever purchased an order
-- Turns out, every customers in the Sales.Customers table has purchased at least once from WideWorldImporters.

WITH 
t1 AS
(
SELECT CustomerID, YEAR(OrderDate) AS OrderYear,
	   ROW_NUMBER() OVER( PARTITION BY CustomerID
					ORDER BY OrderDate DESC) AS ranking
FROM Sales.Orders
-- By partition by CustomerID, we are ranking each customer's orders from latest order date to earliest order date.
)
-- Basiclly we are looking for customers who have purchased at leat one order and the lastest order date is before 2016-01-01
SELECT t1.CustomerID, t1.OrderYear
FROM t1
WHERE t1.ranking = 1 AND OrderYear < '2016'
ORDER BY t1.CustomerID
-- There's nothing in the query result set which means every customer have purchased order at least once since 2016-01-01
*/

-- 4. List of Stock Items and total quantity for each stock item in Purchase Orders in Year 2013.

/*Answer
WITH 
t1 AS
( 
SELECT PPOL.StockItemID, PPOL.OrderedOuters, YEAR(PPO.OrderDate) AS OrderYear
FROM Purchasing.PurchaseOrders AS PPO
INNER JOIN Purchasing.PurchaseOrderLines AS PPOL
ON PPO.PurchaseOrderID = PPOL.PurchaseOrderID AND YEAR(PPO.OrderDate) = '2013'
-- List of Stock Items in the purchase orders in Year 2013
),
t2 AS
(
SELECT t1.StockItemID, SUM(t1.OrderedOuters) AS TotalOuters
FROM t1
GROUP BY t1.StockItemID
)
-- Joining StockItems to get the QuantityPerOuter
SELECT t2.StockItemID, (t2.TotalOuters * WSI.QuantityPerOuter) AS TotalStockItemQuantity
-- Since we already have the list of stock items in the purchase orders in year 2013, number of orderedouters, quantity per outer, we can 
-- multiple OrderedOuters by QuantityPerOuter to get the total quantity of each stock item.
FROM t2
INNER JOIN Warehouse.StockItems AS WSI
ON t2.StockItemID = WSI.StockItemID
ORDER BY StockItemID
*/

-- 5. List of stock items that have at least 10 characters in description.
/* reference
SELECT * FROM Purchasing.PurchaseOrderLines ORDER BY StockItemID;

SELECT * FROM Warehouse.StockItems;
-- The description in Purchasing.PurchaseOrderLineID is same as the StockItemName in Warehouse.StockItems
*/ 

/* Answer
SELECT DISTINCT StockItemID, LEN(Description) AS DescLen 
FROM Purchasing.PurchaseOrderLines 
WHERE LEN(Description) >= 10
ORDER BY DescLen, StockItemID;
*/


-- 6. List of stock items that are not sold to the state of Alabama and Georgia in 2014.

/*Answer
WITH 
t1 AS
(
SELECT DISTINCT ASP.StateProvinceName, AC.CityID
FROM Application.StateProvinces AS ASP
INNER JOIN Application.Cities AS AC
ON AC.StateProvinceID = ASP.StateProvinceID
-- Get all the CityID alongwith the matchi State Name
),
t2 AS
(
SELECT SC.CustomerID, t1.CityID, t1.StateProvinceName
FROM t1
INNER JOIN Sales.Customers AS SC
ON SC.DeliveryCityID = t1.CityID
-- Get the list of all customers' deliveryCityID alongwith the State Name
),
t3 AS
(
SELECT SO.OrderID, t2.CustomerID, t2.StateProvinceName, YEAR(SO.OrderDate) AS OrderYear
FROM t2
INNER JOIN Sales.Orders AS SO
ON SO.CustomerID = t2.CustomerID AND YEAR(SO.OrderDate) = '2014'
-- Get the list of orders made in 2014
),
t4 AS
(
SELECT DISTINCT SOL.StockItemID, t3.OrderYear
FROM t3
INNER JOIN Sales.OrderLines AS SOL
ON SOL.OrderID = t3.OrderID 
WHERE StateProvinceName = 'Alabama' OR StateProvinceName = 'Georgia'
-- List of all the stockitems that have ever been delivered to Alabma or Georgia in Yeaer 2014
)
SELECT WSI.StockItemID
FROM Warehouse.StockItems AS WSI
WHERE WSI.StockItemID NOT IN 
(
SELECT t4.StockItemID 
FROM t4
)
;
*/

-- 7. List of States and Avg dates for processing (confirmed delivery date – order date).

/* reference
SELECT * FROM Sales.Orders; -- OrderID, CustomerID, OrderDate

SELECT * FROM Sales.Invoices; -- OrderID, ComfirmedDeliveryTime

SELECT * FROM Application.StateProvinces; -- StateProvinceID, StateProvinceName

SELECT * FROM Application.Cities; -- CityID, StateProvinceID

SELECT * FROM Sales.Customers; -- CustomerID, DeliveryCityID
*/

/*Answer
WITH
t1 AS
(
SELECT AC.CityID, ASP.StateProvinceName
FROM Application.Cities AS AC
INNER JOIN Application.StateProvinces AS ASP
ON AC.StateProvinceID = ASP.StateProvinceID 
-- Get the State Name for each CityID
),
t2 AS
(
SELECT SC.CustomerID, t1.StateProvinceName
FROM t1
INNER JOIN Sales.Customers AS SC
ON SC.DeliveryCityID = t1.CityID
-- Get the list of customer and their delivery state name
),
t3 AS
(
SELECT SO.OrderID, SO.OrderDate, t2.StateProvinceName AS StateName
FROM Sales.Orders  AS SO
INNER JOIN t2
ON t2.CustomerID = SO.CustomerID
-- get the each order's order date and where are they delivering to
)
SELECT t3.StateName, AVG(DATEDIFF(day, t3.OrderDate, SI. ConfirmedDeliveryTime)) AS AvgProcessingDAY
FROM Sales.Invoices AS SI
INNER JOIN t3	
ON t3.OrderID = SI.OrderID
GROUP BY StateName
ORDER BY t3.StateName;
-- Joining the Sales.Invoices table to get the comfirmed Delivery time 
-- then use datediff to get the number of day of processing
-- group by state name to use the aggregation on ProcessingDay (Average) to get the average processing day for each state.
*/

-- 8. List of States and Avg dates for processing (confirmed delivery date – order date) by month.

/* reference
SELECT * FROM Sales.Orders; -- OrderID, CustomerID, OrderDate

SELECT * FROM Sales.Invoices; -- OrderID, ComfirmedDeliveryTime

SELECT * FROM Application.StateProvinces; -- StateProvinceID, StateProvinceName

SELECT * FROM Application.Cities; -- CityID, StateProvinceID

SELECT * FROM Sales.Customers; -- CustomerID, DeliveryCityID
*/

/*Answer 
WITH
t1 AS
(
SELECT AC.CityID, ASP.StateProvinceName			
FROM Application.Cities AS AC
INNER JOIN Application.StateProvinces AS ASP
ON AC.StateProvinceID = ASP.StateProvinceID
-- Get CityID with their State Name
),
t2 AS
(
SELECT SC.CustomerID, t1.StateProvinceName 
FROM Sales.Customers AS SC
INNER JOIN t1
ON t1.CityID = SC.DeliveryCityID
-- Inner join using cityID to get the list of customers with the state they lived in
),
t3 AS
(
SELECT SO.OrderID, SO.OrderDate, t2.StateProvinceName AS StateName
FROM Sales.Orders AS SO
INNER JOIN t2
ON t2.CustomerID = SO.CustomerID
-- inner join using Sales.Orders.CustomerID to get get the list of order, the order date and the delivery destination of each order.
)
SELECT t3.StateName, 
	   AVG(DATEDIFF(day, t3.OrderDate, SI. ConfirmedDeliveryTime)) AS ProcessingDay, 
	   MONTH(t3.OrderDate) AS OrderMonth
FROM Sales.Invoices AS SI
INNER JOIN t3
ON t3.OrderID = SI.OrderID
-- Inner join Sales.Invoice to get the Confirmed Delivery Time then use DATEDIFF on OrderDate and DeliveryDate to get the 
-- actural number of processing days
GROUP BY t3.StateName, MONTH(t3.OrderDate)
-- Group BY state name, then year, then month and use average as aggregation on DATEDIFF
-- We can get the average order processing day by month if the order was made in that month (I hope what im saying make sense to you)
ORDER BY t3.StateName,  OrderMonth
*/

-- 9. List of StockItems that the company purchased more than sold in the year of 2015.

/*reference
SELECT * FROM Warehouse.StockItems; -- StockItemID, QuantityPerOuter

SELECT * FROM Sales.Orders; -- OrderID, OrderDate(sale)

SELECT * FROM Sales.OrderLines ORDER BY StockItemID; -- OrderID, StockItemID, Quantity

SELECT * FROM Purchasing.PurchaseOrders; -- PurchaseOrderID, OrderDate(purchase)

SELECT * FROM Purchasing.PurchaseOrderLines ORDER BY StockItemID; -- StockItemID, PurchaseOrderID, OrderedOuters
*/

-- In my understanding, 
-- when company purchases in from suppliers, the items come in a Outer,
-- the total quantity of items they received equals to Purchasing.PurchaseOrderLines.OrderedOuters * Warehouse.StockItems.QuantityPerOuter
-- when company sales to customers, the items are sold seperately,
-- the total quantity of items they sent out equals to Sales.OrderLines.Quantity

/*Answer 
DROP VIEW IF EXISTS NumOfStockItemSaleOut2015;
CREATE OR ALTER VIEW NumOfStockItemSaleOut2015 AS
	SELECT q1.StockItemID, SUM(q1.Quantity) AS NumOfStockItemSaleOut
	FROM 
		(
		SELECT SOL.StockItemID, SOL.Quantity, YEAR(SO.OrderDate) AS SaleYear 
		FROM Sales.Orders AS SO
		INNER JOIN Sales.OrderLines AS SOL
		ON SOL.OrderID = SO.OrderID AND YEAR(SO.OrderDate) = '2015'
		) AS q1
	INNER JOIN  Warehouse.StockItems AS WSI
	ON q1.StockItemID = WSI.StockItemID
	GROUP BY q1.StockItemID
;

DROP VIEW IF EXISTS NumOfStockItemPurchaseIn2015;
CREATE OR ALTER VIEW NumOfStockItemPurchaseIn2015 AS
	SELECT q2.StockItemID, SUM(WSI.QuantityPerOuter * q2.OrderedOuters) AS NumOfStockItemPurchaseIn
	FROM
		(
		SELECT PPOL.StockItemID, PPOL.OrderedOuters, PPO.OrderDate AS PurchaseYear
		FROM Purchasing.PurchaseOrderLines AS PPOL
		INNER JOIN Purchasing.PurchaseOrders AS PPO
		ON PPOL.PurchaseOrderID = PPO.PurchaseOrderID AND YEAR(PPO.OrderDate) = '2015'
		) AS q2
	INNER JOIN Warehouse.StockItems AS WSI
	ON WSI.StockItemID = q2.StockItemID
	GROUP BY q2.StockItemID
;

-- SELECT * FROM NumOfStockItemSaleOut2015;

-- SELECT * FROM NumOfStockItemPurchaseIn2015;

SELECT SaleOut.StockItemID, 
	   SaleOut.NumOfStockItemSaleOut AS NumOfStockItemSaleOut, 
	   PurchaseIn.NumOfStockItemPurchaseIn AS NumOfStockItemPurchaseIn
FROM NumOfStockItemSaleOut2015 AS SaleOut
INNER JOIN NumOfStockItemPurchaseIn2015 AS PurchaseIn
ON SaleOut.StockItemID = PurchaseIn.StockItemID
WHERE PurchaseIn.NumOfStockItemPurchaseIn > SaleOut.NumOfStockItemSaleOut
*/

-- 10. List of Customers and their phone number, together with the primary contact person’s name, 
--     to whom we did not sell more than 10  mugs (search by name) in the year 2016.

/* reference
SELECT * FROM Sales.Customers -- ORDER BY PrimaryContactPersonID;

SELECT * FROM Application.People -- WHERE PersonID = 1001;

SELECT * FROM Warehouse.StockItems WHERE StockItemName LIKE '%Mug%'; -- All the Mug StockItem we have

SELECT * FROM Sales.Orders;

SELECT * FROM Sales.OrderLines;
*/

/*Answer
-- Create a view for customers' Id, PhoneNum and their primary contact person name
DROP VIEW IF EXISTS CustomersInfo;
CREATE OR ALTER VIEW CustomersInfo AS
SELECT SC.CustomerID, SC. CustomerName, SC.PhoneNumber, AP.FullName AS PrimaryContactPersonName
FROM Sales.Customers AS SC
INNER JOIN Application.People AS AP
ON SC.PrimaryContactPersonID = AP.PersonID

-- Create a view for list of StockItems that is a mug
DROP VIEW IF EXISTS MugItems;
CREATE OR ALTER VIEW MugItems AS
SELECT StockItemID, StockItemName
FROM Warehouse.StockItems 
WHERE StockItemName LIKE '%Mug%';
SELECT * FROM MugItems;

-- Create a view for each item and purchased by which customer
DROP VIEW IF EXISTS CustomerStockItem;
CREATE OR ALTER VIEW CustomerStockItem AS
SELECT SO.CustomerID, SOL.StockItemID, SOL.Quantity, YEAR(SO.OrderDate) AS OrderYear
FROM Sales.Orders AS SO
INNER JOIN Sales.OrderLines AS SOL
ON SO.OrderID = SOL.OrderID

-- View MugItems: StockItems are mugs
-- VIew CustomersInfo: Customer ID, Tel, PrimaryContactPersonName
-- View CustomerStockItem: Customer ID and the StockItem they ever bought

SELECT CI.CustomerID, CI.PhoneNumber, CI.PrimaryContactPersonName, MugsBuyer.#MugsBought2016
FROM CustomersInfo AS CI
INNER JOIN (
			SELECT CSI.CustomerID, SUM(CSI.Quantity) AS #MugsBought2016
			FROM MugItems AS MI
			INNER JOIN CustomerStockItem AS CSI
			ON MI.StockItemID = CSI.StockItemID 
			'
			GROUP BY CSI.CustomerID
			-- Get list of Customers and the total number of mugs they purchased in 2016
			) AS MugsBuyer
ON CI.CustomerID = MugsBuyer.CustomerID
WHERE MugsBuyer.#MugsBought2016 <= 10
ORDER BY CI.CustomerID;
*/

-- 11. List all the cities that were updated after 2015-01-01

/*Answer
-- Since Application.Cities is a temporal table, which means post-update rows will goes into the Application.Cities, 
-- and all the rows that contain previous data will goes into the Application.Cities_Archive and in that history table it has a ValidTo row
-- so the time in row ValidTo is the actual time a record was being updated.

SELECT CityID, CityName, ValidTo AS UpdatedTime
FROM Application.Cities_Archive
WHERE ValidTo > '2015-01-01 00:00:00.0000000'
*/

-- 12. List all the Order Detail 
--     (Stock Item name, delivery address, delivery state, city, country, customer name, customer contact person name, customer phone, quantity) 
--     for the date of 2014-07-01. Info should be relevant to that date.

/* reference
SELECT * FROM Sales.OrderLines; -- OrderID, StockItemID, Quantity, PickedQuantity(?)

SELECT * FROM Sales.Orders; -- OrderID, CustomerID, OrderDate

SELECT * FROM Sales.CustomerTransactions

SELECT * FROM Sales.Customers; -- CustomerID, Name, Tel, PrimaryContact, AlternateContact, DeliveryAddressLine1, DeliveryAddressLine2

SELECT * FROM Application.Cities; -- CityID, CityName, StateProviceID

SELECT * FROM Application.StateProvinces; -- StateProvinceID, StateProvinceName, CountryID

SELECT * FROM Application.Countries; -- CountryID, CountryName
*/

/* Answer
-- Create a view for each city with its state and its country
DROP VIEW IF EXISTS GeoInfo;
CREATE OR ALTER VIEW GeoInfo AS
WITH
StateCity AS
(
SELECT AC.CityID, AC.CityName, ASP.StateProvinceID, ASP.StateProvinceCode, ASP.StateProvinceName, ASP.CountryID
FROM Application.Cities AS AC
INNER JOIN Application.StateProvinces AS ASP
ON AC.StateProvinceID = ASP.StateProvinceID
) 
SELECT SC.CityID, SC.CityName, SC.StateProvinceID, SC.StateProvinceCode, SC.StateProvinceName, SC.CountryID, Actr.CountryName
FROM Application.Countries AS ACtr
INNER JOIN StateCity AS SC
ON SC.CountryID = ACtr.CountryID
;

-- Create a view for customers' Id, PhoneNum and their primary contact person name
DROP VIEW IF EXISTS CustomerInfo;
CREATE OR ALTER VIEW CustomerInfo AS
WITH
q12t1 AS
(
SELECT SC.CustomerID, SC.CustomerName, SC.PhoneNumber, SC.PrimaryContactPersonID, AP.FullName AS PrimaryContactPersonName
FROM Sales.Customers AS SC
INNER JOIN Application.People AS AP
ON SC.PrimaryContactPersonID = AP.PersonID
),
q12t2 AS
(
SELECT q12t1.CustomerID, q12t1.CustomerName, q12t1.PhoneNumber, q12t1.PrimaryContactPersonID, q12t1.PrimaryContactPersonName, SC.AlternateContactPersonID
FROM q12t1
INNER JOIN Sales.Customers AS SC
ON SC.CustomerID = q12t1.CustomerID
),
q12t3 AS
(
SELECT q12t2.CustomerID, q12t2.CustomerName, q12t2.PhoneNumber, q12t2.PrimaryContactPersonID, q12t2.PrimaryContactPersonName, q12t2.AlternateContactPersonID, AP.FullName AS AlterNateContactPersonName
FROM q12t2
LEFT JOIN Application.People AS AP
-- Use LEFT JOIN here is because AlternateContactPersonID has NULL in the column 
-- so if we use INNER JOIN, the information of customers who don't have a valid AlternateContactPersonID will not be shown in the result.
ON AP.PersonID = q12t2.AlternateContactPersonID
) 
SELECT q12t3.CustomerID, q12t3.CustomerName, q12t3.PhoneNumber, q12t3.PrimaryContactPersonID, q12t3.PrimaryContactPersonName,
	   q12t3.AlternateContactPersonID, q12t3.AlterNateContactPersonName, 
	   CONCAT(SC.DeliveryAddressLine1, ', ', SC.DeliveryAddressLine2) AS DeliveryAddress,
	   DeliveryCityID
FROM q12t3
LEFT JOIN Sales.Customers AS SC
ON SC.CustomerID = q12t3.CustomerID

/* Question(?)
SELECT DISTINCT OrderID FROM Sales.Orders
-- 73595 rows indicate that there are 73595 orders in toal
SELECT DISTINCT OrderID FROM Sales.Invoices
-- 70510 rows indicate there are 3085 Orders don't have a invoice.
SELECT * 
FROM Sales.Orders AS SO
WHERE SO.OrderID NOT IN (SELECT DISTINCT OrderID FROM Sales.Invoices)
-- Orders that don't have a invoice 
-- what happened to these orders and which column indicates the reason why they don't have a invoice?
*/

DROP VIEW IF EXISTS OrderInfo;
CREATE OR ALTER VIEW OrderInfo AS
WITH 
q12t4 AS
(
SELECT DISTINCT SO.OrderID, SOL.StockItemID, SOL.Quantity, SO.OrderDate
FROM Sales.Orders AS SO
LEFT JOIN Sales.OrderLines AS SOL
ON SO.OrderID = SOL.OrderID
)
SELECT q12t4.OrderID, q12t4.StockItemID, WSI.StockItemName, q12t4.Quantity, q12t4.OrderDate
FROM q12t4
INNER JOIN Warehouse.StockItems AS WSI
ON q12t4.StockItemID = WSI.StockItemID
;

-- View GeoInfo: City, State, Country
-- View CustomerInfo: Customer Name, Tel., PrimaryContactPersonName, AlternateContactPersonName, DeliveryAddress
-- View OrderInfo: OrderID, StockItemID, StockItemName, Quantity, OrderDate

WITH
q12t5 AS
(
SELECT OrderInfo.OrderID, OrderInfo.StockItemID, OrderInfo.StockItemName, OrderInfo.Quantity, OrderInfo.OrderDate, SO.CustomerID
FROM Sales.Orders AS SO
INNER JOIN OrderInfo
ON SO.OrderID = OrderInfo.OrderID
),
q12t6 AS
(
SELECT q12t5.OrderID, q12t5.StockItemName, q12t5.Quantity, 
	   CustomerInfo.CustomerName, CustomerInfo.PhoneNumber, CustomerInfo.PrimaryContactPersonName, 
	   CustomerInfo.AlternateContactPersonName, CustomerInfo.DeliveryAddress, CustomerInfo.DeliveryCityID, 
	   q12t5.OrderDate
FROM q12t5
LEFT JOIN CustomerInfo
ON CustomerInfo.CustomerID = q12t5.CustomerID
)
SELECT q12t6.OrderID, q12t6.StockItemName, q12t6.Quantity, 
	   q12t6.CustomerName, q12t6.PhoneNumber, q12t6.PrimaryContactPersonName, 
	   q12t6.AlternateContactPersonName, q12t6.DeliveryAddress,  
	   GeoInfo.CityName, GeoInfo.StateProvinceName, GeoInfo.CountryName,
	   q12t6.OrderDate
FROM q12t6
INNER JOIN GeoInfo
ON GeoInfo.CityID = q12t6.DeliveryCityID AND q12t6.OrderDate = '2014-07-01'
ORDER BY q12t6.OrderID
;
*/

-- 13. List of stock item groups and total quantity purchased, total quantity sold, 
--     and the remaining stock quantity (quantity purchased – quantity sold) 

/* Answer
DROP VIEW IF EXISTS TotalStockItemPurchased;
CREATE OR ALTER VIEW TotalStockItemPurchased AS
WITH
q13t1 AS
(
SELECT WSI.StockItemID, SUM(WSI.QuantityPerOuter * PPOL.OrderedOuters) AS QuantityPurchasedByItem
FROM Warehouse.StockItems AS WSI
INNER JOIN Purchasing.PurchaseOrderLines AS PPOL
ON WSI.StockItemID = PPOL.StockItemID
GROUP BY WSI.StockItemID
)
SELECT WSISG.StockGroupID, SUM(q13t1.QuantityPurchasedByItem) AS QuantityPurchasedByGroup
FROM q13t1
INNER JOIN Warehouse.StockItemStockGroups AS WSISG
ON q13t1.StockItemID = WSISG.StockItemID
GROUP BY WSISG.StockGroupID

CREATE OR ALTER VIEW TotalStockItemSold AS
SELECT WSISG.StockGroupID, SUM(Quantity) AS QuantitySoldByGroup
FROM Sales.OrderLines AS SO
INNER JOIN Warehouse.StockItemStockGroups AS WSISG
ON SO.StockItemID = WSISG.StockItemID
GROUP BY WSISG.StockGroupID

SELECT TSIP.StockGroupID, TSIP.QuantityPurchasedByGroup, TSIS.QuantitySoldByGroup, 
	   (TSIP.QuantityPurchasedByGroup - TSIS.QuantitySoldByGroup) AS QuantityRemainByGroup
FROM TotalStockItemPurchased AS TSIP
INNER JOIN TotalStockItemSold AS TSIS
ON TSIP.StockGroupID = TSIS.StockGroupID
ORDER BY StockGroupID;
-- How come we sold more than we purchaed?
*/

-- 14. List of Cities in the US and the stock item that the city got the most deliveries in 2016. 
--     If the city did not purchase any stock items in 2016, print “No Sales”.

/* Answer
-- Use View GeoInfo for City-State-Country info
DROP VIEW IF EXISTS CityStockItemDelivery;
CREATE OR ALTER VIEW CityStockItemDelivery AS
WITH
q14t1 AS
(
SELECT SO.OrderID, SC.DeliveryCityID, YEAR(SO.OrderDate) AS OrderYear
FROM Sales.Orders AS SO
INNER JOIN Sales.Customers AS SC
ON SO.CustomerID = SC.CustomerID AND YEAR(SO.OrderDate) = '2016'
-- get all the order from 2016 with their DeliveryCityID
),
q14t2 AS
(
SELECT q14t1.DeliveryCityID, SOL.StockItemID, COUNT(SOL.StockItemID) AS NumOfDelivery
FROM q14t1 
INNER JOIN Sales.OrderLines AS SOL
ON q14t1.OrderID = SOL.OrderID
GROUP BY q14t1.DeliveryCityID, SOL.StockItemID
-- count how many times a stockitem was delivered to this city
),
q14t3 AS
(
SELECT *,
	   RANK() OVER(PARTITION BY DeliveryCityID
				   ORDER BY NumOfDelivery DESC) AS ranking
FROM q14t2
-- rank delivery times of each stockitem based on CityID
)
SELECT GeoInfo.CityID, GeoInfo.CityName, 
	   CAST(ISNULL(q14t3.StockItemID, 0) AS nvarchar(50)) AS StockItemID, 
	   CAST(ISNULL(q14t3.NumOfDelivery, 0) AS nvarchar(50)) AS NumOfDelivery,
	   CAST(ISNULL(q14t3.ranking, 0) AS nvarchar(50)) AS ranking
FROM GeoInfo
LEFT JOIN q14t3
ON GeoInfo.CityID = q14t3.DeliveryCityID
-- Since we are looking for the list of Cities, 
-- LEFT JOIN should be the one we use in order to keep all the city info,no matter whether there's a delivery or not.
-- Then use ISNULL() to replace all the null with 0
-- Then CAST() will change those columns from int type to nvarchar type for further inserting

DROP TABLE IF EXISTS t14;
CREATE TABLE t14
(
CityID int,
CityName nvarchar(50),
StockItemID nvarchar(10),
NumOfDelivery nvarchar(10),
ranking nvarchar(10)
);
-- Create a table to hold the view CityStockItemDelivery

INSERT INTO t14
SELECT * FROM CityStockItemDelivery

UPDATE t14
SET
	StockItemID = 'No Sale',
	NumOfDelivery = 'No Sale',
	ranking = 'No Sale'
WHERE 
	StockItemID = '0' AND
	NumOfDelivery = '0' AND
	ranking = '0'
-- In order to print 'No Sale', we need to use UPDATE table to change all the '0' string to 'No Sale' string.

SELECT CityID, CityName, StockItemID, NumOfDelivery
FROM t14
WHERE ranking = '1' OR ranking = 'No Sale'
ORDER BY CityID;
-- get the rank 1 cities and 'no sale' cities
*/

-- 15. List any orders that had more than one delivery attempt (located in invoice table).

/* Answer
SELECT OrderID, 
	   JSON_VALUE(ReturnedDeliveryData, '$.Events[2]')  AS FirstAttemptFailed
FROM Sales.Invoices
WHERE JSON_VALUE(ReturnedDeliveryData, '$.Events[1]') IS NOT NULL
-- If there is a second attempt there would be second event in the column ReturnedDeliveryDate
-- So null second event means no second delivery attempt
*/

-- 16. List all stock items that are manufactured in China. (Country of Manufacture)

/* Answer
SELECT StockItemID, 
	   JSON_VALUE(CustomFields, '$.CountryOfManufacture') AS CountryOfManufacture
FROM Warehouse.StockItems
WHERE JSON_VALUE(CustomFields, '$.CountryOfManufacture') = 'China';
*/

-- 17. Total quantity of stock items sold in 2015, group by country of manufacturing.

/* reference
SELECT * FROM Warehouse.StockItems; -- StockItemID, Country Of Manufacturing

SELECT * FROM Sales.Orders; -- OrderID, OrderDate

SELECT * FROM Sales.OrderLines; -- OrderID, StockItemID, Quantity
*/

/* Answer
WITH 
q17t1 AS
(
SELECT SOL.StockItemID, SUM(SOL.Quantity) AS TotalQuantitySold
FROM Sales.Orders AS SO
INNER JOIN Sales.OrderLines AS SOL
ON SO.OrderID = SOL.OrderID AND YEAR(SO.OrderDate) = 2015
GROUP BY SOL.StockItemID
)
SELECT SUM(q17t1.TotalQuantitySold) TotalQuantitySoldByManuCountry,
	   JSON_VALUE(CustomFields, '$.CountryOfManufacture') AS CountryOfManufacture
FROM Warehouse.StockItems AS WSI
INNER JOIN q17t1
ON WSI.StockItemID = q17t1.StockItemID
GROUP BY JSON_VALUE(CustomFields, '$.CountryOfManufacture')
*/

-- 18. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. 
--     [Stock Group Name, 2013, 2014, 2015, 2016, 2017]

/* reference
SELECT * FROM Sales.Orders ORDER BY OrderDate; -- OrderID, OrderDate

SELECT * FROM Sales.OrderLines; -- OrderID, StockItemID, Quantity

SELECT * FROM Warehouse.StockItemStockGroups; -- StockItemID, StockGroupID

SELECT * FROM Warehouse.StockGroups; -- StockGroupID, StockGroupName
*/

/* Answer
DROP VIEW IF EXISTS TotalQuantityEachGroupSoldByYear;
CREATE OR ALTER VIEW TotalQuantityEachGroupSoldByYear AS
WITH
q18t1 AS
(
SELECT WSISG.StockGroupID, WSG.StockGroupName, WSISG.StockItemID
FROM Warehouse.StockItemStockGroups AS WSISG
INNER JOIN Warehouse.StockGroups AS WSG
ON WSISG.StockGroupID = WSG.StockGroupID
),
q18t2 AS
(
SELECT q18t1.StockGroupID, q18t1.StockGroupName, q18t1.StockItemID, SOL.Quantity, SOL.OrderID
FROM q18t1
LEFT JOIN Sales.OrderLines AS SOL
ON q18t1.StockItemID = SOL.StockItemID
),
q18t3 AS
(
SELECT  q18t2.StockGroupName, q18t2.Quantity,YEAR(SO.OrderDate) AS OrderYear
FROM q18t2
LEFT JOIN Sales.Orders AS SO
ON q18t2.OrderID = SO.OrderID
)
SELECT StockGroupName, [2013], [2014], [2015], [2016],[2017]
FROM q18t3 
PIVOT
(
SUM(Quantity) FOR OrderYear IN ([2013], [2014], [2015], [2016], [2017])
) AS PivotTable18

SELECT * FROM TotalQuantityEachGroupSoldByYear;

*/

-- 19. Create a view that shows the total quantity of stock items of each stock group sold (in orders) by year 2013-2017. 
--     [Year, Stock Group Name1, Stock Group Name2, Stock Group Name3, … , Stock Group Name10]

/* Answer
DROP VIEW IF EXISTS TotalQuantityEachYearSoldByGroup;
CREATE OR ALTER VIEW TotalQuantityEachYearSoldByGroup AS
WITH
q19t1 AS
(
SELECT WSISG.StockGroupID, WSG.StockGroupName, WSISG.StockItemID
FROM Warehouse.StockGroups AS WSG
INNER JOIN Warehouse.StockItemStockGroups  AS WSISG
ON WSG.StockGroupID = WSISG.StockGroupID
),
q19t2 AS
(
SELECT q19t1.StockGroupName, q19t1.StockItemID, SOL.Quantity, SOL.OrderID
FROM q19t1
INNER JOIN Sales.OrderLines AS SOL
ON q19t1.StockItemID = SOL.StockItemID
),
q19t3 AS
(
SELECT YEAR(SO.OrderDate) AS OrderYear, q19t2.Quantity, q19t2.StockGroupName
FROM q19t2 
INNER JOIN Sales.Orders AS SO
ON q19t2.OrderID = SO.OrderID
)
SELECT OrderYear, 
	   [Clothing], [Computing Novelties], [Furry Footwear], [Mugs], [Novelty Items], 
	   [Packaging Materials], [T-Shirts], [Toys], [USB Novelties]
FROM q19t3 
PIVOT
(
SUM(Quantity)
FOR StockGroupName IN ([Clothing], [Computing Novelties], [Furry Footwear], [Mugs], [Novelty Items], 
					   [Packaging Materials], [T-Shirts], [Toys], [USB Novelties])
) AS PivotTable19
;

 
*/

-- 20. Create a function, input: order id; return: total of that order. 
--     List invoices and use that function to attach the order total to the other fields of invoices. 

/* Answer
SELECT * FROM Sales.Orders;

SELECT * FROM Sales.OrderLines WHERE OrderID = 1;

SELECT * FROM Sales.Invoices;

SELECT * FROM Sales.InvoiceLines;

DROP FUNCTION IF EXISTS dbo.OrderTotal;
CREATE OR ALTER FUNCTION dbo.OrderTotal
(
	@orderid AS int
)
RETURNS float
AS
BEGIN
	DECLARE @ordertotal float
	SELECT @ordertotal = SUM((SOL.Quantity*SOL.UnitPrice)*(1 + SOL.TaxRate/100))
	FROM Sales.OrderLines AS SOL
	WHERE SOL.OrderID = @orderid
	GROUP BY SOL.OrderID;
	RETURN @ordertotal;
END;

SELECT dbo.OrderTotal(1) AS OrderTotal;

SELECT * FROM Sales.Invoices AS SI
CROSS APPLY 
(SELECT dbo.OrderTotal(SI.OrderID)) AS t20(OrderTotal);

SELECT * FROM Sales.Invoices AS SI
CROSS APPLY 
(SELECT dbo.OrderTotal(SI.OrderID)) AS t20(OrderTotal);
;
*/

-- CROSS APPLY
-- Will apply every row from left table expression onto right table expression and MUST end with AS TableName(ColName);

-- 21. Create a new table called ods.Orders. 
--     Create a stored procedure, with proper error handling and transactions, that input is a date; 
--     when executed, it would find orders of that day, calculate order total, and save the information 
--     (order id, order date, order total, customer id) into the new table. 
--     If a given date is already existing in the new table, throw an error and roll back. 
--     Execute the stored procedure 5 times using different dates. 

/* Answer
DROP SCHEMA IF EXISTS ods;
CREATE SCHEMA ods;

DROP TABLE IF EXISTS ods.Orders;
CREATE TABLE ods.Orders
(
OrderID int NOT NULL primary key,
OrderDate datetime ,
OrderTotal float ,
CustomerID int 
)

-----------------------------------------------------------------------

DROP TABLE IF EXISTS t21;
CREATE TABLE t21
(
OrderID int,
OrderTotal float
)
INSERT INTO t21 
SELECT SOL.OrderID, SUM((SOL.Quantity*SOL.UnitPrice)*(1 + SOL.TaxRate/100)) AS OrderTotal
FROM Sales.OrderLines AS SOL
GROUP BY SOL.OrderID

--------------------------------------------------------------------------

DROP PROC IF EXISTS dbo.ErrorHandler;
GO

CREATE PROC dbo.ErrorHandler
AS
SET NOCOUNT ON;
BEGIN
	PRINT 'Error Number    : ' + CAST(ERROR_NUMBER() AS nvarchar(10));
	PRINT 'Error Message   : ' + ERROR_MESSAGE();
	PRINT 'Error Severity  : ' + CAST(ERROR_SEVERITY() AS nvarchar(10));
	PRINT 'Error State     : ' + CAST(ERROR_STATE() AS nvarchar(10));
	PRINT 'Error Line      : ' + CAST(ERROR_LINE() AS nvarchar(10));
	PRINT 'Error Procedure : ' + COALESCE(ERROR_PROCEDURE(), 'Not within procedure');
END;

----------------------------------------------

DROP PROC IF EXISTS dbo.GetCustomerOrderByDate;
GO

CREATE OR ALTER PROC dbo.GetCustomerOrderByDate
	@orderdate AS datetime
AS SET NOCOUNT ON;


	BEGIN TRY
		BEGIN TRANSACTION;
		INSERT INTO ods.Orders
		SELECT SO.OrderID, SO.OrderDate, t21.OrderTotal, SO.CustomerID
		FROM Sales.Orders AS SO
		INNER JOIN t21
		ON t21.OrderID = SO.OrderID
		WHERE SO.OrderDate = @orderdate;
		COMMIT;
	END TRY
	BEGIN CATCH
		BEGIN
			EXEC dbo.ErrorHandler;
			IF	
				XACT_STATE() = -1
				BEGIN
					PRINT 'The transaction is in an uncommittable state.' + ' Rolling back transaction.'
					ROLLBACK TRANSACTION;
				END;
			IF 
				XACT_STATE() = 1
				BEGIN
					PRINT 'The transaction is committbale.' + ' Committing transaction.'
					COMMIT TRANSACTION;
				END;
		END;
	END CATCH;

GO

------------------------------------------------------------

EXEC dbo.GetCustomerOrderByDate @orderdate = '2021-04-20';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2014-07-31';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2015-05-16';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2016-09-21';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2015-01-29';
SELECT * FROM ods.Orders;
*/

-- 22. Create a new table called ods.StockItem. It has following columns: [StockItemID], [StockItemName] ,
--     [SupplierID] ,[ColorID] ,[UnitPackageID] ,[OuterPackageID] ,[Brand] ,[Size] ,[LeadTimeDays] ,[QuantityPerOuter] ,
--     [IsChillerStock] ,[Barcode] ,[TaxRate]  ,[UnitPrice],[RecommendedRetailPrice] ,[TypicalWeightPerUnit] ,[MarketingComments]  ,
--     [InternalComments], [CountryOfManufacture], [Range], [Shelflife]. Migrate all the data in the original stock item table.

/* Answer
DROP TABLE IF EXISTS ods.StockItem;
CREATE TABLE ods.StockItem
(
StockItemID int,
StockItemName nvarchar(50),
SupplierID int,
ColorID int,
UnitPackageID int,
OuterPackageID int,
Brand nvarchar(50),
Size nvarchar(50),
LeadTimeDays int,
QuantityPerOuter int,
IsChillerStock bit,
Barcode nvarchar(50),
TaxRate DEC(18,2),
UnitPrice DEC(18,2),
RecommendedRetailPrice DEC(18,2),
TypicalWeightPerUnit DEC(18,3),
MarketingComments nvarchar(max),
InternalComment nvarchar(max),
CountryOfManufacture nvarchar(max),
Range nvarchar(max),
Shelflife nvarchar(50)
)

INSERT INTO ods.StockItem
(
StockItemID,
StockItemName,
SupplierID,
ColorID,
UnitPackageID,
OuterPackageID,
Brand,
Size,
LeadTimeDays,
QuantityPerOuter,
IsChillerStock,
Barcode,
TaxRate,
UnitPrice,
RecommendedRetailPrice,
TypicalWeightPerUnit,
MarketingComments,
InternalComment,
CountryOfManufacture
)
SELECT 
StockItemID,
StockItemName,
SupplierID,
ColorID,
UnitPackageID,
OuterPackageID,
Brand,
Size,
LeadTimeDays,
QuantityPerOuter,
IsChillerStock,
Barcode,
TaxRate,
UnitPrice,
RecommendedRetailPrice,
TypicalWeightPerUnit,
MarketingComments,
InternalComments,
JSON_VALUE(WSI.CustomFields, '$.CountryOfManufacture') AS CountryOfManufacture
FROM Warehouse.StockItems AS WSI;

SELECT * FROM Warehouse.StockItems;
*/

-- 23. Rewrite your stored procedure in (21). 
--     Now with a given date, it should wipe out all the order data prior to the input date 
--     and load the order data that was placed in the next 7 days following the input date.

/* Answer
DROP TABLE IF EXISTS ods.Orders;
CREATE TABLE ods.Orders
(
OrderID int NOT NULL primary key,
OrderDate datetime ,
OrderTotal float ,
CustomerID int 
)

DROP TABLE IF EXISTS t23;
CREATE TABLE t23
(
OrderID int,
OrderTotal float
)
INSERT INTO t23 
SELECT SOL.OrderID, SUM((SOL.Quantity*SOL.UnitPrice)*(1 + SOL.TaxRate/100)) AS OrderTotal
FROM Sales.OrderLines AS SOL
GROUP BY SOL.OrderID

--------------------------------------------------------------------------

DROP PROC IF EXISTS dbo.ErrorHandler;
GO

CREATE PROC dbo.ErrorHandler
AS
SET NOCOUNT ON;
BEGIN
	PRINT 'Error Number    : ' + CAST(ERROR_NUMBER() AS nvarchar(10));
	PRINT 'Error Message   : ' + ERROR_MESSAGE();
	PRINT 'Error Severity  : ' + CAST(ERROR_SEVERITY() AS nvarchar(10));
	PRINT 'Error State     : ' + CAST(ERROR_STATE() AS nvarchar(10));
	PRINT 'Error Line      : ' + CAST(ERROR_LINE() AS nvarchar(10));
	PRINT 'Error Procedure : ' + COALESCE(ERROR_PROCEDURE(), 'Not within procedure');
END;
GO
----------------------------------------------

DROP PROC IF EXISTS dbo.GetCustomerOrderByDate;
GO

CREATE OR ALTER PROC dbo.GetCustomerOrderByDate
	@orderdate AS datetime
AS SET NOCOUNT ON;


	BEGIN TRY
		BEGIN TRANSACTION;

		INSERT INTO ods.Orders
		SELECT SO.OrderID, SO.OrderDate, t23.OrderTotal, SO.CustomerID
		FROM Sales.Orders AS SO
		INNER JOIN t23
		ON t23.OrderID = SO.OrderID
		WHERE SO.OrderDate = @orderdate;

		DELETE FROM ods.Orders WHERE OrderDate < @orderdate;

		INSERT INTO Ods.Orders
		SELECT SO.OrderID, SO.OrderDate, t23.OrderTotal, SO.CustomerID
		FROM Sales.Orders AS SO
		INNER JOIN t23
		ON t23.OrderID = SO.OrderID
		WHERE SO.OrderDate BETWEEN DATEADD(day, 1, @orderdate) AND DATEADD(day, 7, @orderdate);
		COMMIT;
	END TRY
	BEGIN CATCH
		BEGIN
			EXEC dbo.ErrorHandler;
			IF	
				XACT_STATE() = -1
				BEGIN
					PRINT 'The transaction is in an uncommittable state.' + ' Rolling back transaction.'
					ROLLBACK TRANSACTION;
				END;
			IF 
				XACT_STATE() = 1
				BEGIN
					PRINT 'The transaction is committbale.' + ' Committing transaction.'
					COMMIT TRANSACTION;
				END;
		END;
	END CATCH;

GO

EXEC dbo.GetCustomerOrderByDate @orderdate = '2021-04-20';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2014-07-31';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2015-05-16';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2016-09-21';
EXEC dbo.GetCustomerOrderByDate @orderdate = '2015-01-29';
SELECT * FROM ods.Orders;
*/

-- 24. Consider the JSON file:
-- {
--    "PurchaseOrders":[
--       {
--          "StockItemName":"Panzer Video Game",
--          "Supplier":"7",
--          "UnitPackageId":"1",
--          "OuterPackageId":[
--             6,
--             7
--          ],
--         "Brand":"EA Sports",
--         "LeadTimeDays":"5",
--         "QuantityPerOuter":"1",
--         "TaxRate":"6",
--         "UnitPrice":"59.99",
--         "RecommendedRetailPrice":"69.99",
--         "TypicalWeightPerUnit":"0.5",
--         "CountryOfManufacture":"Canada",
--         "Range":"Adult",
--         "OrderDate":"2018-01-01",
--         "DeliveryMethod":"Post",
--         "ExpectedDeliveryDate":"2018-02-02",
--         "SupplierReference":"WWI2308"
--      },
--      {
--         "StockItemName":"Panzer Video Game",
--         "Supplier":"5",
--         "UnitPackageId":"1",
--         "OuterPackageId":"7",
--         "Brand":"EA Sports",
--         "LeadTimeDays":"5",
--         "QuantityPerOuter":"1",
--         "TaxRate":"6",
--         "UnitPrice":"59.99",
--         "RecommendedRetailPrice":"69.99",
--         "TypicalWeightPerUnit":"0.5",
--         "CountryOfManufacture":"Canada",
--         "Range":"Adult",
--         "OrderDate":"2018-01-025",
--         "DeliveryMethod":"Post",
--         "ExpectedDeliveryDate":"2018-02-02",
--         "SupplierReference":"269622390"
--      }
--   ]
--}
-- Looks like that it is our missed purchase orders. Migrate these data into Stock Item, Purchase Order and Purchase Order Lines tables. Of course, save the script.
/*
BEGIN
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
		WITH (
			[StockItemName]    nvarchar(50)   '$.PurchaseOrders[0].StockItemName',  
			[Supplier]         int            '$.PurchaseOrders[0].Supplier', 
			[UnitPackageId]    int            '$.PurchaseOrders[0].UnitPackageId', 
			[OuterPackageId]   int  '$.PurchaseOrders[0].OuterPackageId[0]',
			[Brand]			   nvarchar(50)  '$.PurchaseOrders[0].Brand',
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
END;
*/

-- 25. Revisit your answer in (19). Convert the result in JSON string and save it to the server using TSQL FOR JSON PATH.

/* Answer
-- Q19 result is saved as View: ToatalQuantityEachYearSoldByGroup;
SELECT * FROM TotalQuantityEachYearSoldByGroup;	
BEGIN 
DECLARE @json nvarchar(max);
SET @json = (
SELECT OrderYear,
(
SELECT [Clothing], [Computing Novelties], [Furry Footwear], [Mugs], [Novelty Items], [Packaging Materials], [T-Shirts], [Toys], [USB Novelties]
FROM TotalQuantityEachYearSoldByGroup AS TQEYSBGIn
WHERE TQEYSBGIn.OrderYear = TQEYSBGOut.OrderYear 
FOR JSON PATH
) AS [QuantitySold.Group]
FROM TotalQuantityEachYearSoldByGroup AS TQEYSBGOut 
FOR JSON PATH, INCLUDE_NULL_VALUES
);

DROP TABLE IF EXISTS dbo.jsonInfo;
CREATE TABLE dbo.jsonInfo(
		ID int,
		Logs nvarchar(max)
);
INSERT INTO dbo.jsonInfo
VALUES (1,@json);
SELECT * FROM dbo.jsonInfo;
END;
ALTER TABLE dbo.jsonInfo
ADD CONSTRAINT [logs record should be formatted as JSON]
				CHECK (ISJSON(logs) = 1)

SELECT * FROM dbo.jsonInfo;
*/

-- 26. Revisit your answer in (19). Convert the result into an XML string and save it to the server using TSQL FOR XML PATH.

/* Answer
BEGIN
DROP TABLE IF EXISTS dbo.XMLInfo;
CREATE TABLE dbo.XMLInfo(
	ID INT,
	Content XML
);
DECLARE @XMLContent XML;
SET @XMLContent = 
(
SELECT OrderYear AS '@OrderYear',
	   [Clothing], [Computing Novelties] AS [ComputingNovelties], [Furry Footwear] AS [FurryFootwear], [Mugs], [Novelty Items] AS [NoveltyItems], 
	   [Packaging Materials] AS [PackagingMaterials], [T-Shirts], [Toys], [USB Novelties] AS [USBNovelties]
FROM TotalQuantityEachYearSoldByGroup ORDER BY OrderYear 
FOR XML PATH, 
ROOT('QuantitiesSold'),
ELEMENTS XSINIL);
INSERT INTO dbo.XMLInfo(ID,Content) VALUES(1,@XMLContent);
SELECT * FROM dbo.XMLInfo;
END;
*/

-- 27. Create a new table called ods.ConfirmedDeviveryJson with 3 columns (id, date, value) . 
--     Create a stored procedure, input is a date. The logic would load invoice information (all columns) 
--     as well as invoice line information (all columns) and forge them into a JSON string and then insert into the new table just created. 
--	   Then write a query to run the stored procedure for each DATE that customer id 1 got something delivered to him.

/* Answer
DROP TABLE IF EXISTS ods.ConfirmedDeliveryJson;
CREATE TABLE ods.ConfirmedDeliveryJson
(
ID int NOT NULL,
Date datetime,
Value nvarchar(max)
);

DROP PROC IF EXISTS GetJSON;
CREATE OR ALTER PROC GetJSON
(
@inputdate datetime,
@customerid int = 1,
@json nvarchar(max) OUTPUT
) AS
BEGIN
SET @json = (
SELECT DISTINCT SI.CustomerID AS [customer.id], 
(
SELECT SI.BillToCustomerID,
	   SI.DeliveryMethodID,
	   SIL.InvoiceLineID, 
	   SIL.Description
FROM Sales.Invoices AS SI
INNER JOIN Sales.InvoiceLines AS SIL
ON SI.InvoiceID = SIL.InvoiceID
WHERE SI.CustomerID = 1 AND CONVERT(date, SI.ConfirmedDeliveryTime) = @inputdate
FOR JSON PATH
)
AS [Customer.Deliveries]
FROM Sales.Invoices SI 
WHERE SI.CustomerID = 1 
FOR JSON PATH
);
END;

DROP PROC IF EXISTS GetAnswer;
CREATE OR ALTER PROC GetAnswer AS
BEGIN
DECLARE @deliverydate TABLE(DeliveryDate datetime, RowNumber int);
DECLARE @json nvarchar(max);
DECLARE @totalrow int = 0;
DECLARE @rowcounter int = 0;
DECLARE @curtime datetime;
INSERT INTO @deliverydate
SELECT tt.deliveryDate, tt.RowNumber
FROM
(
SELECT DISTINCT CONVERT(date, SI.ConfirmedDeliveryTime) AS DeliveryDate,
	   ROW_NUMBER() OVER(ORDER BY CONVERT(date, SI.ConfirmedDeliveryTime)) AS RowNumber
FROM Sales.Invoices AS SI
WHERE SI.CustomerID = 1
) AS tt
SET @totalrow = @@ROWCOUNT;

WHILE @rowcounter < @totalrow
	BEGIN
	SET @curtime = (
	SELECT CONVERT(date, deliverydate) FROM @deliverydate
	WHERE RowNumber = @rowcounter + 1);
	EXEC GetJSON @inputdate = @curtime, 
		 @json = @json OUTPUT;
		 
	INSERT INTO ods.ConfirmedDeliveryJson
	VALUES(@rowcounter+1, @curtime, @json);
	SET @rowcounter = @rowcounter + 1;
	END;
END;

EXEC GetAnswer;
SELECT * FROM ods.ConfirmedDeliveryJson;

SELECT * FROM Sales.Invoices
*/

-- 28. Write a short essay talking about your understanding of transactions, locks and isolation levels.

/* Answer
Transaction: Transaction was defined as a unit of work that might iclude multiple activities tht query and modify data and tht can also change the data definition in book 'T-SQL fundamental'.
To put it in a little simpler way, a transaction is a unit of concurrency contro. A sequence of activities or operations that are defined by user.
For a logical unit to become a transaction, it has to meet these four properties called ACID: atumicity, consistency, isolation and durablity. 
Atomicity: A transaction is an atomic unit of work. Take exampel of a bank account, money transfer in account, either the transfer successed or faied, there's no way only half of the money got transferred right?
Consistency: After a transaction, the database will or must adhere to all integrity rules that have been defined within it by contraint. Like PK, Fk etc,. Again,for bank account, oney transferred from account 1 to account 2, the total money these two account have should be remain the same compare to the total money before transaction.
Isolation: it ensures that transactions access only consistent data. Isolation level is the mechanism used to control what consistency means to your transactions. Or we can say because isolation, one transaction will not interfere another transaction. When multiple transaction is in operation, isolation ensure the concurrency with the help of locks. SQL server supports two different models to handle isolation: pessimistic concurrency control purely based on locking and optimistic concurrency control focus on row versioning.
Durable: Basiclly it means once a transaction has been committed, the changes made to the database will be there permanently. Even system fails, the process will be recovered using transaction log.

Let's talk more about the isolation. It determines the consistency level you get when interact with data.
For isolation level, there are 4 of them: READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ and SERIALIZABLE.
READ UNCOMMITTED: The lowest available isolation level. Reader can read uncommitted changes, AKA dirty reads. It means a writer can change data while a reader is reading the data under READ UNCOMMITTED level. 
READ COMMITTED: The lowest level that prevents dirty reads. Also it is the default isolation level for SQL Server. This isolation level allows reader to read ONLY when the change is committed. 
REPEATABLE READ: This isolation level ensures that no one can change values in between reads that takes place in the same transaction. It means a reader will need a shared lock to be able to read, but also the reader will hold the lock until the end of the transaction. In other words, once a reader acquires the shared lock, no one can get the exclusive lock to modify(UPDATE) the resources until the reader end the transaction. Although under this isolation level, resources can be UPDATE by no one, it can still have new rows that are INSERTED by another transaction. And this is called phantom read.
SERIALIZABLE: It is the highest isolation level. It will prevent phantom read because it blocks attempts made by other transactions to add(INSERT) rows.

Shared lock, also called read lock, used for reading data items only. It supports read integrity and ensure that a record is not in process of being updated during a read-only request.
Exclusive lock, also called write lock, allows a data item to be read as well as written. It prevents any other locks get obtained. It can be owned by only one transaction at a time. 
*/

-- 29. Write a short essay, plus screenshots talking about performance tuning in SQL Server. Must include Tuning Advisor, Extended Events, DMV, Logs and Execution Plan.

/* Answer

See external file

*/

-- 30. Write a short essay talking about a scenario: Good news everyone! 
--     We (Wide World Importers) just brought out a small company called “Adventure works”! 
--     Now that bike shop is our sub-company. The first thing of all works pending would be to merge the user logon information,
--     person information (including emails, phone numbers) and products (of course, add category, colors) to WWI database. 
--     Include screenshot, mapping and query.

/* Answer

See external file

*/

-- 31. Database Design: OLTP db design request for EMS business: 
--     when people call 911 for medical emergency, 911 will dispatch UNITs to the given address. 
--     A UNIT means a crew on an apparatus (Fire Engine, Ambulance, Medic Ambulance, Helicopter, EMS supervisor). 
--     A crew member would have a medical level (EMR, EMT, A-EMT, Medic). 
--     All the treatments provided on scene are free. 
--     If the patient needs to be transported, that’s where the bill comes in. 
--     A bill consists of Units dispatched (Fire Engine and EMS Supervisor are free), crew members provided care (EMRs and EMTs are free), 
--     Transported miles from the scene to the hospital (Helicopters have a much higher rate, as you can image) and tax (Tax rate is 6%). 
--     Bill should be sent to the patient insurance company first. If there is a deductible, we send the unpaid bill to the patient only. 
--     Don’t forget about patient information, medical nature and bill paying status.

/* Answer

See external file

*/

-- 32. Remember the discussion about those two databases from the class, also remember, those data models are not perfect. 
--     You can always add new columns (but not alter or drop columns) to any tables. 
--     Suggesting adding Ingested DateTime and Surrogate Key columns. Study the Wide World Importers DW. 
--     Think the integration schema is the ODS. 
--     Come up with a TSQL Stored Procedure driven solution to move the data from WWI database to ODS, 
--     and then from the ODS to the fact tables and dimension tables. By the way, WWI DW is a galaxy schema db. Requirements:
--     Luckly, we only start with 1 fact: Order. Other facts can be ignored for now.
--     Add a new dimension: Country of Manufacture. It should be given on top of Stock Items.
--     Write script(s) and stored procedure(s) for the entire ETL from WWI db to DW.

/* Answer

See external file

*/







