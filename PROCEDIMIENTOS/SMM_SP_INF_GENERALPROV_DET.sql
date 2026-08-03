CREATE OR REPLACE PROCEDURE EXT.SMM_SP_INF_GENERALPROV_DET( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--SMM_GRALPROV_DETALLE
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_GRALPROV_DETALLE.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_GRALPROV_DETALLE WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_GRALPROV_DETALLE.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando CREDITOS de datos en tabla EXT.SMM_GRALPROV_DETALLE.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_GRALPROV_DETALLE ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, TIPO_IMPOSITIVO, DELEGACION, ZONA, TERRITORIO, IMPORTEBASE )   
    SELECT 
        i_period,
        ept.IDPROVEEDOR,
        ept.DESCRIPCION,
        ept.ACTIVIDAD,
        EPDS.PDS,
        EPDS.NOMBRE_FISCAL,            
        EPDS.TIPO_IMPOSITIVO,
        EPDS.DELEGACION,
        EPDS.ZONA,
        EPDS.TERRITORIO,
        sum(edt.VALUE) IMPORTEBASE
            
    FROM EXT.SMM_PROVEEDORES_TEMP ept
        LEFT JOIN EXT.SMM_DEPOSIT_TEMP edt 
             ON EPT.IDPROVEEDOR = edt.EARNINGGROUPID

        LEFT JOIN EXT.SMM_PDS_TEMP epds
             ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
             AND EPDS.PAYEESEQ = edt.payeeseq
    WHERE
        edt.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
            '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
            '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
            '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			'242','243','244','245','246', '247','249','250','251','252', '254', '255', '256',
            '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288', '289')
             --APM 09.08.2022 Se añade el earninggroup '254'
             -- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
             -- DMS 21.06.23 AÑADO 258,259 Y260
             -- DCR 29.06.23 AÑADO WBE 264
             -- DCR 30.06.23 AÑADO WBE 265
             -- APM 25.04.24 AÑADO WBE 268
             -- APM 19.03.2026 Añado WBE 289
    GROUP BY i_period, 
        ept.IDPROVEEDOR,
        EPT.DESCRIPCION,
        ept.actividad,
        EPDS.PDS,
        EPDS.NOMBRE_FISCAL,
        EPDS.TIPO_IMPOSITIVO,
        EPDS.DELEGACION,
        EPDS.ZONA,
        EPDS.TERRITORIO;            

   
    COMMIT;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla ENEL_GRALPROV_DETALLE no Elsa: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
    INSERT INTO EXT.SMM_GRALPROV_DETALLE ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, TIPO_IMPOSITIVO, DELEGACION, ZONA, TERRITORIO, IMPORTEBASE ) 
    SELECT 
        i_period,
        ept.IDPROVEEDOR,
        ept.DESCRIPCION,
        ept.ACTIVIDAD,
        EPDS.PDS,
        EPDS.NOMBRE_FISCAL,            
        EPDS.TIPO_IMPOSITIVO,
        EPDS.DELEGACION,
        EPDS.ZONA,
        EPDS.TERRITORIO,
        sum(edt.VALUE) IMPORTEBASE
            
    FROM EXT.SMM_PROVEEDORES_TEMP ept
        LEFT JOIN EXT.SMM_DEPOSIT_TEMP edt 
             ON EPT.IDPROVEEDOR = edt.wbe

        LEFT JOIN EXT.SMM_PDS_TEMP epds
             ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
             AND EPDS.PAYEESEQ = edt.payeeseq
    WHERE
        edt.wbe not in ( '004', '011', '012', '015', '017', '019', '023', '031', '032', 
            '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
            '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
            '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			'242','243','244','245','246','247','249','250','251','252', '254', '255', '256',
            '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277','287','288')
             --APM 09.08.2022 Se añade el earninggroup '254'
             -- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
             -- DMS 21.06.23 AÑADO 258,259 Y260
             -- DCR 29.06.23 AÑADO WBE 264
             -- DCR 30.06.23 AÑADO WBE 265
             -- APM 25.04.24 AÑADO WBE 268
    GROUP BY i_period, 
        ept.IDPROVEEDOR,
        EPT.DESCRIPCION,
        ept.actividad,
        EPDS.PDS,
        EPDS.NOMBRE_FISCAL,
        EPDS.TIPO_IMPOSITIVO,
        EPDS.DELEGACION,
        EPDS.ZONA,
        EPDS.TERRITORIO;      
    
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga INCENTIVOS de la tabla SMM_GRALPROV_DETALLE: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_GRALPROV_DETALLE '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end;