EXEC sys.sp_configure N'filestream access level', N'1'
 GO
 RECONFIGURE WITH OVERRIDE
 GO

-- CREACIÓN DE LA BASE DE DATOS CON UN FILEGROUP OPTIMIZADO
-- PARA DATOS EN MEMORIA
CREATE DATABASE InMemoryExample1
ON
PRIMARY(NAME=N'InMemoryExample_data1',
FILENAME = N'/var/opt/mssql/data/InMemoryExample_data1.mdf', size=128MB),
FILEGROUP[InMemoryExample_mod_fg1] CONTAINS MEMORY_OPTIMIZED_DATA
(NAME= [InMemoryExample_mod_dir1],
 FILENAME = N'/var/opt/mssql/data/InMemoryExample_mod_dir1'),
(NAME= [InMemoryExample_mod_dir22],
 FILENAME=N'/var/opt/mssql/data/InMemoryExample_mod_dir22')
 LOG ON(name = [InMemoryExample_log1],
 FILENAME=N'/var/opt/mssql/data/InMemoryExample1.ldf', size=64MB)
 go

 
 ALTER DATABASE InMemoryExample1
 SET ALLOW_SNAPSHOT_ISOLATION ON;
 GO
 
 ALTER DATABASE InMemoryExample1
 SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT ON;
 GO

 ALTER DATABASE InMemoryExample1 SET RECOVERY SIMPLE WITH NO_WAIT
 GO

SELECT name, 
		description, *
FROM sys.dm_os_loaded_modules
WHERE description = 'XTP Native DLL'


 ---- CREACIÓN DE LA TABLA EN MEMORIA
 
 CREATE TABLE T1
 (
 [Name] varchar(32) not null PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT=100000),
 [City] varchar(32) not null,
 [State_Province] varchar(32) not null,
 -- [LastModified] datetime not null,

 INDEX T1_ndx_c2c3 NONCLUSTERED([City],[State_Province])
 )WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA)
 GO

 SELECT * FROM T1;

 SELECT * FROM sys.databases;

 --- CREACIÓN DEL PROCEDIMIENTO ALMACENADO
 CREATE PROCEDURE dbo.p1	
 WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
 AS
 BEGIN ATOMIC
 WITH (TRANSACTION ISOLATION LEVEL=snapshot, LANGUAGE=N'us_english')
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

select * from sys.tables;

---------
CREATE TABLE bigtable_inmem(
 id uniqueidentifier not null
 constraint pk_biggerbigtable_inmem primary key nonclustered
 hash with(bucket_count=2097152), 
 
 account_id int not null,
 trans_type_id smallint not null,
 shop_id int not null,
 trans_made datetime not null,
 trans_amount decimal(20,2) not null,
 entry_date datetime2 not null default (current_timestamp),
 
 index hash_trans_type nonclustered hash
		(shop_id, trans_type_id, trans_made)
		with(bucket_count = 2097152),
 index hash_trans_made nonclustered hash
		(trans_made, shop_id, account_id)
		with(bucket_count = 2097152))
		WITH(MEMORY_OPTIMIZED = ON, DURABILITY=SCHEMA_ONLY);
GO

CREATE TABLE bigtable_tsql(
	id uniqueidentifier not null
	constraint pk_biggerbigtable_tsql primary key nonclustered,
	account_id int not null,
	trans_type_id smallint not null,
	shop_id int not null,
	trans_made datetime not null,
	trans_amount decimal(20,2) not null,
	entry_date datetime2 not null default(current_timestamp),

	index IX_trans_type nonclustered (shop_id, trans_type_id, trans_made),
	index IX_trans_made nonclustered (trans_made, shop_id, account_id)
) 


-- PROCEDIMIENTO NORMAL
CREATE PROC ins_bigtable_tsql (@rows_to_INSERT int)
AS
BEGIN
	SET nocount on;

	DECLARE @i int = 1;
	DECLARE @newid uniqueidentifier
	WHILE @i <= @rows_to_INSERT
	BEGIN 
		SET @newid = NEWID()
		INSERT dbo.bigtable_tsql(id, account_id,trans_type_id,
								shop_id,trans_made,trans_amount)
		VALUES(@newid,
				32767 * rand(),
				30* rand(),
				100 * rand(),
				getdate(),
				(32767 * rand())/100);

		SET @i = @i +1;
	END
END
			

-- PROCEDIMIENTO INTEROP
CREATE PROC ins_bigtable (@rows_to_INSERT int)
AS
BEGIN
	SET nocount on;

	DECLARE @i int = 1;
	DECLARE @newid uniqueidentifier
	WHILE @i <= @rows_to_INSERT
	BEGIN 
		SET @newid = NEWID()
		INSERT dbo.bigtable_inmem(id, account_id,trans_type_id,
								shop_id,trans_made,trans_amount)
		VALUES(@newid,
				32767 * rand(),
				30* rand(),
				100 * rand(),
				getdate(),
				(32767 * rand())/100);

		SET @i = @i +1;
	END
END

-- PROCEDIMIENTO NATIVO !!! EL MÁS RÁPIDO !!!

CREATE PROC ins_native_bigtable (@rows_to_INSERT int)
	   with native_compilation, schemabinding, execute as owner
AS
BEGIN ATOMIC WITH
(TRANSACTION ISOLATION LEVEL =SNAPSHOT,
LANGUAGE = N'us_english')
DECLARE @i int = 1;
DECLARE @newid uniqueidentifier
	WHILE @i <= @rows_to_INSERT
	BEGIN 
		SET @newid = NEWID()
		INSERT dbo.bigtable_inmem(id, account_id,trans_type_id,
								shop_id,trans_made,trans_amount)
		VALUES(@newid,
				32767 * rand(),
				30* rand(),
				100 * rand(),
				getdate(),
				(32767 * rand())/100);

		SET @i = @i +1;
	END
END
GO




-- Modo tradicional - Inserta en una tabla normal  - Esperamos hasta 1 min despues detenemos el procedimiento
EXEC ins_bigtable_tsql @rows_to_INSERT = 200000;

-- Modo Interop - Inserta a una tabla en memoria desde un procedimiento normal -- 200mil registros insertados en 8 segundos
EXEC ins_bigtable @rows_to_INSERT = 200000;

-- Modo Nativo - Inserta a una tabla en memoria desde un procedimiento NATIVO - 300mil registros en cero segundos
EXEC ins_native_bigtable @rows_to_INSERT = 3000000; -- Con 10millones la memoria ram de 5GB no alcanza


select * from bigtable_tsql; -- tabla normal en disco TRADICIONAL  - 135.048 registros insertados en casi 2 min

select * from bigtable_inmem; -- TABLA EN MEMORIA 

select count(*) from bigtable_inmem;  -- 13.111.000   - 7.000.000

delete from bigtable_inmem;

select * from sys.tables;

-----------------------------------------------------
-- COLUMN STORE
-----------------------------------------------------

CREATE TABLE dbo.charge_cs
(
 [charge_no] int IDENTITY(1,1) NOT NULL,
 member_no int not null,
 provider_no int not null,
 category_no int not null,
 charge_dt datetime not null,
 charge_amt money not null,
 statement_no int not null,
 charge_code int not null
) on [PRIMARY]

SET IDENTITY_INSERT dbo.charge_cs ON
GO
 
INSERT INTO dbo.charge_cs(
    charge_no,
	member_no,
	provider_no,
	category_no,
	charge_dt,
	charge_amt,
	statement_no,
	charge_code
)
VALUES(1,2,3,4,GETDATE(),4.5,3,4);
GO 1600000


CREATE NONCLUSTERED COLUMNSTORE INDEX IX_C_Column_Charge_cs ON charge_cs(
  member_no,
  provider_no,
  category_no,
  charge_dt,
  charge_amt,
  statement_no,
  charge_code
)
GO

select member_no,
  provider_no,
  category_no,
  charge_dt,
  charge_amt,
  statement_no,
  charge_code
  from charge_cs where charge_no = 1;

-- CONSULTA COMPLEJA

select l3.shop_id, avg(l3.trans_amount) as promedio
from bigtable_inmem l3
join bigtable_inmem on l3.account_id = bigtable_inmem.trans_type_id
group by l3.shop_id
order by promedio;

---------------------------------------------------------------------------------------------------------------
-- Con el indice columnar [16 segundos] devuelve 100 registros - en un dataset de 3 millones - 5GB RAM, 3 CPUS

-- Sin el indice columnar [1:38minutos] devuelve 100 registros - en un dataset de 3 millones - 5GB RAM, 3 CPUS

---------------------------------------------------------------------------------------------------------------
-- Con el indice columnar [28 segundos] devuelve 100 registros - en un dataset de 7 millones - 8GB RAM, 4 CPUS

-- Sin el indice columnar [5:05minutos] devuelve 100 registros - en un dataset de 7 millones - 8GB RAM, 4 CPUS
---------------------------------------------------------------------------------------------------------------

-- Con el indice columnar [5 segundos] devuelve 100 registros - en un dataset de 3 millones - 8GB RAM, 4 CPUS

-- Sin el indice columnar [55 segundos] devuelve 100 registros - en un dataset de 3 millones - 5GB RAM, 3 CPUS

-- SI ES MEJOR TENER SOLO EL INDICE COLUMNAR SIN MAS INDICES ADICIONALES

-----------------------------------------------------------------------------------------------------------------

select * from bigtable_inmem;-- 59 Segundos para 6 millones de registros
select id, account_id, trans_type_id, shop_id, trans_made, trans_amount, entry_date from bigtable_inmem; -- 57 segundos, 6 millones de registros


drop table dbo.bigtable_inmem;
drop procedure ins_native_bigtable; 

CREATE PROC ins_native_bigtable (@rows_to_INSERT int)
	   with native_compilation, schemabinding, execute as owner
AS
BEGIN ATOMIC WITH
(TRANSACTION ISOLATION LEVEL =SNAPSHOT,
LANGUAGE = N'us_english')
DECLARE @i int = 1;
DECLARE @newid uniqueidentifier
	WHILE @i <= @rows_to_INSERT
	BEGIN 
		SET @newid = NEWID()
		INSERT dbo.bigtable_inmem(id, account_id,trans_type_id,
								shop_id,trans_made,trans_amount)
		VALUES(@newid,
				32767 * rand(),
				30* rand(),
				100 * rand(),
				getdate(),
				(32767 * rand())/100);

		SET @i = @i +1;
	END
END
GO

CREATE TABLE bigtable_inmem(
 id uniqueidentifier not null
 hash with(bucket_count=2097152), 
 
 account_id int not null,
 trans_type_id smallint not null,
 shop_id int not null,
 trans_made datetime not null,
 trans_amount decimal(20,2) not null,
 entry_date datetime2 not null default (current_timestamp),
 INDEX t_account_cci CLUSTERED COLUMNSTORE
 --index hash_trans_type nonclustered hash
 --		(shop_id, trans_type_id, trans_made)
 --		with(bucket_count = 2097152),
 --index hash_trans_made nonclustered hash
 	--	(trans_made, shop_id, account_id)
 	--	with(bucket_count = 2097152))
		 )WITH(MEMORY_OPTIMIZED = ON);


CREATE TABLE dbo.bigtable_inmem(
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
