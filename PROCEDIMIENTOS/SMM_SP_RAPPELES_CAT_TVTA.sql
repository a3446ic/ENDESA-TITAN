CREATE OR REPLACE PROCEDURE EXT.SMM_SP_RAPPELES_CAT_TVTA( IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz VARCHAR(50))
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
	
	
	--SMM_RAPPELES_WBE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_RAPPELES_WBE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_RAPPELES_WBE WHERE PERIODO = i_period and PROCESSINGUNITSEQ = 38280596832649518;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_RAPPELES_WBE.', v_log_count, v_idproceso,'info');
	
	
	
	--SMM_RAPPELES
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio cargando tabla SMM_RAPPELES_WBE', v_log_count, v_idproceso,'info');
	v_txtFechaLiquidacion := '';
    IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
        v_txtFechaLiquidacion := CURRENT_DATE;
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Borrado de la tabla SMM_RAPPELES_WBE.', v_log_count, v_idproceso,'info');

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando datos en tabla SMM_RAPPELES_WBE.' , v_log_count, v_idproceso,'info');

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
        38280596832649518

    FROM CS_INCENTIVE CSI
        INNER JOIN EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA EPT
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
		/*(CSI.NAME LIKE 'I - Captacion - Rappel Cuantitativo - Objetivo % - Importe%' 
			or CSI.NAME LIKE 'I - Captacion - Extra Rappel - Objetivo % - Importe%'
			or CSI.NAME LIKE 'I - Atencion - Rappel Cuantitativo Extra - Objetivo 1 - Importe'
			or CSI.NAME LIKE 'I - Captacion - TdF % - Bonus por TdF m-4'
			or CSI.NAME LIKE 'I - Captacion - BTrimestral crecim - %'
			-- MPR - Se incluye en los rappeles la parte de REMUN
			or CSI.name like 'I - ATC - Remun Comercial PDS' 
			-- MPR - incluimos los incentivos de arrastre
			or CSI.name like 'I %Arrastre%' 
			-- MPR - nuevos rappeles de CNS y SW
			or csi.name like 'I - Captacion Rappel CNS%'
			or csi.name like 'I - Captacion Rappel SW%'
		) 
		and csi.name not like 'I - Captacion - Rappel Cuantitativo - Objetivo % PUSH RED - Importe%'  */ --APM 24.03.2022
        CSI.NAME LIKE 'I - CAT TVTA%' --APM 24.03.2022
		and value <>0;
     
    -- filas := sql%rowcount;
    COMMIT;
    
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_RAPPELES_WBE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    


 COMMIT;
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end