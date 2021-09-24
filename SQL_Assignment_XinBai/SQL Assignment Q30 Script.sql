
/*
USE AdventureWorks2019;

DROP TABLE IF EXISTS dbo.ADWEmployeeInfo;
-- Create a new table that contains all the ADW db employee info
CREATE TABLE dbo.ADWEmployeeInfo (
PersonID int,
PersonType nvarchar(10),
FullName nvarchar(max),
LoginID nvarchar(max),
PasswordHash nvarchar(max),
PhoneNumber nvarchar(max),
EmailAddress nvarchar(max)
);

WITH
q30t1 AS
(
SELECT PPr.BusinessEntityID AS PersonID, PPr.PersonType, CONCAT(PPr.FirstName, ' ', PPr.LastName) AS FullName, HRE.LoginID
FROM Person.Person AS PPr
LEFT JOIN HumanResources.Employee AS HRE
ON PPr.BusinessEntityID = HRE.BusinessEntityID 
WHERE PPr.PersonType = 'EM' OR PPr.PersonType = 'SP'
-- FYI, 'SC' means store contact, 'IN' means individual, 'VC' means vendor contact, 
-- 'GC' means General contact, 'SP' means sales person, 'EM' means not-sale-person employee.
-- Since we just bought out ADW, the only thing we can be sure of is that those employees of ADW, now are WWI employees.
-- And as for those people whose person type is not 'sp' or 'em', there's no way for us to know whether we are gonna keep those
-- vendor or retail. 
-- So we decided to only select those peoson whose person type is 'SP' (sales person) or 'EM' (not-sale-person employee)
),
q30t2 AS
(
SELECT q30t1.PersonID, q30t1.PersonType, q30t1.FullName, q30t1.LoginID, PPw.PasswordHash
FROM q30t1
LEFT JOIN Person.Password AS PPw
ON q30t1.PersonID = PPw.BusinessEntityID
),
q30t3 AS
(
SELECT q30t2.PersonID, q30t2.PersonType, q30t2.FullName, q30t2.LoginID, q30t2.PasswordHash, PPP.PhoneNumber
FROM q30t2
LEFT JOIN Person.PersonPhone AS PPP
ON q30t2.PersonID = PPP.BusinessEntityID
-- there are 19972 rows in table Person.PersonPhone and there are also 19972 rows of DISTINCT BusinessEntityID
-- which means each business entity have only one phone number store in the Person.PersonPhone table
-- so the situation that one business entity may have more than one phone number in the table with different phone type 
-- does not exist.
)
INSERT INTO dbo.ADWEmployeeInfo
SELECT q30t3.PersonID, q30t3.PersonType, q30t3.FullName, q30t3.LoginID, q30t3.PasswordHash, q30t3.PhoneNumber, PEA.EmailAddress
FROM q30t3
LEFT JOIN Person.EmailAddress AS PEA
ON q30t3.PersonID = PEA.BusinessEntityID
-- INSERT all the ADW db employee info into the dbo.ADWEmployeeInof table

ALTER TABLE dbo.ADWEmployeeInfo
ADD IsEmployee bit ,
    IsSalesperson bit,
	PreferredName nvarchar(50),
	IsPermittedToLogOn bit,
	IsExternalLogonProvider bit,
	IsSystemUser bit,
	LastEditBy int;
-- Since there are several columns in WWI.Application.People don't allow null value,
-- we add columns with matching datatype in the dbo.ADWEmployeeInfo beforehead merging ADW employee information with WWI employee information

UPDATE dbo.ADWEmployeeInfo
SET IsEmployee = 1, IsSalesperson = 0
WHERE PersonType = 'EM';

UPDATE dbo.ADWEmployeeInfo
SET IsEmployee = 0, IsSalesperson = 1
WHERE PersonType = 'SP';
-- Based on dbo.ADWEmployeeInfo.Persontype, assign value to dbo.ADWEmployeeInfo.IsEmployee (column) and dbo.ADWEmployeeInfo.IsSalesperson (column)

UPDATE dbo.ADWEmployeeInfo
SET PersonID = PersonID + 3261,
	PreferredName = ' ',
	IsPermittedToLogon = 1,
	IsExternalLogonProvider = 0,
	IsSystemUser = 1,
	LastEditBy = 1
;
-- Add 3261 to each personID so after inserting, the ID column in the new table would in the correct order.
-- And since all those columns are set NOT NULL we decided to assign when with the value we picked,although we not quite sure if these 
-- new employees transferred from ASW are actually System users or external logon providers.

ALTER TABLE dbo.ADWEmployeeInfo
DROP COLUMN PersonType;
-- After IsEmployee column and IsSalesperson column the Persontype column is no longer needed so we drop it

SELECT * FROM dbo.ADWEmployeeInfo;
-- At this point we get the table that contains all the columns we can get on ADW employee info

USE WideWorldImporters;

INSERT INTO Application.People(
								PersonID, FullName, LogonName, HashedPassword, 
								PhoneNumber, EmailAddress, IsEmployee, IsSalesperson,
								PreferredName, IsPermittedToLogon, IsExternalLogonProvider, IsSystemUser, 
								LastEditedBy)
SELECT PersonID, FullName, LoginID, 
	   CONVERT(varbinary, PasswordHash), 
	   PhoneNumber, EmailAddress, IsEmployee, IsSalesperson, Preferredname, 
	   IsPermittedToLogOn, IsExternalLogonProvider, IsSystemUser, LastEditBy
FROM AdventureWorks2019.dbo.ADWEmployeeInfo;
-- We insert all the columns from ADW.dbo.ADWEmployeeInfo into the WWI.Application.People table to merge these two table.

SELECT *  FROM Application.People;
-- the ADW User Logon information, person information has been merge to WWI database.

--------------------------------------------------------------------

USE AdventureWorks2019;

-- Create a ProductionColor table.
DROP TABLE IF EXISTS Production.Color;
CREATE TABLE Production.Color 
(
ColorID int NOT NULL IDENTITY(1,1),
ColorName nvarchar(20)
);
-- Because the WWI.Warehouse.StockItems table contains ColorID column, and it is the PK of WWI.Warehouse.Colors
-- We will need to update the WWI.Warehouse.Colors at first
-- in other words, we cannot add value to a foreign key column in a table without updating it in its primary key table first.
-- In order to merge color information of a product, we need to update the WWI.Warehouse.Colors table first.
-- So we create a new table with column of colorID and color Name

INSERT INTO Production.Color(ColorName)
SELECT DISTINCT ISNULL(Color, 'NA') FROM Production.Product;
-- then insert distinct color name from the ADW.Production.Product into the new Production.Color table
-- And the CorlorID will generate new identity automatically
-- Now we have a Product.Color table;

SELECT * FROM Production.ProductCategory;
INSERT INTO Production.ProductCategory(ProductCategoryID, Name)
VALUES ('NA')
-- Add a new row to ADW.Production.ProductCategory table with the new category name as 'NA'

SELECT * FROM Production.ProductSubcategory;
INSERT INTO Production.ProductSubcategory(ProductCategoryID, Name)
VALUES (5, 'NA')
-- Add a new row to Production.SubCatogery table with the new subcategory whose name is 'NA' 
-- and sub category belongs to the Product category whose Product Category is 5

DROP TABLE IF EXISTS dbo.ADWProductInfo;
CREATE TABLE dbo.ADWProductInfo
(
ProductID int,
ProductName nvarchar(max),
ColorID int,
Color nvarchar(20),
ProductCategoryID int,
ProductCategoryName nvarchar(50)
);
-- Create a table called dbo.ADWProductInfo to store all the ADW production information

WITH
q30t4 AS
(
SELECT PP.ProductID, PP.Name AS ProductName, PC.ColorID, ISNULL(PP.Color, 'NA') AS Color, ISNULL(PP.ProductSubcategoryID,38) AS ProductSubcateogoryID
FROM Production.Product AS PP
LEFT JOIN Production.Color AS PC
ON ISNULL(PP.Color,'NA') = PC.ColorName
-- we join ADW.Production with ADW.ProductionSubcategory to get the product ID, Name, its color and its category ID
-- there's will be a lot NULL in color column because that what they were in there original table
-- As the matching columns in WWI.StockItem are not allow NULL,
-- we use ISNULL() on Color to replace NULL with string 'NA'
),
q30t5 AS
(
SELECT q30t4.ProductID, q30t4.ProductName, q30t4.ColorID, q30t4.Color, q30t4.ProductSubcateogoryID,
	   ISNULL(PPS.ProductCategoryID, 5) AS ProductCategoryID
FROM q30t4 
LEFT JOIN Production.ProductSubcategory AS PPS
ON q30t4.ProductSubcateogoryID = PPS.ProductSubcategoryID
-- Same as what we did on Color Column, we use ISNULL() to replace all the NULL in ProductCategory column
)
INSERT INTO dbo.ADWProductInfo
SELECT q30t5.ProductID, q30t5.ProductName, q30t5.ColorID, q30t5.Color,
	   q30t5.ProductCategoryID, PPC.Name AS ProductCategoryName
FROM q30t5 
LEFT JOIN Production.ProductCategory AS PPC
ON q30t5.ProductCategoryID = PPC.ProductCategoryID
-- insert all the product information we will be need into the new dbo.ADWProductInfo table.

SELECT * FROM dbo.ADWProductInfo;
-- now we have all the information we need that will be put into the WWI.Warehouse.StockItems

UPDATE dbo.ADWProductInfo
SET ProductID = ProductID + 227
-- Add 227 to each ProductID so after inserting, the StockItemID column in the new table would in the correct order.

USE WideWorldImporters;

INSERT INTO Warehouse.Colors (ColorName, LastEditedBy)
SELECT DISTINCT NewColor.Color, 1
FROM AdventureWorks2019.dbo.ADWProductInfo AS NewColor
WHERE NewColor.Color  COLLATE SQL_Latin1_General_CP1_CI_AS NOT IN (SELECT DISTINCT ColorName FROM Warehouse.Colors ) 
;
-- As we mentioned before, we need to update the WWI.Warehouse.Colors table first since it contains the color ID as its PK
-- So use NOT IN to find those colors that are not already in the WWI.Warehouse.Colors table and insert them into it
-- About this 'COLLATE SQL_Latin1_General_CP1_CI_AS', before adding this line, there were an error message about the query,
-- and after interneting and asking other for help, we add it in order to get the result we want, still have no idea what this COLLATE means though
SELECT * FROM Warehouse.Colors;
-- Now we have updated the Warehouse.Color table with all the new colors from ADW db.

INSERT INTO Warehouse.StockItems
(StockItemID, StockItemName, SupplierID, ColorID, UnitPackageID, OuterPackageID, IsChillerStock,
 LeadTimeDays, QuantityPerOuter, TaxRate, UnitPrice, TypicalWeightPerUnit, LastEditedBy
)
SELECT ProductID, ProductName, 1, ColorID, 1, 1 ,1, 1, 1, 1, 1, 1,  1
FROM AdventureWorks2019.dbo.ADWProductInfo;
-- Now that we have already updated the WWI.Warehouse.Color, 
-- we can try merge the information of our new product (ADWProductInfo) into WWI.Warehouse.StockItems
-- Since a lot of columns in WWI.Warehouse.StockItems are not allowed NULL
-- We assign them with the value we picked since there is no way for us to know who is the real supplier and further detailed information

SELECT * FROM Warehouse.StockItems;

INSERT INTO WareHouse.StockitemStockGroups(StockItemID, StockGroupID, LastEditedBy)
SELECT ProductID, ProductCategoryID, 1
FROM AdventureWorks2019.dbo.ADWProductInfo;
-- After updating the new product color information, now it's turn for product category
-- insert new product's productID, ProductCategoryID into the WWI.Warehouse.StockitemStockGroups

SELECT * FROM Warehouse.StockitemStockGroups;
-- the new records are now in the lower half of the WWI.Warehouse.StockitemsStockGroups
-- Because the StockItem and StockGroup are connected using this table so we need to update it as well

SELECT * FROM AdventureWorks2019.dbo.ADWProductInfo

SELECT * FROM Warehouse.StockGroups

INSERT INTO Warehouse.StockGroups(StockGroupName, LastEditedBy)
SELECT DISTINCT NewCategory.ProductCategoryName, 1
FROM AdventureWorks2019.dbo.ADWProductInfo AS NewCategory
WHERE NewCategory.ProductCategoryName  COLLATE SQL_Latin1_General_CP1_CI_AS   NOT IN (SELECT DISTINCT StockGroupName FROM Warehouse.StockGroups ) 
;
-- In case there are Product Categorys and Stock Groups who share a same name
-- We use NOT IN to find out those product categorys' name that are not the same as those of Stock group.
-- Still have no idea about this 'COLLATE SQL_Latin1_General_CP1_CI_AS'

SELECT * FROM Warehouse.StockGroups;
*/



-- 