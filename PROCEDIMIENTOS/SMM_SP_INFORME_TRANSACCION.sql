CREATE PROCEDURE EXT.SMM_SP_INFORME_TRANSACCION ( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
		, v_log_count, v_idproceso,'info');
	
	--SMM_INFORME_TRANSACCION
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_INFORME_TRANSACCION.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_INFORME_TRANSACCION WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_INFORME_TRANSACCION.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_INFORME_TRANSACCION.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_INFORME_TRANSACCION (periodo, orderid, channel, eventtypeid, compensationdate, credit_name, credit_value,
						concepto_liquidacion, plazo_motivo, provincia, zona, equipamiento, genericdate1,
						producto, tipo_servicio, nombre_servicio, estado_ga3, canal_entrada, agente, incidencia,
						fecha_insercion, fecha_firma, parte_digitalizado, contrato, positionname, usuariocrm,
						num_pedido_crm, empresa_entrante, linea_pedido, tipo_posicion, segmento, campana, cups, agrupador)

	SELECT 
	(select name from cs_period where periodseq = cred.periodseq and removedate = v_eot) as periodo, --GA1
	ordtxn.orderid, --GA2
	TXN.CHANNEL, --GA3
	ETYPE.EVENTTYPEID, --GA4
	TXN.COMPENSATIONDATE, --GD1
	cred.name , --GA5
	cred.value , --GN1
	cred.GENERICATTRIBUTE1, --GA6 --Concepto Liquidación / Lote 
	cred.GENERICATTRIBUTE5, --GA7 --Plazo / Motivo / Campaña / Canal Entrada
	cred.GENERICATTRIBUTE6, --GA8 --Provincia
	cred.GENERICATTRIBUTE7, --GA9  --Zona /Territorio
	cred.GENERICATTRIBUTE10, --GA10 --Equipamiento / Delegación / Cups 
	cred.genericdate1, --GD2 --Fecha Cálculo / Fecha Realización / Fecha Ganada / Fecha Insercción 
	TXN.PRODUCTID as Producto, --GA11
	TXN.GENERICATTRIBUTE1 as Tipo_Servicio, --GA12 --Tipo / Estado Líneas
	TXN.GENERICATTRIBUTE2 as Nombre_Servicio, --GA13 --Subtipo Producto / Subtipo Precio 
	TXN.GENERICATTRIBUTE3 as Estado_GA3, --GA14 --Estado Oportunidad / Estado Contrato CRM / Estado 
	TXN.GENERICATTRIBUTE6, --GA15 --Canal Entrada Contrato / Herramienta
	TXN.GENERICATTRIBUTE19 as Agente, --GA16 --Cod. Comercial Rep / Agente
	TXN.GENERICATTRIBUTE20 as Incidencia, --GA17 --Incidencia
	etxn0.GENERICDATE1 as Fecha_INSERCION, --GD3 --Fecha Apertura / Fecha Creación / Fecha Inserción
	TXN.GENERICDATE3 as Fecha_Firma, --GD4  --Fecha Efectiva 
	CASE WHEN TXN.GENERICBOOLEAN1 IS NULL THEN 'NO' ELSE 'SI' end, --GA18 --Parte Digitalizado / Registro Principal / Gestión Cartera
	TXN.PONUMBER as Contrato,  --GA19
	TXNASS.POSITIONNAME, --GA20
	TXNASS.GENERICATTRIBUTE2 as UsuarioCRM, --GA21 
	etxn0.GENERICATTRIBUTE13 as Num_Pedido_CRM, --GA22 --Línea Negocio
	etxn0.GENERICATTRIBUTE16 as EmpresaEntrante, --GA23 --Empresa Entrante
	TXN.GENERICATTRIBUTE23, --GA24 --Línea Pedido / Línea Producto / CallId 
	TXN.GENERICATTRIBUTE30, --GA28 --Tipo Posición / Posición Usuario Asignado 
	TXN.GENERICATTRIBUTE31, --GA25 --Segmento 
	TXN.GENERICATTRIBUTE32, --GA26 --Campaña / Lote
	TXN.ALTERNATEORDERNUMBER AS CUPS, --GA27
	TXN.GENERICATTRIBUTE12  as AGRUPADOR-- GA29  --rmm 13.09.2022


FROM cs_salestransaction txn 
INNER JOIN cs_salesorder ordtxn
ON txn.salesorderseq = ordtxn.salesorderseq
AND ordtxn.removedate = v_eot
AND txn.tenantid = 'EXT'
AND ordtxn.processingunitseq = txn.processingunitseq
--AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
AND txn.modelseq = 0
AND txn.processingunitseq = 38280596832649518
AND ordtxn.tenantid = txn.tenantid

INNER JOIN cs_eventtype etype
ON txn.eventtypeseq = etype.datatypeseq
AND etype.removedate = v_eot
AND txn.tenantid = etype.tenantid

LEFT JOIN cs_gasalestransaction etxn0
ON txn.salestransactionseq = etxn0.salestransactionseq
AND etxn0.tenantid = txn.tenantid
AND txn.processingunitseq = etxn0.processingunitseq
AND etxn0.pagenumber = 0
AND etxn0.compensationdate = txn.compensationdate

LEFT JOIN cs_transactionassignment txnass
ON txn.salestransactionseq = txnass.salestransactionseq
AND txn.processingunitseq = txnass.processingunitseq
AND txnass.tenantid = txn.tenantid
AND txn.compensationdate = txnass.compensationdate
AND txnass.setnumber > 0

LEFT JOIN cs_credit cred
on  cred.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ



where (select name from cs_period where periodseq = cred.periodseq and removedate = v_eot)= i_period
 --and ETYPE.EVENTTYPEID not like 'Baja Contrato TVTA' --APM 15.03.2023 --APM 20.05.2026 Se comenta filtro
 ;

	COMMIT;

 INSERT INTO EXT.SMM_INFORME_TRANSACCION (periodo, orderid, channel, eventtypeid, compensationdate, credit_name, credit_value,
						concepto_liquidacion, plazo_motivo, provincia, zona, equipamiento, genericdate1,
						producto, tipo_servicio, nombre_servicio, estado_ga3, canal_entrada, agente, incidencia,
						fecha_insercion, fecha_firma, parte_digitalizado, contrato, positionname, usuariocrm,
						num_pedido_crm, empresa_entrante, linea_pedido, tipo_posicion, segmento, campana, cups, agrupador)

 SELECT 
    (select name from cs_period where periodseq = cred.periodseq and removedate = v_eot) as periodo, --GA1
    ordtxn.orderid, --GA2
    TXN.CHANNEL, --GA3
    ETYPE.EVENTTYPEID, --GA4
    TXN.COMPENSATIONDATE, --GD1
    INCE.NAME, --GA5
    COMMI.VALUE , --GN1
    cred.GENERICATTRIBUTE1, --GA6 --Concepto Liquidación / Lote 
    cred.GENERICATTRIBUTE5, --GA7 --Plazo / Motivo / Campaña / Canal Entrada
    cred.GENERICATTRIBUTE6, --GA8 --Provincia
    cred.GENERICATTRIBUTE7, --GA9  --Zona /Territorio
    cred.GENERICATTRIBUTE10, --GA10 --Equipamiento / Delegación / Cups 
    cred.genericdate1, --GD2 --Fecha Cálculo / Fecha Realización / Fecha Ganada / Fecha Insercción 
    TXN.PRODUCTID as Producto, --GA11
    TXN.GENERICATTRIBUTE1 as Tipo_Servicio, --GA12 --Tipo / Estado Líneas
    TXN.GENERICATTRIBUTE2 as Nombre_Servicio, --GA13 --Subtipo Producto / Subtipo Precio 
    TXN.GENERICATTRIBUTE3 as Estado_GA3, --GA14 --Estado Oportunidad / Estado Contrato CRM / Estado 
    TXN.GENERICATTRIBUTE6, --GA15 --Canal Entrada Contrato / Herramienta
    TXN.GENERICATTRIBUTE19 as Agente, --GA16 --Cod. Comercial Rep / Agente
    TXN.GENERICATTRIBUTE20 as Incidencia, --GA17 --Incidencia
    etxn0.GENERICDATE1 as Fecha_INSERCION, --GD3 --Fecha Apertura / Fecha Creación / Fecha Inserción
    TXN.GENERICDATE3 as Fecha_Firma, --GD4  --Fecha Efectiva 
    CASE WHEN TXN.GENERICBOOLEAN1 IS NULL THEN 'NO' ELSE 'SI' end, --GA18 --Parte Digitalizado / Registro Principal / Gestión Cartera
    TXN.PONUMBER as Contrato,  --GA19
    TXNASS.POSITIONNAME, --GA20
    TXNASS.GENERICATTRIBUTE2 as UsuarioCRM, --GA21 
    etxn0.GENERICATTRIBUTE13 as Num_Pedido_CRM, --GA22 --Línea Negocio
    etxn0.GENERICATTRIBUTE16 as EmpresaEntrante, --GA23 --Empresa Entrante
    TXN.GENERICATTRIBUTE23, --GA24 --Línea Pedido / Línea Producto / CallId 
    TXN.GENERICATTRIBUTE30, --GA28 --Tipo Posición / Posición Usuario Asignado 
    TXN.GENERICATTRIBUTE31, --GA25 --Segmento 
    TXN.GENERICATTRIBUTE32, --GA26 --Campaña / Lote
    TXN.ALTERNATEORDERNUMBER AS CUPS, --GA27
    TXN.GENERICATTRIBUTE12  as AGRUPADOR-- GA29  --rmm 13.09.2022
    FROM cs_salestransaction txn 
        INNER JOIN cs_salesorder ordtxn
            ON txn.salesorderseq = ordtxn.salesorderseq
            AND ordtxn.removedate = v_eot
            AND txn.tenantid = 'EXT'
            AND ordtxn.processingunitseq = txn.processingunitseq
            --AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
            AND txn.modelseq = 0
            AND txn.processingunitseq = 38280596832649518
            AND ordtxn.tenantid = txn.tenantid

        INNER JOIN cs_eventtype etype
            ON txn.eventtypeseq = etype.datatypeseq
            AND etype.removedate = v_eot
            AND txn.tenantid = etype.tenantid

        LEFT JOIN cs_gasalestransaction etxn0
            ON txn.salestransactionseq = etxn0.salestransactionseq
            AND etxn0.tenantid = txn.tenantid
            AND txn.processingunitseq = etxn0.processingunitseq
            AND etxn0.pagenumber = 0
            AND etxn0.compensationdate = txn.compensationdate

        LEFT JOIN cs_transactionassignment txnass
            ON txn.salestransactionseq = txnass.salestransactionseq
            AND txn.processingunitseq = txnass.processingunitseq
            AND txnass.tenantid = txn.tenantid
            AND txn.compensationdate = txnass.compensationdate
            AND txnass.setnumber > 0

        LEFT JOIN cs_credit cred
            on  cred.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = CRED.CREDITSEQ
            AND COMMI.PAYEESEQ = CRED.PAYEESEQ
        LEFT JOIN CS_INCENTIVE INCE 
            ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ


    where (select name from cs_period where periodseq = cred.periodseq and removedate = v_eot)= i_period
        --and ETYPE.EVENTTYPEID not like 'Baja Contrato TVTA' --APM 15.03.2023 --APM 20.05.2026 Se comenta filtro
        AND COMMI.VALUE<>0 
        AND COMMI.VALUE IS NOT NULL 
        AND (INCE.NAME LIKE 'C - CAT TVTA%Rappel Incremental%' 
            or INCE.NAME LIKE '%TM7%' 
            or INCE.NAME LIKE '%TM60%')            
 ;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_INFORME_TRANSACCION '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end