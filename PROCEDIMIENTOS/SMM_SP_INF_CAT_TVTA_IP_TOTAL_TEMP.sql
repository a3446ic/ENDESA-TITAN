CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_CAT_TVTA_IP_TOTAL_TEMP( IN i_processingUnitSeq BIGINT , IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(50))
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
		|| ' || i_periodseq: ' || i_periodseq
		|| ' || i_interfaz: ' || i_interfaz
		, v_log_count, v_idproceso,'info');
	
	--SMM_CAT_TVTA_IP_TOTAL_TEMP
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CAT_TVTA_IP_TOTAL_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CAT_TVTA_IP_TOTAL_TEMP.', v_log_count, v_idproceso,'info');
	
	v_txtFechaLiquidacion := '';

	IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. PeriodSEQ:'|| i_periodseq ||' v_txtFechaLiquidacion: '||v_txtFechaLiquidacion , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
	SELECT
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Penalizacion Ordinaria' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Penalizacion Ordinaria - Unitaria'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Penalizacion Ordinaria - Unitaria' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Penalizacion Ordinaria - Unitaria'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		IFNULL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		IFNULL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		IFNULL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS 

	FROM CS_PERIOD PER
        INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = v_tenantid 
			AND MEAS.PROCESSINGUNITSEQ = i_processingUnitSeq 
			AND MEAS.PERIODSEQ =  i_periodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Penalizacion Ordinaria - Unitaria'

        INNER JOIN TCMP.CS_POSITION POS
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = v_tenantid
			AND POS.EFFECTIVESTARTDATE <= CURRENT_DATE
			AND POS.EFFECTIVEENDDATE > CURRENT_DATE
			AND POS.REMOVEDATE = v_eot  

        INNER JOIN CS_CALENDAR CA
			ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE    
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  i_periodseq  
	;

	
    COMMIT;

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Penalización Ordinaria: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    --Ajuste Manual
    INSERT INTO EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
    SELECT 
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Ajuste Manual' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Ajuste Manual - Unitarios'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Ajuste Manual - Unitarios' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Ajuste Manual - Unitarios'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		IFNULL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		IFNULL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		IFNULL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS 

	FROM CS_PERIOD PER
        INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = v_tenantid 
			AND MEAS.PROCESSINGUNITSEQ = i_processingUnitSeq 
			AND MEAS.PERIODSEQ =  i_periodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Ajuste Manual - Unitarios'

        INNER JOIN TCMP.CS_POSITION POS
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = v_tenantid
			AND POS.EFFECTIVESTARTDATE <= CURRENT_DATE
			AND POS.EFFECTIVEENDDATE > CURRENT_DATE
			AND POS.REMOVEDATE = v_eot  

        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  i_periodseq  
	;


    COMMIT;

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Ajuste Manual: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    --Incentivos
    INSERT INTO EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 

	SELECT   
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Incentivos' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Incentivos - Unitarios'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Incentivos - Unitarios' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Incentivos - Unitarios'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		IFNULL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		IFNULL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		IFNULL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS

	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = v_tenantid 
			AND MEAS.PROCESSINGUNITSEQ = i_processingUnitSeq 
			AND MEAS.PERIODSEQ =  i_periodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Incentivos - Unitarios'

        INNER JOIN TCMP.CS_POSITION POS 
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = v_tenantid
			AND POS.EFFECTIVESTARTDATE <= CURRENT_DATE
			AND POS.EFFECTIVEENDDATE > CURRENT_DATE
			AND POS.REMOVEDATE = v_eot  

        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE    
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  i_periodseq  
	;

	
    COMMIT;

    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Incentivos: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    --Penalización Extraordinaria
    INSERT INTO EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
    SELECT
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Penalizacion Extraordinaria' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Penalizacion Extra - Unitaria'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Penalizacion Extra - Unitaria' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Penalizacion Extra - Unitaria'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		IFNULL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		IFNULL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		IFNULL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS 

	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT MEAS
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = v_tenantid 
			AND MEAS.PROCESSINGUNITSEQ = i_processingUnitSeq 
			AND MEAS.PERIODSEQ =  i_periodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Penalizacion Extra - Unitaria'

        INNER JOIN TCMP.CS_POSITION POS 
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = v_tenantid
			AND POS.EFFECTIVESTARTDATE <= CURRENT_DATE
			AND POS.EFFECTIVEENDDATE > CURRENT_DATE
			AND POS.REMOVEDATE = v_eot  

        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  i_periodseq  
	;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_CAT_TVTA_IP_TOTAL_TEMP '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end