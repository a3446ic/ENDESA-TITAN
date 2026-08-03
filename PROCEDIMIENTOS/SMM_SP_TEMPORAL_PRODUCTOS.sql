CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_PRODUCTOS( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de Productos a una Temporal de Equipamiento
    |
	| Version:	0.1	SMM	   Initial Version.
	|
    -----------------------------------------------------------------------
*/
BEGIN
    DECLARE v_cont INT = 0;
	DECLARE v_proc_name NVARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version NVARCHAR(4) := '0.1';
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_idproceso BIGINT := 0;
	DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
	DECLARE v_permisos_log NVARCHAR(50) := EXT.LIB_GLOBAL_ENDESA:GET_PERMISOS_LOG();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	DECLARE v_finicio TIMESTAMP = CURRENT_TIMESTAMP;
	DECLARE v_contador_ctrl_inf INT;
	DECLARE v_num_ejecucion INT;
	DECLARE v_ultimo_dia_periodo DATE;
	

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	
	v_ultimo_dia_periodo := EXT.SMM_F_ULTIMO_DIA_PERIODO(i_periodseq);
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: '
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		|| ' || v_ultimo_dia_periodo: ' || v_ultimo_dia_periodo
		, v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_PRODUCTOS_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_PRODUCTOS_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tabla SMM_PRODUCTOS_TEMP.', v_log_count, v_idproceso,'info');
	
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_PRODUCTOS_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_PRODUCTOS_TEMP( TENANTID, PERIODSEQ, PRODUCTID, DESCRIPTION, NAME, FAMILIA, PROVEEDOR_PRESTACION, PROVEEDOR_CAPTACION, 
                                              SEGMENTO, TIPO, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR)
    SELECT 
        v_tenantid TENANTID,
        i_periodseq PERIODSEQ,
        C.CLASSIFIERID AS PRODUCTID,
        C.DESCRIPTION,
        C.NAME,
        PROD.GENERICATTRIBUTE1 as FAMILIA,
        PROD.GENERICATTRIBUTE2 as PROVEEDOR_PRESTACION,
        PROD.GENERICATTRIBUTE3 as PROVEEDOR_CAPTACION,
        PROD.GENERICATTRIBUTE4 as SEGMENTO,
        PROD.GENERICATTRIBUTE5 as TIPO,
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR
            
    FROM CS_PRODUCT PROD 
        INNER JOIN CS_CLASSIFIER C ON C.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ
            AND C.TENANTID = v_tenantid
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo                                     
            --AND C.ISLAST = 1
    
    WHERE PROD.REMOVEDATE = v_eot
        AND PROD.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
        AND PROD.EFFECTIVEENDDATE >= v_ultimo_dia_periodo
        AND PROD.TENANTID = v_tenantid; 

    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_PRODUCTOS_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;