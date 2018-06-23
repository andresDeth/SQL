 -- Demo #4: Hacer consultas que tomen ventaja del Batch mode.
    USE [AdventureWorks2016CTP3]
    GO

-- [1] SE CREA UNA TABLA TEMPORAL
   CREATE TABLE #Result (Cost int, ProductId int);

-- [2] INSERTAMOS EL RESULTADO DEL COLUMNSTORE A LA TABLA TEMPORAL - EL BATCHMODE APLICA
--	   HABILITAR EL PLAN DE EJECUCIÓN Y OBSERVAR QUE SE UTILIZA EN EL PROCESO DE INSERCION EL INDEX SCAN EN MODO BATCH MODE
   INSERT INTO #Result
   SELECT SUM(ActualCost), ProductId
   FROM dbo.bigTransactionHistoryTwo
   WHERE TransactionDate between '2006-10-01T00:00:00' and '2009-04-01T00:00:00'
   GROUP BY ProductId;

   SELECT * FROM #Result;

-- [3] EL MISMO EJEMPLO CON UNA TABLA VARIABLE - EL BATCHMODE NO APLICA, SE DESACTIVA
--     EN ESTE CASO NO UTILIZAMOS EL INDICE COLUMNSTORE Y NO SE USA EL BATCHMODE SINO EL ROW-MODE
   DECLARE @Result AS TABLE (Cost int, ProductId int);

   INSERT INTO @Result
   SELECT SUM(ActualCost), ProductId
   FROM dbo.bigTransactionHistoryTwo
   WHERE TransactionDate between '2006-10-01T00:00:00' and '2009-04-01T00:00:00'
   GROUP BY ProductId;

-- [4] CONSULTAMOS INDICANDO EL NUMERO DE PARALELISMO / CPUs CON MAXDOP
   SELECT SUM(ActualCost), ProductId
   FROM dbo.bigTransactionHistoryTwo
   WHERE TransactionDate BETWEEN '2006-10-01T00:00:00' and '2010-04-01T00:00:00'
   GROUP BY ProductId OPTION(MAXDOP 1);

   SELECT SUM(ActualCost), ProductId
   FROM dbo.bigTransactionHistoryTwo
   WHERE TransactionDate BETWEEN '2006-10-01T00:00:00' and '2010-04-01T00:00:00'
   GROUP BY ProductId OPTION(MAXDOP 4);


   SELECT SUM(Quantity) AS SUMATORIA, AVG(ActualCost) AS PROMEDIO, MIN(Quantity) AS MINIMO, MAX(Quantity) AS MAXIMO,
    	  STDEV(Quantity) AS DESVIACION, VAR(Quantity) AS VARIANZA, ProductID
   FROM dbo.bigTransactionHistoryTwo
   WHERE TransactionDate BETWEEN '2005-01-01T00:00:00'
	   				      AND    '2010-06-01T00:00:00'
   GROUP BY ProductId
   ORDER BY ProductId DESC 
   OPTION(MAXDOP 4);

-- Los indices Columnares se recomiendan utilizar o al inicio de la creacion de la tabla en un sistema nuevo 
-- o despues de tener millones y millones de registros. Por lo menos más de 50 millones de registros.

-- CON EL SWITCH NO TENEMOS QUE HACER UN REBUILD EN LA TABLA DE PRODUCCION
-- HACEMOS EL REBUILD EN LA TABLA DE STAGING Y CUANDO HACEMOS EL SWITCH DE LA PARTICION DE STAGING A PRODUCCION
-- YA NO TENEMOS QUE HACER EL REBUILD EN LA TABLA DE PRODUCCION