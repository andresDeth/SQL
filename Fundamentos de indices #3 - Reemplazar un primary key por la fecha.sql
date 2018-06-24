CREATE DATABASE CASINO;

USE [CASINO]
GO

IF EXISTS(SELECT 1 FROM sys.tables where name = 'GamePlay_Demo')
BEGIN
	DROP TABLE dbo.GamePlay_Demo
END

-- Creo la tabla sin ningun primary KEY
CREATE TABLE [dbo].[GamePlay_Demo](
  [HandID] [bigint] IDENTITY(1,1) NOT NULL,
  [PlayerID] [int] NOT NULL,
  [GameID] [int] NOT NULL,
  [bet] [money] NOT NULL,
  [payout] [money] NOT NULL,
  [HandDate] [datetime] NOT NULL
) ON [PRIMARY]
GO

-- Insert some data
   INSERT INTO dbo.GamePlay_Demo
   (PlayerID, GameID, bet, payout, HandDate)
   VALUES (1, 1, 90000, 89000, GETDATE())
   GO 2000000

-- Insert some data
   INSERT INTO dbo.GamePlay_Demo
   (PlayerID, GameID, bet, payout, HandDate)
   VALUES (3, 4, 565443, 67565, GETDATE())
   GO 2000000

-- Insert some data
   INSERT INTO dbo.GamePlay_Demo
   (PlayerID, GameID, bet, payout, HandDate)
   VALUES (2, 3, 4, 39450, GETDATE())
   GO 500000

-- Insert some data
   INSERT INTO dbo.GamePlay_Demo
   (PlayerID, GameID, bet, payout, HandDate)
   VALUES (2, 3, 89, 39450, GETDATE())
   GO 500000

   SELECT TOP (5000000) PlayerID, GameID, bet, payout, HandDate
   FROM dbo.GamePlay
   ORDER BY HandDate DESC

-- Enable IO STATS AND SHOW EXECUTION PLAN
   SET STATISTICS TIME ON
   SET STATISTICS IO ON

-- Check Table Type
   SELECT objs.name, ix.type_desc
   FROM sys.indexes as ix
   INNER JOIN sys.objects as objs
   ON objs.object_id = ix.object_id
   WHERE objs.name = 'GamePlay_Demo'

-- Select some data
   SELECT TOP (100) * FROM dbo.GamePlay_Demo

-- Filter Data, bets lower than 10USD
   SELECT * FROM dbo.GamePlay_Demo
   WHERE bet < 10
 
 -- Filter data, greater than 1 month ago
    SELECT * FROM dbo.GamePlay_Demo
    WHERE HandDate >= GETDATE() - 31

-- Get min and Max dates
    SELECT MIN(HandDate), MAX(HandDate) FROM dbo.GamePlay_Demo

-- Select First 100 games
   SELECT TOP (100) * FROM dbo.GamePlay_Demo
   ORDER BY HandDate ASC

 -- CREATE CLUSTERES INDEX
    CREATE CLUSTERED INDEX cix_GamePlay_demo_HandDate
	ON dbo.GamePlay_demo (HandDate);

-- Check table type
    SELECT objs.name, ix.type_desc
	FROM sys.indexes as ix
	INNER JOIN sys.objects as objs
	ON objs.object_id = ix.object_id
	WHERE objs.name = 'GamePlay_Demo'

-- Volvemos a hacer la consulta ahora con el indice colocado

-- Select some data
   SELECT TOP (100) * FROM dbo.GamePlay_Demo

-- Filter Data, bets lower than 10USD
   SELECT * FROM dbo.GamePlay_Demo
   WHERE bet < 10
 
 -- Filter data, greater than 1 month ago, aca obtengo menos lecturas logicas que con el HEAP
    SELECT * FROM dbo.GamePlay_Demo
    WHERE HandDate >= GETDATE() - 31

-- Get min and Max dates, escanea el indice dos veces
   SELECT MIN(HandDate), MAX(HandDate) FROM dbo.GamePlay_Demo

-- Select First 100 games
   SELECT TOP (100) * FROM dbo.GamePlay_Demo
   ORDER BY HandDate ASC

SET STATISTICS TIME OFF
SET STATISTICS IO OFF

-- How do I detect Tables without clustered index?
SELECT 
	tbs.name as TableName,
	ixs.type_desc as Index_Type,
	ps.rows as Index_Rows
FROM sys.tables as tbs
INNER JOIN sys.indexes as ixs
	ON ixs.object_id = tbs.object_id
INNER JOIN sys.partitions as ps	
	ON ps.object_id = tbs.object_id AND ps.index_id = ixs.index_id
WHERE ixs.index_id = 0


-- DROP CLUSTERED INDEX TO TEST THE QUERY
   DROP INDEX cix_GamePlay_demo_HandDate
   ON dbo.GamePlay_demo

-- Tablas sin indice clustered
SELECT 
	tbs.name as TableName,
	ixs.type_desc as Index_Type,
	ps.rows as Index_Rows
FROM sys.tables as tbs
INNER JOIN sys.indexes as ixs
	ON ixs.object_id = tbs.object_id
INNER JOIN sys.partitions as ps	
	ON ps.object_id = tbs.object_id AND ps.index_id = ixs.index_id
WHERE ixs.index_id = 0

-- DEFAULTS: Primary key is the clustered index
USE CASINO;

IF EXISTS(select 1 from sys.tables WHERE name = 'PKTable')
BEGIN
	DROP TABLE PKTable
END

CREATE TABLE PKTable(
  id int identity(1,1),
  cl varchar(50) not null,
  constraint PK_PKTable primary key(id)
)

-- Check indexes for PKTable
SELECT
	tbs.name as TableName,
	ixs.type_desc as Index_Type,
	ixs.name as IndexName,
	ps.rows as Index_Rows
FROM sys.tables as tbs
INNER JOIN sys.indexes as ixs
	ON ixs.object_id = tbs.object_id
INNER JOIN sys.partitions as ps
    ON ps.object_id = tbs.object_id AND ps.index_id = ixs.index_id
WHERE tbs.name = 'PKTable'

-- Muchas veces no queremos que la primary key sea nuestro indice clustered
-- Recordar que el indice clustered estara ordenado
-- PUEDO DECIR QUE LA FECHA SEA EL INDICE CLUSTERED, PUESTO QUE INSERTARE REGISTROS CADA VEZ MAS NUEVOS, 
-- NO VAMOS A INSERTAR REGISTROS DE HACE UN MES (DEPENDE DEL NEGOCIO)
-- ES UNA BUENA PRACTICA PORQUE MEJORA LA INSERCION
-- Si insertamos datos no ordenados NO SIEMPRE LA PRIMARY KEY TIENE QUE SER EL INDICE CLUSTERED

-- BORRAMOS EL INDICE CLUSTERED Y CREAMOS LA PRIMARY KEY COMO UN INDICE NONCLUSTERED
ALTER TABLE PKTable
DROP CONSTRAINT PK_PKTable;

ALTER TABLE PKTable
ADD CONSTRAINT PK_PKTable PRIMARY KEY NONCLUSTERED(id);

-- Si vuelvo a checkear el tipo de tabla me dira que es un TIPO NONCLUSTERED
SELECT
	tbs.name as TableName,
	ixs.type_desc as Index_Type,
	ixs.name as IndexName,
	ps.rows as Index_Rows
FROM sys.tables as tbs
INNER JOIN sys.indexes as ixs
	ON ixs.object_id = tbs.object_id
INNER JOIN sys.partitions as ps
    ON ps.object_id = tbs.object_id AND ps.index_id = ixs.index_id
WHERE tbs.name = 'PKTable'






