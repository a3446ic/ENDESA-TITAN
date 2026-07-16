CREATE OR REPLACE PROCEDURE EXT.SMM_SP_RAPPELES( IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz VARCHAR(50))
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
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
																							
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		|| ' || i_interfaz: ' || i_interfaz
		, v_log_count, v_idproceso,'info');
	
	--SMM_RAPPELES
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_RAPPELES.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_RAPPELES WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_RAPPELES.', v_log_count, v_idproceso,'info');
	
	--SMM_RAPPELES_WBE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_RAPPELES_WBE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_RAPPELES_WBE WHERE PERIODO = i_period and PROCESSINGUNITSEQ = 38280596832649218;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_RAPPELES_WBE.', v_log_count, v_idproceso,'info');
	
	
	
	--SMM_RAPPELES
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio cargando tabla SMM_RAPPELES', v_log_count, v_idproceso,'info');
	v_txtFechaLiquidacion := '';
    IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
        v_txtFechaLiquidacion := CURRENT_DATE;
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Borrado de la tabla ENEL_RAPPELES.', v_log_count, v_idproceso,'info');

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando datos en tabla ENEL_RAPPELES.' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_RAPPELES(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO,
                                     NOMBRE_PROVEEDOR)        
    SELECT 
        CSPE.NAME,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        csi.GENERICATTRIBUTE1 as concepto,
        CSI.GENERICATTRIBUTE4 as tramo,
        CSI.GENERICATTRIBUTE3 AS NOMBRE_PROVEEDOR --APM 15.01.2025
    
    FROM CS_INCENTIVE CSI
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2         
        
		INNER JOIN CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
            and csp.removedate =v_eot
        
		INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate =v_eot
  
    WHERE 
		CSI.periodseq = i_periodseq and 
		(CSI.NAME LIKE 'I - Captacion - Rappel Cuantitativo% - Objetivo % - Importe%' 
            or CSI.NAME LIKE 'I - Captacion - Extra Rappel - Objetivo % - Importe%'
            or CSI.NAME LIKE 'I - Atencion - Rappel Cuantitativo Extra - Objetivo 1 - Importe'
			or CSI.NAME LIKE 'I - Captacion - TdF % - Bonus por TdF m-4'
			or CSI.NAME LIKE 'I - Captacion - BTrimestral crecim - %'
			or csi.name like 'I - Captacion Rappel CNS%'
			or csi.name like 'I - Captacion Rappel SW%'
            or csi.name like 'I - Captacion - Promo Prescriptores%'
            or csi.name like 'I - Captacion - Incentivo Crecimiento - %'
            or csi.name like 'I - Captacion - Ricorrente -%' --APM 15.01.2025
			or csi.name like 'I - Captacion - Rappel -%'
            or csi.name like 'I - Captacion - Incentivo Transversal % - %'
            or csi.NAME LIKE 'I - Captacion - Rappel Volumen%'
            /*BOM APM 23.06.2026 New Code*/
            or csi.NAME LIKE 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
            or csi.NAME LIKE 'C - Activacion - Rappel Cuantitativo -%'
            /*EOM APM 23.06.2026*/
		) 
        and csi.name not like 'I - Captacion - Rappel Cuantitativo - Objetivo % PUSH RED - Importe%'  
        and value <>0;
     
    -- filas := sql%rowcount;
    COMMIT;
    
    --insert rapeles de credito
INSERT INTO EXT.SMM_RAPPELES(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO,
                                     NOMBRE_PROVEEDOR)        
    SELECT 
        CSPE.NAME,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        csi.GENERICATTRIBUTE1 as concepto,
        CSI.GENERICATTRIBUTE4 as tramo,
        CSI.GENERICATTRIBUTE3 AS NOMBRE_PROVEEDOR --APM 15.01.2025
    
    FROM EXT.SMM_CREDIT_TEMP CSI
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2         
        
		INNER JOIN CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
            and csp.removedate =v_eot
        
		INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate =v_eot
  
    WHERE 
		CSI.periodseq = i_periodseq and 
		(CSI.NAME LIKE 'CD - Activacion - Retrocesion - Rappel Front' 
			or CSI.NAME LIKE 'CD - Activacion - Retrocesion - Rappel Prescriptores'
		)   
        and value <>0;
     
    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_RAPPELES: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    INSERT INTO EXT.SMM_RAPPELES_WBE(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, subcanal, wbe,PROCESSINGUNITSEQ)
    SELECT 
        CSPE.NAME,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        CSI.GENERICATTRIBUTE1,
        CSI.GENERICATTRIBUTE4,
        TMP_PDS.subcanal,
        CSI.GENERICATTRIBUTE7 wbe,
        38280596832649218
    
    FROM CS_INCENTIVE CSI
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
        
        INNER JOIN CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
            and csp.removedate =v_eot
    
        INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate =v_eot
    
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on CSI.payeeseq=TMP_PDS.payeeseq 
            and CSI.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and CSI.periodseq=TMP_PDS.periodseq
      
    WHERE 
		CSI.periodseq = i_periodseq and 
		(CSI.NAME LIKE 'I - Captacion - Rappel Cuantitativo% - Objetivo % - Importe%' 
			or CSI.NAME LIKE 'I - Captacion - Extra Rappel - Objetivo % - Importe%'
			or CSI.NAME LIKE 'I - Atencion - Rappel Cuantitativo Extra - Objetivo 1 - Importe'
			or CSI.NAME LIKE 'I - Captacion - TdF % - Bonus por TdF m-4'
			or CSI.NAME LIKE 'I - Captacion - BTrimestral crecim - %'
			-- MPR - Se incluye en los rappeles la parte de REMUN
			or CSI.name like 'I - ATC - Remun Comercial PDS%' 
			-- MPR - incluimos los incentivos de arrastre
			or CSI.name like 'I %Arrastre%' 
			-- MPR - nuevos rappeles de CNS y SW
			or csi.name like 'I - Captacion Rappel CNS%'
			or csi.name like 'I - Captacion Rappel SW%'
            -- DMS 22.06.2023 AÑADIDO CAMPO ABAJO
            or CSI.NAME LIKE 'I - % - RC OCAP %' 
            or csi.name like 'I - Captacion - Promo Prescriptores%'
            or csi.name like 'I - Captacion - Incentivo Crecimiento - %'
            or csi.name like 'I - Captacion - Ricorrente -%' --APM 15.01.2025
            or csi.name like 'I - Captacion - TM2%Malus'
            or csi.name like 'I - Captacion - TM6%Malus'
			or csi.name like 'I - Captacion - Rappel -%' 
            or csi.name like 'I - Captacion - Incentivo Transversal % - %'
            or csi.NAME LIKE 'I - Captacion - Rappel Volumen%'
            /*BOM APM 23.06.2026 New Code*/
            or csi.NAME LIKE 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
            or csi.NAME LIKE 'C - Activacion - Rappel Cuantitativo -%'
            /*EOM APM 23.06.2026*/
		) 
		and csi.name not like 'I - Captacion - Rappel Cuantitativo - Objetivo % PUSH RED - Importe%'  
		and value <>0
		and EPT.IDPROVEEDOR in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
           '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
            '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
            '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201','242',
			'243','244','245','246', '247', '249','250','251','252', '254', '255', '256', '257','258','259','260','261','262', '264', '265',
            '268','270','271','272','273','274','275','287','288');
            --APM 12.12.2023 Añado el wbe 254 y 264
    
    COMMIT;

--INSERT DE CREDITOS

	INSERT INTO EXT.SMM_RAPPELES_WBE(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, subcanal, wbe,PROCESSINGUNITSEQ)
    SELECT 
        CSPE.NAME,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        CSI.GENERICATTRIBUTE1,
        CSI.GENERICATTRIBUTE4,
        TMP_PDS.subcanal,
        CSI.GENERICATTRIBUTE7 wbe,
        38280596832649218
    
    FROM EXT.SMM_CREDIT_TEMP CSI
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
        
        INNER JOIN CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
            and csp.removedate =v_eot
    
        INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate =v_eot
    
        LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
            on CSI.payeeseq=TMP_PDS.payeeseq 
            and CSI.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and CSI.periodseq=TMP_PDS.periodseq
      
    WHERE 
		CSI.periodseq = i_periodseq and 
		(CSI.NAME LIKE 'CD - Activacion - Retrocesion - Rappel Front' 
			or CSI.NAME LIKE 'CD - Activacion - Retrocesion - Rappel Prescriptores'
		)  
		and value <>0
		and EPT.IDPROVEEDOR in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
           '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
            '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
            '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201','242',
			'243','244','245','246', '247', '249','250','251','252', '254', '255', '256', '257','258','259','260','261','262', '264', '265',
            '268','270','271','272','273','274','275','287','288');
            --APM 12.12.2023 Añado el wbe 254 y 264
    
    COMMIT;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_RAPPELES_WBE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    


 COMMIT;
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;