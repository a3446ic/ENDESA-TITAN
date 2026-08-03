CREATE OR REPLACE PROCEDURE EXT.SP_PACKAGE_E4E(OUT o_salidacontrol VARCHAR(50)
-- ,IN calendar VARCHAR(50)
-- ,IN calendarSeq BIGINT
-- ,IN groupid VARCHAR(50)
,IN i_period VARCHAR(50)
,IN i_periodseq BIGINT
,IN i_processingUnit VARCHAR(50)
,IN i_processingUnitSeq BIGINT
,IN i_stage VARCHAR(50)
-- ,IN userName VARCHAR(50)
,IN i_triggerFilename VARCHAR(50)
,IN i_informe NVARCHAR(250)
)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS
/* *****************************************************************************
NAME:       EXT.ACTUALIZA_INFORMES_CCDD
   PURPOSE:

   REVISIONS:
	Ver      		Date        	Author           	Description
	---------  		----------  	---------------  	-----------------------------------
    
	1.1    Or?genes de datos
    -    DEPOSITOS (CS_DEPOSIT)
    -    DATOS DE CONTRATOS (Clasificaci?n)
    -    DATOS PROVEEDOR (Clasificaci?n)
    -    DATOS PDS (Jerarqu?a)

   2.0      11/12/2017 MRA              Modificaciones para SPRINT 2 - E4E_NEGATIVOS Se marca como LIQUIDADO
   
   3.0  DCR     09.11.2022  CAL0247 - Generar ficheros E4E de CCDD
   4.0								SMM					MIGRACIÓN HANA
***************************************************************************** */
BEGIN
DECLARE v_cont INT = 0;
DECLARE v_proc_name NVARCHAR(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
DECLARE v_version NVARCHAR(4) := '4.0';
DECLARE v_log_count INTEGER := 0;
DECLARE v_idproceso BIGINT := 0;
DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL:getTenantID();
DECLARE v_permisos_log NVARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
DECLARE v_Interfaz_Proceso NVARCHAR(50);
DECLARE v_Interfaz_Activo INT;
DECLARE v_Listado_Informes  NVARCHAR(500);
DECLARE i_periodLiquidado boolean;
DECLARE v_FInicio_Inf timestamp;
DECLARE v_FFin_Inf timestamp;
DECLARE v_i_i_periodo VARCHAR2(50); --DCR 15.05.2023
DECLARE v_puseq VARCHAR2(50); --DCR 15.05.2023
DECLARE v_contador_debug INT;
DECLARE v_contador_ctrl_inf INT;
DECLARE v_num_ejecucion INT;
DECLARE v_Argumentos INT;



DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Error en procedimiento principal ' || v_proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																											|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_idproceso, 'error');
																										
		RESIGNAL;
	END;
	
	CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Procedure starting for: ' || v_proc_name, v_log_count, v_idproceso,'info');
	CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name, 'Argumentos del proceso: i_period:' || i_period
		|| ' || i_processingUnit: ' || i_processingUnit
		|| ' || i_triggerFilename: ' || i_triggerFilename
		, v_log_count, v_idproceso,'info');
	
	
    --Iniciamos el contador del Debug
    v_contador_debug := 0;
        
    CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Procedure starting...', v_log_count, v_idproceso,'info');
    CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumentos del proceso ', v_log_count, v_idproceso,'info');
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: calendar             : ['||calendar           ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: calendarSeq          : ['||calendarSeq        ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: groupid              : ['||groupid            ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_period               : ['||i_period             ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_periodseq            : ['||i_periodseq          ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_processingUnit       : ['||i_processingUnit     ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_processingUnitSeq    : ['||i_processingUnitSeq  ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_stage                : ['||i_stage              ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: userName             : ['||userName           ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_triggerFilename      : ['||i_triggerFilename    ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: tenantId             : ['||tenantId           ||']', v_log_count, v_idproceso,'info');
    -- CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_informe              : ['||i_informe            ||']', v_log_count, v_idproceso,'info');  
 
	-- BOM - DCR - Gestion Control de Informes 
 
 IF(i_processingUnit= 'MENSUAL') THEN
		----------------------------------------------------------------------------------
		-- Este activo o no el interfaz, borramos las tablas de salida                     --
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
        -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
        -- No enviar? fichero                                                             --
        
        --------------- Borrado de las tablas que utilizamos --------------
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.E4E_INF', v_log_count, v_idproceso,'info');
        EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.E4E_INF';
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.E4E_INF', v_log_count, v_idproceso,'info');    
        
        v_Interfaz_Proceso := 'EXT.E4E1_M_CA';
        CALL EXT.SP_ACTUALIZA_FECHAS(v_Interfaz_Proceso,'SHPOSPOST'); -- Con uno actualizamos todos los de E4E a la vez
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.F_DATOS_INTERFAZ(:v_Interfaz_Proceso);                                                                                                                                                                                                                                                                                 
        IF v_Interfaz_Activo = 0 then
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        END IF;
    
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos
        --    v_Interfaz_Proceso := 'EXT.E4E2_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E3_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E4_M_CA';
          
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.E4E_INF.', v_log_count, v_idproceso,'info');
        
		--------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
        IF  i_triggerFilename = 'EJECUCION_MANUAL' then
			CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		ELSE
            CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF; 
        
		-- Extraer datos de EXT.E4E_FINAL para la tabla del informe/Interfaz. Tabla: EXT.E4E_INF
        INSERT INTO EXT.E4E_INF (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
		SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
			CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO
		FROM EXT.E4E_FINAL
		WHERE PERIODO = i_period;
        
		
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.E4E_INF: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
        
		-- v2.0
        UPDATE EXT.E4E_NEGATIVOS set ESTADO ='LIQUIDADO' WHERE PERIODO=i_period AND ESTADO ='PROVISIONAL';
        
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.E4E_NEGATIVOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
	END IF;
    
    IF(i_processingUnit= 'MENSUAL TF') THEN
		----------------------------------------------------------------------------------
        -- Este activo o no el interfaz, borramos las tablas de salida                     --
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
        -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
        -- No enviar? fichero                                                             --
        
        --------------- Borrado de las tablas que utilizamos --------------
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.E4E_INF_TF', v_log_count, v_idproceso,'info');
        EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.E4E_INF_TF';
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.E4E_INF_TF', v_log_count, v_idproceso,'info');    
        
		v_Interfaz_Proceso := 'EXT.E4E1_M_TF';
        CALL EXT.SP_ACTUALIZA_FECHAS(v_Interfaz_Proceso,'SHPOSTF'); -- Con uno actualizamos todos los de E4E a la vez
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.F_DATOS_INTERFAZ(:v_Interfaz_Proceso);                                                                                                                                                                                                                                                                                 
        IF v_Interfaz_Activo = 0 then
            o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        END IF;
    
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos
		--    v_Interfaz_Proceso := 'EXT.E4E2_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E3_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E4_M_CA';
          
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.E4E_INF.', v_log_count, v_idproceso,'info');
        
		--------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
		IF  i_triggerFilename = 'EJECUCION_MANUAL' then
			CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		ELSE
            CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF; 
        
		-- Extraer datos de EXT.E4E_FINAL para la tabla del informe/Interfaz. Tabla: EXT.E4E_INF
        INSERT INTO EXT.E4E_INF_TF (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
		SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
			CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO
		FROM EXT.E4E_FINAL_TF
		WHERE PERIODO = i_period;
        
		
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.E4E_INF_TF: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
              
		-- v2.0
        UPDATE EXT.E4E_NEGATIVOS_TF set ESTADO ='LIQUIDADO' WHERE PERIODO=i_period AND ESTADO ='PROVISIONAL';
        
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.E4E_NEGATIVOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
    
    END IF;
	
	    IF(i_processingUnit= 'ALIADOS') THEN
		----------------------------------------------------------------------------------
        -- Este activo o no el interfaz, borramos las tablas de salida                     --
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
        -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
        -- No enviar? fichero                                                             --
        
        --------------- Borrado de las tablas que utilizamos --------------
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.E4E_INF_ALIADOS', v_log_count, v_idproceso,'info');
        EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.E4E_INF_ALIADOS';
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.E4E_INF_ALIADOS', v_log_count, v_idproceso,'info');    
        
		v_Interfaz_Proceso := 'EXT.E4E_INF_ALIADOS';
        CALL EXT.SP_ACTUALIZA_FECHAS(v_Interfaz_Proceso,'SHPOSTF'); -- Con uno actualizamos todos los de E4E a la vez
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.F_DATOS_INTERFAZ(:v_Interfaz_Proceso);                                                                                                                                                                                                                                                                                 
        IF v_Interfaz_Activo = 0 then
            o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        END IF;
    
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos
		--    v_Interfaz_Proceso := 'EXT.E4E2_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E3_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E4_M_CA';
          
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.E4E_INF.', v_log_count, v_idproceso,'info');
        
		--------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
		IF  i_triggerFilename = 'EJECUCION_MANUAL' then
			CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		ELSE
            CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF; 
        
		-- Extraer datos de EXT.E4E_FINAL para la tabla del informe/Interfaz. Tabla: EXT.E4E_INF
        INSERT INTO EXT.E4E_INF_ALIADOS (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
		SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
			CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO
		FROM EXT.E4E_FINAL_TF
		WHERE PERIODO = i_period;
        
		
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.E4E_INF_ALIADOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
        -- v2.0
        UPDATE EXT.E4E_NEGATIVOS_ALIADO set ESTADO ='LIQUIDADO' WHERE PERIODO=i_period AND ESTADO ='PROVISIONAL';
        
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.E4E_NEGATIVOS_ALIADO: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
    
    END IF;
    
    IF(i_processingUnit= 'MENSUAL CAT TVTA') THEN
		----------------------------------------------------------------------------------
        -- Este activo o no el interfaz, borramos las tablas de salida                     --
        -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
        -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
        -- No enviar? fichero                                                             --
        
        --------------- Borrado de las tablas que utilizamos --------------
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.E4E_INF_CAT_TVTA', v_log_count, v_idproceso,'info');
        EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.E4E_INF_CAT_TVTA';
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.E4E_INF_CAT_TVTA', v_log_count, v_idproceso,'info');    
        
        v_Interfaz_Proceso := 'EXT.E4E1_M_CAT_TVTA';
        CALL EXT.SP_ACTUALIZA_FECHAS(v_Interfaz_Proceso,'SHPOSTCATTVTA'); -- Con uno actualizamos todos los de E4E a la vez
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.F_DATOS_INTERFAZ(:v_Interfaz_Proceso);                                                                                                                                                                                                                                                                                 
        IF v_Interfaz_Activo = 0 then
            o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        END IF;
    
		-- De momento parecr que s?lo va a haber un fichero de E4E. Por lo tanto, no comprobamos
        --    v_Interfaz_Proceso := 'EXT.E4E2_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E3_M_CA';
        --    v_Interfaz_Proceso := 'EXT.E4E4_M_CA';
          
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.E4E_INF.', v_log_count, v_idproceso,'info');
        
        --------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
        IF  i_triggerFilename = 'EJECUCION_MANUAL' then
			CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		ELSE
            CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF; 
        
		-- Extraer datos de EXT.E4E_FINAL para la tabla del informe/Interfaz. Tabla: EXT.E4E_INF
        INSERT INTO EXT.E4E_INF_CAT_TVTA (ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
		SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
			CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT
		FROM EXT.E4E_FINAL_CAT_TVTA
		WHERE PERIODO = i_period;
        
		
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.E4E_INF_CAT_TVTA: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
        -- v2.0
        --UPDATE EXT.E4E_NEGATIVOS_CAT_TVTA set ESTADO ='LIQUIDADO' WHERE PERIODO=i_period AND ESTADO ='PROVISIONAL';
        --
        --COMMIT;
        --CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Se ha actualizado como LIQUIDADO los datos de EXT.E4E_NEGATIVOS: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
    
		CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
    
	END IF;
    
/* BOM DCR 09.11.2022 CAL0247 */
    IF(i_processingUnit= 'CCDD') THEN
        --------------- Borrado de las tablas que utilizamos --------------
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Truncado de la tablas EXT.E4E_INF_CCDD', v_log_count, v_idproceso,'info');
        EXECUTE IMMEDIATE 'TRUNCATE TABLE EXT.E4E_INF_CCDD';
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Truncado de la tablas EXT.E4E_INF_CCDD', v_log_count, v_idproceso,'info');    
        
        v_Interfaz_Proceso := 'EXT.E4E1_M_CCDD';
        CALL EXT.SP_ACTUALIZA_FECHAS(v_Interfaz_Proceso,'SHPOSPOST'); -- Con uno actualizamos todos los de E4E a la vez
        
        SELECT ACTIVO INTO v_Interfaz_Activo DEFAULT 0 FROM EXT.F_DATOS_INTERFAZ(:v_Interfaz_Proceso);                                                                                                                                                                                                                                                                                 
        IF v_Interfaz_Activo = 0 then
            o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        END IF;
        
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Inicio Carga de la tabla de EXT.E4E_INF_CCDD.', v_log_count, v_idproceso,'info');
        
        --------------- Comprobar si es una ejecucion por StageHook o manual --------------
        
        IF  i_triggerFilename = 'EJECUCION_MANUAL' then
			CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
		ELSE
            CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
		END IF; 
        
		-- Extraer datos de EXT.E4E_FINAL para la tabla del informe/Interfaz. Tabla: EXT.E4E_INF
        INSERT INTO EXT.E4E_INF_CCDD (
            ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, CAMPO11, CAMPO12, CAMPO13, 
            CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT
        )
		
            SELECT ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, CAMPO11, CAMPO12, 
                CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT
            FROM EXT.E4E_FINAL_CCDD
            WHERE PERIODO = i_period;
        
		
        COMMIT;
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin Carga de la tabla de EXT.E4E_INF_CCDD: ' || ::ROWCOUNT || ' filas.', v_log_count, v_idproceso,'info');
          
        
        CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Fin del proceso.', v_log_count, v_idproceso,'info');
              
        o_salidacontrol :='Procedure E4E finalizado correctamente.';
        
    END IF;
                                                                                                                                                                                                                                                                                                                                      
                                                                                                                                                                                                                                                                                                                           
                                                                                                                                                                                                                                                                                                                                      
    CALL EXT.LIB_GLOBAL:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Procedure ' || v_proc_name  ||' Ending...', v_log_count, v_idproceso,'info');                                                                                                                                                                                                                                                         
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          

END