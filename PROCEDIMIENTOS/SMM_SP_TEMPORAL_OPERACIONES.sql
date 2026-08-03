CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_OPERACIONES( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de Posiciones y Participantes a una Temporal de Equipamiento
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
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_OPERACIONES_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_OPERACIONES_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tabla SMM_OPERACIONES_TEMP.', v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_OPERACIONES_UB_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_OPERACIONES_UB_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tabla SMM_OPERACIONES_UB_TEMP.', v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_OPERACIONES_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_OPERACIONES_TEMP( TENANTID, PERIODSEQ, OPERACIONID, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, 
                                                AGRUPA_EN_FACTURA, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR)
    SELECT 
        v_tenantid TENANTID,
        i_periodseq PERIDOSEQ,
        C.CLASSIFIERID OPERACIONID,
        GC.GENERICATTRIBUTE1 TIPO_ENTRADA,
        GC.GENERICATTRIBUTE2 TIPO_OPERACION,
        GC.GENERICATTRIBUTE3 SUBTIPO_OPERACION,
        GC.GENERICBOOLEAN1 AGRUPA_EN_FACTURA,
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR

    FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = v_tenantid 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
            -- AND C.ISLAST = 1
        
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = v_tenantid
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
            -- AND GC.ISLAST = 1    

    WHERE UPPER(GCT.NAME) ='OPERACION';

    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_OPERACIONES_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_OPERACIONES_UB_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
    INSERT INTO EXT.SMM_OPERACIONES_UB_TEMP( TENANTID, PERIODSEQ, OPERACIONID, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, 
                                                AGRUPA_EN_FACTURA, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR, UB, EMPRESA) 
    SELECT 
        v_tenantid TENANTID,
        i_periodseq PERIDOSEQ,
		C.classifierid, 
		GC.GENERICATTRIBUTE1 TIPO_ENTRADA,
		GC.GENERICATTRIBUTE2 TIPO_OPERACION,
		GC.GENERICATTRIBUTE3 SUBTIPO_OPERACION,
		GC.GENERICBOOLEAN1 AGRUPA_EN_FACTURA,
		C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
		C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
		CELL.value as UB,
		CASE
			WHEN CELL.DIM2INDEX = 0 THEN 'EE' -- Endesa Energia, S.A.U.
			WHEN CELL.DIM2INDEX = 1 THEN 'EOSC' -- Energia XXI
			WHEN CELL.DIM2INDEX = 2 THEN 'NA' -- Sin Informar
		END AS EMPRESA

	FROM CS_RELATIONALMDLT RM
		INNER JOIN CS_MDLTDIMENSION DIME 
			ON RM.RULEELEMENTSEQ = DIME.RULEELEMENTSEQ
			AND DIME.REMOVEDATE = v_eot

		INNER JOIN CS_MDLTINDEX MINDEX
			ON RM.RULEELEMENTSEQ = MINDEX.RULEELEMENTSEQ
			AND MINDEX.REMOVEDATE = v_eot
			AND mindex.tenantid = v_tenantid
		
		INNER JOIN CS_CLASSIFIER C 
			ON MINDEX.CLASSIFIERSEQ = C.CLASSIFIERSEQ
			AND C.REMOVEDATE = v_eot

		INNER JOIN CS_MDLTCELL CELL
			ON RM.RULEELEMENTSEQ = CELL.MDLTSEQ
			AND CELL.REMOVEDATE = v_eot
			AND CELL.EFFECTIVEENDDATE = v_eot
			AND CELL.DIM0INDEX = MINDEX.ORDINAL

		INNER JOIN CS_GENERICCLASSIFIER GC 
			ON GC.CLASSIFIERSEQ = C.CLASSIFIERSEQ
			AND GC.TENANTID = v_tenantid
			AND GC.REMOVEDATE = v_eot
			AND GC.EFFECTIVESTARTDATE <= V_ULTIMO_DIA_PERIODO
			AND GC.EFFECTIVEENDDATE >= V_ULTIMO_DIA_PERIODO              

	WHERE 
		RM.REMOVEDATE = v_eot 
		AND RM.NAME like 'T - ATC - UB Operacion %'
		AND DIME.NAME = 'UB';

    -- filas := sql%rowcount;
    COMMIT;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_OPERACIONES_UB_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;