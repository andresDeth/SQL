-- Demo #3 - Indices nonclustered de cobertura COVERAGE

USE CASINO;
GO

-- Enable IO STATS AND SHOW EXECUTION PLAN
   SET STATISTICS TIME ON
   SET STATISTICS IO ON

 -- QUERY WITH LOOKUP
	SELECT PlayerID, payout, HandDate, GameName
	FROM dbo.GamePlay_Demo as gp
	INNER JOIN dbo.game as g
	ON g.gameID = gp.GameID
	WHERE g.GameName = 'BlackJack' AND gp.PlayerID = 1500;

-- Get Index Size, una pagina son 8KB
 SELECT 
	tbs.name as TableName,
	ixs.type_desc as Index_Type,
	ixs.name as IndexName,
	SUM(s.used_page_count) * 8 AS IndexSIzeKB,
	(SUM(s.used_page_count) * 8.)/1024. AS IndexSizeMB
FROM sys.dm_db_partition_stats as s
INNER JOIN sys.indexes as ixs
	ON s.object_id = ixs.object_id AND s.index_id = ixs.index_id
INNER JOIN sys.tables as tbs	
	ON tbs.object_id = ixs.object_id
	WHERE tbs.name = 'GamePlay_Demo'
GROUP BY tbs.name, ixs.type_desc, ixs.name
ORDER BY ixs.name


-- Change the index and crate the covered index, ahora el lookup desaparecera y el numero de lecturas logicas desminuira
-- Para el ejemplo disminuye de 128 lecturas a 3 lecturas logicas
CREATE NONCLUSTERED INDEX nci_GamePlayDemo_PlayerID
ON dbo.GamePlay_Demo (PlayerID)
INCLUDE (payout, GameID) -- ESTO ES EL COVERAGE
WITH (drop_existing = ON);

-- Query with covered index
SELECT PlayerID, payout, HandDate, GameName
FROM dbo.GamePlay_Demo as gp
INNER JOIN dbo.game as g
ON g.gameID = gp.GameID
WHERe g.GameName = 'BlackJack' AND gp.PlayerID = 1500

-- Si volvemos a ver el tamaño del indice veremos que el tamaño a aumentado
 SELECT 
	tbs.name as TableName,
	ixs.type_desc as Index_Type,
	ixs.name as IndexName,
	SUM(s.used_page_count) * 8 AS IndexSIzeKB,
	(SUM(s.used_page_count) * 8.)/1024. AS IndexSizeMB
FROM sys.dm_db_partition_stats as s
INNER JOIN sys.indexes as ixs
	ON s.object_id = ixs.object_id AND s.index_id = ixs.index_id
INNER JOIN sys.tables as tbs	
	ON tbs.object_id = ixs.object_id
	WHERE tbs.name = 'GamePlay_Demo'
GROUP BY tbs.name, ixs.type_desc, ixs.name
ORDER BY ixs.name

-- 90MB Vs. 145MB
-- 128 logical read Vs. 3 Reads

-- CUANDO VEO UN INDICE CON MAS DE 4 COLUMNAS NO ME PARECE INDICADO, DEBERIA EXISTIR OTRA SOLUCION

-- FILTERED INDEXES, son indices nonclustered pero las claves que se almacenen en los nodos hojas estaran filtradas
-- esto nos permite tener estructuras mucho mas pequeñas
USE CASINO
GO

-- Queremos obtener la lista de las ultimas jugadas ganadoras para un juego en concreto
CREATE PROCEDURE sproc_GetWinningHandsOfGame
(
  @GameID int
)
as

SELECT PlayerID, payout, GameID, HandDate
FROM dbo.GamePlay_Demo as gp
WHERE gameID = @GameID AND payout > 0;
GO

-- Creo el indice nonclustered
CREATE NONCLUSTERED INDEX nci_GamePlayDemo_GameID
ON dbo.GamePlay_Demo (GameID)
-- with (drop_existing = ON);

-- Try BlackJack - no utiliza el indice que creamos
exec sproc_GetWinningHandsOfGame @GameID = 1;

-- Include columns
CREATE NONCLUSTERED INDEX nci_GamePlayDemo_GameID
ON dbo.GamePlay_Demo (GameID)
INCLUDE (payout, playerID)
WITH (drop_existing = ON)

-- Try BlackJack pasamos de logical read de 19.000 a 1.800
exec sproc_GetWinningHandsOfGame @GameID = 1;

-- Creacion del indice filtrado
-- Si vemos siempre estamos consultado el payout que sea mayor a cero en la consulta
SELECT PlayerID, payout, GameID, HandDate
FROM dbo.GamePlay_Demo as gp
WHERE gameID = @GameID AND payout > 0;
-- PODEMOS AGREGAR UNA CONDICION AL INDICE

-- Include columns + Filtered index
CREATE NONCLUSTERED INDEX nci_GamePlayDemo_GameID
ON dbo.GamePlay_DEmo (GameID)
INCLUDE (payout, playerID)
WHERE (payout > 0)
with (drop_existing = ON);

-- Try BlackJack Consulta al indice filtrado
exec sproc_GetWinningHandsOfGame @GameID = 1;

-- Para cada operacion de insercion, borrado, actualizacion Se debe reconstruir el indice

-- ¿Cuando usar HEAP? - No se suelen usar, no deberiamos usarlos. Pero se suelen usar para Datawarehouses donde se hace mucho scan.
					 -- 