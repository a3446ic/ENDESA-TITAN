create or replace PACKAGE BODY           "ENEL_ACTUALIZA_INFORMES_OFV" AS
/* *****************************************************************************
   NAME:       ACTUALIZA_INFORMES
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        06/07/2017  Sergio Soriano. Created this package.
   1.1        04/10/2017  Marcos Rodellar Change CS_DEPOSIT with CS_PAYMENT  
                                          in p_Temporal_Depositos_E4E procedure
   1.2        09/10/2017 Marcos Rodellar  p_Temporal_Depositos_E4E procedure will use 
                                          CS_DEPOSIT in Reward Stage 
                                          and CS_PAYMENT  in Pay stage
                                          Add fields in ENEL_INFPDS_CREDIT_TEMP table

   1.3        16/10/2017 Marcos Rodellar  Format MM/DD/YYYY Fecha_Calculo en Andromeda FINAL
                                          Tabla Revision de creditos INFPDS   

   1.31       17/10/2017 MRA              Incidencia: Modificacion Query de p_Final_STP_INFPDS 
                                          para que coja todos los creditos y no solo Importe Base 

   1.32       19/10/2017 MRA              Modificacion Query de p_Final_Andromeda, Se fuerza que 
                                          VALUE y PREADJUSTEDVALUE salgan con 2 decimales y separador decimal '.'

   1.33       20/10/2017 MRA              Modificacion p_Temporal_TXN_INFPDS para hacer LEFT JOIN entre TXN 
                                          con la tabla de atrib. extendidos, de direcciones y de Asignacion 
                                          porque no salian los Ajuste (que no tienen Extendidos)

   1.34       30/10/2017 MRA              Modificacion generacion de datos para ENEL_SCAWEB_LIQUIDACION para 
                                          que el periodo de liquidacion se corresponda con el mes siguiente 
                                          al PERIODO calculado

   1.4       30/10/2017 MRA              Modificacion para Ejecucion Manual, si Informe viene vacio se asume ALL

   1.5       02/11/2017 MRA              Modificacion ejecucion de Andromeda: nueva funcion f_ComprobarPeriodoLiquidado
                                         para comprobar si el periodo existe como Liquidado en la tabla ENEL_PERIODOS_LIQUIDADOS

   1.6      09/11/2017 MRA              Modificacion en extraccion de TXN para Andromeda y INFPDS: Se aniade GA3 - ESTADO_GA3 
                                        para determinar estado Pte. Revisar en funcion de GA3 y GA4 de TXns
                                        Se aniade generacion de tabla Resumen de Pagos 

   1.7      10/11/2017 MRA              Modificacion p_Temporal_TXN_Andromeda en carga de  ENEL_ANDROMEDA_FINAL en 2 partes:
                                        - LEFT JOIN  ="%Importes Base" para Prestacion e Instalacion y %Ajuste manual para Ajustes Manuales
                                        - INNER JOIN <> "%Importes Base" para Prestacion e Instalacion 
                                        - UPDATE a Pte. Revisar para los registros que no son "%Importes Base" para Prestacion e Instalacion 
                                          y cuyos "Importes base" estan en "Pte Revisar" 

   2.0      11/12/2017 MRA              Modificaciones para SPRINT 2

   2.1      S26/02/2018 MRA              Se elimina la condicion de credito con valor 0 genera estado Pte Revisar en Tabla Final de Andromeda

   2.2      02/03/2018 MRA              p_Inf_Factura_PDS_Detalle: Se modifica la restriccion de incentivos 'I - Captacion%' y se modifica para obtener tambien Incentivos de Atencion 

   2.3      06/03/2018 MRA              p_Temporal_TXN_Andromeda:Se filtra por EVENTYPEID y se optimiza obteniendo los datos de la temporal general de transacciones
                                        p_Temporal_Creditos: Se aniade campo COMMENTS
                                        p_Temporal_Creditos_Andromeda: se optimiza obteniendo los datos de la temporal general de creditos

   2.4      09/03/2018 MRA              Actualizacion de datos del E4E_Negativos se hace solo en el Reward ya que en fase de pagos no hay negativos en CS_PAYMENT

  2.5      09/03/2018 MRA              Incidencia en E4E al extraer datos sin agrupar de CS_PAYMENT

  2.6        11/02/2019 LLS                Modificado el p_Temporal_Creditos_Scaweb para sacar el campo RULENAME y poder filtra en el informe los canales CNS, AAFF y ALICO

  2.4        12/02/2019    LLS                Creado p_rappeles_completo, p_tasa_fidelizacion, p_tasa_arrastre, p_decomisado

  2.5        14/02/2019    LLS                Modificado p_Temporal_Depositos_E4E para incluir los campos VALOR_INSTALADORES, VALOR_AAFF y VALOR_ALIADOS
                                        Modificado p_Comparativa_Pagos_SCAWEB_E4E para incluir los campos E4E_INSTALADORES, E4E_AAFF y E4E_ALIADOS

  2.6        15/02/2019    LLS                Aniadido el campo SUBPOSICION a ENEL_E4E_CONTRATOS_TEMP y ENEL_E4E_DEPOSIT_TEMP 
                                        Para p_final_e4e_1 y p_final_e4e_2 para que en el campo7 de la linea SERVICIO se ponga el campo SUBPOSICION (en caso de nulo se informa de nuevo el 10)

  2.7        14/02/2022    DCR             Foto Fija: Rentabilidad no funciona pq toma Event Type = OFV Volumen. Se añaden las reglas de dinamico tmb (cartera gas y cartera activa gas)
  
  2.8        10/03/2022    DCR             Foto Fija: Se cambia la logica (Cod = FF1)
  
  2.9        18/10/2022    RMM            informes OFV

***************************************************************************** */

    v_eot DATE := TO_DATE('22000101','yyyymmdd');
	v_periodo VARCHAR2(50 BYTE);
    v_contador_debug integer; 
    v_classifierid         CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION        CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA            CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS        CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD        CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO            CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
    filas number; --Para el DEBUG de los INSERT

/* *****************************
    Debug en ENELEXT.ENEL_DEBUB
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
	Where CT.NAME='Salida' 
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
procedure p_Temporal_Transacciones (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_OFV.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_TXN_TEMP_OFV WHERE periodo=iperiod and ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP_OFV. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);
	
	INSERT INTO ENELEXT.ENEL_TXN_TEMP_OFV( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, ACCOUNTINGDATE, 
                                        PRODUCTID, PONUMBER, DATASOURCE,PROCESSINGUNITSEQ, ALTERNATEORDERNUMBER, GENERICATTRIBUTE3, GENERICATTRIBUTE27, GENERICATTRIBUTE29, GENERICNUMBER9, 
										GENERICNUMBER10, GENERICATTRIBUTE28, GENERICATTRIBUTE6, GENERICATTRIBUTE15, GENERICATTRIBUTE1, GENERICATTRIBUTE11, GENERICATTRIBUTE13, GENERICATTRIBUTE20,
										GENERICNUMBER15, GENERICATTRIBUTE24, TEX0_GENERICDATE7, TEX0_GENERICDATE13, TEX0_GENERICNUMBER14, TEX0_GENERICNUMBER16, TEX0_GENERICNUMBER13, 
                                        TEX0_GENERICNUMBER12, TEX0_GENERICNUMBER11, TEX0_GENERICBOOLEAN1, TEX0_GENERICBOOLEAN3, GENERICNUMBER2, PRODUCTNAME,
										GENERICDATE4, GENERICDATE5, TEX0_GENERICDATE10, TEX0_GENERICDATE11, GENERICNUMBER5, GENERICNUMBER6, GENERICNUMBER7, GENERICATTRIBUTE31, GENERICATTRIBUTE32, GENERICATTRIBUTE23,
                                        TXN_GENERICATTRIBUTE20, TXN_GENERICATTRIBUTE26 , TXN_COMMENTS , VALUE,
                                        FECHA_INICIO_LOTE, FECHA_CIERRE, GENERICATTRIBUTE10, --APM 19/10/2022 Incluir nuevos campos
                                        SUB_PRD, COD_OPP -- RMM 31.01.2023      
                                        )
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
		TXN.PONUMBER as Contrato,
		TXN.DATASOURCE,
		TXN.PROCESSINGUNITSEQ,
		-- MPR nuevo campo para informe Volumen
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICATTRIBUTE3 AS ESTADO,
		TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
		TXN.GENERICATTRIBUTE29 AS CIF,
		ETXN0.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
		ETXN0.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
		TXN.GENERICATTRIBUTE28 AS PRESION,
		TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
		ETXN0.GENERICATTRIBUTE15 AS TARIFA, 
		TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO,
		TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
		ETXN0.GENERICATTRIBUTE13 AS LINEA_NEGOCIO, 
		--MPR nuevos campos para rentabilidad
		ETXN0.GENERICATTRIBUTE20 AS CUARTIL,
		ETXN0.GENERICNUMBER15 AS VOLUMEN_NEGOCIADO, 
		TXN.GENERICATTRIBUTE24 AS COMPONENTE,
		
		ETXN0.GENERICDATE7 AS FECHA_NEGOCIACION,
        ETXN0.GENERICDATE13 AS FECHA_CONTRATO, 
        ETXN0.GENERICNUMBER14 AS PRECIO_CERRADO,
        ETXN0.GENERICNUMBER16 AS PRECIO_MINI_SD,
        ETXN0.GENERICNUMBER13 AS PRECIO_MINI_RT,
        ETXN0.GENERICNUMBER12 AS PRECIO_MINI_GESTOR,
        ETXN0.GENERICNUMBER11 AS PRECIO_MINI_OBJETIVO,
        TXN.GENERICBOOLEAN1 AS GESTION_CARTERA,
        TXN.GENERICBOOLEAN3 AS RRAA,
        TXN.GENERICNUMBER2 AS VERSION, --MPR Se modifica el campo de version
		TXN.PRODUCTNAME,
		TXN.GENERICDATE4 AS FECHA_ALTA,
		TXN.GENERICDATE5 AS FECHA_BAJA,
		ETXN0.GENERICDATE10 AS FECHA_INI_VERSION, 
		ETXN0.GENERICDATE11 AS FECHA_FIN_VERSION,
		TXN.GENERICNUMBER5 AS MARGEN,
        ETXN0.GENERICNUMBER6 AS PRECIO_OBJETIVO_3, --RMM
        ETXN0.GENERICNUMBER7 AS PRECIO_MAXIMO,--RMM
        TXN.GENERICATTRIBUTE31 AS GRP_EMP,
        TXN.GENERICATTRIBUTE32 AS LOTE,
        TXN.GENERICATTRIBUTE23 AS CAMPANA,
        --RMM
        TXN.GENERICATTRIBUTE20 AS  FRCC,
         TXN.GENERICATTRIBUTE26 AS  GRUPO_EMPRESARIAL, --RMM 23.05.2022
         TXN.COMMENTS AS  COMENTARIOS, --RMM 23.05.2022
         TXN.VALUE AS  VALUE, --RMM 23.05.2022
         --BOM APM 19/10/2022
         etxn0.GENERICDATE12 AS FECHA_INICIO_LOTE,
         etxn0.GENERICDATE1  AS FECHA_CIERRE,
         --EOM APM 19/10/2022
         txn.GENERICATTRIBUTE10 as GENERICATTRIBUTE10,
         --BOM - RMM 31.01.2023
         TXN.GENERICATTRIBUTE2 AS sub_prd,
         TXN.GENERICATTRIBUTE8 AS cod_opp
         --EOM - RMM 31.01.2023
         
         
	FROM CS_SALESTRANSACTION txn
		INNER JOIN CS_SALESORDER ordtxn
			ON TXN.SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
			AND ORDTXN.PROCESSINGUNITSEQ = iprocessingunitseq
			AND txn.compensationdate BETWEEN v_periodstartdate AND v_periodenddate
			AND TXN.TENANTID = itenantId
			AND TXN.MODELSEQ = 0
			AND TXN.PROCESSINGUNITSEQ = iprocessingunitseq
			AND ordtxn.tenantid = txn.tenantid
			
		INNER JOIN CS_EVENTTYPE etype
			ON TXN.EVENTTYPESEQ = etype.DATATYPESEQ
			AND ETYPE.REMOVEDATE  = v_eot
			AND txn.tenantid = etype.tenantid
		
		LEFT JOIN cs_gasalestransaction etxn0
			ON txn.salestransactionseq = etxn0.salestransactionseq
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate
	;
/*	
	WHERE  PER.TENANTID =  'ENEL'
		AND PER.REMOVEDATE = v_eot
		AND TXN.COMPENSATIONDATE >= '01/01/2019'
		AND per.periodseq=iperiodseq;
*/

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP.',v_contador_debug);

end;

--------- Volcar datos de la tabla de Creditos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_CREDIT_TEMP ----

procedure p_Temporal_Creditos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP_OFV.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CREDIT_TEMP_OFV WHERE periodo=iperiod and ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP_OFV. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CREDIT_TEMP_OFV( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, 
											POSITIONSEQ, COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, 
											GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, 
											GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, 
											GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, GENERICATTRIBUTE16, GENERICDATE3, 
											GENERICDATE2)
	SELECT 
		credit.TENANTID,
		credit.PERIODSEQ,
		per.name PERIODO,
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
		credit.VALUE,                  --Importe Comision
		credit.PREADJUSTEDVALUE,
		credit.GENERICATTRIBUTE1,      -- Concepto Liquidacion
		credit.GENERICATTRIBUTE2,      -- Proveedor
		credit.GENERICATTRIBUTE3,      -- Servicio
		credit.GENERICATTRIBUTE4,      -- Prestador - PDS                        
		credit.GENERICATTRIBUTE5,      -- Plazo
		credit.GENERICATTRIBUTE6,      -- componente 
		credit.GENERICATTRIBUTE7,      -- Zona
		credit.GENERICATTRIBUTE8,      -- Producto
		credit.GENERICATTRIBUTE9,      -- Solicitud de servicio
		credit.GENERICATTRIBUTE10,     -- Equipamiento            
		null,
		--credit.GENERICATTRIBUTE11,     -- CodigoPostal
		credit.GENERICATTRIBUTE12,     -- Modalidad de Pago            
		credit.GENERICATTRIBUTE13,     --MotivoResultado
		credit.GENERICATTRIBUTE14,     --Descripcion Concepto Liquidacion
		credit.GENERICATTRIBUTE15,     --Observaciones Ajustes Manuales
		credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
		credit.GENERICBOOLEAN2,        -- S/S Garantia
		credit.GENERICDATE1,           --FechaCalculo
		credit.GENERICNUMBER1,
		credit.GENERICNUMBER3, --se guarda en GENERICNUMBER2
		credit.GENERICNUMBER4, --se guarda en GENERICNUMBER3
		credit.GENERICNUMBER5, --se guarda en GENERICNUMBER4
        credit.GENERICNUMBER6, --se guarda en GENERICNUMBER6
		--MPR nuevos campos para informe OFV
		credit.GENERICATTRIBUTE16,
		credit.GENERICDATE3,
		credit.GENERICDATE2

	FROM CS_CREDIT credit
		INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
		INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
		inner join cs_period per
			on per.removedate =v_eot
			and credit.periodseq=per.periodseq
	WHERE
		credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND PER.periodseq=iperiodseq
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_TEMP_OFV.',v_contador_debug);

end;

--------- Volcar datos de la tabla de Incentivos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_INCEN_TEMP ----

procedure p_Temporal_Incentivos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP_OFV. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_INCEN_TEMP_OFV(  TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
                                           GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE16, 
                                           GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
                                           GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2    )
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
	WHERE
		incent.TENANTID = itenantId 
		AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND incent.PERIODSEQ =  iperiodseq
		-- MPR se quita porque en B2B no es necesaria esta condicion
		--AND incent.GENERICATTRIBUTE1 is not null
        ;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INCEN_TEMP_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP_OFV.',v_contador_debug);

end;         

--------- Volcar datos de la tabla de Depositos a una Temporal general para usar como base en todas las demas extracciones 
---------- Tabla ENEL_DEPOSIT_TEMP ----

procedure p_Temporal_Depositos (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP_OFV. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP_OFV( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
                                            PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5, processingunitseq    )
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
		case when LENGTH(depo.EARNINGGROUPID) = '3' then depo.EARNINGGROUPID
		else genericattribute6 end as idproveedor,
		--depo.EARNINGGROUPID,
		depo.COMMENTS,
		depo.GENERICATTRIBUTE1,      -- Actividad
		depo.GENERICATTRIBUTE2,
		depo.GENERICATTRIBUTE5,
		depo.processingunitseq

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

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP_OFV.',v_contador_debug);

end;         

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----

procedure p_Temporal_Proveedores ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP_OFV.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP_OFV. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP_OFV( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
													WBE_FINAL_IMPUTACION,DETALLE_ACTIVIDAD,ACTIVIDAD,SOCIEDAD,
                                                    CENTRO_LOGISTICO,GR_COMPRAS,TIPO_PAGO, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR,subactividad )
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
			-- AND C.ISLAST = 1
		INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
			--  AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
			AND GC.TENANTID = itenantId
			AND GC.REMOVEDATE = v_eot
			AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
			AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
			-- AND GC.ISLAST = 1
	WHERE GCT.NAME like 'Proveedor%';
    
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP_OFV.',v_contador_debug);

end;

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_PROVEEDORES_TEMP ----

procedure p_Temporal_Equipamientos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_EQUIPAMIENTO_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_OFV.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_EQUIPAMIENTO_TEMP_OFV. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_EQUIPAMIENTO_TEMP_OFV( TENANTID,PERIODSEQ,EQUIPAMIENTO, IDMARCA, MARCA, IDMODELO, MODELO, IDTIPO,
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
	WHERE 
		GCT.NAME ='Equipamiento';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);
end;

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_OPERACIONES_TEMP ----

procedure p_Temporal_Operaciones ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_OPERACIONES_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OPERACIONES_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_OPERACIONES_TEMP_OFV.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_OPERACIONES_TEMP_OFV. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_OPERACIONES_TEMP_OFV( TENANTID, PERIODSEQ, OPERACIONID, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, 
                                                AGRUPA_EN_FACTURA, FECHA_INICIO_VIGOR, FECHA_FIN_VIGOR)
	SELECT 
		itenantId TENANTID,
		iperiodseq PERIDOSEQ,
		C.CLASSIFIERID OPERACIONID,
		GC.GENERICATTRIBUTE1 TIPO_ENTRADA,
		GC.GENERICATTRIBUTE2 TIPO_OPERACION,
		GC.GENERICATTRIBUTE3 SUBTIPO_OPERACION,
		GC.GENERICBOOLEAN1 AGRUPA_EN_FACTURA,
		C.EFFECTIVESTARTDATE FECHA_INICIO_VIGOR,
		C.EFFECTIVEENDDATE FECHA_FIN_VIGOR

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

	WHERE GCT.NAME ='Operacion';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);
end;

--------- Volcar datos de Productos a una Temporal. 
---------- Tabla ENEL_PRODUCTOS_TEMP ----

procedure p_Temporal_Productos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_PRODUCTOS_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PRODUCTOS_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_PRODUCTOS_TEMP_OFV.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PRODUCTOS_TEMP_OFV. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PRODUCTOS_TEMP_OFV( TENANTID, PERIODSEQ, PRODUCTID, DESCRIPTION, NAME, FAMILIA, PROVEEDOR_PRESTACION, PROVEEDOR_CAPTACION, 
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
	WHERE 
		PROD.REMOVEDATE = v_eot
		AND PROD.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
		AND PROD.EFFECTIVEENDDATE >= v_ultimo_dia_periodo; 

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PRODUCTOS_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

end;

--------- Volcar datos de Posiciones y participantes a una Temporal de PDS   -------- 
--------- Tabla: ENEL_PDS_TEMP  --------
procedure p_Temporal_Pds (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP_OFV.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP_OFV';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PDS_TEMP_OFV. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PDS_TEMP_OFV( PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
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
		JOIN CS_POSITION pos 
			ON pos.REMOVEDATE = v_eot
			AND pos.TENANTID = itenantId 
			AND pos.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND pos.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            -- and POS.ISLAST = 1   -- Con esta condicion no se quedaba con la version correcta asociada al fichero
			and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq

        INNER JOIN CS_PARTICIPANT par 
			ON POS.PAYEESEQ = PAR.PAYEESEQ
			AND par.TENANTID = itenantId
			AND par.REMOVEDATE = v_eot
			AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
			AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
			--and PAR.ISLAST = 1 -- Con esta condicion no se quedaba con la version correcta asociada al fichero

        INNER JOIN CS_PAYEE payee 
			ON PAR.PAYEESEQ = PAYEE.PAYEESEQ
			AND PAYEE.REMOVEDATE =  v_eot
			--AND PAYEE.ISLAST =1   -- Con esta condicion no se quedaba con la version correcta asociada al fichero
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

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PDS_TEMP_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP_OFV.',v_contador_debug);

end;

-- Extraer datos de Dep?sitos y JOIN con tablas temporales 
-- Tabla: ENEL_E4E_DEPOSIT_TEMP

-- Comrpueba si el periodo esta Liquidado ya o no. Si esta Liquidado, los datos de andromeda no deben actualizarse
function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
    v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin
	-- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
	SELECT count(ESTADO)
		into v_checkCountEstado
	FROM ENELEXT.ENEL_PERIODOS_LIQUIDADOS epl 
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

procedure p_Temporal_Medidas (iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin
    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_TEMP_OFV.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_TEMP_OFV WHERE ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_TEMP_OFV.', v_contador_debug);

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_TEMP_OFV.' ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_MEDIDAS_TEMP_OFV(TENANTID,PERIODSEQ, PERIODO, NAME, VALUE, MEASUREMENTSEQ, PAYEESEQ, POSITIONSEQ, PIPELINERUNSEQ, PLANSEQ, RULESEQ,
                                            GENERICATTRIBUTE1,GENERICATTRIBUTE2,GENERICATTRIBUTE3,GENERICATTRIBUTE4,GENERICATTRIBUTE5,GENERICATTRIBUTE6,
                                            GENERICATTRIBUTE7,GENERICATTRIBUTE8,GENERICATTRIBUTE9,GENERICATTRIBUTE10,GENERICATTRIBUTE11,GENERICATTRIBUTE12,
                                            GENERICATTRIBUTE13,GENERICATTRIBUTE14,GENERICATTRIBUTE15,GENERICATTRIBUTE16,GENERICNUMBER1,UNITTYPEFORGENERICNUMBER1,
                                            GENERICNUMBER2,UNITTYPEFORGENERICNUMBER2,GENERICNUMBER3,UNITTYPEFORGENERICNUMBER3,GENERICNUMBER4,
                                            UNITTYPEFORGENERICNUMBER4,GENERICNUMBER5,UNITTYPEFORGENERICNUMBER5,GENERICNUMBER6,UNITTYPEFORGENERICNUMBER6,GENERICDATE1,
                                            GENERICDATE2,GENERICDATE3,GENERICDATE4,GENERICDATE5,GENERICDATE6,GENERICBOOLEAN1,GENERICBOOLEAN2,
                                            GENERICBOOLEAN3,GENERICBOOLEAN4,GENERICBOOLEAN5,GENERICBOOLEAN6)
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
		CSM.RULESEQ,
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

	FROM CS_MEASUREMENT CSM
		inner join cs_period csp 
			on csm.periodseq=csp.periodseq
			and csp.removedate= v_eot
                
		inner join cs_position cspo
			on csm.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and csp.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where csm.processingunitseq=iprocessingunitseq
		and csp.periodseq=iperiodseq
        AND CSPO.NAME NOT IN 
			(SELECT NAME
				FROM CS_POSITION
				WHERE REMOVEDATE = v_eot
				AND EFFECTIVEENDDATE < '01/12/19'
			)

	UNION

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
		CSM.RULESEQ,
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
                
	FROM CS_MEASUREMENT CSM
		inner join cs_period csp 
			on csm.periodseq=csp.periodseq
			and csp.removedate = v_eot
                
		inner join cs_position cspo
			on csm.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and csp.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where csm.processingunitseq=iprocessingunitseq
		and substr(csp.name, length(csp.name)-3, 4) = substr(iperiod, length(iperiod)-3, 4)
        and csp.name <> iperiod
        AND CSPO.NAME IN 
			(SELECT NAME
				FROM CS_POSITION
				WHERE REMOVEDATE = v_eot
				GROUP BY NAME
				HAVING COUNT(*) >= 2
			)
		and cspo.EFFECTIVEENDDATE between csp.startdate and csp.enddate
	;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_TEMP_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_TEMP_OFV',v_contador_debug);

end;

-- Fichero de VISITAS
procedure p_Medidas_Final ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
AS
begin  
    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_FINAL_OFV.', v_contador_debug);
	BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_FINAL_OFV 
				WHERE ANIO=
					(select to_char(startdate,'YYYY')
						from cs_period
						where periodseq=iperiodseq
						and removedate= v_eot) 
					and(estado='Pte Enviar' or estado is null) 
					and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_FINAL_OFV.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_OFV(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,NVISITAS,OBJ_PRORRATEO,VALUE,CUMPLIMIENTO,CONSECUCION, CONSECUCION_USUARIO)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select 
			to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'USUARIO','FICHA','VISITAS_TOTALES','OBJETIVO_PRORRATEADO', 'PORC_CONSECUCION', 'CUMPLIMIENTO_OBJETIVO', 
		'PORC_CONSECUCION_PROYECTADA', 'PORC_CONSECUCION_TOTAL_POR_USUARIO');

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_FINAL_OFV.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_OFV(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,
												NVISITAS,OBJ_PRORRATEO,VALUE,CUMPLIMIENTO,CONSECUCION, CONSECUCION_USUARIO)
	Select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY'),
		cspa.userid, --PARTICIPANTID
		cspo.name, -- IDFICHA
		(select round(genericnumber1,0) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%Visitas%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "NVISITAS",
		
		(select round(genericnumber4,0) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%Visitas%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "OBJ_PRORRATEO",
		
		(select TRIM(to_char(emt2.value *100 , '9999999999990D99')) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%Visitas%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "VALUE",
		
		(select emt2.genericattribute3 from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%Visitas%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "CUMPLIMIENTO",
		
		(select TRIM(to_char(emt2.genericnumber3 * 100, '9999999999990D99')) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%Visitas%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "CONSECUCION",
		
		(select TRIM(to_char(EMT2.GENERICNUMBER5 * 100, '9999999999990D99')) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%Visitas%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "CONSECUCION_USUARIO"

	from enel_medidas_temp_ofv emt
        inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
        
        inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate

		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		emt.name like 'MS - OFV - Visitas - %'
		and emt.genericboolean1 = 1
		and cspa.payeeseq not like '4503599627373822'
        and cspo.ruleelementownerseq not like '4785074604087002'
        and 0= (select count(*) from enel_medidas_final_ofv where userid=cspa.userid and idficha=cspo.name and periodo=iperiod)
/* 
		and cspo.ruleelementownerseq not in 
			(SELECT positionseq FROM enel_medidas_temp_ofv
				GROUP BY positionseq
				HAVING COUNT(*) >= 2
			)
*/
	;
	
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_FINAL_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_FINAL_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_FINAL_OFV',v_contador_debug);

end;

-- MPR nuevo procedimiento para medidas finales PSVAs
procedure p_Medidas_Final_PSVA ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
AS
begin  
    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_FINAL_PSVA.', v_contador_debug);
	BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_FINAL_PSVA 
				WHERE ANIO=
					(select to_char(startdate,'YYYY')
						from cs_period
						where periodseq=iperiodseq
						and removedate= v_eot) 
					and(estado='Pte Enviar' or estado is null) 
					and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_FINAL_PSVA.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_PSVA(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,
                                                EUROS_TOTALES, OBJETIVO_PRORRATEAEDO, PORC_CONSECUCION, CUMPLIMIENTO_OBJETIVO, PORC_CONSECUCION_PROYECTADA, PORC_CONSECUCION_TOTAL_USUARIO)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select 
			to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'USUARIO','FICHA','EUROS_TOTALES', 'OBJETIVO_PRORRATEAEDO', 'PORC_CONSECUCION', 'CUMPLIMIENTO_OBJETIVO', 
		'PORC_CONSECUCION_PROYECTADA', 'PORC_CONSECUCION_TOTAL_USUARIO');

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_FINAL_PSVA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_PSVA(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,
												-- Info de PSVAs
                                                EUROS_TOTALES, OBJETIVO_PRORRATEAEDO, PORC_CONSECUCION, CUMPLIMIENTO_OBJETIVO, PORC_CONSECUCION_PROYECTADA, PORC_CONSECUCION_TOTAL_USUARIO)
	Select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY'),
		cspa.userid,
		cspo.name,
		-- Info de PSVAs
		(select round(genericnumber1,2) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%- PSVAs%' and emt2.genericboolean1 = 1 and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq and emt2.genericboolean1 = 1) as EUROS_TOTALES,
		
		(select round(genericnumber4,2) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%- PSVAs%' and emt2.genericboolean1 = 1 and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq )as OBJETIVO_PRORRATEAEDO,
		
		--(select TRIM(to_char(value*100, '9999999999990D99')) from cs_incentive incen where incen.name like '%PSVAs%' and incen.name not like '%Premio%' and incen.processingunitseq=38280596832649418 and incen.payeeseq=cspa.payeeseq and incen.positionseq=cspo.ruleelementownerseq and incen.periodseq=cspe.periodseq and genericnumber4 is not null)as PORC_CONSECUCION,
		
		(select TRIM(to_char(emt2.value *100 , '9999999999990D99')) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%- PSVAs%' and emt2.genericboolean1 = 1 and emt2.measurementseq = emt.measurementseq and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION",
		
		(select genericattribute3 from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%- PSVAs%' and emt2.genericboolean1 = 1 and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq ) as CUMPLIMIENTO_OBJETIVO,
		
		(select TRIM(to_char(genericnumber3*100, '9999999999990D99')) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%- PSVAs%' and emt2.genericboolean1 = 1 and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq ) as PORC_CONSECUCION_PROYECTADA,
		
		(select TRIM(to_char(genericnumber5*100, '9999999999990D99')) from enel_medidas_temp_ofv emt2 where emt2.name like 'MS%- PSVAs%' and emt2.genericboolean1 = 1 and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq ) as PORC_CONSECUCION_TOTAL_USUARIO 

	from enel_medidas_temp_ofv emt
        inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
        
        inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
                                
		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		emt.name like 'MS%- PSVAs%' 
		and emt.genericboolean1 = 1
		and cspa.payeeseq not like '4503599627373822'
        and cspo.ruleelementownerseq not like '4785074604087002'
        and 0= (select count(*) from enel_medidas_final_psva where userid=cspa.userid and idficha=cspo.name and periodo=iperiod)
/* 
		and cspo.ruleelementownerseq not in 
			(SELECT positionseq FROM enel_medidas_temp_ofv
				GROUP BY positionseq
				HAVING COUNT(*) >= 2
			)
*/
	;
	
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_FINAL_PSVA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_FINAL_PSVA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_FINAL_PSVA',v_contador_debug);

end;

--Fichero de extraccion Volumen Electrico
procedure p_Medidas_Final_Volumen ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
AS
begin  
    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_FINAL_VOLUMEN.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_FINAL_VOLUMEN WHERE ANIO=
				(select to_char(startdate,'YYYY')
					from cs_period
					where periodseq=iperiodseq
					and removedate= v_eot
				) 
			and( estado='Pte Enviar' or estado is null) 
			and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_FINAL_VOLUMEN.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_VOLUMEN(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,GWH_TOTALES,OBJETIVO_PRORRATEAEDO,PORC_CONSECUCION_TOPADO,CUMPLIMIENTO_OBJETIVO,PORC_CONSECUCION_PROYECTADA,PORC_CONSECUCION_TOTAL_USUARIO)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'ID_USUARIO','ID_FICHA','GWH_TOTALES','OBJETIVO_PRORRATEAEDO', 'PORC_CONSECUCION_TASADA', 
		'CUMPLIMIENTO_OBJETIVO', 'PORC_CONSECUCION_PROYECTADA', 'PORC_CONSECUCION_TOTAL_POR_USUARIO'
	);

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_FINAL_VOLUMEN.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_VOLUMEN(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,GWH_TOTALES,OBJETIVO_PRORRATEAEDO,PORC_CONSECUCION_TOPADO,CUMPLIMIENTO_OBJETIVO,
													PORC_CONSECUCION_PROYECTADA,PORC_CONSECUCION_TOTAL_USUARIO)
	Select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY'),
		cspa.userid,
		cspo.name,
		
		(select trim(to_char(ROUND(genericnumber1, 2),'9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "GWH_TOTALES",
		
		(select trim(to_char(round(genericnumber4,2),'9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "OBJETIVO_PRORRATEAEDO",
		
		(select TRIM(to_char(emt2.value *100 , '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_TOPADO",
		
		(select emt2.genericattribute3 from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "CUMPLIMIENTO_OBJETIVO",
		
		(select TRIM(to_char(emt2.genericnumber3 * 100, '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_PROYECTADA",
		
		(select TRIM(to_char(EMT2.GENERICNUMBER5 * 100, '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_TOTAL_USUARIO"

	from enel_medidas_temp_ofv emt
        inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
        
        inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
                                
		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		(emt.name like 'MS - OFV - Cartera Electricidad - %'
        or emt.name like 'MS - OFV - Cartera Activa Electricidad - %'
        or emt.name like 'MS - OFV - Volumen El%ctrico - %'
        or emt.name like 'MS - OFV - Electricidad Activa Cierre - %')
		and emt.GENERICBOOLEAN1 = 1 --MPR se aNIade este campo para que no se tengan en cuenta las reglas de SF
		and cspa.payeeseq not like '4503599627373822'
        and cspo.ruleelementownerseq not like '4785074604087002'
        and 0= (select count(*) from ENEL_MEDIDAS_FINAL_VOLUMEN where userid=cspa.userid and idficha=cspo.name and periodo=iperiod);

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_FINAL_VOLUMEN: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_FINAL_VOLUMEN COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_FINAL_VOLUMEN',v_contador_debug);

end;

-- Fichero Volumen GAS
procedure p_Medidas_Final_Vol_Gas ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
AS
begin  
    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_FINAL_VOL_GAS.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_FINAL_VOL_GAS WHERE ANIO=
				(select to_char(startdate,'YYYY')
					from cs_period
					where periodseq=iperiodseq
					and removedate= v_eot
				) 
			and( estado='Pte Enviar' or estado is null) 
			and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_FINAL_VOL_GAS.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_VOL_GAS(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,GWH_TOTALES,OBJETIVO_PRORRATEAEDO,PORC_CONSECUCION_TOPADO,CUMPLIMIENTO_OBJETIVO,PORC_CONSECUCION_PROYECTADA,PORC_CONSECUCION_TOTAL_USUARIO)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'ID_USUARIO','ID_FICHA','GWH_TOTALES','OBJETIVO_PRORRATEAEDO', 'PORC_CONSECUCION_TASADA', 
		'CUMPLIMIENTO_OBJETIVO', 'PORC_CONSECUCION_PROYECTADA', 'PORC_CONSECUCION_TOTAL_POR_USUARIO'
	);

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_FINAL_VOL_GAS.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_VOL_GAS(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,GWH_TOTALES,OBJETIVO_PRORRATEAEDO,PORC_CONSECUCION_TOPADO,CUMPLIMIENTO_OBJETIVO,
													PORC_CONSECUCION_PROYECTADA,PORC_CONSECUCION_TOTAL_USUARIO)
	Select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY'),
		cspa.userid,
		cspo.name,
		
		(select TRIM(to_char(ROUND(genericnumber1, 2), '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "GWH_TOTALES",
		
		(select TRIM(to_char(round(genericnumber4,2), '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "OBJETIVO_PRORRATEAEDO",
		
		(select TRIM(to_char(emt2.value *100 , '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_TOPADO",
		
		(select emt2.genericattribute3 from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "CUMPLIMIENTO_OBJETIVO",
		
		(select TRIM(to_char(emt2.genericnumber3 * 100, '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_PROYECTADA",
		
		(select TRIM(to_char(EMT2.GENERICNUMBER5 * 100, '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_TOTAL_USUARIO"

	from enel_medidas_temp_ofv emt
        inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
        
        inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
                                
		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		(emt.name like 'MS - OFV - Cartera Gas - %'
        or emt.name like 'MS - OFV - Volumen Gas - %'
        or emt.name like 'MS - OFV - Cartera Activa Gas - %'
        --APM 29.06.2022 BOM
        or emt.name like 'MS - OFV - Gas Activo Cierre - KAM Corporativo - Consecuci%n'
        or emt.name like 'MS - OFV - Gas Activo Cierre - RT KAM Corporativo - Consecuci%n'
        --APM 29.06.2022 EOM
        )
		and emt.GENERICBOOLEAN1 = 1 --MPR se aNIade este campo para que no se tengan en cuenta las reglas de SF
		and cspa.payeeseq not like '4503599627373822'
        and cspo.ruleelementownerseq not like '4785074604087002'
        and 0= (select count(*) from ENEL_MEDIDAS_FINAL_VOL_GAS where userid=cspa.userid and idficha=cspo.name and periodo=iperiod);

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_FINAL_VOL_GAS: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_FINAL_VOL_GAS COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_FINAL_VOL_GAS',v_contador_debug);

end;

--Fichero de Rentabilidad
procedure p_Medidas_Final_V_Renta ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
AS
begin  
    w_debug('Inicio Borrado de la tabla ENEL_MEDIDAS_FINAL_V_RENTA.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_MEDIDAS_FINAL_V_RENTA WHERE ANIO=
				(select to_char(startdate,'YYYY')
					from cs_period
					where periodseq=iperiodseq
					and removedate= v_eot
				) 
			and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_MEDIDAS_FINAL_V_RENTA.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_V_RENTA(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,GWH_TOTALES,OBJETIVO_PRORRATEAEDO,PORC_CONSECUCION_TOPADO,CUMPLIMIENTO_OBJETIVO,PORC_CONSECUCION_PROYECTADA,PORC_CONSECUCION_TOTAL_USUARIO)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'ID_USUARIO','ID_FICHA','PORC_RENTABILIDAD_ELECTRICA','OBJETIVO_PRORRATEAEDO', 'PORC_CONSECUCION_TASADA', 
		'CUMPLIMIENTO_OBJETIVO', 'PORC_CONSECUCION_PROYECTADA', 'PORC_CONSECUCION_TOTAL_POR_USUARIO'
	);

    w_debug('Insertando datos en tabla ENEL_MEDIDAS_FINAL_V_RENTA.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_MEDIDAS_FINAL_V_RENTA(tenantid,periodseq,periodo,ANIO,PARTICIPANTID,IDFICHA,GWH_TOTALES,OBJETIVO_PRORRATEAEDO,PORC_CONSECUCION_TOPADO,		
													CUMPLIMIENTO_OBJETIVO, PORC_CONSECUCION_PROYECTADA,PORC_CONSECUCION_TOTAL_USUARIO)
	Select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY'),
		cspa.userid,
		cspo.name,
		--PORC_RENTABILIDAD_ELECTRICA
        (select TRIM(to_char(ROUND(genericnumber1*100, 2), '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "GWH_TOTALES",
		--OBJETIVO_PRORRATEAEDO
		(select TRIM(to_char(round(genericnumber4*100,2), '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "OBJETIVO_PRORRATEAEDO",
		--PORC_CONSECUCION_TASADA
		(select TRIM(to_char(emt2.value *100 , '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_TOPADO",
		
		(select emt2.genericattribute3 from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "CUMPLIMIENTO_OBJETIVO",
		
		(select TRIM(to_char(emt2.genericnumber3 * 100, '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_PROYECTADA",
		
		(select TRIM(to_char(EMT2.GENERICNUMBER5 * 100, '9999999999990.99')) from enel_medidas_temp_ofv emt2 where emt2.name = emt.name and emt2.payeeseq=cspa.payeeseq and emt2.periodseq=cspe.periodseq and emt2.positionseq=cspo.ruleelementownerseq) as "PORC_CONSECUCION_TOTAL_USUARIO"

	from enel_medidas_temp_ofv emt
        inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
        
        inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
                                
		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		emt.name like 'MS - OFV - Rentabilidad El%ctrica - % Consecuci%'
		and emt.GENERICBOOLEAN1 = 1 --MPR se aNIade este campo para que no se tengan en cuenta las reglas de SF
		and cspa.payeeseq not like '4503599627373822'
        and cspo.ruleelementownerseq not like '4785074604087002'
        and 0= (select count(*) from ENEL_MEDIDAS_FINAL_V_RENTA where userid=cspa.userid and idficha=cspo.name and periodo=iperiod);

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_MEDIDAS_FINAL_V_RENTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_MEDIDAS_FINAL_V_RENTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_MEDIDAS_FINAL_V_RENTA',v_contador_debug);

end;

--PROCEDIMIENTO ANTIGUO
/*procedure p_Medidas_Consecucion_Temp ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
As
begin
	w_debug('Inicio Borrado de la tabla ENEL_CONSECUCION_TEMP_OFV.', v_contador_debug);
    BEGIN
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CONSECUCION_TEMP_OFV';
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CONSECUCION_TEMP2_OFV';
	*//*
        LOOP
            DELETE FROM ENELEXT.ENEL_CONSECUCION_TEMP_OFV WHERE ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_CONSECUCION_TEMP2_OFV WHERE ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
	*//*
    END;
    w_debug('Fin Borrado de la tabla ENEL_CONSECUCION_TEMP_OFV.', v_contador_debug);
	
	w_debug('Inicio Carga de la tabla ENEL_CONSECUCION_TEMP_OFV.', v_contador_debug);
	
	INSERT INTO ENEL_CONSECUCION_TEMP_OFV  (TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
											CLIENTES_CAPTADOS_VISITAS, OBJETIVO_PRORRATEADO, PORC_CLIENTES_CAPTADOS_VISITAS, CUMPLIMIENTO_OBJETIVO, 
											CLIENTES_CAPTADOS, OBJETIVO_PRORRATEAEDO, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_1, 
											SVAS, OBJETIVO_PRORRATEADO_1, PORC_SVAS, CUMPLIMIENTO_OBJETIVO_2, 
											OFERTAS_PRESENTADAS, OBJETIVO_PRORRATEAEDO_1, PORC_OFERTAS_PRESENTADAS, CUMPLIMIENTO_OBJETIVO_3, 
											DEUDA, OBJETIVO_PRORRATEADO_2, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_4,
											DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_3, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_5, 
											DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_4, PORC_DEUDA_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_6, 
											RENTABILIDAD, OBJETIVO_PRORRATEADO_5, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_7, 
											RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_6, PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_8, 
											DEUDA_PRIVADO_PROM, OBJETIVO_PRORRATEADO_7, PORC_DEUDA_PRIVADO_PROM, CUMPLIMIENTO_OBJETIVO_9, 
											DEUDA_AAPP_PROM, OBJETIVO_PRORRATEADO_8, PORC_DEUDA_AAPP_PROM, CUMPLIMIENTO_OBJETIVO_10, 
											DEUDA_PRIVADO_FIN_ANIO, OBJETIVO_PRORRATEADO_9, PORC_DEUDA_PRIVADO_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_11, 
											DEUDA_AAPP_FIN_ANIO, OBJETIVO_PRORRATEADO_10, PORC_DEUDA_AAPP_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_12, 
											ELECTRICIDAD, OBJETIVO_PRORRATEADO_11, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_13, 
											RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_12, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_14,
											GAS, OBJETIVO_PRORRATEADO_13, PORC_GAS, CUMPLIMIENTO_OBJETIVO_15, 
											RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_14, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_16,
											ASESORAMIENTO, OBJETIVO_PRORRATEADO_15, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_17, 
											ACTIVDAD_PRE_POST, OBJETIVO_PRORRATEADO_16, PORC_ACTIVDAD_PRE_POST, CUMPLIMIENTO_OBJETIVO_18, 
											CAPAC_FFVV, OBJETIVO_PRORRATEADO_17, POR_CAPAC_FFVV, CUMPLIMIENTO_OBJETIVO_19, 
											PORC_CONSECUCION_GLOBAL,
											-- nuevos campos 
											CART_ELE_SUBD, OBJETIVO_PRORRATEADO_18, PORC_CART_ELE_SUBD, CUMPLIMIENTO_OBJETIVO_20, 
											CART_GAS_SUBD, OBJETIVO_PRORRATEADO_19, PORC_CART_GAS_SUBD, CUMPLIMIENTO_OBJETIVO_21,
											CART_ELE_DIR, OBJETIVO_PRORRATEADO_20, PORC_CART_ELE_DIR, CUMPLIMIENTO_OBJETIVO_22,
											CART_GAS_DIR, OBJETIVO_PRORRATEADO_21, PORC_CART_GAS_DIR, CUMPLIMIENTO_OBJETIVO_23,
											CART_ELE_AGR, OBJETIVO_PRORRATEADO_22, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_24,
											RENT_ELE_AGR, OBJETIVO_PRORRATEADO_23, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_25,
											CART_GAS_AGR, OBJETIVO_PRORRATEADO_24, PORC_CART_GAS_AGR, CUMPLIMIENTO_OBJETIVO_26,
											FECHA_PUBLICACION)
	select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY') as anio,
		cspa.userid as ID_USUARIO,
		cspo.name as ID_FICHA,
--CLIENTES_CAPTADOS_VISITAS
		null as CLIENTES_CAPTADOS_VISITAS,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name = 'I - OFV - Consecuci%n Global - Clientes Captados + Visitas - Empresas GC (V)' 
				or inc.name = 'I - OFV - Consecuci%n Global - Clientes Captados + Visitas - Empresas RZ (V)' 
			then inc.genericnumber3
		end as PORC_CLIENTES_CAPTADOS_VISITAS,
		null as CUMPLIMIENTO_OBJETIVO,
--CLIENTES_CAPTADOS
		case 
			when (emt.name like 'MS - OFV - Clientes Captados - Empresas GC - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RZ - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%'
				or emt.name like 'MS - OFV - Número Clientes Captados - KAM Territorial - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%')
				and emt.genericboolean1 = 1
			then emt.genericnumber1
		end as CLIENTES_CAPTADOS,
		case 
			when (emt.name like 'MS - OFV - Clientes Captados - Empresas GC - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RZ - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%'
				or emt.name like 'MS - OFV - Número Clientes Captados - KAM Territorial - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%')
				and emt.genericboolean1 = 1
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEAEDO,
		case
			when (emt.name like 'MS - OFV - Clientes Captados - Empresas GC - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RZ - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%'
				or emt.name like 'MS - OFV - Número Clientes Captados - KAM Territorial - Consecuci%'
				or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%')
				and emt.genericboolean1 = 1
				then emt.value 
		end as PORC_CLIENTES_CAPTADOS,
		null as CUMPLIMIENTO_OBJETIVO,
--SVAS
		null as SVAS,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name = 'I - OFV - Consecuci%n Global - SVAs - Empresas GC (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - SVAs - Empresas RZ (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - SVAs - KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - SVAs - KAM Territorial (V)'
			then inc.genericnumber3
		end as PORC_SVAS,
		null as CUMPLIMIENTO_OBJETIVO,
--OFERTAS_PRESENTADAS
		case 
			when emt.name = 'MS - OFV - Número Ofertas Presentadas - Empresas GC - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - Empresas RZ - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - KAM Corporativo - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - KAM Territorial - Consecuci%n (topada)'
			then emt.genericnumber1
		end as OFERTAS_PRESENTADAS,
		case 
			when emt.name = 'MS - OFV - Número Ofertas Presentadas - Empresas GC - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - Empresas RZ - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - KAM Corporativo - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - KAM Territorial - Consecuci%n (topada)'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEAEDO,
		case 
			when emt.name = 'MS - OFV - Número Ofertas Presentadas - Empresas GC - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - Empresas RZ - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - KAM Corporativo - Consecuci%n (topada)'
				or emt.name = 'MS - OFV - Número Ofertas Presentadas - KAM Territorial - Consecuci%n (topada)'
			then emt.value
		end as PORC_OFERTAS_PRESENTADAS,
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA
		null as DEUDA,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name = 'I - OFV - Consecuci%n Global - Deuda - Empresas GC (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Deuda - Empresas RZ (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Deuda - Empresas RT GC (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Deuda - KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Deuda - KAM Territorial (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Deuda - RT KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Deuda - RT KAM Territorial (V)'
			then inc.genericnumber3
		end as PORC_DEUDA, 
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA_PROMEDIO
		case 
			when emt.name = 'MS - OFV - Deuda Promedio - Empresas GC - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Promedio - Empresas RZ - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Promedio - Empresas RT GC - Consecuci%n'
			then emt.genericnumber1
		end as DEUDA_PROMEDIO,
		case 
			when emt.name = 'MS - OFV - Deuda Promedio - Empresas GC - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Promedio - Empresas RZ - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Promedio - Empresas RT GC - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Deuda Promedio - Empresas GC - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Promedio - Empresas RZ - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Promedio - Empresas RT GC - Consecuci%n'
			then emt.value
		end as PORC_DEUDA_PROMEDIO,
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA_FIN_ANIO
		case 
			when emt.name = 'MS - OFV - Deuda Fin de Año - Empresas GC - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Fin de Año - Empresas RZ - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Fin de Año - Empresas RT GC - Consecuci%n'
			then emt.genericnumber1
		end as DEUDA_FIN_ANIO,
		case 
			when emt.name = 'MS - OFV - Deuda Fin de Año - Empresas GC - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Fin de Año - Empresas RZ - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Fin de Año - Empresas RT GC - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Deuda Fin de Año - Empresas GC - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Fin de Año - Empresas RZ - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Fin de Año - Empresas RT GC - Consecuci%n'
			then emt.value
		end as PORC_DEUDA_FIN_ANIO,
		null as CUMPLIMIENTO_OBJETIVO,
--RENTABILIDAD
		null as RENTABILIDAD,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name = 'I - OFV - Consecuci%n Global - Rentabilidad - KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Rentabilidad - RT KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Rentabilidad - RT KAM Territorial (V)'
			then inc.genericnumber3
		end as PORC_RENTABILIDAD,
		null as CUMPLIMIENTO_OBJETIVO,
--RENTABILIDAD_GAS
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Territorial - MDCM - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n'
			then emt.genericnumber1 
		end as RENTABILIDAD_GAS,
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Territorial - MDCM - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Territorial - MDCM - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n'
			then emt.value
		end as PORC_RENTABILIDAD_GAS,
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA_PRIVADO_PROM
		case 
			when emt.name = 'MS - OFV - Deuda Privados Promedio - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber1
		end as DEUDA_PRIVADO_PROM,
		case 
			when emt.name = 'MS - OFV - Deuda Privados Promedio - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Deuda Privados Promedio - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Promedio - RT KAM Territorial - Consecuci%n'
			then emt.value
		end as PORC_DEUDA_PRIVADO_PROM,
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA_AAPP_PROM
		case 
			when emt.name = 'MS - OFV - Deuda AAPP Promedio - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber1
		end as DEUDA_AAPP_PROM,
		case 
			when emt.name = 'MS - OFV - Deuda AAPP Promedio - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Deuda AAPP Promedio - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Promedio - RT KAM Territorial - Consecuci%n'
			then emt.value
		end as PORC_DEUDA_AAPP_PROM,
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA_PRIVADO_FIN_ANIO
		case 
			when emt.name = 'MS - OFV - Deuda Privados Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber1
		end as DEUDA_PRIVADO_FIN_ANIO,
		case 
			when emt.name = 'MS - OFV - Deuda Privados Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Deuda Privados Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda Privados Fin de Año - RT KAM Territorial - Consecuci%n'
			then emt.value
		end as PORC_DEUDA_PRIVADO_FIN_ANIO,
		null as CUMPLIMIENTO_OBJETIVO,
--DEUDA_AAPP_FIN_ANIO
		case 
			when emt.name = 'MS - OFV - Deuda AAPP Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber1
		end as DEUDA_AAPP_FIN_ANIO,
		case 
			when emt.name = 'MS - OFV - Deuda AAPP Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - RT KAM Territorial - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Deuda AAPP Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name = 'MS - OFV - Deuda AAPP Fin de Año - RT KAM Territorial - Consecuci%n'
			then emt.value
		end as PORC_DEUDA_AAPP_FIN_ANIO,
		null as CUMPLIMIENTO_OBJETIVO,
--ELECTRICIDAD
		null as ELECTRICIDAD,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name = 'I - OFV - Consecuci%n Global - Electricidad - KAM Territorial (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Eléctrico - KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Electricidad - KAMME (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Electricidad - RT KAMME (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Eléctrico - Empresas RT GC (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Eléctrico - RT KAM Territorial (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Eléctrico - RT KAM Corporativo (V)'
			then inc.genericnumber3
		end as PORC_ELECTRICIDAD,
		null as CUMPLIMIENTO_OBJETIVO,
--RENTABILIDAD_GAS_EB
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Territorial GEB - Consecuci%n'
			then emt.genericnumber1
		end as RENTABILIDAD_GAS_EB,
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Territorial GEB - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - RT KAM Territorial GEB - Consecuci%n'
			then emt.value
		end as PORC_RENTABILIDAD_GAS_EB,
		null as CUMPLIMIENTO_OBJETIVO,
--GAS
		null as GAS,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name = 'I - OFV - Consecuci%n Global - Gas - KAMME (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Gas - RT KAMME (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Gas - KAM Territorial (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Gas - KAM Corporativo (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Gas - RT KAM Territorial (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Volumen Gas - RT KAM Corporativo (V)'
			then inc.genericnumber3
		end as PORC_GAS,
		null as CUMPLIMIENTO_OBJETIVO,
--RENTABILIDAD_GAS_AGR
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber1
		end as RENTABILIDAD_GAS_AGR,
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name = 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.value
		end as PORC_RENTABILIDAD_GAS_AGR,
		null as CUMPLIMIENTO_OBJETIVO,
--ASESORAMIENTO
		null as ASESORAMIENTO,
		null as OBJETIVO_PRORRATEADO,
		case 	
			when inc.name = 'I - OFV - Consecuci%n Global - Asesoramiento - KAMME (V)'
				or inc.name = 'I - OFV - Consecuci%n Global - Asesoramiento - RT KAMME (V)'
			then inc.genericnumber3
		end as PORC_ASESORAMIENTO,
		null as CUMPLIMIENTO_OBJETIVO,
--ACTIVDAD_PRE_POST
		case 
			when emt.name = 'MS - OFV - Actividad Pre Post - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Actividad Pre Post - RT KAMME - Consecuci%n'
			then emt.genericnumber1
		end as ACTIVDAD_PRE_POST,
		case 
			when emt.name = 'MS - OFV - Actividad Pre Post - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Actividad Pre Post - RT KAMME - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Actividad Pre Post - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Actividad Pre Post - RT KAMME - Consecuci%n'
			then emt.value
		end as PORC_ACTIVDAD_PRE_POST,
		null as CUMPLIMIENTO_OBJETIVO,
--CAPAC_FFVV
		case 
			when emt.name = 'MS - OFV - Capacitación FFVV - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Capacitación FFVV - RT KAMME - Consecuci%n'
			then emt.genericnumber1
		end as CAPAC_FFVV,
		case 
			when emt.name = 'MS - OFV - Capacitación FFVV - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Capacitación FFVV - RT KAMME - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Capacitación FFVV - KAMME - Consecuci%n'
				or emt.name = 'MS - OFV - Capacitación FFVV - RT KAMME - Consecuci%n'
			then emt.value
		end as POR_CAPAC_FFVV,
		null as CUMPLIMIENTO_OBJETIVO,
--PORC_CONSECUCION_GLOBAL
		case 
			when inc.name = 'I - OFV - Consecuci%n Global Total - Empresas GC'
				or inc.name = 'I - OFV - Consecuci%n Global Total - Empresas RZ'
				or inc.name = 'I - OFV - Consecuci%n Global Total - Empresas RT GC'
				or inc.name = 'I - OFV - Consecuci%n Global Total - KAM Corporativo'
				or inc.name = 'I - OFV - Consecuci%n Global Total - KAM Territorial'
				or inc.name = 'I - OFV - Consecuci%n Global Total - RT KAM Corporativo'
				or inc.name = 'I - OFV - Consecuci%n Global Total - RT KAM Territorial'
				or inc.name = 'I - OFV - Consecuci%n Global Total - KAMME'
				or inc.name = 'I - OFV - Consecuci%n Global Total - RT KAMME'
			then inc.value
		end as PORC_CONSECUCION_GLOBAL,
--CART_ELE_SUBD
		case 
			when emt.name = 'MS - OFV - Volumen El%ctrico - Empresas RT GC - Consecuci%n (ref Subdirector)' 
				or emt.name = 'MS - OFV - Volumen El%ctrico - KAM Corporativo - Consecuci%n (ref Subdirector)'
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAM Territorial - Consecuci%n (ref Subdirector)'
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAM Corporativo - Consecuci%n (ref Subdirector)'	
			then emt.genericnumber1
		end as CART_ELE_SUBD,
		case 
			when emt.name = 'MS - OFV - Volumen El%ctrico - Empresas RT GC - Consecuci%n (ref Subdirector)' 
				or emt.name = 'MS - OFV - Volumen El%ctrico - KAM Corporativo - Consecuci%n (ref Subdirector)'
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAM Territorial - Consecuci%n (ref Subdirector)'
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAM Corporativo - Consecuci%n (ref Subdirector)'	
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Volumen El%ctrico - Empresas RT GC - Consecuci%n (ref Subdirector)' 
				or emt.name = 'MS - OFV - Volumen El%ctrico - KAM Corporativo - Consecuci%n (ref Subdirector)'
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAM Territorial - Consecuci%n (ref Subdirector)'
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAM Corporativo - Consecuci%n (ref Subdirector)'	
			then emt.value
		end as PORC_CART_ELE_SUBD,
		null as CUMPLIMIENTO_OBJETIVO,
--CART_GAS_SUBD
		null as CART_GAS_SUBD,
		null as OBJETIVO_PRORRATEADO,
		null as PORC_CART_GAS_SUBD,
		null as CUMPLIMIENTO_OBJETIVO,
--CART_ELE_DIR
		null as CART_ELE_DIR,
		null as OBJETIVO_PRORRATEADO,
		null as PORC_CART_ELE_DIR,
		null as CUMPLIMIENTO_OBJETIVO,
--CART_GAS_DIR
		case 
			when emt.name = 'MS - OFV - Volumen Gas - KAM Territorial - Consecuci%n (ref Director)' 
				or emt.name = 'MS - OFV - Volumen Gas - KAM Corporativo - Consecuci%n (ref Director)'
				or emt.name = 'MS - OFV - Volumen Gas - RT KAM Territorial - Consecuci%n (ref Director)'
				or emt.name = 'MS - OFV - Volumen Gas - RT KAM Corporativo - Consecuci%n (ref Director)'	
			then emt.genericnumber1
		end as CART_GAS_DIR,
		case 
			when emt.name = 'MS - OFV - Volumen Gas - KAM Territorial - Consecuci%n (ref Director)' 
				or emt.name = 'MS - OFV - Volumen Gas - KAM Corporativo - Consecuci%n (ref Director)'
				or emt.name = 'MS - OFV - Volumen Gas - RT KAM Territorial - Consecuci%n (ref Director)'
				or emt.name = 'MS - OFV - Volumen Gas - RT KAM Corporativo - Consecuci%n (ref Director)'	
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Volumen Gas - KAM Territorial - Consecuci%n (ref Director)' 
				or emt.name = 'MS - OFV - Volumen Gas - KAM Corporativo - Consecuci%n (ref Director)'
				or emt.name = 'MS - OFV - Volumen Gas - RT KAM Territorial - Consecuci%n (ref Director)'
				or emt.name = 'MS - OFV - Volumen Gas - RT KAM Corporativo - Consecuci%n (ref Director)'	
			then emt.value
		end as PORC_CART_GAS_DIR,
		null as CUMPLIMIENTO_OBJETIVO,
--CART_ELE_AGR
		case 
			when emt.name = 'MS - OFV - Volumen El%ctrico - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.genericnumber1
		end as CART_ELE_AGR,
		case 
			when emt.name = 'MS - OFV - Volumen El%ctrico - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Volumen El%ctrico - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Volumen El%ctrico - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.value
		end as PORC_CART_ELE_AGR,
		null as CUMPLIMIENTO_OBJETIVO,
--RENT_ELE_AGR
		case 
			when emt.name = 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.genericnumber1
		end as RENT_ELE_AGR,
		case 
			when emt.name = 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.value
		end as PORC_RENT_ELE_AGR,
		null as CUMPLIMIENTO_OBJETIVO,
--CART_GAS_AGR
		case 
			when emt.name = 'MS - OFV - Volumen Gas - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Volumen Gas - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.genericnumber1
		end as CART_GAS_AGR,
		case 
			when emt.name = 'MS - OFV - Volumen Gas - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Volumen Gas - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO,
		case 
			when emt.name = 'MS - OFV - Volumen Gas - KAMME - Consecuci%n Agregada (Subv)' 
				or emt.name = 'MS - OFV - Volumen Gas - RT KAMME - Consecuci%n Agregada (Subv)' 
			then emt.value
		end as PORC_CART_GAS_AGR,
		null as CUMPLIMIENTO_OBJETIVO,
--FECHA_PUBLICACION
		case 
			when inc.name = 'I - OFV - Consecuci%n Global Total - Empresas GC'
				or inc.name = 'I - OFV - Consecuci%n Global Total - Empresas RZ'
				or inc.name = 'I - OFV - Consecuci%n Global Total - Empresas RT GC'
				or inc.name = 'I - OFV - Consecuci%n Global Total - KAM Corporativo'
				or inc.name = 'I - OFV - Consecuci%n Global Total - KAM Territorial'
				or inc.name = 'I - OFV - Consecuci%n Global Total - RT KAM Corporativo'
				or inc.name = 'I - OFV - Consecuci%n Global Total - RT KAM Territorial'
				or inc.name = 'I - OFV - Consecuci%n Global Total - KAMME'
				or inc.name = 'I - OFV - Consecuci%n Global Total - RT KAMME'
			then to_char(inc.genericdate1,'YYYY-MM-DD')
		end as FECHA_PUBLICACION

	from enel_medidas_temp_ofv emt
		left join ENEL_INCEN_TEMP_OFV inc
			on emt.PAYEESEQ = inc.PAYEESEQ
			and emt.POSITIONSEQ = inc.POSITIONSEQ

		inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
			
		inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
									
		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		(inc.name like 'I - OFV - Consecuci%n Global - Asesoramiento - KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Asesoramiento - RT KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Clientes Captados + Visitas - Empresas % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Deuda - Empresas % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Deuda - KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Deuda - RT KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - KAM Territorial (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - RT KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Gas - RT KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Gas - KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - SVAs - KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - KAM Corporativo (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - RT KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - SVAs - Empresas % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Volumen Eléctrico - Empresas RT GC (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Volumen Eléctrico - KAM Corporativo (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Volumen Eléctrico - RT KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Volumen Gas - KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Volumen Gas - RT KAM % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global Total - Empresas %'
		or inc.name like 'I - OFV - Consecuci%n Global Total - KAM %'
		or inc.name like 'I - OFV - Consecuci%n Global Total - KAMME'
		or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAMME'
		or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAM %'

		or emt.name like 'MS - OFV - Actividad Pre Post - KAMME - Consecuci%n'
		or emt.name like 'MS - OFV - Actividad Pre Post - RT KAMME - Consecuci%n'
		or emt.name like 'MS - OFV - Capacitación FFVV - RT KAMME - Consecuci%n'
		or emt.name like 'MS - OFV - Capacitación FFVV - KAMME - Consecuci%n'
		or emt.name like 'MS - OFV - Clientes Captados - Empresas % - Consecuci%'
		or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%'
		or emt.name like 'MS - OFV - Deuda AAPP Fin de Año - KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda AAPP Fin de Año - RT KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda AAPP Promedio - RT KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda Privados Fin de Año - RT KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda Privados Promedio - RT KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Deuda Promedio - Empresas % - Consecuci%n'
		or emt.name like 'MS - OFV - Número Clientes Captados - KAM Territorial - Consecuci%'
		or emt.name like 'MS - OFV - Número Ofertas Presentadas - Empresas % - Consecuci%n (topada)'
		or emt.name like 'MS - OFV - Número Ofertas Presentadas - KAM % - Consecuci%n (topada)'
		or emt.name like 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
		or emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecució%'
		or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecució%'
		or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM % - Consecuci%n'
		or emt.name like 'MS - OFV - Volumen El%ctrico - Empresas RT GC - Consecuci%n (ref Subdirector)'
		or emt.name like 'MS - OFV - Volumen El%ctrico - KAM Corporativo - Consecuci%n (ref Subdirector)'
		or emt.name like 'MS - OFV - Volumen El%ctrico - KAMME - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Volumen El%ctrico - RT KAMME - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Volumen El%ctrico - RT KAM Corporativo - Consecuci%n (ref Subdirector)'
		or emt.name like 'MS - OFV - Volumen El%ctrico - RT KAM Territorial - Consecuci%n (ref Subdirector)'
		or emt.name like 'MS - OFV - Volumen Gas - KAM % - Consecuci%n (ref Director)'
		or emt.name like 'MS - OFV - Volumen Gas - KAMME - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Volumen Gas - RT KAMME - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Volumen Gas - RT KAM % - Consecuci%n (ref Director)'
		)

	order by cspo.name;
	
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CONSECUCION_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Inicio Carga de la tabla ENEL_CONSECUCION_TEMP2_OFV. ', v_contador_debug);
	
	INSERT INTO ENEL_CONSECUCION_TEMP2_OFV  (TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
											CLIENTES_CAPTADOS_VISITAS, OBJETIVO_PRORRATEADO, PORC_CLIENTES_CAPTADOS_VISITAS, CUMPLIMIENTO_OBJETIVO, 
											CLIENTES_CAPTADOS, OBJETIVO_PRORRATEAEDO, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_1, 
											SVAS, OBJETIVO_PRORRATEADO_1, PORC_SVAS, CUMPLIMIENTO_OBJETIVO_2, 
											OFERTAS_PRESENTADAS, OBJETIVO_PRORRATEAEDO_1, PORC_OFERTAS_PRESENTADAS, CUMPLIMIENTO_OBJETIVO_3, 
											DEUDA, OBJETIVO_PRORRATEADO_2, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_4,
											DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_3, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_5, 
											DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_4, PORC_DEUDA_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_6, 
											RENTABILIDAD, OBJETIVO_PRORRATEADO_5, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_7, 
											RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_6, PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_8, 
											DEUDA_PRIVADO_PROM, OBJETIVO_PRORRATEADO_7, PORC_DEUDA_PRIVADO_PROM, CUMPLIMIENTO_OBJETIVO_9, 
											DEUDA_AAPP_PROM, OBJETIVO_PRORRATEADO_8, PORC_DEUDA_AAPP_PROM, CUMPLIMIENTO_OBJETIVO_10, 
											DEUDA_PRIVADO_FIN_ANIO, OBJETIVO_PRORRATEADO_9, PORC_DEUDA_PRIVADO_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_11, 
											DEUDA_AAPP_FIN_ANIO, OBJETIVO_PRORRATEADO_10, PORC_DEUDA_AAPP_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_12, 
											ELECTRICIDAD, OBJETIVO_PRORRATEADO_11, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_13, 
											RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_12, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_14,
											GAS, OBJETIVO_PRORRATEADO_13, PORC_GAS, CUMPLIMIENTO_OBJETIVO_15, 
											RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_14, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_16,
											ASESORAMIENTO, OBJETIVO_PRORRATEADO_15, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_17, 
											ACTIVDAD_PRE_POST, OBJETIVO_PRORRATEADO_16, PORC_ACTIVDAD_PRE_POST, CUMPLIMIENTO_OBJETIVO_18, 
											CAPAC_FFVV, OBJETIVO_PRORRATEADO_17, POR_CAPAC_FFVV, CUMPLIMIENTO_OBJETIVO_19, 
											PORC_CONSECUCION_GLOBAL,
											-- nuevos campos 
											CART_ELE_SUBD, OBJETIVO_PRORRATEADO_18, PORC_CART_ELE_SUBD, CUMPLIMIENTO_OBJETIVO_20, 
											CART_GAS_SUBD, OBJETIVO_PRORRATEADO_19, PORC_CART_GAS_SUBD, CUMPLIMIENTO_OBJETIVO_21,
											CART_ELE_DIR, OBJETIVO_PRORRATEADO_20, PORC_CART_ELE_DIR, CUMPLIMIENTO_OBJETIVO_22,
											CART_GAS_DIR, OBJETIVO_PRORRATEADO_21, PORC_CART_GAS_DIR, CUMPLIMIENTO_OBJETIVO_23,
											CART_ELE_AGR, OBJETIVO_PRORRATEADO_22, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_24,
											RENT_ELE_AGR, OBJETIVO_PRORRATEADO_23, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_25,
											CART_GAS_AGR, OBJETIVO_PRORRATEADO_24, PORC_CART_GAS_AGR, CUMPLIMIENTO_OBJETIVO_26,
											FECHA_PUBLICACION)
	select
		distinct
		TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
--CLIENTES_CAPTADOS_VISITAS
		(select max(CLIENTES_CAPTADOS_VISITAS) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND  ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CLIENTES_CAPTADOS_VISITAS, 
		(select max(OBJETIVO_PRORRATEADO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND  ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO,
		(select max(PORC_CLIENTES_CAPTADOS_VISITAS) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CLIENTES_CAPTADOS_VISITAS,
		(select max(CUMPLIMIENTO_OBJETIVO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO, 
--CLIENTES_CAPTADOS
		(select max(CLIENTES_CAPTADOS) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CLIENTES_CAPTADOS, 
		(select max(OBJETIVO_PRORRATEAEDO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEAEDO, 
		(select max(PORC_CLIENTES_CAPTADOS) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CLIENTES_CAPTADOS, 
		(select max(CUMPLIMIENTO_OBJETIVO_1) from ENEL_CONSECUCION_TEMP_OFV ofv2 where  ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_1, 
--SVAS
		(select max(SVAS) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as SVAS, 
		(select max(OBJETIVO_PRORRATEADO_1) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_1, 
		(select max(PORC_SVAS) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_SVAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_2) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_2,
--OFERTAS_PRESENTADAS
		(select max(OFERTAS_PRESENTADAS) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OFERTAS_PRESENTADAS, 
		(select max(OBJETIVO_PRORRATEAEDO_1) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEAEDO_1, 
		(select max(PORC_OFERTAS_PRESENTADAS) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_OFERTAS_PRESENTADAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_3) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_3, 
--DEUDA
		(select max(DEUDA) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA, 
		(select max(OBJETIVO_PRORRATEADO_2) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_2, 
		(select max(PORC_DEUDA) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA, 
		(select max(CUMPLIMIENTO_OBJETIVO_4) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_4, 
--DEUDA_PROMEDIO
		(select max(DEUDA_PROMEDIO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_PROMEDIO, 
		(select max(OBJETIVO_PRORRATEADO_3) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_3, 
		(select max(PORC_DEUDA_PROMEDIO) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_PROMEDIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_5) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_5, 
--DEUDA_FIN_ANIO
		(select max(DEUDA_FIN_ANIO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_FIN_ANIO, 
		(select max(OBJETIVO_PRORRATEADO_4) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_4, 
		(select max(PORC_DEUDA_FIN_ANIO) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_FIN_ANIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_6) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_6,
--RENTABILIDAD
		(select max(RENTABILIDAD) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD, 
		(select max(OBJETIVO_PRORRATEADO_5) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_5, 
		(select max(PORC_RENTABILIDAD) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD, 
		(select max(CUMPLIMIENTO_OBJETIVO_7) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_7, 
--RENTABILIDAD_GAS
		(select max(RENTABILIDAD_GAS) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD_GAS, 
		(select max(OBJETIVO_PRORRATEADO_6) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_6, 
		(select max(PORC_RENTABILIDAD_GAS) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_8) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_8, 
--DEUDA_PRIVADO_PROM
		(select max(DEUDA_PRIVADO_PROM) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_PRIVADO_PROM, 
		(select max(OBJETIVO_PRORRATEADO_7) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_7, 
		(select max(PORC_DEUDA_PRIVADO_PROM) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_PRIVADO_PROM, 
		(select max(CUMPLIMIENTO_OBJETIVO_9) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_9, 
--DEUDA_AAPP_PROM
		(select max(DEUDA_AAPP_PROM) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_AAPP_PROM, 
		(select max(OBJETIVO_PRORRATEADO_8) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_8, 
		(select max(PORC_DEUDA_AAPP_PROM) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_AAPP_PROM, 
		(select max(CUMPLIMIENTO_OBJETIVO_10) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_10, 
--DEUDA_PRIVADO_FIN_ANIO
		(select max(DEUDA_PRIVADO_FIN_ANIO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_PRIVADO_FIN_ANIO, 
		(select max(OBJETIVO_PRORRATEADO_9) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_9, 
		(select max(PORC_DEUDA_PRIVADO_FIN_ANIO) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_PRIVADO_FIN_ANIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_11) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_11, 
--DEUDA_AAPP_FIN_ANIO
		(select max(DEUDA_AAPP_FIN_ANIO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_AAPP_FIN_ANIO, 
		(select max(OBJETIVO_PRORRATEADO_10) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_10, 
		(select max(PORC_DEUDA_AAPP_FIN_ANIO) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_AAPP_FIN_ANIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_12) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_12, 
--ELECTRICIDAD
		(select max(ELECTRICIDAD) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as ELECTRICIDAD, 
		(select max(OBJETIVO_PRORRATEADO_11) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_11, 
		(select max(PORC_ELECTRICIDAD) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_ELECTRICIDAD, 
		(select max(CUMPLIMIENTO_OBJETIVO_13) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_13, 
--RENTABILIDAD_GAS_EB
		(select max(RENTABILIDAD_GAS_EB) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD_GAS_EB, 
		(select max(OBJETIVO_PRORRATEADO_12) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_12, 
		(select max(PORC_RENTABILIDAD_GAS_EB) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD_GAS_EB, 
		(select max(CUMPLIMIENTO_OBJETIVO_14) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_14, 
--GAS
		(select max(GAS) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as GAS, 
		(select max(OBJETIVO_PRORRATEADO_13) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_13, 
		(select max(PORC_GAS) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_15) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_15, 
--RENTABILIDAD_GAS_AGR
		(select max(RENTABILIDAD_GAS_AGR) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD_GAS_AGR, 
		(select max(OBJETIVO_PRORRATEADO_14) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_14, 
		(select max(PORC_RENTABILIDAD_GAS_AGR) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD_GAS_AGR, 
		(select max(CUMPLIMIENTO_OBJETIVO_16) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_16, 
--ASESORAMIENTO
		(select max(ASESORAMIENTO) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as ASESORAMIENTO, 
		(select max(OBJETIVO_PRORRATEADO_15) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_15, 
		(select max(PORC_ASESORAMIENTO) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_ASESORAMIENTO, 
		(select max(CUMPLIMIENTO_OBJETIVO_17) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_17, 
--ACTIVDAD_PRE_POST
		(select max(ACTIVDAD_PRE_POST) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as ACTIVDAD_PRE_POST, 
		(select max(OBJETIVO_PRORRATEADO_16) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_16, 
		(select max(PORC_ACTIVDAD_PRE_POST) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_ACTIVDAD_PRE_POST, 
		(select max(CUMPLIMIENTO_OBJETIVO_18) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_18, 
--CAPAC_FFVV
		(select max(CAPAC_FFVV) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CAPAC_FFVV, 
		(select max(OBJETIVO_PRORRATEADO_17) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_17, 
		(select max(POR_CAPAC_FFVV) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as POR_CAPAC_FFVV, 
		(select max(CUMPLIMIENTO_OBJETIVO_19) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_19, 
--PORC_CONSECUCION_GLOBAL
		(select max(PORC_CONSECUCION_GLOBAL) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CONSECUCION_GLOBAL,
--CART_ELE_SUBD
		(select max(CART_ELE_SUBD) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_ELE_SUBD,
		(select max(OBJETIVO_PRORRATEADO_18) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_18,
		(select max(PORC_CART_ELE_SUBD) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_ELE_SUBD,
		(select max(CUMPLIMIENTO_OBJETIVO_20) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_20,
--CART_GAS_SUBD
		(select max(CART_GAS_SUBD) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_GAS_SUBD,
		(select max(OBJETIVO_PRORRATEADO_19) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_19,
		(select max(PORC_CART_GAS_SUBD) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_GAS_SUBD,
		(select max(CUMPLIMIENTO_OBJETIVO_21) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_21,
--CART_ELE_DIR
		(select max(CART_ELE_DIR) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_ELE_DIR,
		(select max(OBJETIVO_PRORRATEADO_20) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_20,
		(select max(PORC_CART_ELE_DIR) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_ELE_DIR,
		(select max(CUMPLIMIENTO_OBJETIVO_22) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_22,
--CART_GAS_DIR
		(select max(CART_GAS_DIR) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_GAS_DIR,
		(select max(OBJETIVO_PRORRATEADO_21) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_21,
		(select max(PORC_CART_GAS_DIR) *100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_GAS_DIR,
		(select max(CUMPLIMIENTO_OBJETIVO_23) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_23,
--CART_ELE_AGR
		(select max(CART_ELE_AGR) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_ELE_AGR,
		(select max(OBJETIVO_PRORRATEADO_22) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_22,
		(select max(PORC_CART_ELE_AGR) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_ELE_AGR,
		(select max(CUMPLIMIENTO_OBJETIVO_24) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_24,
--RENT_ELE_AGR
		(select max(RENT_ELE_AGR) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENT_ELE_AGR,
		(select max(OBJETIVO_PRORRATEADO_23) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_23,
		(select max(PORC_RENT_ELE_AGR) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENT_ELE_AGR,
		(select max(CUMPLIMIENTO_OBJETIVO_25) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_25,
--CART_GAS_AGR
		(select max(CART_GAS_AGR) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_GAS_AGR,
		(select max(OBJETIVO_PRORRATEADO_24) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_24,
		(select max(PORC_CART_GAS_AGR) * 100 from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_GAS_AGR,
		(select max(CUMPLIMIENTO_OBJETIVO_26) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_26,
--FECHA_PUBLICACION
		(select max(FECHA_PUBLICACION) from ENEL_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as FECHA_PUBLICACION

	from ENEL_CONSECUCION_TEMP_OFV ofv1
	
	where periodSeq = iperiodseq
	;
	
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CONSECUCION_TEMP2_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CONSECUCION_TEMP2_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CONSECUCION_TEMP2_OFV',v_contador_debug);

end;*/

procedure p_Medidas_Consecucion_Temp ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
As
begin
	w_debug('Inicio Borrado de la tabla ENEL_NEW_CONSECUCION_TEMP_OFV.', v_contador_debug);
    BEGIN
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_NEW_CONSECUCION_TEMP_OFV';
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_NEW_CONSECUCION_TEMP2_OFV';
	/*
        LOOP
            DELETE FROM ENELEXT.ENEL_NEW_CONSECUCION_TEMP_OFV WHERE ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
		
		LOOP
            DELETE FROM ENELEXT.ENEL_NEW_CONSECUCION_TEMP2_OFV WHERE ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
	*/
    END;
    w_debug('Fin Borrado de la tabla ENEL_NEW_CONSECUCION_TEMP_OFV.', v_contador_debug);
	
	w_debug('Inicio Carga de la tabla ENEL_NEW_CONSECUCION_TEMP_OFV.', v_contador_debug);
	
	INSERT INTO ENEL_NEW_CONSECUCION_TEMP_OFV  (TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
                                                ELECTRICIDAD, OBJETIVO_PRORRATEADO_ELEC, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_ELEC,
                                                CLIENTES_CAPTADOS_SUBV, OBJETIVO_PRORRATEADO_SUBV, PORC_CLIENTES_CAPTADOS_SUBV, CUMPLIMIENTO_OBJETIVO_SUBV,
                                                SVAS, OBJETIVO_PRORRATEADO_SVA, PORC_SVAS, CUMPLIMIENTO_OBJETIVO_SVA,
                                                NUMERO_VENTAS, OBJETIVO_PRORRATEADO_NV, PORC_NV, CUMPLIMIENTO_OBJETIVO_NV, 
                                                DEUDA, OBJETIVO_PRORRATEADO_DEUDA, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_DEUDA, 
                                                DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_DP, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_DP,
                                                DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_DFA, PORC_DEUDA_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_DFA,
                                                DEUDA_AAPP_30, OBJETIVO_PRORRATEADO_DE, PORC_DEUDA_AAPP_30, CUMPLIMIENTO_OBJETIVO_DE, --RMM 01.06.2022 Nuevo
                                                --CLIENTES_CAPTADOS, OBJETIVO_PRORRATEADO_CC, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_CC, --RMM 01.01.2022 borramos
												VOL_ELE_NEGOCIADO, OBJETIVO_PRORRATEADO_VEN, PORC_VOL_ELE_NEGOCIADO, CUMPLIMIENTO_OBJETIVO_VEN, 
                                                GAS, OBJETIVO_PRORRATEADO_GAS, PORC_GAS, CUMPLIMIENTO_OBJETIVO_GAS,
                                                CART_GAS, OBJETIVO_PRORRATEADO_CG, PORC_CART_GAS, CUMPLIMIENTO_OBJETIVO_CG,
												RENTABILIDAD, OBJETIVO_PRORRATEADO_RENT, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_RENT, 
                                                RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_RGEB, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_RGEB, 
                                                RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_RG, 	PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_RG,
                                                CART_SD_ELEC, OBJETIVO_PRORRATEADO_CSE, PORC_CART_SD_ELEC, CUMPLIMIENTO_OBJETIVO_CSE, 
												CART_PROM_GAS, OBJETIVO_PRORRATEADO_CPG, PORC_CART_PROM_GAS, CUMPLIMIENTO_OBJETIVO_CPG,
                                                CART_SD_GAS, OBJETIVO_PRORRATEADO_CSG, PORC_CART_SD_GAS, CUMPLIMIENTO_OBJETIVO_CSG,
                                                CART_ELE_AGR, OBJETIVO_PRORRATEADO_CEA, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_CEA, 
                                                RENT_ELE_AGR, OBJETIVO_PRORRATEADO_REA, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_REA, 
                                                RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_RGA, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_RGA, 
                                                ASESORAMIENTO, OBJETIVO_PRORRATEADO_ASE, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_ASE,
                                                CRECIMIENTO_30GW, OBJETIVO_PRORRATEADO_CRE, PORC_CRECIMIENTO_30GW, CUMPLIMIENTO_OBJETIVO_CRE, --RMM 01.06.2022 Nuevo
                                                PORC_CONSECUCION_GLOBAL, FECHA_PUBLICACION)
												
	select 
		distinct(emt.tenantid),
		emt.periodseq,
		emt.periodo,
		TO_CHAR(CSPE.STARTDATE,'YYYY') as anio,
		cspa.userid as ID_USUARIO,
		cspo.name as ID_FICHA,
--ELECTRICIDAD
		null as ELECTRICIDAD,
		null as OBJETIVO_PRORRATEADO,
		case 
			when inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - Empresas GC (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - Empresas RZ (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - KAM Territorial (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - RT KAM Territorial (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - RT KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - KAMME (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - RT KAMME (V)'
                or inc.name like 'I - OFV - Consecuci%n Global - %Electricid%AAPP%(V)' -- RMM 02.06.2022
                or inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - Empresas RT GC (V)' --APM 29.06.2022 
			then inc.genericnumber3
		end as PORC_ELECTRICIDAD,
		null as CUMPLIMIENTO_OBJETIVO,
--CLIENTES_CAPTADOS_SUBV
		case 
			when (emt.name like 'MS - OFV - Clientes Captados - Empresas GC - Consecuci%' 
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RZ - Consecuci%' 
				or emt.name like 'MS - OFV - N%mero Clientes Captados - KAM Territorial - Consecuci%'
                --APM 29.06.2022 BOM
                --or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%n topada'
                or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%n' --APM 29.06.2022 EOM
                or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%n topada'
                or emt.name like 'MS - OFV - Clientes Captados  - %AAPP% - Consecuci%n topada' )-- RMM 02.06.2022
				and emt.genericboolean1 = 1
			then emt.genericnumber1
        end as CLIENTES_CAPTADOS_SUBV,
		case 
			when (emt.name like 'MS - OFV - Clientes Captados - Empresas GC - Consecuci%' 
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RZ - Consecuci%' 
				or emt.name like 'MS - OFV - N%mero Clientes Captados - KAM Territorial - Consecuci%'
                --APM 29.06.2022 BOM
                --or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%n topada'
                or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%n' --APM 29.06.2022 EOM
                or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%n topada'
                or emt.name like 'MS - OFV - Clientes Captados  - %AAPP% - Consecuci%n topada' )-- RMM 02.06.2022
				and emt.genericboolean1 = 1
			then emt.genericnumber4 
        end as OBJETIVO_PRORRATEADO_SUBV,
		case 
			when (emt.name like 'MS - OFV - Clientes Captados - Empresas GC - Consecuci%' 
				or emt.name like 'MS - OFV - Clientes Captados - Empresas RZ - Consecuci%' 
				or emt.name like 'MS - OFV - N%mero Clientes Captados - KAM Territorial - Consecuci%'
                --APM 29.06.2022 BOM
                --or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%n topada'
                or emt.name like 'MS - OFV - Clientes Captados - Empresas RT GC - Consecuci%n' --APM 29.06.2022 EOM
                or emt.name like 'MS - OFV - Clientes Captados - RT KAM Territorial - Consecuci%n topada'
                or emt.name like 'MS - OFV - Clientes Captados  - %AAPP% - Consecuci%n topada' )-- RMM 02.06.2022
				and emt.genericboolean1 = 1
			then emt.value
		end as PORC_CLIENTES_CAPTADOS_SUBV,
		null as CUMPLIMIENTO_OBJETIVO_SUBV,
--SVAS
		null as SVAS,
		null as OBJETIVO_PRORRATEADO_SVA,
		case 
			when inc.name like 'I - OFV - Consecuci%n Global - SVAs - Empresas GC (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - SVAs - Empresas RZ (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - SVAs - KAM Territorial (V)'
                or inc.name like 'I - OFV - Consecuci%n Global - %SVA%AAPP%(V)' -- RMM 02.06.2022
			then inc.genericnumber3
		end as PORC_SVAS,
		null as CUMPLIMIENTO_OBJETIVO_SVA,
--NUMERO_VENTAS
		case 
			when emt.name like 'MS - OFV - N%mero Ventas - Empresas GC - Consecuci%n (topada)' 
				or emt.name like 'MS - OFV - N%mero Ventas - Empresas RZ - Consecuci%n (topada)' 
				or emt.name like 'MS - OFV - N%mero Ventas - KAM Territorial - Consecuci%n (topada)'
                or emt.name like 'MS - OFV - N%mero Ventas - %AAPP% - Consecuci%n (topada)' -- RMM 02.06.2022
                or emt.name like 'MS - OFV - Número Leads - %AAPP% - Consecuci%n (topada)' -- APM 29.06.2022
			then emt.genericnumber1 
        end as NUMERO_VENTAS,
		case 
			when emt.name like 'MS - OFV - N%mero Ventas - Empresas GC - Consecuci%n (topada)' 
				or emt.name like 'MS - OFV - N%mero Ventas - Empresas RZ - Consecuci%n (topada)' 
				or emt.name like 'MS - OFV - N%mero Ventas - KAM Territorial - Consecuci%n (topada)'
                or emt.name like 'MS - OFV - N%mero Ventas - %AAPP% - Consecuci%n (topada)' -- RMM 02.06.2022
                or emt.name like 'MS - OFV - Número Leads - %AAPP% - Consecuci%n (topada)' -- APM 29.06.2022
			then emt.genericnumber4 
        end as OBJETIVO_PRORRATEADO_NV,
		case 
			when emt.name like 'MS - OFV - N%mero Ventas - Empresas GC - Consecuci%n (topada)' 
				or emt.name like 'MS - OFV - N%mero Ventas - Empresas RZ - Consecuci%n (topada)' 
				or emt.name like 'MS - OFV - N%mero Ventas - KAM Territorial - Consecuci%n (topada)'
                or emt.name like 'MS - OFV - N%mero Ventas - %AAPP% - Consecuci%n (topada)' -- RMM 02.06.2022
                or emt.name like 'MS - OFV - Número Leads - %AAPP% - Consecuci%n (topada)' -- APM 29.06.2022
			then emt.value
		end as PORC_NV,
		null as CUMPLIMIENTO_OBJETIVO_NV,
--DEUDA
		null as DEUDA,
		null as OBJETIVO_PRORRATEADO_DEUDA,
		case 
			when inc.name like 'I - OFV - Consecuci%n Global - Deuda - Empresas GC (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Deuda - Empresas RZ (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Deuda - Empresas RT GC (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Deuda - KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Deuda - KAM Territorial (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Deuda - RT KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Deuda - RT KAM Territorial (V)'
                or inc.name like 'I - OFV - Consecuci%n Global - Deuda - AAPP%' --RMM 02.06.2022
                or inc.name like 'I - OFV - Consecución Global - Deuda - KAM Territorial - DM (V)' -- DCR 10.08.2022
			then inc.genericnumber3
		end as PORC_DEUDA, 
		null as CUMPLIMIENTO_OBJETIVO_DEUDA,
--DEUDA_PROMEDIO
		case 
			when emt.name like 'MS - OFV - Deuda Promedio - Empresas GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - Empresas RZ - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - Empresas RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - RT KAM Territorial - Consecuci%n'
                --APM 29.06.2022 or emt.name like 'MS - OFV - Deuda Promedio - %AAPP% - Consecuci%n' --RMM 02.06.202
                --or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n' --APM 29.06.2022 DCR 10.08.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - RT KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.genericnumber1 -- DCR 10.08.2022 Cambiamos de GN2 a GN1
		end as DEUDA_PROMEDIO,
		case 
			when emt.name like 'MS - OFV - Deuda Promedio - Empresas GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - Empresas RZ - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - Empresas RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - RT KAM Territorial - Consecuci%n'
                --APM 29.06.2022 or emt.name like 'MS - OFV - Deuda Promedio - %AAPP% - Consecuci%n' --RMM 02.06.202
                --or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n' --APM 29.06.2022 DCR 10.08.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - RT KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_DP,
		case 
			when emt.name like 'MS - OFV - Deuda Promedio - Empresas GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - Empresas RZ - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - Empresas RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Promedio - RT KAM Territorial - Consecuci%n'
                --APM 29.06.2022 or emt.name like 'MS - OFV - Deuda Promedio - %AAPP% - Consecuci%n' --RMM 02.06.202
                --or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n' --APM 29.06.2022 DCR 10.08.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - RT KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Promedio - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.value
		end as PORC_DEUDA_PROMEDIO,
		null as CUMPLIMIENTO_OBJETIVO_DP,
--DEUDA_FIN_ANIO
		case 
			when emt.name like 'MS - OFV - Deuda Fin de Año - Empresas GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas RZ - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - RT KAM Territorial - Consecuci%n'
                or emt.name like 'MS - OFV - Deuda Fin de Año - AAPP% - Consecuci%n' --RMM 02.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - RT KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.genericnumber1
		end as DEUDA_FIN_ANIO,
		case 
			when emt.name like 'MS - OFV - Deuda Fin de Año - Empresas GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas RZ - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - RT KAM Territorial - Consecuci%n'
                or emt.name like 'MS - OFV - Deuda Fin de Año - AAPP% - Consecuci%n' --RMM 02.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - RT KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_DFA,
		case 
			when emt.name like 'MS - OFV - Deuda Fin de Año - Empresas GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas RZ - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - Empresas RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda Fin de Año - RT KAM Territorial - Consecuci%n'
                or emt.name like 'MS - OFV - Deuda Fin de Año - AAPP% - Consecuci%n' --RMM 02.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - RT KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Deuda Privados Fin de Año - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.value
		end as PORC_DEUDA_FIN_ANIO,
		null as CUMPLIMIENTO_OBJETIVO_DFA,
        
-- RMM - 02.06.2022 - NO APLICA     BOM   
--  DEUDA_A_30
		--APM 29.06.2022 null as   DEUDA_A_30, BOM
        case 
            when emt.name like 'MS - OFV - Deuda 30.06 - AAPP GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP KAM - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RT KAM - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RZ - Consecuci%n'
                or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
            then emt.genericnumber1
            end as DEUDA_AAPP_30,
        case 
            when emt.name like 'MS - OFV - Deuda 30.06 - AAPP GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP KAM - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RT KAM - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RZ - Consecuci%n'
                or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_DE,
        case 
            when emt.name like 'MS - OFV - Deuda 30.06 - AAPP GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP KAM - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RT GC - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RT KAM - Consecuci%n'
				or emt.name like 'MS - OFV - Deuda 30.06 - AAPP RZ - Consecuci%n'
                or emt.name like 'MS - OFV - Deuda AAPP Promedio - KAM Territorial - Consecuci%n - DM' --DCR 10.08.2022
			then emt.value
		end as PORC_DEUDA_AAPP_30,
        --APM 29.06.2022 EOM
        
        --APM 29.06.2022 BOM
		/*null as OBJETIVO_PRORRATEADO_DE,
		case
			when inc.name like 'I - OFV - Consecuci%n Global - %Deuda%30% (V)'
				or inc.name like 'I - OFV - Consecuci%n Global -%Deuda%30% (V)'
			then inc.genericnumber3 
		end as PORC_DEUDA_AAPP_30,*/
        --APM 29.06.2022 EOM
        
		null as CUMPLIMIENTO_OBJETIVO_DE,
 -- RMM 02.06.2022     EOM     
 
 /*  RMM - 02.06.2022 - NO APLICA       
--CLIENTES_CAPTADOS
		null as CLIENTES_CAPTADOS,
		null as OBJETIVO_PRORRATEADO_CC,
		case
			when inc.name like 'I - OFV - Consecuci%n Global - Clientes Captados - RT KAM Territorial (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Clientes Captados - Empresas RT GC (V)'
			then inc.genericnumber3 
		end as PORC_CLIENTES_CAPTADOS,
		null as CUMPLIMIENTO_OBJETIVO_CC,
*/ -- RMM 02.06.2022        
--VOL_ELE_NEGOCIADO
		case 
			when emt.name like 'MS - OFV - Volumen El%ctrico Negociado - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - RT KAM Territorial - Consecuci%n'
                or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - RT KAM Corporativo - Consecuci%n'
                or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - %AAPP% - Consecuci%n' --RMM 02.06.2022
			then emt.genericnumber1
		end as VOL_ELE_NEGOCIADO,
		case 
			when emt.name like 'MS - OFV - Volumen El%ctrico Negociado - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - RT KAM Territorial - Consecuci%n'
                or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - RT KAM Corporativo - Consecuci%n'
                or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - %AAPP% - Consecuci%n' --RMM 02.06.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_VEN,
		case 
			when emt.name like 'MS - OFV - Volumen El%ctrico Negociado - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - RT KAM Territorial - Consecuci%n'
                or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - RT KAM Corporativo - Consecuci%n'
                or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - %AAPP% - Consecuci%n' --RMM 02.06.2022
			then emt.value
		end as PORC_VOL_ELE_NEGOCIADO,
		null as CUMPLIMIENTO_OBJETIVO_VEN,
--GAS
		null as GAS,
		null as OBJETIVO_PRORRATEADO_GAS,
		case 
			when inc.name like 'I - OFV - Consecuci%n Global - Cartera Gas - KAM Territorial (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Gas - RT KAM Territorial (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Gas - KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Cartera Gas - RT KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Gas - KAMME (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Gas - RT KAMME (V)'
                or inc.name like 'I - OFV - Consecuci%n Global - Gas - %AAPP% (V)' --RMM 02.06.2022
			then inc.genericnumber3
		end as PORC_GAS,
		null as CUMPLIMIENTO_OBJETIVO_GAS,
--CART_GAS
		case 
			when emt.name like 'MS - OFV - Cartera Gas B2B - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera Gas B2B - RT KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Cartera Gas - RT KAMME - Consecuci%n Agregada (Subv)'
                or emt.name like 'MS - OFV - Cartera Gas - %AAPP% - Consecuci%n Agregada (Subv)' --RMM 02.06.2022
			then emt.genericnumber1
		end as CART_GAS,
		case 
			when emt.name like 'MS - OFV - Cartera Gas B2B - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera Gas B2B - RT KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Cartera Gas - RT KAMME - Consecuci%n Agregada (Subv)'
                 or emt.name like 'MS - OFV - Cartera Gas - %AAPP% - Consecuci%n Agregada (Subv)' --RMM 02.06.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_CG,
		case 
			when emt.name like 'MS - OFV - Cartera Gas B2B - KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera Gas B2B - RT KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Cartera Gas - RT KAMME - Consecuci%n Agregada (Subv)'
                 or emt.name like 'MS - OFV - Cartera Gas - %AAPP% - Consecuci%n Agregada (Subv)' --RMM 02.06.2022
			then emt.value
		end as PORC_CART_GAS,
		null as CUMPLIMIENTO_OBJETIVO_CG,
--RENTABILIDAD
		null as RENTABILIDAD,
		null as OBJETIVO_PRORRATEADO_RENT,
		case 
			when inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - RT KAM Corporativo (V)'
				or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - RT KAM Territorial (V)'
                or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - KAM Territorial (V)' --APM 29.06.2022
                or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - %AAPP% (V)' --RMM 02.06.2022
			then inc.genericnumber3
		end as PORC_RENTABILIDAD,
		null as CUMPLIMIENTO_OBJETIVO_RENT,
--RENTABILIDAD_GAS_EB
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Territorial GEB - Consecuci%n'
               or emt.name like 'MS - OFV - Rentabilidad Gas - KAM Territorial GEB - Consecuci%n' --APM 29.06.2022
			then emt.genericnumber1 
		end as RENTABILIDAD_GAS_EB,
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Territorial GEB - Consecuci%n'
              or emt.name like 'MS - OFV - Rentabilidad Gas - KAM Territorial GEB - Consecuci%n' --APM 29.06.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_RGEB,
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Territorial GEB - Consecuci%n'
              or emt.name like 'MS - OFV - Rentabilidad Gas - KAM Territorial GEB - Consecuci%n' --APM 29.06.2022
			then emt.value
		end as PORC_RENTABILIDAD_GAS_EB,
		null as CUMPLIMIENTO_OBJETIVO_RGEB,
--RENTABILIDAD_GAS
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n'
                or emt.name like 'MS - OFV - Rentabilidad Gas - %AAPP% - Consecuci%n' --RMM 02.06.2022
			then emt.genericnumber1 
		end as RENTABILIDAD_GAS,
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n'
                or emt.name like 'MS - OFV - Rentabilidad Gas - %AAPP% - Consecuci%n' --RMM 02.06.2022
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_RG,
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAM Territorial - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n'
                or emt.name like 'MS - OFV - Rentabilidad Gas - %AAPP% - Consecuci%n' --RMM 02.06.2022
			then emt.value
		end as PORC_RENTABILIDAD_GAS,
		null as CUMPLIMIENTO_OBJETIVO_RG,
--CART_SD_ELEC
		case 
			when emt.name like 'MS - OFV - Cartera SD Electricidad - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera SD Electricidad - RT KAM Corporativo - Consecuci%n'
			then emt.genericnumber1
		end as CART_SD_ELEC,
		case 
			when emt.name like 'MS - OFV - Cartera SD Electricidad - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera SD Electricidad - RT KAM Corporativo - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_CSE,
		case 
			when emt.name like 'MS - OFV - Cartera SD Electricidad - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera SD Electricidad - RT KAM Corporativo - Consecuci%n'
			then emt.value
		end as PORC_CART_SD_ELEC,
		null as CUMPLIMIENTO_OBJETIVO_CSE,
--CART_PROM_GAS
		case 
			when emt.name like 'MS - OFV - Volumen Gas Negociado - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen Gas Negociado - RT KAM Corporativo - Consecuci%n'
			then emt.genericnumber1
		end as CART_PROM_GAS,
		case 
			when emt.name like 'MS - OFV - Volumen Gas Negociado - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen Gas Negociado - RT KAM Corporativo - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_CPG,
		case 
			when emt.name like 'MS - OFV - Volumen Gas Negociado - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Volumen Gas Negociado - RT KAM Corporativo - Consecuci%n'
			then emt.value
		end as PORC_CART_PROM_GAS,
		null as CUMPLIMIENTO_OBJETIVO_CPG,
--CART_SD_GAS
		case 
			when emt.name like 'MS - OFV - Cartera SD Gas - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera SD Gas - RT KAM Corporativo - Consecuci%n'
			then emt.genericnumber1
		end as CART_SD_GAS,
		case 
			when emt.name like 'MS - OFV - Cartera SD Gas - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera SD Gas - RT KAM Corporativo - Consecuci%n'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_CSG,
		case 
			when emt.name like 'MS - OFV - Cartera SD Gas - KAM Corporativo - Consecuci%n'
				or emt.name like 'MS - OFV - Cartera SD Gas - RT KAM Corporativo - Consecuci%n'
			then emt.value
		end as PORC_CART_SD_GAS,
		null as CUMPLIMIENTO_OBJETIVO_CSG,
--CART_ELE_AGR
		case 
			when emt.name like 'MS - OFV - Cartera Electricidad - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Cartera Electricidad - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber1
		end as CART_ELE_AGR,
		case 
			when emt.name like 'MS - OFV - Cartera Electricidad - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Cartera Electricidad - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_CEA,
		case 
			when emt.name like 'MS - OFV - Cartera Electricidad - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Cartera Electricidad - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.value
		end as PORC_CART_ELE_AGR,
		null as CUMPLIMIENTO_OBJETIVO_CEA,
--RENT_ELE_AGR
		case 
			when emt.name like 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber1
		end as RENT_ELE_AGR,
		case 
			when emt.name like 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_REA,
		case 
			when emt.name like 'MS - OFV - Rentabilidad El%ctrica - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Rentabilidad El%ctrica - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.value
		end as PORC_RENT_ELE_AGR,
		null as CUMPLIMIENTO_OBJETIVO_REA,
--RENTABILIDAD_GAS_AGR
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber1
		end as RENTABILIDAD_GAS_AGR,
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_RGA,
		case 
			when emt.name like 'MS - OFV - Rentabilidad Gas - KAMME - Consecuci%n Agregada (Subv)'
				or emt.name like 'MS - OFV - Rentabilidad Gas - RT KAMME - Consecuci%n Agregada (Subv)'
			then emt.value
		end as PORC_RENTABILIDAD_GAS_AGR,
		null as CUMPLIMIENTO_OBJETIVO_RGA,
--ASESORAMIENTO
		case 
			when emt.name like 'MS - OFV - Asesoramiento - KAMME - Consecuci%n'
				or emt.name like 'MS - OFV - Asesoramiento - RT KAMME - Consecuci%n'
              -- RMM - 26.10.2022 - BOM -  Cambio en el nombre de la medida de consecución global
               -- or emt.name like 'MS - OFV - Rentabilidad Nº Contratos Asesoramiento - KAM Territorial - Consecuci%n' --APM 29.06.2022
               or emt.name like 'MS - OFV - Rentabilidad Nº Ctos Asesoramiento - KAM Territorial - Consecución Topada' 
               -- RMM - 26.10.2022 - EOM -  Cambios el nombre de la medida de consecución global
			then emt.genericnumber1
		end as ASESORAMIENTO,
		case 
			when emt.name like 'MS - OFV - Asesoramiento - KAMME - Consecuci%n'
				or emt.name like 'MS - OFV - Asesoramiento - RT KAMME - Consecuci%n'
                -- RMM - 26.10.2022 - BOM -  Cambio en el nombre de la medida de consecución global
               -- or emt.name like 'MS - OFV - Rentabilidad Nº Contratos Asesoramiento - KAM Territorial - Consecuci%n' --APM 29.06.2022
                  or emt.name like 'MS - OFV - Rentabilidad Nº Ctos Asesoramiento - KAM Territorial - Consecución Topada' 
               -- RMM - 26.10.2022 - EOM -  Cambios el nombre de la medida de consecución global
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_ASE,
		case 
			when emt.name like 'MS - OFV - Asesoramiento - KAMME - Consecuci%n'
				or emt.name like 'MS - OFV - Asesoramiento - RT KAMME - Consecuci%n'
                 -- RMM - 26.10.2022 - BOM -  Cambio en el nombre de la medida de consecución global
                --or emt.name like 'MS - OFV - Rentabilidad Nº Contratos Asesoramiento - KAM Territorial - Consecuci%n' --APM 29.06.2022
                or emt.name like 'MS - OFV - Rentabilidad Nº Ctos Asesoramiento - KAM Territorial - Consecución Topada' 
               -- RMM - 26.10.2022 - EOM -  Cambios el nombre de la medida de consecución global
                
			then emt.value
		end as PORC_ASESORAMIENTO,
		null as CUMPLIMIENTO_OBJETIVO_ASE,
        
 -- RMM - 02.06.2022 - NO APLICA     BOM   
--  CRECIMIENTO_30GW
  --APM 29.06.2022 BOM
		/*null as   CRECIMIENTO_30GW,
		null as OBJETIVO_PRORRATEADO_CRE,
		case
			when inc.name like 'I - OFV - Consecuci%n Global - %Crecimiento%30% (V)'
			then inc.genericnumber3 
		end as PORC_CRECIMIENTO_30GW,*/
        case 
            when emt.name like 'MS - OFV - Cto Volumen Clientes menor 30 - RT KAM Territorial - Consecuci%n Topada'
			    or emt.name like 'MS - OFV - Cto Volumen Clientes menor 30 - KAM Territorial - Consecuci%n Topada'
            then emt.genericnumber1
            end as CRECIMIENTO_30GW,
        case 
            when emt.name like 'MS - OFV - Cto Volumen Clientes menor 30 - RT KAM Territorial - Consecuci%n Topada'
			    or emt.name like 'MS - OFV - Cto Volumen Clientes menor 30 - KAM Territorial - Consecuci%n Topada'
			then emt.genericnumber4
		end as OBJETIVO_PRORRATEADO_CRE,
        case 
            when emt.name like 'MS - OFV - Cto Volumen Clientes menor 30 - RT KAM Territorial - Consecuci%n Topada'
			   or emt.name like 'MS - OFV - Cto Volumen Clientes menor 30 - KAM Territorial - Consecuci%n Topada'
			then emt.value
		end as PORC_CRECIMIENTO_30GW,
  --APM 29.06.2022 EOM
		null as CUMPLIMIENTO_OBJETIVO_CRE,
 -- RMM 02.06.2022     EOM           
        
        
        case 	
			when inc.name like 'I - OFV - Consecuci%n Global Total - Empresas GC'
				or inc.name like 'I - OFV - Consecuci%n Global Total - Empresas RZ'
                or inc.name like 'I - OFV - Consecuci%n Global Total - Empresas RT GC'
                or inc.name like 'I - OFV - Consecuci%n Global Total - KAM Corporativo'
                or inc.name like 'I - OFV - Consecuci%n Global Total - KAM Territorial'
                or inc.name like 'I - OFV - Consecuci%n Global Total - KAM Territorial - DM' --APM 09.08.2022
                or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAM Corporativo'
                or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAM Territorial'
                or inc.name like 'I - OFV - Consecuci%n Global Total - KAMME'
                or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAMME'
                or inc.name like 'I - OFV - Consecuci%n Global Total - %AAPP%' --RMM 02.06.2022
			then inc.value
		end as PORC_CONSECUCION_GLOBAL,
--FECHA_PUBLICACION
		case 
			when inc.name like 'I - OFV - Consecuci%n Global Total - Empresas GC'
				or inc.name like 'I - OFV - Consecuci%n Global Total - Empresas RZ'
				or inc.name like 'I - OFV - Consecuci%n Global Total - Empresas RT GC'
				or inc.name like 'I - OFV - Consecuci%n Global Total - KAM Corporativo'
				or inc.name like 'I - OFV - Consecuci%n Global Total - KAM Territorial'
                or inc.name like 'I - OFV - Consecuci%n Global Total - KAM Territorial - DM' --APM 09.08.2022
				or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAM Corporativo'
				or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAM Territorial'
				or inc.name like 'I - OFV - Consecuci%n Global Total - KAMME'
				or inc.name like 'I - OFV - Consecuci%n Global Total - RT KAMME'
                or inc.name like 'I - OFV - Consecuci%n Global Total - %AAPP%' --RMM 02.06.2022
			then to_char(inc.genericdate1,'YYYY-MM-DD')
		end as FECHA_PUBLICACION

	from enel_medidas_temp_ofv emt
		left join ENEL_INCEN_TEMP_OFV inc
			on emt.PAYEESEQ = inc.PAYEESEQ
			and emt.POSITIONSEQ = inc.POSITIONSEQ

		inner join cs_period cspe
			on emt.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
			
		inner join cs_participant cspa 
			on emt.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
									
		left join cs_position cspo
			on emt.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate

	where 
		(inc.name like 'I - OFV - Consecuci%n Global - Cartera Electricidad - % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Cartera Gas - % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Clientes Captados - % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Deuda - % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Electricidad - RT KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Gas - RT KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Gas - KAMME (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - Rentabilidad - % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global - SVAs - % (V)'
		or inc.name like 'I - OFV - Consecuci%n Global Total - %'

		or emt.name like 'MS - OFV - Asesoramiento - KAMME - Consecuci%n'
		or emt.name like 'MS - OFV - Asesoramiento - RT KAMME - Consecuci%n'
        or emt.name like 'MS - OFV - Cartera Electricidad - % - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Cartera Gas - % - Consecuci%n Agregada (Subv)'
		or emt.name like 'MS - OFV - Cartera Gas B2B - % - Consecuci%'
		or emt.name like 'MS - OFV - Volumen El%ctrico Negociado - % - Consecuci%'
		or emt.name like 'MS - OFV - Volumen Gas Negociado - % - Consecuci%'
		or emt.name like 'MS - OFV - Cartera SD Electricidad - % - Consecuci%'
		or emt.name like 'MS - OFV - Cartera SD Gas - % - Consecuci%'
		or emt.name like 'MS - OFV - Clientes Captados - % - Consecuci%'
        or emt.name like 'MS - OFV - N%mero Clientes Captados - % - Consecuci%'
		or emt.name like 'MS - OFV - Deuda Fin de Año - % - Consecuci%'
		or emt.name like 'MS - OFV - Deuda Promedio - % - Consecuci%'
		or emt.name like 'MS - OFV - N%mero Ventas - % - Consecuci%n (topada)'
		or emt.name like 'MS - OFV - Rentabilidad El%ctrica - % - Consecuci%'
		or emt.name like 'MS - OFV - Rentabilidad Gas - % - Consecuci%'
		or emt.name like 'MS - OFV -Volumen El%ctrico Negociado - % - Consecuci%'
		)

	order by cspo.name;
	
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_NEW_CONSECUCION_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Inicio Carga de la tabla ENEL_NEW_CONSECUCION_TEMP2_OFV. ', v_contador_debug);
	
	INSERT INTO ENEL_NEW_CONSECUCION_TEMP2_OFV  (TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA, 
                                                ELECTRICIDAD, OBJETIVO_PRORRATEADO_ELEC, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_ELEC, 
                                                CLIENTES_CAPTADOS_SUBV, OBJETIVO_PRORRATEADO_SUBV, PORC_CLIENTES_CAPTADOS_SUBV, CUMPLIMIENTO_OBJETIVO_SUBV,
                                                SVAS, OBJETIVO_PRORRATEADO_SVA, PORC_SVAS, CUMPLIMIENTO_OBJETIVO_SVA,
                                                NUMERO_VENTAS, OBJETIVO_PRORRATEADO_NV, PORC_NV, CUMPLIMIENTO_OBJETIVO_NV,
                                                DEUDA,	OBJETIVO_PRORRATEADO_DEUDA, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_DEUDA, 
                                                DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_DP, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_DP,
                                                DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_DFA, PORC_DEUDA_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_DFA,
                                                DEUDA_AAPP_30, OBJETIVO_PRORRATEADO_DE, PORC_DEUDA_AAPP_30, CUMPLIMIENTO_OBJETIVO_DE, --RMM 01.06.2022 Nuevo
                                                --CLIENTES_CAPTADOS, OBJETIVO_PRORRATEADO_CC, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_CC, -- RMM 01.06.2022 BORRAMOS
												VOL_ELE_NEGOCIADO, OBJETIVO_PRORRATEADO_VEN, PORC_VOL_ELE_NEGOCIADO, CUMPLIMIENTO_OBJETIVO_VEN,
                                                GAS, OBJETIVO_PRORRATEADO_GAS, 	PORC_GAS, CUMPLIMIENTO_OBJETIVO_GAS,
                                                CART_GAS, OBJETIVO_PRORRATEADO_CG, PORC_CART_GAS, CUMPLIMIENTO_OBJETIVO_CG,
												RENTABILIDAD, OBJETIVO_PRORRATEADO_RENT, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_RENT, 
                                                RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_RGEB, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_RGEB,
                                                RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_RG, PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_RG,
                                                CART_SD_ELEC, OBJETIVO_PRORRATEADO_CSE, PORC_CART_SD_ELEC, CUMPLIMIENTO_OBJETIVO_CSE, 
												CART_PROM_GAS, OBJETIVO_PRORRATEADO_CPG, PORC_CART_PROM_GAS, CUMPLIMIENTO_OBJETIVO_CPG, --RMM 01.06.2022 reutilizamos para vol gas
                                                CART_SD_GAS, OBJETIVO_PRORRATEADO_CSG, PORC_CART_SD_GAS, CUMPLIMIENTO_OBJETIVO_CSG,
                                                CART_ELE_AGR, OBJETIVO_PRORRATEADO_CEA, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_CEA, 
                                                RENT_ELE_AGR, OBJETIVO_PRORRATEADO_REA, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_REA,
                                                RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_RGA, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_RGA, 
                                                ASESORAMIENTO, OBJETIVO_PRORRATEADO_ASE,  PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_ASE,
                                                CRECIMIENTO_30GW, OBJETIVO_PRORRATEADO_CRE, PORC_CRECIMIENTO_30GW, CUMPLIMIENTO_OBJETIVO_CRE, --RMM 01.06.2022 Nuevo
                                                PORC_CONSECUCION_GLOBAL, FECHA_PUBLICACION)
												
	select
		distinct
		TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
--ELECTRICIDAD
		(select max(ELECTRICIDAD) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND  ofv1.PERIODSEQ = ofv2.PERIODSEQ) as ELECTRICIDAD, 
		(select max(OBJETIVO_PRORRATEADO_ELEC) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND  ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_ELEC,
		(select max(PORC_ELECTRICIDAD) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_ELECTRICIDAD,
		(select max(CUMPLIMIENTO_OBJETIVO_ELEC) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_ELEC, 
--CLIENTES_CAPTADOS_Subv
		(select max(CLIENTES_CAPTADOS_SUBV) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CLIENTES_CAPTADOS_SUBV, 
		(select max(OBJETIVO_PRORRATEADO_SUBV) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_SUBV, 
		(select max(PORC_CLIENTES_CAPTADOS_SUBV) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CLIENTES_CAPTADOS_SUBV, 
		(select max(CUMPLIMIENTO_OBJETIVO_SUBV) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where  ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_SUBV, 
--SVAS
		(select max(SVAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as SVAS, 
		(select max(OBJETIVO_PRORRATEADO_SVA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_SVA, 
		(select max(PORC_SVAS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_SVAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_SVA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_SVA,
--NUMERO_VENTAS
		(select max(NUMERO_VENTAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as NUMERO_VENTAS, 
		(select max(OBJETIVO_PRORRATEADO_NV) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_NV, 
		(select max(PORC_NV) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_NV, 
		(select max(CUMPLIMIENTO_OBJETIVO_NV) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_NV, 
--DEUDA
		(select max(DEUDA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA, 
		(select max(OBJETIVO_PRORRATEADO_DEUDA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_DEUDA, 
		(select max(PORC_DEUDA) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA, 
		(select max(CUMPLIMIENTO_OBJETIVO_DEUDA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_DEUDA, 
--DEUDA_PROMEDIO
		(select max(DEUDA_PROMEDIO) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_PROMEDIO, 
		(select max(OBJETIVO_PRORRATEADO_DP) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_DP, 
		(select max(PORC_DEUDA_PROMEDIO) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_PROMEDIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_DP) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_DP, 
--DEUDA_FIN_ANIO
		(select max(DEUDA_FIN_ANIO) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_FIN_ANIO, 
		(select max(OBJETIVO_PRORRATEADO_DFA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_DFA, 
		(select max(PORC_DEUDA_FIN_ANIO) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_FIN_ANIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_DFA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_DFA,

--RMM - 01.06.2022   nuevo este año --BOM
--DEUDA_A_30
		(select max(DEUDA_AAPP_30) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_FIN_ANIO, 
		(select max(OBJETIVO_PRORRATEADO_DE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_DFA, 
		(select max(PORC_DEUDA_AAPP_30) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_FIN_ANIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_DE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_DFA,
--RMM - 01.06.2022   nuevo este año --EOM
/* RMM - 01.06.2022  ya no lo utilizamos este año --BOM
--CLIENTES_CAPTADOS
		(select max(CLIENTES_CAPTADOS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CLIENTES_CAPTADOS, 
		(select max(OBJETIVO_PRORRATEADO_CC) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_CC, 
		(select max(PORC_CLIENTES_CAPTADOS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CLIENTES_CAPTADOS, 
		(select max(CUMPLIMIENTO_OBJETIVO_CC) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where  ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_CC, 
 RMM - 01.06.2022  ya no lo utilizamos este año-- EOM */

--VOL_ELE_NEGOCIADO
		(select max(VOL_ELE_NEGOCIADO) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as VOL_ELE_NEGOCIADO, 
		(select max(OBJETIVO_PRORRATEADO_VEN) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_VEN, 
		(select max(PORC_VOL_ELE_NEGOCIADO) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_VOL_ELE_NEGOCIADO, 
		(select max(CUMPLIMIENTO_OBJETIVO_VEN) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_VEN, 
--GAS
		(select max(GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as GAS, 
		(select max(OBJETIVO_PRORRATEADO_GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_GAS, 
		(select max(PORC_GAS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_GAS, 
--CART_GAS
		(select max(CART_GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_GAS, 
		(select max(OBJETIVO_PRORRATEADO_CG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_CG, 
		(select max(PORC_CART_GAS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_CG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_CG, 
--RENTABILIDAD
		(select max(RENTABILIDAD) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD, 
		(select max(OBJETIVO_PRORRATEADO_RENT) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_RENT, 
		(select max(PORC_RENTABILIDAD) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD, 
		(select max(CUMPLIMIENTO_OBJETIVO_RENT) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_RENT, 
--RENTABILIDAD_GAS_EB
		(select max(RENTABILIDAD_GAS_EB) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD_GAS_EB, 
		(select max(OBJETIVO_PRORRATEADO_RGEB) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_RGEB, 
		(select max(PORC_RENTABILIDAD_GAS_EB) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD_GAS_EB, 
		(select max(CUMPLIMIENTO_OBJETIVO_RGEB) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_RGEB, 
--RENTABILIDAD_GAS
		(select max(RENTABILIDAD_GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD_GAS, 
		(select max(OBJETIVO_PRORRATEADO_RG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_RG, 
		(select max(PORC_RENTABILIDAD_GAS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_RG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_RG, 
--CART_SD_ELEC
		(select max(CART_SD_ELEC) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_SD_ELEC, 
		(select max(OBJETIVO_PRORRATEADO_CSE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_CSE, 
		(select max(PORC_CART_SD_ELEC) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_SD_ELEC, 
		(select max(CUMPLIMIENTO_OBJETIVO_CSE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_CSE, 
--CART_PROM_GAS-- RMM - 01-06.2022 - Reutilizamos para vol gas negociado
		(select max(CART_PROM_GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_PROM_GAS, 
		(select max(OBJETIVO_PRORRATEADO_CPG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_CPG, 
		(select max(PORC_CART_PROM_GAS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_PROM_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_CPG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_CPG, 
--CART_SD_GAS
		(select max(CART_SD_GAS) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_SD_GAS, 
		(select max(OBJETIVO_PRORRATEADO_CSG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_CSG, 
		(select max(PORC_CART_SD_GAS) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_SD_GAS, 
		(select max(CUMPLIMIENTO_OBJETIVO_CSG) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_CSG, 
--CART_ELE_AGR
		(select max(CART_ELE_AGR) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CART_ELE_AGR,
		(select max(OBJETIVO_PRORRATEADO_CEA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_CEA,
		(select max(PORC_CART_ELE_AGR) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CART_ELE_AGR,
		(select max(CUMPLIMIENTO_OBJETIVO_CEA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_CEA,
--RENT_ELE_AGR
		(select max(RENT_ELE_AGR) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENT_ELE_AGR,
		(select max(OBJETIVO_PRORRATEADO_REA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_REA,
		(select max(PORC_RENT_ELE_AGR) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENT_ELE_AGR,
		(select max(CUMPLIMIENTO_OBJETIVO_REA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_REA,
--RENTABILIDAD_GAS_AGR
		(select max(RENTABILIDAD_GAS_AGR) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as RENTABILIDAD_GAS_AGR, 
		(select max(OBJETIVO_PRORRATEADO_RGA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_RGA, 
		(select max(PORC_RENTABILIDAD_GAS_AGR) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_RENTABILIDAD_GAS_AGR, 
		(select max(CUMPLIMIENTO_OBJETIVO_RGA) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_RGA, 
--ASESORAMIENTO
		(select max(ASESORAMIENTO) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as ASESORAMIENTO, 
		(select max(OBJETIVO_PRORRATEADO_ASE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_ASE, 
		(select max(PORC_ASESORAMIENTO) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_ASESORAMIENTO, 
		(select max(CUMPLIMIENTO_OBJETIVO_ASE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_ASE, 
--RMM - 01.06.2022   nuevo este año --BOM
--CRECIMIENTO_A_30GW
		(select max(CRECIMIENTO_30GW) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as DEUDA_FIN_ANIO, 
		(select max(OBJETIVO_PRORRATEADO_CRE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as OBJETIVO_PRORRATEADO_DFA, 
		(select max(PORC_CRECIMIENTO_30GW) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_DEUDA_FIN_ANIO, 
		(select max(CUMPLIMIENTO_OBJETIVO_CRE) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as CUMPLIMIENTO_OBJETIVO_DFA,
--RMM - 01.06.2022   nuevo este año --EOM
--PORC_CONSECUCION_GLOBAL
        (select max(PORC_CONSECUCION_GLOBAL) * 100 from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as PORC_CONSECUCION_GLOBAL, 
--FECHA_PUBLICACION
		(select max(FECHA_PUBLICACION) from ENEL_NEW_CONSECUCION_TEMP_OFV ofv2 where ofv1.ID_FICHA = ofv2.id_ficha and ofv1.ID_USUARIO = ofv2.ID_USUARIO AND ofv1.PERIODSEQ = ofv2.PERIODSEQ) as FECHA_PUBLICACION

	from ENEL_NEW_CONSECUCION_TEMP_OFV ofv1
	
	where periodSeq = iperiodseq
	;
	
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_NEW_CONSECUCION_TEMP2_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_NEW_CONSECUCION_TEMP2_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_NEW_CONSECUCION_TEMP2_OFV',v_contador_debug);

end;

--PROCEDIMIENTO ANTIGUO
/*procedure p_Medidas_Consecucion_Final ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
As
begin
	w_debug('Inicio Borrado de la tabla ENEL_CONSECUCION_FINAL_OFV.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CONSECUCION_FINAL_OFV WHERE ANIO=
				(select to_char(startdate,'YYYY')
					from cs_period
					where periodseq=iperiodseq
					and removedate= v_eot
				) 
			and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
		END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_CONSECUCION_FINAL_OFV.', v_contador_debug);
	
	INSERT INTO ENELEXT.ENEL_CONSECUCION_FINAL_OFV(TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
											CLIENTES_CAPTADOS_VISITAS, OBJETIVO_PRORRATEADO, PORC_CLIENTES_CAPTADOS_VISITAS, CUMPLIMIENTO_OBJETIVO, 
											CLIENTES_CAPTADOS, OBJETIVO_PRORRATEAEDO, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_1, 
											SVAS, OBJETIVO_PRORRATEADO_1, PORC_SVAS, CUMPLIMIENTO_OBJETIVO_2, 
											OFERTAS_PRESENTADAS, OBJETIVO_PRORRATEAEDO_1, PORC_OFERTAS_PRESENTADAS, CUMPLIMIENTO_OBJETIVO_3, 
											DEUDA, OBJETIVO_PRORRATEADO_2, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_4,
											DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_3, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_5, 
											DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_4, PORC_DEUDA_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_6, 
											RENTABILIDAD, OBJETIVO_PRORRATEADO_5, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_7, 
											RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_6, PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_8, 
											DEUDA_PRIVADO_PROM, OBJETIVO_PRORRATEADO_7, PORC_DEUDA_PRIVADO_PROM, CUMPLIMIENTO_OBJETIVO_9, 
											DEUDA_AAPP_PROM, OBJETIVO_PRORRATEADO_8, PORC_DEUDA_AAPP_PROM, CUMPLIMIENTO_OBJETIVO_10, 
											DEUDA_PRIVADO_FIN_ANIO, OBJETIVO_PRORRATEADO_9, PORC_DEUDA_PRIVADO_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_11, 
											DEUDA_AAPP_FIN_ANIO, OBJETIVO_PRORRATEADO_10, PORC_DEUDA_AAPP_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_12, 
											ELECTRICIDAD, OBJETIVO_PRORRATEADO_11, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_13, 
											RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_12, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_14,
											GAS, OBJETIVO_PRORRATEADO_13, PORC_GAS, CUMPLIMIENTO_OBJETIVO_15, 
											RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_14, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_16,
											ASESORAMIENTO, OBJETIVO_PRORRATEADO_15, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_17, 
											ACTIVDAD_PRE_POST, OBJETIVO_PRORRATEADO_16, PORC_ACTIVDAD_PRE_POST, CUMPLIMIENTO_OBJETIVO_18, 
											CAPAC_FFVV, OBJETIVO_PRORRATEADO_17, POR_CAPAC_FFVV, CUMPLIMIENTO_OBJETIVO_19, 
											PORC_CONSECUCION_GLOBAL,
											-- nuevos campos 
											CART_ELE_SUBD, OBJETIVO_PRORRATEADO_18, PORC_CART_ELE_SUBD, CUMPLIMIENTO_OBJETIVO_20, 
											CART_GAS_SUBD, OBJETIVO_PRORRATEADO_19, PORC_CART_GAS_SUBD, CUMPLIMIENTO_OBJETIVO_21,
											CART_ELE_DIR, OBJETIVO_PRORRATEADO_20, PORC_CART_ELE_DIR, CUMPLIMIENTO_OBJETIVO_22,
											CART_GAS_DIR, OBJETIVO_PRORRATEADO_21, PORC_CART_GAS_DIR, CUMPLIMIENTO_OBJETIVO_23,
											CART_ELE_AGR, OBJETIVO_PRORRATEADO_22, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_24,
											RENT_ELE_AGR, OBJETIVO_PRORRATEADO_23, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_25,
											CART_GAS_AGR, OBJETIVO_PRORRATEADO_24, PORC_CART_GAS_AGR, CUMPLIMIENTO_OBJETIVO_26,
											FECHA_PUBLICACION)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'ID_USUARIO','ID_FICHA',
		'CLIENTES_CAPTADOS_VISITAS', 'OBJETIVO_PRORRATEADO', 'PORC_CLIENTES_CAPTADOS_VISITAS', 'CUMPLIMIENTO_OBJETIVO', 
		'CLIENTES_CAPTADOS', 'OBJETIVO_PRORRATEADO', 'PORC_CLIENTES_CAPTADOS', 'CUMPLIMIENTO_OBJETIVO', 
		'SVAS', 'OBJETIVO_PRORRATEADO', 'PORC_SVAS', 'CUMPLIMIENTO_OBJETIVO',
		'OFERTAS_PRESENTADAS', 'OBJETIVO_PRORRATEADO', 'PORC_OFERTAS_PRESENTADAS', 'CUMPLIMIENTO_OBJETIVO', 
		'DEUDA', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA', 'CUMPLIMIENTO_OBJETIVO', 
		'DEUDA_PROMEDIO', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_PROMEDIO', 'CUMPLIMIENTO_OBJETIVO',
		'DEUDA_FIN_ANIO', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_FIN_ANIO', 'CUMPLIMIENTO_OBJETIVO', 
		'RENTABILIDAD', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD', 'CUMPLIMIENTO_OBJETIVO', 
		'RENTABILIDAD_GAS', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD_GAS', 'CUMPLIMIENTO_OBJETIVO',
		'DEUDA_PRIVADO_PROM', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_PRIVADO_PROM', 'CUMPLIMIENTO_OBJETIVO',
		'DEUDA_AAPP_PROM', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_AAPP_PROM', 'CUMPLIMIENTO_OBJETIVO', 
		'DEUDA_PRIVADO_FIN_ANIO', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_PRIVADO_FIN_ANIO', 'CUMPLIMIENTO_OBJETIVO',
		'DEUDA_AAPP_FIN_ANIO', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_AAPP_FIN_ANIO', 'CUMPLIMIENTO_OBJETIVO', 
		'ELECTRICIDAD', 'OBJETIVO_PRORRATEADO', 'PORC_ELECTRICIDAD', 'CUMPLIMIENTO_OBJETIVO', 
		'RENTABILIDAD_GAS_EB', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD_GAS_EB', 'CUMPLIMIENTO_OBJETIVO', 
		'GAS', 'OBJETIVO_PRORRATEADO', 'PORC_GAS', 'CUMPLIMIENTO_OBJETIVO', 
		'RENTABILIDAD_GAS_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD_GAS_AGR', 'CUMPLIMIENTO_OBJETIVO',
		'ASESORAMIENTO', 'OBJETIVO_PRORRATEADO', 'PORC_ASESORAMIENTO', 'CUMPLIMIENTO_OBJETIVO', 
		'ACTIVDAD_PRE_POST', 'OBJETIVO_PRORRATEADO', 'PORC_ACTIVDAD_PRE_POST', 'CUMPLIMIENTO_OBJETIVO', 
		'CAPAC_FFVV', 'OBJETIVO_PRORRATEADO', 'POR_CAPAC_FFVV', 'CUMPLIMIENTO_OBJETIVO', 
		'PORC_CONSECUCION_GLOBAL',
		'CART_ELE_SUBD', 'OBJETIVO_PRORRATEADO', 'PORC_CART_ELE_SUBD', 'CUMPLIMIENTO_OBJETIVO',
		'CART_GAS_SUBD', 'OBJETIVO_PRORRATEADO', 'PORC_CART_GAS_SUBD', 'CUMPLIMIENTO_OBJETIVO',
		'CART_ELE_DIR', 'OBJETIVO_PRORRATEADO', 'PORC_CART_ELE_DIR', 'CUMPLIMIENTO_OBJETIVO',
		'CART_GAS_DIR', 'OBJETIVO_PRORRATEADO', 'PORC_CART_GAS_DIR', 'CUMPLIMIENTO_OBJETIVO',
		'CART_ELE_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_CART_ELE_AGR', 'CUMPLIMIENTO_OBJETIVO',
		'RENT_ELE_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_RENT_ELE_AGR', 'CUMPLIMIENTO_OBJETIVO',
		'CART_GAS_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_CART_GAS_AGR', 'CUMPLIMIENTO_OBJETIVO', 
		'FECHA_PUBLICACION'
	);
		
	INSERT INTO ENELEXT.ENEL_CONSECUCION_FINAL_OFV (TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
											CLIENTES_CAPTADOS_VISITAS, OBJETIVO_PRORRATEADO, PORC_CLIENTES_CAPTADOS_VISITAS, CUMPLIMIENTO_OBJETIVO, 
											CLIENTES_CAPTADOS, OBJETIVO_PRORRATEAEDO, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_1, 
											SVAS, OBJETIVO_PRORRATEADO_1, PORC_SVAS, CUMPLIMIENTO_OBJETIVO_2, 
											OFERTAS_PRESENTADAS, OBJETIVO_PRORRATEAEDO_1, PORC_OFERTAS_PRESENTADAS, CUMPLIMIENTO_OBJETIVO_3, 
											DEUDA, OBJETIVO_PRORRATEADO_2, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_4,
											DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_3, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_5, 
											DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_4, PORC_DEUDA_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_6, 
											RENTABILIDAD, OBJETIVO_PRORRATEADO_5, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_7, 
											RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_6, PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_8, 
											DEUDA_PRIVADO_PROM, OBJETIVO_PRORRATEADO_7, PORC_DEUDA_PRIVADO_PROM, CUMPLIMIENTO_OBJETIVO_9, 
											DEUDA_AAPP_PROM, OBJETIVO_PRORRATEADO_8, PORC_DEUDA_AAPP_PROM, CUMPLIMIENTO_OBJETIVO_10, 
											DEUDA_PRIVADO_FIN_ANIO, OBJETIVO_PRORRATEADO_9, PORC_DEUDA_PRIVADO_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_11, 
											DEUDA_AAPP_FIN_ANIO, OBJETIVO_PRORRATEADO_10, PORC_DEUDA_AAPP_FIN_ANIO, CUMPLIMIENTO_OBJETIVO_12, 
											ELECTRICIDAD, OBJETIVO_PRORRATEADO_11, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_13, 
											RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_12, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_14,
											GAS, OBJETIVO_PRORRATEADO_13, PORC_GAS, CUMPLIMIENTO_OBJETIVO_15, 
											RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_14, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_16,
											ASESORAMIENTO, OBJETIVO_PRORRATEADO_15, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_17, 
											ACTIVDAD_PRE_POST, OBJETIVO_PRORRATEADO_16, PORC_ACTIVDAD_PRE_POST, CUMPLIMIENTO_OBJETIVO_18, 
											CAPAC_FFVV, OBJETIVO_PRORRATEADO_17, POR_CAPAC_FFVV, CUMPLIMIENTO_OBJETIVO_19, 
											PORC_CONSECUCION_GLOBAL,
											-- nuevos campos 
											CART_ELE_SUBD, OBJETIVO_PRORRATEADO_18, PORC_CART_ELE_SUBD, CUMPLIMIENTO_OBJETIVO_20, 
											CART_GAS_SUBD, OBJETIVO_PRORRATEADO_19, PORC_CART_GAS_SUBD, CUMPLIMIENTO_OBJETIVO_21,
											CART_ELE_DIR, OBJETIVO_PRORRATEADO_20, PORC_CART_ELE_DIR, CUMPLIMIENTO_OBJETIVO_22,
											CART_GAS_DIR, OBJETIVO_PRORRATEADO_21, PORC_CART_GAS_DIR, CUMPLIMIENTO_OBJETIVO_23,
											CART_ELE_AGR, OBJETIVO_PRORRATEADO_22, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_24,
											RENT_ELE_AGR, OBJETIVO_PRORRATEADO_23, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_25,
											CART_GAS_AGR, OBJETIVO_PRORRATEADO_24, PORC_CART_GAS_AGR, CUMPLIMIENTO_OBJETIVO_26,
											FECHA_PUBLICACION)
	select
		TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
--CLIENTES_CAPTADOS_VISITAS
		trim(to_char(round(emf.CLIENTES_CAPTADOS_VISITAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CLIENTES_CAPTADOS_VISITAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO,2),'9999999999990.99')), 
--CLIENTES_CAPTADOS
		trim(to_char(round(emf.CLIENTES_CAPTADOS,0))),
		trim(to_char(round(emf.OBJETIVO_PRORRATEAEDO,0))),
		trim(to_char(round(emf.PORC_CLIENTES_CAPTADOS,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_1,2),'9999999999990.99')), 
--SVAS
		trim(to_char(round(emf.SVAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_1,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_SVAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_2,2),'9999999999990.99')),
--OFERTAS_PRESENTADAS
		trim(to_char(round(emf.OFERTAS_PRESENTADAS,0))),
		trim(to_char(round(emf.OBJETIVO_PRORRATEAEDO_1,0))),
		trim(to_char(round(emf.PORC_OFERTAS_PRESENTADAS,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_3,2),'9999999999990.99')),
--DEUDA
		trim(to_char(round(emf.DEUDA,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_2,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_4,2),'9999999999990.99')),
--DEUDA_PROMEDIO
		trim(to_char(round(emf.DEUDA_PROMEDIO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_3,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_PROMEDIO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_5,2),'9999999999990.99')),
--DEUDA_FIN_ANIO
		trim(to_char(round(emf.DEUDA_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_4,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_6,2),'9999999999990.99')),
--RENTABILIDAD
		trim(to_char(round(emf.RENTABILIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_5,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_7,2),'9999999999990.99')),
--RENTABILIDAD_GAS
		trim(to_char(round(emf.RENTABILIDAD_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_6,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_8,2),'9999999999990.99')),
--DEUDA_PRIVADO_PROM
		trim(to_char(round(emf.DEUDA_PRIVADO_PROM,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_7,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_PRIVADO_PROM,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_9,2),'9999999999990.99')),
--DEUDA_AAPP_PROM
		trim(to_char(round(emf.DEUDA_AAPP_PROM,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_8,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_AAPP_PROM,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_10,2),'9999999999990.99')),
--DEUDA_PRIVADO_FIN_ANIO
		trim(to_char(round(emf.DEUDA_PRIVADO_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_9,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_PRIVADO_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_11,2),'9999999999990.99')),
--DEUDA_AAPP_FIN_ANIO
		trim(to_char(round(emf.DEUDA_AAPP_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_10,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_AAPP_FIN_ANIO,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_12,2),'9999999999990.99')),
--ELECTRICIDAD
		trim(to_char(round(emf.ELECTRICIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_11,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_ELECTRICIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_13,2),'9999999999990.99')),
--RENTABILIDAD_GAS_EB
		trim(to_char(round(emf.RENTABILIDAD_GAS_EB,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_12,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD_GAS_EB,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_14,2),'9999999999990.99')),
--GAS
		trim(to_char(round(emf.GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_13,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_15,2),'9999999999990.99')),
--RENTABILIDAD_GAS_AGR
		trim(to_char(round(emf.RENTABILIDAD_GAS_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_14,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD_GAS_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_16,2),'9999999999990.99')),
--ASESORAMIENTO
		trim(to_char(round(emf.ASESORAMIENTO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_15,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_ASESORAMIENTO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_17,2),'9999999999990.99')),
--ACTIVDAD_PRE_POST
		trim(to_char(round(emf.ACTIVDAD_PRE_POST,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_16,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_ACTIVDAD_PRE_POST,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_18,2),'9999999999990.99')),
--CAPAC_FFVV
		trim(to_char(round(emf.CAPAC_FFVV,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_17,2),'9999999999990.99')),
		trim(to_char(round(emf.POR_CAPAC_FFVV,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_19,2),'9999999999990.99')),
--PORC_CONSECUCION_GLOBAL
		trim(to_char(round(emf.PORC_CONSECUCION_GLOBAL,2),'9999999999990.99')),
--CART_ELE_SUBD
		trim(to_char(round(emf.CART_ELE_SUBD,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_18,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_ELE_SUBD,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_20,2),'9999999999990.99')),
--CART_GAS_SUBD
		trim(to_char(round(emf.CART_GAS_SUBD,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_19,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_GAS_SUBD,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_21,2),'9999999999990.99')),
--CART_ELE_DIR
		trim(to_char(round(emf.CART_ELE_DIR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_20,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_ELE_DIR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_22,2),'9999999999990.99')),
--CART_GAS_DIR
		trim(to_char(round(emf.CART_GAS_DIR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_21,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_GAS_DIR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_23,2),'9999999999990.99')),
--CART_ELE_AGR
		trim(to_char(round(emf.CART_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_22,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_24,2),'9999999999990.99')),
--RENT_ELE_AGR
		trim(to_char(round(emf.RENT_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_23,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENT_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_25,2),'9999999999990.99')),
--CART_GAS_AGR
		trim(to_char(round(emf.CART_GAS_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_24,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_GAS_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_26,2),'9999999999990.99')),
--FECHA_PUBLICACION	
		FECHA_PUBLICACION
			
	from ENEL_CONSECUCION_TEMP2_OFV emf
	
	where periodSeq = iperiodseq
	;
	
	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_CONSECUCION_FINAL_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CONSECUCION_FINAL_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CONSECUCION_FINAL_OFV',v_contador_debug);

end;*/

procedure p_Medidas_Consecucion_Final ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, ISTAGE IN VARCHAR2 )
As
begin
	w_debug('Inicio Borrado de la tabla ENEL_NEW_CONSECUCION_FINAL_OFV.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_NEW_CONSECUCION_FINAL_OFV WHERE ANIO=
				(select to_char(startdate,'YYYY')
					from cs_period
					where periodseq=iperiodseq
					and removedate= v_eot
				) 
			and ROWNUM <= 10000;
            
			EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
		END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_NEW_CONSECUCION_FINAL_OFV.', v_contador_debug);
	
	INSERT INTO ENELEXT.ENEL_NEW_CONSECUCION_FINAL_OFV(TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA, 
                                                ELECTRICIDAD, OBJETIVO_PRORRATEADO_ELEC, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_ELEC, 
                                                CLIENTES_CAPTADOS_SUBV, OBJETIVO_PRORRATEADO_SUBV, PORC_CLIENTES_CAPTADOS_SUBV, CUMPLIMIENTO_OBJETIVO_SUBV, 
                                                SVAS, OBJETIVO_PRORRATEADO_SVA, PORC_SVAS, 	CUMPLIMIENTO_OBJETIVO_SVA,
                                                NUMERO_VENTAS, OBJETIVO_PRORRATEADO_NV, PORC_NV, CUMPLIMIENTO_OBJETIVO_NV, 
                                                DEUDA, OBJETIVO_PRORRATEADO_DEUDA, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_DEUDA, 
                                                DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_DP, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_DP,
                                                DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_DFA, PORC_DEUDA_FIN_ANIO,	CUMPLIMIENTO_OBJETIVO_DFA,
                                                DEUDA_AAPP_30, OBJETIVO_PRORRATEADO_DE, PORC_DEUDA_AAPP_30, CUMPLIMIENTO_OBJETIVO_DE, --RMM 01.06.2022 Nuevo
                                                --CLIENTES_CAPTADOS, OBJETIVO_PRORRATEADO_CC, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_CC, ----RMM 01.06.2022 Borramos
												VOL_ELE_NEGOCIADO, OBJETIVO_PRORRATEADO_VEN, PORC_VOL_ELE_NEGOCIADO, CUMPLIMIENTO_OBJETIVO_VEN, 
                                                GAS, OBJETIVO_PRORRATEADO_GAS, 	PORC_GAS, CUMPLIMIENTO_OBJETIVO_GAS,
                                                CART_GAS, OBJETIVO_PRORRATEADO_CG, PORC_CART_GAS, CUMPLIMIENTO_OBJETIVO_CG,
												RENTABILIDAD, OBJETIVO_PRORRATEADO_RENT, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_RENT,
                                                RENTABILIDAD_GAS_EB, OBJETIVO_PRORRATEADO_RGEB, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_RGEB, 
                                                RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_RG, 	PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_RG, 
                                                CART_SD_ELEC, OBJETIVO_PRORRATEADO_CSE, PORC_CART_SD_ELEC, CUMPLIMIENTO_OBJETIVO_CSE, 
												CART_PROM_GAS, OBJETIVO_PRORRATEADO_CPG, PORC_CART_PROM_GAS, CUMPLIMIENTO_OBJETIVO_CPG,  --RMM 01.06.2022 reutilizamos para gas negociado
                                                CART_SD_GAS, OBJETIVO_PRORRATEADO_CSG,  PORC_CART_SD_GAS, CUMPLIMIENTO_OBJETIVO_CSG, 
                                                CART_ELE_AGR, OBJETIVO_PRORRATEADO_CEA, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_CEA, 
                                                RENT_ELE_AGR, OBJETIVO_PRORRATEADO_REA, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_REA,
                                                RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_RGA, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_RGA, 
                                                ASESORAMIENTO, OBJETIVO_PRORRATEADO_ASE, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_ASE,
                                                CRECIMIENTO_30GW, OBJETIVO_PRORRATEADO_CRE, PORC_CRECIMIENTO_30GW, CUMPLIMIENTO_OBJETIVO_CRE, --RMM 01.06.2022 Nuevo
                                                PORC_CONSECUCION_GLOBAL, FECHA_PUBLICACION)
    VALUES (
		'ENEL',
		NULL,
		null,
		(select to_char(startdate,'YYYY')
			from cs_period
			where periodseq=iperiodseq
			and removedate= v_eot),
		'ID_USUARIO','ID_FICHA',
		'ELECTRICIDAD', 'OBJETIVO_PRORRATEADO', 'PORC_ELECTRICIDAD', 'CUMPLIMIENTO_OBJETIVO', 
        'CLIENTES_CAPTADOS_Subv', 'OBJETIVO_PRORRATEADO', 'PORC_CLIENTES_CAPTADOS_Subv', 'CUMPLIMIENTO_OBJETIVO', 
        'SVAS', 'OBJETIVO_PRORRATEADO',	'PORC_SVAS', 'CUMPLIMIENTO_OBJETIVO', 
        'NUMERO_VENTAS', 'OBJETIVO_PRORRATEADO', 'PORC_NUMERO_VENTAS', 'CUMPLIMIENTO_OBJETIVO', 
		'DEUDA', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA', 'CUMPLIMIENTO_OBJETIVO', 
        'DEUDA_PROMEDIO', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_PROMEDIO', 'CUMPLIMIENTO_OBJETIVO',
        'DEUDA_FIN_ANIO', 'OBJETIVO_PRORRATEADO', 'PORC_DEUDA_FIN_ANIO', 'CUMPLIMIENTO_OBJETIVO',
        'DEUDA_AAPP_30','OBJETIVO_PRORRATEADO','PORC_DEUDA_AAPP_30', 'CUMPLIMIENTO_OBJETIVO', --RMM 01.06.2022 Nuevo
		--'CLIENTES_CAPTADOS_V', 'OBJETIVO_PRORRATEADO', 'PORC_CLIENTES_CAPTADOS_V', 'CUMPLIMIENTO_OBJETIVO', --RMM 01.06.2022 Borramos
		--'VOL_ELE_NEGOCIADO_CART_PROM_ELEC', 'OBJETIVO_PRORRATEADO', ' PORC_VOL_ELE_NEGOCIADO_CART_PROM_ELEC', 'CUMPLIMIENTO_OBJETIVO', --RMM 01.06.2022 Renombramos
        'VOL_ELE_NEGOCIADO', 'OBJETIVO_PRORRATEADO', 'PORC_VOL_ELE_NEGOCIADO', 'CUMPLIMIENTO_OBJETIVO', --RMM 01.06.2022 nombre tras renombrar
        'GAS', 'OBJETIVO_PRORRATEADO','PORC_GAS', 'CUMPLIMIENTO_OBJETIVO',
        'CART_GAS', 'OBJETIVO_PRORRATEADO', 'PORC_CART_GAS', 'CUMPLIMIENTO_OBJETIVO',
		'RENTABILIDAD', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD', 'CUMPLIMIENTO_OBJETIVO',
        'RENTABILIDAD_GAS_EB', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD_GAS_EB', 'CUMPLIMIENTO_OBJETIVO', 
        'RENTABILIDAD_GAS', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD_GAS', 'CUMPLIMIENTO_OBJETIVO', 
        'CART_SD_ELEC', 'OBJETIVO_PRORRATEADO', 'PORC_CART_SD_ELEC', 'CUMPLIMIENTO_OBJETIVO', 
		--'CART_PROM_GAS', 'OBJETIVO_PRORRATEADO', 'PORC_CART_PROM_GAS', 'CUMPLIMIENTO_OBJETIVO', --RMM 01.06.2022 renombramos
        --APM 30.06.2022 BOM Cambiar el nombre del campo PORC_GAS_NEGOCIADO por PORC_VOL_GAS_NEGOCIADO
        --'VOL_GAS_NEGOCIADO', 'OBJETIVO_PRORRATEADO', 'PORC_GAS_NEGOCIADO', 'CUMPLIMIENTO_OBJETIVO',  --RMM 01.06.2022 nombre tras renombrar
        'VOL_GAS_NEGOCIADO', 'OBJETIVO_PRORRATEADO', 'PORC_VOL_GAS_NEGOCIADO', 'CUMPLIMIENTO_OBJETIVO', 
        --APM 30.06.2022 EOM
        'CART_SD_GAS', 'OBJETIVO_PRORRATEADO', 'PORC_CART_SD_GAS', 'CUMPLIMIENTO_OBJETIVO',
        'CART_ELE_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_CART_ELE_AGR', 'CUMPLIMIENTO_OBJETIVO', 
        'RENT_ELE_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_RENT_ELE_AGR', 'CUMPLIMIENTO_OBJETIVO', 
        'RENTABILIDAD_GAS_AGR', 'OBJETIVO_PRORRATEADO', 'PORC_RENTABILIDAD_GAS_AGR', 'CUMPLIMIENTO_OBJETIVO',
        'ASESORAMIENTO', 'OBJETIVO_PRORRATEADO', 'PORC_ASESORAMIENTO', 'CUMPLIMIENTO_OBJETIVO',
        'CRECIMIENTO_30GW', 'OBJETIVO_PRORRATEADO', 'PORC_CRECIMIENTO_30GW', 'CUMPLIMIENTO_OBJETIVO', --RMM 01.06.2022 Nuevo
        'PORC_CONSECUCION_GLOBAL', 'FECHA_PUBLICACION'	);
		
	INSERT INTO ENELEXT.ENEL_NEW_CONSECUCION_FINAL_OFV (TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA, 
                                                ELECTRICIDAD, OBJETIVO_PRORRATEADO_ELEC, PORC_ELECTRICIDAD, CUMPLIMIENTO_OBJETIVO_ELEC, 
                                                CLIENTES_CAPTADOS_SUBV, OBJETIVO_PRORRATEADO_SUBV, PORC_CLIENTES_CAPTADOS_SUBV, CUMPLIMIENTO_OBJETIVO_SUBV,
                                                SVAS, OBJETIVO_PRORRATEADO_SVA, PORC_SVAS, 	CUMPLIMIENTO_OBJETIVO_SVA, 
                                                NUMERO_VENTAS, OBJETIVO_PRORRATEADO_NV, PORC_NV, CUMPLIMIENTO_OBJETIVO_NV, 
                                                DEUDA, OBJETIVO_PRORRATEADO_DEUDA, PORC_DEUDA, CUMPLIMIENTO_OBJETIVO_DEUDA,
                                                DEUDA_PROMEDIO, OBJETIVO_PRORRATEADO_DP, PORC_DEUDA_PROMEDIO, CUMPLIMIENTO_OBJETIVO_DP,
                                                DEUDA_FIN_ANIO, OBJETIVO_PRORRATEADO_DFA, PORC_DEUDA_FIN_ANIO, 	CUMPLIMIENTO_OBJETIVO_DFA,
                                                DEUDA_AAPP_30, OBJETIVO_PRORRATEADO_DE, PORC_DEUDA_AAPP_30, CUMPLIMIENTO_OBJETIVO_DE, --RMM 01.06.2022 Nuevo
                                                --CLIENTES_CAPTADOS, OBJETIVO_PRORRATEADO_CC, PORC_CLIENTES_CAPTADOS, CUMPLIMIENTO_OBJETIVO_CC, ----RMM 01.06.2022 Borramos
												VOL_ELE_NEGOCIADO, OBJETIVO_PRORRATEADO_VEN, PORC_VOL_ELE_NEGOCIADO, CUMPLIMIENTO_OBJETIVO_VEN, 
                                                GAS, OBJETIVO_PRORRATEADO_GAS, PORC_GAS, CUMPLIMIENTO_OBJETIVO_GAS,
                                                CART_GAS, OBJETIVO_PRORRATEADO_CG, PORC_CART_GAS, CUMPLIMIENTO_OBJETIVO_CG,
												RENTABILIDAD, OBJETIVO_PRORRATEADO_RENT, PORC_RENTABILIDAD, CUMPLIMIENTO_OBJETIVO_RENT, 
                                                RENTABILIDAD_GAS_EB,OBJETIVO_PRORRATEADO_RGEB, PORC_RENTABILIDAD_GAS_EB, CUMPLIMIENTO_OBJETIVO_RGEB,
                                                RENTABILIDAD_GAS, OBJETIVO_PRORRATEADO_RG, PORC_RENTABILIDAD_GAS, CUMPLIMIENTO_OBJETIVO_RG,
                                                CART_SD_ELEC, OBJETIVO_PRORRATEADO_CSE, PORC_CART_SD_ELEC, CUMPLIMIENTO_OBJETIVO_CSE, 
												CART_PROM_GAS, OBJETIVO_PRORRATEADO_CPG, PORC_CART_PROM_GAS, CUMPLIMIENTO_OBJETIVO_CPG, --RMM 01.06.2022 reutilizamos para gas negociado
                                                CART_SD_GAS, OBJETIVO_PRORRATEADO_CSG, PORC_CART_SD_GAS, CUMPLIMIENTO_OBJETIVO_CSG, 
                                                CART_ELE_AGR, OBJETIVO_PRORRATEADO_CEA, PORC_CART_ELE_AGR, CUMPLIMIENTO_OBJETIVO_CEA, 
                                                RENT_ELE_AGR, OBJETIVO_PRORRATEADO_REA, PORC_RENT_ELE_AGR, CUMPLIMIENTO_OBJETIVO_REA,
                                                RENTABILIDAD_GAS_AGR, OBJETIVO_PRORRATEADO_RGA, PORC_RENTABILIDAD_GAS_AGR, CUMPLIMIENTO_OBJETIVO_RGA, 
                                                ASESORAMIENTO, OBJETIVO_PRORRATEADO_ASE, PORC_ASESORAMIENTO, CUMPLIMIENTO_OBJETIVO_ASE,
                                                CRECIMIENTO_30GW, OBJETIVO_PRORRATEADO_CRE, PORC_CRECIMIENTO_30GW, CUMPLIMIENTO_OBJETIVO_CRE, --RMM 01.06.2022 Nuevo
                                                PORC_CONSECUCION_GLOBAL, FECHA_PUBLICACION)
	select
		TENANTID, PERIODSEQ, PERIODO, ANIO, ID_USUARIO, ID_FICHA,
--ELECTRICIDAD
		trim(to_char(round(emf.ELECTRICIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_ELEC,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_ELECTRICIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_ELEC,2),'9999999999990.99')),
--CLIENTES_CAPTADOS_SUBV
		trim(to_char(round(emf.CLIENTES_CAPTADOS_SUBV,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_SUBV,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CLIENTES_CAPTADOS_SUBV,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_SUBV,2),'9999999999990.99')), 
--SVAS
		trim(to_char(round(emf.SVAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_SVA,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_SVAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_SVA,2),'9999999999990.99')),
--NUMERO_VENTAS
  --APM 29.06.2022 BOM
		/*trim(to_char(round(emf.NUMERO_VENTAS,0))),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_NV,0))),*/
        trim(to_char(round(emf.NUMERO_VENTAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_NV,2),'9999999999990.99')),
  --APM 29.06.2022 EOM
		trim(to_char(round(emf.PORC_NV,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_NV,2),'9999999999990.99')),
--DEUDA
		trim(to_char(round(emf.DEUDA,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_DEUDA,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_DEUDA,2),'9999999999990.99')),
--DEUDA_PROMEDIO
		trim(to_char(round(emf.DEUDA_PROMEDIO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_DP,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_PROMEDIO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_DP,2),'9999999999990.99')),
--DEUDA_FIN_ANIO
		trim(to_char(round(emf.DEUDA_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_DFA,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_DEUDA_FIN_ANIO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_DFA,2),'9999999999990.99')),
  /* RMM  01.01.2022 -   BOM -
     --Nuevo deuda a 30 
        --DEUDA_A_30*/
        trim(to_char(round(emf. DEUDA_AAPP_30,2))),--RMM 22.08.2022 pasamos de 0 decimales a 2 decimales
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_DE,2))), --RMM 22.08.2022 pasamos de 0 decimales a 2 decimales
		trim(to_char(round(emf.PORC_DEUDA_AAPP_30,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_DE,2),'9999999999990.99')),
/* RMM  01.01.2022 -   Clientes captado este año no se utiliza
--CLIENTES_CAPTADOS
		trim(to_char(round(emf.CLIENTES_CAPTADOS,0))),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CC,0))),
		trim(to_char(round(emf.PORC_CLIENTES_CAPTADOS,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CC,2),'9999999999990.99')), 
        
 */  --RMM 01.01.2022   --EOF
--VOL_ELE_NEGOCIADO
		trim(to_char(round(emf.VOL_ELE_NEGOCIADO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_VEN,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_VOL_ELE_NEGOCIADO,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_VEN,2),'9999999999990.99')),
--GAS
		trim(to_char(round(emf.GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_GAS,2),'9999999999990.99')),
--CART_GAS
		trim(to_char(round(emf.CART_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CG,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CG,2),'9999999999990.99')),
--RENTABILIDAD
		trim(to_char(round(emf.RENTABILIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_RENT,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_RENT,2),'9999999999990.99')),
--RENTABILIDAD_GAS_EB
		trim(to_char(round(emf.RENTABILIDAD_GAS_EB,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_RGEB,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD_GAS_EB,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_RGEB,2),'9999999999990.99')),
--RENTABILIDAD_GAS
		trim(to_char(round(emf.RENTABILIDAD_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_RG,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_RG,2),'9999999999990.99')),
--CART_SD_ELEC
		trim(to_char(round(emf.CART_SD_ELEC,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CSE,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_SD_ELEC,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CSE,2),'9999999999990.99')),
--CART_PROM_GAS -- REUTILIZAMOS PARA GAS NEGOCIADO
		trim(to_char(round(emf.CART_PROM_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CPG,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_PROM_GAS,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CPG,2),'9999999999990.99')),
--CART_SD_GAS
		trim(to_char(round(emf.CART_SD_GAS,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CSG,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_SD_GAS,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CSG,2),'9999999999990.99')),
--CART_ELE_AGR
		trim(to_char(round(emf.CART_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CEA,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_CART_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CEA,2),'9999999999990.99')),
--RENT_ELE_AGR
		trim(to_char(round(emf.RENT_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_REA,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENT_ELE_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_REA,2),'9999999999990.99')),
--RENTABILIDAD_GAS_AGR
		trim(to_char(round(emf.RENTABILIDAD_GAS_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_RGA,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_RENTABILIDAD_GAS_AGR,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_RGA,2),'9999999999990.99')),
--ASESORAMIENTO
		trim(to_char(round(emf.ASESORAMIENTO,2),'9999999999990.99')),
		trim(to_char(round(emf.OBJETIVO_PRORRATEADO_ASE,2),'9999999999990.99')),
		trim(to_char(round(emf.PORC_ASESORAMIENTO,2),'9999999999990.99')),
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_ASE,2),'9999999999990.99')),
 /* RMM  01.01.2022 -   BOM -
     --Nuevo deuda a 30 
        --CRECIMIENTO_30GW*/
--APM 29.06.2022 BOM
        --trim(to_char(round(emf. CRECIMIENTO_30GW,0))),
        --trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CRE,0))),
        trim(to_char(round(emf. CRECIMIENTO_30GW,2),'9999999999990.99')),
        trim(to_char(round(emf.OBJETIVO_PRORRATEADO_CRE,2),'9999999999990.99')),
--APM 29.06.2022 EOM        
		trim(to_char(round(emf.PORC_CRECIMIENTO_30GW,2),'9999999999990.99')), 
		trim(to_char(round(emf.CUMPLIMIENTO_OBJETIVO_CRE,2),'9999999999990.99')),        
 -- RMM 01.01.2022 - EOM       
--PORC_CONSECUCION_GLOBAL
        trim(to_char(round(emf.PORC_CONSECUCION_GLOBAL,2),'9999999999990.99')),
--FECHA_PUBLICACION	
		FECHA_PUBLICACION
			
	from ENEL_NEW_CONSECUCION_TEMP2_OFV emf
	
	where periodSeq = iperiodseq
	;
	
	filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_NEW_CONSECUCION_FINAL_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_NEW_CONSECUCION_FINAL_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_NEW_CONSECUCION_FINAL_OFV',v_contador_debug);

end;

-- aniadimos la funcion que rellena la cabecera en el caso de que no exista. 
function f_ComprobarCabecera(itenantId IN VARCHAR2) return boolean as   
    v_chequeadaCabecera BOOLEAN;
    cabecera integer;
    
    begin
        select count(*) into cabecera from ENELEXT.ENEL_CREDITOS_FINAL_OFV where periodseq is null and ischild like 'ISCHILD';

        if (cabecera > 1) then
            DELETE FROM ENELEXT.ENEL_CREDITOS_FINAL_OFV WHERE  periodseq is null and  ROWNUM < cabecera;
            -- Actualizamos el estado de la unica cabecera que dejamos
            UPDATE ENELEXT.ENEL_CREDITOS_FINAL_OFV SET estado = null WHERE  periodseq is null and ischild like 'ISCHILD';
            v_chequeadaCabecera := true;
        else 
            if (cabecera = 1) then
                UPDATE ENELEXT.ENEL_CREDITOS_FINAL_OFV SET estado = null WHERE  periodseq is null and ischild like 'ISCHILD';
                v_chequeadaCabecera := true;
            else
                INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_OFV(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VALUE,TIPO_USUARIO,TIPO_MOTIVO,ischild)
                VALUES ('ENEL',NULL,null,'2019','ID_VISITA','USUARIO','FICHA','VALOR','TIPO_DE_USUARIO','TIPO_DE_MOTIVO','ISCHILD');
                v_chequeadaCabecera := false;
            end if;
        end if;
    commit;
    return v_chequeadaCabecera;  
    
end;

-- Informe de Creditos Visitas
PROCEDURE p_Creditos_Final ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2)
AS
	v_cabecera boolean;
	v_fecha_publi date;
	v_fecha_fija date;
	v_cuenta integer;
begin	
	w_debug('Inicio consulta fecha PUBLI tabla ENEL_CREDITOS_FINAL', v_contador_debug);

	select count(distinct cred.genericdate2) into v_cuenta
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid='OFV Visitas'
		
		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantId = itenantId
		
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate =V_EOT
			and cspa.tenantId = itenantId
			and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
		
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspo.tenantId = itenantId
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--AND CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE 
		to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
		and cspo.name like 'a4%'
		and cred.genericdate2 is not null;
	
	w_debug('Cuenta fecha PUBLI tabla ENEL_CREDITOS_FINAL ==> ' || v_cuenta , v_contador_debug);
	
	if (v_cuenta = 1) then 
		-- se hace la comprobacion para cargar la tabla fija en el caso de que sea necesario, solo cuando la fecha de publicacion del credito, GD2, cambie.
		select distinct cred.genericdate2 into v_fecha_publi
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid='OFV Visitas'
			
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
			
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate =V_EOT
				and cspa.tenantId = itenantId
				and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
			
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspo.tenantId = itenantId
				and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--AND CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE 
			to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
			and cspo.name like 'a4%'
			and cred.genericdate2 is not null;
	else 
		if (v_cuenta > 1) then
			w_debug('Cuenta fecha PUBLI tabla ENEL_CREDITOS_FINAL OJO!! Más de una', v_contador_debug);
			select max(cred.genericdate2) into v_fecha_publi
				from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid='OFV Visitas'
				
				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
				
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate =V_EOT
					and cspa.tenantId = itenantId
					and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
				
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspo.tenantId = itenantId
					and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
					-- MPR se comenta y se controla duplicidad por fecha startdate.
					--AND CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT GROUP BY NAME HAVING COUNT(*) < 2)
			WHERE 
				to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
				and cspo.name like 'a4%'
				and cred.genericdate2 is not null;
		else
			v_fecha_publi:= to_date('01/01/2200','DD/MM/YYYY');
		end if;
	end if;

	w_debug('FIN consulta fecha PUBLI tabla ENEL_CREDITOS_FINAL ==> ' || v_fecha_publi , v_contador_debug);

	w_debug('Inicio consulta fecha FIJA tabla ENEL_CREDITOS_FINAL_OFV_FIJA.', v_contador_debug);
	
	SELECT count(distinct FECHA_PUBLI) INTO v_cuenta
	FROM ENELEXT.ENEL_CREDITOS_FINAL_OFV_FIJA
	WHERE FECHA_PUBLI IS NOT NULL
	AND PERIODO = iperiod;
	
	w_debug('Cuenta fecha FIJA tabla ENEL_CREDITOS_FINAL_OFV_FIJA. ==> ' || v_cuenta , v_contador_debug);
	
	if(v_cuenta = 1) then 
		SELECT DISTINCT FECHA_PUBLI INTO v_fecha_fija
		FROM ENELEXT.ENEL_CREDITOS_FINAL_OFV_FIJA
		WHERE FECHA_PUBLI IS NOT NULL
		AND PERIODO = iperiod;
	else 
		if (v_cuenta > 1) then
			v_fecha_fija:= to_date('01/01/2200','DD/MM/YYYY');
		else
			w_debug('La fecha FIJA es nula. No hay datos de ese periodo ==> ' || v_cuenta , v_contador_debug);
			v_fecha_fija:= null;
		end if;
	end if;
	w_debug('FIN consulta fecha FIJA tabla ENEL_CREDITOS_FINAL_FIJA. ==> ' || v_fecha_fija , v_contador_debug);
		
	w_debug('Compara fecha FIJA ==> ' || v_fecha_fija || ' fecha PUBLI ==> ' || v_fecha_publi, v_contador_debug);
	
	-- MPR -- si la fecha de publicacion es diferente se carga la tabla fija
	if (v_fecha_publi <> v_fecha_fija or v_fecha_fija is null) then
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
		
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';
		
		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
				from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid='OFV Visitas'
				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate =V_EOT
					and cspa.tenantId = itenantId
					and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspo.tenantId = itenantId
					and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
				WHERE 
					to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
					and cspo.name like 'a4%'
		);
		filas := sql%rowcount;
		
		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);
		
		w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_OFV_FIJA.', v_contador_debug);		
		DELETE FROM ENEL_CREDITOS_FINAL_OFV_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);
		
		filas := sql%rowcount;
				 
		w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_OFV_FIJA.' || to_char(filas) || ' filas.' , v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_OFV_FIJA. Borrado de meses.' , v_contador_debug);
		
		DELETE FROM ENEL_CREDITOS_FINAL_OFV_FIJA WHERE PERIODSEQ >= iperiodseq;
		filas := sql%rowcount;
		
		w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_OFV_FIJA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_OFV_FIJA.' ,  v_contador_debug);
		
		v_cabecera := f_ComprobarCabecera(itenantId);
	  
		/* Cuando la posicion no esta versionada */
		INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_OFV_FIJA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VALUE,TIPO_USUARIO,tipo_motivo,estado,line,ischild, 
													ACOMPANIANTE, FECHA_REALIZACION, FECHA_MARCADO, VISITA_AMBITO, NOMBRE_CUENTA, CIF, TIPO, NOMBRE, NOMBRE_PARTICIPANTE,PAYEESEQ, 
													POSITIONSEQ, FOBJETIVO, COMPENSATIONDATE, FECHA_PUBLI, NAME)
		Select
			TXN.TENANTID,
			TXN.PERIODSEQ,
			TXN.PERIODO,
			to_char(cspe.startdate,'YYYY'),
			txn.orderid,
			cspa.userid,
			cspo.name,
			cred.value,
			CRED.GENERICnumber4, -- tipo usuario
			cred.genericattribute13, --tipo_motivo
			'Pte Enviar',
			txn.linenumber,
			case 
				when cred.genericboolean1=1 then 'SI'
				when cred.genericboolean1=0 then 'NO'
			end as ischild,
			-- MPR nuevos campos informe
			cred.genericattribute7 as acompaniante,
			cred.genericdate1 as fecha_realizacion,
			cred.genericdate3 as fecha_marcado,
			case 
				when cred.genericboolean2=1 then 'SI'
				when cred.genericboolean2=0 then 'NO'
			end as visita_ambito,
			cred.genericattribute16 as nombre_cuenta,
			txn.genericattribute29 as cif, 
			cred.genericattribute3 as tipo,
			cred.genericattribute4 as nombre,
			cspa.lastname as nombre_participante,
			-- MPR nuevos campos para cruzar informe con permisos usuario
			cred.PAYEESEQ,
			cred.POSITIONSEQ,
			CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
			cred.COMPENSATIONDATE as fecha_liquidacion, 
			cred.genericdate2 as fecha_publi,
			cred.name

		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid='OFV Visitas'
			
			inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
			
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate =V_EOT
				and cspa.tenantId = itenantId
				and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
			
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspo.tenantId = itenantId
				and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--AND CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE 
			to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
			and cspo.name like 'a4%';

		filas := sql%rowcount;
		COMMIT;

		w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_OFV_FIJA: '|| to_char(filas) || ' filas.', v_contador_debug);

		EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDITOS_FINAL_OFV_FIJA COMPUTE STATISTICS FOR ALL INDEXES';
		w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_OFV_FIJA',v_contador_debug);
		
		-- Actualizamos la fecha del informes en la tabla 
        if (filas > 0) then
            p_Actualiza_Informe_Fecha ( iperiod, 'OFV_FIJA_VISITAS');
        end if;
    end if;
	
	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';
	
	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid='OFV Visitas'
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate =V_EOT
				and cspa.tenantId = itenantId
				and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspo.tenantId = itenantId
				and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
		WHERE 
			to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
			and cspo.name like 'a4%'
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);
	
	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_OFV.', v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_OFV 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);
	
	filas := sql%rowcount;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_OFV.' || to_char(filas) || ' filas.' , v_contador_debug);

    w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_OFV. Borrado de meses.' , v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_OFV WHERE PERIODSEQ >= iperiodseq;
	filas := sql%rowcount;
    
    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_OFV. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_OFV.' ,  v_contador_debug);
    
    v_cabecera := f_ComprobarCabecera(itenantId);
  
	/* Cuando la posicion no esta versionada */
    INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_OFV(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VALUE,TIPO_USUARIO,tipo_motivo,estado,line,ischild, 
												ACOMPANIANTE, FECHA_REALIZACION, FECHA_MARCADO, VISITA_AMBITO, NOMBRE_CUENTA, CIF, TIPO, NOMBRE, NOMBRE_PARTICIPANTE,PAYEESEQ, 
												POSITIONSEQ, FOBJETIVO, COMPENSATIONDATE, FECHA_PUBLI, NAME)
	Select
		TXN.TENANTID,
		TXN.PERIODSEQ,
		TXN.PERIODO,
		to_char(cspe.startdate,'YYYY'),
		txn.orderid,
		cspa.userid,
		cspo.name,
		cred.value,
		CRED.GENERICnumber4, -- tipo usuario
		cred.genericattribute13, --tipo_motivo
		'Pte Enviar',
		txn.linenumber,
		case 
			when cred.genericboolean1=1 then 'SI'
			when cred.genericboolean1=0 then 'NO'
		end as ischild,
		-- MPR nuevos campos informe
		cred.genericattribute7 as acompaniante,
		cred.genericdate1 as fecha_realizacion,
		cred.genericdate3 as fecha_marcado,
		case 
			when cred.genericboolean2=1 then 'SI'
			when cred.genericboolean2=0 then 'NO'
		end as visita_ambito,
		cred.genericattribute16 as nombre_cuenta,
		txn.genericattribute29 as cif, 
		cred.genericattribute3 as tipo,
		cred.genericattribute4 as nombre,
		cspa.lastname as nombre_participante,
		-- MPR nuevos campos para cruzar informe con permisos usuario
        cred.PAYEESEQ,
        cred.POSITIONSEQ,
		CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
		cred.COMPENSATIONDATE as fecha_liquidacion,
		cred.genericdate2 as fecha_publi,
		cred.name

	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid='OFV Visitas'
		
		inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
		
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate =V_EOT
			and cspa.tenantId = itenantId
			and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
		
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspo.tenantId = itenantId
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--AND CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT GROUP BY NAME HAVING COUNT(*) < 2)

	WHERE 
		to_char(cspe.startdate,'YYYY')=(select to_char(startdate,'YYYY') from cs_period where periodseq=iperiodseq and removedate= v_eot and tenantId = itenantId)
		and cspo.name like 'a4%'
		--and 0 = (select count(*) from ENEL_CREDITOS_FINAL_OFV where orderid=txn.orderid and participantid=cspa.userid and idficha=cspo.name and line=txn.linenumber and to_number(value)=cred.value)
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDITOS_FINAL_OFV COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_OFV',v_contador_debug);
end;    

-- aniadimos la funcion que rellena la cabecera en el caso de que no exista. 
function f_ComprobarCabeceraPSVA(itenantId IN VARCHAR2, iperiodseq IN VARCHAR2) return boolean as   
    v_chequeadaCabecera BOOLEAN;
    cabecera integer;
begin
	select count(*) into cabecera from ENELEXT.ENEL_CREDITOS_FINAL_PSVA where periodseq is null and PORC_SPLIT like 'PORC_SPLIT';
	
	if (cabecera > 1) then
		DELETE FROM ENELEXT.ENEL_CREDITOS_FINAL_PSVA WHERE  periodseq is null and  ROWNUM < cabecera;
		-- Actualizamos el estado de la unica cabecera que dejamos
		UPDATE ENELEXT.ENEL_CREDITOS_FINAL_PSVA SET estado = null WHERE  periodseq is null and PORC_SPLIT like 'PORC_SPLIT';
		v_chequeadaCabecera := true;
	else 
		if (cabecera = 1) then
			UPDATE ENELEXT.ENEL_CREDITOS_FINAL_PSVA SET estado = null WHERE  periodseq is null and PORC_SPLIT like 'PORC_SPLIT';
			v_chequeadaCabecera := true;
		else
			INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_PSVA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VALUE,TIPO_MOTIVO,PORC_SPLIT)
			VALUES (
				'ENEL',
				NULL,
				null,
				(select to_char(startdate,'YYYY')
					from cs_period
					where periodseq=iperiodseq
					and removedate= v_eot),
				'ID_OPORTUNIDAD','USUARIO','FICHA','VALOR','TIPO_DE_MOTIVO','PORC_SPLIT');
			v_chequeadaCabecera := false;
		end if;
	end if;
	
	commit;
	return v_chequeadaCabecera;  
end;

procedure p_Creditos_Final_psva ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2)
AS
	v_cabecera boolean;
	v_fecha_publi date;
	v_fecha_fija date;
	v_cuenta integer;
begin	
	w_debug('Inicio consulta fecha PUBLI tabla ENEL_CREDITOS_FINAL_PSVA', v_contador_debug);

	select count(distinct cred.genericdate2) into v_cuenta
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid='OFV Oportunidades Ganadas'
			
		inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
			
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate =V_EOT
			and cspa.tenantId = itenantId
			and cspe.startdate +1 between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.payeeseq not like '4503599627373822'
			
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspo.tenantId = itenantId
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
			and cspo.ruleelementownerseq not like '4785074604087002'
	where
/* BOM FF1 DCR 10.03.22 */
        cred.periodseq = iperiodseq AND
/* BOM FF1 DCR 10.03.22  */
		cred.genericdate2 is not null;
	
	w_debug('Cuenta fecha PUBLI tabla ENEL_CREDITOS_FINAL_PSVA ==> ' || v_cuenta , v_contador_debug);
	
	if (v_cuenta = 1) then 
		-- se hace la comprobacion para cargar la tabla fija en el caso de que sea necesario, solo cuando la fecha de publicacion del credito, GD2, cambie.
		select distinct cred.genericdate2 into v_fecha_publi
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid='OFV Oportunidades Ganadas'
				
			inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
				
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate =V_EOT
				and cspa.tenantId = itenantId
				and cspe.startdate +1 between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.payeeseq not like '4503599627373822'
				
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspo.tenantId = itenantId
				and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
				and cspo.ruleelementownerseq not like '4785074604087002'
		where
 /* BOM FF1 DCR 10.03.22 */
            cred.periodseq = iperiodseq AND
/* BOM FF1 DCR 10.03.22  */
			cred.genericdate2 is not null;
	else 
		if (v_cuenta > 1) then
			w_debug('Cuenta fecha PUBLI tabla ENEL_CREDITOS_FINAL_PSVA OJO!! Más de una', v_contador_debug);
			
			select max(cred.genericdate2) into v_fecha_publi
				from enel_credit_temp_ofv cred
					inner join enel_txn_temp_ofv txn
						on txn.salestransactionseq = cred.salestransactionseq
						and txn.tenantid = cred.tenantid
						and txn.periodseq = cred.periodseq
						and txn.eventypeid='OFV Oportunidades Ganadas'
						
					inner join cs_period cspe
							on cred.periodseq=cspe.periodseq
							and cspe.removedate = V_EOT
							and cspe.tenantId = itenantId
						
					inner join cs_participant cspa 
						on cred.payeeseq=cspa.payeeseq
						and cspa.removedate =V_EOT
						and cspa.tenantId = itenantId
						and cspe.startdate +1 between cspa.effectivestartdate and cspa.effectiveenddate
						and cspa.payeeseq not like '4503599627373822'
						
					inner join cs_position cspo
						on cred.positionseq=cspo.ruleelementownerseq
						and cspo.removedate = V_EOT
						and cspo.tenantId = itenantId
						and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
						and cspo.ruleelementownerseq not like '4785074604087002'
				where
 /* BOM FF1 DCR 10.03.22 */
                    cred.periodseq = iperiodseq AND
/* BOM FF1 DCR 10.03.22  */
					cred.genericdate2 is not null;
		else
/* BOM FF1 DCR 10.03.22 */
-- No deberia hacerse foto fija, ya que no hay datos para ese mes. 
-- Old code
/*            v_fecha_publi:= to_date('01/01/2200','DD/MM/YYYY');*/
-- New code
            v_fecha_publi:= null;
            w_debug('No hay datos para el mes de lanzamiento. No es necesario realizar FOTO FIJA' , v_contador_debug);
/* EOM FF1 DCR 10.03.22  */   
		end if;
	end if;

	w_debug('FIN consulta fecha PUBLI tabla ENEL_CREDITOS_FINAL_PSVA ==> ' || v_fecha_publi , v_contador_debug);

/* BOM FF1 DCR 10.03.22 */
    if(v_fecha_publi is not null) then 
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio consulta fecha FIJA tabla ENEL_CREDITOS_FINAL_PSVA_FIJA.', v_contador_debug);
	
	SELECT count(distinct FECHA_PUBLI) INTO v_cuenta
	FROM ENELEXT.ENEL_CREDITOS_FINAL_PSVA_FIJA
	WHERE FECHA_PUBLI IS NOT NULL
	AND PERIODO = iperiod;
	
	w_debug('Cuenta fecha FIJA tabla ENEL_CREDITOS_FINAL_PSVA_FIJA. ==> ' || v_cuenta , v_contador_debug);
	
	if(v_cuenta = 1) then 
		SELECT DISTINCT FECHA_PUBLI INTO v_fecha_fija
		FROM ENELEXT.ENEL_CREDITOS_FINAL_PSVA_FIJA
		WHERE FECHA_PUBLI IS NOT NULL
        AND PERIODO = iperiod;
	else 
		if (v_cuenta > 1) then
			v_fecha_fija:= to_date('01/01/2200','DD/MM/YYYY');
		else
			w_debug('La fecha FIJA es nula. No hay datos de ese periodo ==> ' || v_cuenta , v_contador_debug);
			v_fecha_fija:= null;
		end if;
	end if;
	
	w_debug('FIN consulta fecha FIJA tabla ENEL_CREDITOS_FINAL_PSVA_FIJA. ==> ' || v_fecha_fija , v_contador_debug);

	w_debug('Compara fecha FIJA ==> ' || v_fecha_fija || ' fecha PUBLI ==> ' || v_fecha_publi, v_contador_debug);
	
	-- MPR -- si la fecha de publicacion es diferente se carga la tabla fija
/* BOM FF1 DCR 10.03.22 
Old code */
--    if (v_fecha_publi <> v_fecha_fija or v_fecha_fija is null) then
--New code
    if (v_fecha_publi > v_fecha_fija or v_fecha_fija is null) then
/* EOM FF1 DCR 10.03.22  */
		
/* BOM FF1 DCR 10.03.22 
Old code 
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
		
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';
		
		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from enel_credit_temp_ofv cred
				inner join ENEL_TXN_TEMP_OFV txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid='OFV Oportunidades Ganadas'
				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate =V_EOT
					and cspa.tenantId = itenantId
					and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
					and cspa.payeeseq not like '4503599627373822'
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspo.tenantId = itenantId
					and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
					and cspo.ruleelementownerseq not like '4785074604087002'
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);
		
		w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDITOS_FINAL_PSVA_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA.' || to_char(filas) || ' filas.' , v_contador_debug);
	
		w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA. Borrado de meses.' , v_contador_debug);
    
		DELETE FROM ENEL_CREDITOS_FINAL_PSVA_FIJA WHERE PERIODSEQ >= iperiodseq;
		filas := sql%rowcount;
    
		w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
		
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';
		
		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from ENEL_TXN_TEMP_OFV txn
				inner join cs_period cspe
					on txn.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
			where txn.eventypeid='OFV Oportunidades Ganadas'
				and txn.tenantid = itenantId
				and txn.genericattribute3 = 'Ganada' 
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);
		
		w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA por estado = Ganada.', v_contador_debug);
    
		DELETE FROM ENEL_CREDITOS_FINAL_PSVA_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA estado = Ganada.' || to_char(filas) || ' filas.', v_contador_debug);
    
		w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_PSVA_FIJA.' ,  v_contador_debug);
    
		v_cabecera := f_ComprobarCabeceraPSVA(itenantId, iperiodseq);

-- New code */
        w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDITOS_FINAL_PSVA_FIJA 
		WHERE anio = (SELECT to_char(startdate,'YYYY') FROM cs_period WHERE periodseq = iperiodseq AND removedate = '01/01/2200');

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);
/* EOM FF1 DCR 10.03.22  */

		/* Cuando la posicion no esta versionada */
		INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_PSVA_FIJA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VALUE,tipo_motivo,estado,line,PORC_SPLIT,
														ID_OPORTUNIDAD, NOMBRE_CUENTA, CIF, ETAPA, PERIODO_LIQ, MARGEN, MOTIVO, PAYEESEQ, POSITIONSEQ, NOMBRE_PARTICIPANTE, 
														NOMBRE_OPORTUNIDAD, COD_OPORTUNIDAD, TIPO_PRODUCTO, PAGO, SPLIT, RESPONSABLE, 
														FOBJETIVO, COMPENSATIONDATE, FECHA_PUBLI, NAME, CONTABILIZACION_VENTA)
       
		Select
			TXN.TENANTID,
			TXN.PERIODSEQ,
			TXN.PERIODO,
			to_char(cspe.startdate,'YYYY'),
			txn.orderid,
			cspa.userid,
			cspo.name,
			replace(TRIM(to_char(cred.value, '9999999999990D99')), ',', '.'),
			CRED.GENERICATTRIBUTE15,
			'Pte Enviar',
			txn.linenumber,
			CRED.GENERICNUMBER3*100,
			-- MPR nuevos campos para informe
			cred.genericattribute9 as id_oportunidad,
			cred.genericattribute16 as nombre_cuenta,
			txn.genericattribute29 as cif,
			cred.genericattribute1 as etapa,
			cred.genericdate1 as periodo_liq,
			cred.genericnumber5 as margen, --el number real es el GN5 de la tabla de sistemas
			cred.genericattribute13 as motivo,
			-- MPR nuevos campos para cruzar informe con permisos usuario
			cred.PAYEESEQ,
			cred.POSITIONSEQ,
			--cspa.lastname 
			case 
				when cred.name like 'CP - %' then cred.genericattribute10
				else CSPA.LASTNAME
			end as nombre_participante,
			cred.genericattribute3 as nombre_oportunidad,
			cred.genericattribute6 as cod_oportunidad,
			cred.genericattribute8 as tipo_producto,
			cred.genericattribute12 as pago,
			cred.genericnumber3 as split, --ojo el number real de la tabla de sistema es el GN3
			case 
				when cred.name like 'CD - %' then cred.genericattribute10
				else CSPA.LASTNAME
			end as responsable,
			CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
			CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
			cred.genericdate2 as fecha_publi,
			cred.name,
            CRED.GENERICNUMBER6 AS CONTABILIZACION_VENTA

            
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid='OFV Oportunidades Ganadas'
			
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
		
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate =V_EOT
				and cspa.tenantId = itenantId
				and cspe.startdate +1 between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.payeeseq not like '4503599627373822'
		
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspo.tenantId = itenantId
				and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
				and cspo.ruleelementownerseq not like '4785074604087002'
				-- ya no hace falta implementar el filtro de versionado
                --AND CSPO.NAME NOT IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE LIKE V_EOT GROUP BY NAME HAVING COUNT(*) >= 2 )
		
        WHERE cred.genericboolean1 = 1 
        /* BOM - RMM - 31.01.2023 - Excluimos de esta tabla los leads, ya que no deben aparecen en los informes que no son de leads*/
        AND cred.genericattribute9  NOT LIKE '%numero de leads AAPP%' --  id_oportunidad
        /* EOM - RMM - 31.01.2023 */
        ;
	
		filas := sql%rowcount;
		COMMIT;

		w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_PSVA_FIJA: '|| to_char(filas) || ' filas.', v_contador_debug);

		EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDITOS_FINAL_PSVA_FIJA COMPUTE STATISTICS FOR ALL INDEXES';
		w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_PSVA_FIJA',v_contador_debug);
		
		-- Actualizamos la fecha del informes en la tabla 
        if (filas > 0) then
            p_Actualiza_Informe_Fecha ( iperiod, 'OFV_FIJA_PSVAS');
        end if;
	end if;

/* BOM FF1 DCR 10.03.22 */
    end if;
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
	
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';
		
	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from enel_credit_temp_ofv cred
			inner join ENEL_TXN_TEMP_OFV txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid='OFV Oportunidades Ganadas'
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate =V_EOT
				and cspa.tenantId = itenantId
				and cspe.startdate between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.payeeseq not like '4503599627373822'
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspo.tenantId = itenantId
				and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
				and cspo.ruleelementownerseq not like '4785074604087002'
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

    w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA.', v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_PSVA 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA.' || to_char(filas) || ' filas.' , v_contador_debug);
	
	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA. Borrado de meses.' , v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_PSVA WHERE PERIODSEQ >= iperiodseq;
	filas := sql%rowcount;
    
    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
	
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from ENEL_TXN_TEMP_OFV txn
			inner join cs_period cspe
				on txn.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
		where txn.eventypeid='OFV Oportunidades Ganadas'
			and txn.tenantid = itenantId
			and txn.genericattribute3 = 'Ganada' 
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA por estado = Ganada.', v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_PSVA 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_PSVA estado = Ganada.' || to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_PSVA.' ,  v_contador_debug);
    
    v_cabecera := f_ComprobarCabeceraPSVA(itenantId, iperiodseq);
    
	/* Cuando la posicion no esta versionada */
    INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_PSVA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VALUE,tipo_motivo,estado,line,PORC_SPLIT,
												ID_OPORTUNIDAD, NOMBRE_CUENTA, CIF, ETAPA, PERIODO_LIQ, MARGEN, MOTIVO, PAYEESEQ, POSITIONSEQ, NOMBRE_PARTICIPANTE, 
												NOMBRE_OPORTUNIDAD, COD_OPORTUNIDAD, TIPO_PRODUCTO, PAGO, SPLIT, RESPONSABLE, FOBJETIVO, COMPENSATIONDATE, FECHA_PUBLI, NAME, CONTABILIZACION_VENTA )
	Select
		TXN.TENANTID,
		TXN.PERIODSEQ,
		TXN.PERIODO,
		to_char(cspe.startdate,'YYYY'),
		txn.orderid,
		cspa.userid,
		cspo.name,
		replace(TRIM(to_char(cred.value, '9999999999990D99')), ',', '.'),
		CRED.GENERICATTRIBUTE15,
		'Pte Enviar',
		txn.linenumber,
		CRED.GENERICNUMBER3*100,
		-- MPR nuevos campos para informe
		cred.genericattribute9 as id_oportunidad,
		cred.genericattribute16 as nombre_cuenta,
		txn.genericattribute29 as cif,
		cred.genericattribute1 as etapa,
		cred.genericdate1 as periodo_liq,
		cred.genericnumber5 as margen,
		cred.genericattribute13 as motivo,
		-- MPR nuevos campos para cruzar informe con permisos usuario
        cred.PAYEESEQ,
        cred.POSITIONSEQ,
		--cspa.lastname 
		case 
            when cred.name like 'CP - %' then cred.genericattribute10
            else CSPA.LASTNAME
        end as nombre_participante,
		cred.genericattribute3 as nombre_oportunidad,
		cred.genericattribute6 as cod_oportunidad,
		cred.genericattribute8 as tipo_producto,
		cred.genericattribute12 as pago,
		cred.genericnumber3 as split,
		case 
            when cred.name like 'CD - %' then cred.genericattribute10
            else CSPA.LASTNAME
        end as responsable,
		CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
		CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
		cred.genericdate2 as fecha_publi,
		cred.name,
        CRED.GENERICNUMBER6 AS CONTABILIZACION_VENTA

	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid='OFV Oportunidades Ganadas'

		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantId = itenantId

		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate =V_EOT
			and cspa.tenantId = itenantId
			and cspe.startdate +1 between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.payeeseq not like '4503599627373822'

		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspo.tenantId = itenantId
			and cspe.startdate +1 between cspo.effectivestartdate and cspo.effectiveenddate	
			and cspo.ruleelementownerseq not like '4785074604087002'
			-- ya no hace falta implementar el filtro de versionado
			--AND CSPO.NAME NOT IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE LIKE V_EOT GROUP BY NAME HAVING COUNT(*) >= 2 );
      WHERE cred.genericboolean1 = 1
        /* BOM - RMM - 31.01.2023 - Excluimos de esta tabla los leads, ya que no deben aparecen en los informes que no son de leads*/
        AND cred.genericattribute9  NOT LIKE '%numero de leads AAPP%' --  id_oportunidad
        /* EOM - RMM - 31.01.2023 */
    ;
	
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_PSVA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDITOS_FINAL_PSVA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_PSVA',v_contador_debug);
end;

function f_ComprobarCabeceraVolumen(itenantId IN VARCHAR2, iperiodseq IN VARCHAR2) return boolean as   
    v_chequeadaCabecera BOOLEAN;
    cabecera integer;
    begin
        select count(*) into cabecera from ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN where periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';

        if (cabecera > 1) then
            DELETE FROM ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN WHERE  periodseq is null and  ROWNUM < cabecera;
            -- Actualizamos el estado de la unica cabecera que dejamos
            UPDATE ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN SET estado = null WHERE  periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';
            v_chequeadaCabecera := true;
        else 
            if (cabecera = 1) then
                UPDATE ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN SET estado = null WHERE  periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';
                v_chequeadaCabecera := true;
            else
                INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA)
                VALUES ('ENEL',NULL,null,(select to_char(startdate,'YYYY')
                                          from cs_period
                                          where periodseq=iperiodseq
                                          and removedate= v_eot),'ID_CONTRATO','ID_USUARIO','ID_FICHA','VOLUMEN_REAL','VOLUMEN_CONTABILIZA','TIPO','CONSUMO_CONTABILIZA','ENERGIA_COMPROMETIDA');
                v_chequeadaCabecera := false;
            end if;
        end if;
    commit;
    return v_chequeadaCabecera;  
    
end;

function f_ComprobarCabeceraVolGas(itenantId IN VARCHAR2, iperiodseq IN VARCHAR2) return boolean as   
    v_chequeadaCabecera BOOLEAN;
    cabecera integer;
    begin
        select count(*) into cabecera from ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS where periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';

        if (cabecera > 1) then
            DELETE FROM ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS WHERE  periodseq is null and  ROWNUM < cabecera;
            -- Actualizamos el estado de la unica cabecera que dejamos
            UPDATE ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS SET estado = null WHERE  periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';
            v_chequeadaCabecera := true;
        else 
            if (cabecera = 1) then
                UPDATE ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS SET estado = null WHERE  periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';
                v_chequeadaCabecera := true;
            else
                INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA)
                VALUES ('ENEL',NULL,null,(select to_char(startdate,'YYYY')
                                          from cs_period
                                          where periodseq=iperiodseq
                                          and removedate= v_eot),'ID_CONTRATO','ID_USUARIO','ID_FICHA','VOLUMEN_REAL','VOLUMEN_CONTABILIZA','TIPO','CONSUMO_CONTABILIZA','ENERGIA_COMPROMETIDA');
                v_chequeadaCabecera := false;
            end if;
        end if;
    commit;
    return v_chequeadaCabecera;  
    
end;

function f_ComprobarCabeceraVRenta(itenantId IN VARCHAR2, iperiodseq IN VARCHAR2) return boolean as   
    v_chequeadaCabecera BOOLEAN;
    cabecera integer;
    begin
        select count(*) into cabecera from ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA where periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';

        if (cabecera > 1) then
            DELETE FROM ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA WHERE  periodseq is null and  ROWNUM < cabecera;
            -- Actualizamos el estado de la unica cabecera que dejamos
            UPDATE ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA SET estado = null WHERE  periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';
            v_chequeadaCabecera := true;
        else 
            if (cabecera = 1) then
                UPDATE ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA SET estado = null WHERE  periodseq is null and ENERGIA_COMPROMETIDA like 'ENERGIA_COMPROMETIDA';
                v_chequeadaCabecera := true;
            else
                INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA)
                VALUES ('ENEL',NULL,null,(select to_char(startdate,'YYYY')
                                          from cs_period
                                          where periodseq=iperiodseq
                                          and removedate= v_eot),'ID_CONTRATO','ID_USUARIO','ID_FICHA','VOLUMEN_REAL','VOLUMEN_CONTABILIZA','TIPO','CONSUMO_CONTABILIZA','ENERGIA_COMPROMETIDA');
                v_chequeadaCabecera := false;
            end if;
        end if;
    commit;
    return v_chequeadaCabecera;  
    
end;

procedure p_Creditos_Final_Volumen ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2)
AS
	v_cabecera boolean;
	v_fecha_publi date;
	v_fecha_fija date;
	v_cuenta integer;
begin	
	w_debug('Inicio consulta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL', v_contador_debug);

	select count(distinct cred.genericdate1) into v_cuenta
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid = 'OFV Volumen'
			AND TXN.SUBLINENUMBER = 1 --electrico
			and txn.processingunitseq = 38280596832649418
           
		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantid = itenantId
				
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = V_EOT
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'

		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE 
        (cred.name like 'CD - OFV - Electricidad Activa Cierre - %' or cred.name like 'CP - OFV - Electricidad Activa Cierre - %' or  
         cred.name like 'CD - OFV - Cartera Activa Electricidad - %' or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'or 
         cred.name like 'CD - OFV - Cartera Electricidad - Empresas %' or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %' or 
         cred.name like 'CD - OFV - Volumen El%ctrico Negociado %' or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %' or 
         cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %' or 
         cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %')
 /* BOM FF1 DCR 10.03.22 */
        AND cred.periodseq = iperiodseq
/* BOM FF1 DCR 10.03.22  */
        and cred.genericdate1 is not null;	
	
	w_debug('Cuenta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL ==> ' || v_cuenta , v_contador_debug);
	
	if (v_cuenta = 1) then 
		-- se hace la comprobacion para cargar la tabla fija en el caso de que sea necesario, solo cuando la fecha de publicacion del credito, GD2, cambie.
		select distinct cred.genericdate1 into v_fecha_publi
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 1 --electrico
				and txn.processingunitseq = 38280596832649418

			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId

			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'

			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE 
			(cred.name like 'CD - OFV - Electricidad Activa Cierre - %' or cred.name like 'CP - OFV - Electricidad Activa Cierre - %' or  
             cred.name like 'CD - OFV - Cartera Activa Electricidad - %' or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'or 
             cred.name like 'CD - OFV - Cartera Electricidad - Empresas %' or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %' or 
             cred.name like 'CD - OFV - Volumen El%ctrico Negociado %' or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %' or 
             cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %' or 
             cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %')
/* BOM FF1 DCR 10.03.22 */
            AND cred.periodseq = iperiodseq
/* EOM FF1 DCR 10.03.22  */
            and cred.genericdate1 is not null;	
	else 
		if (v_cuenta > 1) then
			w_debug('Cuenta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL OJO!! Más de una', v_contador_debug);

			select max(cred.genericdate1) into v_fecha_publi
				from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid = 'OFV Volumen'
					AND TXN.SUBLINENUMBER = 1 --electrico
					and txn.processingunitseq = 38280596832649418

				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantid = itenantId

				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate = V_EOT
					and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
					and cspa.tenantid = itenantId
					and cspa.payeeseq <> '4503599627373822'
					
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
					and cspo.tenantid = itenantId
					and cspo.ruleelementownerseq <> '4785074604087002'
					-- MPR se comenta y se controla duplicidad por fecha startdate.
					--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
			WHERE 
				(cred.name like 'CD - OFV - Electricidad Activa Cierre - %' or cred.name like 'CP - OFV - Electricidad Activa Cierre - %' or  
                 cred.name like 'CD - OFV - Cartera Activa Electricidad - %' or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'or 
                 cred.name like 'CD - OFV - Cartera Electricidad - Empresas %' or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %' or 
                 cred.name like 'CD - OFV - Volumen El%ctrico Negociado %' or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %' or 
                 cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %' or 
                 cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %')
/* BOM FF1 DCR 10.03.22 */
                AND cred.periodseq = iperiodseq
/* EOM FF1 DCR 10.03.22  */
                and cred.genericdate1 is not null;	
		else
/* BOM FF1 DCR 10.03.22 */
-- No deberia hacerse foto fija, ya que no hay datos para ese mes. 
-- Old code
/*            v_fecha_publi:= to_date('01/01/2200','DD/MM/YYYY');*/
-- New code
            v_fecha_publi:= null;
            w_debug('No hay datos para el mes de lanzamiento. No es necesario realizar FOTO FIJA' , v_contador_debug);
/* EOM FF1 DCR 10.03.22  */    
		end if;
	end if;

	w_debug('FIN consulta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL ==> ' || v_fecha_publi , v_contador_debug);

/* BOM FF1 DCR 10.03.22 */
    if(v_fecha_publi is not null) then 
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio consulta fecha FIJA tabla ENEL_CREDIT_FINAL_VOL_FIJA.', v_contador_debug);

	SELECT count(distinct FECHA_PUBLI) INTO v_cuenta
	FROM ENELEXT.ENEL_CREDIT_FINAL_VOL_FIJA
	WHERE FECHA_PUBLI IS NOT NULL
	AND PERIODO = iperiod;

	w_debug('Cuenta fecha FIJA tabla ENEL_CREDIT_FINAL_VOL_FIJA. ==> ' || v_cuenta , v_contador_debug);

	if(v_cuenta = 1) then 
		SELECT DISTINCT FECHA_PUBLI INTO v_fecha_fija
		FROM ENELEXT.ENEL_CREDIT_FINAL_VOL_FIJA
		WHERE FECHA_PUBLI IS NOT NULL
    	AND PERIODO = iperiod;
	else 
		if (v_cuenta > 1) then
			v_fecha_fija:= to_date('01/01/2200','DD/MM/YYYY');
		else
			w_debug('La fecha FIJA es nula. No hay datos de ese periodo ==> ' || v_cuenta , v_contador_debug);
			v_fecha_fija:= null;
		end if;
	end if;

	w_debug('FIN consulta fecha FIJA tabla ENEL_CREDIT_FINAL_VOL_FIJA. ==> ' || v_fecha_fija , v_contador_debug);

	w_debug('Compara fecha FIJA ==> ' || v_fecha_fija || ' fecha PUBLI ==> ' || v_fecha_publi, v_contador_debug);

	-- MPR -- si la fecha de publicacion es diferente se carga la tabla fija
/* BOM FF1 DCR 10.03.22 
Old code */
--    if (v_fecha_publi <> v_fecha_fija or v_fecha_fija is null) then
--New code
   if (v_fecha_publi > v_fecha_fija or v_fecha_fija is null) then 
/* EOM FF1 DCR 10.03.22  */
		
/* BOM FF1 DCR 10.03.22 
Old code 
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
        EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid = 'OFV Volumen'
					AND TXN.SUBLINENUMBER = 1 --electrico
					and txn.processingunitseq = 38280596832649418	
				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantid = itenantId
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate = V_EOT
					and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
					and cspa.tenantid = itenantId
					and cspa.payeeseq <> '4503599627373822'
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
					and cspo.tenantid = itenantId
					and cspo.ruleelementownerseq <> '4785074604087002'
					-- MPR se comenta y se controla duplicidad por fecha startdate.
					--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
			WHERE (cred.name like 'CD - OFV - Electricidad Activa Cierre - %' or cred.name like 'CP - OFV - Electricidad Activa Cierre - %' or  
                     cred.name like 'CD - OFV - Cartera Activa Electricidad - %' or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'or 
                     cred.name like 'CD - OFV - Cartera Electricidad - Empresas %' or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %' or 
                     cred.name like 'CD - OFV - Volumen El%ctrico Negociado %' or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %' or 
                     cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %' or 
                     cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %')
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDIT_FINAL_VOL_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA. Borrado de meses.' , v_contador_debug);
		
		DELETE FROM ENEL_CREDIT_FINAL_VOL_FIJA WHERE PERIODSEQ >= iperiodseq;
		filas := sql%rowcount;
		
		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
	
		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from ENEL_TXN_TEMP_OFV txn
				inner join cs_period cspe
					on txn.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
			where txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 1 --electrico
				and txn.tenantid = itenantId
				and (txn.genericattribute3 = 'EN VIGOR' or txn.genericattribute3 = 'VERSION A FUTURO - ENVIADA' )
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);
		
		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA estados.', v_contador_debug);	
		
		DELETE FROM ENEL_CREDIT_FINAL_VOL_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);
			
		filas := sql%rowcount;
				 
		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA estados.' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Insertando datos en tabla ENEL_CREDIT_FINAL_VOL_FIJA.' ,  v_contador_debug);
		
		v_cabecera := f_ComprobarCabeceraVolumen(itenantId, iperiodseq);

-- New code */
        w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDIT_FINAL_VOL_FIJA 
		WHERE anio = (SELECT to_char(startdate,'YYYY') FROM cs_period WHERE periodseq = iperiodseq AND removedate = '01/01/2200');

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);
/* EOM FF1 DCR 10.03.22  */
		/* Cuando la posicion no esta versionada */
		INSERT INTO ENELEXT.ENEL_CREDIT_FINAL_VOL_FIJA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA,
													estado,line, SUBLINENUMBER, NUM_CONTRATO, NOMBRE_PARTICIPANTE, ESTADO2, RAZON_SOCIAL, CIF, CUPS, CONSUMO_ESTIMADO, 
													CONSUMO_OBJETIVADO, PRESION, CANAL_ENTRADA, TARIFA, TIPO_PRODUCTO, TIPO_CONTRATO, LINEA_NEGOCIO, PAYEESEQ, POSITIONSEQ, VERSION,
													FECHA_ALTA, FECHA_BAJA, FECHA_CONTRATO,FECHA_INI_VERSION, FECHA_FIN_VERSION, RESPONSABLE, FOBJETIVO, COMPENSATIONDATE,
													FECHA_PUBLI, NAME, TIPO_POSICION, TIPO_PRESTADOR, GRP_EMP, DURAC_CONTR, F_REC_CONTR, FRCC 
                                                    , F_CIERRE, F_INI_LOTE  --RMM 19.10.2022 incluimos las nuevas fechas
                                                    )
		Select
			TXN.TENANTID,
			TXN.PERIODSEQ,
			TXN.PERIODO,
			to_char(cspe.startdate,'YYYY'),
			txn.orderid,
			cspa.userid,
			cspo.name,
			CASE 
				WHEN ROUND(cred.GENERICNUMBER5, 6) > 0 AND ROUND(cred.GENERICNUMBER5, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
				ELSE TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
			END,
			CASE 
				WHEN ROUND(cred.VALUE, 6) > 0 AND ROUND(cred.VALUE, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.VALUE, 6))
				ELSE TO_CHAR(ROUND(cred.VALUE, 6))
			END,
			CRED.GENERICATTRIBUTE3, --TIPO
			CRED.GENERICATTRIBUTE15, --CONTABILIZA
			CRED.GENERICATTRIBUTE13, --ENERGIA_COMPROMETIDA
			'Pte Enviar', --estado
			txn.linenumber, --line
			
			-- MPR - nuevos campos para informe
			TXN.SUBLINENUMBER, --para filtrar por gas o electrico
			TXN.PONUMBER AS NUM_CONTRATO,
			--CSPA.LASTNAME 
			case 
				when cred.name like 'CP%' then cred.genericattribute2
				else CSPA.LASTNAME
			end as NOMBRE_PARTICIPANTE,
			TXN.GENERICATTRIBUTE3 AS ESTADO2,
			TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
			TXN.GENERICATTRIBUTE29 AS CIF,
			TXN.ALTERNATEORDERNUMBER AS CUPS,
			TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
			TXN.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
			TXN.GENERICATTRIBUTE28 AS PRESION,
			TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
			TXN.GENERICATTRIBUTE15 AS TARIFA, 
			TXN.PRODUCTID AS TIPO_PRODUCTO,
			--TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO, -- se modifica el campo de tipo de producto
			TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
			TXN.GENERICATTRIBUTE13 AS LINEA_NEGOCIO, 
			cred.PAYEESEQ,
			cred.POSITIONSEQ,
			TXN.GENERICNUMBER2 AS VERSION,
			TXN.GENERICDATE4 AS FECHA_ALTA,
			TXN.GENERICDATE5 AS FECHA_BAJA,
			TXN.TEX0_GENERICDATE13 AS FECHA_CONTRATO, 
			TXN.TEX0_GENERICDATE10 AS FECHA_INI_VERSION, 
			TXN.TEX0_GENERICDATE11 AS FECHA_FIN_VERSION,
			case 
                when cred.name like 'CD%' then cred.genericattribute2
                else CSPA.LASTNAME
            end as responsable,
			CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
			CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
			CRED.GENERICDATE1 AS FECHA_PUBLI,
			CRED.NAME,
			TXN.GENERICATTRIBUTE30 AS TIPO_POSICION,
			CSPO.GENERICATTRIBUTE1 as TIPO_PRESTADOR,
            TXN.GENERICATTRIBUTE31 AS GRP_EMP,
            CRED.GENERICNUMBER1 AS DURAC_CONTR,
            TXN.GENERICATTRIBUTE20 AS F_REC_CONTR,
            TXN.TXN_GENERICATTRIBUTE20 AS FRCC
            ,TXN.TEX0_GENERICDATE7 AS F_CIERRE    --RMM 19.10.2022 incluimos las nuevas fechas
            ,TXN.FECHA_INICIO_LOTE AS F_INI_LOTE   --RMM 19.10.2022 incluimos las nuevas fechas
          
            
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Volumen'
				AND (TXN.SUBLINENUMBER = 1 --electrico
                --APM 26.10.2022 Se añade filtro de Gas para mostrar datos de reglas de Volumen Gas
                or  TXN.SUBLINENUMBER = 2) --gas
				and txn.processingunitseq = 38280596832649418
			
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId
				
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'

			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE 
			(cred.name like 'CD - OFV - Electricidad Activa Cierre - %' or 
             cred.name like 'CP - OFV - Electricidad Activa Cierre - %' or  
        --RMM  BEGIN - igualamos las reglas con las que tiene la tabla  ENEL_CREDITOS_FINAL_VOLUMEN 17.02.22
           --  cred.name like 'CD - OFV - Cartera Electricidad - %' or 
          --   cred.name like 'CP - OFV - Cartera Electricidad - %'
            cred.name like 'CD - OFV - Cartera Activa Electricidad - %'
         or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'
         or cred.name like 'CD - OFV - Cartera Electricidad - Empresas %'
         or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %'
         or cred.name like 'CD - OFV - Volumen El%ctrico Negociado %'
         or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %'
         or cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %'
         or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %'
         or cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %'
         or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %'
         --APM 07.07.2022 BOM
         or cred.name like 'CD - OFV - Cartera Electricidad - AAPP%'
         or cred.name like 'CP - OFV - Cartera Electricidad - AAPP%'
         or cred.name like 'CP - OFV - Volumen El%ctrico - Director%'
         or cred.name like 'CP - OFV - Cartera SD Electricidad - %'
         --APM 07.07.2022 EOM
         --RMM 17/11/2022 BOM
         or cred.name like 'C% - OFV - Volumen El%ctrico - KAM Corporativo - Negociación Singular'
         or cred.name like 'C% - OFV - Cartera Electricidad Agregada - Subdirector KAMME'
         or cred.name like 'CD - OFV - Volumen El%ctrico - KAM %'
		 or cred.name like 'CP - OFV - Volumen El%ctrico - Empresas %'
      
         --RMM 17/11/2022 EOM
         
         --APM 26.10.2022 BOM
         or cred.name like 'C% - OFV - Volumen Gas Negociado - %KAM Corporativo%'
         or cred.name like 'C% - OFV - Volumen Gas - %KAMME%'
         or cred.name like 'C% - OFV - Cartera Gas - %KAM Territorial%'
        --APM 26.10.2022 EOM
        --APM 11.11.2022 BOM
         or cred.name like 'C% - OFV - Gas Activo Cierre - %KAM Corporativo%' 
        --APM 11.11.2022 EOM
         )           
       --RMM END        
             
             
            AND UPPER(TXN.GENERICATTRIBUTE3) not like '%MODIFICADO%'--Status no sea modificado
            /*BOM Diego 15/02/2023 mejorar rendimiento*/
            and substr(cred.periodo,-4) = (SELECT to_char(startdate,'YYYY') FROM cs_period WHERE periodseq = iperiodseq AND removedate = '01/01/2200');
            /*EOM Diego 15/02/2023 mejorar rendimiento*/

		filas := sql%rowcount;
		COMMIT;

		w_debug('Fin Carga de la tabla ENEL_CREDIT_FINAL_VOL_FIJA: '|| to_char(filas) || ' filas.', v_contador_debug);

		EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDIT_FINAL_VOL_FIJA COMPUTE STATISTICS FOR ALL INDEXES';
		w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_FINAL_VOL_FIJA',v_contador_debug);
		
		-- Actualizamos la fecha del informes en la tabla 
        if (filas > 0) then
            p_Actualiza_Informe_Fecha ( iperiod, 'OFV_FIJA_VELE');  
        end if;
	end if; 
    
/* BOM FF1 DCR 10.03.22 */
   end if;
/* EOM FF1 DCR 10.03.22  */
	
	/*w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
	
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 1 --electrico
				and txn.processingunitseq = 38280596832649418	
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE (cred.name like 'CD - OFV - Electricidad Activa Cierre - %' or cred.name like 'CP - OFV - Electricidad Activa Cierre - %' or  
                 cred.name like 'CD - OFV - Cartera Activa Electricidad - %' or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'or 
                 cred.name like 'CD - OFV - Cartera Electricidad - Empresas %' or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %' or 
                 cred.name like 'CD - OFV - Volumen El%ctrico Negociado %' or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %' or 
                 cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %' or 
                 cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %' or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %')
			--and 0=(select count(*) from ENEL_CREDITOS_FINAL_VOLUMEN where orderid=txn.orderid and participantid=cspa.userid and idficha=cspo.name and line=txn.linenumber
			--and value=replace(TRIM(to_char(cred.value, '9999999999990D99')), ',', '.'))
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

    w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_VOLUMEN.', v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_VOLUMEN 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

	w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_VOLUMEN.' || to_char(filas) || ' filas.', v_contador_debug);

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_VOLUMEN. Borrado de meses.' , v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_VOLUMEN WHERE PERIODSEQ >= iperiodseq;
	filas := sql%rowcount;
    
    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_VOLUMEN. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);
	
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from ENEL_TXN_TEMP_OFV txn
			inner join cs_period cspe
				on txn.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
		where txn.eventypeid = 'OFV Volumen'
			AND TXN.SUBLINENUMBER = 1 --electrico
			and txn.tenantid = itenantId
			and (txn.genericattribute3 = 'EN VIGOR' or txn.genericattribute3 = 'VERSION A FUTURO - ENVIADA' )
            /* BOM Diego 15/02/2023 mejorar rendimiento*/
            --and txn.periodo=iperiod
            /* EOM Diego 15/02/2023 mejorar rendimiento*/
	/*);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);*/

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_VOLUMEN estados.', v_contador_debug);	
	
	DELETE FROM ENEL_CREDITOS_FINAL_VOLUMEN 
	WHERE periodo=iperiod;

	filas := sql%rowcount;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_VOLUMEN estados.' || to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_VOLUMEN.' ,  v_contador_debug);
    
    v_cabecera := f_ComprobarCabeceraVolumen(itenantId, iperiodseq);
    
	/* Cuando la posicion no esta versionada */
	INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA,
													estado,line, SUBLINENUMBER, NUM_CONTRATO, NOMBRE_PARTICIPANTE, ESTADO2, RAZON_SOCIAL, CIF, CUPS, CONSUMO_ESTIMADO,  
													CONSUMO_OBJETIVADO, PRESION, CANAL_ENTRADA, TARIFA, TIPO_PRODUCTO, TIPO_CONTRATO, LINEA_NEGOCIO, PAYEESEQ, POSITIONSEQ, VERSION,
													FECHA_ALTA, FECHA_BAJA, FECHA_CONTRATO,FECHA_INI_VERSION, FECHA_FIN_VERSION, RESPONSABLE, FOBJETIVO, COMPENSATIONDATE, 
													FECHA_PUBLI, NAME, TIPO_POSICION, TIPO_PRESTADOR, GRP_EMP, DURAC_CONTR, F_REC_CONTR, FRCC,
                                                    FECHA_INICIO_LOTE, FECHA_CIERRE) --APM 19/10/2022 Incluir nuevos campos
    Select
		TXN.TENANTID,
		TXN.PERIODSEQ,
		TXN.PERIODO,
		to_char(cspe.startdate,'YYYY'),
		txn.orderid,
		cspa.userid,
		cspo.name,
		CASE 
			WHEN ROUND(cred.GENERICNUMBER5, 6) > 0 AND ROUND(cred.GENERICNUMBER5, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
			ELSE TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
		END,
		CASE 
			WHEN ROUND(cred.VALUE, 6) > 0 AND ROUND(cred.VALUE, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.VALUE, 6))
			ELSE TO_CHAR(ROUND(cred.VALUE, 6))
		END,
		CRED.GENERICATTRIBUTE3, --TIPO
		CRED.GENERICATTRIBUTE15, --CONTABILIZA
		CRED.GENERICATTRIBUTE13, --ENERGIA_COMPROMETIDA
		'Pte Enviar', --estado
		txn.linenumber, --line
		
		-- MPR - nuevos campos para informe
		TXN.SUBLINENUMBER, --para filtrar por gas o electrico
		TXN.PONUMBER AS NUM_CONTRATO,
		--CSPA.LASTNAME 
		case 
            when cred.name like 'CP%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as NOMBRE_PARTICIPANTE,
		TXN.GENERICATTRIBUTE3 AS ESTADO2,
		TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
		TXN.GENERICATTRIBUTE29 AS CIF,
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
		TXN.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
		TXN.GENERICATTRIBUTE28 AS PRESION,
		TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
		TXN.GENERICATTRIBUTE15 AS TARIFA, 
		TXN.PRODUCTID AS TIPO_PRODUCTO,
		--TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO, -- se modifica el campo de tipo de producto
		TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
		TXN.GENERICATTRIBUTE13 AS LINEA_NEGOCIO, 
		cred.PAYEESEQ,
        cred.POSITIONSEQ,
		TXN.GENERICNUMBER2 AS VERSION,
		TXN.GENERICDATE4 AS FECHA_ALTA,
		TXN.GENERICDATE5 AS FECHA_BAJA,
		TXN.TEX0_GENERICDATE13 AS FECHA_CONTRATO, 
		TXN.TEX0_GENERICDATE10 AS FECHA_INI_VERSION, 
		TXN.TEX0_GENERICDATE11 AS FECHA_FIN_VERSION,
		case 
            when cred.name like 'CD%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as responsable,
		CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
		CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
		CRED.GENERICDATE1 AS FECHA_PUBLI,
		CRED.NAME,
		TXN.GENERICATTRIBUTE30 AS TIPO_POSICION,
		CSPO.GENERICATTRIBUTE1 as TIPO_PRESTADOR,
        TXN.GENERICATTRIBUTE31 AS GRP_EMP,
--      TXN.GENERICNUMBER1 AS DURAC_CONTR,
        CRED.GENERICNUMBER1 AS DURAC_CONTR,
        TXN.GENERICATTRIBUTE20 AS F_REC_CONTR,
		--RMM
        TXN.TXN_GENERICATTRIBUTE20 AS FRCC,
        --BOM APM 19/10/2022
        TXN.FECHA_INICIO_LOTE AS FECHA_INICIO_LOTE,
        TXN.TEX0_GENERICDATE7 AS FECHA_CIERRE
        --EOM APM 19/10/2022
        
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid = 'OFV Volumen'
			AND (TXN.SUBLINENUMBER = 1 --electrico
            --APM 26.10.2022 Se añade filtro de Gas para mostrar datos de reglas de Volumen Gas
            or  TXN.SUBLINENUMBER = 2) --gas
			and txn.processingunitseq = 38280596832649418
		
		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantid = itenantId
			
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = V_EOT
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'

		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE 
		( cred.name   like 'CD - OFV - Electricidad Activa Cierre - %' 
         or cred.name like 'CP - OFV - Electricidad Activa Cierre - %'
         or cred.name like 'CD - OFV - Cartera Activa Electricidad - %'
         or cred.name like 'CP - OFV - Cartera Activa Electricidad - %'
--         or cred.name like 'CP - OFV - Cartera SD Electricidad - %'
--         or cred.name like 'CD - OFV - Cartera Electricidad - %'
--         or cred.name like 'CP - OFV - Cartera Electricidad - %'
         or cred.name like 'CD - OFV - Cartera Electricidad - Empresas %'
         or cred.name like 'CP - OFV - Cartera Electricidad - Empresas %'
/*         or cred.name like 'CP - OFV - Cartera SD Electricidad %'
         or cred.name like 'CD - OFV - Volumen El%ctrico %'
         or cred.name like 'CP - OFV - Volumen El%ctrico %'
         or cred.name like 'CP - OFV - Cartera SD Electricidad - %'
         or cred.name like 'CD - OFV - Cartera Electricidad - %');	*/
         or cred.name like 'CD - OFV - Volumen El%ctrico Negociado %'
         or cred.name like 'CP - OFV - Volumen El%ctrico Negociado %'
         or cred.name like 'CD - OFV - Volumen El%ctrico - KAMME %'
         or cred.name like 'CP - OFV - Volumen El%ctrico - KAMME %'
         or cred.name like 'CD - OFV - Volumen El%ctrico - RT KAMME %'
         or cred.name like 'CP - OFV - Volumen El%ctrico - RT KAMME %'
         --APM 07.07.2022 BOM
         or cred.name like 'CD - OFV - Cartera Electricidad - AAPP%'
         or cred.name like 'CP - OFV - Cartera Electricidad - AAPP%'
         or cred.name like 'CD - OFV - Volumen El%ctrico - KAM %'
      
         or cred.name like 'CP - OFV - Cartera SD Electricidad - %'
         or cred.name like 'CP - OFV - Volumen El%ctrico - Director - %'
         or cred.name like 'CP - OFV - Volumen El%ctrico - Empresas %'
         --APM 07.07.2022 EOM
          --RMM 17/11/2022 BOM
         or cred.name like 'C% - OFV - Volumen El%ctrico - KAM Corporativo - Negociación Singular'
         or cred.name like 'C% - OFV - Cartera Electricidad Agregada - Subdirector KAMME'
         --RMM 17/11/2022 EOM
         --APM 26.10.2022 BOM
         or cred.name like 'C% - OFV - Volumen Gas Negociado - %KAM Corporativo%'
         or cred.name like 'C% - OFV - Volumen Gas - %KAMME%'
         or cred.name like 'C% - OFV - Cartera Gas - %KAM Territorial%'
        --APM 26.10.2022 EOM
        --APM 11.11.2022 BOM
         or cred.name like 'C% - OFV - Gas Activo Cierre - %KAM Corporativo%' 
         or cred.name like 'C% - OFV - Cartera SD Gas - Subdirección Corporativo%' 
        --APM 11.11.2022 EOM
        )
        AND UPPER(TXN.GENERICATTRIBUTE3) not like '%MODIFICADO%'--Status no sea modificado
         /* BOM Diego 15/02/2023 mejorar rendimiento*/
         and cred.periodo=iperiod;
         /* EOM Diego 15/02/2023 mejorar rendimiento*/
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_VOLUMEN: '|| to_char(filas) || ' filas.', v_contador_debug);

--execute immediate 'alter session set "_push_join_union_view" = true';
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CREDITOS_FINAL_VOLUMEN',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
--execute immediate 'alter session "set _push_join_union_view" = false';

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_VOLUMEN',v_contador_debug);
end;

-- MPR - nuevo procedimiento para cargar Volumen Gas
procedure p_Creditos_Final_Vol_Gas ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2)
AS
	v_cabecera boolean;
	v_fecha_publi date;
	v_fecha_fija date;
	v_cuenta integer;
begin	
	w_debug('Inicio consulta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL_GAS', v_contador_debug);

	select count(distinct cred.genericdate1) into v_cuenta
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid = 'OFV Volumen'
			AND TXN.SUBLINENUMBER = 2 -- para volumen gas
			and txn.processingunitseq = 38280596832649418

		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantid = itenantId

		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = V_EOT
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'

		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE  
		(cred.name like 'CD - OFV - Volumen Gas - %' or cred.name like 'CP - OFV - Volumen Gas - %' or
         cred.name like 'CD - OFV - Cartera Gas - %' or cred.name like 'CP - OFV - Cartera Gas - %' or
         cred.name like 'CD - OFV - Cartera Activa Gas - %' or cred.name like 'CP - OFV - Cartera Activa Gas - %' )
 /* BOM FF1 DCR 10.03.22 */
        AND cred.periodseq = iperiodseq
/* BOM FF1 DCR 10.03.22  */
        and cred.genericdate1 is not null;
	
	w_debug('Cuenta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL_GAS ==> ' || v_cuenta , v_contador_debug);
	
	if (v_cuenta = 1) then 
		-- se hace la comprobacion para cargar la tabla fija en el caso de que sea necesario, solo cuando la fecha de publicacion del credito, GD2, cambie.
		select distinct cred.genericdate1 into v_fecha_publi
			from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 2 -- para volumen gas
				and txn.processingunitseq = 38280596832649418

			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId

			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'

			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE  
			(cred.name like 'CD - OFV - Volumen Gas - %' or cred.name like 'CP - OFV - Volumen Gas - %' or
             cred.name like 'CD - OFV - Cartera Gas - %' or cred.name like 'CP - OFV - Cartera Gas - %' or
             cred.name like 'CD - OFV - Cartera Activa Gas - %' or cred.name like 'CP - OFV - Cartera Activa Gas - %' )
 /* BOM FF1 DCR 10.03.22 */
            AND cred.periodseq = iperiodseq
/* BOM FF1 DCR 10.03.22  */
            and cred.genericdate1 is not null;
	else 
		if (v_cuenta > 1) then
			w_debug('Cuenta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL_GAS OJO!! Más de una', v_contador_debug);

			select max(cred.genericdate1) into v_fecha_publi
				from enel_credit_temp_ofv cred
					inner join enel_txn_temp_ofv txn
						on txn.salestransactionseq = cred.salestransactionseq
						and txn.tenantid = cred.tenantid
						and txn.periodseq = cred.periodseq
						and txn.eventypeid = 'OFV Volumen'
						AND TXN.SUBLINENUMBER = 2 -- para volumen gas
						and txn.processingunitseq = 38280596832649418

					inner join cs_period cspe
						on cred.periodseq=cspe.periodseq
						and cspe.removedate = V_EOT
						and cspe.tenantid = itenantId

					inner join cs_participant cspa 
						on cred.payeeseq=cspa.payeeseq
						and cspa.removedate = V_EOT
						and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
						and cspa.tenantid = itenantId
						and cspa.payeeseq <> '4503599627373822'

					inner join cs_position cspo
						on cred.positionseq=cspo.ruleelementownerseq
						and cspo.removedate = V_EOT
						and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
						and cspo.tenantid = itenantId
						and cspo.ruleelementownerseq <> '4785074604087002'
						-- MPR se comenta y se controla duplicidad por fecha startdate.
						--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
				WHERE  
					(cred.name like 'CD - OFV - Volumen Gas - %' or cred.name like 'CP - OFV - Volumen Gas - %' or
                     cred.name like 'CD - OFV - Cartera Gas - %' or cred.name like 'CP - OFV - Cartera Gas - %' or
                     cred.name like 'CD - OFV - Cartera Activa Gas - %' or cred.name like 'CP - OFV - Cartera Activa Gas - %' )
 /* BOM FF1 DCR 10.03.22 */
                    AND cred.periodseq = iperiodseq
/* BOM FF1 DCR 10.03.22  */
                    and cred.genericdate1 is not null;
		else
/* BOM FF1 DCR 10.03.22 */
-- No deberia hacerse foto fija, ya que no hay datos para ese mes. 
-- Old code
/*            v_fecha_publi:= to_date('01/01/2200','DD/MM/YYYY');*/
-- New code
            v_fecha_publi:= null;
            w_debug('No hay datos para el mes de lanzamiento. No es necesario realizar FOTO FIJA' , v_contador_debug);
/* EOM FF1 DCR 10.03.22  */  
		end if;
	end if;

	w_debug('FIN consulta fecha PUBLI tabla ENEL_CREDIT_FINAL_VOL_GAS ==> ' || v_fecha_publi , v_contador_debug);

/* BOM FF1 DCR 10.03.22 */
    if(v_fecha_publi is not null) then 
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio consulta fecha FIJA tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA.', v_contador_debug);

	SELECT count(distinct FECHA_PUBLI) INTO v_cuenta
	FROM ENELEXT.ENEL_CREDIT_FINAL_VOL_GAS_FIJA
	WHERE FECHA_PUBLI IS NOT NULL
	AND PERIODO = iperiod;
	
	w_debug('Cuenta fecha FIJA tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA. ==> ' || v_cuenta , v_contador_debug);
	
	if(v_cuenta = 1) then 
		SELECT DISTINCT FECHA_PUBLI INTO v_fecha_fija
		FROM ENELEXT.ENEL_CREDIT_FINAL_VOL_GAS_FIJA
		WHERE FECHA_PUBLI IS NOT NULL
        AND PERIODO = iperiod;
	else 
		if (v_cuenta > 1) then
			v_fecha_fija:= to_date('01/01/2200','DD/MM/YYYY');
		else
			w_debug('La fecha FIJA es nula. No hay datos de ese periodo ==> ' || v_cuenta , v_contador_debug);
			v_fecha_fija:= null;
		end if;
	end if;

	w_debug('FIN consulta fecha FIJA tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA. ==> ' || v_fecha_fija , v_contador_debug);
	
	w_debug('Compara fecha FIJA ==> ' || v_fecha_fija || ' fecha PUBLI ==> ' || v_fecha_publi, v_contador_debug);
	
	-- MPR -- si la fecha de publicacion es diferente se carga la tabla fija
/* BOM FF1 DCR 10.03.22 
Old code */
--    if (v_fecha_publi <> v_fecha_fija or v_fecha_fija is null) then
--New code
   if (v_fecha_publi > v_fecha_fija or v_fecha_fija is null) then
/* EOM FF1 DCR 10.03.22  */
		
/* BOM FF1 DCR 10.03.22 
Old code 
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid = 'OFV Volumen'
					AND TXN.SUBLINENUMBER = 2 -- para volumen gas
					and txn.processingunitseq = 38280596832649418
				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantid = itenantId
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate = V_EOT
					and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
					and cspa.tenantid = itenantId
					and cspa.payeeseq <> '4503599627373822'
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
					and cspo.tenantid = itenantId
					and cspo.ruleelementownerseq <> '4785074604087002'
					-- MPR se comenta y se controla duplicidad por fecha startdate.
					---and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
			WHERE  
				(cred.name like 'CD - OFV - Volumen Gas - %' or cred.name like 'CP - OFV - Volumen Gas - %' or
                 cred.name like 'CD - OFV - Cartera Gas - %' or cred.name like 'CP - OFV - Cartera Gas - %' or
                 cred.name like 'CD - OFV - Cartera Activa Gas - %' or cred.name like 'CP - OFV - Cartera Activa Gas - %' )
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDIT_FINAL_VOL_GAS_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA. Borrado de meses.' , v_contador_debug);
		
		DELETE FROM ENEL_CREDIT_FINAL_VOL_GAS_FIJA WHERE PERIODSEQ >= iperiodseq;
		filas := sql%rowcount;
		
		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from ENEL_TXN_TEMP_OFV txn
				inner join cs_period cspe
					on txn.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
			where txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 2 --gas
				and txn.tenantid = itenantId
				and (txn.genericattribute3 = 'EN VIGOR' or txn.genericattribute3 = 'VERSION A FUTURO - ENVIADA' )
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA estados.', v_contador_debug);	
		
		DELETE FROM ENEL_CREDIT_FINAL_VOL_GAS_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA estados.' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Insertando datos en tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA.' ,  v_contador_debug);
		
		v_cabecera := f_ComprobarCabeceraVolGas(itenantId, iperiodseq);

-- New code */
        w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_VOL_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDIT_FINAL_VOL_GAS_FIJA 
		WHERE anio = (SELECT to_char(startdate,'YYYY') FROM cs_period WHERE periodseq = iperiodseq AND removedate = '01/01/2200');

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);
/* EOM FF1 DCR 10.03.22  */

		/* Cuando la posicion no esta versionada */
		INSERT INTO ENELEXT.ENEL_CREDIT_FINAL_VOL_GAS_FIJA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA,
														estado,line, SUBLINENUMBER, NUM_CONTRATO, NOMBRE_PARTICIPANTE, ESTADO2, RAZON_SOCIAL, CIF, CUPS, CONSUMO_ESTIMADO,  
														CONSUMO_OBJETIVADO,  PRESION, CANAL_ENTRADA, TARIFA, TIPO_PRODUCTO, TIPO_CONTRATO, LINEA_NEGOCIO, PAYEESEQ, POSITIONSEQ, 
														VERSION, FECHA_ALTA, FECHA_BAJA, FECHA_CONTRATO,FECHA_INI_VERSION, FECHA_FIN_VERSION, RESPONSABLE, FOBJETIVO,
														COMPENSATIONDATE, FECHA_PUBLI, NAME, TIPO_POSICION, TIPO_PRESTADOR, GRP_EMP, DURAC_CONTR, FRCC
                                                        ,F_INI_LOTE , F_CIERRE -- RMM 20.10.2022
                                                        )
		Select
			TXN.TENANTID,
			TXN.PERIODSEQ,
			TXN.PERIODO,
			to_char(cspe.startdate,'YYYY'),
			txn.orderid,
			cspa.userid,
			cspo.name,
			CASE 
				WHEN ROUND(cred.GENERICNUMBER5, 6) > 0 AND ROUND(cred.GENERICNUMBER5, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
				ELSE TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
			END,
			CASE 
				WHEN ROUND(cred.VALUE, 6) > 0 AND ROUND(cred.VALUE, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.VALUE, 6))
				ELSE TO_CHAR(ROUND(cred.VALUE, 6))
			END,
			CRED.GENERICATTRIBUTE3, --TIPO
			CRED.GENERICATTRIBUTE15, --CONTABILIZA
			CRED.GENERICATTRIBUTE13, --ENERGIA_COMPROMETIDA
			'Pte Enviar', --estado
			txn.linenumber, --line
			
			-- MPR - nuevos campos para informe
			TXN.SUBLINENUMBER, --para filtrar por gas o electrico
			TXN.PONUMBER AS NUM_CONTRATO,
			--CSPA.LASTNAME 
			case 
				when cred.name like 'CP %' then cred.genericattribute2
				else CSPA.LASTNAME
			end as NOMBRE_PARTICIPANTE,
			TXN.GENERICATTRIBUTE3 AS ESTADO2,
			TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
			TXN.GENERICATTRIBUTE29 AS CIF,
			TXN.ALTERNATEORDERNUMBER AS CUPS,
			TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
			TXN.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
			TXN.GENERICATTRIBUTE28 AS PRESION,
			TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
			TXN.GENERICATTRIBUTE15 AS TARIFA, 
			TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO,
			TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
			TXN.GENERICATTRIBUTE13 AS LINEA_NEGOCIO,
			cred.PAYEESEQ,
			cred.POSITIONSEQ,
			TXN.GENERICNUMBER2 AS VERSION,
			TXN.GENERICDATE4 AS FECHA_ALTA,
			TXN.GENERICDATE5 AS FECHA_BAJA,
			TXN.TEX0_GENERICDATE13 AS FECHA_CONTRATO, 
			TXN.TEX0_GENERICDATE10 AS FECHA_INI_VERSION, 
			TXN.TEX0_GENERICDATE11 AS FECHA_FIN_VERSION,
			case 
				when cred.name like 'CD %' then cred.genericattribute2
				else CSPA.LASTNAME
			end as responsable,
			CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
			CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
			CRED.GENERICDATE1 AS FECHA_PUBLI, 
			CRED.NAME,
			TXN.GENERICATTRIBUTE30 AS TIPO_POSICION,
			CSPO.GENERICATTRIBUTE1 as TIPO_PRESTADOR,
            TXN.GENERICATTRIBUTE31 AS GRP_EMP,
            CRED.GENERICNUMBER1 AS DURAC_CONTR,
            TXN.TXN_GENERICATTRIBUTE20 AS FRCC
            ,TXN.FECHA_INICIO_LOTE AS F_INI_LOTE   --RMM 20.10.2022 incluimos las nuevas fechas
            ,TXN.TEX0_GENERICDATE7 AS F_CIERRE    --RMM 20.10.2022 incluimos las nuevas fechas
          
          
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 2 -- para volumen gas
				and txn.processingunitseq = 38280596832649418

			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId

			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'

			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE  
            (
             cred.name like 'CD - OFV - Cartera Gas - %' or 
             cred.name like 'CD - OFV - Cartera Activa Gas - %' or
             cred.name like 'CD - OFV - Volumen Gas - %' or
             --APM 07.07.2022 BOM
             cred.name like 'CD - OFV - Volumen Gas Negociado - %' or 
             cred.name like 'CD - OFV - Gas Activo Cierre - %' or
             --APM 07.07.2022 EOM
             cred.name like 'CP - OFV - Cartera Gas - %' or
             cred.name like 'CP - OFV - Cartera Gas Agregada%' or 
             cred.name like 'CP - OFV - Volumen Gas - %' or
             cred.name like 'CP - OFV - Cartera Activa Gas - %' or
             --APM 07.07.2022 BOM
             cred.name like 'CP - OFV - Volumen Gas Negociado - %' or 
             cred.name like 'CP - OFV - Gas Activo Cierre - %' or
             cred.name like 'CP - OFV - Cartera SD Gas - %'  or
              --APM 15.11.2022 BOM
              cred.name like 'CP - OFV - Cartera Gas Agregada%' or
              cred.name like 'CP - OFV - Cartera Activa Gas - %'
             --APM 15.11.2022 EOM
        
             )
            AND UPPER(TXN.GENERICATTRIBUTE3) not like '%MODIFICADO%';--Status no sea modificado
		filas := sql%rowcount;
		COMMIT;

		w_debug('Fin Carga de la tabla ENEL_CREDIT_FINAL_VOL_GAS_FIJA: '|| to_char(filas) || ' filas.', v_contador_debug);

		EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDIT_FINAL_VOL_GAS_FIJA COMPUTE STATISTICS FOR ALL INDEXES';
		w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_FINAL_VOL_GAS_FIJA',v_contador_debug);
		
		-- Actualizamos la fecha del informes en la tabla 
        if (filas > 0) then
            p_Actualiza_Informe_Fecha ( iperiod, 'OFV_FIJA_VGAS');  
        end if;		
	end if;

/* BOM FF1 DCR 10.03.22 */
   end if;
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Volumen'
				AND TXN.SUBLINENUMBER = 2 -- para volumen gas
				and txn.processingunitseq = 38280596832649418
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE  
			(cred.name like 'CD - OFV - Volumen Gas - %' or cred.name like 'CP - OFV - Volumen Gas - %' or
             cred.name like 'CD - OFV - Cartera Gas - %' or cred.name like 'CP - OFV - Cartera Gas - %' or
             cred.name like 'CD - OFV - Cartera Activa Gas - %' or cred.name like 'CP - OFV - Cartera Activa Gas - %' )
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

    w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_VOL_GAS.', v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_VOL_GAS 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

	w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_VOL_GAS.' || to_char(filas) || ' filas.', v_contador_debug);

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_VOL_GAS. Borrado de meses.' , v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_VOL_GAS WHERE PERIODSEQ >= iperiodseq;
	filas := sql%rowcount;
    
    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_VOL_GAS. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from ENEL_TXN_TEMP_OFV txn
			inner join cs_period cspe
				on txn.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
		where txn.eventypeid = 'OFV Volumen'
			AND TXN.SUBLINENUMBER = 2 --gas
			and txn.tenantid = itenantId
			and (txn.genericattribute3 = 'EN VIGOR' or txn.genericattribute3 = 'VERSION A FUTURO - ENVIADA' )
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_VOL_GAS estados.', v_contador_debug);	
	
	DELETE FROM ENEL_CREDITOS_FINAL_VOL_GAS 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_VOL_GAS estados.' || to_char(filas) || ' filas.', v_contador_debug);
    
    w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_VOL_GAS.' ,  v_contador_debug);
    
    v_cabecera := f_ComprobarCabeceraVolGas(itenantId, iperiodseq);
    
	/* Cuando la posicion no esta versionada */
	INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA,
													estado,line, SUBLINENUMBER, NUM_CONTRATO, NOMBRE_PARTICIPANTE, ESTADO2, RAZON_SOCIAL, CIF, CUPS, CONSUMO_ESTIMADO,  
													CONSUMO_OBJETIVADO,  PRESION, CANAL_ENTRADA, TARIFA, TIPO_PRODUCTO, TIPO_CONTRATO, LINEA_NEGOCIO, PAYEESEQ, POSITIONSEQ,
													VERSION, FECHA_ALTA, FECHA_BAJA, FECHA_CONTRATO,FECHA_INI_VERSION, FECHA_FIN_VERSION, RESPONSABLE, FOBJETIVO, COMPENSATIONDATE, 
													FECHA_PUBLI, NAME, TIPO_POSICION, TIPO_PRESTADOR, GRP_EMP, DURAC_CONTR, FRCC,
                                                    FECHA_INICIO_LOTE, FECHA_CIERRE) --APM 19/10/2022 Incluir nuevos campos
    Select
		TXN.TENANTID,
		TXN.PERIODSEQ,
		TXN.PERIODO,
		to_char(cspe.startdate,'YYYY'),
		txn.orderid,
		cspa.userid,
		cspo.name,
		CASE 
			WHEN ROUND(cred.GENERICNUMBER5, 6) > 0 AND ROUND(cred.GENERICNUMBER5, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
			ELSE TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
		END,
		CASE 
			WHEN ROUND(cred.VALUE, 6) > 0 AND ROUND(cred.VALUE, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.VALUE, 6))
			ELSE TO_CHAR(ROUND(cred.VALUE, 6))
		END,
		CRED.GENERICATTRIBUTE3, --TIPO
		CRED.GENERICATTRIBUTE15, --CONTABILIZA
		CRED.GENERICATTRIBUTE13, --ENERGIA_COMPROMETIDA
		'Pte Enviar', --estado
		txn.linenumber, --line
		
		-- MPR - nuevos campos para informe
		TXN.SUBLINENUMBER, --para filtrar por gas o electrico
		TXN.PONUMBER AS NUM_CONTRATO,
		--CSPA.LASTNAME 
		case 
            when cred.name like 'CP%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as NOMBRE_PARTICIPANTE,
		TXN.GENERICATTRIBUTE3 AS ESTADO2,
		TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
		TXN.GENERICATTRIBUTE29 AS CIF,
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
		TXN.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
		TXN.GENERICATTRIBUTE28 AS PRESION,
		TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
		TXN.GENERICATTRIBUTE15 AS TARIFA, 
		TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO,
		TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
		TXN.GENERICATTRIBUTE13 AS LINEA_NEGOCIO,
		cred.PAYEESEQ,
        cred.POSITIONSEQ,
		TXN.GENERICNUMBER2 AS VERSION,
		TXN.GENERICDATE4 AS FECHA_ALTA,
		TXN.GENERICDATE5 AS FECHA_BAJA,
		TXN.TEX0_GENERICDATE13 AS FECHA_CONTRATO, 
		TXN.TEX0_GENERICDATE10 AS FECHA_INI_VERSION, 
		TXN.TEX0_GENERICDATE11 AS FECHA_FIN_VERSION,
		case 
            when cred.name like 'CD%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as responsable,
		CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
		CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
		CRED.GENERICDATE1 AS FECHA_PUBLI,
		CRED.NAME,
		TXN.GENERICATTRIBUTE30 AS TIPO_POSICION,
		CSPO.GENERICATTRIBUTE1 as TIPO_PRESTADOR,
        TXN.GENERICATTRIBUTE31 AS GRP_EMP,
        --TXN.GENERICNUMBER1 AS DURAC_CONTR
        CRED.GENERICNUMBER1 AS DURAC_CONTR,
        TXN.TXN_GENERICATTRIBUTE20 AS FRCC,
         --BOM APM 19/10/2022
        TXN.FECHA_INICIO_LOTE AS FECHA_INICIO_LOTE,
        TXN.TEX0_GENERICDATE7 AS FECHA_CIERRE
         --EOM APM 19/10/2022
         
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid = 'OFV Volumen'
			AND TXN.SUBLINENUMBER = 2 -- para volumen gas
			and txn.processingunitseq = 38280596832649418
						
		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantid = itenantId

		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = V_EOT
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'
		
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE  
		(cred.name like 'CD - OFV - Cartera Gas - %' or 
         cred.name like 'CD - OFV - Cartera Activa Gas - %' or
         cred.name like 'CD - OFV - Volumen Gas - %' or
         --APM 07.07.2022 BOM
         cred.name like 'CD - OFV - Volumen Gas Negociado - %' or 
         cred.name like 'CD - OFV - Gas Activo Cierre - %' or 
         --APM 07.07.2022 EOM
         cred.name like 'CP - OFV - Cartera Gas - %' or
         cred.name like 'CP - OFV - Volumen Gas - %' or
         cred.name like 'CP - OFV - Cartera Activa Gas - %' or
         --APM 07.07.2022 BOM
         cred.name like 'CP - OFV - Volumen Gas Negociado - %' or 
         cred.name like 'CP - OFV - Gas Activo Cierre - %' or 
         cred.name like 'CP - OFV - Cartera SD Gas - %' or
         --APM 07.07.2022 EOM
         --APM 11.11.2022 BOM
         cred.name like 'CP - OFV - Cartera Gas Agregada%' or
         --APM 11.11.2022 EOM
         --APM 15.11.2022 BOM
         cred.name like 'CP - OFV - Cartera Activa Gas - %'
         --APM 15.11.2022 EOM
         )
        AND UPPER(TXN.GENERICATTRIBUTE3) not like '%MODIFICADO%';--Status no sea modificado

        
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_VOL_GAS: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_VOL_GAS',v_contador_debug);
end;

procedure p_Creditos_Final_V_Renta ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2)
AS
	v_cabecera boolean;
	v_fecha_publi date;
	v_fecha_fija date;
	v_cuenta integer;
begin	
	w_debug('Inicio consulta fecha PUBLI tabla ENEL_CREDIT_FINAL_V_RENTA', v_contador_debug);

	select count(distinct cred.genericdate1) into v_cuenta
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid = 'OFV Rentabilidad'
			AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
			and txn.processingunitseq = 38280596832649418

		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantid = itenantId
		
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = V_EOT
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'
			
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE  
		(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %')
 /* BOM FF1 DCR 10.03.22 */
        AND cred.periodseq = iperiodseq
/* BOM FF1 DCR 10.03.22  */
        and cred.genericdate1 is not null;
	
	w_debug('Cuenta fecha PUBLI tabla ENEL_CREDIT_FINAL_V_RENTA ==> ' || v_cuenta , v_contador_debug);
	
	if (v_cuenta = 1) then 
		-- se hace la comprobacion para cargar la tabla fija en el caso de que sea necesario, solo cuando la fecha de publicacion del credito, GD2, cambie.
		select distinct cred.genericdate1 into v_fecha_publi
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
                and txn.eventypeid = 'OFV Rentabilidad'
				AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
				and txn.processingunitseq = 38280596832649418

			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId
			
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'
				
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE  
			(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %')
/* BOM FF1 DCR 10.03.22 */
            AND cred.periodseq = iperiodseq
/* EOM FF1 DCR 10.03.22  */
            and cred.genericdate1 is not null;
	else 
		if (v_cuenta > 1) then
			w_debug('Cuenta fecha PUBLI tabla ENEL_CREDIT_FINAL_V_RENTA OJO!! Más de una', v_contador_debug);
			
			select max(cred.genericdate1) into v_fecha_publi
			from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid = 'OFV Rentabilidad'
					AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
					and txn.processingunitseq = 38280596832649418

				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantid = itenantId
				
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate = V_EOT
					and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
					and cspa.tenantid = itenantId
					and cspa.payeeseq <> '4503599627373822'
					
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
					and cspo.tenantid = itenantId
					and cspo.ruleelementownerseq <> '4785074604087002'
					-- MPR se comenta y se controla duplicidad por fecha startdate.
					--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
			WHERE  
				(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %')
/* BOM FF1 DCR 10.03.22 */
                AND cred.periodseq = iperiodseq
/* EOM FF1 DCR 10.03.22  */
                and cred.genericdate1 is not null;
		else
/* BOM FF1 DCR 10.03.22 */
-- No deberia hacerse foto fija, ya que no hay datos para ese mes. 
-- Old code
/*            v_fecha_publi:= to_date('01/01/2200','DD/MM/YYYY');*/
-- New code
            v_fecha_publi:= null;
            w_debug('No hay datos para el mes de lanzamiento. No es necesario realizar FOTO FIJA' , v_contador_debug);
/* EOM FF1 DCR 10.03.22  */ 
		end if;
	end if;
		
	w_debug('FIN consulta fecha PUBLI tabla ENEL_CREDIT_FINAL_V_RENTA ==> ' || v_fecha_publi , v_contador_debug);

/* BOM FF1 DCR 10.03.22 */
    if(v_fecha_publi is not null) then 
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio consulta fecha FIJA tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA.', v_contador_debug);
	
	SELECT count(distinct FECHA_PUBLI) INTO v_cuenta
	FROM ENELEXT.ENEL_CREDIT_FINAL_V_RENTA_FIJA
	WHERE FECHA_PUBLI IS NOT NULL
	AND PERIODO = iperiod;
	
	w_debug('Cuenta fecha FIJA tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA. ==> ' || v_cuenta , v_contador_debug);
	
	if(v_cuenta = 1) then 
		SELECT DISTINCT FECHA_PUBLI INTO v_fecha_fija
		FROM ENELEXT.ENEL_CREDIT_FINAL_V_RENTA_FIJA
		WHERE FECHA_PUBLI IS NOT NULL
        AND PERIODO = iperiod;
	else 
		if (v_cuenta > 1) then
			v_fecha_fija:= to_date('01/01/2200','DD/MM/YYYY');
		else
			w_debug('La fecha FIJA es nula. No hay datos de ese periodo ==> ' || v_cuenta , v_contador_debug);
			v_fecha_fija:= null;
		end if;
	end if;

	w_debug('FIN consulta fecha FIJA tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA. ==> ' || v_fecha_fija , v_contador_debug);
	
	w_debug('Compara fecha FIJA ==> ' || v_fecha_fija || ' fecha PUBLI ==> ' || v_fecha_publi, v_contador_debug);
	
	-- MPR -- si la fecha de publicacion es diferente se carga la tabla fija
/* BOM FF1 DCR 10.03.22 
Old code */
--    if (v_fecha_publi <> v_fecha_fija or v_fecha_fija is null) then
--New code
   if (v_fecha_publi > v_fecha_fija or v_fecha_fija is null) then 
/* EOM FF1 DCR 10.03.22  */

/* BOM FF1 DCR 10.03.22 
Old code 
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from enel_credit_temp_ofv cred
				inner join enel_txn_temp_ofv txn
					on txn.salestransactionseq = cred.salestransactionseq
					and txn.tenantid = cred.tenantid
					and txn.periodseq = cred.periodseq
					and txn.eventypeid = 'OFV Rentabilidad'
					AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
					and txn.processingunitseq = 38280596832649418
							
				inner join cs_period cspe
					on cred.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantid = itenantId
				inner join cs_participant cspa 
					on cred.payeeseq=cspa.payeeseq
					and cspa.removedate = V_EOT
					and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
					and cspa.tenantid = itenantId
					and cspa.payeeseq <> '4503599627373822'
				inner join cs_position cspo
					on cred.positionseq=cspo.ruleelementownerseq
					and cspo.removedate = V_EOT
					and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
					and cspo.tenantid = itenantId
					and cspo.ruleelementownerseq <> '4785074604087002'
					-- MPR se comenta y se controla duplicidad por fecha startdate.
					--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
			WHERE 
				(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %')
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA.', v_contador_debug);
		
		DELETE FROM ENEL_CREDIT_FINAL_V_RENTA_FIJA
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA. Borrado de meses.' , v_contador_debug);
		
		DELETE FROM ENEL_CREDIT_FINAL_V_RENTA_FIJA WHERE PERIODSEQ >= iperiodseq;
		filas := sql%rowcount;
		
		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
		
		w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

		EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

		INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
		(Select txn.orderid
			from ENEL_TXN_TEMP_OFV txn
				inner join cs_period cspe
					on txn.periodseq=cspe.periodseq
					and cspe.removedate = V_EOT
					and cspe.tenantId = itenantId
			where txn.eventypeid = 'OFV Rentabilidad'
				AND TXN.SUBLINENUMBER = 1 --electrico
				and txn.tenantid = itenantId
				and (txn.genericattribute3 = 'EN VIGOR' or txn.genericattribute3 = 'VERSION A FUTURO - ENVIADA' )
		);
		filas := sql%rowcount;

		w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

		w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA estados.', v_contador_debug);	
		
		DELETE FROM ENEL_CREDIT_FINAL_V_RENTA_FIJA 
		WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);
			
		filas := sql%rowcount;
				 
		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA estados.' || to_char(filas) || ' filas.', v_contador_debug);
	 
		w_debug('Insertando datos en tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA.' ,  v_contador_debug);
		
		v_cabecera := f_ComprobarCabeceraVRenta(itenantId, iperiodseq);

-- New code */
        w_debug('Inicio Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA.', v_contador_debug);
    
		DELETE FROM ENEL_CREDIT_FINAL_V_RENTA_FIJA 
		WHERE anio = (SELECT to_char(startdate,'YYYY') FROM cs_period WHERE periodseq = iperiodseq AND removedate = '01/01/2200');

		filas := sql%rowcount;

		w_debug('Fin Borrado de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA.' || to_char(filas) || ' filas.', v_contador_debug);
/* EOM FF1 DCR 10.03.22  */
		/* Cuando la posicion no esta versionada */
		INSERT INTO ENELEXT.ENEL_CREDIT_FINAL_V_RENTA_FIJA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA,
														estado,line, SUBLINENUMBER, NUM_CONTRATO, NOMBRE_PARTICIPANTE, ESTADO2, RAZON_SOCIAL, CIF, CUPS, CONSUMO_ESTIMADO,
														CONSUMO_OBJETIVADO,  PRESION, CANAL_ENTRADA, TARIFA, TIPO_PRODUCTO, TIPO_CONTRATO, LINEA_NEGOCIO, PAYEESEQ, POSITIONSEQ, 
														CUARTIL, VOLUMEN_NEGOCIADO, COMPONENTE, PRODUCTO, FECHA_NEGOCIACION, FECHA_CONTRATO, PRECIO_CERRADO, 
														PRECIO_MINI_SD, PRECIO_MINI_RT, PRECIO_MINI_GESTOR, PRECIO_MINI_OBJETIVO, GESTION_CARTERA, RRAA, VERSION, DURACION, NAME, 
														MARGEN, PRODUCTNAME, RESPONSABLE, FOBJETIVO, COMPENSATIONDATE, FECHA_PUBLI, CRED_NAME, TIPO_POSICION, TIPO_PRESTADOR,
                                                        PRECIO_OBJETIVO_3, PRECIO_MAXIMO, GRP_EMP, CAMPANA, LOTE, DURAC_CONTR , FRCC) --RMM
		Select
			TXN.TENANTID,
			TXN.PERIODSEQ,
			TXN.PERIODO,
			to_char(cspe.startdate,'YYYY'),
			txn.orderid,
			cspa.userid,
			cspo.name,
			CASE 
				WHEN ROUND(cred.GENERICNUMBER5, 6) > 0 AND ROUND(cred.GENERICNUMBER5, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
				ELSE TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
			END,
			CASE 
				WHEN ROUND(cred.VALUE, 6) > 0 AND ROUND(cred.VALUE, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.VALUE, 6))
				ELSE TO_CHAR(ROUND(cred.VALUE, 6))
			END,
			CRED.GENERICATTRIBUTE3, --TIPO
			CRED.GENERICATTRIBUTE15, --CONTABILIZA
			CRED.GENERICATTRIBUTE13, --ENERGIA_COMPROMETIDA
			'Pte Enviar', --estado
			txn.linenumber, --line
			-- MPR - nuevos campos para informe
			TXN.SUBLINENUMBER, --para filtrar por gas o electrico
			TXN.PONUMBER AS NUM_CONTRATO,
			--CSPA.LASTNAME 
			case 
				when cred.name like 'CP%' then cred.genericattribute2
				else CSPA.LASTNAME
			end as NOMBRE_PARTICIPANTE,
			TXN.GENERICATTRIBUTE3 AS ESTADO2,
			TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
			TXN.GENERICATTRIBUTE29 AS CIF,
			TXN.ALTERNATEORDERNUMBER AS CUPS,
			TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
			TXN.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
			TXN.GENERICATTRIBUTE28 AS PRESION,
			TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
			TXN.GENERICATTRIBUTE15 AS TARIFA, 
			TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO,
			TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
			TXN.GENERICATTRIBUTE13 AS LINEA_NEGOCIO, 
			cred.PAYEESEQ,
			cred.POSITIONSEQ,

			--MPR nuevos campos para rentabilidad
			TXN.GENERICATTRIBUTE20 AS CUARTIL,
			TXN.GENERICNUMBER15 AS VOLUMEN_NEGOCIADO,
			--TXN.GENERICATTRIBUTE24 AS COMPONENTE,
			CRED.GENERICATTRIBUTE6 AS COMPONENTE,
			TXN.PRODUCTID AS PRODUCTO, 
			
			TXN.TEX0_GENERICDATE7 AS FECHA_NEGOCIACION,
			TXN.TEX0_GENERICDATE13 AS FECHA_CONTRATO, 
			TXN.TEX0_GENERICNUMBER14 AS PRECIO_CERRADO,
			TXN.TEX0_GENERICNUMBER16 AS PRECIO_MINI_SD,
			TXN.TEX0_GENERICNUMBER13 AS PRECIO_MINI_RT,
			TXN.TEX0_GENERICNUMBER12 AS PRECIO_MINI_GESTOR,
			TXN.TEX0_GENERICNUMBER11 AS PRECIO_MINI_OBJETIVO,
			TXN.TEX0_GENERICBOOLEAN1 AS GESTION_CARTERA,
			TXN.TEX0_GENERICBOOLEAN3 AS RRAA,
			TXN.GENERICNUMBER2 AS VERSION,
			CRED.GENERICNUMBER1 AS DURACION,
			CRED.NAME,
			TXN.GENERICNUMBER5 AS MARGEN,
			TXN.PRODUCTNAME,
			case 
				when cred.name like 'CD%' then cred.genericattribute2
				else CSPA.LASTNAME
			end as responsable,
			CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
			CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
			CRED.GENERICDATE1 AS FECHA_PUBLI,
			CRED.NAME,
			TXN.GENERICATTRIBUTE30 AS TIPO_POSICION,
			CSPO.GENERICATTRIBUTE1 as TIPO_PRESTADOR,
			TXN.GENERICNUMBER6 AS PRECIO_OBJETIVO_3, --RMM
            TXN.GENERICNUMBER7 AS PRECIO_MAXIMO,  --RMM
            TXN.GENERICATTRIBUTE31 AS GRP_EMP,
            TXN.GENERICATTRIBUTE23 AS CAMPANA,
            TXN.GENERICATTRIBUTE32 AS LOTE,
            TXN.GENERICNUMBER1 AS DURAC_CONTR,
            TXN.TXN_GENERICATTRIBUTE20 AS FRCC   --RMM
            
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Rentabilidad'
				AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
				and txn.processingunitseq = 38280596832649418
				
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId
			
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'
			
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE  
			(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %');

		filas := sql%rowcount;
		COMMIT;

		w_debug('Fin Carga de la tabla ENEL_CREDIT_FINAL_V_RENTA_FIJA: '|| to_char(filas) || ' filas.', v_contador_debug);

		EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDIT_FINAL_V_RENTA_FIJA COMPUTE STATISTICS FOR ALL INDEXES';
		w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_FINAL_V_RENTA_FIJA',v_contador_debug);
		
		-- Actualizamos la fecha del informes en la tabla 
        if (filas > 0) then
            p_Actualiza_Informe_Fecha ( iperiod, 'OFV_FIJA_RENTA');   
        end if;
	end if;

/* BOM FF1 DCR 10.03.22 */
 end if; 
/* EOM FF1 DCR 10.03.22  */

	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Rentabilidad'
				AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
				and txn.processingunitseq = 38280596832649418
						
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantid = itenantId
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = V_EOT
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = V_EOT
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
				-- MPR se comenta y se controla duplicidad por fecha startdate.
				--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
		WHERE 
			(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %')
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

    w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_V_RENTA.', v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_V_RENTA
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

	w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_V_RENTA.' || to_char(filas) || ' filas.', v_contador_debug);

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_V_RENTA. Borrado de meses.' , v_contador_debug);
    
    DELETE FROM ENEL_CREDITOS_FINAL_V_RENTA WHERE PERIODSEQ >= iperiodseq;
	filas := sql%rowcount;
    
    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_V_RENTA. Borrado de meses. ' || to_char(filas) || ' filas.', v_contador_debug);
	
	w_debug('Inicio truncado y carga de la tabla ENEL_OFV_BORRADO.', v_contador_debug);

	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OFV_BORRADO';

	INSERT INTO ENELEXT.ENEL_OFV_BORRADO 
	(Select txn.orderid
		from ENEL_TXN_TEMP_OFV txn
			inner join cs_period cspe
				on txn.periodseq=cspe.periodseq
				and cspe.removedate = V_EOT
				and cspe.tenantId = itenantId
		where txn.eventypeid = 'OFV Rentabilidad'
			AND TXN.SUBLINENUMBER = 1 --electrico
			and txn.tenantid = itenantId
			and (txn.genericattribute3 = 'EN VIGOR' or txn.genericattribute3 = 'VERSION A FUTURO - ENVIADA' )
	);
	filas := sql%rowcount;

	w_debug('Fin carga de la tabla ENEL_OFV_BORRADO.' || to_char(filas) || ' filas.' , v_contador_debug);

	w_debug('Inicio Borrado de la tabla ENEL_CREDITOS_FINAL_V_RENTA estados.', v_contador_debug);	
	
	DELETE FROM ENEL_CREDITOS_FINAL_V_RENTA 
	WHERE ORDERID IN (SELECT ORDERID FROM ENEL_OFV_BORRADO);

	filas := sql%rowcount;

    w_debug('Fin Borrado de la tabla ENEL_CREDITOS_FINAL_V_RENTA estados.' || to_char(filas) || ' filas.', v_contador_debug);
 
    w_debug('Insertando datos en tabla ENEL_CREDITOS_FINAL_V_RENTA.' ,  v_contador_debug);
    
    v_cabecera := f_ComprobarCabeceraVRenta(itenantId, iperiodseq);
    
	/* Cuando la posicion no esta versionada */
	INSERT INTO ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA(tenantid,periodseq,periodo,anio,ORDERID,PARTICIPANTID,IDFICHA,VOLUMEN_ORIGEN,VALUE,TIPO,CONTABILIZA,ENERGIA_COMPROMETIDA,estado,
												line, SUBLINENUMBER, NUM_CONTRATO, NOMBRE_PARTICIPANTE, ESTADO2, RAZON_SOCIAL, CIF, CUPS, CONSUMO_ESTIMADO,  CONSUMO_OBJETIVADO,  
												PRESION, CANAL_ENTRADA, TARIFA, TIPO_PRODUCTO, TIPO_CONTRATO, LINEA_NEGOCIO, PAYEESEQ, POSITIONSEQ, CUARTIL, VOLUMEN_NEGOCIADO, 
												COMPONENTE, PRODUCTO, FECHA_NEGOCIACION, FECHA_CONTRATO, PRECIO_CERRADO, PRECIO_MINI_SD, PRECIO_MINI_RT, PRECIO_MINI_GESTOR, 
												PRECIO_MINI_OBJETIVO, GESTION_CARTERA, RRAA, VERSION, DURACION, NAME, MARGEN, PRODUCTNAME, RESPONSABLE, FOBJETIVO, COMPENSATIONDATE,
												FECHA_PUBLI, CRED_NAME, TIPO_POSICION, TIPO_PRESTADOR , PRECIO_MAXIMO, PRECIO_OBJETIVO_3, GRP_EMP, CAMPANA, LOTE, DURAC_CONTR , FRCC)
    Select
		TXN.TENANTID,
		TXN.PERIODSEQ,
		TXN.PERIODO,
		to_char(cspe.startdate,'YYYY'),
		txn.orderid,
		cspa.userid,
		cspo.name,
		CASE 
			WHEN ROUND(cred.GENERICNUMBER5, 6) > 0 AND ROUND(cred.GENERICNUMBER5, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
			ELSE TO_CHAR(ROUND(cred.GENERICNUMBER5, 6))
		END,
		CASE 
			WHEN ROUND(cred.VALUE, 6) > 0 AND ROUND(cred.VALUE, 6) < 1 THEN '0' || TO_CHAR(ROUND(cred.VALUE, 6))
			ELSE TO_CHAR(ROUND(cred.VALUE, 6))
		END,
		CRED.GENERICATTRIBUTE3, --TIPO
		CRED.GENERICATTRIBUTE15, --CONTABILIZA
		CRED.GENERICATTRIBUTE13, --ENERGIA_COMPROMETIDA
		'Pte Enviar', --estado
		txn.linenumber, --line
		-- MPR - nuevos campos para informe
		TXN.SUBLINENUMBER, --para filtrar por gas o electrico
		TXN.PONUMBER AS NUM_CONTRATO,
		--CSPA.LASTNAME 
		case 
            when cred.name like 'CP%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as NOMBRE_PARTICIPANTE,
		TXN.GENERICATTRIBUTE3 AS ESTADO2,
		TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
		TXN.GENERICATTRIBUTE29 AS CIF,
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, 
		TXN.GENERICNUMBER10 AS CONSUMO_OBJETIVADO, 
		TXN.GENERICATTRIBUTE28 AS PRESION,
		TXN.GENERICATTRIBUTE6 AS CANAL_ENTRADA,
		TXN.GENERICATTRIBUTE15 AS TARIFA, 
		TXN.GENERICATTRIBUTE1 AS TIPO_PRODUCTO,
		TXN.GENERICATTRIBUTE11 AS TIPO_CONTRATO,
		TXN.GENERICATTRIBUTE13 AS LINEA_NEGOCIO, 
		cred.PAYEESEQ,
        cred.POSITIONSEQ,

		--MPR nuevos campos para rentabilidad
		TXN.GENERICATTRIBUTE20 AS CUARTIL,
		TXN.GENERICNUMBER15 AS VOLUMEN_NEGOCIADO,
		--TXN.GENERICATTRIBUTE24 AS COMPONENTE,
		CRED.GENERICATTRIBUTE6 AS COMPONENTE,
		TXN.PRODUCTID AS PRODUCTO, 
		
		TXN.TEX0_GENERICDATE7 AS FECHA_NEGOCIACION,
		TXN.TEX0_GENERICDATE13 AS FECHA_CONTRATO, 
		TXN.TEX0_GENERICNUMBER14 AS PRECIO_CERRADO,
		TXN.TEX0_GENERICNUMBER16 AS PRECIO_MINI_SD,
		TXN.TEX0_GENERICNUMBER13 AS PRECIO_MINI_RT,
		TXN.TEX0_GENERICNUMBER12 AS PRECIO_MINI_GESTOR,
		TXN.TEX0_GENERICNUMBER11 AS PRECIO_MINI_OBJETIVO,
		TXN.TEX0_GENERICBOOLEAN1 AS GESTION_CARTERA,
		TXN.TEX0_GENERICBOOLEAN3 AS RRAA,
		TXN.GENERICNUMBER2 AS VERSION,
		CRED.GENERICNUMBER1 AS DURACION,
		CRED.NAME,
		TXN.GENERICNUMBER5 AS MARGEN,
		TXN.PRODUCTNAME,
		case 
            when cred.name like 'CD%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as responsable,
		CSPO.GENERICATTRIBUTE9 AS FOBJETIVO,
		CRED.COMPENSATIONDATE AS FECHA_LIQUIDACION,
		CRED.GENERICDATE1 AS FECHA_PUBLI,
		CRED.NAME,
		TXN.GENERICATTRIBUTE30 AS TIPO_POSICION,
		CSPO.GENERICATTRIBUTE1 as TIPO_PRESTADOR,
		TXN.GENERICNUMBER7 AS PRECIO_MAXIMO, --RMM
	    TXN.GENERICNUMBER6 AS PRECIO_OBJETIVO_3, --RMM
        TXN.GENERICATTRIBUTE31 AS GRP_EMP,
        TXN.GENERICATTRIBUTE23 AS CAMPANA,
        TXN.GENERICATTRIBUTE32 AS LOTE,
        TXN.GENERICNUMBER1 AS DURAC_CONTR,

--RMM
        TXN.TXN_GENERICATTRIBUTE20 AS FRCC
  
	from enel_credit_temp_ofv cred
		inner join enel_txn_temp_ofv txn
			on txn.salestransactionseq = cred.salestransactionseq
			and txn.tenantid = cred.tenantid
			and txn.periodseq = cred.periodseq
			and txn.eventypeid = 'OFV Rentabilidad'
			AND TXN.SUBLINENUMBER = 1 -- para volumen electrico
			and txn.processingunitseq = 38280596832649418
			
		inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = V_EOT
			and cspe.tenantid = itenantId
		
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = V_EOT
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'
		
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = V_EOT
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
			-- MPR se comenta y se controla duplicidad por fecha startdate.
			--and CSPO.NAME IN (SELECT NAME FROM CS_POSITION WHERE REMOVEDATE = V_EOT and tenantId = itenantId GROUP BY NAME HAVING COUNT(*) < 2)
	WHERE  
		(cred.name like 'CD - OFV - Rentabilidad El%ctrica - %' or cred.name like 'CP - OFV - Rentabilidad El%ctrica - %')
	;
            
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDITOS_FINAL_V_RENTA: '|| to_char(filas) || ' filas.', v_contador_debug);

    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDITOS_FINAL_V_RENTA',v_contador_debug);
end;

procedure p_comprobacion_B2B (iperiod IN VARCHAR2)
AS
begin
	w_debug('Insertando datos en tabla ENEL_COMPROBACION_B2B.' ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_COMPROBACION_B2B(FECHA_ESCRITURA, PERIODO_LANZADO, LINEA_OK)
	SELECT 
		TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI'),
		iperiod,
		'ACTUALIZADO'
	FROM DUAL;
       
	filas := sql%rowcount;
	COMMIT;

	w_debug('Fin Carga de la tabla ENEL_COMPROBACION_B2B: '|| to_char(filas) || ' filas.', v_contador_debug);
	
    EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_COMPROBACION_B2B COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMPROBACION_B2B',v_contador_debug);
end;

/* *****************************
*********** RUN ****************
***************************** */

PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,
				periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,
                stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,
                salidacontrol out varchar2,informe varchar2 ) IS

	v_Interfaz_Proceso  nvarchar2(50);  
	v_Listado_Informes  nvarchar2(500);
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
            WHEN 'Post__'    then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST';
            WHEN 'Pay__'     then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_PAY';
            when 'Ficheros__' then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_FICHEROS';
            ELSE 	
				BEGIN
                    w_debug('stage '||stage||' No contemplado. Salimos...', v_contador_debug);
                    RETURN;
                END;
		end CASE;

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

	if(stage='Ficheros__') then	
        p_Medidas_Final( period ,periodSeq , tenantId , STAGE );
		p_Medidas_Final_PSVA ( period ,periodSeq , tenantId , STAGE );
        p_Medidas_Final_Volumen( period ,periodSeq , tenantId , STAGE );
		p_Medidas_Final_Vol_Gas( period ,periodSeq , tenantId , STAGE );
		p_Medidas_Final_V_Renta( period ,periodSeq , tenantId , STAGE );
		p_Medidas_Consecucion_Temp ( period ,periodSeq , tenantId , STAGE );
		p_Medidas_Consecucion_Final ( period ,periodSeq , tenantId , STAGE );
		p_comprobacion_B2B( period );
		

		-- Actualizamos reports -- cuando se genera ficheros no se actualizan los reports
		--p_Creditos_Final( period ,periodSeq , tenantId , STAGE );
		--p_Creditos_Final_psva( period ,periodSeq , tenantId , STAGE );
		--p_Creditos_Final_Volumen( period ,periodSeq , tenantId , STAGE );
		--p_Creditos_Final_Vol_Gas( period ,periodSeq , tenantId , STAGE );
		--p_Creditos_Final_V_Renta( period ,periodSeq , tenantId , STAGE );
		--p_Actualiza_Informe_Fecha ( period, 'OFV'); 
			
		-- Actualizamos la fecha del informes en la tabla 
        p_Actualiza_Informe_Fecha ( period, 'OFV_FICHERO');  

	else
		-- Se comprueba si el periodo Ya ha sido liquidado. 
		v_PeriodoLiquidado := f_ComprobarPeriodoLiquidado( processingUnitSeq, period ,periodSeq , tenantId  );
	
		-- SI EL PERIODO NO SE HA LIQUIDADO, SE EXTRAEN DE NUEVO LOS DATOS PARA LOS INFORMES      
		IF  v_PeriodoLiquidado = false THEN
			------------------------------------------------------------
            -- Datos Generales que se usan en varios informes
            ------------------------------------------------------------

			-- Volcar datos de las tablas de transacciones a una tabla temporal. Tabla ENEL_TXN_TEMP
			p_Temporal_Transacciones ( processingUnitSeq, period ,periodSeq , tenantId  );
			-- Volcar datos de la tabla de creditos a una tabla temporal. Tabla ENEL_CREDIT_TEMP
			p_Temporal_Creditos ( processingUnitSeq, period ,periodSeq , tenantId  );
			-- Volcar datos de la tabla de incentivos a una tabla temporal. Tabla ENEL_INCEN_TEMP
			p_Temporal_Incentivos ( processingUnitSeq, period ,periodSeq , tenantId  );
			-- Volcar datos de la tabla de Depositos a una tabla temporal. Tabla ENEL_DEPOSIT_TEMP
			p_Temporal_Depositos ( processingUnitSeq, period ,periodSeq , tenantId  );

			p_Temporal_Medidas ( processingUnitSeq, period ,periodSeq , tenantId  );
	
			-- Volcar datos de clasificacion a una Temporal de Proveedores. Tabla ENEL_PROVEEDORES_TEMP
			p_Temporal_Proveedores ( period ,periodSeq , tenantId  );
			-- Volcar datos de clasificacion a una Temporal de Equipamientos Tabla ENEL_EQUIPAMIENTO_TEMP        
			p_Temporal_Equipamientos ( period ,periodSeq , tenantId  );
			-- Volcar datos de Posiciones y participantes a una Temporal de PDS. Tabla: ENEL_PDS_TEMP
			p_Temporal_Pds ( processingUnitSeq, period ,periodSeq , tenantId  );
			-- Volcar datos de clasificacion a una Temporal de Operaciones Tabla ENEL_OPERACIONES_TEMP        
			p_Temporal_Operaciones ( period ,periodSeq , tenantId  );   
			-- Volcar datos de Productos a una Temporal Tabla ENEL_PRODUCTOS_TEMP   
			p_Temporal_Productos ( period ,periodSeq , tenantId  );

			-- Primero actualizamos reports
			p_Creditos_Final( period ,periodSeq , tenantId , STAGE );
			p_Creditos_Final_psva( period ,periodSeq , tenantId , STAGE );
			p_Creditos_Final_Volumen( period ,periodSeq , tenantId , STAGE );
			p_Creditos_Final_Vol_Gas( period ,periodSeq , tenantId , STAGE );
			p_Creditos_Final_V_Renta( period ,periodSeq , tenantId , STAGE );
            
            p_OFV_Crecimiento ( period ,periodSeq , tenantId , STAGE ); --APM 10.05.2022
            P_OFV_Leads ( period ,periodSeq , tenantId , STAGE ); --RMM 10.05.2022
			-- Actualizamos la fecha del infrmes en la tabla 
			p_Actualiza_Informe_Fecha ( period, 'OFV');  
			
			-- Luego se actualizan ficheros
			p_Medidas_Final( period ,periodSeq , tenantId , STAGE );
			p_Medidas_Final_PSVA ( period ,periodSeq , tenantId , STAGE );
			p_Medidas_Final_Volumen( period ,periodSeq , tenantId , STAGE );
			p_Medidas_Final_Vol_Gas( period ,periodSeq , tenantId , STAGE );
			p_Medidas_Final_V_Renta( period ,periodSeq , tenantId , STAGE );
			p_Medidas_Consecucion_Temp ( period ,periodSeq , tenantId , STAGE );
			p_Medidas_Consecucion_Final ( period ,periodSeq , tenantId , STAGE );
			
			p_comprobacion_B2B( period );
            

					
		ELSE
			w_debug('Periodo YA Liquidado. NO se actualizan Datos de INFORMES', v_contador_debug);
		end if;
	end if;

    w_debug('Procedure END', v_contador_debug);
    salidacontrol :='Procedure '||v_Interfaz_Proceso||' END';

    COMMIT;    

END;
-- RMM - 10.05.2022 -  BOM - Nuevas tablas para los nuevos informes de OFV
Procedure p_OFV_Leads ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2 ) 
AS
	v_periodstartdate date;
	v_periodenddate date;
begin

  w_debug('Inicio Truncado de la tabla ENEL_LEADS_TEMP_OFV.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_LEAD_TEMP_OFV WHERE periodo=iperiod and ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_LEADS_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_LEADS_TEMP_OFV. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

  INSERT INTO ENELEXT.ENEL_LEAD_TEMP_OFV( TENANTID, PERIODSEQ, PERIODO, ANIO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, FOBJETIVO, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, ACCOUNTINGDATE, 
                                        PROCESSINGUNITSEQ, NOMBRE_PARTICIPANTE, RAZON_SOCIAL, ESTADO_ACTUAL, contabiliza, comentario, 
                                        NOMBRE_REGLA, RESPONSABLE, --APM 05.07.2022 Nuevos campos
                                        PAYEESEQ, POSITIONSEQ, --APM 08.08.2022
                                        NOMBRE_OPP, TIPO , SUBTIPO_PRD, COD_OPP, CIF, -- RMM 31.01.2023
                                        PRODUCT_ID -- APM 01.02.2023
									    )



	SELECT 
        TXN.TENANTID ,
        cspe.periodseq,
	    cspe.name,
        TO_CHAR(CSPE.STARTDATE,'YYYY'), --anio
     	TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		txn.orderid, --id_ref
        CSPO.GENERICATTRIBUTE9 AS FOBJETIVO, --ficha objetivo
		TXN.LINENUMBER,
		TXN.SUBLINENUMBER,
        txn.eventypeid,
		TXN.COMPENSATIONDATE,
		TXN.ACCOUNTINGDATE,  -- Fecha que indica el ciclo de facturacion
		TXN.PROCESSINGUNITSEQ,
        /*APM 06.07.2022 BOM */ 
        --case  when cred.name like 'CP%' then cred.genericattribute2
        case  when cred.name like 'CP%' then cred.genericattribute10
        /*APM 05.07.2022 EOM*/
         else CSPA.LASTNAME
        end as NOMBRE_PARTICIPANTE,
		TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
		TXN.GENERICATTRIBUTE3 AS ESTADO_ACTUAL,
        txn.value as contabiliza,
        --txn.TXN_COMMENTS as comentario,
        cred.GENERICATTRIBUTE13 as comentario, --APM 06.07.2022
        cred.name as NOMBRE_REGLA, --APM 05.07.2022
        case 
            when cred.name like 'CD%' then cred.genericattribute10
            else CSPA.LASTNAME
        end as responsable,
        --APM 08.08.2022 BOM
            cred.PAYEESEQ,
            cred.POSITIONSEQ,
        --APM 08.08.2022 EOM
        --BOM - RMM 31.01.2023
         cred.genericattribute3 as NOMBRE_OPP, 
         TXN.GENERICATTRIBUTE1 as TIPO , 
         TXN.SUB_PRD as SUBTIPO_PRD, 
         TXN.COD_OPP as COD_OPP, 
         TXN.GENERICATTRIBUTE29 as CIF,
        --EOM - RMM 31.01.2023
         TXN.PRODUCTID AS PRODUCT_ID --APM 01.02.2023
        
     from enel_credit_temp_ofv cred
			inner join enel_txn_temp_ofv txn
				on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
				and txn.eventypeid = 'OFV Oportunidades Ganadas'
				AND TXN.SUBLINENUMBER = 1 --electrico
				and txn.processingunitseq = 38280596832649418	
			inner join cs_period cspe
				on cred.periodseq=cspe.periodseq
				and cspe.removedate = v_eot
				and cspe.tenantid = itenantId
			inner join cs_participant cspa 
				on cred.payeeseq=cspa.payeeseq
				and cspa.removedate = v_eot
				and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
				and cspa.tenantid = itenantId
				and cspa.payeeseq <> '4503599627373822'
			inner join cs_position cspo
				on cred.positionseq=cspo.ruleelementownerseq
				and cspo.removedate = v_eot
				and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
				and cspo.tenantid = itenantId
				and cspo.ruleelementownerseq <> '4785074604087002'
            
        /*APM 05.07.2022 BOM */    
        where
            cred.name like '%OFV%N%mero Leads%'
        ORDER by 
		txn.orderid --id_ref

        /*APM 05.07.2022 EOM*/
                ;

    filas := sql%rowcount;
    COMMIT; 

    w_debug('Fin Carga de la tabla ENEL_LEAD_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LEAD_TEMP_OFV.',v_contador_debug);
end;

procedure p_OFV_Crecimiento ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , ISTAGE IN VARCHAR2 )
AS
	v_periodstartdate date;
	v_periodenddate date;
begin
    w_debug('Inicio Truncado de la tabla ENEL_CRECIMIENTO_TEMP_OFV.', v_contador_debug);
    BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_CRECIMIENTO_TEMP_OFV WHERE periodo=iperiod and ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_CRECIMIENTO_TEMP_OFV.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRECIMIENTO_TEMP_OFV. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

    INSERT INTO ENELEXT.ENEL_CRECIMIENTO_TEMP_OFV(TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, ACCOUNTINGDATE, 
                                        PROCESSINGUNITSEQ, RESPONSABLE, NOMBRE_PARTICIPANTE, GRUPO_EMPRESARIAL, CONSUMO_ESTIMADO, RAZON_SOCIAL, CIF, CUPS, CUPS_INICIAL,
                                        VOL_CUPS, ESTADO_ACTUAL, TIPO_NEGOCIACION, NOMBRE_REGLA, anio, FOBJETIVO,
                                        PAYEESEQ, POSITIONSEQ) --APM 08.08.2022
									
	SELECT 
       TXN.TENANTID ,
        cspe.periodseq,
	    cspe.name,
       
     	TXN.SALESORDERSEQ,
		TXN.SALESTRANSACTIONSEQ,
		txn.orderid, --id_ref
       		TXN.LINENUMBER,
		TXN.SUBLINENUMBER,
        txn.eventypeid,
		TXN.COMPENSATIONDATE,
		TXN.ACCOUNTINGDATE,  -- Fecha que indica el ciclo de facturacion
		TXN.PROCESSINGUNITSEQ,
		
		case 
            when cred.name like 'CD%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as responsable,

		case 
            when cred.name like 'CP%' then cred.genericattribute2
            else CSPA.LASTNAME
        end as NOMBRE_PARTICIPANTE,

		TXN.TXN_GENERICATTRIBUTE26 AS GRUPO_EMPRESARIAL, --grupo empresarial
		--TXN.GENERICNUMBER9 AS CONSUMO_ESTIMADO, --vol_ge_inicial
        TRIM(to_char(TXN.GENERICNUMBER9 , '9999999999990D99')) AS CONSUMO_ESTIMADO, --APM 30.06.2022
		TXN.GENERICATTRIBUTE27 AS RAZON_SOCIAL,
		TXN.GENERICATTRIBUTE29 AS CIF,
		TXN.ALTERNATEORDERNUMBER AS CUPS,
		TXN.GENERICATTRIBUTE10 AS CUPS_INICIAl, -- tipo contrato??
		CRED.VALUE AS VOL_CUPS,
		TXN.GENERICATTRIBUTE3 AS ESTADO_ACTUAL,
    --APM 29.06.2022 BOM
		--CRED.GENERICATTRIBUTE12 AS TIPO_NEGOCIACION, -- modalidad pago??
        TXN.GENERICATTRIBUTE11 AS TIPO_NEGOCIACION, -- modalidad pago??
    --APM 29.06.2022 EOM
        cred.name,
         TO_CHAR(CSPE.STARTDATE,'YYYY'),
          CSPO.GENERICATTRIBUTE9 AS FOBJETIVO, --ficha objetivo
    --APM 08.08.2022 BOM
        cred.PAYEESEQ,
        cred.POSITIONSEQ
    --APM 08.08.2022 EOM
         
        from enel_credit_temp_ofv cred
		inner join    ENEL_TXN_TEMP_OFV  txn --cs_SALEStransaction 
 		
		      
            	on txn.salestransactionseq = cred.salestransactionseq
				and txn.tenantid = cred.tenantid
				and txn.periodseq = cred.periodseq
	            and txn.processingunitseq = 38280596832649418  
                and TXN.SUBLINENUMBER = 1 -- para volumen electrico
           --	and txn.eventypeid = 'OFV Rentabilidad'
			--	and txn.eventypeid='OFV Visitas'
			


	inner join cs_period cspe
			on cred.periodseq=cspe.periodseq
			and cspe.removedate = v_eot
			and cspe.tenantid = itenantId
		
		inner join cs_participant cspa 
			on cred.payeeseq=cspa.payeeseq
			and cspa.removedate = v_eot
			and cspe.startdate +1  between cspa.effectivestartdate and cspa.effectiveenddate
			and cspa.tenantid = itenantId
			and cspa.payeeseq <> '4503599627373822'
			
		inner join cs_position cspo
			on cred.positionseq=cspo.ruleelementownerseq
			and cspo.removedate = v_eot
			and cspe.startdate +1  between cspo.effectivestartdate and cspo.effectiveenddate
			and cspo.tenantid = itenantId
			and cspo.ruleelementownerseq <> '4785074604087002'
        where cred.name like 'C% - OFV - Cto Volumen Clientes menor 30%'; --RMM 29/07/2022 incluimos filtro para CD Y CP

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRECIMIENTO_TEMP_OFV: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRECIMIENTO_TEMP_OFV.',v_contador_debug);

end;
-- RMM - 19.05.2022 - EOM
END;