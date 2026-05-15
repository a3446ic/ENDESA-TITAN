--OBTENER TODAS LAS TABLAS DEL USUARIO
SELECT *
FROM user_tables;

--OBTENER TODAS LAS TABLAS DEL USUARIO ORDENADAS POR NOMBRE
SELECT TABLE_NAME
FROM all_tables
WHERE OWNER = 'ENELEXT'
ORDER BY TABLE_NAME;

--COMPROBAR DONDE SE UTILIZAN LAS TABLAS EN LOS PROCEDIMIENTOS ALMACENADOS
SELECT TABLE_NAME
FROM (
SELECT T.table_name,
       CASE 
           WHEN EXISTS (
               SELECT 1
               FROM user_source X
               WHERE UPPER(X.text) LIKE '%' || T.table_name || '%'
           ) 
           THEN 1 
           ELSE 0 
       END AS existe
FROM all_tables T
WHERE T.owner = 'ENELEXT'
) Z 
WHERE EXISTE = 1
ORDER BY Z.table_name;

--COMPROBAR DONDE SE UTILIZAN LAS TABLAS EN LOS PROCEDIMIENTOS ALMACENADOS
SELECT DISTINCT 
       T.table_name,
       X.name AS objeto,
       X.type AS tipo
FROM all_tables T
JOIN user_source X
  ON UPPER(X.text) LIKE '%' || T.table_name || '%'
WHERE T.owner = 'ENELEXT'
ORDER BY T.table_name, X.name;


