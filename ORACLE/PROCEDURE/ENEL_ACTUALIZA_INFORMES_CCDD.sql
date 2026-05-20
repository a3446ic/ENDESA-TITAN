create or replace PACKAGE BODY ENEL_ACTUALIZA_INFORMES_CCDD AS

/* *****************************************************************************
   NAME:       ENEL_ACTUALIZA_INFORMES_CCDD
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        xx/12/2021  DCR               Created this package.
   
   1.1        31.05.2022  DCR               PDS E4E (CAL0152)
   
   1.2        11.10.2022  DCR               Errores E4E (CAL0230)
   
   1.3        27.10.2022  DMS               Informe Liq no filtra por periodo
   
   1.4        16.01.2023  RMM               Informe de prefactura genera duplicados debido a la forma en la que se generaba la
                                            tabla temporal de credito. Como solo necesitamos información del credito por el 
                                            momento procedemos a eliminar en cruce con comisiones e incentivos
                                            
   1.5        18.04.2023  DCR               Activar DTM para CCDD
   
   1.6        18.07.2023  APM               Modificar longitud de campos tabla ENEL_CUADRELIQ_CCDD_SLA

   1.7        07.03.2024  APM               Se añaden nuevos campos para Evolutivo CPs - Provincia y Apliación Incentivo CPs.   

   1.8        14.11.2024  APM               Campo TIPO_VENTA de la tabla ENEL_TXN_TEMP_CCDD se cambia por CREDIT.GENERICATTRIBUTE3.
   
   1.9        31.01.2024  APM               Campo IMPORTE_S2S añadido a la tabla ENEL_GRALPROV_DETALLE_CCDD.
   
   1.10       30.04.2025  APM               Nueva tabla para nueva pestaña 'Comprobación por WBE' del informe 3.Informe Balance_Callidus - E4E_CCDD  
   
   1.11       03.06.2025  APM               Nueva tabla para nuevo informe '1.Informe Cuadre de Liquidación_Resellers' -> ENEL_CUADRELIQ_CCDD_RESELLERS
                                            Nuevo filtro en la tabla ENEL_CREDIT_TEMP_CCDD
                                            
   1.12       03.03.2026  APM               Informar tablas para Informe Agrupado de liquidaciones
   
   1.13       09.03.2026  APM               Revertir subida Informar tablas para Informe Agrupado de liquidaciones

   1.14       19.03.2026  APM               Cambios para Mas Orange
***************************************************************************** */


v_eot date := to_date('22000101','YYYYMMDD');
	v_contador_debug integer;
    v_contador_ctrl_inf integer; --MIO 10.03.2023
    v_num_ejecucion integer;
    v_finicio timestamp;
    v_ffin timestamp;
    v_classifierid			CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION			CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE					CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA				CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS			CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD			CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO				CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas number; --Para el DEBUG de los INSERT

procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
	proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;

procedure z_ctrl_inf ( valor IN Number, num_ejecucion IN number, proceso IN VARCHAR2, finicio IN timestamp, ffin IN timestamp, mensaje IN VARCHAR2)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG

begin

    INSERT INTO enelext.enel_ctrl_informes (id, num_ejecucion, paquete, proceso, fecha_inicio, fecha_fin, mensaje, duracion) 
        VALUES (valor, v_num_ejecucion, proc_name, proceso, finicio, ffin , mensaje, extract(day from (ffin - finicio)*86400));
    v_contador_ctrl_inf := v_contador_ctrl_inf +1;
    commit;

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

function f_Primer_Dia_Periodo(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT PER.STARTDATE INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
		AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');

	return v_Primer_Dia;
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

-- Fecha Anual
function f_fecha_inicio_anual(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT ADD_MONTHS( PER.STARTDATE , -12) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
		AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
	return v_Primer_Dia;
end;

-- Fecha Trimestral
function f_fecha_inicio_trimestral(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT ADD_MONTHS( PER.STARTDATE , -3) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
		AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
	return v_Primer_Dia;
end;

-- Fecha Bimensual
function f_fecha_inicio_bimensual(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT ADD_MONTHS( PER.STARTDATE , -2) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
		AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
	return v_Primer_Dia;
end;

----------------- f_CodigoMes -----------------------------------------------------------------------
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
  
-- EXtraer el codigo del mes : Enero: A, Febrero:B .... Diciembre:L
-- se comprueba si el informe sobre el que se van a generar los datos pertenece a la lista de informes. Para 'ALL', se devuelve que si existe
function f_ExisteInformeEnLista(iInforme in varchar2, iListaInformes in varchar2 ) return boolean as   
    v_existe BOOLEAN;    
begin  
	-- Si lista de INFORMES es 'ALL', se devuelve como que existe siempre
    IF iListaInformes = 'ALL' THEN
        v_existe := true;
    ELSIF INSTR( iListaInformes, iInforme ) > 0 THEN
		-- Si el nombre del informe existe en la lista que se ha pasado como parametro (ejecución manual), se devuelve que existe (true)   
        v_existe := true;
	ELSE
		-- Si el nombre del informe no existe en la lista que se ha pasado como parametro (ejecución manual), se devuelve que no existe (false)
        v_existe := false;
    END IF; 

    if v_existe then
        w_debug(' SI ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    else
        w_debug(' NO ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    end if;
    
    return v_existe;
end;

procedure p_Temporal_Transacciones (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_CCDD.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP_CCDD. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_CCDD( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, 
												ACCOUNTINGDATE, PRODUCTID, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, 
												GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, 
												GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14, GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICATTRIBUTE17, 
												GENERICATTRIBUTE18,GENERICATTRIBUTE19, GENERICATTRIBUTE20, GENERICATTRIBUTE21, GENERICATTRIBUTE27, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, 
												GENERICDATE3, GENERICDATE4, GENERICDATE5, GENERICBOOLEAN2, PONUMBER, DATASOURCE, TAD_ADDRESS1, TAD_CITY, TAD_STATE, TAD_POSTALCODE, 
												TAD_INDUSTRY, TAD_GEOGRAPHY, TAS_POSITIONNAME, TAS_GENERICATTRIBUTE1, TAS_GENERICATTRIBUTE2, TAS_GENERICNUMBER1, TAS_GENERICNUMBER2, 
												TEX0_GENERICATTRIBUTE4, TEX0_GENERICATTRIBUTE5, TEX0_GENERICATTRIBUTE6, TEX0_GENERICATTRIBUTE7, TEX0_GENERICATTRIBUTE8, 
												TEX0_GENERICATTRIBUTE9, TEX0_GENERICATTRIBUTE10, TEX0_GENERICATTRIBUTE11, TEX0_GENERICATTRIBUTE12, 
												TEX0_GENERICATTRIBUTE13, TEX0_GENERICATTRIBUTE14, TEX0_GENERICATTRIBUTE15, TEX0_GENERICATTRIBUTE16, TEX0_GENERICATTRIBUTE17, 
												TEX0_GENERICDATE3, TEX0_GENERICDATE4, TEX0_GENERICBOOLEAN1, TEX0_GENERICNUMBER1, TEX0_GENERICNUMBER2, TEX0_GENERICNUMBER3, 
												TEX0_GENERICNUMBER4, TEX0_GENERICNUMBER5,PROCESSINGUNITSEQ, ALTERNATEORDERNUMBER,GENERICATTRIBUTE24,
                                                COSTE, GENERICATTRIBUTE25, PRODUCTNAME, GENERICDATE6) --APM 03.06.2025
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
        TXN.GENERICATTRIBUTE27 as Razon_Social,
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
		TXN.ALTERNATEORDERNUMBER as CUPS,
        TXN.GENERICATTRIBUTE24 AS GENERICATTRIBUTE24,
        TXN.GENERICNUMBER6 as COSTE, --APM 03.06.2025
        TXN.GENERICATTRIBUTE25, --APM 03.06.2025
        TXN.PRODUCTNAME, --APM 03.06.2025
        TXN.GENERICDATE6 AS GENERICDATE6 --APM 03.06.2025
        

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
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TXN_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Transacciones', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Transacciones', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--------- Volcar datos de la tabla de Créditos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_CREDIT_TEMP ----
procedure p_Temporal_Creditos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CREDIT_TEMP_CCDD';
	w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP_CCDD.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP_CCDD. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CREDIT_TEMP_CCDD ( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, 
												POSITIONSEQ, COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, 
												GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, 
												GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,
												GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICBOOLEAN1, GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3,
                                                GENERICNUMBER4, GENERICNUMBER5)
	SELECT 
		credit.TENANTID,
		credit.PERIODSEQ,
		iperiod PERIODO,
		credit.PIPELINERUNSEQ,
		credit.PIPELINERUNDATE,
		--credit.NAME,
		case when commi.value is not null and credit.name like '%Resellers -%' then ince.name else credit.NAME end name, --RMM 16.01.2023  
        --credit.NAME,--RMM 16.01.2023  
        CREDIT.CREDITSEQ,
		CREDIT.SALESORDERSEQ,        
		CREDIT.SALESTRANSACTIONSEQ,
		CREDIT.PAYEESEQ,
		CREDIT.POSITIONSEQ,
		CREDIT.COMPENSATIONDATE,
		CREDIT.COMMENTS,                --v2.3
		CTYPE.CREDITTYPEID,           
		CTYPE.DESCRIPTION,             -- Tipo de Comisión
		--credit.VALUE,                --Importe Comision
		case when commi.value is not null and credit.name like '%Resellers -%' then commi.VALUE else credit.value end as importe, --RMM 16.01.2023  
        --credit.VALUE,-- RMM 16.01.2023
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
		--credit.GENERICATTRIBUTE15,     --Observaciones Ajustes Manuales
		--case when ince.name is not null and ince.GENERICATTRIBUTE4 like 'Importe Base Incremental' then ince.genericattribute3 else credit.GENERICATTRIBUTE15 end as observaciones,--RMM 16.01.2023
        credit.GENERICATTRIBUTE15,  --RMM 16.01.2023
        credit.GENERICATTRIBUTE16,      --Linea Negocio
		credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
		credit.GENERICBOOLEAN2,        -- S/S Garantía
		credit.GENERICDATE1,           --FechaCalculo
		credit.GENERICNUMBER1,
		credit.GENERICNUMBER2,
		credit.GENERICNUMBER3,
        credit.GENERICNUMBER4,
        credit.GENERICNUMBER5
        --case when commi.value is not null and ince.GENERICATTRIBUTE4 like 'Importe Base Incremental' then commi.VALUE else credit.value end AS VALUE_CREDIT--APM 18.07.2025 

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
            AND COMMI.PERIODSEQ= CREDIT.PERIODSEQ --APM 18.07.2025
            and credit.name like '%Resellers -%'
        
		LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ  -- RMM : 16.01.2023 Se elimina este cruce  para evitar duplicado ya que actualmente
            --al cruzar con comisiones se estan encontrado 2 entradas por credito y en principio solo mostramos información del credito       
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq
            
            
	WHERE
		credit.TENANTID = itenantId 
		AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND credit.PERIODSEQ =  iperiodseq
        AND ( credit.name LIKE '%Comision Base%'         --Cambio solilcitado por Carmen Fernandez 10.03.2022 -MIKE
        or credit.name LIKE '%Ajustes Manuales%'
        or credit.name LIKE '%Ajuste Manual%'
        or credit.name like 'CD - %Enel X CCDD - Importe Base'
        or credit.name like 'CD - Captacion CCDD - Retribuci%n Especial Tarifas'
        or credit.name like 'CD - Leads CCDD - Importe Base'
        or credit.name LIKE 'Resellers - Captacion%' --APM 03.06.2025
        or credit.name like 'CD - Retenci%n CCDD - Retribuci%n Especial Tarifas'
        or credit.name like '%Mas Orange%') --DMS 19.03.2026
        ;
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CREDIT_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Creditos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Creditos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--------- Volcar datos de la tabla de Incentivos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_INCEN_TEMP ----
procedure p_Temporal_Incentivos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP_CCDD.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP_CCDD. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_INCEN_TEMP_CCDD  ( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
												GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE16, 
												GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
												GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2,GENERICATTRIBUTE7, GENERICATTRIBUTE6 )
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
        incent.GENERICATTRIBUTE6		-- Subcategoria

	FROM CS_INCENTIVE incent
		INNER JOIN CS_PLRUN p ON incent.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
	WHERE
		incent.TENANTID = itenantId 
		AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND incent.PERIODSEQ =  iperiodseq
		and incent.genericattribute1 is not null;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_INCEN_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Incentivos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Incentivos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;         

--------- Volcar datos de la tabla de Depósitos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_DEPOSIT_TEMP ----
procedure p_Temporal_Depositos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_CCDD';
	w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP_CCDD.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP_CCDD. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP_CCDD( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
												PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, TIPO_PAGO_GA5, 
												PROCESSINGUNITSEQ,WBE, BUSINESSUNITMAP, PROVEEDOR_GA6 )
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
		DEPO.PROCESSINGUNITSEQ,
		depo.EARNINGGROUPID, 
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

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_DEPOSIT_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;         

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----
procedure p_Temporal_Proveedores ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP_CCDD.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
	INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP_CCDD( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO, CECO, WBE_FINAL_IMPUTACION, DETALLE_ACTIVIDAD, ACTIVIDAD,
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

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PROVEEDORES_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Proveedores', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Proveedores', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----
procedure p_Temporal_Equipamientos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_EQUIPAMIENTO_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_CCDD.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_EQUIPAMIENTO_TEMP_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_EQUIPAMIENTO_TEMP_CCDD( TENANTID,PERIODSEQ,EQUIPAMIENTO, IDMARCA, MARCA, IDMODELO, MODELO, IDTIPO, TIPO, LITROS, POTENCIAKW,FECHA_INICIO_VIGOR,
														FECHA_FIN_VIGOR )
	SELECT 
		itenantId TENANTID,
		iperiodseq PERIDOSEQ,
		C.CLASSIFIERID EQUIPAMIENTO,
		GC.GENERICATTRIBUTE1 IDMARCA,
		GC.GENERICATTRIBUTE2 MARCA,
		GC.GENERICATTRIBUTE3 IDMODELO,
		GC.GENERICATTRIBUTE4 MODELO,
		GC.GENERICATTRIBUTE5 IDTIPO, 
		GC.GENERICATTRIBUTE6 TIPO,
		GC.GENERICNUMBER1 LITROS,
		GC.GENERICNUMBER2 POTENCIAKW,
		C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
		C.EFFECTIVEENDDATE FECHA_FIN_VIGOR

	FROM CS_GENERICCLASSIFIERTYPE GCT
		INNER JOIN CS_CLASSIFIER C 
			ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
			AND C.TENANTID = itenantId 
			AND C.REMOVEDATE = v_eot
			AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
			--AND C.ISLAST = 1
		INNER JOIN CS_GENERICCLASSIFIER GC 
			ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
			--AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
			AND GC.TENANTID = itenantId
			AND GC.REMOVEDATE = v_eot
			AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
			--AND GC.ISLAST = 1            

	WHERE GCT.NAME ='Equipamiento';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Equipamientos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Equipamientos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Temporal_E4E_Negativos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
		
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TMP2_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_CCDD.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Origen de ENEL_E4E_NEGATIVOS_TEMP_CCDD : CS_DEPOSIT.', v_contador_debug);
    -- Si se ejecuta en la FASE REWARD Utilizamos la tabla de depositos para generar los datos de las tablas porque aun no se han realizado los PAGOS
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_CCDD  ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO, COD_CONTRATO,
														POS_DOC, TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,
														CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, 
														CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO )
	Select
		DEPO.PERIODSEQ,
		DEPO.PERIODO, 
		MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ, 
		--TRIM(replace(to_char(sum(DEPO.VALUE) , '9999999999990D99'), ',', '.')) Valor, 
		sum(DEPO.VALUE),
		--TMP_PDS.PAYEEID,
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

	FROM ENEL_DEPOSIT_TEMP_CCDD DEPO
		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS 
			ON DEPO.payeeseq=TMP_PDS.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PDS.periodseq
			AND (TMP_PDS.SUBCANAL='CCDD'
            or TMP_PDS.SUBCANAL='RESELLERS')

	   INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			--ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            ON TMP_PROV.IDPROVEEDOR=DEPO.PROVEEDOR_GA6
			AND DEPO.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_CCDD TMP_CONTRA
			ON TMP_CONTRA.periodseq=DEPO.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
	WHERE DEPO.TENANTID = itenantId
		AND DEPO.periodseq=iperiodseq        
		AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  

	GROUP BY 
		DEPO.PERIODSEQ, 
		DEPO.PERIODO, 
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ,  
		--TMP_PDS.PAYEEID,
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
		TMP_CONTRA.CONDICIONES_PAGO
	;
		  
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TMP2_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TMP2_CCDD.',v_contador_debug);
	
	w_debug('Origen de ENEL_E4E_NEGATIVOS_TMP2_CCDD : CS_DEPOSIT.', v_contador_debug);
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TMP2_CCDD  ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO, 
														COD_CONTRATO,POS_DOC, TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
														DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
														POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO  )
	Select
		DEPO.PERIODSEQ,
		DEPO.PERIODO, 
		MAX(DEPO.DEPOSITSEQ), -- Guardamos la ref. del seq deposito maximo
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ, 
		--TRIM(replace(to_char(sum(DEPO.VALUE) , '9999999999990D99'), ',', '.')) Valor, 
		sum(DEPO.VALUE),
		--TMP_PDS.PAYEEID,
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
		DEPO.EARNINGGROUPID,--DEPO.wbe,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,          
		DEPO.tipo_pago_ga5, --------------
		TMP_PDS.FECHA_INI_VIGENCIA,
		-- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
		sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO

	FROM ENEL_DEPOSIT_TEMP_CCDD DEPO
		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS 
			ON DEPO.payeeseq=TMP_PDS.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PDS.periodseq
			AND TMP_PDS.SUBCANAL='CCDD'

	   INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.PROVEEDOR_GA6  
			AND DEPO.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_CCDD TMP_CONTRA
			ON TMP_CONTRA.periodseq=DEPO.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			--AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
	WHERE DEPO.TENANTID = itenantId
		AND DEPO.periodseq=iperiodseq        
		--AND DEPO.VALUE < 0  -- Se incluyen los depositos negativos para el informe de Balance de Pagos y se filtran al generar los ficheros E4E y ECS  

	GROUP BY 
		DEPO.PERIODSEQ, 
		DEPO.PERIODO, 
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ,  
		--TMP_PDS.PAYEEID,
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
		--DEPO.wbe,
        DEPO.EARNINGGROUPID,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,           
		DEPO.TIPO_PAGO_GA5,
		TMP_PDS.FECHA_INI_VIGENCIA,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO
	;

	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TMP2_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TMP2_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_E4E_Negativos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_E4E_Negativos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--------- Volcar datos de Productos a una Temporal. 
---------- Tabla ENEL_PRODUCTOS_TEMP ----
procedure p_Temporal_Productos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_PRODUCTOS_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PRODUCTOS_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_PRODUCTOS_TEMP_CCDD.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PRODUCTOS_TEMP_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PRODUCTOS_TEMP_CCDD  ( TENANTID, PERIODSEQ, PRODUCTID, DESCRIPTION, NAME, FAMILIA, PROVEEDOR_PRESTACION, PROVEEDOR_CAPTACION, 
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
		INNER JOIN CS_CLASSIFIER C ON C.CLASSIFIERSEQ = PROD.CLASSIFIERSEQ
			AND C.TENANTID = itenantId
			AND C.REMOVEDATE = v_eot
			AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo                                     
			--AND C.ISLAST = 1
	WHERE PROD.REMOVEDATE = v_eot
		AND PROD.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
		AND PROD.EFFECTIVEENDDATE >= v_ultimo_dia_periodo
		and prod.genericattribute8 is not null
	; 

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PRODUCTOS_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Productos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Productos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Temporal_Contratos_E4E ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;    
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_CCDD.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRATOS_TEMP_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
	INSERT INTO ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CCDD   (TENANTID,PERIODSEQ,ID,PDS,ACTIVIDAD_DETALLADA,ACTIVIDAD, CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
														ORG_COMPRAS,CONDICIONES_PAGO, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR,CECO)
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
        GC.GENERICATTRIBUTE14 AS CECO

	FROM CS_GENERICCLASSIFIERTYPE GCT
		INNER JOIN CS_CLASSIFIER C 
			ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
			AND C.TENANTID = itenantId 
			AND C.REMOVEDATE = v_eot
			AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
			--AND C.ISLAST = 1
		INNER JOIN CS_GENERICCLASSIFIER GC 
			ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
			--AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
			AND GC.TENANTID = itenantId
			AND GC.REMOVEDATE = v_eot
			AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
			--AND GC.ISLAST = 1               

	WHERE GCT.NAME ='Contrato'
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRATOS_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_CONTRATOS_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Contratos_E4E', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Contratos_E4E', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Temporal_Pds (iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS  
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP_CCDD.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP_CCDD';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP_CCDD.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PDS_TEMP_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PDS_TEMP_CCDD( PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
											PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, NOMBRE_COMERCIAL, IMPORTE_UB, FECHA_CONTRATACION, 
											TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
											BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION,
                                            APLICACION_INCEN_CP, RESPONSABLE) --APM 07.03.2024 Evo CPs
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
        POS.GENERICBOOLEAN1 AS APLICACION_INCEN_CP, --APM 07.03.2024 Evo CPs
        (SELECT POSI.NAME FROM CS_POSITION POSI WHERE POSI.REMOVEDATE = v_eot 
            AND POSI.RULEELEMENTOWNERSEQ = POS.MANAGERSEQ 
            AND pos.TENANTID = itenantId 
            AND posi.EFFECTIVESTARTDATE <= PER.ENDDATE - 1 
            AND posi.EFFECTIVEENDDATE >= PER.ENDDATE - 1 and 
            POS.PROCESSINGUNITSEQ = iprocessingUnitSeq) as RESPONSABLE --APM 03.06.2025

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

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PDS_TEMP_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Pds', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Pds', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Temporal_Depositos_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz_Proceso  IN VARCHAR2)
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_DEPOSIT_CCDD_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_CCDD_TEMP';
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_CCDD_TEMP_2';
    w_debug('Fin Truncado de la tabla ENEL_E4E_DEPOSIT_CCDD_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_DEPOSIT_CCDD_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    -- Si se ejecuta en una FASE que no es REWARD Utilizamos la tabla de PAGOS
	w_debug('Origen de ENEL_E4E_DEPOSIT_CCDD_TEMP : CS_PAYMENT.', v_contador_debug);
    INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_CCDD_TEMP( PERIODSEQ,POSITIONSEQ, PAYEESEQ, VALUE, PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO, COD_CONTRATO,POS_DOC, TEXTO_BREVE,ORG_COMPRAS, 
													CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, BUSINESSUNIT)
    Select
		depo.PERIODSEQ, 
		depo.POSITIONSEQ, 
		depo.PAYEESEQ, 
		sum(depo.VALUE),
/* BOM - DCR - 11.10.2022 - Errores E4E (CAL0230)
Old Code
		TMP_PDS.PAYEEID,
New Code */
		TMP_PDS.PDS, -- En CCDD hay agentes con varias posiciones
/* EOM - DCR - 11.10.2022 - Errores E4E (CAL0230) */
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
		sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN depo.VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
        BU.NAME
          
	FROM  ENELEXT.enel_deposit_temp_CCDD DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_CCDD TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.PROVEEDOR_GA6 
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CCDD TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
/* BOM - DCR - 11.10.2022 - Errores E4E (CAL0230)
Old Code
			AND TMP_CONTRA.PDS = TMP_PDS.PDS    
New Code */
AND TMP_CONTRA.PDS = TMP_PDS.PDS  
			--AND TMP_CONTRA.PDS = TMP_PDS.PAYEEID -- En CCDD hay agentes con varias posiciones
/* EOM - DCR - 11.10.2022 - Errores E4E (CAL0230) */
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD --APM 22.07.2025 Se descomenta.
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
			
		INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
             
	WHERE 
		DEPO.TENANTID = itenantId
		AND DEPO.periodseq=iperiodseq        
		AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
		and depo.tipo_pago_ga5 is not null
		and depo.value > 0  
		
	GROUP BY 
		DEPO.PERIODSEQ, 
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ, 
/* BOM - DCR - 11.10.2022 - Errores E4E (CAL0230)
Old Code
		TMP_PDS.PAYEEID,
New Code */
		TMP_PDS.PDS, -- En CCDD hay agentes con varias posiciones
/* EOM - DCR - 11.10.2022 - Errores E4E (CAL0230) */
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
		BU.NAME;
        
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_CCDD_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_CCDD_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_CCDD_TEMP.',v_contador_debug);
	
	w_debug('Cargando tabla ENEL_E4E_DEPOSIT_CCDD_TEMP_2. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

	w_debug('Origen de ENEL_E4E_DEPOSIT_CCDD_TEMP_2 : ', v_contador_debug);
                   
    INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_CCDD_TEMP_2  ( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC, TEXTO_BREVE,ORG_COMPRAS, 
														CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,ACTIVIDAD, 
														TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, 
														BUSINESSUNIT  )
    Select
		depo.PERIODSEQ, 
		depo.POSITIONSEQ, 
		depo.PAYEESEQ, 
		sum(depo.VALUE),
/* BOM CAL0152 31.05.2022 DCR 
Old Code
		TMP_PDS.PAYEEID,
New Code */
        TMP_PDS.NOMBRE_COMERCIAL,
/* EOM CAL0152 31.05.2022 DCR */
		TMP_PDS.PAR_PROVEEDOR, 
		TMP_PDS.TIPO_IMPOSITIVO,
		TMP_CONTRA.COD_CONTRATO, 
		TMP_CONTRA.POS_DOC, 
		TMP_CONTRA.TEXTO_BREVE, 
		TMP_CONTRA.ORG_COMPRAS,
		TMP_CONTRA.CODIGO_SERVICIO,
		TMP_PROV.IDPROVEEDOR,
		TMP_PROV.SOCIEDAD, 
		TMP_CONTRA.CECO, --TMP_PROV.CECO, Ahora saca CECO de CONTRATOS en Callidus 23.03.2022 MIKE
		TMP_PROV.DESCRIPCION, 
		TMP_PROV.GR_COMPRAS, 
		TMP_PROV.CENTRO_LOGISTICO, 
		depo.wbe,
		TMP_PROV.ACTIVIDAD,
		DEPO.TIPO_PAGO_GA5,
		TMP_PDS.FECHA_INI_VIGENCIA,
		-- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
		sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN depo.VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
        BU.NAME
          
	FROM  ENELEXT.enel_deposit_temp_CCDD DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_CCDD TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.PROVEEDOR_GA6  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CCDD TMP_CONTRA
			ON TMP_CONTRA.periodseq=depo.periodseq
/* BOM - DCR - 11.10.2022 - Errores E4E (CAL0230)
Old Code
			AND TMP_CONTRA.PDS = TMP_PDS.PDS
New Code */
			AND TMP_CONTRA.PDS = TMP_PDS.PAYEEID -- En CCDD hay agentes con varias posiciones
/* EOM - DCR - 11.10.2022 - Errores E4E (CAL0230) */
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

	GROUP BY 
		DEPO.PERIODSEQ, 
		DEPO.POSITIONSEQ, 
		DEPO.PAYEESEQ, 
/* BOM CAL0152 31.05.2022 DCR 
Old Code
		TMP_PDS.PAYEEID,
New Code */
        TMP_PDS.NOMBRE_COMERCIAL,
/* EOM CAL0152 31.05.2022 DCR */
		TMP_PDS.PAR_PROVEEDOR, 
		TMP_PDS.TIPO_IMPOSITIVO,
		TMP_CONTRA.COD_CONTRATO, 
		TMP_CONTRA.POS_DOC, 
		TMP_CONTRA.TEXTO_BREVE, 
		TMP_CONTRA.ORG_COMPRAS,
		TMP_CONTRA.CODIGO_SERVICIO,
		TMP_PROV.IDPROVEEDOR,
		TMP_PROV.SOCIEDAD, 
		TMP_CONTRA.CECO, --TMP_PROV.CECO, Ahora saca CECO de CONTRATOS en Callidus 23.03.2022 MIKE
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
		BU.NAME;   
        
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_CCDD_TEMP_2: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_CCDD_TEMP_2',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_CCDD_TEMP_2.',v_contador_debug);

  /*  z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_E4E', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_E4E', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);
*/
end;

procedure p_Cabecera_Ficheros_E4E (  iperiod IN VARCHAR2, iFichero IN VARCHAR2 )
AS
    contador integer;  
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_CCDD para fichero ' || iFichero ,  v_contador_debug);
    contador := 1;
    -- Registro de CABECERA 1 : lista de campos
    INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                     CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'CAMPO1','CAMPO2','CAMPO3','CAMPO4','CAMPO5','CAMPO6','CAMPO7','CAMPO8','CAMPO9',
	'CAMPO10','CAMPO11','CAMPO12','CAMPO13','CAMPO14','CAMPO15','CAMPO16','CAMPO17','CAMPO18','CAMPO19','CAMPO20','CAMPO21','CAMPO22',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 2 : CABECERA
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                     CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','CABECERA','Contrato','Fecha Pedido','','Sociedad','Cod. Proveedor','CECO Aprob.',
	'Org.Compras','Gr.Compras','Riesgo','Contract Manager','Sit.Trabajo','Nota Cab.','','','','','','','',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 3 : POSICION    
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                     CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','POSICION','Contrato','','Pos. contrato','Tipo Imp.','Código','Texto breve',
	'Texto posición','Cantidad','Unidad medida','Fecha entrega','Centro log.','Imputación','Tipo impuesto','Ref. para proveedor','Num. Dirección',
	'Dirección','Población','Cod. postal','Nom. solicitante',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 4 : SERVICIO
    contador := contador +1;
    INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                     CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','SERVICIO','Contrato','','Pos. contrato','Línea. Servicio','Cod. Servicio','Texto breve',
	'Cantidad','Imputación','','','','','','','','','','','',iFichero, 'BUSINESSUNIT');        

    COMMIT;
    w_debug('Fin Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_CCDD para fichero ' || iFichero ,  v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Ficheros_E4E', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Ficheros_E4E', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Final_E4E_1 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(20);
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
    v_cabecera VARCHAR2(20); -- nueva variable para el control de la cabecera
    contadorPosicion integer; -- contador para la posición
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_CCDD.', v_contador_debug);
    
    --v_codFichero :='E4E1';  -- v2.0 se asigna el valor dinamicamente en función de la actividad del proveedor
	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL WHERE ....';
    BEGIN
        LOOP
            DELETE FROM ENEL_E4E_FINAL_CCDD WHERE PERIODO = iperiod AND FICHERO like 'E%1' AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_CCDD.', v_contador_debug);

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
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_CCDD. Fichero ' || v_codFichero ,  v_contador_debug);
    
    contadorE4E := 4;
    contadorECS := 4;
    contadorPosicion := 10;
     
    DECLARE
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
                PERIODSEQ,
                sum(VALUE) as value,
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
                BUSINESSUNIT
            FROM ENEL_E4E_DEPOSIT_CCDD_TEMP_2
            WHERE PERIODSEQ = iperiodseq 
                  AND COD_CONTRATO is not null    -- Fichero E4E1 contiene los registros con contrato
                  AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos 
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
                BUSINESSUNIT
            order by pds, idproveedor;
            
		REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP
			-- Código de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
				WHEN 'STP'          THEN v_codFichero :='E4E1';
                WHEN 'SSII'         THEN v_codFichero :='E4E1';
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS1';  
                WHEN 'CAPTACION'    THEN v_codFichero :='ECS1';
                WHEN 'ATC'          THEN v_codFichero :='ECS1';
                ELSE                     v_codFichero :='NOT1';
            END CASE;
                
            -- Se concatenan los valores que forman el código de referencia:
            --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR || v_codMes;

            -- Se determina el código de equivalencia del tipo impositivo
            CASE REGDEPOSITO.TIPO_IMPOSITIVO
                WHEN 'IVA'          THEN v_Impuesto := 'SD';
                WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
/* BOM CAL0152 31.05.2022 DCR */
                WHEN 'BD'           THEN v_Impuesto :='BD';
/* EOM CAL0152 31.05.2022 DCR */                
                ELSE                     v_Impuesto := '';
            END CASE;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
            
            -- MPR - Se concatenan los valores que forman el código para que solo cargue una cabecera por pds + proveedor, independientemente de las wbe:
            -- Codigo de PDS + Código de proveedor
           
            IF v_cabecera is null then
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;    
            
                INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
												CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
                VALUES ( iperiod,
					contadorTabla,
                    v_referencia,
                    '',
                    'CABECERA', 
                    REGDEPOSITO.COD_CONTRATO,
                    v_txtFechaInicio,
                    '',
                    REGDEPOSITO.SOCIEDAD, --Cambiar a clasificacion de contratos
                    REGDEPOSITO.PAR_PROVEEDOR,
                    REGDEPOSITO.CECO,
                    REGDEPOSITO.ORG_COMPRAS,
                    REGDEPOSITO.GR_COMPRAS,
                    'NO',
                    '',
                    'RE',
                    '','','','','','','','',v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                    
            ELSIF v_cabecera <> REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR then
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;    
            
                INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
                    '','','','','','','','',v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                    
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
            
            INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10,  
											CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
            VALUES ( iperiod,
                contadorTabla,
                v_referencia,    --CAMPO1
                --'10',
                contadorPosicion,
                'POSICION', 
                REGDEPOSITO.COD_CONTRATO, --CAMPO4
                '',
                REGDEPOSITO.POS_DOC,
                'P',                      --CAMPO7
                '',
                REGDEPOSITO.TEXTO_BREVE,  --CAMPO9
                REGDEPOSITO.DESCRIPCION,  --CAMPO10
                -- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
                CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
                'UA',
                v_txtFechaActual,
                REGDEPOSITO.CENTRO_LOGISTICO,
                REGDEPOSITO.WBE_FINAL_IMPUTACION,
                v_Impuesto,
                '','','','','','ES21-01',v_codFichero,REGDEPOSITO.BUSINESSUNIT);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - POSICION
                IF v_codFichero = 'E4E1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF; 
            
                INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
												CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
                VALUES ( iperiod,
                    contadorTabla,
                    v_referencia,
                    --'10',
                    contadorPosicion,
                    'SERVICIO', 
                    REGDEPOSITO.COD_CONTRATO,
                    '',
                    REGDEPOSITO.POS_DOC,  -- CAMPO6
                    '10',                     -- CAMPO7
                    REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
                    REGDEPOSITO.TEXTO_BREVE,
                    to_char(REGDEPOSITO.VALUE),  --CAMPO10
                    REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
                    '', '', '', '',                    -- CAMPO12 a 15
                    '', '', '', '',                    -- CAMPO16 a 19
                    '', '', '',                        -- CAMPO20 a 22
                    v_codFichero,REGDEPOSITO.BUSINESSUNIT);

            END IF;
            
            v_cabecera := REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR;
            
		FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        END LOOP;    
        CLOSE C_TMPDEPOSITOS;
    END;
    
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN
        p_Cabecera_Ficheros_E4E (  iperiod , 'E4E1' );
    end if;
    
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
        p_Cabecera_Ficheros_E4E (  iperiod , 'ECS1' );
    end if;   
    
    w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_CCDD:  E4E1'|| to_char(contadorE4E) || ' -- ECS1'|| to_char(contadorECS) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_1', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_1', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;       

procedure p_Final_E4E_2 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
	v_referencia VARCHAR2(20);
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
    v_cabecera VARCHAR2(20); -- nueva variable para el control de la cabecera
    contadorPosicion integer; -- contador para la posición
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_CCDD.', v_contador_debug);    
    --v_codFichero :='E4E2'; -- v2.0 se asigna el valor dinamicamente en función de la actividad del proveedor

	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL WHERE ....';
    BEGIN
        LOOP
            DELETE FROM ENEL_E4E_FINAL_CCDD WHERE PERIODO = iperiod AND FICHERO like 'E%2'  AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_CCDD.', v_contador_debug);

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
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_CCDD. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_CCDD. Fichero ' || v_codFichero ,  v_contador_debug);
    
    contadorE4E := 4;
    contadorECS := 4;
    contadorPosicion := 10;
     
    DECLARE
        CURSOR C_TMPDEPOSITOS IS
            SELECT 
                PERIODSEQ,
                sum(VALUE) as value,
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
                BUSINESSUNIT
            FROM ENEL_E4E_DEPOSIT_CCDD_TEMP_2
            WHERE PERIODSEQ = iperiodseq 
                AND COD_CONTRATO is null  -- Fichero E4E2 contiene los registros sin contrato (valor nulo)
                AND VALUE > 0             -- Fichero E4E se incluyen solo los positivos
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
                BUSINESSUNIT
            order by pds, idproveedor;
                
	REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP    
            -- Código de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
                WHEN 'STP'          THEN v_codFichero :='E4E2';
                WHEN 'SSII'         THEN v_codFichero :='E4E2';                
                WHEN 'CAPTACIÓN'    THEN v_codFichero :='ECS2';
                WHEN 'CAPTACION'    THEN v_codFichero :='ECS2';
                WHEN 'ATC'          THEN v_codFichero :='ECS2';
                ELSE                     v_codFichero :='NOT2';
            END CASE;
            
            -- Se concatenan los valores que forman el código de referencia:
            --    YY + Codigo de PDS + Código de proveedor + Código de Mes (Enero = A, Febrero = B ...)
            v_referencia := v_txtYear || REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR || v_codMes;

            -- Se determina el código de equivalencia del tipo impositivo
            CASE REGDEPOSITO.TIPO_IMPOSITIVO
                WHEN 'IVA'          THEN v_Impuesto := 'SD';
                WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
/* BOM CAL0152 31.05.2022 DCR */
                WHEN 'BD'           THEN v_Impuesto :='BD';
/* EOM CAL0152 31.05.2022 DCR */   
                ELSE                     v_Impuesto := '';
            END CASE;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
            ELSE
                v_txtFechaInicio := v_txtFechaInicioPeriodo;
            END IF;
             
            -- MPR - Se concatenan los valores que forman el código para que solo cargue una cabecera por pds + proveedor, independientemente de las wbe:
            -- Codigo de PDS + Código de proveedor
           
            IF v_cabecera is null then
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E2' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
				ELSIF v_codFichero = 'ECS2' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
				END IF;          
            
                INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
                    '','','','','','','','',v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                    
            ELSIF v_cabecera <> REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR then
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E2' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
				ELSIF v_codFichero = 'ECS2' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
				END IF; 
            
                INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
                    '','','','','','','','',v_codFichero,REGDEPOSITO.BUSINESSUNIT);
                    
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
            
            INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
			VALUES ( iperiod,
				contadorTabla,
				v_referencia,
				--'10',
				contadorPosicion,
				'POSICION', 
				REGDEPOSITO.COD_CONTRATO,
				'',
				REGDEPOSITO.POS_DOC,
				'P',
				'',
				REGDEPOSITO.TEXTO_BREVE,
				REGDEPOSITO.DESCRIPCION,
				-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
				CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
				'UA',
				v_txtFechaActual,
				REGDEPOSITO.CENTRO_LOGISTICO,
				REGDEPOSITO.WBE_FINAL_IMPUTACION,
				v_Impuesto,
				'','','','','','ES21-01',v_codFichero,REGDEPOSITO.BUSINESSUNIT);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - servicio
                IF v_codFichero = 'E4E2' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
                END IF;
             
                INSERT INTO ENEL_E4E_FINAL_CCDD (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
					contadorTabla,
					v_referencia,
					--'10',
					contadorPosicion,
					'SERVICIO', 
					REGDEPOSITO.COD_CONTRATO,
					'',
					REGDEPOSITO.POS_DOC,  -- CAMPO6
					'10',                     -- CAMPO7
					REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
					REGDEPOSITO.TEXTO_BREVE,
					to_char(REGDEPOSITO.VALUE),  --CAMPO10
					REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
					'', '', '', '',                    -- CAMPO12 a 15
					'', '', '', '',                    -- CAMPO16 a 19
					'', '', '',                        -- CAMPO20 a 22
					v_codFichero,REGDEPOSITO.BUSINESSUNIT);

            END IF;
            
            v_cabecera := REGDEPOSITO.PDS || REGDEPOSITO.IDPROVEEDOR;
                        
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;        
        END LOOP;               
        CLOSE C_TMPDEPOSITOS;
    END;
    
    --Si se han insertado registros de datos de E4E, se insertan los registros de cabecera para el fichero E4E2
    if contadorE4E > 4 THEN    
        p_Cabecera_Ficheros_E4E (  iperiod , 'E4E2' );
    end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
        p_Cabecera_Ficheros_E4E (  iperiod , 'ECS2' );
    end if;   
    
	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_CCDD:  E4E2'|| to_char(contadorE4E) || ' -- ECS2'|| to_char(contadorECS) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_2', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_2', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

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

    w_debug('Inicio Borrado de la tabla ENEL_E4E_NEGATIVOS_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_NEGATIVOS_CCDD.', v_contador_debug);

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

    select NVL(MAX(IDPEDIDO),0) into v_maxIDPEDIDO  from ENEL_E4E_NEGATIVOS_CCDD WHERE ESTADO='LIQUIDADO';
    w_debug('Numero máximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) ,  v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_E4E_NEGATIVOS_CCDD.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_CCDD   ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, PDS, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
													SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
													CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
													CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION, ACTIVIDAD  )   
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
			WHEN 'ES21'          THEN 'ZES000013'
			WHEN 'ES29'          THEN 'ZES000016'
			WHEN 'PT1Q'          THEN 'ZPT000003'
			ELSE  ''
		END MATERIAL,     
		CASE e4edt.SOCIEDAD
			WHEN 'ES21'          THEN 'RETROACCIÓN COM. ENDESA ENERGÍA'
			WHEN 'ES29'          THEN 'RETROACCIÓN COM. EOSC'
			WHEN 'PT1Q'          THEN 'RETROACCIÓN COM. E. E. PORTUGAL'
			ELSE  ''
		END TEXTO_MATERIAL,
		1 CANTIDAD,
		ABS(VALUE) as PRECIO,
		CASE 
			WHEN e4edt.TIPO_IMPOSITIVO ='IVA'          THEN '1'
			WHEN e4edt.TIPO_IMPOSITIVO ='IVA Portugal' THEN 'H'
			ELSE   ''
		END CLASIF_FISCAL_IVA,
		CASE e4edt.TIPO_IMPOSITIVO
			WHEN 'IGIC'          THEN '1'
			ELSE  ''
		END CLASIF_FISCAL_IGIC,    
		WBE_FINAL_IMPUTACION,
		ACTIVIDAD

	FROM ENEL_E4E_NEGATIVOS_TMP2_CCDD e4edt 
	WHERE 
		e4edt.VALUE < 0 
		and e4edt.PERIODSEQ = iperiodseq
/*
		-- MPR - Modificación para quitar los negativos que tengan importe en positivo
		and (select sum(depo.value) from ENEL_E4E_DEPOSIT_CCDD_TEMP depo 
			where depo.periodseq = e4edt.periodseq
			and depo.PAYEESEQ = e4edt.PAYEESEQ
			and depo.POSITIONSEQ = e4edt.POSITIONSEQ 
			and depo.idproveedor = e4edt.idproveedor
			and depo.WBE_FINAL_IMPUTACION = e4edt.WBE_FINAL_IMPUTACION) is null
*/
	;

	filas := sql%rowcount;
	COMMIT;

	w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
	dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_NEGATIVOS_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_Negativos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_Negativos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;       

procedure p_Temporal_Creditos_Scaweb (  iprocessingUnitSeq IN VARCHAR2,  iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    vFechaAlta Date;
    v_fecInicioPeriodoSig date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_SCAWEB_LIQUIDACION_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_CCDD.', v_contador_debug);
    
    -- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := SYSDATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fecInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
        
    w_debug('Insertando CREDITOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_CCDD.' ,  v_contador_debug);
    -- v2.0 Se cambia la tabla de origen CS_CREDIT  a la temporal ENEL_CREDIT_TEMP
	INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_CCDD ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE, NOMBRE, CREDITSEQ )   
	SELECT 
		iperiod PERIODO,        
		--credit.GENERICATTRIBUTE2,      -- Proveedor,
		--to_number(credtmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda
		to_number(REPLACE(credtmp.GENERICATTRIBUTE2, ' integer','')) PROVEEDOR,             
		--to_char(credit.COMPENSATIONDATE, 'YYYY'),
		to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
		--to_char(credit.COMPENSATIONDATE, 'MM'),
		to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
		
		credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
		credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidación
		1 as CANTIDAD,
		--credit.VALUE,                  --Importe Comision
		ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
		to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
		'' as FechaBaja,
		'' as Telefono,
		--credtmp.GENERICATTRIBUTE9 as Observaciones,      -- Solicitud de servicio
		-- En ajustes Manuales se pone el campo Observaciones credit.GA15
		case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end as Observaciones,
		null,
		--credtmp.GENERICATTRIBUTE11,       --Codigo Postal
		credtmp.GENERICATTRIBUTE6,       --Provincia
        /*BOM APM 21.07.2025 Old Code*/
		credtmp.VALUE  as REALVALUE,      -- Valor real sin tomar el valor absoluto para informe de revisión  ,
        --New Code
        --credtmp.importe,
        /*EOM APM 21.07.2025*/
		CREDTMP.NAME,
		CREDITSEQ
		
	FROM ENEL_CREDIT_TEMP_CCDD credtmp
	   INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
			ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

	WHERE 
		credtmp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
		and credtmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)
		and NOT ( credtmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050
		and (TMP_PDS.SUBCANAL='CCDD'
        or TMP_PDS.SUBCANAL='RESELLERS') --APM 16.07.2025
	
	group by
		iperiod,        
		--credit.GENERICATTRIBUTE2,      -- Proveedor,
		--to_number(credtmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda
		to_number(REPLACE(credtmp.GENERICATTRIBUTE2, ' integer','')),             
		--to_char(credit.COMPENSATIONDATE, 'YYYY'),
		to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
		--to_char(credit.COMPENSATIONDATE, 'MM'),
		to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
		credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
		credtmp.GENERICATTRIBUTE1,      -- Concepto Liquidación
		1,
		--credit.VALUE,                  --Importe Comision
		ABS(credtmp.VALUE),                  --Importe Comision 2017-09-28 - se pasa el valor absoluto del credito
		to_char(vFechaAlta, 'YYYYMMDD'),
		-- En ajustes Manuales se pone el campo Observaciones credit.GA15
		case when credtmp.CREDITTYPEID like '%Ajuste%' then credtmp.GENERICATTRIBUTE15 else credtmp.GENERICATTRIBUTE9 end,
		credtmp.GENERICATTRIBUTE6,       --Provincia
		credtmp.VALUE ,      -- Valor real sin tomar el valor absoluto para informe de revisión  ,
		CREDTMP.NAME,
		CREDITSEQ
		;  

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_SCAWEB_LIQUIDACION_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando INCENTIVOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_CCDD.' ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_CCDD ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE )   
	SELECT 
		iperiod PERIODO,        
		to_number(incentmp.GENERICATTRIBUTE2) as PROVEEDOR,   -- Proveedor en formato numerico, sin ceros a la izquierda             
		to_char(v_fecInicioPeriodoSig, 'YYYY') as ANO_LIQUIDACION,  -- Año del periodo sigiente
		to_char(v_fecInicioPeriodoSig, 'MM') as MES_LIQUIDACION,  -- Mes del periodo sigiente
		TMP_PDS.PDS as CODIGO_AGENTE_INTERNO,      -- Prestador - PDS
		incentmp.GENERICATTRIBUTE1 as CONCEPTO,      -- Concepto Liquidación
		1 as CANTIDAD,
		ABS(incentmp.VALUE) as IMPORTE,
		to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
		'' as FechaBaja,
		'' as Telefono,
		 Replace(incentmp.GENERICATTRIBUTE4, 'integer', '') as Observaciones, 
		''  as Codigo_Postal,       --Codigo Postal
		''  as Provincia,     --Provincia
		incentmp.VALUE  as REALVALUE    -- Valor real sin tomar el valor absoluto para informe de revisión
		
	FROM ENEL_INCEN_TEMP_CCDD incentmp
		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
			ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			
	WHERE
		incentmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)  
		and incentmp.VALUE <> 0  -- Se filtran los incentivos que sean distintos de 0
        AND incentmp.GENERICBOOLEAN1 = 1   -- Indica los incentivos que se incluyen en pagos
		and NOT ( incentmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050            
		and (TMP_PDS.SUBCANAL='CCDD'
        or TMP_PDS.SUBCANAL='RESELLERS') --APM 16.07.2025
		and incentmp.name not like 'I - Captacion CCDD - Rappel Incremental -%'
		;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_SCAWEB_LIQUIDACION_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_SCAWEB_LIQUIDACION_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Creditos_Scaweb', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Creditos_Scaweb', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

-- PREFATURA
procedure p_Prefactura ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2  )
AS
    v_fechaPeriodoSiguiente date;
    v_txtMes_Liquidacion VARCHAR2(10);
	v_txtMes_Liquidacion2 VARCHAR(10);
	v_fechaActual date;
    v_mesanio VARCHAR(4);
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_PREFACTURA_CCDD.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_PREFACTURA_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_PREFACTURA_CCDD.', v_contador_debug);
     w_debug('Inicio Borrado de la tabla ENEL_PREFACTURA_CCDD_RESELLERS.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_PREFACTURA_CCDD_RESELLERS WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_PREFACTURA_CCDD_RESELLERS.', v_contador_debug);
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');
	v_txtMes_Liquidacion2 := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
    v_mesanio := to_char(f_fecha_inicio(iperiodseq), 'MMYY');
	
	-- SI iInterfaz es 'ACTUALIZA_INFORMES_POST_CCDD' se está generando el fichero definitivo de LIQUIDACION '
    --iInterfaz
    IF iInterfaz =  'ACTUALIZA_INFORMES_POST_CCDD'  THEN
		v_fechaActual := to_char(SYSDATE, 'DD/MM/YYYY');
    ELSE
		v_fechaActual := '';
    END IF;

    w_debug('Insertando Registros de CREDITOS en tabla ENEL_PREFACTURA_CCDD.' ,  v_contador_debug);
   
    INSERT INTO ENELEXT.ENEL_PREFACTURA_CCDD ( PERIODO, PERIODSEQ, MES_LIQUIDACION, FECHA_LIQUIDACION, PDS, NUMERO_RESUMEN, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION,
												CONCEPTO_LIQ, TARIFA, IMPORTE_COMISION, VALUE, CONSUMO, DESCUENTO, PRODUCTO, BU_NAME, PAYEESEQ, POSITIONSEQ, CAMPANIA, LINEA_NEGOCIO,
												POTENCIA, PVP, PORCENTAJE, IVA, UNIDAD, OFERTA, TIPO, TRAMO_CONSUMO, TRAMO_POTENCIA, SUBCATEGORIA, SERVICIO, NAME, REALIZADO, OBJETIVO,SERVICIO2,VALUE_RESELLERS  )   
    SELECT 
        credtmp.PERIODO, 
		credtmp.PERIODSEQ,
        v_txtMes_Liquidacion as Mes_Liquidacion,
		v_fechaActual as FECHA_LIQUIDACION, -- mdificar esta fecha cuando se lance el POST, mientras blanco
        TMP_PDS.PDS, 
		--CREDTMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        --CREDTMP.GENERICATTRIBUTE1 || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
		TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF,
        'Proveedor', --TMP_PROV.IDPROVEEDOR, 
        'Descripcion', --TMP_PROV.DESCRIPCION,
        credtmp.GenericAttribute1 as CONCEPTO_LIQ,
		TXNTMP.TEX0_GENERICATTRIBUTE15 as TARIFA,
		TRIM(to_char(credtmp.VALUE , '9999999999990D99')) IMPORTE_COMISION,
		credtmp.value,
		CREDTMP.GENERICNUMBER3, --credtmp.GENERICNUMBER4 as CONSUMO,
		TXNTMP.GENERICNUMBER3, --TXNTMP.GENERICNUMBER4*100 as DESCUENTO,
		TXNTMP.PRODUCTID as producto,
		CREDTMP.GENERICATTRIBUTE1, --credtmp.bu_name,
		TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
		TXNTMP. TEX0_GENERICATTRIBUTE3, --TXNTMP.GENERICATTRIBUTE32 as campania,
		TXNTMP.TEX0_GENERICATTRIBUTE13 as linea_negocio,
		CREDTMP.GENERICNUMBER3, --CREDTMP.GENERICNUMBER6 AS POTENCIA, -- TRAMO
		TXNTMP.TEX0_GENERICATTRIBUTE5, --TXNTMP.GENERICNUMBER5 as PVP,
		CREDTMP.GENERICNUMBER2 as PORCENTAJE,
		CASE 
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IVA' THEN 21
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IGIC' THEN 7
			ELSE 21
		END AS IVA,
		'1' as UNIDAD,
		CREDTMP.GENERICATTRIBUTE6 as OFERTA,
		'CREDIT' as TIPO,
		CREDTMP.GENERICATTRIBUTE12 as TRAMO_CONSUMO,
		CREDTMP.GENERICATTRIBUTE13 as TRAMO_POTENCIA,
        CREDTMP.GENERICATTRIBUTE5 || ' - ' || CREDTMP.GENERICATTRIBUTE3 as SUBCATEGORIA,
        /*BOM 21.07.2025 Old Code*/
        --CREDTMP.GENERICATTRIBUTE3 || ' - ' || CREDTMP.GENERICATTRIBUTE1 as SERVICIO2,
        --New Code
        CREDTMP.GENERICATTRIBUTE3 || ' - ' || CREDTMP.GENERICATTRIBUTE1 as SERVICIO,
        /*EOM 21.07.2025*/
        CREDTMP.NAME as NAME,
        credtmp.genericnumber1,
        credtmp.genericnumber2,
        CREDTMP.CREDITTYPEID as SERVICIO2,
        CREDTMP.VALUE_CREDIT AS VALUE_RESELLERS
        
        		
    FROM ENEL_CREDIT_TEMP_CCDD CREDTMP
        INNER JOIN ENEL_TXN_TEMP_CCDD TXNTMP 
            ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ
        
        INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS 
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
            and tmp_pds.periodseq = iperiodseq
        
/*        INNER JOIN ENEL_ORDER_IMPU_TEMP_CCDD TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE4
            and TMP_PROV.periodseq = iperiodseq*/
 
    WHERE 
		CREDTMP.GENERICATTRIBUTE1 is not null  
		and CREDTMP.NAME not like '%Incentivo%'
        and credtmp.periodseq = iperiodseq
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
    ;
                
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga CREDITOS de la tabla ENEL_PREFACTURA_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
    

w_debug('Insertando Registros de CREDITOS en tabla ENEL_PREFACTURA_CCDD_RESELLERS.' ,  v_contador_debug);
   
    INSERT INTO ENELEXT.ENEL_PREFACTURA_CCDD_RESELLERS ( PERIODO, PERIODSEQ, MES_LIQUIDACION, FECHA_LIQUIDACION, PDS, NUMERO_RESUMEN, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION,
												CONCEPTO_LIQ, TARIFA, IMPORTE_COMISION, VALUE, CONSUMO, DESCUENTO, PRODUCTO, BU_NAME, PAYEESEQ, POSITIONSEQ, CAMPANIA, LINEA_NEGOCIO,
												POTENCIA, PVP, PORCENTAJE, IVA, UNIDAD, OFERTA, TIPO, TRAMO_CONSUMO, TRAMO_POTENCIA, SUBCATEGORIA, SERVICIO, NAME, REALIZADO, OBJETIVO,SERVICIO2,VALUE_RESELLERS  )   
    SELECT 
        credtmp.PERIODO, 
		credtmp.PERIODSEQ,
        v_txtMes_Liquidacion as Mes_Liquidacion,
		v_fechaActual as FECHA_LIQUIDACION, -- mdificar esta fecha cuando se lance el POST, mientras blanco
        TMP_PDS.PDS, 
		--CREDTMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        --CREDTMP.GENERICATTRIBUTE1 || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
		TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF,
        'Proveedor', --TMP_PROV.IDPROVEEDOR, 
        'Descripcion', --TMP_PROV.DESCRIPCION,
        credtmp.GenericAttribute1 as CONCEPTO_LIQ,
		TXNTMP.TEX0_GENERICATTRIBUTE15 as TARIFA,
		TRIM(to_char(credtmp.VALUE , '9999999999990D99')) IMPORTE_COMISION,
		case when commi.value is not null and ince.GENERICATTRIBUTE4 like 'Importe Base Incremental' then commi.VALUE else CREDTMP.value end,
		CREDTMP.GENERICNUMBER3, --credtmp.GENERICNUMBER4 as CONSUMO,
		TXNTMP.GENERICNUMBER3, --TXNTMP.GENERICNUMBER4*100 as DESCUENTO,
		TXNTMP.PRODUCTID as producto,
		CREDTMP.GENERICATTRIBUTE1, --credtmp.bu_name,
		TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
		TXNTMP. TEX0_GENERICATTRIBUTE3, --TXNTMP.GENERICATTRIBUTE32 as campania,
		TXNTMP.TEX0_GENERICATTRIBUTE13 as linea_negocio,
		CREDTMP.GENERICNUMBER3, --CREDTMP.GENERICNUMBER6 AS POTENCIA, -- TRAMO
		TXNTMP.TEX0_GENERICATTRIBUTE5, --TXNTMP.GENERICNUMBER5 as PVP,
		CREDTMP.GENERICNUMBER2 as PORCENTAJE,
		CASE 
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IVA' THEN 21
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IGIC' THEN 7
			ELSE 21
		END AS IVA,
		'1' as UNIDAD,
		CREDTMP.GENERICATTRIBUTE6 as OFERTA,
		'CREDIT' as TIPO,
		CREDTMP.GENERICATTRIBUTE12 as TRAMO_CONSUMO,
		CREDTMP.GENERICATTRIBUTE13 as TRAMO_POTENCIA,
        CREDTMP.GENERICATTRIBUTE5 || ' - ' || CREDTMP.GENERICATTRIBUTE3 as SUBCATEGORIA,
        /*BOM 21.07.2025 Old Code*/
        --CREDTMP.GENERICATTRIBUTE3 || ' - ' || CREDTMP.GENERICATTRIBUTE1 as SERVICIO2,
        --New Code
         CREDTMP.CREDITTYPEID as SERVICIO,
        /*EOM 21.07.2025*/
        CREDTMP.NAME as NAME,
        credtmp.genericnumber1,
        credtmp.genericnumber2,
        CREDTMP.GENERICATTRIBUTE3 || ' - ' || CREDTMP.GENERICATTRIBUTE1 as SERVICIO2,
        CREDTMP.VALUE_CREDIT AS VALUE_RESELLERS
        
        		
    FROM ENEL_CREDIT_TEMP_CCDD CREDTMP
        INNER JOIN ENEL_TXN_TEMP_CCDD TXNTMP 
            ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ
        
        INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS 
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
            and tmp_pds.periodseq = iperiodseq
        
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = CREDTMP.CREDITSEQ
            AND COMMI.PAYEESEQ = CREDTMP.PAYEESEQ
            AND COMMI.PERIODSEQ= CREDTMP.PERIODSEQ

        LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ 
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq
 
    WHERE 
		CREDTMP.GENERICATTRIBUTE1 is not null  
		and CREDTMP.NAME not like '%Incentivo%'
        and credtmp.periodseq = iperiodseq
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
    ;
                
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga CREDITOS de la tabla ENEL_PREFACTURA_CCDD_RESELLERS: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros de INCENTIVOS en tabla ENEL_PREFACTURA_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_PREFACTURA_CCDD ( PERIODO, PERIODSEQ, MES_LIQUIDACION, FECHA_LIQUIDACION, PDS, NUMERO_RESUMEN, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION,
												CONCEPTO_LIQ, TARIFA, IMPORTE_COMISION, VALUE, CONSUMO, DESCUENTO, PRODUCTO, BU_NAME, PAYEESEQ, POSITIONSEQ, CAMPANIA, LINEA_NEGOCIO,
												POTENCIA, PVP, PORCENTAJE, IVA, UNIDAD, TIPO, REALIZADO, OBJETIVO, CONSECUCION, IMPORTE_UNITARIO,
                                                TIPO_RAPPEL, SUBCATEGORIA, PORC_APLICAR, NAME)
    SELECT 
		INCETMP.PERIODO, 
		INCETMP.PERIODSEQ,
        v_txtMes_Liquidacion as Mes_Liquidacion,
		v_fechaActual as FECHA_LIQUIDACION,
        TMP_PDS.PDS, 
		--INCETMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        --INCETMP.genericattribute7 || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
		TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF,
        'IDProveedor', --TMP_PROV.IDPROVEEDOR, 
        'Descripcion', --TMP_PROV.DESCRIPCION,
        INCETMP.GenericAttribute1 as CONCEPTO_LIQ,
		'' as TARIFA,
		TRIM(to_char(INCETMP.VALUE , '9999999999990D99')) IMPORTE_COMISION,
		INCETMP.value,
		'' as CONSUMO, 
		'' as DESCUENTO,
		'' as producto,
		INCETMP.GENERICATTRIBUTE7, --INCETMP.bu_name,
		TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
		'' as campania,
		INCETMP.GENERICATTRIBUTE2 as linea_negocio,
		'' AS POTENCIA,
		'' AS PVP, 
		'' as PORCENTAJE,
		CASE 
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IVA' THEN 21
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IGIC' THEN 7
			ELSE 21
		END AS IVA,
		'1' as UNIDAD,
		'INCENT' as TIPO,
		INCETMP.GENERICNUMBER2 as REALIZADO, 
		INCETMP.GENERICNUMBER1 as OBJETIVO, 
		INCETMP.GENERICNUMBER3 as CONSECUCION, 
		INCETMP.GENERICNUMBER5 as IMPORTE_UNITARIO,
        INCETMP.GENERICATTRIBUTE3 as TIPO_RAPPEL,
        INCETMP.GENERICATTRIBUTE6 as SUBCATEGORIA,
        INCETMP.GENERICNUMBER4 as PORC_APLICAR,
        INCETMP.NAME as NAME
    
    FROM ENEL_INCEN_TEMP_CCDD INCETMP
        INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
            ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = iperiodseq
      
/*            
        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETF TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE3
            and TMP_PROV.periodseq = iperiodseq
*/
    WHERE 
		INCETMP.GENERICATTRIBUTE1 is not null 
        AND INCETMP.GENERICBOOLEAN1 = 1 -- Este campo está vacío en la tabla del sistema CS_INCENTIVE
        and INCETMP.value <> 0
        and INCETMP.periodseq = iperiodseq
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
		;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_PREFACTURA_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
    

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PREFACTURA_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PREFACTURA_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Prefactura', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Prefactura', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Inf_Factura_Detalle ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaPeriodoSiguiente date;
    v_txtMes_Liquidacion VARCHAR2(10);
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_PREFACT_DETALLE_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_PREFACT_DETALLE_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_PREFACT_DETALLE_CCDD.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');

    w_debug('Insertando Registros de CREDITOS en tabla ENEL_PREFACT_DETALLE_CCDD.' ,  v_contador_debug);
   
	INSERT INTO ENELEXT.ENEL_PREFACT_DETALLE_CCDD ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, 
											DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E,DELEGACION, ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, 
											CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, 
											COD_COMERCIAL, MARCA, MODELO, OBSERVACIONES, CUPS )   
	SELECT 
		credtmp.PERIODO, 
		credtmp.PERIODSEQ,
		v_txtMes_Liquidacion as Mes_Liquidacion,
		credtmp.CREDITSEQ, 
		credtmp.CREDITTYPEID ,
		TMP_PDS.PAYEESEQ,
		TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
		TMP_PDS.PDS, 
		TMP_PDS.NOMBRE_FISCAL,
		TMP_PDS.CIF,
		TMP_PROV.IDPROVEEDOR, 
		TMP_PROV.DESCRIPCION,
		TMP_PROV.FICHERO,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,
		TMP_PDS.PAR_PROVEEDOR as CODIGOE4E,
		TMP_PDS.DELEGACION,
		TMP_PDS.ZONA,
		TMP_PDS.TERRITORIO,
		TMP_PDS.CALLE,
		TMP_PDS.COD_POSTAL,
		TMP_PDS.PROVINCIA,
		TMP_PDS.POBLACION, 
		1 AS CANTIDAD,           
		credtmp.VALUE,
		case 
			when CREDTMP.CREDITTYPEID like 'Instalacion%' or CREDTMP.CREDITTYPEID like 'Prestacion%' THEN credtmp.GENERICATTRIBUTE9 
			ELSE '' 
		END AS solicitud_servicio,      -- Solicitud de servicio (solo prestacion e Instalacion)
		credtmp.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidación
		CASE 
			WHEN credtmp.GenericAttribute14 is not null THEN credtmp.GenericAttribute14                              -- Si existe GA14 --> GA14,
			WHEN credtmp.GenericAttribute14 is null  AND TMP_PROD.DESCRIPTION is not null THEN TMP_PROD.DESCRIPTION  -- Si no existe GA14 pero si hay Descrip Producto-->  Descrip Producto
			else credtmp.GenericAttribute1 
		END AS DESC_CONCEPTO_LIQ,                                             -- Si no Se pone el GA1 --> Concepto de Liquidacion
		TMP_CONTRA.COD_CONTRATO,  -- PAra saber si tiene pedido o no
		TXNTMP.EVENTYPEID,
		TXNTMP.PONUMBER as CONTRATO,
		TXNTMP.PRODUCTID, 
		TXNTMP.TAD_POSTALCODE AS COD_POSTAL_DETALLE,
		TXNTMP.TAS_GENERICATTRIBUTE1 AS COD_COMERCIAL,
		EET.MARCA,
		EET.MODELO,
		credtmp.genericattribute15,
		TXNTMP.ALTERNATEORDERNUMBER as CUPS

	FROM ENEL_CREDIT_TEMP_CCDD CREDTMP
		inner JOIN ENEL_TXN_TEMP_CCDD TXNTMP
			ON CREDTMP.SALESTRANSACTIONSEQ = TXNTMP.SALESTRANSACTIONSEQ
			and credtmp.periodseq=txntmp.periodseq

		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
			ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and credtmp.periodseq=tmp_pds.periodseq

		INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2

		LEFT JOIN ENEL_PRODUCTOS_TEMP_CCDD TMP_PROD
			ON TMP_PROD.PRODUCTID=CREDTMP.GENERICATTRIBUTE1

		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_CCDD TMP_CONTRA
			ON  TMP_CONTRA.PDS = TMP_PDS.PDS
			AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENEL_EQUIPAMIENTO_TEMP_CCDD EET
			ON  TXNTMP.GENERICATTRIBUTE8 = EET.IDMARCA
			AND TXNTMP.GENERICATTRIBUTE9 = EET.IDMODELO                    

		WHERE  
			(TXNTMP.EVENTYPEID='Captacion CCDD'
			OR TXNTMP.EVENTYPEID like 'Ajuste Manual - Captacion CCDD')
			--and credtmp.GenericAttribute1 not like '%BONI.KPI.%'
			and CREDTMP.GENERICATTRIBUTE1 is not null  
			and CREDTMP.GENERICATTRIBUTE2 is not null AND CREDTMP.GENERICATTRIBUTE2 <> '000' 
			and CREDTMP.GENERICBOOLEAN1 = 1
			and credtmp.periodo=iperiod
	; 

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_PREFACT_DETALLE_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros de INCENTIVOS en tabla ENEL_PREFACT_DETALLE_CCDD.' ,  v_contador_debug);
   
	INSERT INTO ENELEXT.ENEL_PREFACT_DETALLE_CCDD ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, 
											DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E, DELEGACION, ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, 
											CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE,
											COD_COMERCIAL, MARCA, MODELO ) 
	SELECT 
		INCETMP.PERIODO, 
		INCETMP.PERIODSEQ,
		v_txtMes_Liquidacion as Mes_Liquidacion,
		INCETMP.INCENTIVESEQ,
		INCETMP.NAME ,
		TMP_PDS.PAYEESEQ,
		TMP_PDS.RULEELEMENTOWNERSEQ ,  -- POSITIONSEQ
		TMP_PDS.PDS, 
		TMP_PDS.NOMBRE_FISCAL,
		TMP_PDS.CIF,
		TMP_PROV.IDPROVEEDOR, 
		TMP_PROV.DESCRIPCION,
		TMP_PROV.FICHERO,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,
		TMP_PDS.PAR_PROVEEDOR as CODIGOE4E,
		TMP_PDS.DELEGACION,
		TMP_PDS.ZONA,
		TMP_PDS.TERRITORIO,
		TMP_PDS.CALLE,
		TMP_PDS.COD_POSTAL,
		TMP_PDS.PROVINCIA,
		TMP_PDS.POBLACION, 
		1 AS CANTIDAD,           
		INCETMP.VALUE,
		'' solicitud_servicio,      -- Solicitud de servicio
		INCETMP.GenericAttribute1 as CONCEPTO_LIQ,    --Concepto liquidación
		INCETMP.GenericAttribute3 AS DESC_CONCEPTO_LIQ,  -- Siempre debe venir informado
		TMP_CONTRA.COD_CONTRATO,
		'' EVENTYPEID,
		''  CONTRATO,
		'' PRODUCTID, 
		'' COD_POSTAL_DETALLE,
		'' COD_COMERCIAL,
		'' MARCA,
		'' MODELO
	FROM ENEL_INCEN_TEMP_CCDD INCETMP
		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
			ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

		INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE2

		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_CCDD TMP_CONTRA
			ON  TMP_CONTRA.PDS = TMP_PDS.PDS
			AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq   

	WHERE --INCETMP.NAME like 'I - Captacion - %' AND    v2.2 se elmina esta condición
		NOT( INCETMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- v2.2 se filtra que no sea proveedor 050 y OCAP 
		and INCETMP.GENERICATTRIBUTE1 is not null 
		and INCETMP.GENERICATTRIBUTE2 is not null AND INCETMP.GENERICATTRIBUTE2 <> '000' 
		and INCETMP.value <> 0
		and (UPPER(INCETMP.GENERICATTRIBUTE16) NOT LIKE 'DASHBOARDS'
		or INCETMP.GENERICATTRIBUTE16 is null)
		--and UPPER(INCETMP.GenericAttribute1) not like '%BON%'
	;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_PREFACT_DETALLE_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PREFACT_DETALLE_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PREFACT_DETALLE_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_Detalle', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_Detalle', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Inf_Factura_Portada ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaActual date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_PREFACT_PORTADA_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_PREFACT_PORTADA_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_PREFACT_PORTADA_CCDD.', v_contador_debug);
    v_fechaActual := sysdate;    
    w_debug('Insertando Registros de CREDITOS en tabla ENEL_FACTPDS_PORTADA.' ,  v_contador_debug);
   
	INSERT INTO ENELEXT.ENEL_PREFACT_PORTADA_CCDD ( PERIODO, PERIODSEQ, NUMERO_RESUMEN, MES_LIQUIDACION, FECHA_LIQUIDACION, PAYEESEQ, POSITIONSEQ, CIF, CODIGOE4E,  
                                                ZONA, PDS, NOMBRE_FISCAL, CALLE, COD_POSTAL, POBLACION, PROVINCIA, IDPROVEEDOR, FICHERO, DESCRIPCION, 
                                                CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, COD_CONTRATO, ACTIVIDAD, DETALLE_ACTIVIDAD, PRECIO_UNITARIO, CANTIDAD, IMPORTE_TOTAL )  
	SELECT 
		FAPDET.PERIODO,
		FAPDET.PERIODSEQ,
		substr(FAPDET.MES_LIQUIDACION,1,4) || '/'||  FAPDET.PDS as NUMERO_RESUMEN ,  -- YYYY/PDS
		FAPDET.MES_LIQUIDACION,
		v_fechaActual as FECHA_LIQUIDACION,
		FAPDET.PAYEESEQ,
		FAPDET.POSITIONSEQ,
		FAPDET.CIF,
		FAPDET.CODIGOE4E,
		FAPDET.DELEGACION AS ZONA,
		FAPDET.PDS,
		FAPDET.NOMBRE_FISCAL,
		FAPDET.CALLE,
		FAPDET.COD_POSTAL,
		FAPDET.POBLACION,
		FAPDET.PROVINCIA,
		FAPDET.IDPROVEEDOR,
		FAPDET.FICHERO,
		FAPDET.DESCRIPCION,
		FAPDET.CONCEPTO_LIQ,
		FAPDET.DESC_CONCEPTO_LIQ,
		FAPDET.COD_CONTRATO,
		FAPDET.ACTIVIDAD,
		FAPDET.DETALLE_ACTIVIDAD,
		FAPDET.VALUE as PRECIO_UNITARIO,
		sum(FAPDET.CANTIDAD),
		sum(FAPDET.CANTIDAD * FAPDET.VALUE) AS IMPORTE_TOTAL

	FROM ENEL_PREFACT_DETALLE_CCDD fapDet
	WHERE FAPDET.PERIODSEQ = iperiodseq
	GROUP BY
		FAPDET.PERIODO,
		FAPDET.PERIODSEQ,
		substr(FAPDET.MES_LIQUIDACION,1,4) || '/'||  FAPDET.PDS,
		FAPDET.MES_LIQUIDACION,
		v_fechaActual,
		FAPDET.PAYEESEQ,
		FAPDET.POSITIONSEQ,
		FAPDET.CIF,
		FAPDET.CODIGOE4E,
		FAPDET.DELEGACION,
		FAPDET.PDS,
		FAPDET.NOMBRE_FISCAL,
		FAPDET.CALLE,
		FAPDET.COD_POSTAL,
		FAPDET.POBLACION,
		FAPDET.PROVINCIA,
		FAPDET.IDPROVEEDOR,
		FAPDET.FICHERO,
		FAPDET.DESCRIPCION,
		FAPDET.CONCEPTO_LIQ,
		FAPDET.DESC_CONCEPTO_LIQ,
		FAPDET.COD_CONTRATO,
		FAPDET.ACTIVIDAD,
		FAPDET.DETALLE_ACTIVIDAD,
		FAPDET.VALUE

	ORDER BY PDS
	;   
      
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PREFACT_PORTADA_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PREFACT_PORTADA_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PREFACT_PORTADA_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_Portada', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_Portada', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

-- cuadre de liquidación
    procedure p_Informe_CUADRE_LIQ ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
	v_ini_anual date;
	v_ini_trimestral date;
	v_ini_bimensual date;
	v_fin date;
begin

    v_finicio := current_timestamp();

	v_ini_anual :=  f_fecha_inicio_anual(iperiodseq);
	v_ini_trimestral :=  f_fecha_inicio_trimestral(iperiodseq);
	v_fin := f_Ultimo_Dia_Periodo(iperiodseq);
	v_ini_bimensual :=  f_fecha_inicio_bimensual(iperiodseq);
	
    w_debug('Inicio Borrado de la tabla ENEL_CUADRELIQ_CCDD.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CUADRELIQ_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_LEADS_WBE_CCDD WHERE PERIODO_liquidacion = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_CUADRELIQ_CCDD_SLA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_CUADRELIQ_CCDD_RAPPEL WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE WHERE PERIODO = iperiod and PROCESSINGUNITSEQ = iprocessingunitseq AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_REGULARIZACION_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_CCC_CCDD WHERE PERIODO = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_RENOVACION_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_TDM_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        /*BOM APM 03.06.2025*/
        LOOP
            DELETE FROM ENELEXT.ENEL_CUADRELIQ_CCDD_RESELLERS WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_TDM2_CCDD WHERE PERIODO_BIMENSUAL = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        /*EOM APM 03.06.2025*/
    END;
    
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST_CCDD') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_CUADRELIQ_CCDD.', v_contador_debug);
    w_debug('Insertando Registros de datos en tabla ENEL_CUADRELIQ_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CUADRELIQ_CCDD (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, CUPS, TIPO_VENTA, TIPO_CONTRATACION, ID_PRODUCTO, DESCRIPCION, LINEA_NEGOCIO, 
                                            NUM_PROVEEDOR, COD_PLATAF, FECHA_FIRMA, PEDIDO_CRM, WBE, NIF_PLATAF, NIF_CLIENTE, RAZON_SOCIAL, AGENTE_COMERCIAL, CANAL,
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, 
                                            CREDITTYPEID, nom_credito,PRODUCTO, ESTADOCONTRATO,
                                            PROVINCIA, APLICACION_INCEN_CP ) --APM 07.03.2024 Evo CPs
	SELECT 
		ETT.PERIODO,
		ETT.ORDERID,
		ETT.LINENUMBER,
		ETT.SUBLINENUMBER,
		ETT.EVENTYPEID,
		--TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        ect.value as IMPORTE,
		'EURO',
        ECT.GENERICATTRIBUTE10 as CUPS,
        /*BOM APM 14.11.2024 Old Code*/
        --ETT.GENERICATTRIBUTE11 as TIPO_VENTA,
        --New Code
        ECT.GENERICATTRIBUTE3 as TIPO_VENTA,
		/*EOM APM 14.11.2024*/
        /*ECT.GENERICATTRIBUTE16 as ID_PRODUCTO, --TXN.GA16 */
        ETT.GENERICATTRIBUTE1  as TIPO_CONTRATACION, --GA1 de la transaccion
        ETT.productid AS ID_PRODUCTO, --Se saca el idproducto de la transaccion (petición Carmen) - MIKE 14.03.2022
        SATXN.PRODUCTNAME AS DESCRIPCION, --Se saca el nombre del producto de la transacción (petición Carmen) - MIKE 14.03.2022        
/* Esta disponible en la tabla de transacciones
        GATXN.GENERICATTRIBUTE13 as LINEA_NEGOCIO, */
        ETT.TEX0_GENERICATTRIBUTE13,
        ECT.GENERICATTRIBUTE16  as NUM_PROVEEDOR,   --GA16 del crédito
        ETT.GENERICATTRIBUTE19 as COD_PLATAF,
        ETT.GENERICDATE3  as FECHA_FIRMA,
        ETT.GENERICATTRIBUTE24 as PEDIDO_CRM,
        ECT.GENERICATTRIBUTE11  as WBE,
        TMP_PDS.CIF, --Participante GA1
        ETT.GENERICATTRIBUTE29 as NIF_CLIENTE,
        ETT.GENERICATTRIBUTE27 as RAZON_SOCIAL,
        --TMP_PDS.COMUNIDAD_AUTONOMA as COD_COMERCIAL, --POSICION.GA2
        txna.genericattribute1 AS AGENTE_COMERCIAL, --Comercial/Agente GA1 de la transacción de la pestaña de Participantes asociados a la transición 14.03.2022 MIKE - Petición Carmen
        ETT.GENERICATTRIBUTE11 as CANAL,
		TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
		'EURO',
		ECT.GENERICATTRIBUTE1 as TIPO_PRODUCTO,    --tipo_producto del informe cuad_liq_ccdd-pestaña detalle contratos (MIKE-11.03.2022)    --ID Producto SCA Web
		ECT.GENERICATTRIBUTE4,    --    Código de PDS/OCAP
		v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
		case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
		TEMP_PROV.DESCRIPCION,
		TEMP_PROV.IDPROVEEDOR,
		ECT.GENERICATTRIBUTE3, --NUMPROVEEDOR --INCIDENCIA
		ECT.CREDITTYPEID,
		ect.name as NOM_CREDITO,
		ECT.GENERICATTRIBUTE1 as PRODUCTO,
        ETT.GENERICATTRIBUTE3,
        /*BOM APM 07.03.2024 Evo CPs*/
        ETT.TAD_STATE AS PROVINCIA,
        TMP_PDS.APLICACION_INCEN_CP AS APLICACION_INCEN_CP
        /*EOM APM 07.03.2024*/        
		
	FROM ENEL_TXN_TEMP_CCDD ETT
		LEFT JOIN ENEL_CREDIT_TEMP_CCDD ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
            AND TEMP_PROV.PERIODSEQ=ECT.PERIODSEQ
            
        INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS     -- Se hace JOIN CON PDS para informar
			ON ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            AND ECT.PERIODSEQ=TMP_PDS.PERIODSEQ
            
        INNER JOIN cs_transactionassignment txna    --Se hace el JOIN para sacar el Campo Agente (GA1) de la transacción de la pestaña de Participantes asociados a la transacción (callidus) 14.03.2022 MIKE - Petición Carmen
            ON ett.salestransactionseq = txna.salestransactionseq
            AND ett.tenantid = txna.tenantid
            AND txna.setnumber = 1    
            
        INNER JOIN CS_SALESTRANSACTION SATXN
            ON ETT.SALESTRANSACTIONSEQ = SATXN.SALESTRANSACTIONSEQ
            AND ETT.TENANTID = SATXN.TENANTID
/* No lo necesitamos, ya esta disponible en la tabla de transacciones
        INNER JOIN CS_GASALESTRANSACTION GATXN
            ON ETT.SALESTRANSACTIONSEQ = GATXN.SALESTRANSACTIONSEQ
            AND ETT.TENANTID = GATXN.TENANTID
*/
		
	WHERE ETT.PROCESSINGUNITSEQ=iprocessingUnitSeq
    AND ETT.PERIODSEQ=IPERIODSEQ --Diego 28/10/2022 salen datos en el informe que no deberian
	;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CUADRELIQ_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CUADRELIQ_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CUADRELIQ_CCDD.',v_contador_debug);
    
    
    INSERT INTO ENELEXT.ENEL_LEADS_CCDD (PERIODO , ORDERID , LINENUMBER , SUBLINENUMBER , EVENTTYPEID , ESTADOCONTRATO ,
                                                IMPORTE , UNIDAD , PRODUCTO_SCAWEB , CODIGO_PDS_OCAP , 
                                                 ESTADO , IDPROVEEDOR ,NUMPROVEEDOR , nom_credito ,WO_VISITA,Venta_Relacionada )
                                                 
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        ETT.GENERICATTRIBUTE3,
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        TMP_PDS.PDS,
        case when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
        when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and ect.value is not null then 'Liquidado'
        else 'Pte Liquidar'
        end,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ect.name,
        ETT.GENERICATTRIBUTE4 AS WO_VISITA,
        ETT.GENERICATTRIBUTE24 AS Venta_Relacionada
    FROM ENEL_TXN_TEMP_CCDD ETT
		LEFT JOIN ENEL_CREDIT_TEMP_CCDD ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			
		LEFT JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq
            
        where ETT.EVENTYPEID like '%Lead%'


	;

	filas := sql%rowcount;
    COMMIT;
    
    
    -- Carga pestaña Rappeles / Detalle --
    w_debug('Insertando Registros de datos en tabla ENEL_CUADRELIQ_CCDD_RAPPEL.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CUADRELIQ_CCDD_RAPPEL (PERIODO, OI_SOLICITUD, LINE, SUBLINE, TIPO_EVENTO, NOMBRE, IMPORTE_COMISION,
                                                    PORC_APLICAR, IMPORTE, UNIDADES, CUPS, TIPO_VENTA, TIPO_RAPPEL, PRODUCTO,
                                                    PROVEEDOR, NUM_PROVEEDOR, ESTADO_CALIDAD, INCIDENCIA, COD_PLATAF, NIF_PLATAF,
                                                    COD_COMERCIAL, ESTADO, FECHA_FIRMA, FECHA_ALTA, PEDIDO_CRM, NUM_PEDIDO, PDS,
                                                    ORIGEN, CANAL) 
	SELECT
        iperiod,
        ett.orderid AS oi_solicitud,
        ett.linenumber AS line,
        ett.sublinenumber AS subline,
        ett.eventypeid AS tipo_evento,
        inc.name AS nombre, --inc.name AS nombre,
        inc.genericnumber5 AS importe_comision,
        inc.genericnumber4 AS porc_aplicar,
        commi.value AS importe,
        'EURO' AS unidades,
        cred.genericattribute10 AS cups,
        ett.genericattribute11 AS tipo_venta,
        inc.genericattribute3 AS tipo_rappel,
        cred.genericattribute8 AS producto,
        --temp_prov.idproveedor AS proveedor,
        cred.genericattribute16 AS proveedor, --Se pide(Carmen) que el proveedor salga del crédito GA16 14.03.2022 - MIKE
        cred.genericattribute2 AS num_proveedor,
        ett.genericattribute3 AS estado_control,
        ett.genericattribute20 AS incidencia,
        ett.genericattribute19 AS cod_plataf,
        par.genericattribute1 as nif_plata, --'NIF PLATAFORMA', --TEMP_PROV.GA1, Participante GA1
        inc.genericattribute1 AS codigo_comercial, --'CODIGO COMERCIAL' AS cod_comercial, --POSICION.GA2
        CASE
                WHEN cred.value IS NULL
                     --OR temp_prov.idproveedor IS NULL THEN 'Pte Revisar'
                     OR cred.genericattribute16 IS NULL THEN 'Pte Revisar' --Se pide(Carmen) que el proveedor salga del crédito GA16 14.03.2022 - MIKE
                when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and cred.value is not null then 'Liquidado'
                ELSE 'Pte Liquidar'
            END
        AS estado,
        ett.genericdate3 AS fecha_firma,
        ett.genericdate3 AS fecha_alta,
        ett.genericattribute24 AS pedido_crm,
        'NM_PEDIDO_VISIÓN_CLI' AS num_pedido,
        'CD_PDS_TASK_FORCE' AS pds,
        'ORIGEN_ATC' AS origen,
        ett.genericattribute11 AS canal
    FROM
        cs_commission commi
        INNER JOIN cs_incentive inc ON commi.incentiveseq = inc.incentiveseq
                                       AND commi.payeeseq = inc.payeeseq
                                       AND commi.tenantid = inc.tenantid
                                       --AND commi.periodseq=inc.periodseq --Diego 28/10/2022 En el informe aparecen datos cuando no deberian
        INNER JOIN cs_credit cred ON commi.creditseq = cred.creditseq
                                     AND cred.payeeseq = commi.payeeseq
                                     AND cred.processingunitseq = commi.processingunitseq
                                     AND cred.tenantid = commi.tenantid
                                     AND cred.periodseq = commi.periodseq
        INNER JOIN enel_txn_temp_ccdd ett ON ett.salestransactionseq = cred.salestransactionseq
        
        inner join cs_period per on per.periodseq=iperiodseq
         AND PER.PERIODSEQ=INC.PERIODSEQ
            AND PER.REMOVEDATE=v_eot
        
        inner join cs_participant par on par.payeeseq=inc.payeeseq
            AND par.TENANTID = itenantId
			AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
        --INNER JOIN enel_proveedores_temp_ccdd temp_prov ON temp_prov.idproveedor = cred.genericattribute2 --Se pide(Carmen) que el proveedor salga del crédito GA16 14.03.2022 - MIKE
		/*INNER JOIN cs_transactionassignment txna ON txna.salesorderseq = cred.salesorderseq
                                                AND txna.salestransactionseq = cred.salestransactionseq*/
                                                
	WHERE ETT.PROCESSINGUNITSEQ = iprocessingUnitSeq
        AND ( inc.name LIKE ( 'C - Captacion CCDD%' ) OR  inc.name LIKE ( 'I - Captacion CCDD%Rap%' )) --Se añade el filtro de Rappel para el informe Cuadre Liquidación
        AND inc.tenantid = 'ENEL'
        AND commi.processingunitseq = iprocessingUnitSeq
        AND inc.periodseq=iperiodseq /*Diego Montañez 27/10/22 No filtraba por periodo y se añade esta linea */
        and inc.name NOT LIKE '%Dashboard%';/*Diego Montañez 11/11/22 Carga demasiados datos en tabla */
        --AND txna.genericattribute1 IS NOT NULL;
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CUADRELIQ_CCDD_RAPPEL: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CUADRELIQ_CCDD_RAPPEL',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CUADRELIQ_CCDD_RAPPEL.',v_contador_debug);
    
    -- Carga pestaña SLAs --
    w_debug('Insertando Registros de datos en tabla ENEL_CUADRELIQ_CCDD_SLA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CUADRELIQ_CCDD_SLA (PERIODO, NOMBRE, TIPO_VENTA, TIPO_SLA, IMPORTE_COMISION, CONSECUCION, PORC_APLICAR,
                                                IMPORTE, COD_PLATAF) 
	SELECT 
        iperiod AS periodo,
        inc.name AS nombre,
        inc.genericattribute6  AS tipo_regla,
        inc.genericattribute3  AS tipo_sla,
        /*BOM APM 18.07.2023*/
        --Old Code
        /*CAST(inc.genericnumber5 AS NUMBER(20,15))     AS importe_comision,
        CAST(inc.genericnumber3 AS NUMBER(20,15))     AS consecucion,
        CAST(inc.genericnumber4 AS NUMBER(20,15))     AS porc_aplicar,
        CAST(inc.value AS NUMBER(20,15))              AS importe,
        CAST(ett.genericattribute19 AS VARCHAR2(20)) AS cod_plataf*/
        --New Code
        inc.genericnumber5 AS importe_comision,
        inc.genericnumber3 AS consecucion,
        inc.genericnumber4 AS porc_aplicar,
        inc.value  AS importe,
        pos.name AS cod_plataf
        /*EOM APM 18.07.2023*/
        
        
    /*FROM
    cs_commission commi
    INNER JOIN cs_incentive inc ON commi.incentiveseq = inc.incentiveseq
                                   AND commi.payeeseq = inc.payeeseq
                                   AND commi.tenantid = inc.tenantid
    INNER JOIN cs_credit cred ON commi.creditseq = cred.creditseq
                                 AND cred.payeeseq = commi.payeeseq
                                 AND cred.processingunitseq = commi.processingunitseq
                                 AND cred.tenantid = commi.tenantid
                                 AND cred.periodseq = commi.periodseq
    INNER JOIN enel_txn_temp_ccdd ett ON ett.salestransactionseq = cred.salestransactionseq
    LEFT JOIN enel_proveedores_temp_ccdd temp_prov ON temp_prov.idproveedor = cred.genericattribute2
		
	WHERE ETT.PROCESSINGUNITSEQ=iprocessingUnitSeq
    AND( inc.name = 'I - Captacion CCDD%Calidad de la Venta%'
        OR inc.name = 'I - Captacion CCDD%TM3%'
        OR inc.name = 'I - Captacion CCDD%Respuesta%'
        OR inc.name = 'I - Captacion CCDD%Productividad Minima%'
        OR inc.name = 'I - Captacion CCDD%Productividad Objetivo%'
        OR inc.name = 'I - Captacion CCDD%Tasa de Activacion%'
        OR inc.name = 'I - Captacion CCDD%Tasa de Conversion Minima%'
        OR inc.name = 'I - Captacion CCDD%Tasa de Ofrecimiento%'
        OR inc.name = 'I - Captacion CCDD%Dualizacion%')*/
        FROM cs_incentive inc
    left join CS_PERIOD PER
            ON PER.PERIODSEQ=IPERIODSEQ
            AND PER.PERIODSEQ=INC.PERIODSEQ
            AND PER.REMOVEDATE=v_eot

		left JOIN cs_position pos 
			ON pos.payeeseq=inc.payeeseq
            and  pos.REMOVEDATE = v_eot
			AND pos.TENANTID = itenantId 
			AND pos.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND pos.EFFECTIVEENDDATE >= PER.ENDDATE - 1
			and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq
            AND POS.RULEELEMENTOWNERSEQ=INC.POSITIONSEQ
WHERE
    inc.processingunitseq = 38280596832650118
    AND inc.name LIKE ( 'I - Captacion CCDD%' )
    AND inc.GENERICATTRIBUTE1 LIKE '%SLA%'
    AND inc.periodseq=iperiodseq; /*Diego Montañez 27/10/22 No filtraba por periodo y se añade esta linea */
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CUADRELIQ_CCDD_SLA: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CUADRELIQ_CCDD_SLA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CUADRELIQ_CCDD_SLA.',v_contador_debug);
	
    -- Carga pestaña Renovación --
	w_debug('Insertando Registros de datos en tabla ENEL_RENOVACION_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_RENOVACION_CCDD (PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
												CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
												CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, FECHA_ALTA )
    SELECT 
        iperiod,
		iperiodseq,
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
        case 
			when CRED.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and CRED.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
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
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		CRED.PAYEESEQ, 
		CRED.POSITIONSEQ,
		TXN.GENERICDATE4 FECHA_ALTA
		
    FROM CS_COMMISSION COMMI
		INNER JOIN CS_INCENTIVE INC
			on commi.incentiveseq = inc.incentiveseq
			and commi.payeeseq = inc.payeeseq
			and commi.tenantId = inc.tenantId
		
		INNER JOIN cs_credit CRED
			on commi.creditseq = cred.creditseq
			and cred.payeeseq = commi.payeeseq
			and cred.processingUnitseq = commi.processingUnitSeq
			and cred.tenantId = commi.tenantId
			and cred.periodSeq = commi.periodSeq
		
		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=CRED.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = CRED.tenantId
			

		INNER JOIN CS_SALESTRANSACTION txn
			ON CRED.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = cred.processingUnitSeq
			AND txn.compensationdate BETWEEN v_ini_anual AND v_fin
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

	where inc.name like ('C - Renovacion CCDD%')
	and inc.tenantId = itenantId
	and commi.processingUnitSeq = iprocessingUnitSeq
    ;
               
    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_RENOVACION_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_RENOVACION_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	
	-- Carga pestaña Regularización --
	w_debug('Insertando Registros de datos en tabla ENEL_REGULARIZACION_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_REGULARIZACION_CCDD (PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
												CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
												CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ)
    SELECT 
        iperiod,
		iperiodseq,
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
        case 
			when CRED.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and CRED.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
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
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		CRED.PAYEESEQ, 
		CRED.POSITIONSEQ,
		CRED.COMPENSATIONDATE
		
    FROM CS_COMMISSION COMMI
		INNER JOIN CS_INCENTIVE INC
			on commi.incentiveseq = inc.incentiveseq
			and commi.payeeseq = inc.payeeseq
			and commi.tenantId = inc.tenantId
			
		INNER JOIN cs_credit CRED
			on commi.creditseq = cred.creditseq
			and cred.payeeseq = commi.payeeseq
			and cred.processingUnitseq = commi.processingUnitSeq
			and cred.tenantId = commi.tenantId
			and cred.periodSeq = commi.periodSeq
			
		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=CRED.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = CRED.tenantId

		INNER JOIN CS_SALESTRANSACTION txn
			ON CRED.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = cred.processingUnitSeq
			AND txn.compensationdate BETWEEN v_ini_trimestral AND v_fin
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

	where inc.name like ('C - Captacion CCDD - Reg Trim%') 
	and inc.tenantId = itenantId
	and commi.processingUnitSeq = iprocessingUnitSeq
    ;
               
    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_REGULARIZACION_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_REGULARIZACION_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	
	-- Carga pestaña CCC --
	w_debug('Insertando Registros de datos en tabla ENEL_CCC_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CCC_CCDD (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM)
    SELECT 
        iperiod,
		ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        ECT.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        ETT.GENERICATTRIBUTE3,
		INC.name,
		ECT.GENERICATTRIBUTE8,
		--MPR - nuevos campos
		ETT.ALTERNATEORDERNUMBER, --CUPS
		ETT.GENERICDATE3, --fecha de firma
		ETT.GENERICATTRIBUTE24 -- pedido_CRM
		
    FROM ENEL_TXN_TEMP_CCDD ETT
		INNER JOIN ENEL_CREDIT_TEMP_CCDD ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2

		INNER JOIN CS_COMMISSION COMMI
			ON COMMI.CREDITSEQ = ECT.CREDITSEQ
            AND COMMI.PAYEESEQ = ECT.PAYEESEQ
        
		INNER JOIN CS_INCENTIVE INC
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ

	WHERE INC.NAME LIKE ('C - Captacion CCDD - CCC%') 
	AND INC.TENANTID = ITENANTID
	AND COMMI.PROCESSINGUNITSEQ = IPROCESSINGUNITSEQ
	AND COMMI.PERIODSEQ = iperiodseq
    ;

    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_CCC_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CCC_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
	
	-- Carga pestaña Detalle TdM --
	w_debug('Insertando Registros de datos en tabla ENEL_TDM_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_TDM_CCDD (PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION )
    SELECT 
		iperiod,
		iperiodseq,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        ECT.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		INC.name,
		ECT.GENERICATTRIBUTE8,
		--MPR - nuevos campos
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		ECT.PAYEESEQ, 
		ECT.POSITIONSEQ,
		ECT.COMPENSATIONDATE,
		INC.GENERICNUMBER1 as ALTAS, 
		INC.GENERICNUMBER2 as BAJAS,
		INC.GENERICNUMBER3 as PORC_TDM, 
		INC.GENERICNUMBER5 as IMPORTE_COMISION 
		
    FROM CS_COMMISSION COMMI
		INNER JOIN ENEL_INCEN_TEMP_CCDD INC
			on commi.incentiveseq = inc.incentiveseq
			and commi.payeeseq = inc.payeeseq
			and commi.tenantId = inc.tenantId
            and inc.periodseq=iperiodseq

			
		INNER JOIN cs_credit ECT
			on commi.creditseq = ECT.creditseq
			and ECT.payeeseq = commi.payeeseq
			and ECT.processingUnitseq = commi.processingUnitSeq
			and ECT.tenantId = commi.tenantId
			and ECT.periodSeq = commi.periodSeq
			
		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = ECT.tenantId


		INNER JOIN CS_SALESTRANSACTION txn
			ON ECT.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = ECT.processingUnitSeq
			AND txn.compensationdate =ect.compensationdate
            AND txn.tenantid = ECT.tenantId
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

	WHERE INC.NAME LIKE 'C - Captacion CCDD - TdM%'
    and commi.periodseq=iperiodseq
    and commi.processingunitseq=iprocessingUnitSeq
    ;

    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_TDM_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TDM_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    
    w_debug('Insertando Registros de datos en tabla ENEL_TDM2_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_TDM2_CCDD (PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION, 
                                        FILTRO_PRD, FECHA_ALTA, FECHA_BAJA , PERIODO_BIMENSUAL --RMM - CAL0206 - 12.09.2022 
                                        ,NUM_DIAS, MOTIVO_BAJA, GENERICATTRIBUTE20 --APM 29.03.2023
                                        )
    SELECT per.name,
		per.periodseq,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        '1' AS IMPORTE_COMISION,--COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        /*BOM APM 31.07.2025*/
        /*case when commi.value is not null then commi.value
            else ect.value 
        end as VALOR_1,*/
        case when commi.value is not null and ince.GENERICATTRIBUTE4 like 'Importe Base Incremental' then to_char(commi.value , '9999999999990D99') 
            else to_char(ect.value , '9999999999990D99')   end as VALOR_1,
        /*EOM APM 31.07.2025*/
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        ECT.GENERICATTRIBUTE3,
        '' as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		'NAME',--INC.name,
		ECT.GENERICATTRIBUTE8,
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		ECT.PAYEESEQ, 
		ECT.POSITIONSEQ,
		ECT.COMPENSATIONDATE,
        '1' AS ALTAS,
        '1' AS BAJAS,
        '1' AS PORC_TDM,
        '1' AS IMPORTE_COMISION,   
        TXN.GENERICBOOLEAN2 as FILTRO_PRD, --Filtro para los productos que cumplem TdM
        TXN.GENERICDATE4 as FECHA_ALTA,
        TXN.GENERICDATE5 as FECHA_BAJA,
         iperiod AS PERIODO_BIMENSUAL,        
         to_date(TXN.GENERICDATE5) - to_date(TXN.GENERICDATE4) as NUM_DIAS,
         etxn0.GENERICATTRIBUTE3 as MOTIVO_BAJA,
         txn.GENERICATTRIBUTE20 --APM 17.07.2025

    FROM cs_credit ECT
		INNER JOIN CS_PERIOD PER
           ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-2)
         and per.periodseq = ect.periodseq
        and removedate= '01/01/2200' 	

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = ECT.tenantId

		INNER JOIN CS_SALESTRANSACTION txn
			ON ECT.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = ECT.processingUnitSeq
            AND txn.compensationdate BETWEEN per.startdate AND per.enddate          
            AND txn.tenantid = ECT.tenantId
            AND txn.modelseq = 0	
          
        LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
            
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = ECT.CREDITSEQ
            AND COMMI.PAYEESEQ = ECT.PAYEESEQ
            AND COMMI.PERIODSEQ= ECT.PERIODSEQ
         
		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
         
        INNER JOIN cs_position pos
            ON pos.payeeseq = ect.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = ect.tenantid
            and POS.PROCESSINGUNITSEQ =  ECT.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate              
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = '01/01/2200'
			AND txn.tenantid = etype.tenantid
        
         /* BOM APM 31.07.2025 */
        LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ 
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq
            /* EOM APM 31.07.2025 */ 

      WHERE ECT.NAME LIKE 'CD - Captacion Resellers - Comision Base'
        and (TEMP_PROV.IDPROVEEDOR = '011' 
            or  TEMP_PROV.IDPROVEEDOR = '012')          
        and ECT.GENERICBOOLEAN1 = 1
        and ECT.GENERICATTRIBUTE1 is not null
        and ETYPE.eventtypeid = 'Captacion Resellers'
    ;

    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_TDM2_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
	
	-- Carga fichero de WBE --
	w_debug('Insertando Registros de datos en tabla ENEL_LIQSCAWEB_FINAL_WBE.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE (PERIODO, ORDERID, subcanal, wbe, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
												CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO,PROCESSINGUNITSEQ,
												ESTADOCONTRATO) 
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        TMP_PDS.subcanal,
        ECT.GENERICATTRIBUTE11 wbe,
        ETT.EVENTYPEID,
        TRIM(replace(to_char(ECT.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Código de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
            when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
            when iInterfaz ='ACTUALIZA_INFORMES_POST_CCDD' and ect.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ect.name,
        ETT.PRODUCTID,
		iprocessingunitseq,
		ETT.GENERICATTRIBUTE3
                
    FROM ENEL_TXN_TEMP_CCDD ETT
        LEFT JOIN ENEL_CREDIT_TEMP_CCDD ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
    
        LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
    
        LEFT JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq
    
    WHERE ETT.PROCESSINGUNITSEQ=iprocessingunitseq
		and ECT.GENERICATTRIBUTE11 is not null
    ;
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_FINAL_WBE: '|| to_char(filas) || ' filas.', v_contador_debug);

 INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_LEADS_WBE_CCDD(Periodo_Liquidacion ,Canal_Unidad_Negocio, WBE,	Nombre_Deposito,	
                                                            Importe,Proveedor, Codigo_Comercial )
    SELECT
     DEP.PERIODO AS PERIODO_LIQUIDACION,
    pos.genericattribute6 AS Canal_Unidad_Negocio,
    dep.wbe AS WBE,
    dep.name AS Nombre_DepOsito,
    dep.value AS Importe,
    DEP.EARNINGCODEID AS Proveedor,
    POS.NAME AS COdigo_Comercial
    
    from enel_deposit_temp_CCDD dep
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
    

/*BOM APM 03.06.2025*/

    w_debug('Insertando Registros de datos en tabla ENEL_CUADRELIQ_CCDD_RESELLERS.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CUADRELIQ_CCDD_RESELLERS (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, ESTADOCONTRATO, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, 
                                            NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO, RESPONSABLE, NUM_DIAS, RETROCESION,
                                            FECHA_RETROCESION, CODIGO_POSICION, FECHA_ALTA, FECHA_BAJA, MOTIVO_BAJA,
                                            PROVINCIA, APLICACION_INCEN_CP, CUPS, TARIFA,COSTE,WO_VISITA, VENTA_RELACIONADA,
                                            INCENTIVO_OFERTA, TIENDA, GENERICATTRIBUTE20, TIPOLOGIA, OBSERVACIONES)
	SELECT 
		ETT.PERIODO,
		ETT.ORDERID,
		ETT.LINENUMBER,
		ETT.SUBLINENUMBER,
		ETT.EVENTYPEID,
		ETT.GENERICATTRIBUTE3,
		case when commi.value is not null then commi.VALUE else ECT.value end as IMPORTE_COMISION,
		'EURO',
         /* BOM APM 18.07.2025 Old Code*/
		--TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        ECT.value as VALOR_1,
        /* EOM APM 18.07.2025 */ 
		'EURO',
		ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
		TMP_PDS.PDS,
		v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
		case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
		TEMP_PROV.DESCRIPCION,
		TEMP_PROV.IDPROVEEDOR,
		ECT.GENERICATTRIBUTE3,
		ECT.CREDITTYPEID,
		case when commi.value is not null then ince.name else ECT.name end,
		ECT.GENERICATTRIBUTE8,
		TMP_PDS.RESPONSABLE,
		ECT.GENERICNUMBER3, --NUMERO DE DÍAS
		ECT.GENERICNUMBER4, --PORCENTAJE RETROCESIÓN
		ECT.GENERICDATE1,
		ECT.GENERICATTRIBUTE4,    -- Código Posción
        ETT.GENERICDATE6 as FECHA_ALTA,      --Fecha Alta (GD4 transaccion)
        ETT.GENERICDATE5       as FECHA_BAJA,      --Fecha Baja (GD5 transaccion)
        TEX0_GENERICATTRIBUTE3 as MOTIVO_BAJA,      --Motivo Baja (EA3 transaccion)
        ETT.TAD_STATE AS PROVINCIA,
        TMP_PDS.APLICACION_INCEN_CP AS APLICACION_INCEN_CP,
        ETT.ALTERNATEORDERNUMBER AS CUPS,
        ETT.PRODUCTNAME AS TARIFA,
        TRIM(replace(to_char(ETT.COSTE , '9999999999990D99'), ',', '.')) AS COSTE,
        ETT.GENERICATTRIBUTE4 AS WO_VISITA,
        ETT.GENERICATTRIBUTE24 AS VENTA_RELACIONADA, 
        ECT.GENERICATTRIBUTE13 AS INCENTIVO_OFERTA, 
		null, --ETT.GENERICATTRIBUTE25 AS TIENDA 
        ETT.GENERICATTRIBUTE20, --APM 17.07.2025
        ETT.GENERICATTRIBUTE9 AS TIPOLOGIA, --APM 17.07.2025
        ECT.GENERICATTRIBUTE15 AS OBSERVACIONES --APM 17.07.2025
        
	FROM ENEL_TXN_TEMP_CCDD ETT
		LEFT JOIN ENEL_CREDIT_TEMP_CCDD ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_CCDD TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			
		LEFT JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq
			and ( tmp_pds.title_name not like 'RETAIL TF RESP' )
        
        LEFT JOIN CS_COMMISSION COMMI
            ON COMMI.CREDITSEQ = ECT.CREDITSEQ
            AND COMMI.PAYEESEQ = ECT.PAYEESEQ
            AND COMMI.PERIODSEQ= ECT.PERIODSEQ

        LEFT JOIN CS_INCENTIVE INCE 
			ON INCE.INCENTIVESEQ = COMMI.INCENTIVESEQ 
            AND ince.payeeseq = commi.payeeseq
            AND ince.positionseq = commi.positionseq
            AND ince.periodseq = commi.periodseq
            AND ince.pipelinerunseq = commi.pipelinerunseq
        
		
	WHERE ETT.PROCESSINGUNITSEQ=38280596832650118 --CCDD
	;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CUADRELIQ_CCDD_RESELLERS: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CUADRELIQ_CCDD_RESELLERS',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CUADRELIQ_CCDD_RESELLERS.',v_contador_debug);
/*EOM APM 03.06.2025*/

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Informe_CUADRE_LIQ', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Informe_CUADRE_LIQ', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;      

procedure p_Comp_Pagos_SCAWEB_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_COMP_SCAWEB_E4E_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_COMP_SCAWEB_E4E_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_SCAWEB_E4E_CCDD.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_SCAWEB_E4E_CCDD.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_CCDD ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES )   
	SELECT 
        T_SCAWEB.PERIODO,
        T_SCAWEB.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_SCAWEB.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        IMPORTE_SCAWEB,
        case when T_E4E.POSITIVO_CON_CONTRATO is null then 0 else T_E4E.POSITIVO_CON_CONTRATO end as Con_Contrato,
        case when T_E4E.POSITIVO_SIN_CONTRATO is null then 0 else T_E4E.POSITIVO_SIN_CONTRATO end as Sin_Contrato,

		case when E4ENT.NEGATIVO is null then 0 else E4ENT.NEGATIVO end as Negativo,
        case when T_E4E.OPERACIONES is null then 0 else T_E4E.OPERACIONES end as Operaciones
	FROM
		(select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
			from ENEL_SCAWEB_LIQUIDACION_CCDD sca 
			where PERIODO = iperiod
            group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO 
		) T_SCAWEB
      
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
                sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
                SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
                SUM(VALOR_OPERACIONES) AS OPERACIONES
            from ENEL_E4E_DEPOSIT_CCDD_TEMP 
			where periodseq=iperiodseq
            group by TRIM(IDPROVEEDOR), PDS
			) T_E4E
           ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
           AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
			from ENEL_E4E_NEGATIVOS_TEMP_CCDD 
			where periodseq=iperiodseq
			group by TRIM(IDPROVEEDOR), PDS
			)E4ENT
			ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.PDS)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)
                        
		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
			ON T_SCAWEB.PDS=TMP_PDS.PDS
			and (TMP_PDS.SUBCANAL='CCDD'
            or TMP_PDS.SUBCANAL='RESELLERS') --APM 16.07.2025

		INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR)
	;      
           
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E_CCDD.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_CCDD ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES )
	SELECT 
		T_E4E.PERIODO,
        T_E4E.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_E4E.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        IMPORTE_SCAWEB,
        T_E4E.POSITIVO_CON_CONTRATO,
        T_E4E.POSITIVO_SIN_CONTRATO,
        T_E4E.NEGATIVO,
        T_E4E.OPERACIONES
	FROM
        (select 
			iperiod PERIODO, TRIM(IDPROVEEDOR)  as IDPROVEEDOR, PDS, 
			sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
			sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
			SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
			SUM(VALOR_OPERACIONES) AS OPERACIONES
		from ENEL_E4E_DEPOSIT_CCDD_TEMP 
		where periodseq=iperiodseq
		group by iperiod, TRIM(IDPROVEEDOR), PDS 
		) T_E4E
            
		LEFT JOIN
			( select PERIODO, trim( to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
				from ENEL_SCAWEB_LIQUIDACION_CCDD sca where PERIODO = iperiod
				group by PERIODO, trim( to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO 
			) T_SCAWEB           
			ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
			AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
		INNER JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
			ON T_E4E.PDS=TMP_PDS.PDS
			AND (TMP_PDS.SUBCANAL='CCDD'
            or TMP_PDS.SUBCANAL='RESELLERS') --APM 16.07.2025

		INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_E4E.IDPROVEEDOR)
      
	WHERE T_SCAWEB.IMPORTE_SCAWEB is null
	;
      
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_SCAWEB_E4E_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);
        
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_COMP_SCAWEB_E4E_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_SCAWEB_E4E_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Comp_Pagos_SCAWEB_E4E', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Comp_Pagos_SCAWEB_E4E', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;            

procedure p_Inf_GeneralProv_Det ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_GRALPROV_DETALLE_CCDD.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_GRALPROV_DETALLE_CCDD WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_GRALPROV_DETALLE_CCDD.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_GRALPROV_DETALLE_CCDD.' ,  v_contador_debug);
	/*INSERT INTO ENELEXT.ENEL_GRALPROV_DETALLE_CCDD ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, TIPO_IMPOSITIVO, DELEGACION, ZONA, 
													TERRITORIO, IMPORTEBASE )   
	SELECT 
        iperiod,
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
            
	FROM ENEL_PROVEEDORES_TEMP_CCDD ept
		LEFT JOIN ENEL_DEPOSIT_TEMP_CCDD edt 
             ON EPT.IDPROVEEDOR = edt.EARNINGGROUPID

        LEFT JOIN ENEL_PDS_TEMP_CCDD epds
             ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
             AND EPDS.PAYEESEQ = edt.payeeseq
             AND EPDS.SUBCANAL = 'CCDD' 

	GROUP BY 
		iperiod, 
		ept.IDPROVEEDOR,
		EPT.DESCRIPCION,
		ept.actividad,
		EPDS.PDS,
		EPDS.NOMBRE_FISCAL,
		EPDS.TIPO_IMPOSITIVO,
		EPDS.DELEGACION,
		EPDS.ZONA,
		EPDS.TERRITORIO; */
    INSERT INTO ENELEXT.ENEL_GRALPROV_DETALLE_CCDD ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, TIPO_IMPOSITIVO, DELEGACION, ZONA, 
													TERRITORIO, IMPORTE_CRUZADA, IMPORTE_REACTIVA, IMPORTE_S2S )   
	SELECT 
        iperiod,
        ept.IDPROVEEDOR,
        ept.DESCRIPCION,
        ept.ACTIVIDAD,
        EPDS.PDS,
        EPDS.NOMBRE_FISCAL,            
        EPDS.TIPO_IMPOSITIVO,
        EPDS.DELEGACION,
        EPDS.ZONA,
        EPDS.TERRITORIO,
        /*BOM APM 17.07.2025*/
        --Old Code
        /*SUM(case when edt.genericattribute1 = 'Venta Cruzada' THEN edt.value else 0 end) AS IMPORTE_CRUZADA,
        SUM(case when edt.genericattribute1 = 'Venta Reactiva' THEN edt.value else 0 end) AS IMPORTE_REACTIVA,
        SUM(case when edt.genericattribute1 = 's2s' THEN edt.value else 0 end) AS IMPORTE_S2S*/
        --New Code
        0 as IMPORTE_CRUZADA,
        0 as IMPORTE_REACTIVA,
        sum(edt.VALUE) IMPORTE_S2S
        /*EOM APM 17.07.2025*/
            
	FROM enel_deposit_temp_ccdd edt
    INNER JOIN enel_proveedores_temp_ccdd ept ON edt.proveedor_ga6 = ept.idproveedor
    INNER JOIN enel_pds_temp_ccdd epds ON epds.ruleelementownerseq = edt.positionseq
                                          AND epds.payeeseq = edt.payeeseq
                                          AND (epds.subcanal = 'CCDD' 
                                          OR epds.subcanal = 'RESELLERS') --APM 16.07.2025

	GROUP BY 
		iperiod, 
		ept.IDPROVEEDOR,
		EPT.DESCRIPCION,
		ept.actividad,
		EPDS.PDS,
		EPDS.NOMBRE_FISCAL,
		EPDS.TIPO_IMPOSITIVO,
		EPDS.DELEGACION,
		EPDS.ZONA,
		EPDS.TERRITORIO;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_GRALPROV_DETALLE_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_GRALPROV_DETALLE_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_GRALPROV_DETALLE_CCDD.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_GeneralProv_Det', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_GeneralProv_Det', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
	v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin
	-- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
	SELECT count(ESTADO)
		into v_checkCountEstado
	FROM ENELEXT.ENEL_PERIODOS_LIQ_CCDD epl 
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

procedure p_rappeles( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , iInterfaz IN VARCHAR2, iprocessingUnitSeq IN VARCHAR2)
as
    v_txtFechaLiquidacion VARCHAR2(10);
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_RAPPELES_CCDD.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_CCDD WHERE periodo = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
         LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_LIQ_CCDD WHERE periodo = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;     

        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_WBE WHERE periodo = iperiod and PROCESSINGUNITSEQ=iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;
    
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST_CCDD') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    w_debug('Fin Borrado de la tabla ENEL_RAPPELES_CCDD.', v_contador_debug);

    w_debug('Insertando datos en tabla ENEL_RAPPELES_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_RAPPELES_CCDD  (PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, ALTAS, BAJAS,
											PORC_TDM, IMPORTE_COMISION, PENA_TDM,COMISIONBASE )   
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
		CSI.GENERICNUMBER1 as ALTAS, 
		CSI.GENERICNUMBER2 as BAJAS,
		CSI.GENERICNUMBER3 as PORC_TDM, 
		CSI.GENERICNUMBER5 as IMPORTE_COMISION,
        CSI.GENERICNUMBER4 as PENA_TDM, --APM 16.07.2025
        CSI.GENERICNUMBER5 AS COMISIONBASE
    
    FROM ENEL_INCEN_TEMP_CCDD CSI --CS_INCENTIVE CSI
        INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
          
        INNER JOIN ENEL_PDS_TEMP_CCDD CSP --CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
		/*
		INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate = v_eot
		*/
  
    WHERE 
		CSI.periodseq = iperiodseq 
		and ((CSI.NAME LIKE 'I - Captacion CCDD - Rappel Ventas%' and csi.GENERICATTRIBUTE16 is not null)
			or csi.name like 'I - Captacion CCDD - TdM%'
            or csi.name like 'I - Captacion Resellers%') --APM 16.07.2025
        and csi.value<>0
		; 
    
    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_RAPPELES_CCDD - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Carga de la tabla ENEL_RAPPELES_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_RAPPELES_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_CCDD.',v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_RAPPELES_WBE(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, subcanal, wbe, PROCESSINGUNITSEQ)
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
        iprocessingUnitSeq
	
	FROM ENEL_INCEN_TEMP_CCDD CSI --CS_INCENTIVE CSI
        INNER JOIN ENEL_PROVEEDORES_TEMP_CCDD EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
          
        INNER JOIN ENEL_PDS_TEMP_CCDD CSP --CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
    
		LEFT JOIN ENEL_PDS_TEMP_CCDD TMP_PDS
			on CSI.payeeseq=TMP_PDS.payeeseq 
			and CSI.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and CSI.periodseq=TMP_PDS.periodseq
		
    WHERE 
		CSI.periodseq = iperiodseq 
        /* QUE REGLAS DEBEN IR AQUI?
		and ((CSI.NAME LIKE 'I - Captacion CCDD - Rappel Ventas%' and csi.GENERICATTRIBUTE16 is not null)
		or csi.name like 'I - Captacion CCDD - TdM%')*/
        and (CSI.NAME LIKE 'I - Captacion CCDD - Rappel%' -- me lo invento!!!!
        or csi.name like 'I - Captacion Resellers - %Malus%'
        OR CSI.NAME LIKE 'I - Captacion CCDD - Incentivo Transversal % - %')
		and csi.value<>0
    ;
    
    filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_RAPPELES_WBE - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_RAPPELES_WBE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_WBE.',v_contador_debug);
    
    -- Rappeles
    w_debug('Insertando Registros de datos en tabla ENEL_RAPPELES_LIQ_CCDD.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_RAPPELES_LIQ_CCDD (PERIODO, NOMBRE,IMP_BASE,PORCENTAJE,IMPORTE, TIPO_VENTA,
                                                TIPO_RAPPEL,CONSECUCION,REALIZADO,OBJETIVO,TIPO_SLA,IMPORTE_BASE,COD_PLATAF)

	SELECT 
            PER.NAME,           
            INC.name as NOMBRE,
            inc.VALUE AS IMP_BASE,
            INC.GENERICNUMBER4 AS PORCENTAJE,
            INC.value as IMPORTE,           
            inc.GENERICATTRIBUTE6 as TIPO_VENTA,
            INC.GENERICATTRIBUTE3 AS TIPO_RAPPEL,                   
            INC.GENERICNUMBER3 AS CONSECUCION,
            INC.GENERICNUMBER2 AS REALIZADO,
            INC.GENERICNUMBER1 AS OBJETIVO,
            INC.GENERICATTRIBUTE6 AS TIPO_SLA,
            INC.GENERICNUMBER5 AS IMPORTE_BASE,
            pos.name AS COD_PLATAF
            	
	FROM  CS_INCENTIVE INC       
    
    left join CS_PERIOD PER
            ON PER.PERIODSEQ=IPERIODSEQ
            AND PER.PERIODSEQ=INC.PERIODSEQ
            AND PER.REMOVEDATE='01/01/2200'

		left JOIN cs_position pos 
			ON pos.payeeseq=inc.payeeseq
            and  pos.REMOVEDATE = '01/01/2200'
			AND pos.TENANTID = 'ENEL' 
			AND pos.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND pos.EFFECTIVEENDDATE >= PER.ENDDATE - 1
			and POS.PROCESSINGUNITSEQ = 38280596832650118
            AND POS.RULEELEMENTOWNERSEQ=INC.POSITIONSEQ
        
		
	WHERE INC.PROCESSINGUNITSEQ=38280596832650118
    AND (inc.name LIKE 'I - Captacion CCDD%Rap%'
    OR INC.NAME LIKE 'I - Captacion CCDD - Incentivo Transversal % - %')
    AND (inc.GENERICATTRIBUTE4 not like 'Dashboards' OR inc.GENERICATTRIBUTE4 is null)
	AND inc.periodseq=iperiodseq /*Diego Montañez 27/10/22 Faltaba filtrar por periodo y se añade esta linea */
    AND inc.GENERICBOOLEAN1 = 1;--DMS 07/12/2022

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_RAPPELES_LIQ_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CUADRELIQ_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CUADRELIQ_CCDD.',v_contador_debug);

 /*   z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_rappeles', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_rappeles', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;

/* BOM - APM - 30.04.2025 */
procedure p_E4E_CCDD_WBE ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_CCDD_WBE.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_CCDD_WBE WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_CCDD_WBE.', v_contador_debug);

    w_debug('Insertando Registros E4E de datos en tabla ENEL_E4E_CCDD_WBE.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_E4E_CCDD_WBE ( PERIODSEQ, PERIODO, IDPROVEEDOR, DESCRIPCION, PDS, NOMBRE_FISCAL, EARNINGGROUPID, IMPORTE_SCAWEB)  
     
        select depo.PERIODSEQ, 
            PER.name, 
            TRIM(TMP_PROV.IDPROVEEDOR) AS IDPROVEEDOR, 
            TMP_PROV.DESCRIPCION AS DESCRIPCION,
            PDS, 
            TMP_PDS.NOMBRE_FISCAL AS NOMBRE_FISCAL,
            EARNINGGROUPID, 
            depo.VALUE
        
        from cs_deposit depo
                INNER JOIN CS_PERIOD PER
                    ON PER.PERIODSEQ=DEPO.PERIODSEQ
                    AND PER.REMOVEDATE='01/01/2200'
                    
		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_CCDD TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.GENERICATTRIBUTE6   
			AND depo.periodseq=TMP_PROV.periodseq
            
            INNER JOIN ENELEXT.ENEL_PDS_TEMP_CCDD TMP_PDS 
                ON depo.payeeseq=TMP_PDS.payeeseq 
                and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
                and depo.periodseq=TMP_PDS.periodseq
                
        where depo.periodseq=iperiodseq
            ;
      
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros E4E de la tabla ENEL_E4E_CCDD_WBE: '|| to_char(filas) || ' filas.', v_contador_debug);
        
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_CCDD_WBE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CCDD_WBE.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_E4E_CCDD_WBE', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_E4E_CCDD_WBE', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end; 
/* EOM - APM - 30.04.2025 */

--BOM APM 28/05/2025 - TM2
procedure p_informe_tasa_mortandad (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_txtFechaLiquidacion VARCHAR2(10);
begin

    v_finicio := current_timestamp();
    
        v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
		LOOP
            DELETE FROM ENELEXT.ENEL_TM2_CCDD WHERE PERIODO_BIMENSUAL = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;  
    

    w_debug('Cargando tabla ENEL_TM2_CCDD. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_TM2_CCDD(PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION, 
                                        FILTRO_PRD, FECHA_ALTA, FECHA_BAJA , PERIODO_BIMENSUAL ,NUM_DIAS, MOTIVO_BAJA, PRESCRIPTOR 
                                        )
    SELECT per.name,
		per.periodseq,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        '1' AS IMPORTE_COMISION,--COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.GENERICNUMBER2 , '9999999999990D99'), ',', '.')) VALOR_1,
        'EURO',
        ECT.GENERICATTRIBUTE1,    --    ID Producto SCA Web
        ECT.GENERICATTRIBUTE4,    --    Codigo de PDS/OCAP
        v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
        case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
        TEMP_PROV.DESCRIPCION, -- idproveedor
        TEMP_PROV.IDPROVEEDOR, -- numproveedor
        ECT.GENERICATTRIBUTE3,
        ctype.CREDITTYPEID as CREDITTYPEID,
        TXN.GENERICATTRIBUTE3,
		'NAME',--INC.name,
		ECT.GENERICATTRIBUTE8,
		TXN.ALTERNATEORDERNUMBER, --CUPS
		TXN.GENERICDATE3, --fecha de firma
		TXN.GENERICATTRIBUTE24, -- pedido_CRM
		ECT.PAYEESEQ, 
		ECT.POSITIONSEQ,
		ECT.COMPENSATIONDATE,
        '1' AS ALTAS,
        '1' AS BAJAS,
        '1' AS PORC_TDM,
        '1' AS IMPORTE_COMISION,
        TXN.GENERICBOOLEAN2 as FILTRO_PRD, --Filtro para los productos que cumplem TdM
        TXN.GENERICDATE4 as FECHA_ALTA,
        TXN.GENERICDATE5 as FECHA_BAJA,
        iperiod AS PERIODO_BIMENSUAL, 
        to_date(TXN.GENERICDATE5) - to_date(TXN.GENERICDATE4) as NUM_DIAS,
        etxn0.GENERICATTRIBUTE3 as MOTIVO_BAJA,
         ECT.GENERICATTRIBUTE10 as PRESCRIPTOR

    FROM cs_credit ECT
    INNER JOIN CS_CREDITTYPE ctype ON ECT.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
		INNER JOIN CS_PERIOD PER
           ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-3)
         and per.periodseq = ect.periodseq
        and PER.removedate= '01/01/2200' 	
		LEFT JOIN ENEL_PROVEEDORES_TEMP TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			and TEMP_PROV.tenantId = ECT.tenantId

		INNER JOIN CS_SALESTRANSACTION txn
			ON ECT.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = ECT.processingUnitSeq
            AND txn.compensationdate BETWEEN per.startdate AND per.enddate
            AND txn.tenantid = ECT.tenantId
            AND txn.modelseq = 0	
        LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
		INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid     
        INNER JOIN cs_position pos
            ON pos.payeeseq = ect.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = ect.tenantid
            and POS.PROCESSINGUNITSEQ =  ECT.processingUnitSeq          
            AND pos.EFFECTIVESTARTDATE <= per.startdate          
			AND pos.EFFECTIVEENDDATE >= per.enddate	
		INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = '01/01/2200'
			AND txn.tenantid = etype.tenantid
      WHERE (ctype.CREDITTYPEID = 'Resellers - Ajueste Manual'
            or ctype.CREDITTYPEID = 'Resellers - Captacion Lead'
            or ctype.CREDITTYPEID = 'Resellers - Captacion'
            ) 
        and (TEMP_PROV.IDPROVEEDOR = '011' 
            or TEMP_PROV.IDPROVEEDOR = '012')        
        and ECT.GENERICBOOLEAN1 = 1
        and ECT.GENERICATTRIBUTE1 is not null
        and (ETYPE.eventtypeid = 'Captacion Resellers'
        or ETYPE.eventtypeid = 'Ajuste Manual Resellers')
        ;
 
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TM2_CCDD: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TM2_CCDD',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TM2_CCDD.',v_contador_debug);
    

end;
--EOM APM 17/06/2025

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
    v_Interfaz_Proceso  nvarchar2(50);  
    v_Listado_Informes  nvarchar2(500);
    v_PeriodoLiquidado boolean;
    v_FInicio_Inf timestamp;
    v_FFin_Inf timestamp;
    v_periodo VARCHAR2(50); --DCR 15.05.2023
    v_puseq VARCHAR2(50); --DCR 15.05.2023
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

/* BOM - DCR - Gestion Control de Informes */
begin 
    v_FInicio_Inf := current_timestamp();
    
    SELECT id +1, num_ejecucion +1 INTO v_contador_ctrl_inf, v_num_ejecucion FROM enelext.enel_ctrl_informes
        WHERE id = (SELECT MAX(id) FROM enelext.enel_ctrl_informes);
    IF v_contador_ctrl_inf is null or v_num_ejecucion is null then
        v_contador_ctrl_inf := 1; 
        v_num_ejecucion :=1;
    END IF;
    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'RUN', v_FInicio_Inf, null, null);
exception
    when others then
        w_debug('Error'||SQLCODE||SQLERRM, v_contador_debug);
        v_contador_ctrl_inf := 1; 
        v_num_ejecucion :=1;
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'RUN', v_FInicio_Inf, null, null);
end;
/* EOM - DCR - Gestion Control de Informes */

    --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    /*BOM DCR 15.05.2023 - 2.11 - Creamos variables auxiliares para informar el periodo y PU */
    v_periodo := period;
    v_puseq := processingUnitSeq;
    /*EOM  DCR 15.05.2023 - 2.11 */

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
            WHEN 'Post__'    then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST'; -- 18.04.2023
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
		
		if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_POST' then -- 18.04.2023
			-- se deben actualizar los estados de las tablas
			-- SCAWEB_FINAL
			UPDATE ENELEXT.ENEL_CUADRELIQ_CCDD
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq;
			
			--ENEL_RENOVACION_CCDD
			UPDATE ENELEXT.ENEL_RENOVACION_CCDD
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = period;
			
			--ENEL_CCC_CCDD
			UPDATE ENELEXT.ENEL_CCC_CCDD
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = period;
			
			--ENEL_REGULARIZACION_CCDD
			UPDATE ENELEXT.ENEL_REGULARIZACION_CCDD
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = period;

			--SCAWEB_FINAL_WBE
			UPDATE ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq;

			--RAPPELES
			UPDATE ENELEXT.ENEL_RAPPELES_CCDD
			SET CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq;

			--RAPPELES_WBE
			UPDATE ENELEXT.ENEL_RAPPELES_WBE
			SET CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq;
        end if;

        if v_ACTIVO <> 1 then
            w_debug('Interfaz '||v_Interfaz_Proceso||' NO ACTIVO. Salimos...', v_contador_debug);
            salidacontrol :='Salida '||v_Interfaz_Proceso||' no activa.';
            RETURN;
        else 
            w_debug('Interfaz '||v_Interfaz_Proceso||' ACTIVO.', v_contador_debug);
        end if;    
    end if; 

    salidacontrol :='Procedure '||v_Interfaz_Proceso||' comenzando';

	-- Se comprueba si el periodo Ya ha sido liquidado. 
    v_PeriodoLiquidado := f_ComprobarPeriodoLiquidado( processingUnitSeq, period ,periodSeq , tenantId  );

	-- SI EL PERIODO NO SE HA LIQUIDADO, SE EXTRAEN DE NUEVO LOS DATOS PARA LOS INFORMES      
    IF  v_PeriodoLiquidado = false THEN
        ------------------------------------------------------------
        -- Datos Generales que se usan en varios informes
        ------------------------------------------------------------
        -- Volcar datos de las tablas de transacciones a una tabla temporal. Tabla ENEL_TXN_TEMP
        p_Temporal_Transacciones ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de créditos a una tabla temporal. Tabla ENEL_CREDIT_TEMP
        p_Temporal_Creditos ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de incentivos a una tabla temporal. Tabla ENEL_INCEN_TEMP
        p_Temporal_Incentivos ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de Depósitos a una tabla temporal. Tabla ENEL_DEPOSIT_TEMP
        p_Temporal_Depositos ( processingUnitSeq, period ,periodSeq , tenantId  );

        -- Volcar datos de clasificacion a una Temporal de Proveedores. Tabla ENEL_PROVEEDORES_TEMP
        p_Temporal_Proveedores ( period ,periodSeq , tenantId  );
        -- Volcar datos de clasificacion a una Temporal de Equipamientos Tabla ENEL_EQUIPAMIENTO_TEMP        
        p_Temporal_Equipamientos ( period ,periodSeq , tenantId  );
        -- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PDS_TEMP
        p_Temporal_Pds ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de Productos a una Temporal Tabla ENEL_PRODUCTOS_TEMP   
        p_Temporal_Productos ( period ,periodSeq , tenantId  );

        p_Temporal_E4E_Negativos ( period ,periodSeq , tenantId  );
        
        p_rappeles ( period ,periodSeq , tenantId , v_Interfaz_Proceso, processingUnitSeq );

/*  Informe de Prefactura . Es mas similar el de CES, se modifica 
        p_Inf_Factura_Detalle ( processingUnitSeq, period,periodSeq, tenantId );
        p_Inf_Factura_Portada ( processingUnitSeq, period,periodSeq, tenantId );
*/
        ---------------------------------------------------
        -- Datos para PREFACTURA
        ---------------------------------------------------
        IF f_ExisteInformeEnLista('PREFACT_CCDD', v_Listado_Informes) THEN
            -- Extraer datos para detalle de PreFactura
            p_Prefactura ( processingUnitSeq, period ,periodSeq , tenantId, v_Interfaz_Proceso );

            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'PREFACT_CCDD');   
        end if;

        IF f_ExisteInformeEnLista('E4E', v_Listado_Informes) THEN
            -- Volcar datos de clasificaci?n a una Temporal de Contratos.     Tabla ENEL_E4E_CONTRATOS_TEMP
            p_Temporal_Contratos_E4E ( period ,periodSeq , tenantId  );
            -- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_TEMP
            p_Temporal_Depositos_E4E  ( processingUnitSeq, period ,periodSeq , tenantId, v_Interfaz_Proceso  );
            -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 1 
            p_Final_E4E_1  ( period ,periodSeq , tenantId  );
            -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 2 
            p_Final_E4E_2  ( period ,periodSeq , tenantId  );        
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'E4E_CCDD');

            if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_REWARD' THEN  -- v2.4
                -- Los datos Negativos solo se extraen enel REWARD
                -- Extraer datos NEGATIVOS de TEMP_Depositos. Tabla: ENEL_E4E_NEGATIVOS
                p_Final_E4E_Negativos  ( processingUnitSeq, period ,periodSeq , tenantId  );
                -- Actualizamos la fecha del informe en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'E4ENEG_CCDD');          
            end if;
        end if;

        ------------------------------------
        -- Datos para INTERFACE SCAWEB
        ------------------------------------
        --if v_Listado_Informes = 'ALL' OR v_Listado_Informes = 'ANDROMEDA' then
        IF f_ExisteInformeEnLista('SCAWEB', v_Listado_Informes) THEN
            -- Extraer datos de creditos calculados para el periodo -> Tabla : ENEL_SCAWEB_LIQUIDACION   
            p_Temporal_Creditos_Scaweb  ( processingUnitSeq, period ,periodSeq , tenantId  );    
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'SCAWEB_CCDD');      
        end if;
        
        -- Comparativa Pagos solo se hace si se ejecutan todos los informes
        IF v_Listado_Informes = 'ALL' THEN
            p_Comp_Pagos_SCAWEB_E4E ( processingUnitSeq, period ,periodSeq , tenantId  );
            p_E4E_CCDD_WBE ( processingUnitSeq, period ,periodSeq , tenantId  ); --APM 30.04.2025
        end if;        
        
        ---------------------------------------------------
        -- Datos para INFORMES GENERAL DE PROVEEDORES
        ---------------------------------------------------    
        IF f_ExisteInformeEnLista('INFGRALPROV', v_Listado_Informes) THEN
            -- Extraer datos de Transacciones para informes del PDS    
            p_Inf_GeneralProv_Det  ( processingUnitSeq, period ,periodSeq , tenantId  );
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'INFGRALPROV_CCDD');            
        end if;        

        --------------------------------
        -- Datos para Mensual de Cuadre de Liquidación
        --------------------------------    
        IF f_ExisteInformeEnLista('LIQSCAWEB', v_Listado_Informes) THEN
            -- Extraer datos para Interface de LIQUIDACION MENSUAL SCAWEB  (Captacion - Importe Base)
            p_Informe_CUADRE_LIQ (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
         
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'LIQSCAWEB_CCDD');    
        end if;
        
--BOM APM 03.03.2026
            ---------------------------------------------------
            -- Datos para Informe Agrupado de liquidaciones
            ---------------------------------------------------
            IF f_ExisteInformeEnLista('LIQ_CCDD', v_Listado_Informes) THEN
				p_informe_agrupado (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
				-- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_CCDD');    
			end if;
--EOM APM 03.03.2026
		
	ELSE
        w_debug('Periodo YA Liquidado. NO se actualizan Datos de INFORMES', v_contador_debug);
	end if;

    w_debug('Procedure END', v_contador_debug);
/* BOM - DCR - Gestion Control de Informes */
    v_FFin_Inf := current_timestamp();
    UPDATE enelext.enel_ctrl_informes 
        SET fecha_fin = v_FFin_Inf, duracion = extract(day from (v_FFin_Inf - v_FInicio_Inf)*86400)
        WHERE num_ejecucion = v_num_ejecucion
            AND proceso = 'RUN';
    COMMIT;
/* EOM - DCR - Gestion Control de Informes */
    salidacontrol :='Procedure '||v_Interfaz_Proceso||' END';

    COMMIT;    
END;

END ENEL_ACTUALIZA_INFORMES_CCDD;