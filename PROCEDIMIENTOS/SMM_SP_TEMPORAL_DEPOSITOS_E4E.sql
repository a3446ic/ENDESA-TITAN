CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_DEPOSITOS_E4E( IN i_processingUnitSeq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz VARCHAR(50))
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Extraer datos de Depósitos y JOIN con tablas temporales 
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
	-- DECLARE v_ultimo_dia_periodo DATE;

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
		-- || ' || v_ultimo_dia_periodo: ' || v_ultimo_dia_periodo
		, v_log_count, v_idproceso,'info');
	
	--SMM_E4E_DEPOSIT_TEMP
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_E4E_DEPOSIT_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_E4E_DEPOSIT_TEMP.', v_log_count, v_idproceso,'info');
	
	--SMM_E4E_DEPOSIT_TEMP_2
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_E4E_DEPOSIT_TEMP_2.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_E4E_DEPOSIT_TEMP_2';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_E4E_DEPOSIT_TEMP_2.', v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_E4E_DEPOSIT_TEMP. Periodo:'|| i_period ||' Periodseq: '||i_periodseq, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Origen de SMM_E4E_DEPOSIT_TEMP : NO ELSA.', v_log_count, v_idproceso,'info');
	
	INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT )
    Select
        DEPO.PERIODSEQ,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(depo.VALUE),
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT
          
    FROM  EXT.SMM_deposit_temp DEPO				 
		INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
             
    WHERE DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        AND DEPO.PROCESSINGUNITSEQ =  i_processingUnitSeq
        and depo.tipo_pago_ga5 is not null
		and depo.value > 0
        --and length(PAYM.EARNINGGROUPID) >3
        and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288',
              '289')
-- DMS 25.05.23 AÑADO WBE 258,259,260
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- DCR 29.06.23 AÑADO WBE 264
-- DCR 30.06.23 AÑADO WBE 265
-- APM 25.04.24 AÑADO WBE 268
-- APM 19.03.2026 Añado WBE 289
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,       
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;     
        
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_E4E_DEPOSIT_TEMP no Elsa: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP( PERIODSEQ, POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT )
    Select
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ---
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.WBE = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT
          
    FROM  EXT.SMM_deposit_temp DEPO				 
		INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.WBE  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
			           
    WHERE 
        DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        AND DEPO.PROCESSINGUNITSEQ =  i_processingUnitSeq
        and depo.tipo_pago_ga5 is not null
		and depo.value > 0
       
        and depo.wbe Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','270','271','272','273','274','275','277','287','288', '289')
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- APM 19.03.2026 Añado WBE 289
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.WBE,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ----
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;   
        
    -- filas := sql%rowcount;
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_E4E_DEPOSIT_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info'); 	

    
	
	-- Carga de depositos neto. Suma los depositos totales para que E4E solo tenga el valor neto
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_E4E_DEPOSIT_TEMP_2. Periodo:'|| i_period ||' Periodseq: '||i_periodseq, v_log_count, v_idproceso,'info');

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Origen de SMM_E4E_DEPOSIT_TEMP_2 : NO ELSA.', v_log_count, v_idproceso,'info'); 	
	
	INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_2 ( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT  )
    Select
        DEPO.PERIODSEQ,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(depo.VALUE),
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT
          
    FROM  EXT.SMM_deposit_temp DEPO				 
		INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
             
    WHERE DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        AND DEPO.PROCESSINGUNITSEQ =  i_processingUnitSeq
        and depo.tipo_pago_ga5 is not null
		--and depo.value > 0
        and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288',
              '289')
-- DMS 23.05.23 AÑADO EL WBE 258,259 Y 260
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- DCR 29.06.23 AÑADO WBE 264
-- DCR 30.06.23 AÑADO WBE 265
-- DMS 27.11.23 WBE 261
-- APM 25.04.24 AÑADO WBE 268
-- APM 19.03.2026 Añado WBE 289
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,       
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;     
        
    
    COMMIT;
    --END IF;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_E4E_DEPOSIT_TEMP_2 no Elsa: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info'); 	
    
    INSERT INTO EXT.SMM_E4E_DEPOSIT_TEMP_2 ( PERIODSEQ, POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT  )                        
    Select
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ---
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.WBE = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT
          
    FROM  EXT.SMM_deposit_temp DEPO				 
		INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.WBE  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = v_tenantid
			           
    WHERE 
        DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        AND DEPO.PROCESSINGUNITSEQ =  i_processingUnitSeq
        and depo.tipo_pago_ga5 is not null
		--and depo.value > 0
       
        and depo.wbe Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256'
              ,'257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288',
              '289')
-- DMS 23.05.23 AÑADO EL WBE 258,259 Y 260
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- DCR 29.06.23 AÑADO WBE 264
-- DCR 30.06.23 AÑADO WBE 265
--DMS 27.11.23 WBE 261
-- APM 25.04.24 AÑADO WBE 268
-- APM 19.03.2026 Añado WBE 289
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.WBE,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ----
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;   
        
    -- filas := sql%rowcount;
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_E4E_DEPOSIT_TEMP_2: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info'); 	

    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;