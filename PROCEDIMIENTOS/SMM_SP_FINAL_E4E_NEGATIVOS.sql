CREATE OR REPLACE PROCEDURE EXT.SMM_SP_FINAL_E4E_NEGATIVOS( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	DECLARE v_fechaInicioPeriodoSig DATE;
	DECLARE v_fechaInicio DATE;
	DECLARE v_txtFechaInicioPeriodoSig VARCHAR(25);
	DECLARE v_txtYear VARCHAR(4);
	DECLARE v_codMes VARCHAR(2);
	DECLARE v_txtFechaActual VARCHAR(25);
	DECLARE contadorE4E INT;
	DECLARE contadorECS INT;
	DECLARE contadorPosicion  INT;
	DECLARE v_codFichero VARCHAR(50);
	DECLARE v_maxIDPEDIDO INT;
	

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
	
	--SMM_E4E_NEGATIVOS
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_E4E_NEGATIVOS.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_E4E_NEGATIVOS WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_E4E_NEGATIVOS.', v_log_count, v_idproceso,'info');
	
	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(i_periodseq);
    -- v_fechaInicio := EXT.SMM_F_FECHA_INICIO(i_periodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodoSig := to_char(v_fechaInicioPeriodoSig, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodoSig, 'YY');
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := EXT.SMM_F_CODIGO_MES(v_fechaInicioPeriodoSig);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodoSig ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual , v_log_count, v_idproceso,'info');
    
    
	SELECT IFNULL(MAX(IDPEDIDO), 0)
	INTO v_maxIDPEDIDO
	FROM EXT.SMM_E4E_NEGATIVOS
	WHERE ESTADO = 'LIQUIDADO';
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Numero maximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) , v_log_count, v_idproceso,'info');

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_E4E_NEGATIVOS.' || v_codFichero , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_E4E_NEGATIVOS ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, PDS, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
                                              SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
                                              CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
                                              CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION  )   
    SELECT 
        e4edt.PERIODSEQ,
        e4edt.PERIODO,
        e4edt.DEPOSITSEQ,
        e4edt.POSITIONSEQ,
        e4edt.PAYEESEQ, 
        e4edt.PDS,
        v_maxIDPEDIDO + ROW_NUMBER() OVER (ORDER BY PERIODSEQ) AS IDPEDIDO,
        -- v_maxIDPEDIDO + rownum as IDPEDIDO,
        e4edt.ORG_VENTAS,
        CASE WHEN COMUNIDAD_AUTONOMA = 'CANARIAS' THEN 'CA' ELSE 'CO' END AS CANAL_DISTRIBUCION,
        '39' as SECTOR,
        'ZOAL' as CLASE_PEDIDO,
        '' AS FACTURA_REF,
        e4edt.CODIGODEUDOR Solicitante_ShipTo,
        e4edt.CODIGODEUDOR Solicitante_SoldTo,
        v_txtYear || e4edt.PDS || e4edt.IDPROVEEDOR || v_codMes as NUM_PEDIDO,
        v_txtFechaActual FechaPedido,
        v_txtFechaActual FechaFactura, 
        e4edt.CONDICIONES_PAGO,
        '' ContratoSEPA,
        '' MotivoPedido,
        'EUR' MONEDA,
        '10' POSICION,
        CASE e4edt.SOCIEDAD
            WHEN 'ES21' THEN 'ZES000013'
            WHEN 'ES29' THEN 'ZES000016'
            WHEN 'PT1Q' THEN 'ZPT000003'
            ELSE  ''
        END MATERIAL,     
        CASE e4edt.SOCIEDAD
            WHEN 'ES21' THEN 'RETROACCIoN COM. ENDESA ENERGiA'
            WHEN 'ES29' THEN 'RETROACCIoN COM. EOSC'
            WHEN 'PT1Q' THEN 'RETROACCIoN COM. E. E. PORTUGAL'
            ELSE  ''
        END TEXTO_MATERIAL,
        1 CANTIDAD,
        ABS(VALUE) as PRECIO,
        CASE 
            WHEN e4edt.TIPO_IMPOSITIVO ='IVA' THEN '1'
            WHEN e4edt.TIPO_IMPOSITIVO ='IVA Portugal' THEN 'H'
            ELSE   ''
        END CLASIF_FISCAL_IVA,
        CASE e4edt.TIPO_IMPOSITIVO
            WHEN 'IGIC' THEN '1'
            ELSE  ''
        END CLASIF_FISCAL_IGIC,    
        WBE_FINAL_IMPUTACION

    FROM EXT.SMM_E4E_NEGATIVOS_TEMP_2 e4edt 
    
    WHERE 
        e4edt.VALUE < 0  and 
        e4edt.PERIODSEQ = i_periodseq;
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_E4E_NEGATIVOS '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;