CREATE PROCEDURE EXT.SMM_SP_INF_CAT_TVTA_AM( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_interfaz NVARCHAR(50))
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
	
	--SMM_CAT_TVTA_AM
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_CAT_TVTA_AM.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_CAT_TVTA_AM WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_CAT_TVTA_AM.', v_log_count, v_idproceso,'info');
	
	v_txtFechaLiquidacion := '';

	IF (i_Interfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Referencia fechas. Periodo:'|| i_period ||' v_txtFechaLiquidacion: '||v_txtFechaLiquidacion , v_log_count, v_idproceso,'info');
    
    
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_CAT_TVTA_AM.' ,v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_CAT_TVTA_AM ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO,  ORDERID,  LINENUMBER,  SUBLINENUMBER,  EVENTTYPEID,  CREDITTYPEID,  IMPORTE, 
											UNIDAD,  CODIGO_COMERCIAL,  FECHA_LIQUIDACION,  ESTADO,  OBSERVACIONES ) 
	SELECT
		PERIODSEQ,
		POSITIONSEQ,
		PAYEESEQ,
		PERIODO,
		ORDERID,
		LINENUMBER,
		SUBLINENUMBER,
		EVENTTYPEID,
		CREDITTYPEID,
		IMPORTE,
		UNIDAD,
		CODIGO_COMERCIAL,
		FECHA_LIQUIDACION,
		ESTADO,
		OBSERVACIONES

	FROM EXT.SMM_CAT_TVTA_AM_TEMP
	WHERE    
		PERIODO =  i_period
	;

    /*BOM APM 16.04.2025 - Se comenta*/
    /*INSERT INTO ENELEXT.ENEL_LEADS_CAT_TVTA (PERIODO , ORDERID , LINENUMBER , SUBLINENUMBER , EVENTTYPEID , ESTADOCONTRATO ,
                                                IMPORTE , UNIDAD ,VALOR_1 , UNIDAD_1 , PRODUCTO_SCAWEB , CODIGO_PDS_OCAP , CICLO_FACTURACION ,
                                                 ESTADO , IDPROVEEDOR ,NUMPROVEEDOR , nom_credito ,WO_VISITA,VENTA_RELACIONADA )

    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        ETT.GENERICATTRIBUTE3,
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        TMP_PDS.PDS,
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
        when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
        else 'Pte Liquidar'
        end,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ect.name,
        ETT.GENERICATTRIBUTE4 AS WO_VISITA,
        ETT.GENERICATTRIBUTE24 AS VENTA_RELACIONADA
    FROM ENEL_TXN_TEMP ETT
		LEFT JOIN ENEL_CREDIT_TEMP ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2

		LEFT JOIN ENEL_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq


	;*/
    /*EOM APM 16.04.2025*/
               
    
     COMMIT;
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_CAT_TVTA_AM '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end