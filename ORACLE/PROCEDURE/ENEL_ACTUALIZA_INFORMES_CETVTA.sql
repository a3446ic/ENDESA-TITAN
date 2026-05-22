create or replace PACKAGE BODY         "ENEL_ACTUALIZA_INFORMES_CETVTA" AS
/* *****************************************************************************
	NAME:       ACTUALIZA_INFORMES_CETVTA
	PURPOSE:

	REVISIONS:
	Ver      		Date        	Author           	Description
	---------  		----------  	---------------  	-----------------------------------											
	1.0				15/06/2020		MPR	                Creacion de procedimientos para nueva processingUnit - CE_TVTA
    2.0             07/02/2022      DCR                 Informe Agregado no coherente con cuadre de liquidación
    3.0             29/05/2024      APM                 Se añade nuevo campo Decomisión a la tabla ENEL_CUADRELIQ_FINAL_CES	
    4.0             11/07/2024      APM                 Actualizar CAMPO11 a 2 decimales.
    5.0             18/07/2024      APM                 Añadir nuevo campo TXN.GB2 (SS_GARANTIA) en la tabla ENEL_CUADRELIQ_FINAL_CES.
    6.0             05/11/2024      APM                 Añadir nuevo campo TXN.GA1  (TIPO_SERVICIO) en la tabla ENEL_CUADRELIQ_FINAL_CES.
    7.0             07/11/2024      APM                 Añadir nuevo campo TXN.GB1 (GESTION_CARTERA) en la tabla ENEL_CUADRELIQ_FINAL_CES.
    
***************************************************************************** */

    v_eot 				DATE := TO_DATE('22000101','yyyymmdd');
    v_periodo 			VARCHAR2(50 BYTE);
    v_contador_debug	integer; 
    v_classifierid  	CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION   	CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE         	CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA     	CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS    	CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD  	CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO        	CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas 				number; --Para el DEBUG de los INSERT

/* *****************************
    Debug en ENELEXT.ENEL_DEBUG
***************************** */
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
		c.classifierid,
		C.DESCRIPTION,
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
	
    	inner join CS_GENERICCLASSIFIER gc on C.CLASSIFIERSEQ=GC.CLASSIFIERSEQ 
			and    gc.TENANTID = 'ENEL' 
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
	
    Where CT.NAME='Salida' 
		AND GCT.NAME ='Interfaz'
		and GCT.TENANTID = 'ENEL' 
		and c.classifierid=iInterfaz 
		and c.REMOVEDATE= v_eot and c.ISLAST=1;

	w_debug('Datos del Interfaz en Clasificacion: ',v_contador_debug);
	w_debug('Clasificacion.classifierid: ['||v_classifierid     	||']',v_contador_debug);    
	w_debug('Clasificacion.DESCRIPCION : ['||v_DESCRIPCION			||']',v_contador_debug);
	w_debug('Clasificacion.STAGE       : ['||v_STAGE				||']',v_contador_debug);        
	w_debug('Clasificacion.SECUENCIA   : ['||v_SECUENCIA			||']',v_contador_debug);        
	w_debug('Clasificacion.ARGUMENTOS  : ['||v_ARGUMENTOS			||']',v_contador_debug);            
	w_debug('Clasificacion.PERIODICIDAD: ['||v_PERIODICIDAD			||']',v_contador_debug);        
	w_debug('Clasificacion.ACTIVO      : ['||v_ACTIVO				||']',v_contador_debug);                                       
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

-- Se calcula el primer dia del mes siguiente al actual 
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

-- periodo anterior
function f_Primer_Dia_Periodo_Anterior(iperiodseq varchar2) return date as
    v_Primer_Dia date;
begin
    SELECT ADD_MONTHS( PER.STARTDATE , 1 ) INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
    AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
     return v_Primer_Dia;
end;

function f_Ultimo_Dia_Periodo_Anterior(iperiodseq varchar2) return date as
    v_Ultimo_Dia date;
begin
    SELECT ADD_MONTHS( PER.ENDDATE  - 1 , 1 )INTO v_Ultimo_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=iperiodseq 
    AND PER.REMOVEDATE = to_date('2200-01-01','YYYY-MM-DD');
      
    return v_Ultimo_Dia;
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

--------- Volcar datos de las tablas de Transacciones a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_TXN_TEMP ----

procedure p_Temporal_TXN_truncate (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_CETVTA.', v_contador_debug);    
end;

procedure p_Temporal_Transacciones (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Cargando tabla ENEL_TXN_TEMP_CETVTA. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);
	
    INSERT INTO ENELEXT.ENEL_TXN_TEMP_CETVTA( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, ACCOUNTINGDATE, 
                                        PRODUCTID, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, 
                                        GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14, 
                                        GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICATTRIBUTE17, GENERICATTRIBUTE18,GENERICATTRIBUTE19, GENERICATTRIBUTE20, 
                                        GENERICATTRIBUTE21, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICDATE3, GENERICDATE4, GENERICDATE5, GENERICBOOLEAN2, 
                                        PONUMBER, DATASOURCE, TAD_ADDRESS1, TAD_CITY, TAD_STATE, TAD_POSTALCODE, TAD_INDUSTRY, TAD_GEOGRAPHY, 
                                        TAS_POSITIONNAME, TAS_GENERICATTRIBUTE1, TAS_GENERICATTRIBUTE2, TAS_GENERICNUMBER1, TAS_GENERICNUMBER2, 
                                        TEX0_GENERICATTRIBUTE4, TEX0_GENERICATTRIBUTE5, TEX0_GENERICATTRIBUTE6, TEX0_GENERICATTRIBUTE7, TEX0_GENERICATTRIBUTE8, 
                                        TEX0_GENERICATTRIBUTE9, TEX0_GENERICATTRIBUTE10, TEX0_GENERICATTRIBUTE11, TEX0_GENERICATTRIBUTE12, 
                                        TEX0_GENERICATTRIBUTE13, TEX0_GENERICATTRIBUTE14, TEX0_GENERICATTRIBUTE15, 
                                        TEX0_GENERICATTRIBUTE16, TEX0_GENERICATTRIBUTE17, TEX0_GENERICDATE3, TEX0_GENERICDATE4, TEX0_GENERICBOOLEAN1, 
                                        TEX0_GENERICNUMBER1, TEX0_GENERICNUMBER2, TEX0_GENERICNUMBER3, TEX0_GENERICNUMBER4, TEX0_GENERICNUMBER5,PROCESSINGUNITSEQ, 
										GENERICATTRIBUTE26, GENERICATTRIBUTE27, GENERICATTRIBUTE28, GENERICATTRIBUTE29, GENERICATTRIBUTE32, ALTERNATEORDERNUMBER, GENERICNUMBER4, TEX0_GENERICNUMBER9,
										TEX0_GENERICNUMBER10, GENERICNUMBER5, TEX0_GENERICDATE1, CHANNEL, GENERICBOOLEAN1 ) --APM 07.11.2024
    SELECT 
        TXN.TENANTID ,
        iperiodseq,   
        iperiod,     
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
        TXN.GENERICATTRIBUTE19 as Agente,
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
        etxN0.GENERICNUMBER5 AS NUM_FUERAPLAZOCLIENTE,
        TXN.PROCESSINGUNITSEQ,
		TXN.GENERICATTRIBUTE26 AS COMPONENTE,
		TXN.GENERICATTRIBUTE27 AS NOMBRE_CLIENTE,
		TXN.GENERICATTRIBUTE28 AS ANEXO,
		TXN.GENERICATTRIBUTE29 AS CIF,
		TXN.GENERICATTRIBUTE32 AS CAMPANIA,
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICNUMBER4 as DESCUENTO_TARIFA,
		etxN0.GENERICNUMBER9 AS potencia_max,
		etxN0.GENERICNUMBER10 AS consumo,
		TXN.GENERICNUMBER5 as PVP,
		etxn0.GENERICDATE1 as Fecha_INSERCION,
		TXN.CHANNEL,
        TXN.GENERICBOOLEAN1 as gestion_cartera --APM 07.11.2024
		
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

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    BEGIN
        SYS.DBMS_STATS.GATHER_TABLE_STATS (
        OwnName => 'ENELEXT'
        ,TabName => 'ENEL_TXN_TEMP_CETVTA'
        ,Estimate_Percent => 1
        ,Method_Opt => 'FOR ALL COLUMNS SIZE 1'
        ,Degree => 10
        ,Cascade => TRUE
        ,No_Invalidate => FALSE);
    END;

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_CETVTA.',v_contador_debug);
end;

procedure p_Temporal_Medidas ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS   
begin

    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_TEMP_CETVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_TEMP_CETVTA WHERE  ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_TEMP_CETVTA.', v_contador_debug);

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_TEMP_CETVTA.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_MEDIDAS_TEMP_CETVTA (TENANTID,PERIODSEQ, PERIODO, NAME, VALUE, MEASUREMENTSEQ, PAYEESEQ, POSITIONSEQ, PIPELINERUNSEQ, PLANSEQ, RULESEQ)
												/* GENERICATTRIBUTE1,GENERICATTRIBUTE2,GENERICATTRIBUTE3,GENERICATTRIBUTE4,GENERICATTRIBUTE5,GENERICATTRIBUTE6,
												GENERICATTRIBUTE7,GENERICATTRIBUTE8,GENERICATTRIBUTE9,GENERICATTRIBUTE10,GENERICATTRIBUTE11,GENERICATTRIBUTE12,
												GENERICATTRIBUTE13,GENERICATTRIBUTE14,GENERICATTRIBUTE15,GENERICATTRIBUTE16,GENERICNUMBER1,UNITTYPEFORGENERICNUMBER1,
												GENERICNUMBER2,UNITTYPEFORGENERICNUMBER2,GENERICNUMBER3,UNITTYPEFORGENERICNUMBER3,GENERICNUMBER4,
												UNITTYPEFORGENERICNUMBER4,GENERICNUMBER5,UNITTYPEFORGENERICNUMBER5,GENERICNUMBER6,UNITTYPEFORGENERICNUMBER6,GENERICDATE1,
												GENERICDATE2,GENERICDATE3,GENERICDATE4,GENERICDATE5,GENERICDATE6,GENERICBOOLEAN1,GENERICBOOLEAN2,
												GENERICBOOLEAN3,GENERICBOOLEAN4,GENERICBOOLEAN5,GENERICBOOLEAN6) */      
    SELECT 
        CSM.TENANTID,
        CSM.PERIODSEQ,
        CSP.NAME as Periodo,
        CSM.NAME as Nombre,
        CSM.VALUE as Valor,
        CSM.MEASUREMENTSEQ,
        CSM.PAYEESEQ,
        CSM.POSITIONSEQ,
        CSM.PIPELINERUNSEQ,
        CSM.PLANSEQ,
        CSM.RULESEQ
/*      
        CSM.GENERICATTRIBUTE1,
        CSM.GENERICATTRIBUTE2,
        CSM.GENERICATTRIBUTE3,
        CSM.GENERICATTRIBUTE4,
        CSM.GENERICATTRIBUTE5,
        CSM.GENERICATTRIBUTE6,
        CSM.GENERICATTRIBUTE7,
        CSM.GENERICATTRIBUTE8,
        CSM.GENERICATTRIBUTE9,
        CSM.GENERICATTRIBUTE10,
        CSM.GENERICATTRIBUTE11,
        CSM.GENERICATTRIBUTE12,
        CSM.GENERICATTRIBUTE13,
        CSM.GENERICATTRIBUTE14,
        CSM.GENERICATTRIBUTE15,
        CSM.GENERICATTRIBUTE16,
        CSM.GENERICNUMBER1,
        CSM.UNITTYPEFORGENERICNUMBER1,
        CSM.GENERICNUMBER2,
        CSM.UNITTYPEFORGENERICNUMBER2,
        CSM.GENERICNUMBER3,
        CSM.UNITTYPEFORGENERICNUMBER3,
        CSM.GENERICNUMBER4,
        CSM.UNITTYPEFORGENERICNUMBER4,
        CSM.GENERICNUMBER5,
        CSM.UNITTYPEFORGENERICNUMBER5,
        CSM.GENERICNUMBER6,
        CSM.UNITTYPEFORGENERICNUMBER6,
        CSM.GENERICDATE1,
        CSM.GENERICDATE2,
        CSM.GENERICDATE3,
        CSM.GENERICDATE4,
        CSM.GENERICDATE5,
        CSM.GENERICDATE6,
        CSM.GENERICBOOLEAN1,
        CSM.GENERICBOOLEAN2,
        CSM.GENERICBOOLEAN3,
        CSM.GENERICBOOLEAN4,
        CSM.GENERICBOOLEAN5,
        CSM.GENERICBOOLEAN6
  */              
    
    FROM CS_MEASUREMENT CSM
        inner join cs_period csp 
            on csm.periodseq=csp.periodseq
            and csp.removedate= v_eot
                
    where csm.periodseq= iperiodseq
	and csm.PROCESSINGUNITSEQ = iprocessingUnitSeq;
                 
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_TEMP_CETVTA',v_contador_debug);
    
end;

--------- Volcar datos de la tabla de Creditos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_CREDIT_TEMP ----
procedure p_Temporal_Creditos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CREDIT_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP_CETVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_CREDIT_TEMP_CETVTA( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, POSITIONSEQ, COMPENSATIONDATE,  
											COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, 
											GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, 
											GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, GENERICBOOLEAN2, GENERICDATE1, 
											GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, BU_NAME, GENERICNUMBER6 )
    SELECT 
        credit.TENANTID,
        credit.PERIODSEQ,
        iperiod PERIODO,
        credit.PIPELINERUNSEQ,
        credit.PIPELINERUNDATE,
        credit.NAME,
        CREDIT.CREDITSEQ,
        CREDIT.SALESORDERSEQ,        
        CREDIT.SALESTRANSACTIONSEQ,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        CREDIT.COMPENSATIONDATE,
        CREDIT.COMMENTS,                --v2.3
        CTYPE.CREDITTYPEID,           
        CTYPE.DESCRIPTION,             -- Tipo de Comision
        credit.VALUE,                --Importe Comision
        credit.PREADJUSTEDVALUE,
        credit.GENERICATTRIBUTE1,      -- Concepto Liquidacion
        credit.GENERICATTRIBUTE2,      -- Proveedor
        credit.GENERICATTRIBUTE3,      -- Servicio
        credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
        credit.GENERICATTRIBUTE5,      -- Plazo
        credit.GENERICATTRIBUTE6,      -- Oferta1, Oferta2, Oferta3
        credit.GENERICATTRIBUTE7,      -- Zona
        credit.GENERICATTRIBUTE8,      -- Producto
        credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
        credit.GENERICATTRIBUTE10,     -- Equipamiento   
        credit.GENERICATTRIBUTE11,     -- CodigoPostal --ahora WBE
        credit.GENERICATTRIBUTE12,     -- Tramo Consumo         
        credit.GENERICATTRIBUTE13,     -- Tramo Potencia
        credit.GENERICATTRIBUTE14,     --Descripcion Concepto Liquidacion
        credit.GENERICATTRIBUTE15,     --Observaciones Ajustes Manuales
        credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
        credit.GENERICBOOLEAN2,        -- S/S Garantia
        credit.GENERICDATE1,           --FechaCalculo
        credit.GENERICNUMBER1,
        credit.GENERICNUMBER2,
        credit.GENERICNUMBER3,
		credit.GENERICNUMBER4 as consumo,
		bu.NAME,
		credit.GENERICNUMBER6
        
    FROM CS_CREDIT credit
        INNER JOIN CS_PLRUN p 
            ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Aniadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
                                             
        INNER JOIN CS_CREDITTYPE ctype 
            ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
            AND ctype.TENANTID = itenantId
            AND ctype.REMOVEDATE  = v_eot
		
		INNER JOIN CS_BUSINESSUNIT BU
			ON BU.MASK = CREDIT.BUSINESSUNITMAP
			AND BU.TENANTID = itenantId
	
    WHERE
        credit.TENANTID = itenantId 
        AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND credit.PERIODSEQ =  iperiodseq; 
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDIT_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_TEMP_CETVTA.',v_contador_debug);
end;

---------- Tabla ENEL_COMMISSION_TEMP ----
procedure p_Temporal_Commission (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    w_debug('Inicio Truncado de la tabla ENEL_COMMISSION_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_COMMISSION_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_COMMISSION_TEMP_CETVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_COMMISSION_TEMP_CETVTA. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_COMMISSION_TEMP_CETVTA( TENANTID, PERIODSEQ, PERIODO, COMMISSIONSEQ, CREDITSEQ, INCENTIVESEQ, ENTRYNUMBER, PIPELINERUNSEQ, PAYEESEQ, POSITIONSEQ, ORIGINTYPEID, PIPELINERUNDATE, 
													VALUE, UNITTYPEFORVALUE, RATEVALUE, UNITTYPEFORRATEVALUE, BUSINESSUNITMAP, PROCESSINGUNITSEQ, UNITTYPEFORENTRYNUMBER, ISPRIVATE  )
    SELECT 
        commi.TENANTID,
        commi.PERIODSEQ,
        iperiod PERIODO,
		commi.COMMISSIONSEQ, 
		commi.CREDITSEQ, 
		commi.INCENTIVESEQ, 
		commi.ENTRYNUMBER, 
		commi.PIPELINERUNSEQ, 
		commi.PAYEESEQ, 
		commi.POSITIONSEQ, 
		commi.ORIGINTYPEID, 
		commi.PIPELINERUNDATE, 
		commi.VALUE, 
		commi.UNITTYPEFORVALUE, 
		commi.RATEVALUE, 
		commi.UNITTYPEFORRATEVALUE, 
		commi.BUSINESSUNITMAP, 
		commi.PROCESSINGUNITSEQ, 
		commi.UNITTYPEFORENTRYNUMBER, 
		commi.ISPRIVATE
        
    FROM CS_COMMISSION commi

    WHERE
        commi.TENANTID = itenantId 
        AND commi.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND commi.PERIODSEQ =  iperiodseq; 
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_COMMISSION_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_COMMISSION_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMMISSION_TEMP_CETVTA.',v_contador_debug);
end;
--------- Volcar datos de la tabla de Incentivos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_INCEN_TEMP ----
procedure p_Temporal_Incentivos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS    
begin

    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP_CETVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP_CETVTA. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_INCEN_TEMP_CETVTA(  TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
											GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE16, 
											GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
											GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2,GENERICATTRIBUTE6, BU_NAME )
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
        incent.VALUE,                  	-- Importe Incentivo
        incent.GENERICATTRIBUTE1,      	-- Concepto Retributivo
        incent.GENERICATTRIBUTE2,      	-- Linea de Negocio
        incent.GENERICATTRIBUTE3,      	-- Descripcion
        incent.GENERICATTRIBUTE4,      	-- Tramo                     
        incent.GENERICATTRIBUTE16,     	-- Nombre Cuota
        incent.GENERICNUMBER1,         	-- Objetivo
        incent.GENERICNUMBER2,         	-- Realizado
        incent.GENERICNUMBER3,         	-- % Consecucion
        incent.GENERICNUMBER4,         	-- Tarifa
        incent.GENERICNUMBER5,         	-- Importe unitario
        incent.GENERICNUMBER6,         	-- Target Incentive
        incent.GENERICBOOLEAN1,         
        incent.GENERICDATE1,           	-- Fecha Inicio
        incent.GENERICDATE2,           	-- Fecha Final       
		incent.GENERICATTRIBUTE6,     	-- Tipo de gasto
        BU.NAME
		
    FROM CS_INCENTIVE incent
        INNER JOIN CS_PLRUN p ON incent.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Aniadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
		
		INNER JOIN CS_BUSINESSUNIT BU
			ON BU.MASK = INCENT.BUSINESSUNITMAP
			AND BU.TENANTID = itenantId

    WHERE
        incent.TENANTID = itenantId 
        AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND incent.PERIODSEQ =  iperiodseq
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INCEN_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP_CETVTA.',v_contador_debug);
end;         

--------- Volcar datos de la tabla de Depositos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_DEPOSIT_TEMP ----
procedure p_Temporal_Depositos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS    
begin

    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP_CETVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP_CETVTA. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP_CETVTA( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
												PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5, 
												processingunitseq, wbe, BUSINESSUNITMAP, LINEA_NEGOCIO, TIPO, BU_NAME, GENERICNUMBER1,GENERICDATE1,GENERICATTRIBUTE9 )
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
        depo.GENERICATTRIBUTE1,      -- Actividad / Campania
        depo.GENERICATTRIBUTE2,
        depo.GENERICATTRIBUTE5,
        depo.processingunitseq,
        depo.EARNINGGROUPID wbe, 
		DEPO.BUSINESSUNITMAP, 
		DEPO.GENERICATTRIBUTE3 as linea_negocio,
		DEPO.GENERICATTRIBUTE7 AS TIPO,
		BU.NAME,
        DEPO.GENERICNUMBER1,
         DEPO.GENERICDATE1, --DMS 28.06.2024
        DEPO.GENERICATTRIBUTE9 --DMS 28.06.2024
        
    FROM CS_DEPOSIT depo
        INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            --Aniadimos nuevo filtro para optimizar
            AND p.tenantid = itenantId
			
		INNER JOIN CS_BUSINESSUNIT BU
			ON BU.MASK = DEPO.BUSINESSUNITMAP
			AND BU.TENANTID = itenantId
			
    WHERE
        depo.TENANTID = itenantId 
        AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
        AND depo.PERIODSEQ =  iperiodseq;
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP_CETVTA.',v_contador_debug);   
end;         

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----
procedure p_Temporal_Orden_Imputacion ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_ORDER_IMPU_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_ORDER_IMPU_TEMP_CETVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_ORDER_IMPU_TEMP_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
													WBE_FINAL_IMPUTACION,DETALLE_ACTIVIDAD,ACTIVIDAD,SOCIEDAD,
													CENTRO_LOGISTICO,GR_COMPRAS, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR,SUBACTIVIDAD, NOM_SOLICITANTE)
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
        GC.GENERICATTRIBUTE8 ORG_VENTAS, -- Nuevo v2.0            
        C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
        C.EFFECTIVEENDDATE FECHA_FIN_VIGOR,
        GC.GENERICATTRIBUTE10, 
		GC.GENERICATTRIBUTE9
        
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
         
    WHERE GCT.NAME like 'Orden de Imputa%'
	and GC.GENERICATTRIBUTE4 = 'Clientes Empresa' -- filtro para clientes empresas 
    ;
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_ORDER_IMPU_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA.',v_contador_debug); 
end;

--------- Volcar datos de clasificaci?n a una Temporal de Equipamientos. 
procedure p_Temporal_Equipamientos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_EQUIPAMIENTO_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_CETVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_EQUIPAMIENTO_TEMP_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_EQUIPAMIENTO_TEMP_CETVTA( TENANTID,PERIODSEQ,EQUIPAMIENTO, IDMARCA, MARCA, IDMODELO, MODELO, IDTIPO,
													TIPO, LITROS, POTENCIAKW,FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR )
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

    WHERE GCT.NAME ='Equipamiento';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
end;

procedure p_Temporal_E4E_Negativos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_CETVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_CETVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_CETVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Origen de ENEL_E4E_NEGATIVOS_TEMP_CETVTA : CS_DEPOSIT.', v_contador_debug);
    -- Si se ejecuta en la FASE REWARD Utilizamos la tabla de depositos para generar los datos de las tablas porque aun no se han realizado los PAGOS
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_CETVTA( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
													PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO,
													TIPO, LINEA_NEGOCIO, CANAL_PDS, BU_NAME  )
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
        --TMP_CONTRA.ORG_COMPRAS,
		TMP_PROV.ORG_VENTAS, --MPR se modifica para que coga el el ORG_Compras
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
		DEPO.GENERICATTRIBUTE1,  --El Tipo en el informe es la Actividad del depósito
		DEPO.LINEA_NEGOCIO,
		TMP_PDS.CANAL,
		DEPO.BU_NAME

    FROM ENEL_DEPOSIT_TEMP_CETVTA DEPO
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
            on DEPO.payeeseq=TMP_PDS.payeeseq 
            and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and DEPO.periodseq=TMP_PDS.periodseq
            
        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
            AND DEPO.periodseq=TMP_PROV.periodseq

        --INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
        LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_CETVTA TMP_CONTRA
            ON TMP_CONTRA.periodseq=DEPO.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
		
    WHERE DEPO.TENANTID = itenantId
        AND DEPO.periodseq=iperiodseq        
        --AND DEPO.VALUE < 0  -- Se calcula la diferencia de todos los depositos 

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
		DEPO.GENERICATTRIBUTE1,  --El Tipo en el informe es la Actividad del depósito
		DEPO.LINEA_NEGOCIO,
		TMP_PDS.CANAL,
		DEPO.BU_NAME;
                      
    filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
end;

--------- Volcar datos de clasificacion a una Temporal de Contratos 
---------- Tabla ENEL_E4E_CONTRATOS_TEMP ----
procedure p_Temporal_Contratos_E4E ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_CETVTA.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRATOS_TEMP_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CETVTA(TENANTID,PERIODSEQ,ID,PDS,ACTIVIDAD_DETALLADA,ACTIVIDAD, CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
													ORG_COMPRAS,CONDICIONES_PAGO, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, SUBPOSICION, COD_PROVEEDOR, IMPORTE, POS_ORDEN, LINEA_SERVICIO)
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
        GC.GENERICATTRIBUTE12 SUBPOSICION, -- Se va a guardar la cesta
		GC.GENERICATTRIBUTE13 as cod_proveedor,
		GC.GENERICNUMBER1 as IMPORTE,
		GC.GENERICNUMBER2 AS POS_ORDEN,
		GC.GENERICNUMBER3 AS LINEA_SERVICIO
            
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
            
    WHERE GCT.NAME ='Contrato'
        AND GCT.TENANTID = itenantId;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRATOS_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CETVTA.',v_contador_debug);   
end;

--------- Volcar datos de Posiciones y participantes a una Temporal de PDS   -------- 
--------- Tabla: ENEL_PDS_TEMP  --------
procedure p_Temporal_Pds (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP_CETVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PDS_TEMP_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_PDS_TEMP_CETVTA( PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
                                          PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, NOMBRE_COMERCIAL, IMPORTE_UB, FECHA_CONTRATACION, 
                                          TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
                                          BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION, NOMBRE_FISCAL_CORTO )
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
        POS.GENERICATTRIBUTE1 AS TIPO_PRESTADOR,  -- condición para canal BP
        POS.GENERICATTRIBUTE2 AS COMUNIDAD_AUTONOMA,
        POS.GENERICATTRIBUTE3 AS TERRITORIO,
        POS.GENERICATTRIBUTE4 AS ZONA,
        POS.GENERICATTRIBUTE5 AS POS_NOMBRE_COMERCIAL,
        POS.GENERICATTRIBUTE6 AS CANAL,
        POS.GENERICATTRIBUTE7 AS SUBCANAL,
        POS.GENERICATTRIBUTE8 AS DELEGACION,
        POS.GENERICATTRIBUTE10 AS BASE_COMISION,
        POS.EFFECTIVESTARTDATE,    -- Fecha inicio de vigencia 
        PAR.TERMINATIONDATE AS TERMINATIONDATE,
        TIT.NAME AS TITLE_NAME,
        TIT.GENERICATTRIBUTE1 AS CANAL_CALCULOS,
        TIT.GENERICATTRIBUTE2 AS TIPO_POSICION,
		PAR.FIRSTNAME NOMBRE_FISCAL_CORTO

    FROM CS_PERIOD per
        JOIN CS_POSITION pos ON  pos.REMOVEDATE = v_eot
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
		;
        --and par.GENERICATTRIBUTE1 is not null; -- MPR esta condicion no aplica a CES
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PDS_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP_CETVTA.',v_contador_debug);
end;

-- Extraer datos de Dep?sitos y JOIN con tablas temporales 
-- Tabla: ENEL_E4E_DEPOSIT_TEMP
procedure p_Temporal_Depositos_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz_Proceso  IN VARCHAR2)
AS    
begin
    w_debug('Inicio Truncado de la tabla ENEL_E4E_DEPOSIT_TEMP_CETVTA.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TEMP_CETVTA';
    w_debug('Fin Truncado de la tabla ENEL_E4E_DEPOSIT_TEMP_CETVTA.', v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_DEPOSIT_TEMP_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    -- Si se ejecuta en una FASE que no es REWARD Utilizamos la tabla de PAGOS
    w_debug('Origen de ENEL_E4E_DEPOSIT_TEMP_CETVTA.', v_contador_debug);

	INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_TEMP_CETVTA( PERIODSEQ, PERIODO, POSITIONSEQ,PAYEESEQ,VALUE,PDS,PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO,DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,
												WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, 
												SUBPOSICION, BUSINESSUNIT, LINEA_NEGOCIO, TIPO, CAMPANIA, NOM_SOLICITANTE, POS_ORDEN, LINEA_SERVICIO,GENERICDATE1,GENERICATTRIBUTE9)
    Select
        DEPO.PERIODSEQ,
		iperiod,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        sum(depo.VALUE),
        TMP_PDS.PDS,
        --TMP_PDS.PAR_PROVEEDOR, 
		TMP_CONTRA.COD_PROVEEDOR, -- se informa el número código proveedor E4E	
        TMP_PDS.TIPO_IMPOSITIVO,
        TMP_CONTRA.COD_CONTRATO, 
        TMP_CONTRA.POS_DOC, 
        TMP_CONTRA.TEXTO_BREVE, 
        --TMP_CONTRA.ORG_COMPRAS,
		TMP_PROV.ORG_VENTAS, --MPR se modifica para que coga el ORG_Compras
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
        BU.NAME AS BUSINESS_UNIT,
		DEPO.LINEA_NEGOCIO,
		DEPO.TIPO, 
		DEPO.GENERICATTRIBUTE1 AS CAMPANIA,
		TMP_PROV.NOM_SOLICITANTE,
		TMP_CONTRA.POS_ORDEN,
		TMP_CONTRA.LINEA_SERVICIO,
          DEPO.GENERICDATE1, --DMS 28.06.2024
        DEPO.GENERICATTRIBUTE9 --DMS 28.06.2024
          
    FROM  ENELEXT.enel_deposit_temp_CETVTA DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_CETVTA TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_TEMP_CETVTA TMP_CONTRA
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
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)

    GROUP BY 
        DEPO.PERIODSEQ, 
		iperiod,
        DEPO.POSITIONSEQ, 
        DEPO.PAYEESEQ, 
        TMP_PDS.PDS,
        --TMP_PDS.PAR_PROVEEDOR, 
		TMP_CONTRA.COD_PROVEEDOR,
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
        BU.NAME,
		DEPO.LINEA_NEGOCIO,
		DEPO.TIPO,
		DEPO.GENERICATTRIBUTE1,
		TMP_PROV.NOM_SOLICITANTE,
		TMP_CONTRA.POS_ORDEN,
		TMP_CONTRA.LINEA_SERVICIO,
          DEPO.GENERICDATE1, --DMS 28.06.2024
        DEPO.GENERICATTRIBUTE9 --DMS 28.06.2024
		;     
        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_TEMP_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TEMP_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_TEMP_CETVTA.',v_contador_debug);
end;

procedure p_Cabecera_Ficheros_E4E (  iperiod IN VARCHAR2, iFichero IN VARCHAR2 )
AS
    contador integer;  
begin
    w_debug('Inicio Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_CETVTA para fichero ' || iFichero ,  v_contador_debug);
    contador := 1;
    -- Registro de CABECERA 1 : lista de campos
    INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'CAMPO1','CAMPO2','CAMPO3','CAMPO4','CAMPO5','CAMPO6','CAMPO7','CAMPO8','CAMPO9',
		'CAMPO10','CAMPO11','CAMPO12','CAMPO13','CAMPO14','CAMPO15','CAMPO16','CAMPO17','CAMPO18','CAMPO19','CAMPO20','CAMPO21','CAMPO22',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 2 : CABECERA
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','CABECERA','Contrato','Fecha Pedido','','Sociedad','Cod. Proveedor','CECO Aprob.',
	'Org.Compras','Gr.Compras','Riesgo','Contract Manager','Sit.Trabajo','Nota Cab.','Interlocutor DP','Interlocutor EF','Descripcion Breve','Contract Supervisor','','','',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 3 : POSICION    
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
							   CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','POSICION','Contrato','','Pos. contrato','Tipo Imp.','Codigo','Texto breve',
	'Texto posicion','Cantidad','Unidad medida','Fecha entrega','Centro log.','Imputacion','Tipo impuesto','Ref. para proveedor','Num. Direccion',
	'Direccion','Poblacion','Cod. postal','Nom. solicitante',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 4 : SERVICIO
    contador := contador +1;
    INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
							   CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','SERVICIO','Contrato','','Pos. contrato','Linea. Servicio','Cod. Servicio','Texto breve',
	'Cantidad','Imputacion','','','','','','','','','','','',iFichero, 'BUSINESSUNIT');        

    COMMIT;
    w_debug('Fin Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_CETVTA para fichero ' || iFichero ,  v_contador_debug);
    
end;

procedure p_Final_E4E_1 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
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
	v_campania VARCHAR2(5);
	v_mes VARCHAR2(5);
	--MPR nuevas variables para el incluir el código de prefactura
	v_cod_prefactura VARCHAR2(50);
	v_txtMes_Liquidacion VARCHAR(10);
	v_aux VARCHAR(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_CETVTA.', v_contador_debug);
   
    --v_codFichero :='E4E1';  -- v2.0 se asigna el valor dinamicamente en funcion de la actividad del proveedor
        
	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL_CETVTA WHERE ....';
	BEGIN
		LOOP
			DELETE FROM ENEL_E4E_FINAL_CETVTA WHERE PERIODO = iperiod AND FICHERO like 'E%1' AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_CETVTA.', v_contador_debug);
    
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
    w_debug('Inicio Borrado de la tabla ENEL_AGR_FAC_E4E_FINAL_CES.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENEL_AGR_FAC_E4E_FINAL_CES WHERE PERIODO = iperiod AND CANAL = 'TVTA' AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;    
    w_debug('Fin Borrado de la tabla ENEL_AGR_FAC_E4E_FINAL_CES.', v_contador_debug);
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    v_fechaInicio := f_fecha_inicio(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el anio YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
	v_txtMes_Liquidacion := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_CETVTA. Fichero ' || v_codFichero ,  v_contador_debug);
    
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
				SUBPOSICION,
				BUSINESSUNIT,
				SUBSTR(LINEA_NEGOCIO, 1, 1) as LINEA_NEGOCIO,
				TIPO,
				SUBSTR(CAMPANIA, 1, 1) as CAMPANIA,
				NOM_SOLICITANTE,
				POS_ORDEN,
				LINEA_SERVICIO,
                  GENERICDATE1, --DMS 27.06.2024
                GENERICATTRIBUTE9 --DMS 28.06.2024
            FROM ENEL_E4E_DEPOSIT_TEMP_CETVTA
            WHERE PERIODSEQ = iperiodseq 
				AND COD_CONTRATO is not null      -- Fichero E4E1 contiene los registros con contrato
				AND VALUE > 0                     -- Fichero E4E se incluyen solo los positivos 
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
				SUBSTR(LINEA_NEGOCIO, 1, 1),
				TIPO,
				SUBSTR(CAMPANIA, 1, 1),
				NOM_SOLICITANTE,
				POS_ORDEN,
				LINEA_SERVICIO,
                  GENERICDATE1, --DMS 27.06.2024
                GENERICATTRIBUTE9 --DMS 28.06.2024
			order by pds, linea_negocio, campania, tipo;
        
            REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP        
            -- Codigo de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
				WHEN 'Clientes Empresa' THEN v_codFichero :='E4E1';
                ELSE                     v_codFichero :='NOT1';
            END CASE;
			
			v_mes := to_char(v_fechaInicio,'MM');
            v_txtYear := to_char(v_fechaInicio, 'YY');
            -- Se concatenan los valores que forman el codigo de referencia:
            -- YY + Codigo de proveedor + Linea de Negocio + Campania + Tipo + Mes
            v_referencia := REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO || v_mes || v_txtYear ;
			
			CASE 
				WHEN REGDEPOSITO.TIPO like 'I%' THEN v_aux := 'I' || REGDEPOSITO.LINEA_NEGOCIO;
				WHEN REGDEPOSITO.TIPO like 'PF' and REGDEPOSITO.BUSINESSUNIT = 'CEBP' THEN v_aux := 'PF'; -- NO MODIFICAR
				WHEN REGDEPOSITO.LINEA_NEGOCIO = 'B' THEN v_aux := REGDEPOSITO.LINEA_NEGOCIO;
				WHEN REGDEPOSITO.LINEA_NEGOCIO = 'D' THEN v_aux := REGDEPOSITO.LINEA_NEGOCIO;
				ELSE v_aux := REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA;
			END CASE;

			-- MPR se incluye en el campo 17 el código de la prefactura
			--CREDTMP.BU_NAME || v_txtMes_Liquidacion || TMP_PDS.PDS as NUMERO_RESUMEN 
			v_cod_prefactura := REGDEPOSITO.BUSINESSUNIT || v_txtMes_Liquidacion || REGDEPOSITO.PDS || v_aux; 
			
            -- Se determina el codigo de equivalencia del tipo impositivo
            if (v_fechaInicio>= to_date('01/01/2017','dd/mm/yyyy') AND v_fechaInicio <=to_date('28/02/2019', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := 'SD';
                END CASE;
            END IF;
            
            if (v_fechaInicio>= to_date('01/03/2019','dd/mm/yyyy')  AND v_fechaInicio <=to_date('30/11/2019','dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO 
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA PTG'      THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := 'SD';
                END CASE;
            END IF;
            
			if (v_fechaInicio>= to_date('01/12/2019','dd/mm/yyyy') AND v_fechaInicio <=to_date('01/01/2200', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA PTG'      THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := 'SD';
                END CASE;
            END IF;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
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
                
                INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITO.COD_CONTRATO,
						--v_txtFechaInicio,
						  --OLD DMS 27.06.2024
						--v_txtFechaActual,
                        --NEW DMS 27.06.2024
                       substr(to_char(REGDEPOSITO.GENERICDATE1),4,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),1,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),7,4),
						'',
						REGDEPOSITO.SOCIEDAD,
						REGDEPOSITO.PAR_PROVEEDOR,
						REGDEPOSITO.CECO,
						REGDEPOSITO.ORG_COMPRAS,
						REGDEPOSITO.GR_COMPRAS,
						'NO',
						'ES03101242Z', --dms 28.06.2024
						'NI',
						'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.GENERICATTRIBUTE9, --DMS 28.06.2024,
                        '','','',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);
	
			ELSIF v_cabecera <> REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO then      
				-- Registro de DATOS - CABECERA
				IF v_codFichero = 'E4E1' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
				ELSIF v_codFichero = 'ECS1' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
				END IF;    
            
				INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', --3 
						REGDEPOSITO.COD_CONTRATO, --4
						--v_txtFechaInicio,
						  --OLD DMS 27.06.2024
						--v_txtFechaActual,
                        --NEW DMS 27.06.2024
                        substr(to_char(REGDEPOSITO.GENERICDATE1),4,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),1,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),7,4),
						'',
						REGDEPOSITO.SOCIEDAD,
						REGDEPOSITO.PAR_PROVEEDOR,
						REGDEPOSITO.CECO,
						REGDEPOSITO.ORG_COMPRAS,
						REGDEPOSITO.GR_COMPRAS,
						'NO',
						'ES03101242Z', --dms 28.06.2024
						'NI',
						'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.GENERICATTRIBUTE9, --DMS 28.06.2024,
                        '','','',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);
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
			
            INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
			VALUES ( iperiod,
					contadorTabla,
					v_referencia,    --CAMPO1
					'10',
					--contadorPosicion,
					--REGDEPOSITO.POS_ORDEN,
					'POSICION', 
					REGDEPOSITO.COD_CONTRATO, --CAMPO4
					'',
					REGDEPOSITO.POS_DOC,
					'P',                      --CAMPO7
					'',
					--REGDEPOSITO.TEXTO_BREVE,  
					REGDEPOSITO.SUBPOSICION, --CAMPO9
					REGDEPOSITO.DESCRIPCION,  --CAMPO10
					-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
                    /*BOM APM 11.07.2024 Old Code*/
					--CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
                    --New Code
                    CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE TRIM(replace(to_char(REGDEPOSITO.VALUE , '9999999999990D99'), '.', ',')) END,  --CAMPO11
                    /*EOM APM 11.07.2024*/
					'EURO',
					  --OLD DMS 27.06.2024
						v_txtFechaActual,
                        --NEW DMS 27.06.2024
                       -- REGDEPOSITO.GENERICDATE1,
					REGDEPOSITO.CENTRO_LOGISTICO,
					REGDEPOSITO.WBE_FINAL_IMPUTACION,
					v_Impuesto,
					v_cod_prefactura,-- incluir el código prefactura
					'','','','',REGDEPOSITO.NOM_SOLICITANTE,v_codFichero,
					REGDEPOSITO.BUSINESSUNIT);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - POSICION
                IF v_codFichero = 'E4E1' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
                END IF; 
                
				INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						--'10',
						contadorPosicion,
						--REGDEPOSITO.POS_ORDEN,
						'SERVICIO', 
						REGDEPOSITO.COD_CONTRATO,
						'',
						REGDEPOSITO.POS_DOC,  -- CAMPO6
						--CASE WHEN REGDEPOSITO.SUBPOSICION IS NULL THEN '10' ELSE REGDEPOSITO.SUBPOSICION END, 
						-- MPR se MODIFICA PAR QUE GUARDE LA LINEA DE SERVICIO DEL CONTRATO
						REGDEPOSITO.LINEA_SERVICIO, -- CAMPO7
						REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
						REGDEPOSITO.TEXTO_BREVE,
						--to_char(REGDEPOSITO.VALUE), 
						-- MPR se modifica el formato del valor
						TRIM(replace(to_char(REGDEPOSITO.VALUE , '9999999999990D99'), '.', ',')), --CAMPO10
						REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
						'', '', '', '',                    -- CAMPO12 a 15
						'', '', '', '',                    -- CAMPO16 a 19
						'', '', '',                        -- CAMPO20 a 22
						v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);
                        
                        -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
                        INSERT INTO ENELEXT.ENEL_AGR_FAC_E4E_FINAL_CES  (PERIODO, PDS, IMPORTE_NUM, DET_ORDEN, CANAL, LINEA_NEGOCIO)
                        VALUES ( iperiod,
                                v_cod_prefactura,
                                REGDEPOSITO.VALUE,
                                v_referencia,
                                'TVTA',
                                SUBSTR(REGDEPOSITO.DESCRIPCION, 1, INSTR(REGDEPOSITO.DESCRIPCION, ' ')-1 )
                        );
                        -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021
            END IF;
            
            v_cabecera := REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO;
                       
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
        
	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_CETVTA:  E4E1 '|| to_char(contadorE4E) || ' -- ECS1 '|| to_char(contadorECS) || ' filas.', v_contador_debug);
end;

procedure p_Final_E4E_2 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
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
	v_campania VARCHAR2(5);
	v_mes VARCHAR2(5);
	--MPR nuevas variables para el incluir el código de prefactura
	v_cod_prefactura VARCHAR2(50);
	v_txtMes_Liquidacion VARCHAR(10);
	v_aux VARCHAR(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_CETVTA.', v_contador_debug);
        
    --v_codFichero :='E4E2'; -- v2.0 se asigna el valor dinamicamente en funcion de la actividad del proveedor

	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL_CETVTA WHERE ....';
	BEGIN
		LOOP
			DELETE FROM ENEL_E4E_FINAL_CETVTA WHERE PERIODO = iperiod AND FICHERO like 'E%2'  AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_CETVTA.', v_contador_debug);
    
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
    /*w_debug('Inicio Borrado de la tabla ENEL_AGR_FAC_E4E_FINAL_CES.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENEL_AGR_FAC_E4E_FINAL_CES WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;    
    w_debug('Fin Borrado de la tabla ENEL_AGR_FAC_E4E_FINAL_CES.', v_contador_debug);*/
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    v_fechaInicio := f_fecha_inicio(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el anio YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
	v_txtMes_Liquidacion := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_CETVTA. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_CETVTA. Fichero ' || v_codFichero ,  v_contador_debug);
    
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
				SUBPOSICION,
				BUSINESSUNIT,
				SUBSTR(LINEA_NEGOCIO, 1, 1) as LINEA_NEGOCIO,
				TIPO,
				SUBSTR(CAMPANIA, 1, 1) as CAMPANIA,
				NOM_SOLICITANTE,
				POS_ORDEN,
				LINEA_SERVICIO,
                 GENERICDATE1, --DMS 27.06.2024
                   GENERICATTRIBUTE9 --DMS 28.06.2024
            FROM ENEL_E4E_DEPOSIT_TEMP_CETVTA
            WHERE PERIODSEQ = iperiodseq 
                  AND COD_CONTRATO is null          -- Fichero E4E2 contiene los registros sin contrato (valor nulo)
                  AND VALUE > 0                     -- Fichero E4E se incluyen solo los positivos
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
				SUBSTR(LINEA_NEGOCIO, 1, 1),
				TIPO,
				SUBSTR(CAMPANIA, 1, 1),
				NOM_SOLICITANTE,
				POS_ORDEN,
				LINEA_SERVICIO,
                 GENERICDATE1, --DMS 27.06.2024
                   GENERICATTRIBUTE9 --DMS 28.06.2024
			order by pds, linea_negocio, campania, tipo;
          
            REGDEPOSITO C_TMPDEPOSITOS%ROWTYPE;
            
    BEGIN
        OPEN C_TMPDEPOSITOS;
        FETCH C_TMPDEPOSITOS INTO REGDEPOSITO;
        
        WHILE C_TMPDEPOSITOS%FOUND
        LOOP
            -- Codigo de fichero
            CASE REGDEPOSITO.ACTIVIDAD 
				WHEN 'Clientes Empresa' THEN v_codFichero :='E4E2';
                ELSE                     	v_codFichero :='NOT2';
            END CASE;
			
			v_mes := to_char(v_fechaInicio,'MM');
            v_txtYear := to_char(v_fechaInicio, 'YY');
            -- Se concatenan los valores que forman el codigo de referencia:
            --    YY + Codigo de proveedor + Linea de Negocio + Campania + Tipo + Mes
            v_referencia := REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO || v_mes || v_txtYear;
            
			CASE 
				WHEN REGDEPOSITO.TIPO like 'I%' THEN v_aux := 'I' || REGDEPOSITO.LINEA_NEGOCIO;
				WHEN REGDEPOSITO.TIPO like 'PF' and REGDEPOSITO.BUSINESSUNIT = 'CEBP' THEN v_aux := 'PF'; -- NO MODIFICAR
				WHEN REGDEPOSITO.LINEA_NEGOCIO = 'B' THEN v_aux := REGDEPOSITO.LINEA_NEGOCIO;
				WHEN REGDEPOSITO.LINEA_NEGOCIO = 'D' THEN v_aux := REGDEPOSITO.LINEA_NEGOCIO;
				ELSE v_aux := REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA;
			END CASE;
			-- MPR se incluye en el campo 17 el código de la prefactura
			--CREDTMP.BU_NAME || v_txtMes_Liquidacion || TMP_PDS.PDS as NUMERO_RESUMEN 
			v_cod_prefactura := REGDEPOSITO.BUSINESSUNIT || v_txtMes_Liquidacion || REGDEPOSITO.PDS || v_aux;
			
            -- Se determina el codigo de equivalencia del tipo impositivo
            if (v_fechaInicio>= to_date('01/01/2017','dd/mm/yyyy') AND v_fechaInicio <=to_date('28/02/2019', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA Portugal' THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := 'SD';
                END CASE;
            END IF;
            
            if (v_fechaInicio>= to_date('01/03/2019','dd/mm/yyyy')  AND v_fechaInicio <=to_date('30/11/2019','dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO 
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CG';
                    WHEN 'IVA PTG' 		THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := 'SD';
                END CASE;
            END IF;
            
			if (v_fechaInicio>= to_date('01/12/2019','dd/mm/yyyy') AND v_fechaInicio <=to_date('01/01/2200', 'dd/mm/yyyy')) THEN
                CASE REGDEPOSITO.TIPO_IMPOSITIVO
                    WHEN 'IVA'          THEN v_Impuesto := 'SD';
                    WHEN 'IGIC'         THEN v_Impuesto := 'CB';
                    WHEN 'IVA PTG' 		THEN v_Impuesto := 'KK';
                    ELSE                     v_Impuesto := 'SD';
                END CASE;
            END IF;
            
            -- Se determina la fecha de inicio
            IF REGDEPOSITO.POS_FECHA_INI_VIGENCIA > v_fechaInicioPeriodo THEN
                v_txtFechaInicio := to_char(REGDEPOSITO.POS_FECHA_INI_VIGENCIA, 'DD/MM/YYYY');
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
                             
                INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITO.COD_CONTRATO,
						--v_txtFechaInicio,
						  --OLD DMS 27.06.2024
						--v_txtFechaActual,
                        --NEW DMS 27.06.2024
                        substr(to_char(REGDEPOSITO.GENERICDATE1),4,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),1,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),7,4),
						'',
						REGDEPOSITO.SOCIEDAD,
						REGDEPOSITO.PAR_PROVEEDOR,
						REGDEPOSITO.CECO,
						REGDEPOSITO.ORG_COMPRAS,
						REGDEPOSITO.GR_COMPRAS,
						'NO',
						'ES03101242Z', --dms 28.06.2024
						'NI',
						'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.GENERICATTRIBUTE9, --DMS 28.06.2024,
                        '','','',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);

            ELSIF v_cabecera <> REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO then
                -- Registro de DATOS - CABECERA
                IF v_codFichero = 'E4E2' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;          
                             
                INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                           CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						'',
						'CABECERA', 
						REGDEPOSITO.COD_CONTRATO,
						--v_txtFechaInicio,
						  --OLD DMS 27.06.2024
						--v_txtFechaActual,
                        --NEW DMS 27.06.2024
                        substr(to_char(REGDEPOSITO.GENERICDATE1),4,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),1,2)||'/'||substr(to_char(REGDEPOSITO.GENERICDATE1),7,4),
						'',
						REGDEPOSITO.SOCIEDAD,
						REGDEPOSITO.PAR_PROVEEDOR,
						REGDEPOSITO.CECO,
						REGDEPOSITO.ORG_COMPRAS,
						REGDEPOSITO.GR_COMPRAS,
						'NO',
						'ES03101242Z', --dms 28.06.2024
						'NI',
						'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        REGDEPOSITO.PAR_PROVEEDOR,--DMS 28.06.2024,
                        'Facturación CE '|| CASE WHEN REGDEPOSITO.PDS >= 4000 THEN 'PUSH '
                        WHEN REGDEPOSITO.TIPO = 'PF' THEN 'Fijo '
                        ELSE 'Variable ' END || IPERIOD,
                        REGDEPOSITO.GENERICATTRIBUTE9, --DMS 28.06.2024,
                        '','','',v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);
						
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
            
            INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
			VALUES ( iperiod,
					contadorTabla,
					v_referencia,
					'10',
					--contadorPosicion,
					--REGDEPOSITO.POS_ORDEN,
					'POSICION', 
					REGDEPOSITO.COD_CONTRATO,
					'',
					REGDEPOSITO.POS_DOC,
					'P',
					'',
					--REGDEPOSITO.TEXTO_BREVE,
					REGDEPOSITO.SUBPOSICION ,
					REGDEPOSITO.DESCRIPCION,
					-- CAMPO 11 es 1 cuando hay linea de SERVICIO y si no contiene el importe
					CASE WHEN REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN '1' ELSE to_char(REGDEPOSITO.VALUE) END,  --CAMPO11
					'EURO',
					  --OLD DMS 27.06.2024
						v_txtFechaActual,
                        --NEW DMS 27.06.2024
                       -- REGDEPOSITO.GENERICDATE1,
					REGDEPOSITO.CENTRO_LOGISTICO,
					REGDEPOSITO.WBE_FINAL_IMPUTACION,
					v_Impuesto,
					v_cod_prefactura,-- incluir el código prefactura
					'','','','',REGDEPOSITO.NOM_SOLICITANTE,v_codFichero,
					REGDEPOSITO.BUSINESSUNIT);            

            IF REGDEPOSITO.TIPO_PAGO = 'SERVICIO' THEN
                -- Registro de DATOS - servicio
				IF v_codFichero = 'E4E2' then
					contadorE4E := contadorE4E +1;
					contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS2' then
					contadorECS := contadorECS +1;
					contadorTabla := contadorECS;
                END IF;
             
                INSERT INTO ENEL_E4E_FINAL_CETVTA (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
				VALUES ( iperiod,
						contadorTabla,
						v_referencia,
						--'10',
						contadorPosicion,
						--REGDEPOSITO.POS_ORDEN,
						'SERVICIO', 
						REGDEPOSITO.COD_CONTRATO,
						'',
						REGDEPOSITO.POS_DOC,  -- CAMPO6
						-- MPR se MODIFICA PAR QUE GUARDE LA LINEA DE SERVICIO DEL CONTRATO
						REGDEPOSITO.LINEA_SERVICIO, -- CAMPO7
						REGDEPOSITO.CODIGO_SERVICIO,  --CAMPO8
						REGDEPOSITO.TEXTO_BREVE,
						--to_char(REGDEPOSITO.VALUE), 
						-- MPR se modifica el formato del valor
						TRIM(replace(to_char(REGDEPOSITO.VALUE , '9999999999990D99'), '.', ',')), --CAMPO10
						REGDEPOSITO.WBE_FINAL_IMPUTACION, -- CAMPO11
						'', '', '', '',                    -- CAMPO12 a 15
						'', '', '', '',                    -- CAMPO16 a 19
						'', '', '',                        -- CAMPO20 a 22
						v_codFichero,
						REGDEPOSITO.BUSINESSUNIT);
                        
                        -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
                        INSERT INTO ENELEXT.ENEL_AGR_FAC_E4E_FINAL_CES  (PERIODO, PDS, IMPORTE_NUM, DET_ORDEN, CANAL, LINEA_NEGOCIO)
                        VALUES ( iperiod,
                                v_cod_prefactura,
                                REGDEPOSITO.VALUE,
                                v_referencia,
                                'TVTA',
                                SUBSTR(REGDEPOSITO.DESCRIPCION, 1, INSTR(REGDEPOSITO.DESCRIPCION, ' ')-1 )
                        );
                        -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021

            END IF;
            
            v_cabecera := REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO;
                        
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
    
	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_CETVTA:  E4E2 '|| to_char(contadorE4E) || ' -- ECS2 '|| to_char(contadorECS) || ' filas.', v_contador_debug);
    
end;

procedure p_Final_E4E_Negativos ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodoSig date;
    v_fechaInicio date;
    v_txtFechaInicioPeriodoSig VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(1);
    v_mes VARCHAR2(5);
    v_maxIDPEDIDO integer;
	v_txtMes_Liquidacion VARCHAR2(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_E4E_NEGATIVOS_CES.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_NEGATIVOS_CES.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    v_fechaInicio := f_fecha_inicio(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodoSig := to_char(v_fechaInicioPeriodoSig, 'DD/MM/YYYY');
    
    -- Se convierte a texto el anio YY para el codigo de referencia
    v_txtYear := to_char(v_fechaInicioPeriodoSig, 'YY');
    
    -- Se extrae el codigo asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodoSig);
    
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
	
	v_txtMes_Liquidacion := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodoSig ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    select NVL(MAX(IDPEDIDO),0) into v_maxIDPEDIDO  from ENEL_E4E_NEGATIVOS_CES WHERE ESTADO='LIQUIDADO';
    w_debug('Numero maximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) ,  v_contador_debug);
    
    v_mes := to_char(v_fechaInicio,'MM');
    v_txtYear := to_char(v_fechaInicio, 'YY');

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_NEGATIVOS_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_CES ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, PDS, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
                                              SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
                                              CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
                                              CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION, TIPO, LINEA_NEGOCIO, CANAL_PDS, NOMBRE_FISCAL, PROCESSINGUNITSEQ   )   
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
        --v_txtYear || e4edt.PDS || e4edt.IDPROVEEDOR || v_mes as NUM_PEDIDO,
		e4edt.BU_NAME || v_txtMes_Liquidacion || e4edt.PDS as NUM_PEDIDO,  -- BUYYYYMMPDS
        v_txtFechaActual FechaPedido,
        v_txtFechaActual FechaFactura, 
        e4edt.CONDICIONES_PAGO,
        '' ContratoSEPA,
        '' MotivoPedido,
        'EUR' MONEDA,
        '10' POSICION,
        e4edt.SOCIEDAD MATERIAL,
        e4edt.SOCIEDAD TEXTO_MATERIAL,
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
		TIPO,
		LINEA_NEGOCIO,
		e4edt.CANAL_PDS,
		e4edt.NOMBRE_FISCAL,
		iprocessingUnitSeq

    FROM ENEL_E4E_NEGATIVOS_TEMP_CETVTA e4edt 
    
    WHERE 
        e4edt.VALUE < 0  and 
		e4edt.BU_NAME is not null and
        e4edt.PERIODSEQ = iperiodseq;
               
     filas := sql%rowcount;
     COMMIT;
    
     w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_CES: '|| to_char(filas) || ' filas.', v_contador_debug);
     EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_NEGATIVOS_CES COMPUTE STATISTICS FOR ALL INDEXES';
     w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_CES.',v_contador_debug);         
end;        

---------------- Se Actualiza la tabla para el informe de Liquidacion para el periodo indicado -------------
procedure p_Liquidacion_Final (  iprocessingUnitSeq IN VARCHAR2,  iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    vFechaAlta Date;
    v_fecInicioPeriodoSig date;
begin
    w_debug('Inicio Borrado de la tabla ENEL_LIQUIDACION_CETVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQUIDACION_CETVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_LIQUIDACION_CETVTA.', v_contador_debug);
    
    -- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := SYSDATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fecInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    w_debug('Insertando CREDITOS de datos en tabla ENEL_LIQUIDACION_CETVTA.' ,  v_contador_debug);
    -- v2.0 Se cambia la tabla de origen CS_CREDIT  a la temporal ENEL_CREDIT_TEMP
    INSERT INTO ENELEXT.ENEL_LIQUIDACION_CETVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, OBSERVACIONES, REALVALUE, DESCRIPCION_PROVEEDOR)   
    SELECT 
        iperiod PERIODO,        
        to_number(REPLACE(credtmp.GENERICATTRIBUTE4, 'integer','')) PROVEEDOR,             
        to_char(v_fecInicioPeriodoSig, 'YYYY'),  				-- Anio del periodo sigiente
        to_char(v_fecInicioPeriodoSig, 'MM'),  					-- Mes del periodo sigiente
        tmp_pds.pds,      										-- Prestador - PDS
        credtmp.GENERICATTRIBUTE1,      						-- Concepto Liquidacion
        1 as CANTIDAD,
        credtmp.VALUE,                  						--Importe Credito
        to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
        '' as FechaBaja,
        credtmp.GENERICATTRIBUTE15 as Observaciones,
        credtmp.VALUE as REALVALUE,
		TMP_PROV.DESCRIPCION

    FROM ENEL_CREDIT_TEMP_CETVTA credtmp
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
            ON credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
		LEFT JOIN ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV
			ON CREDTMP.GENERICATTRIBUTE4 = TMP_PROV.IDPROVEEDOR
                      
    WHERE 
        credtmp.GENERICBOOLEAN1 = 1   							-- Indica los creditos que se incluyen en pagos
        and credtmp.GENERICATTRIBUTE1 is not null 				-- Solo se  incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)
        ;
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_LIQUIDACION_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando INCENTIVOS de datos en tabla ENEL_LIQUIDACION_CETVTA.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_LIQUIDACION_CETVTA ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
												IMPORTE, FECHA_ALTA, FECHA_BAJA, OBSERVACIONES, REALVALUE, DESCRIPCION_PROVEEDOR )   
    SELECT 
        iperiod PERIODO,        
        TO_NUMBER(INCENTMP.GENERICATTRIBUTE3),   			-- Proveedor en formato numerico, sin ceros a la izquierda             
        TO_CHAR(v_fecInicioPeriodoSig, 'YYYY'),  			-- Anio del periodo sigiente
        TO_CHAR(v_fecInicioPeriodoSig, 'MM'),  				-- Mes del periodo sigiente
        TMP_PDS.PDS ,      									-- Prestador - PDS
        INCENTMP.GENERICATTRIBUTE1,      					-- Concepto Retributivo
        1 AS CANTIDAD,
        INCENTMP.VALUE,
        TO_CHAR(vFechaAlta, 'YYYYMMDD') AS FechaAlta,
        '' AS FechaBaja,
        '' AS Observaciones, 
        INCENTMP.VALUE  AS REALVALUE, 
        TMP_PROV.DESCRIPCION
		
    FROM ENEL_INCEN_TEMP_CETVTA INCENTMP    
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON INCENTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
		LEFT JOIN ENELEXT.ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV
			ON INCENTMP.GENERICATTRIBUTE3 = TMP_PROV.IDPROVEEDOR
             
    WHERE    
        INCENTMP.GENERICBOOLEAN1 = 1 						-- Indica los Incentivos que se incluyen en pagos
        AND INCENTMP.GENERICATTRIBUTE1 IS NOT NULL  		-- Solo se incluyen los creditos con Concepto de Liquidacion que no son vacios (nulos)  
        ;

    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_LIQUIDACION_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_LIQUIDACION_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQUIDACION_CETVTA.',v_contador_debug);
end;

-- TABLAS PARA INFORME CUADRE_LIQUIDACIoN                    
procedure p_Cuadre_Liquidacion ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
	v_anio VARCHAR(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_CUADRELIQ_FINAL_CES.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CUADRELIQ_FINAL_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_CUADRELIQ_FINAL_CES.', v_contador_debug);
	
	w_debug('Inicio Borrado de la tabla ENEL_DET_INCENTIVOS_CES.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_DET_INCENTIVOS_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_DET_INCENTIVOS_CES.', v_contador_debug);

	v_anio := to_char(f_fecha_inicio(iperiodseq),'YYYY');
	
	v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
	
    w_debug('Insertando Registros de datos en tabla ENEL_CUADRELIQ_FINAL_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CUADRELIQ_FINAL_CES (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, 
													CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, 
													ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO, CAMPANIA, TARIFA, CONSUMO, DESCUENTO, POTENCIA, PVP,
													NOMBRE_FISCAL, LINEA_NEGOCIO, FECHA_INSERCION, FECHA_FIRMA, PROCESSINGUNITSEQ, CANAL, OFERTA, AGENTE, COMENTARIOS, ANIO, 
													CUPS, CIF, NOMBRE_CLIENTE, SEGMENTO, PROVINCIA, TERRITORIO, CONSUMO_TXN, COMPONENTE, PAYEESEQ, POSITIONSEQ, CONDICION_MULTIPUNTO,CONTRATO,
                                                    DECOMISION, SS_GARANTIA, TIPO_SERVICIO, --APM 29.05.2024 --APM 18.07.2024 --APM 05.11.2024
                                                    GESTION_CARTERA,FECHA_ALTA,FECHA_BAJA,FECHAVENTA) --APM 07.11.2024 DMS 21.05.2025
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        TRIM(to_char(ECT.VALUE , '9999999999990D99')) IMPORTE_COMISION,
        'EURO',
        TRIM(to_char(ECT.GENERICNUMBER2 , '9999999999990D99')) VALOR_1,
        'EURO',
        ETT.PRODUCTID,    							-- ID Producto SCA Web
        TMP_PDS.PAYEEID,    						-- Codigo de PDS/OCAP
        v_txtFechaLiquidacion,						-- CICLO facturacion - Pte confirmar formato
        case 
            when ECT.VALUE is null then 'Pte Revisar'
            when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ETT.GENERICATTRIBUTE3,
		ect.name,
		ECT.GENERICATTRIBUTE8,
		ETT.GENERICATTRIBUTE32 as CAMPANIA,
		ETT.TEX0_GENERICATTRIBUTE15 as TARIFA,
		ECT.GENERICNUMBER4 as CONSUMO,
		ETT.GENERICNUMBER4 as DESCUENTO,
		ETT.TEX0_GENERICNUMBER9 as POTENCIA,
		ETT.GENERICNUMBER5 as PVP,
		TMP_PDS.NOMBRE_FISCAL,
		ECT.GENERICATTRIBUTE2 AS LINEA_NEGOCIO,
		CASE WHEN (ETT.TEX0_GENERICDATE1 is NULL) THEN
            ETT.GENERICDATE3 
            ELSE
            ETT.TEX0_GENERICDATE1 
            END AS FECHA_INSERCION,
		ETT.GENERICDATE3 AS FECHA_FIRMA,
		iprocessingUnitSeq,
		ECT.BU_NAME AS CANAL,
		ECT.GENERICATTRIBUTE6 AS OFERTA,
		ETT.GENERICATTRIBUTE19 AS AGENTE,
		ECT.GENERICATTRIBUTE15 AS COMENTARIOS,
		v_anio, 
		ETT.ALTERNATEORDERNUMBER as CUPS,
		ETT.GENERICATTRIBUTE29 as CIF,
		ETT.GENERICATTRIBUTE27 as NOMBRE_CLIENTE,
		ETT.CHANNEL AS SEGMENTO,
		ETT.TAD_CITY AS PROVINCIA,
		ETT.TAD_STATE AS TERRITORIO,
		ETT.TEX0_GENERICNUMBER10 as CONSUMO_TXN, 
		ETT.GENERICATTRIBUTE26 as COMPONENTE,
		TMP_PDS.PAYEESEQ,
		TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
		ETT.GENERICATTRIBUTE21 as CONDICION_MULTIPUNTO,
        ETT.PONUMBER AS CONTRATO,
        ECT.GENERICNUMBER2 AS DECOMISION, --APM 29.05.2024
        ETT.GENERICBOOLEAN2 as SS_GARANTIA, --APM 18.07.2024
		ETT.GENERICATTRIBUTE1 AS TIPO_SERVICIO, --APM 05.11.2024
        ETT.GENERICBOOLEAN1 AS GESTION_CARTERA,  --APM 07.11.2024
        ETT.GENERICDATE4 AS FECHA_ALTA, --DMS 21.05.2025
        ETT.GENERICDATE5 AS FECHA_BAJA, --DMS 21.05.2025
        ECT.GENERICDATE1 AS FECHAVENTA
		
    FROM ENEL_TXN_TEMP_CETVTA ETT
        LEFT JOIN ENEL_CREDIT_TEMP_CETVTA ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE4
		LEFT JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
			ON ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
			
	--WHERE TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
	;

    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_CUADRELIQ_FINAL_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CUADRELIQ_FINAL_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CUADRELIQ_FINAL_CES.',v_contador_debug);
	
	w_debug('Insertando Registros de datos en tabla ENEL_DET_INCENTIVOS_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_DET_INCENTIVOS_CES (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, 
													CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, 
													ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO, CAMPANIA, TARIFA, CONSUMO, DESCUENTO, POTENCIA, PVP,
													NOMBRE_FISCAL, LINEA_NEGOCIO, FECHA_INSERCION, FECHA_FIRMA, PROCESSINGUNITSEQ, CANAL, OFERTA, AGENTE, COMENTARIOS, ANIO, 
													CUPS, CIF, NOMBRE_CLIENTE, SEGMENTO, PROVINCIA, TERRITORIO, CONSUMO_TXN, COMPONENTE, PAYEESEQ, POSITIONSEQ,contrato)
    SELECT 
        ETT.PERIODO,
        ETT.ORDERID,
        ETT.LINENUMBER,
        ETT.SUBLINENUMBER,
        ETT.EVENTYPEID,
        TRIM(to_char(COMMI.VALUE , '9999999999990D99')) IMPORTE_COMISION,
        'EURO',
        TRIM(to_char(ECT.GENERICNUMBER2 , '9999999999990D99')) VALOR_1,
        'EURO',
        ETT.PRODUCTID,    							-- ID Producto SCA Web
        TMP_PDS.PAYEEID,    						-- Codigo de PDS/OCAP
        v_txtFechaLiquidacion,						-- CICLO facturacion - Pte confirmar formato
        case 
            when COMMI.VALUE is null then 'Pte Revisar'
            when iInterfaz ='ACTUALIZA_INFORMES_POST' and COMMI.value is not null then 'Liquidado'
            else 'Pte Liquidar'
        end as Estado,
        TEMP_PROV.DESCRIPCION,
        TEMP_PROV.IDPROVEEDOR,
        ECT.GENERICATTRIBUTE3,
        ECT.CREDITTYPEID,
        ETT.GENERICATTRIBUTE3,
		ect.name,
		ECT.GENERICATTRIBUTE8,
		ETT.GENERICATTRIBUTE32 as CAMPANIA,
		ETT.TEX0_GENERICATTRIBUTE15 as TARIFA,
		ECT.GENERICNUMBER4 as CONSUMO,
		ETT.GENERICNUMBER4 as DESCUENTO,
		ETT.TEX0_GENERICNUMBER9 as POTENCIA,
		ETT.GENERICNUMBER5 as PVP,
		TMP_PDS.NOMBRE_FISCAL,
		ECT.GENERICATTRIBUTE2 AS LINEA_NEGOCIO,
		CASE WHEN (ETT.TEX0_GENERICDATE1 is NULL) THEN
            ETT.GENERICDATE3 
            ELSE
            ETT.TEX0_GENERICDATE1 
            END AS FECHA_INSERCION,
		ETT.GENERICDATE3 AS FECHA_FIRMA,
		iprocessingUnitSeq,
		ECT.BU_NAME AS CANAL,
		ECT.GENERICATTRIBUTE6 AS OFERTA,
		ETT.GENERICATTRIBUTE19 AS AGENTE,
		ECT.GENERICATTRIBUTE15 AS COMENTARIOS,
		v_anio, 
		ETT.ALTERNATEORDERNUMBER as CUPS,
		ETT.GENERICATTRIBUTE29 as CIF,
		ETT.GENERICATTRIBUTE27 as NOMBRE_CLIENTE,
		ETT.CHANNEL AS SEGMENTO,
		ETT.TAD_CITY AS PROVINCIA,
		ETT.TAD_STATE AS TERRITORIO,
		ETT.TEX0_GENERICNUMBER10 as CONSUMO_TXN, 
		ETT.GENERICATTRIBUTE26 as COMPONENTE,
		TMP_PDS.PAYEESEQ,
		TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
        ETT.PONUMBER AS CONTRATO
		
    FROM ENEL_TXN_TEMP_CETVTA ETT
        LEFT JOIN ENEL_CREDIT_TEMP_CETVTA ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ
        LEFT JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE4
		INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
			ON ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
		
		INNER JOIN cs_commission commi
			on commi.CREDITSEQ = ECT.creditseq
            and commi.payeeseq = ECT.payeeseq
    ;

    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_DET_INCENTIVOS_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_DET_INCENTIVOS_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DET_INCENTIVOS_CES.',v_contador_debug);
end;

-- pestaña precio base fijo
procedure p_remun (iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2)
as
	v_anio VARCHAR(10);
	v_txtMes_Liquidacion VARCHAR2(10);
	v_fechaActual date;
begin
    w_debug('Inicio Borrado de la tabla ENEL_REMUN_CES.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_REMUN_CES WHERE periodo=iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_REMUN_CES.', v_contador_debug);
   
	v_anio := to_char(f_fecha_inicio(iperiodseq),'YYYY');
	v_txtMes_Liquidacion := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
	
	IF iInterfaz =  'ACTUALIZA_INFORMES_POST'  THEN
		v_fechaActual := to_char(SYSDATE, 'DD/MM/YYYY');
    ELSE
		v_fechaActual := '';
    END IF;
	
    w_debug('Insertando Registros de datos en tabla ENEL_REMUN_CES.' ,  v_contador_debug);
	
    INSERT INTO ENELEXT.ENEL_REMUN_CES (PERIODO,NAME,VALUE,PAYEEID, PROCESSINGUNITSEQ, NOMBRE_FISCAL, CANAL, ANIO, PAYEESEQ, POSITIONSEQ, NUMERO_RESUMEN, CIF, PDS, 
										FECHA_LIQUIDACION, IVA, LINEA_NEGOCIO, CONCEPTO_LIQ, IDPROVEEDOR, TIPO_PRESTADOR)
    Select 
        EDT.periodo,
        EDT.name,
        TRIM(to_char(edt.VALUE , '9999999999990D99')) IMPORTE_COMISION,
        CSP.PAYEEID,
		iprocessingUnitSeq,
		CSP.NOMBRE_FISCAL,
		EDT.BU_NAME,
		v_anio,
		CSP.PAYEESEQ,
		CSP.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
		-- nuevos campos para informe de prefactura
		EDT.BU_NAME || v_txtMes_Liquidacion || CSP.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
        CSP.CIF,
		CSP.PDS,
		v_fechaActual as FECHA_LIQUIDACION, -- mdificar esta fecha cuando se lance el POST, mientras blanco
		CASE 
			WHEN CSP.TIPO_IMPOSITIVO = 'IVA' THEN 21
			WHEN CSP.TIPO_IMPOSITIVO = 'IGIC' THEN 7
			ELSE 21
		END AS IVA,
		EDT.GENERICATTRIBUTE2 as LINEA_NEGOCIO,
		EDT.GENERICATTRIBUTE6 as CONCEPTO_LIQ, 
		EDT.genericattribute3,
		CSP.TIPO_PRESTADOR
		
    from ENELEXT.ENEL_INCEN_TEMP_CETVTA edt
		INNER JOIN ENEL_PDS_TEMP_CETVTA CSP
            ON EDT.POSITIONSEQ=CSP.RULEELEMENTOWNERSEQ
    where 
		(name  like 'I - CE - % - Precio Base Fijo%');
--		and value > 0; 7feb22 Se solicita que aparezcan negativos en Cuadre Liq/Total Precio Base Fijo
	
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_REMUN_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_REMUN_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_REMUN_CES.',v_contador_debug);
end;       

procedure p_rappeles( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , iInterfaz IN VARCHAR2, iprocessingUnitSeq IN VARCHAR2)
as
    v_txtFechaLiquidacion VARCHAR2(10);
	v_anio VARCHAR(10);
begin
    w_debug('Inicio Borrado de la tabla ENEL_RAPPELES_CES.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_CES WHERE periodo = iperiod and PROCESSINGUNITSEQ = iprocessingUnitSeq and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;

    END;
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
        v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;    
    w_debug('Fin Borrado de la tabla ENEL_RAPPELES_CES.', v_contador_debug);
	
	v_anio := to_char(f_fecha_inicio(iperiodseq),'YYYY');
	
    w_debug('Insertando datos en tabla ENEL_RAPPELES_CES.' ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_RAPPELES_CES(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, IDPROVEEDOR, CONCEPTO, TRAMO, NOMBRE_FISCAL, PROCESSINGUNITSEQ, 
											CANAL, ANIO, REALIZADO, OBJETIVO, CONSECUCION, IMPORTE_UNITARIO, LINEA_NEGOCIO, CAMPANIA, PAYEESEQ, POSITIONSEQ,CIF_MES)     
    SELECT 
        iperiod,
        CSI.NAME,
        TRIM(to_char(csi.VALUE , '9999999999990D99')) IMPORTE_COMISION,
        TMP_PDS.PAYEEID,
        v_txtFechaLiquidacion,
        CSI.GENERICATTRIBUTE3,
        csi.GENERICATTRIBUTE1 as concepto,
        case 
			when csi.value = 0 then 'No comisiona por no llegar a objetivo'
			else 'Comisiona'
		end as tramo, -- nuevo campo de observaciones
		TMP_PDS.NOMBRE_FISCAL,
		iprocessingUnitSeq,
		CSI.BU_NAME,
		v_anio,
		CSI.genericnumber2 as realizado,
		CSI.genericnumber1 as objetivo,
		CSI.genericnumber3 as consecucion,
		CSI.genericnumber5 as importe_unitario,
		CSI.GENERICATTRIBUTE2 as linea_negocio,
		CSI.GENERICATTRIBUTE6 as campania,
		TMP_PDS.PAYEESEQ,
		TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
        CSI.GENERICNUMBER4 AS CIF_MES
		
    FROM ENELEXT.ENEL_INCEN_TEMP_CETVTA CSI
       	INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
			ON csi.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
  
    WHERE 
		CSI.periodseq = iperiodseq  
		--and value >0
		and CSI.GENERICBOOLEAN1 = 1 ;
     
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_RAPPELES_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RAPPELES_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_CES.',v_contador_debug);
end;

-- Tabla ENEL_CLASIFICACION_EVENTO_CES
procedure p_Clasificacion_Evento ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iprocessingUnitSeq IN VARCHAR2 )
AS
	v_primer_dia_periodo date;
    v_ultimo_dia_periodo date;
	v_anio VARCHAR(10);
begin
    w_debug('Inicio Truncado de la tabla ENEL_CLASIFICACION_EVENTO_CES.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CLASIFICACION_EVENTO_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
		
	END;
    w_debug('Fin Truncado de la tabla ENEL_CLASIFICACION_EVENTO_CES.', v_contador_debug);
	
	v_anio := to_char(f_fecha_inicio(iperiodseq),'YYYY');
    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);
	v_primer_dia_periodo := f_fecha_inicio(iperiodseq);

    w_debug('Cargando tabla ENEL_CLASIFICACION_EVENTO_CES. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
    INSERT INTO ENELEXT.ENEL_CLASIFICACION_EVENTO_CES(PERIODO, PROCESSINGUNITSEQ, CANAL, NOMBRE, FECHA_INICIO, FECHA_FIN, DIAS_TRABAJADOS, FIJO, IMPORTE_FACTURACION, BP, ANIO,
														DIAS_TRABAJADOS_CAP, DIAS_TRABAJADOS_RENOVA, DIAS_TRABAJADOS_PSVAS, DIAS_TRABAJADOS_MKT, DIAS)
    SELECT 
        iperiod,
		iprocessingUnitSeq,
		BU.NAME AS CANAL,
		C.CLASSIFIERID AS NOMBRE, 
		GC.GENERICDATE1 AS FECHA_INICIO,
		GC.GENERICDATE2 AS FECHA_FIN,
		GC.GENERICNUMBER1 AS DIAS_TRABAJADOS,
		GC.GENERICNUMBER6 AS FIJO,
		(GC.GENERICNUMBER1 * GC.GENERICNUMBER6) / (substr(v_ultimo_dia_periodo,0,2)) AS IMPORTE_FACTURACION,
		C.DESCRIPTION AS BP,
		v_anio,
		GC.GENERICNUMBER2 AS DIAS_TRABAJADOS_CAP,
		GC.GENERICNUMBER3 AS DIAS_TRABAJADOS_RENOVA,
		GC.GENERICNUMBER4 AS DIAS_TRABAJADOS_PSVAS,
		GC.GENERICNUMBER5 AS DIAS_TRABAJADOS_MKT,
		substr(v_ultimo_dia_periodo,0,2) as DIAS
            
    FROM CS_GENERICCLASSIFIERTYPE GCT
        INNER JOIN CS_CLASSIFIER C ON GCT.GENERICCLASSIFIERTYPESEQ = C.SELECTORID
            AND C.TENANTID = itenantId 
            AND C.REMOVEDATE = v_eot
            AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo            
        
        INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo      
				
		INNER JOIN CS_BUSINESSUNIT BU 
			ON C.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    WHERE GCT.NAME ='Evento'
        AND GCT.TENANTID = itenantId
		AND BU.PROCESSINGUNITSEQ = iprocessingUnitSeq
		AND C.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
		AND C.EFFECTIVEENDDATE >= v_ultimo_dia_periodo     
		;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CLASIFICACION_EVENTO_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CLASIFICACION_EVENTO_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CLASIFICACION_EVENTO_CES.',v_contador_debug);   
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
    w_debug('Inicio Borrado de la tabla ENEL_PREFACTURA_CETVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_PREFACTURA_CETVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_PREFACTURA_CETVTA.', v_contador_debug);
    
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
    w_debug('Inicio Borrado de la tabla ENEL_AGR_FAC_PREFACTURA_CES.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_AGR_FAC_PREFACTURA_CES WHERE PERIODO = iperiod AND CANAL = 'TVTA' AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_AGR_FAC_PREFACTURA_CES.', v_contador_debug);
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');
	v_txtMes_Liquidacion2 := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
    v_mesanio := to_char(f_fecha_inicio(iperiodseq), 'MMYY');
	
	-- SI iInterfaz es 'ACTUALIZA_INFORMES_POST' se está generando el fichero definitivo de LIQUIDACION '
    --iInterfaz
    IF iInterfaz =  'ACTUALIZA_INFORMES_POST'  THEN
		v_fechaActual := to_char(SYSDATE, 'DD/MM/YYYY');
    ELSE
		v_fechaActual := '';
    END IF;

    w_debug('Insertando Registros de CREDITOS en tabla ENEL_PREFACTURA_CETVTA.' ,  v_contador_debug);
   
    INSERT INTO ENELEXT.ENEL_PREFACTURA_CETVTA ( PERIODO, PERIODSEQ, MES_LIQUIDACION, FECHA_LIQUIDACION, PDS, NUMERO_RESUMEN, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION,
												CONCEPTO_LIQ, TARIFA, IMPORTE_COMISION, VALUE, CONSUMO, DESCUENTO, PRODUCTO, BU_NAME, PAYEESEQ, POSITIONSEQ, CAMPANIA, LINEA_NEGOCIO,
												POTENCIA, PVP, PORCENTAJE, IVA, UNIDAD, OFERTA, TIPO, TRAMO_CONSUMO, TRAMO_POTENCIA )   
    SELECT 
        credtmp.PERIODO, 
		credtmp.PERIODSEQ,
        v_txtMes_Liquidacion as Mes_Liquidacion,
		v_fechaActual as FECHA_LIQUIDACION, -- mdificar esta fecha cuando se lance el POST, mientras blanco
        TMP_PDS.PDS, 
		CREDTMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
		TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF,
        TMP_PROV.IDPROVEEDOR, 
        TMP_PROV.DESCRIPCION,
        credtmp.GenericAttribute1 as CONCEPTO_LIQ,
		TXNTMP.TEX0_GENERICATTRIBUTE15 as TARIFA,
		TRIM(to_char(credtmp.VALUE , '9999999999990D99')) IMPORTE_COMISION,
		credtmp.value,
		credtmp.GENERICNUMBER4 as CONSUMO,
		TXNTMP.GENERICNUMBER4*100 as DESCUENTO,
		TXNTMP.PRODUCTID as producto,
		credtmp.bu_name,
		TMP_PDS.PAYEESEQ,
        TMP_PDS.RULEELEMENTOWNERSEQ,  -- POSITIONSEQ
		TXNTMP.GENERICATTRIBUTE32 as campania,
		TXNTMP.TEX0_GENERICATTRIBUTE13 as linea_negocio,
		CREDTMP.GENERICNUMBER6 AS POTENCIA, -- TRAMO
		TXNTMP.GENERICNUMBER5 as PVP,
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
		CREDTMP.GENERICATTRIBUTE13 as TRAMO_POTENCIA
		
    FROM ENEL_CREDIT_TEMP_CETVTA CREDTMP
        INNER JOIN ENEL_TXN_TEMP_CETVTA TXNTMP 
            ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ
        
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
            and tmp_pds.periodseq = iperiodseq
        
        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE4
            and TMP_PROV.periodseq = iperiodseq
 
    WHERE 
		CREDTMP.GENERICATTRIBUTE1 is not null  
		and CREDTMP.NAME not like '%Incentivo%'
        and credtmp.periodseq = iperiodseq
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
    ;
                
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga CREDITOS de la tabla ENEL_PREFACTURA_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
    w_debug('Insertando Registros de CREDITOS en tabla ENEL_AGR_FAC_PREFACTURA_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_AGR_FAC_PREFACTURA_CES ( PERIODO, PDS,  IMPORTE, DET_ORDEN, CANAL, LINEA_NEGOCIO )
    SELECT 
		CREDTMP.PERIODO, 
		CREDTMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS || SUBSTR(TXNTMP.TEX0_GENERICATTRIBUTE13,0,1) || SUBSTR(credtmp.GenericAttribute1,0,1), 
        --TMP_PDS.PDS || TXNTMP.TEX0_GENERICATTRIBUTE13 || TXNTMP.GENERICATTRIBUTE32 || v_txtMes_Liquidacion2,
		CREDTMP.value,
        TMP_PDS.PDS || SUBSTR(TMP_PROV.DESCRIPCION, 1, 1 ) || SUBSTR(TMP_PROV.DESCRIPCION, INSTR(TMP_PROV.DESCRIPCION, ' ')+1,1 ) || 
            CASE
                WHEN credtmp.GenericAttribute1 LIKE 'INCENTIVO CUMPLIMIENTO OBJETIVOS' THEN 'IO'
                WHEN credtmp.GenericAttribute1 LIKE 'INCENTIVO ACELERADOR' THEN 'IA'
                ELSE 'PB'
            END
        || v_mesanio as DET_ORDEN,
        'TVTA',
        TXNTMP.TEX0_GENERICATTRIBUTE13 as linea_negocio
        
    FROM ENEL_CREDIT_TEMP_CETVTA CREDTMP
        INNER JOIN ENEL_TXN_TEMP_CETVTA TXNTMP 
            ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ
        
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
            ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
            and tmp_pds.periodseq = iperiodseq
        
        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE4
            and TMP_PROV.periodseq = iperiodseq
 
    WHERE 
		CREDTMP.GENERICATTRIBUTE1 is not null  
		and CREDTMP.NAME not like '%Incentivo%'
        and credtmp.periodseq = iperiodseq
    ;
    filas := sql%rowcount;
    COMMIT;
    w_debug('Fin Carga CREDITOS de la tabla ENEL_AGR_FAC_PREFACTURA_CES: '|| to_char(filas) || ' filas.', v_contador_debug);
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021

    w_debug('Insertando Registros de INCENTIVOS en tabla ENEL_PREFACTURA_CETVTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_PREFACTURA_CETVTA ( PERIODO, PERIODSEQ, MES_LIQUIDACION, FECHA_LIQUIDACION, PDS, NUMERO_RESUMEN, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION,
												CONCEPTO_LIQ, TARIFA, IMPORTE_COMISION, VALUE, CONSUMO, DESCUENTO, PRODUCTO, BU_NAME, PAYEESEQ, POSITIONSEQ, CAMPANIA, LINEA_NEGOCIO,
												POTENCIA, PVP, PORCENTAJE, IVA, UNIDAD, TIPO, REALIZADO, OBJETIVO, CONSECUCION, IMPORTE_UNITARIO )
    SELECT 
		INCETMP.PERIODO, 
		INCETMP.PERIODSEQ,
        v_txtMes_Liquidacion as Mes_Liquidacion,
		v_fechaActual as FECHA_LIQUIDACION,
        TMP_PDS.PDS, 
		INCETMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS as NUMERO_RESUMEN ,  -- BUYYYYMMPDS
		TMP_PDS.NOMBRE_FISCAL,
        TMP_PDS.CIF,
        TMP_PROV.IDPROVEEDOR, 
        TMP_PROV.DESCRIPCION,
        INCETMP.GenericAttribute1 as CONCEPTO_LIQ,
		'' as TARIFA,
		TRIM(to_char(INCETMP.VALUE , '9999999999990D99')) IMPORTE_COMISION,
		INCETMP.value,
		'' as CONSUMO, 
		'' as DESCUENTO,
		'' as producto,
		INCETMP.bu_name,
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
		INCETMP.GENERICNUMBER5 as IMPORTE_UNITARIO
    
    FROM ENEL_INCEN_TEMP_CETVTA INCETMP
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = iperiodseq
            AND INCETMP.PAYEESEQ = TMP_PDS.PAYEESEQ -- DMS 27/06/2023 SALIAN DUPLICADOS
            
        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE3
            and TMP_PROV.periodseq = iperiodseq

    WHERE 
		INCETMP.GENERICATTRIBUTE1 is not null 
        AND INCETMP.GENERICBOOLEAN1 = 1
        and INCETMP.value > 0
        and INCETMP.periodseq = iperiodseq
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
		;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_PREFACTURA_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
    w_debug('Insertando Registros de INCENTIVOS en tabla ENEL_AGR_FAC_PREFACTURA_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_AGR_FAC_PREFACTURA_CES ( PERIODO, PDS,  IMPORTE, DET_ORDEN, CANAL, LINEA_NEGOCIO )
    SELECT 
		INCETMP.PERIODO, 
		INCETMP.BU_NAME || v_txtMes_Liquidacion2 || TMP_PDS.PDS || SUBSTR(INCETMP.GENERICATTRIBUTE2,0,1) || SUBSTR(INCETMP.GenericAttribute1,0,1), 
        --TMP_PDS.PDS || INCETMP.GENERICATTRIBUTE2 || v_txtMes_Liquidacion2,
		INCETMP.value,
        TMP_PDS.PDS || SUBSTR(TMP_PROV.DESCRIPCION, 1, 1) || SUBSTR(TMP_PROV.DESCRIPCION, INSTR(TMP_PROV.DESCRIPCION, ' ')+1, 1) ||
        CASE
            WHEN INCETMP.GenericAttribute1 LIKE 'INCENTIVO CUMPLIMIENTO OBJETIVOS' THEN 'IO'
            WHEN INCETMP.GenericAttribute1 LIKE 'INCENTIVO ACELERADOR' THEN 'IA'
            WHEN INCETMP.GenericAttribute1 IS NOT NULL THEN 'PF'
            ELSE 'PB'
        END
        || v_mesanio,
        'TVTA',
        INCETMP.GENERICATTRIBUTE2 as linea_negocio
        
    FROM ENEL_INCEN_TEMP_CETVTA INCETMP
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = iperiodseq
            
        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE3
            and TMP_PROV.periodseq = iperiodseq

    WHERE 
		INCETMP.GENERICATTRIBUTE1 is not null 
        AND INCETMP.GENERICBOOLEAN1 = 1
        and INCETMP.value > 0
        and INCETMP.periodseq = iperiodseq
    ;
    filas := sql%rowcount;
    COMMIT;
    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_AGR_FAC_PREFACTURA_CES: '|| to_char(filas) || ' filas.', v_contador_debug);
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021
	
-- ==>> Solo para TVTA, resto de canales comentado
	w_debug('Insertando Registros de REMUN, precio BASE en tabla ENEL_PREFACTURA_CETVTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_PREFACTURA_CETVTA ( PERIODO, PERIODSEQ, MES_LIQUIDACION, FECHA_LIQUIDACION, PDS, NUMERO_RESUMEN, NOMBRE_FISCAL, CIF, IDPROVEEDOR, 
												CONCEPTO_LIQ, VALUE, BU_NAME, PAYEESEQ, POSITIONSEQ, LINEA_NEGOCIO, TARIFA, PRODUCTO, IVA, UNIDAD, TIPO)
	SELECT 				
		REMU.PERIODO,
		iperiodseq,
		v_txtMes_Liquidacion as Mes_Liquidacion,
		v_fechaActual as FECHA_LIQUIDACION,
		REMU.PDS,
		REMU.NUMERO_RESUMEN,
		REMU.NOMBRE_FISCAL,
		REMU.CIF,
		REMU.IDPROVEEDOR,
		REMU.CONCEPTO_LIQ,
		REMU.VALUE,
		REMU.CANAL,
		REMU.PAYEESEQ,
		REMU.POSITIONSEQ,
		REMU.LINEA_NEGOCIO,
		'PRECIO BASE FIJO',
		'PRECIO BASE FIJO',
		CASE 
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IVA' THEN 21
			WHEN TMP_PDS.TIPO_IMPOSITIVO = 'IGIC' THEN 7
			ELSE 21
		END AS IVA,
		'1' as UNIDAD,
		'CREDIT' as TIPO
		
	FROM ENELEXT.ENEL_REMUN_CES REMU
		 INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON REMU.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = iperiodseq
			
	WHERE REMU.CANAL = 'CETV' 
		and REMU.PROCESSINGUNITSEQ = iprocessingUnitSeq
		and REMU.PERIODO = iperiod;
	
	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga INCENTIVOS de la tabla ENEL_PREFACTURA_CETVTA para Precio BASE: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - inicio - 05.11.2021
    -- PDS = PDS + LINEA_NEGOCIO +  CAMPANIA + Tipo? + MMYY
    w_debug('Insertando Registros de REMUN, precio BASE en tabla ENEL_AGR_FAC_PREFACTURA_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_AGR_FAC_PREFACTURA_CES ( PERIODO, PDS,  IMPORTE, DET_ORDEN, CANAL, LINEA_NEGOCIO )
    SELECT 
		REMU.PERIODO, 
		--REMU.CANAL || v_txtMes_Liquidacion2 || TMP_PDS.PDS || SUBSTR(REMU.LINEA_NEGOCIO,0,1) || SUBSTR(REMU.CONCEPTO_LIQ,0,1), 
        --TMP_PDS.PDS || INCETMP.GENERICATTRIBUTE2 || v_txtMes_Liquidacion2,
        REMU.NUMERO_RESUMEN || SUBSTR(REMU.LINEA_NEGOCIO,0,1) || SUBSTR(REMU.CONCEPTO_LIQ,0,1),
		REMU.value,
        TMP_PDS.PDS || SUBSTR(REMU.LINEA_NEGOCIO,0,1) || SUBSTR(REMU.CONCEPTO_LIQ,0,1) || 'PF' || v_mesanio,
        'TVTA' as CANAL,
        REMU.LINEA_NEGOCIO
        
    FROM ENELEXT.ENEL_REMUN_CES REMU
		 INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON REMU.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and tmp_pds.periodseq = iperiodseq
			
	WHERE REMU.CANAL = 'CETV' 
		and REMU.PROCESSINGUNITSEQ = iprocessingUnitSeq
		and REMU.PERIODO = iperiod;

    filas := sql%rowcount;
    COMMIT;
    w_debug('Fin Carga Registros de REMUN, precio BASE de la tabla ENEL_AGR_FAC_PREFACTURA_CES: '|| to_char(filas) || ' filas.', v_contador_debug);
    -- REQ-CM-003: Informe de Balance para Clientes Empresa - fin - 05.11.2021

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PREFACTURA_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PREFACTURA_CETVTA.',v_contador_debug);
end;

procedure p_Comparativa_Pagos_E4E ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Borrado de la tabla ENEL_COMP_E4E_CETVTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_COMP_E4E_CETVTA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_E4E_CETVTA.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_E4E_CETVTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_COMP_E4E_CETVTA ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
											E4E_POS_SIN_CONTRATO, E4E_NEGATIVO)   
    SELECT 
        T_SCAWEB.PERIODO,
        T_SCAWEB.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_SCAWEB.PDS,
        TMP_PDS.NOMBRE_FISCAL,
		trunc(IMPORTE_SCAWEB,2),
        case when T_E4E.POSITIVO_CON_CONTRATO is null then 0 else trunc(T_E4E.POSITIVO_CON_CONTRATO,2) end as Con_Contrato,
        case when T_E4E.POSITIVO_SIN_CONTRATO is null then 0 else trunc(T_E4E.POSITIVO_SIN_CONTRATO,2) end as Sin_Contrato,
        case when T_E4E.NEGATIVO is null then 0 else T_E4E.NEGATIVO end as Negativo
        
    FROM
        ( select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
            from ENEL_LIQUIDACION_CETVTA sca where PERIODO = IPERIOD
            group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO 
        ) T_SCAWEB
        LEFT JOIN 
            (select TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
					sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
					sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
					SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO
				from ENEL_E4E_DEPOSIT_TEMP_CETVTA
				where periodseq=IPERIODSEQ
				group by TRIM(IDPROVEEDOR), PDS 
            ) T_E4E
            
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)

            
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON T_SCAWEB.PDS=TMP_PDS.PDS

        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR);        
      
    filas := sql%rowcount;
    COMMIT;
   
    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_E4E_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_E4E_CETVTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_COMP_E4E_CETVTA ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
											E4E_POS_SIN_CONTRATO, E4E_NEGATIVO)         
    SELECT    
		T_E4E.PERIODO,
		T_E4E.IDPROVEEDOR,
        TMP_PROV.DESCRIPCION,
        TMP_PROV.ACTIVIDAD,
        T_E4E.PDS,
        TMP_PDS.NOMBRE_FISCAL,
        T_SCAWEB.IMPORTE_SCAWEB,
        T_E4E.POSITIVO_CON_CONTRATO,
        T_E4E.POSITIVO_SIN_CONTRATO,
        T_E4E.NEGATIVO
    FROM
        ( SELECT iperiod PERIODO, TRIM(IDPROVEEDOR)  AS IDPROVEEDOR, PDS, 
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NOT NULL THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
            SUM(CASE WHEN VALUE > 0 AND COD_CONTRATO IS NULL THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
            SUM(CASE WHEN VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO
            FROM ENEL_E4E_DEPOSIT_TEMP_CETVTA 
            WHERE PERIODSEQ = iperiodseq
            GROUP BY iperiod, TRIM(IDPROVEEDOR), PDS 
        ) T_E4E
            
        LEFT JOIN
            ( SELECT PERIODO
                , TRIM( TO_CHAR(PROVEEDOR,'000')) IDPROVEEDOR
                , SCA.CODIGO_AGENTE_INTERNO AS PDS
                , SUM(REALVALUE) AS IMPORTE_SCAWEB
                , COUNT(*) REGISTROS        
                FROM ENEL_LIQUIDACION_CETVTA SCA             
                WHERE PERIODO = iperiod            
                GROUP BY PERIODO, TRIM( TO_CHAR(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO             
            ) T_SCAWEB
            ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
            AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
			          
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON T_E4E.PDS = TMP_PDS.PDS

        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TRIM(TMP_PROV.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR)
    
	WHERE T_SCAWEB.IMPORTE_SCAWEB IS NULL;
      
    filas := sql%rowcount;
    COMMIT;
   
    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_E4E_CETVTA: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_COMP_E4E_CETVTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_E4E_CETVTA.',v_contador_debug);
end; 

procedure p_Agregado_Facturacion ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
	v_anio VARCHAR(10);
	v_mes VARCHAR2(5);
	v_referencia VARCHAR2(50);
	v_txtMes_Liquidacion VARCHAR2(10);
	v_txtYear VARCHAR2(2);
	v_fechaPeriodoSiguiente date;

	v_periodstartdate date;
	v_periodenddate date;
    v_count number;
begin
    w_debug('Inicio Borrado de la tabla ENEL_AGREFACT_FINAL_CES.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_AGREFACT_FINAL_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			DELETE FROM ENELEXT.ENEL_REGISTROS_CRED_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			DELETE FROM ENELEXT.ENEL_REGISTROS_TXN_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			DELETE FROM ENELEXT.ENEL_REGISTROS_COMMISSION_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			DELETE FROM ENELEXT.ENEL_DISPUTAS_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
		
	END;
    w_debug('Fin Borrado de la tabla ENEL_AGREFACT_FINAL_CES.', v_contador_debug);

	v_periodstartdate :=  f_Primer_Dia_Periodo_Anterior(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo_Anterior(iperiodseq);
	
	v_anio := to_char(f_fecha_inicio(iperiodseq),'YYYY');
	v_mes := to_char(f_fecha_inicio(iperiodseq),'MM');

	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
	v_txtMes_Liquidacion := to_char(f_fecha_inicio(iperiodseq), 'YYYYMM');
	-- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
	
	-- Se convierte a texto el anio YY para el codigo de referencia
    v_txtYear := to_char(f_fecha_inicio(iperiodseq),'YY');
	
	v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
	
    w_debug('Insertando Registros de datos en tabla ENEL_AGREFACT_FINAL_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_AGREFACT_FINAL_CES (PERIODO, CANAL, PDS, LINEA_NEGOCIO, CONCEPTO_RETRIBUTIVO, TIPO_GASTO, VALUE, CECO, WBE_FINAL_IMPUTACION, COD_CONTRATO, DEPOSITSEQ, 
												PROCESSINGUNITSEQ, COLABORADOR, FECHA_SOL_EXCEPCION, SOLICITANTE_EXCEPCION, FECHA_EXTRACCION, FECHA_PUBLI_FACT, FECHA_CIERRE_FACT, 
												N_ALEGACIONES,DETALLE_N_ALEGACIONES, FECHA_ALEGACIONES, N_ALEGACIONES_ACEPTADAS, N_ALEGACIONES_RECHAZADAS, FECHA_RESOLUCION, COD_PREFACTURA,
												FECHA_PREFACTURA, IMPORTE_CONTRATO_INI, RESTANTE, DET_ORDEN, CONCEPTO_DETALLE,CONSUMO_DEPOSITO)
    SELECT 
        DEPOTMP.PERIODO,  				--periodo
        TMP_PDS.CANAL,  				--canal
        TMP_PDS.PDS as cod_colaborador,	--codigo colaborador -- pds
        DEPOTMP.LINEA_NEGOCIO,  		--linea_negocio
        case	
			when DEPOTMP.TIPO = 'DC' or DEPOTMP.value < 0 or DEPOTMP.name like '%Decomi%' then  'DC'
			else DEPOTMP.TIPO
		end tipo,  						--concepto retributivo
        DEPOTMP.GENERICATTRIBUTE1,  	--tipo_gasto
        DEPOTMP.VALUE,
        TMP_PROV.CECO,
        DEPOTMP.WBE,
        TMP_CONTRA.COD_CONTRATO,
        DEPOTMP.DEPOSITSEQ,
        iprocessingUnitSeq,
		TMP_PDS.NOMBRE_FISCAL, 			--colaborador
		-- nuevos campos
		'' as FECHA_SOL_EXCEPCION, 
		'' as SOLICITANTE_EXCEPCION, 
		'' as FECHA_EXTRACCION, 
		'' as FECHA_PUBLI_FACT, 
		'' as FECHA_CIERRE_FACT, 
		'' as N_ALEGACIONES,
        '' as DETALLE_N_ALEGACIONES,
		'' as FECHA_ALEGACIONES, 
		'' as N_ALEGACIONES_ACEPTADAS, 
		'' as N_ALEGACIONES_RECHAZADAS,  --N. Alegaciones - N. Alegaciones Aceptadas
		'' as FECHA_RESOLUCION, 
		BU.NAME || v_txtMes_Liquidacion || TMP_PDS.PDS ||
			CASE 
				WHEN DEPOTMP.TIPO like 'I%' THEN 'I' || SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1)
				WHEN DEPOTMP.TIPO like 'PF' and BU.NAME = 'CEBP' THEN 'PF' -- NO MODIFICAR
				WHEN SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1) = 'B' THEN SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1)
				WHEN SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1) = 'D' THEN SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1)
				ELSE SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1) || SUBSTR(DEPOTMP.GENERICATTRIBUTE1, 1, 1)
			END
		as COD_PREFACTURA,  --CREDTMP.BU_NAME || v_txtMes_Liquidacion || TMP_PDS.PDS ,  -- BUYYYYPDS
		'' as FECHA_PREFACTURA, 
		TMP_CONTRA.IMPORTE as IMPORTE_CONTRATO_INI, 
		'' as RESTANTE,
		-- Codigo de proveedor + Linea de Negocio + Campania + Tipo + Mes + YY
		--v_referencia := REGDEPOSITO.PDS || REGDEPOSITO.LINEA_NEGOCIO || REGDEPOSITO.CAMPANIA || REGDEPOSITO.TIPO || v_mes || v_txtYear ;
		TMP_PDS.PDS || SUBSTR(DEPOTMP.LINEA_NEGOCIO, 1, 1) || SUBSTR(DEPOTMP.GENERICATTRIBUTE1, 1, 1) || DEPOTMP.TIPO || v_mes || v_txtYear as DET_ORDEN,
		case
			when DEPOTMP.TIPO = 'PB' and DEPOTMP.value > 0 and DEPOTMP.name like '%Ajustes Manuales%' then 'Ajustes Manuales' -- DCR 29.12.2021
            when DEPOTMP.TIPO = 'PB' and DEPOTMP.value < 0 and DEPOTMP.name like '%Decomi%' then 'Decomisión' -- DCR 25.02.2022
            when DEPOTMP.TIPO = 'PB' and (DEPOTMP.value > 0 or DEPOTMP.name not like '%Decomi%') then 'Precio Base'
			when DEPOTMP.TIPO = 'PB' and (DEPOTMP.value < 0 or DEPOTMP.name like '%Reg. Campa%') then 'Reg. Campañas Fidelizacion'
			when DEPOTMP.TIPO = 'PF' then 'Precio Fijo'
			when DEPOTMP.TIPO = 'DC' or DEPOTMP.value < 0 or DEPOTMP.name like '%Decomi%' then 'Decomisión'
			when DEPOTMP.TIPO = 'IO' then 'Incentivo por Objetivos'
			when DEPOTMP.TIPO = 'IA' then 'Incentivo Acelerador'
			else DEPOTMP.TIPO
		end CONCEPTO_DETALLE,
        DEPOTMP.GENERICNUMBER1 --CONSUMO_DEPOSITO

    FROM ENEL_DEPOSIT_TEMP_CETVTA DEPOTMP
        INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS
            ON DEPOTMP.payeeseq=TMP_PDS.payeeseq
            and tmp_pds.periodseq = iperiodseq

        INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
            ON TMP_PROV.IDPROVEEDOR=DEPOTMP.earninggroupid
            and TMP_PROV.periodseq = iperiodseq

        LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_CETVTA TMP_CONTRA
            ON TMP_CONTRA.periodseq = DEPOTMP.periodseq
            AND TMP_CONTRA.PDS = TMP_PDS.PDS
            AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
            AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
		
		INNER JOIN CS_BUSINESSUNIT BU ON DEPOTMP.BUSINESSUNITMAP = BU.MASK
		
	WHERE
		DEPOTMP.PERIODSEQ = iperiodseq
		AND DEPOTMP.VALUE <> 0
		--and TMP_PDS.TIPO_PRESTADOR = 'SI' -- sólo afecta a canal BP (oct. 2020)
		
	order by TMP_PDS.PDS, DEPOTMP.LINEA_NEGOCIO, DEPOTMP.GENERICATTRIBUTE1, DEPOTMP.TIPO
    ;
	
    filas := sql%rowcount;
    COMMIT;

	w_debug('Fin carga datos en tabla ENEL_AGREFACT_FINAL_CES.' || to_char(filas) || ' filas.', v_contador_debug);

	INSERT INTO ENELEXT.ENEL_REGISTROS_CRED_CES (PERIODO, CANAL, TOTAL, PDS, LINEA_NEGOCIO, TIPO_GASTO, CONCEPTO_RETRIBUTIVO, PROCESSINGUNITSEQ)
	SELECT 
		iperiod,
		TMP_PDS.CANAL,  				--CANAL
		COUNT(CREDTMP.CREDITSEQ) AS TOTAL,
		TMP_PDS.PDS AS COD_COLABORADOR,	--CODIGO COLABORADOR
		CREDTMP.GENERICATTRIBUTE2 AS LIN_NEG_CRED,
		CREDTMP.GENERICATTRIBUTE1 AS TIPO_GASTO,   	--TIPO_GASTO
		CASE 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Contratos %' THEN 'PB' 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Bajas %' THEN 'DC' 
		END AS CONCEPTO_RETRIBUTIVO,
		iprocessingUnitSeq
		
	FROM ENEL_CREDIT_TEMP_CETVTA CREDTMP
		INNER JOIN ENEL_TXN_TEMP_CETVTA TXNTMP 
			ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ

		INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
			ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
	
		INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE4

	WHERE 
		CREDTMP.GENERICATTRIBUTE1 IS NOT NULL 
		AND CREDTMP.VALUE > 0
		AND CREDTMP.NAME NOT LIKE '%Incent%'
		
	GROUP BY
		iperiod,
		TMP_PDS.CANAL,  				--CANAL
		TMP_PDS.PDS,	--CODIGO COLABORADOR
		CREDTMP.GENERICATTRIBUTE2,
		CREDTMP.GENERICATTRIBUTE1,   	--TIPO_GASTO
		CASE 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Contratos %' THEN 'PB' 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Bajas %' THEN 'DC' 
		END,
		iprocessingUnitSeq
	;
	
	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin carga datos en tabla ENEL_REGISTROS_CRED_CES.' || to_char(filas) || ' filas.', v_contador_debug);
	
	INSERT INTO ENELEXT.ENEL_REGISTROS_TXN_CES (PERIODO, CANAL, TOTAL, PDS, LINEA_NEGOCIO, TIPO_GASTO, CONCEPTO_RETRIBUTIVO, PROCESSINGUNITSEQ)
	SELECT 
		iperiod,
		TMP_PDS.CANAL,  				--CANAL
		COUNT(CREDTMP.CREDITSEQ) AS TOTAL,
		TMP_PDS.PDS AS COD_COLABORADOR,	--CODIGO COLABORADOR
		CREDTMP.GENERICATTRIBUTE2 AS LIN_NEG_CRED,
		CREDTMP.GENERICATTRIBUTE1 AS TIPO_GASTO,   	--TIPO_GASTO
		CASE 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Contratos %' THEN 'PB' 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Bajas %' THEN 'DC' 
            WHEN TXNTMP.EVENTYPEID LIKE 'CE Ajuste Manual %' THEN 'PB' -- DCR 29.12.2021
		END AS CONCEPTO_RETRIBUTIVO,
		iprocessingUnitSeq
		
	FROM ENEL_CREDIT_TEMP_CETVTA CREDTMP
		INNER JOIN ENEL_TXN_TEMP_CETVTA TXNTMP 
			ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ

		INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
			ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
	
		INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE4

	WHERE 
		CREDTMP.GENERICATTRIBUTE1 IS NOT NULL 
		
	GROUP BY
		iperiod,
		TMP_PDS.CANAL,  				--CANAL
		TMP_PDS.PDS,	--CODIGO COLABORADOR
		CREDTMP.GENERICATTRIBUTE2,
		CREDTMP.GENERICATTRIBUTE1,   	--TIPO_GASTO
		CASE 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Contratos %' THEN 'PB' 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Bajas %' THEN 'DC' 
            WHEN TXNTMP.EVENTYPEID LIKE 'CE Ajuste Manual %' THEN 'PB' -- DCR 29.12.2021
		END,
		iprocessingUnitSeq,
        TXNTMP.EVENTYPEID -- DCR 29.12.2021
	;
	
	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin carga datos en tabla ENEL_REGISTROS_TXN_CES.' || to_char(filas) || ' filas.', v_contador_debug);
	
	INSERT INTO ENELEXT.ENEL_REGISTROS_COMMISSION_CES (PERIODO, CANAL, TOTAL, PDS, LINEA_NEGOCIO, TIPO_GASTO, CONCEPTO_RETRIBUTIVO, PROCESSINGUNITSEQ)
	SELECT 
		iperiod,
		TMP_PDS.CANAL,  				--CANAL
		COUNT(CREDTMP.CREDITSEQ) AS TOTAL,
		TMP_PDS.PDS AS COD_COLABORADOR,	--CODIGO COLABORADOR
		CREDTMP.GENERICATTRIBUTE2 AS LIN_NEG_CRED,
		CREDTMP.GENERICATTRIBUTE1 AS TIPO_GASTO,   	--TIPO_GASTO
		CASE 
			WHEN CREDTMP.GENERICATTRIBUTE6 = 'IA' THEN CREDTMP.GENERICATTRIBUTE6
			ELSE 'IO' 
		END AS CONCEPTO_RETRIBUTIVO,
		iprocessingUnitSeq
		
	FROM ENEL_CREDIT_TEMP_CETVTA CREDTMP
		INNER JOIN ENEL_TXN_TEMP_CETVTA TXNTMP 
			ON CREDTMP.SALESTRANSACTIONSEQ=TXNTMP.SALESTRANSACTIONSEQ

		INNER JOIN ENEL_PDS_TEMP_CETVTA TMP_PDS 
			ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ 
	
		INNER JOIN ENEL_ORDER_IMPU_TEMP_CETVTA TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE4
			
		INNER JOIN ENEL_COMMISSION_TEMP_CETVTA COMMI
			ON COMMI.CREDITSEQ = CREDTMP.CREDITSEQ

	WHERE 
		CREDTMP.GENERICATTRIBUTE1 IS NOT NULL 
		AND COMMI.VALUE > 0
		
	GROUP BY
		iperiod,
		TMP_PDS.CANAL,  				--CANAL
		TMP_PDS.PDS,	--CODIGO COLABORADOR
		CREDTMP.GENERICATTRIBUTE2,
		CREDTMP.GENERICATTRIBUTE1,   	--TIPO_GASTO
		CASE 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Contratos %' THEN 'PB' 
			WHEN TXNTMP.EVENTYPEID LIKE 'CE Bajas %' THEN 'DC' 
		END,
		CASE 
			WHEN CREDTMP.GENERICATTRIBUTE6 = 'IA' THEN CREDTMP.GENERICATTRIBUTE6
			ELSE 'IO' 
		END,
		iprocessingUnitSeq
	;
	
	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin carga datos en tabla ENEL_REGISTROS_COMMISSION_CES.' || to_char(filas) || ' filas.', v_contador_debug);
	
	INSERT INTO ENELEXT.ENEL_DISPUTAS_CES (PERIODO, TIPO, PDS, PROCESSINGUNITSEQ, CANAL, REGISTROSALEGADOS, BU, FECHA_ENVIO, FECHA_RESOLUCION, TOTAL_RESUELTA, TOTAL_DENEGADA, TIPO_COMI)
	SELECT 
		iperiod,
		CASE 
			WHEN DIS.REASONCODE LIKE 'Comisi%' THEN SUBSTR(DIS.REASONCODE, INSTR(DIS.REASONCODE, ' ')+1 ) --TRIM(REPLACE(DIS.REASONCODE,'Comision','')) 
			WHEN DIS.REASONCODE LIKE 'Decomisi%' THEN SUBSTR(DIS.REASONCODE, INSTR(DIS.REASONCODE, ' ')+1 ) --TRIM(REPLACE(DIS.REASONCODE,'Decomision','')) 
			WHEN DIS.REASONCODE LIKE 'Incentivo%' THEN SUBSTR(DIS.REASONCODE, INSTR(DIS.REASONCODE, ' ')+1 ) --TRIM(REPLACE(DIS.REASONCODE,'Incentivo','')) 
			ELSE DIS.REASONCODE
		END AS TIPO,
		POS.NAME AS PDS,
		iprocessingUnitSeq,
		POS.GENERICATTRIBUTE6 AS CANAL,
        --DIS.GENERICNUMBER1 AS REGISTROSALEGADOS,
        TO_NUMBER(DIS.GENERICATTRIBUTE6) AS REGISTROSALEGADOS, --MRMM 12/11/21
		BU.NAME,
		MAX(DOC.STARTDATE) AS FECHA_ENVIO,
		MAX(DOC.ENDDATE) AS FECHA_RESOLUCION,
		CASE
			WHEN DOC.STATUS LIKE 'status_DisputeResolved' THEN COUNT(DIS.DISPUTEID)
			ELSE 0
		END AS TOTAL_RESUELTA,
		CASE
			WHEN DOC.STATUS LIKE 'status_DisputeWithdrawn' OR DOC.STATUS LIKE 'status_DisputeDenied' THEN COUNT(DIS.DISPUTEID) 
			ELSE 0
		END AS TOTAL_DENEGADA,
		case 
			when SUBSTR(DIS.REASONCODE, 1, 1) = 'C' then 'PB' 
			when SUBSTR(DIS.REASONCODE, 1, 1) = 'D' then 'DC'
			when SUBSTR(DIS.REASONCODE, 1, 1) = 'I' then 'IO'
		end as TIPO_COMI -- concepto_retributivo

	FROM CSP_DISPUTEPROCESS DIS 
		INNER JOIN CSP_DOCUMENTPROCESS DOC
			ON DIS.DOCUMENTPROCESSSEQ = DOC.DOCUMENTPROCESSSEQ
		INNER JOIN CS_POSITION POS 
			ON DOC.POSITIONSEQ = POS.RULEELEMENTOWNERSEQ
			AND POS.REMOVEDATE = v_eot
			AND POS.TENANTID = itenantId
			AND POS.PROCESSINGUNITSEQ = iprocessingUnitSeq
		INNER JOIN CSP_DOCUMENTWORKFLOW DOCWF
			ON DOC.DOCUMENTPROCESSTEMPLATESEQ = DOCWF.DOCUMENTPROCESSTEMPLATESEQ
			AND DOCWF.REMOVEDATE = v_eot
		LEFT JOIN CS_BUSINESSUNIT BU
			ON DOCWF.BUSINESSUNITMAP = BU.MASK

	WHERE DOC.STARTDATE BETWEEN v_periodstartdate AND v_periodenddate
	GROUP BY 
		iperiod,
		DIS.REASONCODE,
		POS.NAME,
		POS.GENERICATTRIBUTE6,
		iprocessingUnitSeq,
        --DIS.GENERICNUMBER1, --MRMM 12/11/21
		DIS.GENERICATTRIBUTE6,  --MRMM 12/11/21
		DOC.STATUS,
		BU.NAME;

	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin carga datos en tabla ENEL_DISPUTAS_CES.' || to_char(filas) || ' filas.', v_contador_debug);

-- N_ALEGACIONES,DETALLE_N_ALEGACIONES, FECHA_ALEGACIONES, N_ALEGACIONES_ACEPTADAS, N_ALEGACIONES_RECHAZADAS, FECHA_RESOLUCION
	BEGIN ------Actualizacion de columnas begin
    
	-- ALEGACIONES para Captación
	-- Actualizamos el campo de alegaciones
    v_count := 1;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_ALEGACIONES = 
	(
		SELECT SUM(T2.TOTAL_DENEGADA + T2.TOTAL_RESUELTA) AS TOTAL
		FROM ENEL_DISPUTAS_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			--AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.TIPO, 1, 1)
            AND UPPER(T1.LINEA_NEGOCIO) = UPPER(T2.TIPO)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.TIPO_COMI
	)
	WHERE T1.PERIODO = iperiod
	AND SUBSTR(T1.TIPO_GASTO, 1, 1) = 'C'
	;
    
	-- detalle n_alegaciones
    v_count := 2;
    UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.DETALLE_N_ALEGACIONES = 
	(
        SELECT SUM (REGISTROSALEGADOS) AS TOTAL
		FROM ENEL_DISPUTAS_CES T2
        WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			--AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.TIPO, 1, 1)
            AND UPPER(T1.LINEA_NEGOCIO) = UPPER(T2.TIPO)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.TIPO_COMI
	)
	WHERE T1.PERIODO = iperiod
	AND SUBSTR(T1.TIPO_GASTO, 1, 1) = 'C'
	;
    
	-- alegaciones aceptadas
    v_count := 3;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_ALEGACIONES_ACEPTADAS = 
	(
		SELECT SUM (T2.TOTAL_RESUELTA) AS TOTAL
		FROM ENEL_DISPUTAS_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			--AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.TIPO, 1, 1)
            AND UPPER(T1.LINEA_NEGOCIO) = UPPER(T2.TIPO)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.TIPO_COMI
	)
	WHERE T1.PERIODO = iperiod
	AND SUBSTR(T1.TIPO_GASTO, 1, 1) = 'C'
	;
	
	-- alegaciones Rechazadas
    v_count := 4;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_ALEGACIONES_RECHAZADAS = 
	(
		SELECT SUM (T2.TOTAL_DENEGADA) AS TOTAL
		FROM ENEL_DISPUTAS_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			--AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.TIPO, 1, 1)
            AND UPPER(T1.LINEA_NEGOCIO) = UPPER(T2.TIPO)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.TIPO_COMI
	)
	WHERE T1.PERIODO = iperiod
	AND SUBSTR(T1.TIPO_GASTO, 1, 1) = 'C'
	;
	
	-- Fecha Alegación
    v_count := 5;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.FECHA_ALEGACIONES = 
	(
		SELECT MAX(FECHA_ENVIO) AS TOTAL
		FROM ENEL_DISPUTAS_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			--AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.TIPO, 1, 1)
            AND UPPER(T1.LINEA_NEGOCIO) = UPPER(T2.TIPO)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.TIPO_COMI
	)
	WHERE T1.PERIODO = iperiod
	AND SUBSTR(T1.TIPO_GASTO, 1, 1) = 'C'
	;
	
	-- alegaciones FECHA_RESOLUCION
    v_count := 6;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.FECHA_RESOLUCION = 
	(
		SELECT MAX(FECHA_RESOLUCION) AS TOTAL
		FROM ENEL_DISPUTAS_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			--AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.TIPO, 1, 1)
            AND UPPER(T1.LINEA_NEGOCIO) = UPPER(T2.TIPO)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.TIPO_COMI
	)
	WHERE T1.PERIODO = iperiod
	AND SUBSTR(T1.TIPO_GASTO, 1, 1) = 'C'
	;
-- FIN Alegaciones --

    v_count := 7;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS_FACT = 
	(
		SELECT T2.TOTAL AS TOTAL
		FROM ENEL_REGISTROS_CRED_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.CONCEPTO_RETRIBUTIVO
	)
	WHERE T1.PERIODO = iperiod
-- DCR BOM 29.12.2021 INC000079731266 
-- Los conceptos "Ajustes Manuales" son tomados como Precio Base, así que no
-- son contabilizados correctamente ni distinguidos en el informe
-- Es la unica forma que encontre de hacerlo sin cambiar el concepto, que puede romper otros informes
    AND T1.CONCEPTO_DETALLE <> 'Ajustes Manuales'
    AND T1.CANAL = 'TVTA';
    
    v_count := 8;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS_FACT = 
	(
		SELECT COUNT(T2.concepto_retributivo) AS TOTAL
		FROM ENEL_REGISTROS_CRED_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.CONCEPTO_RETRIBUTIVO
	)
	WHERE T1.PERIODO = iperiod
    AND T1.CONCEPTO_DETALLE = 'Ajustes Manuales'
    AND T1.CANAL = 'TVTA';
    
    v_count := 9;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS = 
	(
		SELECT COUNT(T2.concepto_retributivo) AS TOTAL
		FROM ENEL_REGISTROS_TXN_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
 			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.CONCEPTO_RETRIBUTIVO
	)
	WHERE T1.PERIODO = iperiod
    AND T1.CONCEPTO_DETALLE = 'Ajustes Manuales'
    AND T1.CANAL = 'TVTA';
-- DCR EOM 29.12.2021 INC000079731266 
	
    v_count := 10;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS = 
	(
		SELECT T2.TOTAL AS TOTAL
		FROM ENEL_REGISTROS_TXN_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.CONCEPTO_RETRIBUTIVO
	)
	WHERE T1.PERIODO = iperiod
    AND T1.CONCEPTO_DETALLE <> 'Ajustes Manuales' -- DCR BOM 29.12.2021 INC000079731266 
    AND T1.CANAL = 'TVTA';
	
	-- Actualización de la tabla para Incentivos por Objetivos
    v_count := 11;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS_FACT = 
	(
		SELECT T2.TOTAL AS TOTAL
		FROM ENEL_REGISTROS_COMMISSION_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.CONCEPTO_RETRIBUTIVO --el concepto retributivo de las comisiones siempre es IO
	)
	WHERE T1.PERIODO = iperiod
	and T1.CONCEPTO_RETRIBUTIVO = 'IO'
    AND T1.CANAL = 'TVTA';
	
    v_count := 12;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS = 
	(
		SELECT T2.TOTAL AS TOTAL
		FROM ENEL_REGISTROS_TXN_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T2.CONCEPTO_RETRIBUTIVO = 'PB'
	)
	WHERE T1.CONCEPTO_RETRIBUTIVO = 'IO'
	AND T1.PERIODO = iperiod
    AND T1.CANAL = 'TVTA';
	
	-- Actualización de la tabla para Incentivos Aceleración
    v_count := 13;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS_FACT = 
	(
		SELECT T2.TOTAL AS TOTAL
		FROM ENEL_REGISTROS_COMMISSION_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T1.CONCEPTO_RETRIBUTIVO = T2.CONCEPTO_RETRIBUTIVO
	)
	WHERE T1.PERIODO = iperiod
	and T1.CONCEPTO_RETRIBUTIVO = 'IA'
    AND T1.CANAL = 'TVTA';
	
    v_count := 14;
	UPDATE ENEL_AGREFACT_FINAL_CES T1
	SET T1.N_REGISTROS = 
	(
		SELECT T2.TOTAL AS TOTAL
		FROM ENEL_REGISTROS_TXN_CES T2
		WHERE
			T1.PERIODO = T2.PERIODO
			AND T1.CANAL = T2.CANAL
			AND T1.PDS = T2.PDS
			AND SUBSTR(T1.LINEA_NEGOCIO, 1, 1) = SUBSTR(T2.LINEA_NEGOCIO, 1, 1)
			AND SUBSTR(T1.TIPO_GASTO, 1, 1) = SUBSTR(T2.TIPO_GASTO, 1, 1)
			AND T2.CONCEPTO_RETRIBUTIVO = 'PB'
	)
	WHERE T1.CONCEPTO_RETRIBUTIVO = 'IA'
	AND T1.PERIODO = iperiod
    AND T1.CANAL = 'TVTA';
    
    EXCEPTION
        WHEN OTHERS THEN
            w_debug('ERROR en actualizacion de columnas ALEGACIONES o N REGISTROS. Update:' || v_count, v_contador_debug);
    
    END; ------Actualizacion de columnas END
    
    w_debug('Fin Carga de la tabla ENEL_AGREFACT_FINAL_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_AGREFACT_FINAL_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_AGREFACT_FINAL_CES.',v_contador_debug);
end;

-- Nuevo procedimiento para informe de CANAL


-- Comrpueba si el periodo esta Liquidado ya o no. Si esta Liquidado, los datos de andromeda no deben actualizarse
function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
    v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin
   -- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
    SELECT count(ESTADO)
        into v_checkCountEstado
	FROM ENELEXT.ENEL_PER_LIQUIDADOS_CES epl 
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
            
---------------- Actualizamos la tabla que indica la fecha y hora de actualizaci¿n del informes-------------
procedure p_Actualiza_Informe_Fecha ( iPeriod IN VARCHAR2, iInforme IN varchar2)
AS
begin
    MERGE
        INTO ENELEXT.ENEL_FECHAS_WEBI tabla
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


/*BOM APM 14.04.2025 Informes CTAs*/
procedure p_informe_cta ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    /*v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
	v_anio VARCHAR(10);*/
begin
    w_debug('Inicio Borrado de la tabla ENEL_DEPOSIT_CTAS_CES.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_DEPOSIT_CTAS_CES WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_DEPOSIT_CTAS_CES.', v_contador_debug);
    
     w_debug('Inicio Borrado de la tabla ENEL_DEPOSIT_CTAS_CES_2.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_DEPOSIT_CTAS_CES_2 WHERE PERIODO = iperiod AND PROCESSINGUNITSEQ = iprocessingUnitSeq AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_DEPOSIT_CTAS_CES_2.', v_contador_debug);

	/*v_anio := to_char(f_fecha_inicio(iperiodseq),'YYYY');
	
	v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;*/
	
    w_debug('Insertando Registros de datos en tabla ENEL_DEPOSIT_CTAS_CES.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_DEPOSIT_CTAS_CES (TENANTID, PERIODSEQ, PERIODO, LINEA_NEGOCIO, BU, VARIABLE_ELEC, FIJOS_ELEC, INCENTIVOS_ELEC, DECOMISIONES_ELEC, AJUSTES_MANUALES_ELEC, 
													VARIABLE_GAS, FIJOS_GAS, INCENTIVOS_GAS, DECOMISIONES_GAS, AJUSTES_MANUALES_GAS, PROCESSINGUNITSEQ) 
        SELECT
        depo.TENANTID,
        depo.PERIODSEQ,
        iperiod,
        upper(DEPO.GENERICATTRIBUTE3) as linea_negocio,
        case
            WHEN bu.NAME  = 'CEBP' THEN 'BP' 
			WHEN bu.NAME  = 'CEIS' THEN 'IS' 
            WHEN bu.NAME  = 'CESP' THEN 'SP' 
            WHEN bu.NAME  = 'CETF' THEN 'TF' 
            WHEN bu.NAME  = 'CETV' THEN 'TV' 
        END as BU,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'ELECTRICIDAD' 
                and DEPO.GENERICATTRIBUTE7 = 'PB'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE > 0
                THEN DEPO.VALUE
        END as VARIABLE_ELEC,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'ELECTRICIDAD' 
                and DEPO.GENERICATTRIBUTE7 = 'PF'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE > 0
                THEN DEPO.VALUE
        END as FIJOS_ELEC,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'ELECTRICIDAD' 
                and DEPO.GENERICATTRIBUTE7 = 'IO'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE > 0
                THEN DEPO.VALUE
        END as INCENTIVOS_ELEC,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'ELECTRICIDAD' 
                and DEPO.GENERICATTRIBUTE7 = 'PB'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE < 0
                THEN DEPO.VALUE
        END as DECOMISIONES_ELEC,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'ELECTRICIDAD' 
                and DEPO.GENERICATTRIBUTE7 = 'NR'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                THEN DEPO.VALUE
        END as AJUSTES_MANUALES_ELEC,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'GAS' 
                and DEPO.GENERICATTRIBUTE7 = 'PB'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE > 0
                THEN DEPO.VALUE
        END as VARIABLE_GAS,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'GAS' 
                and DEPO.GENERICATTRIBUTE7 = 'PF'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE > 0
                THEN DEPO.VALUE
        END as FIJOS_GAS,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'GAS' 
                and DEPO.GENERICATTRIBUTE7 = 'IO'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE > 0
                THEN DEPO.VALUE
        END as INCENTIVOS_GAS,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'GAS' 
                and DEPO.GENERICATTRIBUTE7 = 'PB'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                and DEPO.VALUE < 0
                THEN DEPO.VALUE
        END as DECOMISIONES_GAS,
        case
            when    upper(DEPO.GENERICATTRIBUTE3) = 'GAS' 
                and DEPO.GENERICATTRIBUTE7 = 'NR'
                and DEPO.GENERICATTRIBUTE1 like 'Captaci%n'
                THEN DEPO.VALUE
        END as AJUSTES_MANUALES_GAS,
        iprocessingUnitSeq
        
    FROM CS_DEPOSIT depo
        INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            AND p.tenantid = itenantId
			
		INNER JOIN CS_BUSINESSUNIT BU
			ON BU.MASK = DEPO.BUSINESSUNITMAP
			AND BU.TENANTID = itenantId 
			
    WHERE
        depo.TENANTID = itenantId
        AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq
        AND depo.PERIODSEQ = iperiodseq
        ;

    filas := sql%rowcount;
    COMMIT;
  
  
  INSERT INTO ENEL_DEPOSIT_CTAS_CES_2 (TENANTID, PERIODSEQ , PERIODO, LINEA_NEGOCIO, ACTIVIDAD,TIPO_CONCEPTO,BU,VALUE,PROCESSINGUNITSEQ)
    
    SELECT 
     depo.TENANTID,
        depo.PERIODSEQ,
        iperiod,
        upper(DEPO.GENERICATTRIBUTE3) as linea_negocio,
        DEPO.GENERICATTRIBUTE1 AS ACTIVIDAD,
        DEPO.GENERICATTRIBUTE7 AS TIPO_CONCEPTO,
         case
            WHEN bu.NAME  = 'CEBP' THEN 'BP' 
			WHEN bu.NAME  = 'CEIS' THEN 'IS' 
            WHEN bu.NAME  = 'CESP' THEN 'SP' 
            WHEN bu.NAME  = 'CETF' THEN 'TF' 
            WHEN bu.NAME  = 'CETV' THEN 'TV' 
        END as BU,
        DEPO.VALUE AS VALUE,
        iprocessingUnitSeq
        
         FROM CS_DEPOSIT depo
        INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
            AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
            AND p.tenantid = itenantId
			
		INNER JOIN CS_BUSINESSUNIT BU
			ON BU.MASK = DEPO.BUSINESSUNITMAP
			AND BU.TENANTID = itenantId 
			
    WHERE
        depo.TENANTID = itenantId
        AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq
        AND depo.PERIODSEQ = iperiodseq
        ;

    filas := sql%rowcount;
    COMMIT;
    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_CTAS_CES: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_DEPOSIT_CTAS_CES COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_CTAS_CES.',v_contador_debug);
	
end;
/*EOM APM 14.04.2025 Informes CTAs*/

/* *****************************
************* RUN *************
***************************** */
PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,
                periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,
                stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,
                salidacontrol out varchar2,informe varchar2 ) IS
    
v_Interfaz_Proceso  nvarchar2(50);  
v_Listado_Informes  nvarchar2(500);
v_PeriodoLiquidado boolean;
v_periodo VARCHAR2(50); --APM 12.12.2022
v_puseq VARCHAR2(50); --APM 12.12.2022

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
    
    /*BOM APM 12.12.2022 - Creamos variables auxiliares para informar el periodo y PU para usar en la tabla ENEL_CUADRELIQ_FINAL_CES */
    v_periodo := period;
    v_puseq := processingUnitSeq;
    /*EOM  APM 12.12.2022*/
    
    if  triggerFilename = 'EJECUCION_MANUAL' then
        w_debug('Peticion de ejecucion manual con periodo '||period, v_contador_debug);
        w_debug('Informes a actualizar  '||informe, v_contador_debug);
        v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_MANUAL';
        
        if informe = '' or informe is null then  -- MRA 
            v_Listado_Informes := 'ALL';
            w_debug('Argumento Actualizado : informe : ['||v_Listado_Informes ||'] (EJECUCION_MANUAL)',V_CONTADOR_DEBUG);
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
       
        if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_POST' then
			-- se deben actualizar los estados de las tablas
			UPDATE ENELEXT.ENEL_CUADRELIQ_FINAL_CES
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
            /*BOM APM 12.12.2022 */
			/*WHERE Periodo = period
			and PROCESSINGUNITSEQ = processingunitseq*/
            WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq
            /*EOM APM 12.12.2022 */
			;
			
			--RAPPELES
			UPDATE ENELEXT.ENEL_RAPPELES_CES
			SET CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = period
			and PROCESSINGUNITSEQ = processingunitseq
			;
                -- MRMM 12/11/21 BOF
			--AGREGADO FACTURACION 
            UPDATE ENELEXT.ENEL_AGREFACT_FINAL_CES
			SET FECHA_PREFACTURA = SYSDATE
			WHERE Periodo = period
			and PROCESSINGUNITSEQ = processingunitseq
			;
            
            --PREFACTURA CETVTA
            UPDATE ENELEXT.ENEL_PREFACTURA_CETVTA
			SET FECHA_LIQUIDACION = SYSDATE
			WHERE Periodo = period
			and PROCESSINGUNITSEQ = processingunitseq
            ;
             -- MRMM 12/11/21 EOF
			
            COMMIT; --APM 14.12.2022
            
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
        p_Temporal_TXN_truncate( processingUnitSeq, period ,periodSeq , tenantId  );
		p_Temporal_Transacciones ( processingUnitSeq, period ,periodSeq , tenantId  );
		
		p_Temporal_Medidas ( processingUnitSeq, period, periodseq, tenantId );
		
        -- Volcar datos de la tabla de creditos a una tabla temporal. Tabla ENEL_CREDIT_TEMP
        p_Temporal_Creditos ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de incentivos a una tabla temporal. Tabla ENEL_INCEN_TEMP
        p_Temporal_Incentivos ( processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de la tabla de Depositos a una tabla temporal. Tabla ENEL_DEPOSIT_TEMP
        p_Temporal_Depositos ( processingUnitSeq, period ,periodSeq , tenantId  );
		-- Volcar datos de la tabla de Comisiones a una temporal. Tabla ENEL_COMMISSION_TEMP
        p_Temporal_Commission (  processingUnitSeq, period ,periodSeq , tenantId  );
        -- Volcar datos de clasificacion a una Temporal de Proveedores. Tabla ENEL_PROVEEDORES_TEMP
        p_Temporal_Orden_Imputacion ( period ,periodSeq , tenantId  );
        -- Volcar datos de clasificacion a una Temporal de Equipamientos Tabla ENEL_EQUIPAMIENTO_TEMP        
        p_Temporal_Equipamientos ( period ,periodSeq , tenantId  );
        -- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PDS_TEMP
        p_Temporal_Pds ( processingUnitSeq, period ,periodSeq , tenantId  );
        
        p_Temporal_E4E_Negativos ( period ,periodSeq , tenantId  );
		          
		if(processingUnit='B2B CE TVTA') then
        
            IF f_ExisteInformeEnLista('E4E_TVTA', v_Listado_Informes) THEN
                -- Volcar datos de clasificaci?n a una Temporal de Contratos. Tabla ENEL_E4E_CONTRATOS_TEMP
                p_Temporal_Contratos_E4E ( period ,periodSeq , tenantId  );
                end if;
			---------------------------------------
			-- Datos para Mensual de Liquidacion --
			---------------------------------------
			IF f_ExisteInformeEnLista('LIQ_TVTA', v_Listado_Informes) THEN
				-- Extraer datos para Interface de LIQUIDACION MENSUAL
				p_Cuadre_Liquidacion (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
				p_rappeles(period, periodseq, tenantId, v_Interfaz_Proceso, processingUnitSeq);
				p_remun (processingUnitSeq, period, periodseq, tenantId, v_Interfaz_Proceso);
				p_Clasificacion_Evento (period, periodseq, tenantId, processingUnitSeq);
                p_Agregado_Facturacion (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
                -- Actualizamos la fecha del informes en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'LIQ_TVTA');    
			end if;
		
			--------------------------------
            -- Datos para INTERFACE E4E
            --------------------------------
            IF f_ExisteInformeEnLista('E4E_TVTA', v_Listado_Informes) THEN

                -- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_TEMP
                p_Temporal_Depositos_E4E ( processingUnitSeq, period ,periodSeq , tenantId, v_Interfaz_Proceso  );
    
                -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 1 
                p_Final_E4E_1 ( period ,periodSeq , tenantId  );

                -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 2 
                p_Final_E4E_2 ( period ,periodSeq , tenantId  );
            
                -- Actualizamos la fecha del informes en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'E4E_TVTA');

				-- Extraer datos NEGATIVOS de TEMP_Depositos. Tabla: ENEL_E4E_NEGATIVOS
				p_Final_E4E_Negativos ( processingUnitSeq, period ,periodSeq , tenantId  );   
				-- Actualizamos la fecha del informe en la tabla 
				p_Actualiza_Informe_Fecha ( period, 'E4ENEG_TVTA');
            end if;

            ----------------------------
            -- Datos para Liquidacion --
            ----------------------------
            IF f_ExisteInformeEnLista('LIQFINAL_TVTA', v_Listado_Informes) THEN  
                -- Extraer datos de creditos calculados para el periodo -> Tabla : ENEL_SCAWEB_LIQUIDACION
                p_Liquidacion_Final ( processingUnitSeq, period ,periodSeq , tenantId  );       
                -- Actualizamos la fecha del informes en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'LIQFINAL_TVTA');
            end if;
    
            -- Comparativa Pagos solo se hace si se ejecutan todos los informes
            IF v_Listado_Informes = 'ALL' THEN
                p_Comparativa_Pagos_E4E( processingUnitSeq, period ,periodSeq , tenantId  );
				
				-- Actualizamos la fecha del informes en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'CANAL_TVTA');
            end if;        
     
            ---------------------------------------------------
            -- Datos para PREFACTURA
            ---------------------------------------------------
            IF f_ExisteInformeEnLista('PREFACT_TVTA', v_Listado_Informes) THEN
                -- Extraer datos para detalle de PreFactura
                p_Prefactura ( processingUnitSeq, period ,periodSeq , tenantId, v_Interfaz_Proceso );

                -- Actualizamos la fecha del informes en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'PREFACT_TVTA');   
            end if;
            
            /*BOM APM 14.04.2025 Informes CTAs*/
            p_informe_cta (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
            /*EOM APM 14.04.2025 Informes CTAs*/
            
        end if;
    
	ELSE
		w_debug('Periodo YA Liquidado. NO se actualizan Datos de INFORMES', v_contador_debug);
	end if;

	w_debug('Procedure END', v_contador_debug);
	salidacontrol :='Procedure '||v_Interfaz_Proceso||' END';
    
	COMMIT;    
END;
            
END;