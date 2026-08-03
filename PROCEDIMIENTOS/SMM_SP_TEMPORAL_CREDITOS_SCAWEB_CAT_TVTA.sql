CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_CREDITOS_SCAWEB_CAT_TVTA( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	DECLARE vFechaAlta DATE;
	
	

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
	
	--SMM_SCAWEB_LIQUIDACION_CAT_TVTA
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_SCAWEB_LIQUIDACION_CAT_TVTA.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_SCAWEB_LIQUIDACION_CAT_TVTA.', v_log_count, v_idproceso,'info');
	
	-- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := CURRENT_DATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(i_periodseq);
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando CREDITOS de datos en tabla EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT DISTINCT
        i_period PERIODO,        
        to_number(REPLACE(credtmp.GENERICATTRIBUTE14, ' integer','')) PROVEEDOR,             
        to_char(v_fechaInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        to_char(v_fechaInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
        credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        1 as CANTIDAD,
        ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
        to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
        '' as FechaBaja,
        '' as Telefono,
        case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end as Observaciones,
        null,
        credtmp.GENERICATTRIBUTE6,       --Provincia
        credtmp.VALUE  as REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision  

    FROM EXT.SMM_CREDIT_TEMP credtmp
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
            ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

    WHERE 
        (credtmp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
        and credtmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)
        --and NOT ( credtmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050
		--and not TMP_PDS.TIPO_POSICION in ('ALICO','AAFF')  --MPR se quita del filtro CNS y SW
        and ( 
			credtmp.CREDITTYPEID = 'CAT Captacion' 
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion'
            OR credtmp.CREDITTYPEID like 'CAT TVTA -%'
            OR credtmp.CREDITTYPEID like '%EXT.SMMX - CAT%' 
            or credtmp.CREDITTYPEID like '%EXT.SMM X - CAT%'
            OR credtmp.CREDITTYPEID = 'CAT Captacion Campañas'
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion Campañas'
            OR credtmp.CREDITTYPEID = 'TLV INBOUND'
            /*BOM APM 19.03.2026*/
            OR credtmp.CREDITTYPEID LIKE 'Captacion CAT TVTA - Mas Orange%'
            OR credtmp.CREDITTYPEID LIKE 'Bajas - Mas Orange - CAT TVTA%'
            OR credtmp.CREDITTYPEID LIKE 'Ajuste Manual - Mas Orange - CAT TVTA'
            /*EOM APM 19.03.2026*/
            /*BOM APM 24.04.2026*/
            OR credtmp.CREDITTYPEID = 'CAT Captacion - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Captacion Campañas - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion Campañas - Activacion'
            OR credtmp.CREDITTYPEID = 'TLV INBOUND - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion Capta Campaña'
            OR credtmp.CREDITTYPEID = 'CAT Retro Capta Rappel'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion Recuperacion'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion Recuperacion Campaña'
            OR credtmp.CREDITTYPEID = 'CAT Retro Recu Rappel'))
            /*EOM APM 24.04.2026*/
            /*BOM APM 14.05.2026*/
            OR (credtmp.CREDITTYPEID like 'CAT Recuperacion Ajuste Manual%'
            OR credtmp.CREDITTYPEID like 'CAT Captacion Ajuste Manual%')

            /*BOM APM 14.05.2026*/

	;  -- De atencion solo los ajustes Manuales (para que no salgan todo el detalle de operaciones)

    
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga CREDITOS de la tabla EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando INCENTIVOS de datos en tabla EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA.' ,  v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT 
        i_period PERIODO,        
        TO_NUMBER(INCENTMP.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda             
        TO_CHAR(v_fechaInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        TO_CHAR(v_fechaInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        TMP_PDS.PDS ,      -- Prestador - PDS
        INCENTMP.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        1 AS CANTIDAD,
        ABS(INCENTMP.VALUE),
        TO_CHAR(vFechaAlta, 'YYYYMMDD') AS FechaAlta,
        '' AS FechaBaja,
        '' AS Telefono,
         REPLACE(INCENTMP.GENERICATTRIBUTE4, 'integer', '') AS Observaciones, 
        ''  AS Codigo_Postal,       --Codigo Postal
        ''  AS Provincia,     --Provincia
        INCENTMP.VALUE  AS REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision

    FROM EXT.SMM_INCEN_TEMP INCENTMP    
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON INCENTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and incentmp.payeeseq=tmp_pds.payeeseq

    WHERE (    
        INCENTMP.GENERICBOOLEAN1 = 1  -- Indica los Incentivos que se incluyen en pagos
        AND INCENTMP.GENERICATTRIBUTE1 IS NOT NULL  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)  
        AND INCENTMP.VALUE <> 0 -- Se filtran los incentivos que sean distintos de 0      
        --AND NOT ( INCENTMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')  -- No se incluyen Creditos de OCAPS y proveedor 050            
		--AND NOT TMP_PDS.TIPO_POSICION IN ('ALICO','AAFF')   --MPR se quita del filtro CNS y SW 
        AND ( 
			INCENTMP.NAME LIKE 'I - %CAT TVTA - Incentivo%'
            OR INCENTMP.NAME LIKE 'I - %CAT TVTA - TdM%Malus'
			or incentmp.NAME LIKE 'I - %CAT TVTA - %BBDD'
            --or incentmp.NAME LIKE 'C - CAT TVTA % Rappel Incremental'
            --or incentmp.NAME LIKE 'C - CAT TVTA %TM%'
			));


    
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga INCENTIVOS de la tabla EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando INCENTIVOS RENOVACION de datos en tabla EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA.' ,  v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT 
        i_period PERIODO,        
        TO_NUMBER(ASESOR.NUMPROVEEDOR),   -- Proveedor en formato numerico, sin ceros a la izquierda             
        TO_CHAR(v_fechaInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        TO_CHAR(v_fechaInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        ASESOR.CODIGO_PDS_OCAP ,      -- Prestador - PDS
        '',      -- Concepto Liquidacion
        1 AS CANTIDAD,
        ABS(ASESOR.IMPORTE),
        TO_CHAR(vFechaAlta, 'YYYYMMDD') AS FechaAlta,
        '' AS FechaBaja,
        '' AS Telefono,
        '' AS Observaciones, 
        ''  AS Codigo_Postal,       --Codigo Postal
        ''  AS Provincia,     --Provincia
        ASESOR.IMPORTE  AS REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision

    FROM EXT.SMM_LIQ_FINAL_ASESOR ASESOR    
	WHERE PERIODO = i_period

    ;
    
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga INCENTIVOS de la tabla SMM_SCAWEB_LIQUIDACION_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_SCAWEB_LIQUIDACION_CAT_TVTA '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end