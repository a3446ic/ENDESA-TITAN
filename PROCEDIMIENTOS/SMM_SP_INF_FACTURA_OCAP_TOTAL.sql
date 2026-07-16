CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_FACTURA_OCAP_TOTAL( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--SMM_FACTOPE_TOTAL
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTOPE_TOTAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTOPE_DETALLE WHERE PERIODO = i_period;
    --nueva tabla para EE y EOSC
    DELETE FROM EXT.SMM_FACTOPE_TOTAL_EE WHERE PERIODO = i_period;
    DELETE FROM EXT.SMM_FACTOPE_TOTAL_EOSC WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTOPE_TOTAL.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_FACTOPE_TOTAL.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTOPE_TOTAL (PERIODO,PERIODSEQ, MES_PERIODO, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, 
                                            TIPO_IMPOSITIVO, K, MES_OPERACION, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, UNIDAD_BAREMACION,
                                            AGRUPA_EN_FACTURA, ORDEN, NUM_OPERACIONES, TOTAL_OPERACIONES, DELEGACION)                                         
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.MES_PERIODO,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        EFD.MES_OPERACION,
        EFD.TIPO_ENTRADA,
        EFD.TIPO_OPERACION,
        EFD.SUBTIPO_OPERACION,
        EFD.UNIDAD_BAREMACION,
        EFD.AGRUPA_EN_FACTURA,
        0 as ORDEN,
        SUM(EFD.NUM_OPERACIONES),
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        EFD.DELEGACION

    FROM EXT.SMM_FACTOPE_DETALLE efd

    WHERE 
        TIPO_ENTRADA is not null

    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.MES_PERIODO,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        EFD.MES_OPERACION,
        EFD.TIPO_ENTRADA,
        EFD.TIPO_OPERACION,
        EFD.SUBTIPO_OPERACION,
        EFD.UNIDAD_BAREMACION,
        EFD.AGRUPA_EN_FACTURA,
        0,
        EFD.DELEGACION
    
    ORDER BY EFD.TIPO_ENTRADA, EFD.TIPO_OPERACION, EFD.SUBTIPO_OPERACION;    
    
    INSERT INTO EXT.SMM_FACTOPE_TOTAL_EE (PERIODO,PERIODSEQ, MES_PERIODO, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, 
                                            TIPO_IMPOSITIVO, K, MES_OPERACION, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, UNIDAD_BAREMACION,
                                            AGRUPA_EN_FACTURA, ORDEN, NUM_OPERACIONES, TOTAL_OPERACIONES, DELEGACION, POSICION_USUARIO)                                                
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.MES_PERIODO,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        EFD.MES_OPERACION,
        EFD.TIPO_ENTRADA,
        EFD.TIPO_OPERACION,
        EFD.SUBTIPO_OPERACION,
        EFD.UNIDAD_BAREMACION,
        EFD.AGRUPA_EN_FACTURA,
        0 as ORDEN,
        SUM(EFD.NUM_OPERACIONES),
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        EFD.DELEGACION,
        EFD.POSICION_USUARIO --APM 25.02.2025
        
    FROM EXT.SMM_FACTOPE_DETALLE_EE efd

    WHERE 
        TIPO_ENTRADA is not null

    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.MES_PERIODO,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,       
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        EFD.MES_OPERACION,
        EFD.TIPO_ENTRADA,
        EFD.TIPO_OPERACION,
        EFD.SUBTIPO_OPERACION,
        EFD.UNIDAD_BAREMACION,
        EFD.AGRUPA_EN_FACTURA,
        0,
        EFD.DELEGACION,
        EFD.POSICION_USUARIO
    
    ORDER BY EFD.TIPO_ENTRADA, EFD.TIPO_OPERACION, EFD.SUBTIPO_OPERACION;    
    
    INSERT INTO EXT.SMM_FACTOPE_TOTAL_EOSC (PERIODO,PERIODSEQ, MES_PERIODO, PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA, POBLACION, 
                                                TIPO_IMPOSITIVO, K, MES_OPERACION, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, UNIDAD_BAREMACION,
                                                AGRUPA_EN_FACTURA, ORDEN, NUM_OPERACIONES, TOTAL_OPERACIONES, DELEGACION, POSICION_USUARIO,GENERICNUMBER5, ROL,TIPO_PRESTADOR)                                                
    SELECT
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.MES_PERIODO,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        EFD.MES_OPERACION,
        EFD.TIPO_ENTRADA,
        EFD.TIPO_OPERACION,
        EFD.SUBTIPO_OPERACION,
        EFD.UNIDAD_BAREMACION,
        EFD.AGRUPA_EN_FACTURA,
        0 as ORDEN,
        SUM(EFD.NUM_OPERACIONES),
        SUM(EFD.NUM_OPERACIONES * EFD.UNIDAD_BAREMACION)  as TOTAL,
        EFD.DELEGACION,
        EFD.POSICION_USUARIO, --APM 25.02.2025
		EFD.GENERICNUMBER5,
        EFD.ROL, --APM 08.08.2025
        EFD.TIPO_PRESTADOR --DMS 26.05.2026

    FROM EXT.SMM_FACTOPE_DETALLE_EOSC efd

    WHERE 
        TIPO_ENTRADA is not null
        AND CREDITTYPEID NOT LIKE 'ATC - Ajuste Manual'

    GROUP BY 
        EFD.PERIODO,
        EFD.PERIODSEQ,
        EFD.MES_PERIODO,
        EFD.PAYEESEQ,
        EFD.POSITIONSEQ,
        EFD.OCAP_PDS,        
        EFD.NOMBRE_FISCAL,
        EFD.PROVINCIA,
        EFD.POBLACION,
        EFD.TIPO_IMPOSITIVO,
        EFD.K,
        EFD.MES_OPERACION,
        EFD.TIPO_ENTRADA,
        EFD.TIPO_OPERACION,
        EFD.SUBTIPO_OPERACION,
        EFD.UNIDAD_BAREMACION,
        EFD.AGRUPA_EN_FACTURA,
        0,
        EFD.DELEGACION,
        EFD.POSICION_USUARIO,
		EFD.GENERICNUMBER5,
        EFD.ROL,
        EFD.TIPO_PRESTADOR

    ORDER BY EFD.TIPO_ENTRADA, EFD.TIPO_OPERACION, EFD.SUBTIPO_OPERACION;    
    

   
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla FACTOPE_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;