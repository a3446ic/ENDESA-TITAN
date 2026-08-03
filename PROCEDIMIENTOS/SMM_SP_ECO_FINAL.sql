CREATE OR REPLACE PROCEDURE EXT.SMM_SP_ECO_FINAL( IN i_period VARCHAR(25), IN i_periodseq BIGINT, IN i_processingunitseq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 
    |----------------------------------------------------------------------
    | Procedure Purpose: TM2 Y TM6
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
	DECLARE v_txtFechaLiquidacion DATE;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
		CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, 'Error:'||::SQL_ERROR_CODE||::SQL_ERROR_MESSAGE);																									
																							
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: ' 
		|| ' || i_processingunitseq: ' || i_processingunitseq
		|| ' || i_period: ' || i_period
		|| ' || i_periodseq: ' || i_periodseq
		, v_log_count, v_idproceso,'info');
	
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_ECO_FINAL.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_ECO_FINAL WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_ECO_FINAL.', v_log_count, v_idproceso,'info');
	
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Inicio cargando tabla SMM_ECO_FINAL', v_log_count, v_idproceso,'info');
	INSERT INTO EXT.SMM_ECO_FINAL (PERIODO,CANAL,ACTIVIDAD,SUBACTIVIDAD,IDPROVEEDOR,NAME,PDS,IMPORTE)
    SELECT 
        CSP.NAME,
        CASE WHEN EDT.PROCESSINGUNITSEQ = 38280596832649218 THEN 'CCPP'
        END AS CANAL,
        ept.ACTIVIDAD,
        ept.subactividad,
        ept.IDPROVEEDOR,
        ept.DESCRIPCION,
        EPDS.PDS,
        TRIM(replace(to_char(sum(edt.VALUE) , '9999999999990D99'), ',', '.')) IMPORTE
            
    FROM EXT.SMM_PROVEEDORES_TEMP ept
        LEFT JOIN EXT.SMM_DEPOSIT_TEMP edt 
            ON EPT.IDPROVEEDOR = edt.EARNINGGROUPID

        LEFT JOIN EXT.SMM_PDS_TEMP epds
             ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
             AND EPDS.PAYEESEQ = edt.payeeseq
            
        INNER JOIN CS_PERIOD CSP
            ON CSP.PERIODSEQ=EDT.PERIODSEQ
            AND CSP.REMOVEDATE =v_eot         
    
    group by CSP.NAME,
        CASE WHEN EDT.PROCESSINGUNITSEQ = 38280596832649218 THEN 'CCPP'
        END,
        ept.actividad,
        ept.subactividad,
        ept.idproveedor,
        ept.descripcion,
        epds.pds
    ;    
 COMMIT;
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros de la tabla SMM_ECO_FINAL: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
	
	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;