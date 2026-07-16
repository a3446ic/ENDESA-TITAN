CREATE OR REPLACE PROCEDURE EXT.SMM_SP_ACTUALIZA_INFORMES(OUT o_salidacontrol VARCHAR(50)
-- ,IN calendar VARCHAR(50)
-- ,IN calendarSeq BIGINT
-- ,IN groupid VARCHAR(50)
,IN i_period VARCHAR(50)
,IN i_periodSeq BIGINT
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
	NAME:       ACTUALIZA_INFORMES
	PURPOSE:

	REVISIONS:
	Ver      		Date        	Author           	Description
	---------  		----------  	---------------  	-----------------------------------
	1.0				06/07/2017  	Sergio Soriano		Created this package.
	
	1.1        		04/10/2017 		Marcos Rodellar 	Change CS_DEPOSIT with CS_PAYMENT  
														in p_Temporal_Depositos_E4E procedure
														
	1.2        		09/10/2017 		Marcos Rodellar  	p_Temporal_Depositos_E4E procedure will use 
														CS_DEPOSIT in Reward i_stage 
														and CS_PAYMENT  in Pay i_stage
														Add fields in ENEL_INFPDS_CREDIT_TEMP table

	1.3        		16/10/2017 		Marcos Rodellar  	Format MM/DD/YYYY Fecha_Calculo en Andromeda FINAL
														Tabla Revision de creditos INFPDS   

	1.3.1      		17/10/2017 		MRA              	Incidencia: Modificacion Query de p_Final_STP_INFPDS 
														para que coja todos los creditos y no solo Importe Base 

	1.3.2			19/10/2017 		MRA         	 	Modificacion Query de p_Final_Andromeda, Se fuerza que 
														VALUE y PREADJUSTEDVALUE salgan con 2 decimales y separador decimal '.'

	1.3.3			20/10/2017 		MRA             	Modificacion p_Temporal_TXN_INFPDS para hacer LEFT JOIN entre TXN 
														con la tabla de atrib. extendidos, de direcciones y de Asignacion 
														porque no salian los Ajuste (que no tienen Extendidos)

	1.3.4      		30/10/2017 		MRA            		Modificacion generacion de datos para ENEL_SCAWEB_LIQUIDACION para 
														que el periodo de liquidacion se corresponda con el mes siguiente 
														al PERIODO calculado

	1.4       		30/10/2017 		MRA              	Modificacion para Ejecucion Manual, si i_informe viene vacio se asume ALL

	1.5       		02/11/2017 		MRA              	Modificacion ejecucion de Andromeda: nueva funcion f_ComprobarPeriodoLiquidado
														para comprobar si el periodo existe como Liquidado en la tabla ENEL_PERIODOS_LIQUIDADOS
                                         
	1.6      		09/11/2017 		MRA            		Modificacion en extraccion de TXN para Andromeda y INFPDS: Se añade GA3 - ESTADO_GA3 
														para determinar estado Pte. Revisar en funcion de GA3 y GA4 de TXns
														Se añade generacion de tabla Resumen de Pagos 
   
	1.7     	 	10/11/2017 		MRA              	Modificacion p_Temporal_TXN_Andromeda en carga de  ENEL_ANDROMEDA_FINAL en 2 partes:
														- LEFT JOIN  ="%Importes Base" para Prestacion e Instalacion y %Ajuste manual para Ajustes Manuales
														- INNER JOIN <> "%Importes Base" para Prestacion e Instalacion 
														- UPDATE a Pte. Revisar para los registros que no son "%Importes Base" para Prestacion e Instalacion 
														y cuyos "Importes base" estan en "Pte Revisar" 
                                          
	2.0      		11/12/2017 		MRA              	Modificaciones para SPRINT 2
   
	2.1      		S26/02/2018 	MRA              	Se elimina la condicion de credito con valor 0 genera estado Pte Revisar en Tabla Final de Andromeda
   
	2.2      		02/03/2018 		MRA              	p_Inf_Factura_PDS_Detalle: Se modifica la restriccion de incentivos 'I - Captacion%' y se modifica para obtener tambien Incentivos de Atencion 

	2.3      		06/03/2018 		MRA              	p_Temporal_TXN_Andromeda:Se filtra por EVENTYPEID y se optimiza obteniendo los datos de la temporal general de transacciones
														p_Temporal_Creditos: Se añade campo COMMENTS
														p_Temporal_Creditos_Andromeda: se optimiza obteniendo los datos de la temporal general de creditos
                                         
	2.4      		09/03/2018 		MRA					Actualizacion de datos del E4E_Negativos se hace solo en el Reward ya que en fase de pagos no hay negativos en CS_PAYMENT
   
	2.5      		09/03/2018 		MRA             	Incidencia en E4E al extraer datos sin agrupar de CS_PAYMENT
  
	2.6        		11/02/2019 		LLS                	Modificado el p_Temporal_Creditos_Scaweb para sacar el campo RULENAME y poder filtra en el i_informe los canales CNS, AAFF y ALICO
  

	2.5				14/02/2019		LLS					Modificado p_Temporal_Depositos_E4E para incluir los campos VALOR_INSTALADORES, VALOR_AAFF y VALOR_ALIADOS
														Modificado p_Comparativa_Pagos_SCAWEB_E4E para incluir los campos E4E_INSTALADORES, E4E_AAFF y E4E_ALIADOS
                                        
	2.6				15/02/2019		LLS					Añadido el campo SUBPOSICION a ENEL_E4E_CONTRATOS_TEMP y ENEL_E4E_DEPOSIT_TEMP 
														Para p_final_e4e_1 y p_final_e4e_2 para que en el campo7 de la linea SERVICIO se ponga el campo SUBPOSICION (en caso de nulo se informa de nuevo el 10)
														
	2.7				13/11/2019		MPR	                Se modifican los procedimientos de FACOCAPS para incluir la carga de las nuevas tablas para los informes de EOSC y EE
    
	2.8				22/03/2022		DCR	                Portada. Nuevo campo WBE

    2.9				08/08/2022		DCR	                Añadir WBE 254 al i_informe 0.Administracion_02.Informe_E4E_Captacion y 0.Administracion_06.i_informe Balance_Callidus - E4E
    
    2.9.1			09/09/2022		DCR	                Añadir WBE 254 0.Administracion_03.i_informe E4E Negativos
    
    2.10			15/09/2022		RMM	                Añadir WBE 257 0.Administracion_03.i_informe E4E Negativos, 0.Administracion_02.Informe_E4E_Captacion , 0.Administracion_02.Informe_E4E_Captacion
    
    2.11			15/05/2023		DCR	                Evitar cierre de otras PUs
    
    2.12            29/06/2023      DCR                 Añadir proveedor 264 HVAC
	
    2.13            30/06/2023      DCR                 Añadir proveedor 265    
    
    2.14            26/07/2023      DCR                 Mejora proceso p_temporal_creditos
    
    2.15            01/08/2023      DCR                 Ajuste redondeo i_informe Balance E4E
    
    2.16            12/12/2023      APM                 Se añaden nuevos tipos de créditos para la tabla ENEL_COMP_SCAWEB_E4E
    
    2.17            28/12/2023      APM                 Añadir campo COSTE para i_informe 2.Actividad PdS-OCAPS_04.Cuadre de Liquidación
    
    2.18            16/02/2024      APM                 Se añade nuevo tipo de cálculo (Captacion - Prescriptor) para los informes: 
                                                        2. Actividad_03_Prefactura_Detalle, 2.Actividad_02_Prefactura_Portada, 
                                                        0.Administracion_06.i_informe Balance_Callidus - E4E y 2.Actividad PdS-OCAPS_04.Cuadre de Liquidación
  
    2.19            07/03/2024      APM                 Se añaden nuevos campos para Evolutivo CPs - Provincia y Apliación Incentivo CPs.
    
    2.20            25/04/2024      APM                 Añadir proveedor 268

    2.21            05/11/2024      APM                 Añadir nuevo campo TALLA_SOLAR_FV en la tabla ENEL_LIQSCAWEB_FINAL
                                                        Añadir filtro credit type 'Ajuste Venta EnelX - Canal Presencial' en la tabla ENEL_FACTPDS_DETALLE
    
    2.22            16/12/2024      APM                 Nuevos informes de Ricorrente. Aplica a la BU 'CCPP Comercializacion'
    
    2.23            09/01/2025      APM                 Nuevo i_informe 2.Actividad PdS-OCAPS_05.Detalle Tasa Mortandad, pestaña TM2 y TM6
    
    2.24            25/02/2025      APM                 Campo POSICIÓN.GA11 en los informes de OCAPS.
                                                        Se añaden filtros para i_informe de Balance_Callidus (050)
                                                        
    2.25            23/07/2025      DMS                 Se añade proveedor 277
    
    2.26            08/08/2025      APM                 Se añade campo ROL para los informes 2.Actividad PdS-OCAPS_01.Prefactura OCAP_EOSC y 2.Actividad PdS-OCAPS_01.Prefactura OCAP_EOSC_MR
    
    2.27            03/12/2025      APM                 Nuevas tablas para i_informe Agrupado de liquidaciones
    
    2.28            19/12/2025      APM                 Tabla ENEL_CRE_RICORRENTE_DIAS -> Se realiza update del campo FECHA_ACTIVACION
    
    2.29            22/12/2025      APM                 Tabla ENEL_CRE_RICORRENTE_DIAS -> Se incluye JOIN con la tabla CS_TITLE
                                                        Tablas ENEL_TM2_MENSUAL y ENEL_TM6_MENSUAL -> Se añade campo MOTIVO_SOLICITUD
                                                        
    2.30            09/01/2026      APM                 Nuevo campo GRUPO_RETRIBUCION en la tabla ENEL_DEPOSIT_AGRUPADO.
    
    2.31            02/03/2026      APM                 Se añade filtro credtmp.CREDITTYPEID like 'Comisionado Act Comercial - Importe' en la tabla ENEL_SCAWEB_LIQUIDACION
    
    2.32            16/03/2026      APM                 Nuevos campos de fechas en i_informe de 2.Actividad PdS-OCAPS_04.Cuadre de Liquidación
    
    2.33            18/03/2026      APM                 Se actualiza filtro del campo AJUSTE de la tabla ENEL_FACTOPE_RESUMEN_EOSC para ML y MR.

    2.34            19/03/2026      APM                 Cambios para Mas Orange
    
    2.35            27/03/2026      APM                 Se actualiza filtro del campo AJUSTE de las tablas ENEL_FACTOPE_RESUMEN_EE y ENEL_FACTOPE_DETALLE_EE

    2.36            24/04/2026      APM                 Añadir filtro al realizar el insert de Incentivos en la tabla ENEL_SCAWEB_LIQUIDACION -> 'I - ATC - Ajuste Remun Comercial PDS -%'

    2.37            28/04/2026      APM                 Añadir campo PROVEEDOR en las tablas ENEL_FACTOPE_DETALLE_EOSC y ENEL_FACTOPE_RESUMEN_EOSC

    2.38            29/04/2026      APM                 Añadir campo PROVEEDOR en el group by de la tabla ENEL_FACTOPE_RESUMEN_EOSC
    
    2.39            04/05/2026      APM                 Se añade filtro en la tabla ENEL_REMUN - or name like 'I - ATC - Ajuste Remun Comercial PDS%'

    2.40            17/06/2026      APM                 Se añade filtro en el insert de incentivos de la tabla ENEL_FACTOPE_RESUMEN_EOSC - I - ATC - Remun Comercial - Alquiler MR%
    
    2.41            19/06/2026      APM                 Insert de incentivos de la tabla ENEL_FACTOPE_RESUMEN_EOSC se añaden nuevos campos

    2.42            22/06/2026      APM                 Se revierte subida del día 27/03/2026 en la tabla ENEL_FACTOPE_RESUMEN_EE y del día 18/03/2026 en la tabla ENEL_FACTOPE_RESUMEN_EOSC

    2.43            23/06/2026      APM                 Se añade filtro en la tabla ENEL_CREDIT_TEMP, ENEL_SCAWEB_LIQUIDACION, ENEL_FACTPDS_DETALLE, ENEL_RAPPELES y ENEL_RAPPELES_WBE para activación

    2.44            30/06/2026      APM                 Se añaden campos CIF, COD_POSTAL, CALLE en el insert a incentivos de la tabla ENEL_FACTOPE_RESUMEN_EOSC

    2.45            07/07/2026      APM                 En la tabla ENEL_FACTPDS_DETALLE se mapean COD_CONTRATO y CUPS en el insert de Comisiones.

    2.46            09/07/2026      APM                 Se añade filtro en la taba ENEL_FACTPDS_DETALLE en el insert de comisiones y en la tabla ENEL_SCAWEB_LIQUIDACION en el insert de Incentivos el filtro or INCETMP.NAME like 'C - Captacion - Rappel Cuantitativo Incremental -%')
***************************************************************************** */
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
DECLARE v_Listado_Informes  NVARCHAR(500);
DECLARE v_PeriodoLiquidado boolean;
DECLARE v_FInicio_Inf timestamp;
DECLARE v_FFin_Inf timestamp;
DECLARE v_periodo VARCHAR2(50); --DCR 15.05.2023
DECLARE v_puseq VARCHAR2(50); --DCR 15.05.2023
DECLARE v_contador_debug INT;
DECLARE v_contador_ctrl_inf INT;
DECLARE v_num_ejecucion INT;
DECLARE v_Argumentos INT;



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
	
	
    --Iniciamos el contador del Debug
    v_contador_debug := 0;
        
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Procedure starting...', v_log_count, v_idproceso,'info');
    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumentos del proceso ', v_log_count, v_idproceso,'info');
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: calendar             : ['||calendar           ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: calendarSeq          : ['||calendarSeq        ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: groupid              : ['||groupid            ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_period               : ['||i_period             ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_periodSeq            : ['||i_periodSeq          ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_processingUnit       : ['||i_processingUnit     ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_processingUnitSeq    : ['||i_processingUnitSeq  ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_stage                : ['||i_stage              ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: userName             : ['||userName           ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_triggerFilename      : ['||i_triggerFilename    ||']', v_log_count, v_idproceso,'info'); 
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: tenantId             : ['||tenantId           ||']', v_log_count, v_idproceso,'info');
    -- CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento: i_informe              : ['||i_informe            ||']', v_log_count, v_idproceso,'info');  
 
	-- BOM - DCR - Gestion Control de Informes 
 
    v_FInicio_Inf := CURRENT_TIMESTAMP;
    
    SELECT id +1, num_ejecucion +1 INTO v_contador_ctrl_inf, v_num_ejecucion FROM EXT.SMM_ctrl_informes
        WHERE id = (SELECT MAX(id) FROM EXT.SMM_ctrl_informes);
        
    IF v_contador_ctrl_inf is null or v_num_ejecucion is null then
        v_contador_ctrl_inf := 1; 
        v_num_ejecucion :=1;
    END IF;
    CALL EXT.SMM_SP_Z_CTRL_INF(v_contador_ctrl_inf, v_num_ejecucion, 'RUN', v_FInicio_Inf, null, null);

	-- EOM - DCR - Gestion Control de Informes 

    --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    --BOM DCR 15.05.2023 - 2.11 - Creamos variables auxiliares para informar el periodo y PU 
    v_periodo := i_period;
    v_puseq := i_processingUnitSeq;
    --EOM  DCR 15.05.2023 - 2.11 
    
    if  i_triggerFilename = 'EJECUCION_MANUAL' then
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion manual con periodo '||i_period, v_log_count, v_idproceso,'info');
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Informes a actualizar  '||i_informe, v_log_count, v_idproceso,'info');
        v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_MANUAL';
        
        if i_informe = '' or i_informe is null then  -- MRA 
            v_Listado_Informes := 'ALL';
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Argumento Actualizado : i_informe : ['||v_Listado_Informes            ||'] (EJECUCION_MANUAL)', v_log_count, v_idproceso,'info');
        else
            v_Listado_Informes := i_informe;
        end if;
     
    else
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Peticion de ejecucion StageHook con periodo '|| i_period, v_log_count, v_idproceso,'info');
        
        
		v_Interfaz_Proceso :=
		    CASE :i_stage
		        WHEN 'Reward__' THEN 'ACTUALIZA_INFORMES_REWARD'
		        WHEN 'Post__'   THEN 'ACTUALIZA_INFORMES_POST'
		        WHEN 'Pay__'    THEN 'ACTUALIZA_INFORMES_PAY'
		        ELSE NULL
		    END;
       IF v_Interfaz_Proceso IS NULL THEN

		 CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG(
    	    v_tenantid,
    	    v_permisos_log,
    	    v_proc_name,
    	    'i_stage ' || :i_stage || ' No contemplado. Salimos...',
    	    v_log_count,
    	    v_idproceso,
    	    'info'
    	);
	
    	RETURN;

		END IF;
        -- CASE i_stage 
        --     WHEN 'Reward__'  then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_REWARD';  
        --     WHEN 'Post__'    then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST';
        --     WHEN 'Pay__'     then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_PAY';
        -- ELSE 
        --     BEGIN
        --         CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'i_stage '||i_stage||' No contemplado. Salimos...', v_log_count, v_idproceso,'info');
        --         RETURN;
        --     END;
        -- end CASE;
        
        
		v_Interfaz_Proceso :=
		    CASE
		        WHEN :i_stage = 'Reward__' THEN 'ACTUALIZA_INFORMES_REWARD'
		        WHEN :i_stage = 'Post__'   THEN 'ACTUALIZA_INFORMES_POST'
		        WHEN :i_stage = 'Pay__'    THEN 'ACTUALIZA_INFORMES_PAY'
		        ELSE NULL
		    END;
		    
		IF v_Interfaz_Proceso IS NULL THEN

		    CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG(
		        v_tenantid,
		        v_permisos_log,
		        v_proc_name,
		        'i_stage ' || :i_stage || ' No contemplado. Salimos...',
		        v_log_count,
		        v_idproceso,
		        'info'
		    );
		
		    RETURN;
		
		END IF;

    
        -- p_Datos_Interfaz(v_Interfaz_Proceso);    
        SELECT ACTIVO,ARGUMENTOS INTO v_Interfaz_Activo,v_Argumentos DEFAULT 0,0 FROM EXT.SMM_F_INTERFAZ_ACTIVO(:v_Interfaz_Proceso);
		IF v_Interfaz_Activo = 0 THEN
			o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
		    RETURN;
		END IF;
		
        CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Informes a actualizar  '||v_Argumentos, v_log_count, v_idproceso,'info');
        v_Listado_Informes := v_Argumentos;
       
        if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_POST' then
			-- se deben actualizar los estados de las tablas


			-- SCAWEB_FINAL
			UPDATE EXT.SMM_LIQSCAWEB_FINAL
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(CURRENT_DATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			;

			--SCAWEB_FINAL_WBE
			UPDATE EXT.SMM_LIQSCAWEB_FINAL_WBE
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(CURRENT_DATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and i_processingUnitSeq = v_puseq
			;

			--RAPPELES
			UPDATE EXT.SMM_RAPPELES
			SET CICLO_FACTURACION = to_char(CURRENT_DATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			; 

			--RAPPELES_WBE
			UPDATE EXT.SMM_RAPPELES_WBE
			SET CICLO_FACTURACION = to_char(CURRENT_DATE, 'DD/MM/YYYY')
			WHERE Periodo = i_period
			and i_processingUnitSeq = 38280596832649218
			;
			
			--OCAP 
			UPDATE EXT.SMM_DETALLE_OCAP
			SET ESTADO_CIERRE = 'Cerrado',
			CICLO_FACTURACION = CURRENT_DATE
			WHERE Periodo = i_period
			;
        end if;
     
        if v_Interfaz_Activo <> 1 then
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_log_count, v_idproceso,'info');
            o_salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        else 
            CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_log_count, v_idproceso,'info');
        end if;    
   end if; 

    o_salidacontrol :='Procedure '||v_Interfaz_Proceso||' comenzando';
    
    -- Se comprueba si el periodo Ya ha sido liquidado. 
    -- v_PeriodoLiquidado := f_ComprobarPeriodoLiquidado( i_processingUnitSeq, i_period ,i_periodSeq , tenantId  );
    v_PeriodoLiquidado = EXT.SMM_F_COMPROBAR_PERIODO_LIQUIDADO(i_processingUnitSeq, i_period ,i_periodSeq );
       
    -- SI EL PERIODO NO SE HA LIQUIDADO, SE EXTRAEN DE NUEVO LOS DATOS PARA LOS INFORMES      
    IF  v_PeriodoLiquidado = false THEN
        ------------------------------------------------------------
        -- Datos Generales que se usan en varios informes
        ------------------------------------------------------------
        
 --       -- Volcar datos de las tablas de transacciones a una tabla temporal. Tabla ENEL_TXN_TEMP
        CALL EXT.SMM_SP_TEMPORAL_TXN_TRUNCATE(i_processingUnitSeq, i_period ,i_periodSeq);
	-- 	p_Temporal_Transacciones ( i_processingUnitSeq, i_period ,i_periodSeq , tenantId  );
		
        -- Volcar datos de la tabla de creditos a una tabla temporal. Tabla ENEL_CREDIT_TEMP
        CALL EXT.SMM_SP_TEMPORAL_CREDITOS(i_processingUnitSeq, i_period ,i_periodSeq);
        -- p_Temporal_Creditos ( i_processingUnitSeq, i_period ,i_periodSeq , tenantId  );
        -- Volcar datos de la tabla de incentivos a una tabla temporal. Tabla ENEL_INCEN_TEMP
        CALL EXT.SMM_SP_TEMPORAL_INCENTIVOS(i_processingUnitSeq, i_period ,i_periodSeq);
        -- p_Temporal_Incentivos ( i_processingUnitSeq, i_period ,i_periodSeq , tenantId  );
        -- Volcar datos de la tabla de Depositos a una tabla temporal. Tabla ENEL_DEPOSIT_TEMP
        CALL EXT.SMM_SP_TEMPORAL_DEPOSITOS(i_processingUnitSeq, i_period ,i_periodSeq);
        -- p_Temporal_Depositos ( i_processingUnitSeq, i_period ,i_periodSeq , tenantId  );
        
        CALL EXT.SMM_SP_TEMPORAL_MEDIDAS(i_period ,i_periodSeq);
        -- p_Temporal_Medidas ( i_period ,i_periodSeq , tenantId  );
            
 --       -- Volcar datos de clasificacion a una Temporal de Proveedores. Tabla ENEL_PROVEEDORES_TEMP
		CALL EXT.SMM_SP_TEMPORAL_PROVEEDORES(i_period ,i_periodSeq);
 --       p_Temporal_Proveedores ( i_period ,i_periodSeq , tenantId  );
 --       -- Volcar datos de clasificacion a una Temporal de Equipamientos Tabla ENEL_EQUIPAMIENTO_TEMP        
		CALL EXT.SMM_SP_TEMPORAL_EQUIPAMIENTOS(i_period ,i_periodSeq);
 --       p_Temporal_Equipamientos ( i_period ,i_periodSeq , tenantId  );
 --       -- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PDS_TEMP
		CALL EXT.SMM_SP_TEMPORAL_PDS(i_processingUnitSeq, i_period ,i_periodSeq);
 --       p_Temporal_Pds ( i_processingUnitSeq, i_period ,i_periodSeq , tenantId  );
 --       -- Volcar datos de clasificacion a una Temporal de Operaciones Tabla ENEL_OPERACIONES_TEMP        
		CALL EXT.SMM_SP_TEMPORAL_OPERACIONES(i_period ,i_periodSeq);
 --       p_Temporal_Operaciones ( i_period ,i_periodSeq , tenantId  );   
 --       -- Volcar datos de Productos a una Temporal Tabla ENEL_PRODUCTOS_TEMP   
		CALL EXT.SMM_SP_TEMPORAL_PRODUCTOS(i_period ,i_periodSeq);
 --       p_Temporal_Productos ( i_period ,i_periodSeq , tenantId  );
		
	-- 	-- NUEVA TABLA DE CARGA PARA PREFACTURA	
		CALL EXT.SMM_SP_ENTRADA_TIPO_OPERACION(i_period ,i_periodSeq);
	-- 	p_Entrada_Tipo_Operacion ( i_period, i_periodSeq, tenantId );
    
    	CALL EXT.SMM_SP_TEMPORAL_E4E_NEGATIVOS(i_period ,i_periodSeq);    
 --       p_Temporal_E4E_Negativos ( i_period ,i_periodSeq , tenantId  );
 --       --p_Temporal_E4E_Negativos_TF ( i_period ,i_periodSeq , tenantId  );
		CALL EXT.SMM_SP_REMUN(i_processingUnitSeq, i_period ,i_periodSeq,v_Interfaz_Proceso);
 --       p_REMUN (i_processingUnitSeq, i_period ,i_periodSeq , tenantId , v_Interfaz_Proceso );
        
        
        -- Actualizamos la fecha del informes en la tabla 
        CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'FACOCAPS'); 
        CALL EXT.SMM_SP_CREDITOS_RICORRENTE(i_processingUnitSeq, i_period, i_periodSeq ); --APM 16.12.2024
        CALL EXT.SMM_SP_INFORME_TASA_MORTANDAD( i_processingUnitSeq, i_period ,i_periodSeq , v_Interfaz_Proceso); --APM 09.01.2025
        CALL EXT.SMM_SP_INFORME_ACTIVIDAD_COMERCIAL(  i_processingUnitSeq, i_period,i_periodSeq); --DMS 07.01.2026
            
        ------------------------------------
        -- Datos para INTERFACE ANDROMEDA
        ------------------------------------
        if(i_processingUnit='MENSUAL') then  
        
          CALL EXT.SMM_SP_ECO_FINAL(i_period ,i_periodSeq , i_processingUnitSeq );
         CALL EXT.SMM_SP_RAPPELES(i_period ,i_periodSeq , v_Interfaz_Proceso );
			
			--------------------------------
            -- Datos para Mensual de Liquidacion SCAWEB
            --------------------------------    
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('LIQSCAWEB', v_Listado_Informes) = 1 THEN
                -- Extraer datos para Interface de LIQUIDACION MENSUAL SCAWEB  (Captacion - Importe Base)
              CALL EXT.SMM_SP_INFORME_LIQSCAWEB(i_processingUnitSeq, i_period ,i_periodSeq , v_Interfaz_Proceso );
				
                -- Actualizamos la fecha del informes en la tabla 
                CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'LIQSCAWEB');  
            end if;


            --------------------------------
            -- Datos para INTERFACE E4E
            --------------------------------
            --if v_Listado_Informes = 'E4E' OR v_Listado_Informes = 'ALL' then
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('E4E', v_Listado_Informes) = 1 THEN
                -- Volcar datos de clasificaci?n a una Temporal de Contratos.     Tabla ENEL_E4E_CONTRATOS_TEMP
                CALL EXT.SMM_SP_TEMPORAL_CONTRATOS_E4E ( i_period ,i_periodSeq);
   
                -- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_TEMP
                CALL EXT.SMM_SP_TEMPORAL_DEPOSITOS_E4E ( i_processingUnitSeq, i_period ,i_periodSeq ,v_Interfaz_Proceso  );
    
                -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 1 
                CALL EXT.SMM_SP_FINAL_E4E_1 ( i_period ,i_periodSeq);

                -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 2 
                CALL EXT.SMM_SP_FINAL_E4E_2 ( i_period ,i_periodSeq);
           
                -- Extraer datos de las tablas de E4E    
                -- p_Final_Fichero_E4E ( i_period, tenantId );
            
                -- Actualizamos la fecha del informes en la tabla 
                CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'E4E');
               

                if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_REWARD' THEN  -- v2.4
                    -- Los datos Negativos solo se extraen enel REWARD
                    -- Extraer datos NEGATIVOS de TEMP_Depositos. Tabla: ENEL_E4E_NEGATIVOS
                    CALL EXT.SMM_SP_FINAL_E4E_NEGATIVOS( i_processingUnitSeq, i_period ,i_periodSeq);   
                    -- Actualizamos la fecha del i_informe en la tabla 
                    CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'E4ENEG');
                            
                end if;
     
                -- Generamos datos de resumen de pagos
                CALL EXT.SMM_SP_INFORME_RESUMEN_PAGOS( i_processingUnitSeq, i_period ,i_periodSeq);
            end if;

            ------------------------------------
            -- Datos para INTERFACE SCAWEB
            ------------------------------------
 --if v_Listado_Informes = 'ALL' OR v_Listado_Informes = 'ANDROMEDA' then
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('SCAWEB', v_Listado_Informes) = 1 THEN  
                -- Extraer datos de creditos calculados para el periodo -> Tabla : ENEL_SCAWEB_LIQUIDACION
                CALL EXT.SMM_SP_TEMPORAL_CREDITOS_SCAWEB( i_processingUnitSeq, i_period ,i_periodSeq);       
                -- Actualizamos la fecha del informes en la tabla 
				CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'SCAWEB');	
            end if;
    
            -- Comparativa Pagos solo se hace si se ejecutan todos los informes
            IF v_Listado_Informes = 'ALL' THEN
                CALL EXT.SMM_SP_COMPARATIVA_PAGOS_SCAWEB_E4E( i_processingUnitSeq, i_period ,i_periodSeq);
            end if;        
    
            --------------------------------

            ---------------------------------------------------
            -- Datos para INFORMES GENERAL DE PROVEEDORES
            ---------------------------------------------------    
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('INFGRALPROV', v_Listado_Informes) = 1 THEN
                -- Extraer datos de Transacciones para informes del PDS    
                CALL EXT.SMM_SP_INF_GENERALPROV_DET( i_processingUnitSeq, i_period ,i_periodSeq);
                -- Actualizamos la fecha del informes en la tabla 
                CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'INFGRALPROV');   
            end if;        
            
            ---------------------------------------------------
            -- Datos para FACTURA OCAPS
            ---------------------------------------------------
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('FACOCAPS', v_Listado_Informes) = 1 THEN
                -- Extraer datos de Creditos para detalle de Operaciones de OCAPS    
                CALL EXT.SMM_SP_INF_FACTURA_OCAP_DETALLE( i_processingUnitSeq, i_period ,i_periodSeq);

                -- Extraer datos de Creditos para detalle de Operaciones de OCAPS    
                CALL EXT.SMM_SP_INF_FACTURA_OCAP_TOTAL( i_processingUnitSeq, i_period ,i_periodSeq);

                -- Agrupar datos de detalle de Operaciones de OCAPS  y extraer Datos de Icentivos para resumen de factura  
                CALL EXT.SMM_SP_INF_FACTURA_OCAP_RESUMEN( i_processingUnitSeq, i_period ,i_periodSeq);  
				
				CALL EXT.SMM_SP_INF_FACTURA_OCAP_FINAL( i_processingUnitSeq, i_period,i_periodSeq);
            
				CALL EXT.SMM_SP_INF_DETALLE_OCAP( i_processingUnitSeq, i_period, i_periodSeq, v_Interfaz_Proceso );
                -- Actualizamos la fecha del informes en la tabla 
                CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'FACOCAPS');
            end if;      
        
            ---------------------------------------------------
            -- Datos para FACTURA PDS
            ---------------------------------------------------
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('FACPDS', v_Listado_Informes) = 1 THEN
                -- Extraer datos para detalle de Factura de PDS 
                CALL EXT.SMM_SP_INF_FACTURA_PDS_DETALLE( i_processingUnitSeq, i_period ,i_periodSeq);
                -- Extraer datos para Portada de Factura de PDS 
                CALL EXT.SMM_SP_INF_FACTURA_PDS_PORTADA( i_processingUnitSeq, i_period ,i_periodSeq);
                     
                -- Actualizamos la fecha del informes en la tabla 
                CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'FACPDS');  
            end if;
    
            ---------------------------------------------------
            -- Datos para i_informe Agrupado de liquidaciones
            ---------------------------------------------------
            IF EXT.SMM_F_EXISTE_INFORME_EN_LISTA('LIQ_MENSUAL', v_Listado_Informes) = 1 THEN
				CALL EXT.SMM_SP_INFORME_AGRUPADO(i_processingUnitSeq, i_period ,i_periodSeq , v_Interfaz_Proceso );
				-- Actualizamos la fecha del informes en la tabla 
				CALL EXT.SMM_SP_ACTUALIZA_INFORME_FECHA(i_period, 'LIQ_MENSUAL');
			end if;
        end if;
    
	ELSE
		CALL EXT.LIB_GLOBAL_ENDESA:WRITE_DEBUG (v_tenantid,v_permisos_log, v_proc_name,'Periodo YA Liquidado. NO se actualizan Datos de INFORMES', v_log_count, v_idproceso,'info');
	end if;
	
	/* BOM - DCR - Gestion Control de Informes */
    v_FFin_Inf := CURRENT_TIMESTAMP;
    UPDATE EXT.SMM_CTRL_INFORMES
		SET FECHA_FIN = :v_FFin_Inf,
    		DURACION = SECONDS_BETWEEN(:v_FInicio_Inf, :v_FFin_Inf)
	WHERE NUM_EJECUCION = :v_num_ejecucion
		AND PROCESO = 'RUN';
		
    COMMIT;
/* EOM - DCR - Gestion Control de Informes */
	o_salidacontrol :='Procedure '||v_Interfaz_Proceso||' END';

END;