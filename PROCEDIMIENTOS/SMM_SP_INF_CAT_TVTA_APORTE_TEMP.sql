CREATE PROCEDURE EXT.SMM_SP_INF_CAT_TVTA_APORTE_TEMP( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(50))
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
	
	--SMM_CAT_TVTA_APORTE_TEMP
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CAT_TVTA_APORTE_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_CAT_TVTA_APORTE_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CAT_TVTA_APORTE_TEMP.', v_log_count, v_idproceso,'info');
	
	v_txtFechaLiquidacion := '';

	IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' v_txtFechaLiquidacion: '||v_txtFechaLiquidacion , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_CAT_TVTA_APORTE_TEMP.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_CAT_TVTA_APORTE_TEMP ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, CODIGO_COMERCIAL, CANAL, N_REGISTROS, APORTE_UNITARIO, APORTE_TOTAL, ID_PRODUCTO, PRODUCTO, 
												PORCENTAJE_APORTE, N_PRODUCTOS, APORTE_INICIAL, APORTE_PENDIENTE, APORTE_FINAL, APORTE_FINAL_UNITARIO ) 

	SELECT    
		PO.PAYEESEQ,
		PO.RULEELEMENTOWNERSEQ POSITIONSEQ,
		PER.PERIODSEQ,
		PER.NAME PERIODO,
		PO.NAME CODIGO_COMERCIAL,
		'CAT Captacion' CANAL,
		ME1.GENERICNUMBER3 N_REGISTROS,
		FV.VALUE APORTE_UNITARIO,
		ME2.GENERICNUMBER1 APORTE_TOTAL,
		SUBSTR (ME2.NAME, 58, 1) ID_PRODUCTO,
		ME2.GENERICATTRIBUTE1 PRODUCTO,
		ME2.GENERICNUMBER4 PORCENTAJE_APORTE,
		ME2.GENERICNUMBER3 N_PROD,
		ME2.GENERICNUMBER2 APORTE_INICIAL,
		ME2.GENERICNUMBER6 APORTE_PENDIENTE,
		ME3.VALUE APORTE_FINAL,
		ME2.VALUE APORTE_FINAL_UNITARIO

	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT ME1
			ON ME1.PERIODSEQ =  PER.PERIODSEQ
			AND ME1.TENANTID = v_tenantid 
			AND ME1.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND ME1.PERIODSEQ =  i_periodseq
			AND  ME1.NAME = 'MS - CAT TVTA - Captacion - Aporte'

        INNER JOIN CS_MEASUREMENT ME2
			ON ME2.PERIODSEQ =  PER.PERIODSEQ
			AND ME2.TENANTID = v_tenantid 
			AND ME2.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND ME2.PERIODSEQ =  i_periodseq
			AND ME1.POSITIONSEQ = ME2.POSITIONSEQ
			AND ME2.NAME IN ( 'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 1',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 2',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 3',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 4',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 5',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 6',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 7',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 8')

		INNER JOIN CS_MEASUREMENT ME3
			ON ME3.PERIODSEQ =  PER.PERIODSEQ
			AND ME3.TENANTID = v_tenantid 
			AND ME3.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND ME3.PERIODSEQ =  i_periodseq
			AND ME1.POSITIONSEQ = ME3.POSITIONSEQ
			AND SUBSTR (ME2.NAME, 58, 1) = SUBSTR (ME3.NAME, 49, 1) 
			AND ME3.NAME IN ( 'MS - CAT TVTA - Captacion - Aporte Final - Prod 1',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 2',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 3',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 4',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 5',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 6',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 7',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 8')

		INNER JOIN CS_POSITION PO
			ON ME1.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ 
			AND ME2.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ 
			AND ME3.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND PO.REMOVEDATE = v_eot
			AND PO.TENANTID = v_tenantid
			AND PO.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND PO.EFFECTIVESTARTDATE <= PER.STARTDATE AND EFFECTIVEENDDATE >= PER.ENDDATE

        INNER JOIN CS_PLRUN P1 
            ON ME1.PIPELINERUNSEQ = P1.PIPELINERUNSEQ
			AND P1.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion  

        INNER JOIN CS_PLRUN P2
            ON ME2.PIPELINERUNSEQ = P2.PIPELINERUNSEQ
			AND P2.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       

        INNER JOIN CS_PLRUN P3
            ON ME3.PIPELINERUNSEQ = P3.PIPELINERUNSEQ
			AND P3.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion                

        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

        LEFT JOIN CS_FIXEDVALUE FV
            ON FV.EFFECTIVESTARTDATE <= PER.STARTDATE AND FV.EFFECTIVEENDDATE >= PER.ENDDATE
			AND FV.REMOVEDATE = v_eot
			AND FV.TENANTID = v_tenantid
			AND FV.NAME = 'VF - CAT TVTA - Captacion - Aporte'                  

	WHERE    
		PER.REMOVEDATE = v_eot   
		AND PER.PERIODSEQ =  i_periodseq
	;

    INSERT INTO EXT.SMM_CAT_TVTA_APORTE_TEMP ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, CODIGO_COMERCIAL, CANAL, N_REGISTROS, APORTE_UNITARIO, APORTE_TOTAL, ID_PRODUCTO, 
													PRODUCTO, PORCENTAJE_APORTE, N_PRODUCTOS, APORTE_INICIAL, APORTE_PENDIENTE, APORTE_FINAL, APORTE_FINAL_UNITARIO ) 
	SELECT
		PO.PAYEESEQ,
		PO.RULEELEMENTOWNERSEQ POSITIONSEQ,
		PER.PERIODSEQ,
		PER.NAME PERIODO,
		PO.NAME CODIGO_COMERCIAL,
		'CAT Recuperacion' CANAL,
		ME1.GENERICNUMBER3 N_REGISTROS,
		FV.VALUE APORTE_UNITARIO,
		ME2.GENERICNUMBER1 APORTE_TOTAL,
		SUBSTR (ME2.NAME, 61, 1) ID_PRODUCTO,
		ME2.GENERICATTRIBUTE1 PRODUCTO,
		ME2.GENERICNUMBER4 PORCENTAJE_APORTE,
		ME2.GENERICNUMBER3 N_PROD,
		ME2.GENERICNUMBER2 APORTE_INICIAL,
		ME2.GENERICNUMBER6 APORTE_PENDIENTE,
		ME3.VALUE APORTE_FINAL,
		ME2.VALUE APORTE_FINAL_UNITARIO

	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT ME1
			ON ME1.PERIODSEQ =  PER.PERIODSEQ
			AND ME1.TENANTID = v_tenantid 
			AND ME1.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND ME1.PERIODSEQ =  i_periodseq
			AND  ME1.NAME = 'MP - CAT TVTA - Recuperacion - Aporte - Numero de Registros'

        INNER JOIN CS_MEASUREMENT ME2
			ON ME2.PERIODSEQ =  PER.PERIODSEQ
			AND ME2.TENANTID = v_tenantid 
			AND ME2.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND ME2.PERIODSEQ =  i_periodseq
			AND ME1.POSITIONSEQ = ME2.POSITIONSEQ
			AND ME2.NAME IN ( 'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 1',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 2',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 3',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 4',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 5',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 6',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 7',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 8')

		INNER JOIN CS_MEASUREMENT ME3
			ON ME3.PERIODSEQ =  PER.PERIODSEQ
			AND ME3.TENANTID = v_tenantid 
			AND ME3.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND ME3.PERIODSEQ =  i_periodseq
			AND ME1.POSITIONSEQ = ME3.POSITIONSEQ
			AND SUBSTR (ME2.NAME, 61, 1) = SUBSTR (ME3.NAME, 52, 1) 
			AND ME3.NAME IN ( 'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 1',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 2',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 3',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 4',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 5',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 6',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 7',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 8')

        INNER JOIN CS_POSITION PO
			ON ME1.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND ME2.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ 
			AND ME3.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND PO.REMOVEDATE = v_eot
			AND PO.TENANTID = v_tenantid
			AND PO.PROCESSINGUNITSEQ = i_processingUnitSeq
			AND PO.EFFECTIVESTARTDATE <= PER.STARTDATE AND EFFECTIVEENDDATE >= PER.ENDDATE

        INNER JOIN CS_PLRUN P1 
            ON ME1.PIPELINERUNSEQ = P1.PIPELINERUNSEQ
			AND P1.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion  

        INNER JOIN CS_PLRUN P2
            ON ME2.PIPELINERUNSEQ = P2.PIPELINERUNSEQ
			AND P2.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       

        INNER JOIN CS_PLRUN P3
            ON ME3.PIPELINERUNSEQ = P3.PIPELINERUNSEQ
			AND P3.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion                

        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

        LEFT JOIN CS_FIXEDVALUE FV
            ON FV.EFFECTIVESTARTDATE <= PER.STARTDATE AND FV.EFFECTIVEENDDATE >= PER.ENDDATE
			AND FV.REMOVEDATE = v_eot
			AND FV.TENANTID = v_tenantid
			AND FV.NAME = 'VF - CAT TVTA - Recuperacion - Aporte'                  

	WHERE
		PER.REMOVEDATE = v_eot   
		AND PER.PERIODSEQ =  i_periodseq
	;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_CAT_TVTA_APORTE_TEMP '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end