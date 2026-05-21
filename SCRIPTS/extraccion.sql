  --EXTRACCIÓN DE DEPENDENCIAS DE PAQUETES
  SELECT DISTINCT
       referenced_name AS table_name,
       owner AS objeto,
       type AS tipo,      
       NAME AS package_name
FROM all_dependencies
WHERE referenced_owner = 'ENELEXT';


--NÚMERO DE REGISTROS
SELECT owner, table_name, num_rows
FROM all_tables
WHERE owner = 'ENELEXT';


--DEPENDENCIAS DE LAS TABLAS Y REGISTROS
SELECT T.TABLE_NAME,D.TYPE,D.NAME,T.NUM_ROWS
FROM ALL_TABLES T
LEFT OUTER JOIN all_dependencies D ON T.TABLE_NAME = D.REFERENCED_NAME
WHERE T.OWNER = 'ENELEXT'
ORDER BY T.TABLE_NAME;