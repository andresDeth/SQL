USE Credit;
GO

/*
  Member table indexes

  -- Clustered index defined on member_no
  -- Non Clustered Indexes
      - on corp_no
	  - on region_no
*/

-- Como no tengo ningun indice espero un Clustered indexScan
SELECT firstname FROM member WHERE firstname = N'XBQ'

-- Creamos un indice sobre first_name
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_member_firstname')
	DROP INDEX IX_member_firstname ON member
CREATE INDEX IX_member_firstname ON member(firstname)

-- Deberia hacerme un nonclustered index seek, pero NO, me hace un Nonclustered index Scan
-- esto es porque se utiliza la funcion CAST, EL INDICE SE VUELVE NO UTILIZABLE. SQL Server debe hacer el indexScan completo
SELECT firstname FROM member WHERE CAST(firstname AS VARCHAR) = 'XBQ' 

--  Si veo en el plan de ejecucion veo que me aparece un CONVERT en el predicado que es lo que esta utilizando
-- Aca se utiliza el indice? NO, SQL Server en este caso utiliza el IMPLICIT CONVERT. Toma el valor que le paso en el Where
-- y lo convierte para poder compararlo con el otro valor
SELECT firstname FROM member WHERE firstname = N'XBQ' -- INDEX SCAN

-- LA MANERA DE ARREGLARLO Y QUITARLE LA 'N'
SELECT firstname FROM member WHERE firstname = 'XBQ' -- INDEX SEEK







