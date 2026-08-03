CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_CREDITOS_SCAWEB( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--SMM_SCAWEB_LIQUIDACION
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_SCAWEB_LIQUIDACION.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_SCAWEB_LIQUIDACION WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_SCAWEB_LIQUIDACION.', v_log_count, v_idproceso,'info');
	
	-- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := CURRENT_DATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(i_periodseq);
    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando CREDITOS de datos en tabla EXT.SMM_SCAWEB_LIQUIDACION.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT 
        i_period PERIODO,        
        --credit.GENERICATTRIBUTE2,      -- Proveedor,
        --to_number(credtmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda
        to_number(REPLACE(credtmp.GENERICATTRIBUTE2, ' integer','')) PROVEEDOR,             
        --to_char(credit.COMPENSATIONDATE, 'YYYY'),
        to_char(v_fechaInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        --to_char(credit.COMPENSATIONDATE, 'MM'),
        to_char(v_fechaInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
        credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        1 as CANTIDAD,
        --credit.VALUE,                  --Importe Comision
        ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
        to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
        '' as FechaBaja,
        '' as Telefono,
        --credtmp.GENERICATTRIBUTE9 as Observaciones,      -- Solicitud de servicio
        -- En ajustes Manuales se pone el campo Observaciones credit.GA15
        case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end as Observaciones,
        null,
        --credtmp.GENERICATTRIBUTE11,		--Codigo Postal
        credtmp.GENERICATTRIBUTE6,       --Provincia
        credtmp.VALUE  as REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision  

    FROM EXT.SMM_CREDIT_TEMP credtmp
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
            ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

    WHERE 
        credtmp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
        and credtmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)
        AND credtmp.genericattribute15 not like 'Prescriptor'
        and NOT ( credtmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050
		and not TMP_PDS.TIPO_POSICION in ('ALICO','AAFF')  --MPR se quita del filtro CNS y SW
        and ( 
			credtmp.CREDITTYPEID like 'Prestacion%' 
            OR credtmp.CREDITTYPEID like 'Instalacion%'
            OR credtmp.CREDITTYPEID like 'Captacion%'
            OR credtmp.CREDITTYPEID like 'ATC - Ajuste Manual' 
            or credtmp.CREDITTYPEID like 'ATC - EFactura PULL'
            /*BOM 12.12.2023 APM*/
            OR credtmp.CREDITTYPEID like 'Venta EXT.SMMX%'
            OR credtmp.CREDITTYPEID like 'Instalaci%n EXT.SMMX%'
            OR credtmp.CREDITTYPEID like 'CCPP -%'
            /*EOM 12.12.2023 APM*/
            OR credtmp.CREDITTYPEID like 'Retrocomision EXT.SMMX%' --APM 29.12.2023
            OR credtmp.CREDITTYPEID like 'Captacion - Prescriptor' --APM 16.02.2024
            OR credtmp.CREDITTYPEID like 'Comisionado Act Comercial - Importe' --APM 02.03.2026
            /*BOM APM 19.03.2026*/
            OR credtmp.CREDITTYPEID LIKE 'Captacion - Mas Orange%'
            OR credtmp.CREDITTYPEID LIKE 'Bajas - Mas Orange%'
            OR credtmp.CREDITTYPEID LIKE 'Ajuste Manual - Mas Orange'
            /*EOM APM 19.03.2026*/
            /*BOM APM 23.06.2026 New Code*/
            OR credtmp.CREDITTYPEID LIKE 'Activacion - Importe Base'
            OR credtmp.CREDITTYPEID LIKE 'Activacion - Prescriptor' 
            OR credtmp.CREDITTYPEID LIKE 'Activacion - Importe Tarifas'
            OR credtmp.CREDITTYPEID LIKE 'Baja - Importe Base'     
            OR credtmp.CREDITTYPEID LIKE 'Baja - Importe Base - Prescriptor'
            /*EOM APM 23.06.2026*/
            or (
				credtmp.CREDITTYPEID like 'ATC - Operaciones' 	
				and credtmp.GENERICATTRIBUTE2 <> '179' 
                and credtmp.GENERICATTRIBUTE2 <> '277'
				and credtmp.GENERICATTRIBUTE2 <> '180' 
				and credtmp.GENERICATTRIBUTE2 <> '181' 
				and credtmp.GENERICATTRIBUTE2 <> '242'
                and credtmp.GENERICATTRIBUTE2 <> '050' --APM 05.04.2025
			)
		)
	;  -- De atencion solo los ajustes Manuales (para que no salgan todo el detalle de operaciones)
               
    
     COMMIT;
     
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga CREDITOS de la tabla SMM_SCAWEB_LIQUIDACION: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando INCENTIVOS de datos en tabla SMM_SCAWEB_LIQUIDACION.' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
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
        AND NOT ( INCENTMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')  -- No se incluyen Creditos de OCAPS y proveedor 050            
		AND NOT TMP_PDS.TIPO_POSICION IN ('ALICO','AAFF')   --MPR se quita del filtro CNS y SW 
        AND ( 
			INCENTMP.NAME LIKE 'I - Captacion - %'
            OR INCENTMP.NAME LIKE 'I - ATC - Remun Comercial PDS%'
			or incentmp.NAME LIKE 'I - Atencion - Rappel Cuantitativo Extra -%'
            or incentmp.NAME like 'I - ATC - Remun Comercial -%'
			or incentmp.NAME LIKE 'I - Captacion - TdF % - Bonus por TdF m-4'
			or incentmp.NAME LIKE 'I - Captacion - BTrimestral crecim - %'
            or INCENTMP.NAME LIKE 'I - %Arrastre%'
			-- MPR - nuevos rappeles para CNS y SW
			or INCENTMP.NAME LIKE 'I - Captacion Rappel CNS%'
			or INCENTMP.NAME LIKE 'I - Captacion Rappel SW%'
            or INCENTMP.NAME LIKE 'I - Captacion - Ricorrente -%' --APM 16.01.2025
            or INCENTMP.name like 'I - Captacion - Incentivo Transversal % - %'
            or INCENTMP.NAME LIKE 'I - Captacion - Rappel Volumen%'
            or INCENTMP.NAME LIKE 'I - ATC - Ajuste Remun Comercial PDS%' --APM 24.04.2026
            /*BOM APM 23.06.2026 New Code*/
            or INCENTMP.NAME LIKE 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
            or INCENTMP.NAME LIKE 'C - Activacion - Rappel Cuantitativo -%'
            /*EOM APM 23.06.2026*/			
            or INCENTMP.name LIKE 'C - Captacion - Rappel Cuantitativo Incremental -%' --APM 09.07.2026
            --OR INCENTMP.NAME = 'I - Captacion Arrastre CNS'
            --OR INCENTMP.NAME LIKE '%Captacion Decomisado IB CNS'
            --OR INCENTMP.NAME = 'I - Captacion AAFF - Rappel Cuantitativo - Obj 1'
            --OR INCENTMP.NAME LIKE 'I - Captacion AAFF - TdF % - Importe %'
            --or incentmp.name like 'I - 1% RC OCAP %'
			)
		-- MPR - se excluyen los incentivos de los Dashboards
        and incentmp.Name not like 'I - Captacion - Rappel Cuantitativo Incremental - Objetivo % (Dashboards)'
        and incentmp.Name not like 'I - Captacion - Rappel Cuantitativo Incremental - Objetivo % (DB)'
        AND incentmp.Name not like 'C - Captacion - Ricorrente%' --APM 16.01.2025
        AND INCENTMP.name not like 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
        AND INCENTMP.name not like 'C - Activacion - Rappel Cuantitativo -%'
		)
        or(
            INCENTMP.VALUE <> 0 -- Se filtran los incentivos que sean distintos de 0      
            AND NOT ( INCENTMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')  -- No se incluyen Creditos de OCAPS y proveedor 050            
            AND (incentmp.name like 'I - 1% RC OCAP %'
            or incentmp.name like 'I - 277% RC OCAP %'
            or incentmp.name like 'I - 050 - RC PDS%') --APM 05.04.2025
			-- MPR - se excluye el incentivo de ajuste manual de RC OCAP
			and incentmp.Name not like 'I - 179 - RC OCAP EOSC Ajustes Manuales'
            and incentmp.Name not like 'I - 179 - RC OCAP EOSC'
            and incentmp.Name not like 'I - 277 - RC OCAP EOSC MR - Ajustes Manuales'
            and incentmp.Name not like 'I - 277 - RC OCAP EOSC MR'
        );

    
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga INCENTIVOS de la tabla SMM_SCAWEB_LIQUIDACION: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
     INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT 
        i_period PERIODO,        
        TO_NUMBER(INCENTMP.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda             
        TO_CHAR(v_fechaInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        TO_CHAR(v_fechaInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        TMP_PDS.PDS ,      -- Prestador - PDS
        INCENTMP.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        1 AS CANTIDAD,
        ABS(commi.VALUE),
        TO_CHAR(vFechaAlta, 'YYYYMMDD') AS FechaAlta,
        '' AS FechaBaja,
        '' AS Telefono,
         REPLACE(INCENTMP.GENERICATTRIBUTE4, 'integer', '') AS Observaciones, 
        ''  AS Codigo_Postal,       --Codigo Postal
        ''  AS Provincia,     --Provincia
        commi.VALUE  AS REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision
            
    FROM CS_COMMISSION COMMI          
        inner JOIN   cs_incentive INCENTMP 
			ON INCENTMP.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INCENTMP.payeeseq = COMMI.payeeseq
            AND INCENTMP.positionseq = COMMI.positionseq
            and incentmp.periodseq=commi.periodseq
        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON INCENTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and incentmp.payeeseq=tmp_pds.payeeseq
            left join cs_credit cre
            on commi.creditseq=cre.creditseq
            and commi.periodseq=cre.periodseq
             
    WHERE  commi.VALUE <> 0 -- Se filtran los incentivos que sean distintos de 0    
    and (INCENTMP.name like 'C - Activacion - Importe Base Prescriptor -%'
    or INCENTMP.name like'C - Activacion - Retrocesion - Importe Base Prescriptor -%'
    or INCENTMP.name like 'C - Activacion - Rappel Cuantitativo Prescriptor -%'
    or INCENTMP.name like 'C - Captacion - Rappel Cuantitativo Incremental%'
    or INCENTMP.name like 'C - Activacion - Rappel Cuantitativo -%')
    and incentmp.periodseq=i_periodseq
        ;

   
    COMMIT;
    
    
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando INCENTIVOS RENOVACION de datos en tabla SMM_SCAWEB_LIQUIDACION.' , v_log_count, v_idproceso,'info');

    INSERT INTO EXT.SMM_SCAWEB_LIQUIDACION ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
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
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga INCENTIVOS de la tabla SMM_SCAWEB_LIQUIDACION: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_SCAWEB_LIQUIDACION '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;