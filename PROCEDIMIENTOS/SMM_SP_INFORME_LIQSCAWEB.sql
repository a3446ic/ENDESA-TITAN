CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INFORME_LIQSCAWEB( IN i_processingUnitSeq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz VARCHAR(50))
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
	
	--SMM_LIQSCAWEB_FINAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_LIQSCAWEB_FINAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_LIQSCAWEB_FINAL WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_LIQSCAWEB_FINAL.', v_log_count, v_idproceso,'info');
	
	--SMM_LIQSCAWEB_FINAL_WBE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_LIQSCAWEB_FINAL_WBE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_LIQSCAWEB_FINAL_WBE WHERE PERIODO = i_period and PROCESSINGUNITSEQ = i_processingUnitSeq;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_LIQSCAWEB_FINAL_WBE.', v_log_count, v_idproceso,'info');
	
	--SMM_LIQ_FINAL_ASESOR
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_LIQ_FINAL_ASESOR.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_LIQ_FINAL_ASESOR WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_LIQ_FINAL_ASESOR.', v_log_count, v_idproceso,'info');
	
	
	
	--SMM_RAPPELES
	v_txtFechaLiquidacion := '';
    IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
        v_txtFechaLiquidacion := CURRENT_DATE;
    END IF;
    
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando datos en tabla SMM_LIQSCAWEB_FINAL.' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_LIQSCAWEB_FINAL (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
											CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
											CUPS, FECHA_FIRMA, PEDIDO_CRM, ESTADOCONTRATO,TIPO_PDS_OCAP,
                                            COSTE, --APM 28.12.2023
                                            PROVINCIA, APLICACION_INCEN_CP, TALLA_SOLAR_FV, --APM 07.03.2024 Evo CPs --APM 05.11.2024
                                            FECHA_VENTA, COMPENSATIONDATE, FECHA_ACTIVACION, FECHA_BAJA)
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
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
            when i_interfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ETT.GENERICATTRIBUTE3,
		ect.name,
		ECT.GENERICATTRIBUTE8,
		--MPR - nuevos campos
		ETT.ALTERNATEORDERNUMBER, --CUPS
		ETT.GENERICDATE3, --fecha de firma
		ETT.GENERICATTRIBUTE24, -- pedido_CRM
        ETT.GENERICATTRIBUTE3,
        ECT.GENERICATTRIBUTE10,
        TRIM(replace(to_char(ETT.COSTE , '9999999999990D99'), ',', '.')) COSTE, --APM 28.12.2023
		/*BOM APM 07.03.2024 Evo CPs*/
        ETT.TAD_STATE AS PROVINCIA,
        TMP_PDS.APLICACION_INCEN_CP AS APLICACION_INCEN_CP,
        /*EOM APM 07.03.2024*/
        ECT.GENERICATTRIBUTE13 AS TALLA_SOLAR_FV, --APM 05.11.2024
        /*BOM APM 16.03.2026*/
        ECT.GENERICDATE2 AS FECHA_VENTA,
        ETT.COMPENSATIONDATE AS COMPENSATIONDATE,
        ETT.FECHA_ACTIVACION AS FECHA_ACTIVACION,
        ETT.GENERICDATE5 AS FECHA_BAJA
        /*EOM APM 16.03.2026*/
        
    FROM EXT.SMM_TXN_TEMP ETT
        LEFT JOIN EXT.SMM_CREDIT_TEMP ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq            
    ;
     
    -- filas := sql%rowcount;
    COMMIT;
    
    INSERT INTO EXT.SMM_LIQSCAWEB_FINAL (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
											CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
											CUPS, FECHA_FIRMA, PEDIDO_CRM, ESTADOCONTRATO,TIPO_PDS_OCAP,
                                            COSTE, --APM 28.12.2023
                                            PROVINCIA, APLICACION_INCEN_CP, TALLA_SOLAR_FV, --APM 07.03.2024 Evo CPs --APM 05.11.2024
                                            FECHA_VENTA, COMPENSATIONDATE, FECHA_ACTIVACION, FECHA_BAJA)
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        TRIM(replace(to_char(commi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
            when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
            when i_interfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ETT.GENERICATTRIBUTE3,
		ince.name,
		ECT.GENERICATTRIBUTE8,
		--MPR - nuevos campos
		ETT.ALTERNATEORDERNUMBER, --CUPS
		ETT.GENERICDATE3, --fecha de firma
		ETT.GENERICATTRIBUTE24, -- pedido_CRM
        ETT.GENERICATTRIBUTE3,
        ECT.GENERICATTRIBUTE10,
        TRIM(replace(to_char(ETT.COSTE , '9999999999990D99'), ',', '.')) COSTE, --APM 28.12.2023
		/*BOM APM 07.03.2024 Evo CPs*/
        ETT.TAD_STATE AS PROVINCIA,
        TMP_PDS.APLICACION_INCEN_CP AS APLICACION_INCEN_CP,
        /*EOM APM 07.03.2024*/
        ECT.GENERICATTRIBUTE13 AS TALLA_SOLAR_FV, --APM 05.11.2024
        /*BOM APM 16.03.2026*/
        ECT.GENERICDATE2 AS FECHA_VENTA,
        ETT.COMPENSATIONDATE AS COMPENSATIONDATE,
        ETT.FECHA_ACTIVACION AS FECHA_ACTIVACION,
        ETT.GENERICDATE5 AS FECHA_BAJA
        /*EOM APM 16.03.2026*/
        
    FROM EXT.SMM_TXN_TEMP ETT
        LEFT JOIN EXT.SMM_CREDIT_TEMP ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq    
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = ECT.CREDITSEQ
            AND COMMI.PAYEESEQ = ECT.PAYEESEQ
            AND COMMI.PERIODSEQ= ECT.PERIODSEQ --añadido mejorar rendimiento DMS
        
		LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq
        
        where (ince.name like 'C - Activacion - Importe Base Prescriptor -%'
        or ince.name like 'C - Activacion - Retrocesion - Importe Base Prescriptor -%'
        or ince.name like 'C - Captacion - Rappel Cuantitativo Incremental - Objetivo%')
    ;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_LIQSCAWEB_FINAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    --insert rapeles de credito
INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_WBE (PERIODO, ORDERID, subcanal, wbe, EVENTTYPEID, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, 
                                            NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO,PROCESSINGUNITSEQ, ESTADOCONTRATO) 
    SELECT 
		ETT.PERIODO,
        ETT.ORDERID,
        TMP_PDS.subcanal,
        ECT.GENERICATTRIBUTE11 wbe,
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
            when i_interfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ect.name,
        ECT.GENERICATTRIBUTE8,
        i_processingUnitSeq,
        ETT.GENERICATTRIBUTE3
        
    FROM EXT.SMM_TXN_TEMP ETT
        LEFT JOIN EXT.SMM_CREDIT_TEMP ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq

    WHERE 
    ETT.PROCESSINGUNITSEQ=i_processingUnitSeq
    and TEMP_PROV.IDPROVEEDOR in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
           '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
            '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
            '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201','242',
			'243','244','245','246', '247', '249','250','251','252', '254', '255', '256', '257','258','259','260','261','262', '264', '265',
            '268','270','271','272','273','274','275','287','288', '289')
    ;
    
    INSERT INTO EXT.SMM_LIQSCAWEB_FINAL_WBE (PERIODO, ORDERID, subcanal, wbe, EVENTTYPEID, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, 
                                            NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO,PROCESSINGUNITSEQ, ESTADOCONTRATO) 
    SELECT 
		ETT.PERIODO,
        ETT.ORDERID,
        TMP_PDS.subcanal,
        ECT.GENERICATTRIBUTE11 wbe,
        ETT.EVENTYPEID,
        TRIM(replace(to_char(commi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
            when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
            when i_interfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ince.name,
        ECT.GENERICATTRIBUTE8,
        i_processingUnitSeq,
        ETT.GENERICATTRIBUTE3
        
    FROM EXT.SMM_TXN_TEMP ETT
        LEFT JOIN EXT.SMM_CREDIT_TEMP ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq
            
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = ECT.CREDITSEQ
            AND COMMI.PAYEESEQ = ECT.PAYEESEQ
            AND COMMI.PERIODSEQ= ECT.PERIODSEQ --añadido mejorar rendimiento DMS
        
		LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq

    WHERE 
    ETT.PROCESSINGUNITSEQ=i_processingUnitSeq
    and (ince.name like 'C - Activacion - Importe Base Prescriptor -%'
    or ince.name like 'C - Activacion - Retrocesion - Importe Base Prescriptor -%')
    and TEMP_PROV.IDPROVEEDOR in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
           '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
            '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
            '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201','242',
			'243','244','245','246', '247', '249','250','251','252', '254', '255', '256', '257','258','259','260','261','262', '264', '265',
            '268','270','271','272','273','274','275','287','288', '289')
    ;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_LIQSCAWEB_FINAL_WBE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla SMM_LIQ_FINAL_ASESOR', v_log_count, v_idproceso,'info');
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
            and commi.periodseq=inc.periodseq --DMS 26.03.2026
		
		LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
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
            and txn.compensationdate=cred.compensationdate --DMS 26.03.2026
			
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
	and commi.processingUnitSeq = i_processingUnitSeq
    /*BOM DMS 26.03.2026 Old Code*/
    --and inc.periodSeq = i_periodseq
    --New Code
    and commi.periodSeq = i_periodseq
    /*EOM DMS 26.03.2026*/
    ;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla SMM_LIQ_FINAL_ASESOR: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    


 COMMIT;
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;