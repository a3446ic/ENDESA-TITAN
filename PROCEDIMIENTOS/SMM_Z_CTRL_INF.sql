CREATE OR REPLACE PROCEDURE EXT.SMM_SP_Z_CTRL_INF( IN i_valor INTEGER, IN i_num_ejecucion INTEGER, IN i_proceso NVARCHAR(250), IN i_finicio TIMESTAMP, IN i_ffin TIMESTAMP, IN i_mensaje NVARCHAR(250))
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
	DECLARE v_contador_ctrl_inf INT;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																											
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: i_valor' || i_valor
		|| ' || i_num_ejecucion: ' || i_num_ejecucion
		|| ' || i_proceso: ' || i_proceso
		|| ' || i_finicio: ' || i_finicio
		|| ' || i_ffin: ' || i_ffin
		|| ' || i_mensaje: ' || i_mensaje
		, v_log_count, v_idproceso,'info');
		
	--SELECT MAX(ID) + 1 INTO v_contador_ctrl_inf DEFAULT 0 FROM 
/*
    if valor is null then 
        select max(id) +1, num_ejecucion +1 into v_contador_ctrl_inf, v_num_ejecucion from axpoext.axpo_ctrl_informes
            group by id, num_ejecucion;
    END IF; 
*/       

    INSERT INTO EXT.SMM_CTRL_INFORMES (id, num_ejecucion, paquete, proceso, fecha_inicio, fecha_fin, mensaje, duracion) 
        VALUES (:i_valor, i_num_ejecucion, v_proc_name, i_proceso, i_finicio, i_ffin , i_mensaje, SECONDS_BETWEEN(i_finicio, i_ffin));
    v_contador_ctrl_inf := v_contador_ctrl_inf +1;
    commit;

	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;