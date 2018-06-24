USE CASINO;
GO

-- Check table type
    SELECT objs.name, ix.type_desc
	FROM sys.indexes as ix
	INNER JOIN sys.objects as objs
	ON objs.object_id = ix.object_id
	WHERE objs.name = 'GamePlay_Demo'

-- Enable IO STATS AND SHOW EXECUTION PLAN
   SET STATISTICS TIME ON
   SET STATISTICS IO ON

-- CHECK Players
   SELECT * FROM dbo.Player

-- Get all BlackJack games since Last Month
   SELECT PlayerID, payout, HandDate, GameName
   FROM dbo.GamePlay_Demo as gp
   INNER JOIN dbo.game as g
   ON g.gameID = gp.GameID
   WHERE g.GameName = 'BlackJack' AND gp.PlayerID = 1500

-- Create nonclustered index
   CREATE NONCLUSTERED INDEX nci_GamePlayDemo_PlayerID
   ON dbo.GamePlay_Demo (PlayerID)

-- Execute again
-- Get all BlackJack games sinc  Last Month -- Vemos que se ejecuta en el plan de ejecucion el nonclustered index por los datos de payout y HandDate
-- pero como he pedido mas datos como lo son el Gamename y el playerID se hace un LOOKUP al indice clustered de la tabla GAME
-- PARA COMPLETAR LA INFORMACION DE LA CONSULTA UTILIZA EL OPERADOR LOOKUP que lo que hace es hacer un HEAP e ir a la otra tabla 
-- a la pagina que corresponde.
   SELECT PlayerID, payout, HandDate, GameName
   FROM dbo.GamePlay_Demo as gp
   INNER JOIN dbo.game as g
   ON g.gameID = gp.GameID
   WHERE g.GameName = 'BlackJack' AND gp.PlayerID = 1500

-- Let's see what happends if the table is a Clustered index instead of a Heap
   CREATE CLUSTERED INDEX cix_GamePlay_demo_HandDate
   ON dbo.GamePlay_Demo (HandDate);

-- Execute again, ahora en lugar de usarme un RID Lookup me hace un KEY LOOKUP, se usa cuando nuestra tabla es un indice clustered
-- puesto que ahora hace la busqueda adicional por la llave, ademas reducimos el numero de lecturas logicas
   SELECT PlayerID, payout, HandDate, GameName
   FROM dbo.GamePlay_Demo as gp
   INNER JOIN dbo.game as g
   ON g.gameID = gp.GameID
   WHERE g.GameName = 'BlackJack' AND gp.PlayerID = 1500

-- Check nonclustered indexes in the table
SELECT 
	tbs.name as TableName,
	ixs.name as IndexName,
	ixs.type_desc as Index_Type,
	ps.rows as Index_Rows
FROM sys.tables as tbs
INNER JOIN sys.indexes as ixs
	ON ixs.object_id = tbs.object_id
INNER JOIN sys.partitions as ps	
	ON ps.object_id = tbs.object_id AND ps.index_id = ixs.index_id
WHERE ixs.index_id NOT IN (0,1) AND tbs.name = 'GamePlay_Demo'

-- Enable IO STATS AND SHOW EXECUTION PLAN
   SET STATISTICS TIME OFF
   SET STATISTICS IO OFF