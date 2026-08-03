CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INFORME_RESUMEN_PAGOS( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: 
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
	DECLARE v_fechaInicioPeriodoSig DATE;
	DECLARE v_fechaInicio DATE;
	DECLARE v_txtFechaInicioPeriodoSig VARCHAR(25);
	DECLARE v_txtYear VARCHAR(4);
	DECLARE v_codMes VARCHAR(2);
	DECLARE v_txtFechaActual VARCHAR(25);
	DECLARE contadorE4E INT;
	DECLARE contadorECS INT;
	DECLARE contadorPosicion  INT;
	DECLARE v_codFichero VARCHAR(50);
	DECLARE v_maxIDPEDIDO INT;
	

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
																							
		RESIGNAL;
	END;
	
	-- v_ultimo_dia_periodo := EXT.SMM_F_ULTIMO_DIA_PERIODO(i_periodseq);
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_processingUnitSeq: ' || i_processingUnitSeq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	--SMM_PAGOS_RESUMEN
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_PAGOS_RESUMEN.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_PAGOS_RESUMEN WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_PAGOS_RESUMEN.', v_log_count, v_idproceso,'info');
	
	
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_PAGOS_RESUMEN.' || v_codFichero , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_PAGOS_RESUMEN ( TENANTID, PERIODSEQ, PERIODO, IDPROVEEDOR, DESCRIPCION, 
                                              TOTAL, VALOR_POS_CON, VALOR_POS_SIN, VALOR_NEG_CON, VALOR_NEG_SIN )   
    SELECT 
        v_tenantid,
        i_periodseq,
        i_period,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        sum(DEPO.VALUE) TOTAL,
        SUM( CASE WHEN DEPO.VALUE>=0 and TMP_CONTRA.COD_CONTRATO is not null then DEPO.VALUE else 0 END ) VALOR_POS_CON,
        SUM( CASE WHEN DEPO.VALUE>=0 and TMP_CONTRA.COD_CONTRATO is null then DEPO.VALUE else 0 END ) VALOR_POS_SIN,
        SUM( CASE WHEN DEPO.VALUE<0 and TMP_CONTRA.COD_CONTRATO is not null then DEPO.VALUE else 0 END ) VALOR_NEG_CON,
        SUM( CASE WHEN DEPO.VALUE<0 and TMP_CONTRA.COD_CONTRATO is null then DEPO.VALUE else 0 END ) VALOR_NEG_SIN

    FROM CS_DEPOSIT DEPO
        INNER JOIN CS_PLRUN p ON DEPO.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS ON DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq

        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            AND DEPO.periodseq=TMP_PROV.periodseq

        LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq  
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq                

    WHERE 
		DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        AND DEPO.PROCESSINGUNITSEQ =  i_processingUnitSeq
    
    GROUP BY TMP_PROV.IDPROVEEDOR, TMP_PROV.DESCRIPCION;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_PAGOS_RESUMEN '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;