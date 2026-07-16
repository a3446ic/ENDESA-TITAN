CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_E4E_NEGATIVOS( IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de todas las operaciones por OCAPS
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
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	
	v_ultimo_dia_periodo := EXT.SMM_F_ULTIMO_DIA_PERIODO(i_periodseq);

	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: '
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		|| ' || v_ultimo_dia_periodo: ' || v_ultimo_dia_periodo
		, v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_E4E_NEGATIVOS_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tabla SMM_E4E_NEGATIVOS_TEMP.', v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_E4E_NEGATIVOS_TEMP_2.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_E4E_NEGATIVOS_TEMP_2';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tabla SMM_E4E_NEGATIVOS_TEMP_2.', v_log_count, v_idproceso,'info');
	
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_E4E_NEGATIVOS_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
                                                PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
                                                POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        --sum(case when b.NEGATIVO > 0 then 0 else NEGATIVO end), 
		sum(DEPO.VALUE),
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, 
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO

    FROM EXT.SMM_DEPOSIT_TEMP DEPO
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA  
        LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
		
		-- MPR - Se incluye cruce para sacar los negativos agrupados por WBE cuyo pago es la diferencia de los depositos.
		/*
		LEFT JOIN 
			(select 
				payeeseq, wbe,
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
				from EXT.SMM_DEPOSIT_TEMP
				where periodseq=i_periodseq
				group by payeeseq, wbe
			)b
			ON depo.payeeseq = b.payeeseq
			and depo.wbe=b.wbe
		*/
		
    WHERE DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
         and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','277','287','288', '289')
        -- APM 25.04.24 AÑADO WBE 268   
        -- APM 19.03.2026 Añado WBE 289
              
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO;

    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_E4E_NEGATIVOS_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_E4E_NEGATIVOS_TEMP_2: CS_DEPOSIT. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
    
    INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_2 ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
													PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        --sum(case when b.NEGATIVO > 0 then 0 else NEGATIVO end), 
		sum(DEPO.VALUE),
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, 
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO

    FROM EXT.SMM_DEPOSIT_TEMP DEPO
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA  
        LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
		
    WHERE DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        --AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
       and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288', 
              '289')     
-- DCR 09.09.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen   
        -- APM 25.04.24 AÑADO WBE 268
        -- APM 19.03.2026 Añado WBE 289
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_E4E_NEGATIVOS_TEMP_2: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
	INSERT INTO EXT.SMM_E4E_NEGATIVOS_TEMP_2 ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
													PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, 
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO

    FROM EXT.SMM_DEPOSIT_TEMP DEPO
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.wbe  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA  
        LEFT JOIN EXT.SMM_E4E_CONTRATOS_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
    WHERE DEPO.TENANTID = v_tenantid
        AND DEPO.periodseq=i_periodseq        
        --AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
        -- filtro de proveedores de Elsa 
		and depo.wbe Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256'
              ,'257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288',
              '289')
-- DCR 09.09.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
        -- APM 25.04.24 AÑADO WBE 268
        -- APM 19.03.2026 Añado WBE 289
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO;
                      
    -- filas := sql%rowcount;
    COMMIT;
    
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;