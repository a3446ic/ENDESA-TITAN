CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_CONTRATOS_E4E_CAT_TVTA( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Cuadre de liquidacion
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
	
	v_ultimo_dia_periodo := EXT.SMM_F_ULTIMO_DIA_PERIODO(i_periodseq);
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		|| ' || v_ultimo_dia_periodo: ' || v_ultimo_dia_periodo
		, v_log_count, v_idproceso,'info');
	
	--SMM_LIQSCAWEB_FINAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_E4E_CONTRATOS_TEMP_CAT_TVTA.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_E4E_CONTRATOS_TEMP_CAT_TVTA';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_E4E_CONTRATOS_TEMP_CAT_TVTA.', v_log_count, v_idproceso,'info');
	
	INSERT INTO EXT.SMM_E4E_CONTRA_TEMP_CAT_TVTA(TENANTID,PERIODSEQ,ID,POS_NAME,ACTIVIDAD_DETALLADA,ACTIVIDAD,                                                                                                                                                                                                                      
             CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,                                                                                                                                                                                                                                                                    
             ORG_COMPRAS,CONDICIONES_PAGO, SUBPOSICION, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, GR_COMPRAS_GA11)                                                                                                                                                                                                                          
	SELECT                                                                                                                                                                                                                                                                                                                               
	 v_tenantid TENANTID,                                                                                                                                                                                                                                                                                                                 
	 i_periodseq PERIDOSEQ,                                                                                                                                                                                                                                                                                                               
	 C.CLASSIFIERID ID,                                                                                                                                                                                                                                                                                                                  
	 GC.GENERICATTRIBUTE2 POS_NAME,                                                                                                                                                                                                                                                                                                      
	 GC.GENERICATTRIBUTE5 ACTIVIDAD_DETALLADA,                                                                                                                                                                                                                                                                                           
	 GC.GENERICATTRIBUTE4 ACTIVIDAD,                                                                                                                                                                                                                                                                                                     
	 GC.GENERICATTRIBUTE1 CIF,                                                                                                                                                                                                                                                                                                           
	 GC.GENERICATTRIBUTE3 COD_CONTRATO,                                                                                                                                                                                                                                                                                                  
	 GC.GENERICATTRIBUTE7 POS_DOC,                                                                                                                                                                                                                                                                                                       
	 GC.GENERICATTRIBUTE6 TEXTO_BREVE,                                                                                                                                                                                                                                                                                                   
	 GC.GENERICATTRIBUTE8 CODIGO_SERVICIO,                                                                                                                                                                                                                                                                                               
	 GC.GENERICATTRIBUTE9 ORG_COMPRAS,                                                                                                                                                                                                                                                                                                   
	 GC.GENERICATTRIBUTE10 CONDICIONES_PAGO,                                                                                                                                                                                                                                                                                             
	 GC.GENERICATTRIBUTE12 SUBPOSICION,                                                                                                                                                                                                                                                                                                  
	 C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,                                                                                                                                                                                                                                                                                            
	 C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,                                                                                                                                                                                                                                                                                                 
	       GC.GENERICATTRIBUTE11 GR_COMPRAS                                                                                                                                                                                                                                                                                              
	                                                                                                                                                                                                                                                                                                                                     
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
	                                                                                                                                                                                                                                                                                                                                     
	WHERE GCT.NAME ='Contrato' ;                                                                                                                                                                                                                                                                                                         
 
        
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla SMM_E4E_CONTRA_TEMP_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    


 COMMIT;
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end