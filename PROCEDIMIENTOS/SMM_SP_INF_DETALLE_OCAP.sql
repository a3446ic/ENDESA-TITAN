CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_DETALLE_OCAP( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_Interfaz VARCHAR(50))
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
	DECLARE v_txtFechaLiquidacion NVARCHAR(10);
	
	
	

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
		|| ' || i_Interfaz: ' || i_Interfaz
		, v_log_count, v_idproceso,'info');
	
	--SMM_DETALLE_OCAP
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_DETALLE_OCAP.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_DETALLE_OCAP WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_DETALLE_OCAP.', v_log_count, v_idproceso,'info');
	
	v_txtFechaLiquidacion := '';
	IF (i_interfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(CURRENT_DATE, 'DD/MM/YYYY');
    END IF;
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_DETALLE_OCAP.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_DETALLE_OCAP (PERIODSEQ, PERIODO, T_OPERACION, PDS, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION,
											ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, NUM_OPERACIONES, VALUE, UB, K, PROD_SCAWEB, IDPROVEEDOR,
											DESCRIPCION, OPERACIONID, CREDITTYPEID, ESTADO, NAME, DATASOURCE, COMPENSATIONDATE,
											PAYEESEQ, POSITIONSEQ, CICLO_FACTURACION, ESTADO_CIERRE, USUARIO_CRM)
    SELECT 
		i_periodseq,
		credtmp.PERIODO,
		CASE 
			WHEN credtmp.GENERICATTRIBUTE2 = '050' THEN ETT.TEX0_GENERICATTRIBUTE15
			WHEN credtmp.GENERICATTRIBUTE2 = '179' THEN 'ENERGIA XXI'
			WHEN credtmp.GENERICATTRIBUTE2 in ('180', '181', '242') THEN 'ENDESA ENERGIA, S.A.U.'
			ELSE 'Otros'
		END AS T_OPERACION,
		credtmp.GENERICATTRIBUTE4 AS PDS,
		ot.TIPO_ENTRADA,
		ot.TIPO_OPERACION,   --Tipo Operacion
		ot.SUBTIPO_OPERACION, -- Subtipo Operacion
		ETT.ORDERID,
		ETT.LINENUMBER,
		ETT.SUBLINENUMBER,
		ETT.EVENTYPEID,
		credtmp.GenericNumber1 AS NUM_OPERACIONES, -- Numero Operaciones
		credtmp.VALUE,
		credtmp.GenericNumber3 AS UB, -- Unidada Baremacion
		credtmp.GenericNumber2 AS K, -- K (Famosa)
		credtmp.GENERICATTRIBUTE1,  -- Producto SCAWEB
		TMP_PROV.IDPROVEEDOR,
		TMP_PROV.DESCRIPCION,
		credtmp.GENERICATTRIBUTE3,
		credtmp.CREDITTYPEID,
		ETT.GENERICATTRIBUTE3,
		credtmp.NAME,
		ETT.DATASOURCE,
		ETT.COMPENSATIONDATE,
		credtmp.PAYEESEQ,
		credtmp.POSITIONSEQ,
		v_txtFechaLiquidacion,
		case 
            when i_Interfaz ='ACTUALIZA_INFORMES_POST' then 'Cerrado'
            else 'Pte Cierre'
        end as Estado,
        ETT.GENERICATTRIBUTE20

		FROM EXT.SMM_TXN_TEMP ETT
			LEFT JOIN EXT.SMM_CREDIT_TEMP credtmp
				ON ETT.SALESTRANSACTIONSEQ = credtmp.SALESTRANSACTIONSEQ
		
			LEFT JOIN EXT.SMM_OPERACIONES_TEMP ot 
				ON CREDTMP.GENERICATTRIBUTE3 = ot.OPERACIONID
				
			LEFT JOIN EXT.SMM_PDS_TEMP TMP_PDS
				ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
				
			LEFT JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
				ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2
	
		/* --MPR Comentamos el cruce antiguo.
		SMM_CREDIT_TEMP credtmp
			LEFT JOIN SMM_OPERACIONES_TEMP ot 
				ON CREDTMP.GENERICATTRIBUTE3 = ot.OPERACIONID
				
			INNER JOIN SMM_PDS_TEMP TMP_PDS
				ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
				
			INNER JOIN SMM_PROVEEDORES_TEMP TMP_PROV 
				ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2
				
			INNER JOIN SMM_TXN_TEMP ETT
				ON credtmp.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
		*/
		
		WHERE 
		-- modificar por eventtype txn = Operaciones
		ETT.EVENTYPEID like 'Operaciones'
		--MPR Cometamos el filtro de búsqueda para mdificarlo por el eventtype de la TXN
		--credtmp.CREDITTYPEID in ( 'ATC - Operaciones' , 'ATC - Ajuste Operaciones', 'ATC - Ajuste Recepcion', 'ATC - Recepcion')
        --and credtmp.value<>'0'
        ;
    
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_DETALLE_OCAP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
    COMMIT;
   
    
   
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;