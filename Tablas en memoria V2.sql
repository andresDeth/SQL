
-- [1] Nivel de acceso filestream Opción de configuración del servidor
/*
-- [Característica FILESTREAM]
   FILESTREAM se introdujo en SQL Server 2008 para el almacenamiento y la administración de datos no estructurados. 
   La función FILESTREAM permite almacenar datos BLOB (por ejemplo: documentos word, archivos de imágenes, música y videos, etc.) 
   en el sistema de archivos NT y garantiza la coherencia transaccional entre los datos no estructurados almacenados en el sistema de archivos NT 
   y los datos estructurados almacenados en la tabla.

-- El almacenamiento FILESTREAM permite almacenar los datos binarios grandes (BLOBs), es decir, ficheros o documentos, fuera de la Base de Datos, 
   de forma transparente. De este modo, SQL Server podrá almacenar los datos BLOBs en un sistema de ficheros NTFS. 
   Esto permite un acceso más rápido a dicha información, y adicionalmente, permite poder liberar de carga de memoria a SQL Server, 
   ya que para el acceso a datos FILESTREAM podría no utilizarse el Buffer Pool.

-- [Cuándo usar FILESTREAM]
   En SQL Server, los BLOB pueden ser datos estándar varbinary (max) que almacenan los datos en tablas o objetos varbinary (max) de FILESTREAM 
   que almacenan los datos en el sistema de archivos. El tamaño y el uso de los datos determinan si debe usar el almacenamiento de la base de datos 
   o el almacenamiento del sistema de archivos. Si las siguientes condiciones son verdaderas, debería considerar usar FILESTREAM:

     - Los objetos que se almacenan tienen, en promedio, más de 1 MB.
     - El acceso rápido a la lectura es importante.
     - Está desarrollando aplicaciones que usan un nivel medio (middle tier) para la lógica de la aplicación.
     - Para objetos más pequeños, el almacenamiento de BLOB varbinary (max) en la base de datos a menudo proporciona un mejor rendimiento de transmisión.
*/
-------------------------------------------------------------------------------------
-- Valor  |  Definición
-------------------------------------------------------------------------------------
--   0	  |  Deshabilita el soporte de FILESTREAM para esta instancia.
--   1	  |  Habilita FILESTREAM para el acceso a Transact-SQL.
--   2	  |  Habilita FILESTREAM para acceso de transmisión de Transact-SQL y Win32.

  EXEC sys.sp_configure N'filestream access level', N'1'
  GO
  RECONFIGURE WITH OVERRIDE
  GO

-- [2] CREACIÓN DE LA BASE DE DATOS CON UN FILEGROUP OPTIMIZADO PARA DATOS EN MEMORIA
/* Para crear tablas optimizadas para memoria, primero debe crear un grupo de archivos FILEGROUP optimizado para la memoria MEMORY_OPTIMIZED_DATA. 
   El grupo de archivos optimizado para memoria contiene uno o más contenedores. 
   Cada contenedor contiene archivos de datos o archivos delta o ambos. 
*/
   CREATE DATABASE InMemoryExampleDB
   ON
   PRIMARY(NAME=N'InMemoryExample_dataDB',
   FILENAME = N'/var/opt/mssql/data/InMemoryExample_dataDB.mdf', size=128MB),
              FILEGROUP[InMemoryExample_mod_fg1] CONTAINS MEMORY_OPTIMIZED_DATA
              (NAME= [InMemoryExample_mod_dir1],
   FILENAME = N'/var/opt/mssql/data/InMemoryExample_mod_dir1'),
   (NAME= [InMemoryExample_mod_dir2],
   FILENAME=N'/var/opt/mssql/data/InMemoryExample_mod_dir2')
   LOG ON(name = [InMemoryExample_log1],
   FILENAME=N'/var/opt/mssql/data/InMemoryExample.ldf', size=64MB)
   GO

-- [3] TRANSACTION ISOLATION LEVEL 
/* Controla el comportamiento de bloqueo y control de versiones de filas de las instrucciones de Transact-SQL emitidas por una conexión a SQL Server. 
   
   SET TRANSACTION ISOLATION LEVEL
     { READ UNCOMMITTED --> PREDETERMINADO
     | READ COMMITTED
     | REPEATABLE READ
     | SNAPSHOT
     | SERIALIZABLE
     }
   
   -- Entendiendo Snapshot Isolation and Row Versioning

   Una vez que se habilita el aislamiento de instantáneas, las versiones de filas actualizadas para cada transacción se mantienen en tempdb. 
   Un número de secuencia de transacción único identifica cada transacción, y estos números únicos se registran para cada versión de fila. 
   La transacción funciona con las versiones de fila más recientes que tienen un número de secuencia antes del número de secuencia de la transacción. 
   Las versiones más recientes creadas después de que la transacción ha comenzado son ignoradas por la transacción.

   El término "instantánea" refleja el hecho de que todas las consultas en la transacción ven la misma versión, o instantánea, de la base de datos, 
   en función del estado de la base de datos en el momento en que comienza la transacción. No se adquieren bloqueos en las filas de datos o páginas 
   de datos subyacentes en una transacción de instantánea, 
   lo que permite que se ejecuten otras transacciones sin ser bloqueadas por una transacción incompleta anterior. 

   [Las transacciones que modifican datos no bloquean las transacciones que leen datos] y [las transacciones que leen datos no bloquean las transacciones que escriben datos], 
   como lo harían normalmente con el nivel de aislamiento READ COMMITTED predeterminado en SQL Server.

   El aislamiento de instantáneas debe habilitarse estableciendo la opción de base de datos ALLOW_SNAPSHOT_ISOLATION ON antes de que se use en las transacciones. 
   Esto activa el mecanismo para almacenar las versiones de fila en la base de datos temporal ( tempdb ).
*/
   ALTER DATABASE InMemoryExample1
   SET ALLOW_SNAPSHOT_ISOLATION ON;
   GO
 
 /*
   -- [Como funcionan el aislamiento de instantaneas y el control de filas]
   
   Cuando el nivel de aislamiento SNAPSHOT está habilitado, cada vez que se actualiza una fila, el Motor de base de datos de SQL Server 
   almacena una copia de la fila original en tempdb y agrega un número de secuencia de transacción a la fila.

   La siguiente es la secuencia de eventos que ocurre:

   1. Se inicia una nueva transacción y se le asigna un número de secuencia de transacción.

   2. El Motor de base de datos lee una fila dentro de la transacción y recupera la versión de fila de tempdb cuyo número de secuencia es más cercano o menor 
      que el número de secuencia de transacción.

   3. El Motor de base de datos comprueba si el número de secuencia de transacción no está en la lista de números de secuencia de transacción de las transacciones
      no confirmadas activas cuando se inició la transacción de instantánea.

   4. La transacción lee la versión de la fila de tempdb que estaba vigente desde el inicio de la transacción. 
      No verá nuevas filas insertadas después de que se inició la transacción porque esos valores de número de secuencia serán más altos 
	  que el valor del número de secuencia de transacción.

   5. La transacción actual verá las filas que se eliminaron después de que comenzó la transacción, porque habrá una versión de fila en tempdb 
      con un valor de número de secuencia más bajo.

    *** IMPORTANTE
	Si usa [ALLOW_SNAPSHOT_ISOLATION] asegúrese de utilizar [SET TRANSACTION ISOLATION LEVEL SNAPSHOT] en su código, de lo contrario no obtendrá ninguno de los beneficios.
*/

-- [4] Cuando configure una base de datos para tablas optimizadas para la memoria en SQL Server 2014, 
--     se recomienda habilitar la configuración SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT:
   ALTER DATABASE InMemoryExample1
   SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT ON;
   GO

/* [5] Un modelo de recuperación es una propiedad de base de datos que controla cómo se registran las transacciones, 
       si el registro de transacciones requiere (y permite) hacer una copia de seguridad, y qué tipos de operaciones de restauración están disponibles. 
	   Existen tres modelos de recuperación: 

	   1. Simple, 
	   2. Completa y 
	   3. Registrada en bloque. 
	   
	   * Normalmente, una base de datos usa el modelo de recuperación completo o el modelo de recuperación simple.
	   
	   Las operaciones de copia de seguridad y restauración de SQL Server ocurren dentro del contexto del modelo de recuperación de la base de datos.
	   https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server?view=sql-server-2017  

	   * MODELO DE RECUPERACIÓN SIMPLE
		 El modelo simple no permite las copias de seguridad del registro de transacciones. Como resultado, 
		 [NO PUEDE RESTAURAR una base de datos a un punto en el tiempo]. Su base de datos es vulnerable a la pérdida de datos cuando usa este modelo. 
		 Dicho esto, usar este modelo facilita la tarea de administración porque SQL Server recuperará espacio automáticamente del registro de transacciones.

		 Con este modelo de recuperación tiene la capacidad de hacer copias de seguridad completas (una copia completa) o copias de seguridad diferenciales
		 (cualquier cambio desde la última copia de seguridad completa). Con este modelo de recuperación, usted está expuesto a cualquier falla desde la última
		 copia de seguridad completada.  

		 - Estas son algunas razones por las que puede elegir este modelo de recuperación:

			1. Sus datos no son críticos y pueden recrearse fácilmente
			2. La base de datos solo se usa para prueba o desarrollo
			3. Los datos son estáticos y no cambian
			4. Perder una o todas las transacciones desde la última copia de seguridad no es un problema
			5. Los datos se derivan y se pueden recrear fácilmente

	  * MODELO DE RECUPERACIÓN COMPLETA
         Con el modelo completo, la pérdida de datos es mínima cuando se realiza una copia de seguridad periódica del registro de transacciones. 
		 Todas las transacciones se registran por completo en el registro de transacciones, y el registro de transacciones continuará creciendo hasta
		 que se haga una copia de seguridad.  Si bien este modelo agrega una sobrecarga administrativa, sus datos están protegidos contra la pérdida de datos.

	  * MODELOS DE RECUPERACIÓN REGISTRO MASIVO (Bulk Logged)
		 Cuando utiliza el modelo de registro masivo, las operaciones masivas se registran mínimamente, lo que reduce el tamaño del registro de transacciones.  
		 Tenga en cuenta que esto no elimina la necesidad de hacer una copia de seguridad del registro de transacciones.  
		 A diferencia del modelo de recuperación completa, en el modelo de registro masivo puede restaurar solo hasta el final de cualquier copia de seguridad; 
		 no puedes restaurar en algún punto en el tiempo.
*/
    ALTER DATABASE InMemoryExample1 SET RECOVERY SIMPLE WITH NO_WAIT
	GO	

/* [6] Listamos los Procedimientos Almacenados Compilados Nativamente */
    SELECT name, 
		   description, *
	FROM sys.dm_os_loaded_modules
	WHERE description = 'XTP Native DLL'
	
/* [7] CREACIÓN DE LA TABLA EN MEMORIA 
       Un valor incorrecto de BUCKET_COUNT, especialmente si es demasiado bajo, puede afectar significativamente el rendimiento
	   de la carga de trabajo, así como afectar el tiempo de recuperación de la base de datos. Es mejor sobrestimar el número de depósitos.

	   - INDICES, INDICES HASH

	   * Los índices con optimización para memoria deben crearse con CREATE TABLE (Transact-SQL). Los índices basados en disco se pueden crear con CREATE TABLE y CREATE INDEX.
	   * Los índices con optimización para memoria no se escriben ni se leen del disco.

	   - Hay dos tipos de índices con optimización para memoria:

		 1. Los índices de hash no clúster, que son convenientes para las búsquedas de puntos. Para obtener más información sobre los índices hash, vea Índices hash.
         2. Los índices no clúster, que son para exámenes de intervalo y exámenes ordenados.
	   
	   * Los índices con optimización para memoria no se escriben ni se leen del disco

	   Los índices con optimización para memoria solo existen en la memoria. Las estructuras de índice no permanecen en el disco y las operaciones
	   de índice no se graban en el registro de transacciones. Se crea la estructura de índice cuando la tabla con optimización para memoria se crea
	   en la memoria, durante la operación CREATE TABLE y durante el inicio de la base de datos.

	   Las claves de índice duplicadas pueden reducir el rendimiento con un índice hash porque a las claves se les aplica el 
	   algoritmo hash en el mismo cubo, por lo que la cadena del cubo aumenta.

	   * Indices HASH - Utiliza distribución poison
	   https://msdn.microsoft.com/es-co/library/dn133190(v=sql.120).aspx
	   * Directrices para usar índices en las tablas con optimización para memoria
	   https://msdn.microsoft.com/es-co/library/dn133166(v=sql.120).aspx
*/
   CREATE TABLE T1
   (
     [Name] VARCHAR(32) NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT=100000),
     [City] VARCHAR(32) NOT NULL,
     [State_Province] VARCHAR(32) NOT NULL,
     [LastModified] DATETIME NOT NULL,
  
     INDEX T1_ndx_c2c3 NONCLUSTERED([City],[State_Province])
   ) WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA)
   GO


/* [8] Consultamos el contenido de la tabla y los datos de la base de datos creada */
   SELECT * FROM T1;
   SELECT * FROM sys.databases;

/* [9] PRUEBA DE CREACIÓN DE UN PROCEDIMIENTO ALMACENADO NATIVO 
   
   * SQL Server puede compilar de forma nativa procedimientos almacenados que acceden a tablas optimizadas para la memoria. 

   SQL Server también puede compilar de forma nativa tablas optimizadas para memoria. La compilación nativa permite un acceso de datos más rápido 
   y una ejecución de consultas más eficiente que Transact-SQL interpretado (tradicional). 
   [La compilación nativa de tablas y procedimientos almacenados producen archivos DLL].

   La compilación nativa se refiere al proceso de conversión de construcciones de programación a código nativo, que consiste en 
   instrucciones del procesador sin la necesidad de una compilación o interpretación adicional.

   OLTP en memoria compila tablas optimizadas para la memoria cuando se crean y compila de forma nativa procedimientos
   almacenados cuando se cargan en archivos DLL nativos. 

   * Los archivos DLL se vuelven a compilar después de reiniciar una base de datos o un servidor. 
   * La información necesaria para recrear los archivos DLL se almacena en los metadatos de la base de datos. 
   * Los archivos DLL no son parte de la base de datos, aunque están asociados con la base de datos. Por ejemplo, 
     los archivos DLL NO ESTÁN INCLUIDOS en las copias de seguridad de la base de datos.

   BEGIN ATOMIC
   -------------
   Solo se admite para procedimientos compilados de forma nativa y como un punto de rescate dentro de la transacción
   
   * Cada procedimiento almacenado nativamente compilado contiene exactamente un bloque de instrucciones de Transact-SQL. Este es un bloque ATOMICO.

   * Los procedimientos almacenados de Transact-SQL NO NATIVOS e INTERPRETADOS y los lotes ad hoc NO ADMITEN bloques atómicos.

     Los bloques atómicos se ejecutan (atómicamente) dentro de la transacción. 
   * O bien todas las instrucciones en el bloque tienen éxito o todo el bloque se retrotraerá al punto de rescate que se creó al inicio del bloque. 

   * Native Compilation of Tables and Stored Procedures
   https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/native-compilation-of-tables-and-stored-procedures?view=sql-server-2017
   * Bloques atomicos en procedimientos nativos
   https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/atomic-blocks-in-native-procedures?view=sql-server-2017
*/
    CREATE PROCEDURE dbo.p1	
	WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
	AS
		BEGIN ATOMIC
			WITH (TRANSACTION ISOLATION LEVEL = snapshot, LANGUAGE = N'us_english')
			DECLARE @name VARCHAR(32) = 'Mustaine'
			DECLARE @i INT =0
				WHILE @i <100
				BEGIN
					SET @name = 'Mustaine' + '_'+ CAST(@i AS VARCHAR);
					INSERT dbo.T1
					VALUES(@name, @name,@name)
					SET @i = @i - 1
				END
		END

		INSERT INTO T1
		VALUES ('Da vinci','Vinci','FL');

		INSERT INTO T1
		VALUES ('Botticelli','Florence','FL');

		SELECT *
		FROM T1
		WHERE Name = 'Da Vinci'
		----------------------------------------
		SELECT name, 
		description, *
	    FROM sys.dm_os_loaded_modules
	    WHERE description = 'XTP Native DLL'
		----------------------------------------
		select * from sys.tables;

/* [10] PRUEBA DE CREACIÓN DE UN PROCEDIMIENTO ALMACENADO NATIVO CON TABLA EN MEMORIA 

   - SCHEMA_AND_DATA (predeterminado) 
   Esta opción proporciona durabilidad tanto de esquema como de datos. El nivel de durabilidad de los datos depende de si realiza
   una transacción como totalmente duradera o con una durabilidad retrasada. 
   
   * Las transacciones totalmente duraderas proporcionan la misma 
   garantía de durabilidad para datos y esquemas, similar a una tabla basada en disco. 
   
   * La durabilidad retrasada mejorará el rendimiento, pero puede ocasionar la pérdida de datos en caso de que el servidor falle.

   - SCHEMA_ONLY 
   Esta opción garantiza la durabilidad del esquema de la tabla. Cuando se reinicia SQL Server,
   el esquema de la tabla persiste, pero los datos en la tabla se pierden. 
   (Esto es diferente de una tabla en tempdb, donde tanto la tabla como sus datos se pierden al reiniciarse). 
   
   * Un escenario típico para crear una tabla no duradera es almacenar datos transitorios, como una tabla de etapas para un proceso ETL. 
     Una durabilidad SCHEMA_ONLY evita tanto el registro de transacciones como el punto de control, lo que puede reducir significativamente las operaciones de E / S.

   --> Controlar la durabilidad de la transacción

   * Las confirmaciones de transacción de SQL Server pueden ser totalmente duraderas, la predeterminada de SQL Server o duradera con retraso 
     (también conocida como commit diferido).

   * Las confirmaciones de transacciones totalmente duraderas son síncronas e informan que una confirmación es exitosa y devuelven el control 
     al cliente solo después de que los registros de la transacción se escriben en el disco. 
	 
   --> Las confirmaciones de transacciones duraderas diferidas son asíncronas e informan que una confirmación ha sido exitosa 
       antes de que los registros de la transacción se escriban en el disco. Es necesario escribir las entradas del registro de
	   transacciones en el disco para que una transacción sea duradera. Las transacciones diferidas duraderas se vuelven duraderas 
	   cuando las entradas del registro de transacciones se vacían en el disco.

   * Controlar la durabilidad de la transacción
   https://docs.microsoft.com/en-us/sql/relational-databases/logs/control-transaction-durability?view=sql-server-2017

   * Definición de durabilidad para objetos optimizados para memoria
   https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/defining-durability-for-memory-optimized-objects?view=sql-server-2017
*/
/* [11] CREACIÓN DE TABLA EN MEMORIA */
CREATE TABLE bigtable_inmem(
	 Id UNIQUEIDENTIFIER NOT NULL
	 CONSTRAINT pk_biggerbigtable_inmem PRIMARY KEY NONCLUSTERED
     HASH WITH(BUCKET_COUNT = 2097152), 
 
     account_id INT NOT NULL,
     trans_type_id SMALLINT NOT NULL,
     shop_id INT NOT NULL,
     trans_made DATETIME NOT NULL,
     trans_amount DECIMAL(20,2) NOT NULL,
     entry_date DATETIME2 NOT NULL DEFAULT(current_timestamp),
 
	 INDEX hash_trans_type NONCLUSTERED HASH
			(shop_id, trans_type_id, trans_made)
			WITH(bucket_count = 2097152),
	 INDEX hash_trans_made NONCLUSTERED HASH
			(trans_made, shop_id, account_id)
			WITH(BUCKET_COUNT = 2097152))
			WITH(MEMORY_OPTIMIZED = ON, DURABILITY=SCHEMA_ONLY);
	 GO

/* [12] CREACIÓN DE TABLA COMÚN EN DISCO */
CREATE TABLE bigtable_tsql(
	Id UNIQUEIDENTIFIER NOT NULL
	CONSTRAINT pk_biggerbigtable_tsql PRIMARY KEY NONCLUSTERED,
	account_id INT NOT NULL,
	trans_type_id SMALLINT NOT NULL,
	shop_id INT NOT NULL,
	trans_made DATETIME NOT NULL,
	trans_amount DECIMAL(20,2) NOT NULL,
	entry_date DATETIME2 NOT NULL DEFAULT(current_timestamp),

	INDEX IX_trans_type NONCLUSTERED (shop_id, trans_type_id, trans_made),
	INDEX IX_trans_made NONCLUSTERED (trans_made, shop_id, account_id)
) 

/* [13] CREACIÓN DE PROCEDIMIENTO NORMAL - SIN COMPILACIÓN NATIVA ACCEDIENDO A TABLA TRADICIONAL EN DISCO */
   CREATE PROC ins_bigtable_tsql (@rows_to_INSERT int)
   AS
      BEGIN
	  SET NOCOUNT ON;

	  DECLARE @i INT = 1;
	  DECLARE @newid UNIQUEIDENTIFIER -- Es un GUID de 16 bytes
		WHILE @i <= @rows_to_INSERT
		BEGIN 
			SET @newid = NEWID()
			INSERT dbo.bigtable_tsql(id, account_id,trans_type_id,
								 shop_id,trans_made,trans_amount)
			VALUES(@newid,
					32767 * RAND(),
					30* RAND(),
					100 * RAND(),
					GETDATE(),
					(32767 * RAND())/100);

			SET @i = @i +1;
		END
   END

/* [14] CREACIÓN DE PROCEDIMIENTO INTEROP --> PROCEDIMIENTO SIN COMPILACIÓN NATIVA ACCEDIENDO A TABLA EN MEMORIA */
	CREATE PROC ins_bigtable (@rows_to_INSERT int)
	AS
	BEGIN
		SET nocount on;

		DECLARE @i INT = 1;
		DECLARE @newid UNIQUEIDENTIFIER
		WHILE @i <= @rows_to_INSERT
		BEGIN 
			SET @newid = NEWID()
			INSERT dbo.bigtable_inmem(id, account_id,trans_type_id,
				   					  shop_id,trans_made,trans_amount)
			VALUES(@newid,
					32767 * RAND(),
					30* RAND(),
					100 * RAND(),
					GETDATE(),
					(32767 * RAND())/100);

			SET @i = @i +1;
		END
	END

/* [15] CREACIÓN DE PROCEDIMIENTO NATIVO --> ACCEDIENDO A TABLA EN MEMORIA !!! EL MÁS RÁPIDO !!! */
	CREATE PROC ins_native_bigtable (@rows_to_INSERT int)
		   WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
	AS
		BEGIN ATOMIC WITH
			(TRANSACTION ISOLATION LEVEL =SNAPSHOT,
			 LANGUAGE = N'us_english')
			 DECLARE @i INT = 1;
			 DECLARE @newid UNIQUEIDENTIFIER
	
			WHILE @i <= @rows_to_INSERT
			BEGIN 
				SET @newid = NEWID()
				INSERT dbo.bigtable_inmem(id, account_id,trans_type_id,
			   						  shop_id,trans_made,trans_amount)
				VALUES(@newid,
					   32767 * RAND(),
					   30* RAND(),
					   100 * RAND(),
					   GETDATE(),
   					   (32767 * RAND())/100);

				SET @i = @i +1;
			END
		END
	GO

/* [15] PRUEBAS DE INSERCIÓN */

-- Modo tradicional - Inserta en una tabla normal  - Esperamos hasta 1 min despues detenemos el procedimiento
   EXEC ins_bigtable_tsql @rows_to_INSERT = 200000;

-- Modo Interop - Inserta a una tabla en memoria desde un procedimiento normal -- 200mil registros insertados en 8 segundos
   EXEC ins_bigtable @rows_to_INSERT = 200000;

-- Modo Nativo - Inserta a una tabla en memoria desde un procedimiento NATIVO - 300mil registros en cero segundos
   EXEC ins_native_bigtable @rows_to_INSERT = 3000000; -- Con 10millones la memoria ram de 5GB no alcanza

/* [16] CONSULTAMOS TABLA TRADICIONAL EN DISCO */
    SELECT * FROM bigtable_tsql; 

/* [17] CONSULTAMOS TABLA EN MEMORIA */
	SELECT * FROM bigtable_inmem; 

/* [18] CONTEO DE FILAS EN TABLA EN MEMORIA */
	select count(*) from bigtable_inmem;  -- 13.111.000   - 7.000.000

/* [19] ELIMINA TODOS LOS DATOS DE LAS TABLAS */
   DELETE FROM bigtable_inmem;
   DELETE FROM bigtable_tsql

/* [20] CONSULTAMOS ESTRUCTURAS DE LAS TABLAS */
   SELECT * FROM sys.tables;

-----------------------------------------------------
-- COLUMN STORE
-----------------------------------------------------

--CREATE TABLE dbo.charge_cs
--(
-- [charge_no] int IDENTITY(1,1) NOT NULL,
-- member_no int not null,
-- provider_no int not null,
-- category_no int not null,
-- charge_dt datetime not null,
-- charge_amt money not null,
-- statement_no int not null,
-- charge_code int not null
--) on [PRIMARY]

--SET IDENTITY_INSERT dbo.charge_cs ON
--GO
 
--INSERT INTO dbo.charge_cs(
--    charge_no,
--	member_no,
--	provider_no,
--	category_no,
--	charge_dt,
--	charge_amt,
--	statement_no,
--	charge_code
--)
--VALUES(1,2,3,4,GETDATE(),4.5,3,4);
--GO 1600000


--CREATE NONCLUSTERED COLUMNSTORE INDEX IX_C_Column_Charge_cs ON charge_cs(
--  member_no,
--  provider_no,
--  category_no,
--  charge_dt,
--  charge_amt,
--  statement_no,
--  charge_code
--)
--GO

--select member_no,
--  provider_no,
--  category_no,
--  charge_dt,
--  charge_amt,
--  statement_no,
--  charge_code
--  from charge_cs where charge_no = 1;

---- CONSULTA COMPLEJA

--select l3.shop_id, avg(l3.trans_amount) as promedio
--from bigtable_inmem l3
--join bigtable_inmem on l3.account_id = bigtable_inmem.trans_type_id
--group by l3.shop_id
--order by promedio;

-----------------------------------------------------------------------------------------------------------------
---- Con el indice columnar [16 segundos] devuelve 100 registros - en un dataset de 3 millones - 5GB RAM, 3 CPUS

---- Sin el indice columnar [1:38minutos] devuelve 100 registros - en un dataset de 3 millones - 5GB RAM, 3 CPUS

-----------------------------------------------------------------------------------------------------------------
---- Con el indice columnar [28 segundos] devuelve 100 registros - en un dataset de 7 millones - 8GB RAM, 4 CPUS

---- Sin el indice columnar [5:05minutos] devuelve 100 registros - en un dataset de 7 millones - 8GB RAM, 4 CPUS
-----------------------------------------------------------------------------------------------------------------

---- Con el indice columnar [5 segundos] devuelve 100 registros - en un dataset de 3 millones - 8GB RAM, 4 CPUS

---- Sin el indice columnar [55 segundos] devuelve 100 registros - en un dataset de 3 millones - 5GB RAM, 3 CPUS

---- SI ES MEJOR TENER SOLO EL INDICE COLUMNAR SIN MAS INDICES ADICIONALES

-------------------------------------------------------------------------------------------------------------------

--select * from bigtable_inmem;-- 59 Segundos para 6 millones de registros
--select id, account_id, trans_type_id, shop_id, trans_made, trans_amount, entry_date from bigtable_inmem; -- 57 segundos, 6 millones de registros


--drop table dbo.bigtable_inmem;
--drop procedure ins_native_bigtable; 

--CREATE PROC ins_native_bigtable (@rows_to_INSERT int)
--	   with native_compilation, schemabinding, execute as owner
--AS
--BEGIN ATOMIC WITH
--(TRANSACTION ISOLATION LEVEL =SNAPSHOT,
--LANGUAGE = N'us_english')
--DECLARE @i int = 1;
--DECLARE @newid uniqueidentifier
--	WHILE @i <= @rows_to_INSERT
--	BEGIN 
--		SET @newid = NEWID()
--		INSERT dbo.bigtable_inmem(id, account_id,trans_type_id,
--								shop_id,trans_made,trans_amount)
--		VALUES(@newid,
--				32767 * rand(),
--				30* rand(),
--				100 * rand(),
--				getdate(),
--				(32767 * rand())/100);

--		SET @i = @i +1;
--	END
--END
--GO

--CREATE TABLE bigtable_inmem(
-- id uniqueidentifier not null
-- hash with(bucket_count=2097152), 
 
-- account_id int not null,
-- trans_type_id smallint not null,
-- shop_id int not null,
-- trans_made datetime not null,
-- trans_amount decimal(20,2) not null,
-- entry_date datetime2 not null default (current_timestamp),
-- INDEX t_account_cci CLUSTERED COLUMNSTORE
-- --index hash_trans_type nonclustered hash
-- --		(shop_id, trans_type_id, trans_made)
-- --		with(bucket_count = 2097152),
-- --index hash_trans_made nonclustered hash
-- 	--	(trans_made, shop_id, account_id)
-- 	--	with(bucket_count = 2097152))
--		 )WITH(MEMORY_OPTIMIZED = ON);


--CREATE TABLE dbo.bigtable_inmem(
--   OnlineSalesKey int NOT NULL PRIMARY KEY NONCLUSTERED,
--   DateKey datetime NOT NULL,
--   StoreKey int NOT NULL,
--   ProductKey int NOT NULL,
--   PromotionKey int NOT NULL,
--   CurrencyKey int NOT NULL,
--   CustomerKey int NOT NULL,
--   SalesOrderNumber nvarchar(20) NOT NULL,
--   SalesOrderLineNumber int NULL,
--   SalesQuantity int NOT NULL,
--   SalesAmount money NOT NULL,
--   ReturnQuantity int NOT NULL,
--   ReturnAmount money NULL,
--   DiscountQuantity int NULL,
--   DiscountAmount money NULL,
--   TotalCost money NULL,
--   UnitCost money NULL,
--   UnitPrice money NULL,
--   ETLLoadID int NULL,
--   LoadDate datetime NULL,
--   UpdateDate datetime NULL,
--   INDEX t_account_cci CLUSTERED COLUMNSTORE -- Indice columnar
--   ) WITH(MEMORY_OPTIMIZED = ON)
