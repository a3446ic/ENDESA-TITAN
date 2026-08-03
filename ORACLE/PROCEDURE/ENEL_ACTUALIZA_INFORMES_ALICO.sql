create or replace PACKAGE BODY ENEL_ACTUALIZA_INFORMES_ALICO AS

/* *****************************************************************************
	NAME:       ENEL_ACTUALIZA_INFORMES_ALICO
	PURPOSE:

	REVISIONS:
	Ver      		Date        	Author           	Description
	---------  		----------  	---------------  	-----------------------------------											
	1.0				09/10/2024		APM	                Actualizar formato campo VALOR tabla ENEL_TXN_TEMP_RESELLER. Modificar filtro tabla ENEL_INCEN_TEMP_RESELLERS.
    1.1             07/11/2024      APM                 Añadir campo CONCEPTO_LIQ en la tabla ENEL_RAPPELES_ALICO
    1.2             27/01/2025      APM                 Añadir campo NOMBRE_PROVEEDOR en la tabla ENEL_RAPPELES_WBE_ALICO
    1.3             17/02/2025      APM                 Añadir campo TIPO_VENDA en la tabla ENEL_RESUMEN_LIQ_ALICO
    1.4             28/03/2025      APM                 Se añade lógica para Rappeles en la tabla ENEL_CUADRELIQ_CAT_RECEPCION.
    1.5             07/08/2025      APM                 Nueva tabla ENEL_E4E_FINAL_PTG y procedimiento p_Cabecera_Ficheros_E4E
    1.6             17/12/2025      APM                 Tabla ENEL_TDM2_PTG -> Se actualiza de dónde toma el campo CANAL. (po.genericattribute5)
    1.7             09/01/2026      APM                 Se cambia filtro en la tabla ENEL_INCEN_TM2_ALICO - CSI.NAME LIKE '%PTG%TM2%'
    1.8             20/02/2026      APM                 Añadir campo USERID en las siguientes tablas: ENEL_PDS_TEMP_ALICO, ENEL_SCAWEB_LIQUIDACION_PTG ,ENEL_COMP_SCAWEB_E4E_PTG
    1.9             11/03/2026      APM                 Informar tablas para Informe Agrupado de liquidaciones
    1.10            12/03/2026      APM                 Se añde filtro cre.name like 'CD - Captacion Lojas PTG - Ajustes Manuales' en la tabla ENEL_TXN_TEMP_LOJAS
    1.13            16/03/2026      APM                 Se añade filtro OR INCENTMP.NAME LIKE 'C - Captacion Online PTG - Importe Base%' en la tabla ENEL_SCAWEB_LIQUIDACION_PTG
    1.14            21/04/2026      APM                 Actualizar INSERT tabla ENEL_E4E_DEPOSIT_PTG_TEMP en el campo VALUE.
    1.15            29/04/2026      APM                 Se añade filtro en Incentivos de la tabla ENEL_SCAWEB_LIQUIDACION_PTG
    1.16            11/05/2026      APM                 Revertir cambio del día 21/04/2026 (Actualizar INSERT tabla ENEL_E4E_DEPOSIT_PTG_TEMP en el campo VALUE.)    
***************************************************************************** */

-- Definiciones
v_contador_debug integer; 
v_eot date := to_date('22000101','YYYYMMDD');
filas number; --Para el DEBUG de los INSERT
v_finicio timestamp; --APM 07.08.2025
v_contador_ctrl_inf integer; --APM 07.08.2025
v_num_ejecucion integer; --APM 07.08.2025
v_classifierid			CS_CLASSIFIER.classifierid%TYPE;
v_DESCRIPCION			CS_CLASSIFIER.DESCRIPTION%TYPE;
v_STAGE					CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
v_SECUENCIA				CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
v_ARGUMENTOS			CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
v_PERIODICIDAD			CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
v_ACTIVO				CS_GENERICCLASSIFIER.Genericboolean1%TYPE;


--funciones comunes para todo el paquete
function f_fecha_inicio(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT PER.STARTDATE INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
		AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
	return v_Primer_Dia;
end;

function f_Ultimo_Dia_Periodo(iperiodseq varchar2) return date as
    v_Ultimo_Dia date;
begin
    SELECT PER.ENDDATE  - 1 INTO v_Ultimo_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
		AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
	return v_Ultimo_Dia;
end;

function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
	v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin
	-- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
	SELECT count(ESTADO)
		into v_checkCountEstado
	FROM ENELEXT.ENEL_PERIODOS_LIQ_PTG epl 
	WHERE epl.PERIODO = iperiod 
		AND epl.PROCESSINGUNITSEQ=iprocessingUnitSeq;
 
    IF v_checkCountEstado > 0 THEN
        v_liquidado := true;
        w_debug(' Comprobar Estado del Periodo : LIQUIDADO - '||  iperiod ||' Unidad Proceso: '|| to_char(iprocessingUnitSeq) ,  v_contador_debug);
    ELSE
        v_liquidado := false;    
        w_debug(' Comprobar Estado del Periodo : NO Liquidado - '||  iperiod ||' Unidad Proceso: '|| to_char(iprocessingUnitSeq) ,  v_contador_debug);
    END IF;
    
    return v_liquidado;      
end;  

function f_Primer_Dia_Periodo_Siguiente(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT ADD_MONTHS( PER.STARTDATE , 1 ) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
    AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
     return v_Primer_Dia;
end;

-- se comprueba si el informe sobre el que se van a generar los datos pertenece a la lista de informes. Para 'ALL', se devuelve que si existe
function f_ExisteInformeEnLista(iInforme in varchar2, iListaInformes in varchar2 ) return boolean as   
    v_existe BOOLEAN;
begin   
    -- Si lista de INFORMES es 'ALL', se devuelve como que existe siempre
    IF iListaInformes = 'ALL' THEN
        v_existe := true;
    ELSIF INSTR( iListaInformes, iInforme ) > 0 THEN
    -- Si el nombre del informe existe en la lista que se ha pasado como parametro (ejecucion manual), se devuelve que existe (true)   
        v_existe := true;
    ELSE
    -- Si el nombre del informe no existe en la lista que se ha pasado como parametro (ejecucion manual), se devuelve que no existe (false)
        v_existe := false;
    END IF; 

    if v_existe then
        w_debug(' SI ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    else
        w_debug(' NO ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    end if;
    
    return v_existe;
end;

---------------- Procedimiento para obtener los datos del interfaz de la clasificaci?n-------------
procedure p_Datos_Interfaz ( iInterfaz IN VARCHAR2)
AS
begin
	select
		c.classifierid,C.DESCRIPTION,gc.Genericattribute1 as STAGE,gc.Genericattribute2 as SECUENCIA,
		gc.Genericattribute3 as ARGUMENTOS,gc.Genericattribute4 as PERIODICIDAD,
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
			and CCC.REMOVEDATE= v_eot 
			and CCC.ISLAST=1
		inner join CS_CATEGORYTREE ct 
			on CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ 
			and ct.TENANTID = 'ENEL' 
			and ct.REMOVEDATE= v_eot 
			and ct.ISLAST=1
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
		and c.ISLAST=1
	;

	w_debug('Datos del Interfaz en Clasificacion: ',v_contador_debug);
	w_debug('Clasificacion.classifierid: ['||v_classifierid     ||']',v_contador_debug);    
	w_debug('Clasificacion.DESCRIPCION : ['||v_DESCRIPCION         ||']',v_contador_debug);
	w_debug('Clasificacion.STAGE       : ['||v_STAGE               ||']',v_contador_debug);        
	w_debug('Clasificacion.SECUENCIA   : ['||v_SECUENCIA           ||']',v_contador_debug);        
	w_debug('Clasificacion.ARGUMENTOS  : ['||v_ARGUMENTOS          ||']',v_contador_debug);            
	w_debug('Clasificacion.PERIODICIDAD: ['||v_PERIODICIDAD        ||']',v_contador_debug);        
	w_debug('Clasificacion.ACTIVO      : ['||v_ACTIVO              ||']',v_contador_debug);                    
end;

  PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,
  period IN VARCHAR2,periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,
  processingUnitSeq IN VARCHAR2,stage IN VARCHAR2,userName IN VARCHAR2,
  triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,salidacontrol out varchar2,informe varchar2 DEFAULT 'ALL') AS
     v_Listado_Informes  nvarchar2(500);
    v_Interfaz_Proceso  nvarchar2(50); 
    v_PeriodoLiquidado boolean;
  BEGIN
 
  --Iniciamos el contador del Debug
    v_contador_debug := 0;

    w_debug('Procedure starting...', v_contador_debug);
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
    w_debug('Argumento: informe              : ['||informe            ||']',V_CONTADOR_DEBUG);  

   --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    if  triggerFilename = 'EJECUCION_MANUAL' then
        w_debug('Peticion de ejecucion manual con periodo '||period, v_contador_debug);
        w_debug('Informes a actualizar  '||informe, v_contador_debug);
        v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_MANUAL';

        if informe = '' or informe is null then  -- MRA 
            v_Listado_Informes := 'ALL';
            w_debug('Argumento Actualizado : informe : ['||v_Listado_Informes            ||'] (EJECUCION_MANUAL)',V_CONTADOR_DEBUG);
        else
            v_Listado_Informes := informe;
        end if;
    else
        w_debug('Peticion de ejecucion StageHook con periodo '|| period, v_contador_debug);

        CASE stage 
            WHEN 'Reward__'  then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_REWARD';  
            WHEN 'Post__'    then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST_PTG';
            WHEN 'Pay__'     then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_PAY';
            ELSE 
				BEGIN
					w_debug('stage '||stage||' No contemplado. Salimos...', v_contador_debug);
					RETURN;
				END;
        end CASE;
        
        p_Datos_Interfaz(v_Interfaz_Proceso);    
        w_debug('Informes a actualizar  '||v_ARGUMENTOS, v_contador_debug);
        v_Listado_Informes := v_ARGUMENTOS;
		
		if v_ACTIVO <> 1 then
            w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
            salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        else 
            w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
        end if;    
    end if; 
    
    -- Se comprueba si el periodo Ya ha sido liquidado. 
    v_PeriodoLiquidado := f_ComprobarPeriodoLiquidado( processingUnitSeq, period ,periodSeq , tenantId  );

	-- SI EL PERIODO NO SE HA LIQUIDADO, SE EXTRAEN DE NUEVO LOS DATOS PARA LOS INFORMES      
    IF  v_PeriodoLiquidado = false THEN
    -- TAREA: Se necesita implantación para PROCEDURE ENEL_ACTUALIZA_INFORMES_ALICO.RUN
    
        p_Temporal_Transacciones_alico (  processingUnitSeq , period ,periodseq , tenantId , v_Interfaz_Proceso );
        p_Temporal_Creditos (  processingUnitSeq, period, periodseq, tenantId ); --APM 15.05.2023
        
        --Cargamos datos temporales de las tablas de sistema
        p_Temporal_Incentivos (  processingUnitSeq , period ,periodseq , tenantId  );
        p_Temporal_Depositos_PTG ( processingUnitSeq, period, periodseq, tenantId); --APM 24.09.2025
        p_Temporal_Proveedores ( period ,periodseq , tenantId );
        p_Temporal_Pds (processingUnitSeq, period ,periodseq , tenantId  );
        
       --datos para ONLINE
        p_Temporal_Transacciones_online (  processingUnitSeq , period ,periodseq , tenantId , v_Interfaz_Proceso  );
        p_Cuadre_Liq_Online (  processingUnitSeq , period ,periodseq , tenantId , v_Interfaz_Proceso  );
       --datos para Resellers
        p_Temporal_Transacciones_resellers (  processingUnitSeq , period ,periodseq , tenantId , v_Interfaz_Proceso  );
        p_Temporal_Incentivos_resellers (    processingUnitSeq , period ,periodseq , tenantId  );
        p_resellers_TM  (  processingUnitSeq , period , periodseq , tenantId  ); -- Tasa de mortandad
        p_rappeles_alico( period ,periodseq , tenantId  , v_Interfaz_Proceso , processingUnitSeq ); --rappeles
        /* BOM APM 26.06.2023 */
        IF processingUnitSeq = 38280596832650020 THEN --Resellers Online PTG 
        -- Actualizamos la fecha del informe ONLINE_PTG y RESELLERS_PTG en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'RES_ONL_PTG'); 
        END IF;
        /* EOM APM 26.06.2023 */  
       --datos para Stands
        p_Temporal_Transacciones_Stands (  processingUnitSeq , period ,periodseq , tenantId , v_Interfaz_Proceso  );
     --datos para lojas
        p_Temporal_Transacciones_Lojas (  processingUnitSeq , period, periodseq , tenantId , v_Interfaz_Proceso  );      
     --datos para D2D
      IF processingUnitSeq = 38280596832650021 THEN
        p_Temporal_Transacciones_D2D (  processingUnitSeq ,period ,periodseq , tenantId , v_Interfaz_Proceso  );
          END IF;
        p_Temporal_Transacciones_STORES (  processingUnitSeq ,period ,periodseq , tenantId , v_Interfaz_Proceso  );
         p_creditos_ricorrente_stores (  processingUnitSeq ,period ,periodseq , tenantId );
        /* BOM APM 26.06.2023 */
        IF processingUnitSeq = 38280596832650021 THEN --CCPP PTG 
        -- Actualizamos la fecha del informe D2D_PTG y Lojas_PTG en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'CCPP_PTG'); 
        END IF;
        /* EOM APM 26.06.2023 */
        
        p_resumen_liq_alico (  processingUnitSeq , period,periodseq , tenantId , v_Interfaz_Proceso  );
        --rellenar información para informes de resumen liquidativo de resellers y online
         p_resumen_liq_res_onl (  processingUnitSeq , period,periodseq , tenantId , v_Interfaz_Proceso  );
         
         /* BOM APM 15.05.2023 */
        p_Incen_TM2_alico (  processingUnitSeq, period, periodseq , tenantId ); 

        p_Creditos_Incen_alico (  processingUnitSeq, period, periodseq , tenantId, v_Interfaz_Proceso ); 
        p_tdm2_ptg( processingUnitSeq, period,periodseq, tenantId);
        /* BOM APM 26.06.2023 */
        IF processingUnitSeq = 38280596832650019 THEN --CAT Emision ALICO PTG
        -- Actualizamos la fecha del informe CAT_EMI_ALICO_PTG en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'CAT_EMI_ALICO_PTG'); 
        END IF;
        /* EOM APM 26.06.2023 */
        p_Informe_Cuadre_Liq_Cat_Recepcion (  processingUnitSeq, period, periodseq , tenantId, v_Interfaz_Proceso ); 
        /* BOM APM 26.06.2023 */
        IF processingUnitSeq = 38280596832650018 THEN --CAT Recepcion PTG
        -- Actualizamos la fecha del informe CAT_RECEP_PTG en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'CAT_RECEP_PTG'); 
        END IF;
        /* EOM APM 26.06.2023 */
        /* EOM APM 15.05.2023 */

/*BOM 25.09.2025*/
            --------------------------------
            -- Datos para INTERFACE E4E
            --------------------------------
            --if v_Listado_Informes = 'E4E' OR v_Listado_Informes = 'ALL' then
            IF f_ExisteInformeEnLista('E4E', v_Listado_Informes) THEN
                -- Volcar datos de clasificaci?n a una Temporal de Contratos.     Tabla ENEL_E4E_CONTRATOS_PTG_TEMP
                p_Temporal_Contratos_E4E ( period ,periodSeq , tenantId  );
   
                -- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_PTG_TEMP
                p_Temporal_Depositos_E4E_PTG ( processingUnitSeq, period, periodseq, tenantId, v_Interfaz_Proceso);
    
                -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL_PTG Fichero 1 
                p_Final_E4E_1 ( period ,periodSeq , tenantId,processingUnitSeq  );

                -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 2 
                p_Final_E4E_2 ( period ,periodSeq , tenantId,processingUnitSeq  );
                
                p_Temporal_E4E_Negativos ( period,periodseq,tenantId );
           
                -- Extraer datos de las tablas de E4E    
                -- p_Final_Fichero_E4E ( period, tenantId );
            
                -- Actualizamos la fecha del informes en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'E4E');

                if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_REWARD' THEN  -- v2.4
                    -- Los datos Negativos solo se extraen enel REWARD
                    -- Extraer datos NEGATIVOS de TEMP_Depositos. Tabla: ENEL_E4E_NEGATIVOS
                    p_Final_E4E_Negativos ( processingUnitSeq, period ,periodSeq , tenantId  );   
                    -- Actualizamos la fecha del informe en la tabla 
                    p_Actualiza_Informe_Fecha ( period, 'E4ENEG');          
                end if;
     
                -- Generamos datos de resumen de pagos
                --p_Informe_Resumen_Pagos( processingUnitSeq, period ,periodSeq , tenantId  );
            end if;
            
            IF f_ExisteInformeEnLista('SCAWEB', v_Listado_Informes) THEN
                -- Extraer datos de creditos calculados para el periodo -> Tabla : ENEL_SCAWEB_LIQUIDACION   
                p_Temporal_Creditos_Scaweb ( processingUnitSeq, period ,periodSeq , tenantId  );    
                -- Actualizamos la fecha del informes en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'SCAWEB_TF');      
            end if;
            -- Comparativa Pagos solo se hace si se ejecutan todos los informes
            IF v_Listado_Informes = 'ALL' THEN
                p_Comparativa_Pagos_SCAWEB_E4E ( processingUnitSeq, period ,periodSeq , tenantId  );
                p_Actualiza_Informe_Fecha ( period, 'SCAWEB_E4E_PTG');
            end if;   
/*BOM 25.09.2025*/
--BOM APM 11.03.2026
            ---------------------------------------------------
            -- Datos para Informe Agrupado de liquidaciones
            ---------------------------------------------------
            /*p_informe_agrupado (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
            IF processingUnitSeq = 38280596832650019  THEN --CAT Emision ALICO PTG
				-- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_CAT_EMISION_ALICO_PTG');    
            ELSIF processingUnitSeq = 38280596832650018  THEN --CAT Recepcion PTG
				-- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_CAT_RECEPCION_PTG');   
            ELSIF processingUnitSeq = 38280596832650020  THEN --Resellers Online PTG
				-- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_RESELLERS_ONLINE_PTG'); 
            ELSIF processingUnitSeq = 38280596832650021  THEN --CCPP PTG
				-- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_CCPP_PTG'); 
			end if;*/
--EOM APM 11.03.2026

    ELSE
        w_debug('Periodo YA Liquidado. NO se actualizan Datos de INFORMES', v_contador_debug);
	end if;
     w_debug('Procedure END', v_contador_debug);
    salidacontrol :='Procedure '||v_Interfaz_Proceso||' END';

    COMMIT;    
    NULL;
  END RUN;


procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
	proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;


----------------- f_CodigoMes -----------------------------------------------------------------------

function f_CodigoMes(idate date) return varchar2 as
    v_CodigoMes varchar2(1);
begin
    -- Se extrae un codigo de mes de modo que Enero es A , Febrero B .... hasta Diciembre que es L
    -- ASCII('A') = 65  y ASCII('L') = 76
    -- Metodo:
    --  Se extrae numero de mes: extract(month from idate) 
    --  Se suma 64 y ese codigo ascci se convierte a caracter con chr
  
    SELECT chr(extract(month from idate) + 64)
    INTO  v_CodigoMes
    FROM DUAL;  
      
    return v_CodigoMes;
end;  
-- EXtraer el codigo del mes : Enero: A, Febrero:B .... Diciembre:L




/*BOM APM 07.08.2025*/
procedure z_ctrl_inf ( valor IN Number, num_ejecucion IN number, proceso IN VARCHAR2, finicio IN timestamp, ffin IN timestamp, mensaje IN VARCHAR2)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG

begin     

    INSERT INTO enelext.enel_ctrl_informes (id, num_ejecucion, paquete, proceso, fecha_inicio, fecha_fin, mensaje, duracion) 
        VALUES (valor, v_num_ejecucion, proc_name, proceso, finicio, ffin , mensaje, extract(day from (ffin - finicio)*86400));
    v_contador_ctrl_inf := v_contador_ctrl_inf +1;
    commit;

end;
/*EOM APM 07.08.2025*/

procedure p_Temporal_Transacciones_alico (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_ALICO_V2.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP_ALICO_V2';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_ALICO_V2.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP_ALICO_V2. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Carga Créditos en la tabla ENEL_TXN_TEMP_ALICO_V2.', v_contador_debug); --APM 17.03.2023
    
    if (iprocessingUnitSeq = 38280596832650018 or iprocessingUnitSeq = 38280596832650019) then 
    
	INSERT INTO ENELEXT.ENEL_TXN_TEMP_ALICO_V2( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT,
                                             BUSINESSUNITMAP, EVENTTYPESEQ,UNIDADES, --APM 15.05.2023
                                             NOMBRE_PROVEEDOR ) --APM 04.07.2023
                                       
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla credito
        cre.value,--valor crdito
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE22 as Nombre_Servicio, -- tipo venta --DMS 27.06.2023 CAMBIO DE GA1 A GA22
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        TXN.BUSINESSUNITMAP AS BUSINESSUNITMAP, --APM 15.05.2023
        TXN.EVENTTYPESEQ AS EVENTTYPESEQ, --APM 15.05.2023
         'EURO' as UNIDAD,
        par.lastname as NOMBRE_PROVEEDOR --APM 04.07.2023 
          
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
        INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
			
         --       INNER JOIN CS_participant   pa  ON pa.payeeseq  = CRE.payeeseq 
      --      AND  txn.tenantid = 'ENEL'

		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        inner join cs_period per on per.periodseq = iperiodseq  
            AND CRE.PERIODSEQ=PER.PERIODSEQ AND per.REMOVEDATE = v_eot
            
        inner join cs_position po   ON po.payeeseq  = CRE.payeeseq 
            and po.RULEELEMENTOWNERSEQ = CRE.positionseq and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant   par  ON par.payeeseq  = po.payeeseq 
                AND  CRE.tenantid = txn.tenantid
                AND par.REMOVEDATE = v_eot
                AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
                AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1

        inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq 
            and txn.businessunitmap=bu.mask

        WHERE -- ( etype.eventtypeid Like '%ALICO%' OR  etype.eventtypeid Like '%Alico%' )
            --BU.NAME LIKE '%CAT%PTG' OR BU.NAME LIKE 'ALICO PTG'
            per.periodseq=iperiodseq
	
	;

    filas := sql%rowcount;
    COMMIT;
--BOM APM 17.03.2023
    w_debug('Fin Carga Créditos de la tabla ENEL_TXN_TEMP_ALICO_V2: '|| to_char(filas) || ' filas.', v_contador_debug);
    
 /*    w_debug('Carga Incentivos en la tabla ENEL_TXN_TEMP_ALICO_V2.', v_contador_debug);
--EOM APM 17.03.2023   

   INSERT INTO ENELEXT.ENEL_TXN_TEMP_ALICO_V2( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT,
                                             BUSINESSUNITMAP, EVENTTYPESEQ,UNIDADES, --APM 15.05.2023
                                             NOMBRE_PROVEEDOR ) --APM 04.07.2023
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        inc.name,--regla credito
        inc.value,--valor crdito
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        inc.GENERICATTRIBUTE16,--proveedor
        inc.GENERICATTRIBUTE1,-- num proveedor 
        inc.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  inc.value is null or inc.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and inc.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        TXN.BUSINESSUNITMAP AS BUSINESSUNITMAP, --APM 15.05.2023
        TXN.EVENTTYPESEQ AS EVENTTYPESEQ, --APM 15.05.2023
        'EURO' as UNIDAD,
        par.lastname as NOMBRE_PROVEEDOR --APM 04.07.2023 
       
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
      			
		-- INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
       --     AND  txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = txn.PROCESSINGUNITSEQ
            
       INNER JOIN ENEL_INCEN_TEMP_ALICO inc    ON --INC.PAYEESEQ = CRE.PAYEESEQ
            --AND INC.POSITIONSEQ = CRE.POSITIONSEQ AND
            inc.PROCESSINGUNITSEQ  = txn.PROCESSINGUNITSEQ
            AND  txn.tenantid = itenantId
            and txn.pipelinerunseq=inc.pipelinerunseq
            
        
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        inner join cs_period per on per.periodseq = iperiodseq  
            AND per.REMOVEDATE = v_eot AND PER.PERIODSEQ=INC.PERIODSEQ
            
        inner join cs_position po   ON po.payeeseq  = inc.payeeseq  and po.RULEELEMENTOWNERSEQ = inc.positionseq and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant   par  ON par.payeeseq  = po.payeeseq 
            AND  inc.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
                  
        inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq 
            and INC.businessunitmap=bu.mask

        WHERE -- ( etype.eventtypeid Like '%ALICO%' OR  etype.eventtypeid Like '%Alico%' )
            --BU.NAME LIKE '%CAT%PTG%' OR BU.NAME LIKE 'ALICO PTG'
             per.periodseq=iperiodseq
            AND inc.GENERICATTRIBUTE1 IS NOT NULL 
            AND inc.GENERICBOOLEAN1 = 1 -- true
	;

    filas := sql%rowcount;
    COMMIT;

--BOM APM 17.03.2023
-- Old Code
    --w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_ALICO_V2: '|| to_char(filas) || ' filas.', v_contador_debug);
-- New Code      
    w_debug('Fin Carga Incentivos de la tabla ENEL_TXN_TEMP_ALICO_V2: '|| to_char(filas) || ' filas.', v_contador_debug); */     
--EOM APM 17.03.2023
w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_ALICO.', v_contador_debug);
     BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_TXN_TEMP_ALICO WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_ALICO.', v_contador_debug);
/* BOM DCR 26.09.2023 */
     w_debug('Inicio Carga de la tabla ENEL_TXN_TEMP_ALICO.', v_contador_debug); 
     INSERT INTO ENELEXT.ENEL_TXN_TEMP_ALICO( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             ESTADO, FECHA_ALTA, TIPO_EVENTO, PROCESSINGUNITSEQ, BUSINESSUNIT, BUSINESSUNITMAP, 
                                             EVENTTYPESEQ, VALOR)
                                       
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE22 as Nombre_Servicio, -- tipo venta --DMS 27.06.2023 CAMBIO DE GA1 A GA22
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        TXN.BUSINESSUNITMAP AS BUSINESSUNITMAP, --APM 15.05.2023
        TXN.EVENTTYPESEQ AS EVENTTYPESEQ,
        0
          
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid

		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        -- Se hace el LEFT JOIN sobre una subquery de CS_TRANSACTIONADDRESS con un INNER JOIN con el Tipo de ADdress "BILLTO" por que si no las TXN sin dirección se pierden o se pueden duplicar las que si tienen otros tipos  
		LEFT JOIN  
			(Select * FROM  CS_TRANSACTIONADDRESS txnaddress 
				INNER JOIN  CS_ADDRESSTYPE addtype
					ON txnaddress.ADDRESSTYPESEQ = ADDTYPE.ADDRESSTYPESEQ
					AND ADDTYPE.ADDRESSTYPEID ='BILLTO' 
			) TXNADD
			ON txn.SALESTRANSACTIONSEQ  = TXNADD.SALESTRANSACTIONSEQ   
			AND txn.processingunitseq = txnadd.processingunitseq
			AND txnadd.tenantid = txn.tenantid
			AND txn.compensationdate = txnadd.compensationdate
                                               
		LEFT JOIN CS_TRANSACTIONASSIGNMENT txnass
			ON txn.SALESTRANSACTIONSEQ  = txnass.SALESTRANSACTIONSEQ   
			AND txn.processingunitseq = txnass.processingunitseq
			AND txnass.tenantid = txn.tenantid
			AND txn.compensationdate = txnass.compensationdate
			AND txnass.setnumber > 0
        
        inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq 
            and txn.businessunitmap=bu.mask
	
	;

    filas := sql%rowcount;
    COMMIT;
     w_debug('Inicio Carga de la tabla ENEL_TXN_TEMP_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug); 
/* EOM DCR 26.09.2023 */
end if;

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_ALICO_V2 COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_ALICO_V2.',v_contador_debug);
end;

--Rappeles
procedure p_rappeles_alico( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , iInterfaz IN VARCHAR2, iprocessingUnitSeq IN VARCHAR2)
as
    v_txtFechaLiquidacion VARCHAR2(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_RAPPELES_ALICO.', v_contador_debug);
    BEGIN
        LOOP
            /* BOM APM 15.05.2023 - Código antiguo */
            --DELETE FROM ENELEXT.ENEL_RAPPELES_ALICO WHERE periodo = iperiod and ROWNUM <= 10000;
            --Código nuevo
            DELETE FROM ENELEXT.ENEL_RAPPELES_ALICO WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
             /* EOM APM 15.05.2023 */
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
--BOM APM 20.06.2023   
        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_WBE_ALICO WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP; 
--EOM APM 20.06.2023           
    END;
    
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    w_debug('Fin Borrado de la tabla ENEL_RAPPELES_ALICO.', v_contador_debug);

    w_debug('Insertando datos en tabla ENEL_RAPPELES_ALICO.' ,  v_contador_debug);
    
  INSERT INTO ENELEXT.ENEL_RAPPELES_ALICO(PERIODO, NAME, objetivo, realizado, porc_tm2, importe_unitario, importe, proveedor,
                                         BUSINESSUNIT, PROCESSINGUNITSEQ, --APM 24.04.2023
                                         UNIDAD_UNITARIO, UNIDAD, DESCRIPCION_PROVEEDOR,escalon, --APM 27.06.2023
                                         CONCEPTO_LIQ,DESCRIPCION_POSICION) --APM 07.11.2024
    
    
    SELECT 
		csi.periodo,
        CSI.NAME,
        --CSI.GENERICATTRIBUTE3 as LINEA_NEGOCIO, --linea negocio  
        --cre.GENERICATTRIBUTE4, -- codigo alico
        CSI.GENERICNUMBER1 as OBJETIVO, 
        CSI.GENERICNUMBER2 as REALIZADO,
        CSI.GENERICNUMBER3 as porc_tm2, --APM 29.06.2022
        CSI.GENERICNUMBER5 as Importe_unitario, --APM 29.06.2022
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) AS IMPORTE,
        POS.NAME as proveedor,
        --TXN.PRODUCTID as Producto,  --producto
        --CSI.GENERICNUMBER5 as escalon
        BU.NAME AS BUSINESSUNIT, --APM 24.04.2023
        iprocessingUnitSeq, --APM 24.04.2023
        --BOM APM 27.06.2023
        'EURO' as UNIDAD_UNITARIO,
        'EURO' as UNIDAD,
        --EOM APM 27.06.2023
        PAR.LASTNAME AS DESCRIPCION_PROVEEDOR,
        csi.genericattribute3 as escalon,
        csi.genericattribute1 as CONCEPTO_LIQ,
        POS.GENERICATTRIBUTE5 AS DESCRIPCION_POSICION
        
    FROM ENEL_INCEN_TEMP_ALICO CSI --CS_INCENTIVE CSI
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = csi.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
        INNER JOIN CS_POSITION POS
            ON CSI.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND CSI.PAYEESEQ = POS.PAYEESEQ
            AND POS.REMOVEDATE = '01/01/2200'
            AND POS.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND POS.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        
         /*BOM APM 24.04.2023*/
         Inner join cs_businessunit bu  
            on CSI.PROCESSINGUNITSEQ = bu.processingunitseq 
            and CSI.businessunitmap = bu.mask
        /*EOM APM 24.04.2023*/
        INNER JOIN CS_participant par
        /*BOM APM 20.09.2023*/
        --Old Code 
            --ON par.payeeseq  = CSI.payeeseq 
        --New Code    
            on par.payeeseq  = pos.payeeseq 
        /*EOM APM 20.09.2023*/
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        /*BOM APM 20.09.2023*/ -- New Code
        INNER JOIN CS_PAYEE payee ON PAR.PAYEESEQ = PAYEE.PAYEESEQ
            AND PAYEE.REMOVEDATE =  v_eot
            --AND PAYEE.ISLAST =1   -- Con esta condicion no se quedaba con la version correcta asociada al fichero
            AND PAYEE.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAYEE.EFFECTIVEENDDATE >= PER.ENDDATE - 1   
            AND payee.TENANTID = itenantId
        /*EOM APM 20.09.2023*/
      WHERE 
		per.periodseq = iperiodseq 
		and ( 
        CSI.NAME LIKE '%Rappel%' 
        OR CSI.NAME LIKE '%PTG%TM2%'
        OR CSI.NAME LIKE '%PTG%TM12%'
           )
        /*BOM APM 24.04.2023*/
        AND CSI.GENERICATTRIBUTE1 IS NOT NULL 
        AND CSI.GENERICBOOLEAN1 = 1 -- true
        /*EOM APM 24.04.2023*/
       -- and csi.value<>0
		; 




    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_RAPPELES_ALICO - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Carga de la tabla ENEL_RAPPELES_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RAPPELES_ALICO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_ALICO.',v_contador_debug);
  
--BOM APM 20.06.2023      
  INSERT INTO ENELEXT.ENEL_RAPPELES_WBE_ALICO(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, subcanal, wbe, PROCESSINGUNITSEQ,
                                              NOMBRE_PROVEEDOR)
    SELECT 
        iperiod,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        CSI.GENERICATTRIBUTE1,
        CSI.GENERICATTRIBUTE4,
        TMP_PDS.subcanal,
        CSI.GENERICATTRIBUTE7 wbe,
        iprocessingUnitSeq,
        CSI.GENERICATTRIBUTE3 AS NOMBRE_PROVEEDOR --APM 27.01.2025
	
	FROM ENEL_INCEN_TEMP_ALICO CSI --CS_INCENTIVE CSI
        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
          
        INNER JOIN ENEL_PDS_TEMP_ALICO CSP --CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
    
		LEFT JOIN ENEL_PDS_TEMP_ALICO  TMP_PDS
			on CSI.payeeseq=TMP_PDS.payeeseq 
			and CSI.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and CSI.periodseq=TMP_PDS.periodseq
		
    WHERE 
		CSI.periodseq = iperiodseq 
		and (CSI.NAME LIKE 'I - Captacion CAT Emision PTG - Rappel por Objetivos' 
          OR CSI.NAME LIKE 'I - Captacion Stores PTG - Ricorrente -%') --APM 27.01.2025
		and csi.value<>0
    ;
    
    filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_RAPPELES_WBE_ALICO - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RAPPELES_WBE_ALICO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_WBE_ALICO.',v_contador_debug);
--EOM APM 20.06.2023      
end;


---------- Tabla ENEL_INCEN_TEMP ----
procedure p_Temporal_Incentivos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP_ALICO.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP_ALICO';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP_ALICO.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP_ALICO. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_INCEN_TEMP_ALICO( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
												GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE16, 
												GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
												GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2,GENERICATTRIBUTE7,
                                                BUSINESSUNITMAP, PROCESSINGUNITSEQ) --APM 24.04.2023
	SELECT 
		incent.TENANTID,
		incent.PERIODSEQ,
		iperiod PERIODO,
		incent.PIPELINERUNSEQ,
		incent.PIPELINERUNDATE,
		incent.INCENTIVESEQ,
		incent.PAYEESEQ,
		incent.POSITIONSEQ,
		incent.NAME,
		incent.VALUE,					--Importe Incentivo
		incent.GENERICATTRIBUTE1,		-- Concepto Liquidación
		incent.GENERICATTRIBUTE2,		-- Proveedor
		incent.GENERICATTRIBUTE3,		-- Descripción
		incent.GENERICATTRIBUTE4,		-- Tramo                     
		incent.GENERICATTRIBUTE16,		-- Nombre Cuota
		incent.GENERICNUMBER1,			-- Objetivo
		incent.GENERICNUMBER2,			-- Realizado
		incent.GENERICNUMBER3,			-- % Consecucion
		incent.GENERICNUMBER4,			-- Tarifa
		incent.GENERICNUMBER5,			-- Importe unitario
		incent.GENERICNUMBER6,			-- Target Incentive
		incent.GENERICBOOLEAN1,	
		incent.GENERICDATE1,			--Fecha Inicio
		incent.GENERICDATE2,			--Fecha Final
		incent.GENERICATTRIBUTE7,		-- WBE
        /*BOM APM 24.04.2023*/
        incent.BUSINESSUNITMAP, 
        incent.PROCESSINGUNITSEQ
        /*EOM APM 24.04.2023*/

	FROM CS_INCENTIVE incent

	WHERE
		incent.TENANTID = itenantId 
		AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND incent.PERIODSEQ =  iperiodseq
		and incent.genericattribute1 is not null;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INCEN_TEMP_ALICO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP_ALICO.',v_contador_debug);
        
end;   

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----
procedure p_Temporal_Proveedores ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP_ALICO.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP_ALICO.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP_ALICO. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
	INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO, CECO, WBE_FINAL_IMPUTACION, DETALLE_ACTIVIDAD, ACTIVIDAD,
													SOCIEDAD, CENTRO_LOGISTICO,GR_COMPRAS,TIPO_PAGO, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, SUBACTIVIDAD)
	SELECT 
		itenantId TENANTID,
		iperiodseq PERIDOSEQ,
		C.CLASSIFIERID IDPROVEEDOR,
		C.NAME DESCRIPCION,
		GC.GENERICATTRIBUTE8 DESCRIPCION_CORTA,
		C.DESCRIPTION FICHERO,
		GC.GENERICATTRIBUTE1 CECO,
		GC.GENERICATTRIBUTE2 WBE_FINAL_IMPUTACION,
		GC.GENERICATTRIBUTE3 DETALLE_ACTIVIDAD,
		GC.GENERICATTRIBUTE4 ACTIVIDAD,
		GC.GENERICATTRIBUTE5 SOCIEDAD,
		GC.GENERICATTRIBUTE6 CENTRO_LOGISTICO, 
		GC.GENERICATTRIBUTE7 GR_COMPRAS,
		GC.GENERICATTRIBUTE8 TIPO_PAGO,  -- Nuevo v2.0  
		GC.GENERICATTRIBUTE9 ORG_VENTAS, -- Nuevo v2.0            
		C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
		C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
		GC.GENERICATTRIBUTE10
	
	FROM CS_GENERICCLASSIFIERTYPE GCT
		INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
			AND C.TENANTID = itenantId 
			AND C.REMOVEDATE = v_eot
			AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
			--AND C.ISLAST = 1
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
			--AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
			--AND GC.ISLAST = 1
	
	WHERE GCT.NAME  like 'Proveedor%'
		AND GC.GENERICATTRIBUTE4 not like '%TELEVENTA'
	;
    
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO.',v_contador_debug);
end;



procedure p_Temporal_Pds (iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS  
begin
    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP_ALICO.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP_ALICO';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP_ALICO.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PDS_TEMP_ALICO. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PDS_TEMP_ALICO( PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
											PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, NOMBRE_COMERCIAL, IMPORTE_UB, FECHA_CONTRATACION, 
											TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
											BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION, USERID)
	SELECT 
		PER.PERIODSEQ, 
		POS.RULEELEMENTOWNERSEQ, 
		PAR.PAYEESEQ,
		PAYEE.PAYEEID, 
		POS.NAME PDS, 
		PAR.LASTNAME NOMBRE_FISCAL,
		PAR.GENERICATTRIBUTE1 AS CIF,
		PAR.GENERICATTRIBUTE2 AS NOMBRE_CUENTA,
		PAR.GENERICATTRIBUTE3 AS CALLE,
		PAR.GENERICATTRIBUTE4 AS COD_POSTAL,
		PAR.GENERICATTRIBUTE5 AS PROVINCIA,
		PAR.GENERICATTRIBUTE6 AS POBLACION,
		PAR.GENERICATTRIBUTE7 AS TIPO_IMPOSITIVO,
		PAR.GENERICATTRIBUTE8 AS CODIGOE4E,  -- PAR_PROVEEDOR
		PAR.GENERICATTRIBUTE9 AS CODIGODEUDOR,                   
		PAR.GENERICATTRIBUTE10 AS NOMBRE_COMERCIAL,
		PAR.GENERICNUMBER1 AS IMPORTE_UB,
		PAR.GENERICDATE1 AS FECHA_CONTRATACION,
		POS.GENERICATTRIBUTE1 AS TIPO_PRESTADOR,
		POS.GENERICATTRIBUTE2 AS COMUNIDAD_AUTONOMA,
		POS.GENERICATTRIBUTE3 AS TERRITORIO,
		POS.GENERICATTRIBUTE4 AS ZONA,
		POS.GENERICATTRIBUTE5 AS POS_NOMBRE_COMERCIAL,
		POS.GENERICATTRIBUTE6 AS CANAL,
		POS.GENERICATTRIBUTE7 AS SUBCANAL,
		POS.GENERICATTRIBUTE8 AS DELEGACION,
		POS.GENERICATTRIBUTE10 AS BASE_COMISION,
		POS.EFFECTIVESTARTDATE,    -- Fecha inicio de vigencia 
		PAR.TERMINATIONDATE  AS TERMINATIONDATE,
		TIT.NAME  AS TITLE_NAME,
		TIT.GENERICATTRIBUTE1 AS CANAL_CALCULOS,
		TIT.GENERICATTRIBUTE2 AS TIPO_POSICION,
        PAR.USERID AS USERID --APM 20.02.2026

	FROM CS_PERIOD per
		JOIN  CS_POSITION pos 
			ON  pos.REMOVEDATE = v_eot
			AND pos.TENANTID = itenantId 
			AND pos.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND pos.EFFECTIVEENDDATE >= PER.ENDDATE - 1
			-- and POS.ISLAST = 1   -- Con esta condición no se quedaba con la versión correcta asociada al fichero
			and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq
			  
		INNER JOIN CS_PARTICIPANT par 
			ON POS.PAYEESEQ = PAR.PAYEESEQ
			AND par.TENANTID = itenantId
			AND par.REMOVEDATE = v_eot
			AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
			--and PAR.ISLAST = 1 -- Con esta condición no se quedaba con la versión correcta asociada al fichero

		INNER JOIN CS_PAYEE payee 
			ON PAR.PAYEESEQ = PAYEE.PAYEESEQ
			AND PAYEE.REMOVEDATE =  v_eot
			--AND PAYEE.ISLAST =1   -- Con esta condición no se quedaba con la versión correcta asociada al fichero
			AND PAYEE.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND PAYEE.EFFECTIVEENDDATE >= PER.ENDDATE - 1        

		INNER JOIN CS_TITLE tit 
			ON POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
			AND TIT.REMOVEDATE = v_eot
			AND TIT.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND TIT.EFFECTIVEENDDATE >= PER.ENDDATE - 1
				
	WHERE
		per.REMOVEDATE = v_eot
		AND per.PERIODSEQ = iperiodseq
		and par.GENERICATTRIBUTE1 is not null
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PDS_TEMP_ALICO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP_ALICO.',v_contador_debug);
end;





 procedure p_Temporal_Transacciones_online (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2  , iInterfaz IN VARCHAR2 )

AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_ONLINE.', v_contador_debug);     
    DELETE FROM ENELEXT.ENEL_TXN_TEMP_ONLINE WHERE PERIODO = iperiod ;      
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_ONLINE.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP_ONLINE. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);
    w_debug('FECHA Inicio:'|| v_periodstartdate ,  v_contador_debug);
    w_debug('FECHA Fin:'|| v_periodenddate ,  v_contador_debug);

    w_debug('Carga Créditos en la tabla ENEL_TXN_TEMP_ONLINE.', v_contador_debug); --APM 15.05.2023
    
	INSERT INTO ENELEXT.ENEL_TXN_TEMP_ONLINE( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT , TASA_CONV,
                                             BUSINESSUNITMAP, EVENTTYPESEQ,UNIDADES, --APM 15.05.2023
                                             PARTICIPANTE) --APM 13.09.2023
    
                                                
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla
        cre.value,--valor 
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        --cre.GENERICATTRIBUTE2,--proveedor
       -- cre.GENERICATTRIBUTE1,-- num proveedor 
       
        PO.NAME as proveedor, -- prov
		PAR.LASTNAME as num_prov,  -- num proveedor 

        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        cre.GENERICNUMBER1, -- TASA CONVERSION
        TXN.BUSINESSUNITMAP AS BUSINESSUNITMAP, --APM 15.05.2023
        TXN.EVENTTYPESEQ AS EVENTTYPESEQ, --APM 15.05.2023
        'EURO' as UNIDAD, --DMS 27.06.2023
      -- inc.name, -- regla incentivo
      --  inc.value -- valor incentivo
         PAR.LASTNAME as participante --APM 13.09.2023         
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			--AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
            and cre.compensationdate=txn.compensationdate
			
         --       INNER JOIN CS_participant   pa  ON pa.payeeseq  = CRE.payeeseq 
      --      AND  txn.tenantid = 'ENEL'

		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        inner join cs_period per 
            on per.periodseq = iperiodseq 
            AND CRE.PERIODSEQ=PER.PERIODSEQ --APM 15.05.2023
            AND per.REMOVEDATE = v_eot
            
        inner join cs_position po   
            ON po.payeeseq  = CRE.payeeseq              and po.RULEELEMENTOWNERSEQ = CRE.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant   par  
            ON par.payeeseq  = po.payeeseq 
            AND  CRE.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
            and txn.businessunitmap = bu.mask --APM 15.05.2023
            
        WHERE 
--BOM APM 15.05.2023
--Old Code
        --TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq  and
--EOM APM 15.05.2023        
            cre.PERIODSEQ = iperiodseq 
            and BU.NAME LIKE 'Online PTG'
			--and cre.name like '%Importe Base%' --'%Ajustes Manuales%' --APM 13.09.2023
	;

    filas := sql%rowcount;
    COMMIT;
--BOM APM 15.05.2023
    w_debug('Fin Carga Créditos de la tabla ENEL_TXN_TEMP_ONLINE: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Carga Incentivos en la tabla ENEL_TXN_TEMP_ONLINE.', v_contador_debug);
--EOM APM 15.05.2023       
    --incentivos
    INSERT INTO ENELEXT.ENEL_TXN_TEMP_ONLINE( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT , TASA_CONV,
                                             BUSINESSUNITMAP, EVENTTYPESEQ) --APM 15.05.2023
--BOM APM 17.03.2023
--Old Code                                             
   /*SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        inc.name,--regla
        inc.value,--comm.value,--valor 
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        --inc.GENERICATTRIBUTE16,--proveedor
       -- inc.GENERICATTRIBUTE1,-- num proveedor 
       	PO.NAME as proveedor, -- prov
		PAR.LASTNAME as num_prov,  -- num proveedor 
        inc.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  inc.value is null or inc.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and inc.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        INC.GENERICNUMBER3 AS TASA_CONVERSION-- TASA CONVERSION
       -- inc.name, -- regla incentivo
      --  inc.value -- valor incentivo
        

	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
      			
		-- INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
       --     AND  txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = txn.PROCESSINGUNITSEQ
            
       INNER JOIN TCMP.CS_incentive inc    ON --INC.PAYEESEQ = CRE.PAYEESEQ
            --AND INC.POSITIONSEQ = CRE.POSITIONSEQ AND
            inc.PROCESSINGUNITSEQ  = txn.PROCESSINGUNITSEQ
            AND  txn.tenantid = itenantId
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
        
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        INNER JOIN CS_COMMISSION comm 
            on inc.incentiveseq = comm.incentiveseq 

        inner join cs_period per 
            on per.periodseq = iperiodseq  
            AND per.REMOVEDATE = v_eot
            AND PER.PERIODSEQ=INC.PERIODSEQ
            
        inner join cs_position po   
            ON po.payeeseq  = inc.payeeseq  
            and po.RULEELEMENTOWNERSEQ = inc.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant   par  
            ON par.payeeseq  = po.payeeseq 
            AND  inc.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
 
        inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
            and INC.businessunitmap=bu.mask --APM 15.05.2023

        WHERE  TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq       
            and inc.PERIODSEQ = iperiodseq
            and BU.NAME LIKE 'Online PTG'
            and inc.name like '%Importe Base%'
			AND INC.GENERICATTRIBUTE1 IS NOT NULL 
            AND INC.GENERICBOOLEAN1 = 1*/
-- New Code    
SELECT 
		'ENEL' ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		null,
		null,
		null as orderid, -- TRANSACCION id
        null as Contrato,  --contrato
        null as linea_pedido, -- linea pedido
        inc.name,--regla
        inc.value,--comm.value,--valor 
        '1' as CUPS, --CUPS
        null as Producto,  --producto
        null as Nombre_prd,  --producto DESCRIPCION
        null as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        null as LINEA_NEGOCIO, --linea negocio  
        null as Nombre_Servicio, -- tipo venta
        --inc.GENERICATTRIBUTE16,--proveedor
       -- inc.GENERICATTRIBUTE1,-- num proveedor 
       	PO.NAME as proveedor, -- prov
		PAR.LASTNAME as num_prov,  -- num proveedor 
        inc.GENERICATTRIBUTE4, -- codigo alico
        null as Estado, -- estado
        null as fecha_alta, -- fecha alta 
       	case 
			when  inc.value is null or inc.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and inc.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        null AS TIPO_EVENTO , -- TIPO EVENTO
     	iprocessingUnitSeq, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        inc.GENERICNUMBER3 AS TASA_CONVERSION,-- TASA CONVERSION
        '1' AS BUSINESSUNITMAP, --APM 15.05.2023
        '1' AS EVENTTYPESEQ --APM 15.05.2023
        from cs_incentive inc
            inner join cs_period per 
                on inc.periodseq = per.periodseq 
                and per.removedate='01/01/2200'
            Inner join cs_businessunit bu  
                on inc.PROCESSINGUNITSEQ =  bu.processingunitseq 
                and INC.businessunitmap = bu.mask
            inner join cs_position po   
                ON po.payeeseq  = inc.payeeseq  
                and po.RULEELEMENTOWNERSEQ = inc.positionseq 
                and po.removedate='01/01/2200'
                AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
                AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            INNER JOIN CS_participant   par 
                ON par.payeeseq  = po.payeeseq 
                AND inc.tenantid = 'ENEL'
                AND par.REMOVEDATE = '01/01/2200'
                AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
                AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1

	 	WHERE inc.periodseq = iperiodseq
            and inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and BU.NAME LIKE 'Online PTG' 
            AND INC.GENERICATTRIBUTE1 IS NOT NULL 
            AND INC.GENERICBOOLEAN1 = 1 -- true            
--EOM APM 15.05.2023  	
	;

    filas := sql%rowcount;
    COMMIT;
--BOM APM 15.05.2023
-- Old Code
    --w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_ONLINE: '|| to_char(filas) || ' filas.', v_contador_debug);
-- New Code     
     w_debug('Fin Carga  Incentivos de la tabla ENEL_TXN_TEMP_ONLINE: '|| to_char(filas) || ' filas.', v_contador_debug);
--EOM APM 15.05.2023

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_ONLINE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_ONLINE.',v_contador_debug);
end;

 procedure p_Temporal_Transacciones_resellers (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2  , iInterfaz IN VARCHAR2 )

AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_RESELLER.', v_contador_debug);
--BOM APM 15.05.2023
--Old Code        
    --DELETE FROM ENELEXT.ENEL_TXN_TEMP_RESELLER WHERE PERIODO = iperiod ;
--New Code     
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_TXN_TEMP_RESELLER WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;  
--EOM APM 15.05.2023      
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_RESELLER.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP_RESELLER. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_RESELLER( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT , PARTICIPANTE,UNIDADES  )
    
                                                
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
      	TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla credito
--BOM APM 09.10.2024
--Old Code   
        --CRE.value,--valor 
--New Code 
        TRIM(replace(to_char(CRE.value , '9999999999990D99'), ',', '.')) VALOR,
--EOM APM 09.10.2024
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE2,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
       
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        PAR.LASTNAME as participante,
        'EURO' as UNIDAD
       
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
			
        /*INNER JOIN TCMP.CS_incentive inc    
            ON inc.payeeseq  = CRE.payeeseq 
            AND  txn.tenantid = itenantId*/
        
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate

        inner join cs_period per 
            on per.periodseq = iperiodseq 
            AND CRE.PERIODSEQ = PER.PERIODSEQ
            AND per.REMOVEDATE = v_eot
            
        inner join cs_position po   
            ON po.payeeseq  = cre.payeeseq  
            and po.RULEELEMENTOWNERSEQ = cre.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant  par  
            ON par.payeeseq  = po.payeeseq 
            AND CRE.tenantid = txn.tenantid
            --AND PAR.tenantid = txn.tenantid --APM 25.04.2023
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
            and txn.businessunitmap=bu.mask
            
        WHERE TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            and cre.PERIODSEQ = iperiodseq
            and BU.NAME LIKE 'Resellers PTG'  
            and cre.value <> 0;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_RESELLER: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_RESELLER COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_RESELLER.',v_contador_debug);
end;
procedure p_Temporal_Incentivos_Resellers (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_periodstartdate date;
	v_periodenddate date;
begin
/* BOM APM 15.05.2023 - Código antiguo */
    /*w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP_RESELLERS.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP_RESELLERS';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP_RESELLERS.', v_contador_debug);*/
--Código nuevo
    w_debug('Inicio Borrado de la tabla ENEL_INCEN_TEMP_RESELLERS.', v_contador_debug);
    LOOP
        DELETE FROM ENELEXT.ENEL_INCEN_TEMP_RESELLERS WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
    END LOOP;
    w_debug('Fin Borrado de la tabla ENEL_INCEN_TEMP_RESELLERS.', v_contador_debug);
/* EOM APM 15.05.2023 */

    w_debug('Cargando tabla ENEL_INCEN_TEMP_RESELLERS. Periodo:'|| iperiod ,  v_contador_debug);
    v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);


	INSERT INTO ENELEXT.ENEL_INCEN_TEMP_RESELLERS( TENANTID, PERIODSEQ, PERIODO,
                                             REGLA, CODIGO_ALICO , REALIZADO_SEM, OBJETIVO_ESC, TM, VALOR,
                                             PROVEEDOR, PROCESSINGUNITSEQ, BUSINESSUNIT,UNIDADES   )
      SELECT 
		inc.TENANTID ,
        inc.periodseq,       --periodseq
        per.name,      -- name
        inc.name,--regla 
        po.name,--cre.GENERICATTRIBUTE4 as codigo_alico, -- codigo alic
        inc.genericnumber2 as realizado_sem, -- realizado semanal
        inc.genericnumber1 as objetivo_esC, -- objetivo escalado
        inc.genericnumber3 as tm, -- tasa mortandad
        inc.value,--valor 
        inc.GENERICATTRIBUTE2,--proveedor
     	inc.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDADES

        FROM CS_incentive inc           
                
            inner join cs_period per on per.periodseq = iperiodseq  
                AND per.REMOVEDATE = v_eot AND PER.PERIODSEQ=INC.PERIODSEQ
                
            inner join cs_position po   ON po.payeeseq  = inc.payeeseq  and po.RULEELEMENTOWNERSEQ = inc.positionseq and po.removedate='01/01/2200'
                AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
                AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
                
            INNER JOIN CS_participant   par  ON par.payeeseq  = po.payeeseq 
                AND par.REMOVEDATE = v_eot
                AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
                AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
                      
            inner join cs_businessunit bu  on inc.PROCESSINGUNITSEQ =  bu.processingunitseq 
                and INC.businessunitmap=bu.mask
--EOM APM 25.04.2023
            where 

                inc.name  like '%Rappel Volumen%'
                and inc.periodseq=iperiodseq
                AND inc.GENERICATTRIBUTE1 IS NOT NULL 
                AND inc.GENERICBOOLEAN1 = 1 
                AND BU.NAME ='Resellers PTG'

                ;
--EOM APM 25.04.2023

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP_RESELLERS: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INCEN_TEMP_RESELLERS COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP_RESELLERS.',v_contador_debug);
end; 
procedure p_resellers_TM  (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
   
     
    AS
	v_periodstartdate date;
	v_periodenddate date;
begin
/* BOM APM 15.05.2023 - Código antiguo */
    /*w_debug('Inicio Truncado de la tabla ENEL_RESELLER_TM.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_RESELLER_TM';
    w_debug('Fin Truncado de la tabla ENEL_RESELLER_TM.', v_contador_debug);*/
--Código nuevo
    w_debug('Inicio Borrado de la tabla ENEL_RESELLER_TM.', v_contador_debug);
    LOOP
        DELETE FROM ENELEXT.ENEL_RESELLER_TM WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
    END LOOP;
    w_debug('Fin Borrado de la tabla ENEL_RESELLER_TM.', v_contador_debug);
/* EOM APM 15.05.2023 */    

    w_debug('Cargando tabla ENEL_RESELLER_TM. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_RESELLER_TM( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA,  LINEA_NEGOCIO, CODIGO_ALICO , REALIZADO_SEM, OBJETIVO_ESC, TM, VALOR,
                                             PROVEEDOR,   TIPO_EVENTO, PROCESSINGUNITSEQ, BUSINESSUNIT,UNIDADES   )
    
                                                
    SELECT 
		TXN.TENANTID ,
        inc.periodseq,       --periodseq
        per.name,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        inc.name,--regla 
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
--BOM APM 25.04.2023   
--Old Code
        cre.GENERICATTRIBUTE4 as codigo_alico, -- codigo alic
--New Code
        
--EOM APM 25.04.2023
        inc.genericnumber2 as realizado_sem, -- realizado semanal
        inc.genericnumber1 as objetivo_esC, -- objetivo escalado
        inc.genericnumber3 as tm, -- tasa mortandad
        inc.value,--valor 
        inc.GENERICATTRIBUTE2,--proveedor
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDAD
        
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = '01/01/2200' --v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			--AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = '01/01/2200'--v_eot
			AND txn.tenantid = etype.tenantid

--BOM APM 25.04.2023
--Old Code
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
            and cre.compensationdate=txn.compensationdate
--EOM APM 25.04.2023
		
        INNER JOIN TCMP.CS_incentive inc    
            ON inc.payeeseq  = CRE.payeeseq 
            AND  txn.tenantid = itenantId
            and inc.periodseq =iperiodseq
        
        inner join cs_period per
            on per.periodseq = inc.periodseq
            AND per.REMOVEDATE = '01/01/2200'--v_eot
            
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate

        inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
            
        WHERE  BU.NAME LIKE '%Resellers PTG%'
--BOM APM 25.04.2023        
            and inc.periodseq=iperiodseq
            AND INC.GENERICATTRIBUTE1 IS NOT NULL 
            AND INC.GENERICBOOLEAN1 = 1 -- true
--EOM APM 25.04.2023   
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_RESELLER_TM: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RESELLER_TM COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RESELLER_TM.',v_contador_debug);
end; 
 procedure p_Temporal_Transacciones_Stands (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )     
      
    AS
	v_periodstartdate date;
	v_periodenddate date;
begin
/* BOM APM 15.05.2023 - Código antiguo */
    /*w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_STAND.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP_STAND';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_STAND.', v_contador_debug);*/
--Código nuevo
    w_debug('Inicio Borrado de la tabla ENEL_TXN_TEMP_STAND.', v_contador_debug);
    LOOP
        DELETE FROM ENELEXT.ENEL_TXN_TEMP_STAND WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
    END LOOP;
    w_debug('Fin Borrado de la tabla ENEL_TXN_TEMP_STAND.', v_contador_debug);
/* EOM APM 15.05.2023 */    

    w_debug('Cargando tabla ENEL_TXN_TEMP_STAND. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_STAND ( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT  )
    
                                                
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla credito
        cre.value,--valor crdito
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT -- BU
                
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
            INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
			

        
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate


          inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
			WHERE    BU.NAME LIKE '%Stands PTG%'
	
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_STAND: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_STAND COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_STAND.',v_contador_debug);
end;  

procedure p_Temporal_Transacciones_Lojas (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )

     
    AS
	v_periodstartdate date;
	v_periodenddate date;
begin
/* BOM APM 15.05.2023 - Código antiguo */
    /*w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_LOJAS.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP_LOJAS';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_LOJAS.', v_contador_debug);*/
--Código nuevo
    w_debug('Inicio Borrado de la tabla ENEL_TXN_TEMP_LOJAS.', v_contador_debug);
    LOOP
        DELETE FROM ENELEXT.ENEL_TXN_TEMP_LOJAS WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
    END LOOP;
    w_debug('Fin Borrado de la tabla ENEL_TXN_TEMP_LOJAS.', v_contador_debug);
/* EOM APM 15.05.2023 */    

    w_debug('Cargando tabla ENEL_TXN_TEMP_LOJAS. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_LOJAS ( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT,
                                             UNIDAD,CODIGO_POSICION,DESCRIPCION_PROVEEDOR) --APM 27.06.2023
    
                                                
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla credito
        --BOM APM 27.06.2023        
        --Old Code cre.value,--valor credito
        --New Code
        TRIM(replace(to_char(cre.value , '9999999999990D99'), ',', '.')) AS VALOR,
        --EOM APM 27.06.2023 
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDAD, --APM 27.06.2023
        PO.NAME AS CODIGO_POSICION, --DMS 27.06.2023
        PAR.LASTNAME AS DESCRIPCION_PROVEEDOR
                
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
            INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
            
            inner join cs_period per 
            on per.periodseq = iperiodseq  
            AND per.REMOVEDATE = v_eot
			
        inner join cs_position po   
            ON po.payeeseq  = CRE.payeeseq  
            and po.RULEELEMENTOWNERSEQ = CRE.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1    
            
        INNER JOIN CS_participant par
            ON par.payeeseq  = po.payeeseq 
            AND  CRE.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate


          inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
			WHERE   
            TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            /*BOM APM 16.03.2026 Old Code*/
            and cre.PERIODSEQ = iperiodseq
            --New Code
            and per.PERIODSEQ = iperiodseq
            /*BOM APM 16.03.2026*/
            and BU.NAME LIKE '%Lojas PTG%'
			and cre.name like '%Importe Base%'
            --or cre.name like '%Captacion Lojas PTG%Ajustes Manuales') --APM 12.03.2026
      
	
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_LOJAS: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_LOJAS COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_LOJAS.',v_contador_debug);
end;      
    
 procedure p_Temporal_Transacciones_D2D (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 ) 
      
    AS
	v_periodstartdate date;
	v_periodenddate date;
begin
/* BOM APM 15.05.2023 - Código antiguo */
    /*w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_D2D.', v_contador_debug);
     DELETE FROM ENELEXT.ENEL_TXN_TEMP_D2D WHERE PERIODO = iperiod ;
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_D2D.', v_contador_debug);*/
--Código nuevo
    w_debug('Inicio Borrado de la tabla ENEL_TXN_TEMP_D2D.', v_contador_debug);
    LOOP
        DELETE FROM ENELEXT.ENEL_TXN_TEMP_D2D WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
    END LOOP;
    w_debug('Fin Borrado de la tabla ENEL_TXN_TEMP_D2D.', v_contador_debug);
/* EOM APM 15.05.2023 */    

    w_debug('Cargando tabla ENEL_TXN_TEMP_D2D. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_D2D ( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT, TIPO, TIPO_RAPPEL,
                                             UNIDAD,CODIGO_POSICION,CODIGO_PROVEEDOR,SEGMENTO,CONCEPTO_LIQ,GENERICATTRIBUTE16) --APM 27.06.2023
    
                                                
    SELECT distinct
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla credito
        --BOM APM 27.06.2023        
        --Old Code cre.value,--valor credito
        --New Code
        TRIM(replace(to_char(cre.value , '9999999999990D99'), ',', '.')) AS VALOR,
        --EOM APM 27.06.2023  
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        cre.GENERICATTRIBUTE12, -- Tipo APM 27.06.2022
        'PENDIENTE DE MAPEAR' AS TIPO_RAPPEL, --APM 28.06.2022
        'EURO' as UNIDAD, --APM 27.06.2023
        PO.NAME AS CODIGO_POSICION, --DMS 27.06.2023
        PAR.LASTNAME AS DESCRIPCION_PROVEEDOR, --DMS 25.07.2023
        TXN.GENERICATTRIBUTE31 AS SEGMENTO,
        TXN.GENERICATTRIBUTE10 AS CONCEPTO_LIQ,
        TXN.GENERICATTRIBUTE16 AS GENERICATTRIBUTE16
                
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
			
         --       INNER JOIN CS_participant   pa  ON pa.payeeseq  = CRE.payeeseq 
      --      AND  txn.tenantid = 'ENEL'

		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        inner join cs_period per 
            on per.periodseq = iperiodseq  
            AND per.REMOVEDATE = v_eot
            
        inner join cs_position po   
            ON po.payeeseq  = CRE.payeeseq  
            and po.RULEELEMENTOWNERSEQ = CRE.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant par
            ON par.payeeseq  = po.payeeseq 
            AND  CRE.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1

        inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq

        WHERE BU.NAME LIKE '%D2D%PTG%'
            and per.periodseq=iperiodseq
            ;
            

    filas := sql%rowcount;
    COMMIT;
    
 /*   INSERT INTO ENELEXT.ENEL_TXN_TEMP_D2D ( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT, TIPO, TIPO_RAPPEL,
                                             UNIDAD,CODIGO_POSICION,CODIGO_PROVEEDOR,SEGMENTO) --APM 27.06.2023
    
                                                
    SELECT distinct
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        inc.name,--regla credito
        --BOM APM 27.06.2023        
        --Old Code inc.value,--valor credito
        --New Code
        TRIM(replace(to_char(inc.value , '9999999999990D99'), ',', '.')) AS VALOR,
        --EOM APM 27.06.2023        
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        inc.GENERICATTRIBUTE16,--proveedor
        inc.GENERICATTRIBUTE1,-- num proveedor 
        inc.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  inc.value is null or inc.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and inc.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        inc.GENERICATTRIBUTE12, -- Tipo APM 27.06.2022
        'PENDIENTE DE MAPEAR' AS TIPO_RAPPEL, --APM 28.06.2022
        'EURO' as UNIDAD, --APM 27.06.2023
        PO.NAME AS CODIGO_POSICION, --DMS 27.03.2023
        PAR.LASTNAME AS DESCRIPCION_PROVEEDOR,
        TXN.GENERICATTRIBUTE31 AS SEGMENTO
                
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
      			
		-- INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
       --     AND  txn.tenantid = itenantId  AND txn.PROCESSINGUNITSEQ = txn.PROCESSINGUNITSEQ
            
       INNER JOIN TCMP.CS_incentive inc    ON --INC.PAYEESEQ = CRE.PAYEESEQ
            --AND INC.POSITIONSEQ = CRE.POSITIONSEQ AND
            inc.PROCESSINGUNITSEQ  = txn.PROCESSINGUNITSEQ
            AND  txn.tenantid = itenantId
        
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
     inner join cs_period per on per.periodseq = iperiodseq  AND per.REMOVEDATE = v_eot
        inner join cs_position po   ON po.payeeseq  = inc.payeeseq  and po.RULEELEMENTOWNERSEQ = inc.positionseq and po.removedate='01/01/2200'
    AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
    AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
    INNER JOIN CS_participant   par  ON par.payeeseq  = po.payeeseq 
            AND  inc.tenantid = txn.tenantid
       AND par.REMOVEDATE = v_eot
        AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
        AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
      
            
          inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq

			WHERE    BU.NAME LIKE '%D2D%PTG%'
            and per.periodseq=iperiodseq
            AND INC.GENERICATTRIBUTE1 IS NOT NULL 
           AND INC.GENERICBOOLEAN1 = 1 -- true
	
	;

    filas := sql%rowcount;
    COMMIT;*/

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_D2D: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_D2D COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_D2D.',v_contador_debug);
end; 

procedure p_Temporal_Transacciones_STORES (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 ) 
      
    AS
	v_periodstartdate date;
	v_periodenddate date;
begin
/* BOM APM 15.05.2023 - Código antiguo */
    /*w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_STORES.', v_contador_debug);
     DELETE FROM ENELEXT.ENEL_TXN_TEMP_STORES WHERE PERIODO = iperiod ;
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_STORES.', v_contador_debug);*/
--Código nuevo
w_debug('Inicio Borrado de la tabla ENEL_TXN_TEMP_STORES.', v_contador_debug);
    LOOP
        DELETE FROM ENELEXT.ENEL_TXN_TEMP_STORES WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
        EXIT WHEN SQL%ROWCOUNT = 0;
        COMMIT;
    END LOOP;
    w_debug('Fin Borrado de la tabla ENEL_TXN_TEMP_STORES.', v_contador_debug);
/* EOM APM 15.05.2023 */    

w_debug('Cargando tabla ENEL_TXN_TEMP_STORES. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_STORES ( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT, TIPO, TIPO_RAPPEL,
                                             UNIDAD,CODIGO_POSICION,CODIGO_PROVEEDOR,SEGMENTO,MODELOVENTA,GENERICATTRIBUTE16,CONCEPTO_LIQ) --APM 27.06.2023
    
                                                
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		ordtxn.orderid as orderid, -- TRANSACCION id
        TXN.PONUMBER as Contrato,  --contrato
        txn.GENERICATTRIBUTE23 as linea_pedido, -- linea pedido
        cre.name,--regla credito
        --BOM APM 27.06.2023        
        --Old Code cre.value,--valor credito
        --New Code
        TRIM(replace(to_char(cre.value , '9999999999990D99'), ',', '.')) AS VALOR,
        --EOM APM 27.06.2023  
        TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        TXN.PRODUCTID as Producto,  --producto
        TXN.PRODUCTNAME as Nombre_prd,  --producto DESCRIPCION
        txn.GENERICATTRIBUTE24 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        etxn0.GENERICATTRIBUTE13 as LINEA_NEGOCIO, --linea negocio  
        TXN.GENERICATTRIBUTE1 as Nombre_Servicio, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.GENERICATTRIBUTE3 as Estado, -- estado
        TXN.GENERICdate4 as fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        cre.GENERICATTRIBUTE12, -- Tipo APM 27.06.2022
        'PENDIENTE DE MAPEAR' AS TIPO_RAPPEL, --APM 28.06.2022
        'EURO' as UNIDAD, --APM 27.06.2023
        PO.NAME AS CODIGO_POSICION, --DMS 27.06.2023
        PO.GENERICATTRIBUTE5 AS DESCRIPCION_PROVEEDOR, --DMS 25.07.2023
        TXN.GENERICATTRIBUTE31 AS SEGMENTO,
        txn.genericattribute7 as MODELOVENTA,
        txn.GENERICATTRIBUTE16 as GENERICATTRIBUTE16,
        TXN.GENERICATTRIBUTE10 AS CONCEPTO_LIQ
                
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
            
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
			
         --       INNER JOIN CS_participant   pa  ON pa.payeeseq  = CRE.payeeseq 
      --      AND  txn.tenantid = 'ENEL'

		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
            
        inner join cs_period per 
            on per.periodseq = iperiodseq  
            AND per.REMOVEDATE = v_eot
            
        inner join cs_position po   
            ON po.payeeseq  = CRE.payeeseq  
            and po.RULEELEMENTOWNERSEQ = CRE.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        INNER JOIN CS_participant par
            ON par.payeeseq  = po.payeeseq 
            AND  CRE.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1

        inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
            and txn.businessunitmap=bu.mask

        WHERE BU.NAME LIKE '%Stores%PTG%'
            and per.periodseq=iperiodseq
            ;
            

    filas := sql%rowcount;
    COMMIT;
    
  

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_STORES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_STORES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_STORES.',v_contador_debug);
end; 


procedure p_creditos_ricorrente_stores (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

  
    
    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_6M.', v_contador_debug);
     BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_STORES_6M WHERE periodo_anual = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_6M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_STORES_6M. Periodo:'|| iperiod ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_STORES_6M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL,processingunitseq )
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL,
        inc.processingunitseq
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-6)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ       
            and credit.periodseq=commi.periodseq
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid

        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            and inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    
	WHERE
		inc.TENANTID = itenantId 
        and inc.periodseq=iperiodseq
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_STORES_6M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_STORES_6M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_STORES_6M.',v_contador_debug);
    
    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_12M.', v_contador_debug);
     BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_STORES_12M WHERE periodo_anual = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_12M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_STORES_12M. Periodo:'|| iperiod ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_STORES_12M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL,processingunitseq )
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL,
        inc.processingunitseq
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-12)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ   
            and credit.periodseq=commi.periodseq
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            and inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    
	WHERE
		inc.TENANTID = itenantId 
        and inc.periodseq=iperiodseq
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_STORES_12M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_STORES_12M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_STORES_12M.',v_contador_debug);

/* w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_13M.', v_contador_debug);
     BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_STORES_13M WHERE periodo_anual = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_13M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_STORES_13M. Periodo:'|| iperiod ,  v_contador_debug);*/

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	/*INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_STORES_13M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL,processingunitseq )
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL,
        inc.processingunitseq
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-13)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ   
            and credit.periodseq=commi.periodseq
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            and inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    
	WHERE
		inc.TENANTID = itenantId 
        and inc.periodseq=iperiodseq
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_STORES_13M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_STORES_13M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_STORES_13M.',v_contador_debug);
	
	
 w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_14M.', v_contador_debug);
     BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_STORES_14M WHERE periodo_anual = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_14M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_STORES_14M. Periodo:'|| iperiod ,  v_contador_debug);*/

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	/*INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_STORES_14M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL,processingunitseq )
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL,
        inc.processingunitseq
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-14)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ   
            and credit.periodseq=commi.periodseq
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            and inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    
	WHERE
		inc.TENANTID = itenantId 
        and inc.periodseq=iperiodseq
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_STORES_14M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_STORES_14M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_STORES_14M.',v_contador_debug);
	
	
 w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_15M.', v_contador_debug);
     BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_STORES_15M WHERE periodo_anual = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_STORES_15M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_STORES_15M. Periodo:'|| iperiod ,  v_contador_debug);*/

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	/*INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_STORES_15M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL,processingunitseq )
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		inc.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        CASE BU.NAME
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL,
        inc.processingunitseq
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-15)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    LEFT JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ   
            and credit.periodseq=commi.periodseq
            
       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		
            
        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            and inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
         INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    
	WHERE
		inc.TENANTID = itenantId 
        and inc.periodseq=iperiodseq
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_STORES_15M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_STORES_15M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_STORES_15M.',v_contador_debug);*/

end;


 procedure p_resumen_liq_alico (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_RESUMEN_LIQ_ALICO.', v_contador_debug);
    --BOM APM 15.05.2023
    --DELETE FROM ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL WHERE PERIODO = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq;
    --Nuevo Código
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_RESUMEN_LIQ_ALICO WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;  
    --EOM APM 15.05.2023        
    END;
    w_debug('Fin Truncado de la tabla ENEL_RESUMEN_LIQ_ALICO.', v_contador_debug);

    w_debug('Cargando tabla ENEL_RESUMEN_LIQ_ALICO. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);
    w_debug('FECHA Inicio:'|| v_periodstartdate ,  v_contador_debug);
    w_debug('FECHA Fin:'|| v_periodenddate ,  v_contador_debug);
    
    w_debug('Carga Créditos en la tabla ENEL_RESUMEN_LIQ_ALICO.', v_contador_debug); --APM 20.03.2023
    
	INSERT INTO ENELEXT.ENEL_RESUMEN_LIQ_ALICO( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, --CONTRATO, 
                                               VALOR,  PRODUCTO, PROVEEDOR, prov , PROCESSINGUNITSEQ, BUSINESSUNIT ,UNIDADES,NOMBRE_REGLA,tipo,payeeseq,positionseq, TIPO_VENDA,POSICION,ESTANDAR,OUTDOOR,
                                               TIPO_IMPORTE)
                                                
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
     	ordtxn.orderid as orderid, -- TRANSACCION id
        --TXN.PONUMBER as Contrato,  --contrato
          -- SUM( cre.value), --valor crdito
        cre.value,
       -- TXN.ALTERNATEORDERNUMBER as CUPS, --CUPS
        CRE.GENERICATTRIBUTE1 as Producto,  --producto
       --cre.genericattribute8 ,
        pa.lastname as proveedor,
        CRE.GENERICATTRIBUTE2 as prov,
       -- cre.name,
       -- inc.name
      	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT ,-- BU
        '1' AS UNIDADES,
        cre.name as NOMBRE_REGLA,
        txn.GENERICATTRIBUTE31 as tipo,
        cre.payeeseq,
        cre.positionseq,
        /*BOM APM 17.02.2025*/
        case 
            when txn.GENERICBOOLEAN1 = 1 then 'Winback'
            else 'Competitiva' end AS TIPO_VENDA,
        PO.GENERICATTRIBUTE5,
        CRE.GENERICATTRIBUTE13,
        CRE.GENERICATTRIBUTE14,
        /*eOM APM 17.02.2025*/
        CRE.GENERICATTRIBUTE15 as TIPO_IMPORTE --APM 21.10.2025
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = '01/01/2200'
			AND txn.tenantid = 'ENEL'
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = '01/01/2200'
			AND txn.tenantid = etype.tenantid
            
        INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = 'ENEL' -- AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
            
        inner join cs_period per on per.periodseq = cre.periodseq
            AND per.REMOVEDATE = v_eot
            
        left JOIN cs_position po
            ON po.payeeseq = cre.payeeseq
            and po.RULEELEMENTOWNERSEQ=cre.positionseq
            AND po.removedate  = '01/01/2200'
            AND po.tenantid = cre.tenantid
            and PO.PROCESSINGUNITSEQ =  cre.processingUnitSeq
            AND po.EFFECTIVESTARTDATE <= per.startdate             
			AND po.EFFECTIVEENDDATE >= per.enddate
-- New code
        INNER JOIN CS_participant   pa  ON pa.payeeseq  = cre.payeeseq 
                AND  pa.tenantid = txn.tenantid
                AND pa.REMOVEDATE = '01/01/2200'
                 AND PA.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PA.EFFECTIVEENDDATE >= PER.ENDDATE - 1
                   

        Inner join cs_businessunit bu  on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq
            and txn.businessunitmap=bu.mask --APM 21.03.2023

	 	WHERE 
            BU.NAME LIKE '%PTG%'
            and cre.processingunitseq = iprocessingUnitSeq --38280596832650019 --CAT Emision ALICO PTG
            AND cre.name not like '%Altas%' 
            and per.periodseq=iperiodseq;
          
   

    filas := sql%rowcount;
    COMMIT;

--BOM APM 20.03.2023
    w_debug('Fin Carga Créditos de la tabla ENEL_RESUMEN_LIQ_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Carga Incentivos en la tabla ENEL_RESUMEN_LIQ_ALICO.', v_contador_debug);
--EOM APM 20.03.2023  

INSERT INTO ENELEXT.ENEL_RESUMEN_LIQ_ALICO( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, --CONTRATO, 
                                               VALOR,  PRODUCTO, PROVEEDOR, prov , PROCESSINGUNITSEQ, BUSINESSUNIT ,UNIDADES,NOMBRE_REGLA,tipo,payeeseq,positionseq,
                                               MARCADOR_TABLA, OBJETIVO, REALIZADO, porc_tm2)
 
    SELECT
            'ENEL' AS tenantid,
            iperiodseq AS periodseq,
            iperiod AS periodo,
            null AS SALESORDERSEQ,
            null AS SALESTRANSACTIONSEQ,
            null AS ORDERID,
            inc.value AS valor,
            inc.genericattribute1 AS producto,
            pa.lastname as proveedor,
            inc.genericattribute2 as prov,
            inc.processingunitseq as processingunitseq,
            BU.NAME AS BUSINESS_UNIT, -- BU
            '1' AS UNIDADES,
            inc.name as NOMBRE_REGLA,
            null as tipo,
            inc.payeeseq,
            inc.positionseq,
            /*BOM APM 21.10.2025*/
            case when inc.name like '%TM2%' then 1
            when inc.name like '%Rappel%' then 2
            when inc.name like '%Ricorrente%' then 3 
            else 0 end,
            /*EOM APM 21.10.2025*/
            /*BOM APM 24.10.2025*/
            inc.GENERICNUMBER1 as OBJETIVO, 
            inc.GENERICNUMBER2 as REALIZADO,
            inc.GENERICNUMBER3 as porc_tm2
            /*EOM APM 24.10.2025*/
    FROM cs_incentive inc
        INNER JOIN cs_period  per
            ON inc.periodseq = per.periodseq
            AND per.REMOVEDATE = v_eot
        /*BOM APM 13.07.2023*/
        --New Code
        INNER JOIN CS_POSITION POS
            ON inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND inc.PAYEESEQ = POS.PAYEESEQ
            AND POS.REMOVEDATE = '01/01/2200'
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
        /*EOM APM 13.07.2023*/
         INNER JOIN CS_participant   pa  ON pa.payeeseq  = INC.payeeseq 
                AND  pa.tenantid = 'ENEL'
                AND pa.REMOVEDATE = '01/01/2200'
                 AND PA.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PA.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        /*EOM APM 13.07.2023*/        
        INNER JOIN cs_businessunit bu  
            ON bu.processingunitseq = inc.processingunitseq
            and INC.businessunitmap=bu.mask --APM 13.07.2023
    WHERE 
        (bu.name LIKE '%PTG%')      
        AND INC.GENERICATTRIBUTE1 IS NOT NULL 
        AND INC.GENERICBOOLEAN1 = 1 -- true
        and per.periodseq = iperiodseq
        and INC.PROCESSINGUNITSEQ = iprocessingUnitSeq--38280596832650019 --CAT Emision ALICO PTG --APM 20.03.2023
          
     /* group by 
        TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
        ordtxn.orderid , -- TRANSACCION id
        --TXN.PONUMBER ,  --contrato
       -- txn.GENERICATTRIBUTE23, -- linea pedido
        inc.value,--valor crdito
        TXN.PRODUCTID ,  --producto
        --cre.genericattribute8 ,
        pa.lastname,
        inc.GENERICATTRIBUTE2,
     --   cre.name,

    --      inc.name
	TXN.PROCESSINGUNITSEQ,
    BU.NAME */
	;

    filas := sql%rowcount;
    COMMIT;
--BOM APM 20.03.2023
-- Old Code     
    --w_debug('Fin Carga de la tabla ENEL_RESUMEN_LIQ_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);
-- New Code      
    w_debug('Fin Carga Incentivos de la tabla ENEL_RESUMEN_LIQ_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);      
--EOM APM 20.03.2023

--BOM APM 10.05.2023
    w_debug('Carga Incentivos - Comisiones en la tabla ENEL_RESUMEN_LIQ_ALICO.', v_contador_debug);
    INSERT INTO ENELEXT.ENEL_RESUMEN_LIQ_ALICO( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, --CONTRATO, 
                                               VALOR,  PRODUCTO, PROVEEDOR, prov , PROCESSINGUNITSEQ, BUSINESSUNIT ,UNIDADES,NOMBRE_REGLA,tipo)
    SELECT
            'ENEL' AS tenantid,
            iperiodseq AS periodseq,
            iperiod AS periodo,
            null AS SALESORDERSEQ,
            null AS SALESTRANSACTIONSEQ,
            null AS ORDERID,
            inc.value AS valor,
            inc.genericattribute1 AS producto,
            pa.lastname as proveedor,
            inc.genericattribute2 as prov,
            inc.processingunitseq as processingunitseq,
            BU.NAME AS BUSINESS_UNIT, -- BU
            '1' AS UNIDADES,
            inc.name as NOMBRE_REGLA,
            null as tipo
    FROM cs_incentive inc
        INNER JOIN cs_period  per
            ON inc.periodseq = per.periodseq
            AND per.REMOVEDATE = v_eot
        INNER JOIN cs_participant pa  
            ON pa.payeeseq = inc.payeeseq 
        INNER JOIN cs_businessunit bu  
            ON bu.processingunitseq = inc.processingunitseq  
        INNER JOIN CS_COMMISSION comm 
            on inc.incentiveseq = comm.incentiveseq 
            and pa.payeeseq=comm.payeeseq
            and inc.periodseq=comm.periodseq
    WHERE 
        (bu.name LIKE '%PTG%') 
        and per.periodseq = iperiodseq
        and INC.PROCESSINGUNITSEQ = iprocessingUnitSeq;

    filas := sql%rowcount;
    COMMIT;
        
    w_debug('Fin Carga Incentivos - Comisiones de la tabla ENEL_RESUMEN_LIQ_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);      
--EOM APM 10.05.2023

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RESUMEN_LIQ_ALICO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RESUMEN_LIQ_ALICO.',v_contador_debug);
end;
 


 procedure p_resumen_liq_res_onl (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_RESUMEN_LIQ_RES_ONL.', v_contador_debug);
    DELETE FROM ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL WHERE PERIODO = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq;
    w_debug('Fin Truncado de la tabla ENEL_RESUMEN_LIQ_RES_ONL.', v_contador_debug);

    w_debug('Cargando tabla ENEL_RESUMEN_LIQ_RES_ONL. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);
    w_debug('FECHA Inicio:'|| v_periodstartdate ,  v_contador_debug);
    w_debug('FECHA Fin:'|| v_periodenddate ,  v_contador_debug);
    
    w_debug('Carga Créditos en la tabla ENEL_RESUMEN_LIQ_RES_ONL.', v_contador_debug); --APM 20.03.2023
    
	INSERT INTO ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL( TENANTID, PERIODSEQ, PERIODO, VALOR,  PRODUCTO, PROVEEDOR, prov , PROCESSINGUNITSEQ, BUSINESSUNIT, ORDERID, UNIDADES,TIPO,
                                                  REGLA,PAYEESEQ,POSITIONSEQ,POSICION,ESTANDAR,OUTDOOR)--APM 20.03.2023
                                                
    SELECT 
		TXN.TENANTID ,
        cre.periodseq,-- iperiodseq,       --periodseq
        IPERIOD , --iperiod,      -- name
	    cre.value,
        CRE.GENERICATTRIBUTE1 as Producto,  --producto
        pa.lastname as proveedor,
        CRE.GENERICATTRIBUTE2 as prov,
       	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        ordtxn.orderid as orderid,
        '1' AS UNIDADES,
        TXN.GENERICATTRIBUTE31 AS TIPO,
        cre.name,--regla credito --APM 20.03.2023
        CRE.PAYEESEQ,
        CRE.POSITIONSEQ,
        PO.GENERICATTRIBUTE5,
        CRE.GENERICATTRIBUTE13,
        CRE.GENERICATTRIBUTE14
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = '01/01/2200'
			AND txn.tenantid = 'ENEL'
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq

		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = '01/01/2200'
			AND txn.tenantid = etype.tenantid

        INNER JOIN TCMP.CS_CREDIT CRE    ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND  txn.tenantid = 'ENEL' -- AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and cre.periodseq=iperiodseq
            
--BOM APM 20.03.2023
--New Code  
        inner join cs_position po   
            ON po.payeeseq  = CRE.payeeseq 
            and po.RULEELEMENTOWNERSEQ = CRE.positionseq 
            and po.removedate='01/01/2200'
--EOM APM 20.03.2023  

        inner join cs_period per 
            on per.periodseq = cre.periodseq
            AND per.REMOVEDATE = v_eot
            
        INNER JOIN CS_participant  pa
            ON pa.payeeseq  = po.payeeseq
            and pa.removedate=v_eot             
            AND PA.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PA.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            AND  CRE.tenantid = txn.tenantid
            AND pa.REMOVEDATE = '01/01/2200'
--EOM APM 20.03.2023
        Inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ =  bu.processingunitseq 
            and txn.businessunitmap = bu.mask
      
	 	WHERE 
--BOM APM 20.03.2023
--Old Code          
        per.periodseq = iperiodseq 
--EOM APM 20.03.2023       
            and cre.PROCESSINGUNITSEQ = iprocessingUnitSeq 
            AND BU.NAME LIKE '%PTG%' --OR BU.NAME LIKE 'ALICO PTG'
            AND ( cre.name not like '%Altas%' 
            and cre.name not like '%Ventas%' 
            and cre.name not like '%Leads%' 
            and cre.name not like '%E Billing%')
     /*   group by 
      	TXN.TENANTID ,
         iperiodseq,       --periodseq
        iperiod,      -- name
		cre.value,
        TXN.PRODUCTID ,  --producto
        pa.lastname ,
        CRE.GENERICATTRIBUTE2 ,
       	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME  -- BU*/
	;

    filas := sql%rowcount;
    COMMIT;
--BOM APM 20.03.2023
    w_debug('Fin Carga Créditos de la tabla ENEL_RESUMEN_LIQ_RES_ONL: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Carga Incentivos en la tabla ENEL_RESUMEN_LIQ_RES_ONL.', v_contador_debug);
--EOM APM 20.03.2023  

   INSERT INTO ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL( TENANTID, PERIODSEQ, PERIODO,  VALOR,  PRODUCTO, PROVEEDOR, prov , PROCESSINGUNITSEQ, BUSINESSUNIT, ORDERID ,UNIDADES,TIPO,
                                                REGLA,OBJETIVO,REALIZADO,porc_tm2,PRECIO_UNITARIO,MARCADOR_TABLA,payeeseq,positionseq,posicion)--APM 20.03.2023   
                                                
    SELECT 
		inc.TENANTID ,
        inc.periodseq, --iperiodseq,       --periodseq
        IPERIOD, --iperiod,      -- name
		inc.value,
        inc.genericattribute1 as Producto,  --producto
        par.lastname as proveedor,
        inc.genericattribute2 as prov,
       	inc.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        NULL,
        '1' AS UNIDADES,
        'NULL',
        inc.name,--regla credito --APM 20.03.2023
        inc.GENERICNUMBER1 as OBJETIVO, 
        inc.GENERICNUMBER2 as REALIZADO,
        inc.GENERICNUMBER3 as porc_tm2,
        inc.GENERICNUMBER5 as PRECIO_UNITARIO,
        case when inc.name like '%TM2%' then 1
        when inc.name like '%Rappel%' then 2
        when inc.name like '%Ricorrente%' then 3 --APM 27.01.2025
        else 0 end ,--numero usado para seleccionar los datos en el informe resumen liquidacion
        inc.payeeseq,
        inc.positionseq,
        POs.GENERICATTRIBUTE5
        
	from cs_incentive inc
        inner join cs_period per 
            on inc.periodseq = per.periodseq 
            and per.removedate='01/01/2200'
        Inner join cs_businessunit bu  
            on inc.PROCESSINGUNITSEQ =  bu.processingunitseq 
            and INC.businessunitmap=bu.mask
        /*inner join cs_position po   
            ON po.payeeseq  = inc.payeeseq  
            and po.RULEELEMENTOWNERSEQ = inc.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1*/
        /*INNER JOIN CS_participant   par  
            --ON par.payeeseq  = po.payeeseq 
            ON par.payeeseq = inc.payeeseq */
            /*AND  inc.tenantid = 'ENEL'
            AND par.REMOVEDATE = '01/01/2200'
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1*/
   -- INNER JOIN CS_COMMISSION comm on inc.incentiveseq=comm.incentiveseq and po.payeeseq=comm.payeeseq
        /*BOM APM 13.07.2023*/
        --New Code
        INNER JOIN CS_POSITION POS
            ON inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND inc.PAYEESEQ = POS.PAYEESEQ
            AND POS.REMOVEDATE = '01/01/2200'
        INNER JOIN CS_participant par
            ON par.payeeseq  = pos.payeeseq 
            AND par.REMOVEDATE = v_eot
             AND PAr.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAr.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        /*EOM APM 13.07.2023*/
            
	 	WHERE  inc.periodseq = iperiodseq 
           and inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
           and BU.NAME LIKE '%PTG%' --OR BU.NAME LIKE 'ALICO PTG'
           AND INC.GENERICATTRIBUTE1 IS NOT NULL 
           and inc.name not like 'C -%'
           AND (INC.GENERICBOOLEAN2 = 1 -- true
           or INC.GENERICBOOLEAN1 =1)
                     
     /* group by 
        inc.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		inc.value,--valor crdito
         inc.genericattribute1 ,       
        par.lastname,
        inc.GENERICATTRIBUTE2,
    	inc.PROCESSINGUNITSEQ,
         BU.NAME */
	;

    filas := sql%rowcount;
    COMMIT;
    
--BOM APM 20.03.2023
    w_debug('Fin Carga Incentivos de la tabla : ENEL_RESUMEN_LIQ_RES_ONL'|| to_char(filas) || ' filas.', v_contador_debug);      
    
    w_debug('Carga Incentivos - Comisiones en la tabla ENEL_RESUMEN_LIQ_RES_ONL .', v_contador_debug);
--EOM APM 20.03.2023    
    INSERT INTO ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL( TENANTID, PERIODSEQ, PERIODO,  VALOR,  PRODUCTO, PROVEEDOR, prov ,
                                                 PROCESSINGUNITSEQ, BUSINESSUNIT, ORDERID ,UNIDADES,TIPO,payeeseq,positionseq)
                                                
    SELECT 
		inc.TENANTID ,
        inc.periodseq, --iperiodseq,       --periodseq
        IPERIOD, --iperiod,      -- name
		comm.value,
        inc.genericattribute1 as Producto,  --producto
        par.lastname as proveedor,
        inc.genericattribute2 as prov,
       	inc.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        NULL,
        '1' AS UNIDADES,
         'NULL',
         inc.payeeseq,
        inc.positionseq
	from cs_incentive inc
        inner join cs_period per 
            on   inc.periodseq = per.periodseq 
            and per.removedate='01/01/2200'
        Inner join cs_businessunit bu  
            on inc.PROCESSINGUNITSEQ =  bu.processingunitseq 
            and INC.businessunitmap=bu.mask
        /*inner join cs_position po   
            ON po.payeeseq  = inc.payeeseq  
            and po.RULEELEMENTOWNERSEQ = inc.positionseq 
            and po.removedate='01/01/2200'
            AND Po.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND Po.EFFECTIVEENDDATE >= PER.ENDDATE - 1*/ --APM 13.07.2023 Se comenta
        INNER JOIN CS_participant   par  
            /*ON par.payeeseq  = po.payeeseq 
            AND  inc.tenantid = 'ENEL'
            AND par.REMOVEDATE = '01/01/2200'
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1*/ --APM 13.07.2023 Se comenta
            ON par.payeeseq = inc.payeeseq --APM 13.07.2023
            and par.removedate='01/01/2200'
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        INNER JOIN CS_COMMISSION comm 
            on inc.incentiveseq=comm.incentiveseq 
            and inc.periodseq=comm.periodseq
            /*BOM APM 13.07.2023*/
            --Old Code            
            --and po.payeeseq=comm.payeeseq
            --New Code 
            and par.payeeseq=comm.payeeseq
            /*EOM APM 13.07.2023*/

	 	WHERE  inc.periodseq = iperiodseq 
          /*BOM APM 13.07.2023*/
           --Old Code
           --  and inc.PROCESSINGUNITSEQ = 38280596832650020
           --and BU.NAME LIKE '%Online%PTG%' --OR BU.NAME LIKE 'ALICO PTG'
           --New Code 
           and INC.PROCESSINGUNITSEQ = iprocessingUnitSeq
           AND bu.name LIKE '%PTG%'
           /*EOM APM 13.07.2023*/
           AND INC.GENERICATTRIBUTE1 IS NOT NULL 
           AND INC.GENERICBOOLEAN1 = 1 -- true
                     
     /* group by 
        inc.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		inc.value,--valor crdito
         inc.genericattribute1 ,       
        par.lastname,
        inc.GENERICATTRIBUTE2,
    	inc.PROCESSINGUNITSEQ,
         BU.NAME */
	;

    filas := sql%rowcount;
    COMMIT;
--BOM APM 20.03.2023
-- Old Code    
    --w_debug('Fin Carga de la tabla ENEL_RESUMEN_LIQ_RES_ONL: '|| to_char(filas) || ' filas.', v_contador_debug);
-- New Code      
    w_debug('Fin Carga Incentivos - Comisiones de la tabla ENEL_RESUMEN_LIQ_RES_ONL: '|| to_char(filas) || ' filas.', v_contador_debug);      
--EOM APM 20.03.2023

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RESUMEN_LIQ_RES_ONL.',v_contador_debug);
end;

--BOM APM 15.05.2023
--New Code
procedure p_Incen_TM2_alico( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2)
as
begin
    w_debug('Inicio Borrado de la tabla ENEL_INCEN_TM2_ALICO.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_INCEN_TM2_ALICO WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;

    w_debug('Fin Borrado de la tabla ENEL_INCEN_TM2_ALICO.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TM2_ALICO. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_INCEN_TM2_ALICO( TENANTID, PERIODSEQ, PERIODO, REGLA_INC, VALOR_INC, PROVEEDOR, ALTAS, BAJAS, 
                                              INCENTIVO , PROCESSINGUNITSEQ,
                                              UNIDAD,CODIGO_PROVEEDOR,DESCRIPCION_PROVEEDOR) --APM 27.06.2023
    
    SELECT 
            per.TENANTID,
            per.periodseq,       
            per.name, 
            CSI.name,
            CSI.value,
            CSI.GENERICATTRIBUTE2, -- proveedor
            CSI.GENERICNUMBER1, -- altas
            CSI.GENERICNUMBER2, -- bajas
            CSI.GENERICNUMBER3, -- incentivo
            iprocessingUnitSeq,
            'EURO' as UNIDAD, --APM 27.06.2023
            POS.NAME AS CODIGO_PROVEEDOR,
            PAR.LASTNAME AS DESCRIPCION_PROVEEDOR
        
    FROM ENEL_INCEN_TEMP_ALICO CSI --CS_INCENTIVE CSI
        INNER JOIN CS_POSITION POS
            ON CSI.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND CSI.PAYEESEQ = POS.PAYEESEQ
            AND POS.REMOVEDATE = '01/01/2200'
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = csi.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on CSI.PROCESSINGUNITSEQ = bu.processingunitseq 
            and CSI.businessunitmap = bu.mask
        INNER JOIN CS_participant par
            ON par.payeeseq  = CSI.payeeseq 
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
      WHERE 
		per.periodseq = iperiodseq 
        /*BOM APM 09.01.2026*/
        --Old Code
		--and CSI.NAME LIKE '%D2D%TM2%'
        --New Code
        and CSI.NAME LIKE '%PTG%TM2%'
        /*EOM APM 09.01.2026*/
        AND CSI.GENERICATTRIBUTE1 IS NOT NULL 
        AND CSI.GENERICBOOLEAN1 = 1 -- true
        --and CSI.value <> 0
		; 

    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_INCEN_TM2_ALICO - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
end;
procedure p_tdm2_ptg( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2)
as
begin
    w_debug('Inicio Borrado de la tabla ENEL_TDM2_PTG.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_TDM2_PTG WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;

    w_debug('Fin Borrado de la tabla ENEL_TDM2_PTG.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TDM2_PTG. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_TDM2_PTG ( periodo , periodo_alta ,id_transaccion  ,id_contrato ,call_id ,cups , id_producto , 
										descripcion_producto , descripcion_producto_2 , tarifa , tipo_venta , codigo_proveedor , canal ,
										estado , segmento , fecha_alta , estado_liquidacion,processingunitseq )
											
    SELECT 
        iperiod as periodo , 
		per.name as periodo_alta ,
		ordtxn.orderid as id_transaccion  ,
		txn.ponumber as id_contrato ,
		txn.genericattribute23 as call_id ,
		txn.alternateordernumber as cups , 
		txn.productid as id_producto , 
		txn.productname as descripcion_producto , 
		txn.genericattribute24 as descripcion_producto_2 , 
		etxn0.genericattribute15 as tarifa , 
		txn.genericattribute1 as tipo_venta , 
		txn.genericattribute19 as codigo_proveedor , 
/*BOM APM 17.12.2025*/
--Old Code
		--txn.genericattribute2 as canal ,
--New Code
        po.genericattribute5 as canal ,
/*BOM APM 17.12.2025*/
		txn.genericattribute3 as estado , 
		txn.genericattribute31 as segmento , 
		txn.genericdate4 as fecha_alta , 
		txn.genericdate5 as estado_liquidacion,
        iprocessingunitseq as processingunitseq
        
        
    FROM cs_salestransaction TXN
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND txn.tenantid = itenantId
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingUnitSeq
		LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
        INNER JOIN cs_credit CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND cre.tenantid = itenantId  
            AND cre.PROCESSINGUNITSEQ = iprocessingUnitSeq
			and cre.compensationdate=txn.compensationdate
            
         Inner Join cs_period per
            on per.startdate=ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-2)
            and per.periodseq = cre.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ = bu.processingunitseq 
            and TXN.businessunitmap = bu.mask
        INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid

/*BOM APM 17.12.2025*/
--New Code
        INNER JOIN cs_position po
            ON po.payeeseq = cre.payeeseq
            and po.RULEELEMENTOWNERSEQ=cre.positionseq
            AND po.removedate  = '01/01/2200'
            AND po.tenantid = cre.tenantid
            and PO.PROCESSINGUNITSEQ =  cre.processingUnitSeq
            AND po.EFFECTIVESTARTDATE <= per.startdate             
			AND po.EFFECTIVEENDDATE >= per.enddate
/*EOM APM 17.12.2025*/
        
      WHERE 
		txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
		and (etype.eventtypeid='Alta Contrato CAT Emision PTG'
		or etype.eventtypeid='Alta Contrato D2D PTG')
    ;

    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_TDM2_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
end;


procedure p_Creditos_Incen_alico( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2)
as
begin
    w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_INCEN_ALICO.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CREDITOS_INCEN_ALICO WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_INCEN_ALICO.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDITOS_INCEN_ALICO. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CREDITOS_INCEN_ALICO(  TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                                    REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                                    PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                                    PROCESSINGUNITSEQ, BUSINESSUNIT,
                                                    UNIDAD,DESCRIPCION_PROVEEDOR) --APM 27.06.2023
    
/* BOM DCR 26.09.2023 
    SELECT 
        TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		TXN.orderid as orderid, -- TRANSACCION id
        TXN.Contrato,  --contrato
        txn.linea_pedido, -- linea pedido
        cre.name,--regla credito
        --BOM APM 26.06.2023
        --Old Code cre.value,--valor credito
        --New Code
        TRIM(replace(to_char(cre.value , '9999999999990D99'), ',', '.')) VALOR,
        --EOM APM 26.06.2023
        TXN.CUPS, --CUPS
        TXN.Producto,  --producto
        TXN.Nombre_prd,  --producto DESCRIPCION
        txn.nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        TXN.LINEA_NEGOCIO, --linea negocio  
        TXN.TIPO_VENTA, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.Estado, -- estado
        TXN.fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDAD, --APM 27.06.2023
        PAR.LASTNAME AS DESCRIPCION_PROVEEDOR --DMS 26.07.2023
        
    FROM ENEL_TXN_TEMP_ALICO_V2 TXN
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = TXN.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ = bu.processingunitseq 
            and TXN.businessunitmap = bu.mask
        INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and txn.periodseq=cre.periodseq
        INNER JOIN CS_participant par
            ON par.payeeseq  = CRE.payeeseq 
            AND  CRE.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
      WHERE 
		per.periodseq = iperiodseq 
        and BU.NAME LIKE '%CAT%PTG' OR BU.NAME LIKE 'ALICO PTG'
		; 
EOM DCR 26.09.2023 */
    SELECT 
        TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		TXN.orderid as orderid, -- TRANSACCION id
        TXN.Contrato,  --contrato
        txn.linea_pedido, -- linea pedido
        cre.name,--regla credito
        --BOM APM 26.06.2023
        --Old Code cre.value,--valor credito
        --New Code
        TRIM(replace(to_char(cre.value , '9999999999990D99'), ',', '.')) VALOR,
        --EOM APM 26.06.2023
        TXN.CUPS, --CUPS
        TXN.Producto,  --producto
        TXN.Nombre_prd,  --producto DESCRIPCION
        txn.nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        TXN.LINEA_NEGOCIO, --linea negocio  
        TXN.TIPO_VENTA, -- tipo venta
        cre.GENERICATTRIBUTE16,--proveedor
        cre.GENERICATTRIBUTE1,-- num proveedor 
        cre.GENERICATTRIBUTE4, -- codigo alico
        TXN.Estado, -- estado
        TXN.fecha_alta, -- fecha alta 
       	case 
			when  cre.value is null or cre.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and cre.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDAD, --APM 27.06.2023
        PAR.LASTNAME AS DESCRIPCION_PROVEEDOR --DMS 26.07.2023
        
    FROM ENEL_TXN_TEMP_ALICO TXN
        INNER JOIN ENEL_CREDIT_TEMP_ALICO CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
            and txn.periodseq=cre.periodseq
            
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = TXN.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ = bu.processingunitseq 
            and TXN.businessunitmap = bu.mask
        INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
        
        INNER JOIN CS_participant par
            ON par.payeeseq  = CRE.payeeseq 
            AND  CRE.tenantid = txn.tenantid
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
      WHERE 
		cre.periodseq = iperiodseq 
        --and BU.NAME LIKE '%CAT%PTG' OR BU.NAME LIKE 'ALICO PTG'
        and txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
    ;

    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_CREDITOS_INCEN_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);
end;

procedure p_Informe_Cuadre_Liq_Cat_Recepcion( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2)
as
begin
    w_debug('Inicio Borrado de la tabla ENEL_CUADRELIQ_CAT_RECEPCION.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CUADRELIQ_CAT_RECEPCION WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;

    w_debug('Fin Borrado de la tabla ENEL_CUADRELIQ_CAT_RECEPCION.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CUADRELIQ_CAT_RECEPCION. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CUADRELIQ_CAT_RECEPCION(  TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                                    REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                                    PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                                    PROCESSINGUNITSEQ, BUSINESSUNIT,
                                                    UNIDAD, --APM 27.06.2023
                                                    NOMBRE_PROVEEDOR,payeeseq,positionseq) --APM 04.07.2023
    
    SELECT 
        TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		TXN.orderid as orderid, -- TRANSACCION id
        TXN.Contrato,  --contrato
        txn.linea_pedido, -- linea pedido
        ECT.NAME,--regla credito
        --BOM APM 26.06.2023
        --ECT.VALUE,--valor credito
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) VALOR,
        --EOM APM 26.06.2023
        TXN.CUPS, --CUPS
        TXN.Producto,  --producto
        TXN.Nombre_prd,  --producto DESCRIPCION
        txn.nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        TXN.LINEA_NEGOCIO, --linea negocio  
        TXN.TIPO_VENTA, -- tipo venta
        ECT.GENERICATTRIBUTE2,--proveedor
        ECT.GENERICATTRIBUTE1,-- num proveedor 
        ECT.GENERICATTRIBUTE4, -- codigo alico
        TXN.Estado, -- estado
        TXN.fecha_alta, -- fecha alta 
       	case 
			when  ECT.value is null or ECT.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and ECT.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        etype.eventtypeid AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDAD, --APM 27.06.2023
        TXN.NOMBRE_PROVEEDOR,
        ect.payeeseq,
        ect.positionseq
        
    FROM ENEL_TXN_TEMP_ALICO_V2 TXN
        LEFT JOIN ENEL_CREDIT_TEMP_ALICO ECT
			ON ECT.SALESTRANSACTIONSEQ = TXN.SALESTRANSACTIONSEQ
            and ECT.SALESORDERSEQ=TXN.SALESORDERSEQ
            and ect.periodseq=txn.periodseq
            --AND ECT.COMPENSATIONDATE= TXN.COMPENSATIONDATE
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = TXN.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ = bu.processingunitseq 
            and TXN.businessunitmap = bu.mask
        INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
      WHERE 
		per.periodseq = iperiodseq 
        and BU.NAME LIKE '%CAT%PTG'
		; 

    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_CUADRELIQ_CAT_RECEPCION: '|| to_char(filas) || ' filas.', v_contador_debug);

--EOM APM 28.03.2025
 w_debug('Cargando Incentivos en la tabla ENEL_CUADRELIQ_CAT_RECEPCION. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CUADRELIQ_CAT_RECEPCION( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                                    REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                                    PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                                    PROCESSINGUNITSEQ, BUSINESSUNIT,
                                                    UNIDAD,NOMBRE_PROVEEDOR,payeeseq,positionseq)
    
    SELECT 
        inc.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		null,
		null,
		null as orderid, -- TRANSACCION id
        null,  --contrato
        null, -- linea pedido
        inc.NAME,--regla credito
        TRIM(replace(to_char(inc.VALUE , '9999999999990D99'), ',', '.')) VALOR,
        '1', --CUPS
        inc.genericattribute1 as Producto,  --producto
        null,  --producto DESCRIPCION
        null, -- DESCRIPCION PRODUCTO 2
        null, --linea negocio  
        null, -- tipo venta
        null,--proveedor
        null,-- num proveedor 
        null, -- codigo alico
        null, -- estado
        null, -- fecha alta 
       	case 
			when  inc.value is null or inc.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and inc.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        null, -- TIPO EVENTO
     	inc.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
        'EURO' as UNIDAD, --APM 27.06.2023
        par.lastname as NOMBRE_PROVEEDOR,
        inc.payeeseq,
        inc.positionseq
        
    FROM cs_incentive inc
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = inc.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on inc.PROCESSINGUNITSEQ = bu.processingunitseq 
            and inc.businessunitmap = bu.mask
        INNER JOIN CS_POSITION POS
            ON inc.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND inc.PAYEESEQ = POS.PAYEESEQ
            AND POS.REMOVEDATE = '01/01/2200'
        INNER JOIN CS_participant par
            ON par.payeeseq  = pos.payeeseq 
            AND par.REMOVEDATE = v_eot
             AND PAr.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAr.EFFECTIVEENDDATE >= PER.ENDDATE - 1
      WHERE 
		per.periodseq = iperiodseq 
        and BU.NAME LIKE '%CAT%PTG' --OR BU.NAME LIKE 'ALICO PTG'
        and inc.NAME like 'I%Rappel%'
		; 

    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga Incentivos de la tabla ENEL_CUADRELIQ_CAT_RECEPCION: '|| to_char(filas) || ' filas.', v_contador_debug);
--BOM APM 28.03.2025
end;

procedure p_Temporal_Creditos_Scaweb (  iprocessingUnitSeq IN VARCHAR2,  iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    vFechaAlta Date;
    v_fecInicioPeriodoSig date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_PTG.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_SCAWEB_LIQUIDACION_PTG WHERE PERIODO = iperiod AND ROWNUM <= 10000 AND PROCESSINGUNITSEQ=iprocessingunitseq;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_PTG.', v_contador_debug);
    
    -- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := SYSDATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fecInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    w_debug('Insertando CREDITOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_PTG.' ,  v_contador_debug);
    -- v2.0 Se cambia la tabla de origen CS_CREDIT  a la temporal ENEL_CREDIT_TEMP
    INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_PTG ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE,PROCESSINGUNITSEQ,
                                                    USERID)   
    SELECT 
        iperiod PERIODO,
        to_number(REPLACE(credtmp.GENERICATTRIBUTE2, ' integer','')) PROVEEDOR,
        to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
        credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        1 as CANTIDAD,
        ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
        to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
        '' as FechaBaja,
        '' as Telefono,
        -- En ajustes Manuales se pone el campo Observaciones credit.GA15
        case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end as Observaciones,
        null,
        credtmp.GENERICATTRIBUTE6,       --Provincia
        credtmp.VALUE  as REALVALUE,      -- Valor real sin tomar el valor absoluto para informe de revision  
        CREDTMP.PROCESSINGUNITSEQ,
        TMP_PDS.USERID as USERID --APM 20.02.2026

    FROM ENEL_CREDIT_TEMP_ALICO credtmp
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
            ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

    WHERE 
        credtmp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
        and credtmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)
        and (
            --CAT Emisión y ALICO:
            credtmp.CREDITTYPEID like 'Captacion - ALICO PTG%'
            or credtmp.CREDITTYPEID like 'Captacion ALICO PTG - %'
            or credtmp.CREDITTYPEID like 'Captacion - CAT Emision PTG%'
            or credtmp.CREDITTYPEID like 'Captacion CAT Emision PTG - %'
            --D2D:
            or credtmp.CREDITTYPEID like 'Captacion - D2D PTG%'
            or credtmp.CREDITTYPEID like 'Captacion - Lojas PTG%'
            or credtmp.CREDITTYPEID like 'Captacion - Stores PTG%'
            or credtmp.CREDITTYPEID like 'Captacion D2D PTG - %'
            or credtmp.CREDITTYPEID like 'Captacion Lojas PTG - %'
            or credtmp.CREDITTYPEID like 'Captacion Stores PTG - %'
            --CAT Recepcion:
            or credtmp.CREDITTYPEID like 'Captacion CAT Recep PTG - %'
            --Resellers y Online:
            or credtmp.CREDITTYPEID like 'Captacion - Resellers PTG%'
            or credtmp.CREDITTYPEID like 'Captacion - Online PTG%'
            or credtmp.CREDITTYPEID like 'Captacion Resellers PTG - %'
            or credtmp.CREDITTYPEID like 'Captacion Online PTG - %'
			)
	; 
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_SCAWEB_LIQUIDACION_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando INCENTIVOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_PTG.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_PTG ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE,processingUnitSeq,
                                                USERID)   
    SELECT 
        iperiod PERIODO,        
        TO_NUMBER(INCENTMP.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda             
        TO_CHAR(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        TO_CHAR(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
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
        INCENTMP.VALUE  AS REALVALUE,      -- Valor real sin tomar el valor absoluto para informe de revision
        iprocessingUnitSeq,
        TMP_PDS.USERID as USERID --APM 20.02.2026
            
    FROM ENEL_INCEN_TEMP_ALICO INCENTMP    
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS
            ON INCENTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and incentmp.payeeseq=tmp_pds.payeeseq
             
    WHERE (    
        INCENTMP.GENERICBOOLEAN1 = 1  -- Indica los Incentivos que se incluyen en pagos
        AND INCENTMP.GENERICATTRIBUTE1 IS NOT NULL  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)  
        AND INCENTMP.VALUE <> 0 -- Se filtran los incentivos que sean distintos de 0
        AND ( 
            --CAT Emisión y ALICO:
            INCENTMP.NAME LIKE 'I - Captacion CAT Emision PTG - Rappel%'
            OR INCENTMP.NAME LIKE 'I - Captacion CAT Emision PTG - TM2%Ajuste%'
            OR INCENTMP.NAME LIKE 'I - Captacion ALICO PTG - TM2%Ajuste%'
            --D2D:
            OR INCENTMP.NAME LIKE 'I - Captacion D2D PTG - Rappel%'
            OR INCENTMP.NAME LIKE 'I - Captacion D2D PTG - TM2%Ajuste%'
            OR INCENTMP.NAME LIKE 'I - Captacion Stores PTG - Rappel%'
            OR INCENTMP.NAME LIKE 'I - Captacion Stores PTG - TM2%Ajuste%'
            OR INCENTMP.NAME LIKE 'I - Captacion Stores PTG - Ricorrente%'
            --CAT Recepcion:
            OR INCENTMP.NAME LIKE 'I - Captacion CAT Recepcion PTG - Rappel%'
            --Resellers y Online:
            OR INCENTMP.NAME LIKE 'I - Captacion Resellers PTG - Rappel%'
            OR INCENTMP.NAME LIKE 'I - Captacion Resellers PTG - TM2%Ajuste%'
            OR INCENTMP.NAME LIKE 'I - Captacion Online PTG - Rappel%'
            OR INCENTMP.NAME LIKE 'I - Captacion Online PTG - TM2%Ajuste%'
            OR INCENTMP.NAME LIKE 'C - Captacion Online PTG - Importe Base%' --APM 16.03.2026
            OR INCENTMP.NAME LIKE 'I - Captacion Resellers PTG - TM2%' --APM 29.04.2026
			)
		-- MPR - se excluyen los incentivos de los Dashboards
        and incentmp.Name not like 'I - %PTG%Dashboards'
		);

    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_SCAWEB_LIQUIDACION_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
	

    
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_SCAWEB_LIQUIDACION_PTG',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION_PTG.',v_contador_debug);


end;

procedure p_Comparativa_Pagos_SCAWEB_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_COMP_SCAWEB_E4E_PTG.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_COMP_SCAWEB_E4E_PTG WHERE PERIODO = iperiod AND ROWNUM <= 10000 AND PROCESSINGUNITSEQ=IPROCESSINGUNITSEQ;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_SCAWEB_E4E_PTG.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_SCAWEB_E4E_PTG.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_PTG ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO, E4E_OPERACIONES, BUSINESSUNIT, PROCESSINGUNITSEQ, USERID)   
/* 01.08.2023 DCR v2.15 Quitamos truncados y redondearemos en informes */
    SELECT 
        T_SCAWEB.PERIODO,
        T_SCAWEB.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        TMP_PDS.PAYEEID,
        TMP_PDS.NOMBRE_FISCAL,
		round(IMPORTE_SCAWEB,2),
        case when T_E4E.POSITIVO_CON_CONTRATO is null then 0 else round(T_E4E.POSITIVO_CON_CONTRATO,2) end as Con_Contrato,
        case when T_E4E.POSITIVO_SIN_CONTRATO is null then 0 else round(T_E4E.POSITIVO_SIN_CONTRATO,2) end as Sin_Contrato,
        --case when E4ENT.VALUE is null then 0 else E4ENT.VALUE end as Negativo,
		-- MPR -- modificacion de negativos para que se agrupe la suma por proveedor y pds
		case when E4ENT.NEGATIVO is null then 0 else round(E4ENT.NEGATIVO,2) end as Negativo,
        case when T_E4E.OPERACIONES is null then 0 else round(T_E4E.OPERACIONES,2) end as Operaciones,
        T_E4E.BUSINESSUNIT,
        iprocessingUnitSeq,
        T_SCAWEB.USERID --APM 20.02.2026
        
    FROM
        ( select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros,
            SCA.USERID --APM 20.02.2026
            from ENEL_SCAWEB_LIQUIDACION_PTG sca where PERIODO = IPERIOD and PROCESSINGUNITSEQ=iprocessingUnitSeq
            group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO, SCA.USERID --APM 20.02.2026
        ) T_SCAWEB
        LEFT JOIN 
            (select TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, BUSINESSUNIT, PROCESSINGUNITSEQ,
				sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
				sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
				SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
				SUM(VALOR_OPERACIONES) AS OPERACIONES,
				SUM(VALOR_INSTALADORES) AS INSTALADORES,
				SUM(VALOR_AAFF) AS AAFF,
				SUM(VALOR_ALIADOS) AS ALIADOS
			from ENEL_E4E_DEPOSIT_PTG_TEMP 
			where periodseq=IPERIODSEQ and PROCESSINGUNITSEQ=iprocessingUnitSeq
			group by TRIM(IDPROVEEDOR), PDS, BUSINESSUNIT, PROCESSINGUNITSEQ 
            ) T_E4E
            
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
        /*  
        LEFT JOIN ENEL_E4E_NEGATIVOS_TEMP_PTG E4ENT
            ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.PDS)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)
            and T_SCAWEB.PERIODO = E4ENT.PERIODO
		*/
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
			from ENEL_E4E_NEGATIVOS_TEMP_PTG
			where periodseq=iperiodseq
			group by TRIM(IDPROVEEDOR), PDS
			)E4ENT
			ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.PDS)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)
            
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS
            ON T_SCAWEB.PDS=TMP_PDS.PDS

        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
            ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR)
		;        
      
    filas := sql%rowcount;
    COMMIT;
   
    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E_PTG.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_PTG ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO, E4E_OPERACIONES, E4E_INSTALADORES, E4E_AAFF, E4E_ALIADOS )   
    SELECT    
		T_E4E.PERIODO,
		T_E4E.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_E4E.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        round(T_SCAWEB.IMPORTE_SCAWEB,2),
        round(T_E4E.POSITIVO_CON_CONTRATO,2),
        round(T_E4E.POSITIVO_SIN_CONTRATO,2),
        round(T_E4E.NEGATIVO,2),
        round(T_E4E.OPERACIONES,2),
        round(T_E4E.INSTALADORES,2),
        round(T_E4E.AAFF,2),
        round(T_E4E.ALIADOS,2)
    FROM
        ( SELECT iperiod PERIODO, TRIM(IDPROVEEDOR)  AS IDPROVEEDOR, PDS, 
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NOT NULL THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NULL THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
            SUM(CASE WHEN VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
            SUM(VALOR_OPERACIONES) AS OPERACIONES,
            SUM(VALOR_INSTALADORES) AS INSTALADORES,
            SUM(VALOR_AAFF) AS AAFF,
            SUM(VALOR_ALIADOS) AS ALIADOS
            FROM ENEL_E4E_DEPOSIT_PTG_TEMP 
            WHERE PERIODSEQ = iperiodseq
            GROUP BY iperiod, TRIM(IDPROVEEDOR), PDS 
        ) T_E4E
            
        LEFT JOIN
            ( SELECT 
				PERIODO,
                TRIM( TO_CHAR(PROVEEDOR,'000')) IDPROVEEDOR,
                SCA.CODIGO_AGENTE_INTERNO AS PDS,
                SUM(REALVALUE) AS IMPORTE_SCAWEB,
                COUNT(*) REGISTROS
                FROM ENEL_SCAWEB_LIQUIDACION_PTG SCA
                WHERE PERIODO = iperiod            
                GROUP BY PERIODO, TRIM( TO_CHAR(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO             
            ) T_SCAWEB
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
			          
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS
            ON T_E4E.PDS = TMP_PDS.PDS

        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
            ON TRIM(TMP_PROV.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR)
    
	WHERE T_SCAWEB.IMPORTE_SCAWEB IS NULL;
      
    filas := sql%rowcount;
    COMMIT;
   
    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_SCAWEB_E4E_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_COMP_SCAWEB_E4E_PTG',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_SCAWEB_E4E_PTG.',v_contador_debug);

         
end;      


procedure p_Cabecera_Ficheros_E4E (  iperiod IN VARCHAR2, iFichero IN VARCHAR2 )
AS
    contador integer;  
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_PTG para fichero ' || iFichero ,  v_contador_debug);
    contador := 1;
    -- Registro de CABECERA 1 : lista de campos
    INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)--,PROCESSINGUNITSEQ)
	VALUES (iperiod,contador,'CAMPO1','CAMPO2','CAMPO3','CAMPO4','CAMPO5','CAMPO6','CAMPO7','CAMPO8','CAMPO9',
		'CAMPO10','CAMPO11','CAMPO12','CAMPO13','CAMPO14','CAMPO15','CAMPO16','CAMPO17','CAMPO18','CAMPO19','CAMPO20','CAMPO21','CAMPO22',iFichero, 'BUSINESSUNIT');--,'PROCESSINGUNITSEQ');

    -- Registro de CABECERA 2 : CABECERA
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)--,PROCESSINGUNITSEQ)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','CABECERA','Contrato','Fecha Pedido','','Sociedad','Cod. Proveedor','CECO Aprob.',
	'Org.Compras','Gr.Compras','Riesgo','Contract Manager','Sit.Trabajo','Nota Cab.','','','','','','','',iFichero, 'BUSINESSUNIT');--,'PROCESSINGUNITSEQ');

    -- Registro de CABECERA 3 : POSICION    
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
							   CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)--,PROCESSINGUNITSEQ)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','POSICION','Contrato','','Pos. contrato','Tipo Imp.','Codigo','Texto breve',
	'Texto posicion','Cantidad','Unidad medida','Fecha entrega','Centro log.','Imputacion','Tipo impuesto','Ref. para proveedor','Num. Direccion',
	'Direccion','Poblacion','Cod. postal','Nom. solicitante',iFichero, 'BUSINESSUNIT');--,'PROCESSINGUNITSEQ');

    -- Registro de CABECERA 4 : SERVICIO
    contador := contador +1;
    INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
							   CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)--,PROCESSINGUNITSEQ)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','SERVICIO','Contrato','','Pos. contrato','Linea. Servicio','Cod. Servicio','Texto breve',
	'Cantidad','Imputacion','','','','','','','','','','','',iFichero, 'BUSINESSUNIT');--,'PROCESSINGUNITSEQ');        

    COMMIT;
    w_debug('Fin Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_PTG para fichero ' || iFichero ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Ficheros_E4E', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Ficheros_E4E', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;

procedure p_Final_E4E_1 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2,iprocessingUnitSeq IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(50);
    v_fechaInicioPeriodo date;
    v_fechaInicio date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- sera igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
    v_cabecera VARCHAR2(20); -- nueva variable para el control de la cabecera
    contadorPosicion integer; -- contador para la posicion
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_PTG.', v_contador_debug);
   
    --v_codFichero :='E4E1';  -- v2.0 se asigna el valor dinamicamente en funcion de la actividad del proveedor       
	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL_PTG WHERE ....';
	BEGIN
		LOOP
			DELETE FROM ENEL_E4E_FINAL_PTG WHERE PERIODO = iperiod AND FICHERO like 'E%1' AND ROWNUM <= 10000 AND (PROCESSINGUNITSEQ=IPROCESSINGUNITSEQ or processingunitseq=null);
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_PTG.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    v_fechaInicio := f_fecha_inicio(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_PTG. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_PTG. Fichero ' || v_codFichero ,  v_contador_debug);
    
	contadorE4E := 4;
	contadorECS := 4;
	contadorPosicion := 10;
     
    DECLARE
        CURSOR C_TMPDEPOSITOSFIX IS
            SELECT 
				PERIODSEQ,
				trunc(sum(VALUE),2) as value,
				PDS,
				PAR_PROVEEDOR,
				TIPO_IMPOSITIVO,
				COD_CONTRATO,
				POS_DOC,
				TEXTO_BREVE,
				ORG_COMPRAS,
				IDPROVEEDOR,
				SOCIEDAD,
				CECO,
				DESCRIPCION,
				GR_COMPRAS,
				CENTRO_LOGISTICO,
				WBE_FINAL_IMPUTACION,
				ACTIVIDAD,
				TIPO_PAGO,
				POS_FECHA_INI_VIGENCIA,
				CODIGO_SERVICIO,
				SUBPOSICION,
				BUSINESSUNIT,
                PROCESSINGUNITSEQ as PROCESSINGUNITSEQ

            FROM ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP_2
            WHERE PERIODSEQ = iperiodseq 
				AND COD_CONTRATO is not null      -- Fichero E4E1 contiene los registros con contrato
				AND VALUE > 0                     -- Fichero E4E se incluyen solo los positivos 
				AND IDPROVEEDOR not in ('019', '023', '031', '057', '083', '110','112', '115') -- MPR se excluye los proveedore para que no aparezcan en el fichero de captacion
            group by
				PERIODSEQ,
				PDS,
				PAR_PROVEEDOR,
				TIPO_IMPOSITIVO,
				COD_CONTRATO,
				POS_DOC,
				TEXTO_BREVE,
				ORG_COMPRAS,
				IDPROVEEDOR,
				SOCIEDAD,
				CECO,
				DESCRIPCION,
				GR_COMPRAS,
				CENTRO_LOGISTICO,
				WBE_FINAL_IMPUTACION,
				ACTIVIDAD,
				TIPO_PAGO,
				POS_FECHA_INI_VIGENCIA,
				CODIGO_SERVICIO,
				SUBPOSICION,
				BUSINESSUNIT,
                PROCESSINGUNITSEQ
			order by pds, idproveedor;
        
            REGDEPOSITOFIX C_TMPDEPOSITOSFIX%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOSFIX;
        FETCH C_TMPDEPOSITOSFIX INTO REGDEPOSITOFIX;
        
        WHILE C_TMPDEPOSITOSFIX%FOUND
        LOOP        
            -- Codigo de fichero
            CASE REGDEPOSITOFIX.ACTIVIDAD 
                WHEN 'STP'          THEN v_codFichero :='E4E1';
                WHEN 'SSII'         THEN v_codFichero :='E4E1';
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS1';
                WHEN 'CAPTACION'    THEN v_codFichero :='ECS1';
                WHEN 'ATC'          THEN v_codFichero :='ECS1';
                ELSE                     v_codFichero :='NOT1';
            END CASE;
                
            -- Se concatenan los valores que forman el codigo de referencia:
            --    YY + Codigo de PDS + Codigo de proveedor + Codigo de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITOFIX.PDS || REGDEPOSITOFIX.IDPROVEEDOR || v_codMes;

            -- Se determina el codigo de equivalencia del tipo impositivo
            if (v_fechaInicio>= to_date('01/01/2017','dd/mm/yyyy') AND v_fechaInicio <=to_date('28/02/2019', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITOFIX.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
            if (v_fechaInicio>= to_date('01/03/2019','dd/mm/yyyy')  AND v_fechaInicio <=to_date('30/11/2019','dd/mm/yyyy')) THEN
                CASE REGDEPOSITOFIX.TIPO_IMPOSITIVO 
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA PTG'      THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
			if (v_fechaInicio>= to_date('01/12/2019','dd/mm/yyyy') AND v_fechaInicio <=to_date('01/01/2200', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITOFIX.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA PTG'      THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITOFIX.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITOFIX.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
             
            -- MPR - Se concatenan los valores que forman el codigo para que solo cargue una cabecera por pds + proveedor, independientemente de las wbe:
            -- Codigo de PDS + Codigo de proveedor
           
            IF v_cabecera is null then 
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;    
                
                INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITOFIX.COD_CONTRATO,
						v_txtFechaInicio,
						'',
						REGDEPOSITOFIX.SOCIEDAD,
						REGDEPOSITOFIX.PAR_PROVEEDOR,
						REGDEPOSITOFIX.CECO,
						REGDEPOSITOFIX.ORG_COMPRAS,
						REGDEPOSITOFIX.GR_COMPRAS,
						'NO',
						'',
						'RE',
						'','','','','','','','',v_codFichero,
						REGDEPOSITOFIX.BUSINESSUNIT,
                        REGDEPOSITOFIX.PROCESSINGUNITSEQ);
	
			ELSIF v_cabecera <> REGDEPOSITOFIX.PDS || REGDEPOSITOFIX.IDPROVEEDOR then      
				-- Registro de DATOS - CABECERA
				IF v_codFichero = 'E4E1' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
				ELSIF v_codFichero = 'ECS1' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
				END IF;    
            
				INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
											CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITOFIX.COD_CONTRATO,
						v_txtFechaInicio,
						'',
						REGDEPOSITOFIX.SOCIEDAD,
						REGDEPOSITOFIX.PAR_PROVEEDOR,
						REGDEPOSITOFIX.CECO,
						REGDEPOSITOFIX.ORG_COMPRAS,
						REGDEPOSITOFIX.GR_COMPRAS,
						'NO',
						'',
						'RE',
						'','','','','','','','',v_codFichero,
						REGDEPOSITOFIX.BUSINESSUNIT,
                        REGDEPOSITOFIX.PROCESSINGUNITSEQ);
				contadorPosicion := 10;
			ELSE
				contadorPosicion := contadorPosicion+10;
			END IF;

			-- Registro de DATOS - POSICION
			IF v_codFichero = 'E4E1' then
				contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS1' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF; 
			
            INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
			VALUES ( iperiod,
					contadorTabla,
					v_referencia,    --CAMPO1
					--'10',
					contadorPosicion,
					'POSICION', 
					REGDEPOSITOFIX.COD_CONTRATO, --CAMPO4
					'',
					REGDEPOSITOFIX.POS_DOC,
					'P',                      --CAMPO7
					'',
					REGDEPOSITOFIX.TEXTO_BREVE,  --CAMPO9
					REGDEPOSITOFIX.DESCRIPCION,  --CAMPO10
					-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
					CASE WHEN REGDEPOSITOFIX.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITOFIX.VALUE) END,  --CAMPO11
					'UA',
					v_txtFechaActual,
					REGDEPOSITOFIX.CENTRO_LOGISTICO,
					REGDEPOSITOFIX.WBE_FINAL_IMPUTACION,
					v_Impuesto,
					'','','','','','PT1Q_E900_00',v_codFichero,
					REGDEPOSITOFIX.BUSINESSUNIT,
                    REGDEPOSITOFIX.PROCESSINGUNITSEQ);            

            IF REGDEPOSITOFIX.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - POSICION
                IF v_codFichero = 'E4E1' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
                END IF; 
                
				INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
											CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						--'10',
						contadorPosicion,
						'SERVICIO', 
						REGDEPOSITOFIX.COD_CONTRATO,
						'',
						REGDEPOSITOFIX.POS_DOC,  -- CAMPO6
						CASE WHEN REGDEPOSITOFIX.SUBPOSICION IS NULL THEN '10' ELSE REGDEPOSITOFIX.SUBPOSICION END, -- CAMPO7
						REGDEPOSITOFIX.CODIGO_SERVICIO,  --CAMPO8
						REGDEPOSITOFIX.TEXTO_BREVE,
						to_char(REGDEPOSITOFIX.VALUE),  --CAMPO10
						REGDEPOSITOFIX.WBE_FINAL_IMPUTACION, -- CAMPO11
						'', '', '', '',                    -- CAMPO12 a 15
						'', '', '', '',                    -- CAMPO16 a 19
						'', '', '',                        -- CAMPO20 a 22
						v_codFichero,
						REGDEPOSITOFIX.BUSINESSUNIT,
                        REGDEPOSITOFIX.PROCESSINGUNITSEQ);
            END IF;
            
            v_cabecera := REGDEPOSITOFIX.PDS || REGDEPOSITOFIX.IDPROVEEDOR;
                       
            FETCH C_TMPDEPOSITOSFIX INTO REGDEPOSITOFIX;
            
        END LOOP;
                   
        CLOSE C_TMPDEPOSITOSFIX;
    END;
    
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
		p_Cabecera_Ficheros_E4E (  iperiod , 'E4E1' );
	end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
		p_Cabecera_Ficheros_E4E (  iperiod , 'ECS1' );
	end if;   
        
	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_PTG:  E4E1'|| to_char(contadorE4E) || ' -- ECS1'|| to_char(contadorECS) || ' filas.', v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_1', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_1', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;

procedure p_Final_E4E_2 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2,iprocessingUnitSeq IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(50);
    v_fechaInicioPeriodo date;
    v_fechaInicio date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- sera igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
    v_cabecera VARCHAR2(20); -- nueva variable para el control de la cabecera
    contadorPosicion integer; -- contador para la posicion
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_PTG.', v_contador_debug);
        
    --v_codFichero :='E4E2'; -- v2.0 se asigna el valor dinamicamente en funcion de la actividad del proveedor
   -- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL_PTG WHERE ....';
	BEGIN
		LOOP
			DELETE FROM ENEL_E4E_FINAL_PTG WHERE PERIODO = iperiod AND FICHERO like 'E%2'  AND ROWNUM <= 10000 AND PROCESSINGUNITSEQ=IPROCESSINGUNITSEQ;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_PTG.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    v_fechaInicio := f_fecha_inicio(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_PTG. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_PTG. Fichero ' || v_codFichero ,  v_contador_debug);
    
	contadorE4E := 4;
	contadorECS := 4;
	contadorPosicion := 10;
     
    DECLARE
        CURSOR C_TMPDEPOSITOSFIX IS
            SELECT 
				PERIODSEQ,
				trunc(sum(VALUE),2) as value,
				PDS,
				PAR_PROVEEDOR,
				TIPO_IMPOSITIVO,
				COD_CONTRATO,
				POS_DOC,
				TEXTO_BREVE,
				ORG_COMPRAS,
				IDPROVEEDOR,
				SOCIEDAD,
				CECO,
				DESCRIPCION,
				GR_COMPRAS,
				CENTRO_LOGISTICO,
				WBE_FINAL_IMPUTACION,
				ACTIVIDAD,
				TIPO_PAGO,
				POS_FECHA_INI_VIGENCIA,
				CODIGO_SERVICIO,
				SUBPOSICION,
				BUSINESSUNIT,
                PROCESSINGUNITSEQ
              
            FROM ENEL_E4E_DEPOSIT_PTG_TEMP_2
            WHERE PERIODSEQ = iperiodseq 
                  AND COD_CONTRATO is null          -- Fichero E4E2 contiene los registros sin contrato (valor nulo)
                  AND VALUE > 0                     -- Fichero E4E se incluyen solo los positivos
				  AND IDPROVEEDOR not in ('019', '023', '031', '057', '083', '110','112', '115')
            group by
				PERIODSEQ,
				PDS,
				PAR_PROVEEDOR,
				TIPO_IMPOSITIVO,
				COD_CONTRATO,
				POS_DOC,
				TEXTO_BREVE,
				ORG_COMPRAS,
				IDPROVEEDOR,
				SOCIEDAD,
				CECO,
				DESCRIPCION,
				GR_COMPRAS,
				CENTRO_LOGISTICO,
				WBE_FINAL_IMPUTACION,
				ACTIVIDAD,
				TIPO_PAGO,
				POS_FECHA_INI_VIGENCIA,
				CODIGO_SERVICIO,
				SUBPOSICION,
				BUSINESSUNIT,
                PROCESSINGUNITSEQ
			order by pds, idproveedor;
          
            REGDEPOSITOFIX C_TMPDEPOSITOSFIX%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOSFIX;
        FETCH C_TMPDEPOSITOSFIX INTO REGDEPOSITOFIX;
        
        WHILE C_TMPDEPOSITOSFIX%FOUND
        LOOP
            -- Codigo de fichero
            CASE REGDEPOSITOFIX.ACTIVIDAD 
                WHEN 'STP'          THEN v_codFichero :='E4E2';
                WHEN 'SSII'         THEN v_codFichero :='E4E2';                
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS2';
                WHEN 'CAPTACION'    THEN v_codFichero :='ECS2';
                WHEN 'ATC'          THEN v_codFichero :='ECS2';
                ELSE                     v_codFichero :='NOT2';
            END CASE;
            
            -- Se concatenan los valores que forman el codigo de referencia:
            --    YY + Codigo de PDS + Codigo de proveedor + Codigo de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITOFIX.PDS || REGDEPOSITOFIX.IDPROVEEDOR || v_codMes;

            -- Se determina el codigo de equivalencia del tipo impositivo
            if (v_fechaInicio>= to_date('01/01/2017','dd/mm/yyyy') AND v_fechaInicio <=to_date('28/02/2019', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITOFIX.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
            if (v_fechaInicio>= to_date('01/03/2019','dd/mm/yyyy')  AND v_fechaInicio <=to_date('30/11/2019','dd/mm/yyyy')) THEN
                CASE REGDEPOSITOFIX.TIPO_IMPOSITIVO 
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA PTG' 		THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
			if (v_fechaInicio>= to_date('01/12/2019','dd/mm/yyyy') AND v_fechaInicio <=to_date('01/01/2200', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITOFIX.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA PTG' 		THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := '';
                END CASE;
            END IF;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITOFIX.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITOFIX.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
            
            -- MPR - Se concatenan los valores que forman el codigo para que solo cargue una cabecera por pds + proveedor, independientemente de las wbe:
            -- Codigo de PDS + Codigo de proveedor
           
            IF v_cabecera is null then 
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E2' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;          
                             
                INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITOFIX.COD_CONTRATO,
						v_txtFechaInicio,
						'',
						REGDEPOSITOFIX.SOCIEDAD,
						REGDEPOSITOFIX.PAR_PROVEEDOR,
						REGDEPOSITOFIX.CECO,
						REGDEPOSITOFIX.ORG_COMPRAS,
						REGDEPOSITOFIX.GR_COMPRAS,
						'NO',
						'',
						'RE',
						'','','','','','','','',v_codFichero,
						REGDEPOSITOFIX.BUSINESSUNIT,
                         REGDEPOSITOFIX.PROCESSINGUNITSEQ);

            ELSIF v_cabecera <> REGDEPOSITOFIX.PDS || REGDEPOSITOFIX.IDPROVEEDOR then
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E2' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;          
                             
                INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITOFIX.COD_CONTRATO,
						v_txtFechaInicio,
						'',
						REGDEPOSITOFIX.SOCIEDAD,
						REGDEPOSITOFIX.PAR_PROVEEDOR,
						REGDEPOSITOFIX.CECO,
						REGDEPOSITOFIX.ORG_COMPRAS,
						REGDEPOSITOFIX.GR_COMPRAS,
						'NO',
						'',
						'RE',
						'','','','','','','','',v_codFichero,
						REGDEPOSITOFIX.BUSINESSUNIT,
                        REGDEPOSITOFIX.PROCESSINGUNITSEQ);
						
                contadorPosicion := 10;
            ELSE
                contadorPosicion := contadorPosicion+10;
            END IF;

            -- Registro de DATOS - POSICION
            
            IF v_codFichero = 'E4E2' then
                contadorE4E := contadorE4E +1;
                contadorTabla := contadorE4E;
            ELSIF v_codFichero = 'ECS2' then
                contadorECS := contadorECS +1;
                contadorTabla := contadorECS;
            END IF; 
            
            INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
			VALUES ( iperiod,
					contadorTabla,
					v_referencia,
					--'10',
					contadorPosicion,
					'POSICION', 
					REGDEPOSITOFIX.COD_CONTRATO,
					'',
					REGDEPOSITOFIX.POS_DOC,
					'P',
					'',
					REGDEPOSITOFIX.TEXTO_BREVE,
					REGDEPOSITOFIX.DESCRIPCION,
					-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
					CASE WHEN REGDEPOSITOFIX.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITOFIX.VALUE) END,  --CAMPO11
					'EUR',
					v_txtFechaActual,
					REGDEPOSITOFIX.CENTRO_LOGISTICO,
					REGDEPOSITOFIX.WBE_FINAL_IMPUTACION,
					v_Impuesto,
					'','','','','','PT1Q_E900_00',v_codFichero,
					REGDEPOSITOFIX.BUSINESSUNIT,
                    REGDEPOSITOFIX.PROCESSINGUNITSEQ);            

            IF REGDEPOSITOFIX.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - servicio
				IF v_codFichero = 'E4E2' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
                END IF;
             
                INSERT INTO ENEL_E4E_FINAL_PTG (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
											CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT,PROCESSINGUNITSEQ)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						--'10',
						contadorPosicion,
						'SERVICIO', 
						REGDEPOSITOFIX.COD_CONTRATO,
						'',
						REGDEPOSITOFIX.POS_DOC,  -- CAMPO6
						CASE WHEN REGDEPOSITOFIX.SUBPOSICION IS NULL THEN '10' ELSE REGDEPOSITOFIX.SUBPOSICION END,                     -- CAMPO7
						REGDEPOSITOFIX.CODIGO_SERVICIO,  --CAMPO8
						REGDEPOSITOFIX.TEXTO_BREVE,
						to_char(REGDEPOSITOFIX.VALUE),  --CAMPO10
						REGDEPOSITOFIX.WBE_FINAL_IMPUTACION, -- CAMPO11
						'', '', '', '',                    -- CAMPO12 a 15
						'', '', '', '',                    -- CAMPO16 a 19
						'', '', '',                        -- CAMPO20 a 22
						v_codFichero,
						REGDEPOSITOFIX.BUSINESSUNIT,
                        REGDEPOSITOFIX.PROCESSINGUNITSEQ);
            END IF;
            
            v_cabecera := REGDEPOSITOFIX.PDS || REGDEPOSITOFIX.IDPROVEEDOR;
                        
            FETCH C_TMPDEPOSITOSFIX INTO REGDEPOSITOFIX;
            
        END LOOP;
                   
        CLOSE C_TMPDEPOSITOSFIX;
    END;
    
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN    
        p_Cabecera_Ficheros_E4E (  iperiod , 'E4E2' );
    end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
        p_Cabecera_Ficheros_E4E (  iperiod , 'ECS2' );
    end if;   
    
	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_PTG:  E4E2'|| to_char(contadorE4E) || ' -- ECS2'|| to_char(contadorECS) || ' filas.', v_contador_debug);


        
end;

procedure p_Temporal_Contratos_E4E ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;   
begin
    
    v_finicio := current_timestamp();
    
    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRATOS_PTG_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRATOS_PTG_TEMP.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRATOS_PTG_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP(TENANTID,PERIODSEQ,ID,PDS,ACTIVIDAD_DETALLADA,ACTIVIDAD,
                                                CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
                                                ORG_COMPRAS,CONDICIONES_PAGO, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, SUBPOSICION)
    SELECT 
        itenantId TENANTID,
        iperiodseq PERIDOSEQ,
        C.CLASSIFIERID ID,
        GC.GENERICATTRIBUTE2 PDS,
        GC.GENERICATTRIBUTE5 ACTIVIDAD_DETALLADA,
        GC.GENERICATTRIBUTE4 ACTIVIDAD,
        GC.GENERICATTRIBUTE1 CIF,
        GC.GENERICATTRIBUTE3 COD_CONTRATO,
        GC.GENERICATTRIBUTE7 POS_DOC,
        GC.GENERICATTRIBUTE6 TEXTO_BREVE,
        GC.GENERICATTRIBUTE8 CODIGO_SERVICIO,
        GC.GENERICATTRIBUTE9 ORG_COMPRAS,
        GC.GENERICATTRIBUTE10 CONDICIONES_PAGO,            
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
        GC.GENERICATTRIBUTE12 SUBPOSICION
            
    FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
            -- AND C.ISLAST = 1
        
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
            -- AND GC.ISLAST = 1               
            
    WHERE UPPER(GCT.NAME) ='CONTRATO'
        AND GCT.TENANTID = itenantId;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRATOS_PTG_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_CONTRATOS_PTG_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP.',v_contador_debug);


end;

procedure p_Temporal_E4E_Negativos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_PTG.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG_2 WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_PTG.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Origen de ENEL_E4E_NEGATIVOS_TEMP_PTG : CS_DEPOSIT.', v_contador_debug);
    -- Si se ejecuta en la FASE REWARD Utilizamos la tabla de depositos para generar los datos de las tablas porque aun no se han realizado los PAGOS
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
                                                PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
                                                POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        --sum(case when b.NEGATIVO > 0 then 0 else NEGATIVO end), 
		sum(DEPO.VALUE),
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, 
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO

    --FROM ENEL_DEPOSIT_PTG_TEMP DEPO
        FROM ENEL_DEPOSIT_TEMP_PTG DEPO --APM 09.10.2025
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA  
        LEFT JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
		
	
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
         and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','277',
              '278', '279', '280')--APM 09.10.2025
        -- APM 25.04.24 AÑADO WBE 268     
              
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO;
                      
    filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
                                                PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
                                                POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, --------------
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO

    --FROM ENEL_DEPOSIT_PTG_TEMP DEPO
        FROM ENEL_DEPOSIT_TEMP_PTG DEPO --APM 09.10.2025
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.wbe  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA  
        LEFT JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
        -- filtro de proveedores de Elsa 
		  and depo.wbe Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','277',
              '278', '279', '280')--APM 09.10.2025
         -- APM 25.04.24 AÑADO WBE 268     
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO;
                      
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG.',v_contador_debug);
	
	w_debug('Origen de ENEL_E4E_NEGATIVOS_TEMP_PTG_2 : CS_DEPOSIT.', v_contador_debug);
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG_2 ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
													PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO,processingunitseq  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        --sum(case when b.NEGATIVO > 0 then 0 else NEGATIVO end), 
		sum(DEPO.VALUE),
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, 
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        depo.processingunitseq

    --FROM ENEL_DEPOSIT_PTG_TEMP DEPO
        FROM ENEL_DEPOSIT_TEMP_PTG DEPO --APM 09.10.2025
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA  
        LEFT JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
		
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
       and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277',
              '278', '279', '280')     
-- DCR 09.09.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen   
        -- APM 25.04.24 AÑADO WBE 268
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        --TMP_PROV.WBE_FINAL_IMPUTACION,
		DEPO.wbe,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        depo.processingunitseq;
                      
    filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_PTG_2: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG_2 ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
													PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO,processingunitseq  )
    Select
        DEPO.PERIODSEQ,
        DEPO.PERIODO, 
        MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,          
        DEPO.tipo_pago_ga5, 
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        depo.processingunitseq

    --FROM ENEL_DEPOSIT_PTG_TEMP DEPO
        FROM ENEL_DEPOSIT_TEMP_PTG DEPO --APM 09.10.2025
        INNER JOIN ENEL_PDS_TEMP_ALICO TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.wbe  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA  
        LEFT JOIN ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        --AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  
        -- filtro de proveedores de Elsa 
		and depo.wbe Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256'
              ,'257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275','277',
              '278', '279', '280') 
-- DCR 09.09.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
        -- APM 25.04.24 AÑADO WBE 268
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.PERIODO, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ,  
        -- TMP_PDS.PAYEEID,
        TMP_PDS.PDS,
        TMP_PDS.PAR_PROVEEDOR,
        TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.FICHERO,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        TMP_PROV.DETALLE_ACTIVIDAD,           
        DEPO.TIPO_PAGO_GA5,
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        depo.processingunitseq;
                      
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_PTG.',v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_E4E_Negativos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_E4E_Negativos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;

procedure p_Final_E4E_Negativos ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodoSig date;
    v_txtFechaInicioPeriodoSig VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_maxIDPEDIDO integer;    
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_NEGATIVOS_PTG.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_PTG WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_NEGATIVOS_PTG.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodoSig := to_char(v_fechaInicioPeriodoSig, 'DD/MM/YYYY');
    
    -- Se convierte a texto el año YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodoSig, 'YY');
    
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodoSig);
    
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodoSig ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    select NVL(MAX(IDPEDIDO),0) into v_maxIDPEDIDO  from ENEL_E4E_NEGATIVOS_PTG WHERE ESTADO='LIQUIDADO';
    w_debug('Numero maximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) ,  v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_E4E_NEGATIVOS_PTG.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_PTG ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, PDS, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
                                              SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
                                              CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
                                              CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION,processingunitseq  )   
    SELECT 
        e4edt.PERIODSEQ,
        e4edt.PERIODO,
        e4edt.DEPOSITSEQ,
        e4edt.POSITIONSEQ,
        e4edt.PAYEESEQ, 
        e4edt.PDS,
        v_maxIDPEDIDO + rownum as IDPEDIDO,
        e4edt.ORG_VENTAS,
        CASE WHEN COMUNIDAD_AUTONOMA = 'CANARIAS' THEN 'CA' ELSE 'CO' END AS CANAL_DISTRIBUCION,
        '39' as SECTOR,
        'ZOAL' as CLASE_PEDIDO,
        '' AS FACTURA_REF,
        e4edt.CODIGODEUDOR Solicitante_ShipTo,
        e4edt.CODIGODEUDOR Solicitante_SoldTo,
        v_txtYear || e4edt.PDS || e4edt.IDPROVEEDOR || v_codMes as NUM_PEDIDO,
        v_txtFechaActual FechaPedido,
        v_txtFechaActual FechaFactura, 
        e4edt.CONDICIONES_PAGO,
        '' ContratoSEPA,
        '' MotivoPedido,
        'EUR' MONEDA,
        '10' POSICION,
        CASE e4edt.SOCIEDAD
            WHEN 'ES21' THEN 'ZES000013'
            WHEN 'ES29' THEN 'ZES000016'
            WHEN 'PT1Q' THEN 'ZPT000003'
            ELSE  ''
        END MATERIAL,     
        CASE e4edt.SOCIEDAD
            WHEN 'ES21' THEN 'RETROACCIÓN COM. ENDESA ENERGÍA'
            WHEN 'ES29' THEN 'RETROACCIÓN COM. EOSC'
            WHEN 'PT1Q' THEN 'RETROACCIÓN COM. E. E. PORTUGAL'
            ELSE  ''
        END TEXTO_MATERIAL,
        1 CANTIDAD,
        ABS(VALUE) as PRECIO,
        CASE 
            WHEN e4edt.TIPO_IMPOSITIVO ='IVA' THEN '1'
            WHEN e4edt.TIPO_IMPOSITIVO ='IVA Portugal' THEN 'H'
            ELSE   ''
        END CLASIF_FISCAL_IVA,
        CASE e4edt.TIPO_IMPOSITIVO
            WHEN 'IGIC' THEN '1'
            ELSE  ''
        END CLASIF_FISCAL_IGIC,    
        WBE_FINAL_IMPUTACION,
        e4edt.processingunitseq

    FROM ENEL_E4E_NEGATIVOS_TEMP_PTG_2 e4edt 
    
    WHERE 
        e4edt.VALUE < 0  and 
        e4edt.PERIODSEQ = iperiodseq;
               
     filas := sql%rowcount;
     COMMIT;
    
     w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);
     dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_NEGATIVOS_PTG',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
     w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_PTG.',v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_Negativos', v_finicio, current_timestamp(), null);
EXCEPTION
    WHEN others THEN
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_Negativos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;     
   

procedure p_Temporal_Creditos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP_ALICO.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CREDIT_TEMP_ALICO';
	w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP_ALICO.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP_ALICO. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CREDIT_TEMP_ALICO( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, 
												POSITIONSEQ, COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, 
												GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, 
												GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,
												GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICBOOLEAN1, GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3,
                                                GENERICNUMBER5,PROCESSINGUNITSEQ)
	SELECT 
        credit.TENANTID,
		credit.PERIODSEQ,
		iperiod PERIODO,
		credit.PIPELINERUNSEQ,
		credit.PIPELINERUNDATE,
		case when ince.name is not null then ince.name else credit.NAME end name,
		CREDIT.CREDITSEQ,
		CREDIT.SALESORDERSEQ,        
		CREDIT.SALESTRANSACTIONSEQ,
		CREDIT.PAYEESEQ,
		CREDIT.POSITIONSEQ,
		CREDIT.COMPENSATIONDATE,
		CREDIT.COMMENTS,                --v2.3
		CTYPE.CREDITTYPEID,           
		CTYPE.DESCRIPTION,             -- Tipo de Comisión
		case when commi.value is not null then commi.VALUE else credit.value end as importe,
		credit.PREADJUSTEDVALUE,
		credit.GENERICATTRIBUTE1,      -- Concepto Liquidación
		credit.GENERICATTRIBUTE2,      -- Proveedor
		credit.GENERICATTRIBUTE3,      -- Servicio
		credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
		credit.GENERICATTRIBUTE5,      -- Plazo
		credit.GENERICATTRIBUTE6,      -- Provincia
		credit.GENERICATTRIBUTE7,      -- Zona
		credit.GENERICATTRIBUTE8,      -- Producto
		credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
		credit.GENERICATTRIBUTE10,     -- Equipamiento            
		credit.GENERICATTRIBUTE11,     -- CodigoPostal
		credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
		credit.GENERICATTRIBUTE13,     --MotivoResultado
		credit.GENERICATTRIBUTE14,     --Descripción Concepto Liquidación
		case when ince.name is not null then ince.genericattribute3 else credit.GENERICATTRIBUTE15 end as observaciones,
        credit.GENERICATTRIBUTE16,      --proveedor
		credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
		credit.GENERICBOOLEAN2,        -- S/S Garantía
		credit.GENERICDATE1,           --FechaCalculo
--BOM APM 14.09.2023
--Old Code        
		--credit.GENERICNUMBER1,
--New Code        
        case
            when ince.genericnumber3 is not null then ince.genericnumber3
            else 0
        end as GENERICNUMBER1,
--EOM APM 14.09.2023   
		credit.GENERICNUMBER2,
		credit.GENERICNUMBER3,
        credit.GENERICNUMBER5,
        iprocessingunitseq

	FROM CS_CREDIT credit
		INNER JOIN CS_PLRUN p 
			ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
		INNER JOIN CS_CREDITTYPE ctype 
			ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
            
		LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = CREDIT.CREDITSEQ
            AND COMMI.PAYEESEQ = CREDIT.PAYEESEQ
        
		LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ
	
	WHERE
		credit.TENANTID = itenantId 
		AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND credit.PERIODSEQ =  iperiodseq; 

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP_ALICO: '|| to_char(filas) || ' filas.', v_contador_debug);

end;
procedure p_Temporal_Depositos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS    
begin
    
    v_finicio := current_timestamp();
    
    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_PTG_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_PTG_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_PTG_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_PTG_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_DEPOSIT_PTG_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
                                            PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5, processingunitseq, wbe, BUSINESSUNITMAP )
    SELECT
        depo.TENANTID,
        depo.PERIODSEQ,
        iperiod PERIODO,
        depo.PIPELINERUNSEQ,
        depo.PIPELINERUNDATE,
        depo.DEPOSITSEQ ,
        depo.PAYEESEQ,
        depo.POSITIONSEQ,
        depo.NAME,
        depo.VALUE,                  --Importe
        depo.PREADJUSTEDVALUE,
        depo.EARNINGCODEID,
        depo.genericattribute6 idproveedor,
        --depo.EARNINGGROUPID,
        depo.COMMENTS,
        depo.GENERICATTRIBUTE1,      -- Actividad
        depo.GENERICATTRIBUTE2,
        depo.GENERICATTRIBUTE5,
        depo.processingunitseq,
        depo.EARNINGGROUPID wbe, 
		DEPO.BUSINESSUNITMAP
        
    FROM CS_DEPOSIT depo
        INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Añadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
    WHERE
        depo.TENANTID = itenantId 
        AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND depo.PERIODSEQ =  iperiodseq;
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_PTG_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_DEPOSIT_PTG_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_PTG_TEMP.',v_contador_debug);


end;         

procedure p_Cuadre_Liq_Online (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2  , iInterfaz IN VARCHAR2 )
AS

begin
    w_debug('Inicio Borrado de la tabla ENEL_CUADRE_LIQ_ONLINE.', v_contador_debug);    
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CUADRE_LIQ_ONLINE WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;     
    w_debug('Fin Borrado de la tabla ENEL_CUADRE_LIQ_ONLINE.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CUADRE_LIQ_ONLINE. Periodo:'|| iperiod ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_CUADRE_LIQ_ONLINE( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, CONTRATO, LINEA_PEDIDO,
                                             REGLA, VALOR,  CUPS , PRODUCTO, NOMBRE_PRD, NOMBRE_PRD2, LINEA_NEGOCIO, TIPO_VENTA ,
                                             PROVEEDOR, NUM_PROVEEDOR, CODIGO_ALICO, ESTADO, FECHA_ALTA, ESTADO_LIQUIDACION , TIPO_EVENTO,
                                             PROCESSINGUNITSEQ, BUSINESSUNIT , TASA_CONV,  
                                             UNIDADES, --APM 06.07.2023
                                             PARTICIPANTE) --APM 13.09.2023
    SELECT 
		TXN.TENANTID ,
        iperiodseq,       --periodseq
        iperiod,      -- name
		TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		TXN.orderid as orderid, -- TRANSACCION id
        TXN.Contrato as Contrato,  --contrato
        txn.linea_pedido as linea_pedido, -- linea pedido
        ect.name,--regla
        TRIM(replace(to_char(ect.VALUE , '9999999999990D99'), ',', '.')) VALOR, 
        TXN.CUPS as CUPS, --CUPS
        TXN.Producto as Producto,  --producto
        TXN.Nombre_prd as Nombre_prd,  --producto DESCRIPCION
        txn.nombre_PRD2 as nombre_PRD2, -- DESCRIPCION PRODUCTO 2
        TXN.LINEA_NEGOCIO as LINEA_NEGOCIO, --linea negocio  
        TXN.TIPO_VENTA as Nombre_Servicio, -- tipo venta
--BOM APM 13.09.2023
--Old Code        
        --ect.GENERICATTRIBUTE2,--proveedor
--New Code 
        TXN.proveedor, --proveedor Código Proveedor en el informe
--EOM APM 13.09.2023        
		ect.GENERICATTRIBUTE1,-- num proveedor 
        ect.GENERICATTRIBUTE4, -- codigo alico
        TXN.Estado as Estado, -- estado
        TXN.fecha_alta as fecha_alta, -- fecha alta 
       	case 
			when  ect.value is null or ect.GENERICATTRIBUTE1 is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value  is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado_Liquidacion,   --estado liquidación
        TXN.TIPO_EVENTO AS TIPO_EVENTO , -- TIPO EVENTO
     	TXN.PROCESSINGUNITSEQ, --PU
        BU.NAME AS BUSINESS_UNIT, -- BU
--BOM APM 14.09.2023
--Old Code          
        --TXN.TASA_CONV, -- TASA CONVERSION 
--New Code
        trunc(ECT.GENERICNUMBER1*100, 2),
--EOM APM 14.09.2023
        TXN.UNIDADES, --APM 06.07.2023
        TXN.PARTICIPANTE --APM 13.09.2023
    FROM ENEL_TXN_TEMP_ONLINE TXN
    LEFT JOIN ENEL_CREDIT_TEMP_ALICO ECT
			ON ECT.SALESTRANSACTIONSEQ = TXN.SALESTRANSACTIONSEQ
            and ECT.SALESORDERSEQ=TXN.SALESORDERSEQ
         Inner Join cs_period per
            on per.name= iperiod 
            and per.periodseq= iperiodseq 
            and per.periodseq = TXN.periodseq 
            AND per.REMOVEDATE = '01/01/2200'
         Inner join cs_businessunit bu  
            on TXN.PROCESSINGUNITSEQ = bu.processingunitseq 
            and TXN.businessunitmap = bu.mask
        INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
        INNER JOIN TCMP.CS_CREDIT CRE    
            ON txn.SALESTRANSACTIONSEQ = CRE.SALESTRANSACTIONSEQ  
            AND txn.tenantid = itenantId  
            AND txn.PROCESSINGUNITSEQ = iprocessingUnitSeq
       
      WHERE 
		per.periodseq = iperiodseq 
        and BU.NAME LIKE 'Online PTG'
		; 

    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_CUADRE_LIQ_ONLINE: '|| to_char(filas) || ' filas.', v_contador_debug);
end;
--EOM APM 15.05.2023

--BOM APM 26.06.2023
---------------- Actualizamos la tabla que indica la fecha y hora de actualizaci¿n del informes-------------
procedure p_Actualiza_Informe_Fecha ( iPeriod IN VARCHAR2, iInforme IN varchar2)
AS
    
begin

    MERGE INTO ENELEXT.ENEL_FECHAS_WEBI tabla
    USING (SELECT iPeriod as mes, iInforme as tabla from dual) condicion
    ON (tabla.periodo = condicion.mes and tabla.tabla=condicion.tabla)
    WHEN MATCHED THEN UPDATE SET
    tabla.ultima_actualizacion = FROM_TZ(CAST(sysdate AS TIMESTAMP), to_char(cast(systimestamp as TIMESTAMP WITH TIME ZONE),'TZH:TZM')) AT TIME ZONE 'Europe/Madrid'
    WHEN NOT MATCHED THEN
    INSERT  (periodo, tabla, ultima_actualizacion, descripcion)
    VALUES  (
    condicion.mes,
    condicion.tabla,
    FROM_TZ(CAST(sysdate AS TIMESTAMP), to_char(cast(systimestamp as TIMESTAMP WITH TIME ZONE),'TZH:TZM')) AT TIME ZONE 'Europe/Madrid',
    'Ultima carga de la tabla '|| iInforme
    );

    COMMIT;

    w_debug('Fin carga ENELEXT.ENEL_FECHAS_WEBI para Informe: ' ||iInforme,v_contador_debug );
    
    
end;
--EOM APM 26.06.2023

--BOM APM 07.08.2025
/*procedure p_Temporal_Contratos_E4E_PTG ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;   
begin
    
    v_finicio := current_timestamp();
    
    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_PTG.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP_PTG';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_PTG.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRATOS_TEMP_PTG. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_E4E_CONTRATOS_TEMP_PTG(TENANTID,PERIODSEQ,ID,PDS,ACTIVIDAD_DETALLADA,ACTIVIDAD,
                                                CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
                                                ORG_COMPRAS,CONDICIONES_PAGO, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, SUBPOSICION)
    SELECT 
        itenantId TENANTID,
        iperiodseq PERIDOSEQ,
        C.CLASSIFIERID ID,
        GC.GENERICATTRIBUTE2 PDS,
        GC.GENERICATTRIBUTE5 ACTIVIDAD_DETALLADA,
        GC.GENERICATTRIBUTE4 ACTIVIDAD,
        GC.GENERICATTRIBUTE1 CIF,
        GC.GENERICATTRIBUTE3 COD_CONTRATO,
        GC.GENERICATTRIBUTE7 POS_DOC,
        GC.GENERICATTRIBUTE6 TEXTO_BREVE,
        GC.GENERICATTRIBUTE8 CODIGO_SERVICIO,
        GC.GENERICATTRIBUTE9 ORG_COMPRAS,
        GC.GENERICATTRIBUTE10 CONDICIONES_PAGO,            
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
        GC.GENERICATTRIBUTE12 SUBPOSICION
            
    FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
            -- AND C.ISLAST = 1
        
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
            -- AND GC.ISLAST = 1               
            
    WHERE UPPER(GCT.NAME) ='CONTRATO'
        AND GCT.TENANTID = itenantId;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRATOS_TEMP_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_CONTRATOS_TEMP_PTG',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRATOS_TEMP_PTG.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Contratos_E4E_PTG', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Contratos_E4E_PTG', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;*/

---------- Tabla ENEL_PROVEEDORES_TEMP_PTG ----
/*procedure p_Temporal_Proveedores_PTG ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    
    v_finicio := current_timestamp();
    
    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP_PTG.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_PTG';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP_PTG.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP_PTG. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP_PTG( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
                                                WBE_FINAL_IMPUTACION,DETALLE_ACTIVIDAD,ACTIVIDAD,SOCIEDAD,
                                                CENTRO_LOGISTICO,GR_COMPRAS,TIPO_PAGO, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR,subactividad)
    SELECT 
        itenantId TENANTID,
        iperiodseq PERIDOSEQ,
        C.CLASSIFIERID IDPROVEEDOR,
        C.NAME DESCRIPCION,
        GC.GENERICATTRIBUTE8 DESCRIPCION_CORTA,
        C.DESCRIPTION FICHERO,
        GC.GENERICATTRIBUTE1 CECO,
        GC.GENERICATTRIBUTE2 WBE_FINAL_IMPUTACION,
        GC.GENERICATTRIBUTE3 DETALLE_ACTIVIDAD,
        GC.GENERICATTRIBUTE4 ACTIVIDAD,
        GC.GENERICATTRIBUTE5 SOCIEDAD,
        GC.GENERICATTRIBUTE6 CENTRO_LOGISTICO, 
        GC.GENERICATTRIBUTE7 GR_COMPRAS,
        GC.GENERICATTRIBUTE8 TIPO_PAGO,  -- Nuevo v2.0  
        GC.GENERICATTRIBUTE9 ORG_VENTAS, -- Nuevo v2.0            
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
        GC.GENERICATTRIBUTE10
        
    FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C 
            ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
            -- AND C.ISLAST = 1
      
        INNER JOIN CS_GENERICCLASSIFIER GC 
            ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            --  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
            -- AND GC.ISLAST = 1
         
    WHERE 
		UPPER(GCT.NAME) like 'PROVEEDOR%'
        AND UPPER(GC.GENERICATTRIBUTE4) not like '%TELEVENTA';
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PROVEEDORES_TEMP_PTG',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP_PTG.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Proveedores_PTG', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Proveedores_PTG', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;*/

---------- Tabla ENEL_DEPOSIT_TEMP_PTG ----
procedure p_Temporal_Depositos_PTG (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS    
begin
    
    v_finicio := current_timestamp();
    
    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP_PTG.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_PTG';
    w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP_PTG.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP_PTG. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP_PTG( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
                                            PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5, processingunitseq, wbe, BUSINESSUNITMAP )
    SELECT
        depo.TENANTID,
        depo.PERIODSEQ,
        iperiod PERIODO,
        depo.PIPELINERUNSEQ,
        depo.PIPELINERUNDATE,
        depo.DEPOSITSEQ ,
        depo.PAYEESEQ,
        depo.POSITIONSEQ,
        depo.NAME,
        depo.VALUE,                  --Importe
        depo.PREADJUSTEDVALUE,
        depo.EARNINGCODEID,
        depo.genericattribute6 idproveedor,
        --depo.EARNINGGROUPID,
        depo.COMMENTS,
        depo.GENERICATTRIBUTE1,      -- Actividad
        depo.GENERICATTRIBUTE2,
        depo.GENERICATTRIBUTE5,
        depo.processingunitseq,
        depo.EARNINGGROUPID wbe, 
		DEPO.BUSINESSUNITMAP
        
    FROM CS_DEPOSIT depo
        INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Añadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
    WHERE
        depo.TENANTID = itenantId 
        AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND depo.PERIODSEQ =  iperiodseq;
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP_PTG: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_DEPOSIT_TEMP_PTG',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP_PTG.',v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_PTG', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_PTG', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;

procedure p_Temporal_Depositos_E4E_PTG ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz_Proceso  IN VARCHAR2)
AS    
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_DEPOSIT_PTG_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP';
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP_2';
    w_debug('Fin Truncado de la tabla ENEL_E4E_DEPOSIT_PTG_TEMP y ENEL_E4E_DEPOSIT_PTG_TEMP_2.', v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_DEPOSIT_PTG_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    -- Si se ejecuta en una FASE que no es REWARD Utilizamos la tabla de PAGOS
    w_debug('Origen de ENEL_E4E_DEPOSIT_PTG_TEMP : NO ELSA.', v_contador_debug);

	INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT, PROCESSINGUNITSEQ )
    Select
        DEPO.PERIODSEQ,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(depo.VALUE),
        case when bu.name='Stores PTG' then TMP_PDS.PDS ELSE TMP_PDS.PAYEEID END,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        IPROCESSINGUNITSEQ AS PROCESSINGUNITSEQ
          
    FROM  ENELEXT.ENEL_DEPOSIT_TEMP_PTG DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_ALICO TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
             
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
        and depo.tipo_pago_ga5 is not null
		and depo.value > 0
        --and length(PAYM.EARNINGGROUPID) >3
        and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275',
              '278', '279', '280','281','282','283')
-- DMS 25.05.23 AÑADO WBE 258,259,260
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- DCR 29.06.23 AÑADO WBE 264
-- DCR 30.06.23 AÑADO WBE 265
-- APM 25.04.24 AÑADO WBE 268
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        case when bu.name='Stores PTG' then TMP_PDS.PDS ELSE TMP_PDS.PAYEEID END,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,       
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;     
        
    filas := sql%rowcount;
    COMMIT;
    --END IF;
	
	w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_PTG_TEMP no Elsa: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP( PERIODSEQ, POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT, PROCESSINGUNITSEQ )
    Select
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        case when bu.name='Stores PTG' then TMP_PDS.PDS ELSE TMP_PDS.PAYEEID END,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ---
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.WBE = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        IPROCESSINGUNITSEQ AS PROCESSINGUNITSEQ
          
    FROM  ENELEXT.ENEL_DEPOSIT_TEMP_PTG DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_ALICO TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.WBE  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
			           
    WHERE 
        DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
        and depo.tipo_pago_ga5 is not null
		and depo.value <> 0
       
        and depo.wbe Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','270','271','272','273','274','275',
              '278', '279', '280','281','282','283')
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.WBE,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        case when bu.name='Stores PTG' then TMP_PDS.PDS ELSE TMP_PDS.PAYEEID END,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ----
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;   
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_PTG_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_PTG_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP.',v_contador_debug);
	
	-- Carga de depositos neto. Suma los depositos totales para que E4E solo tenga el valor neto
	w_debug('Cargando tabla ENEL_E4E_DEPOSIT_PTG_TEMP_2. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Origen de ENEL_E4E_DEPOSIT_PTG_TEMP_2 : NO ELSA.', v_contador_debug);
	
	INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP_2 ( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT,PROCESSINGUNITSEQ  )
    Select
        DEPO.PERIODSEQ,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(depo.VALUE),
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        IPROCESSINGUNITSEQ AS PROCESSINGUNITSEQ
          
    FROM  ENELEXT.ENEL_DEPOSIT_TEMP_PTG DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_ALICO TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
             
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
        and depo.tipo_pago_ga5 is not null
		--and depo.value > 0
        and DEPO.EARNINGGROUPID in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256',
              '257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275',
              '278', '279', '280','281','282','283')
-- DMS 23.05.23 AÑADO EL WBE 258,259 Y 260
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- DCR 29.06.23 AÑADO WBE 264
-- DCR 30.06.23 AÑADO WBE 265
-- DMS 27.11.23 WBE 261
-- APM 25.04.24 AÑADO WBE 268
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        depo.wbe,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,       
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;     
        
    filas := sql%rowcount;
    COMMIT;
    --END IF;
	
	w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_PTG_TEMP_2 no Elsa: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP_2 ( PERIODSEQ, POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, VALOR_INSTALADORES, VALOR_AAFF, 
												VALOR_ALIADOS, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS, CONDICIONES_PAGO, SUBPOSICION, BUSINESSUNIT,PROCESSINGUNITSEQ  )                        
    Select
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(DEPO.VALUE), 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ---
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN DEPO.WBE = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN DEPO.VALUE ELSE 0 END) as VALOR_OPERACIONES,
        -- Se separa el valor de las INSTALADORES para mostralo en el BALANCE
        sum(CASE WHEN (TMP_PDS.TIPO_POSICION = 'CNS' OR TMP_PDS.TIPO_POSICION = 'SW') THEN DEPO.VALUE ELSE 0 END) as VALOR_INSTALADORES,
        -- Se separa el valor de las AAFF para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'AAFF' THEN DEPO.VALUE ELSE 0 END) as VALOR_AAFF,
        -- Se separa el valor de las ALIADOS para mostralo en el BALANCE
        sum(CASE WHEN TMP_PDS.TIPO_POSICION = 'ALICO' THEN DEPO.VALUE ELSE 0 END) as VALOR_ALIADOS,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        CASE BU.NAME 
            WHEN 'ENDESA OPV' THEN 'EOPV'
            WHEN 'CCPP Comercializacion' THEN 'CCPP'
            WHEN 'ALICO' THEN 'ALIC'
            WHEN 'Endesa X' THEN 'ENDX'
            WHEN 'CAT TVTA' THEN 'CATT'
            WHEN 'Administracion Callidus' THEN 'ADMC'
            ELSE BU.NAME
        END AS BUSINESS_UNIT,
        IPROCESSINGUNITSEQ AS PROCESSINGUNITSEQ
          
    FROM  ENELEXT.ENEL_DEPOSIT_TEMP_PTG DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_ALICO TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_ALICO TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_PTG_TEMP TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
			           
    WHERE 
        DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
        and depo.tipo_pago_ga5 is not null
		--and depo.value > 0
       
        and depo.EARNINGGROUPID Not in ('004', '011', '012', '015', '017', '019', '023', '031', '032', 
              '036', '040', '041', '042', '043', '044', '045', '050', '052', '053', '057', '080', 
              '083', '091', '100', '110', '112', '115', '120', '126', '127', '129', '130', '131', 
              '132', '133', '134', '135', '136', '137', '138', '176', '179', '180', '181', '201',
			  '242','243','244','245','246', '247', '249','250','251','252', '254', '255', '256'
              ,'257','258','259','260','261','262', '264', '265', '268','270','271','272','273','274','275',
              '278', '279', '280','281','282','283')
-- DMS 23.05.23 AÑADO EL WBE 258,259 Y 260
-- DCR 08.08.22 Añado el WBE 254 a peticion de carmen
-- RMM 15.09.22 Añado el WBE 257 a peticion de carmen
-- DCR 29.06.23 AÑADO WBE 264
-- DCR 30.06.23 AÑADO WBE 265
--DMS 27.11.23 WBE 261
-- APM 25.04.24 AÑADO WBE 268
    GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.WBE,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PAYEEID,
        TMP_PDS.PAR_PROVEEDOR, 
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_PROV.GR_COMPRAS, 
        TMP_PROV.CENTRO_LOGISTICO, 
        TMP_PROV.WBE_FINAL_IMPUTACION,
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ----
        TMP_PDS.FECHA_INI_VIGENCIA,
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        TMP_CONTRA.SUBPOSICION,
        BU.NAME;   
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_PTG_TEMP_2: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_PTG_TEMP_2',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_PTG_TEMP_2.',v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_E4E_PTG', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_E4E_PTG', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;
--EOM APM 07.08.2025

--BOM APM 11.03.2026
/*procedure p_informe_agrupado (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_txtFechaLiquidacion VARCHAR2(10);
begin

    w_debug('Inicio Borrado de la tabla ENEL_DEPOSIT_AGRUPADO.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_DEPOSIT_AGRUPADO WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_DEPOSIT_AGRUPADO.', v_contador_debug);
    
    w_debug('Inicio Borrado de la tabla ENEL_INCENT_AGRUPADO.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_INCENT_AGRUPADO WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_INCENT_AGRUPADO.', v_contador_debug);

	v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
    w_debug('Cargando tabla ENEL_DEPOSIT_AGRUPADO. Periodo:'|| iperiod ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_DEPOSIT_AGRUPADO(PROCESSINGUNITSEQ, PERIODO, PERIODSEQ, COD_COMERCIAL, REGLA, VALUE, UNIDAD, FECHA_LIQUIDACION,
                                            ESTADO, COD_RETRIBUCION, LINEA_NEGOCIO, CANAL, GRUPO_RETRIBUCION)
    
    SELECT
        depo.PROCESSINGUNITSEQ,
        iperiod PERIODO,
        depo.PERIODSEQ,
        POS.NAME AS COD_COMERCIAL,
        depo.NAME AS REGLA,
        depo.VALUE AS VALUE, 
        'EURO',
        v_txtFechaLiquidacion AS FECHA_LIQUIDACION,
        case 
            when depo.VALUE is null then 'Pte Revisar'
            when iInterfaz ='ACTUALIZA_INFORMES_POST' and depo.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        depo.EARNINGCODEID AS COD_RETRIBUCION,
        depo.GENERICATTRIBUTE6 AS LINEA_NEGOCIO,
        POS.GENERICATTRIBUTE7 AS CANAL,
        depo.EARNINGGROUPID AS GRUPO_RETRIBUCION --APM 09/01/2026
        
    FROM CS_DEPOSIT depo
        INNER JOIN CS_PLRUN p 
            ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND p.tenantid = itenantId
            
     INNER JOIN CS_PERIOD per
            on per.periodseq = depo.periodseq
            and per.removedate= '01/01/2200'
            
        INNER JOIN cs_position pos
            ON pos.payeeseq = depo.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = depo.tenantid
            and POS.PROCESSINGUNITSEQ =  depo.processingUnitSeq           
			AND pos.EFFECTIVEENDDATE >= per.enddate
    WHERE
        depo.TENANTID = itenantId 
        AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND depo.PERIODSEQ =  iperiodseq;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_AGRUPADO: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCENT_AGRUPADO. Periodo:'|| iperiod ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_INCENT_AGRUPADO(PROCESSINGUNITSEQ, PERIODO, PERIODSEQ, COD_COMERCIAL, TIPO_INCENTIVO, REGLA, ALTAS,
                                            BAJAS, INCENTIVO, IMPORTE_UNITARIO,UNIDAD, VALUE, UNIDAD_1, FECHA_LIQUIDACION, LINEA_NEGOCIO, CANAL)
    
    SELECT
        incent.PROCESSINGUNITSEQ,
        iperiod PERIODO,
        incent.PERIODSEQ,
        POS.NAME AS COD_COMERCIAL,
        incent.GENERICATTRIBUTE1 AS TIPO_INCENTIVO,
        incent.NAME AS REGLA,
        incent.GENERICNUMBER1 AS ALTAS,
        incent.GENERICNUMBER2 AS BAJAS,
        incent.GENERICNUMBER3 AS INCENTIVO,
        incent.GENERICNUMBER5 AS IMPORTE_UNITARIO,
        'EURO',
        incent.VALUE AS VALUE, 
        'EURO',
        v_txtFechaLiquidacion AS FECHA_LIQUIDACION,
        incent.GENERICATTRIBUTE2 AS LINEA_NEGOCIO,
        POS.GENERICATTRIBUTE7 AS CANAL
        
    FROM CS_INCENTIVE incent
        INNER JOIN CS_PLRUN p 
            ON incent.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND p.tenantid = itenantId
            
     INNER JOIN CS_PERIOD per
            on per.periodseq = incent.periodseq
            and per.removedate= '01/01/2200'
            
        INNER JOIN cs_position pos
            ON pos.payeeseq = incent.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = incent.tenantid
            and POS.PROCESSINGUNITSEQ =  incent.processingUnitSeq           
			AND pos.EFFECTIVEENDDATE >= per.enddate
    WHERE
        incent.TENANTID = itenantId 
        AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND incent.PERIODSEQ =  iperiodseq;

    w_debug('Fin Carga de la tabla ENEL_INCENT_AGRUPADO: '|| to_char(filas) || ' filas.', v_contador_debug);
end;*/
--EOM APM 11.03.2026


END ENEL_ACTUALIZA_INFORMES_ALICO;