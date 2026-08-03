CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_MEDIDAS( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de la tabla de Medidas a una Temporal general para usar como base en todas las demas extracciones 
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

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_MEDIDAS_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_MEDIDAS_TEMP';
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_MEDIDAS_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_MEDIDAS_TEMP(TENANTID,PERIODSEQ, PERIODO, NAME, VALUE, MEASUREMENTSEQ, PAYEESEQ, POSITIONSEQ, PIPELINERUNSEQ, PLANSEQ, RULESEQ)
											/* GENERICATTRIBUTE1,GENERICATTRIBUTE2,GENERICATTRIBUTE3,GENERICATTRIBUTE4,GENERICATTRIBUTE5,GENERICATTRIBUTE6,
                                            GENERICATTRIBUTE7,GENERICATTRIBUTE8,GENERICATTRIBUTE9,GENERICATTRIBUTE10,GENERICATTRIBUTE11,GENERICATTRIBUTE12,
                                            GENERICATTRIBUTE13,GENERICATTRIBUTE14,GENERICATTRIBUTE15,GENERICATTRIBUTE16,GENERICNUMBER1,UNITTYPEFORGENERICNUMBER1,
                                            GENERICNUMBER2,UNITTYPEFORGENERICNUMBER2,GENERICNUMBER3,UNITTYPEFORGENERICNUMBER3,GENERICNUMBER4,
                                            UNITTYPEFORGENERICNUMBER4,GENERICNUMBER5,UNITTYPEFORGENERICNUMBER5,GENERICNUMBER6,UNITTYPEFORGENERICNUMBER6,GENERICDATE1,
                                            GENERICDATE2,GENERICDATE3,GENERICDATE4,GENERICDATE5,GENERICDATE6,GENERICBOOLEAN1,GENERICBOOLEAN2,
                                            GENERICBOOLEAN3,GENERICBOOLEAN4,GENERICBOOLEAN5,GENERICBOOLEAN6) */      
    SELECT 
        CSM.TENANTID,
        CSM.PERIODSEQ,
        CSP.NAME as Periodo,
        CSM.NAME as Nombre,
        CSM.VALUE as Valor,
        CSM.MEASUREMENTSEQ,
        CSM.PAYEESEQ,
        CSM.POSITIONSEQ,
        CSM.PIPELINERUNSEQ,
        CSM.PLANSEQ,
        CSM.RULESEQ
/*      
        CSM.GENERICATTRIBUTE1,
        CSM.GENERICATTRIBUTE2,
        CSM.GENERICATTRIBUTE3,
        CSM.GENERICATTRIBUTE4,
        CSM.GENERICATTRIBUTE5,
        CSM.GENERICATTRIBUTE6,
        CSM.GENERICATTRIBUTE7,
        CSM.GENERICATTRIBUTE8,
        CSM.GENERICATTRIBUTE9,
        CSM.GENERICATTRIBUTE10,
        CSM.GENERICATTRIBUTE11,
        CSM.GENERICATTRIBUTE12,
        CSM.GENERICATTRIBUTE13,
        CSM.GENERICATTRIBUTE14,
        CSM.GENERICATTRIBUTE15,
        CSM.GENERICATTRIBUTE16,
        CSM.GENERICNUMBER1,
        CSM.UNITTYPEFORGENERICNUMBER1,
        CSM.GENERICNUMBER2,
        CSM.UNITTYPEFORGENERICNUMBER2,
        CSM.GENERICNUMBER3,
        CSM.UNITTYPEFORGENERICNUMBER3,
        CSM.GENERICNUMBER4,
        CSM.UNITTYPEFORGENERICNUMBER4,
        CSM.GENERICNUMBER5,
        CSM.UNITTYPEFORGENERICNUMBER5,
        CSM.GENERICNUMBER6,
        CSM.UNITTYPEFORGENERICNUMBER6,
        CSM.GENERICDATE1,
        CSM.GENERICDATE2,
        CSM.GENERICDATE3,
        CSM.GENERICDATE4,
        CSM.GENERICDATE5,
        CSM.GENERICDATE6,
        CSM.GENERICBOOLEAN1,
        CSM.GENERICBOOLEAN2,
        CSM.GENERICBOOLEAN3,
        CSM.GENERICBOOLEAN4,
        CSM.GENERICBOOLEAN5,
        CSM.GENERICBOOLEAN6
  */              
    
    FROM CS_MEASUREMENT CSM
        inner join cs_period csp 
            on csm.periodseq=csp.periodseq
            and csp.removedate= v_eot
                
    where csm.periodseq= i_periodseq;
                 
    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_MEDIDAS_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;