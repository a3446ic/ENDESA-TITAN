CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_CREDITOS( IN i_processingUnitSeq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	DECLARE v_finicio TIMESTAMP;
	DECLARE v_contador_ctrl_inf INT;
	DECLARE v_num_ejecucion INT;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, 'SMM_SP_TEMPORAL_CREDITOS', v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: i_processingUnitSeq' || i_processingUnitSeq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
		
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_CREDIT_TEMP';
	
	INSERT INTO EXT.SMM_CREDIT_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, POSITIONSEQ, 
										COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, 
										GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, 
										GENERICATTRIBUTE10, GENERICATTRIBUTE11,GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, 
										GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3,GENERICNUMBER5, GENERICDATE2)

    /* Insert de créditos*/
        SELECT 
        credit.TENANTID,
        credit.PERIODSEQ,
        i_period PERIODO,
        credit.PIPELINERUNSEQ,
        credit.PIPELINERUNDATE,
        --credit.NAME,
        credit.NAME as name,
        CREDIT.CREDITSEQ,
        CREDIT.SALESORDERSEQ,        
        CREDIT.SALESTRANSACTIONSEQ,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        CREDIT.COMPENSATIONDATE,
        CREDIT.COMMENTS,                --v2.3
        CTYPE.CREDITTYPEID,           
        CTYPE.DESCRIPTION,             -- Tipo de Comision
        --credit.VALUE,                --Importe Comision
        credit.value as importe,
        credit.PREADJUSTEDVALUE,
        credit.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        credit.GENERICATTRIBUTE2,      -- Proveedor
        credit.GENERICATTRIBUTE3,      -- Servicio
        credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
        credit.GENERICATTRIBUTE5,      -- Plazo
        credit.GENERICATTRIBUTE6,      -- Provincia
        credit.GENERICATTRIBUTE7,      -- Zona
        credit.GENERICATTRIBUTE8,      -- Producto
        credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
        credit.GENERICATTRIBUTE10,     -- Equipamiento   
        credit.GENERICATTRIBUTE11,     -- CodigoPostal --ahora WBE
        credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
        credit.GENERICATTRIBUTE13,     --MotivoResultado
        credit.GENERICATTRIBUTE14,     --Descripcion Concepto Liquidacion
        credit.GENERICATTRIBUTE15 as observaciones,
        credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
        credit.GENERICBOOLEAN2,        -- S/S Garantia
        credit.GENERICDATE1,           --FechaCalculo
        credit.GENERICNUMBER1,
        credit.GENERICNUMBER2,
        credit.GENERICNUMBER3,
		credit.GENERICNUMBER5,
        credit.GENERICDATE2 --APM 16.03.2026
        
    FROM CS_CREDIT credit
        INNER JOIN CS_PLRUN p 
            ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Añadimos nuevo filtro para optimizar
            AND p.tenantid = v_tenantid
                                             
        INNER JOIN CS_CREDITTYPE ctype 
            ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
            AND ctype.TENANTID = v_tenantid
            AND ctype.REMOVEDATE  = v_eot
			
    
    WHERE
        CREDIT.TENANTID = v_tenantid 
        AND CREDIT.PROCESSINGUNITSEQ = i_processingUnitSeq 
        AND CREDIT.PERIODSEQ =  i_periodSEQ
	; 
   
    -- COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla ENEL_CREDIT_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, 'SMM_SP_TEMPORAL_CREDITOS', v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;