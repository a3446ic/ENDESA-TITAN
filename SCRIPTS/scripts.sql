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

--V2. MEJOR ESTA. EJEMPLO:
SELECT DISTINCT
       referenced_name AS table_name,
       owner AS objeto,
       type AS tipo
FROM all_dependencies
WHERE referenced_owner = 'ENELEXT'
  AND referenced_name = 'ENEL_CRE_RICORRENTE_24M';


--OBTENER CANTIDAD DE REGISTROS EN TABLAS 
--SE MUESTRA LA SALIDA POR SCRIPT
SET SERVEROUTPUT ON

DECLARE
    v_sql   VARCHAR2(2000);
    v_count NUMBER;
BEGIN
    FOR t IN (
        SELECT DISTINCT 
            T.owner,
            T.table_name
        FROM all_tables T
        JOIN user_source X
          ON UPPER(X.text) LIKE '%' || T.table_name || '%'
        WHERE T.owner = 'ENELEXT'
    ) LOOP
        BEGIN
            v_sql := 'SELECT COUNT(*) FROM ' || t.owner || '.' || t.table_name;

            EXECUTE IMMEDIATE v_sql INTO v_count;

            DBMS_OUTPUT.PUT_LINE(t.owner || '.' || t.table_name || ';' || v_count);

        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE(t.owner || '.' || t.table_name || ';ERROR');
        END;
    END LOOP;
END;
/


--EXPRESION REGULAR
\\\);\\s\*\\r\? --> CAMBIAR ); POR );<SALTO DE LINEA>

--OBTENER CREATE DE TODAS LAS TABLAS
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET LINESIZE 500
SET PAGESIZE 0

SELECT DBMS_METADATA.GET_DDL('TABLE', table_name, owner)
FROM (
    SELECT DISTINCT 
        t.owner,
        t.table_name
    FROM all_tables T
    --JOIN user_source X
    --  ON UPPER(X.text) LIKE '%' || T.table_name || '%'
    WHERE T.owner = 'ENELEXT'
    order by t.table_name
);


--EXTRACCIÓN PACKAGE BODY
SELECT OWNER,OBJECT_NAME
FROM all_objects
WHERE object_type = 'PACKAGE BODY'
 AND owner = 'ENELEXT'
 ORDER BY OBJECT_NAME
 ;
 