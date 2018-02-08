

-- INDICES COLUMNARES

create nonclustered columnstore index
<name> on <tabla> (<columns>) with
(compression_delay = 30 Minutes)

-- MEJORA EN OVERHEADER : ARQUITECTURA DISTRIBUIDA

-- Con [AlwaysOn Availability Group] podemos mejorar el analisis en tiempo real
-- Direccionando a nuestros usuarios de reporteria a servidores secundarios
-- Usando ademas los indices columnares, los cuales seran replicados automaticamente
-- en los nodos secundarios.

-- Se puede redireccionar la lectura al segundo nodo en lugar de ir al primero
-- seria muy muy rápido ese escenario.

-- Se pueden crear indices columnares en memoria. Obligatorio que la tabla este en memoria
-- Se recomienda en las usar el compresion delay para no pegarle al CPU cuando se usan indices
-- columnares en tablas en memoria.

-- 1) PRUEBA DE CONSULTAS COMPLEJAS CON ALTO CONTENIDO DE CARGA EN LECTURA
--    DEBEN DEMORAR BASTANTE EN EJECUTAR

-- Las tablas no deben tener ningun indice
   
SELECT  storekey, month(datekey), sum(SalesAmount)
FROM ContosoRetailDW.dbo.FactOnlineSales
WHERE StoreKey <> 782 or PromotionKey > 1 or SalesOrderNumber like '%1017%'
GROUP BY storekey, month(datekey)
ORDER BY storekey, month(datekey);

SELECT storename, month(datekey), sum(SalesAmount)
FROM ContosoRetailDW.dbo.FactOnlineSales
JOIN DimStore
ON DimStore.StoreKey = FactOnlineSales.StoreKey
WHERE FactOnlineSales.StoreKey <> 782 or PromotionKey > 1 or SalesOrderNumber like '%1017%'
GROUP BY storename, month(datekey)
ORDER BY storename, month(datekey);

-- 2) CREAMOS EL INDICE COLUMNAR NONCLUSTER VIA GRAFICA A LA TABLA FactOnlineSales

-- Se recomienda incluir todas las columnas de la tabla
-- Se compresionan 12 millones de registros
-- Demora algún tiempo en crearse el indice columnar

-- DEBEN DEMORAR MUY POCO TIEMPO Y HACER USO DEL COLUMN STORE EN EL PLAN DE EJECUCIÓN
-- RECORDAR - Que la tabla esta en disco, el siguiente paso es crearla en memoria


-- 3) CREAR TABLA EN MEMORIA

USE ContosoRetailDW
go
CREATE TABLE dbo.FactOnlineSales_inmem(
   OnlineSalesKey int NOT NULL PRIMARY KEY NONCLUSTERED,
   DateKey datetime NOT NULL,
   StoreKey int NOT NULL,
   ProductKey int NOT NULL,
   PromotionKey int NOT NULL,
   CurrencyKey int NOT NULL,
   CustomerKey int NOT NULL,
   SalesOrderNumber nvarchar(20) NOT NULL,
   SalesOrderLineNumber int NULL,
   SalesQuantity int NOT NULL,
   SalesAmount money NOT NULL,
   ReturnQuantity int NOT NULL,
   ReturnAmount money NULL,
   DiscountQuantity int NULL,
   DiscountAmount money NULL,
   TotalCost money NULL,
   UnitCost money NULL,
   UnitPrice money NULL,
   ETLLoadID int NULL,
   LoadDate datetime NULL,
   UpdateDate datetime NULL,
   INDEX t_account_cci CLUSTERED COLUMNSTORE -- Indice columnar
   ) WITH(MEMORY_OPTIMIZED = ON)

-- 4) REPETIMOS LAS CONSULTA, AHORA APUNTANDO A LAS TABLAS EN MEMORIA

-- A mayor datos se notará más la diferencia

SELECT  storekey, month(datekey), sum(SalesAmount)
FROM ContosoRetailDW.dbo.FactOnlineSales_inmem
WHERE StoreKey <> 782 or PromotionKey > 1 or SalesOrderNumber like '%1017%'
GROUP BY storekey, month(datekey)
ORDER BY storekey, month(datekey);

SELECT storename, month(datekey), sum(SalesAmount)
FROM ContosoRetailDW.dbo.FactOnlineSales_inmem
JOIN DimStore
ON DimStore.StoreKey = FactOnlineSales_inmem.StoreKey
WHERE FactOnlineSales_inmem.StoreKey <> 782 or PromotionKey > 1 or SalesOrderNumber like '%1017%'
GROUP BY storename, month(datekey)
ORDER BY storename, month(datekey);

-- Aclaración: Se debe tener en cuenta que Todo esto ocupa cierta cantidad de RAM.

-- Desde SQL 2016 se puede consultar cuanto ocupa un Query en memoria.

-- Requisito obligatorio: se debe tener buena cantidad de RAM, minimo 256GB para arriba de RAM.
-- Si la base de datos es menor a 256GB, es mejor no implementar una solución de este tipo
-- Ya que para bases de datos tan pequeñas realmente el rendimiento no se ve a simple vista - Conclusión: NO VALDRIA LA PENA

-- RECOMENDACIONES DEL AUTOR: en un ambiente de dataWarehouse, se recomienda crear una base de datos 
-- De tipo tabular y configurar en el Analysis services - Modo DirectQuery
-- Este modo en lugar de cargar la info a memoria la carga a cache Y YO NO LA TENGO QUE CARGAR
-- UNICAMENTE MANTIENE EL CACHE


-- NO TODAS LAS TABLAS DEBEN TENER INDICES COLUMNARES - UNICAMENTE TABLAS QUE SON NECESARIAS PARA ANALISIS EN TIEMPO REAL

  



 








 