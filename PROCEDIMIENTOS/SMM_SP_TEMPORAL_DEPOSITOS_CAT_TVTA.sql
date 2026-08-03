CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_DEPOSITOS_CAT_TVTA( IN i_processingUnitSeq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de la tabla de Depositos a una Temporal general para usar como base en todas las demas extracciones 
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
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: i_processingUnitSeq' || i_processingUnitSeq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_DEPOSIT_TEMP_CAT_TVTA.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_DEPOSIT_TEMP_CAT_TVTA';
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_DEPOSIT_TEMP_CAT_TVTA. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_DEPOSIT_TEMP_CAT_TVTA( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,                                                                                                                                                                       
             PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5,                                                                                                                                                                                                          
             processingunitseq, BUSINESSUNITMAP, PROVEEDOR_GA6 )                                                                                                                                                                                                                                                                      
 SELECT                                                                                                                                                                                                                                                                                                                               
  depo.TENANTID,                                                                                                                                                                                                                                                                                                                      
  depo.PERIODSEQ,                                                                                                                                                                                                                                                                                                                     
  i_period PERIODO,                                                                                                                                                                                                                                                                                                                    
  depo.PIPELINERUNSEQ,                                                                                                                                                                                                                                                                                                                
  depo.PIPELINERUNDATE,                                                                                                                                                                                                                                                                                                               
  depo.DEPOSITSEQ ,                                                                                                                                                                                                                                                                                                                   
  depo.PAYEESEQ,                                                                                                                                                                                                                                                                                                                      
  depo.POSITIONSEQ,                                                                                                                                                                                                                                                                                                                   
  depo.NAME,                                                                                                                                                                                                                                                                                                                          
  depo.VALUE,                  --Importe                                                                                                                                                                                                                                                                                              
  depo.PREADJUSTEDVALUE,                                                                                                                                                                                                                                                                                                              
  depo.EARNINGCODEID,                                                                                                                                                                                                                                                                                                                 
  depo.EARNINGGROUPID,                                                                                                                                                                                                                                                                                                                
  depo.COMMENTS,                                                                                                                                                                                                                                                                                                                      
  depo.GENERICATTRIBUTE1,      -- Actividad                                                                                                                                                                                                                                                                                           
  depo.GENERICATTRIBUTE2,                                                                                                                                                                                                                                                                                                             
  depo.GENERICATTRIBUTE5,                                                                                                                                                                                                                                                                                                             
  depo.processingunitseq,                                                                                                                                                                                                                                                                                                             
  DEPO.BUSINESSUNITMAP,                                                                                                                                                                                                                                                                                                               
        DEPO.GENERICATTRIBUTE6                                                                                                                                                                                                                                                                                                        
                                                                                                                                                                                                                                                                                                                                      
 FROM CS_DEPOSIT depo                                                                                                                                                                                                                                                                                                                 
  INNER JOIN CS_PLRUN p                                                                                                                                                                                                                                                                                                               
   ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ                                                                                                                                                                                                                                                                                          
   AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion                                                                                                                                                                                                                                          
 WHERE                                                                                                                                                                                                                                                                                                                                
  depo.TENANTID = v_tenantid                                                                                                                                                                                                                                                                                                           
  AND depo.PROCESSINGUNITSEQ = i_processingUnitSeq                                                                                                                                                                                                                                                                                     
  AND depo.PERIODSEQ =  i_periodseq;
        
    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_DEPOSIT_TEMP_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end