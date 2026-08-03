CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INFORME_TASA_MORTANDAD( IN i_processingunitseq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(250))
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
		|| ' || i_interfaz: ' || i_interfaz
		, v_log_count, v_idproceso,'info');
	
	--SMM_TM2_MENSUAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_TM2_MENSUAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_TM2_MENSUAL WHERE PERIODO_BIMENSUAL = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_TM2_MENSUAL.', v_log_count, v_idproceso,'info');
	
	--SMM_TM6_MENSUAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_TM6_MENSUAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_TM6_MENSUAL WHERE PERIODO_ANUAL = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_TM6_MENSUAL.', v_log_count, v_idproceso,'info');
	
	--SMM_TM_MENSUAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_TM_MENSUAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_TM_MENSUAL WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_TM_MENSUAL.', v_log_count, v_idproceso,'info');
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio cargando tabla SMM_TM2_MENSUAL', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_TM2_MENSUAL(PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION, 
                                        FILTRO_PRD, FECHA_ALTA, FECHA_BAJA , PERIODO_BIMENSUAL ,NUM_DIAS, MOTIVO_BAJA, PRESCRIPTOR,
                                        MOTIVO_SOLICITUD
                                        )
    SELECT per.name,
		per.periodseq,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        '1' AS IMPORTE_COMISION,--COMMI.VALUE as IMPORTE_COMISION,
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
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        ECT.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		'NAME',--INC.name,
		ECT.GENERICATTRIBUTE8,
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		ECT.PAYEESEQ, 
		ECT.POSITIONSEQ,
		ECT.COMPENSATIONDATE,
        '1' AS ALTAS,
        '1' AS BAJAS,
        '1' AS PORC_TDM,
        '1' AS IMPORTE_COMISION,
        TXN.GENERICBOOLEAN2 as FILTRO_PRD, --Filtro para los productos que cumplem TdM
        TXN.GENERICDATE4 as FECHA_ALTA,
        TXN.GENERICDATE5 as FECHA_BAJA,
        i_period AS PERIODO_BIMENSUAL, 
        DAYS_BETWEEN(TXN.GENERICDATE5,TXN.GENERICDATE4)as NUM_DIAS,
        -- to_date(TXN.GENERICDATE5) - to_date(TXN.GENERICDATE4) as NUM_DIAS,
        etxn0.GENERICATTRIBUTE3 as MOTIVO_BAJA,
        ECT.GENERICATTRIBUTE10 as PRESCRIPTOR,
        TXN.GENERICATTRIBUTE5 AS MOTIVO_SOLICITUD --APM 22.12.2025

    FROM cs_credit ECT
		INNER JOIN CS_PERIOD PER
           ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot ),-2)
         and per.periodseq = ect.periodseq
        and removedate= v_eot	
		LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = ECT.tenantId

		INNER JOIN CS_SALESTRANSACTION txn
			ON ECT.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = ECT.processingUnitSeq
            AND txn.compensationdate BETWEEN per.startdate AND per.enddate
            AND txn.tenantid = ECT.tenantId
            AND txn.modelseq = 0	
        LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid     
        INNER JOIN cs_position pos
            ON pos.payeeseq = ect.payeeseq
            AND pos.removedate  = v_eot
            AND pos.tenantid = ect.tenantid
            and POS.PROCESSINGUNITSEQ =  ECT.processingUnitSeq                              
			AND pos.EFFECTIVEENDDATE >= per.enddate	
		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid
      WHERE ECT.NAME LIKE 'CD - Captacion - Importe Base'
        and (TEMP_PROV.IDPROVEEDOR = '011' 
            or TEMP_PROV.IDPROVEEDOR = '012')        
        and ECT.GENERICBOOLEAN1 = 1
        and ECT.GENERICATTRIBUTE1 is not null
        and ETYPE.eventtypeid = 'Captacion'
          
    ;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_TM2_MENSUAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga Registros Créditos de la tabla SMM_TM6_MENSUAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_TM6_MENSUAL (PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION, 
                                        FILTRO_PRD, FECHA_ALTA, FECHA_BAJA , PERIODO_ANUAL ,NUM_DIAS, MOTIVO_BAJA, PRESCRIPTOR,
                                        MOTIVO_SOLICITUD)
    
        SELECT per.name,
		per.periodseq,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        '1' AS IMPORTE_COMISION,--COMMI.VALUE as IMPORTE_COMISION,
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
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        ECT.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		ect.name,--INC.name,
		ECT.GENERICATTRIBUTE8,
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		ECT.PAYEESEQ, 
		ECT.POSITIONSEQ,
		ECT.COMPENSATIONDATE,
        '1' AS ALTAS,
        '1' AS BAJAS,
        '1' AS PORC_TDM,
        '1' AS IMPORTE_COMISION, 
        TXN.GENERICBOOLEAN2 as FILTRO_PRD, --Filtro para los productos que cumplem TdM
        TXN.GENERICDATE4 as FECHA_ALTA,
        TXN.GENERICDATE5 as FECHA_BAJA,
        i_period AS PERIODO_ANUAL,       
        DAYS_BETWEEN(TXN.GENERICDATE5,TXN.GENERICDATE4) as NUM_DIAS,
        -- to_date(TXN.GENERICDATE5) - to_date(TXN.GENERICDATE4) as NUM_DIAS,
        etxn0.GENERICATTRIBUTE3 as MOTIVO_BAJA,
        ect.genericattribute10 as PRESCRIPTOR,
        TXN.GENERICATTRIBUTE5 AS MOTIVO_SOLICITUD --APM 22.12.2025

    FROM cs_credit ECT
		INNER JOIN CS_PERIOD PER
           ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = i_period and removedate= v_eot ),-6)
         and per.periodseq = ect.periodseq
        and removedate= v_eot	
		LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = ECT.tenantId

		INNER JOIN CS_SALESTRANSACTION txn
			ON ECT.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = ECT.processingUnitSeq
            AND txn.compensationdate BETWEEN per.startdate AND per.enddate
            AND txn.tenantid = ECT.tenantId
            AND txn.modelseq = 0	
          
        LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate           
		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid        
        INNER JOIN cs_position pos
            ON pos.payeeseq = ect.payeeseq
            AND pos.removedate  = v_eot
            AND pos.tenantid = ect.tenantid
            and POS.PROCESSINGUNITSEQ =  ECT.processingUnitSeq           
			AND pos.EFFECTIVEENDDATE >= per.enddate
		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid

      WHERE (ECT.NAME LIKE 'CD - Captacion - Importe Base'
      or ect.name like 'CD - Captacion - Importe Prescripcion')
        and (TEMP_PROV.IDPROVEEDOR = '011' 
            or TEMP_PROV.IDPROVEEDOR = '012')
        and ECT.GENERICBOOLEAN1 = 1
        and ECT.GENERICATTRIBUTE1 is not null
        and ETYPE.eventtypeid = 'Captacion'
    ;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_TM6_MENSUAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga Registros Créditos de la tabla SMM_TM_MENSUAL', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_TM_MENSUAL(PERIODO, NAME, IMPORTE, UNIDAD, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, ALTAS, BAJAS,
											PORC_TDM, IMPORTE_COMISION, UNIDAD_1 )   
    SELECT 
		i_period,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        CSI.GENERICATTRIBUTE1,
        CSI.GENERICATTRIBUTE4,
		CSI.GENERICNUMBER1 as ALTAS, 
		CSI.GENERICNUMBER2 as BAJAS,
		CSI.GENERICNUMBER3 as PORC_TDM, 
		CSI.GENERICNUMBER5 as IMPORTE_COMISION,
        'EURO'
    
    FROM EXT.SMM_INCEN_TEMP CSI --CS_INCENTIVE CSI
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
          
        INNER JOIN EXT.SMM_PDS_TEMP CSP --CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
  
    WHERE 
		CSI.periodseq = i_periodseq 
		and (csi.name like 'I - Captacion - TM2%Malus'
            or csi.name like 'I - Captacion - TM6%Malus')
        and csi.value<>0
		; 
 COMMIT;
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_TM_MENSUAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	

	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;