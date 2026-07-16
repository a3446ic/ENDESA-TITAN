CREATE OR REPLACE PROCEDURE EXT.SMM_SP_CREDITOS_RICORRENTE( IN i_processingunitseq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Ricorrente
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
		
																							
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_processingunitseq: ' || i_processingunitseq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	--SMM_CRE_RICORRENTE_6M
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CRE_RICORRENTE_6M.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_CRE_RICORRENTE_6M WHERE PERIODO_ANUAL = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CRE_RICORRENTE_6M.', v_log_count, v_idproceso,'info');
	
	--SMM_CRE_RICORRENTE_12M
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CRE_RICORRENTE_12M.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_CRE_RICORRENTE_12M WHERE PERIODO_ANUAL = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CRE_RICORRENTE_12M.', v_log_count, v_idproceso,'info');
	
	--SMM_CRE_RICORRENTE_DIAS
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CRE_RICORRENTE_DIAS.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_CRE_RICORRENTE_DIAS WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CRE_RICORRENTE_DIAS.', v_log_count, v_idproceso,'info');
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_CRE_RICORRENTE_6M: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_CRE_RICORRENTE_6M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL )
	SELECT 
		inc.TENANTID,
		per.name,
        inc.PERIODSEQ,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        i_period AS PERIODO_ANUAL,
        inc.PAYEESEQ,
        inc.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot  ),-6)
            and per.PERIODSEQ = commi.PERIODSEQ
            and per.removedate= v_eot
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ       
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            AND pos.removedate  = v_eot
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.enddate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = v_tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE 
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE 
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
            
    
	WHERE
		inc.TENANTID = v_tenantid 
		AND inc.PROCESSINGUNITSEQ = i_processingUnitSeq
        and inc.name like 'C%Ricorrente%';
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_CRE_RICORRENTE_6M: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_CRE_RICORRENTE_12M: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_CRE_RICORRENTE_12M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL )
	SELECT 
		inc.TENANTID,
		per.name,
        inc.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        i_period AS PERIODO_ANUAL,
        inc.PAYEESEQ,
        inc.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot  ),-12)
            and per.periodseq = commi.periodseq
            and per.removedate= v_eot
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ       
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            AND pos.removedate  = v_eot
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = v_tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= ADD_DAYS(PER.ENDDATE,- 1)
            AND PAR.EFFECTIVEENDDATE >= ADD_DAYS(PER.ENDDATE,- 1)
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
            
    
	WHERE
		inc.TENANTID = v_tenantid 
		AND inc.PROCESSINGUNITSEQ = i_processingUnitSeq
        and inc.name like 'C%Ricorrente%';
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_CRE_RICORRENTE_12M: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga Registros Créditos de la tabla SMM_CRE_RICORRENTE_DIAS', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_CRE_RICORRENTE_DIAS( TENANTID, PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, ORDERID, CUPS, PRODUCTO, 
                                                    SUBCANAL, COMERCIAL, FECHA_BAJA, MESES_6, MESES_12, BUSINESS_UNIT, PERIODO_ANUAL,
                                                    COMPENSATIONDATE, FECHA_ACTIVACION,GA5,GA8)/*,MESES_13, MESES_14, MESES_15, MESES_16, MESES_17, 
                                                    MESES_18, MESES_19, MESES_20, MESES_21, MESES_22, MESES_23, MESES_24, MESES_25, 
                                                    MESES_26, MESES_27, MESES_28, MESES_29, MESES_30, MESES_31, MESES_32, MESES_33, 
                                                    MESES_34, MESES_35, MESES_36)*/
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        ordtxn.ORDERID, -- ID Referencia
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto,
        POS.NAME AS SUBCANAL,
        TXNASS.GENERICATTRIBUTE1 as COMERCIAL,
        txn.GENERICDATE5 AS FECHA_BAJA,
        ADD_MONTHS(txn.compensationdate, 6) AS MESES_6,
        ADD_MONTHS(txn.compensationdate, 12) AS MESES_12,
        BU.NAME AS BUSINESS_UNIT,
        SUBSTR_REGEXPR('[0-9]{4}' IN per.name) AS PERIODO_ANUAL,
        txn.compensationdate as COMPENSATIONDATE,
        txn.GENERICDATE6 as FECHA_ACTIVACION,
		CREDIT.GENERICATTRIBUTE5 AS GA5,
        CREDIT.GENERICATTRIBUTE8 AS GA8
/*BOM APM 03.03.2026 New Code*/
        /*ADD_MONTHS(txn.compensationdate, 13) AS MESES_13,
        ADD_MONTHS(txn.compensationdate, 14) AS MESES_14,
        ADD_MONTHS(txn.compensationdate, 15) AS MESES_15,
        ADD_MONTHS(txn.compensationdate, 16) AS MESES_16,
		ADD_MONTHS(txn.compensationdate, 17) AS MESES_17,
        ADD_MONTHS(txn.compensationdate, 18) AS MESES_18,
        ADD_MONTHS(txn.compensationdate, 19) AS MESES_19,
        ADD_MONTHS(txn.compensationdate, 20) AS MESES_20,
        ADD_MONTHS(txn.compensationdate, 21) AS MESES_21,
        ADD_MONTHS(txn.compensationdate, 22) AS MESES_22,
        ADD_MONTHS(txn.compensationdate, 23) AS MESES_23,
        ADD_MONTHS(txn.compensationdate, 24) AS MESES_24,
        ADD_MONTHS(txn.compensationdate, 25) AS MESES_25,
        ADD_MONTHS(txn.compensationdate, 26) AS MESES_26,
        ADD_MONTHS(txn.compensationdate, 27) AS MESES_27,
        ADD_MONTHS(txn.compensationdate, 28) AS MESES_28,
        ADD_MONTHS(txn.compensationdate, 29) AS MESES_29,
        ADD_MONTHS(txn.compensationdate, 30) AS MESES_30,
        ADD_MONTHS(txn.compensationdate, 31) AS MESES_31,
        ADD_MONTHS(txn.compensationdate, 32) AS MESES_32,
        ADD_MONTHS(txn.compensationdate, 33) AS MESES_33,
        ADD_MONTHS(txn.compensationdate, 34) AS MESES_34,
        ADD_MONTHS(txn.compensationdate, 35) AS MESES_35,
        ADD_MONTHS(txn.compensationdate, 36) AS MESES_36*/
/*EOM APM 03.03.2026*/

    FROM CS_CREDIT credit
 
     INNER JOIN CS_PERIOD per
            --ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot  ),-12)
            on per.periodseq = credit.periodseq
            and per.removedate= v_eot
          
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            and txn.compensationdate=credit.compensationdate
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            AND pos.removedate  = v_eot
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = v_tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= ADD_DAYS(PER.ENDDATE,- 1)
            AND PAR.EFFECTIVEENDDATE >= ADD_DAYS(PER.ENDDATE,- 1)
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON credit.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
            
        LEFT JOIN CS_TRANSACTIONASSIGNMENT txnass
			ON txn.SALESTRANSACTIONSEQ  = txnass.SALESTRANSACTIONSEQ   
			AND txn.processingunitseq = txnass.processingunitseq
			AND txnass.tenantid = txn.tenantid
			AND txn.compensationdate = txnass.compensationdate
			AND txnass.setnumber > 0
            
        INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = v_tenantid
			AND ctype.REMOVEDATE  = v_eot

/*BOM APM 22.12.2025*/
--New Code
        INNER JOIN CS_TITLE tit ON POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
            AND TIT.REMOVEDATE = v_eot
            AND TIT.EFFECTIVESTARTDATE <= ADD_DAYS(PER.ENDDATE,- 1)
            AND TIT.EFFECTIVEENDDATE >= ADD_DAYS(PER.ENDDATE,- 1)
            AND TIT.TENANTID = v_tenantid
/*EOM APM 22.12.2025*/
    
	WHERE
		credit.TENANTID = v_tenantid 
		AND credit.PROCESSINGUNITSEQ = i_processingUnitSeq
        and CTYPE.CREDITTYPEID = 'Captacion - Importe Base'
        and (credit.genericattribute2='011' or credit.genericattribute2='012')
        and credit.periodseq = i_periodseq
        and tit.name not like 'No Comisiona' --APM 22.12.2025
        ;
        
        COMMIT;
        UPDATE EXT.SMM_CRE_RICORRENTE_DIAS tf
			SET (FECHA_BAJA, FECHA_ACTIVACION) = (
    SELECT
        txn.GENERICDATE5,
        txn.GENERICDATE6

    FROM CS_SALESTRANSACTION txn
    LEFT JOIN cs_salesorder ordtxn
        ON txn.salesorderseq = ordtxn.salesorderseq
        AND ordtxn.removedate = v_eot
        AND ordtxn.processingunitseq = txn.processingunitseq
        AND ordtxn.tenantid = txn.tenantid
    INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid
	LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
    WHERE txn.ALTERNATEORDERNUMBER = tf.CUPS
      AND txn.TENANTID = 'EXT'
      AND txn.PROCESSINGUNITSEQ = 38280596832649218
      AND txn.MODELSEQ = 0
      AND ordtxn.orderid = tf.orderid
      AND TXN.COMPENSATIONDATE=TF.COMPENSATIONDATE
      AND ETYPE.EVENTTYPEID like 'Captacion%'
      and (txn.genericdate5 between (select per.startdate from cs_period per where per.periodseq=i_periodseq and per.removedate=v_eot) and (select per.enddate from cs_period per where per.periodseq=i_periodseq and per.removedate=v_eot)
	  or (txn.compensationdate > ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot  ),-6)
	  and etxn0.genericattribute3 is not null and txn.genericdate5 is null))
)
WHERE  EXISTS (
    SELECT 1
    FROM CS_SALESTRANSACTION txn
    LEFT JOIN cs_salesorder ordtxn
        ON txn.salesorderseq = ordtxn.salesorderseq
        AND ordtxn.removedate = v_eot
        AND ordtxn.processingunitseq = txn.processingunitseq
        AND ordtxn.tenantid = txn.tenantid
    INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid
	LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
    WHERE txn.ALTERNATEORDERNUMBER = tf.CUPS
      AND txn.TENANTID = 'EXT'
      AND txn.PROCESSINGUNITSEQ = 38280596832649218
      AND txn.MODELSEQ = 0
      AND ordtxn.orderid = tf.orderid
      AND TXN.COMPENSATIONDATE=TF.COMPENSATIONDATE
      AND ETYPE.EVENTTYPEID like 'Captacion%'
	  and (txn.genericdate5 between (select per.startdate from cs_period per where per.periodseq=i_periodseq and per.removedate=v_eot) and (select per.enddate from cs_period per where per.periodseq=i_periodseq and per.removedate=v_eot)
	  or (txn.compensationdate > ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot  ),-6)
	  and etxn0.genericattribute3 is not null and txn.genericdate5 is null))
);
 COMMIT;
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_CRE_RICORRENTE_DIAS: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	

	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;