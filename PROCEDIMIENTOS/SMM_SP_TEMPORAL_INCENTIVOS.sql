CREATE OR REPLACE PROCEDURE EXT.SMM_SP_TEMPORAL_INCENTIVOS( IN i_processingUnitSeq BIGINT, IN i_period VARCHAR(25), IN i_periodseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: Volcar datos de la tabla de Incentivos a una Temporal general para usar como base en todas las demas extracciones 
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
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: i_processingUnitSeq' || i_processingUnitSeq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tabla SMM_INCEN_TEMP.', v_log_count, v_idproceso,'info');
	EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.SMM_INCEN_TEMP';
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Cargando tabla SMM_INCEN_TEMP. Periodo: ' || i_period, v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_INCEN_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
										GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE7, GENERICATTRIBUTE16, 
										GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
										GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2 )
    SELECT 
        incent.TENANTID,
        incent.PERIODSEQ,
        i_period PERIODO,
        incent.PIPELINERUNSEQ,
        incent.PIPELINERUNDATE,
        incent.INCENTIVESEQ,
        incent.PAYEESEQ,
        incent.POSITIONSEQ,
        incent.NAME,
        incent.VALUE,                  --Importe Incentivo
        incent.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        incent.GENERICATTRIBUTE2,      -- Proveedor
        incent.GENERICATTRIBUTE3,      -- Descripcion
        incent.GENERICATTRIBUTE4,      -- Tramo
        incent.GENERICATTRIBUTE7,      -- WBE
        incent.GENERICATTRIBUTE16,     -- Nombre Cuota
        incent.GENERICNUMBER1,         -- Objetivo
        incent.GENERICNUMBER2,         -- Realizado
        incent.GENERICNUMBER3,         -- % Consecucion
        incent.GENERICNUMBER4,         -- Tarifa
        incent.GENERICNUMBER5,         -- Importe unitario
        incent.GENERICNUMBER6,         -- Target Incentive
        incent.GENERICBOOLEAN1,         
        incent.GENERICDATE1,           --Fecha Inicio
        incent.GENERICDATE2           --Fecha Final            
        
    FROM CS_INCENTIVE incent
        INNER JOIN CS_PLRUN p ON incent.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Añadimos nuevo filtro para optimizar
            AND p.tenantid = v_tenantid
    WHERE
        incent.TENANTID = v_tenantid 
        AND incent.PROCESSINGUNITSEQ = i_processingUnitSeq 
        AND incent.PERIODSEQ =  i_periodseq
        AND (incent.GENERICATTRIBUTE1 is not null
            or incent.GENERICATTRIBUTE2= '179'
            or incent.GENERICATTRIBUTE2= '277'
            or incent.GENERICATTRIBUTE2= '180'
            or incent.GENERICATTRIBUTE2= '181'
			--MPR nuevo proveedor de OCAP
			or incent.GENERICATTRIBUTE2= '242'
            or incent.GENERICATTRIBUTE2= '050'--APM 05.04.2025
        );

    -- filas := sql%rowcount;
    COMMIT;
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros Créditos de la tabla SMM_INCEN_TEMP: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    
	
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;