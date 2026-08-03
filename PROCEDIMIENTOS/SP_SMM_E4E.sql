CREATE OR REPLACE PROCEDURE EXT.SP_SMM_E4E(OUT o_salidacontrol VARCHAR(50)
-- ,IN calendar VARCHAR(50)
-- ,IN calendarSeq BIGINT
-- ,IN groupid VARCHAR(50)
,IN i_period VARCHAR(50)
-- ,IN periodSeq BIGINT
,IN i_processingUnit VARCHAR(50)
-- ,IN processingUnitSeq BIGINT
-- ,IN stage VARCHAR(50)
-- ,IN userName VARCHAR(50)
,IN i_triggerFilename VARCHAR(50)
)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 18-06-2026
    |----------------------------------------------------------------------
    | Procedure Purpose: Dependiendo de la i_processingUnit vacía tablas y las vuelve a cargar con datos filtrados
    |
	| Version:	0.1	SMM	20260618   Initial Version.
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
DECLARE v_Interfaz_Proceso NVARCHAR(50);
DECLARE v_Interfaz_Activo INT;



DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																											
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: i_period:' || i_period
		|| ' || i_processingUnit: ' || i_processingUnit
		|| ' || i_triggerFilename: ' || i_triggerFilename
		, v_log_count, v_idproceso,'info');
	

	
	
	IF(:i_processingUnit='MENSUAL') THEN
		----------------------------------------------------------------------------------
		-- Este activo o no el interfaz, borramos las tablas de salida                     --
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
        -- Al estar esta opci?n: EXT.CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
        -- No enviar? fichero                                                             --
        ----------------------------------------------------------------------------------
		
		--------------- Borrado de las tablas que utilizamos --------------
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Truncado de tabla SMM_E4E_INF', v_log_count, v_idproceso,'info');
		TRUNCATE TABLE EXT.SMM_E4E_INF;
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Fin truncado de tabla SMM_E4E_INF', v_log_count, v_idproceso,'info');
		
		v_Interfaz_Proceso := 'ENEL_E4E1_M_CA';
		CALL EXT.SP_SMM_ACTUALIZA_FECHAS_ECO_FICHERO(:i_period,:v_Interfaz_Proceso,'SHPOSPOST',v_proc_name,v_idproceso,v_log_count); -- Con uno actualizamos todos los de E4E a la vez
		
		SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.SMM_F_INTERFAZ_ACTIVO(:v_Interfaz_Proceso);
		IF v_Interfaz_Activo = 0 THEN
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		    RETURN;
		END IF;
		
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos
        --    v_Interfaz_Proceso := 'ENEL_E4E2_M_CA';
        --    v_Interfaz_Proceso := 'ENEL_E4E3_M_CA';
        --    v_Interfaz_Proceso := 'ENEL_E4E4_M_CA';
          
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.SMM_E4E_INF.', v_log_count, v_idproceso,'info');
        
		--------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
        if  :i_triggerFilename = 'EJECUCION_MANUAL' THEN
			CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		else
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF;
        
		-- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_E4E_INF
        INSERT INTO EXT.SMM_E4E_INF (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
		SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
			CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO
		FROM EXT.SMM_E4E_FINAL
		WHERE PERIODO = :i_period;
        
		
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.SMM_E4E_INF: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
        -- EXECUTE IMMEDIATE 'ANALYZE TABLE EXT.SMM_E4E_INF COMPUTE STATISTICS FOR ALL INDEXES';
        -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Actualizacion Indices EXT.SMM_E4E_INF.', v_log_count, v_idproceso,'info');
                
		-- v2.0
        UPDATE EXT.SMM_E4E_NEGATIVOS set ESTADO ='LIQUIDADO' WHERE PERIODO=i_period AND ESTADO ='PROVISIONAL';
        
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.SMM_E4E_NEGATIVOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
        
        INSERT INTO EXT.SMM_ECO_INF(periodo,canal,actividad,subactividad, idproveedor, name ,pds ,importe)
        select periodo, canal, actividad, subactividad, idproveedor, name, pds, importe
        from EXT.SMM_ECO_FINAL
        WHERE PERIODO= i_period OR PERIODO IS NULL;       
		
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Carga de la tabla SMM_ECO_INF. Filas: ' || ::ROWCOUNT, v_log_count, v_idproceso,'info');
	
    ELSEIF(:i_processingUnit='MENSUAL TF') THEN
    	----------------------------------------------------------------------------------
        -- Este activo o no el interfaz, borramos las tablas de salida                     --
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
        -- Al estar esta opci?n: EXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
        -- No enviar? fichero                                                --
        ----------------------------------------------------------------------------------
		
		--------------- Borrado de las tablas que utilizamos --------------
    	CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Truncado de tabla SMM_E4E_INF_TF', v_log_count, v_idproceso,'info');
		TRUNCATE TABLE EXT.SMM_E4E_INF_TF;
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Fin truncado de tabla SMM_E4E_INF_TF', v_log_count, v_idproceso,'info');
		v_Interfaz_Proceso := 'ENEL_E4E1_M_TF';  
	
		CALL EXT.SP_SMM_ACTUALIZA_FECHAS_ECO_FICHERO(:i_period,:v_Interfaz_Proceso,'SHPOSTF',v_proc_name,v_idproceso,v_log_count); -- Con uno actualizamos todos los de E4E a la vez
		
		SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.SMM_F_INTERFAZ_ACTIVO(:v_Interfaz_Proceso);
		IF v_Interfaz_Activo = 0 THEN
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		    RETURN;
		END IF;
		-- 	IF f_Interfaz_Activo(v_Interfaz_Proceso) = 'NO' THEN
					-- o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		--         RETURN;
		--     END IF;;
		
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos
        --    v_Interfaz_Proceso := 'ENEL_E4E2_M_CA';
        --    v_Interfaz_Proceso := 'ENEL_E4E3_M_CA';
        --    v_Interfaz_Proceso := 'ENEL_E4E4_M_CA';
          
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.SMM_E4E_INF.', v_log_count, v_idproceso,'info');
        
		--------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
        if  :i_triggerFilename = 'EJECUCION_MANUAL' THEN
			CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		else
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF;
        
		-- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_E4E_INF
        INSERT INTO EXT.SMM_E4E_INF_TF (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
		SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
			CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO
		FROM EXT.SMM_E4E_FINAL_TF
		WHERE PERIODO = :i_period;
        
		
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.SMM_E4E_INF_TF: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
        -- EXECUTE IMMEDIATE 'ANALYZE TABLE EXT.SMM_E4E_INF_TF COMPUTE STATISTICS FOR ALL INDEXES';
        -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Actualizacion Indices EXT.SMM_E4E_INF_TF.', v_log_count, v_idproceso,'info');
                
		-- v2.0
        UPDATE EXT.SMM_E4E_NEGATIVOS_TF set ESTADO ='LIQUIDADO' WHERE PERIODO=i_period AND ESTADO ='PROVISIONAL';
        
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.SMM_E4E_NEGATIVOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
        
        INSERT INTO EXT.SMM_ECO_INF(periodo,canal,actividad,subactividad, idproveedor, name ,pds ,importe)
        select periodo, canal, actividad, subactividad, idproveedor, name, pds, importe
        from EXT.SMM_ECO_FINAL
        WHERE PERIODO= i_period OR PERIODO IS NULL;       
		
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Carga de la tabla SMM_ECO_INF. Filas: ' || ::ROWCOUNT, v_log_count, v_idproceso,'info');
	ELSEIF(:i_processingUnit='ALIADOS') THEN
		  ----------------------------------------------------------------------------------                                                                                                                                                                          
        -- Este activo o no el interfaz, borramos las tablas de salida                     --                                                                                                                                                                 
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --                                                                                                                                                                 
        -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --                                                                                                                                                                    
        -- No enviar? fichero                                                             --                                                                                                                                                                  
                                                                                                                                                                                                                                                              
        --------------- Borrado de las tablas que utilizamos --------------                                                                                                                                                                                   
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.SMM_E4E_INF_ALIADOS', v_log_count, v_idproceso,'info');
        execute immediate 'truncate table EXT.SMM_E4E_INF_ALIADOS';                                                                                                                                                                                      
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.SMM_E4E_INF_ALIADOS', v_log_count, v_idproceso,'info');   
                                                                                                                                                                                                                                                              
		v_Interfaz_Proceso := 'ENEL_E4E_INF_ALIADOS';                                                                                                                                                                                                               
        CALL EXT.SP_SMM_ACTUALIZA_FECHAS_ECO_FICHERO(:i_period,:v_Interfaz_Proceso,'SHPOSTF',v_proc_name,v_idproceso,v_log_count); -- Con uno actualizamos todos los de E4E a la vez                                                                                                                                                   
        -- p_Actualiza_Fechas(v_Interfaz_Proceso,'SHPOSTF'); -- Con uno actualizamos todos los de E4E a la vez                                                                                                                                                   
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.SMM_F_INTERFAZ_ACTIVO(:v_Interfaz_Proceso);
		IF v_Interfaz_Activo = 0 THEN
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		    RETURN;
		END IF;                                                                                                                                                                                                                                                      
        -- IF f_Interfaz_Activo(v_Interfaz_Proceso) = 'NO' THEN                                                                                                                                                                                                  
        --     o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';                                                                                                                                                                                     
        --     RETURN;                                                                                                                                                                                                                                           
        -- END IF;;                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                              
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos                                                                                                                                                                    
		--    v_Interfaz_Proceso := 'ENEL_E4E2_M_CA';                                                                                                                                                                                                               
        --    v_Interfaz_Proceso := 'ENEL_E4E3_M_CA';                                                                                                                                                                                                         
        --    v_Interfaz_Proceso := 'ENEL_E4E4_M_CA';                                                                                                                                                                                                         
                                                                                                                                                                                                                                                              
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.SMM_E4E_INF.', v_log_count, v_idproceso,'info');              
                                                                                                                                                                                                                                                              
		--------------- Comprobar si es una ejecucion por StageHook o manual --------------                                                                                                                                                                         
                                                                                                                                                                                                                                                              
		if  :i_triggerFilename = 'EJECUCION_MANUAL' THEN                                                                                                                                                                                                               
			CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||:i_period, v_log_count, v_idproceso,'info');             
		else                                                                                                                                                                                                                                                        
		    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| :i_period, v_log_count, v_idproceso,'info');
		END IF;                                                                                                                                                                                                                                              
                                                                                                                                                                                                                                                              
		-- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_E4E_INF                                                                                                                                                                  
        INSERT INTO EXT.SMM_E4E_INF_ALIADOS (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10,                                                                                                                     
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)                                                                                               
		  SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10,                                                                                                                                                              
		   CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO                                                                                                                                        
		  FROM EXT.SMM_E4E_FINAL_TF                                                                                                                                                                                                                              
		  WHERE PERIODO = :i_period;                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                              
		--filas := sql%rowcount;                                                                                                                                                                                                                                      
		--      COMMIT;                                                                                                                                                                                                                                               
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.SMM_E4E_INF_ALIADOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');                                                                                                           
                                                                                                                                                                                                                                                              
        -- EXECUTE IMMEDIATE 'ANALYZE TABLE EXT.SMM_E4E_INF_ALIADOS COMPUTE STATISTICS FOR ALL INDEXES';                                                                                                                                                    
        -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Actualizacion Indices EXT.SMM_E4E_INF_ALIADOS.', v_log_count, v_idproceso,'info');                                                                                                                                          
                                                                                                                                                                                                                                                              
		-- v2.0                                                                                                                                                                                                                                                     
        UPDATE EXT.SMM_E4E_NEGATIVOS_ALIADO set ESTADO ='LIQUIDADO' WHERE PERIODO=:i_period AND ESTADO ='PROVISIONAL';                                                                                                                                              
        -- filas := sql%rowcount;                                                                                                                                                                                                                                
        -- COMMIT;                                                                                                                                                                                                                                               
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.SMM_E4E_NEGATIVOS_ALIADO: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');                                                                                 
                                                                                                                                                                                                                                                              
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');                                               
                                                                                                                                                                                                                                                              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';   
	ELSEIF(:i_processingUnit='MENSUAL CAT TVTA') THEN
		----------------------------------------------------------------------------------                                                                                                                                                                          
        -- Este activo o no el interfaz, borramos las tablas de salida                     --                                                                                                                                                                 
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --                                                                                                                                                                 
        -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --                                                                                                                                                                    
        -- No enviar? fichero                                                             --                                                                                                                                                                  
                                                                                                                                                                                                                                                              
        --------------- Borrado de las tablas que utilizamos --------------                                                                                                                                                                                   
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.SMM_E4E_INF_CAT_TVTA', v_log_count, v_idproceso,'info');                                                                                                                                                              
        execute immediate 'truncate table EXT.SMM_E4E_INF_CAT_TVTA';                                                                                                                                                                                     
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.SMM_E4E_INF_CAT_TVTA', v_log_count, v_idproceso,'info');  
                                                                                                                                                                                                                                                              
        v_Interfaz_Proceso := 'ENEL_E4E1_M_CAT_TVTA';                                                                                                                                                                                                         
        CALL EXT.SP_SMM_ACTUALIZA_FECHAS_ECO_FICHERO(:i_period,:v_Interfaz_Proceso,'SHPOSTCATTVTA',v_proc_name,v_idproceso,v_log_count); -- Con uno actualizamos todos los de E4E a la vez                                                                                                                                             
        -- p_Actualiza_Fechas(v_Interfaz_Proceso,'SHPOSTCATTVTA'); -- Con uno actualizamos todos los de E4E a la vez                                                                                                                                             
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.SMM_F_INTERFAZ_ACTIVO(:v_Interfaz_Proceso);
		IF v_Interfaz_Activo = 0 THEN
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		    RETURN;
		END IF;                                                                                                                                                                                                                                                      
        -- IF f_Interfaz_Activo(v_Interfaz_Proceso) = 'NO' THEN                                                                                                                                                                                                  
        --     o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';                                                                                                                                                                                     
        --     RETURN;                                                                                                                                                                                                                                           
        -- END IF;;                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                              
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos                                                                                                                                                                    
        --    v_Interfaz_Proceso := 'ENEL_E4E2_M_CA';                                                                                                                                                                                                         
        --    v_Interfaz_Proceso := 'ENEL_E4E3_M_CA';                                                                                                                                                                                                         
        --    v_Interfaz_Proceso := 'ENEL_E4E4_M_CA';                                                                                                                                                                                                         
                                                                                                                                                                                                                                                              
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.SMM_E4E_INF.', v_log_count, v_idproceso,'info');              
                                                                                                                                                                                                                                                              
        --------------- Comprobar si es una ejecucion por StageHook o manual --------------                                                                                                                                                                   
                                                                                                                                                                                                                                                              
        if  :i_triggerFilename = 'EJECUCION_MANUAL' THEN                                                                                                                                                                                                         
			CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||:i_period, v_log_count, v_idproceso,'info');             
		else                                                                                                                                                                                                                                                        
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| :i_period, v_log_count, v_idproceso,'info');
		END IF;                                                                                                                                                                                                                                                  
                                                                                                                                                                                                                                                              
		-- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_E4E_INF                                                                                                                                                                  
        INSERT INTO EXT.SMM_E4E_INF_CAT_TVTA (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10,                                                                                                                    
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)                                                                                 
			SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10,                                                                                                                                                              
				CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT                                                                                                                          
			FROM EXT.SMM_E4E_FINAL_CAT_TVTA                                                                                                                                                                                                                        
			WHERE PERIODO = :i_period;                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                              
		-- filas := sql%rowcount;                                                                                                                                                                                                                                      
		--      COMMIT;                                                                                                                                                                                                                                               
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.SMM_E4E_INF_CAT_TVTA: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');                                                                                                          
                                                                                                                                                                                                                                                              
        EXECUTE IMMEDIATE 'ANALYZE TABLE EXT.SMM_E4E_INF_CAT_TVTA COMPUTE STATISTICS FOR ALL INDEXES';                                                                                                                                                   
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Actualizacion Indices EXT.SMM_E4E_INF_CAT_TVTA.', v_log_count, v_idproceso,'info');                                                                                                                                         
                                                                                                                                                                                                                                                              
		-- v2.0                                                                                                                                                                                                                                                     
        --UPDATE ENEL_E4E_NEGATIVOS_CAT_TVTA set ESTADO ='LIQUIDADO' WHERE PERIODO=:i_period AND ESTADO ='PROVISIONAL';                                                                                                                                          
        --filas := sql%rowcount;                                                                                                                                                                                                                              
        --COMMIT;                                                                                                                                                                                                                                             
        --CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.SMM_E4E_NEGATIVOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');                                                                                      
                                                                                                                                                                                                                                                              
  CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');                                               
                                                                                                                                                                                                                                                              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';                                                                                                                                                                                            
  
	ELSEIF(:i_processingUnit='CCDD') THEN
		--------------- Borrado de las tablas que utilizamos --------------                                                                                                                                                                                   
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.ENEL_E4E_INF_CCDD', v_log_count, v_idproceso,'info');
        EXECUTE IMMEDIATE 'truncate table EXT.ENEL_E4E_INF_CCDD';                                                                                                                                                                                         
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.ENEL_E4E_INF_CCDD', v_log_count, v_idproceso,'info');   
                                                                                                                                                                                                                                                              
        v_Interfaz_Proceso := 'ENEL_E4E1_M_CCDD';                                                                                                                                                                                                             
        CALL EXT.SP_SMM_ACTUALIZA_FECHAS_ECO_FICHERO(:i_period,:v_Interfaz_Proceso,'SHPOSPOST',v_proc_name,v_idproceso,v_log_count);
        -- p_Actualiza_Fechas(v_Interfaz_Proceso,'SHPOSPOST'); -- Con uno actualizamos todos los de E4E a la vez                                                                                                                                                 
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.SMM_F_INTERFAZ_ACTIVO(:v_Interfaz_Proceso);
		IF v_Interfaz_Activo = 0 THEN
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		    RETURN;
		END IF;                                                                                                                                                                                                                                                      
        -- IF f_Interfaz_Activo(v_Interfaz_Proceso) = 'NO' THEN                                                                                                                                                                                                  
        --     o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';                                                                                                                                                                                     
        --     RETURN;                                                                                                                                                                                                                                           
        -- END IF;;                                                                                                                                                                                                                                               
                                                                                                                                                                                                                                                              
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.ENEL_E4E_INF_CCDD.', v_log_count, v_idproceso,'info');
                                                                                                                                                                                                                                                              
        --------------- Comprobar si es una ejecucion por StageHook o manual --------------                                                                                                                                                                   
                                                                                                                                                                                                                                                              
        if  :i_triggerFilename = 'EJECUCION_MANUAL' THEN                                                                                                                                                                                                         
			CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||:i_period, v_log_count, v_idproceso,'info');          
		else                                                                                                                                                                                                                                                        
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| :i_period, v_log_count, v_idproceso,'info');
		END IF;                                                                                                                                                                                                                                              
                                                                                                                                                                                                                                                              
  -- Extraer datos de ENEL_E4E_FINAL para la tabla del informe/Interfaz. Tabla: ENEL_E4E_INF                                                                                                                                                                  
        INSERT INTO EXT.SMM_E4E_INF_CCDD (                                                                                                                                                                                                               
            ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, CAMPO11, CAMPO12, CAMPO13,                                                                                                                                
            CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT                                                                                                                                            
        )                                                                                                                                                                                                                                                     
                                                                                                                                                                                                                                                              
            SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, CAMPO11, CAMPO12,                                                                                                                                  
                CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT                                                                                                                               
            FROM EXT.SMM_E4E_FINAL_CCDD                                                                                                                                                                                                                  
            WHERE PERIODO = :i_period;                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                              
  --filas := sql%rowcount;                                                                                                                                                                                                                                      
  --      COMMIT;                                                                                                                                                                                                                                               
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.ENEL_E4E_INF_CCDD: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');                                                                                                              
                                                                                                                                                                                                                                                              
        -- EXECUTE IMMEDIATE 'ANALYZE TABLE EXT.ENEL_E4E_INF_CCDD COMPUTE STATISTICS FOR ALL INDEXES';                                                                                                                                                       
        -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Actualizacion Indices EXT.ENEL_E4E_INF_CCDD.', v_log_count, v_idproceso,'info');                                                                                                                                             
                                                                                                                                                                                                                                                              
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');                                      
                                                                                                                                                                                                                                                              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';                                                                                                                                                                                            
        
    END IF;

	
    CALL LIB_GLOBAL_ENDESA:WRITE_DEBUG(v_tenantid,v_permisos_log, v_proc_name, 'Fin procedimiento', v_log_count, v_idproceso, 'info');
    
    COMMIT;

	

END;

-- DO BEGIN

	
-- 	DECLARE o_salidacontrol VARCHAR(50);
-- 	DECLARE i_processingUnit VARCHAR(50) = 'MENSUAL';
-- 	DECLARE i_period VARCHAR(50) = 'Mayo 2026';
-- 	DECLARE i_triggerfilename VARCHAR(50) = 'EJECUCION_MANUAL';

-- 	DELETE FROM EXT.CS_DEBUG WHERE CAST(DATETIME AS DATE) = CURRENT_DATE;
-- 	CALL EXT.SP_SMM_E4E(o_salidacontrol
-- 		,i_period
-- 		,i_processingUnit
-- 		,i_triggerfilename
-- 	);
-- 	SELECT o_salidacontrol FROM DUMMY;
	
-- 	SELECT * FROM EXT.CS_DEBUG WHERE CAST(DATETIME AS DATE) = CURRENT_DATE;
	
-- 	-- SELECT * FROM CS_PERIOD WHERE NAME LIKE '%2026';
	
-- 	SELECT TOP 1 * FROM CS_PLRUN
-- END;