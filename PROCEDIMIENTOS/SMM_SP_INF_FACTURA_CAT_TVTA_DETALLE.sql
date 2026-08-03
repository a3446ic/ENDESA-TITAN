CREATE PROCEDURE EXT.SMM_SP_INF_FACTURA_CAT_TVTA_DETALLE ( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(50))
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
	DECLARE v_fechaPeriodoSiguiente DATE;
	DECLARE v_txtMes_Liquidacion VARCHAR(10);
	

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
	
	--SMM_FACTCAT_TVTA_DETALLE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTCAT_TVTA_DETALLE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_FACTCAT_TVTA_DETALLE WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTCAT_TVTA_DETALLE.', v_log_count, v_idproceso,'info');
	
	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(i_periodseq);

    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' v_txtMes_Liquidacion: '||v_txtMes_Liquidacion , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_FACTCAT_TVTA_DETALLE.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTCAT_TVTA_DETALLE ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, MES_LIQUIDACION, NOMBRE_FISCAL, DIRECCION, COD_POSTAL, PROVINCIA, CIF, ORDERID,
													CANAL, PRODUCTO, TERRITORIO, HERRAMIENTA, BBDD, EMPRESA, CODIGO_COMERCIAL, DELEGACION, CAMPANIA, PB_UNITARIO_MEDIO, PROVEEDOR,
                                                    SUBCANAL,PROVEEDOR2) 
	SELECT
		PAGO.PAYEESEQ,
		PAGO.POSITIONSEQ,
		PAGO.PERIODSEQ,
		PAGO.PERIODO,
		v_txtMes_Liquidacion MES_LIQUIDACION,
		PA.LASTNAME NOMBRE_FISCAL,
		PA.GENERICATTRIBUTE3 DIRECCION,
		PA.GENERICATTRIBUTE4 COD_POSTAL,
		PA.GENERICATTRIBUTE5 PROVINCIA,
		PA.GENERICATTRIBUTE1 CIF,
		PAGO.CONTRATO ORDERID,
		PAGO.CREDITTYPEID CANAL,
/* BOM CAL0134 DCR 19.04.2022 
Old Code 
		PROV.SUBACTIVIDAD PRODUCTO,
New code */
        PAGO.PRODUCTO PRODUCTO,
/* EOM CAL0134 DCR 19.04.2022 */
		PAGO.TERRITORIO,
		PAGO.HERRAMIENTA,
		PAGO.BBDD,
		PAGO.EMPRESA,
		PAGO.CODIGO_COMERCIAL,
		PAGO.DELEGACION,
		PAGO.CAMPANIA,
		PAGO.VALOR_FINAL,
		PAGO.PROVEEDOR,
/* BOM CAL0134 DCR 19.04.2022 */
        POS.NAME as SUBCANAL,
        PAGO.PROVEEDOR2
/* EOM CAL0134 DCR 19.04.2022 */

	FROM EXT.SMM_CAT_TVTA_RESUM_PAGO PAGO
/* BOM CAL0134 DCR 19.04.2022 
Old Code
		INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA PROV
			ON PAGO.PROVEEDOR = PROV.IDPROVEEDOR 
			AND PAGO.PERIODSEQ = PROV.PERIODSEQ
*/
        --LEFT JOIN ENEL_PRODUCTOS_TEMP_CAT_TVTA PROD
          --  ON PROD.PRODUCTID = PAGO.CONCEPTO_LIQ
/* EOM CAL0134 DCR 19.04.2022 */
        INNER JOIN CS_PERIOD PER
			ON PAGO.PERIODSEQ = PER.PERIODSEQ
			AND PER.REMOVEDATE = v_eot      
			AND PER.PERIODSEQ =  i_periodseq

        INNER JOIN CS_CALENDAR CA
			ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual' 


         INNER JOIN CS_PARTICIPANT PA
           ON PAGO.PAYEESEQ = PA.PAYEESEQ 
       	    AND PA.REMOVEDATE = v_eot
			AND PA.TENANTID = v_tenantid
			AND PA.EFFECTIVESTARTDATE <= PER.STARTDATE AND PA.EFFECTIVEENDDATE >= PER.ENDDATE
/* BOM CAL0134 DCR 19.04.2022 */
        INNER JOIN CS_POSITION POS
            ON POS.PAYEESEQ = PA.PAYEESEQ
            AND pa.userid = POS.NAME /* CAL0176 RMM 14.07.2022  eliminamos duplicados*/
            AND pos.TENANTID = v_tenantid
            AND pos.REMOVEDATE = v_eot
            AND POS.EFFECTIVESTARTDATE <= ADD_DAYS(PER.ENDDATE, - 1)
            AND POS.EFFECTIVEENDDATE >= ADD_DAYS(PER.ENDDATE, - 1)
/* EOM CAL0134 DCR 19.04.2022 */

	WHERE
		PAGO.PERIODSEQ = i_periodseq
        and PAGO.CONTRATO is not null
	;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_FACTCAT_TVTA_DETALLE '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end