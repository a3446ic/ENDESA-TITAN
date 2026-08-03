CREATE PROCEDURE EXT.SMM_SP_INF_CAT_TVTA_RESUMEN_PAGO( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(50))
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
	DECLARE v_txtFechaLiquidacion VARCHAR(10);
	

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
		|| ' || i_interfaz: ' || i_interfaz
		, v_log_count, v_idproceso,'info');
	
	--SMM_CAT_TVTA_RESUM_PAGO
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CAT_TVTA_RESUM_PAGO.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_CAT_TVTA_RESUM_PAGO WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CAT_TVTA_RESUM_PAGO.', v_log_count, v_idproceso,'info');
	
	v_txtFechaLiquidacion := '';

	IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' v_txtFechaLiquidacion: '||v_txtFechaLiquidacion , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_CAT_TVTA_RESUM_PAGO.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_CAT_TVTA_RESUM_PAGO ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO,  PROVEEDOR, CODIGO_COMERCIAL,  CONTRATO,  CREDITTYPEID, 
                                                    HERRAMIENTA, BBDD, EMPRESA,  TERRITORIO,  DELEGACION,  CAMPANIA, PRODUCTO, VALOR_FINAL,PROVEEDOR2  ) 
    SELECT    
		CR.payeeseq as PAYEESEQ,
        CR.positionseq as POSITIONSEQ,
        CR.periodseq as PERIODSEQ,
        PER.name as PERIODO,
        CR.genericattribute14 as PROVEEDOR,
        CR.genericattribute4 as CODIGO_COMERCIAL,
        SO.orderid as CONTRATO,
        CT.credittypeid as CREDITTYPEID,
        CR.genericattribute3 as HERRAMIENTA,
        '' as BBDD,
        CR.genericattribute11 as EMPRESA,
        CR.genericattribute7 as TERRITORIO,
		CR.genericattribute10 as DELEGACION,
		CR.genericattribute5 as CAMPANIA,
/* BOM CAL0134 DCR 19.04.2022 */
        CR.genericattribute15 as PRODUCTO,
/* EOM CAL0134 DCR 19.04.2022 */
        CR.value  as VALOR_FINAL,
        CR.GENERICATTRIBUTE2 as proveedor2

    FROM CS_PERIOD PER
		INNER JOIN CS_SALESTRANSACTION ST
			ON ST.COMPENSATIONDATE BETWEEN PER.STARTDATE AND ADD_DAYS(PER.ENDDATE, - 1)
			AND ST.TENANTID = v_tenantid
			AND ST.MODELSEQ = 0
			AND ST.PROCESSINGUNITSEQ = i_processingUnitSeq

		INNER JOIN CS_SALESORDER SO 
			ON ST.SALESORDERSEQ = SO.SALESORDERSEQ 
			AND SO.REMOVEDATE = v_eot
			AND SO.PROCESSINGUNITSEQ = i_processingUnitSeq

		INNER JOIN CS_CREDIT CR 
			ON ST.SALESTRANSACTIONSEQ = CR.SALESTRANSACTIONSEQ
			AND CR.TENANTID = v_tenantid 
			AND CR.PROCESSINGUNITSEQ = i_processingUnitSeq 
			AND CR.PERIODSEQ =  i_periodseq



        INNER JOIN CS_CREDITTYPE CT 
            ON CR.CREDITTYPESEQ = CT.DATATYPESEQ
			AND CT.TENANTID = v_tenantid
			AND CT.REMOVEDATE = v_eot

		INNER JOIN CS_PLRUN P 
			ON CR.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       

	WHERE	
		PER.REMOVEDATE = v_eot      
		AND PER.PERIODSEQ =  i_periodseq

        AND ( CR.NAME like 'CD - CAT TVTA - Captacion - Coste Unitario%'
				OR CR.NAME like 'CD - CAT TVTA - Recuperacion - Coste Unitario%'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Ventas'
                or cr.name like 'CD - CAT TVTA - TLV INBOUND - Ventas%'
/* BOM CAL0XXX DCR 24.05.2022 */
                OR CR.NAME = 'CD - CAT TVTA - Captacion - Ajuste Manual'
                OR CR.NAME = 'CD - CAT TVTA - MKT - Ajuste Manual'
                OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Ajuste Manual'
                OR CR.NAME = 'CD - Leads CAT TVTA - Importe Base'
                OR CR.NAME = 'CD - Captacion TVTA - Permanencia'
                OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Coste Unitario Campañas'
                OR CR.NAME = 'CD - CAT TVTA - Captacion - Coste Unitario Campañas' --APM 15.04.2025
                /*BOM APM 19.03.2026*/
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Fibra'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Futbol'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - DAZN'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Linea Movil'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - OTT'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Dispositivo'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Fibra'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Futbol'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - DAZN'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Linea Movil'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - OTT'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Dispositivo'
                OR CR.NAME = 'CD - Ajuste Manual CAT TVTA - Mas Orange - Importe Base'
                /*EOM APM 19.03.2026*/
                OR CR.NAME LIKE 'CD - CAT TVTA - Retrocesion%' --APM 19.05.2026
                )
/* EOM CAL0XXX DCR 24.05.2022 */
/* BOM CAL0134 DCR 19.04.2022 */
        --AND CR.value <> 0 DCR 05.05.2022 Carmen nos indica que ya no es necesario esta condicion
/* EOM CAL0134 DCR 19.04.2022 */
	;


    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_CAT_TVTA_RESUM_PAGO: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando INCENTIVOS en la tabla ENEL_CAT_TVTA_RESUM_PAGO' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_CAT_TVTA_RESUM_PAGO ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO,  PROVEEDOR, CODIGO_COMERCIAL,  CONTRATO,  CREDITTYPEID, 
                                                    HERRAMIENTA, BBDD, EMPRESA,  TERRITORIO,  DELEGACION,  CAMPANIA, PRODUCTO, VALOR_FINAL,PROVEEDOR2  )
    SELECT
        INC.payeeseq as PAYEESEQ,
        INC.positionseq as POSITIONSEQ,
        INC.periodseq as PERIODSEQ,
        PER.name as PERIODO,
        --POS.NAME as PROVEEDOR,
        INC.genericattribute2 as PROVEEDOR,
        pos.name as CODIGO_COMERCIAL,--cambiar por codigo posicion
        ordtxn.orderid as CONTRATO,
        'CAT TVTA' as CREDITTYPEID,
        INC.genericattribute3 as HERRAMIENTA,
        '' as BBDD,
        '' as EMPRESA,
        '' as TERRITORIO,
		'' as DELEGACION,
		INC.genericattribute6 as CAMPANIA,
/* BOM CAL0134 DCR 19.04.2022 */
        INC.genericattribute1 as PRODUCTO,
/* EOM CAL0134 DCR 19.04.2022 */
         commi.value as VALOR_FINAL,
        inc.genericattribute7

    FROM CS_INCENTIVE INC
        LEFT JOIN CS_COMMISSION COMMI
        ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
		INNER JOIN CS_PERIOD PER
			ON PER.PERIODSEQ =  INC.PERIODSEQ
            AND PER.REMOVEDATE = v_eot

		INNER JOIN CS_PLRUN P 
			ON INC.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion    

        INNER JOIN CS_POSITION POS
            ON INC.payeeseq = POS.payeeseq
            AND INC.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND INC.PROCESSINGUNITSEQ = POS.PROCESSINGUNITSEQ
            AND POS.REMOVEDATE = v_eot

        left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = v_tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= ADD_DAYS(PER.ENDDATE, - 1)
            AND PAR.EFFECTIVEENDDATE >= ADD_DAYS(PER.ENDDATE, - 1)

        left join cs_credit cred 
            ON COMMI.CREDITSEQ = CRED.CREDITSEQ
            AND COMMI.PAYEESEQ = CRED.PAYEESEQ
            and cred.periodseq=i_periodseq

        left join cs_salestransaction txn 
             on  cred.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
             and cred.compensationdate=txn.compensationdate

         INNER JOIN cs_salesorder ordtxn
            ON txn.salesorderseq = ordtxn.salesorderseq
            AND ordtxn.removedate = v_eot
            AND txn.tenantid = 'ENEL'
            AND ordtxn.processingunitseq = txn.processingunitseq
            --AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
            AND txn.modelseq = 0
            AND txn.processingunitseq = 38280596832649518
            AND ordtxn.tenantid = txn.tenantid


	WHERE	
		INC.PERIODSEQ = i_periodseq
        and INC.PROCESSINGUNITSEQ = i_processingUnitSeq
        and INC.genericattribute1 is not null
/* BOM CAL0134 DCR 19.04.2022 */
        AND commi.value <> 0
/* EOM CAL0134 DCR 19.04.2022 */
    ;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_CAT_TVTA_RESUM_PAGO '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end