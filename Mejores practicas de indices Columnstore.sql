    -- Demo #1: Cargar un non-clustered Columnstore de forma óptima.
	USE [AdventureWorks2016CTP3]
	GO

    -- [1] Función de partición --- Divide los registros por año
	   CREATE PARTITION FUNCTION [dateFunction](datetime)
	   AS RANGE RIGHT FOR VALUES (N'2005-01-01T00:00:00', N'2006-01-01T00:00:00', N'2007-01-01T00:00:00',
	   N'2008-01-01T00:00:00', N'2009-01-01T00:00:00', N'2010-01-01T00:00:00', N'2011-01-01T00:00:00')

	-- [2] dbo.BIGTRANSACTIONHISTORY - Tiene 33 millones de registros
	-- Por objetivos del demo se colocan todos en el primario, pero deberia ser un filegroup por particion
	-- en un ambiente productivo
	   CREATE PARTITION SCHEME [trxScheme] AS PARTITION [dateFunction] TO
   ([PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY])

	-- [3] SE CREA UN CLUSTER INDEX B-TREE NORMAL, Se puede dejar de solo lectura con nonclustered
	   CREATE CLUSTERED INDEX [ClusteredIndex_on_trxScheme] ON [dbo].[bigTransactionHistory](
		  [TransactionDate]
		) WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [trxScheme]([TransactionDate])

	-- [4] CREACIÓN DE NONCLUSTERED COLUMNSTORE Version 2012
	-- * Se considera una buena practica agregar todas las columnas a un indice columnStore
	-- * Se recomienda usar indices ColumnStore con tablas particionadas. NUNCA directamente sobre tablas gigantes,
	--	 ya que la (inserción/carga de datos) se vuelve un problema.
	-- * En SQL Server 2012 como no contamos con inserción sobre el indice, ya que es de solo lectura, tendriamos que:
	--   1. Desactivar el indice ColumnStore
	--	 2. Cargar los datos
	--	 3. Reconstruir el indice (esto ultimo sin particionamiento es muy demorado, horas y horas)

	-- [5] Con particionamiento podriamos hacer el mantenimiento del columnStore a nivel de la partición
	--     cuando se necesite mantenimiento se puede hacer solo en la particion deseada y no en toda la tabla gigante
	CREATE COLUMNSTORE INDEX nonClust_Columnstore_Trx ON
	bigTransactionHistory([TransactionID], [ProductID], [TransactionDate], [Quantity], [ActualCost])
	ON trxScheme(TransactionDate);

	-- [7] Consultamos los indices sobre la tabla dbo.bigTransactionHistory
	SELECT i.object_id, object_name(i.object_id) as TableName,
		   i.name as IndexName, i.index_id, i.type_desc,
		   CSRowGroups.*,
		   100*(total_rows - ISNULL(deleted_rows,0))/ total_rows as PercentFull
	FROM sys.indexes AS i
	JOIN sys.column_store_row_groups AS CSRowGroups
		 ON  i.object_id = CSRowGroups.object_id
		 AND i.index_id = CSRowGroups.index_id
	WHERE object_name(i.object_id) = 'bigTransactionHistory'
	ORDER BY i.index_id, partition_number

	-- [8] [CREACIÓN DE TABLA STAGING] con el mismo esquema de la tabla original, 
	-- tiene el mismo clustered index y columnStore index, la unica diferencia es que esta VACIA
	-- NOTA: AMBAS TABLAS DEBEN TENER LOS MISMO TIPOS DE DATOS Y CANTIDAD DE COLUMNAS
	CREATE TABLE [dbo].[bigTransactionHistoryStaging]
	(
	  [TransactionID] [bigint] NULL,
	  [ProductID] [int] NULL,
	  [TransactionDate] [datetime] NULL,
	  [Quantity] [int] NULL,
	  [ActualCost] [money] NULL
	)
	CREATE CLUSTERED INDEX [ClusteredIndex_on_trxStagingScheme] ON [dbo].[bigTransactionHistoryStaging]
	(
	  [TransactionDate]
	) WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF) ON [trxScheme]([TransactionDate])
	CREATE COLUMNSTORE INDEX nonClust_Columnstore_TrxStaging ON
	bigTransactionHistoryStaging([TransactionID], [ProductID], [TransactionDate], [Quantity], [ActualCost])
	ON trxScheme(TransactionDate);
	GO

	-- [9] CONSULTA DE LAS PARTICIONES DE LA TABLA dbo.bigTransationHistory y bigTransactionHistoryStaging
	-- Aca se puede ver que cuentan con el mismo esquema y lo que cambia es la cantidad de registros
	SELECT 
		t.name as TableName,
		ps.name as PartitionScheme,
		pf.name as PartitionFunction,
		p.partition_number,
		p.rows,
		case
			when pf.boundary_value_on_right = 1 then 'RIGHT'
			else 'LEFT'
		end [range_type],
		prv.value [boundary]
	from sys.tables t
	join sys.indexes i on t.object_id = i.object_id
	join sys.partition_schemes ps on i.data_space_id = ps.data_space_id
	join sys.partition_functions pf on ps.function_id = pf.function_id
	join sys.partitions p on i.object_id = p.object_id and i.index_id = p.index_id
	join sys.partition_range_values prv on pf.function_id = prv.function_id and p.partition_number
	= prv.boundary_id
	where i.index_id < 2
	order by t.name, p.partition_number

	--[10] SE VERIFICA QUE LA [TABLA STAGING] ESTE VACIA
	SELECT * 
	FROM dbo.bigTransactionHistoryStaging;

	--[11] INSERCIÓN A LA TABLA CON UN INDICE COLUMNSTORE
	--     Si estuvieramos en SQL Server 2012, esta operación NO se podria ejecutar	
	--     por el indice ColumnStore
	INSERT INTO [dbo].[bigTransactionHistory]	
			([TransactionID],
			 [ProductID],
			 [TransactionDate],
			 [Quantity],
			 [ActualCost])
	SELECT top 100 * from bigTransactionHistory
	where datepart(yy, TransactionDate) = 2010;

	--[12] ¿QUÉ PODRIAMOS HACER PARA INSERTAR ESTOS REGISTROS?
	--     Como tenemos particiones podemos hacer un Switch Out y pasar una particion a la tabla Stagin
	--     Switch out
	--     NOTA: AMBAS TABLAS DEBEN TENER LOS MISMO TIPOS DE DATOS, NULLABLE, CANTIDAD Y NOMBRES DE COLUMNAS
	ALTER TABLE dbo.bigTransactionHistory
	SWITCH PARTITION 7 TO bigTransactionHistoryStaging PARTITION 7;

	--[13] CONSULTAMOS DE NUEVO LAS PARTICIONES
	--     Aca observamos como se cambio el numero de registros de la tabla dbo.bigTransactionHistory
	--     a la tabla dbo.bigTransactionHistoryTwo
		SELECT 
			t.name as TableName,
			ps.name as PartitionScheme,
			pf.name as PartitionFunction,
			p.partition_number,
			p.rows,
			case
				when pf.boundary_value_on_right = 1 then 'RIGHT'
				else 'LEFT'
			end [range_type],
			prv.value [boundary]
		FROM sys.tables t
		join sys.indexes i on t.object_id = i.object_id
		join sys.partition_schemes ps on i.data_space_id = ps.data_space_id
		join sys.partition_functions pf on ps.function_id = pf.function_id
		join sys.partitions p on i.object_id = p.object_id and i.index_id = p.index_id
		join sys.partition_range_values prv on pf.function_id = prv.function_id and p.partition_number
		= prv.boundary_id
		WHERE i.index_id < 2
		ORDER BY t.name, p.partition_number

	--[14] VERIFICAMOS QUE EN STAGING EXISTE AHORA REGISTROS
	   SELECT * FROM [dbo].[bigTransactionHistoryStaging]
	   SELECT COUNT(*) FROM [dbo].[bigTransactionHistoryStaging]

	--[15] DESACTIVAMOS el ColumnStore de la tabla de Staging para insertar en Staging
	   ALTER INDEX nonClust_Columnstore_TrxStaging ON bigTransactionHistoryStaging DISABLE;

	--[16] AHORA SOY LIBRE DE INSERTAR EN LA TABLA STAGING
	   INSERT INTO [dbo].[bigTransactionHistoryStaging]
					([TransactionID],
					 [ProductID],
					 [TransactionDate],
					 [Quantity],
					 [ActualCost]) 
	   SELECT TOP 100 * FROM bigTransactionHistory
	   WHERE datepart(yy, TransactionDate) = 2010; -- Si yo inserto registros con fecha 2009, 2008,etc, no se va a guardar en la particion 7 sino en la 6, 5, respectivamente

	--[18] EJECUTAR EL SIGUIENTE QUERY EN SQLQUERY STRESS PARA PRUEBAS - [500 Iteraciones con 10 Threads] 
	--     Aca se puede ver que mientras se insertan datos a la tabla de Staging podemos hacer consultas 
	--     a la tabla Original dbo.BigTransactionHistory, utilizando el ColumnStore de la tabla original
	--     sin problemas.
	--     * EN BACKGROUND MIENTRAS TANTO ESTAMOS CARGANDO/INSERTANDO registros a la tabla de STAGING.
	   SELECT SUM(Quantity), 
	          AVG(ActualCost), 
			  MIN(Quantity), MAX(Quantity), COUNT(Quantity),
			  STDEV(Quantity), VAR(Quantity)
	   FROM dbo.bigTransactionHistory
	   WHERE TransactionDate BETWEEN '2005-01-01T00:00:00'
							 AND     '2005-06-01T00:00:00'

    --[19] CONSULTAMOS DE NUEVO EL NUMERO DE REGISTROS Y NOS DAMOS CUENTA QUE AHORA TENEMOS REGISTROS EN LA TABLA
	--     DE STAGING 
		SELECT 
			t.name as TableName,
			ps.name as PartitionScheme,
			pf.name as PartitionFunction,
			p.partition_number,
			p.rows,
			case
				when pf.boundary_value_on_right = 1 then 'RIGHT'
				else 'LEFT'
			end [range_type],
			prv.value [boundary]
		FROM sys.tables t
		join sys.indexes i on t.object_id = i.object_id
		join sys.partition_schemes ps on i.data_space_id = ps.data_space_id
		join sys.partition_functions pf on ps.function_id = pf.function_id
		join sys.partitions p on i.object_id = p.object_id and i.index_id = p.index_id
		join sys.partition_range_values prv on pf.function_id = prv.function_id and p.partition_number
		= prv.boundary_id
		WHERE i.index_id < 2
		ORDER BY t.name, p.partition_number

	--[19] VERIFICAMOS QUE EN STAGING EXISTEn AHORA LOS REGISTROS INSERTADOS
	   SELECT * FROM [dbo].[bigTransactionHistoryStaging]
	   SELECT COUNT(*) FROM [dbo].[bigTransactionHistoryStaging]

	--[20] LUEGO DE INSERTAR, DEBO RECONSTRUIR EL INDICE COLUMNSTORE EN LA TABLA DE STAGING
	--     Aún reconstruyendo podemos seguir ejecutando el SQLQueryStreess sin problema,
	--     El unico problema en este punto seria que alguien consultara los datos de la particion que 
	--     pasamos a staging, en dicho caso saldrian datos vacios. Podriamos consultar datos del 2005, 2006, 2007 sin problema.  
	   ALTER INDEX nonClust_Columnstore_TrxStaging on bigTransactionHistoryStaging REBUILD;

	--[21] REFLEXIÓN: El proceso de inserción y reconstrucción del indice
	--		      si hablamos de billones de registros PUEDE TOMAR HORAS Y HORAS.
	--     Si fuera en una tabla sin particiones la productividad de la operacion se detendria completamente
	--     ESTARIAMOS SIRVIENDO LOS DATOS SIN EL INDICE COLUMNSTORE EN EL MEJOR DE LOS CASOS para el escenario que tuvieramos Staging
	--     En este caso usamos la particion y obviamente los datos se esa particion se verian afectados
	--     pero podriamos seguir trabajando

	--[22] FINALMENTE SWITCHEAMOS DE LA TABLA DE STAGING A LA TABLA ORIGINAL
	   ALTER TABLE bigTransactionHistoryStaging
	   SWITCH PARTITION 7 TO bigTransactionHistory PARTITION 7;
    
	--[23] CANCELAMOS EL SQLQUERYSTRESS

	--[24] CONSULTAMOS DE NUEVO LOS METADADOS Y VEMOS QUE LA PARTICION 7 NUEVAMENTE TIENE DATOS 
	SELECT 
		t.name as TableName,
		ps.name as PartitionScheme,
		pf.name as PartitionFunction,
		p.partition_number,
		p.rows,
		case
			when pf.boundary_value_on_right = 1 then 'RIGHT'
			else 'LEFT'
		end [range_type],
		prv.value [boundary]
	FROM sys.tables t
	join sys.indexes i on t.object_id = i.object_id
	join sys.partition_schemes ps on i.data_space_id = ps.data_space_id
	join sys.partition_functions pf on ps.function_id = pf.function_id
	join sys.partitions p on i.object_id = p.object_id and i.index_id = p.index_id
	join sys.partition_range_values prv on pf.function_id = prv.function_id and p.partition_number
	= prv.boundary_id
	WHERE i.index_id < 2
	ORDER BY t.name, p.partition_number

	--[25] CONSULTAMOS STAGING PARA OBSERVAR QUE NO TIENE REGISTROS
	SELECT * FROM [dbo].[bigTransactionHistoryStaging]

	-- REFLEXIÓN: 
	-- * USAR TABLAS DE STAGING PARA INSERCIONES PESADAS
	-- * USAR PARTICIONING PARA FACILITAR LA ADMINISTRACION PUESTO QUE PERMITE 
	--   CONVERTIR CADA COLUMNSTORE EN UNA UNIDAD MAS PEQUEÑA (Divide y venceras)
	-- * UTILIZAR TABLAS DE STAGING PARA MAXIMIZAR LA CANTIDAD DE TIEMPO QUE LOS DATOS VAN A ESTAR DISPONIBLES
	--   EL RESTO DE LA TABLA ESTARA DISPNIBLE PARA CONSULTAS Y LA RECONSTRUCCION SE REALIZARA 
	--   SOLO ESA PARTICION SIN AFECTAR EL RESTO DE PARTICIONES