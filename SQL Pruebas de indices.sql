-- SE HABILITA LA GENERACION DE ESTADISTICAS DE MANERA ASINCRONA Y EL MODO DE RECUPERACION COMPLETO
ALTER DATABASE [Credit] SET AUTO_UPDATE_STATISTICS_ASYNC ON WITH NO_WAIT
GO
ALTER DATABASE [Credit] SET RECOVERY FULL WITH NO_WAIT
USE Credit

-- Tenemos tres nonclustered indexes definidos en Category_no, Provider_no, Statement_no
-- Se hace un Query Seek
select * from charge where charge_no = 1223

-- un indice es copia llana de datos, asi de simple
-- Se hace un nonclustered Seek, el indice responde la consulta por si solo
select provider_no from charge where provider_no = 24

-- Como yo defini un clustered index en provider_no esperariamos que se utilizara el indice pero no es asi
-- El nonclustered index es capaz de servirme el provider_no, esperariamos un Key Lookup pero no es asi no hay necesidad de ir al clustered index
-- Charge_no esta definido en un indice de llave primaria
select provider_no, charge_no from charge where provider_no = 24

-- Charge_amt no esta definido en ningun indice, aca si pasa el Key Lookup. El que fuerza el Keylookup es el charge_amt
-- Que es ir al clustered y traer el dato directo
-- Ese Keylookup representa el 95% del costo de mi Query
select provider_no, charge_no, charge_amt from charge where provider_no = 24

-- Como optimizar esto? voy a crear un nonclustered que lo tenia inicialmente definido solo para provider_no e incluir en los nodos hoja el charge_amt NO EN LOS NODOS RAIZ
-- incluir charge_amt dentro del nonclustered pero directamente en los nodos hoja, esto se logra con la instruccion 'include'
create nonclustered index charge_provider_link
on dbo.charge(provider_no)
include (charge_amt) -- el charge_amt va solo al nodo hoja
with (drop_existing = on)
GO

-- Ahora si utilizamos el Query se va por el indice nonclustered sin el KeyLookup
-- ESTA ESTRATEGIA SE CONOCE COMO COVERAGE
select provider_no, charge_no, charge_amt from charge where provider_no = 24



