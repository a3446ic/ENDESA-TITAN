CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INFORME_ACTIVIDAD_COMERCIAL( IN i_processingunitseq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: TM2 Y TM6
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
	DECLARE v_txtFechaLiquidacion DATE;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		
																							
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_processingunitseq: ' || i_processingunitseq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	--SMM_ACTIVIDAD_COMERCIAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_ACTIVIDAD_COMERCIAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_ACTIVIDAD_COMERCIAL WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_ACTIVIDAD_COMERCIAL.', v_log_count, v_idproceso,'info');
	
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio cargando tabla SMM_ACTIVIDAD_COMERCIAL', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_ACTIVIDAD_COMERCIAL(PERIODO, periodseq, ORDERID ,PAYEESEQ , POSITIONSEQ ,PROCESSINGUNITSEQ ,CONCEPTO ,IMPORTE ,OBSERVACIONES,POSICIONID 
                                        )
    SELECT PER.NAME AS PERIODO ,
		PER.PERIODSEQ AS periodseq ,
		ORDTXN.ORDERID AS ORDERID,
		CRE.PAYEESEQ , 
		CRE.POSITIONSEQ ,
		CRE.PROCESSINGUNITSEQ ,
		TXN.GENERICATTRIBUTE1 AS CONCEPTO ,
		CRE.VALUE AS IMPORTE ,
		TXN.COMMENTS AS OBSERVACIONES,
        pos.name

    FROM cs_credit cre
		INNER JOIN CS_PERIOD PER           
         ON per.periodseq = cre.periodseq
        and removedate= v_eot 	

		INNER JOIN CS_SALESTRANSACTION txn
			ON cre.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = cre.processingUnitSeq
            AND txn.compensationdate BETWEEN per.startdate AND per.enddate
            AND txn.tenantid = cre.tenantId
            AND txn.modelseq = 0	

		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid     
        
         left JOIN cs_position pos
            ON pos.payeeseq = cre.payeeseq
            AND pos.removedate  = v_eot
            AND pos.tenantid = cre.tenantid
            and POS.PROCESSINGUNITSEQ =  cre.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate

		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid
      WHERE etype.eventtypeid='Comisionado Actividad Comercial'
      and cre.processingunitseq=i_processingunitseq
      and per.periodseq=i_periodseq
          
    ;
 COMMIT;
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros de la tabla SMM_ACTIVIDAD_COMERCIAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	

	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;