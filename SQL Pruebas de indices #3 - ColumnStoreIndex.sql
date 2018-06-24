USE Credit
GO

-- Creating the new ColumnIndexStore table
IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'charge_cs')
	DROP TABLE dbo.charge_cs

CREATE TABLE [dbo].[charge_cs](
	[charge_no] [dbo].[numeric_id] IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED,
	[member_no] [dbo].[numeric_id] NOT NULL,
	[provider_no] [dbo].[numeric_id] NOT NULL,
	[category_no] [dbo].[numeric_id] NOT NULL,
	[charge_dt] [datetime] NOT NULL,
	[charge_amt] [money] NOT NULL,
	[statement_no] [dbo].[numeric_id] NOT NULL,
	[charge_code] [dbo].[status_code] NOT NULL
	) ON [PRIMARY]
GO

SET IDENTITY_INSERT dbo.[charge_cs] ON
GO

INSERT INTO dbo.charge_cs (charge_no, member_no, provider_no, category_no, charge_dt, charge_amt, statement_no, charge_code)
SELECT * FROM dbo.charge

SET IDENTITY_INSERT dbo.Charge OFF
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'IX_C_Charge_cs')
	DROP INDEX IX_C_Charge_cs ON dbo.[Charge_cs]
GO

CREATE NONCLUSTERED COLUMNSTORE INDEX IX_C_Charge_cs
ON dbo.[charge_cs]
(
	[charge_no],
	[member_no],
	[provider_no],
	[category_no],
	[charge_dt],
	[charge_amt],
	[statement_no],
	[charge_code] 
)

-- Crear foreign keys

ALTER TABLE [dbo].[charge_cs] WITH CHECK ADD CONSTRAINT [charge_category_link_cs] FOREIGN KEY([category_no])
REFERENCES [dbo].[category]([category_no])
GO

ALTER TABLE [dbo].[charge_cs] CHECK CONSTRAINT [charge_category_link_cs]
GO

-- ESTOY PENSANDO EN RETORNAR POCOS DATOS? O EN RETORNAR MUCHOS DATOS?
-- Si son muchos, deberia estar pensando en un patron SCAN
-- Que es mas optimo un SCAN o un SEEK?, Si son muchos datos lo mas optimo es un SCAN
-- Pocos datos, deberia buscar obtener SEEKS

USE Credit
GO

ALTER TABLE [dbo].[charge_cs] WITH CHECK ADD CONSTRAINT [charge_member_link_cs] FOREIGN KEY([member_no])
REFERENCES [dbo].[member]([member_no])
GO

ALTER TABLE [dbo].[charge_cs] CHECK CONSTRAINT [charge_member_link_cs]
GO

USE Credit
GO

ALTER TABLE [dbo].[charge_cs] WITH CHECK ADD CONSTRAINT [charge_provider_link_cs] FOREIGN KEY([provider_no])
REFERENCES [dbo].[provider]([provider_no])
GO

ALTER TABLE [dbo].[charge_cs] CHECK CONSTRAINT [charge_provider_link_cs]
GO

IF EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'charge_category_link')
BEGIN
	DROP INDEX charge_category_link ON charge
END
GO

CREATE NONCLUSTERED INDEX charge_category_link ON charge(category_no)
INCLUDE(charge_amt, statement_no)
GO

-- COMPARACION DEL RENDIMIENTO DE DOS CONSULTAS UNA CON COLUMNSTORE Y OTRA CON ROWINDEXES

-- Encendemos el plan de ejecución
SET STATISTICS TIME ON
SET STATISTICS IO ON
GO
-- LA CONSULTA GIRA ENTORNO A SCAN POR ESO ESTA ES MAS RAPIDA
-- Charge_cs utiliza un almacenamiento basado en columnas 10% de la ejecucion
-- Una de las ventajas de ColumnStore es el uso de paralelismo, multiples hilos de ejecución
SELECT c.category_desc,
	   SUM(ch.charge_amt) AS sum_charge,
	   AVG(ch.charge_amt) AS avg_charge,
	   COUNT(1) AS qty_charges,
	   MIN(ch.statement_no)
FROM dbo.category c
INNER JOIN charge_cs ch ON ch.category_no = c.category_no
 --WHERE
 --c.category_no IN(2,3)
GROUP BY c.category_desc
GO
SET STATISTICS TIME OFF
SET STATISTICS IO OFF

PRINT '--------------------------------------'

SET STATISTICS TIME ON
SET STATISTICS IO ON
GO
-- La tabla Charge utiliza almacenamiento basado en filas 90% de la ejecución
SELECT c.category_desc,
	   SUM(ch.charge_amt) AS sum_charge,
	   AVG(ch.charge_amt) AS avg_charge,
	   COUNT(1) AS qty_charges,
	   MIN(ch.statement_no)
FROM dbo.category c
INNER JOIN charge ch ON ch.category_no = c.category_no
 --WHERE
 --c.category_no IN(2,3)
GROUP BY c.category_desc
GO
SET STATISTICS TIME OFF
SET STATISTICS IO OFF

-- Cuando tengo estadisticas desactualizadas poco a poco puedo ver como mis Queries se hacen más lentos

-- PATRON CURSOR -- Lentitud ya que va registro a registro, se recomienda usar UNIONS en su lugar
-- Tratar de no hacer ordenamientos innecesarios
-- Si estoy accediendo muchos registros de datos no deberia optimizar hacia SEEK sino a SCAN

-- El columnIndexStore lo utilizo cuando espero utilizar por lo menos el 20% de los registros de mi tabla en una consulta, 
-- esto no quiere decir devolver el 20% de los registros de la tabla, sino UTILIZARLOS en la consulta.

-- EL COLUMNSTORE no es cuando tenga muchos datos, sino cuando hago un SCAN.
-- Cuando busco por un id para traer un registro especifico, SEEK B-TREES
-- Traigame la sumatoria de ventas totales, uso de miles de registros, SUMARIZAR, AGRUPAR - SCAN TIENE MAYOR VENTAJA

select count(*) from charge;