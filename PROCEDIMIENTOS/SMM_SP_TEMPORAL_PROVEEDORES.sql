CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_PROVEEDORES( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de clasificación a una Temporal de proveedores
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
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_PROVEEDORES_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_PROVEEDORES_TEMP';
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_PROVEEDORES_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_PROVEEDORES_TEMP( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
                                                WBE_FINAL_IMPUTACION,DETALLE_ACTIVIDAD,ACTIVIDAD,SOCIEDAD,
                                                CENTRO_LOGISTICO,GR_COMPRAS,TIPO_PAGO, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR,subactividad)
    SELECT 
        v_tenantid TENANTID,
        i_periodseq PERIDOSEQ,
        C.CLASSIFIERID IDPROVEEDOR,
        C.NAME DESCRIPCION,
        GC.GENERICATTRIBUTE8 DESCRIPCION_CORTA,
        C.DESCRIPTION FICHERO,
        GC.GENERICATTRIBUTE1 CECO,
        GC.GENERICATTRIBUTE2 WBE_FINAL_IMPUTACION,
        GC.GENERICATTRIBUTE3 DETALLE_ACTIVIDAD,
        GC.GENERICATTRIBUTE4 ACTIVIDAD,
        GC.GENERICATTRIBUTE5 SOCIEDAD,
        GC.GENERICATTRIBUTE6 CENTRO_LOGISTICO, 
        GC.GENERICATTRIBUTE7 GR_COMPRAS,
        GC.GENERICATTRIBUTE8 TIPO_PAGO,  -- Nuevo v2.0  
        GC.GENERICATTRIBUTE9 ORG_VENTAS, -- Nuevo v2.0            
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
        GC.GENERICATTRIBUTE10
        
    FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C 
            ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = v_tenantid 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
            -- AND C.ISLAST = 1
      
        INNER JOIN CS_GENERICCLASSIFIER GC 
            ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = v_tenantid
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
            -- AND GC.ISLAST = 1
         
    WHERE 
		UPPER(GCT.NAME) like 'PROVEEDOR%'
        AND UPPER(GC.GENERICATTRIBUTE4) not like '%TELEVENTA';
                 
    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_PROVEEDORES_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;