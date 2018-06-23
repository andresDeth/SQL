-- Demo #3: Borrar datos en el Columnstore.
USE [AdventureWorks2016CTP3]
GO

--  [1] CONSULTAMOS LOS METADATOS ORIGINALES DEL COLUMNSTORE CON UN LLENADO PERCENTFULL AL 100%
	SELECT i.object_id, object_name(i.object_id) AS TableName,
		   i.name AS IndexName, i.index_id, i.type_desc,
		   CSRowGroups.*,
		   100*(total_rows - ISNULL(deleted_rows, 0))/total_rows AS PercentFull
	FROM sys.indexes AS i
	JOIN sys.column_store_row_groups AS CSRowGroups
		ON i.object_id = CSRowGroups.object_id
		AND i.index_id = CSRowGroups.index_id
	WHERE object_name(i.object_id) = 'bigTransactionHistoryTwo'
	ORDER BY object_name(i.object_id), i.name, row_group_id;

--  [2] BORRAMOS 2 MILLONES DE REGISTROS
	DELETE TOP(200000) FROM [dbo].[bigTransactionHistoryTwo]
	WHERE datepart(yy, TransactionDate) = 2005 + cast(rand()*1000 as int) % 6;
	GO 10

--  [3] ACA VEMOS COMO AFECTA LOS METADATOS DEL COLUMNSTORE 
--      PODEMOS VER PORCENTAJE DE LLENADO MENOR AL 100%
	SELECT i.object_id, object_name(i.object_id) AS TableName,
		   i.name AS IndexName, i.index_id, i.type_desc,
		   CSRowGroups.*,
		   100*(total_rows - ISNULL(deleted_rows, 0))/total_rows AS PercentFull
	FROM sys.indexes AS i
	JOIN sys.column_store_row_groups AS CSRowGroups
		ON i.object_id = CSRowGroups.object_id
		AND i.index_id = CSRowGroups.index_id
	WHERE object_name(i.object_id) = 'bigTransactionHistoryTwo'
	ORDER BY object_name(i.object_id), i.name, row_group_id;

--  [4] LA UNICA MANERA DE VOLVER A TENER UN LLENADO CON PORCENTAJE AL 100% ES CON UN REBUILD
--      EL REBUILD: ES UNA operacion es semi-online, podemos consultar datos PERO NO PODEMOS INSERTAR NUEVOS REGISTROS
--      LAS PERSONAS QUE CONSULTAN REPORTERIA PUEDEN SEGUIR CONSULTANDO REPORTES TRANQUILAMENTE
	    ALTER INDEX clustCstoretrx on bigTransactionHistoryTwo REBUILD;

--  NOTA: CUANDO EL PROMEDIO DEL PORCENTAJE DE LLENADO ES MENOR A 80% SE DEBE CONSIDERAR HACER UNA RECONSTRUCCION TOTAL DEL INDICE