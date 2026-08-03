CREATE PROCEDURE EXT.SMM_SP_INF_FACTURA_CAT_TVTA_PORTADA ( IN i_period VARCHAR(25))
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
		|| ' || i_period: ' || i_period
		, v_log_count, v_idproceso,'info');
	
	--SMM_FACTCAT_TVTA_PORTADA
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTCAT_TVTA_PORTADA.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTCAT_TVTA_PORTADA WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTCAT_TVTA_PORTADA.', v_log_count, v_idproceso,'info');
	
	v_fechaActual :=  CURRENT_DATE;

   INSERT INTO EXT.SMM_FACTCAT_TVTA_PORTADA ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, MES_LIQUIDACION, FECHA_LIQUIDACION, NUMERO_RESUMEN, NOMBRE_FISCAL, 
													CODIGO_COMERCIAL, CIF, DIRECCION, COD_POSTAL, PROVINCIA, DELEGACION, CANAL, PRODUCTO, TERRITORIO, PROVEEDOR, 
													UNIDADES, PB_UNITARIO_MEDIO, IMPORTE_FINAL,PROVEEDOR2 ) 
	--Hacemos una subconsulta para aquellas combinaciones de canal/producto/territorio con diferentes valores unitarios medios. Así evitamos tener dos SUR con dos unitarios medios diferentes
    SELECT 
		X.PAYEESEQ,
		X.POSITIONSEQ,
		X.PERIODSEQ,
		X.PERIODO,
		X.MES_LIQUIDACION,
		X.FECHA_LIQUIDACION,
		X.NUMERO_RESUMEN,
		X.NOMBRE_FISCAL,
		X.CODIGO_COMERCIAL,
		X.CIF,
		X.DIRECCION,
		X.COD_POSTAL,
		X.PROVINCIA,
		X.DELEGACION,
		X.CANAL,
		X.PRODUCTO,
		X.TERRITORIO,
		X.PROVEEDOR,
		SUM(X.UNIDADES),
		SUM(IMPORTE_TOTAL) / SUM (UNIDADES) AS PB_UNITARIO_MEDIO,
		SUM(IMPORTE_TOTAL),
        X.PROVEEDOR2
	FROM
		(SELECT    
			FACDET.PAYEESEQ,
			FACDET.POSITIONSEQ,
			FACDET.PERIODSEQ,
			FACDET.PERIODO,
			FACDET.MES_LIQUIDACION,
			v_fechaActual as FECHA_LIQUIDACION,
			--, SUBSTR(FACDET.MES_LIQUIDACION,1,4) || '/'||  FACDET.CODIGO_COMERCIAL as NUMERO_RESUMEN  -- YYYY/PDS
			FACDET.MES_LIQUIDACION || '/' || FACDET.CODIGO_COMERCIAL as NUMERO_RESUMEN, --YYYYMM/PDS
			FACDET.NOMBRE_FISCAL,
			FACDET.CODIGO_COMERCIAL,
			FACDET.CIF,
			FACDET.DIRECCION,
			FACDET.COD_POSTAL,
			FACDET.PROVINCIA,
			'' AS DELEGACION, --Valor de delegación a nulo
			--, FACDET.DELEGACION
			FACDET.CANAL,
			FACDET.PRODUCTO,
			FACDET.TERRITORIO,
			FACDET.PROVEEDOR,
			COUNT(*) UNIDADES,
			FACDET.PB_UNITARIO_MEDIO,
			COUNT(*) * FACDET.PB_UNITARIO_MEDIO AS IMPORTE_TOTAL,
            FACDET.PROVEEDOR2

		FROM EXT.SMM_FACTCAT_TVTA_DETALLE FACDET
		WHERE FACDET.PERIODO = i_period
		GROUP BY   
			FACDET.PAYEESEQ,
			FACDET.POSITIONSEQ,
			FACDET.PERIODSEQ,
			FACDET.PERIODO,
			FACDET.MES_LIQUIDACION,
			SUBSTR(FACDET.MES_LIQUIDACION,1,4) || '/'||  FACDET.CODIGO_COMERCIAL,
			FACDET.NOMBRE_FISCAL,
			FACDET.CODIGO_COMERCIAL,
			FACDET.CIF,
			FACDET.DIRECCION,
			FACDET.COD_POSTAL,
			FACDET.PROVINCIA,
			--, FACDET.DELEGACION
			FACDET.CANAL,
			FACDET.PRODUCTO,
			FACDET.TERRITORIO,
			FACDET.PROVEEDOR,
			FACDET.PB_UNITARIO_MEDIO,
            FACDET.PROVEEDOR2
		) X

    GROUP BY 
		X.PAYEESEQ,
		X.POSITIONSEQ,
		X.PERIODSEQ,
		X.PERIODO,
		X.MES_LIQUIDACION,
		X.FECHA_LIQUIDACION,
		X.NUMERO_RESUMEN,
		X.NOMBRE_FISCAL,
		X.CODIGO_COMERCIAL,
		X.CIF,
		X.DIRECCION,
		X.COD_POSTAL,
		X.PROVINCIA,
		X.DELEGACION,
		X.CANAL,
		X.PRODUCTO,
		X.TERRITORIO,
		X.PROVEEDOR,
        X.PROVEEDOR2
	;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_FACTCAT_TVTA_PORTADA '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end