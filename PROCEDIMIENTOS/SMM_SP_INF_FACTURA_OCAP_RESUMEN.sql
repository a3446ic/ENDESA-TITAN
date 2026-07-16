CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_FACTURA_OCAP_RESUMEN( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--SMM_FACTOPE_RESUMEN
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTOPE_RESUMEN.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTOPE_RESUMEN WHERE PERIODO = i_period;
    --nueva tabla para EE y EOSC
    DELETE FROM EXT.SMM_FACTOPE_RESUMEN_EE WHERE PERIODO = i_period;
    DELETE FROM EXT.SMM_FACTOPE_RESUMEN_EOSC WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTOPE_RESUMEN.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_FACTOPE_RESUMEN.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTOPE_RESUMEN (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO, K, 
											PERIODO_OPERACION, CANTIDAD, TOTAL, IMPORTE, YYYYMM_OPERACION, CONCEPTO, ORDEN, DELEGACION, CIF, COD_POSTAL, CALLE, 
											MANTENIMIENTO, ALQUILER)
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,       
        per.NAME,
        sum(EFD.NUM_OPERACIONES) as CANTIDAD,
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        sum(EFD.IMPORTE),
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY') as YYYYMM_OPERACION,
        'TOTAL OPERACIONES'as CONCEPTO,
        0 as ORDEN,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Mantenimiento PC%') as mantenimiento,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Alquiler%') as alquiler
		
    FROM EXT.SMM_FACTOPE_DETALLE efd
        INNER JOIN CS_PERIOD per
            ON PER.STARTDATE <= EFD.FECHA_OPERACION 
            AND PER.ENDDATE > EFD.FECHA_OPERACION
            AND PER.REMOVEDATE=v_eot
        
        INNER JOIN CS_PERIODTYPE PERT
            ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
            AND PERT.removedate=v_eot
            AND pert.name='month'
    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,     
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY'),
        'TOTAL OPERACIONES',
        0,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE;  -- ORDEN       

	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla ENEL_FACTOPE_RESUMEN_EE.' ,  v_log_count, v_idproceso,'info');
                
    INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EE (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO, K, 
												PERIODO_OPERACION, CANTIDAD, TOTAL, IMPORTE, YYYYMM_OPERACION, CONCEPTO, ORDEN, DELEGACION, CIF, COD_POSTAL, CALLE, 
												MANTENIMIENTO, ALQUILER, AJUSTE, POSICION_USUARIO )
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,
        sum(EFD.NUM_OPERACIONES) as CANTIDAD,
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        sum(EFD.IMPORTE),
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY') as YYYYMM_OPERACION,
        'TOTAL OPERACIONES'as CONCEPTO,
        0 as ORDEN,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Mantenimiento PC%') as mantenimiento,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Alquiler%') as alquiler,
		--MPR incluimos los ajustes en RC OCAP
		(select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_credit_temp cred where efd.periodseq=cred.periodseq and efd.payeeseq=cred.payeeseq and efd.positionseq=cred.positionseq 
            /*BOM APM 27.03.2026 Old Code*/
            and cred.genericattribute2 in(180,181,242) --APM 22.06.2026 Se descomenta.
            --New Code
            --and cred.genericattribute2 in(180,181) --APM 22.06.2026 Se comenta.
            /*EOM APM 27.03.2026*/
            and cred.name like 'CD - ATC - Ajustes Manuales') as ajuste,
        EFD.POSICION_USUARIO --APM 25.02.2025
 
    FROM EXT.SMM_FACTOPE_DETALLE_EE efd
        INNER JOIN CS_PERIOD per
            ON PER.STARTDATE <= EFD.FECHA_OPERACION 
            AND PER.ENDDATE > EFD.FECHA_OPERACION
            AND PER.REMOVEDATE=v_eot
        
        INNER JOIN CS_PERIODTYPE PERT
            ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
            AND PERT.removedate=v_eot
            AND pert.name='month'

    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,     
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY'),
        'TOTAL OPERACIONES',
        0,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,  -- ORDEN  
        EFD.POSICION_USUARIO;

	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN_EE '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla ENEL_FACTOPE_RESUMEN_EOSC.' ,  v_log_count, v_idproceso,'info');
            
    INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EOSC (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO, K, 
												PERIODO_OPERACION, CANTIDAD, TOTAL, IMPORTE, YYYYMM_OPERACION, CONCEPTO, ORDEN, DELEGACION, CIF, COD_POSTAL, CALLE, 
												MANTENIMIENTO, ALQUILER, AJUSTE, POSICION_USUARIO, ROL, PROVEEDOR )
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,
        sum(EFD.NUM_OPERACIONES) as CANTIDAD,
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        sum(EFD.IMPORTE),
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY') as YYYYMM_OPERACION,
        'TOTAL OPERACIONES'as CONCEPTO,
        0 as ORDEN,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Mantenimiento PC%') as mantenimiento,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Alquiler%' and incen.name not like '%MR%') as alquiler,
		--MPR incluimos los ajustes en RC OCAP
		(select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_credit_temp cred where efd.periodseq=cred.periodseq and efd.payeeseq=cred.payeeseq and efd.positionseq=cred.positionseq 
            /*BOM APM 18.03.2026 Old Code*/
            and cred.genericattribute2 = 179 and cred.name like 'CD - ATC - Ajustes Manuales') as ajuste, --APM 22.06.2026 Se descomenta.
            --New Code
            --and (cred.genericattribute2 = 179 or cred.genericattribute2 = 242)  and cred.name like 'CD - ATC - Ajustes Manuales') as ajuste, --APM 22.06.2026 Se comenta.
            /*EOM APM 18.03.2026*/
        EFD.POSICION_USUARIO, --APM 25.02.2025
        EFD.ROL AS ROL, --APM 08.08.2025
        EFD.PROVEEDOR --APM 28.04.2026

    FROM EXT.SMM_FACTOPE_DETALLE_EOSC efd
        INNER JOIN CS_PERIOD per
            ON PER.STARTDATE <= EFD.FECHA_OPERACION 
            AND PER.ENDDATE > EFD.FECHA_OPERACION
            AND PER.REMOVEDATE=v_eot
        
        INNER JOIN CS_PERIODTYPE PERT
            ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
            AND PERT.removedate=v_eot
            AND pert.name='month'
    where rol='ML' or rol is null
    
    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,     
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY'),
        'TOTAL OPERACIONES',
        0,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,  -- ORDEN   
        EFD.POSICION_USUARIO,
        EFD.ROL,
        EFD.PROVEEDOR; --APM 29.04.2026
            
    
    COMMIT;

-- DMS añadir otro insert para separar ML y MR para el campo Alquiler
    INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EOSC (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO, K, 
												PERIODO_OPERACION, CANTIDAD, TOTAL, IMPORTE, YYYYMM_OPERACION, CONCEPTO, ORDEN, DELEGACION, CIF, COD_POSTAL, CALLE, 
												MANTENIMIENTO, ALQUILER, AJUSTE, POSICION_USUARIO, ROL, PROVEEDOR )
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,
        sum(EFD.NUM_OPERACIONES) as CANTIDAD,
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        sum(EFD.IMPORTE),
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY') as YYYYMM_OPERACION,
        'TOTAL OPERACIONES'as CONCEPTO,
        0 as ORDEN,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Mantenimiento PC%') as mantenimiento,
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_incen_temp incen where efd.periodseq=incen.periodseq and efd.payeeseq=incen.payeeseq and efd.positionseq=incen.positionseq and incen.name like '%Alquiler MR%') as alquiler,
		--MPR incluimos los ajustes en RC OCAP
		(select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) from EXT.SMM_credit_temp cred where efd.periodseq=cred.periodseq and efd.payeeseq=cred.payeeseq and efd.positionseq=cred.positionseq 
            /*BOM APM 18.03.2026 Old Code*/
            --and cred.genericattribute2 = 179 and cred.name like 'CD - ATC - Ajustes Manuales') as ajuste,
            --New Code
            and cred.genericattribute2 = 277 and cred.name like 'CD - ATC - Ajustes Manuales') as ajuste,
            /*EOM APM 18.03.2026*/
        EFD.POSICION_USUARIO, --APM 25.02.2025
        EFD.ROL AS ROL, --APM 08.08.2025
        EFD.PROVEEDOR --APM 29.04.2026

    FROM EXT.SMM_FACTOPE_DETALLE_EOSC efd
        INNER JOIN CS_PERIOD per
            ON PER.STARTDATE <= EFD.FECHA_OPERACION 
            AND PER.ENDDATE > EFD.FECHA_OPERACION
            AND PER.REMOVEDATE=v_eot
        
        INNER JOIN CS_PERIODTYPE PERT
            ON PER.PERIODTYPESEQ=PERT.PERIODTYPESEQ
            AND PERT.removedate=v_eot
            AND pert.name='month'
    where rol='MR'
    
    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        per.NAME,     
        to_char(EFD.FECHA_OPERACION, 'MM/YYYY'),
        'TOTAL OPERACIONES',
        0,
        EFD.DELEGACION,
        EFD.CIF,
        EFD.COD_POSTAL,
        EFD.CALLE,  -- ORDEN   
        EFD.POSICION_USUARIO,
        EFD.ROL,
        EFD.PROVEEDOR; --APM 29.04.2026
            
    
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN_EOSC: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando INCENTIVOS en tabla ENEL_FACTOPE_RESUMEN - incentivos.' ,  v_log_count, v_idproceso,'info');  
      
    INSERT INTO EXT.SMM_FACTOPE_RESUMEN (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO, CANTIDAD, IMPORTE,  	
											PERIODO_OPERACION, YYYYMM_OPERACION, CONCEPTO, ORDEN )                                                    
    SELECT
        INCENTMP.PERIODO,
        INCENTMP.PERIODSEQ, 
        INCENTMP.PAYEESEQ, 
        INCENTMP.POSITIONSEQ,
        TMP_PDS.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.PROVINCIA,
        TMP_PDS.POBLACION,
        TMP_PDS.TIPO_IMPOSITIVO,            
        1 as CANTIDAD,
        INCENTMP.VALUE,
        '' PERIODO_OPERACION,
        '' YYYYMM_OPERACION,
        INCENTMP.GENERICATTRIBUTE3 as CONCEPTO,
        0 as ORDEN
    
    FROM EXT.SMM_INCEN_TEMP INCENTMP
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 

    WHERE INCENTMP.NAME in ('I - ATC - Alquiler','I - ATC - Mantenimiento PC','I - ATC - Variable Calidad - Importe Pago')
    or incentmp.name like 'I - Captacion - Promo Prescriptores - %'
    or incentmp.name like 'I - Captacion - Incentivo Crecimiento - %';
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN - incentivos: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla ENEL_FACTOPE_RESUMEN_EE - incentivos.' ,  v_log_count, v_idproceso,'info');
	
    INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EE (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO, CANTIDAD, IMPORTE,  
												PERIODO_OPERACION, YYYYMM_OPERACION, CONCEPTO, ORDEN )                                                    
    SELECT
        INCENTMP.PERIODO,
        INCENTMP.PERIODSEQ, 
        INCENTMP.PAYEESEQ, 
        INCENTMP.POSITIONSEQ,
        TMP_PDS.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.PROVINCIA,
        TMP_PDS.POBLACION,
        TMP_PDS.TIPO_IMPOSITIVO,            
        1 as CANTIDAD,
        INCENTMP.VALUE,
        '' PERIODO_OPERACION,
        '' YYYYMM_OPERACION,
        INCENTMP.GENERICATTRIBUTE3 as CONCEPTO,
        0 as ORDEN
    
    FROM EXT.SMM_INCEN_TEMP INCENTMP
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 

    WHERE INCENTMP.NAME in ('I - ATC - Alquiler','I - ATC - Mantenimiento PC','I - ATC - Variable Calidad - Importe Pago')
    or incentmp.name like 'I - Captacion - Promo Prescriptores - %'
    or incentmp.name like 'I - Captacion - Incentivo Crecimiento - %';

	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN_EE - incentivos: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla ENEL_FACTOPE_RESUMEN_EOSC - incentivos.' ,  v_log_count, v_idproceso,'info');
	
    INSERT INTO EXT.SMM_FACTOPE_RESUMEN_EOSC (PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, TIPO_IMPOSITIVO,
                                              CANTIDAD, IMPORTE,  PERIODO_OPERACION, YYYYMM_OPERACION, CONCEPTO, ORDEN,
                                              ALQUILER, POSICION_USUARIO, NOMBRE_REGLA, CIF, COD_POSTAL, CALLE)                                                    
    SELECT
        INCENTMP.PERIODO,
        INCENTMP.PERIODSEQ, 
        INCENTMP.PAYEESEQ, 
        INCENTMP.POSITIONSEQ,
        TMP_PDS.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.PROVINCIA,
        TMP_PDS.POBLACION,
        TMP_PDS.TIPO_IMPOSITIVO,            
        1 as CANTIDAD,
        INCENTMP.VALUE,
        '' PERIODO_OPERACION,
        '' YYYYMM_OPERACION,
        INCENTMP.GENERICATTRIBUTE3 as CONCEPTO,
        0 as ORDEN,
        /*BOM APM 18.06.2026 New Code*/
        (select TRIM(replace(to_char(sum(VALUE) , '9999999999990D99'), ',', '.')) 
            from EXT.SMM_incen_temp incen 
            where INCENTMP.periodseq=incen.periodseq 
            and TMP_PDS.payeeseq=incen.payeeseq 
            and TMP_PDS.RULEELEMENTOWNERSEQ=incen.positionseq 
            and incen.name like '%Alquiler MR%') as alquiler,
        TMP_PDS.POSICION_USUARIO,
        INCENTMP.NAME as NOMBRE_REGLA,
        /*EOM APM 18.06.2026*/
		/*BOM APM 30.06.2026 New Code*/
        TMP_PDS.CIF, 
        TMP_PDS.COD_POSTAL,
        TMP_PDS.CALLE
        /*EOM APM 30.06.2026*/	
        
    FROM EXT.SMM_INCEN_TEMP INCENTMP
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 

    WHERE INCENTMP.NAME in ('I - ATC - Alquiler','I - ATC - Mantenimiento PC','I - ATC - Variable Calidad - Importe Pago')
    or incentmp.name like 'I - Captacion - Promo Prescriptores - %'
    or incentmp.name like 'I - Captacion - Incentivo Crecimiento - %'
    or incentmp.name like 'I - ATC - Remun Comercial - Alquiler MR%' --APM 17.06.2026
    ;

	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_FACTOPE_RESUMEN_EE - incentivos: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
   
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla FACTOPE_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;