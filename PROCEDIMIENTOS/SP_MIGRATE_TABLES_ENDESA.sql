CREATE OR REPLACE PROCEDURE EXT.SP_MIGRATE_TABLES_ENDESA()
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 16-06-2026
    |----------------------------------------------------------------------
    | Procedure Purpose: 
    | -- 
	| -- 
    |
	| Version:	0.1	SMM	20260616    Initial Version.
	|
    -----------------------------------------------------------------------
*/
BEGIN
DECLARE v_cont INT = 0;
DECLARE proc_name NVARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
DECLARE v_version NVARCHAR(4) := '0.1';
DECLARE v_log_count INTEGER := 0;
DECLARE v_idproceso BIGINT := 0;
DECLARE v_num_rows INT;
DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
DECLARE v_permisos_log NVARCHAR(50) := EXT.LIB_GLOBAL_ENDESA:GET_PERMISOS_LOG();



DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, proc_name, 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																											
		RESIGNAL;
END;
   




CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, proc_name, 'Procedure starting for: MIGRAR TABLAS', v_log_count, v_idproceso,'info');

--SMM_CS_USUARIOS_ROLES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_CS_USUARIOS_ROLES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_USUARIOS_ROLES;
            INSERT INTO EXT.SMM_USUARIOS_ROLES
                SELECT *               
                FROM EXT.SMM_CS_USUARIOS_ROLES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_CS_USUARIOS_ROLES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_ENEL_ACTIVIDAD_COMERCIAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ACTIVIDAD_COMERCIAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ACTIVIDAD_COMERCIAL;
            INSERT INTO EXT.SMM_ACTIVIDAD_COMERCIAL
                SELECT *               
                FROM EXT.SMM_ENEL_ACTIVIDAD_COMERCIAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ACTIVIDAD_COMERCIAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_AGREFACT_FINAL_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_AGREFACT_FINAL_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_AGREFACT_FINAL_CES;
            INSERT INTO EXT.SMM_AGREFACT_FINAL_CES
                SELECT *               
                FROM EXT.SMM_ENEL_AGREFACT_FINAL_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_AGREFACT_FINAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_AGR_FAC_E4E_FINAL_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_AGR_FAC_E4E_FINAL_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_AGR_FAC_E4E_FINAL_CES;
            INSERT INTO EXT.SMM_AGR_FAC_E4E_FINAL_CES
                SELECT *               
                FROM EXT.SMM_ENEL_AGR_FAC_E4E_FINAL_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_AGR_FAC_E4E_FINAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_AGR_FAC_PREFACTURA_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_AGR_FAC_PREFACTURA_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_AGR_FAC_PREFACTURA_CES;
            INSERT INTO EXT.SMM_AGR_FAC_PREFACTURA_CES
                SELECT *               
                FROM EXT.SMM_ENEL_AGR_FAC_PREFACTURA_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_AGR_FAC_PREFACTURA_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ANDROMEDA_CREDIT_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ANDROMEDA_CREDIT_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ANDROMEDA_CREDIT_TEMP;
            INSERT INTO EXT.SMM_ANDROMEDA_CREDIT_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_ANDROMEDA_CREDIT_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ANDROMEDA_CREDIT_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_ENEL_ANDROMEDA_FINAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ANDROMEDA_FINAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ANDROMEDA_FINAL;
            INSERT INTO EXT.SMM_ANDROMEDA_FINAL
                SELECT *               
                FROM EXT.SMM_ENEL_ANDROMEDA_FINAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ANDROMEDA_FINAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ANDROMEDA_INF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ANDROMEDA_INF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ANDROMEDA_INF;
            INSERT INTO EXT.SMM_ANDROMEDA_INF
                SELECT *               
                FROM EXT.SMM_ENEL_ANDROMEDA_INF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ANDROMEDA_INF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ANDROMEDA_TXN_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ANDROMEDA_TXN_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ANDROMEDA_TXN_TEMP;
            INSERT INTO EXT.SMM_ANDROMEDA_TXN_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_ANDROMEDA_TXN_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ANDROMEDA_TXN_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_BAJAS
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_BAJAS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_BAJAS;
            -- INSERT INTO EXT.SMM_BAJAS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_BAJAS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_BAJAS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_AM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_AM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_AM;
            INSERT INTO EXT.SMM_CAT_TVTA_AM
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_AM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_AM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_ENEL_CAT_TVTA_AM_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_AM_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_AM_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_AM_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_AM_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_AM_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_APORTE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_APORTE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_APORTE;
            INSERT INTO EXT.SMM_CAT_TVTA_APORTE
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_APORTE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_APORTE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_APORTE_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_APORTE_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_APORTE_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_APORTE_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_APORTE_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_APORTE_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_BONUS_MALUS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_BONUS_MALUS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_BONUS_MALUS;
            INSERT INTO EXT.SMM_CAT_TVTA_BONUS_MALUS
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_BONUS_MALUS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_BONUS_MALUS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_BONUS_MALUS_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_BONUS_MALUS_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_BONUS_MALUS_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_BONUS_MALUS_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_BONUS_MALUS_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_BONUS_MALUS_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_IB_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_IB_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_IB_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_IB_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_IB_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_IB_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_ENEL_CAT_TVTA_INCEN_PENAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_INCEN_PENAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_INCEN_PENAL;
            INSERT INTO EXT.SMM_CAT_TVTA_INCEN_PENAL
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_INCEN_PENAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_INCEN_PENAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_ENEL_CAT_TVTA_INCEN_PENAL_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_INCEN_PENAL_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_INCEN_PENAL_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_INCEN_PENAL_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_INCEN_PENAL_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_INCEN_PENAL_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_IP_TOTAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_IP_TOTAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_IP_TOTAL;
            INSERT INTO EXT.SMM_CAT_TVTA_IP_TOTAL
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_IP_TOTAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_IP_TOTAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_IP_TOTAL_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_IP_TOTAL_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_IP_TOTAL_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_IP_TOTAL_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_CAT_TVTA_IP_VENTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_IP_VENTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_IP_VENTA;
            INSERT INTO EXT.SMM_CAT_TVTA_IP_VENTA
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_IP_VENTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_IP_VENTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_CAT_TVTA_IP_VENTA_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_IP_VENTA_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_IP_VENTA_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_IP_VENTA_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_IP_VENTA_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_IP_VENTA_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_CAT_TVTA_RESUM_PAGO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_RESUM_PAGO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_RESUM_PAGO;
            INSERT INTO EXT.SMM_CAT_TVTA_RESUM_PAGO
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_RESUM_PAGO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_RESUM_PAGO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CAT_TVTA_RESUM_PAGO_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CAT_TVTA_RESUM_PAGO_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CAT_TVTA_RESUM_PAGO_TEMP;
            INSERT INTO EXT.SMM_CAT_TVTA_RESUM_PAGO_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CAT_TVTA_RESUM_PAGO_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CAT_TVTA_RESUM_PAGO_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CCC_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CCC_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CCC_ALIADOS;
            INSERT INTO EXT.SMM_CCC_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_CCC_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CCC_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CCC_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CCC_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CCC_CCDD;
            INSERT INTO EXT.SMM_CCC_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_CCC_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CCC_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CLASIFICACION_EVENTO_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CLASIFICACION_EVENTO_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CLASIFICACION_EVENTO_CES;
            INSERT INTO EXT.SMM_CLASIFICACION_EVENTO_CES
                SELECT *               
                FROM EXT.SMM_ENEL_CLASIFICACION_EVENTO_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CLASIFICACION_EVENTO_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CODIGOPOSTAL_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CODIGOPOSTAL_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CODIGOPOSTAL_DTM;
            INSERT INTO EXT.SMM_CODIGOPOSTAL_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_CODIGOPOSTAL_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CODIGOPOSTAL_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMMI_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMMI_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMMI_DTM;
            INSERT INTO EXT.SMM_COMMI_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_COMMI_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMMI_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_COMMISSION_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMMISSION_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMMISSION_TEMP_CEBP;
            INSERT INTO EXT.SMM_COMMISSION_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_COMMISSION_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMMISSION_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMMISSION_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMMISSION_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMMISSION_TEMP_CEIS;
            INSERT INTO EXT.SMM_COMMISSION_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_COMMISSION_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMMISSION_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMMISSION_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMMISSION_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMMISSION_TEMP_CESP;
            INSERT INTO EXT.SMM_COMMISSION_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_COMMISSION_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMMISSION_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMMISSION_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMMISSION_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMMISSION_TEMP_CETF;
            INSERT INTO EXT.SMM_COMMISSION_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_COMMISSION_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMMISSION_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMMISSION_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMMISSION_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMMISSION_TEMP_CETVTA;
            INSERT INTO EXT.SMM_COMMISSION_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_COMMISSION_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMMISSION_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_E4E_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_E4E_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_E4E_CEBP;
            INSERT INTO EXT.SMM_COMP_E4E_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_E4E_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_E4E_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_E4E_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_E4E_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_E4E_CEIS;
            INSERT INTO EXT.SMM_COMP_E4E_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_E4E_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_E4E_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_E4E_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_E4E_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_E4E_CESP;
            INSERT INTO EXT.SMM_COMP_E4E_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_E4E_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_E4E_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_E4E_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_E4E_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_E4E_CETF;
            INSERT INTO EXT.SMM_COMP_E4E_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_E4E_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_E4E_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_E4E_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_E4E_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_E4E_CETVTA;
            INSERT INTO EXT.SMM_COMP_E4E_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_E4E_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_E4E_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMPROBACION_B2B
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMPROBACION_B2B', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMPROBACION_B2B;
            INSERT INTO EXT.SMM_COMPROBACION_B2B
                SELECT *               
                FROM EXT.SMM_ENEL_COMPROBACION_B2B;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMPROBACION_B2B: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E_ALIADO;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E_CAB_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E_CAB_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E_CAB_TF;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_CAB_TF
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E_CAB_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E_CAB_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E_CAT_TVTA;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E_CCDD;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E_PTG;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_COMP_SCAWEB_E4E_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_COMP_SCAWEB_E4E_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_COMP_SCAWEB_E4E_TF;
            INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_TF
                SELECT *               
                FROM EXT.SMM_ENEL_COMP_SCAWEB_E4E_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_COMP_SCAWEB_E4E_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CONSECUCION_FINAL_OFV
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CONSECUCION_FINAL_OFV', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CONSECUCION_FINAL_OFV;
            -- INSERT INTO EXT.SMM_CONSECUCION_FINAL_OFV
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CONSECUCION_FINAL_OFV;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CONSECUCION_FINAL_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CONSECUCION_TEMP_OFV
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CONSECUCION_TEMP_OFV', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CONSECUCION_TEMP_OFV;
            -- INSERT INTO EXT.SMM_CONSECUCION_TEMP_OFV
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CONSECUCION_TEMP_OFV;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CONSECUCION_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CONSECUCION_TEMP2_OFV
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CONSECUCION_TEMP2_OFV', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CONSECUCION_TEMP2_OFV;
            -- INSERT INTO EXT.SMM_CONSECUCION_TEMP2_OFV
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CONSECUCION_TEMP2_OFV;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CONSECUCION_TEMP2_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CONTRATOS_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_HANA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CONTRATOS_DTM;
            INSERT INTO EXT.SMM_CONTRATOS_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_CONTRATOS_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CONTRATOS_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRECIMIENTO_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRECIMIENTO_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRECIMIENTO_TEMP_OFV;
            INSERT INTO EXT.SMM_CRECIMIENTO_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_CRECIMIENTO_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRECIMIENTO_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_DTM;
            INSERT INTO EXT.SMM_CREDIT_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_DTM_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_DTM_TEMP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CREDIT_DTM_TEMP;
            -- INSERT INTO EXT.SMM_CREDIT_DTM_TEMP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CREDIT_DTM_TEMP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_DTM_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_FINAL_VOL_FIJA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_FINAL_VOL_FIJA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_FINAL_VOL_FIJA;
            INSERT INTO EXT.SMM_CREDIT_FINAL_VOL_FIJA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_FINAL_VOL_FIJA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_FINAL_VOL_FIJA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_FINAL_VOL_GAS_FIJA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_FINAL_VOL_GAS_FIJA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_FINAL_VOL_GAS_FIJA;
            INSERT INTO EXT.SMM_CREDIT_FINAL_VOL_GAS_FIJA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_FINAL_VOL_GAS_FIJA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_FINAL_VOL_GAS_FIJA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_FINAL_V_RENTA_FIJA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_FINAL_V_RENTA_FIJA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_FINAL_V_RENTA_FIJA;
            INSERT INTO EXT.SMM_CREDIT_FINAL_V_RENTA_FIJA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_FINAL_V_RENTA_FIJA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_FINAL_V_RENTA_FIJA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_CANAL_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_CANAL_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CREDITOS_CANAL_CES;
            -- INSERT INTO EXT.SMM_CREDITOS_CANAL_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CREDITOS_CANAL_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_CANAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_OFV;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_OFV_FIJA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_OFV_FIJA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_OFV_FIJA;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_OFV_FIJA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_OFV_FIJA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_OFV_FIJA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_PSVA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_PSVA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_PSVA;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_PSVA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_PSVA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_PSVA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_PSVA_FIJA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_PSVA_FIJA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_PSVA_FIJA;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_PSVA_FIJA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_PSVA_FIJA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_PSVA_FIJA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_VOL_GAS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_VOL_GAS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_VOL_GAS;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_VOL_GAS
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_VOL_GAS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_VOL_GAS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_VOLUMEN
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_VOLUMEN', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_VOLUMEN;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_VOLUMEN
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_VOLUMEN;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_VOLUMEN: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_VOLUMEN_HIST
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_VOLUMEN_HIST', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_VOLUMEN_HIST;
            -- INSERT INTO EXT.SMM_CREDITOS_FINAL_VOLUMEN_HIST
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CREDITOS_FINAL_VOLUMEN_HIST;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_VOLUMEN_HIST: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_FINAL_V_RENTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_FINAL_V_RENTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_FINAL_V_RENTA;
            INSERT INTO EXT.SMM_CREDITOS_FINAL_V_RENTA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_FINAL_V_RENTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_FINAL_V_RENTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDITOS_INCEN_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDITOS_INCEN_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDITOS_INCEN_ALICO;
            INSERT INTO EXT.SMM_CREDITOS_INCEN_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_CREDITOS_INCEN_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDITOS_INCEN_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_CREDIT_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP;
            INSERT INTO EXT.SMM_CREDIT_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_ALIADO;
            INSERT INTO EXT.SMM_CREDIT_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_ALICO;
            INSERT INTO EXT.SMM_CREDIT_TEMP_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CCDD;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CCDD_2
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CCDD_2', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CCDD_2;
            -- INSERT INTO EXT.SMM_CREDIT_TEMP_CCDD_2
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CREDIT_TEMP_CCDD_2;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CCDD_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CEBP;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CEBP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CEBP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CEBP_2;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CEBP_2
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CEBP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CEBP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CEIS;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CEIS_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CEIS_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CEIS_2;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CEIS_2
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CEIS_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CEIS_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CESP;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CETF;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_CETVTA;
            INSERT INTO EXT.SMM_CREDIT_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_ENEL_CREDIT_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_OFV;
            INSERT INTO EXT.SMM_CREDIT_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CREDIT_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CREDIT_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CREDIT_TEMP_TF;
            INSERT INTO EXT.SMM_CREDIT_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_CREDIT_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CREDIT_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_DIAS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_DIAS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_DIAS;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_DIAS
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_DIAS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_DIAS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_DIAS_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_DIAS_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_DIAS_TF;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_DIAS_TF
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_DIAS_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_DIAS_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_STORES_12M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_STORES_12M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_STORES_12M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_STORES_12M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_STORES_12M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_STORES_12M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_CRE_RICORRENTE_STORES_13M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_STORES_13M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_STORES_13M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_STORES_13M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_STORES_13M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_STORES_13M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM__CRE_RICORRENTE_STORES_14M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_STORES_14M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_STORES_14M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_STORES_14M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_STORES_14M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_STORES_14M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_CRE_RICORRENTE_STORES_15M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_STORES_15M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_STORES_15M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_STORES_15M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_STORES_15M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_STORES_15M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_STORES_6M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_STORES_6M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_STORES_6M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_STORES_6M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_STORES_6M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_STORES_6M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_TF_12M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_TF_12M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_TF_12M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_TF_12M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_TF_12M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_TF_12M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_TF_24M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_TF_24M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_TF_24M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_TF_24M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_TF_24M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_TF_24M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_TF_36M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_TF_36M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_TF_36M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_TF_36M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_TF_36M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_TF_36M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_TF_6M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_TF_6M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_TF_6M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_TF_6M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_TF_6M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_TF_6M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_12M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_12M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_12M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_12M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_12M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_12M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_CRE_RICORRENTE_13M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_13M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_13M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_13M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_13M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_13M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_14M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_14M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_14M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_14M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_14M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_14M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_15M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_15M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_15M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_15M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_15M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_15M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_24M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_24M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_24M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_24M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_24M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_24M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CRE_RICORRENTE_36M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_36M', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_36M;
            -- INSERT INTO EXT.SMM_CRE_RICORRENTE_36M
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_CRE_RICORRENTE_36M;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_36M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_CRE_RICORRENTE_6M
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CRE_RICORRENTE_6M', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CRE_RICORRENTE_6M;
            INSERT INTO EXT.SMM_CRE_RICORRENTE_6M
                SELECT *               
                FROM EXT.SMM_ENEL_CRE_RICORRENTE_6M;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CRE_RICORRENTE_6M: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CTRL_INFORMES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CTRL_INFORMES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CTRL_INFORMES;
            INSERT INTO EXT.SMM_CTRL_INFORMES
                SELECT *               
                FROM EXT.SMM_ENEL_CTRL_INFORMES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CTRL_INFORMES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_ALIADO;
            INSERT INTO EXT.SMM_CUADRELIQ_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_CAT_RECEPCION
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_CAT_RECEPCION', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_CAT_RECEPCION;
            INSERT INTO EXT.SMM_CUADRELIQ_CAT_RECEPCION
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_CAT_RECEPCION;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_CAT_RECEPCION: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_CCDD;
            INSERT INTO EXT.SMM_CUADRELIQ_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_CCDD_RAPPEL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_CCDD_RAPPEL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_CCDD_RAPPEL;
            INSERT INTO EXT.SMM_CUADRELIQ_CCDD_RAPPEL
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_CCDD_RAPPEL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_CCDD_RAPPEL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_CCDD_RESELLERS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_CCDD_RESELLERS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_CCDD_RESELLERS;
            INSERT INTO EXT.SMM_CUADRELIQ_CCDD_RESELLERS
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_CCDD_RESELLERS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_CCDD_RESELLERS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_CCDD_SLA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_CCDD_SLA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_CCDD_SLA;
            INSERT INTO EXT.SMM_CUADRELIQ_CCDD_SLA
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_CCDD_SLA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_CCDD_SLA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRELIQ_FINAL_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRELIQ_FINAL_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRELIQ_FINAL_CES;
            INSERT INTO EXT.SMM_CUADRELIQ_FINAL_CES
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRELIQ_FINAL_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRELIQ_FINAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_CUADRE_LIQ_ONLINE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_CUADRE_LIQ_ONLINE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CUADRE_LIQ_ONLINE;
            INSERT INTO EXT.SMM_CUADRE_LIQ_ONLINE
                SELECT *               
                FROM EXT.SMM_ENEL_CUADRE_LIQ_ONLINE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_CUADRE_LIQ_ONLINE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEBUG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEBUG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEBUG;
            INSERT INTO EXT.SMM_DEBUG
                SELECT *               
                FROM EXT.SMM_ENEL_DEBUG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEBUG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DECOMISADO
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DECOMISADO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_DECOMISADO;
            -- INSERT INTO EXT.SMM_DECOMISADO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_DECOMISADO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DECOMISADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_AGRUPADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_AGRUPADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_AGRUPADO;
            INSERT INTO EXT.SMM_DEPOSIT_AGRUPADO
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_AGRUPADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_AGRUPADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_CTAS_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_CTAS_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_DEPOSIT_CTAS_CES;
            -- INSERT INTO EXT.SMM_DEPOSIT_CTAS_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_DEPOSIT_CTAS_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_CTAS_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_CTAS_CES_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_CTAS_CES_2', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_DEPOSIT_CTAS_CES_2;
            -- INSERT INTO EXT.SMM_DEPOSIT_CTAS_CES_2
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_DEPOSIT_CTAS_CES_2;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_CTAS_CES_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_DTM;
            INSERT INTO EXT.SMM_DEPOSIT_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSITOS_CANAL_CES
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSITOS_CANAL_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_DEPOSITOS_CANAL_CES;
            -- INSERT INTO EXT.SMM_DEPOSITOS_CANAL_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_DEPOSITOS_CANAL_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSITOS_CANAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_PTG_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_PTG_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_PTG_TEMP;
            INSERT INTO EXT.SMM_DEPOSIT_PTG_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_PTG_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_PTG_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_ALIADO;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CAT_TVTA;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CCDD;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CEBP;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CEIS;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CESP;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CETF;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CETVTA;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_OFV;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_PTG;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DEPOSIT_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DEPOSIT_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_TF;
            INSERT INTO EXT.SMM_DEPOSIT_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_DEPOSIT_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DEPOSIT_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');




--SMM_ENEL_DETALLE_OCAP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DETALLE_OCAP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DETALLE_OCAP;
            INSERT INTO EXT.SMM_DETALLE_OCAP
                SELECT *               
                FROM EXT.SMM_ENEL_DETALLE_OCAP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DETALLE_OCAP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DET_INCENTIVOS_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DET_INCENTIVOS_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DET_INCENTIVOS_CES;
            INSERT INTO EXT.SMM_DET_INCENTIVOS_CES
                SELECT *               
                FROM EXT.SMM_ENEL_DET_INCENTIVOS_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DET_INCENTIVOS_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_DISPUTAS_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_DISPUTAS_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_DISPUTAS_CES;
            INSERT INTO EXT.SMM_DISPUTAS_CES
                SELECT *               
                FROM EXT.SMM_ENEL_DISPUTAS_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_DISPUTAS_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ECO_FINAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ECO_FINAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ECO_FINAL;
            INSERT INTO EXT.SMM_ECO_FINAL
                SELECT *               
                FROM EXT.SMM_ENEL_ECO_FINAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ECO_FINAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ECO_FINAL_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ECO_FINAL_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ECO_FINAL_TF;
            INSERT INTO EXT.SMM_ECO_FINAL_TF
                SELECT *               
                FROM EXT.SMM_ENEL_ECO_FINAL_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ECO_FINAL_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ECO_INF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ECO_INF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ECO_INF;
            INSERT INTO EXT.SMM_ECO_INF
                SELECT *               
                FROM EXT.SMM_ENEL_ECO_INF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ECO_INF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ECO_INF_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ECO_INF_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ECO_INF_TF;
            INSERT INTO EXT.SMM_ECO_INF_TF
                SELECT *               
                FROM EXT.SMM_ENEL_ECO_INF_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ECO_INF_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ENTRADA_TIPO_SUBTIPO
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ENTRADA_TIPO_SUBTIPO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_ENTRADA_TIPO_SUBTIPO;
            -- INSERT INTO EXT.SMM_ENTRADA_TIPO_SUBTIPO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_ENTRADA_TIPO_SUBTIPO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ENTRADA_TIPO_SUBTIPO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_ENTRADA_TIPO_SUBTIPO_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_ENTRADA_TIPO_SUBTIPO_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ENTRADA_TIPO_SUBTIPO_TEMP;
            INSERT INTO EXT.SMM_ENTRADA_TIPO_SUBTIPO_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_ENTRADA_TIPO_SUBTIPO_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_ENTRADA_TIPO_SUBTIPO_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_EQUIPAMIENTO_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_DTM;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_ALIADO;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_CCDD;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_CEBP;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_CEIS;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_CESP;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_CETF;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_CETVTA;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_OFV;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_EQUIPAMIENTO_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_EQUIPAMIENTO_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_EQUIPAMIENTO_TEMP_TF;
            INSERT INTO EXT.SMM_EQUIPAMIENTO_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_EQUIPAMIENTO_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_EQUIPAMIENTO_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CCDD_WBE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CCDD_WBE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CCDD_WBE;
            INSERT INTO EXT.SMM_E4E_CCDD_WBE
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CCDD_WBE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CCDD_WBE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRA_TEMP_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRA_TEMP_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRA_TEMP_CAT_TVTA;
            INSERT INTO EXT.SMM_E4E_CONTRA_TEMP_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRA_TEMP_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRA_TEMP_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_PTG_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_PTG_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_PTG_TEMP;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_PTG_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_PTG_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_PTG_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_ALIADO;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CCDD;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CEBP;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CEIS;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CESP;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CETF;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CETVTA;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_PTG
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_PTG', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_PTG;
            -- INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_PTG
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_PTG;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_CONTRATOS_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_CONTRATOS_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_TF;
            INSERT INTO EXT.SMM_E4E_CONTRATOS_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_CONTRATOS_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_CONTRATOS_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_ALIADO_TEMP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_ALIADO_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_ALIADO_TEMP_2;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_ALIADO_TEMP_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_ALIADO_TEMP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_CAT_TVTA_TEMP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_CAT_TVTA_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_CCDD_TEMP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_CCDD_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_CCDD_TEMP_2;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_CCDD_TEMP_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_CCDD_TEMP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_PRUEBA
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_PRUEBA', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_PRUEBA;
            -- INSERT INTO EXT.SMM_E4E_DEPOSIT_PRUEBA
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_DEPOSIT_PRUEBA;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_PRUEBA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_DEPOSIT_PTG_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_PTG_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_PTG_TEMP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_PTG_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_PTG_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_PTG_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_PTG_TEMP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_PTG_TEMP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_PTG_TEMP_2;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_PTG_TEMP_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_PTG_TEMP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_PTG_TEMP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_E4E_DEPOSIT_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_CEBP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_CEIS;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_CESP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_CETF;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_CETVTA;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TEMP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TEMP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_2;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TEMP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TEMP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_DEPOSIT_TF_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TF_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TF_TEMP;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TF_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TF_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TF_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_ENEL_E4E_DEPOSIT_TF_TEMP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_DEPOSIT_TF_TEMP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TF_TEMP_2;
            INSERT INTO EXT.SMM_E4E_DEPOSIT_TF_TEMP_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_DEPOSIT_TF_TEMP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_DEPOSIT_TF_TEMP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL;
            INSERT INTO EXT.SMM_E4E_FINAL
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_ALIADO;
            INSERT INTO EXT.SMM_E4E_FINAL_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CAT_TVTA;
            INSERT INTO EXT.SMM_E4E_FINAL_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CCDD;
            INSERT INTO EXT.SMM_E4E_FINAL_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CEBP;
            INSERT INTO EXT.SMM_E4E_FINAL_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CEIS;
            INSERT INTO EXT.SMM_E4E_FINAL_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CESP;
            INSERT INTO EXT.SMM_E4E_FINAL_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_HANA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CETF;
            INSERT INTO EXT.SMM_E4E_FINAL_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_CETVTA;
            INSERT INTO EXT.SMM_E4E_FINAL_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_PTG;
            INSERT INTO EXT.SMM_E4E_FINAL_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_FINAL_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_FINAL_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_FINAL_TF;
            INSERT INTO EXT.SMM_E4E_FINAL_TF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_FINAL_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_FINAL_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_INF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_INF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_INF;
            INSERT INTO EXT.SMM_E4E_INF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_INF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_INF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_INF_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_INF_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_INF_ALIADOS;
            INSERT INTO EXT.SMM_E4E_INF_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_INF_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_INF_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_INF_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_INF_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_INF_CAT_TVTA;
            INSERT INTO EXT.SMM_E4E_INF_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_INF_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_INF_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_INF_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_INF_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_INF_CCDD;
            INSERT INTO EXT.SMM_E4E_INF_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_INF_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_INF_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_INF_CEBP
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_INF_CEBP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_INF_CEBP;
            -- INSERT INTO EXT.SMM_E4E_INF_CEBP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_INF_CEBP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_INF_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_INF_CEIS
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_INF_CEIS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_INF_CEIS;
            -- INSERT INTO EXT.SMM_E4E_INF_CEIS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_INF_CEIS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_INF_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_INF_CESP
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_INF_CESP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SM_E4E_INF_CESP;
            -- INSERT INTO EXT.SMM_E4E_INF_CESP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_INF_CESP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_INF_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_INF_CETF
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_INF_CETF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_INF_CETF;
            -- INSERT INTO EXT.SMM_E4E_INF_CETF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_INF_CETF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_INF_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_INF_CETVTA
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_INF_CETVTA', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_INF_CETVTA;
            -- INSERT INTO EXT.SMM_E4E_INF_CETVTA
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_INF_CETVTA;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_INF_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_INF_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_INF_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_INF_TF;
            INSERT INTO EXT.SMM_E4E_INF_TF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_INF_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_INF_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_NEGATIVOS_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_ALIADO;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_NEGATIVOS_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CAT_TVTA;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CCDD;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_CEBP
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CEBP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CEBP;
            -- INSERT INTO EXT.SMM_E4E_NEGATIVOS_CEBP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CEBP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_CEIS
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CEIS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CEIS;
            -- INSERT INTO EXT.SMM_E4E_NEGATIVOS_CEIS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CEIS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CES;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_CES
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_E4E_NEGATIVOS_CESP
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CESP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CESP;
            -- INSERT INTO EXT.SMM_E4E_NEGATIVOS_CESP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CESP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_CETF
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CETF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CETF;
            -- INSERT INTO EXT.SMM_E4E_NEGATIVOS_CETF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CETF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_CETVTA
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_CETVTA', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_CETVTA;
            -- INSERT INTO EXT.SMM_E4E_NEGATIVOS_CETVTA
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_E4E_NEGATIVOS_CETVTA;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_PTG;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_ALIADO;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_CCDD;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_CEBP;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_CEIS;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_CESP;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_CETF;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_CETVTA;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_PTG;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_PTG_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_PTG_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_PTG_2;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_PTG_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_PTG_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_PTG_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_TF;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_TF_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_TF_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_TF_2;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_TF_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_TF_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_TF_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TEMP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TEMP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_2;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_2
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TEMP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TEMP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ENEL_E4E_NEGATIVOS_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ENEL_E4E_NEGATIVOS_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ENEL_E4E_NEGATIVOS_TF;
            INSERT INTO EXT.SMM_ENEL_E4E_NEGATIVOS_TF
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ENEL_E4E_NEGATIVOS_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TMP2_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TMP2_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TMP2_ALIADO;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TMP2_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TMP2_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TMP2_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEGATIVOS_TMP2_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEGATIVOS_TMP2_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TMP2_CCDD;
            INSERT INTO EXT.SMM_E4E_NEGATIVOS_TMP2_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEGATIVOS_TMP2_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEGATIVOS_TMP2_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_E4E_NEG_TEMP_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_E4E_NEG_TEMP_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_E4E_NEG_TEMP_CAT_TVTA;
            INSERT INTO EXT.SMM_E4E_NEG_TEMP_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_E4E_NEG_TEMP_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_E4E_NEG_TEMP_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTCAT_TVTA_DEPOSITOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTCAT_TVTA_DEPOSITOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTCAT_TVTA_DEPOSITOS;
            INSERT INTO EXT.SMM_FACTCAT_TVTA_DEPOSITOS
                SELECT *               
                FROM EXT.SMM_ENEL_FACTCAT_TVTA_DEPOSITOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTCAT_TVTA_DEPOSITOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTCAT_TVTA_DETALLE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTCAT_TVTA_DETALLE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTCAT_TVTA_DETALLE;
            INSERT INTO EXT.SMM_FACTCAT_TVTA_DETALLE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTCAT_TVTA_DETALLE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTCAT_TVTA_DETALLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTCAT_TVTA_PORTADA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTCAT_TVTA_PORTADA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTCAT_TVTA_PORTADA;
            INSERT INTO EXT.SMM_FACTCAT_TVTA_PORTADA
                SELECT *               
                FROM EXT.SMM_ENEL_FACTCAT_TVTA_PORTADA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTCAT_TVTA_PORTADA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_FACTOPE_DETALLE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_DETALLE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_DETALLE;
            INSERT INTO EXT.SMM_FACTOPE_DETALLE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_DETALLE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_DETALLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_DETALLE_EE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_DETALLE_EE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_DETALLE_EE;
            INSERT INTO EXT.SMM_FACTOPE_DETALLE_EE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_DETALLE_EE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_DETALLE_EE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_DETALLE_EOSC
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_DETALLE_EOSC', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_DETALLE_EOSC;
            INSERT INTO EXT.SMM_FACTOPE_DETALLE_EOSC
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_DETALLE_EOSC;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_DETALLE_EOSC: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_FINAL_EE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_FINAL_EE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_FINAL_EE;
            INSERT INTO EXT.SMM_FACTOPE_FINAL_EE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_FINAL_EE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_FINAL_EE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_FINAL_EOSC
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_FINAL_EOSC', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_FINAL_EOSC;
            INSERT INTO EXT.SMM_FACTOPE_FINAL_EOSC
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_FINAL_EOSC;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_FINAL_EOSC: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_RESUMEN
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_RESUMEN', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_RESUMEN;
            INSERT INTO EXT.SMM_FACTOPE_RESUMEN
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_RESUMEN;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_RESUMEN: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_RESUMEN_EE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_RESUMEN_EE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_RESUMEN_EE;
            INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_RESUMEN_EE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_RESUMEN_EE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_RESUMEN_EOSC
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_RESUMEN_EOSC', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_RESUMEN_EOSC;
            INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EOSC
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_RESUMEN_EOSC;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_RESUMEN_EOSC: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_TOTAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_TOTAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_TOTAL;
            INSERT INTO EXT.SMM_FACTOPE_TOTAL
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_TOTAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_TOTAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_TOTAL_EE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_TOTAL_EE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_TOTAL_EE;
            INSERT INTO EXT.SMM_FACTOPE_TOTAL_EE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_TOTAL_EE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_TOTAL_EE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTOPE_TOTAL_EOSC
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTOPE_TOTAL_EOSC', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTOPE_TOTAL_EOSC;
            INSERT INTO EXT.SMM_FACTOPE_TOTAL_EOSC
                SELECT *               
                FROM EXT.SMM_ENEL_FACTOPE_TOTAL_EOSC;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTOPE_TOTAL_EOSC: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTPDS_DETALLE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTPDS_DETALLE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTPDS_DETALLE;
            INSERT INTO EXT.SMM_FACTPDS_DETALLE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTPDS_DETALLE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTPDS_DETALLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTPDS_DETALLE_BUNDLE
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTPDS_DETALLE_BUNDLE', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FACTPDS_DETALLE_BUNDLE;
            -- INSERT INTO EXT.SMM_FACTPDS_DETALLE_BUNDLE
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FACTPDS_DETALLE_BUNDLE;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTPDS_DETALLE_BUNDLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTPDS_PORTADA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTPDS_PORTADA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTPDS_PORTADA;
            INSERT INTO EXT.SMM_FACTPDS_PORTADA
                SELECT *               
                FROM EXT.SMM_ENEL_FACTPDS_PORTADA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTPDS_PORTADA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTTF_DETALLE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTTF_DETALLE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTTF_DETALLE;
            INSERT INTO EXT.SMM_FACTTF_DETALLE
                SELECT *               
                FROM EXT.SMM_ENEL_FACTTF_DETALLE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTTF_DETALLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FACTTF_PORTADA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FACTTF_PORTADA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FACTTF_PORTADA;
            INSERT INTO EXT.SMM_FACTTF_PORTADA
                SELECT *               
                FROM EXT.SMM_ENEL_FACTTF_PORTADA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FACTTF_PORTADA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FECHAS_WEBI
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FECHAS_WEBI', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FECHAS_WEBI;
            INSERT INTO EXT.SMM_FECHAS_WEBI
                SELECT *               
                FROM EXT.SMM_ENEL_FECHAS_WEBI;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FECHAS_WEBI: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_LIQ_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_ALIADOS;
            INSERT INTO EXT.SMM_FICHERO_LIQ_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_FICHERO_LIQ_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_LIQ_CEBP
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_CEBP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_CEBP;
            -- INSERT INTO EXT.SMM_FICHERO_LIQ_CEBP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQ_CEBP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_LIQ_CEIS
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_CEIS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_CEIS;
            -- INSERT INTO EXT.SMM_FICHERO_LIQ_CEIS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQ_CEIS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_LIQ_CESP
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_CESP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_CESP;
            -- INSERT INTO EXT.SMM_FICHERO_LIQ_CESP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQ_CESP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_LIQ_CETF
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_CETF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_CETF;
            -- INSERT INTO EXT.SMM_FICHERO_LIQ_CETF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQ_CETF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_LIQ_CETVTA
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_CETVTA', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_CETVTA;
            -- INSERT INTO EXT.SMM_FICHERO_LIQ_CETVTA
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQ_CETVTA;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_FICHERO_LIQ_PTG
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQ_PTG', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQ_PTG;
            -- INSERT INTO EXT.SMM_FICHERO_LIQ_PTG
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQ_PTG;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQ_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_FICHERO_LIQUIDACION
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQUIDACION', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_FICHERO_LIQUIDACION;
            INSERT INTO EXT.SMM_FICHERO_LIQUIDACION
                SELECT *               
                FROM EXT.SMM_ENEL_FICHERO_LIQUIDACION;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQUIDACION: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_FICHERO_LIQUIDACION_TF
--NO EXISTE EN PRD Y SÍ ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_LIQUIDACION_TF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_LIQUIDACION_TF;
            -- INSERT INTO EXT.SMM_FICHERO_LIQUIDACION_TF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_LIQUIDACION_TF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_LIQUIDACION_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_FICHERO_ORDTXNCRED
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_FICHERO_ORDTXNCRED', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_FICHERO_ORDTXNCRED;
            -- INSERT INTO EXT.SMM_FICHERO_ORDTXNCRED
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_FICHERO_ORDTXNCRED;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_FICHERO_ORDTXNCRED: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_GRAFICOS_CANAL_CES
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_GRAFICOS_CANAL_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_GRAFICOS_CANAL_CES;
            -- INSERT INTO EXT.SMM_GRAFICOS_CANAL_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_GRAFICOS_CANAL_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_GRAFICOS_CANAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_GRALPROV_DETALLE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_GRALPROV_DETALLE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_GRALPROV_DETALLE;
            INSERT INTO EXT.SMM_GRALPROV_DETALLE
                SELECT *               
                FROM EXT.SMM_ENEL_GRALPROV_DETALLE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_GRALPROV_DETALLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_GRALPROV_DETALLE_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_GRALPROV_DETALLE_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_GRALPROV_DETALLE_ALIADO;
            INSERT INTO EXT.SMM_GRALPROV_DETALLE_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_GRALPROV_DETALLE_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_GRALPROV_DETALLE_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_GRALPROV_DETALLE_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_GRALPROV_DETALLE_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_GRALPROV_DETALLE_CCDD;
            INSERT INTO EXT.SMM_GRALPROV_DETALLE_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_GRALPROV_DETALLE_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_GRALPROV_DETALLE_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_GRALPROV_DETALLE_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_GRALPROV_DETALLE_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_GRALPROV_DETALLE_TF;
            INSERT INTO EXT.SMM_GRALPROV_DETALLE_TF
                SELECT *               
                FROM EXT.SMM_ENEL_GRALPROV_DETALLE_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_GRALPROV_DETALLE_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_DTM;
            INSERT INTO EXT.SMM_INCEN_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_RAPPEL_ALICO
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_RAPPEL_ALICO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_INCEN_RAPPEL_ALICO;
            -- INSERT INTO EXT.SMM_INCEN_RAPPEL_ALICO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_INCEN_RAPPEL_ALICO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_RAPPEL_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCENT_AGRUPADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCENT_AGRUPADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCENT_AGRUPADO;
            INSERT INTO EXT.SMM_INCENT_AGRUPADO
                SELECT *               
                FROM EXT.SMM_ENEL_INCENT_AGRUPADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCENT_AGRUPADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP;
            INSERT INTO EXT.SMM_INCEN_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_ALIADO;
            INSERT INTO EXT.SMM_INCEN_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_ALICO;
            INSERT INTO EXT.SMM_INCEN_TEMP_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_CCDD;
            INSERT INTO EXT.SMM_INCEN_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_CEBP;
            INSERT INTO EXT.SMM_INCEN_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_CEIS;
            INSERT INTO EXT.SMM_INCEN_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_CESP;
            INSERT INTO EXT.SMM_INCEN_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_CETF;
            INSERT INTO EXT.SMM_INCEN_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_CETVTA;
            INSERT INTO EXT.SMM_INCEN_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_OFV;
            INSERT INTO EXT.SMM_INCEN_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCEN_TEMP_RESELLERS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_RESELLERS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_RESELLERS;
            INSERT INTO EXT.SMM_INCEN_TEMP_RESELLERS
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_RESELLERS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_RESELLERS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_INCEN_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TEMP_TF;
            INSERT INTO EXT.SMM_INCEN_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCENTIVO_CANAL_CES
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCENTIVO_CANAL_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_INCENTIVO_CANAL_CES;
            -- INSERT INTO EXT.SMM_INCENTIVO_CANAL_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_INCENTIVO_CANAL_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCENTIVO_CANAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_INCEN_TM2_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCEN_TM2_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCEN_TM2_ALICO;
            INSERT INTO EXT.SMM_INCEN_TM2_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_INCEN_TM2_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCEN_TM2_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INCIDENCIAS_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INCIDENCIAS_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INCIDENCIAS_DTM;
            INSERT INTO EXT.SMM_INCIDENCIAS_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_INCIDENCIAS_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INCIDENCIAS_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFORME_DISPUTAS_CES
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFORME_DISPUTAS_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_INFORME_DISPUTAS_CES;
            -- INSERT INTO EXT.SMM_INFORME_DISPUTAS_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_INFORME_DISPUTAS_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFORME_DISPUTAS_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFORME_ICISA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFORME_ICISA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFORME_ICISA;
            INSERT INTO EXT.SMM_INFORME_ICISA
                SELECT *               
                FROM EXT.SMM_ENEL_INFORME_ICISA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFORME_ICISA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFORME_STP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFORME_STP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFORME_STP;
            INSERT INTO EXT.SMM_INFORME_STP
                SELECT *               
                FROM EXT.SMM_ENEL_INFORME_STP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFORME_STP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFORME_TRANSACCION
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFORME_TRANSACCION', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFORME_TRANSACCION;
            INSERT INTO EXT.SMM_INFORME_TRANSACCION
                SELECT *               
                FROM EXT.SMM_ENEL_INFORME_TRANSACCION;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFORME_TRANSACCION: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFPDS_COMISIONES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFPDS_COMISIONES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFPDS_COMISIONES;
            INSERT INTO EXT.SMM_INFPDS_COMISIONES
                SELECT *               
                FROM EXT.SMM_ENEL_INFPDS_COMISIONES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFPDS_COMISIONES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFPDS_CREDIT_REVISION
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFPDS_CREDIT_REVISION', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFPDS_CREDIT_REVISION;
            INSERT INTO EXT.SMM_INFPDS_CREDIT_REVISION
                SELECT *               
                FROM EXT.SMM_ENEL_INFPDS_CREDIT_REVISION;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFPDS_CREDIT_REVISION: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFPDS_CREDIT_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFPDS_CREDIT_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFPDS_CREDIT_TEMP;
            INSERT INTO EXT.SMM_INFPDS_CREDIT_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_INFPDS_CREDIT_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFPDS_CREDIT_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFPDS_STP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFPDS_STP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFPDS_STP;
            INSERT INTO EXT.SMM_INFPDS_STP
                SELECT *               
                FROM EXT.SMM_ENEL_INFPDS_STP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFPDS_STP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_INFPDS_TXN_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_INFPDS_TXN_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_INFPDS_TXN_TEMP;
            INSERT INTO EXT.SMM_INFPDS_TXN_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_INFPDS_TXN_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_INFPDS_TXN_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LEADS_CAT_TVTA
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LEADS_CAT_TVTA', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_LEADS_CAT_TVTA;
            -- INSERT INTO EXT.SMM_LEADS_CAT_TVTA
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_LEADS_CAT_TVTA;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LEADS_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LEADS_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LEADS_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LEADS_CCDD;
            INSERT INTO EXT.SMM_LEADS_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_LEADS_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LEADS_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LEAD_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LEAD_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LEAD_TEMP_OFV;
            INSERT INTO EXT.SMM_LEAD_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_LEAD_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LEAD_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQ_FINAL_ASESOR
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQ_FINAL_ASESOR', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQ_FINAL_ASESOR;
            INSERT INTO EXT.SMM_LIQ_FINAL_ASESOR
                SELECT *               
                FROM EXT.SMM_ENEL_LIQ_FINAL_ASESOR;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQ_FINAL_ASESOR: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_BUNDLE
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_BUNDLE', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_BUNDLE;
            -- INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_BUNDLE
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_BUNDLE;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_BUNDLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_LEADS_WBE_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_ALIADOS;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_LEADS_WBE_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_LEADS_WBE_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_CCDD;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_LEADS_WBE_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF;
            -- INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_LEADS_WBE_TF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_TF;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_TF
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_WBE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_WBE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_WBE;
            INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_WBE
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_WBE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_WBE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_WBE_BUNDLE
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_WBE_BUNDLE', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_WBE_BUNDLE;
            -- INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_WBE_BUNDLE
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_WBE_BUNDLE;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_WBE_BUNDLE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_FINAL_WBE_CCDD
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_FINAL_WBE_CCDD', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_LIQSCAWEB_FINAL_WBE_CCDD;
            -- INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_WBE_CCDD
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_LIQSCAWEB_FINAL_WBE_CCDD;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_FINAL_WBE_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_LIQSCAWEB_INF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_INF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_INF;
            INSERT INTO EXT.SMM_LIQSCAWEB_INF
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_INF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_INF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_INF_TF
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_INF_TF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_LIQSCAWEB_INF_TF;
            -- INSERT INTO EXT.SMM_LIQSCAWEB_INF_TF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_LIQSCAWEB_INF_TF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_INF_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQSCAWEB_RENOV_AAFF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_RENOV_AAFF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_RENOV_AAFF;
            INSERT INTO EXT.SMM_LIQSCAWEB_RENOV_AAFF
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_RENOV_AAFF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_RENOV_AAFF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_LIQSCAWEB_RENOV_VR
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQSCAWEB_RENOV_VR', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQSCAWEB_RENOV_VR;
            INSERT INTO EXT.SMM_LIQSCAWEB_RENOV_VR
                SELECT *               
                FROM EXT.SMM_ENEL_LIQSCAWEB_RENOV_VR;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQSCAWEB_RENOV_VR: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQUIDACION_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQUIDACION_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQUIDACION_CEBP;
            INSERT INTO EXT.SMM_LIQUIDACION_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_LIQUIDACION_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQUIDACION_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQUIDACION_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQUIDACION_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQUIDACION_CEIS;
            INSERT INTO EXT.SMM_LIQUIDACION_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_LIQUIDACION_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQUIDACION_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQUIDACION_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQUIDACION_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQUIDACION_CESP;
            INSERT INTO EXT.SMM_LIQUIDACION_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_LIQUIDACION_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQUIDACION_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQUIDACION_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQUIDACION_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQUIDACION_CETF;
            INSERT INTO EXT.SMM_LIQUIDACION_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_LIQUIDACION_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQUIDACION_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_LIQUIDACION_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_LIQUIDACION_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_LIQUIDACION_CETVTA;
            INSERT INTO EXT.SMM_LIQUIDACION_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_LIQUIDACION_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_LIQUIDACION_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_CANAL_CES
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_CANAL_CES', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_MEDIDAS_CANAL_CES;
            -- INSERT INTO EXT.SMM_MEDIDAS_CANAL_CES
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_MEDIDAS_CANAL_CES;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_CANAL_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_FINAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_FINAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_FINAL;
            INSERT INTO EXT.SMM_MEDIDAS_FINAL
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_FINAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_FINAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_FINAL_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_FINAL_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_FINAL_OFV;
            INSERT INTO EXT.SMM_MEDIDAS_FINAL_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_FINAL_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_FINAL_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_FINAL_PSVA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_FINAL_PSVA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_FINAL_PSVA;
            INSERT INTO EXT.SMM_MEDIDAS_FINAL_PSVA
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_FINAL_PSVA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_FINAL_PSVA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_FINAL_VOL_GAS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_FINAL_VOL_GAS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_FINAL_VOL_GAS;
            INSERT INTO EXT.SMM_MEDIDAS_FINAL_VOL_GAS
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_FINAL_VOL_GAS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_FINAL_VOL_GAS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_MEDIDAS_FINAL_VOLUMEN
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_FINAL_VOLUMEN', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_FINAL_VOLUMEN;
            INSERT INTO EXT.SMM_MEDIDAS_FINAL_VOLUMEN
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_FINAL_VOLUMEN;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_FINAL_VOLUMEN: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_FINAL_V_RENTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_FINAL_V_RENTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_FINAL_V_RENTA;
            INSERT INTO EXT.SMM_MEDIDAS_FINAL_V_RENTA
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_FINAL_V_RENTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_FINAL_V_RENTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_MEDIDAS_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_MEDIDAS_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP_CEBP;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP_CEIS;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_MEDIDAS_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP_CESP;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP_CETF;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP_CETVTA;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_MEDIDAS_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_MEDIDAS_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP_OFV;
            INSERT INTO EXT.SMM_MEDIDAS_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_MEDIDAS_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_MEDIDAS_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_NEW_CONSECUCION_FINAL_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_NEW_CONSECUCION_FINAL_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_NEW_CONSECUCION_FINAL_OFV;
            INSERT INTO EXT.SMM_NEW_CONSECUCION_FINAL_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_NEW_CONSECUCION_FINAL_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_NEW_CONSECUCION_FINAL_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_NEW_CONSECUCION_FINAL_OFV21
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_NEW_CONSECUCION_FINAL_OFV21', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_NEW_CONSECUCION_FINAL_OFV21;
            -- INSERT INTO EXT.SMM_NEW_CONSECUCION_FINAL_OFV21
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_NEW_CONSECUCION_FINAL_OFV21;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_NEW_CONSECUCION_FINAL_OFV21: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_NEW_CONSECUCION_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_NEW_CONSECUCION_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_NEW_CONSECUCION_TEMP_OFV;
            INSERT INTO EXT.SMM_NEW_CONSECUCION_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_NEW_CONSECUCION_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_NEW_CONSECUCION_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_NEW_CONSECUCION_TEMP_OFV21
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_NEW_CONSECUCION_TEMP_OFV21', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_NEW_CONSECUCION_TEMP_OFV21;
            -- INSERT INTO EXT.SMM_NEW_CONSECUCION_TEMP_OFV21
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_NEW_CONSECUCION_TEMP_OFV21;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_NEW_CONSECUCION_TEMP_OFV21: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_NEW_CONSECUCION_TEMP2_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_NEW_CONSECUCION_TEMP2_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_NEW_CONSECUCION_TEMP2_OFV;
            INSERT INTO EXT.SMM_NEW_CONSECUCION_TEMP2_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_NEW_CONSECUCION_TEMP2_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_NEW_CONSECUCION_TEMP2_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_NEW_CONSECUCION_TEMP2_OFV21
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_NEW_CONSECUCION_TEMP2_OFV21', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_NEW_CONSECUCION_TEMP2_OFV21;
            -- INSERT INTO EXT.SMM_NEW_CONSECUCION_TEMP2_OFV21
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_NEW_CONSECUCION_TEMP2_OFV21;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_NEW_CONSECUCION_TEMP2_OFV21: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



--SMM_OFV_BORRADO
--NO EXISTE EN PRD Y SÍ ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_OFV_BORRADO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_OFV_BORRADO;
            -- INSERT INTO EXT.SMM_OFV_BORRADO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_OFV_BORRADO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_OFV_BORRADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_OPERACION_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_OPERACION_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_OPERACION_DTM;
            INSERT INTO EXT.SMM_OPERACION_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_OPERACION_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_OPERACION_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_OPERACIONES_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_OPERACIONES_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_OPERACIONES_TEMP;
            INSERT INTO EXT.SMM_OPERACIONES_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_OPERACIONES_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_OPERACIONES_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_OPERACIONES_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_OPERACIONES_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_OPERACIONES_TEMP_OFV;
            INSERT INTO EXT.SMM_OPERACIONES_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_OPERACIONES_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_OPERACIONES_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_OPERACIONES_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_OPERACIONES_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_OPERACIONES_TEMP_TF;
            INSERT INTO EXT.SMM_OPERACIONES_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_OPERACIONES_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_OPERACIONES_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_OPERACIONES_UB_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_OPERACIONES_UB_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_OPERACIONES_UB_TEMP;
            INSERT INTO EXT.SMM_OPERACIONES_UB_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_OPERACIONES_UB_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_OPERACIONES_UB_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ORDER_IMPU_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ORDER_IMPU_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ORDER_IMPU_TEMP_CEBP;
            INSERT INTO EXT.SMM_ORDER_IMPU_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_ORDER_IMPU_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ORDER_IMPU_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ORDER_IMPU_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ORDER_IMPU_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ORDER_IMPU_TEMP_CEIS;
            INSERT INTO EXT.SMM_ORDER_IMPU_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_ORDER_IMPU_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ORDER_IMPU_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ORDER_IMPU_TEMP_CEIS_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ORDER_IMPU_TEMP_CEIS_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ORDER_IMPU_TEMP_CEIS_2;
            INSERT INTO EXT.SMM_ORDER_IMPU_TEMP_CEIS_2
                SELECT *               
                FROM EXT.SMM_ENEL_ORDER_IMPU_TEMP_CEIS_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ORDER_IMPU_TEMP_CEIS_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ORDER_IMPU_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ORDER_IMPU_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ORDER_IMPU_TEMP_CESP;
            INSERT INTO EXT.SMM_ORDER_IMPU_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_ORDER_IMPU_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ORDER_IMPU_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ORDER_IMPU_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ORDER_IMPU_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ORDER_IMPU_TEMP_CETF;
            INSERT INTO EXT.SMM_ORDER_IMPU_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_ORDER_IMPU_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ORDER_IMPU_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_ORDER_IMPU_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_ORDER_IMPU_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_ORDER_IMPU_TEMP_CETVTA;
            INSERT INTO EXT.SMM_ORDER_IMPU_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_ORDER_IMPU_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_ORDER_IMPU_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PAGOS_RESUMEN
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PAGOS_RESUMEN', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PAGOS_RESUMEN;
            INSERT INTO EXT.SMM_PAGOS_RESUMEN
                SELECT *               
                FROM EXT.SMM_ENEL_PAGOS_RESUMEN;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PAGOS_RESUMEN: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PAGOS_RESUMEN_TF
--NO EXISTE EN PRD Y SÍ ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PAGOS_RESUMEN_TF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_PAGOS_RESUMEN_TF;
            -- INSERT INTO EXT.SMM_PAGOS_RESUMEN_TF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_PAGOS_RESUMEN_TF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PAGOS_RESUMEN_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PARTICIPANTES_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PARTICIPANTES_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PARTICIPANTES_DTM;
            INSERT INTO EXT.SMM_PARTICIPANTES_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_PARTICIPANTES_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PARTICIPANTES_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PAYEE_TEMP_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PAYEE_TEMP_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PAYEE_TEMP_CAT_TVTA;
            INSERT INTO EXT.SMM_PAYEE_TEMP_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_PAYEE_TEMP_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PAYEE_TEMP_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP;
            INSERT INTO EXT.SMM_PDS_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_ALIADO;
            INSERT INTO EXT.SMM_PDS_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_ALICO;
            INSERT INTO EXT.SMM_PDS_TEMP_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CCDD;
            INSERT INTO EXT.SMM_PDS_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CEBP;
            INSERT INTO EXT.SMM_PDS_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CEIS;
            INSERT INTO EXT.SMM_PDS_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CEIS_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CEIS_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CEIS_2;
            INSERT INTO EXT.SMM_PDS_TEMP_CEIS_2
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CEIS_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CEIS_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CESP;
            INSERT INTO EXT.SMM_PDS_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CETF;
            INSERT INTO EXT.SMM_PDS_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_CETVTA;
            INSERT INTO EXT.SMM_PDS_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_OFV;
            INSERT INTO EXT.SMM_PDS_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PDS_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PDS_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PDS_TEMP_TF;
            INSERT INTO EXT.SMM_PDS_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_PDS_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PDS_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PERIODO_LIQUIDADOS_ALIADO
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PERIODO_LIQUIDADOS_ALIADO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_PERIODO_LIQUIDADOS_ALIADO;
            -- INSERT INTO EXT.SMM_PERIODO_LIQUIDADOS_ALIADO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_PERIODO_LIQUIDADOS_ALIADO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PERIODO_LIQUIDADOS_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PERIODOS_LIQ_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PERIODOS_LIQ_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PERIODOS_LIQ_ALIADOS;
            INSERT INTO EXT.SMM_PERIODOS_LIQ_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_PERIODOS_LIQ_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PERIODOS_LIQ_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PERIODOS_LIQ_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PERIODOS_LIQ_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PERIODOS_LIQ_CCDD;
            INSERT INTO EXT.SMM_PERIODOS_LIQ_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PERIODOS_LIQ_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PERIODOS_LIQ_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PERIODOS_LIQ_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PERIODOS_LIQ_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PERIODOS_LIQ_PTG;
            INSERT INTO EXT.SMM_PERIODOS_LIQ_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_PERIODOS_LIQ_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PERIODOS_LIQ_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PERIODOS_LIQUIDADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PERIODOS_LIQUIDADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PERIODOS_LIQUIDADOS;
            INSERT INTO EXT.SMM_PERIODOS_LIQUIDADOS
                SELECT *               
                FROM EXT.SMM_ENEL_PERIODOS_LIQUIDADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PERIODOS_LIQUIDADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PERIODOS_LIQUIDADOS_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PERIODOS_LIQUIDADOS_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PERIODOS_LIQUIDADOS_TF;
            INSERT INTO EXT.SMM_PERIODOS_LIQUIDADOS_TF
                SELECT *               
                FROM EXT.SMM_ENEL_PERIODOS_LIQUIDADOS_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PERIODOS_LIQUIDADOS_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PER_LIQUIDADOS_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PER_LIQUIDADOS_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PER_LIQUIDADOS_CAT_TVTA;
            INSERT INTO EXT.SMM_PER_LIQUIDADOS_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_PER_LIQUIDADOS_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PER_LIQUIDADOS_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PER_LIQUIDADOS_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PER_LIQUIDADOS_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PER_LIQUIDADOS_CES;
            INSERT INTO EXT.SMM_PER_LIQUIDADOS_CES
                SELECT *               
                FROM EXT.SMM_ENEL_PER_LIQUIDADOS_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PER_LIQUIDADOS_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_POSITION_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_POSITION_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_POSITION_DTM;
            INSERT INTO EXT.SMM_POSITION_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_POSITION_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_POSITION_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACT_DETALLE_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACT_DETALLE_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACT_DETALLE_ALIADO;
            INSERT INTO EXT.SMM_PREFACT_DETALLE_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACT_DETALLE_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACT_DETALLE_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACT_DETALLE_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACT_DETALLE_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACT_DETALLE_CCDD;
            INSERT INTO EXT.SMM_PREFACT_DETALLE_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACT_DETALLE_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACT_DETALLE_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACT_PORTADA_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACT_PORTADA_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACT_PORTADA_ALIADO;
            INSERT INTO EXT.SMM_PREFACT_PORTADA_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACT_PORTADA_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACT_PORTADA_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACT_PORTADA_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACT_PORTADA_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACT_PORTADA_CCDD;
            INSERT INTO EXT.SMM_PREFACT_PORTADA_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACT_PORTADA_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACT_PORTADA_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACTURA_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CCDD;
            INSERT INTO EXT.SMM_PREFACTURA_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACTURA_CCDD_RESELLERS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CCDD_RESELLERS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CCDD_RESELLERS;
            INSERT INTO EXT.SMM_PREFACTURA_CCDD_RESELLERS
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CCDD_RESELLERS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CCDD_RESELLERS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_PREFACTURA_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CEBP;
            INSERT INTO EXT.SMM_PREFACTURA_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACTURA_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CEIS;
            INSERT INTO EXT.SMM_PREFACTURA_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACTURA_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CESP;
            INSERT INTO EXT.SMM_PREFACTURA_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACTURA_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CETF;
            INSERT INTO EXT.SMM_PREFACTURA_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREFACTURA_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREFACTURA_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PREFACTURA_CETVTA;
            INSERT INTO EXT.SMM_PREFACTURA_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_PREFACTURA_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREFACTURA_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PREOVEEDORES_TEMP_ALICO
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PREOVEEDORES_TEMP_ALICO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_PREOVEEDORES_TEMP_ALICO;
            -- INSERT INTO EXT.SMM_PREOVEEDORES_TEMP_ALICO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_PREOVEEDORES_TEMP_ALICO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PREOVEEDORES_TEMP_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRODUCTOS_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRODUCTOS_DTM;
            INSERT INTO EXT.SMM_PRODUCTOS_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_PRODUCTOS_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRODUCTOS_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP;
            INSERT INTO EXT.SMM_PRODUCTOS_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_PRODUCTOS_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRODUCTOS_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP_ALIADO;
            INSERT INTO EXT.SMM_PRODUCTOS_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_PRODUCTOS_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_PRODUCTOS_TEMP_CAT_TVTA
--NO EXISTE EN PRD Y SÍ ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_TEMP_CAT_TVTA', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP_CAT_TVTA;
            -- INSERT INTO EXT.SMM_PRODUCTOS_TEMP_CAT_TVTA
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_PRODUCTOS_TEMP_CAT_TVTA;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_TEMP_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRODUCTOS_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP_CCDD;
            INSERT INTO EXT.SMM_PRODUCTOS_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PRODUCTOS_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRODUCTOS_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP_OFV;
            INSERT INTO EXT.SMM_PRODUCTOS_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_PRODUCTOS_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRODUCTOS_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRODUCTOS_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP_TF;
            INSERT INTO EXT.SMM_PRODUCTOS_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_PRODUCTOS_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRODUCTOS_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_DTM;
            INSERT INTO EXT.SMM_PROVEEDORES_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_ALIADO;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_ALICO;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_CCDD;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_OFV;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_PTG
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_PTG', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_PTG;
            -- INSERT INTO EXT.SMM_PROVEEDORES_TEMP_PTG
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_PTG;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PROVEEDORES_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PROVEEDORES_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP_TF;
            INSERT INTO EXT.SMM_PROVEEDORES_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_PROVEEDORES_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PROVEEDORES_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_PRUEBA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_PRUEBA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_PRUEBA;
            INSERT INTO EXT.SMM_PRUEBA
                SELECT *               
                FROM EXT.SMM_ENEL_PRUEBA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_PRUEBA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES;
            INSERT INTO EXT.SMM_RAPPELES
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_ALIADO;
            INSERT INTO EXT.SMM_RAPPELES_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_ALICO;
            INSERT INTO EXT.SMM_RAPPELES_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_CCDD;
            INSERT INTO EXT.SMM_RAPPELES_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_CES;
            INSERT INTO EXT.SMM_RAPPELES_CES
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_COMPLETO
--SIN USO. SE MIGRA A SI MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_COMPLETO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_RAPPELES_COMPLETO;
            -- INSERT INTO EXT.SMM_RAPPELES_COMPLETO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_RAPPELES_COMPLETO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_COMPLETO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_LIQ_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_LIQ_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_LIQ_CCDD;
            INSERT INTO EXT.SMM_RAPPELES_LIQ_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_LIQ_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_LIQ_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_RAPPELES_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_TF;
            INSERT INTO EXT.SMM_RAPPELES_TF
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RAPPELES_WBE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_WBE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_WBE;
            INSERT INTO EXT.SMM_RAPPELES_WBE
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_WBE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_WBE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_RAPPELES_WBE_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RAPPELES_WBE_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RAPPELES_WBE_ALICO;
            INSERT INTO EXT.SMM_RAPPELES_WBE_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_RAPPELES_WBE_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RAPPELES_WBE_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REGISTROS_COMMISSION_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REGISTROS_COMMISSION_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REGISTROS_COMMISSION_CES;
            INSERT INTO EXT.SMM_REGISTROS_COMMISSION_CES
                SELECT *               
                FROM EXT.SMM_ENEL_REGISTROS_COMMISSION_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REGISTROS_COMMISSION_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REGISTROS_CRED_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REGISTROS_CRED_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REGISTROS_CRED_CES;
            INSERT INTO EXT.SMM_REGISTROS_CRED_CES
                SELECT *               
                FROM EXT.SMM_ENEL_REGISTROS_CRED_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REGISTROS_CRED_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REGISTROS_TXN_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REGISTROS_TXN_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REGISTROS_TXN_CES;
            INSERT INTO EXT.SMM_REGISTROS_TXN_CES
                SELECT *               
                FROM EXT.SMM_ENEL_REGISTROS_TXN_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REGISTROS_TXN_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REGULARIZACION_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REGULARIZACION_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REGULARIZACION_ALIADOS;
            INSERT INTO EXT.SMM_REGULARIZACION_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_REGULARIZACION_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REGULARIZACION_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REGULARIZACION_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REGULARIZACION_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REGULARIZACION_CCDD;
            INSERT INTO EXT.SMM_REGULARIZACION_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_REGULARIZACION_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REGULARIZACION_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REMUN
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REMUN', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REMUN;
            INSERT INTO EXT.SMM_REMUN
                SELECT *               
                FROM EXT.SMM_ENEL_REMUN;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REMUN: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REMUN_CES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REMUN_CES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_REMUN_CES;
            INSERT INTO EXT.SMM_REMUN_CES
                SELECT *               
                FROM EXT.SMM_ENEL_REMUN_CES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REMUN_CES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_REMUN_TF
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_REMUN_TF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_REMUN_TF;
            -- INSERT INTO EXT.SMM_REMUN_TF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_REMUN_TF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_REMUN_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RENOVACION_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RENOVACION_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RENOVACION_ALIADOS;
            INSERT INTO EXT.SMM_RENOVACION_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_RENOVACION_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RENOVACION_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RENOVACION_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RENOVACION_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RENOVACION_CCDD;
            INSERT INTO EXT.SMM_RENOVACION_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_RENOVACION_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RENOVACION_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RESELLER_TM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RESELLER_TM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RESELLER_TM;
            INSERT INTO EXT.SMM_RESELLER_TM
                SELECT *               
                FROM EXT.SMM_ENEL_RESELLER_TM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RESELLER_TM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RESUMEN_LIQ_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RESUMEN_LIQ_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RESUMEN_LIQ_ALICO;
            INSERT INTO EXT.SMM_RESUMEN_LIQ_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_RESUMEN_LIQ_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RESUMEN_LIQ_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_RESUMEN_LIQ_ALICO_D2D
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RESUMEN_LIQ_ALICO_D2D', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_RESUMEN_LIQ_ALICO_D2D;
            -- INSERT INTO EXT.SMM_RESUMEN_LIQ_ALICO_D2D
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_RESUMEN_LIQ_ALICO_D2D;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RESUMEN_LIQ_ALICO_D2D: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_RESUMEN_LIQ_RES_ONL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_RESUMEN_LIQ_RES_ONL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_RESUMEN_LIQ_RES_ONL;
            INSERT INTO EXT.SMM_RESUMEN_LIQ_RES_ONL
                SELECT *               
                FROM EXT.SMM_ENEL_RESUMEN_LIQ_RES_ONL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_RESUMEN_LIQ_RES_ONL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SCAWEB_LIQUIDACION
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SCAWEB_LIQUIDACION_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_ALIADO;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');




--SMM_SCAWEB_LIQUIDACION_CAT_TVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_CAT_TVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_CAT_TVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_CAT_TVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SCAWEB_LIQUIDACION_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_CCDD;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SCAWEB_LIQUIDACION_INF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_INF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_INF;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_INF
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_INF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_INF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SCAWEB_LIQUIDACION_INF_TF
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_INF_TF', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_INF_TF;
            -- INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_INF_TF
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_INF_TF;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_INF_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_SCAWEB_LIQUIDACION_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_PTG;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SCAWEB_LIQUIDACION_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SCAWEB_LIQUIDACION_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SCAWEB_LIQUIDACION_TF;
            INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_TF
                SELECT *               
                FROM EXT.SMM_ENEL_SCAWEB_LIQUIDACION_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SCAWEB_LIQUIDACION_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_SERVICIOS_DTM
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_SERVICIOS_DTM', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_SERVICIOS_DTM;
            INSERT INTO EXT.SMM_SERVICIOS_DTM
                SELECT *               
                FROM EXT.SMM_ENEL_SERVICIOS_DTM;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_SERVICIOS_DTM: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TASA_ARRASTRE
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TASA_ARRASTRE', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TASA_ARRASTRE;
            -- INSERT INTO EXT.SMM_TASA_ARRASTRE
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TASA_ARRASTRE;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TASA_ARRASTRE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TASA_FIDELIZACION
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TASA_FIDELIZACION', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TASA_FIDELIZACION;
            -- INSERT INTO EXT.SMM_TASA_FIDELIZACION
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TASA_FIDELIZACION;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TASA_FIDELIZACION: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TASA_FIDELIZACION_ALTAS
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TASA_FIDELIZACION_ALTAS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TASA_FIDELIZACION_ALTAS;
            -- INSERT INTO EXT.SMM_TASA_FIDELIZACION_ALTAS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TASA_FIDELIZACION_ALTAS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TASA_FIDELIZACION_ALTAS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TASA_FIDELIZACION_BONUS
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TASA_FIDELIZACION_BONUS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TASA_FIDELIZACION_BONUS;
            -- INSERT INTO EXT.SMM_TASA_FIDELIZACION_BONUS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TASA_FIDELIZACION_BONUS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TASA_FIDELIZACION_BONUS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TDF_ALTAS_ASESOR
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDF_ALTAS_ASESOR', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TDF_ALTAS_ASESOR;
            -- INSERT INTO EXT.SMM_TDF_ALTAS_ASESOR
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TDF_ALTAS_ASESOR;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDF_ALTAS_ASESOR: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TDF_ASESOR
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDF_ASESOR', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TDF_ASESOR;
            -- INSERT INTO EXT.SMM_TDF_ASESOR
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TDF_ASESOR;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDF_ASESOR: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TDF_BONUS_ASESOR
--SIN USO. SE MIGRA A SÍ MISMA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDF_BONUS_ASESOR', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TDF_BONUS_ASESOR;
            -- INSERT INTO EXT.SMM_TDF_BONUS_ASESOR
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TDF_BONUS_ASESOR;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDF_BONUS_ASESOR: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TDM_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDM_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TDM_ALIADOS;
            INSERT INTO EXT.SMM_TDM_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_TDM_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDM_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TDM_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDM_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TDM_CCDD;
            INSERT INTO EXT.SMM_TDM_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_TDM_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDM_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TDM2_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDM2_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TDM2_CCDD;
            INSERT INTO EXT.SMM_TDM2_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_TDM2_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDM2_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TDM2_PTG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TDM2_PTG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TDM2_PTG;
            INSERT INTO EXT.SMM_TDM2_PTG
                SELECT *               
                FROM EXT.SMM_ENEL_TDM2_PTG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TDM2_PTG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TF_APROVISIONAMIENTO
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TF_APROVISIONAMIENTO', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TF_APROVISIONAMIENTO;
            -- INSERT INTO EXT.SMM_TF_APROVISIONAMIENTO
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TF_APROVISIONAMIENTO;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TF_APROVISIONAMIENTO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TM_MENSUAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM_MENSUAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM_MENSUAL;
            INSERT INTO EXT.SMM_TM_MENSUAL
                SELECT *               
                FROM EXT.SMM_ENEL_TM_MENSUAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM_MENSUAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TM12_ALIADOS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM12_ALIADOS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM12_ALIADOS;
            INSERT INTO EXT.SMM_TM12_ALIADOS
                SELECT *               
                FROM EXT.SMM_ENEL_TM12_ALIADOS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM12_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TM12_MENSUAL_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM12_MENSUAL_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM12_MENSUAL_TF;
            INSERT INTO EXT.SMM_TM12_MENSUAL_TF
                SELECT *               
                FROM EXT.SMM_ENEL_TM12_MENSUAL_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM12_MENSUAL_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TM18_ALIADOS
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM18_ALIADOS', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TM18_ALIADOS;
            -- INSERT INTO EXT.SMM_TM18_ALIADOS
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TM18_ALIADOS;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM18_ALIADOS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TM2_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM2_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM2_CCDD;
            INSERT INTO EXT.SMM_TM2_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_TM2_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM2_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TM2_MENSUAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM2_MENSUAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM2_MENSUAL;
            INSERT INTO EXT.SMM_TM2_MENSUAL
                SELECT *               
                FROM EXT.SMM_ENEL_TM2_MENSUAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM2_MENSUAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TM2_MENSUAL_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM2_MENSUAL_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM2_MENSUAL_TF;
            INSERT INTO EXT.SMM_TM2_MENSUAL_TF
                SELECT *               
                FROM EXT.SMM_ENEL_TM2_MENSUAL_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM2_MENSUAL_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TM6_MENSUAL
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TM6_MENSUAL', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TM6_MENSUAL;
            INSERT INTO EXT.SMM_TM6_MENSUAL
                SELECT *               
                FROM EXT.SMM_ENEL_TM6_MENSUAL;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TM6_MENSUAL: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TRANSACTION_PRUEBA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TRANSACTION_PRUEBA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TRANSACTION_PRUEBA;
            INSERT INTO EXT.SMM_TRANSACTION_PRUEBA
                SELECT *               
                FROM EXT.SMM_ENEL_TRANSACTION_PRUEBA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TRANSACTION_PRUEBA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_DTM_TEMP
--NO EXISTE EN PRD Y NO ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_DTM_TEMP', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMM_TXN_DTM_TEMP;
            -- INSERT INTO EXT.SMM_TXN_DTM_TEMP
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TXN_DTM_TEMP;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_DTM_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP;
            INSERT INTO EXT.SMM_TXN_TEMP
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TXN_TEMP_ALIADO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_ALIADO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_ALIADO;
            INSERT INTO EXT.SMM_TXN_TEMP_ALIADO
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_ALIADO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_ALIADO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_ALICO
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_ALICO', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_ALICO;
            INSERT INTO EXT.SMM_TXN_TEMP_ALICO
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_ALICO;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_ALICO: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_ALICO_V2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_ALICO_V2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_ALICO_V2;
            INSERT INTO EXT.SMM_TXN_TEMP_ALICO_V2
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_ALICO_V2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_ALICO_V2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CCDD
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CCDD', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CCDD;
            INSERT INTO EXT.SMM_TXN_TEMP_CCDD
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CCDD;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CCDD: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');

--SMM_TXN_TEMP_CEBP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CEBP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CEBP;
            INSERT INTO EXT.SMM_TXN_TEMP_CEBP
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CEBP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CEBP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CEBP_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CEBP_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CEBP_2;
            INSERT INTO EXT.SMM_TXN_TEMP_CEBP_2
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CEBP_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CEBP_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CEIS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CEIS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CEIS;
            INSERT INTO EXT.SMM_TXN_TEMP_CEIS
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CEIS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CEIS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CEIS_2
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CEIS_2', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CEIS_2;
            INSERT INTO EXT.SMM_TXN_TEMP_CEIS_2
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CEIS_2;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CEIS_2: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CESP
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CESP', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CESP;
            INSERT INTO EXT.SMM_TXN_TEMP_CESP
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CESP;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CESP: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CETF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CETF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CETF;
            INSERT INTO EXT.SMM_TXN_TEMP_CETF
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CETF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CETF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_CETVTA
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_CETVTA', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_CETVTA;
            INSERT INTO EXT.SMM_TXN_TEMP_CETVTA
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_CETVTA;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_CETVTA: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_D2D
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_D2D', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_D2D;
            INSERT INTO EXT.SMM_TXN_TEMP_D2D
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_D2D;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_D2D: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_LOJAS
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_LOJAS', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_LOJAS;
            INSERT INTO EXT.SMM_TXN_TEMP_LOJAS
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_LOJAS;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_LOJAS: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_OFV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_OFV', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_OFV;
            INSERT INTO EXT.SMM_TXN_TEMP_OFV
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_OFV;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_OFV: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_ONLINE
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_ONLINE', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_ONLINE;
            INSERT INTO EXT.SMM_TXN_TEMP_ONLINE
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_ONLINE;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_ONLINE: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_RESELLER
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_RESELLER', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_RESELLER;
            INSERT INTO EXT.SMM_TXN_TEMP_RESELLER
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_RESELLER;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_RESELLER: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMML_TXN_TEMP_STAND
--NO EXISTE EN PRD Y SÍ ESTÁ EN USO EN DEV
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMML_TXN_TEMP_STAND', v_log_count, v_idproceso, 'info');
            -- TRUNCATE TABLE EXT.SMML_TXN_TEMP_STAND;
            -- INSERT INTO EXT.SMML_TXN_TEMP_STAND
            --     SELECT *               
            --     FROM EXT.SMM_ENEL_TXN_TEMP_STAND;
            -- v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_STAND: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_STORES
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_STORES', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_STORES;
            INSERT INTO EXT.SMM_TXN_TEMP_STORES
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_STORES;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_STORES: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_TXN_TEMP_TF
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_TXN_TEMP_TF', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_TXN_TEMP_TF;
            INSERT INTO EXT.SMM_TXN_TEMP_TF
                SELECT *               
                FROM EXT.SMM_ENEL_TXN_TEMP_TF;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_TXN_TEMP_TF: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');


--SMM_CODEMAP_CONFIG
        --CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'TABLA A PROCESAR = ' || 'SMM_CODEMAP_CONFIG', v_log_count, v_idproceso, 'info');
            TRUNCATE TABLE EXT.SMM_CODEMAP_CONFIG;
            INSERT INTO EXT.SMM_CODEMAP_CONFIG
                SELECT *               
                FROM EXT.SMM_ODX_CODEMAP_CONFIG;
            v_num_rows := ::ROWCOUNT;
        CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'SMM_CODEMAP_CONFIG: ' || ' cargada correctamente. Filas: ' || v_num_rows, v_log_count, v_idproceso, 'info');



CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');



END