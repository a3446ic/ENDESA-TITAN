CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_FACTURA_OCAP_DETALLE( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--SMM_FACTOPE_DETALLE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_FACTOPE_DETALLE.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_FACTOPE_DETALLE';
    --borramos las nuevas tablas creadas para EE y EOCS
    EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_FACTOPE_DETALLE_EE';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_FACTOPE_DETALLE_EOSC';
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_FACTOPE_DETALLE.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros de datos en tabla EXT.SMM_FACTOPE_DETALLE.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_FACTOPE_DETALLE (PERIODO, PERIODSEQ, MES_PERIODO, CREDITSEQ, CREDITTYPEID,PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA,
                                                POBLACION, TIPO_IMPOSITIVO, IDPROVEEDOR, DESCRIPCION, NAME, IMPORTE, CONCEPTO_LIQUIDACION, NUM_OPERACIONES, 
                                                UNIDAD_BAREMACION, K, FECHA_OPERACION, MES_OPERACION, TIPO_OPERACION, SUBTIPO_OPERACION, TIPO_ENTRADA, 
                                                AGRUPA_EN_FACTURA, DELEGACION, CIF, COD_POSTAL, CALLE )
    SELECT
        credtmp.PERIODO, 
        credtmp.PERIODSEQ,
        to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_PERIODO,
        credtmp.CREDITSEQ, 
        credtmp.CREDITTYPEID ,
        TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
        TMP_PDS.PDS, 
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.PROVINCIA,
        TMP_PDS.POBLACION,
        TMP_PDS.TIPO_IMPOSITIVO, 
        TMP_PROV.IDPROVEEDOR, 
        TMP_PROV.DESCRIPCION,
        credtmp.name, 
        credtmp.VALUE,
        credtmp.GenericAttribute1,    --Concepto liquidacion
        credtmp.GenericNumber1,       -- Numero operaciones
        credtmp.GenericNumber3,     --  Unidad Baremacion
        credtmp.GenericNumber2,       --  K (Famosa)
        --TMP_PDS.IMPORTE_UB,
        CREDTMP.COMPENSATIONDATE,       -- Fecha Operacion
        to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_OPERACION,
        ot.TIPO_OPERACION,   --TIpo Operacion 
        ot.SUBTIPO_OPERACION, -- Subtipo Operacion
        ot.TIPO_ENTRADA, -- Tipo Registro
        ot.AGRUPA_EN_FACTURA,
        TMP_PDS.DELEGACION,
        TMP_PDS.CIF,
        TMP_PDS.COD_POSTAL,
        TMP_PDS.CALLE
            
    FROM  EXT.SMM_CREDIT_TEMP credtmp
        LEFT JOIN EXT.SMM_OPERACIONES_TEMP ot 
            ON CREDTMP.GENERICATTRIBUTE3 = ot.OPERACIONID

        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2
           
    WHERE credtmp.CREDITTYPEID in ( 'ATC - Operaciones' , 'ATC - Ajuste Operaciones', 'ATC - Ajuste Recepcion', 'ATC - Recepcion');           
        
    
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_FACTOPE_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    
    INSERT INTO EXT.SMM_FACTOPE_DETALLE_EE (PERIODO, PERIODSEQ, MES_PERIODO, CREDITSEQ, CREDITTYPEID,PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA,
                                                POBLACION, TIPO_IMPOSITIVO, IDPROVEEDOR, DESCRIPCION, NAME, IMPORTE, CONCEPTO_LIQUIDACION, NUM_OPERACIONES, 
                                                UNIDAD_BAREMACION, K, FECHA_OPERACION, MES_OPERACION, TIPO_OPERACION, SUBTIPO_OPERACION, TIPO_ENTRADA, 
                                                AGRUPA_EN_FACTURA, DELEGACION, CIF, COD_POSTAL, CALLE, POSICION_USUARIO )                                            
    SELECT
        credtmp.PERIODO, 
        credtmp.PERIODSEQ,
        to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_PERIODO,
        credtmp.CREDITSEQ, 
        credtmp.CREDITTYPEID ,
        TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
        TMP_PDS.PDS, 
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.PROVINCIA,
        TMP_PDS.POBLACION,
        TMP_PDS.TIPO_IMPOSITIVO,            
        TMP_PROV.IDPROVEEDOR, 
        TMP_PROV.DESCRIPCION,
        credtmp.name, 
        credtmp.VALUE,
        credtmp.GenericAttribute1,    --Concepto liquidacion
        credtmp.GenericNumber1,       -- Numero operaciones
        credtmp.GenericNumber3,     --  Unidad Baremacion
        credtmp.GenericNumber2,       --  K (Famosa)
        --TMP_PDS.IMPORTE_UB,
		--MPR Modificamos el GD1 por COMPENSATIONDATE
        CREDTMP.COMPENSATIONDATE,       -- Fecha Operacion
        to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_OPERACION,
        ot.TIPO_OPERACION,   --TIpo Operacion 
        ot.SUBTIPO_OPERACION, -- Subtipo Operacion
        ot.TIPO_ENTRADA, -- Tipo Registro
        ot.AGRUPA_EN_FACTURA,
        TMP_PDS.DELEGACION,
        TMP_PDS.CIF,
        TMP_PDS.COD_POSTAL,
        TMP_PDS.CALLE,
        TMP_PDS.POSICION_USUARIO --APM 25.02.2025
            
    FROM  EXT.SMM_CREDIT_TEMP credtmp
        LEFT JOIN EXT.SMM_OPERACIONES_TEMP ot 
            ON CREDTMP.GENERICATTRIBUTE3 = ot.OPERACIONID

        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2
           
    WHERE credtmp.CREDITTYPEID in ( 'ATC - Operaciones' , 'ATC - Ajuste Operaciones', 'ATC - Ajuste Recepcion', 'ATC - Recepcion')
        /*BOM APM 27.03.2026 Old Code*/
        --and (credtmp.genericattribute2 = 180 or credtmp.genericattribute2 = 181 or credtmp.genericattribute2 = 242
        --New Code
        and (credtmp.genericattribute2 = 180 or credtmp.genericattribute2 = 181
        /*EOM APM 27.03.2026*/
        or credtmp.genericattribute2 = 050);   --APM 27.02.2025                                             

    
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla EXT.SMM_FACTOPE_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    
    
    INSERT INTO EXT.SMM_FACTOPE_DETALLE_EOSC (PERIODO, PERIODSEQ, MES_PERIODO, CREDITSEQ, CREDITTYPEID,PAYEESEQ, POSITIONSEQ, OCAP_PDS, NOMBRE_FISCAL, PROVINCIA,
                                                POBLACION, TIPO_IMPOSITIVO, IDPROVEEDOR, DESCRIPCION, NAME, IMPORTE, CONCEPTO_LIQUIDACION, NUM_OPERACIONES, 
                                                UNIDAD_BAREMACION, K, FECHA_OPERACION, MES_OPERACION, TIPO_OPERACION, SUBTIPO_OPERACION, TIPO_ENTRADA, 
                                                AGRUPA_EN_FACTURA, DELEGACION, CIF, COD_POSTAL, CALLE, POSICION_USUARIO,GENERICNUMBER5, ROL, PROVEEDOR,TIPO_PRESTADOR )                                                
    SELECT
        credtmp.PERIODO, 
        credtmp.PERIODSEQ,
        to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_PERIODO,
        credtmp.CREDITSEQ, 
        credtmp.CREDITTYPEID ,
        TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
        TMP_PDS.PDS, 
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.PROVINCIA,
        TMP_PDS.POBLACION,
        TMP_PDS.TIPO_IMPOSITIVO, 
        TMP_PROV.IDPROVEEDOR, 
        TMP_PROV.DESCRIPCION,
        credtmp.name, 
        credtmp.VALUE,
        credtmp.GenericAttribute1,    --Concepto liquidacion
        credtmp.GenericNumber1,       -- Numero operaciones
        credtmp.GenericNumber3,     --  Unidad Baremacion
        credtmp.GenericNumber2,       --  K (Famosa)
        --TMP_PDS.IMPORTE_UB,
        CREDTMP.COMPENSATIONDATE,       -- Fecha Operacion
        to_char(CREDTMP.COMPENSATIONDATE, 'MM/YYYY') MES_OPERACION,
        ot.TIPO_OPERACION,   --TIpo Operacion 
        ot.SUBTIPO_OPERACION, -- Subtipo Operacion
        ot.TIPO_ENTRADA, -- Tipo Registro
        ot.AGRUPA_EN_FACTURA,
        TMP_PDS.DELEGACION,
        TMP_PDS.CIF,
        TMP_PDS.COD_POSTAL,
        TMP_PDS.CALLE,
        TMP_PDS.POSICION_USUARIO, --APM 25.02.2025
		CREDTMP.GENERICNUMBER5,
        CREDTMP.GENERICATTRIBUTE5 AS ROL, --APM 08.08.2025
        credtmp.genericattribute2 AS PROVEEDOR, --APM 28.04.2026
        TMP_PDS.TIPO_PRESTADOR --DMS 26.05.2026
            
    FROM  EXT.SMM_CREDIT_TEMP credtmp
        LEFT JOIN EXT.SMM_OPERACIONES_TEMP ot 
            ON CREDTMP.GENERICATTRIBUTE3 = ot.OPERACIONID

        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

        INNER JOIN EXT.SMM_PROVEEDORES_TEMP TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2
           
    WHERE credtmp.CREDITTYPEID in ( 'ATC - Operaciones' , 'ATC - Ajuste Operaciones', 'ATC - Ajuste Recepcion', 'ATC - Recepcion','ATC - Ajuste Manual')
        and (credtmp.genericattribute2 = 179 or credtmp.genericattribute2 = 050 or credtmp.genericattribute2 = 277) ;   --APM 27.02.2025

   
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla FACTOPE_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
      
    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;