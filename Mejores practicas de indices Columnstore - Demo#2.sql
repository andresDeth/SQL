 -- Demo #2: Cargar un clustered Columnstore sin caer en la Delta Store.
 -- Explicación sobre la carga de datos
	USE [AdventureWorks2016CTP3]
	GO 
	
	-- [1] SE CREA UN CLUSTERED COLUMNSTORE EN UNA COPIA DE LA TABLA dbo.bigTransactionHistory 
	CREATE CLUSTERED COLUMNSTORE INDEX clustCstoretrx ON bigTransactionHistoryTwo;
	
	-- [2] CONSULTAMOS LOS METADATOS DEL INDICE CLUSTER COLUMNSTORE, COMO ES CLUSTERED ESTAMOS EN SQL SERVER 2014 
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

    -- [3] CONSULTA ANALITICA de datos muy rápida, procesa 2 millones de registros, 
	-- agregar plan de ejecución, Excecution Plan es Batch Mode
	-- SIN INDICE COLUMNSTORE : 45 Segundos
	-- CON INDICE COLUMNSTORE :  4 Segundos
    SELECT SUM(Quantity) AS SUMATORIA, AVG(ActualCost) AS PROMEDIO, MIN(Quantity) AS MINIMO, MAX(Quantity) AS MAXIMO,
		   STDEV(Quantity) AS DESVIACION, VAR(Quantity) AS VARIANZA, ProductID
	FROM dbo.bigTransactionHistoryTwo
	WHERE TransactionDate BETWEEN '2005-01-01T00:00:00'
	   				      AND     '2010-06-01T00:00:00'
    GROUP BY ProductId
	ORDER BY ProductId DESC;

	-- PROCESO DE CARGA DE DATOS

	--[4] SE DESHABILITA EL TUPLE MOVER - PARA VER COMO SE COMPORTAN LOS DELTA STORES
	  dbcc traceon(634) -- NUNCA USARLO EN PRODUCCION

	--[5] INSERTAMOS 100.000 REGISTROS PARA VER COMO SE COMPORTA EL DELTA STORE
	--    RECORDAR QUE LOS DATOS QUE SON MENOS DE 102.400 NO SE VAN AL COLUMNSTORE DIRECTAMENTE SINO QUE SE VAN AL DELTA-STORE
	--    Y EL TUPLE-MOVER NO PROCESARA / MOVERA NADA A MENOS DE QUE YA ESTE LLENA LA TABLA AL MILLON DE REGISTROS
		INSERT INTO [dbo].[bigTransactionHistoryTwo]
		(
		  [TransactionID],
		  [ProductID],
		  [TransactionDate],
		  [Quantity],
		  [ActualCost]
		)
		SELECT TOP 100000 * FROM dbo.bigTransactionHistory
		WHERE DATEPART(yy, TransactionDate) = 2005 + CAST(RAND()*1000 as int) % 6;
		GO 11

	--[6] MIENTRAS INSERTA CONSULTAMOS COMO SE VA ACTUALIZANDO EL INDICE COLUMNSTORE
	--   PODEMOS OBSERVAR QUE TENEMOS PARTICIONES / ROWGROUP FILEGROUPS ABIERTOS CON UN DELTASTORE ACTIVO
	--   * ESTADOS:
	--     COMPRESSED
	--	   CLOSE, Se completo el numero de 1.048.576 Registros   
	--     OPEN
	--     TOMBSTONE, Requiere de un REBUILD el INDICE COLUMNSTORE
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

	-- [7] ¿QUE PASARIA SI SEGUIMOS INSERTANDO REGISTROS?
	--     Estos se almacenaran en el RowGroup DELTA-STORE OPEN hasta completar el 1.048.576
	--     * HASTA QUE NO LLEGUE A ESE MILLON DE REGISTROS NO SE VA A CERRAR
	--     MUEVE LOS CLOSED Rowgroups que esten CLOSE y los va a integrar en el COLUMNSTORE PARA DEJARLOS EN ESTADO COMPRESSED
		ALTER INDEX clustCstoretrx on bigTransactionHistoryTwo REORGANIZE; 

	-- [8] CONSULTAMOS DE NUEVO LOS METADATOS DEL INDICE COLUMNSTORE
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

	-- [9] AHORA INSERTAMOS EL NUMERO DE REGISTROS MINIMO INDICADO PARA QUE NO SE VAYAN AL DELTA-STORE SINO 
	--     DIRECTAMENTE AL COLUMNSTORE, DE ESTA FORMA NO DEPENDEMOS DEL TUPLE-MOVER
		INSERT INTO [dbo].[bigTransactionHistoryTwo]	
		(
		  [TransactionID],
		  [ProductID],
		  [TransactionDate],
		  [Quantity],
		  [ActualCost])
		  SELECT TOP 1048576 * FROM dbo.bigTransactionHistory
		  WHERE DATEPART(yy, TransactionDate) = 2005 + CAST(RAND()*1000 AS INT) % 6;

	-- [10] CONSULTAMOS DE NUEVO LOS METADATOS DEL INDICE COLUMNSTORE
	--      ACA PODEMOS OBSERVAR QUE EL ULTIMO ROWGROUPS NO PASO POR EL DELTA-STORE SINO QUE DIRECTAMENTE QUEDO COMPRESSED
	--      COMO EL TAMAÑO DEL INSERT ERA LO SUFICIENTEMENTE GRANDE LO COMPRIMIO SIN IR AL DELTA-STORE
	--      * ESTA ES UNA BUENA PRACTICA
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

   	-- [11] SI OBLIGATORIAMENTE NECESITAMOS INSERTAR UN NUMERO MENOR DE REGISTROS UTILIZAR EL REORGANIZE PARA NO DEPENDER
	--      DEL TUPLE-MOVER, mover los closed rowgroups
	--      ALTER INDEX clustCstoretrx on bigTransactionHistoryTwo REORGANIZE; 

	-- [12] Habilitar el tuple mover
	        dbcc traceoff(634)

  	-- [13] Ejemplo - NOS DICE CUANTOS REGISTROS DEBERIAMOS ACUMULAR para un total de registros
	--      ayudando al tupleMover a que se llene con mas de 1 millon,
	--      102.400 - Tamaño minimo con el que se construye un segmento
	--      1 millon es el tamaño optimo que deberiamos cargar
	   DECLARE @registrosPendientes int = 2252152;
	   SELECT @registrosPendientes % 1048576, -- Hace el modulo con el numero magico de registros a cargar
	   CASE when @registrosPendientes % 1048576 > 102400 THEN 'Cargar al Columstore'
	   ELSE 'Acumular registros'
	   END