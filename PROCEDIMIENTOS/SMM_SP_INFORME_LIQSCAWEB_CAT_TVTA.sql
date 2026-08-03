CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INFORME_LIQSCAWEB_CAT_TVTA( IN i_processingUnitSeq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz VARCHAR(50))
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
	DECLARE v_txtFechaLiquidacion DATE;

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
		|| ' || i_processingUnitSeq: ' || i_processingUnitSeq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		|| ' || i_interfaz: ' || i_interfaz
		, v_log_count, v_idproceso,'info');
	
	--SMM_LIQSCAWEB_FINAL_WBE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_LIQSCAWEB_FINAL_WBE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_LIQSCAWEB_FINAL_WBE WHERE PERIODO = i_period AND PROCESSINGUNITSEQ = i_processingUnitSeq;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_LIQSCAWEB_FINAL_WBE.', v_log_count, v_idproceso,'info');
	
	--SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA WHERE PERIODO_LIQUIDACION = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA.', v_log_count, v_idproceso,'info');
	
	--SMM_LIQ_FINAL_ASESOR
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_LIQ_FINAL_ASESOR.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_LIQ_FINAL_ASESOR WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_LIQ_FINAL_ASESOR.', v_log_count, v_idproceso,'info');
	
	
	
	--SMM_RAPPELES
	v_txtFechaLiquidacion := '';
    IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
        v_txtFechaLiquidacion := CURRENT_DATE;
    END IF;
    
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando datos en tabla EXT.SMM_LIQSCAWEB_FINAL_WBE.' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_WBE (PERIODO, ORDERID, subcanal, wbe, EVENTTYPEID, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, --NUMPROVEEDOR, 
                                            INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO,PROCESSINGUNITSEQ, ESTADOCONTRATO) 
    SELECT 
		ETT.PERIODO,
        ETT.ORDERID,
        TMP_PDS.subcanal,
        ECT.GENERICATTRIBUTE2 wbe,
        ETT.EVENTYPEID,
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
            when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
            --when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado' -- RMM 10.01.2022 CAT TVTA se liquida por fuera, por lo que nunca debe aparecer liquidado
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        --TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ect.name,
        ECT.GENERICATTRIBUTE8,
        i_processingunitseq,
        ETT.GENERICATTRIBUTE3

    FROM EXT.SMM_TXN_TEMP ETT
        LEFT JOIN EXT.SMM_CREDIT_TEMP ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE14
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq


    WHERE 
    ETT.PROCESSINGUNITSEQ=i_processingUnitSeq
    ;
    
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_LIQSCAWEB_FINAL_WBE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA(Periodo_Liquidacion ,Canal_Unidad_Negocio, WBE,	Nombre_Deposito,	
                                                            Importe,Proveedor, Codigo_Comercial )
    SELECT
     DEP.PERIODO AS PERIODO_LIQUIDACION,
    pos.genericattribute6 AS Canal_Unidad_Negocio,
    dep.EARNINGGROUPID AS WBE,
    dep.name AS Nombre_DepOsito,
    dep.value AS Importe,
    DEP.EARNINGCODEID AS Proveedor,
    POS.NAME AS COdigo_Comercial

    from EXT.SMM_DEPOSIT_TEMP_CAT_TVTA dep
        inner join cs_position pos
            on pos.payeeseq = dep.payeeseq
            and pos.removedate = v_eot
            and pos.processingunitseq = i_processingunitseq

    where dep.name like '%Leads%'
    AND dep.PERIODSEQ = i_periodseq

    ;
    
    COMMIT;

   

--BOM APM 09.12.2025
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_LIQ_FINAL_ASESOR.' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_LIQ_FINAL_ASESOR (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
											CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
											CUPS, FECHA_FIRMA, PEDIDO_CRM)
    SELECT 
        INC.PERIODO,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(CRED.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        CRED.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        CRED.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        '' as Estado,
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        CRED.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		INC.name,
		CRED.GENERICATTRIBUTE8,
		--MPR - nuevos campos
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24 -- pedido_CRM

    FROM CS_COMMISSION COMMI
		INNER JOIN EXT.SMM_INCEN_TEMP INC
			on commi.incentiveseq = inc.incentiveseq
			and commi.payeeseq = inc.payeeseq
			and commi.tenantId = inc.tenantId

		LEFT JOIN EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=INC.GENERICATTRIBUTE2
			and TEMP_PROV.periodSeq = inc.PERIODSEQ
			and TEMP_PROV.tenantId = inc.tenantId

		INNER JOIN cs_credit CRED
			on commi.creditseq = cred.creditseq
			and cred.payeeseq = commi.payeeseq
			and cred.processingUnitseq = commi.processingUnitSeq
			and cred.tenantId = commi.tenantId
			and cred.periodSeq = commi.periodSeq

		INNER JOIN CS_SALESTRANSACTION txn
			ON CRED.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = cred.processingUnitSeq
            AND txn.tenantid = cred.tenantId
            AND txn.modelseq = 0

		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid

		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid

	where inc.name like ('C - Renovacion ASESOR%')
    or inc.name like 'I - Captacion - Promo Prescriptores - %'
    or inc.name like 'I - Captacion - Incentivo Crecimiento - %'
	and inc.tenantId = v_tenantid
	and commi.processingUnitSeq = i_processingunitseq
	and inc.periodSeq = i_periodseq
    ;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla SMM_LIQ_FINAL_ASESOR: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    


 COMMIT;
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end