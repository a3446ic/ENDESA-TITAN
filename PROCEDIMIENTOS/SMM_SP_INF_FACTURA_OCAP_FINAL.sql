CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_FACTURA_OCAP_FINAL( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--ENEL_FACTOPE_TOTAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTOPE_TOTAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTOPE_FINAL_EE WHERE PERIODO = i_period;
    DELETE FROM EXT.SMM_FACTOPE_FINAL_EOSC WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTOPE_TOTAL.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.ENEL_FACTOPE_TOTAL.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTOPE_FINAL_EOSC	(PERIODO, OCAP, NOMBRE_FISCAL, ENTRADA, TIPO, SUBTIPO, MES, PROBLACION, PROVINCIA, TIPO_IMPOSITIVO, 
												NUM_OPERACIONES, UNIDAD_BAREMACION, K, TOTAL_OPERACIONES, AGRUPA_EN_FACTURA, DELEGACION, PERIODO_DOS, POSICION_USUARIO, ROL,genericnumber5)
    SELECT
        case 
			when EFT.periodo is not null then eft.periodo
			else ''||i_period 
		end as periodo,
        ETS.OCAP, 
		case when EFT.NOMBRE_FISCAL is not null then EFT.NOMBRE_FISCAL else  ETS.NOMBRE_FISCAL end nombre_fiscal,
		ETS.ENTRADA,
		ETS.TIPO,
		ETS.SUBTIPO,
		CASE 
			WHEN EFT.MES_PERIODO = EFT.MES_OPERACION THEN '' 
			ELSE EFT.MES_OPERACION 
		END as MES,
		EFT.POBLACION,
		EFT.PROVINCIA,
		EFT.TIPO_IMPOSITIVO,
		case when EFT.NUM_OPERACIONES is not null then EFT.NUM_OPERACIONES else 0 end as num_operaciones,
		case when EFT.UNIDAD_BAREMACION is not null then EFT.UNIDAD_BAREMACION else ets.ub end as UNIDAD_BAREMACION,
		EFT.K,
		case when EFT.TOTAL_OPERACIONES is not null then EFT.TOTAL_OPERACIONES else 0 end as TOTAL_OPERACIONES,
		EFT.AGRUPA_EN_FACTURA,
		case when EFT.DELEGACION is not null then EFT.DELEGACION else ets.delegacion end delegacion,
		(select per.name
			from cs_period per
			INNER JOIN CS_PERIODTYPE PERT ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
			AND PERT.removedate  = v_eot
			AND pert.name='month'
			where per.removedate = v_eot
			and per.calendarseq = 2251799813685249 
			and per.startdate = 
				(select ADD_MONTHS(per.startdate, -1) 
					from cs_period per
					INNER JOIN CS_PERIODTYPE PERT ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
					AND PERT.removedate  = v_eot
					AND pert.name='month'
					where PER.removedate  = v_eot 
					and per.periodseq = i_periodseq)),
        EFT.POSICION_USUARIO, --APM 25.02.2025
        EFT.ROL, --APM 08.08.2025
        EFT.genericnumber5

    FROM  EXT.SMM_FACTOPE_TOTAL_EOSC EFT 
		RIGHT JOIN EXT.SMM_ENTRADA_TIPO_SUBTIPO_TEMP ETS ON
			CONCAT(EFT.OCAP_PDS , CONCAT(' - ', CONCAT(EFT.TIPO_ENTRADA, CONCAT (' - ' , CONCAT( EFT.TIPO_OPERACION, CONCAT( ' - ', EFT.SUBTIPO_OPERACION)))))) = ETS.UNIFICA 
			AND (periodo = i_period OR PERIODO IS NULL)
    WHERE 
        ETS.EMPRESA like 'EOSC'
        
		
    ORDER BY ETS.OCAP, EFT.ORDEN, ETS.ENTRADA, ETS.TIPO, ETS.SUBTIPO;   
    
    INSERT INTO EXT.SMM_FACTOPE_FINAL_EE (PERIODO, OCAP, NOMBRE_FISCAL, ENTRADA, TIPO, SUBTIPO, MES, PROBLACION, PROVINCIA, TIPO_IMPOSITIVO, 
												NUM_OPERACIONES, UNIDAD_BAREMACION, K, TOTAL_OPERACIONES, AGRUPA_EN_FACTURA, DELEGACION, PERIODO_DOS, POSICION_USUARIO)
    SELECT
        case 
			when EFT.periodo is not null then eft.periodo
			else ''||i_period 
		end as periodo,
        ETS.OCAP, 
		case when EFT.NOMBRE_FISCAL is not null then EFT.NOMBRE_FISCAL else  ETS.NOMBRE_FISCAL end nombre_fiscal,
		ETS.ENTRADA,
		ETS.TIPO,
		ETS.SUBTIPO,
		CASE 
			WHEN EFT.MES_PERIODO = EFT.MES_OPERACION THEN '' 
			ELSE EFT.MES_OPERACION 
		END as MES,
		EFT.POBLACION,
		EFT.PROVINCIA,
		EFT.TIPO_IMPOSITIVO,
		case when EFT.NUM_OPERACIONES is not null then  EFT.NUM_OPERACIONES else 0 end as num_operaciones,
		case when EFT.UNIDAD_BAREMACION is not null then  EFT.UNIDAD_BAREMACION else ets.ub end as UNIDAD_BAREMACION,
		EFT.K,
		case when EFT.TOTAL_OPERACIONES is not null then  EFT.TOTAL_OPERACIONES else 0 end as TOTAL_OPERACIONES,
		EFT.AGRUPA_EN_FACTURA,
		case when EFT.DELEGACION is not null then EFT.DELEGACION else ets.delegacion end delegacion,
		(select per.name
			from cs_period per
			INNER JOIN CS_PERIODTYPE PERT ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
			AND PERT.removedate  = v_eot
			AND pert.name='month'
			where per.removedate = v_eot
			and per.calendarseq = 2251799813685249 
			and per.startdate = 
				(select ADD_MONTHS(per.startdate, -1) 
					from cs_period per
					INNER JOIN CS_PERIODTYPE PERT ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
					AND PERT.removedate  = v_eot
					AND pert.name='month'
					where PER.removedate  = v_eot 
					and per.periodseq = i_periodseq)),
        EFT.POSICION_USUARIO

    FROM  EXT.SMM_FACTOPE_TOTAL_EE EFT 
		RIGHT JOIN EXT.SMM_ENTRADA_TIPO_SUBTIPO_TEMP ETS ON
			CONCAT(EFT.OCAP_PDS , CONCAT(' - ', CONCAT(EFT.TIPO_ENTRADA, CONCAT (' - ' , CONCAT( EFT.TIPO_OPERACION, CONCAT( ' - ', EFT.SUBTIPO_OPERACION)))))) = ETS.UNIFICA 
			AND (periodo = i_period OR PERIODO IS NULL)
    WHERE 
        ETS.EMPRESA like 'EE'
	
    ORDER BY ETS.OCAP, EFT.ORDEN, ETS.ENTRADA, ETS.TIPO, ETS.SUBTIPO; 
    
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN_EE - incentivos: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
   
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla FACTOPE_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;