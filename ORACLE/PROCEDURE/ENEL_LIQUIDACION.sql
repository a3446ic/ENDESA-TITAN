create or replace PACKAGE BODY ENEL_LIQUIDACION as
/* *****************************************************************************
   NAME:       ENEL_LIQUIDACION
   PURPOSE:    Generate Output data for LIQUIDACION interface

   REVISIONS:
   Ver        	Date        	Author           	Description
   ---------  	----------  	---------------  	------------------------------------
   1.0        	06/02/2018  	Marcos Rodellar 	Created this package.
   1.1        	07/11/2019  	RMF             	CAT TVTA Added
   1.2			24/07/2020		Macarena Palacios	Nuevas BU de CES (TF, SP, BP y TVTA)
   1.3          30/09/2022      RMM                 Fix PUs de CES
   1.4          09/11/2022      DCR                 CAL0247 - Generar ficheros E4E para CCDD
   1.5          23/02/2026      APM                 Informar tabla ENEL_PERIODOS_LIQ_PTG - Paquete ENEL_ACTUALIZA_INFORMES_ALICO Body
   
***************************************************************************** */

	v_eot date := to_date('22000101','YYYYMMDD');
	v_contador_debug integer; 
    v_classifierid         		CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION        		CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                		CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA            		CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS        		CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD        		CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO            		CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas number; --Para el DEBUG de los INSERT
   
---------------- Procedimiento para insertar en cs_debug -------------     
procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
	proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;

---------------- Procedimiento para obtener los datos del interfaz de la clasificaci?n-------------     
procedure p_Datos_Interfaz ( iInterfaz IN VARCHAR2)
AS
begin  
	select
		c.classifierid,C.DESCRIPTION,
		gc.Genericattribute1 as STAGE,
		gc.Genericattribute2 as SECUENCIA,
        gc.Genericattribute3 as ARGUMENTOS,
		gc.Genericattribute4 as PERIODICIDAD,
        gc.Genericboolean1 as ACTIVO
    into 
		v_classifierid,         
        v_DESCRIPCION,        
        v_STAGE,                
        v_SECUENCIA,
        v_ARGUMENTOS,    
        v_PERIODICIDAD,
        v_ACTIVO            
	
	from CS_CLASSIFIER c 
		inner join CS_GENERICCLASSIFIER gc 
			on C.CLASSIFIERSEQ=GC.CLASSIFIERSEQ 
			and gc.TENANTID = 'ENEL' 
			and gc.REMOVEDATE  = v_eot  
			and gc.islast=1
		
		inner join CS_CATEGORY_CLASSIFIERS ccc 
			on ccc.CLASSIFIERSEQ = c.CLASSIFIERSEQ 
			and ccc.TENANTID = 'ENEL' 
			and CCC.REMOVEDATE= v_eot and CCC.ISLAST=1
            
		inner join CS_CATEGORYTREE ct 
			on CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ 
			and ct.TENANTID = 'ENEL' 
			and ct.REMOVEDATE= v_eot and ct.ISLAST=1
            
		INNER JOIN CS_GENERICCLASSIFIERTYPE GCT 
			ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
			AND C.TENANTID = 'ENEL' 
			AND C.REMOVEDATE = v_eot
            
	Where 
		CT.NAME='Salida' 
		AND GCT.NAME ='Interfaz'
		and GCT.TENANTID = 'ENEL' 
		and c.classifierid=iInterfaz 
		and c.REMOVEDATE= v_eot 
		and c.ISLAST=1;

	w_debug('Datos del Interfaz en Clasificacion: ',v_contador_debug);
	w_debug('Clasificacion.classifierid: ['||v_classifierid     	||']',v_contador_debug);    
	w_debug('Clasificacion.DESCRIPCION : ['||v_DESCRIPCION       	||']',v_contador_debug);
	w_debug('Clasificacion.STAGE       : ['||v_STAGE               	||']',v_contador_debug);        
	w_debug('Clasificacion.SECUENCIA   : ['||v_SECUENCIA           	||']',v_contador_debug);        
	w_debug('Clasificacion.ARGUMENTOS  : ['||v_ARGUMENTOS          	||']',v_contador_debug);            
	w_debug('Clasificacion.PERIODICIDAD: ['||v_PERIODICIDAD        	||']',v_contador_debug);        
	w_debug('Clasificacion.ACTIVO      : ['||v_ACTIVO              	||']',v_contador_debug);                    
end;

---------------- Procedimiento para iactualizar las fechas del fichero de salida -------------     
procedure p_Actualiza_Fechas ( iPeriodo In VARCHAR2, iProveedorAct IN VARCHAR2,iSecondFileType IN VARCHAR2)
AS
    v_OutputFileName    ODX_CODEMAP_CONFIG.INFA_OUTPUT_FILETYPES_OUTBOUND%TYPE;
    v_Longitud_Fechas    integer;
    v_Longitud_Interfaz    integer;
    v_FechaYYYYMM VARCHAR2(6 CHAR);
begin
	select length('AAAAMM.txt') into v_Longitud_Fechas from dual;
    select length(iProveedorAct||'_') into v_Longitud_Interfaz from dual; -- Donde XXX es el c?digo de proveedor
    
	select 
		replace(INFA_OUTPUT_FILETYPES_OUTBOUND, 
			substr( INFA_OUTPUT_FILETYPES_OUTBOUND, 
			instr(INFA_OUTPUT_FILETYPES_OUTBOUND,iProveedorAct), 
			v_Longitud_Interfaz + v_Longitud_Fechas), 
			iProveedorAct ||'_'||  to_char(sysdate,'YYYYmm')||'.txt' )
    into v_OutputFileName
	from ENELEXT.ODX_CODEMAP_CONFIG 
    where secondary_filetype=iSecondFileType;
  
    update ENELEXT.ODX_CODEMAP_CONFIG 
    set INFA_OUTPUT_FILETYPES_OUTBOUND=v_OutputFileName
    where secondary_filetype=iSecondFileType;  

    commit;
    
    w_debug('Nombre fichero salida actualizado en ODX_CODEMAP_CONFIG.INFA_OUTPUT_FILETYPES_OUTBOUND :'|| v_OutputFileName,  v_contador_debug);   
end;

---------------- Procedimiento principal -------------
PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,salidacontrol out varchar2) IS
  
	v_Interfaz_Proceso  nvarchar2(50);
    v_stagetype     CS_STAGETYPE.name%TYPE;
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
    v_checkCountEstado integer;
    v_FechaYYYYMM VARCHAR2(6 CHAR);
    v_period_liq VARCHAR2(1 CHAR); --RMM 30/09/2022
    v_Existe_per integer; -- RMM 25.10.2022
    V_PERIODSEQ VARCHAR2(100 CHAR) ; -- 25.10.2022
    V_PUSEQ VARCHAR2(100 CHAR) ; -- 25.10.2022
    

begin
	--Iniciamos el contador del Debug
	v_contador_debug := 0;
    v_period_liq := 0; --RMM 30/09/2022
    --RMM - 25.10.2022 - BOM - Asignamos los valores de entrada a variables pq creemos que el problema de CES se debe a esto
    V_PERIODSEQ := periodSeq;
    V_PUSEQ := processingUnitSeq;
    --RMM - 25.10.2022 - EOM - Asignamos los valores de entrada a variables pq creemos que el problema de CES se debe a esto
    salidacontrol :='Procedure LIQUIDACION comenzando';
    w_debug(' Procedure starting...', v_contador_debug);
    w_debug('Argumentos del proceso ',V_CONTADOR_DEBUG);
    w_debug('Argumento: calendar             : ['||calendar           ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: calendarSeq          : ['||calendarSeq        ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: groupid              : ['||groupid            ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: period               : ['||period             ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: periodSeq            : ['||periodSeq          ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: processingUnit       : ['||processingUnit     ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: processingUnitSeq    : ['||processingUnitSeq  ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: stage                : ['||stage              ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: userName             : ['||userName           ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: triggerFilename      : ['||triggerFilename    ||']',V_CONTADOR_DEBUG); 
    w_debug('Argumento: tenantId             : ['||tenantId           ||']',V_CONTADOR_DEBUG); 

    v_Interfaz_Proceso := 'ENEL_Liquidacion_' || upper(processingUnit);  
   
    p_Datos_Interfaz(v_Interfaz_Proceso);
    ----------------------------------------------------------------------------------
    -- Este activo o no el interfaz, borramos las tablas de salida                     --
    -- Esto se hace as? para que el mapping continue y genere un fichero vac?o         --
    -- Al estar esta opci?n: ENELEXT.ODX_CODEMAP_CONFIG.SKIP_EMPTY_OUTPUT='YES'     --
    -- No envia el fichero                                                             --
    
    IF(PROCESSINGUNIT= 'MENSUAL') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_FICHERO_LIQUIDACION', v_contador_debug);
		execute immediate 'truncate table ENELEXT.ENEL_FICHERO_LIQUIDACION';
		w_debug('Fin Truncado de la tablas ENELEXT.ENEL_FICHERO_LIQUIDACION', v_contador_debug);    
    
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQUIDADOS epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;
            
		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period 
            and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ=2251799813685249; 
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQUIDADOS (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, v_Estado, periodSeq, v_FechaYYYYMM );

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQUIDADOS: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    
        -- Actualizamos el nombre del fichero de salida con la fecha del periodo que se liquida
		p_Actualiza_Fechas(period, v_Interfaz_Proceso,'SHPOSPOST');  

		-- Extraer datos de ENEL_PERIODOS_LIQUIDADOS para la tabla del Interfaz de notificacion de Liquidacion. Tabla: ENEL_FICHERO_LIQUIDACION
		INSERT INTO ENELEXT.ENEL_FICHERO_LIQUIDACION (PERIODO, FECHA_LIQUIDACION)
		SELECT 
			--PERIODO,  Se cambia el Nombre del Periodo  por el mes en fomrtao MM/YYYYY
			to_char(to_date(YYYYMM,'YYYYMM'),'MM/YYYY')  as MES_PERIODO, 
			to_char(FECHA_ACTUALIZACION, 'YYYY-MM-DD hh24:mi:ss') 
		FROM ENEL_PERIODOS_LIQUIDADOS 
		WHERE PERIODO = period;

		filas := sql%rowcount;
		COMMIT;
	END IF;
    
    IF(PROCESSINGUNIT= 'MENSUAL TF') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_FICHERO_LIQUIDACION_TF', v_contador_debug);
		execute immediate 'truncate table ENELEXT.ENEL_FICHERO_LIQUIDACION_TF';
		w_debug('Fin Truncado de la tablas ENELEXT.ENEL_FICHERO_LIQUIDACION_TF', v_contador_debug);    
      
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQUIDADOS_TF epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;
            
		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			--WHERE per.PERIODSEQ=periodSeq and PER.REMOVEDATE = v_eot;
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot -- and rownum < 2;
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQUIDADOS_TF (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, v_Estado, periodSeq, v_FechaYYYYMM);-- '201812' );

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQUIDADOS_TF: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    
        -- Actualizamos el nombre del fichero de salida con la fecha del periodo que se liquida
		p_Actualiza_Fechas(period, v_Interfaz_Proceso,'SHPOSTF');  

		-- Extraer datos de ENEL_PERIODOS_LIQUIDADOS para la tabla del Interfaz de notificacion de Liquidacion. Tabla: ENEL_FICHERO_LIQUIDACION
		INSERT INTO ENELEXT.ENEL_FICHERO_LIQUIDACION_TF (PERIODO, FECHA_LIQUIDACION)
		SELECT 
			--PERIODO,  Se cambia el Nombre del Periodo  por el mes en fomrtao MM/YYYYY
			to_char(to_date(YYYYMM,'YYYYMM'),'MM/YYYY')  as MES_PERIODO, 
			to_char(FECHA_ACTUALIZACION, 'YYYY-MM-DD hh24:mi:ss') 
		FROM ENEL_PERIODOS_LIQUIDADOS_TF 
		WHERE PERIODO = period;

		filas := sql%rowcount;
		COMMIT;
    END IF;
    
    IF(PROCESSINGUNIT= 'MENSUAL CAT TVTA') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PER_LIQUIDADOS_CAT_TVTA epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;

		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PER_LIQUIDADOS_CAT_TVTA (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PER_LIQUIDADOS_CAT_TVTA: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    END IF;
	
	-- Nuevas processingunit para CES --
	
	IF(PROCESSINGUNIT= 'B2B CE TF') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
      
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
		--where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq; --RMM 25.10.2022
        where epl.PERIODSEQ = v_periodseq and EPL.PROCESSINGUNITSEQ = v_puseq;  --RMM 25.10.2022
         w_debug('Ya hemos calculado v_checkCountEstado para B2B CE TF ' ||v_checkCountEstado,v_contador_debug ); --RMM 26.09.2022
		IF v_checkCountEstado = 0 THEN 
         
         w_debug('B2B CE TF v_checkCountEstado = '||v_checkCountEstado,v_contador_debug ); --RMM 26.09.2022
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
            w_debug('B2B CE TF  v_FechaYYYYMM '|| v_FechaYYYYMM, v_contador_debug ); --RMM 26.09.2022
			w_debug('Inicio Inserción en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - ' || periodSeq || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' - ' || processingUnit || ' YYYYMM:' || v_FechaYYYYMM || ' estado:' || v_Estado ,v_contador_debug);  
			
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PER_LIQUIDADOS_CES (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION,ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);


			COMMIT;
			w_debug('Se inserta la marca en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF;
        
     
    END IF;
	
	IF(PROCESSINGUNIT= 'B2B CE SP') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
      
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
        SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
		--where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq; --RMM 25.10.2022
        where epl.PERIODSEQ = v_periodseq and EPL.PROCESSINGUNITSEQ = v_puseq;  --RMM 25.10.2022
        w_debug('Ya hemos calculado v_checkCountEstado para B2B CE SP '||v_checkCountEstado ,v_contador_debug ); --RMM 26.09.2022    
		IF v_checkCountEstado = 0 
         or  v_checkCountEstado is null THEN --RMM 26.09.2022
            w_debug('B2B CE SP v_checkCountEstado = '||v_checkCountEstado , v_contador_debug ); --RMM 26.09.2022
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
            w_debug('B2B CE SP  v_FechaYYYYMM '|| v_FechaYYYYMM , v_contador_debug ); --RMM 26.09.2022    
			w_debug('Inicio Inserción en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - ' || periodSeq || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' - ' || processingUnit || ' YYYYMM:' || v_FechaYYYYMM || ' estado:' || v_Estado ,v_contador_debug);  
				
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PER_LIQUIDADOS_CES (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION,ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);


			COMMIT;
			w_debug('Se inserta la marca en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF;
        
       
    END IF;
	
	IF(PROCESSINGUNIT= 'B2B CE BP') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
       
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
        --where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq; --RMM 25.10.2022
        where epl.PERIODSEQ = v_periodseq and EPL.PROCESSINGUNITSEQ = v_puseq;  --RMM 25.10.2022
        w_debug('SELECT count(ESTADO) from ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
		where epl.PERIODSEQ ='||periodseq ||'and EPL.PROCESSINGUNITSEQ='|| processingUnitSeq, v_contador_debug );
        
         w_debug('Ya hemos calculado v_checkCountEstado para B2B CE BP '||v_checkCountEstado , v_contador_debug ); --RMM 26.09.2022        
		IF v_checkCountEstado = 0 
        or  v_checkCountEstado is null THEN --RMM 26.09.2022
            w_debug('B2B CE BP v_checkCountEstado = '||v_checkCountEstado , v_contador_debug ); --RMM 26.09.2022
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
            w_debug('B2B CE BP  v_FechaYYYYMM '|| v_FechaYYYYMM , v_contador_debug ); --RMM 26.09.2022    
            w_debug('Inicio Inserción en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - ' || periodSeq || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' - ' || processingUnit || ' YYYYMM:' || v_FechaYYYYMM || ' estado:' || v_Estado ,v_contador_debug);  
			
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PER_LIQUIDADOS_CES (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION,ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);
            			COMMIT;
			w_debug('Se inserta la marca en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 

   
    END IF;

	
	IF(PROCESSINGUNIT= 'B2B CE TVTA') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
       
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
		--where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq; --RMM 25.10.2022
        where epl.PERIODSEQ = v_periodseq and EPL.PROCESSINGUNITSEQ = v_puseq;  --RMM 25.10.2022
         w_debug('Ya hemos calculado v_checkCountEstado para B2B CE TVTA ',v_checkCountEstado ); --RMM 26.09.2022          
		IF v_checkCountEstado = 0 
         or  v_checkCountEstado is null THEN --RMM 26.09.2022
            w_debug('B2B CE TVTA v_checkCountEstado = ',v_checkCountEstado ); --RMM 26.09.2022
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
            w_debug('B2B CE TVTA  v_FechaYYYYMM ', v_FechaYYYYMM ); --RMM 26.09.2022    
			w_debug('Inicio Inserción en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - ' || periodSeq || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' - ' || processingUnit || ' YYYYMM:' || v_FechaYYYYMM || ' estado:' || v_Estado ,v_contador_debug);  
			
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PER_LIQUIDADOS_CES (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION,ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF;
        
    END IF;
	
	IF(PROCESSINGUNIT= 'B2B CE IS') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
        
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
		--where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq; --RMM 25.10.2022
        where epl.PERIODSEQ = v_periodseq and EPL.PROCESSINGUNITSEQ = v_puseq;  --RMM 25.10.2022
          w_debug('Ya hemos calculado v_checkCountEstado para B2B CE IS ',v_checkCountEstado ); --RMM 26.09.2022      
		IF v_checkCountEstado = 0 
         or  v_checkCountEstado is null THEN --RMM 26.09.2022
            w_debug('B2B CE IS v_checkCountEstado = ',v_checkCountEstado ); --RMM 26.09.2022
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
            w_debug('B2B CE IS  v_FechaYYYYMM ', v_FechaYYYYMM ); --RMM 26.09.2022    
			w_debug('Inicio Inserción en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - ' || periodSeq || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' - ' || processingUnit || ' 	YYYYMM:' || v_FechaYYYYMM || ' estado:' || v_Estado ,v_contador_debug);  
			
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PER_LIQUIDADOS_CES (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION,ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);


			COMMIT;
			w_debug('Se inserta la marca en ENEL_PER_LIQUIDADOS_CES: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
     
    END IF;
	
	-- MPR - Nuevo Canal ALIADOS
	IF(PROCESSINGUNIT= 'ALIADOS') THEN
		--------------- Borrado de las tablas que utilizamos --------------
		w_debug('Inicio Truncado de la tablas ENELEXT.ENEL_FICHERO_LIQ_ALIADOS', v_contador_debug);
		execute immediate 'truncate table ENELEXT.ENEL_FICHERO_LIQ_ALIADOS';
		w_debug('Fin Truncado de la tablas ENELEXT.ENEL_FICHERO_LIQ_ALIADOS', v_contador_debug);    
      
		if v_ACTIVO <> 1 then
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		else 
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		end if;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQ_ALIADOS epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;
            
		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			--WHERE per.PERIODSEQ=periodSeq and PER.REMOVEDATE = v_eot;
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot -- and rownum < 2;
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQ_ALIADOS (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQ_ALIADOS: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    
        -- Actualizamos el nombre del fichero de salida con la fecha del periodo que se liquida
		p_Actualiza_Fechas(period, v_Interfaz_Proceso,'SHPOSTF');  

		-- Extraer datos de ENEL_PERIODOS_LIQUIDADOS para la tabla del Interfaz de notificacion de Liquidacion. Tabla: ENEL_FICHERO_LIQUIDACION
		INSERT INTO ENELEXT.ENEL_FICHERO_LIQ_ALIADOS (PERIODO, FECHA_LIQUIDACION)
		SELECT 
			--PERIODO,  Se cambia el Nombre del Periodo  por el mes en fomrtao MM/YYYYY
			to_char(to_date(YYYYMM,'YYYYMM'),'MM/YYYY')  as MES_PERIODO, 
			to_char(FECHA_ACTUALIZACION, 'YYYY-MM-DD hh24:mi:ss') 
		FROM ENEL_PERIODOS_LIQ_ALIADOS 
		WHERE PERIODO = period;

		filas := sql%rowcount;
		COMMIT;
    END IF;
    
/* BOM - DCR - 09.11.2022 - CAL0247 Generar ficheros E4E para CCDD */
    IF(PROCESSINGUNIT= 'CCDD') THEN
        --------------- Borrado de las tablas que utilizamos --------------
		IF v_ACTIVO <> 1 THEN
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		ELSE
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		END IF;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQ_CCDD epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;

		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQ_CCDD (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQ_CCDD: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    END IF;
/* EOM - DCR - 09.11.2022 - CAL0247 Generar ficheros E4E para CCDD */

/* BOM - APM - 23.02.2026 - Informar tabla ENEL_PERIODOS_LIQ_PTG - Paquete ENEL_ACTUALIZA_INFORMES_ALICO Body */
    IF(PROCESSINGUNIT= 'CAT Emision ALICO PTG') THEN
        --------------- Borrado de las tablas que utilizamos --------------
		IF v_ACTIVO <> 1 THEN
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		ELSE
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		END IF;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQ_PTG epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;

		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQ_PTG (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQ_PTG: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    END IF;

    IF(PROCESSINGUNIT= 'CAT Recepcion PTG') THEN
        --------------- Borrado de las tablas que utilizamos --------------
		IF v_ACTIVO <> 1 THEN
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		ELSE
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		END IF;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQ_PTG epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;

		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQ_PTG (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQ_PTG: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    END IF;
    
    IF(PROCESSINGUNIT= 'CCPP PTG') THEN
        --------------- Borrado de las tablas que utilizamos --------------
		IF v_ACTIVO <> 1 THEN
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		ELSE
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		END IF;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQ_PTG epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;

		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQ_PTG (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQ_PTG: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    END IF;
    
    IF(PROCESSINGUNIT= 'Resellers Online PTG') THEN
        --------------- Borrado de las tablas que utilizamos --------------
		IF v_ACTIVO <> 1 THEN
			w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
			salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
			RETURN;
		ELSE
			w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
		END IF;
    
		-- Se inserta el registro de que el periodo ha sido liquidado
		v_Estado := 'Liquidado';
            
		-- Si no existe, Se inserta la marca de PERIODO LIQUIDADO para evitar que se vuelvan a generar datos para ANDROMEDA de ese periodo
		SELECT count(ESTADO)
		into v_checkCountEstado
		from ENELEXT.ENEL_PERIODOS_LIQ_PTG epl 
		where epl.PERIODO = period and EPL.PROCESSINGUNITSEQ=processingUnitSeq;

		IF v_checkCountEstado = 0 THEN
            SELECT to_char(PER.STARTDATE,'YYYYMM') 
			into v_FechaYYYYMM
			FROM CS_PERIOD PER 
			WHERE PER.NAME= period  and PER.REMOVEDATE = v_eot
            and PER.CALENDARSEQ = 2251799813685249;
                
            -- No existe Periodo Liquidado, se inserta en la tabla
			INSERT INTO ENELEXT.ENEL_PERIODOS_LIQ_PTG (PERIODO,PROCESSINGUNITSEQ, PROCESSINGUNIT, FECHA_ACTUALIZACION, ESTADO, PERIODSEQ, YYYYMM )
			VALUES ( period, processingUnitSeq, processingUnit, sysdate, v_Estado, periodSeq, v_FechaYYYYMM);

			COMMIT;
			w_debug('Se inserta la marca en ENEL_PERIODOS_LIQ_PTG: ' || period || ' - processingUnitSeq: ' || to_char(PROCESSINGUNITSEQ) || ' YYYYMM:' || v_FechaYYYYMM ,v_contador_debug);
		END IF; 
    END IF;
/* EOM - APM - 23.02.2026 - Informar tabla ENEL_PERIODOS_LIQ_PTG - Paquete ENEL_ACTUALIZA_INFORMES_ALICO Body */
    
    w_debug('Fin del proceso.', v_contador_debug);
          
    salidacontrol :='Procedure LIQUIDACION finalizado correctamente.';
    
end;
end;