create or replace PACKAGE BODY ENEL_ACTUAL_INFORMES_CAT_TVTA as

/* *****************************************************************************
   NAME:       ENEL_ACTUAL_INFORMES_CAT_TVTA
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/10/2019  RMF               Created this package.
   
   1.1        11.03.2022  DCR               Nuevo Informe WBE (CAL0124)
   
   1.2        29.03.2022  DCR               Informe Prefactura (CAL0130)
                                            Portada Detalle - Quitar comisiones
                                            
   1.3        19.04.2022  DCR               Inf. Pref. Detalle Campo Producto (CAL0134)
   
   1.4        24.05.2022  DCR               Se añaden Ajustes Manuales a Prefactura Detalle
   
   1.5        20.06.2022  DCR               Se añade Cod. Position a Prefactura Detalle
   
   1.6        14.07.2022  RMM               Se eliminan duplicados en Prefactura 

   1.7        10.01.2023  RMM               Se eliminan el estado liquidado en CAT TVTA ya que no se liquidan por callidus
   
   1.8        15.03.2023  APM               Se añade Fecha actualización en el procedure p_Inf_CAT_TVTA_RESUMEN_PAGO
   
   1.9        12.02.2024  APM               Se añade la llamada al procedure p_Actualiza_Informe_Fecha al final del último
                                            procedura para tener la fecha/hora de la actualización de la última tabla.
                                            
   1.10       15.04.2025  APM               Se añade nuevo filtro en la tabla ENEL_CAT_TVTA_RESUM_PAGO
   
   1.11       16.04.2025  APM               Se comenta el insert a la tabla ENEL_LEADS_CAT_TVTA.
   
   1.12       09.12.2025  APM               Nuevas tablas para informe Balance CAT TVTA E4E
   
   1.13       03.03.2026  APM               Informar tablas para Informe Agrupado de liquidaciones
   
   1.14       19.03.2026  APM               Cambios para Mas Orange
   
   1.15       24.04.2026  APM               Añadir filtros de tipo de crédito en la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA para activación

   1.16       14.05.2026  APM               Se añade filtro en la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA 
   
   1.17       19.05.2026  APM               Se añade filtro en la tabla ENEL_CAT_TVTA_RESUM_PAGO
   
   1.18       20.05.2026  APM               Se quita filtro en la tabla ENEL_INFORME_TRANSACCION
***************************************************************************** */

    v_contador_debug NUMBER;
    v_eot DATE := TO_DATE('22000101','yyyymmdd');
    v_classifierid          CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION           CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                 CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA             CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS            CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD          CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO                CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas NUMBER;--Para DEBUG

procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
	proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG  
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;

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
			and gc.REMOVEDATE  = v_eot  and gc.islast=1
		
		inner join CS_CATEGORY_CLASSIFIERS ccc on  ccc.CLASSIFIERSEQ = c.CLASSIFIERSEQ 
			and ccc.TENANTID = 'ENEL' 
			and CCC.REMOVEDATE= v_eot and CCC.ISLAST=1
				
		inner join CS_CATEGORYTREE ct on CCC.CATEGORYTREESEQ=CT.CATEGORYTREESEQ 
			and ct.TENANTID = 'ENEL' 
			and ct.REMOVEDATE= v_eot and ct.ISLAST=1
				
		INNER JOIN CS_GENERICCLASSIFIERTYPE GCT ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
			AND C.TENANTID = 'ENEL' 
			AND C.REMOVEDATE = v_eot
				
	Where 
		CT.NAME='Salida' 
		AND GCT.NAME ='Interfaz'
		and GCT.TENANTID = 'ENEL' 
		and c.classifierid=iInterfaz 
		and c.REMOVEDATE= v_eot and c.ISLAST=1
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

-- Se calcula el primer día del mes siguiente al actual 
function f_Primer_Dia_Periodo_Siguiente(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT ADD_MONTHS( PER.STARTDATE , 1 ) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
	AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
	return v_Primer_Dia;
end;
  
function f_ExisteInformeEnLista(iInforme in varchar2, iListaInformes in varchar2 ) return boolean as   
    v_existe BOOLEAN;    
begin  
    -- Si lista de INFORMES es 'ALL', se devuelve como que existe siempre
    IF iListaInformes = 'ALL' THEN
        v_existe := true;
	-- Si el nombre del informe existe en la lista que se ha pasado como parametro (ejecución manual), se devuelve que existe (true)   
	ELSIF INSTR( iListaInformes, iInforme ) > 0 THEN 	
		v_existe := true;
	-- Si el nombre del informe no existe en la lista que se ha pasado como parametro (ejecución manual), se devuelve que no existe (false)
	ELSE 
		v_existe := false;
    END IF; 

    if v_existe then
        w_debug(' SI ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    else
        w_debug(' NO ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    end if;
    
    return v_existe;
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
  
-- Comrpueba si el periodo está Liquidado ya o no. Si está Liquidado, los datos de andrómeda no deben actualizarse
function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
	v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin
	-- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
	SELECT count(ESTADO)
		into v_checkCountEstado
	FROM ENELEXT.ENEL_PER_LIQUIDADOS_CAT_TVTA epl 
	WHERE 
		epl.PERIODO = iperiod 
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

function f_CodigoMes(idate date) return varchar2 as
    v_CodigoMes varchar2(1);
begin
	-- Se extrae un código de mes de modo que Enero es A , Febrero B .... hasta Diciembre que es L
    -- ASCII('A') = 65  y ASCII('L') = 76
    -- Metodo:
    --  Se extrae numero de mes: extract(month from idate) 
    --  Se suma 64 y ese código ascci se convierte a carácter con chr

	SELECT chr(extract(month from idate) + 64)
		INTO  v_CodigoMes
	FROM DUAL;  

	return v_CodigoMes;
end;

-- BOM CAL0124 DCR 11.03.22
function f_fecha_inicio(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT PER.STARTDATE INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
    AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
    return v_Primer_Dia;
end;
-- EOM CAL0124 DCR 11.03.22

procedure p_Temporal_Proveedores ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP_CAT_TVTA', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_CAT_TVTA';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP_CAT_TVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP_CAT_TVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP_CAT_TVTA( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
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
		GCT.NAME  like 'Proveedor%';
		
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PROVEEDORES_TEMP_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP_CAT_TVTA.',v_contador_debug);
end;

procedure p_Temporal_Payee (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
	w_debug('Inicio Truncado de la tabla ENEL_PAYEE_TEMP_CAT_TVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PAYEE_TEMP_CAT_TVTA';
    w_debug('Fin Truncado de la tabla ENEL_PAYEE_TEMP_CAT_TVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PAYEE_TEMP_CAT_TVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PAYEE_TEMP_CAT_TVTA( PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PROCESSINGUNITSEQ, PAYEEID, POS_NAME, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
												PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, ID_CENTRO_E4E, IMPORTE_UB, FECHA_CONTRATACION, 
												TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
												BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION )
	SELECT 
		PER.PERIODSEQ, 
		POS.RULEELEMENTOWNERSEQ, 
		PAR.PAYEESEQ,
		POS.PROCESSINGUNITSEQ,
		PAYEE.PAYEEID, 
		POS.NAME POS_NAME, 
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
		PAR.GENERICATTRIBUTE10 AS ID_CENTRO_E4E,--NOMBRE_COMERCIAL
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
		TIT.GENERICATTRIBUTE2 AS TIPO_POSICION

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
		and par.GENERICATTRIBUTE1 is not null;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PAYEE_TEMP_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PAYEE_TEMP_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PAYEE_TEMP_CAT_TVTA.',v_contador_debug);
end;    

procedure p_Temporal_Productos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_PRODUCTOS_TEMP_CAT_TVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PRODUCTOS_TEMP_CAT_TVTA';
    w_debug('Fin Truncado de la tabla ENEL_PRODUCTOS_TEMP_CAT_TVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PRODUCTOS_TEMP_CAT_TVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PRODUCTOS_TEMP_CAT_TVTA( TENANTID, PERIODSEQ, PRODUCTID, DESCRIPTION, NAME, FAMILIA, PROVEEDOR_PRESTACION, PROVEEDOR_CAPTACION, 
													SEGMENTO, TIPO, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR)
	SELECT 
		itenantId TENANTID,
		iperiodseq PERIODSEQ,
		C.CLASSIFIERID AS PRODUCTID,
		C.DESCRIPTION,
		C.NAME,
		PROD.GENERICATTRIBUTE1 as FAMILIA,
		PROD.GENERICATTRIBUTE2 as PROVEEDOR_PRESTACION,
		PROD.GENERICATTRIBUTE3 as PROVEEDOR_CAPTACION,
		PROD.GENERICATTRIBUTE4 as SEGMENTO,
		PROD.GENERICATTRIBUTE5 as TIPO,
		C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
		C.EFFECTIVEENDDATE FECHA_FIN_VIGOR

	FROM CS_PRODUCT PROD 
		INNER JOIN CS_CLASSIFIER C 
			ON C.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ
			AND C.TENANTID = itenantId
			AND C.REMOVEDATE = v_eot
			AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo                                     
			--AND C.ISLAST = 1

	WHERE 
		PROD.REMOVEDATE = v_eot
		AND PROD.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
		AND PROD.EFFECTIVEENDDATE >= v_ultimo_dia_periodo; 

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PRODUCTOS_TEMP_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);  
end;

procedure p_Temporal_Depositos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP_CAT_TVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_CAT_TVTA';
    w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP_CAT_TVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP_CAT_TVTA. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP_CAT_TVTA( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
													PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5, 
													processingunitseq, BUSINESSUNITMAP, PROVEEDOR_GA6 )
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
		depo.EARNINGGROUPID,
		depo.COMMENTS,
		depo.GENERICATTRIBUTE1,      -- Actividad
		depo.GENERICATTRIBUTE2,
		depo.GENERICATTRIBUTE5,
		depo.processingunitseq,
		DEPO.BUSINESSUNITMAP,
        DEPO.GENERICATTRIBUTE6

	FROM CS_DEPOSIT depo
		INNER JOIN CS_PLRUN p 
			ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
	WHERE
		depo.TENANTID = itenantId 
		AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND depo.PERIODSEQ =  iperiodseq;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_DEPOSIT_TEMP_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP_CAT_TVTA.',v_contador_debug);
end;

procedure p_Temporal_Contratos_E4E ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRA_TEMP_CAT_TVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRA_TEMP_CAT_TVTA';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRA_TEMP_CAT_TVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRA_TEMP_CAT_TVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_E4E_CONTRA_TEMP_CAT_TVTA(TENANTID,PERIODSEQ,ID,POS_NAME,ACTIVIDAD_DETALLADA,ACTIVIDAD,
													CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
													ORG_COMPRAS,CONDICIONES_PAGO, SUBPOSICION, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, GR_COMPRAS_GA11)
	SELECT 
		itenantId TENANTID,
		iperiodseq PERIDOSEQ,
		C.CLASSIFIERID ID,
		GC.GENERICATTRIBUTE2 POS_NAME,
		GC.GENERICATTRIBUTE5 ACTIVIDAD_DETALLADA,
		GC.GENERICATTRIBUTE4 ACTIVIDAD,
		GC.GENERICATTRIBUTE1 CIF,
		GC.GENERICATTRIBUTE3 COD_CONTRATO,
		GC.GENERICATTRIBUTE7 POS_DOC,
		GC.GENERICATTRIBUTE6 TEXTO_BREVE,
		GC.GENERICATTRIBUTE8 CODIGO_SERVICIO,
		GC.GENERICATTRIBUTE9 ORG_COMPRAS,
		GC.GENERICATTRIBUTE10 CONDICIONES_PAGO,
		GC.GENERICATTRIBUTE12 SUBPOSICION,            
		C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
		C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
        GC.GENERICATTRIBUTE11 GR_COMPRAS

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

	WHERE GCT.NAME ='Contrato' ;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRA_TEMP_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_CONTRA_TEMP_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRA_TEMP_CAT_TVTA.',v_contador_debug);
end;

procedure p_Temporal_Depositos_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2)
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
	
	-- Si se ejecuta en una FASE que no es REWARD Utilizamos la tabla de PAGOS
	w_debug('Origen de ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP : CS_PAYMENT.', v_contador_debug);

	INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP( PERIODSEQ,DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,POS_NAME,
													PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA,
													VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, SUBPOSICION, ID_CENTRO_E4E, BUSINESSUNIT,POS_ID  )
	Select
		DEPO.PERIODSEQ, 
		--MAX(PAYM.PAYMENTSEQ),
		MAX(DEPO.DEPOSITSEQ),
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ, 
		ROUND(sum(DEPO.VALUE),2), 
		TMP_PAYEE.PAYEEID,
		TMP_PAYEE.PAR_PROVEEDOR, 
		TMP_PAYEE.TIPO_IMPOSITIVO,
		TMP_CONTRA.COD_CONTRATO, 
		TMP_CONTRA.POS_DOC, 
		--TMP_CONTRA.TEXTO_BREVE,
		TMP_PROV.ACTIVIDAD AS TEXTO_BREVE, 
		TMP_CONTRA.ORG_COMPRAS,
		TMP_CONTRA.CODIGO_SERVICIO,
		TMP_PROV.IDPROVEEDOR,
		TMP_PROV.SOCIEDAD, 
		TMP_PROV.CECO, 
		TMP_PROV.DESCRIPCION, 
		TMP_CONTRA.GR_COMPRAS_GA11, 
		TMP_PROV.CENTRO_LOGISTICO, 
		DEPO.EARNINGGROUPID,
		DEPO.GENERICATTRIBUTE1 AS ACTIVIDAD, --ACTIVIDAD DEL DEPOSITO, NO DEL PROVEEDOR
		DEPO.TIPO_PAGO_GA5,        ---
		TMP_PAYEE.FECHA_INI_VIGENCIA,
		0 as VALOR_OPERACIONES,-------
		TMP_PAYEE.CODIGODEUDOR,
		TMP_PAYEE.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
		TMP_CONTRA.SUBPOSICION,
		TMP_PAYEE.ID_CENTRO_E4E,
		CASE BU.NAME 
			WHEN 'ENDESA OPV' THEN 'EOPV'
			WHEN 'CCPP Comercializacion' THEN 'CCPP'
			WHEN 'ALICO' THEN 'ALIC'
			WHEN 'Endesa X' THEN 'ENDX'
			WHEN 'CAT TVTA' THEN 'CATT'
			WHEN 'Administracion Callidus' THEN 'ADMC'
			ELSE BU.NAME
		END AS BUSINESS_UNIT,
        TMP_PAYEE.POS_NAME

	--FROM CS_PAYMENT PAYM
	FROM enel_deposit_temp_CAT_TVTA DEPO
		INNER JOIN CS_PLRUN p 
			ON DEPO.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion

		INNER JOIN ENEL_PAYEE_TEMP_CAT_TVTA TMP_PAYEE 
			ON DEPO.payeeseq=TMP_PAYEE.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PAYEE.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PAYEE.periodseq

		INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.PROVEEDOR_GA6  
			AND DEPO.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRA_TEMP_CAT_TVTA TMP_CONTRA
			ON TMP_CONTRA.periodseq=DEPO.periodseq
			AND TMP_CONTRA.POS_NAME = TMP_PAYEE.POS_NAME                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq

		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK

	WHERE 
		DEPO.TENANTID = itenantId
		AND DEPO.periodseq=iperiodseq
		--AND DEPO.value >= 0        
		AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
		and depo.tipo_pago_ga5 is not null
		and TMP_PAYEE.PROCESSINGUNITSEQ = iprocessingUnitSeq

	GROUP BY 
        DEPO.PERIODSEQ, 
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PAYEE.PAYEEID,
        TMP_PAYEE.PAR_PROVEEDOR, 
        TMP_PAYEE.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        --TMP_CONTRA.TEXTO_BREVE,
        TMP_PROV.ACTIVIDAD, 
        TMP_CONTRA.ORG_COMPRAS,
        TMP_CONTRA.CODIGO_SERVICIO,
        TMP_PROV.IDPROVEEDOR,
        TMP_PROV.SOCIEDAD, 
        TMP_PROV.CECO, 
        TMP_PROV.DESCRIPCION, 
        TMP_CONTRA.GR_COMPRAS_GA11, 
        TMP_PROV.CENTRO_LOGISTICO, 
        DEPO.EARNINGGROUPID,
        DEPO.GENERICATTRIBUTE1,
        DEPO.TIPO_PAGO_GA5,        ----
        TMP_PAYEE.FECHA_INI_VIGENCIA,
		TMP_PAYEE.CODIGODEUDOR,
		TMP_PAYEE.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
		TMP_CONTRA.SUBPOSICION,
		TMP_PAYEE.ID_CENTRO_E4E,
		BU.NAME,
        TMP_PAYEE.POS_NAME
	--HAVING SUM(DEPO.VALUE) >= 0 --RMM 12.07.2022
	;     

	filas := sql%rowcount;
	COMMIT;
    --END IF;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP.',v_contador_debug);
end;

procedure p_Temporal_E4E_Negativos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iprocessingUnitSeq IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_E4E_NEG_TEMP_CAT_TVTA.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEG_TEMP_CAT_TVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_E4E_NEG_TEMP_CAT_TVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Origen de ENEL_E4E_NEG_TEMP_CAT_TVTA : CS_DEPOSIT.', v_contador_debug);
    -- Si se ejecuta en la FASE REWARD Utilizamos la tabla de depositos para generar los datos de las tablas porque aun no se han realizado los PAGOS
	INSERT INTO ENELEXT.ENEL_E4E_NEG_TEMP_CAT_TVTA(    PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,POS_NAME,
                                                PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
                                                POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, SUBPOSICION, ID_CENTRO_E4E, BUSINESSUNIT  )
	Select
		DEPO.PERIODSEQ,
		DEPO.PERIODO, 
		MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ, 
		ROUND(sum(DEPO.VALUE),2), 
		-- TMP_PDS.PAYEEID,
		TMP_PAYEE.POS_NAME,
		TMP_PAYEE.PAR_PROVEEDOR,
		TMP_PAYEE.NOMBRE_FISCAL,
		TMP_PAYEE.CIF, 
		TMP_PAYEE.TIPO_IMPOSITIVO,
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
		DEPO.EARNINGGROUPID,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,          
		DEPO.tipo_pago_ga5, --------------
		TMP_PAYEE.FECHA_INI_VIGENCIA,
		0 as VALOR_OPERACIONES,
		TMP_PAYEE.CODIGODEUDOR,
		TMP_PAYEE.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
		TMP_CONTRA.SUBPOSICION,
		TMP_PAYEE.ID_CENTRO_E4E,
		CASE BU.NAME 
			WHEN 'ENDESA OPV' THEN 'EOPV'
			WHEN 'CCPP Comercializacion' THEN 'CCPP'
			WHEN 'ALICO' THEN 'ALIC'
			WHEN 'Endesa X' THEN 'ENDX'
			WHEN 'CAT TVTA' THEN 'CATT'
			WHEN 'Administracion Callidus' THEN 'ADMC'
			ELSE BU.NAME
		END AS BUSINESS_UNIT

	FROM ENEL_DEPOSIT_TEMP_CAT_TVTA DEPO
		INNER JOIN ENEL_PAYEE_TEMP_CAT_TVTA TMP_PAYEE 
			ON DEPO.payeeseq=TMP_PAYEE.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PAYEE.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PAYEE.periodseq
			AND TMP_PAYEE.PROCESSINGUNITSEQ = iprocessingUnitSeq

		INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.PROVEEDOR_GA6  
			AND DEPO.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRA_TEMP_CAT_TVTA TMP_CONTRA
			ON TMP_CONTRA.periodseq=DEPO.periodseq
			AND TMP_CONTRA.POS_NAME = TMP_PAYEE.POS_NAME                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq

		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK

	WHERE 
		DEPO.TENANTID = itenantId
		AND DEPO.periodseq=iperiodseq 
		AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq       
		--AND DEPO.VALUE < 0    

	GROUP BY 
		DEPO.PERIODSEQ, 
		DEPO.PERIODO, 
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ,  
		TMP_PAYEE.POS_NAME,
		TMP_PAYEE.PAR_PROVEEDOR,
		TMP_PAYEE.NOMBRE_FISCAL,
		TMP_PAYEE.CIF, 
		TMP_PAYEE.TIPO_IMPOSITIVO,
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
		DEPO.EARNINGGROUPID,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,           
		DEPO.TIPO_PAGO_GA5,
		TMP_PAYEE.FECHA_INI_VIGENCIA,
		TMP_PAYEE.CODIGODEUDOR,
		TMP_PAYEE.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
		TMP_CONTRA.SUBPOSICION,
		TMP_PAYEE.ID_CENTRO_E4E,
		BU.NAME
		HAVING SUM(DEPO.VALUE) < 0
	;

	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_CAT_TVTA.',v_contador_debug);
end;

procedure p_Cabecera_Ficheros_E4E (  iperiod IN VARCHAR2, iFichero IN VARCHAR2 )
AS
    contador integer;  
begin
    w_debug('Inicio Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_CAT_TVTA para fichero ' || iFichero ,  v_contador_debug);
    contador := 1;
    -- Registro de CABECERA 1 : lista de campos
	INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO)
	VALUES (iperiod,contador,'CAMPO1','CAMPO2','CAMPO3','CAMPO4','CAMPO5','CAMPO6','CAMPO7','CAMPO8','CAMPO9',
			'CAMPO10','CAMPO11','CAMPO12','CAMPO13','CAMPO14','CAMPO15','CAMPO16','CAMPO17','CAMPO18','CAMPO19','CAMPO20','CAMPO21','CAMPO22',iFichero);

    -- Registro de CABECERA 2 : CABECERA
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','CABECERA','Contrato','Fecha Pedido','','Sociedad','Cod. Proveedor','CECO Aprob.',
			'Org.Compras','Gr.Compras','Riesgo','Contract Manager','Sit.Trabajo','Nota Cab.','','','','','','','',iFichero, '');

    -- Registro de CABECERA 3 : POSICION    
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','POSICION','Contrato','','Pos. contrato','Tipo Imp.','Código','Texto breve',
			'Texto posición','Cantidad','Unidad medida','Fecha entrega','Centro log.','Imputación','Tipo impuesto','Ref. para proveedor','Num. Dirección',
			'Dirección','Población','Cod. postal','Nom. solicitante',iFichero,'');

    -- Registro de CABECERA 4 : SERVICIO
    contador := contador +1;
    INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','SERVICIO','Contrato','','Pos. contrato','Línea. Servicio','Cod. Servicio','Texto breve',
			'Cantidad','Imputación','','','','','','','','','','','',iFichero,'');        

    COMMIT;
    w_debug('Fin Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_CAT_TVTA para fichero ' || iFichero ,  v_contador_debug);
end;

procedure p_Final_E4E_1 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(32);
    v_actividad VARCHAR2(3);
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(9);
    v_contador_cabecera NUMBER; --contador para la cabecera. Se reinicia con cada payee + actividad nuevo
    v_contador_orden_entrega NUMBER;
begin
    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_CAT_TVTA.', v_contador_debug);

	BEGIN
		LOOP
			DELETE FROM ENEL_E4E_FINAL_CAT_TVTA WHERE PERIODO = iperiod AND FICHERO = 'CAT_TVTA1' AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_CAT_TVTA.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');

    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_FINAL_CAT_TVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_CAT_TVTA. Fichero ' || v_codFichero ,  v_contador_debug);

	contadorE4E := 4;
	--contadorECS := 4;

    DECLARE
        CURSOR C_TMPPAYEE IS
            SELECT 
				DISTINCT POS_NAME, 
				ACTIVIDAD 
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
            WHERE 
				PERIODSEQ = iperiodseq
                AND COD_CONTRATO IS NOT NULL    -- Fichero E4E1 contiene los registros con contrato
              --  AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos -- rmm 13/072022
            ;
           
            v_reg_pos_name          VARCHAR2(255);
            v_reg_pos_actividad     VARCHAR2(255);
   
            
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
				PERIODSEQ,
				VALUE,
				POS_NAME,
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
				ID_CENTRO_E4E,
				BUSINESSUNIT
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
            WHERE 
				PERIODSEQ = iperiodseq 
				AND COD_CONTRATO is not null    -- Fichero E4E1 contiene los registros con contrato
				AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos --RMM 12.07.2022 Solicitan que aparezcan negativos tb
				AND POS_NAME = v_reg_pos_name
				AND ACTIVIDAD = v_reg_pos_actividad
            ORDER BY WBE_FINAL_IMPUTACION; 
            
			REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
       
    BEGIN
        OPEN C_TMPPAYEE;
        
        FETCH C_TMPPAYEE INTO v_reg_pos_name,v_reg_pos_actividad;
        WHILE C_TMPPAYEE%FOUND
        LOOP
            --Inicializamos contadores
            v_contador_cabecera := 0;
            v_contador_orden_entrega := 0;
            
            OPEN C_TMPDEPOSITOS;
            FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
            WHILE C_TMPDEPOSITOS%FOUND
            LOOP
                --Codigo Fichero
                v_codFichero := 'CAT_TVTA1';

                -- Se concatenan los valores que forman el código de referencia:
                --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
                --En función del tipo de actividad se genera un valor de referencia u otro
                --CAPTACTION -> CAT
                --RECUPERACION -> REC
                --MKT DIRECTO COTEL -> MKT
                
                v_actividad := 'ERR'; --valor por defecto
                
                CASE REGDEPOSITO.ACTIVIDAD
                    WHEN 'CAPTACIÓN'            THEN v_actividad := 'CAT';
                    WHEN 'CAPTACION'            THEN v_actividad := 'CAT';
                    WHEN 'RECUPERACIÓN'         THEN v_actividad := 'REC';
                    WHEN 'MKT DIRECTO COTEL'    THEN v_actividad := 'MKT';
                    ELSE                             v_actividad := 'ERR';
                END CASE;
                v_referencia := v_txtYear || REGDEPOSITO.ID_CENTRO_E4E || v_actividad || v_codMes;

                -- Se determina el código de equivalencia del tipo impositivo
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
					WHEN 'IVA OFFSHORE' THEN v_Impuesto := 'BF';
                    ELSE                     v_Impuesto := '';
                END CASE;

                -- Se determina la fecha de inicio
                IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                    v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
                ELSE
                    v_txtFechaInicio := v_txtFechaInicioPeriodo;
                END IF;

                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'CAT_TVTA1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                END IF;
                IF v_contador_cabecera = 0 THEN   
                    INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                               CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
					VALUES ( iperiod,
							contadorTabla,
							v_referencia,
							'',
							'CABECERA', 
							REGDEPOSITO.COD_CONTRATO,
							v_txtFechaInicio,
							'',
							REGDEPOSITO.SOCIEDAD,
							REGDEPOSITO.PAR_PROVEEDOR,
							REGDEPOSITO.CECO,
							REGDEPOSITO.ORG_COMPRAS,
							REGDEPOSITO.GR_COMPRAS,
							'NO',
							'',
							'RE',
							'','','','','','','','',v_codFichero,
							REGDEPOSITO.BUSINESSUNIT);

                    -- Registro de DATOS - POSICION
                    IF v_codFichero = 'CAT_TVTA1' then
                        contadorE4E := contadorE4E +1;
                        contadorTabla := contadorE4E;
                    END IF;
                    
                    v_contador_cabecera := 1; --Cabecera insertada. A 1 para no volver a insertarla 
                END IF;
                
                IF v_codFichero = 'CAT_TVTA1' then
                    v_contador_orden_entrega := v_contador_orden_entrega + 10;
                END IF;
                INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,    --CAMPO1
						v_contador_orden_entrega,
						'POSICION', 
						REGDEPOSITO.COD_CONTRATO, --CAMPO4
						'',
						REGDEPOSITO.POS_DOC,
						'P',                      --CAMPO7
						'',
						REGDEPOSITO.TEXTO_BREVE,  --CAMPO9
						UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REGDEPOSITO.DESCRIPCION,'ú','u'),'ó','o'),'í','i'),'é','e'),'á','a')),  --CAMPO10
						-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
						CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
						'UA',
						v_txtFechaActual,
						REGDEPOSITO.CENTRO_LOGISTICO,
						REGDEPOSITO.WBE_FINAL_IMPUTACION,
						v_Impuesto,
						'','','','','','ES21-06',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);            

                IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                    -- Registro de DATOS - POSICION
                    IF v_codFichero = 'CAT_TVTA1' then
						contadorE4E := contadorE4E +1;
						contadorTabla := contadorE4E;
					END IF; 
 
					INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
					VALUES ( iperiod,
							contadorTabla,
							v_referencia,
							v_contador_orden_entrega,
							'SERVICIO', 
							REGDEPOSITO.COD_CONTRATO,
							'',
							REGDEPOSITO.POS_DOC,  -- CAMPO6
							REGDEPOSITO.SUBPOSICION,      -- CAMPO7
							REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
							REGDEPOSITO.TEXTO_BREVE,      --CAMPO9
							to_char(REGDEPOSITO.VALUE),  --CAMPO10
							REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
							'', '', '', '',                    -- CAMPO12 a 15
							'', '', '', '',                    -- CAMPO16 a 19
							'', '', '',                        -- CAMPO20 a 22
							v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                END IF;

                FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
			END LOOP;
     
            FETCH C_TMPPAYEE INTO v_reg_pos_name,v_reg_pos_actividad;

            CLOSE C_TMPDEPOSITOS;
		END LOOP;
        
        CLOSE C_TMPPAYEE;
	END;
    
    COMMIT;

    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
		p_Cabecera_Ficheros_E4E (  iperiod , 'CAT_TVTA1' );
    end if;

	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_CAT_TVTA:  CAT_TVTA1'|| to_char(contadorE4E) || ' filas.', v_contador_debug);
end;

procedure p_Final_E4E_2 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(12);
    v_actividad VARCHAR2(3);
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(9);
    v_contador_cabecera NUMBER; --contador para la cabecera. Se reinicia con cada payee + actividad nuevo
    v_contador_orden_entrega NUMBER;    
begin
    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_CAT_TVTA.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENEL_E4E_FINAL_CAT_TVTA WHERE PERIODO = iperiod AND FICHERO = 'CAT_TVTA2' AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_CAT_TVTA.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');

    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_FINAL_CAT_TVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_CAT_TVTA. Fichero ' || v_codFichero ,  v_contador_debug);

	contadorE4E := 4;
	--contadorECS := 4;

    DECLARE
		CURSOR C_TMPPAYEE IS
            SELECT DISTINCT POS_NAME, ACTIVIDAD 
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
            WHERE PERIODSEQ = iperiodseq
                AND COD_CONTRATO IS NULL        -- Fichero E4E2 contiene los registros sin contrato
            --    AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos --RMM 13/07/2022
            ;
            
            v_reg_pos_name          VARCHAR2(255);
            v_reg_pos_actividad     VARCHAR2(255);
            
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
				PERIODSEQ,
				VALUE,
				POS_NAME,
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
				ID_CENTRO_E4E,
				BUSINESSUNIT
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP
            WHERE 
				PERIODSEQ = iperiodseq 
				AND COD_CONTRATO is null        -- Fichero E4E2 contiene los registros sin contrato
				AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos --RMM 12/07/2022 Solicitan que aparezcan negativos
				AND POS_NAME = v_reg_pos_name
				AND ACTIVIDAD = v_reg_pos_actividad
            ORDER BY WBE_FINAL_IMPUTACION; 
            
			REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
    BEGIN
        OPEN C_TMPPAYEE;
        FETCH C_TMPPAYEE INTO v_reg_pos_name,v_reg_pos_actividad;
        
        WHILE C_TMPPAYEE%FOUND
        LOOP
			--Inicializamos contadores
            v_contador_cabecera := 0;
            v_contador_orden_entrega := 0;
            
            OPEN C_TMPDEPOSITOS;
            FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;

            WHILE C_TMPDEPOSITOS%FOUND
            LOOP
				--Codigo Fichero
                v_codFichero := 'CAT_TVTA2';

                -- Se concatenan los valores que forman el código de referencia:
                --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
                --En función del tipo de actividad se genera un valor de referencia u otro
                --CAPTACTION -> CAT
                --RECUPERACION -> REC
                --MKT DIRECTO COTEL -> MKT
                
                v_actividad := 'ERR'; --valor por defecto
                
                CASE REGDEPOSITO.ACTIVIDAD
                    WHEN 'CAPTACIÓN'            THEN v_actividad := 'CAT';
                    WHEN 'CAPTACION'            THEN v_actividad := 'CAT';
                    WHEN 'RECUPERACIÓN'         THEN v_actividad := 'REC';
                    WHEN 'MKT DIRECTO COTEL'    THEN v_actividad := 'MKT';
                    ELSE                             v_actividad := 'ERR';
                END CASE;
                v_referencia := v_txtYear || REGDEPOSITO.ID_CENTRO_E4E || v_actividad || v_codMes;

                -- Se determina el código de equivalencia del tipo impositivo
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    WHEN 'IVA OFFSHORE' THEN v_Impuesto := 'BF';
                    ELSE                     v_Impuesto := '';
                END CASE;

                -- Se determina la fecha de inicio
                IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                    v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
                ELSE
                    v_txtFechaInicio := v_txtFechaInicioPeriodo;
                END IF;

                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'CAT_TVTA2' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                END IF;
                
                IF v_contador_cabecera = 0 THEN   
					INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
														CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
					VALUES ( iperiod,
							contadorTabla,
							v_referencia,
							'',
							'CABECERA', 
							REGDEPOSITO.COD_CONTRATO,
							v_txtFechaInicio,
							'',
							REGDEPOSITO.SOCIEDAD,
							REGDEPOSITO.PAR_PROVEEDOR,
							REGDEPOSITO.CECO,
							REGDEPOSITO.ORG_COMPRAS,
							REGDEPOSITO.GR_COMPRAS,
							'NO',
							'',
							'RE',
							'','','','','','','','',v_codFichero,
							REGDEPOSITO.BUSINESSUNIT);

                    -- Registro de DATOS - POSICION
                    IF v_codFichero = 'CAT_TVTA2' then
						contadorE4E := contadorE4E +1;
                        contadorTabla := contadorE4E;
                    END IF;
                    
                    v_contador_cabecera := 1; --Cabecera insertada. A 1 para no volver a insertarla 
                END IF;
                
                IF v_codFichero = 'CAT_TVTA2' then
                    v_contador_orden_entrega := v_contador_orden_entrega + 10;
                END IF;
                
                INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
													CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,    --CAMPO1
						v_contador_orden_entrega,
						'POSICION', 
						REGDEPOSITO.COD_CONTRATO, --CAMPO4
						'',
						REGDEPOSITO.POS_DOC,
						'P',                      --CAMPO7
						'',
						REGDEPOSITO.TEXTO_BREVE,  --CAMPO9
						UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REGDEPOSITO.DESCRIPCION,'ú','u'),'ó','o'),'í','i'),'é','e'),'á','a')),  --CAMPO10
						-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
						CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
						'UA',
						v_txtFechaActual,
						REGDEPOSITO.CENTRO_LOGISTICO,
						REGDEPOSITO.WBE_FINAL_IMPUTACION,
						v_Impuesto,
						'','','','','','ES21-06',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);            

                IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                    -- Registro de DATOS - POSICION
                    IF v_codFichero = 'CAT_TVTA2' then
						contadorE4E := contadorE4E +1;
						contadorTabla := contadorE4E;
                    END IF; 
                    
					INSERT INTO ENEL_E4E_FINAL_CAT_TVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
													CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
					VALUES ( iperiod,
							contadorTabla,
							v_referencia,
							v_contador_orden_entrega,
							'SERVICIO', 
							REGDEPOSITO.COD_CONTRATO,
							'',
							REGDEPOSITO.POS_DOC,  -- CAMPO6
							REGDEPOSITO.SUBPOSICION,      -- CAMPO7
							REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
							REGDEPOSITO.TEXTO_BREVE,      --CAMPO9
							to_char(REGDEPOSITO.VALUE),  --CAMPO10
							REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
							'', '', '', '',                    -- CAMPO12 a 15
							'', '', '', '',                    -- CAMPO16 a 19
							'', '', '',                        -- CAMPO20 a 22
							v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                END IF;

				FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
			END LOOP;

			FETCH C_TMPPAYEE INTO v_reg_pos_name,v_reg_pos_actividad;

            CLOSE C_TMPDEPOSITOS;
		END LOOP;
        
		CLOSE C_TMPPAYEE;
    END;
    
	COMMIT;

    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
		p_Cabecera_Ficheros_E4E (  iperiod , 'CAT_TVTA2' );
	end if;

	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_CAT_TVTA:  CAT_TVTA2'|| to_char(contadorE4E) || ' filas.', v_contador_debug);
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
    w_debug('Inicio Borrado de la tabla ENEL_E4E_NEGATIVOS_CAT_TVTA.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_CAT_TVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_NEGATIVOS_CAT_TVTA.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodoSig := to_char(v_fechaInicioPeriodoSig, 'DD/MM/YYYY');
    
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodoSig, 'YY');
    
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodoSig);
    
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodoSig ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    select NVL(MAX(IDPEDIDO),0) into v_maxIDPEDIDO  from ENEL_E4E_NEGATIVOS_CAT_TVTA WHERE ESTADO='LIQUIDADO';
    w_debug('Numero máximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) ,  v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_E4E_NEGATIVOS_CAT_TVTA.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_CAT_TVTA ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, POS_NAME, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
                                              SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
                                              CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, TEXTO_CABECERA, TEXTO_SUPLEMENTARIO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
                                              CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION  )   
	SELECT 
		e4edt.PERIODSEQ,
		e4edt.PERIODO,
		e4edt.DEPOSITSEQ,
		e4edt.POSITIONSEQ,
		e4edt.PAYEESEQ, 
		e4edt.POS_NAME,
		v_maxIDPEDIDO + rownum as IDPEDIDO,
		e4edt.ORG_VENTAS,
		CASE 
			WHEN COMUNIDAD_AUTONOMA = 'CANARIAS' THEN 'CA' 
			ELSE 'CO' 
		END AS CANAL_DISTRIBUCION,
		'39' as SECTOR,
		'ZOAL' as CLASE_PEDIDO,
		'' AS FACTURA_REF,
		e4edt.CODIGODEUDOR Solicitante_ShipTo,
		e4edt.CODIGODEUDOR Solicitante_SoldTo,
		CASE 
			WHEN e4edt.ACTIVIDAD = 'CAPTACIÓN' THEN v_txtYear || e4edt.POS_NAME || 'CAT' || v_codMes
			WHEN e4edt.ACTIVIDAD = 'RECUPERACIÓN' THEN v_txtYear || e4edt.POS_NAME || 'REC' || v_codMes
			WHEN e4edt.ACTIVIDAD = 'MKT DIRECTO COTEL' THEN v_txtYear || e4edt.POS_NAME || 'MKT' || v_codMes
			ELSE v_txtYear || e4edt.POS_NAME || 'ERR' || v_codMes
		END NUM_PEDIDO,
		'' FechaPedido,
		'' FechaFactura,
		--v_txtFechaInicioPeriodoSig FechaPedido,
		--v_txtFechaActual FechaFactura, 
		e4edt.CONDICIONES_PAGO,
		'' ContratoSEPA,
		'' MotivoPedido,
		'' TEXTO_CABECERA,
		'' TEXTO_SUPLEMENTARIO,
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
			ELSE ''
		END CLASIF_FISCAL_IVA,
		CASE e4edt.TIPO_IMPOSITIVO
			WHEN 'IGIC' THEN '1'
			ELSE ''
		END CLASIF_FISCAL_IGIC,    
		WBE_FINAL_IMPUTACION

	FROM ENEL_E4E_NEG_TEMP_CAT_TVTA e4edt 
	WHERE 
		e4edt.VALUE < 0  
		and e4edt.PERIODSEQ = iperiodseq;
               
	filas := sql%rowcount;
	COMMIT;

	w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
	dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_NEGATIVOS_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_CAT_TVTA.',v_contador_debug);     
end;        

procedure p_Inf_CAT_TVTA_IB_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_IB_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_IB_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_IB_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_IB_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IB_TEMP ( PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, REGISTRO_PPAL, EVENTTYPEID, CREDITTYPEID, PRODUCTO, HERRAMIENTA, BBDD, IMPORTE, UNIDAD, EMPRESA, CODIGO_COMERCIAL, PROVEEDOR, 
												NOMBRE_PROVEEDOR, FECHA_LIQUIDACION, ESTADO, TERRITORIO, DELEGACION, CAMPANIA, GRUPO_PROD, CREDITSEQ ) 
	
	SELECT    
		PER.NAME PERIODO,
		SO.ORDERID,
		ST.LINENUMBER,
		ST.SUBLINENUMBER,
		CASE 
			WHEN CR.GENERICBOOLEAN4 = 1 
			THEN 'Si' ELSE '' 
		END REGISTRO_PPAL,
		ET.EVENTTYPEID,
		CT.CREDITTYPEID,
		CR.GENERICATTRIBUTE1 PRODUCTO,
		--, CR.GENERICATTRIBUTE5 HERRAMIENTA
		CR.GENERICATTRIBUTE3 HERRAMIENTA,
		'' BBDD,
		CR.VALUE IMPORTE,
		'EURO' UNIDADES,
		CR.GENERICATTRIBUTE11 EMPRESA,
		CR.GENERICATTRIBUTE4 CODIGO_COMERCIAL,
-- BOM CAL0130 DCR 29.03.22
-- Old Code
		--CR.GENERICATTRIBUTE2 PROVEEDOR,
-- New Code
		CR.GENERICATTRIBUTE14 PROVEEDOR,
-- EOM CAL0130 DCR 29.03.22
		CR.GENERICATTRIBUTE16 NOMBRE_PROVEEDOR,
		v_txtFechaLiquidacion,
		CASE  
			WHEN CR.VALUE IS NULL THEN 'Pte Revisar'
	--		WHEN iInterfaz ='ACTUALIZA_INFORMES_POST' AND CR.VALUE IS NOT NULL THEN 'Liquidado' -- RMM 10.01.2022 CAT TVTA se liquida por fuera, por lo que nunca debe aparecer liquidado
			ELSE 'Pte Liquidar'
		END ESTADO,
		CR.GENERICATTRIBUTE7 TERRITORIO,
		CR.GENERICATTRIBUTE10 DELEGACION,
		CR.GENERICATTRIBUTE5 CAMPANIA,
		CR.GENERICATTRIBUTE12 GRUPO_PROD,
		CR.CREDITSEQ

	FROM CS_PERIOD PER
		INNER JOIN CS_SALESTRANSACTION ST
			ON ST.COMPENSATIONDATE BETWEEN PER.STARTDATE AND PER.ENDDATE - 1
			AND ST.TENANTID = itenantId
			AND ST.MODELSEQ = 0
			AND ST.PROCESSINGUNITSEQ = iprocessingUnitSeq
		
		INNER JOIN CS_SALESORDER SO 
			ON ST.SALESORDERSEQ = SO.SALESORDERSEQ 
			AND SO.REMOVEDATE = v_eot
			AND SO.PROCESSINGUNITSEQ = iprocessingUnitSeq
			   
		INNER JOIN CS_EVENTTYPE ET 
			ON ST.EVENTTYPESEQ = ET.DATATYPESEQ
			AND ET.TENANTID = itenantId
			AND ET.REMOVEDATE = v_eot
		
		INNER JOIN CS_CREDIT CR 
			ON ST.SALESTRANSACTIONSEQ = CR.SALESTRANSACTIONSEQ
			AND CR.TENANTID = itenantId 
			AND CR.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND CR.PERIODSEQ =  iperiodseq

        INNER JOIN CS_CREDITTYPE CT 
            ON CR.CREDITTYPESEQ = CT.DATATYPESEQ
			AND CT.TENANTID = itenantId
			AND CT.REMOVEDATE = v_eot
		
		INNER JOIN CS_PLRUN P 
			ON CR.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       
		
		INNER JOIN CS_CALENDAR CA
			ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE	
		PER.REMOVEDATE = v_eot      
		AND PER.PERIODSEQ =  iperiodseq
        AND ( CR.NAME = 'CD - CAT TVTA - Captacion - Coste Unitario'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Coste Unitario'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Ventas')
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IB_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_IB_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_IB_TEMP.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_RESUM_PAGO_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_RESUM_PAGO_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_RESUM_PAGO_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_RESUM_PAGO_TEMP.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO_TEMP ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO,  PROVEEDOR, NOMBRE_PROVEEDOR,  CODIGO_COMERCIAL,  CONTRATO,  LINE,  SUBLINE,  EVENTTYPEID,  
														CREDITTYPEID,  REGISTRO_PPAL, PRODUCTO,  HERRAMIENTA, BBDD, EMPRESA,  TERRITORIO,  DELEGACION,  CAMPANIA,  FECHA_LIQUIDACION,  COSTE_UNITARIO,  APORTE, 
														BONUSMALUS, INCENTIVO,  PENAL_EXT,  PENAL_ORD,  AJUSTE,  VALOR_FINAL,  ESTADO  ) 
    SELECT    
		COM.PAYEESEQ,
		COM.POSITIONSEQ,
		COM.PERIODSEQ,
		IB.PERIODO,
		IB.PROVEEDOR,
		IB.NOMBRE_PROVEEDOR,
		IB.CODIGO_COMERCIAL,
		IB.ORDERID CONTRATO,
		IB.LINENUMBER LINE,
		IB.SUBLINENUMBER SUBLINE,
		IB.EVENTTYPEID,
		IB.CREDITTYPEID,
		IB.REGISTRO_PPAL,
		IB.PRODUCTO,
		IB.HERRAMIENTA,
		IB.BBDD,
		IB.EMPRESA,
		IB.TERRITORIO,
		IB.DELEGACION,
		IB.CAMPANIA,
		IB.FECHA_LIQUIDACION,
		IB.IMPORTE COSTE_UNITARIO,
		INC.GENERICNUMBER1 APORTE,
		INC.GENERICNUMBER2 BONUSMALUS,
		INC.GENERICNUMBER3 INCENTIVO,
		INC.GENERICNUMBER4 PENAL_EXT,
		INC.GENERICNUMBER5 PENAL_ORD,
		INC.GENERICNUMBER6 AJUSTE,
		COM.VALUE VALOR_FINAL,
		IB.ESTADO

	FROM ENELEXT.ENEL_CAT_TVTA_IB_TEMP IB
		LEFT JOIN CS_COMMISSION COM 
			ON IB.CREDITSEQ = COM.CREDITSEQ
			AND COM.TENANTID = itenantId
			AND COM.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND COM.PERIODSEQ =  iperiodseq
    
		LEFT JOIN CS_INCENTIVE INC 
			ON COM.INCENTIVESEQ = INC.INCENTIVESEQ
			AND INC.TENANTID = itenantId
			AND INC.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND INC.PERIODSEQ =  iperiodseq
    
    WHERE IB.PERIODO = iperiod
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_RESUM_PAGO_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_RESUM_PAGO_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO_TEMP.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_RESUMEN_PAGO ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
	w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_RESUM_PAGO.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_RESUM_PAGO.', v_contador_debug);

/* BOM CAL0130 DCR 29.03.22 */
/* Old Code
    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_RESUM_PAGO.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO (   PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO,  PROVEEDOR, NOMBRE_PROVEEDOR,  CODIGO_COMERCIAL,  CONTRATO,  LINE,  SUBLINE,  EVENTTYPEID,
													CREDITTYPEID, REGISTRO_PPAL,  PRODUCTO,  HERRAMIENTA, BBDD, EMPRESA,  TERRITORIO,  DELEGACION,  CAMPANIA,  FECHA_LIQUIDACION,
													COSTE_UNITARIO,  APORTE,  BONUSMALUS,  INCENTIVO,  PENAL_EXT,  PENAL_ORD,  AJUSTE,  VALOR_FINAL,  ESTADO  ) 
    
    SELECT    
		PAYEESEQ,
		POSITIONSEQ,
		PERIODSEQ,
		PERIODO,
		PROVEEDOR,
		NOMBRE_PROVEEDOR,
		CODIGO_COMERCIAL,
		CONTRATO,
		LINE,
		SUBLINE,
		EVENTTYPEID,
		CREDITTYPEID,
		REGISTRO_PPAL,
		PRODUCTO,
		HERRAMIENTA,
		BBDD,
		EMPRESA,
		TERRITORIO,
		DELEGACION,
		CAMPANIA,
		FECHA_LIQUIDACION,
		COSTE_UNITARIO,
		APORTE,
		BONUSMALUS,
		INCENTIVO,
		PENAL_EXT,
		PENAL_ORD,
		AJUSTE,
		VALOR_FINAL,
		ESTADO

    FROM ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO_TEMP
    WHERE PERIODO =  iperiod
    ;
    
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_RESUM_PAGO: '|| to_char(filas) || ' filas.', v_contador_debug);
*/ 

-- New code
    w_debug('Insertando CREDITOS en la tabla ENEL_CAT_TVTA_RESUM_PAGO' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO,  PROVEEDOR, CODIGO_COMERCIAL,  CONTRATO,  CREDITTYPEID, 
                                                    HERRAMIENTA, BBDD, EMPRESA,  TERRITORIO,  DELEGACION,  CAMPANIA, PRODUCTO, VALOR_FINAL,PROVEEDOR2  ) 
    SELECT    
		CR.payeeseq as PAYEESEQ,
        CR.positionseq as POSITIONSEQ,
        CR.periodseq as PERIODSEQ,
        PER.name as PERIODO,
        CR.genericattribute14 as PROVEEDOR,
        CR.genericattribute4 as CODIGO_COMERCIAL,
        SO.orderid as CONTRATO,
        CT.credittypeid as CREDITTYPEID,
        CR.genericattribute3 as HERRAMIENTA,
        '' as BBDD,
        CR.genericattribute11 as EMPRESA,
        CR.genericattribute7 as TERRITORIO,
		CR.genericattribute10 as DELEGACION,
		CR.genericattribute5 as CAMPANIA,
/* BOM CAL0134 DCR 19.04.2022 */
        CR.genericattribute15 as PRODUCTO,
/* EOM CAL0134 DCR 19.04.2022 */
        CR.value  as VALOR_FINAL,
        CR.GENERICATTRIBUTE2 as proveedor2
    
    FROM CS_PERIOD PER
		INNER JOIN CS_SALESTRANSACTION ST
			ON ST.COMPENSATIONDATE BETWEEN PER.STARTDATE AND PER.ENDDATE - 1
			AND ST.TENANTID = itenantId
			AND ST.MODELSEQ = 0
			AND ST.PROCESSINGUNITSEQ = iprocessingUnitSeq
		
		INNER JOIN CS_SALESORDER SO 
			ON ST.SALESORDERSEQ = SO.SALESORDERSEQ 
			AND SO.REMOVEDATE = v_eot
			AND SO.PROCESSINGUNITSEQ = iprocessingUnitSeq
		
		INNER JOIN CS_CREDIT CR 
			ON ST.SALESTRANSACTIONSEQ = CR.SALESTRANSACTIONSEQ
			AND CR.TENANTID = itenantId 
			AND CR.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND CR.PERIODSEQ =  iperiodseq
            
        

        INNER JOIN CS_CREDITTYPE CT 
            ON CR.CREDITTYPESEQ = CT.DATATYPESEQ
			AND CT.TENANTID = itenantId
			AND CT.REMOVEDATE = v_eot
		
		INNER JOIN CS_PLRUN P 
			ON CR.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       

	WHERE	
		PER.REMOVEDATE = v_eot      
		AND PER.PERIODSEQ =  iperiodseq
        
        AND ( CR.NAME = 'CD - CAT TVTA - Captacion - Coste Unitario'
				OR CR.NAME like 'CD - CAT TVTA - Recuperacion - Coste Unitario%'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Ventas'
                or cr.name = 'CD - CAT TVTA - TLV INBOUND - Ventas'
/* BOM CAL0XXX DCR 24.05.2022 */
                OR CR.NAME = 'CD - CAT TVTA - Captacion - Ajuste Manual'
                OR CR.NAME = 'CD - CAT TVTA - MKT - Ajuste Manual'
                OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Ajuste Manual'
                OR CR.NAME = 'CD - Leads CAT TVTA - Importe Base'
                OR CR.NAME = 'CD - Captacion TVTA - Permanencia'
                OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Coste Unitario Campañas'
                OR CR.NAME = 'CD - CAT TVTA - Captacion - Coste Unitario Campañas' --APM 15.04.2025
                /*BOM APM 19.03.2026*/
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Fibra'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Futbol'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - DAZN'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Linea Movil'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - OTT'
                OR CR.NAME = 'CD - Captacion CAT TVTA - Mas Orange - Importe Base - Dispositivo'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Fibra'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Futbol'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - DAZN'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Linea Movil'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - OTT'
                OR CR.NAME = 'CD - Retrocesion CAT TVTA - Mas Orange - Importe Base - Dispositivo'
                OR CR.NAME = 'CD - Ajuste Manual CAT TVTA - Mas Orange - Importe Base'
                /*EOM APM 19.03.2026*/
                OR CR.NAME LIKE 'CD - CAT TVTA - Retrocesion%' --APM 19.05.2026
                )
/* EOM CAL0XXX DCR 24.05.2022 */
/* BOM CAL0134 DCR 19.04.2022 */
        --AND CR.value <> 0 DCR 05.05.2022 Carmen nos indica que ya no es necesario esta condicion
/* EOM CAL0134 DCR 19.04.2022 */
	;
    
	filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_RESUM_PAGO: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Insertando INCENTIVOS en la tabla ENEL_CAT_TVTA_RESUM_PAGO' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO,  PROVEEDOR, CODIGO_COMERCIAL,  CONTRATO,  CREDITTYPEID, 
                                                    HERRAMIENTA, BBDD, EMPRESA,  TERRITORIO,  DELEGACION,  CAMPANIA, PRODUCTO, VALOR_FINAL,PROVEEDOR2  )
    SELECT
        INC.payeeseq as PAYEESEQ,
        INC.positionseq as POSITIONSEQ,
        INC.periodseq as PERIODSEQ,
        PER.name as PERIODO,
        --POS.NAME as PROVEEDOR,
        INC.genericattribute2 as PROVEEDOR,
        pos.name as CODIGO_COMERCIAL,--cambiar por codigo posicion
        ordtxn.orderid as CONTRATO,
        'CAT TVTA' as CREDITTYPEID,
        INC.genericattribute3 as HERRAMIENTA,
        '' as BBDD,
        '' as EMPRESA,
        '' as TERRITORIO,
		'' as DELEGACION,
		INC.genericattribute6 as CAMPANIA,
/* BOM CAL0134 DCR 19.04.2022 */
        INC.genericattribute1 as PRODUCTO,
/* EOM CAL0134 DCR 19.04.2022 */
         commi.value as VALOR_FINAL,
        inc.genericattribute7
    
    FROM CS_INCENTIVE INC
        LEFT JOIN CS_COMMISSION COMMI
        ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
		INNER JOIN CS_PERIOD PER
			ON PER.PERIODSEQ =  INC.PERIODSEQ
            AND PER.REMOVEDATE = v_eot
		
		INNER JOIN CS_PLRUN P 
			ON INC.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion    
        
        INNER JOIN CS_POSITION POS
            ON INC.payeeseq = POS.payeeseq
            AND INC.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
            AND INC.PROCESSINGUNITSEQ = POS.PROCESSINGUNITSEQ
            AND POS.REMOVEDATE = v_eot
        
        left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        left join cs_credit cred 
            ON COMMI.CREDITSEQ = CRED.CREDITSEQ
            AND COMMI.PAYEESEQ = CRED.PAYEESEQ
            and cred.periodseq=iperiodseq
            
        left join cs_salestransaction txn 
             on  cred.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
             and cred.compensationdate=txn.compensationdate
         
         INNER JOIN cs_salesorder ordtxn
            ON txn.salesorderseq = ordtxn.salesorderseq
            AND ordtxn.removedate = '01/01/2200'
            AND txn.tenantid = 'ENEL'
            AND ordtxn.processingunitseq = txn.processingunitseq
            --AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
            AND txn.modelseq = 0
            AND txn.processingunitseq = 38280596832649518
            AND ordtxn.tenantid = txn.tenantid

        
	WHERE	
		INC.PERIODSEQ = iperiodseq
        and INC.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and INC.genericattribute1 is not null
/* BOM CAL0134 DCR 19.04.2022 */
        AND commi.value <> 0
/* EOM CAL0134 DCR 19.04.2022 */
    ;
    
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_RESUM_PAGO: '|| to_char(filas) || ' filas.', v_contador_debug);
/* EOM CAL0130 DCR 29.03.22 */

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_RESUM_PAGO',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_RESUM_PAGO.',v_contador_debug);
end;

procedure p_Inf_CAT_TVTA_APORTE_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_APORTE_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_APORTE_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_APORTE_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_APORTE_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_APORTE_TEMP ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, CODIGO_COMERCIAL, CANAL, N_REGISTROS, APORTE_UNITARIO, APORTE_TOTAL, ID_PRODUCTO, PRODUCTO, 
												PORCENTAJE_APORTE, N_PRODUCTOS, APORTE_INICIAL, APORTE_PENDIENTE, APORTE_FINAL, APORTE_FINAL_UNITARIO ) 
    
	SELECT    
		PO.PAYEESEQ,
		PO.RULEELEMENTOWNERSEQ POSITIONSEQ,
		PER.PERIODSEQ,
		PER.NAME PERIODO,
		PO.NAME CODIGO_COMERCIAL,
		'CAT Captacion' CANAL,
		ME1.GENERICNUMBER3 N_REGISTROS,
		FV.VALUE APORTE_UNITARIO,
		ME2.GENERICNUMBER1 APORTE_TOTAL,
		SUBSTR (ME2.NAME, 58, 1) ID_PRODUCTO,
		ME2.GENERICATTRIBUTE1 PRODUCTO,
		ME2.GENERICNUMBER4 PORCENTAJE_APORTE,
		ME2.GENERICNUMBER3 N_PROD,
		ME2.GENERICNUMBER2 APORTE_INICIAL,
		ME2.GENERICNUMBER6 APORTE_PENDIENTE,
		ME3.VALUE APORTE_FINAL,
		ME2.VALUE APORTE_FINAL_UNITARIO

	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT ME1
			ON ME1.PERIODSEQ =  PER.PERIODSEQ
			AND ME1.TENANTID = itenantId 
			AND ME1.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ME1.PERIODSEQ =  iperiodseq
			AND  ME1.NAME = 'MS - CAT TVTA - Captacion - Aporte'
                
        INNER JOIN CS_MEASUREMENT ME2
			ON ME2.PERIODSEQ =  PER.PERIODSEQ
			AND ME2.TENANTID = itenantId 
			AND ME2.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ME2.PERIODSEQ =  iperiodseq
			AND ME1.POSITIONSEQ = ME2.POSITIONSEQ
			AND ME2.NAME IN ( 'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 1',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 2',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 3',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 4',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 5',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 6',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 7',
							'MS - CAT TVTA - Captacion - Aporte Final Unitario - Prod 8')
                
		INNER JOIN CS_MEASUREMENT ME3
			ON ME3.PERIODSEQ =  PER.PERIODSEQ
			AND ME3.TENANTID = itenantId 
			AND ME3.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ME3.PERIODSEQ =  iperiodseq
			AND ME1.POSITIONSEQ = ME3.POSITIONSEQ
			AND SUBSTR (ME2.NAME, 58, 1) = SUBSTR (ME3.NAME, 49, 1) 
			AND ME3.NAME IN ( 'MS - CAT TVTA - Captacion - Aporte Final - Prod 1',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 2',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 3',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 4',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 5',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 6',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 7',
							'MS - CAT TVTA - Captacion - Aporte Final - Prod 8')
            
		INNER JOIN CS_POSITION PO
			ON ME1.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ 
			AND ME2.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ 
			AND ME3.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND PO.REMOVEDATE = v_eot
			AND PO.TENANTID = itenantId
			AND PO.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND PO.EFFECTIVESTARTDATE <= PER.STARTDATE AND EFFECTIVEENDDATE >= PER.ENDDATE
            
        INNER JOIN CS_PLRUN P1 
            ON ME1.PIPELINERUNSEQ = P1.PIPELINERUNSEQ
			AND P1.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion  
                
        INNER JOIN CS_PLRUN P2
            ON ME2.PIPELINERUNSEQ = P2.PIPELINERUNSEQ
			AND P2.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       
                
        INNER JOIN CS_PLRUN P3
            ON ME3.PIPELINERUNSEQ = P3.PIPELINERUNSEQ
			AND P3.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion                
                    
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'
                
        LEFT JOIN CS_FIXEDVALUE FV
            ON FV.EFFECTIVESTARTDATE <= PER.STARTDATE AND FV.EFFECTIVEENDDATE >= PER.ENDDATE
			AND FV.REMOVEDATE = v_eot
			AND FV.TENANTID = itenantId
			AND FV.NAME = 'VF - CAT TVTA - Captacion - Aporte'                  

	WHERE    
		PER.REMOVEDATE = v_eot   
		AND PER.PERIODSEQ =  iperiodseq
	;
                
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_APORTE_TEMP ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, CODIGO_COMERCIAL, CANAL, N_REGISTROS, APORTE_UNITARIO, APORTE_TOTAL, ID_PRODUCTO, 
													PRODUCTO, PORCENTAJE_APORTE, N_PRODUCTOS, APORTE_INICIAL, APORTE_PENDIENTE, APORTE_FINAL, APORTE_FINAL_UNITARIO ) 
	SELECT
		PO.PAYEESEQ,
		PO.RULEELEMENTOWNERSEQ POSITIONSEQ,
		PER.PERIODSEQ,
		PER.NAME PERIODO,
		PO.NAME CODIGO_COMERCIAL,
		'CAT Recuperacion' CANAL,
		ME1.GENERICNUMBER3 N_REGISTROS,
		FV.VALUE APORTE_UNITARIO,
		ME2.GENERICNUMBER1 APORTE_TOTAL,
		SUBSTR (ME2.NAME, 61, 1) ID_PRODUCTO,
		ME2.GENERICATTRIBUTE1 PRODUCTO,
		ME2.GENERICNUMBER4 PORCENTAJE_APORTE,
		ME2.GENERICNUMBER3 N_PROD,
		ME2.GENERICNUMBER2 APORTE_INICIAL,
		ME2.GENERICNUMBER6 APORTE_PENDIENTE,
		ME3.VALUE APORTE_FINAL,
		ME2.VALUE APORTE_FINAL_UNITARIO

	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT ME1
			ON ME1.PERIODSEQ =  PER.PERIODSEQ
			AND ME1.TENANTID = itenantId 
			AND ME1.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ME1.PERIODSEQ =  iperiodseq
			AND  ME1.NAME = 'MP - CAT TVTA - Recuperacion - Aporte - Numero de Registros'
                
        INNER JOIN CS_MEASUREMENT ME2
			ON ME2.PERIODSEQ =  PER.PERIODSEQ
			AND ME2.TENANTID = itenantId 
			AND ME2.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ME2.PERIODSEQ =  iperiodseq
			AND ME1.POSITIONSEQ = ME2.POSITIONSEQ
			AND ME2.NAME IN ( 'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 1',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 2',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 3',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 4',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 5',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 6',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 7',
							'MS - CAT TVTA - Recuperacion - Aporte Final Unitario - Prod 8')
                
		INNER JOIN CS_MEASUREMENT ME3
			ON ME3.PERIODSEQ =  PER.PERIODSEQ
			AND ME3.TENANTID = itenantId 
			AND ME3.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ME3.PERIODSEQ =  iperiodseq
			AND ME1.POSITIONSEQ = ME3.POSITIONSEQ
			AND SUBSTR (ME2.NAME, 61, 1) = SUBSTR (ME3.NAME, 52, 1) 
			AND ME3.NAME IN ( 'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 1',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 2',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 3',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 4',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 5',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 6',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 7',
							'MS - CAT TVTA - Recuperacion - Aporte Final - Prod 8')
            
        INNER JOIN CS_POSITION PO
			ON ME1.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND ME2.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ 
			AND ME3.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND PO.REMOVEDATE = v_eot
			AND PO.TENANTID = itenantId
			AND PO.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND PO.EFFECTIVESTARTDATE <= PER.STARTDATE AND EFFECTIVEENDDATE >= PER.ENDDATE
            
        INNER JOIN CS_PLRUN P1 
            ON ME1.PIPELINERUNSEQ = P1.PIPELINERUNSEQ
			AND P1.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion  
                
        INNER JOIN CS_PLRUN P2
            ON ME2.PIPELINERUNSEQ = P2.PIPELINERUNSEQ
			AND P2.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       
                
        INNER JOIN CS_PLRUN P3
            ON ME3.PIPELINERUNSEQ = P3.PIPELINERUNSEQ
			AND P3.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion                
                    
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'
                
        LEFT JOIN CS_FIXEDVALUE FV
            ON FV.EFFECTIVESTARTDATE <= PER.STARTDATE AND FV.EFFECTIVEENDDATE >= PER.ENDDATE
			AND FV.REMOVEDATE = v_eot
			AND FV.TENANTID = itenantId
			AND FV.NAME = 'VF - CAT TVTA - Recuperacion - Aporte'                  

	WHERE
		PER.REMOVEDATE = v_eot   
		AND PER.PERIODSEQ =  iperiodseq
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_APORTE_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_APORTE_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_APORTE_TEMP.',v_contador_debug);         
end;
 
procedure p_Inf_CAT_TVTA_APORTE ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
	w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_APORTE.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_APORTE WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	
	v_txtFechaLiquidacion := '';
			
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_APORTE.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_APORTE.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_CAT_TVTA_APORTE ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, CODIGO_COMERCIAL, CANAL, N_REGISTROS, APORTE_UNITARIO, APORTE_TOTAL, ID_PRODUCTO, 
												PRODUCTO, PORCENTAJE_APORTE, N_PRODUCTOS, APORTE_INICIAL, APORTE_PENDIENTE, APORTE_FINAL, APORTE_FINAL_UNITARIO )     
	SELECT
		PAYEESEQ,
		POSITIONSEQ,
		PERIODSEQ,
		PERIODO,
		CODIGO_COMERCIAL,
		CANAL,
		N_REGISTROS,
		APORTE_UNITARIO,
		APORTE_TOTAL,
		ID_PRODUCTO,
		PRODUCTO,
		PORCENTAJE_APORTE,
		N_PRODUCTOS,
		APORTE_INICIAL,
		APORTE_PENDIENTE,
		APORTE_FINAL,
		APORTE_FINAL_UNITARIO

	FROM ENEL_CAT_TVTA_APORTE_TEMP
	
	WHERE
		PERIODO =  iperiod
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_APORTE: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_APORTE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_APORTE.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_AM_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_AM_TEMP.', v_contador_debug);
 
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_AM_TEMP';
 
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_AM_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_AM_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_AM_TEMP ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO,  ORDERID,  LINENUMBER,  SUBLINENUMBER,  EVENTTYPEID,  CREDITTYPEID,  IMPORTE,  
												UNIDAD,  CODIGO_COMERCIAL,  FECHA_LIQUIDACION,  ESTADO,  OBSERVACIONES ) 
	SELECT
		PER.PERIODSEQ,
		CR.POSITIONSEQ,
		CR.PAYEESEQ,
		PER.NAME PERIODO,
		SO.ORDERID,
		ST.LINENUMBER,
		ST.SUBLINENUMBER,
		ET.EVENTTYPEID,
		CT.CREDITTYPEID,
		CR.VALUE IMPORTE,
		'EURO' UNIDADES,
		CR.GENERICATTRIBUTE4 CODIGO_COMERCIAL,
		v_txtFechaLiquidacion,
		CASE  
			WHEN CR.VALUE IS NULL THEN 'Pte Revisar'
			--WHEN iInterfaz ='ACTUALIZA_INFORMES_POST' AND CR.VALUE IS NOT NULL THEN 'Liquidado' -- RMM 10.01.2022 CAT TVTA se liquida por fuera, por lo que nunca debe aparecer liquidado
			ELSE 'Pte Liquidar'
		END ESTADO,
		CR.GENERICATTRIBUTE15 OBSERVACIONES
                    
	FROM CS_PERIOD PER
        INNER JOIN CS_SALESTRANSACTION ST
			ON ST.COMPENSATIONDATE BETWEEN PER.STARTDATE AND PER.ENDDATE - 1
			AND ST.TENANTID = itenantId
			AND ST.MODELSEQ = 0
			AND ST.PROCESSINGUNITSEQ = iprocessingUnitSeq
        
        INNER JOIN CS_SALESORDER SO 
            ON ST.SALESORDERSEQ = SO.SALESORDERSEQ 
			AND SO.REMOVEDATE = v_eot
			AND SO.PROCESSINGUNITSEQ = iprocessingUnitSeq
               
        INNER JOIN CS_EVENTTYPE ET 
            ON ST.EVENTTYPESEQ = ET.DATATYPESEQ
			AND ET.TENANTID = itenantId
			AND ET.REMOVEDATE = v_eot
        
        INNER JOIN CS_CREDIT CR 
            ON ST.SALESTRANSACTIONSEQ = CR.SALESTRANSACTIONSEQ
			AND CR.TENANTID = itenantId 
			AND CR.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND CR.PERIODSEQ =  iperiodseq
			AND ( CR.NAME = 'CD - CAT TVTA - Captacion - Ajuste Manual' 
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Ajuste Manual' 
				OR CR.NAME = 'CD - CAT TVTA - MKT - Ajuste Manual')

        INNER JOIN CS_CREDITTYPE CT 
            ON CR.CREDITTYPESEQ = CT.DATATYPESEQ
			AND CT.TENANTID = itenantId
			AND CT.REMOVEDATE = v_eot
        
        INNER JOIN CS_PLRUN P 
            ON CR.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot    
        AND PER.PERIODSEQ =  iperiodseq
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_AM_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_AM_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_AM_TEMP.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_AM ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_AM.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_AM WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	v_txtFechaLiquidacion := '';
	
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_AM.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_AM.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_AM ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO,  ORDERID,  LINENUMBER,  SUBLINENUMBER,  EVENTTYPEID,  CREDITTYPEID,  IMPORTE, 
											UNIDAD,  CODIGO_COMERCIAL,  FECHA_LIQUIDACION,  ESTADO,  OBSERVACIONES ) 
	SELECT
		PERIODSEQ,
		POSITIONSEQ,
		PAYEESEQ,
		PERIODO,
		ORDERID,
		LINENUMBER,
		SUBLINENUMBER,
		EVENTTYPEID,
		CREDITTYPEID,
		IMPORTE,
		UNIDAD,
		CODIGO_COMERCIAL,
		FECHA_LIQUIDACION,
		ESTADO,
		OBSERVACIONES
                    
	FROM ENEL_CAT_TVTA_AM_TEMP
	WHERE    
		PERIODO =  iperiod
	;
    
    /*BOM APM 16.04.2025 - Se comenta*/
    /*INSERT INTO ENELEXT.ENEL_LEADS_CAT_TVTA (PERIODO , ORDERID , LINENUMBER , SUBLINENUMBER , EVENTTYPEID , ESTADOCONTRATO ,
                                                IMPORTE , UNIDAD ,VALOR_1 , UNIDAD_1 , PRODUCTO_SCAWEB , CODIGO_PDS_OCAP , CICLO_FACTURACION ,
                                                 ESTADO , IDPROVEEDOR ,NUMPROVEEDOR , nom_credito ,WO_VISITA,VENTA_RELACIONADA )
                                                 
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        ETT.GENERICATTRIBUTE3,
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        TMP_PDS.PDS,
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
        when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
        else 'Pte Liquidar'
        end,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ect.name,
        ETT.GENERICATTRIBUTE4 AS WO_VISITA,
        ETT.GENERICATTRIBUTE24 AS VENTA_RELACIONADA
    FROM ENEL_TXN_TEMP ETT
		LEFT JOIN ENEL_CREDIT_TEMP ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			
		LEFT JOIN ENEL_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq


	;*/
    /*EOM APM 16.04.2025*/
    
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_AM: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_AM',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_AM.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_BONUSMALUS_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_BONUS_MALUS_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_BONUS_MALUS_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
	
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_BONUS_MALUS_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_BONUS_MALUS_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_BONUS_MALUS_TEMP ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO, POSICION, NOMBRE_MEDIDA, REALIZADO_QUOTASAT, OBJETIVO_TOTALBM,
														PORCENTAJE_OBTENIDO, SATISFACCION, VALOR_MEDIDA, PORCENTAJE_MINIMO, PRODUCTO, CUMPLIMIENTO ) 
	SELECT  
		PER.PERIODSEQ,
		ME.POSITIONSEQ,
		ME.PAYEESEQ,
		PER.NAME PERIODO,
		PO.NAME POSICION,
		ME.NAME NOMBRE_MEDIDA,
		ME.GENERICNUMBER1 REALIZADO_QUOTASAT,
		ME.GENERICNUMBER2 OBJETIVO_TOTALBM,
		ME.GENERICNUMBER5 PORCENTAJE_OBTENIDO,
		ME.GENERICNUMBER3 SATISFACCION,
		ME.VALUE VALOR_MEDIDA,
		ME.GENERICNUMBER5 PORCENTAJE_MINIMO,
		ME.GENERICATTRIBUTE1 PRODUCTO,
		ME.GENERICATTRIBUTE3 CUMPLIMIENTO
                    
	FROM CS_PERIOD PER
        INNER JOIN CS_POSITION PO
            ON PO.EFFECTIVESTARTDATE <= PER.STARTDATE AND PO.EFFECTIVEENDDATE >= PER.ENDDATE   
			AND PO.REMOVEDATE = v_eot
			AND PO.TENANTID = itenantId
			AND PO.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        
        INNER JOIN CS_MEASUREMENT ME
            ON ME.PERIODSEQ =  PER.PERIODSEQ
			AND ME.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
			AND ME.TENANTID = itenantId
			AND ME.PROCESSINGUNITSEQ = iprocessingUnitSeq
			AND ( ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 1'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 2'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 3'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 4'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 5'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 6'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 7'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % Consecucion - Prod 8'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % BM Consecucion'
				OR ME.NAME = 'MS - CAT TVTA - Emision - % BM Conversion'
				OR ME.NAME = 'MS - CAT TVTA - % BM Satisfaccion'
				OR ME.NAME = 'MS - CAT TVTA - Emision - Bonus Malus - Unitario'
				OR ME.NAME = 'MS - CAT TVTA - MKT - Bonus Malus - Unitario'
				)
                    
        INNER JOIN CS_PLRUN P 
            ON ME.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                
        LEFT JOIN CS_FIXEDVALUE FV
            ON FV.EFFECTIVESTARTDATE <= PER.STARTDATE AND FV.EFFECTIVEENDDATE >= PER.ENDDATE
			AND FV.REMOVEDATE = v_eot
			AND FV.TENANTID = itenantId
			AND FV.NAME = 'VF - CAT TVTA - Emision - % Consecucion Minimo Individual'     
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot 
        AND PER.PERIODSEQ =  iperiodseq    
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_BONUS_MALUS_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_BONUS_MALUS_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_BONUS_MALUS_TEMP.',v_contador_debug);         
end;
 
procedure p_Inf_CAT_TVTA_BONUS_MALUS ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_BONUS_MALUS.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_BONUS_MALUS WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_BONUS_MALUS.', v_contador_debug);
	
    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_BONUS_MALUS.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_BONUS_MALUS ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO, POSICION, NOMBRE_MEDIDA, REALIZADO_QUOTASAT, OBJETIVO_TOTALBM,
													SATISFACCION, PORCENTAJE_OBTENIDO, VALOR_MEDIDA, PORCENTAJE_MINIMO, PRODUCTO, CUMPLIMIENTO ) 
	SELECT
		PERIODSEQ,
		POSITIONSEQ,
		PAYEESEQ,
		PERIODO,
		POSICION,
		NOMBRE_MEDIDA,
		REALIZADO_QUOTASAT,
		OBJETIVO_TOTALBM,
		SATISFACCION,
		PORCENTAJE_OBTENIDO,
		VALOR_MEDIDA,
		PORCENTAJE_MINIMO,
		PRODUCTO,
		CUMPLIMIENTO

	FROM ENEL_CAT_TVTA_BONUS_MALUS_TEMP
    WHERE 
		PERIODO =  iperiod;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_BONUS_MALUS: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_BONUS_MALUS',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_BONUS_MALUS.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_IP_TOTAL_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_IP_TOTAL_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
	
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
	SELECT
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Penalizacion Ordinaria' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Penalizacion Ordinaria - Unitaria'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Penalizacion Ordinaria - Unitaria' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Penalizacion Ordinaria - Unitaria'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		NVL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		NVL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		NVL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS 

	FROM CS_PERIOD PER
        INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = itenantId 
			AND MEAS.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND MEAS.PERIODSEQ =  iperiodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Penalizacion Ordinaria - Unitaria'
        
        INNER JOIN TCMP.CS_POSITION POS
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = itenantId
			AND POS.EFFECTIVESTARTDATE <= SYSDATE
			AND POS.EFFECTIVEENDDATE > SYSDATE
			AND POS.REMOVEDATE = v_eot  
        
        INNER JOIN CS_CALENDAR CA
			ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE    
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  iperiodseq  
	;
               
	filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Penalización Ordinaria: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    --Ajuste Manual
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
    SELECT 
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Ajuste Manual' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Ajuste Manual - Unitarios'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Ajuste Manual - Unitarios' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Ajuste Manual - Unitarios'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		NVL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		NVL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		NVL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS 
                    
	FROM CS_PERIOD PER
        INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = itenantId 
			AND MEAS.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND MEAS.PERIODSEQ =  iperiodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Ajuste Manual - Unitarios'
        
        INNER JOIN TCMP.CS_POSITION POS
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = itenantId
			AND POS.EFFECTIVESTARTDATE <= SYSDATE
			AND POS.EFFECTIVEENDDATE > SYSDATE
			AND POS.REMOVEDATE = v_eot  
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  iperiodseq  
	;
               
	filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Ajuste Manual: '|| to_char(filas) || ' filas.', v_contador_debug);

    --Incentivos
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
    
	SELECT   
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Incentivos' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Incentivos - Unitarios'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Incentivos - Unitarios' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Incentivos - Unitarios'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		NVL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		NVL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		NVL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS
                    
	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = itenantId 
			AND MEAS.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND MEAS.PERIODSEQ =  iperiodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Incentivos - Unitarios'
        
        INNER JOIN TCMP.CS_POSITION POS 
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = itenantId
			AND POS.EFFECTIVESTARTDATE <= SYSDATE
			AND POS.EFFECTIVEENDDATE > SYSDATE
			AND POS.REMOVEDATE = v_eot  
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE    
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  iperiodseq  
	;
               
	filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    --Penalización Extraordinaria
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_TOTAL_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
    SELECT
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		'Penalizacion Extraordinaria' AS TIPO_CALCULO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Penalizacion Extra - Unitaria'    THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Penalizacion Extra - Unitaria' THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Penalizacion Extra - Unitaria'          THEN 'MKT Directo Cotel'
			ELSE 'ERR'
		END AS ACTIVIDAD,
		NVL(MEAS.VALUE,0) AS IMPORTE_UNITARIO,
		NVL(MEAS.GENERICNUMBER1,0) AS IMPORTE_TOTAL,
		NVL(MEAS.GENERICNUMBER3,0) AS TOTAL_VENTAS 
                    
	FROM CS_PERIOD PER
		INNER JOIN CS_MEASUREMENT MEAS
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = itenantId 
			AND MEAS.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND MEAS.PERIODSEQ =  iperiodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Penalizacion Extra - Unitaria'
        
        INNER JOIN TCMP.CS_POSITION POS 
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = itenantId
			AND POS.EFFECTIVESTARTDATE <= SYSDATE
			AND POS.EFFECTIVEENDDATE > SYSDATE
			AND POS.REMOVEDATE = v_eot  
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  iperiodseq  
	;
               
	filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP Penalizacion Extraordinaria: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL_TEMP.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_IP_TOTAL_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_IP_TOTAL_TEMP.',v_contador_debug);
end;

procedure p_Inf_CAT_TVTA_IP_TOTAL ( iperiod IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_IP_TOTAL.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_IP_TOTAL WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_IP_TOTAL.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_IP_TOTAL.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_TOTAL ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, TIPO_CALCULO, ACTIVIDAD, IMPORTE_UNITARIO, IMPORTE_TOTAL, TOTAL_VENTAS ) 
    SELECT 
		PERIODSEQ,
		PAYEESEQ,
		CODIGO_COMERCIAL,
		POSITIONSEQ,
		PERIODO,
		TIPO_CALCULO,
		ACTIVIDAD,
		IMPORTE_UNITARIO,
		IMPORTE_TOTAL,
		TOTAL_VENTAS
						
	FROM ENEL_CAT_TVTA_IP_TOTAL_TEMP
	WHERE
		PERIODO =  iperiod
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_TOTAL: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_IP_TOTAL',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_IP_TOTAL.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_IP_VENTA_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_IP_VENTA_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_IP_VENTA_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_IP_VENTA_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_IP_VENTA_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_VENTA_TEMP ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, ACTIVIDAD, TIPO_PENALIZACION, NUMERO_VENTAS, IMPORTE_PENALIZACION, TOTAL_PENALIZACION ) 
    SELECT
		PER.PERIODSEQ,
		MEAS.PAYEESEQ,
		POS.NAME AS CODIGO_COMERCIAL,
		MEAS.POSITIONSEQ,
		PER.NAME AS PERIODO,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Venta Duplicada'                      THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Captacion - Venta Incompleta'                     THEN 'CAT Captación'
			WHEN 'MS - CAT TVTA - Recuperacion - Venta Duplicada'                   THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - Recuperacion - Venta Incompleta'                  THEN 'CAT Recuperación'
			WHEN 'MS - CAT TVTA - MKT - Venta Duplicada'                            THEN 'MKT Directo Cotel'
			WHEN 'MS - CAT TVTA - MKT - Venta Incompleta'                           THEN 'MKT Directo Cotel'
			ELSE                                                                         'ERR'
		END AS ACTIVIDAD,
		CASE MEAS.NAME
			WHEN 'MS - CAT TVTA - Captacion - Venta Duplicada'                      THEN 'Venta Duplicada'
			WHEN 'MS - CAT TVTA - Captacion - Venta Incompleta'                     THEN 'Venta Incompleta'
			WHEN 'MS - CAT TVTA - Recuperacion - Venta Duplicada'                   THEN 'Venta Duplicada'
			WHEN 'MS - CAT TVTA - Recuperacion - Venta Incompleta'                  THEN 'Venta Incompleta'
			WHEN 'MS - CAT TVTA - MKT - Venta Duplicada'                            THEN 'Venta Duplicada'
			WHEN 'MS - CAT TVTA - MKT - Venta Incompleta'                           THEN 'Venta Incompleta'
			ELSE                                                                         'ERR'
		END AS TIPO_PENALIZACION,
		NVL(MEAS.GENERICNUMBER3,0) AS NUMERO_VENTAS,
		NVL(MEAS.GENERICNUMBER4,0) AS IMPORTE_PENALIZACION,
		NVL(MEAS.VALUE,0) AS TOTAL_PENALIZACION 
                  
	FROM CS_PERIOD PER
        INNER JOIN CS_MEASUREMENT MEAS 
			ON PER.PERIODSEQ = MEAS.PERIODSEQ
			AND MEAS.TENANTID = itenantId 
			AND MEAS.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND MEAS.PERIODSEQ =  iperiodseq
			AND MEAS.NAME LIKE 'MS - CAT TVTA - % - Venta %'
        
        INNER JOIN TCMP.CS_POSITION POS 
			ON POS.RULEELEMENTOWNERSEQ = MEAS.POSITIONSEQ
			AND POS.TENANTID = itenantId
			AND POS.EFFECTIVESTARTDATE <= SYSDATE
			AND POS.EFFECTIVEENDDATE > SYSDATE 
			AND POS.REMOVEDATE = v_eot 
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE    
		PER.REMOVEDATE = v_eot     
		AND PER.PERIODSEQ =  iperiodseq  
	;
               
	filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_VENTA_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_IP_VENTA_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_IP_VENTA_TEMP.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_IP_VENTA ( iperiod IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_IP_VENTA.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_IP_VENTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_IP_VENTA.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_IP_VENTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_IP_VENTA ( PERIODSEQ, PAYEESEQ, CODIGO_COMERCIAL, POSITIONSEQ, PERIODO, ACTIVIDAD, TIPO_PENALIZACION, NUMERO_VENTAS, IMPORTE_PENALIZACION, TOTAL_PENALIZACION ) 
    SELECT 
		PERIODSEQ,
		PAYEESEQ,
		CODIGO_COMERCIAL,
		POSITIONSEQ,
		PERIODO,
		ACTIVIDAD,
		TIPO_PENALIZACION,
		NUMERO_VENTAS,
		IMPORTE_PENALIZACION,
		TOTAL_PENALIZACION
	
	FROM ENEL_CAT_TVTA_IP_VENTA_TEMP
	WHERE
		PERIODO =  iperiod
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_IP_VENTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_IP_VENTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_IP_VENTA.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_INCENPENAL_TEMP ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_INCEN_PENAL_TEMP.', v_contador_debug);
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CAT_TVTA_INCEN_PENAL_TEMP';
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_INCEN_PENAL_TEMP.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_INCEN_PENAL_TEMP.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_INCEN_PENAL_TEMP ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_CALCULO, 
														CREDITTYPEID, IMPORTE, UNIDAD, EMPRESA, CODIGO_COMERCIAL, FECHA_LIQUIDACION, TERRITORIO, DELEGACION, CAMPANIA, OBSERVACIONES ) 
	SELECT
		PER.PERIODSEQ,
		CR.POSITIONSEQ,
		CR.PAYEESEQ,
		PER.NAME PERIODO,
		SO.ORDERID,
		ST.LINENUMBER,
		ST.SUBLINENUMBER,
		ET.EVENTTYPEID,
		CASE CR.NAME
			WHEN 'CD - CAT TVTA - Captacion - Incentivos'                               THEN 'Incentivos'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Extra'                       THEN 'Penalizacion Extra'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Ordinaria'                   THEN 'Penalizacion Ordinaria'
			WHEN 'CD - CAT TVTA - Recuperacion - Incentivos'                            THEN 'Incentivos'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Extra'                    THEN 'Penalizacion Extra'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Ordinaria'                THEN 'Penalizacion Ordinaria'
			WHEN 'CD - CAT TVTA - MKT - Incentivos'                                     THEN 'Incentivos'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Extra'                             THEN 'Penalizacion Extra'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Ordinaria'                         THEN 'Penalizacion Ordinaria'
			ELSE                                                                         'ERR'
		END AS TIPO_CALCULO,
		CASE CR.NAME
			WHEN 'CD - CAT TVTA - Captacion - Incentivos'                               THEN 'CAT Captacion'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Extra'                       THEN 'CAT Captacion'
			WHEN 'CD - CAT TVTA - Captacion - Penalizacion Ordinaria'                   THEN 'CAT Captacion'
			WHEN 'CD - CAT TVTA - Recuperacion - Incentivos'                            THEN 'CAT Recuperacion'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Extra'                    THEN 'CAT Recuperacion'
			WHEN 'CD - CAT TVTA - Recuperacion - Penalizacion Ordinaria'                THEN 'CAT Recuperacion'
			WHEN 'CD - CAT TVTA - MKT - Incentivos'                                     THEN 'MKT Directo Cotel'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Extra'                             THEN 'MKT Directo Cotel'
			WHEN 'CD - CAT TVTA - MKT - Penalizacion Ordinaria'                         THEN 'MKT Directo Cotel'
			ELSE                                                                         'ERR'
		END AS CREDITYPEID,
		CR.VALUE IMPORTE,
		'EURO' UNIDADES,
		CR.GENERICATTRIBUTE11 EMPRESA,
		CR.GENERICATTRIBUTE4 CODIGO_COMERCIAL,
		v_txtFechaLiquidacion,
		CR.GENERICATTRIBUTE7 TERRITORIO,
		CR.GENERICATTRIBUTE10 DELEGACION,
		CR.GENERICATTRIBUTE9 CAMPANIA,
		CR.GENERICATTRIBUTE15 OBSERVACIONES
                    
	FROM CS_PERIOD PER
        INNER JOIN CS_SALESTRANSACTION ST
			ON ST.COMPENSATIONDATE BETWEEN PER.STARTDATE AND PER.ENDDATE - 1
			AND ST.TENANTID = itenantId
			AND ST.MODELSEQ = 0
			AND ST.PROCESSINGUNITSEQ = iprocessingUnitSeq
        
        INNER JOIN CS_SALESORDER SO 
            ON ST.SALESORDERSEQ = SO.SALESORDERSEQ 
			AND SO.REMOVEDATE = v_eot
			AND SO.PROCESSINGUNITSEQ = iprocessingUnitSeq
               
        INNER JOIN CS_EVENTTYPE ET 
            ON ST.EVENTTYPESEQ = ET.DATATYPESEQ
			AND ET.TENANTID = itenantId
			AND ET.REMOVEDATE = v_eot
        
        INNER JOIN CS_CREDIT CR 
            ON ST.SALESTRANSACTIONSEQ = CR.SALESTRANSACTIONSEQ
			AND CR.TENANTID = itenantId 
			AND CR.PROCESSINGUNITSEQ = iprocessingUnitSeq 
			AND CR.PERIODSEQ =  iperiodseq
			AND ( CR.NAME = 'CD - CAT TVTA - Captacion - Incentivos'
				OR CR.NAME = 'CD - CAT TVTA - Captacion - Penalizacion Extra'
				OR CR.NAME = 'CD - CAT TVTA - Captacion - Penalizacion Ordinaria'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Incentivos'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Penalizacion Extra'
				OR CR.NAME = 'CD - CAT TVTA - Recuperacion - Penalizacion Ordinaria'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Incentivos'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Penalizacion Extra'
				OR CR.NAME = 'CD - CAT TVTA - MKT - Penalizacion Ordinaria')

        INNER JOIN CS_CREDITTYPE CT 
            ON CR.CREDITTYPESEQ = CT.DATATYPESEQ
			AND CT.TENANTID = itenantId
			AND CT.REMOVEDATE = v_eot
        
        INNER JOIN CS_PLRUN P 
            ON CR.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion       
        
        INNER JOIN CS_CALENDAR CA
            ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual'

	WHERE
		PER.REMOVEDATE = v_eot     
        AND PER.PERIODSEQ =  iperiodseq  
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_INCEN_PENAL_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_INCEN_PENAL_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_INCEN_PENAL_TEMP.',v_contador_debug);         
end;

procedure p_Inf_CAT_TVTA_INCEN_PENAL ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CAT_TVTA_INCEN_PENAL.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CAT_TVTA_INCEN_PENAL WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CAT_TVTA_INCEN_PENAL.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_CAT_TVTA_INCEN_PENAL.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CAT_TVTA_INCEN_PENAL ( PERIODSEQ, POSITIONSEQ, PAYEESEQ, PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, TIPO_CALCULO, CREDITTYPEID, 
													IMPORTE, UNIDAD, EMPRESA, CODIGO_COMERCIAL, FECHA_LIQUIDACION, TERRITORIO, DELEGACION, CAMPANIA, OBSERVACIONES )     
	SELECT
		PERIODSEQ,
		POSITIONSEQ,
		PAYEESEQ,
		PERIODO,
		ORDERID,
		LINENUMBER,
		SUBLINENUMBER,
		EVENTTYPEID,
		TIPO_CALCULO,
		CREDITTYPEID,
		IMPORTE,
		UNIDAD,
		EMPRESA,
		CODIGO_COMERCIAL,
		FECHA_LIQUIDACION,
		TERRITORIO,
		DELEGACION,
		CAMPANIA,
		OBSERVACIONES
                    
	FROM ENEL_CAT_TVTA_INCEN_PENAL_TEMP
	WHERE
		PERIODO =  iperiod
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CAT_TVTA_INCEN_PENAL: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CAT_TVTA_INCEN_PENAL',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CAT_TVTA_INCEN_PENAL.',v_contador_debug);         
end;

procedure p_Inf_Factura_CAT_TVTA_Detalle ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaPeriodoSiguiente date;
    v_txtMes_Liquidacion VARCHAR2(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_FACTCAT_TVTA_DETALLE.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_FACTCAT_TVTA_DETALLE WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_FACTCAT_TVTA_DETALLE.', v_contador_debug);

	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');

    w_debug('Insertando Registros de datos en tabla ENEL_FACTCAT_TVTA_DETALLE.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_FACTCAT_TVTA_DETALLE ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, MES_LIQUIDACION, NOMBRE_FISCAL, DIRECCION, COD_POSTAL, PROVINCIA, CIF, ORDERID,
													CANAL, PRODUCTO, TERRITORIO, HERRAMIENTA, BBDD, EMPRESA, CODIGO_COMERCIAL, DELEGACION, CAMPANIA, PB_UNITARIO_MEDIO, PROVEEDOR,
                                                    SUBCANAL,PROVEEDOR2) 
	SELECT
		PAGO.PAYEESEQ,
		PAGO.POSITIONSEQ,
		PAGO.PERIODSEQ,
		PAGO.PERIODO,
		v_txtMes_Liquidacion MES_LIQUIDACION,
		PA.LASTNAME NOMBRE_FISCAL,
		PA.GENERICATTRIBUTE3 DIRECCION,
		PA.GENERICATTRIBUTE4 COD_POSTAL,
		PA.GENERICATTRIBUTE5 PROVINCIA,
		PA.GENERICATTRIBUTE1 CIF,
		PAGO.CONTRATO ORDERID,
		PAGO.CREDITTYPEID CANAL,
/* BOM CAL0134 DCR 19.04.2022 
Old Code 
		PROV.SUBACTIVIDAD PRODUCTO,
New code */
        PAGO.PRODUCTO PRODUCTO,
/* EOM CAL0134 DCR 19.04.2022 */
		PAGO.TERRITORIO,
		PAGO.HERRAMIENTA,
		PAGO.BBDD,
		PAGO.EMPRESA,
		PAGO.CODIGO_COMERCIAL,
		PAGO.DELEGACION,
		PAGO.CAMPANIA,
		PAGO.VALOR_FINAL,
		PAGO.PROVEEDOR,
/* BOM CAL0134 DCR 19.04.2022 */
        POS.NAME as SUBCANAL,
        PAGO.PROVEEDOR2
/* EOM CAL0134 DCR 19.04.2022 */
				
	FROM ENEL_CAT_TVTA_RESUM_PAGO PAGO
/* BOM CAL0134 DCR 19.04.2022 
Old Code
		INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA PROV
			ON PAGO.PROVEEDOR = PROV.IDPROVEEDOR 
			AND PAGO.PERIODSEQ = PROV.PERIODSEQ
*/
        --LEFT JOIN ENEL_PRODUCTOS_TEMP_CAT_TVTA PROD
          --  ON PROD.PRODUCTID = PAGO.CONCEPTO_LIQ
/* EOM CAL0134 DCR 19.04.2022 */
        INNER JOIN CS_PERIOD PER
			ON PAGO.PERIODSEQ = PER.PERIODSEQ
			AND PER.REMOVEDATE = v_eot      
			AND PER.PERIODSEQ =  iperiodseq
        
        INNER JOIN CS_CALENDAR CA
			ON PER.CALENDARSEQ = CA.CALENDARSEQ 
			AND CA.REMOVEDATE = v_eot
			AND CA.NAME = 'Calendario Mensual' 
            
           
         INNER JOIN CS_PARTICIPANT PA
           ON PAGO.PAYEESEQ = PA.PAYEESEQ 
       	    AND PA.REMOVEDATE = v_eot
			AND PA.TENANTID = itenantId
			AND PA.EFFECTIVESTARTDATE <= PER.STARTDATE AND PA.EFFECTIVEENDDATE >= PER.ENDDATE
/* BOM CAL0134 DCR 19.04.2022 */
        INNER JOIN CS_POSITION POS
            ON POS.PAYEESEQ = PA.PAYEESEQ
            AND pa.userid = POS.NAME /* CAL0176 RMM 14.07.2022  eliminamos duplicados*/
            AND pos.TENANTID = itenantId
            AND pos.REMOVEDATE = v_eot
            AND POS.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND POS.EFFECTIVEENDDATE >= PER.ENDDATE - 1
/* EOM CAL0134 DCR 19.04.2022 */
                        
	WHERE
		PAGO.PERIODSEQ = iperiodseq
        and PAGO.CONTRATO is not null
	;
               
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_FACTCAT_TVTA_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_FACTCAT_TVTA_DETALLE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTCAT_TVTA_DETALLE.',v_contador_debug);         
end;

procedure p_Inf_Factura_CAT_TVTA_Portada ( iperiod IN VARCHAR2 )
AS
	v_txtFechaLiquidacion VARCHAR2(10);
	v_fechaActual date;
begin
	w_debug('Inicio Borrado de la tabla ENEL_FACTCAT_TVTA_PORTADA.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_FACTCAT_TVTA_PORTADA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;

	w_debug('Fin Borrado de la tabla ENEL_FACTCAT_TVTA_PORTADA.', v_contador_debug);

    v_fechaActual := sysdate;

	w_debug('Insertando Registros de datos en tabla ENEL_FACTCAT_TVTA_PORTADA.' ,  v_contador_debug);
 
	INSERT INTO ENELEXT.ENEL_FACTCAT_TVTA_PORTADA ( PAYEESEQ, POSITIONSEQ, PERIODSEQ, PERIODO, MES_LIQUIDACION, FECHA_LIQUIDACION, NUMERO_RESUMEN, NOMBRE_FISCAL, 
													CODIGO_COMERCIAL, CIF, DIRECCION, COD_POSTAL, PROVINCIA, DELEGACION, CANAL, PRODUCTO, TERRITORIO, PROVEEDOR, 
													UNIDADES, PB_UNITARIO_MEDIO, IMPORTE_FINAL,PROVEEDOR2 ) 
	--Hacemos una subconsulta para aquellas combinaciones de canal/producto/territorio con diferentes valores unitarios medios. Así evitamos tener dos SUR con dos unitarios medios diferentes
    SELECT 
		X.PAYEESEQ,
		X.POSITIONSEQ,
		X.PERIODSEQ,
		X.PERIODO,
		X.MES_LIQUIDACION,
		X.FECHA_LIQUIDACION,
		X.NUMERO_RESUMEN,
		X.NOMBRE_FISCAL,
		X.CODIGO_COMERCIAL,
		X.CIF,
		X.DIRECCION,
		X.COD_POSTAL,
		X.PROVINCIA,
		X.DELEGACION,
		X.CANAL,
		X.PRODUCTO,
		X.TERRITORIO,
		X.PROVEEDOR,
		SUM(X.UNIDADES),
		SUM(IMPORTE_TOTAL) / SUM (UNIDADES) AS PB_UNITARIO_MEDIO,
		SUM(IMPORTE_TOTAL),
        X.PROVEEDOR2
	FROM
		(SELECT    
			FACDET.PAYEESEQ,
			FACDET.POSITIONSEQ,
			FACDET.PERIODSEQ,
			FACDET.PERIODO,
			FACDET.MES_LIQUIDACION,
			v_fechaActual as FECHA_LIQUIDACION,
			--, SUBSTR(FACDET.MES_LIQUIDACION,1,4) || '/'||  FACDET.CODIGO_COMERCIAL as NUMERO_RESUMEN  -- YYYY/PDS
			FACDET.MES_LIQUIDACION || '/' || FACDET.CODIGO_COMERCIAL as NUMERO_RESUMEN, --YYYYMM/PDS
			FACDET.NOMBRE_FISCAL,
			FACDET.CODIGO_COMERCIAL,
			FACDET.CIF,
			FACDET.DIRECCION,
			FACDET.COD_POSTAL,
			FACDET.PROVINCIA,
			'' AS DELEGACION, --Valor de delegación a nulo
			--, FACDET.DELEGACION
			FACDET.CANAL,
			FACDET.PRODUCTO,
			FACDET.TERRITORIO,
			FACDET.PROVEEDOR,
			COUNT(*) UNIDADES,
			FACDET.PB_UNITARIO_MEDIO,
			COUNT(*) * FACDET.PB_UNITARIO_MEDIO AS IMPORTE_TOTAL,
            FACDET.PROVEEDOR2

		FROM ENEL_FACTCAT_TVTA_DETALLE FACDET
		WHERE FACDET.PERIODO = iperiod
		GROUP BY   
			FACDET.PAYEESEQ,
			FACDET.POSITIONSEQ,
			FACDET.PERIODSEQ,
			FACDET.PERIODO,
			FACDET.MES_LIQUIDACION,
			SUBSTR(FACDET.MES_LIQUIDACION,1,4) || '/'||  FACDET.CODIGO_COMERCIAL,
			FACDET.NOMBRE_FISCAL,
			FACDET.CODIGO_COMERCIAL,
			FACDET.CIF,
			FACDET.DIRECCION,
			FACDET.COD_POSTAL,
			FACDET.PROVINCIA,
			--, FACDET.DELEGACION
			FACDET.CANAL,
			FACDET.PRODUCTO,
			FACDET.TERRITORIO,
			FACDET.PROVEEDOR,
			FACDET.PB_UNITARIO_MEDIO,
            FACDET.PROVEEDOR2
		) X
    
    GROUP BY 
		X.PAYEESEQ,
		X.POSITIONSEQ,
		X.PERIODSEQ,
		X.PERIODO,
		X.MES_LIQUIDACION,
		X.FECHA_LIQUIDACION,
		X.NUMERO_RESUMEN,
		X.NOMBRE_FISCAL,
		X.CODIGO_COMERCIAL,
		X.CIF,
		X.DIRECCION,
		X.COD_POSTAL,
		X.PROVINCIA,
		X.DELEGACION,
		X.CANAL,
		X.PRODUCTO,
		X.TERRITORIO,
		X.PROVEEDOR,
        X.PROVEEDOR2
	;

	filas := sql%rowcount;
	COMMIT;
 
	w_debug('Fin Carga de la tabla ENEL_FACTCAT_TVTA_PORTADA: '|| to_char(filas) || ' filas.', v_contador_debug);

	dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_FACTCAT_TVTA_PORTADA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTCAT_TVTA_PORTADA.',v_contador_debug);
end;

procedure p_Inf_Factura_CAT_TVTA_Depo (iperiodseq IN VARCHAR2)
AS
begin
	w_debug('Inicio Borrado de la tabla ENEL_FACTCAT_TVTA_DEPOSITOS.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_FACTCAT_TVTA_DEPOSITOS WHERE PERIODSEQ = iperiodseq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;

	w_debug('Fin Borrado de la tabla ENEL_FACTCAT_TVTA_DEPOSITOS.', v_contador_debug);

	w_debug('Insertando Registros de datos en tabla ENEL_FACTCAT_TVTA_DEPOSITOS.' ,  v_contador_debug);
 
	INSERT INTO ENELEXT.ENEL_FACTCAT_TVTA_DEPOSITOS (TENANTID, PERIODSEQ, POSITIONSEQ, EARNINGGROUPID, IMPORTE)
	SELECT 
		TENANTID,
		PERIODSEQ,
		POSITIONSEQ,
		EARNINGGROUPID,
		SUM(VALUE)
	FROM ENELEXT.ENEL_DEPOSIT_TEMP_CAT_TVTA
	GROUP BY 
		TENANTID,
		PERIODSEQ,
		POSITIONSEQ,
		EARNINGGROUPID
	;
 
	filas := sql%rowcount;
	COMMIT;
 
	w_debug('Fin Carga de la tabla ENEL_FACTCAT_TVTA_DEPOSITOS: '|| to_char(filas) || ' filas.', v_contador_debug);

	dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_FACTCAT_TVTA_DEPOSITOS',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTCAT_TVTA_DEPOSITOS.',v_contador_debug);
end;

procedure p_Informe_Transaccion (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
	w_debug('Inicio Borrado de la tabla ENEL_INFORME_TRANSACCION.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_INFORME_TRANSACCION WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;

	w_debug('Fin Borrado de la tabla ENEL_INFORME_TRANSACCION.', v_contador_debug);

	w_debug('Insertando Registros de datos en tabla ENEL_INFORME_TRANSACCION.' ,  v_contador_debug);
 
INSERT INTO ENELEXT.ENEL_INFORME_TRANSACCION (periodo, orderid, channel, eventtypeid, compensationdate, credit_name, credit_value,
						concepto_liquidacion, plazo_motivo, provincia, zona, equipamiento, genericdate1,
						producto, tipo_servicio, nombre_servicio, estado_ga3, canal_entrada, agente, incidencia,
						fecha_insercion, fecha_firma, parte_digitalizado, contrato, positionname, usuariocrm,
						num_pedido_crm, empresa_entrante, linea_pedido, tipo_posicion, segmento, campana, cups, agrupador)

	SELECT 
	(select name from cs_period where periodseq = cred.periodseq and removedate = '01/01/2200') as periodo, --GA1
	ordtxn.orderid, --GA2
	TXN.CHANNEL, --GA3
	ETYPE.EVENTTYPEID, --GA4
	TXN.COMPENSATIONDATE, --GD1
	cred.name , --GA5
	cred.value , --GN1
	cred.GENERICATTRIBUTE1, --GA6 --Concepto Liquidación / Lote 
	cred.GENERICATTRIBUTE5, --GA7 --Plazo / Motivo / Campaña / Canal Entrada
	cred.GENERICATTRIBUTE6, --GA8 --Provincia
	cred.GENERICATTRIBUTE7, --GA9  --Zona /Territorio
	cred.GENERICATTRIBUTE10, --GA10 --Equipamiento / Delegación / Cups 
	cred.genericdate1, --GD2 --Fecha Cálculo / Fecha Realización / Fecha Ganada / Fecha Insercción 
	TXN.PRODUCTID as Producto, --GA11
	TXN.GENERICATTRIBUTE1 as Tipo_Servicio, --GA12 --Tipo / Estado Líneas
	TXN.GENERICATTRIBUTE2 as Nombre_Servicio, --GA13 --Subtipo Producto / Subtipo Precio 
	TXN.GENERICATTRIBUTE3 as Estado_GA3, --GA14 --Estado Oportunidad / Estado Contrato CRM / Estado 
	TXN.GENERICATTRIBUTE6, --GA15 --Canal Entrada Contrato / Herramienta
	TXN.GENERICATTRIBUTE19 as Agente, --GA16 --Cod. Comercial Rep / Agente
	TXN.GENERICATTRIBUTE20 as Incidencia, --GA17 --Incidencia
	etxn0.GENERICDATE1 as Fecha_INSERCION, --GD3 --Fecha Apertura / Fecha Creación / Fecha Inserción
	TXN.GENERICDATE3 as Fecha_Firma, --GD4  --Fecha Efectiva 
	CASE WHEN TXN.GENERICBOOLEAN1 IS NULL THEN 'NO' ELSE 'SI' end, --GA18 --Parte Digitalizado / Registro Principal / Gestión Cartera
	TXN.PONUMBER as Contrato,  --GA19
	TXNASS.POSITIONNAME, --GA20
	TXNASS.GENERICATTRIBUTE2 as UsuarioCRM, --GA21 
	etxn0.GENERICATTRIBUTE13 as Num_Pedido_CRM, --GA22 --Línea Negocio
	etxn0.GENERICATTRIBUTE16 as EmpresaEntrante, --GA23 --Empresa Entrante
	TXN.GENERICATTRIBUTE23, --GA24 --Línea Pedido / Línea Producto / CallId 
	TXN.GENERICATTRIBUTE30, --GA28 --Tipo Posición / Posición Usuario Asignado 
	TXN.GENERICATTRIBUTE31, --GA25 --Segmento 
	TXN.GENERICATTRIBUTE32, --GA26 --Campaña / Lote
	TXN.ALTERNATEORDERNUMBER AS CUPS, --GA27
	TXN.GENERICATTRIBUTE12  as AGRUPADOR-- GA29  --rmm 13.09.2022
	
	
FROM cs_salestransaction txn 
INNER JOIN cs_salesorder ordtxn
ON txn.salesorderseq = ordtxn.salesorderseq
AND ordtxn.removedate = '01/01/2200'
AND txn.tenantid = 'ENEL'
AND ordtxn.processingunitseq = txn.processingunitseq
--AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
AND txn.modelseq = 0
AND txn.processingunitseq = 38280596832649518
AND ordtxn.tenantid = txn.tenantid

INNER JOIN cs_eventtype etype
ON txn.eventtypeseq = etype.datatypeseq
AND etype.removedate = '01/01/2200'
AND txn.tenantid = etype.tenantid

LEFT JOIN cs_gasalestransaction etxn0
ON txn.salestransactionseq = etxn0.salestransactionseq
AND etxn0.tenantid = txn.tenantid
AND txn.processingunitseq = etxn0.processingunitseq
AND etxn0.pagenumber = 0
AND etxn0.compensationdate = txn.compensationdate

LEFT JOIN cs_transactionassignment txnass
ON txn.salestransactionseq = txnass.salestransactionseq
AND txn.processingunitseq = txnass.processingunitseq
AND txnass.tenantid = txn.tenantid
AND txn.compensationdate = txnass.compensationdate
AND txnass.setnumber > 0

LEFT JOIN cs_credit cred
on  cred.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ



where (select name from cs_period where periodseq = cred.periodseq and removedate = '01/01/2200')= iperiod
 --and ETYPE.EVENTTYPEID not like 'Baja Contrato TVTA' --APM 15.03.2023 --APM 20.05.2026 Se comenta filtro
 ;
	filas := sql%rowcount;
	COMMIT;
 
 INSERT INTO ENELEXT.ENEL_INFORME_TRANSACCION (periodo, orderid, channel, eventtypeid, compensationdate, credit_name, credit_value,
						concepto_liquidacion, plazo_motivo, provincia, zona, equipamiento, genericdate1,
						producto, tipo_servicio, nombre_servicio, estado_ga3, canal_entrada, agente, incidencia,
						fecha_insercion, fecha_firma, parte_digitalizado, contrato, positionname, usuariocrm,
						num_pedido_crm, empresa_entrante, linea_pedido, tipo_posicion, segmento, campana, cups, agrupador)
 
 SELECT 
    (select name from cs_period where periodseq = cred.periodseq and removedate = '01/01/2200') as periodo, --GA1
    ordtxn.orderid, --GA2
    TXN.CHANNEL, --GA3
    ETYPE.EVENTTYPEID, --GA4
    TXN.COMPENSATIONDATE, --GD1
    INCE.NAME, --GA5
    COMMI.VALUE , --GN1
    cred.GENERICATTRIBUTE1, --GA6 --Concepto Liquidación / Lote 
    cred.GENERICATTRIBUTE5, --GA7 --Plazo / Motivo / Campaña / Canal Entrada
    cred.GENERICATTRIBUTE6, --GA8 --Provincia
    cred.GENERICATTRIBUTE7, --GA9  --Zona /Territorio
    cred.GENERICATTRIBUTE10, --GA10 --Equipamiento / Delegación / Cups 
    cred.genericdate1, --GD2 --Fecha Cálculo / Fecha Realización / Fecha Ganada / Fecha Insercción 
    TXN.PRODUCTID as Producto, --GA11
    TXN.GENERICATTRIBUTE1 as Tipo_Servicio, --GA12 --Tipo / Estado Líneas
    TXN.GENERICATTRIBUTE2 as Nombre_Servicio, --GA13 --Subtipo Producto / Subtipo Precio 
    TXN.GENERICATTRIBUTE3 as Estado_GA3, --GA14 --Estado Oportunidad / Estado Contrato CRM / Estado 
    TXN.GENERICATTRIBUTE6, --GA15 --Canal Entrada Contrato / Herramienta
    TXN.GENERICATTRIBUTE19 as Agente, --GA16 --Cod. Comercial Rep / Agente
    TXN.GENERICATTRIBUTE20 as Incidencia, --GA17 --Incidencia
    etxn0.GENERICDATE1 as Fecha_INSERCION, --GD3 --Fecha Apertura / Fecha Creación / Fecha Inserción
    TXN.GENERICDATE3 as Fecha_Firma, --GD4  --Fecha Efectiva 
    CASE WHEN TXN.GENERICBOOLEAN1 IS NULL THEN 'NO' ELSE 'SI' end, --GA18 --Parte Digitalizado / Registro Principal / Gestión Cartera
    TXN.PONUMBER as Contrato,  --GA19
    TXNASS.POSITIONNAME, --GA20
    TXNASS.GENERICATTRIBUTE2 as UsuarioCRM, --GA21 
    etxn0.GENERICATTRIBUTE13 as Num_Pedido_CRM, --GA22 --Línea Negocio
    etxn0.GENERICATTRIBUTE16 as EmpresaEntrante, --GA23 --Empresa Entrante
    TXN.GENERICATTRIBUTE23, --GA24 --Línea Pedido / Línea Producto / CallId 
    TXN.GENERICATTRIBUTE30, --GA28 --Tipo Posición / Posición Usuario Asignado 
    TXN.GENERICATTRIBUTE31, --GA25 --Segmento 
    TXN.GENERICATTRIBUTE32, --GA26 --Campaña / Lote
    TXN.ALTERNATEORDERNUMBER AS CUPS, --GA27
    TXN.GENERICATTRIBUTE12  as AGRUPADOR-- GA29  --rmm 13.09.2022
    FROM cs_salestransaction txn 
        INNER JOIN cs_salesorder ordtxn
            ON txn.salesorderseq = ordtxn.salesorderseq
            AND ordtxn.removedate = '01/01/2200'
            AND txn.tenantid = 'ENEL'
            AND ordtxn.processingunitseq = txn.processingunitseq
            --AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
            AND txn.modelseq = 0
            AND txn.processingunitseq = 38280596832649518
            AND ordtxn.tenantid = txn.tenantid

        INNER JOIN cs_eventtype etype
            ON txn.eventtypeseq = etype.datatypeseq
            AND etype.removedate = '01/01/2200'
            AND txn.tenantid = etype.tenantid

        LEFT JOIN cs_gasalestransaction etxn0
            ON txn.salestransactionseq = etxn0.salestransactionseq
            AND etxn0.tenantid = txn.tenantid
            AND txn.processingunitseq = etxn0.processingunitseq
            AND etxn0.pagenumber = 0
            AND etxn0.compensationdate = txn.compensationdate

        LEFT JOIN cs_transactionassignment txnass
            ON txn.salestransactionseq = txnass.salestransactionseq
            AND txn.processingunitseq = txnass.processingunitseq
            AND txnass.tenantid = txn.tenantid
            AND txn.compensationdate = txnass.compensationdate
            AND txnass.setnumber > 0

        LEFT JOIN cs_credit cred
            on  cred.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = CRED.CREDITSEQ
            AND COMMI.PAYEESEQ = CRED.PAYEESEQ
        LEFT JOIN CS_INCENTIVE INCE 
            ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ


    where (select name from cs_period where periodseq = cred.periodseq and removedate = '01/01/2200')= iperiod
        --and ETYPE.EVENTTYPEID not like 'Baja Contrato TVTA' --APM 15.03.2023 --APM 20.05.2026 Se comenta filtro
        AND COMMI.VALUE<>0 
        AND COMMI.VALUE IS NOT NULL 
        AND (INCE.NAME LIKE 'C - CAT TVTA%Rappel Incremental%' 
            or INCE.NAME LIKE '%TM7%' 
            or INCE.NAME LIKE '%TM60%')            
 ;
	filas := sql%rowcount;
	COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_INFORME_TRANSACCION: '|| to_char(filas) || ' filas.', v_contador_debug);

	dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_INFORME_TRANSACCION',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INFORME_TRANSACCION.',v_contador_debug);
end;


-- BOM CAL0124 DCR 11.03.22
procedure p_Temporal_TXN_truncate (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP.', v_contador_debug);    
end;

procedure p_Temporal_Transacciones (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Cargando tabla ENEL_TXN_TEMP NUEVA. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);
	
    INSERT INTO ENELEXT.ENEL_TXN_TEMP( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, 
										ACCOUNTINGDATE, PRODUCTID, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, 
										GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, 
										GENERICATTRIBUTE14, GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICATTRIBUTE17, GENERICATTRIBUTE18,GENERICATTRIBUTE19, GENERICATTRIBUTE20, 
                                        GENERICATTRIBUTE21, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICDATE3, GENERICDATE4, GENERICDATE5, GENERICBOOLEAN2, 
                                        PONUMBER, DATASOURCE, TAD_ADDRESS1, TAD_CITY, TAD_STATE, TAD_POSTALCODE, TAD_INDUSTRY, TAD_GEOGRAPHY, TAS_POSITIONNAME, 
										TAS_GENERICATTRIBUTE1, TAS_GENERICATTRIBUTE2, TAS_GENERICNUMBER1, TAS_GENERICNUMBER2, TEX0_GENERICATTRIBUTE4, TEX0_GENERICATTRIBUTE5, 
										TEX0_GENERICATTRIBUTE6, TEX0_GENERICATTRIBUTE7, TEX0_GENERICATTRIBUTE8, TEX0_GENERICATTRIBUTE9, TEX0_GENERICATTRIBUTE10, 
										TEX0_GENERICATTRIBUTE11, TEX0_GENERICATTRIBUTE12, TEX0_GENERICATTRIBUTE13, TEX0_GENERICATTRIBUTE14, TEX0_GENERICATTRIBUTE15, 
                                        TEX0_GENERICATTRIBUTE16, TEX0_GENERICATTRIBUTE17, TEX0_GENERICDATE3, TEX0_GENERICDATE4, TEX0_GENERICBOOLEAN1, 
                                        TEX0_GENERICNUMBER1, TEX0_GENERICNUMBER2, TEX0_GENERICNUMBER3, TEX0_GENERICNUMBER4, TEX0_GENERICNUMBER5,PROCESSINGUNITSEQ,
										ALTERNATEORDERNUMBER, GENERICATTRIBUTE24, TEX0_GENERICATTRIBUTE3)
    SELECT 
        TXN.TENANTID ,
        -- PER.PERIODSEQ,  Ver 1.0
        iperiodseq,        -- Ver 1.0
        --PER.NAME,   -- Ver 1.0
        iperiod,      -- Ver 1.0
        TXN.SALESORDERSEQ,
        TXN.SALESTRANSACTIONSEQ,
        ordtxn.orderid,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        TXN.COMPENSATIONDATE,
        TXN.ACCOUNTINGDATE,  -- Fecha que indica el ciclo de facturacion
        TXN.PRODUCTID as Producto,
        TXN.GENERICATTRIBUTE1 as Tipo_Servicio,
        TXN.GENERICATTRIBUTE2 as Nombre_Servicio,
        TXN.GENERICATTRIBUTE3 as Estado_GA3,        
        TXN.GENERICATTRIBUTE4 as Estado_Liquidacion,
        TXN.GENERICATTRIBUTE5 As Motivo_Resultado,
        TXN.GENERICATTRIBUTE6,
        TXN.GENERICATTRIBUTE7,        
        TXN.GENERICATTRIBUTE8 As IDMARCA,
        TXN.GENERICATTRIBUTE9 As IDMODELO,
        TXN.GENERICATTRIBUTE10,
        TXN.GENERICATTRIBUTE11,
        TXN.GENERICATTRIBUTE12,
        TXN.GENERICATTRIBUTE13,
        TXN.GENERICATTRIBUTE14,
        TXN.GENERICATTRIBUTE15,
        TXN.GENERICATTRIBUTE16,
        TXN.GENERICATTRIBUTE17,
        TXN.GENERICATTRIBUTE18,
        TXN.GENERICATTRIBUTE19 as Codigo_comercial,
        TXN.GENERICATTRIBUTE20 as Incidencia,
        TXN.GENERICATTRIBUTE21 as SubProducto,
        TXN.GENERICNUMBER1 as Duracion,
        TXN.GENERICNUMBER2 as Plazo,        
        TXN.GENERICNUMBER3 as Paquetizacion,
        TXN.GENERICDATE3 as Fecha_Firma,
        TXN.GENERICDATE4 as Fecha_Alta,        
        TXN.GENERICDATE5 as Fecha_Baja,        
        TXN.GENERICBOOLEAN2 as SS_Garantia,        
        TXN.PONUMBER as Contrato,
        TXN.DATASOURCE,
        TXNADD.ADDRESS1 AS Calle ,   
        TXNADD.CITY  AS Municipio ,
        TXNADD.STATE AS Provincia ,
        TXNADD.POSTALCODE as Codigo_Postal,
        TXNADD.INDUSTRY as Latitud,
        TXNADD.GEOGRAPHY as Longitud,
        TXNASS.POSITIONNAME,
        TXNASS.GENERICATTRIBUTE1 as Comercial,
        TXNASS.GENERICATTRIBUTE2 as UsuarioCRM,
        TXNASS.GENERICNUMBER1 as Calidad_Tecnica_Gas,
        TXNASS.GENERICNUMBER2 as Calidad_Tecnica_Luz,
        etxn0.GENERICATTRIBUTE4 as FechaMaximaInicial,
        etxn0.GENERICATTRIBUTE5 as Fecha_Validacion,
        etxn0.GENERICATTRIBUTE6 as FechaMaxima,
        etxn0.GENERICATTRIBUTE7 as InicioTrabajos,
        etxn0.GENERICATTRIBUTE8 as FinTrabajos,
        etxn0.GENERICATTRIBUTE9 as FechaSolicitdaCliente,
        etxn0.GENERICATTRIBUTE10 as FechaHora_Apertura,
        etxn0.GENERICATTRIBUTE11 as Fecha_Prevista,
        etxn0.GENERICATTRIBUTE12 as FormaPago,                        
        etxn0.GENERICATTRIBUTE13 as Num_Pedido_CRM,
        etxn0.GENERICATTRIBUTE14 as Num_Contrato_SVE,
        etxn0.GENERICATTRIBUTE15 as Tarifa,
        etxn0.GENERICATTRIBUTE16 as EmpresaEntrante,          
        etxn0.GENERICATTRIBUTE17 as ComercializadoraSal,            
        etxn0.GENERICDATE3 as Fecha_Plataforma,
        etxn0.GENERICDATE4 as Fecha_Registro,
        etxn0.GENERICBOOLEAN1 as Hidden_Firma,
        etxn0.GENERICNUMBER1 as Num_Validaciones,
        etxn0.GENERICNUMBER2 as Num_Insistencias,
        etxn0.GENERICNUMBER3 as Num_Insistencias_App,
        etxn0.GENERICNUMBER4 as Num_CambiosNoLocalizado,
        etxn0.GENERICNUMBER5 as Num_FueraPlazoCLiente,
        TXN.PROCESSINGUNITSEQ,
		-- MPR nuevo campo cups para cuadre de liq.
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICATTRIBUTE24 AS PEDIDO_CRM,
		ETXN0.GENERICATTRIBUTE3 as Motivo_BAJA
        
    FROM cs_salestransaction txn 
		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate = v_eot
			AND txn.tenantid = itenantId
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND txn.modelseq = 0
			AND txn.processingunitseq = iprocessingUnitSeq
			AND ordtxn.tenantid = txn.tenantid
       
		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate = v_eot
			AND txn.tenantid = etype.tenantid
		
		LEFT JOIN cs_gasalestransaction etxn0
			ON txn.salestransactionseq = etxn0.salestransactionseq
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
		
		LEFT JOIN
			(SELECT *
				FROM cs_transactionaddress txnaddress 
				INNER JOIN cs_addresstype addtype
					ON txnaddress.addresstypeseq = addtype.addresstypeseq
					AND addtype.addresstypeid = 'BILLTO'
			) txnadd
			ON txn.salestransactionseq = txnadd.salestransactionseq
			AND txn.processingunitseq = txnadd.processingunitseq
			AND txnadd.tenantid = txn.tenantid
			AND txn.compensationdate = txnadd.compensationdate
		
		LEFT JOIN cs_transactionassignment txnass
			ON txn.salestransactionseq = txnass.salestransactionseq
			AND txn.processingunitseq = txnass.processingunitseq
			AND txnass.tenantid = txn.tenantid
			AND txn.compensationdate = txnass.compensationdate
			AND txnass.setnumber > 0
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP NUEVA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    --dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TXN_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    BEGIN
        SYS.DBMS_STATS.GATHER_TABLE_STATS (
        OwnName => 'ENELEXT'
        ,TabName => 'ENEL_TXN_TEMP'
        ,Estimate_Percent => 1
        ,Method_Opt => 'FOR ALL COLUMNS SIZE 1'
        ,Degree => 10
        ,Cascade => TRUE
        ,No_Invalidate => FALSE);
    END;

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP.',v_contador_debug);
end;

procedure p_Temporal_Creditos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CREDIT_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_CREDIT_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, POSITIONSEQ, 
										COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, 
										GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, 
										GENERICATTRIBUTE10, GENERICATTRIBUTE11,GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, 
										GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3 )
    SELECT 
        credit.TENANTID,
        credit.PERIODSEQ,
        iperiod PERIODO,
        credit.PIPELINERUNSEQ,
        credit.PIPELINERUNDATE,
        --credit.NAME,
		credit.NAME name,
        CREDIT.CREDITSEQ,
        CREDIT.SALESORDERSEQ,        
        CREDIT.SALESTRANSACTIONSEQ,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        CREDIT.COMPENSATIONDATE,
        CREDIT.COMMENTS,                --v2.3
        CTYPE.CREDITTYPEID,           
        CTYPE.DESCRIPTION,             -- Tipo de Comision
        --credit.VALUE,                --Importe Comision
		credit.value as importe,
        credit.PREADJUSTEDVALUE,
        credit.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        credit.GENERICATTRIBUTE2,      -- Proveedor
        credit.GENERICATTRIBUTE3,      -- Servicio
        credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
        credit.GENERICATTRIBUTE5,      -- Plazo
        credit.GENERICATTRIBUTE6,      -- Provincia
        credit.GENERICATTRIBUTE7,      -- Zona
        credit.GENERICATTRIBUTE8,      -- Producto
        credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
        credit.GENERICATTRIBUTE10,     -- Equipamiento   
        credit.GENERICATTRIBUTE11,     -- CodigoPostal --ahora WBE
        credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
        credit.GENERICATTRIBUTE13,     --MotivoResultado
        credit.GENERICATTRIBUTE14,     --Descripcion Concepto Liquidacion
        case when ince.name is not null and ince.GENERICATTRIBUTE4 like 'Importe Base Incremental' then ince.genericattribute3 else credit.GENERICATTRIBUTE15 end as observaciones,
        credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
        credit.GENERICBOOLEAN2,        -- S/S Garantia
        credit.GENERICDATE1,           --FechaCalculo
        credit.GENERICNUMBER1,
        credit.GENERICNUMBER2,
        credit.GENERICNUMBER3
        
    FROM CS_CREDIT credit
        INNER JOIN CS_PLRUN p 
            ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Añadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
                                             
        INNER JOIN CS_CREDITTYPE ctype 
            ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
            AND ctype.TENANTID = itenantId
            AND ctype.REMOVEDATE  = v_eot
			
		LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = CREDIT.CREDITSEQ
            AND COMMI.PAYEESEQ = CREDIT.PAYEESEQ
            AND COMMI.PERIODSEQ= CREDIT.PERIODSEQ --añadido mejorar rendimiento APM 09.12.2025
        
		LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ
/* BOM APM 09.12.2025 Mejora performance */
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq
/* EOM BOM APM 09.12.2025 Mejora performance */
    
    WHERE
        CREDIT.TENANTID = ITENANTID 
        AND CREDIT.PROCESSINGUNITSEQ = IPROCESSINGUNITSEQ 
        AND CREDIT.PERIODSEQ =  IPERIODSEQ
		AND (INCE.GENERICATTRIBUTE16 NOT LIKE 'No mostrar' OR INCE.GENERICATTRIBUTE16 IS NULL)
        
	; 
            
    filas := sql%rowcount;
    COMMIT;

INSERT INTO ENELEXT.ENEL_CREDIT_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, POSITIONSEQ, 
										COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, 
										GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, 
										GENERICATTRIBUTE10, GENERICATTRIBUTE11,GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, 
										GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3 )
    SELECT 
        credit.TENANTID,
        credit.PERIODSEQ,
        iperiod PERIODO,
        credit.PIPELINERUNSEQ,
        credit.PIPELINERUNDATE,
        --credit.NAME,
		ince.name  name,
        CREDIT.CREDITSEQ,
        CREDIT.SALESORDERSEQ,        
        CREDIT.SALESTRANSACTIONSEQ,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        CREDIT.COMPENSATIONDATE,
        CREDIT.COMMENTS,                --v2.3
        CTYPE.CREDITTYPEID,           
        CTYPE.DESCRIPTION,             -- Tipo de Comision
        --credit.VALUE,                --Importe Comision
		commi.VALUE as importe,
        credit.PREADJUSTEDVALUE,
        credit.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        credit.GENERICATTRIBUTE2,      -- Proveedor
        credit.GENERICATTRIBUTE3,      -- Servicio
        credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
        credit.GENERICATTRIBUTE5,      -- Plazo
        credit.GENERICATTRIBUTE6,      -- Provincia
        credit.GENERICATTRIBUTE7,      -- Zona
        credit.GENERICATTRIBUTE8,      -- Producto
        credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
        credit.GENERICATTRIBUTE10,     -- Equipamiento   
        credit.GENERICATTRIBUTE11,     -- CodigoPostal --ahora WBE
        credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
        credit.GENERICATTRIBUTE13,     --MotivoResultado
        credit.GENERICATTRIBUTE14,     --Descripcion Concepto Liquidacion
        case when ince.name is not null and ince.GENERICATTRIBUTE4 like 'Importe Base Incremental' then ince.genericattribute3 else credit.GENERICATTRIBUTE15 end as observaciones,
        credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
        credit.GENERICBOOLEAN2,        -- S/S Garantia
        credit.GENERICDATE1,           --FechaCalculo
        credit.GENERICNUMBER1,
        credit.GENERICNUMBER2,
        credit.GENERICNUMBER3
        
    FROM CS_CREDIT credit
        INNER JOIN CS_PLRUN p 
            ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Añadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
                                             
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
        CREDIT.TENANTID = ITENANTID 
        AND CREDIT.PROCESSINGUNITSEQ = IPROCESSINGUNITSEQ 
        AND CREDIT.PERIODSEQ =  IPERIODSEQ
		AND (INCE.GENERICATTRIBUTE16 NOT LIKE 'No mostrar' OR INCE.GENERICATTRIBUTE16 IS NULL)
        and ((INCE.NAME LIKE 'C - CAT TVTA%Rappel Incremental%' or ince.name like 'C - CAT TVTA%TM7%' or ince.name like 'C - CAT TVTA%TM60%') and commi.value<>0 and commi.value is not null)
        
	; 
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CREDIT_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_TEMP.',v_contador_debug);
end;

procedure p_Temporal_Pds (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PDS_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_PDS_TEMP(   PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
                                          PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, NOMBRE_COMERCIAL, IMPORTE_UB, FECHA_CONTRATACION, 
                                          TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
                                          BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION )
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
        TIT.GENERICATTRIBUTE2 AS TIPO_POSICION
                    
    FROM CS_PERIOD per
        JOIN  CS_POSITION pos ON  pos.REMOVEDATE = v_eot
            AND pos.TENANTID = itenantId 
            AND pos.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND pos.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            -- and POS.ISLAST = 1   -- Con esta condicion no se quedaba con la version correcta asociada al fichero
            and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq
                          
        INNER JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            --and PAR.ISLAST = 1 -- Con esta condicion no se quedaba con la version correcta asociada al fichero

        INNER JOIN CS_PAYEE payee ON PAR.PAYEESEQ = PAYEE.PAYEESEQ
            AND PAYEE.REMOVEDATE =  v_eot
            --AND PAYEE.ISLAST =1   -- Con esta condicion no se quedaba con la version correcta asociada al fichero
            AND PAYEE.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAYEE.EFFECTIVEENDDATE >= PER.ENDDATE - 1   
            AND payee.TENANTID = itenantId

        INNER JOIN CS_TITLE tit ON POS.TITLESEQ = TIT.RULEELEMENTOWNERSEQ
            AND TIT.REMOVEDATE = v_eot
            AND TIT.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND TIT.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            AND TIT.TENANTID = itenantId
                            
    WHERE
        per.REMOVEDATE = v_eot
        AND per.PERIODSEQ = iperiodseq
        and par.GENERICATTRIBUTE1 is not null;
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PDS_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP.',v_contador_debug);
end;

procedure p_Informe_LIQSCAWEB ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
    my_code NUMBER;
    my_errm VARCHAR2(32000);
begin
    w_debug('Inicio Borrado de la tabla ENEL_LIQSCAWEB_FINAL_WBE.', v_contador_debug);
	BEGIN
		
		LOOP
			DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE WHERE PERIODO = iperiod and PROCESSINGUNITSEQ = iprocessingunitseq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;

        LOOP
			DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA WHERE PERIODO_liquidacion = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;

--BOM APM 09.12.2025
		LOOP
			DELETE FROM ENELEXT.ENEL_LIQ_FINAL_ASESOR WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
--EOM APM 09.12.2025

	END;
	v_txtFechaLiquidacion := '';
    
	IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    w_debug('Fin Borrado de la tabla ENEL_LIQSCAWEB_FINAL_WBE.', v_contador_debug);

    begin
    INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE (PERIODO, ORDERID, subcanal, wbe, EVENTTYPEID, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, --NUMPROVEEDOR, 
                                            INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO,PROCESSINGUNITSEQ, ESTADOCONTRATO) 
    SELECT 
		ETT.PERIODO,
        ETT.ORDERID,
        TMP_PDS.subcanal,
        ECT.GENERICATTRIBUTE2 wbe,
        ETT.EVENTYPEID,
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
            when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
            --when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado' -- RMM 10.01.2022 CAT TVTA se liquida por fuera, por lo que nunca debe aparecer liquidado
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        --TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ect.name,
        ECT.GENERICATTRIBUTE8,
        iprocessingunitseq,
        ETT.GENERICATTRIBUTE3
        
    FROM ENEL_TXN_TEMP ETT
        LEFT JOIN ENEL_CREDIT_TEMP ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE14
        LEFT JOIN ENEL_PDS_TEMP TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq
            

    WHERE 
    ETT.PROCESSINGUNITSEQ=iprocessingUnitSeq
    ;
    EXCEPTION
      WHEN OTHERS THEN
         my_code := SQLCODE;
         my_errm := SQLERRM;
         w_debug('Error: '|| my_code || my_errm, v_contador_debug);
    end;
    
    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_FINAL_WBE: '|| to_char(filas) || ' filas.', v_contador_debug);

INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_LEADS_WBE_CAT_TVTA(Periodo_Liquidacion ,Canal_Unidad_Negocio, WBE,	Nombre_Deposito,	
                                                            Importe,Proveedor, Codigo_Comercial )
    SELECT
     DEP.PERIODO AS PERIODO_LIQUIDACION,
    pos.genericattribute6 AS Canal_Unidad_Negocio,
    dep.EARNINGGROUPID AS WBE,
    dep.name AS Nombre_DepOsito,
    dep.value AS Importe,
    DEP.EARNINGCODEID AS Proveedor,
    POS.NAME AS COdigo_Comercial
    
    from ENEL_DEPOSIT_TEMP_CAT_TVTA dep
        inner join cs_position pos
            on pos.payeeseq = dep.payeeseq
            and pos.removedate = '01/01/2200'
            and pos.processingunitseq = iprocessingunitseq
    
    where dep.name like '%Leads%'
    AND dep.PERIODSEQ = iperiodseq
    
    ;
    filas := sql%rowcount;
    COMMIT;

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_LIQSCAWEB_FINAL_WBE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE.',v_contador_debug);

--BOM APM 09.12.2025
	w_debug('Insertando Registros de datos en tabla ENEL_LIQ_FINAL_ASESOR.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_LIQ_FINAL_ASESOR (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
											CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
											CUPS, FECHA_FIRMA, PEDIDO_CRM)
    SELECT 
        INC.PERIODO,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(CRED.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        CRED.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        CRED.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        '' as Estado,
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        CRED.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		INC.name,
		CRED.GENERICATTRIBUTE8,
		--MPR - nuevos campos
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24 -- pedido_CRM
		
    FROM CS_COMMISSION COMMI
		INNER JOIN ENEL_INCEN_TEMP INC
			on commi.incentiveseq = inc.incentiveseq
			and commi.payeeseq = inc.payeeseq
			and commi.tenantId = inc.tenantId
		
		LEFT JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=INC.GENERICATTRIBUTE2
			and TEMP_PROV.periodSeq = inc.PERIODSEQ
			and TEMP_PROV.tenantId = inc.tenantId
			
		INNER JOIN cs_credit CRED
			on commi.creditseq = cred.creditseq
			and cred.payeeseq = commi.payeeseq
			and cred.processingUnitseq = commi.processingUnitSeq
			and cred.tenantId = commi.tenantId
			and cred.periodSeq = commi.periodSeq

		INNER JOIN CS_SALESTRANSACTION txn
			ON CRED.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = cred.processingUnitSeq
            AND txn.tenantid = cred.tenantId
            AND txn.modelseq = 0
			
		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = v_eot
			AND txn.tenantid = etype.tenantid

	where inc.name like ('C - Renovacion ASESOR%')
    or inc.name like 'I - Captacion - Promo Prescriptores - %'
    or inc.name like 'I - Captacion - Incentivo Crecimiento - %'
	and inc.tenantId = itenantId
	and commi.processingUnitSeq = iprocessingUnitSeq
	and inc.periodSeq = iperiodseq
    ;
               
    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_LIQ_FINAL_ASESOR: '|| to_char(filas) || ' filas.', v_contador_debug);
--EOM APM 09.12.2025
    
end;

procedure p_rappeles( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , iInterfaz IN VARCHAR2)
as
    v_txtFechaLiquidacion VARCHAR2(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_RAPPELES_WBE.', v_contador_debug);
    BEGIN       
        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_WBE WHERE periodo = iperiod and PROCESSINGUNITSEQ = 38280596832649518 and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
        v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
    w_debug('Fin Borrado de la tabla ENEL_RAPPELES_WBE.', v_contador_debug);
    
    w_debug('Insertando datos en tabla ENEL_RAPPELES_WBE.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_RAPPELES_WBE(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, subcanal, wbe,PROCESSINGUNITSEQ)
    SELECT 
        CSPE.NAME,
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
        38280596832649518
    
    FROM CS_INCENTIVE CSI
        INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
        
        INNER JOIN CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
            and csp.removedate =v_eot
    
        INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate =v_eot
    
        LEFT JOIN ENEL_PDS_TEMP TMP_PDS
            on CSI.payeeseq=TMP_PDS.payeeseq 
            and CSI.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and CSI.periodseq=TMP_PDS.periodseq
      
    WHERE 
		CSI.periodseq = iperiodseq and 
		/*(CSI.NAME LIKE 'I - Captacion - Rappel Cuantitativo - Objetivo % - Importe%' 
			or CSI.NAME LIKE 'I - Captacion - Extra Rappel - Objetivo % - Importe%'
			or CSI.NAME LIKE 'I - Atencion - Rappel Cuantitativo Extra - Objetivo 1 - Importe'
			or CSI.NAME LIKE 'I - Captacion - TdF % - Bonus por TdF m-4'
			or CSI.NAME LIKE 'I - Captacion - BTrimestral crecim - %'
			-- MPR - Se incluye en los rappeles la parte de REMUN
			or CSI.name like 'I - ATC - Remun Comercial PDS' 
			-- MPR - incluimos los incentivos de arrastre
			or CSI.name like 'I %Arrastre%' 
			-- MPR - nuevos rappeles de CNS y SW
			or csi.name like 'I - Captacion Rappel CNS%'
			or csi.name like 'I - Captacion Rappel SW%'
		) 
		and csi.name not like 'I - Captacion - Rappel Cuantitativo - Objetivo % PUSH RED - Importe%'  */ --APM 24.03.2022
        CSI.NAME LIKE 'I - CAT TVTA%' --APM 24.03.2022
		and value <>0;
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_RAPPELES_WBE: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_RAPPELES_WBE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_WBE.',v_contador_debug);
    
end;
-- EOM CAL0124 DCR 11.03.22

--BOM APM 09.12.2025
procedure p_Temporal_Incentivos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS    
begin
    
    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_INCEN_TEMP( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
										GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE7, GENERICATTRIBUTE16, 
										GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
										GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2 )
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
            AND p.tenantid = itenantId
    WHERE
        incent.TENANTID = itenantId 
        AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND incent.PERIODSEQ =  iperiodseq
        AND incent.GENERICATTRIBUTE1 is not null
        ;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_INCEN_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP.',v_contador_debug);
 
end;

procedure p_Temporal_Creditos_Scaweb (  iprocessingUnitSeq IN VARCHAR2,  iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    vFechaAlta Date;
    v_fecInicioPeriodoSig date;
begin

    w_debug('Inicio Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_SCAWEB_LIQUIDACION_CAT_TVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA.', v_contador_debug);
    
    -- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := SYSDATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fecInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    w_debug('Insertando CREDITOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA.' ,  v_contador_debug);
    -- v2.0 Se cambia la tabla de origen CS_CREDIT  a la temporal ENEL_CREDIT_TEMP
    INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_CAT_TVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT DISTINCT
        iperiod PERIODO,        
        to_number(REPLACE(credtmp.GENERICATTRIBUTE14, ' integer','')) PROVEEDOR,             
        to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
        credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        1 as CANTIDAD,
        ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
        to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
        '' as FechaBaja,
        '' as Telefono,
        case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end as Observaciones,
        null,
        credtmp.GENERICATTRIBUTE6,       --Provincia
        credtmp.VALUE  as REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision  

    FROM ENEL_CREDIT_TEMP credtmp
        INNER JOIN ENEL_PDS_TEMP TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
            ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

    WHERE 
        (credtmp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
        and credtmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)
        --and NOT ( credtmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050
		--and not TMP_PDS.TIPO_POSICION in ('ALICO','AAFF')  --MPR se quita del filtro CNS y SW
        and ( 
			credtmp.CREDITTYPEID = 'CAT Captacion' 
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion'
            OR credtmp.CREDITTYPEID like 'CAT TVTA -%'
            OR credtmp.CREDITTYPEID like '%EnelX - CAT%' 
            or credtmp.CREDITTYPEID like '%Enel X - CAT%'
            OR credtmp.CREDITTYPEID = 'CAT Captacion Campañas'
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion Campañas'
            OR credtmp.CREDITTYPEID = 'TLV INBOUND'
            /*BOM APM 19.03.2026*/
            OR credtmp.CREDITTYPEID LIKE 'Captacion CAT TVTA - Mas Orange%'
            OR credtmp.CREDITTYPEID LIKE 'Bajas - Mas Orange - CAT TVTA%'
            OR credtmp.CREDITTYPEID LIKE 'Ajuste Manual - Mas Orange - CAT TVTA'
            /*EOM APM 19.03.2026*/
            /*BOM APM 24.04.2026*/
            OR credtmp.CREDITTYPEID = 'CAT Captacion - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Captacion Campañas - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Recuperacion Campañas - Activacion'
            OR credtmp.CREDITTYPEID = 'TLV INBOUND - Activacion'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion Capta Campaña'
            OR credtmp.CREDITTYPEID = 'CAT Retro Capta Rappel'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion Recuperacion'
            OR credtmp.CREDITTYPEID = 'CAT Retrocesion Recuperacion Campaña'
            OR credtmp.CREDITTYPEID = 'CAT Retro Recu Rappel'))
            /*EOM APM 24.04.2026*/
            /*BOM APM 14.05.2026*/
            OR (credtmp.CREDITTYPEID like 'CAT Recuperacion Ajuste Manual%'
            OR credtmp.CREDITTYPEID like 'CAT Captacion Ajuste Manual%')
            
            /*BOM APM 14.05.2026*/
		
	;  -- De atencion solo los ajustes Manuales (para que no salgan todo el detalle de operaciones)
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando INCENTIVOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_CAT_TVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
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
        INCENTMP.VALUE  AS REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision
            
    FROM ENEL_INCEN_TEMP INCENTMP    
        INNER JOIN ENEL_PDS_TEMP TMP_PDS
            ON INCENTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and incentmp.payeeseq=tmp_pds.payeeseq
             
    WHERE (    
        INCENTMP.GENERICBOOLEAN1 = 1  -- Indica los Incentivos que se incluyen en pagos
        AND INCENTMP.GENERICATTRIBUTE1 IS NOT NULL  -- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)  
        AND INCENTMP.VALUE <> 0 -- Se filtran los incentivos que sean distintos de 0      
        --AND NOT ( INCENTMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')  -- No se incluyen Creditos de OCAPS y proveedor 050            
		--AND NOT TMP_PDS.TIPO_POSICION IN ('ALICO','AAFF')   --MPR se quita del filtro CNS y SW 
        AND ( 
			INCENTMP.NAME LIKE 'I - %CAT TVTA - Incentivo%'
            OR INCENTMP.NAME LIKE 'I - %CAT TVTA - TdM%Malus'
			or incentmp.NAME LIKE 'I - %CAT TVTA - %BBDD'
            --or incentmp.NAME LIKE 'C - CAT TVTA % Rappel Incremental'
            --or incentmp.NAME LIKE 'C - CAT TVTA %TM%'
			));


    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Insertando INCENTIVOS RENOVACION de datos en tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_CAT_TVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
    SELECT 
        iperiod PERIODO,        
        TO_NUMBER(ASESOR.NUMPROVEEDOR),   -- Proveedor en formato numerico, sin ceros a la izquierda             
        TO_CHAR(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
        TO_CHAR(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
        ASESOR.CODIGO_PDS_OCAP ,      -- Prestador - PDS
        '',      -- Concepto Liquidacion
        1 AS CANTIDAD,
        ABS(ASESOR.IMPORTE),
        TO_CHAR(vFechaAlta, 'YYYYMMDD') AS FechaAlta,
        '' AS FechaBaja,
        '' AS Telefono,
        '' AS Observaciones, 
        ''  AS Codigo_Postal,       --Codigo Postal
        ''  AS Provincia,     --Provincia
        ASESOR.IMPORTE  AS REALVALUE      -- Valor real sin tomar el valor absoluto para informe de revision
            
    FROM ENEL_LIQ_FINAL_ASESOR ASESOR    
	WHERE PERIODO = iperiod
	
    ;
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_SCAWEB_LIQUIDACION_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_SCAWEB_LIQUIDACION_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION_CAT_TVTA.',v_contador_debug);

end;

procedure p_Comparativa_Pagos_SCAWEB_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    w_debug('Inicio Borrado de la tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_COMP_SCAWEB_E4E_CAT_TVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_CAT_TVTA ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
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
            from ENEL_SCAWEB_LIQUIDACION_CAT_TVTA sca where PERIODO = IPERIOD
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
			from ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP 
			where periodseq=IPERIODSEQ
			group by TRIM(IDPROVEEDOR), POS_ID 
            ) T_E4E
            
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.POS_ID)

		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, POS_NAME, 
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
			from ENEL_E4E_NEG_TEMP_CAT_TVTA
			where periodseq=iperiodseq
			group by TRIM(IDPROVEEDOR), POS_NAME
			)E4ENT
			ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.POS_NAME)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)
            
        INNER JOIN ENEL_PDS_TEMP TMP_PDS
            ON T_SCAWEB.PDS=TMP_PDS.PDS

        INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TMP_PROV 
            ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR)
		;        
      
    filas := sql%rowcount;
    COMMIT;
   
    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_CAT_TVTA ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
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
        ( SELECT iperiod PERIODO, TRIM(IDPROVEEDOR)  AS IDPROVEEDOR, POS_ID, 
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NOT NULL THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NULL THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
            SUM(CASE WHEN VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
            SUM(VALOR_OPERACIONES) AS OPERACIONES
            --SUM(VALOR_INSTALADORES) AS INSTALADORES,
            --SUM(VALOR_AAFF) AS AAFF,
            --SUM(VALOR_ALIADOS) AS ALIADOS
            FROM ENEL_E4E_DEPOSIT_CAT_TVTA_TEMP 
            WHERE PERIODSEQ = iperiodseq
            GROUP BY iperiod, TRIM(IDPROVEEDOR), POS_ID 
        ) T_E4E
            
        LEFT JOIN
            ( SELECT 
				PERIODO,
                TRIM( TO_CHAR(PROVEEDOR,'000')) IDPROVEEDOR,
                SCA.CODIGO_AGENTE_INTERNO AS PDS,
                SUM(REALVALUE) AS IMPORTE_SCAWEB,
                COUNT(*) REGISTROS
                FROM ENEL_SCAWEB_LIQUIDACION_CAT_TVTA SCA
                WHERE PERIODO = iperiod            
                GROUP BY PERIODO, TRIM( TO_CHAR(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO             
            ) T_SCAWEB
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.POS_ID)
			          
        INNER JOIN ENEL_PDS_TEMP TMP_PDS
            ON T_E4E.POS_ID = TMP_PDS.PDS

        INNER JOIN ENEL_PROVEEDORES_TEMP_CAT_TVTA TMP_PROV 
            ON TRIM(TMP_PROV.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR)
    
	WHERE T_SCAWEB.IMPORTE_SCAWEB IS NULL;
      
    filas := sql%rowcount;
    COMMIT;
   
    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_SCAWEB_E4E_CAT_TVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_COMP_SCAWEB_E4E_CAT_TVTA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_SCAWEB_E4E_CAT_TVTA.',v_contador_debug);

end;   
--EOM APM 09.12.2025

--BOM APM 03/03/2026
procedure p_informe_agrupado (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2, iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
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
end;
--EOM APM 03/03/2026

PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,
			periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,
			stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,
			salidacontrol out varchar2,informe varchar2 ) IS
                
	v_nom_procedure VARCHAR2(200) := 'ENEL_ACTUAL_INFORMES_CAT_TVTA.RUN';
	v_Interfaz_Proceso  nvarchar2(50);  
	v_Listado_Informes  nvarchar2(500);
	v_PeriodoLiquidado boolean;

BEGIN
	--INICIALIZAMOS v_contador_debug
	v_contador_debug := 0;
 
	w_debug('Procedure ' || v_nom_procedure || ' Starting...',v_contador_debug);

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
        
		if informe = '' or informe is null then
            v_Listado_Informes := 'ALL';
            w_debug('Argumento Actualizado : informe : ['||v_Listado_Informes            ||'] (EJECUCION_MANUAL)',V_CONTADOR_DEBUG);
        else
            v_Listado_Informes := informe;
        end if;
	else
        w_debug('Peticion de ejecucion StageHook con periodo '|| period, v_contador_debug);
		
		CASE stage 
            WHEN 'Reward__'  then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_REWARD';  
            WHEN 'Post__'    then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST';
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

    salidacontrol :='Procedure '||v_Interfaz_Proceso||' comenzando';

	--    Se comprueba si el periodo Ya ha sido liquidado. 
    v_PeriodoLiquidado := f_ComprobarPeriodoLiquidado( processingUnitSeq, period ,periodSeq , tenantId  );

	-- SI EL PERIODO NO SE HA LIQUIDADO, SE EXTRAEN DE NUEVO LOS DATOS PARA LOS INFORMES      
    IF  v_PeriodoLiquidado = false THEN
		------------------------------------------------------------
		-- Datos Generales que se usan en varios informes
		------------------------------------------------------------
-- BOM CAL0124 DCR 11.03.22
        -- Volcar datos de las tablas de transacciones a una tabla temporal. Tabla ENEL_TXN_TEMP
        p_Temporal_TXN_truncate( processingUnitSeq, period ,periodSeq , tenantId  );
		p_Temporal_Transacciones ( processingUnitSeq, period ,periodSeq , tenantId  );
        
        -- Volcar datos de la tabla de creditos a una tabla temporal. Tabla ENEL_CREDIT_TEMP
        p_Temporal_Creditos ( processingUnitSeq, period ,periodSeq , tenantId  );

--BOM APM 09.12.2025
        -- Volcar datos de la tabla de incentivos a una tabla temporal. Tabla ENEL_INCEN_TEMP
        p_Temporal_Incentivos ( processingUnitSeq, period ,periodSeq , tenantId  );
--EOM APM 09.12.2025

        -- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PDS_TEMP
        p_Temporal_Pds ( processingUnitSeq, period ,periodSeq , tenantId  );
-- EOM CAL0124 DCR 11.03.22
        
		--Volcar datos de depositos a una tabla temporal ENEL_DEPOSIT_TEMP_CAT_TVTA
        p_Temporal_Depositos ( processingUnitSeq, period, periodseq, tenantId);    
        
		-- Volcar datos de clasificacion a una Temporal de Proveedores. Tabla ENEL_PROVEEDORES_CAT_TVTA
        p_Temporal_Proveedores ( period ,periodSeq , tenantId  );
        
		-- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PAYEE_TEMP
        p_Temporal_Payee ( processingUnitSeq, period ,periodSeq , tenantId  );
        
		-- Volcar datos de Productos a una Temporal Tabla ENEL_PRODUCTOS_TEMP   
        p_Temporal_Productos ( period ,periodSeq , tenantId  );

        p_Temporal_E4E_Negativos ( period ,periodSeq , tenantId, processingUnitSeq  );

        IF f_ExisteInformeEnLista('E4E', v_Listado_Informes) THEN
			-- Volcar datos de clasificaci?n a una Temporal de Contratos.     Tabla ENEL_E4E_CONTRATOS_TEMP
			p_Temporal_Contratos_E4E ( period ,periodSeq , tenantId  );
   
			-- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_TEMP
			p_Temporal_Depositos_E4E ( processingUnitSeq, period ,periodSeq , tenantId);
    
			-- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 1 
			p_Final_E4E_1 ( period ,periodSeq , tenantId  );

			-- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 2 
			p_Final_E4E_2 ( period ,periodSeq , tenantId  );
			
			-- Actualizamos la fecha del informes en la tabla 
			p_Actualiza_Informe_Fecha ( period, 'E4E CAT TVTA');

			if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_REWARD' THEN  -- v2.4
				-- Los datos Negativos solo se extraen enel REWARD
				-- Extraer datos NEGATIVOS de TEMP_Depositos. Tabla: ENEL_E4E_NEGATIVOS
				p_Final_E4E_Negativos ( processingUnitSeq, period ,periodSeq , tenantId  );

				-- Actualizamos la fecha del informe en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'E4ENEG CAT TVTA');          
			end if;
    
		-- Generamos datos de resumen de pagos
		-- p_Informe_Resumen_Pagos( processingUnitSeq, period ,periodSeq , tenantId  );
		end if;
 
/* BOM CAL0130 DCR 29.03.22 */
/* Old 
        p_Inf_CAT_TVTA_IB_TEMP ( processingUnitSeq, period, periodSeq , tenantId , v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_RESUM_PAGO_TEMP ( processingUnitSeq, period, periodSeq , tenantId , v_Interfaz_Proceso );
*/
        p_Inf_CAT_TVTA_RESUMEN_PAGO ( processingUnitSeq, period, periodSeq , tenantId , v_Interfaz_Proceso );
        --BOM APM 15.03.2023
        -- Actualizamos la fecha del informe en la tabla 
        p_Actualiza_Informe_Fecha ( period, 'CAT_TVTA_RESUMEN');  
        --EOM APM 15.03.2023
    
        p_Inf_CAT_TVTA_APORTE_TEMP ( processingUnitSeq, period, periodSeq, tenantId, v_Interfaz_Proceso );
    
        p_Inf_CAT_TVTA_APORTE ( processingUnitSeq, period, periodSeq, tenantId, v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_AM_TEMP ( processingUnitSeq, period, periodSeq, tenantId, v_Interfaz_Proceso );
    
        p_Inf_CAT_TVTA_AM ( processingUnitSeq, period, periodSeq, tenantId, v_Interfaz_Proceso );
    
        p_Inf_CAT_TVTA_BONUSMALUS_TEMP ( processingUnitSeq, period , periodSeq , tenantId , v_Interfaz_Proceso );
    
        p_Inf_CAT_TVTA_BONUS_MALUS ( processingUnitSeq, period , periodSeq , tenantId , v_Interfaz_Proceso );
    
        p_Inf_CAT_TVTA_INCENPENAL_TEMP ( processingUnitSeq , period, periodSeq, tenantId, v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_INCEN_PENAL ( processingUnitSeq , period, periodSeq, tenantId, v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_IP_TOTAL_TEMP ( processingUnitSeq, periodSeq, tenantId, v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_IP_TOTAL ( period, v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_IP_VENTA_TEMP ( processingUnitSeq , periodseq , tenantId , v_Interfaz_Proceso );
        
        p_Inf_CAT_TVTA_IP_VENTA ( period , v_Interfaz_Proceso );
    
        p_Inf_Factura_CAT_TVTA_Detalle ( processingUnitSeq , period , periodSeq , tenantId, v_Interfaz_Proceso );
    
        p_Inf_Factura_CAT_TVTA_Portada ( period );
        
        p_Inf_Factura_CAT_TVTA_Depo (periodSeq);
        
        p_Informe_Transaccion ( processingUnitSeq , period , periodSeq , tenantId );
        
-- BOM CAL0124 DCR 11.03.22
        -- Extraer datos para Interface de LIQUIDACION MENSUAL SCAWEB  (Captacion - Importe Base)
        p_Informe_LIQSCAWEB (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
        p_rappeles ( period ,periodSeq , tenantId , v_Interfaz_Proceso );
-- EOM CAL0124 DCR 11.03.22
--BOM APM 12.02.2024
        -- Actualizamos la fecha del informe
        p_Actualiza_Informe_Fecha ( period, 'INF_CUADRE_LIQ');  
--EOM APM 12.02.2024

--BOM APM 09.12.2025
        IF f_ExisteInformeEnLista('SCAWEB', v_Listado_Informes) THEN  
             -- Extraer datos de creditos calculados para el periodo -> Tabla : ENEL_SCAWEB_LIQUIDACION
             p_Temporal_Creditos_Scaweb ( processingUnitSeq, period ,periodSeq , tenantId  );       
             -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'SCAWEB');   
        end if;
        -- Comparativa Pagos solo se hace si se ejecutan todos los informes
        IF v_Listado_Informes = 'ALL' THEN
            p_Comparativa_Pagos_SCAWEB_E4E( processingUnitSeq, period ,periodSeq , tenantId  );
            p_Actualiza_Informe_Fecha ( period, 'SCAWEB_E4E_CAT_TVTA');
        end if;  
--EOM APM 09.12.2025

--BOM APM 03.03.2026
            ---------------------------------------------------
            -- Datos para Informe Agrupado de liquidaciones
            ---------------------------------------------------
            IF f_ExisteInformeEnLista('LIQ_CAT_TVTA', v_Listado_Informes) THEN
				p_informe_agrupado (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
				-- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_CAT_TVTA');    
			end if;
--EOM APM 03.03.2026

    END IF;
    
    w_debug('Procedure ' || v_nom_procedure || ' Ending...',v_contador_debug);
 
END;

END;