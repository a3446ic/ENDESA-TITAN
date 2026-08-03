CREATE OR REPLACE PROCEDURE EXT.SMM_SP_COMPARATIVA_PAGOS_SCAWEB_E4E_CAT_TVTA( IN i_processingUnitSeq BIGINT ,IN i_period VARCHAR(25), IN i_periodseq BIGINT)
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
	
	--SMM_COMP_SCAWEB_E4E_CAT_TVTA
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio borrado de la tabla SMM_COMP_SCAWEB_E4E_CAT_TVTA.', v_log_count, v_idproceso,'info');
	DELETE FROM EXT.SMM_COMP_SCAWEB_E4E_CAT_TVTA WHERE PERIODO = i_period;
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin borrado de la tabla SMM_COMP_SCAWEB_E4E_CAT_TVTA.', v_log_count, v_idproceso,'info');
	

    
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Insertando CREDITOS de datos en tabla EXT.SMM_COMP_SCAWEB_E4E_CAT_TVTA.' , v_log_count, v_idproceso,'info');
    
	INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_CAT_TVTA ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO, E4E_OPERACIONES)   

    SELECT 
        T_SCAWEB.PERIODO,
        T_SCAWEB.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_SCAWEB.PDS,
        TMP_PDS.NOMBRE_FISCAL,
		round(IMPORTE_SCAWEB,2),
        case when T_E4E.POSITIVO_CON_CONTRATO is null then 0 else round(T_E4E.POSITIVO_CON_CONTRATO,2) end as Con_Contrato,
        case when T_E4E.POSITIVO_SIN_CONTRATO is null then 0 else round(T_E4E.POSITIVO_SIN_CONTRATO,2) end as Sin_Contrato,
		case when T_E4E.NEGATIVO is null then 0 else round(T_E4E.NEGATIVO,2) end as Negativo,
        case when T_E4E.OPERACIONES is null then 0 else round(T_E4E.OPERACIONES,2) end as Operaciones

    FROM
        ( select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
            from EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA sca where PERIODO = I_PERIOD
            group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO 
        ) T_SCAWEB
        LEFT JOIN 
            (select TRIM(IDPROVEEDOR) as IDPROVEEDOR, POS_ID, 
				sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
				sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
				SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
				SUM(VALOR_OPERACIONES) AS OPERACIONES
				--SUM(VALOR_INSTALADORES) AS INSTALADORES
				--SUM(VALOR_AAFF) AS AAFF
				--SUM(VALOR_ALIADOS) AS ALIADOS
			from EXT.SMM_E4E_DEPOSIT_CAT_TVTA_TEMP 
			where periodseq=i_periodseq
			group by TRIM(IDPROVEEDOR), POS_ID 
            ) T_E4E

            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.POS_ID)

		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, POS_NAME, 
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
			from EXT.SMM_E4E_NEG_TEMP_CAT_TVTA
			where periodseq=i_periodseq
			group by TRIM(IDPROVEEDOR), POS_NAME
			)E4ENT
			ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.POS_NAME)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)

        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON T_SCAWEB.PDS=TMP_PDS.PDS

        INNER JOIN EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA TMP_PROV 
            ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR)
		;        

   
    COMMIT;

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA.' ,  v_log_count, v_idproceso, 'info');

    INSERT INTO EXT.SMM_COMP_SCAWEB_E4E_CAT_TVTA ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO, E4E_OPERACIONES, E4E_INSTALADORES, E4E_AAFF, E4E_ALIADOS)   
    SELECT    
		T_E4E.PERIODO,
		T_E4E.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_E4E.POS_ID,
        TMP_PDS.NOMBRE_FISCAL,
        round(T_SCAWEB.IMPORTE_SCAWEB,2),
        round(T_E4E.POSITIVO_CON_CONTRATO,2),
        round(T_E4E.POSITIVO_SIN_CONTRATO,2),
        round(T_E4E.NEGATIVO,2),
        round(T_E4E.OPERACIONES,2),
        round(T_SCAWEB.IMPORTE_SCAWEB,2), --round(T_E4E.INSTALADORES,2),
        round(T_SCAWEB.IMPORTE_SCAWEB,2), --round(T_E4E.AAFF,2),
        round(T_SCAWEB.IMPORTE_SCAWEB,2) --round(T_E4E.ALIADOS,2)
    FROM
        ( SELECT i_period PERIODO, TRIM(IDPROVEEDOR)  AS IDPROVEEDOR, POS_ID, 
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NOT NULL THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NULL THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
            SUM(CASE WHEN VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
            SUM(VALOR_OPERACIONES) AS OPERACIONES
            --SUM(VALOR_INSTALADORES) AS INSTALADORES,
            --SUM(VALOR_AAFF) AS AAFF,
            --SUM(VALOR_ALIADOS) AS ALIADOS
            FROM EXT.SMM_E4E_DEPOSIT_CAT_TVTA_TEMP 
            WHERE PERIODSEQ = i_periodseq
            GROUP BY i_period, TRIM(IDPROVEEDOR), POS_ID 
        ) T_E4E

        LEFT JOIN
            ( SELECT 
				PERIODO,
                TRIM( TO_CHAR(PROVEEDOR,'000')) IDPROVEEDOR,
                SCA.CODIGO_AGENTE_INTERNO AS PDS,
                SUM(REALVALUE) AS IMPORTE_SCAWEB,
                COUNT(*) REGISTROS
                FROM EXT.SMM_SCAWEB_LIQUIDACION_CAT_TVTA SCA
                WHERE PERIODO = i_period            
                GROUP BY PERIODO, TRIM( TO_CHAR(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO             
            ) T_SCAWEB
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.POS_ID)

        INNER JOIN EXT.SMM_PDS_TEMP TMP_PDS
            ON T_E4E.POS_ID = TMP_PDS.PDS

        INNER JOIN EXT.SMM_PROVEEDORES_TEMP_CAT_TVTA TMP_PROV 
            ON TRIM(TMP_PROV.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR)

	WHERE T_SCAWEB.IMPORTE_SCAWEB IS NULL;
    
    COMMIT;
    
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga INCENTIVOS de la tabla SMM_COMP_SCAWEB_E4E_CAT_TVTA: '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
   
        
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla SMM_COMP_SCAWEB_E4E_CAT_TVTA '|| ::ROWCOUNT || ' filas.', v_log_count, v_idproceso, 'info');

    


    
  

	CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, v_proc_name, v_finicio, current_timestamp, NULL);
	
	
	CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
end