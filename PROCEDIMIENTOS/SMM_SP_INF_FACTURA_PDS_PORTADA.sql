CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_FACTURA_PDS_PORTADA( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: FATURA PDS - DETALLE - Prefactura Portada/Detalle
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
	DECLARE v_fechaActual DATE;
	
	
	

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
	
	--SMM_FACTPDS_PORTADA
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTPDS_PORTADA.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTPDS_PORTADA WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTPDS_PORTADA.', v_log_count, v_idproceso,'info');
	
	v_fechaActual := CURRENT_DATE;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_FACTPDS_PORTADA.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTPDS_PORTADA ( PERIODO, PERIODSEQ, NUMERO_RESUMEN, MES_LIQUIDACION, FECHA_LIQUIDACION, PAYEESEQ, POSITIONSEQ, CIF, CODIGOE4E,  
                                                ZONA, PDS, NOMBRE_FISCAL, CALLE, COD_POSTAL, POBLACION, PROVINCIA, IDPROVEEDOR, FICHERO, DESCRIPCION, 
                                                CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, COD_CONTRATO, ACTIVIDAD, DETALLE_ACTIVIDAD, PRECIO_UNITARIO, 
                                                CANTIDAD, IMPORTE_TOTAL, WBE, NOMBRE )   
    SELECT 
        FAPDET.PERIODO,
        FAPDET.PERIODSEQ,
        substr(FAPDET.MES_LIQUIDACION,1,4) || '/'||  FAPDET.PDS as NUMERO_RESUMEN ,  -- YYYY/PDS
        FAPDET.MES_LIQUIDACION,
        v_fechaActual as FECHA_LIQUIDACION,
        FAPDET.PAYEESEQ,
        FAPDET.POSITIONSEQ,
        FAPDET.CIF,
        FAPDET.CODIGOE4E,
        FAPDET.DELEGACION AS ZONA,
        FAPDET.PDS,
        FAPDET.NOMBRE_FISCAL,
        FAPDET.CALLE,
        FAPDET.COD_POSTAL,
        FAPDET.POBLACION,
        FAPDET.PROVINCIA,
        FAPDET.IDPROVEEDOR,
        FAPDET.FICHERO,
        FAPDET.DESCRIPCION,
        FAPDET.CONCEPTO_LIQ,
        FAPDET.DESC_CONCEPTO_LIQ,
        FAPDET.COD_CONTRATO,
        FAPDET.ACTIVIDAD,
        FAPDET.DETALLE_ACTIVIDAD,
        FAPDET.VALUE as PRECIO_UNITARIO,
        sum(FAPDET.CANTIDAD),
        sum(FAPDET.CANTIDAD * FAPDET.VALUE) AS IMPORTE_TOTAL,
        FAPDET.WBE as WBE,
        FAPDET.credittypeid as Nombre --APM 15.01.2025 incluimos el campo para filtrar por regla

    FROM EXT.SMM_FACTPDS_DETALLE fapDet
    WHERE FAPDET.PERIODSEQ = i_periodseq
    GROUP BY
        FAPDET.PERIODO,
        FAPDET.PERIODSEQ,
        substr(FAPDET.MES_LIQUIDACION,1,4) || '/'||  FAPDET.PDS,
        FAPDET.MES_LIQUIDACION,
        v_fechaActual,
        FAPDET.PAYEESEQ,
        FAPDET.POSITIONSEQ,
        FAPDET.CIF,
        FAPDET.CODIGOE4E,
        FAPDET.DELEGACION,
        FAPDET.PDS,
        FAPDET.NOMBRE_FISCAL,
        FAPDET.CALLE,
        FAPDET.COD_POSTAL,
        FAPDET.POBLACION,
        FAPDET.PROVINCIA,
        FAPDET.IDPROVEEDOR,
        FAPDET.FICHERO,
        FAPDET.DESCRIPCION,
        FAPDET.CONCEPTO_LIQ,
        FAPDET.DESC_CONCEPTO_LIQ,
        FAPDET.COD_CONTRATO,
        FAPDET.ACTIVIDAD,
        FAPDET.DETALLE_ACTIVIDAD,
        FAPDET.VALUE,
        FAPDET.WBE,
        FAPDET.credittypeid
    ORDER BY PDS;   
    
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_FACTPDS_PORTADA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
   
    
   
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;