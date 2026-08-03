CREATE PROCEDURE EXT.SMM_SP_INF_CAT_TVTA_INCENPENAL_TEMP( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(50))
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
	
	--SMM_CAT_TVTA_INCEN_PENAL_TEMP
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CAT_TVTA_INCEN_PENAL_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_CAT_TVTA_INCEN_PENAL_TEMP';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CAT_TVTA_INCEN_PENAL_TEMP.', v_log_count, v_idproceso,'info');
	
	v_txtFechaLiquidacion := '';

	IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' v_txtFechaLiquidacion: '||v_txtFechaLiquidacion , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_CAT_TVTA_INCEN_PENAL_TEMP.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_CAT_TVTA_INCEN_PENAL_TEMP ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_CALCULO, 
														CREDITTYPEID, IMPORTE, UNIDAD, EMPRESA, CODIGO_COMERCIAL, FECHA_LIQUIDACION, TERRITORIO, DELEGACION, CAMPANIA, OBSERVACIONES ) 
	SELECT
		PER.PERIODSEQ,
		CR.POSITIONSEQ,
		CR.PAYEESEQ,
		PER.NAME PERIODO,
		SO.ORDERID,
		ST.LINENUMBER,
		ST.SUBLINENUMBER,
		ET.EVENTTYPEID,
		CASE CR.NAME
			WHEN 'CD - CAT TVTA - Captacion - Incentivos'                               THEN 'Incentivos'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Extra'                       THEN 'Penalizacion Extra'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Ordinaria'                   THEN 'Penalizacion Ordinaria'
			WHEN 'CD - CAT TVTA - Recuperacion - Incentivos'                            THEN 'Incentivos'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Extra'                    THEN 'Penalizacion Extra'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Ordinaria'                THEN 'Penalizacion Ordinaria'
			WHEN 'CD - CAT TVTA - MKT - Incentivos'                                     THEN 'Incentivos'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Extra'                             THEN 'Penalizacion Extra'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Ordinaria'                         THEN 'Penalizacion Ordinaria'
			ELSE                                                                         'ERR'
		END AS TIPO_CALCULO,
		CASE CR.NAME
			WHEN 'CD - CAT TVTA - Captacion - Incentivos'                               THEN 'CAT Captacion'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Extra'                       THEN 'CAT Captacion'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Ordinaria'                   THEN 'CAT Captacion'
			WHEN 'CD - CAT TVTA - Recuperacion - Incentivos'                            THEN 'CAT Recuperacion'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Extra'                    THEN 'CAT Recuperacion'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Ordinaria'                THEN 'CAT Recuperacion'
			WHEN 'CD - CAT TVTA - MKT - Incentivos'                                     THEN 'MKT Directo Cotel'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Extra'                             THEN 'MKT Directo Cotel'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Ordinaria'                         THEN 'MKT Directo Cotel'
			ELSE                                                                         'ERR'
		END AS CREDITYPEID,
		CR.VALUE IMPORTE,
		'EURO' UNIDADES,
		CR.GENERICATTRIBUTE11 EMPRESA,
		CR.GENERICATTRIBUTE4 CODIGO_COMERCIAL,
		v_txtFechaLiquidacion,
		CR.GENERICATTRIBUTE7 TERRITORIO,
		CR.GENERICATTRIBUTE10 DELEGACION,
		CR.GENERICATTRIBUTE9 CAMPANIA,
		CR.GENERICATTRIBUTE15 OBSERVACIONES

	FROM CS_PERIOD PER
        INNER JOIN CS_SALESTRANSACTION ST
			ON ST.COMPENSATIONDATE BETWEEN PER.STARTDATE AND ADD_DAYS(PER.ENDDATE, - 1)
			AND ST.TENANTID = v_tenantid
			AND ST.MODELSEQ = 0
			AND ST.PROCESSINGUNITSEQ = i_processingUnitSeq

        INNER JOIN CS_SALESORDER SO 
            ON ST.SALESORDERSEQ = SO.SALESORDERSEQ 
			AND SO.REMOVEDATE = v_eot
			AND SO.PROCESSINGUNITSEQ = i_processingUnitSeq

        INNER JOIN CS_EVENTTYPE ET 
            ON ST.EVENTTYPESEQ = ET.DATATYPESEQ
			AND ET.TENANTID = v_tenantid
			AND ET.REMOVEDATE = v_eot

        INNER JOIN CS_CREDIT CR 
            ON ST.SALESTRANSACTIONSEQ = CR.SALESTRANSACTIONSEQ
			AND CR.TENANTID = v_tenantid 
			AND CR.PROCESSINGUNITSEQ = i_processingUnitSeq 
			AND CR.PERIODSEQ =  i_periodseq
			AND ( CR.NAME = 'CD - CAT TVTA - Captacion - Incentivos'
				OR CR.NAME = 'CD - CAT TVTA - Captacion - Penalizacion Extra'
				OR CR.NAME = 'CD - CAT TVTA - Captacion - Penalizacion Ordinaria'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Incentivos'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Penalizacion Extra'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Penalizacion Ordinaria'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Incentivos'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Penalizacion Extra'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Penalizacion Ordinaria')

        INNER JOIN CS_CREDITTYPE CT 
            ON CR.CREDITTYPESEQ = CT.DATATYPESEQ
			AND CT.TENANTID = v_tenantid
			AND CT.REMOVEDATE = v_eot

        INNER JOIN CS_PLRUN P 
            ON CR.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       

        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  i_periodseq  
	;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_CAT_TVTA_INCEN_PENAL_TEMP '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end