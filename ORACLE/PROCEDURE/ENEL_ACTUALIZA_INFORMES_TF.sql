create or replace PACKAGE BODY ENEL_ACTUALIZA_INFORMES_TF as
/* *****************************************************************************

	REVISIONS:
	Ver      		Date        	Author           	Description
	---------  		----------  	---------------  	-----------------------------------
    
	2.0				22/03/2022		DCR	                Portada. Nuevo campo WBE
    
    2.1             03/06/2022      DCR                 CAL0154 Quitar altas contratos
    
    2.2             12/01/2023      RMM                 CAL0264 Filtrar por la actividad en E4E para que no recupere las Renovaciones
    
    2.3             15/05/2023      DCR                 Evitar cierres de otras PUs
    
    2.4             11/01/2024      APM                 Modificar el valor de la varible v_txtYear para el informe
                                                        0.Administracion_11.Informe E4E Negativos_TF por petición de Pau.
	
    2.5             07/03/2024      APM                 Se añaden nuevos campos para Evolutivo CPs - Provincia y Apliación Incentivo CPs.
    
    2.6             11/04/2024      APM                 Se añade nuevo campo CUPS en la tabla ENEL_LIQSCAWEB_FINAL_TF para los informes: 
2.Actividad TF_05.Cuadre de Liquidación_Speed_Lead_VR, 2.Actividad TF_05.Cuadre de Liquidación_AAFF y 2.Actividad TF_05.Cuadre de Liquidación_Corner_TW

    2.7             22/04/2024      APM                 Se añade nuevo tipo de evento, de cálculo y proveedores para los informes: 
2.Actividad TF_05.Cuadre de Liquidación_Corner_TW, 0.Administracion_10.Informe General Proveedores_TF, 0.Administracion_09.Informe Balance_Callidus - E4E_TF,
0.Administracion_07.Informe E4E Captacion_TF, 2.Actividad TF_06.Prefactura-Portada y 2.Actividad TF_06.Prefactura-Detalle
  
    2.8             15/05/2024      APM                 Se añade nuevo campo Tarifa en la tabla ENEL_LIQSCAWEB_FINAL_TF para el informe: 2.Actividad TF_05.Cuadre de Liquidación_Speed_Lead_VR 
y 2.Actividad TF_05.Cuadre de Liquidación_Corner_TW  

    2.9             27/06/2024      APM                 Se añaden nuevos tipos de evento y cálculo: RETAIL EE
    
    2.10            16/12/2024      APM                 Nuevos informes de Ricorrente. Aplica a la BU de Agentes Comerciales (VR, TF , TW y AAFF)

    2.11            14/05/2025      APM                 Nueva tabla ENEL_CRE_RICORRENTE_DIAS_TF para VR - Nuevo informe 2.Actividad VR_00.Ricorrente_Dias
	
    2.12            20/05/2025      APM                 Se añade nuevo filtro en la tabla ENEL_RAPPELES_TF.
                                                        Nueva tabla para pestaña 'Renovacion Speed Lead – Importe Base' del informe 2.Actividad TF_05.Cuadre de Liquidación_Speed_Lead_VR
                                                        Nuevos campos en las tablas: ENEL_LIQSCAWEB_FINAL_TF (INCENTIVO_OFERTA y TIENDA) y ENEL_TXN_TEMP_TF (GENERICATTRIBUTE25)
    
    2.13            03/06/2025      APM                 Nuevo filtro en la tabla ENEL_TM2_MENSUAL_TF para Retail TF.
    
    2.14            03/07/2025      APM                 Añadir campo COSTE para informe 2.Actividad TF_05.Cuadre de Liquidación_Speed_Lead_VR
    
    2.15            16/07/2025      APM                 Añadir campo TXN.GENERICDATE4 en la tabla ENEL_LIQSCAWEB_FINAL_TF
    
    2.16            03/12/2025      APM                 Nuevas tablas para Informe Agrupado de liquidaciones  

    2.17            15/12/2025      APM                 Se añade proveedor 287 y 288 en la tabla ENEL_CRE_RICORRENTE_DIAS_TF
    
    2.18            18/12/2025      APM                 Tabla ENEL_RAPPELES_TF -> se añade filtro OR CSI.NAME LIKE 'I - Captacion VR - Ricorrente -%'
                                                        Tabla ENEL_CRE_RICORRENTE_DIAS_TF -> Se añaden 2 nuevos campos.
    
    2.19            19/12/2025      APM                 Tabla ENEL_CRE_RICORRENTE_DIAS_TF -> Se realiza update del campo FECHA_ACTIVACION
                                                        Tablas ENEL_TM2_MENSUAL_TF y ENEL_TM12_MENSUAL_TF -> Se añade campo MOTIVO_SOLICITUD
                                                        
    2.20            09/01/2026      APM                 Nuevo campo GRUPO_RETRIBUCION en la tabla ENEL_DEPOSIT_AGRUPADO.
    
    2.21            16/03/2026      APM                 Nuevos campos de fechas en el informe 2.Actividad TF_05.Cuadre de Liquidación_AAFF y 2.Actividad TF_05.Cuadre de Liquidación_Retail_TF

    2.22            25/03/2026      APM                 Se añaden filtros para los informes de Stands.
    
    2.23            28/04/2026      APM                 Se añade filtro en la tabla ENEL_TM2_MENSUAL_TF y ENEL_TM12_MENSUAL_TF
    
    2.24            19/05/2026      APM                 Se añaden filtros en la tabla ENEL_FACTTF_DETALLE, enel_rappeles_tf y ENEL_RAPPELES_WBE de Activación
***************************************************************************** */

v_eot date := to_date('22000101','YYYYMMDD');
	v_contador_debug integer;
    v_contador_ctrl_inf integer; --MIO 10.03.2023
    v_num_ejecucion integer;
    v_finicio timestamp;
    v_ffin timestamp;
    v_classifierid         	CS_CLASSIFIER.classifierid%TYPE;
    v_DESCRIPCION        	CS_CLASSIFIER.DESCRIPTION%TYPE;
    v_STAGE                	CS_GENERICCLASSIFIER.Genericattribute1%TYPE;
    v_SECUENCIA            	CS_GENERICCLASSIFIER.Genericattribute2%TYPE;
    v_ARGUMENTOS        	CS_GENERICCLASSIFIER.Genericattribute3%TYPE;
    v_PERIODICIDAD        	CS_GENERICCLASSIFIER.Genericattribute4%TYPE;
    v_ACTIVO            	CS_GENERICCLASSIFIER.Genericboolean1%TYPE;
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
    
    w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP_TF.', v_contador_debug);

    w_debug('Cargando tabla ENEL_TXN_TEMP_TF. Periodo:'|| iperiod ,  v_contador_debug);
	v_periodstartdate :=  f_fecha_inicio(iperiodseq);
	v_periodenddate := f_Ultimo_Dia_Periodo(iperiodseq);

	INSERT INTO ENELEXT.ENEL_TXN_TEMP_TF( TENANTID, PERIODSEQ, PERIODO, SALESORDERSEQ, SALESTRANSACTIONSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTYPEID, COMPENSATIONDATE, 
										ACCOUNTINGDATE, PRODUCTID, GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, 
										GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, 
										GENERICATTRIBUTE14, GENERICATTRIBUTE15, GENERICATTRIBUTE16, GENERICATTRIBUTE17, GENERICATTRIBUTE18,GENERICATTRIBUTE19, GENERICATTRIBUTE20, 
                                        GENERICATTRIBUTE21, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICDATE3, GENERICDATE4, GENERICDATE5, GENERICBOOLEAN2, 
                                        PONUMBER, DATASOURCE, TAD_ADDRESS1, TAD_CITY, TAD_STATE, TAD_POSTALCODE, TAD_INDUSTRY, TAD_GEOGRAPHY, TAS_POSITIONNAME, 
										TAS_GENERICATTRIBUTE1, TAS_GENERICATTRIBUTE2, TAS_GENERICNUMBER1, TAS_GENERICNUMBER2, TEX0_GENERICATTRIBUTE3, TEX0_GENERICATTRIBUTE4, TEX0_GENERICATTRIBUTE5, 
										TEX0_GENERICATTRIBUTE6, TEX0_GENERICATTRIBUTE7, TEX0_GENERICATTRIBUTE8, TEX0_GENERICATTRIBUTE9, TEX0_GENERICATTRIBUTE10, 
										TEX0_GENERICATTRIBUTE11, TEX0_GENERICATTRIBUTE12, TEX0_GENERICATTRIBUTE13, TEX0_GENERICATTRIBUTE14, TEX0_GENERICATTRIBUTE15, 
                                        TEX0_GENERICATTRIBUTE16, TEX0_GENERICATTRIBUTE17, TEX0_GENERICDATE3, TEX0_GENERICDATE4, TEX0_GENERICBOOLEAN1, 
                                        TEX0_GENERICNUMBER1, TEX0_GENERICNUMBER2, TEX0_GENERICNUMBER3, TEX0_GENERICNUMBER4, TEX0_GENERICNUMBER5,PROCESSINGUNITSEQ, ALTERNATEORDERNUMBER,GENERICDATE6,
                                        PRODUCTNAME,COSTE, GENERICATTRIBUTE24, GENERICATTRIBUTE25, FECHA_ACTIVACION) --APM 15.05.2024
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
        etxn0.GENERICATTRIBUTE3 as MotivoBaja,
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
		TXN.ALTERNATEORDERNUMBER AS CUPS,
        TXN.GENERICDATE6 AS GENERICDATE6,
        TXN.PRODUCTNAME, --APM 15.05.2024
        TXN.GENERICNUMBER6 as COSTE, --DMS17.06.2024
        TXN.GENERICATTRIBUTE24, --APM 17.09.2024
        TXN.GENERICATTRIBUTE25, --APM 14.05.2025
        /*BOM APM 16.03.2026*/
        TXN.GENERICDATE6 AS FECHA_ACTIVACION 
        /*EOM APM 16.03.2026*/
        
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
/*	
	WHERE  PER.TENANTID =  itenantId
		AND PER.REMOVEDATE = v_eot 
		AND PER.PERIODSEQ = iperiodseq;
*/

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TXN_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TXN_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TXN_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TXN_TEMP_TF.',v_contador_debug);
    
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
    
    w_debug('Inicio Truncado de la tabla ENEL_CREDIT_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_CREDIT_TEMP_TF';
	w_debug('Fin Truncado de la tabla ENEL_CREDIT_TEMP_TF.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CREDIT_TEMP_TF. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_CREDIT_TEMP_TF( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, NAME, CREDITSEQ, SALESORDERSEQ, SALESTRANSACTIONSEQ, PAYEESEQ, 
											POSITIONSEQ, COMPENSATIONDATE, COMMENTS, CREDITTYPEID, CREDITTYPEDESCRIPT, VALUE, PREADJUSTEDVALUE, GENERICATTRIBUTE1, GENERICATTRIBUTE2, 
											GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE5, GENERICATTRIBUTE6, GENERICATTRIBUTE7, GENERICATTRIBUTE8, GENERICATTRIBUTE9, 
											GENERICATTRIBUTE10, GENERICATTRIBUTE11, GENERICATTRIBUTE12, GENERICATTRIBUTE13, GENERICATTRIBUTE14,GENERICATTRIBUTE15, GENERICBOOLEAN1, 
											GENERICBOOLEAN2, GENERICDATE1, GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, BU_NAME, GENERICNUMBER4, GENERICDATE2 )
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
		CTYPE.DESCRIPTION,             -- Tipo de Comisión
		credit.VALUE,                  --Importe Comision
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
		credit.GENERICATTRIBUTE15,     --Observaciones Ajustes Manuales
		credit.GENERICBOOLEAN1,         --Incluir_En_Pagos
		credit.GENERICBOOLEAN2,        -- S/S Garantía
		credit.GENERICDATE1,           --FechaCalculo
		credit.GENERICNUMBER1,
		credit.GENERICNUMBER2,
		credit.GENERICNUMBER3,
		bu.name,
		credit.GENERICNUMBER4,
        credit.GENERICDATE2 --APM 16.03.2026

	FROM CS_CREDIT credit
		INNER JOIN CS_PLRUN p ON CREDIT.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                                             
		INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
		
		INNER JOIN CS_BUSINESSUNIT bu on credit.businessunitmap = bu.mask
			and bu.tenantId = itenantId
			and bu.processingUnitSeq = credit.processingUnitseq
	
	WHERE
		credit.TENANTID = itenantId 
		AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND credit.PERIODSEQ =  iperiodseq; 

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CREDIT_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CREDIT_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_CREDIT_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CREDIT_TEMP_TF.',v_contador_debug);

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

    w_debug('Inicio Truncado de la tabla ENEL_INCEN_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_INCEN_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_INCEN_TEMP_TF.', v_contador_debug);

    w_debug('Cargando tabla ENEL_INCEN_TEMP_TF. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_INCEN_TEMP_TF(  TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, INCENTIVESEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE,
                                           GENERICATTRIBUTE1, GENERICATTRIBUTE2, GENERICATTRIBUTE3, GENERICATTRIBUTE4, GENERICATTRIBUTE16, 
                                           GENERICNUMBER1, GENERICNUMBER2, GENERICNUMBER3, GENERICNUMBER4, GENERICNUMBER5, GENERICNUMBER6, 
                                           GENERICBOOLEAN1, GENERICDATE1, GENERICDATE2,GENERICATTRIBUTE7, BU_NAME  )
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
		incent.GENERICATTRIBUTE1,      -- Concepto Liquidación
		incent.GENERICATTRIBUTE2,      -- Proveedor
		incent.GENERICATTRIBUTE3,      -- Descripción
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
		incent.GENERICDATE2,           --Fecha Final            
		incent.GENERICATTRIBUTE7, 		--wbe
		bu.name
		
	FROM CS_INCENTIVE incent
		INNER JOIN CS_PLRUN p ON incent.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
		
		INNER JOIN CS_BUSINESSUNIT bu on incent.businessunitmap = bu.mask
			and bu.tenantId = itenantId
			and bu.processingUnitSeq = incent.processingUnitseq
			
	WHERE
		incent.TENANTID = itenantId 
		AND incent.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND incent.PERIODSEQ =  iperiodseq
		and incent.genericattribute1 is not null;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_INCEN_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_INCEN_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_INCEN_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_INCEN_TEMP_TF.',v_contador_debug);

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

    w_debug('Inicio Truncado de la tabla ENEL_DEPOSIT_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_TF';
	w_debug('Fin Truncado de la tabla ENEL_DEPOSIT_TEMP_TF.', v_contador_debug);

    w_debug('Cargando tabla ENEL_DEPOSIT_TEMP_TF. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_DEPOSIT_TEMP_TF( TENANTID, PERIODSEQ, PERIODO, PIPELINERUNSEQ, PIPELINERUNDATE, DEPOSITSEQ, PAYEESEQ, POSITIONSEQ, NAME, VALUE, 
                                            PREADJUSTEDVALUE, EARNINGCODEID, EARNINGGROUPID, COMMENTS, GENERICATTRIBUTE1, GENERICATTRIBUTE2, tipo_pago_ga5, 
											PROCESSINGUNITSEQ,wbe, BUSINESSUNITMAP )
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
		DEPO.PROCESSINGUNITSEQ,
		depo.EARNINGGROUPID, 
		DEPO.BUSINESSUNITMAP

	FROM CS_DEPOSIT depo
		INNER JOIN CS_PLRUN p ON depo.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
	WHERE
		depo.TENANTID = itenantId 
		AND depo.PROCESSINGUNITSEQ = iprocessingUnitSeq 
		AND depo.PERIODSEQ =  iperiodseq;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_DEPOSIT_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_DEPOSIT_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_DEPOSIT_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_DEPOSIT_TEMP_TF.',v_contador_debug);  
    
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

    w_debug('Inicio Truncado de la tabla ENEL_PROVEEDORES_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_PROVEEDORES_TEMP_TF.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PROVEEDORES_TEMP_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
	INSERT INTO ENELEXT.ENEL_PROVEEDORES_TEMP_TF( TENANTID,PERIODSEQ,IDPROVEEDOR,DESCRIPCION,DESCRIPCION_CORTA, FICHERO,CECO,
												WBE_FINAL_IMPUTACION,DETALLE_ACTIVIDAD,ACTIVIDAD,SOCIEDAD,
												CENTRO_LOGISTICO,GR_COMPRAS,TIPO_PAGO, ORG_VENTAS, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR, SUBACTIVIDAD)
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

    w_debug('Fin Carga de la tabla ENEL_PROVEEDORES_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PROVEEDORES_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PROVEEDORES_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PROVEEDORES_TEMP_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Proveedores', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Proveedores', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--------- Volcar datos de clasificaci?n a una Temporal de Proveedores. 
---------- Tabla ENEL_EQUIPAMIENTO_TEMP ----
procedure p_Temporal_Equipamientos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_EQUIPAMIENTO_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_EQUIPAMIENTO_TEMP_TF.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_EQUIPAMIENTO_TEMP_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_EQUIPAMIENTO_TEMP_TF( TENANTID,PERIODSEQ,EQUIPAMIENTO, IDMARCA, MARCA, IDMODELO, MODELO, IDTIPO,
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
		--AND C.ISLAST = 1
	INNER JOIN CS_GENERICCLASSIFIER GC ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
		--AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
		AND GC.TENANTID = itenantId
		AND GC.REMOVEDATE = v_eot
		AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
		AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
		--AND GC.ISLAST = 1            

	WHERE GCT.NAME ='Equipamiento';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_EQUIPAMIENTO_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Equipamientos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Equipamientos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);
        
end;

procedure p_Cabecera_Eco (iperiod in Varchar2)
AS
BEGIN

    v_finicio := current_timestamp();
    
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_ECO_FINAL_TF  WHERE PERIODO IS NULL AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
	
    INSERT INTO ENELEXT.ENEL_ECO_FINAL_TF (PERIODO,CANAL,ACTIVIDAD,SUBACTIVIDAD,IDPROVEEDOR,NAME,PDS,IMPORTE)
    VALUES('','Canal','Actividad','Subactividad','Proveedor','Desc. Proveedor','Payee','Importe Total (€)');
    
    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Eco', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Eco', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);
    
END;

procedure p_Eco_FINAL_TF ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iprocessingUnitSeq IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();
    
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_ECO_FINAL_tf WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    
    w_debug('Inicio Truncado de la tabla ENEL_ECO_FINAL_TF.', v_contador_debug);
    w_debug('Fin Truncado de la tabla ENEL_ECO_FINAL_TF.', v_contador_debug);
    
    p_Cabecera_Eco (iperiod);
    
    INSERT INTO ENELEXT.ENEL_ECO_FINAL_TF (PERIODO,CANAL,ACTIVIDAD,SUBACTIVIDAD,IDPROVEEDOR,NAME,PDS,IMPORTE)
    SELECT 
        CSP.NAME,
        CASE WHEN EDT.PROCESSINGUNITSEQ = 38280596832649318 THEN 'TF' END AS CANAL,
        ept.ACTIVIDAD,
        ept.subactividad,
        ept.IDPROVEEDOR,
        ept.DESCRIPCION,
        EPDS.PDS,
        TRIM(replace(to_char(sum(edt.VALUE) , '9999999999990D99'), ',', '.')) IMPORTE
            
	FROM ENEL_PROVEEDORES_TEMP_TF ept
		LEFT JOIN ENEL_DEPOSIT_TEMP_TF edt 
			ON EPT.IDPROVEEDOR = edt.EARNINGGROUPID

        LEFT JOIN ENEL_PDS_TEMP_TF epds
			ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
			AND EPDS.PAYEESEQ = edt.payeeseq
            
        INNER JOIN CS_PERIOD CSP
			ON CSP.PERIODSEQ=EDT.PERIODSEQ
            AND CSP.REMOVEDATE =v_eot         
    
	group by CSP.NAME,
		CASE WHEN EDT.PROCESSINGUNITSEQ = 38280596832649318 THEN 'TF' END,
		ept.actividad,
		ept.subactividad,
		ept.idproveedor,
		ept.descripcion,
		epds.pds
	;    

	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_ECO_FINAL_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_ECO_FINAL_TF.',v_contador_debug);
    
    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Eco_FINAL_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Eco_FINAL_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);
        
END;

procedure p_Temporal_Operaciones ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_OPERACIONES_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_OPERACIONES_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_OPERACIONES_TEMP_TF.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_OPERACIONES_TEMP_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_OPERACIONES_TEMP_TF( TENANTID, PERIODSEQ, OPERACIONID, TIPO_ENTRADA, TIPO_OPERACION, SUBTIPO_OPERACION, 
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
			--AND C.ISLAST = 1
        INNER JOIN CS_GENERICCLASSIFIER GC 
			ON C.CLASSIFIERSEQ = GC.CLASSIFIERSEQ
			--AND GC.EFFECTIVESTARTDATE <= PD.ENDDATE AND GC.EFFECTIVEENDDATE >= PD.ENDDATE
            AND GC.TENANTID = itenantId
            AND GC.REMOVEDATE = v_eot
            AND GC.EFFECTIVESTARTDATE <= v_ultimo_dia_periodo
            AND GC.EFFECTIVEENDDATE >= v_ultimo_dia_periodo              
			--AND GC.ISLAST = 1    

	WHERE GCT.NAME ='Operacion';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_OPERACIONES_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Operaciones', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Operaciones', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);
        
end;

procedure p_Temporal_E4E_Negativos_TF ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
		
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_TF_2 WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_E4E_NEGATIVOS_TEMP_TF.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Origen de ENEL_E4E_NEGATIVOS_TEMP_TF : CS_DEPOSIT.', v_contador_debug);
    -- Si se ejecuta en la FASE REWARD Utilizamos la tabla de depositos para generar los datos de las tablas porque aun no se han realizado los PAGOS
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_TF( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
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
		DEPO.tipo_pago_ga5, --------------
		TMP_PDS.FECHA_INI_VIGENCIA,
		-- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
		sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO

	FROM ENEL_DEPOSIT_TEMP_TF DEPO
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS 
			ON DEPO.payeeseq=TMP_PDS.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PDS.periodseq
			AND TMP_PDS.SUBCANAL is not null
			--(TMP_PDS.SUBCANAL='TF' or TMP_PDS.SUBCANAL='STAND')

	   INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
			AND DEPO.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
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

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_TF_2: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_TF_2.',v_contador_debug);
	
	w_debug('Origen de ENEL_E4E_NEGATIVOS_TEMP_TF_2 : CS_DEPOSIT.', v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_TF_2 ( PERIODSEQ,PERIODO, DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
													PAR_PROVEEDOR,NOMBRE_FISCAL, CIF, TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
													TEXTO_BREVE,ORG_COMPRAS,CODIGO_SERVICIO, IDPROVEEDOR, FICHERO, SOCIEDAD,CECO,
													DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION, ACTIVIDAD, DETALLE_ACTIVIDAD, TIPO_PAGO, 
													POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO,
                                                    TIPO_PRESTADOR) --APM 06.02.2025
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
		DEPO.tipo_pago_ga5, --------------
		TMP_PDS.FECHA_INI_VIGENCIA,
		-- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
		sum(CASE WHEN DEPO.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
        /*BOM APM 06.02.2025*/
        case 
			when BU.NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when BU.NAME not like 'RETAIL TF' then 'SI'
			else 'NO'
		end
        /*EOM APM 06.02.2025*/

	FROM ENEL_DEPOSIT_TEMP_TF DEPO
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS 
			ON DEPO.payeeseq=TMP_PDS.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PDS.periodseq
			AND TMP_PDS.SUBCANAL is not null
			--(TMP_PDS.SUBCANAL='TF' or TMP_PDS.SUBCANAL='STAND')

	   INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
			AND DEPO.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
			ON TMP_CONTRA.periodseq=DEPO.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
            
        /*BOM APM 06.02.2025*/
        INNER JOIN CS_BUSINESSUNIT BU 
			ON DEPO.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
        /*EOM APM 06.02.2025*/
            
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
		DEPO.wbe,
		TMP_PROV.ACTIVIDAD,
		TMP_PROV.DETALLE_ACTIVIDAD,           
		DEPO.TIPO_PAGO_GA5,
		TMP_PDS.FECHA_INI_VIGENCIA,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
        case 
			when BU.NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when BU.NAME not like 'RETAIL TF' then 'SI'
			else 'NO'
		end
	;
		  
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TEMP_TF_2: '|| to_char(filas) || ' filas.', v_contador_debug);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TEMP_TF_2.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_E4E_Negativos_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_E4E_Negativos_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--------- Volcar datos de Productos a una Temporal. 
---------- Tabla ENEL_PRODUCTOS_TEMP ----
procedure p_Temporal_Productos ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_ultimo_dia_periodo  date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_PRODUCTOS_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PRODUCTOS_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_PRODUCTOS_TEMP_TF.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_PRODUCTOS_TEMP_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_PRODUCTOS_TEMP_TF( TENANTID, PERIODSEQ, PRODUCTID, DESCRIPTION, NAME, FAMILIA, PROVEEDOR_PRESTACION, PROVEEDOR_CAPTACION, 
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

    w_debug('Fin Carga de la tabla ENEL_PRODUCTOS_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);

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

    w_debug('Inicio Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_E4E_CONTRATOS_TEMP_TF.', v_contador_debug);

    v_ultimo_dia_periodo := f_Ultimo_Dia_Periodo(iperiodseq);

    w_debug('Cargando tabla ENEL_E4E_CONTRATOS_TEMP_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId || ' Ult.Dia Period:' || v_ultimo_dia_periodo,  v_contador_debug);
      
	INSERT INTO ENELEXT.ENEL_E4E_CONTRATOS_TEMP_TF(TENANTID,PERIODSEQ,ID,PDS,ACTIVIDAD_DETALLADA,ACTIVIDAD, CIF,COD_CONTRATO,POS_DOC,TEXTO_BREVE,CODIGO_SERVICIO,
													ORG_COMPRAS,CONDICIONES_PAGO, FECHA_INICIO_VIGOR,FECHA_FIN_VIGOR)
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

	WHERE GCT.NAME ='Contrato'
	;

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_CONTRATOS_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_CONTRATOS_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_CONTRATOS_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_CONTRATOS_TEMP_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Contratos_E4E', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Contratos_E4E', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Temporal_Pds (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS  
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_PDS_TEMP_TF.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_PDS_TEMP_TF';
    w_debug('Fin Truncado de la tabla ENEL_PDS_TEMP_TF.', v_contador_debug);

    w_debug('Cargando tabla ENEL_PDS_TEMP_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);
      
	INSERT INTO ENELEXT.ENEL_PDS_TEMP_TF(   PERIODSEQ, RULEELEMENTOWNERSEQ, PAYEESEQ, PAYEEID, PDS, NOMBRE_FISCAL, CIF, NOMBRE_CUENTA, CALLE, COD_POSTAL, 
                                          PROVINCIA, POBLACION, TIPO_IMPOSITIVO, PAR_PROVEEDOR, CODIGODEUDOR, NOMBRE_COMERCIAL, IMPORTE_UB, FECHA_CONTRATACION, 
                                          TIPO_PRESTADOR, COMUNIDAD_AUTONOMA, TERRITORIO, ZONA, POS_NOMBRE_COMERCIAL, CANAL, SUBCANAL, DELEGACION, 
                                          BASE_COMISION, FECHA_INI_VIGENCIA,TERMINATIONDATE,TITLE_NAME,CANAL_CALCULOS,TIPO_POSICION, RESPONSABLE,
                                          APLICACION_INCEN_CP) --APM 07.03.2024 Evo CPs
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
	   POS.GENERICATTRIBUTE1 AS TIPO_PRESTADOR, --condición para nueva BU de Retail TF
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
	   (SELECT POSI.NAME FROM CS_POSITION POSI WHERE POSI.REMOVEDATE = v_eot AND POSI.RULEELEMENTOWNERSEQ = POS.MANAGERSEQ AND pos.TENANTID = itenantId AND posi.EFFECTIVESTARTDATE <= PER.ENDDATE - 1 AND posi.EFFECTIVEENDDATE >= PER.ENDDATE - 1 and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq) as RESPONSABLE,
       POS.GENERICBOOLEAN1 AS APLICACION_INCEN_CP --APM 07.03.2024 Evo CPs
		
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

    w_debug('Fin Carga de la tabla ENEL_PDS_TEMP_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PDS_TEMP_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PDS_TEMP_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PDS_TEMP_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Pds', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Pds', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Temporal_Depositos_E4E_TF ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz_Proceso  IN VARCHAR2)
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Truncado de la tabla ENEL_E4E_DEPOSIT_TF_TEMP.', v_contador_debug);
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP';
	EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP_2';
    w_debug('Fin Truncado de la tabla ENEL_E4E_DEPOSIT_TF_TEMP.', v_contador_debug);

    w_debug('Cargando tabla ENEL_E4E_DEPOSIT_TF_TEMP. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    -- Si se ejecuta en una FASE que no es REWARD Utilizamos la tabla de PAGOS
	w_debug('Origen de ENEL_E4E_DEPOSIT_TF_TEMP : CS_PAYMENT.', v_contador_debug);
             
    --MPR comentamos la carga antigua por pagos y cargamos por depósitos
/*             
	INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP(    PERIODSEQ,DEPOSITSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS,
                                                PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO,
                                                DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA,
												VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, BUSINESSUNIT  )
    Select
        PAYM.PERIODSEQ, 
        MAX(DEPO.DEPOSITSEQ),
        PAYM.POSITIONSEQ, 
        PAYM.PAYEESEQ, 
        PAYM.VALUE,
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
        --TMP_PROV.WBE_FINAL_IMPUTACION,
        paym.earninggroupid, 
        TMP_PROV.ACTIVIDAD,
        DEPO.TIPO_PAGO_GA5,        ---
        TMP_PDS.FECHA_INI_VIGENCIA,
        -- Se separa el valor de las operaciones de OCAPS para mostralo en el BALANCE
        sum(CASE WHEN PAYM.EARNINGGROUPID = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN PAYM.VALUE ELSE 0 END) as VALOR_OPERACIONES,-------
        TMP_PDS.CODIGODEUDOR,
        TMP_PDS.COMUNIDAD_AUTONOMA,
        TMP_PROV.ORG_VENTAS,
        TMP_CONTRA.CONDICIONES_PAGO,
        BU.NAME
          
	FROM CS_PAYMENT PAYM
		INNER JOIN CS_PLRUN p 
			ON PAYM.TRIALPIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
                  
		left join enel_deposit_temp_tf DEPO
			on  PAYM.payeeseq=DEPO.payeeseq 
			and DEPO.POSITIONSEQ=PAYM.POSITIONSEQ
			and depo.periodseq= paym.periodseq
			and DEPO.EARNINGCODEID = paym.EARNINGCODEID
			and depo.wbe = PAYM.EARNINGGROUPID
                                             
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS 
			ON PAYM.payeeseq=TMP_PDS.payeeseq 
			and PAYM.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and PAYM.periodseq=TMP_PDS.periodseq

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND PAYM.periodseq=TMP_PROV.periodseq

		--INNER JOIN ENEL_E4E_CONTRATOS_TEMP TMP_CONTRA  
		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
			ON TMP_CONTRA.periodseq=PAYM.periodseq
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq
 
		INNER JOIN CS_BUSINESSUNIT BU 
			ON PAYM.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
             
	WHERE PAYM.TENANTID = itenantId
		AND PAYM.periodseq=iperiodseq        
		AND PAYM.PROCESSINGUNITSEQ =  iprocessingUnitSeq
		and depo.tipo_pago_ga5 is not null
		--and TMP_PDS.SUBCANAL = 'TF'
		and length(PAYM.EARNINGGROUPID) >3
              
	GROUP BY 
		PAYM.VALUE,
		PAYM.PERIODSEQ, 
		PAYM.POSITIONSEQ, 
		PAYM.PAYEESEQ, 
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
		paym.EARNINGGROUPID,
		TMP_PROV.ACTIVIDAD,
		DEPO.TIPO_PAGO_GA5,       
		TMP_PDS.FECHA_INI_VIGENCIA,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
		BU.NAME;     
 */       
    INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,
												ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, 
												BUSINESSUNIT, TIPO_PRESTADOR  )
    Select
		depo.PERIODSEQ, 
		depo.POSITIONSEQ, 
		depo.PAYEESEQ, 
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
		sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN depo.VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
        BU.NAME,
		case 
			when BU.NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
            when BU.NAME like 'Stands' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when BU.NAME not like 'RETAIL TF' and BU.NAME not like 'Stands' then 'SI'
			else 'NO'
		end

	FROM  ENELEXT.enel_deposit_temp_tf DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_TF TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
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
		--and TMP_PDS.SUBCANAL = 'TF'
		--and length(PAYM.EARNINGGROUPID) >3
		and depo.value > 0  	

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
		BU.NAME,
		case 
			when BU.NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
            when BU.NAME like 'Stands' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when BU.NAME not like 'RETAIL TF' and BU.NAME not like 'Stands' then 'SI'
			else 'NO'
		end
		;   

	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_TF_TEMP: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_TF_TEMP',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

    --EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP.',v_contador_debug);
	
	w_debug('Cargando tabla ENEL_E4E_DEPOSIT_TF_TEMP_2. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

	w_debug('Origen de ENEL_E4E_DEPOSIT_TF_TEMP_2 : ', v_contador_debug);
                   
    INSERT INTO ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP_2( PERIODSEQ,POSITIONSEQ,PAYEESEQ,VALUE,PDS, PAR_PROVEEDOR,TIPO_IMPOSITIVO,COD_CONTRATO,POS_DOC,
                                                TEXTO_BREVE,ORG_COMPRAS, CODIGO_SERVICIO, IDPROVEEDOR,SOCIEDAD,CECO, DESCRIPCION,GR_COMPRAS,CENTRO_LOGISTICO,WBE_FINAL_IMPUTACION,
												ACTIVIDAD, TIPO_PAGO, POS_FECHA_INI_VIGENCIA, VALOR_OPERACIONES, CODIGODEUDOR,COMUNIDAD_AUTONOMA, ORG_VENTAS,CONDICIONES_PAGO, 
												BUSINESSUNIT, TIPO_PRESTADOR  )
    Select
		depo.PERIODSEQ, 
		depo.POSITIONSEQ, 
		depo.PAYEESEQ, 
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
		sum(CASE WHEN depo.wbe = '050' and TMP_PDS.TIPO_POSICION = 'OCAP' THEN depo.VALUE ELSE 0 END) as VALOR_OPERACIONES,
		TMP_PDS.CODIGODEUDOR,
		TMP_PDS.COMUNIDAD_AUTONOMA,
		TMP_PROV.ORG_VENTAS,
		TMP_CONTRA.CONDICIONES_PAGO,
        BU.NAME,
		case 
			when BU.NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
            when BU.NAME like 'Stands' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when BU.NAME not like 'RETAIL TF' and BU.NAME not like 'Stands' then 'SI'
			else 'NO'
		end

	FROM  ENELEXT.enel_deposit_temp_tf DEPO				 
		INNER JOIN ENELEXT.ENEL_PDS_TEMP_TF TMP_PDS 
			ON depo.payeeseq=TMP_PDS.payeeseq 
			and depo.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and depo.periodseq=TMP_PDS.periodseq

		INNER JOIN ENELEXT.ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=depo.earninggroupid  
			AND depo.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENELEXT.ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
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
		--and TMP_PDS.SUBCANAL = 'TF'
		--and length(PAYM.EARNINGGROUPID) >3
		--and depo.value > 0         

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
		BU.NAME,
		case 
			when BU.NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
            when BU.NAME like 'Stands' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when BU.NAME not like 'RETAIL TF' and BU.NAME not like 'Stands' then 'SI'
			else 'NO'
		end
		;   
        
	filas := sql%rowcount;
	COMMIT;

    w_debug('Fin Carga de la tabla ENEL_E4E_DEPOSIT_TF_TEMP_2: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_DEPOSIT_TF_TEMP_2',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP_2 COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_DEPOSIT_TF_TEMP_2.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_E4E_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Depositos_E4E_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);
        
end;

procedure p_Cabecera_Ficheros_E4E_TF (  iperiod IN VARCHAR2, iFichero IN VARCHAR2 )
AS
    contador integer;  
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_TF para fichero ' || iFichero ,  v_contador_debug);
    contador := 1;
    -- Registro de CABECERA 1 : lista de campos
    INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
									CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'CAMPO1','CAMPO2','CAMPO3','CAMPO4','CAMPO5','CAMPO6','CAMPO7','CAMPO8','CAMPO9',
	'CAMPO10','CAMPO11','CAMPO12','CAMPO13','CAMPO14','CAMPO15','CAMPO16','CAMPO17','CAMPO18','CAMPO19','CAMPO20','CAMPO21','CAMPO22',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 2 : CABECERA
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
									CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','CABECERA','Contrato','Fecha Pedido','','Sociedad','Cod. Proveedor','CECO Aprob.',
	'Org.Compras','Gr.Compras','Riesgo','Contract Manager','Sit.Trabajo','Nota Cab.','','','','','','','',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 3 : POSICION    
    contador := contador + 1;
    INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
									CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','POSICION','Contrato','','Pos. contrato','Tipo Imp.','Código','Texto breve',
	'Texto posición','Cantidad','Unidad medida','Fecha entrega','Centro log.','Imputación','Tipo impuesto','Ref. para proveedor','Num. Dirección',
	'Dirección','Población','Cod. postal','Nom. solicitante',iFichero, 'BUSINESSUNIT');

    -- Registro de CABECERA 4 : SERVICIO
    contador := contador +1;
    INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
									CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
	VALUES (iperiod,contador,'Ref.Orden Entrega','Pos.Orden.Entrega','SERVICIO','Contrato','','Pos. contrato','Línea. Servicio','Cod. Servicio','Texto breve',
	'Cantidad','Imputación','','','','','','','','','','','',iFichero, 'BUSINESSUNIT');        

    COMMIT;
    w_debug('Fin Inserccion 4 Registros fijos de cabecera en tabla ENEL_E4E_FINAL_TF para fichero ' || iFichero ,  v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Ficheros_E4E_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Cabecera_Ficheros_E4E_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Final_E4E_TF_1 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
    v_referencia VARCHAR2(20);
    v_fechaInicioPeriodo date;
	v_fechaInicio date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(2);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
    v_cabecera VARCHAR2(20); -- nueva variable para el control de la cabecera
    contadorPosicion integer; -- contador para la posición
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_TF.', v_contador_debug);
    
    --v_codFichero :='E4E1';  -- v2.0 se asigna el valor dinamicamente en función de la actividad del proveedor
	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL WHERE ....';
    BEGIN
        LOOP
            DELETE FROM ENEL_E4E_FINAL_TF WHERE PERIODO = iperiod AND FICHERO like 'E%1' AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_TF.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
	v_fechaInicio := f_fecha_inicio(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el código de referencia
    --v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
	v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_TF. Fichero ' || v_codFichero ,  v_contador_debug);
    
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
            FROM ENEL_E4E_DEPOSIT_TF_TEMP_2
            WHERE PERIODSEQ = iperiodseq 
				AND COD_CONTRATO is not null    -- Fichero E4E1 contiene los registros con contrato
				AND VALUE > 0                   -- Fichero E4E se incluyen solo los positivos
				AND TIPO_PRESTADOR like 'SI'	
                --and ACTIVIDAD NOT LIKE '%RENOVACI%N%' -- RMM 12.01.2023 - No queremos incluir las renovaciones en E4E TF
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
            
                INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
                IF v_codFichero = 'E4E1' then
                    contadorE4E := contadorE4E +1;
                    contadorTabla := contadorE4E;
                ELSIF v_codFichero = 'ECS1' then
                    contadorECS := contadorECS +1;
                    contadorTabla := contadorECS;
                END IF;    
            
                INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                                CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
                VALUES ( iperiod,
                    contadorTabla,
                    v_referencia,
                    '',
                    'CABECERA',  --CAMPO 3
                    REGDEPOSITO.COD_CONTRATO, --CAMPO 4
                    v_txtFechaInicio, --CAMPO 5
                    '', --CAMPO 6
                    REGDEPOSITO.SOCIEDAD, --CAMPO 7
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
            
            INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10,  
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
            VALUES ( iperiod,
                contadorTabla,
                v_referencia,    --CAMPO1
                --'10',
                --case when REGDEPOSITO.BUSINESSUNIT = 'AAFF' then 10 else contadorPosicion end,
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
            
                INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
        p_Cabecera_Ficheros_E4E_TF (  iperiod , 'E4E1' );
    end if;
    
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
        p_Cabecera_Ficheros_E4E_TF (  iperiod , 'ECS1' );
    end if;   
    
    w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_TF:  E4E1'|| to_char(contadorE4E) || ' -- ECS1 '|| to_char(contadorECS) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_TF_1', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_TF_1', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;       

procedure p_Final_E4E_TF_2 ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    contadorE4E integer;
    contadorECS integer; 
    contadorTabla integer;   
	v_referencia VARCHAR2(20);
    v_fechaInicioPeriodo date;
	v_fechaInicio date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(2);
    v_Impuesto VARCHAR2(2);
    v_txtFechaInicio VARCHAR2(10); -- será igual que v_txtFechaInicioPeriodo a no ser que el PDS tenga fechainicio vigencia mayor
    v_codFichero VARCHAR2(4);
    v_cabecera VARCHAR2(20); -- nueva variable para el control de la cabecera
    contadorPosicion integer; -- contador para la posición
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_FINAL_TF.', v_contador_debug);    
    --v_codFichero :='E4E2'; -- v2.0 se asigna el valor dinamicamente en función de la actividad del proveedor

	-- EXECUTE IMMEDIATE 'DELETE ENELEXT.ENEL_E4E_FINAL WHERE ....';
    BEGIN
        LOOP
            DELETE FROM ENEL_E4E_FINAL_TF WHERE PERIODO = iperiod AND FICHERO like 'E%2'  AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_FINAL_TF.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodo :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
	v_fechaInicio := f_fecha_inicio(iperiodseq);
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodo := to_char(v_fechaInicioPeriodo, 'DD/MM/YYYY');
    -- Se convierte a texto el año YY para el código de referencia
    --v_txtYear := to_char(v_fechaInicioPeriodo, 'YY');
	v_txtYear := to_char(v_fechaInicio, 'YY');
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    v_codMes := f_CodigoMes(v_fechaInicioPeriodo);
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodo ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);
    
    w_debug('Cargando tabla ENEL_E4E_FINAL_TF. Periodo:'|| iperiod ||' Periodseq: '||iperiodseq ||' TenantId: '||itenantId ,  v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_E4E_FINAL_TF. Fichero ' || v_codFichero ,  v_contador_debug);
    
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
            FROM ENEL_E4E_DEPOSIT_TF_TEMP_2
            WHERE PERIODSEQ = iperiodseq 
                AND COD_CONTRATO is null  -- Fichero E4E2 contiene los registros sin contrato (valor nulo)
                AND VALUE > 0             -- Fichero E4E se incluyen solo los positivos
				AND TIPO_PRESTADOR like 'SI'
                --and ACTIVIDAD NOT LIKE '%RENOVACI%N%' -- RMM 12.01.2023 - No queremos incluir las renovaciones en E4E TF
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
            
                INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
            
                INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
            
            INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
                                       CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20, CAMPO21, CAMPO22, FICHERO, BUSINESSUNIT)
			VALUES ( iperiod,
				contadorTabla,
				v_referencia,
				--'10',
				--case when REGDEPOSITO.BUSINESSUNIT = 'AAFF' then 10 else contadorPosicion end,
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
             
                INSERT INTO ENEL_E4E_FINAL_TF (PERIODO, ORDEN, CAMPO1, CAMPO2, CAMPO3, CAMPO4, CAMPO5, CAMPO6, CAMPO7, CAMPO8, CAMPO9, CAMPO10, 
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
        p_Cabecera_Ficheros_E4E_TF (  iperiod , 'E4E2' );
    end if;
    --Si se han insertado registros de datos ECS, se insertan los registros de cabecera para el fichero ECS2
    if contadorECS > 4 THEN
        p_Cabecera_Ficheros_E4E_TF (  iperiod , 'ECS2' );
    end if;   
    
	w_debug('Fin Carga de la tabla ENEL_E4E_FINAL_TF:  E4E2'|| to_char(contadorE4E) || ' -- ECS2 '|| to_char(contadorECS) || ' filas.', v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_TF_2', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_TF_2', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Final_E4E_Negativos_TF ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaInicioPeriodoSig date;
    v_txtFechaInicioPeriodoSig VARCHAR2(10);
    v_txtFechaActual VARCHAR2(10);
    v_txtYear VARCHAR2(2);
    v_codMes VARCHAR2(2);
	v_fechaInicio date;
	v_mes VARCHAR2(5);
    v_maxIDPEDIDO integer;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_E4E_NEGATIVOS_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_E4E_NEGATIVOS_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_E4E_NEGATIVOS_TF.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
	v_fechaInicio := f_fecha_inicio(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtFechaInicioPeriodoSig := to_char(v_fechaInicioPeriodoSig, 'DD/MM/YYYY');
    
    -- Se convierte a texto el año YY para el código de referencia
    v_txtYear := to_char(v_fechaInicioPeriodoSig, 'YY'); --APM 11.01.2024 Se descomenta esta sentencia por petición de Pau.
	--v_txtYear := to_char(v_fechaInicio, 'YY'); --APM 11.01.2024 Se comenta esta sentencia por petición de Pau, ya que
    --en el informe 0.Administracion_11.Informe E4E Negativos_TF el campo 'Nº pedido cliente' aparece mal.
    
    -- Se extrae el código asociado al mes, donde Enero = A, Febrero = B, ... Diciembre = L
    --v_codMes := f_CodigoMes(v_fechaInicioPeriodoSig);
	v_codMes := to_char(v_fechaInicio,'MM');
    
    -- Se convierte a texto la fecha actual en formato DD/MM/YYYY para los registros de salida
    v_txtFechaActual := to_char(sysdate, 'DD/MM/YYYY');
    
    w_debug('Referencia fechas. Periodo:'|| iperiod ||' FechaInicioPeriodo Siguiente: '||v_txtFechaInicioPeriodoSig ||' YY: '||v_txtYear ||' codMes: '||v_codMes || ' FechaActual ' || v_txtFechaActual ,  v_contador_debug);

    select NVL(MAX(IDPEDIDO),0) into v_maxIDPEDIDO  from ENEL_E4E_NEGATIVOS_tf WHERE ESTADO='LIQUIDADO';
    w_debug('Numero máximo de pedido E4E Negativos Liquidado: ' || to_char(v_maxIDPEDIDO) ,  v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_E4E_NEGATIVOS_TF.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_E4E_NEGATIVOS_TF ( PERIODSEQ, PERIODO, DEPOSITSEQ, POSITIONSEQ, PAYEESEQ, PDS, IDPEDIDO, ORG_VENTAS, CANAL_DISTRIBUCION, 
                                              SECTOR, CLASE_PEDIDO, FACTURA_REF, SOLICITANTE_SHIPTO, SOLICITANTE_SOLDTO, NUM_PEDIDO, FECHAPEDIDO, FECHAFACTURA, 
                                              CONDICIONES_PAGO, CONTRATOSEPA, MOTIVOPEDIDO, MONEDA, POSICION, MATERIAL, TEXTO_MATERIAL, CANTIDAD, PRECIO, 
                                              CLASIF_FISCAL_IVA, CLASIF_FISCAL_IGIC, WBE_FINAL_IMPUTACION, ACTIVIDAD ) 
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

	FROM ENEL_E4E_NEGATIVOS_TEMP_TF_2 e4edt 
	WHERE 
		e4edt.VALUE < 0 
		and e4edt.PERIODSEQ = iperiodseq
        AND e4edt.TIPO_PRESTADOR like 'SI' --APM 06.02.2025
/*
		-- MPR - Modificación para quitar los negativos que tengan importe en positivo
		and (select sum(depo.value) from ENEL_E4E_DEPOSIT_TF_TEMP depo 
			where depo.periodseq = e4edt.periodseq
			and depo.PAYEESEQ = e4edt.PAYEESEQ
			and depo.POSITIONSEQ = e4edt.POSITIONSEQ 
			and depo.idproveedor = e4edt.idproveedor
			and depo.WBE_FINAL_IMPUTACION = e4edt.WBE_FINAL_IMPUTACION) is null
*/
	;

	filas := sql%rowcount;
	COMMIT;

	w_debug('Fin Carga de la tabla ENEL_E4E_NEGATIVOS_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_E4E_NEGATIVOS_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

	--EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_E4E_NEGATIVOS_TF COMPUTE STATISTICS FOR ALL INDEXES';
	w_debug('Fin Actualizacion Indices ENELEXT.ENEL_E4E_NEGATIVOS_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_Negativos_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Final_E4E_Negativos_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;       

procedure p_Temporal_Creditos_Scaweb_TF (  iprocessingUnitSeq IN VARCHAR2,  iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    vFechaAlta Date;
    v_fecInicioPeriodoSig date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_SCAWEB_LIQUIDACION_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_SCAWEB_LIQUIDACION_TF.', v_contador_debug);
    
    -- Fecha de Alta se corresponde con la fecha de sistema
    vFechaAlta := SYSDATE;
    
    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fecInicioPeriodoSig :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
        
    w_debug('Insertando CREDITOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_TF.' ,  v_contador_debug);
    -- v2.0 Se cambia la tabla de origen CS_CREDIT  a la temporal ENEL_CREDIT_TEMP
	INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_TF ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE, NOMBRE, TIPO_PRESTADOR )   
	SELECT 
		iperiod PERIODO,        
		--credit.GENERICATTRIBUTE2,      -- Proveedor,
		--to_number(credtmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda
		to_number(REPLACE(credtmp.GENERICATTRIBUTE2, ' integer','')) PROVEEDOR,             
		--to_char(credit.COMPENSATIONDATE, 'YYYY'),
		to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
		--to_char(credit.COMPENSATIONDATE, 'MM'),
		to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
		
		--credtmp.GENERICATTRIBUTE4,      -- Prestador - PDS
		TMP_PDS.PDS, --codigo_agente
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
		credtmp.VALUE  as REALVALUE,      -- Valor real sin tomar el valor absoluto para informe de revisión  ,
		CREDTMP.NAME,
		case 
			when CREDTMP.BU_NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
            when CREDTMP.BU_NAME like 'Stands' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when CREDTMP.BU_NAME not like 'RETAIL TF' and CREDTMP.BU_NAME not like 'Stands' then 'SI'
			else 'NO'
		end
 
	FROM ENEL_CREDIT_TEMP_TF credtmp
	   INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS     -- Se hace JOIN CON PDS para poder filtar los de TIPO OCAP y Proveedor 050 que no se deben incluir
			ON credtmp.payeeseq=TMP_PDS.payeeseq 
			and credtmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

	WHERE 
		credtmp.GENERICBOOLEAN1 = 1   -- Indica los creditos que se incluyen en pagos
		and credtmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)
		and NOT ( credtmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050
		--and TMP_PDS.SUBCANAL is not null 
		--(TMP_PDS.SUBCANAL='TF' or TMP_PDS.SUBCANAL='STAND') -- los subcanales son=> TF, STAND, AAFF, CORNER, RETAIL TF, SPEED LEAD
        ;  
              
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_SCAWEB_LIQUIDACION_TF: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando INCENTIVOS de datos en tabla ENEL_SCAWEB_LIQUIDACION_TF.' ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_SCAWEB_LIQUIDACION_TF ( PERIODO, PROVEEDOR, ANO_LIQUIDACION, MES_LIQUIDACION, CODIGO_AGENTE_INTERNO, CONCEPTO, CANTIDAD, 
                                                    IMPORTE, FECHA_ALTA, FECHA_BAJA, TELEFONO, OBSERVACIONES, CODIGO_POSTAL, PROVINCIA, REALVALUE, 
                                                    NOMBRE,--APM 08.07.2022
                                                    TIPO_PRESTADOR )   
	SELECT 
		iperiod PERIODO,        
		to_number(incentmp.GENERICATTRIBUTE2),   -- Proveedor en formato numerico, sin ceros a la izquierda             
		to_char(v_fecInicioPeriodoSig, 'YYYY'),  -- Año del periodo sigiente
		to_char(v_fecInicioPeriodoSig, 'MM'),  -- Mes del periodo sigiente
		TMP_PDS.PDS ,      -- Prestador - PDS
		incentmp.GENERICATTRIBUTE1,      -- Concepto Liquidación
		1 as CANTIDAD,
		ABS(incentmp.VALUE),
		to_char(vFechaAlta, 'YYYYMMDD') as FechaAlta,
		'' as FechaBaja,
		'' as Telefono,
		 Replace(incentmp.GENERICATTRIBUTE4, 'integer', '') as Observaciones, 
		''  as Codigo_Postal,       --Codigo Postal
		''  as Provincia,     --Provincia
		incentmp.VALUE  as REALVALUE,   -- Valor real sin tomar el valor absoluto para informe de revisión
        incentmp.NAME,--APM 08.07.2022
		case 
			when incentmp.BU_NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
            when incentmp.BU_NAME like 'Stands' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when incentmp.BU_NAME not like 'RETAIL TF' and incentmp.BU_NAME not like 'Stands' then 'SI'
			else 'NO'
		end
		
	FROM ENEL_INCEN_TEMP_TF incentmp

	INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
		ON incentmp.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

	WHERE
		incentmp.GENERICATTRIBUTE1 is not null  -- Solo se  incluyen los créditos con Concepto de Liquidación que no son vacios (nulos)  
		and incentmp.VALUE <> 0  -- Se filtran los incentivos que sean distintos de 0      
		and NOT ( incentmp.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- No se incluyen Creditos de OCAPS y proveedor 050            
		and TMP_PDS.SUBCANAL is not null
		--(TMP_PDS.SUBCANAL='TF' or TMP_PDS.SUBCANAL='STAND')
		AND INCENTMP.NAME NOT LIKE '%Rappel Cualitativo%'
		AND INCENTMP.NAME NOT LIKE '%Bonus exclusivo Permanencia%'
		AND INCENTMP.NAME NOT LIKE '%Tasa Mortandad%'
        AND INCENTMP.NAME NOT LIKE 'C - Captacion % - Incentivo Transversal%'
        AND INCENTMP.NAME NOT LIKE 'C - Captacion TW - Ricorrente%' --APM 16.01.2025
        AND INCENTMP.NAME NOT LIKE 'C - Captacion VR - Ricorrente%'; --APM 30.12.2025

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_SCAWEB_LIQUIDACION_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_SCAWEB_LIQUIDACION_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_SCAWEB_LIQUIDACION_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_SCAWEB_LIQUIDACION_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Creditos_Scaweb_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_Creditos_Scaweb_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Inf_Factura_TF_Detalle ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaPeriodoSiguiente date;
    v_txtMes_Liquidacion VARCHAR2(10);
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_FACTTF_DETALLE.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_FACTTF_DETALLE WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_FACTTF_DETALLE.', v_contador_debug);

    -- Se extrae la fecha inicial del siguiente mes al periodSeq del proceso
    v_fechaPeriodoSiguiente :=  f_Primer_Dia_Periodo_Siguiente(iperiodseq);
    
    -- Se convierte a texto en formato DD/MM/YYYY para los registros de salida
    v_txtMes_Liquidacion := to_char(v_fechaPeriodoSiguiente, 'YYYYMM');

    w_debug('Insertando Registros de CREDITOS en tabla ENEL_FACTTF_DETALLE.' ,  v_contador_debug);
   
	INSERT INTO ENELEXT.ENEL_FACTTF_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
											PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E,DELEGACION,
											ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, 
											COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, MARCA, MODELO, OBSERVACIONES, CUPS, TIPO_PRESTADOR,
                                            WBE )   
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
		TXNTMP.ORDERID as CONTRATO,
		TXNTMP.PRODUCTID, 
		TXNTMP.TAD_POSTALCODE AS COD_POSTAL_DETALLE,
		TXNTMP.TAS_GENERICATTRIBUTE1 AS COD_COMERCIAL,
		EET.MARCA,
		EET.MODELO,
		credtmp.genericattribute15,
		TXNTMP.ALTERNATEORDERNUMBER as CUPS, 
		case 
			when credtmp.BU_NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when credtmp.BU_NAME not like 'RETAIL TF' then 'SI'
			else 'NO'
		end,
        CREDTMP.GENERICATTRIBUTE11 as WBE

	FROM ENEL_CREDIT_TEMP_TF CREDTMP
		inner JOIN ENEL_TXN_TEMP_TF TXNTMP
			ON CREDTMP.SALESTRANSACTIONSEQ = TXNTMP.SALESTRANSACTIONSEQ
			and credtmp.periodseq=txntmp.periodseq

		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			ON CREDTMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and credtmp.periodseq=tmp_pds.periodseq

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=CREDTMP.GENERICATTRIBUTE2

		LEFT JOIN ENEL_PRODUCTOS_TEMP_TF TMP_PROD
			ON TMP_PROD.PRODUCTID=CREDTMP.GENERICATTRIBUTE1

		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
			ON  TMP_CONTRA.PDS = TMP_PDS.PDS
			AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENEL_EQUIPAMIENTO_TEMP_TF EET
			ON  TXNTMP.GENERICATTRIBUTE8 = EET.IDMARCA
			AND TXNTMP.GENERICATTRIBUTE9 = EET.IDMODELO                    

		WHERE  
			(TXNTMP.EVENTYPEID = 'Captacion TF'
				OR TXNTMP.EVENTYPEID like 'Ajuste Manual Captación TF%'
                OR TXNTMP.EVENTYPEID = 'Baja Contrato TF' -- la retrocesión
				OR TXNTMP.EVENTYPEID = 'Captacion RETAIL TF'
				OR TXNTMP.EVENTYPEID = 'Ajuste Manual Captacion RETAIL TF'
                OR TXNTMP.EVENTYPEID = 'Baja Contrato RETAIL TF' -- la retrocesión
				-- Administradores de Fincas
				OR TXNTMP.EVENTYPEID = 'Captacion AAFF'
				OR TXNTMP.EVENTYPEID = 'Ajuste Manual Captacion AAFF'
				OR TXNTMP.EVENTYPEID = 'Baja Contrato AAFF' -- la retrocesión
				-- Ventas Remotas - SPEED LEAD
				OR TXNTMP.EVENTYPEID = 'Captacion VR'
				OR TXNTMP.EVENTYPEID = 'Ajuste Manual Captacion VR'
                OR TXNTMP.EVENTYPEID = 'Baja Contrato VR' -- la retrocesión
				-- CORNER
				OR TXNTMP.EVENTYPEID = 'Captacion TW'
				OR TXNTMP.EVENTYPEID = 'Ajuste Manual Captacion TW'
                OR TXNTMP.EVENTYPEID = 'Baja Contrato TW' -- la retrocesión
                -- VR Offshore
                OR TXNTMP.EVENTYPEID = 'Ajuste Manual Captacion VR Offshore'  --07/10/2022
                or TXNTMP.EVENTYPEID = 'Renovacion TF' --APM 19.01.2023
                -- Renovaciones  BOM APM 07.03.2023
                or TXNTMP.EVENTYPEID like 'Renovaci%n VR'
                or TXNTMP.EVENTYPEID like 'Ajuste Manual Renovaci%n VR'
                or TXNTMP.EVENTYPEID like 'Renovaci%n TW'
                or TXNTMP.EVENTYPEID like 'Ajuste Manual Renovaci%n TW'
                or TXNTMP.EVENTYPEID like 'Renovaci%n AAFF'
                or TXNTMP.EVENTYPEID like 'Ajuste Manual Renovaci%n AAFF'
                -- EOM APM 07.03.2023
                /*BOM 22.04.2024 APM*/ --AACC EE
                or TXNTMP.EVENTYPEID  = 'Venta Enel X AACC EE'
                or TXNTMP.EVENTYPEID  like 'Instalaci%n Enel X AACC EE'
                /*EOM 22.04.2024 APM*/
                /*BOM 27.06.2024 APM*/
                or TXNTMP.EVENTYPEID  = 'Venta Enel X RETAIL EE'
                or TXNTMP.EVENTYPEID  like 'Instalaci%n Enel X RETAIL EE'
                /*EOM 27.06.2024 APM*/	
                or TXNTMP.EVENTYPEID  like 'Lead%'
                /*BOM APM 25.03.2026*/
                or TXNTMP.EVENTYPEID  = 'Venta Enel X Stands'
                or TXNTMP.EVENTYPEID  like 'Instalaci%n Enel X Stands'
                or TXNTMP.EVENTYPEID  like '%Stands'
                /*eOM APM 25.03.2026*/
                /*BOM APM 19.05.2026*/
                or TXNTMP.EVENTYPEID  = 'Activacion VR'
                or TXNTMP.EVENTYPEID  = 'Ajuste Manual Activacion VR'
                or TXNTMP.EVENTYPEID  = 'Activacion AAFF'
                or TXNTMP.EVENTYPEID  = 'Activacion AAFF - Ajuste Manual'
                or TXNTMP.EVENTYPEID  = 'Ajuste Manual Activacion AAFF'
                /*EOM APM 19.05.2026*/
			) 
			and credtmp.GenericAttribute1 not like '%BONI.KPI.%'
			and CREDTMP.GENERICATTRIBUTE1 is not null  
			and CREDTMP.GENERICATTRIBUTE2 is not null AND CREDTMP.GENERICATTRIBUTE2 <> '000' 
			and CREDTMP.GENERICBOOLEAN1 = 1
			and credtmp.periodo=iperiod
/* BOM - CAL0154 DCR 03.06.2022 */
            AND CREDTMP.NAME not like '%Alta Contrato%'
/* EOM - CAL0154 DCR 03.06.2022 */
		
		group by
			credtmp.PERIODO, 
			credtmp.PERIODSEQ,
			v_txtMes_Liquidacion,
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
			TMP_PDS.PAR_PROVEEDOR,
			TMP_PDS.DELEGACION,
			TMP_PDS.ZONA,
			TMP_PDS.TERRITORIO,
			TMP_PDS.CALLE,
			TMP_PDS.COD_POSTAL,
			TMP_PDS.PROVINCIA,
			TMP_PDS.POBLACION, 
			1,           
			credtmp.VALUE,
			case 
				when CREDTMP.CREDITTYPEID like 'Instalacion%' or CREDTMP.CREDITTYPEID like 'Prestacion%' THEN credtmp.GENERICATTRIBUTE9 
				ELSE '' 
			END,      -- Solicitud de servicio (solo prestacion e Instalacion)
			credtmp.GenericAttribute1,    --Concepto liquidación
			CASE 
				WHEN credtmp.GenericAttribute14 is not null THEN credtmp.GenericAttribute14
				WHEN credtmp.GenericAttribute14 is null  AND TMP_PROD.DESCRIPTION is not null THEN TMP_PROD.DESCRIPTION
				else credtmp.GenericAttribute1 
			END,
			TMP_CONTRA.COD_CONTRATO,
			TXNTMP.EVENTYPEID,
			TXNTMP.ORDERID,
			TXNTMP.PRODUCTID, 
			TXNTMP.TAD_POSTALCODE,
			TXNTMP.TAS_GENERICATTRIBUTE1,
			EET.MARCA,
			EET.MODELO,
			credtmp.genericattribute15,
			TXNTMP.ALTERNATEORDERNUMBER,
			case 
				when credtmp.BU_NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
				when credtmp.BU_NAME not like 'RETAIL TF' then 'SI'
				else 'NO'
			end,
            CREDTMP.GENERICATTRIBUTE11
	; 

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga CREDITOS de la tabla ENEL_FACTTF_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros de INCENTIVOS en tabla ENEL_FACTTF_DETALLE.' ,  v_contador_debug);
   
	INSERT INTO ENELEXT.ENEL_FACTTF_DETALLE ( PERIODO, PERIODSEQ, MES_LIQUIDACION, CREDITSEQ, CREDITTYPEID, PAYEESEQ, POSITIONSEQ, 
                                                PDS, NOMBRE_FISCAL, CIF, IDPROVEEDOR, DESCRIPCION, FICHERO, ACTIVIDAD, DETALLE_ACTIVIDAD, CODIGOE4E, DELEGACION, 
                                                ZONA, TERRITORIO, CALLE, COD_POSTAL, PROVINCIA, POBLACION, CANTIDAD, VALUE, SOLICITUD_SERVICIO, CONCEPTO_LIQ, 
                                                DESC_CONCEPTO_LIQ, COD_CONTRATO, EVENTYPEID, CONTRATO, PRODUCTID, COD_POSTAL_DETALLE, COD_COMERCIAL, 
                                                MARCA, MODELO, TIPO_PRESTADOR, WBE ) 
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
		'' MODELO,
		case 
			when INCETMP.BU_NAME like 'RETAIL TF' and TMP_PDS.TIPO_PRESTADOR like 'SI' then 'SI'
			when INCETMP.BU_NAME not like 'RETAIL TF' then 'SI'
			else 'NO'
		end,
        INCETMP.GENERICATTRIBUTE7 as WBE
		
	FROM ENEL_INCEN_TEMP_TF INCETMP
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			ON INCETMP.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=INCETMP.GENERICATTRIBUTE2

		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
			ON  TMP_CONTRA.PDS = TMP_PDS.PDS
			AND TMP_CONTRA.ACTIVIDAD = TMP_PROV.ACTIVIDAD
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq   

	WHERE --INCETMP.NAME like 'I - Captacion - %' AND    v2.2 se elmina esta condición
		NOT( INCETMP.GENERICATTRIBUTE2 ='050' AND TMP_PDS.TIPO_POSICION ='OCAP')   -- v2.2 se filtra que no sea proveedor 050 y OCAP 
		and INCETMP.GENERICATTRIBUTE1 is not null 
		and INCETMP.GENERICATTRIBUTE2 is not null AND INCETMP.GENERICATTRIBUTE2 <> '000' 
		and INCETMP.value <> 0
        and INCETMP.NAME NOT LIKE 'C - Captacion%- Ricorrente -%'
        and INCETMP.NAME NOT LIKE 'C - Captacion%- Incentivo Transversal%'
		--and UPPER(INCETMP.GenericAttribute1) not like '%BON%'
/* BOM - CAL0154 DCR 03.06.2022 */
        AND INCETMP.NAME not like '%Alta Contrato%'
/* EOM - CAL0154 DCR 03.06.2022 */
	;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga INCENTIVOS de la tabla ENEL_FACTTF_DETALLE: '|| to_char(filas) || ' filas.', v_contador_debug);
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_FACTTF_DETALLE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTTF_DETALLE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTTF_DETALLE.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_TF_Detalle', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_TF_Detalle', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Inf_Factura_TF_Portada ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
    v_fechaActual date;
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_FACTTF_PORTADA.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_FACTTF_PORTADA WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_FACTTF_PORTADA.', v_contador_debug);

    v_fechaActual := sysdate;
    
    w_debug('Insertando Registros de CRED e INC en tabla ENEL_FACTPDS_PORTADA.' ,  v_contador_debug);
   
    
	INSERT INTO ENELEXT.ENEL_FACTTF_PORTADA ( PERIODO, PERIODSEQ, NUMERO_RESUMEN, MES_LIQUIDACION, FECHA_LIQUIDACION, PAYEESEQ, POSITIONSEQ, CIF, CODIGOE4E,  
											ZONA, PDS, NOMBRE_FISCAL, CALLE, COD_POSTAL, POBLACION, PROVINCIA, IDPROVEEDOR, FICHERO, DESCRIPCION, 
											CONCEPTO_LIQ, DESC_CONCEPTO_LIQ, COD_CONTRATO, ACTIVIDAD, DETALLE_ACTIVIDAD, PRECIO_UNITARIO, CANTIDAD, IMPORTE_TOTAL,
                                            WBE , NOMBRE )  
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
		sum(FAPDET.CANTIDAD * FAPDET.VALUE) AS IMPORTE_TOTAL,
        FAPDET.WBE as WBE,
        FAPDET.credittypeid as Nombre --RMM 25.05.22 incluimos el campo para filtrar por regla

	FROM ENEL_FACTTF_DETALLE fapDet
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
		FAPDET.VALUE,
        FAPDET.WBE,
        FAPDET.credittypeid

	ORDER BY PDS
	;   
      
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_FACTTF_PORTADA: '|| to_char(filas) || ' filas.', v_contador_debug);
 dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_FACTTF_PORTADA',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
   
   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_FACTTF_PORTADA COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_FACTTF_PORTADA.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_TF_Portada', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_Factura_TF_Portada', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

-- cuadre de liquidación
procedure p_Informe_LIQSCAWEB_TF ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2, iInterfaz IN VARCHAR2 )
AS
    v_fechaInicioPeriodo date;
    v_txtFechaInicioPeriodo VARCHAR2(10);
    v_txtFechaLiquidacion VARCHAR2(10);
    v_Estado VARCHAR2(50);
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_LIQSCAWEB_FINAL_TF.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE WHERE PERIODO = iperiod and PROCESSINGUNITSEQ = iprocessingunitseq AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL WHERE Periodo_Liquidacion = iperiod  AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
       LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_RENOV_VR WHERE periodo_anual = iperiod  AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
        LOOP
            DELETE FROM ENELEXT.ENEL_LIQSCAWEB_RENOV_AAFF WHERE periodo_anual = iperiod  AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    
	w_debug('Fin Borrado de la tabla ENEL_LIQSCAWEB_FINAL_TF.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_LIQSCAWEB_FINAL_TF.' ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_TF (PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, ESTADOCONTRATO, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, 
                                            NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO, RESPONSABLE, NUM_DIAS, RETROCESION,
                                            FECHA_RETROCESION, CODIGO_POSICION, FECHA_ALTA, FECHA_BAJA, MOTIVO_BAJA,
                                            PROVINCIA, APLICACION_INCEN_CP,  --APM 07.03.2024 Evo CPs
                                            CUPS, --APM 11.04.2024
                                            TARIFA,COSTE,WO_VISITA, VENTA_RELACIONADA, --APM 15.05.2024
                                            INCENTIVO_OFERTA, TIENDA, COSTE_2, GENERICDATE4,
                                            FECHA_VENTA, COMPENSATIONDATE, FECHA_ACTIVACION) --APM 14.05.2025
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
		case 
			when ECT.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and ect.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
		TEMP_PROV.DESCRIPCION,
		TEMP_PROV.IDPROVEEDOR,
		ECT.GENERICATTRIBUTE3,
		ECT.CREDITTYPEID,
		ect.name,
		ECT.GENERICATTRIBUTE8,
		TMP_PDS.RESPONSABLE,
		ECT.GENERICNUMBER3, --NUMERO DE DÍAS
		ECT.GENERICNUMBER4, --PORCENTAJE RETROCESIÓN
		ECT.GENERICDATE1,
		ECT.GENERICATTRIBUTE4,    -- Código Posción
        ETT.GENERICDATE4 as FECHA_ALTA,      --Fecha Alta (GD4 transaccion)
        ETT.GENERICDATE5       as FECHA_BAJA,      --Fecha Baja (GD5 transaccion)
        TEX0_GENERICATTRIBUTE3 as MOTIVO_BAJA,      --Motivo Baja (EA3 transaccion)
        /*BOM APM 07.03.2024 Evo CPs*/
        ETT.TAD_STATE AS PROVINCIA,
        TMP_PDS.APLICACION_INCEN_CP AS APLICACION_INCEN_CP,
        /*EOM APM 07.03.2024*/
        ETT.ALTERNATEORDERNUMBER AS CUPS, --APM 11.04.2024 
        ETT.PRODUCTNAME AS TARIFA, --APM 15.05.2024
        TRIM(replace(to_char(ETT.COSTE , '9999999999990D99'), ',', '.')) AS COSTE, --DMS 17.06.2024
        ETT.GENERICATTRIBUTE4 AS WO_VISITA,
        ETT.GENERICATTRIBUTE24 AS VENTA_RELACIONADA, --APM 17.09.2024
        ECT.GENERICATTRIBUTE13 AS INCENTIVO_OFERTA, --APM 14.05.2025
		ETT.GENERICATTRIBUTE25 AS TIENDA, --APM 14.05.2025
        TRIM(replace(to_char(ETT.COSTE , '9999999999990D99'), ',', '.')) COSTE_2, --APM 03.07.2025
        ETT.GENERICDATE4, --APM 16.07.2025
        /*BOM APM 16.03.2026*/
        ECT.GENERICDATE2 AS FECHA_VENTA,
        ETT.COMPENSATIONDATE AS COMPENSATIONDATE,
        ETT.FECHA_ACTIVACION AS FECHA_ACTIVACION
        /*EOM APM 16.03.2026*/
        
	FROM ENEL_TXN_TEMP_TF ETT
		LEFT JOIN ENEL_CREDIT_TEMP_TF ECT
			ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

		LEFT JOIN ENEL_PROVEEDORES_TEMP_TF TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2
			
		LEFT JOIN ENEL_PDS_TEMP_TF TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq
			and ( tmp_pds.title_name not like 'RETAIL TF RESP' )
        
		
	WHERE ETT.PROCESSINGUNITSEQ=38280596832649318
	;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_FINAL_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_LIQSCAWEB_FINAL_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_LIQSCAWEB_FINAL_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQSCAWEB_FINAL_TF.',v_contador_debug);
  
  w_debug('Insertando Registros de datos en tabla ENEL_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL.' ,  v_contador_debug);
  
    INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL(Periodo_Liquidacion ,Canal_Unidad_Negocio, WBE,	Nombre_Deposito,	
                                                            Importe,Proveedor, Codigo_Comercial )
    SELECT
     DEP.PERIODO AS PERIODO_LIQUIDACION,
    pos.genericattribute6 AS Canal_Unidad_Negocio,
    dep.wbe AS WBE,
    dep.name AS Nombre_DepOsito,
    dep.value AS Importe,
    DEP.EARNINGCODEID AS Proveedor,
    POS.NAME AS COdigo_Comercial
    
    from ENEL_DEPOSIT_TEMP_TF dep
        inner join cs_position pos
            on pos.payeeseq = dep.payeeseq
            and pos.removedate = '01/01/2200'
            and pos.processingunitseq = 38280596832649318
    
    where dep.name like '%Leads%'
    AND dep.PERIODSEQ = iperiodseq
    
    ;
    filas := sql%rowcount;
    COMMIT;
    
    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_FINAL_LEADS_WBE_TF_FINAL: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE (PERIODO, ORDERID, subcanal, wbe, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 	
											CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO,PROCESSINGUNITSEQ, ESTADOCONTRATO) 
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
        --ECT.GENERICATTRIBUTE4,    --    Código de PDS/OCAP
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
        ect.name,
        ECT.GENERICATTRIBUTE8,
		iprocessingunitseq,
		ETT.GENERICATTRIBUTE3

    FROM ENEL_TXN_TEMP_TF ETT
        LEFT JOIN ENEL_CREDIT_TEMP_TF ECT
            ON ECT.SALESTRANSACTIONSEQ = ETT.SALESTRANSACTIONSEQ

        LEFT JOIN ENEL_PROVEEDORES_TEMP_TF TEMP_PROV
            ON TEMP_PROV.IDPROVEEDOR=ECT.GENERICATTRIBUTE2

        LEFT JOIN ENEL_PDS_TEMP_TF TMP_PDS
            on ECT.payeeseq=TMP_PDS.payeeseq 
            and ECT.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
            and ECT.periodseq=TMP_PDS.periodseq

    WHERE ETT.PROCESSINGUNITSEQ=iprocessingunitseq
		and ECT.GENERICATTRIBUTE11 is not null
		and (tmp_pds.title_name not like 'RETAIL TF RESP' 
        or tmp_pds.title_name is null)
    ;
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_FINAL_WBE: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_LIQSCAWEB_FINAL_WBE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

    --EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE.',v_contador_debug);


--BOM APM 13/05/2025 - Renovación VR.

    w_debug('Cargando tabla ENEL_LIQSCAWEB_RENOV_VR. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_LIQSCAWEB_RENOV_VR( PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, ESTADOCONTRATO, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, 
                                            NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO, RESPONSABLE, NUM_DIAS, RETROCESION,
                                            FECHA_RETROCESION, CODIGO_POSICION, FECHA_ALTA, FECHA_BAJA, MOTIVO_BAJA,
                                            PROVINCIA, APLICACION_INCEN_CP, CUPS, TARIFA, COSTE, WO_VISITA, VENTA_RELACIONADA, PERIODO_ANUAL,
                                            PROVEEDOR)
	SELECT 
		per.name,
		ordtxn.ORDERID,
		txn.LINENUMBER,
		txn.SUBLINENUMBER,
		'', --txn.EVENTYPEID,
		txn.GENERICATTRIBUTE3,
		TRIM(replace(to_char(commi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
		'EURO',
		TRIM(replace(to_char(credit.VALUE , '9999999999990D99'), ',', '.')) VALOR_1,
		'EURO',
		credit.GENERICATTRIBUTE1,    --    ID Producto SCA Web
		POS.NAME,
		v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
		case 
			when credit.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and credit.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
		TEMP_PROV.DESCRIPCION, --IDPROVEEDOR
		TEMP_PROV.IDPROVEEDOR, --NUMPROVEEDOR
		credit.GENERICATTRIBUTE3,
		'', --credit.CREDITTYPEID,
		INC.name,
		credit.GENERICATTRIBUTE8,
		(SELECT POSI.NAME FROM CS_POSITION POSI WHERE POSI.REMOVEDATE = v_eot AND POSI.RULEELEMENTOWNERSEQ = POS.MANAGERSEQ AND pos.TENANTID = itenantId AND posi.EFFECTIVESTARTDATE <= PER.ENDDATE - 1 AND posi.EFFECTIVEENDDATE >= PER.ENDDATE - 1 and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq) as RESPONSABLE,
		credit.GENERICNUMBER3, --NUMERO DE DÍAS
		credit.GENERICNUMBER4, --PORCENTAJE RETROCESIÓN
		credit.GENERICDATE1,
		credit.GENERICATTRIBUTE4,    -- Código Posción
        txn.GENERICDATE6 as FECHA_ALTA,      --Fecha Alta (GD4 transaccion)
        txn.GENERICDATE5       as FECHA_BAJA,      --Fecha Baja (GD5 transaccion)
        '1',--TEX0_GENERICATTRIBUTE3 as MOTIVO_BAJA,      --Motivo Baja (EA3 transaccion)
        TXNADD.STATE AS PROVINCIA,
        POS.GENERICBOOLEAN1 AS APLICACION_INCEN_CP,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.PRODUCTNAME AS TARIFA, 
        TRIM(replace(to_char(txn.GENERICNUMBER6 , '9999999999990D99'), ',', '.')) AS COSTE,
        txn.GENERICATTRIBUTE4 AS WO_VISITA,
        txn.GENERICATTRIBUTE24 AS VENTA_RELACIONADA,
        iperiod AS PERIODO_ANUAL,
        INC.GENERICATTRIBUTE2 AS PROVEEDOR
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-12)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    inner JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ

       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
        
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
    
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid

        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
        
        LEFT JOIN ENEL_PROVEEDORES_TEMP_TF TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=credit.GENERICATTRIBUTE2
	WHERE
		inc.TENANTID = itenantId 
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Renovacion VR%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_RENOV_VR: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_LIQSCAWEB_RENOV_VR',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQSCAWEB_RENOV_VR.',v_contador_debug);
    
--EOM APM 13/05/2025

--BOM APM 20/05/2025 - Renovación AAFF.

    w_debug('Cargando tabla ENEL_LIQSCAWEB_RENOV_AAFF. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_LIQSCAWEB_RENOV_AAFF( PERIODO, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, ESTADOCONTRATO, IMPORTE, UNIDAD, 
                                            VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, CICLO_FACTURACION, ESTADO, IDPROVEEDOR, 
                                            NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, nom_credito,PRODUCTO, RESPONSABLE, NUM_DIAS, RETROCESION,
                                            FECHA_RETROCESION, CODIGO_POSICION, FECHA_ALTA, FECHA_BAJA, MOTIVO_BAJA,
                                            PROVINCIA, APLICACION_INCEN_CP, CUPS, TARIFA, COSTE, WO_VISITA, VENTA_RELACIONADA, PERIODO_ANUAL )
	SELECT 
		per.name,
		ordtxn.ORDERID,
		txn.LINENUMBER,
		txn.SUBLINENUMBER,
		'', --txn.EVENTYPEID,
		txn.GENERICATTRIBUTE3,
		TRIM(replace(to_char(commi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
		'EURO',
		TRIM(replace(to_char(credit.VALUE , '9999999999990D99'), ',', '.')) VALOR_1,
		'EURO',
		credit.GENERICATTRIBUTE1,    --    ID Producto SCA Web
		POS.NAME,
		v_txtFechaLiquidacion,--       CICLO facturacion - Pte confirmar formato
		case 
			when credit.VALUE is null or TEMP_PROV.IDPROVEEDOR is null then 'Pte Revisar'
			when iInterfaz ='ACTUALIZA_INFORMES_POST' and credit.value is not null then 'Liquidado'
			else 'Pte Liquidar'
		end as Estado,
		TEMP_PROV.DESCRIPCION,
		TEMP_PROV.IDPROVEEDOR,
		credit.GENERICATTRIBUTE3,
		'', --credit.CREDITTYPEID,
		INC.name,
		credit.GENERICATTRIBUTE8,
		(SELECT POSI.NAME FROM CS_POSITION POSI WHERE POSI.REMOVEDATE = v_eot AND POSI.RULEELEMENTOWNERSEQ = POS.MANAGERSEQ AND pos.TENANTID = itenantId AND posi.EFFECTIVESTARTDATE <= PER.ENDDATE - 1 AND posi.EFFECTIVEENDDATE >= PER.ENDDATE - 1 and POS.PROCESSINGUNITSEQ = iprocessingUnitSeq) as RESPONSABLE,
		credit.GENERICNUMBER3, --NUMERO DE DÍAS
		credit.GENERICNUMBER4, --PORCENTAJE RETROCESIÓN
		credit.GENERICDATE1,
		credit.GENERICATTRIBUTE4,    -- Código Posción
        txn.GENERICDATE6 as FECHA_ALTA,      --Fecha Alta (GD4 transaccion)
        txn.GENERICDATE5       as FECHA_BAJA,      --Fecha Baja (GD5 transaccion)
        '1',--TEX0_GENERICATTRIBUTE3 as MOTIVO_BAJA,      --Motivo Baja (EA3 transaccion)
        TXNADD.STATE AS PROVINCIA,
        POS.GENERICBOOLEAN1 AS APLICACION_INCEN_CP,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.PRODUCTNAME AS TARIFA, 
        TRIM(replace(to_char(txn.GENERICNUMBER6 , '9999999999990D99'), ',', '.')) AS COSTE,
        txn.GENERICATTRIBUTE4 AS WO_VISITA,
        txn.GENERICATTRIBUTE24 AS VENTA_RELACIONADA,
        iperiod AS PERIODO_ANUAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-12)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    inner JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ

       left JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
        
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
    
        left JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = '01/01/2200'
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid

        left JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
        
        LEFT JOIN ENEL_PROVEEDORES_TEMP_TF TEMP_PROV
			ON TEMP_PROV.IDPROVEEDOR=credit.GENERICATTRIBUTE2
	WHERE
		inc.TENANTID = itenantId 
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Renovacion AAFF%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_LIQSCAWEB_RENOV_AAFF: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_LIQSCAWEB_RENOV_AAFF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_LIQSCAWEB_RENOV_AAFF.',v_contador_debug);
    
--EOM APM 20/05/2025

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Informe_LIQSCAWEB_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Informe_LIQSCAWEB_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;      

procedure p_Comp_Pagos_SCAWEB_E4E_TF ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_COMP_SCAWEB_E4E_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_COMP_SCAWEB_E4E_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_SCAWEB_E4E_TF.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_SCAWEB_E4E_TF.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_TF ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES , TITLE_NAME )   
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
/*
        case 
			when T_E4E.POSITIVO_CON_CONTRATO is null then 0 
			else case 
				when E4ENT.VALUE is null then T_E4E.POSITIVO_CON_CONTRATO 
				else T_E4E.POSITIVO_CON_CONTRATO+(E4ENT.VALUE) 
			end 
        end as Con_Contrato,
        case 
			when T_E4E.POSITIVO_SIN_CONTRATO is null then 0 
			else case 
				when E4ENT.VALUE is null then T_E4E.POSITIVO_SIN_CONTRATO 
				else case 
					when T_E4E.POSITIVO_CON_CONTRATO is null or T_E4E.POSITIVO_CON_CONTRATO = 0 
					then T_E4E.POSITIVO_SIN_CONTRATO+(E4ENT.VALUE) 
					else T_E4E.POSITIVO_SIN_CONTRATO 
				end
			end 
        end as Sin_Contrato,
*/
        --case when T_E4E.POSITIVO_SIN_CONTRATO is null then 0 else T_E4E.POSITIVO_SIN_CONTRATO end as Sin_Contrato,
		-- MPR -- modificación de negativos para que se agrupe la suma por proveedor y pds
        --case when E4ENT.VALUE is null then 0 else E4ENT.VALUE end as Negativo,
		case when E4ENT.NEGATIVO is null then 0 else E4ENT.NEGATIVO end as Negativo,
        case when T_E4E.OPERACIONES is null then 0 else T_E4E.OPERACIONES end as Operaciones,
        T_SCAWEB.NOMBRE --MIKE 05.05.2022 Se añade el campo que solicitan de una regla que impacta en los incentivos del informe PUSH
	FROM
		(select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
			,NOMBRE --RMM 05.05.2022
            from ENEL_SCAWEB_LIQUIDACION_TF sca 
			where PERIODO = iperiod
			and TIPO_PRESTADOR = 'SI'
            --and nombre not like '%Alta Contrato' --RMM 03.05.2022 
            group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO ,
             NOMBRE  --RMM 03.05.2022 
            
		) T_SCAWEB
      
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
                sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
                SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
                SUM(VALOR_OPERACIONES) AS OPERACIONES
            from ENEL_E4E_DEPOSIT_TF_TEMP 
			where periodseq=iperiodseq
			and TIPO_PRESTADOR like 'SI'
            group by TRIM(IDPROVEEDOR), PDS
			) T_E4E
           ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
           AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
			from ENEL_E4E_NEGATIVOS_TEMP_tf 
			where periodseq=iperiodseq
			group by TRIM(IDPROVEEDOR), PDS
			)E4ENT
			ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.PDS)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)
                        
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			ON T_SCAWEB.PDS=TMP_PDS.PDS
			--and TMP_PDS.SUBCANAL is not null
			--(TMP_PDS.SUBCANAL='TF' or TMP_PDS.SUBCANAL='STAND')

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR)
	;      
           
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E_TF: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E_TF.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_TF ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES,TITLE_NAME )
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
        T_E4E.OPERACIONES,
        T_SCAWEB.NOMBRE --MIKE 05.05.2022 Se añade el campo que solicitan de una regla que impacta en los incentivos del informe PUSH
	FROM
        (select 
			iperiod PERIODO, TRIM(IDPROVEEDOR)  as IDPROVEEDOR, PDS, 
			sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
			sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
			SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
			SUM(VALOR_OPERACIONES) AS OPERACIONES
          
		from ENEL_E4E_DEPOSIT_TF_TEMP 
		where periodseq=iperiodseq
		and TIPO_PRESTADOR like 'SI'
		group by iperiod, TRIM(IDPROVEEDOR), PDS 
		) T_E4E
            
		LEFT JOIN
			( select PERIODO, trim( to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
				  ,NOMBRE --RMM 05.05.2022
                from ENEL_SCAWEB_LIQUIDACION_TF sca where PERIODO = iperiod and TIPO_PRESTADOR = 'SI'
				group by PERIODO, trim( to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO  ,
                 NOMBRE
			) T_SCAWEB
           
			ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
			AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			ON T_E4E.PDS=TMP_PDS.PDS
            --and tmp_pds.title_name not like '%Alta Contrato'  --RMM 03.05.2022
			--AND TMP_PDS.SUBCANAL is not null
			--(TMP_PDS.SUBCANAL='TF' or TMP_PDS.SUBCANAL='STAND')

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_E4E.IDPROVEEDOR)
      
	WHERE T_SCAWEB.IMPORTE_SCAWEB is null
	;
      
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_SCAWEB_E4E: '|| to_char(filas) || ' filas.', v_contador_debug);
        dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_COMP_SCAWEB_E4E',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_COMP_SCAWEB_E4E COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_SCAWEB_E4E.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Comp_Pagos_SCAWEB_E4E_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Comp_Pagos_SCAWEB_E4E_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;            

procedure p_Informe_Resumen_Pagos ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

	w_debug('Inicio Borrado de la tabla ENEL_PAGOS_RESUMEN_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_PAGOS_RESUMEN_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_PAGOS_RESUMEN.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_PAGOS_RESUMEN.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_PAGOS_RESUMEN_TF ( TENANTID, PERIODSEQ, PERIODO, IDPROVEEDOR, DESCRIPCION, TOTAL, VALOR_POS_CON, VALOR_POS_SIN, VALOR_NEG_CON, VALOR_NEG_SIN )   
	SELECT 
		itenantId,
		iperiodseq,
		iperiod,
		TMP_PROV.IDPROVEEDOR,
		TMP_PROV.DESCRIPCION,
		sum(DEPO.VALUE) TOTAL,
		SUM( CASE WHEN DEPO.VALUE>=0 and TMP_CONTRA.COD_CONTRATO is not null then DEPO.VALUE else 0 END ) VALOR_POS_CON,
		SUM( CASE WHEN DEPO.VALUE>=0 and TMP_CONTRA.COD_CONTRATO is null then DEPO.VALUE else 0 END ) VALOR_POS_SIN,
		SUM( CASE WHEN DEPO.VALUE<0 and TMP_CONTRA.COD_CONTRATO is not null then DEPO.VALUE else 0 END ) VALOR_NEG_CON,
		SUM( CASE WHEN DEPO.VALUE<0 and TMP_CONTRA.COD_CONTRATO is null then DEPO.VALUE else 0 END ) VALOR_NEG_SIN

	FROM CS_DEPOSIT DEPO

		INNER JOIN CS_PLRUN p 
			ON DEPO.PIPELINERUNSEQ = P.PIPELINERUNSEQ 
			AND P.MODELSEQ = 0   -- Solo se tienen en cuenta las ejecuciones que no son de simulacion
										 
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS 
			ON DEPO.payeeseq=TMP_PDS.payeeseq 
			and DEPO.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and DEPO.periodseq=TMP_PDS.periodseq

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON TMP_PROV.IDPROVEEDOR=DEPO.earninggroupid  
			AND DEPO.periodseq=TMP_PROV.periodseq

		LEFT JOIN ENEL_E4E_CONTRATOS_TEMP_TF TMP_CONTRA
			ON TMP_CONTRA.periodseq=DEPO.periodseq  
			AND TMP_CONTRA.PDS = TMP_PDS.PDS                 
			AND TMP_CONTRA.ACTIVIDAD_DETALLADA=TMP_PROV.DETALLE_ACTIVIDAD
			AND TMP_CONTRA.periodseq=TMP_PROV.periodseq                

	WHERE DEPO.TENANTID = itenantId
		AND DEPO.periodseq=iperiodseq        
		AND DEPO.PROCESSINGUNITSEQ =  iprocessingUnitSeq
		
	GROUP BY TMP_PROV.IDPROVEEDOR, TMP_PROV.DESCRIPCION;

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_PAGOS_RESUMEN_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_PAGOS_RESUMEN_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

    --EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_PAGOS_RESUMEN_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_PAGOS_RESUMEN_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Informe_Resumen_Pagos', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Informe_Resumen_Pagos', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

procedure p_Inf_GeneralProv_Det_TF ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_GRALPROV_DETALLE_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_GRALPROV_DETALLE_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_GRALPROV_DETALLE_TF.', v_contador_debug);

    w_debug('Insertando Registros de datos en tabla ENEL_GRALPROV_DETALLE_TF.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_GRALPROV_DETALLE_TF ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, TIPO_IMPOSITIVO, 
                                                 DELEGACION, ZONA, TERRITORIO, IMPORTEBASE, RESPONSABLE )
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
        sum(edt.VALUE) IMPORTEBASE,
		EPDS.RESPONSABLE
            
	FROM ENEL_PROVEEDORES_TEMP_TF ept
		LEFT JOIN ENEL_DEPOSIT_TEMP_TF edt 
			ON EPT.IDPROVEEDOR = edt.EARNINGGROUPID
			 
        INNER JOIN ENEL_PDS_TEMP_TF epds
			ON  EPDS.RULEELEMENTOWNERSEQ = edt.positionseq
			AND EPDS.PAYEESEQ = edt.payeeseq
			AND ((EPDS.TITLE_NAME NOT LIKE 'RETAIL TF RESP' and EPDS.TITLE_NAME NOT LIKE 'Stands RESP')
            or EPDS.TITLE_NAME is null)
			--AND EPDS.SUBCANAL is not null
			--(EPDS.SUBCANAL = 'TF' or EPDS.SUBCANAL = 'STAND') 

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
		EPDS.TERRITORIO,
		EPDS.RESPONSABLE
		;            

	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_GRALPROV_DETALLE_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_GRALPROV_DETALLE_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

    --EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_GRALPROV_DETALLE_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_GRALPROV_DETALLE_TF.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_GeneralProv_Det_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Inf_GeneralProv_Det_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

function f_ComprobarPeriodoLiquidado ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 ) return boolean as   
	v_liquidado BOOLEAN;
    v_checkCountEstado integer;
begin
	-- Se comprueba si existe la marca de PERIODO LIQUIDADO para el Periodo y la Unidad de proceso
	SELECT count(ESTADO)
		into v_checkCountEstado
	FROM ENELEXT.ENEL_PERIODOS_LIQUIDADOS_TF epl 
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

procedure p_rappeles_tf( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 , iInterfaz IN VARCHAR2)
as
    v_txtFechaLiquidacion VARCHAR2(10);
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_RAPPELES_TF.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_TF WHERE periodo = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;

        LOOP
            DELETE FROM ENELEXT.ENEL_RAPPELES_WBE WHERE periodo = iperiod and PROCESSINGUNITSEQ=38280596832649318 and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;        
    END;
    
    v_txtFechaLiquidacion := '';
    IF (iInterfaz = 'ACTUALIZA_INFORMES_POST') THEN
		v_txtFechaLiquidacion := to_char(SYSDATE, 'DD/MM/YYYY');
    END IF;
    w_debug('Fin Borrado de la tabla ENEL_RAPPELES_TF.', v_contador_debug);

    w_debug('Insertando datos en tabla ENEL_RAPPELES_TF.' ,  v_contador_debug);
    
	-- MPR se modifica para que cargue la información de las temporales
    INSERT INTO ENELEXT.ENEL_RAPPELES_TF(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, RESPONSABLE,
                                         ALTAS, BAJAS, PORC_TDM, IMPORTE_BASE_COMISION, PENA_TDM, --APM 14.03.2023 Nuevos campos
                                         NUM_VENTAS, NOMBRE_PROVEEDOR) --APM 21.04.2023
    SELECT 
		--CSPE.NAME,
		iperiod,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2, --IDPROVEEDOR
        CSI.GENERICATTRIBUTE1,
        CSI.GENERICATTRIBUTE4,
		CSP.RESPONSABLE,
        --BOM APM 14.03.2023
        CSI.GENERICNUMBER1 as ALTAS, 
		CSI.GENERICNUMBER2 as BAJAS,
        CSI.GENERICNUMBER3 as PORC_TDM,
        CSI.GENERICNUMBER5 as IMPORTE_BASE_COMISION,
        CSI.GENERICNUMBER4 as PENA_TDM,
        --EOM APM 14.03.2023
        CSI.GENERICNUMBER6 as NUM_VENTAS, --APM 21.04.2023
        CSI.GENERICATTRIBUTE3 AS NOMBRE_PROVEEDOR --APM 15.01.2025
    
    FROM ENEL_INCEN_TEMP_TF CSI --CS_INCENTIVE CSI
        INNER JOIN ENEL_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2
          
        INNER JOIN ENEL_PDS_TEMP_TF CSP --CS_PAYEE CSP
            ON CSI.PAYEESEQ=CSP.PAYEESEQ
			and CSP.TITLE_NAME not like 'RETAIL TF RESP'
            --and csp.removedate = v_eot
        /*
		INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSI.PERIODSEQ
            and cspe.removedate = v_eot
		*/

    WHERE 
        (CSI.NAME LIKE 'I - Captacion TF - Rappel Cuantitativo - Objetivo % TF%'
            or CSI.NAME LIKE 'I - Captacion TF - Rappel Cuantitativo Extra rappel - Objetivo % TF %'
            or CSI.NAME LIKE 'I -%- Captacion TF - Tasa Mortandad'
            or CSI.NAME LIKE 'I - Captacion TF - Bonus exclusivo Permanencia TF'
            OR CSI.NAME LIKE 'I - Captacion TF - Incentivo Directo Luz MENOR 10Kw'
            or CSI.Name like '%I - Captacion Stands - Rappel Cuantitativo%'
            or CSI.NAME LIKE 'I - Captacion Stands Reticulae - Rappel Cuantitativo%'
            or CSI.NAME LIKE 'I - Captacion Nuevos Stands - Rappel Cuantitativo%'
            or CSI.NAME like 'I - % Stands Reticulae - % (Imp. %)'
            or CSI.NAME like 'I - % Nuevos Stands - % (Imp. %)'
			or CSI.NAME LIKE 'I - Captacion TF - Importe Fijo TF %'
			or CSI.NAME LIKE 'I - Captacion Stands TV - Rappel Cuantitativo - Objetivo %'
			or CSI.NAME LIKE 'I - Captacion RETAIL TF - Rappel %'
			or CSI.NAME LIKE 'I - Captacion AAFF - Rappel %'
            or CSI.NAME LIKE 'I - Captacion AAFF % Regularizaci%n Rappel Trim'
			or CSI.NAME LIKE 'I - Captacion TW - Rappel %'
			or CSI.NAME LIKE 'I - Captacion VR - Rappel %'
            or CSI.NAME LIKE 'I - Captacion Stands - BONUS Rappel Cuantitativo%'
            or CSI.NAME LIKE 'I - Captacion Stands TV - Rappel Cuantitativo - ST%'
            or CSI.NAME LIKE 'I - Captacion VR - Reg Trim - Rappel Cuantitativo - Objetivo %'
            or CSI.name like 'I - Captacion VR - TdM%' --APM 14.03.2023
            or CSI.name like 'I - Captacion TW - TdM%' --APM 20.04.2023
            or CSI.NAME LIKE 'I - Captacion RETAIL TF - Retrocesi%n Rappel%'
            or CSI.NAME LIKE 'I - Captacion VR - Incentivo Base Contratacion%'
            OR CSI.NAME LIKE 'I - Captacion TW - Incentivo Base Contratacion%'
            OR CSI.NAME LIKE 'I - Captacion AAFF - Incentivo Base Contratacion%'
            OR CSI.NAME LIKE 'I - Captacion TW - Ricorrente -%'
            or CSI.NAME like 'I - Captacion VR - TM%' --APM 08.05.2025
            or CSI.name like 'I - Captacion RETAIL TF - TdM%'
            or CSI.NAME LIKE 'I - Captacion VR - Incentivo Transversal % - %'
            or CSI.NAME LIKE 'I - Captacion AAFF - Incentivo Transversal % - %'
            or CSI.NAME LIKE 'I - Captacion RETAIL TF - Incentivo Transversal % - %'
            OR CSI.NAME LIKE 'I - Captacion VR - Ricorrente -%' --APM 18.12.2025
            or CSI.NAME LIKE 'I - Captacion Stands - Rappel -%'
            or CSI.NAME LIKE 'I - Captacion Stands - Retrocesi%n Rappel%'
            or CSI.name like 'I - Captacion Stands - Incentivo Transversal % - %'
            or CSI.name LIKE 'I - Captacion Stands - TdM - 01% - % Malus' --APM 26.03.2026
            /*BOM APM 23.03.2026*/
            /*OR CSI.NAME LIKE 'I - Captacion Stands - Rappel -%' 
            OR CSI.NAME LIKE 'I - Captacion Stands - Retrocesi%n Rappel%' 
            OR CSI.NAME LIKE 'I - Captacion Stands  - Incentivo Transversal % - %'*/ 
            /*EOM APM 23.03.2026*/
            /*BOM APM 19.05.2026 New Code*/
            or CSI.name LIKE 'I - Activacion VR - % - Rappel %'
            or CSI.name LIKE 'I - Captacion VR - Incentivo Base Contratacion%' 
            or CSI.name LIKE 'I - Activacion VR - Incentivo Base Contratacion%'
            or CSI.name LIKE 'I - Activacion VR - Rappel Cuantitativo%'
            or CSI.name LIKE 'I - Activacion AAFF - % Regularizaci%n Rappel Trim'
            or CSI.name LIKE 'I - Captacion AAFF - Incentivo Transversal % - %' 
            or CSI.name LIKE 'I - Activacion AAFF - Incentivo Transversal % - %'
            or CSI.name LIKE 'I - Activacion AAFF - Rappel%'
            /*EOM APM 19.05.2026*/
            
        ) 
        and csi.value<>0
        ; 
    
    filas := sql%rowcount;
    commit;
	
	w_debug('Fin Carga de la tabla ENEL_RAPPELES_TF - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_RAPPELES_TF(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR)
    Select 
        --cspe.name,
		iperiod,
        csd.name,
        TRIM(replace(to_char(csd.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        CSP.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSD.earninggroupid
		
    from ENEL_DEPOSIT_TEMP_TF CSD --cs_deposit csd
        INNER JOIN ENEL_PROVEEDORES_TEMP_TF EPT
            ON EPT.IDPROVEEDOR=CSd.earninggroupid          
        INNER JOIN ENEL_PDS_TEMP_TF CSP --CS_PAYEE CSP
            ON CSD.PAYEESEQ=CSP.PAYEESEQ
            --and csp.removedate = v_eot
        /*
		INNER JOIN CS_PERIOD CSPE
            ON CSPE.PERIODSEQ=CSD.PERIODSEQ
			and cspe.removedate = v_eot       
		*/
    
	WHERE CSD.NAME LIKE 'D - % - Captacion TF - Rappel cualitativo' 
	and csd.value >0;
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_RAPPELES_TF: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_RAPPELES_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RAPPELES_TF COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_TF.',v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_RAPPELES_WBE(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, CONCEPTO, TRAMO, subcanal, wbe, PROCESSINGUNITSEQ)
    SELECT 
        --CSPE.NAME,
		iperiod,
        CSI.NAME,
        TRIM(replace(to_char(csi.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        TMP_PDS.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSI.GENERICATTRIBUTE2,
        CSI.GENERICATTRIBUTE1,
        CSI.GENERICATTRIBUTE4,
        TMP_PDS.subcanal,
        CSI.GENERICATTRIBUTE7 wbe,
        38280596832649318
		
    FROM ENEL_INCEN_TEMP_TF CSI --CS_INCENTIVE CSI
        INNER JOIN ENEL_PROVEEDORES_TEMP EPT
            ON EPT.IDPROVEEDOR=CSI.GENERICATTRIBUTE2

		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			on CSI.payeeseq=TMP_PDS.payeeseq 
			and CSI.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and CSI.periodseq=TMP_PDS.periodseq
			and TMP_PDS.TITLE_NAME not like 'RETAIL TF RESP'

    WHERE 
		CSI.periodseq = iperiodseq 
		and (CSI.NAME LIKE 'I - Captacion TF - Rappel Cuantitativo - Objetivo % TF%'
			or CSI.NAME LIKE 'I - Captacion TF - Rappel Cuantitativo Extra rappel - Objetivo % TF %'
			or CSI.NAME LIKE 'I -%- Captacion TF - Tasa Mortandad'
			or CSI.NAME LIKE 'I - Captacion TF - Bonus exclusivo Permanencia TF'
			OR CSI.NAME LIKE 'I - Captacion TF - Incentivo Directo Luz MENOR 10Kw'
			or CSI.Name like '%I - Captacion Stands - Rappel Cuantitativo%'
			or CSI.NAME LIKE 'I - Captacion Stands Reticulae - Rappel Cuantitativo%'
			or CSI.NAME LIKE 'I - Captacion Nuevos Stands - Rappel Cuantitativo%'
			or CSI.NAME like 'I - % Stands Reticulae - % (Imp. %)'
			or CSI.NAME like 'I - % Nuevos Stands - % (Imp. %)'
			or CSI.NAME LIKE 'I - Captacion TF - Importe Fijo TF %'
			or CSI.NAME LIKE 'I - Captacion Stands TV - Rappel Cuantitativo - Objetivo %'
			or CSI.NAME LIKE 'I - Captacion RETAIL TF - Rappel %'
			or CSI.NAME LIKE 'I - Captacion AAFF - Rappel %'
			or CSI.NAME LIKE 'I - Captacion TW - Rappel %'
			or CSI.NAME LIKE 'I - Captacion VR - Rappel %'
            or CSI.NAME LIKE 'I - Captacion Stands - BONUS Rappel Cuantitativo%'
            or CSI.NAME LIKE 'I - Captacion Stands TV - Rappel Cuantitativo - ST%'
            or CSI.NAME LIKE 'I - Captacion VR - Reg Trim - Rappel Cuantitativo - Objetivo %'
            or CSI.NAME LIKE 'I - Captacion AAFF - 012 - Luz menor 10 VC Regularización Rappel Trim'
            or CSI.NAME LIKE 'I - Captacion AAFF - 012 - Luz mayor 10 VC Regularización Rappel Trim'
            or CSI.NAME LIKE 'I - Captacion RETAIL TF - Retrocesi%n Rappel%'
            or CSI.NAME LIKE 'I - Captacion VR - Incentivo Base Contratacion%'
            OR CSI.NAME LIKE 'I - Captacion TW - Incentivo Base Contratacion%'
            OR CSI.NAME LIKE 'I - Captacion AAFF - Incentivo Base Contratacion%'
            OR CSI.NAME LIKE 'I - Captacion TW - Ricorrente -%' --APM 15.01.2025
            OR CSI.NAME LIKE 'I - Captacion VR - TdM%' --APM 06.05.2025
            or CSI.NAME like 'I - Captacion VR - TM%' --APM 08.05.2025
            or csi.name like 'I - Renovacion VR - %'
            or csi.name like 'I - Renovacion AAFF - %'
            or CSI.NAME LIKE 'I - Captacion VR - Incentivo Transversal % - %'
            or CSI.NAME LIKE 'I - Captacion AAFF - Incentivo Transversal % - %'
            or CSI.NAME LIKE 'I - Captacion RETAIL TF - Incentivo Transversal % - %'
            OR CSI.NAME LIKE 'I - Captacion VR - Ricorrente -%' --APM 22.01.2026
            /*BOM APM 25.03.2026*/
            or CSI.NAME LIKE 'I - Captacion Stands - Rappel %'
            or CSI.NAME LIKE 'I - Captacion Stands - Retrocesi%n Rappel%'
            or CSI.NAME LIKE 'I - Captacion Stands - Incentivo Transversal % - %'
            or CSI.name like 'I - Captacion RETAIL TF - TdM - 01% - % Malus'
            or CSI.name LIKE 'I - Captacion Stands - TdM - 01% - % Malus'
            /*BOM APM 25.03.2026*/
            /*BOM APM 19.05.2026 New Code*/
            or CSI.name like 'I - Activacion AAFF - Incentivo Transversal % - %' 
            or CSI.name LIKE 'I - Activacion AAFF - % Regularizaci%n Rappel Trim' 
            or CSI.name LIKE 'I - Activacion AAFF - Rappel%' 
            or CSI.name LIKE 'I - Activacion VR - Incentivo Base Contratacion%'
            or CSI.name LIKE 'I - Activacion VR - % - Rappel%'
            or CSI.name LIKE 'I - Activacion VR - Rappel%'
            /*EOM APM 19.05.2026*/
		) 
		and csi.value<>0      
    ;
    
    filas := sql%rowcount;
    COMMIT;
	
	w_debug('Fin Carga de la tabla ENEL_RAPPELES_WBE - incentivos: '|| to_char(filas) || ' filas.', v_contador_debug);
   
    INSERT INTO ENELEXT.ENEL_RAPPELES_WBE(PERIODO, NAME, IMPORTE, CODIGO_PDS_OCAP, CICLO_FACTURACION, PROVEEDOR, IDPROVEEDOR, subcanal, wbe, PROCESSINGUNITSEQ)
    Select 
        --cspe.name,
		iperiod,
        csd.name,
        TRIM(replace(to_char(csd.VALUE , '9999999999990D99'), ',', '.')) IMPORTE_COMISION,
        TMP_PDS.PAYEEID,
        v_txtFechaLiquidacion,
        EPT.DESCRIPCION,
        CSD.earninggroupid,
        TMP_PDS.subcanal,
        CSd.wbe wbe,
        38280596832649318
    
    from ENEL_DEPOSIT_TEMP_TF CSD --cs_deposit csd
        
		INNER JOIN ENEL_PROVEEDORES_TEMP_TF EPT
            ON EPT.IDPROVEEDOR=CSd.earninggroupid          
        
		LEFT JOIN ENEL_PDS_TEMP_TF TMP_PDS
			on CSd.payeeseq=TMP_PDS.payeeseq 
			and CSd.POSITIONSEQ=TMP_PDS.RULEELEMENTOWNERSEQ
			and CSd.periodseq=TMP_PDS.periodseq
    
    WHERE 
		CSD.NAME LIKE 'D - % - Captacion TF - Rappel cualitativo' 
		and csd.value >0
	;
    
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_RAPPELES_WBE - depósitos: '|| to_char(filas) || ' filas.', v_contador_debug);
dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_RAPPELES_WBE',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_RAPPELES_WBE COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_RAPPELES_WBE.',v_contador_debug);

  /*  z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_rappeles_tf', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_rappeles_tf', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

end;

procedure p_Taksforce_Aprovisionamiento ( iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS   
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_TF_APROVISIONAMIENTO.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_TF_APROVISIONAMIENTO WHERE  ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
    w_debug('Fin Borrado de la tabla ENEL_TF_APROVISIONAMIENTO.', v_contador_debug);

    w_debug('Insertando datos en tabla ENEL_TF_APROVISIONAMIENTO.' ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_TF_APROVISIONAMIENTO(TENANTID, PERIODSEQ, PERIODO, PDS, NOMBRE_FISCAL, NAME, REGISTROS, SUM_VALUE, COSTE_UNITARIO)
	SELECT 
		CRED.TENANTID,
		CRED.PERIODSEQ,
		CRED.PERIODO,
		PDS.PDS,
		PDS.NOMBRE_FISCAL,
		CATEG.NAME,
		COUNT(*),
		SUM(CRED.VALUE),
		ROUND((SUM(CRED.VALUE)/COUNT(*)), 2)

	FROM ENEL_CREDIT_TEMP_TF CRED
		INNER JOIN ENEL_TXN_TEMP_TF TXN 
			ON CRED.GENERICATTRIBUTE9 = TXN.ORDERID --relación transacción
     
		INNER JOIN ENEL_PDS_TEMP_TF PDS 
			ON CRED.GENERICATTRIBUTE4 = PDS.PDS --relación código comercial
     
		INNER JOIN ENEL_PRODUCTOS_TEMP_TF PROD 
			ON CRED.GENERICATTRIBUTE8 = PROD.PRODUCTID --relación ID producto
     
		INNER JOIN CS_CLASSIFIER CLAS 
			ON PROD.PRODUCTID = CLAS.CLASSIFIERID --categoría producto
     
		INNER JOIN CS_CATEGORY_CLASSIFIERS CATEGC 
			ON CLAS.CLASSIFIERSEQ = CATEGC.CLASSIFIERSEQ --categoría producto
     
		INNER JOIN CS_CATEGORYTREE CATEGT 
			ON CATEGC.CATEGORYTREESEQ = CATEGT.CATEGORYTREESEQ --categoría producto
     
		INNER JOIN CS_CATEGORY CATEG 
			ON CATEGC.CATEGORYSEQ = CATEG.RULEELEMENTSEQ --categoría producto
     
	WHERE 
		CRED.NAME LIKE '%Captacion TF - Importe Base%'
		AND CRED.COMPENSATIONDATE BETWEEN CLAS.CREATEDATE AND CLAS.REMOVEDATE
		AND CRED.COMPENSATIONDATE BETWEEN CATEGC.CREATEDATE AND CATEGC.REMOVEDATE
		AND CRED.COMPENSATIONDATE BETWEEN CATEGT.CREATEDATE AND CATEGT.REMOVEDATE
		AND CRED.COMPENSATIONDATE BETWEEN CATEG.CREATEDATE AND CATEG.REMOVEDATE
		AND CATEGT.NAME = 'Productos PUSH'
		AND (CATEG.NAME = 'GAS'
			OR CATEG.NAME = 'LUZ < 10 GESTIÓN CARTERA (EE - EE)'
			OR CATEG.NAME = 'LUZ < 10 GESTIÓN CARTERA (EEXXI - EE)'
			OR CATEG.NAME = 'LUZ < 10 COMPETITIVAS (OTRA COMERCIALIZADORA - EE)'
			OR CATEG.NAME = 'LUZ > 10 GESTIÓN CARTERA (EE - EE)'
			OR CATEG.NAME = 'LUZ > 10 GESTIÓN CARTERA (EEXXI - EE)'
			OR CATEG.NAME = 'LUZ > 30 GESTIÓN CARTERA (EE - EE)'
			OR CATEG.NAME = 'LUZ > 30 GESTIÓN CARTERA (EEXXI - EE)'
			OR CATEG.NAME = 'LUZ > 10 COMPETITIVAS (OTRA COMERCIALIZADORA - EE)'
			OR CATEG.NAME = 'LUZ > 30 COMPETITIVAS (OTRA COMERCIALIZADORA - EE)'
			OR CATEG.NAME = 'OKGAS'
			OR CATEG.NAME = 'OKGAS CALENTADOR'
			OR CATEG.NAME = 'OKLUZ ASSIST'
			OR CATEG.NAME = 'OKLUZ NEGOCIO'
			OR CATEG.NAME = 'SMAP NEGOCIO'
			OR CATEG.NAME = 'PROTECCION DE PAGOS GAS'
			OR CATEG.NAME = 'PROTECCION DE PAGOS LUZ'
		)
		AND CRED.TENANTID = itenantId 
     
	GROUP BY 
		CRED.TENANTID,
		CRED.PERIODSEQ,
		CRED.PERIODO,
		PDS.PDS,
		PDS.NOMBRE_FISCAL,
		CATEG.NAME; 
    
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TF_APROVISIONAMIENTO: '|| to_char(filas) || ' filas.', v_contador_debug);
    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TF_APROVISIONAMIENTO',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);

   -- EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_TF_APROVISIONAMIENTO COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TF_APROVISIONAMIENTO.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Taksforce_Aprovisionamiento', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Taksforce_Aprovisionamiento', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;

--BOM APM 16/12/2024 - Ricorrente
procedure p_creditos_ricorrente (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();
    
    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_TF_6M.', v_contador_debug);
   BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_TF_6M WHERE periodo_anual = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_TF_6M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_TF_6M. Periodo:'|| iperiod ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_TF_6M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL )
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
        BU.NAME AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-6)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    inner JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ
   
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
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
	WHERE
		inc.TENANTID = itenantId 
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';
    
    /*FROM CS_CREDIT credit
        INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-6)
            and per.periodseq = credit.periodseq
            and per.removedate= v_eot
            
       INNER JOIN CS_SALESTRANSACTION txn
			ON credit.SALESTRANSACTIONSEQ = txn.SALESTRANSACTIONSEQ
            AND txn.processingunitseq = credit.processingUnitSeq
            AND txn.tenantid = credit.TENANTID
            AND txn.modelseq = 0
            
        INNER JOIN cs_salesorder ordtxn
			ON txn.salesorderseq = ordtxn.salesorderseq
			AND ordtxn.removedate  = v_eot
			AND ordtxn.processingunitseq = txn.processingunitseq
			AND ordtxn.tenantid = txn.tenantid
	
		LEFT JOIN CS_COMMISSION COMMI
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ
        
		LEFT JOIN CS_INCENTIVE INC
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq
            AND INC.periodseq = COMMI.periodseq
            AND INC.pipelinerunseq = COMMI.pipelinerunseq
            
        INNER JOIN cs_position pos
            ON pos.payeeseq = credit.payeeseq
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
        INNER JOIN CS_BUSINESSUNIT BU 
			ON credit.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            and inc.name like '%Ricorrente%'
    
	WHERE
		credit.TENANTID = itenantId 
		AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq;
		--AND credit.PERIODSEQ =  iperiodseq; */

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_6M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_TF_6M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_TF_6M.',v_contador_debug);
    
    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);*/

    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_TF_12M.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_TF_12M WHERE periodo_anual = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_TF_12M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_TF_12M. Periodo:'|| iperiod ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_TF_12M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL )
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        ordtxn.ORDERID, -- ID Referencia
		credit.NAME,
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto, 
        CREDIT.GENERICATTRIBUTE16 AS NOMBRE_PROVEEDOR, 
        TXN.COMPENSATIONDATE AS FECHA_CAPTACION,           --FechaCalculo 
        INC.GENERICATTRIBUTE4 AS TERRITORIO, 
		COMMI.VALUE,                --Importe Comision
        INC.GENERICATTRIBUTE1 AS OBSERVACIONES, 
        BU.NAME AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-12)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    inner JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ

        
		
       
            
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
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
    
	WHERE
		inc.TENANTID = itenantId 
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_TF_12M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_TF_12M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_TF_12M.',v_contador_debug);
    
    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_TF_24M.', v_contador_debug);
   BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_TF_24M WHERE periodo_anual = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_TF_24M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_TF_24M. Periodo:'|| iperiod ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_TF_24M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL )
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
        BU.NAME AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-24)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    inner JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ
   
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
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
	WHERE
		inc.TENANTID = itenantId 
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';
    

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_6M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_TF_24M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_TF_24M.',v_contador_debug);
    
    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_TF_36M.', v_contador_debug);
   BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_TF_36M WHERE periodo_anual = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_TF_36M.', v_contador_debug);

    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_TF_36M. Periodo:'|| iperiod ,  v_contador_debug);

    /*z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_creditos_ricorrente', v_finicio, current_timestamp(), null);*/

	INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_TF_36M( TENANTID, PERIODO, PERIODSEQ, ORDERID, NAME, CUPS, PRODUCTO, NOMBRE_PROVEEDOR, FECHA_CAPTACION, TERRITORIO, 
												VALUE, OBSERVACIONES, BUSINESSUNIT, PERIODO_ANUAL, PAYEESEQ, POSITIONSEQ,PROVEEDOR,CIF,CODIGO_COMERCIAL )
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
        BU.NAME AS BUSINESS_UNIT,
        iperiod AS PERIODO_ANUAL,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        par.lastname AS PROVEEDOR,
        par.genericattribute1 AS CIF,
        pos.name AS CODIGO_COMERCIAL
        
	FROM CS_INCENTIVE INC
    
    LEFT JOIN  CS_COMMISSION COMMI
			ON INC.INCENTIVESEQ = COMMI.INCENTIVESEQ
            AND INC.payeeseq = COMMI.payeeseq
            AND INC.positionseq = COMMI.positionseq  
    
     INNER JOIN CS_PERIOD per
            ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-36)
            and per.periodseq = commi.periodseq
            and per.removedate= '01/01/2200'
            
    inner JOIN CS_CREDIT credit 
			ON COMMI.CREDITSEQ = credit.CREDITSEQ
            AND COMMI.PAYEESEQ = credit.PAYEESEQ
   
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
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON inc.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
	WHERE
		inc.TENANTID = itenantId 
		AND inc.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and inc.name like 'C%Ricorrente%';
    

    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_6M: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_TF_36M',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_TF_36M.',v_contador_debug);

    --BOM APM 14/05/2025
    w_debug('Inicio Truncado de la tabla ENEL_CRE_RICORRENTE_DIAS_TF.', v_contador_debug);
    BEGIN
        LOOP
            DELETE FROM ENELEXT.ENEL_CRE_RICORRENTE_DIAS_TF WHERE PERIODO = iperiod and ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
    END;
	w_debug('Fin Truncado de la tabla ENEL_CRE_RICORRENTE_DIAS_TF.', v_contador_debug);

    /*w_debug('Cargando tabla ENEL_CRE_RICORRENTE_DIAS_TF para AAFF. Periodo:'|| iperiod ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_DIAS_TF( TENANTID, PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, ORDERID, CUPS, PRODUCTO, 
                                                    SUBCANAL, COMERCIAL, FECHA_BAJA, MESES_6, MESES_12, BUSINESS_UNIT, PERIODO_ANUAL,
                                                    COMPENSATIONDATE)
	SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        ordtxn.ORDERID, -- ID Referencia
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto,
        POS.NAME AS SUBCANAL,
        TXNASS.GENERICATTRIBUTE1 as COMERCIAL,
        txn.GENERICDATE5 AS FECHA_BAJA,
        ADD_MONTHS(txn.compensationdate, 6) AS MESES_6,
        ADD_MONTHS(txn.compensationdate, 12) AS MESES_12,
        BU.NAME AS BUSINESS_UNIT,
        REGEXP_SUBSTR(per.name, '\d{4}')AS PERIODO_ANUAL,
        txn.compensationdate as COMPENSATIONDATE

    FROM CS_CREDIT credit
 
     INNER JOIN CS_PERIOD per
            --ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-12)
            on per.periodseq = credit.periodseq
            and per.removedate= '01/01/2200'
          
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
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON credit.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
        LEFT JOIN CS_TRANSACTIONASSIGNMENT txnass
			ON txn.SALESTRANSACTIONSEQ  = txnass.SALESTRANSACTIONSEQ   
			AND txn.processingunitseq = txnass.processingunitseq
			AND txnass.tenantid = txn.tenantid
			AND txn.compensationdate = txnass.compensationdate
			AND txnass.setnumber > 0
            
        INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
    
	WHERE
		credit.TENANTID = itenantId 
		AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and CTYPE.CREDITTYPEID='Captacion - AAFF (BV)'
        and ((txn.genericboolean3=0 or txn.genericboolean3 is null)
        or (txn.genericboolean3=1 and txn.genericnumber5 < 6))
        and (credit.genericattribute2='011' or credit.genericattribute2='012')
        ;

    filas := sql%rowcount;
    COMMIT;
    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_DIAS_TF - AAFF: '|| to_char(filas) || ' filas.', v_contador_debug);*/
    
    w_debug('Cargando tabla ENEL_CRE_RICORRENTE_DIAS_TF para VR. Periodo:'|| iperiod ,  v_contador_debug);

    INSERT INTO ENELEXT.ENEL_CRE_RICORRENTE_DIAS_TF(TENANTID, PERIODO, PERIODSEQ, PAYEESEQ, POSITIONSEQ, ORDERID, CUPS, PRODUCTO, 
                                                    SUBCANAL, COMERCIAL, FECHA_BAJA, MESES_6, MESES_12, BUSINESS_UNIT, PERIODO_ANUAL,
                                                    COMPENSATIONDATE, FECHA_ACTIVACION,GA5,GA8, MESES_6_ACTIVACION, MESES_12_ACTIVACION,
                                                    MESES_24, MESES_36)
    
    
    SELECT 
		credit.TENANTID,
		per.name,
        CREDIT.periodseq,
        CREDIT.PAYEESEQ,
        CREDIT.POSITIONSEQ,
        ordtxn.ORDERID, -- ID Referencia
        txn.ALTERNATEORDERNUMBER AS CUPS, 
        txn.productid as producto,
        POS.NAME AS SUBCANAL,
        TXNASS.GENERICATTRIBUTE1 as COMERCIAL,
        txn.GENERICDATE5 AS FECHA_BAJA,
        ADD_MONTHS(txn.compensationdate, 6) AS MESES_6,
        ADD_MONTHS(txn.compensationdate, 12) AS MESES_12,
        BU.NAME AS BUSINESS_UNIT,
        REGEXP_SUBSTR(per.name, '\d{4}')AS PERIODO_ANUAL,
        txn.compensationdate as COMPENSATIONDATE,
        txn.GENERICDATE6 as FECHA_ACTIVACION,
        CREDIT.GENERICATTRIBUTE5 AS GA5,
        CREDIT.GENERICATTRIBUTE8 AS GA8,
        /*BOM APM 18.12.2025*/
        ADD_MONTHS(txn.GENERICDATE6, 6) AS MESES_6_ACTIVACION,
        ADD_MONTHS(txn.GENERICDATE6, 12) AS MESES_12_ACTIVACION,
        /*EOM APM 18.12.2025*/
        /*BOM APM 22.01.2026*/
        ADD_MONTHS(txn.compensationdate, 24) AS MESES_24,
        ADD_MONTHS(txn.compensationdate, 36) AS MESES_36
        /*EOM APM 22.01.2026*/

    FROM CS_CREDIT credit
 
     INNER JOIN CS_PERIOD per
            --ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-12)
            on per.periodseq = credit.periodseq
            and per.removedate= '01/01/2200'
          
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
            AND pos.removedate  = '01/01/2200'
            AND pos.tenantid = credit.tenantid
            and POS.PROCESSINGUNITSEQ =  credit.processingUnitSeq
            AND pos.EFFECTIVESTARTDATE <= per.startdate             
			AND pos.EFFECTIVEENDDATE >= per.enddate
            
          left JOIN CS_PARTICIPANT par ON POS.PAYEESEQ = PAR.PAYEESEQ
            AND par.TENANTID = itenantId
            AND par.REMOVEDATE = v_eot
            AND PAR.EFFECTIVESTARTDATE <= PER.ENDDATE - 1
            AND PAR.EFFECTIVEENDDATE >= PER.ENDDATE - 1
            
        inner JOIN CS_BUSINESSUNIT BU 
			ON credit.BUSINESSUNITMAP = BU.MASK
			AND BU.TENANTID = itenantId
            
        LEFT JOIN CS_TRANSACTIONASSIGNMENT txnass
			ON txn.SALESTRANSACTIONSEQ  = txnass.SALESTRANSACTIONSEQ   
			AND txn.processingunitseq = txnass.processingunitseq
			AND txnass.tenantid = txn.tenantid
			AND txn.compensationdate = txnass.compensationdate
			AND txnass.setnumber > 0
        INNER JOIN CS_CREDITTYPE ctype ON credit.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
    
	WHERE
		credit.TENANTID = itenantId 
		AND credit.PROCESSINGUNITSEQ = iprocessingUnitSeq
        and (CTYPE.CREDITTYPEID='Captacion - VR (BV)' or CTYPE.CREDITTYPEID='Captacion - TW (BV)')
       -- and ((txn.genericboolean3=0 or txn.genericboolean3 is null)
       -- or (txn.genericboolean3=1 and txn.genericnumber5 < 6))
        /*BOM APM 15.12.2025*/
        --Old Code
        --and (credit.genericattribute2='011' or credit.genericattribute2='012')
        --New Code
        and (credit.genericattribute2='287' or credit.genericattribute2='288')
        /*EOM APM 15.12.2025*/
        and credit.periodseq = iperiodseq
        ;

    filas := sql%rowcount;
    COMMIT;
    
    UPDATE ENELEXT.ENEL_CRE_RICORRENTE_DIAS_TF tf
SET (FECHA_BAJA, FECHA_ACTIVACION) = (
    SELECT
        txn.GENERICDATE5,
        txn.GENERICDATE6
    FROM CS_SALESTRANSACTION txn
    LEFT JOIN cs_salesorder ordtxn
        ON txn.salesorderseq = ordtxn.salesorderseq
        AND ordtxn.removedate = DATE '2200-01-01'
        AND ordtxn.processingunitseq = txn.processingunitseq
        AND ordtxn.tenantid = txn.tenantid
    INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = '01/01/2200'
			AND txn.tenantid = etype.tenantid
	LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
    WHERE txn.ALTERNATEORDERNUMBER = tf.CUPS
      AND txn.TENANTID = 'ENEL'
      AND txn.PROCESSINGUNITSEQ = 38280596832649318
      AND txn.MODELSEQ = 0
      AND ordtxn.orderid = tf.orderid
      AND ETYPE.EVENTTYPEID like 'Captacion%'
      AND TXN.COMPENSATIONDATE=TF.COMPENSATIONDATE
	  and (txn.genericdate5 between (select per.startdate from cs_period per where per.periodseq=iperiodseq and per.removedate='01/01/2200') and (select per.enddate from cs_period per where per.periodseq=iperiodseq and per.removedate='01/01/2200')
	  or (txn.compensationdate > ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-6)
	  and etxn0.genericattribute3 is not null and txn.genericdate5 is null))
)
WHERE EXISTS (
    SELECT 1
    FROM CS_SALESTRANSACTION txn
    LEFT JOIN cs_salesorder ordtxn
        ON txn.salesorderseq = ordtxn.salesorderseq
        AND ordtxn.removedate = DATE '2200-01-01'
        AND ordtxn.processingunitseq = txn.processingunitseq
        AND ordtxn.tenantid = txn.tenantid
    INNER JOIN cs_eventtype etype
			ON txn.eventtypeseq = etype.datatypeseq
			AND etype.removedate  = '01/01/2200'
			AND txn.tenantid = etype.tenantid
	LEFT JOIN CS_GASALESTRANSACTION etxn0   
			ON txn.SALESTRANSACTIONSEQ = etxn0.SALESTRANSACTIONSEQ
			AND etxn0.tenantid = txn.tenantid
			AND txn.processingunitseq = etxn0.processingunitseq
			AND etxn0.pagenumber = 0
			AND etxn0.compensationdate = txn.compensationdate 
    WHERE txn.ALTERNATEORDERNUMBER = tf.CUPS
      AND txn.TENANTID = 'ENEL'
      AND txn.PROCESSINGUNITSEQ = 38280596832649318
      AND txn.MODELSEQ = 0
      AND ETYPE.EVENTTYPEID like 'Captacion%'
      AND ordtxn.orderid = tf.orderid
      AND TXN.COMPENSATIONDATE=TF.COMPENSATIONDATE
	  and (txn.genericdate5 between (select per.startdate from cs_period per where per.periodseq=iperiodseq and per.removedate='01/01/2200') and (select per.enddate from cs_period per where per.periodseq=iperiodseq and per.removedate='01/01/2200')
	  or (txn.compensationdate > ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-6)
	  and etxn0.genericattribute3 is not null and txn.genericdate5 is null))
);

 COMMIT;

    w_debug('Fin Carga de la tabla ENEL_CRE_RICORRENTE_DIAS_TF - VR: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_CRE_RICORRENTE_DIAS_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_CRE_RICORRENTE_DIAS_TF.',v_contador_debug);
    --EOM APM 14/05/2025
end;
--EOM APM 16/12/2024

--BOM APM 28/05/2025 - TM2 y TM12
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
            DELETE FROM ENELEXT.ENEL_TM2_MENSUAL_TF WHERE PERIODO_BIMENSUAL = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;
        
		LOOP
            DELETE FROM ENELEXT.ENEL_TM12_MENSUAL_TF WHERE PERIODO_ANUAL = iperiod AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
        END LOOP;    
    

    w_debug('Cargando tabla ENEL_TM2_MENSUAL_TF. Periodo:'|| iperiod ,  v_contador_debug);

	INSERT INTO ENELEXT.ENEL_TM2_MENSUAL_TF(PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION, 
                                        FILTRO_PRD, FECHA_ALTA, FECHA_BAJA , PERIODO_BIMENSUAL ,NUM_DIAS, MOTIVO_BAJA, PRESCRIPTOR, 
                                        MOTIVO_SOLICITUD)
    SELECT per.name,
		per.periodseq,
		ordtxn.ORDERID,
        TXN.LINENUMBER,
        TXN.SUBLINENUMBER,
        ETYPE.EVENTTYPEID,
        '1' AS IMPORTE_COMISION,--COMMI.VALUE as IMPORTE_COMISION,
        'EURO',
        TRIM(replace(to_char(ECT.value , '9999999999990D99'), ',', '.')) VALOR_1,
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
         ECT.GENERICATTRIBUTE10 as PRESCRIPTOR,
        TXN.GENERICATTRIBUTE5 AS MOTIVO_SOLICITUD --APM 19.12.2025

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
      WHERE (ctype.CREDITTYPEID LIKE '%Captacion - VR (BV)%'
            or ctype.CREDITTYPEID LIKE '%Captacion - RETAIL TF (BV)%' --APM 03.06.2025
            or ctype.CREDITTYPEID LIKE '%Captacion - Stands (BV)%' --APM 25.03.2026
            or ctype.CREDITTYPEID  = 'Captacion - AAFF (BV)') --APM 28.04.2026
        and (TEMP_PROV.IDPROVEEDOR = '011' 
            or TEMP_PROV.IDPROVEEDOR = '012')        
        and ECT.GENERICBOOLEAN1 = 1
        and ECT.GENERICATTRIBUTE1 is not null
        and (ETYPE.eventtypeid = 'Captacion VR'
        or ETYPE.eventtypeid = 'Captacion RETAIL TF'
        or ETYPE.eventtypeid = 'Captacion TW' --APM 03.06.2025
        or ETYPE.eventtypeid = 'Captacion Stands' --APM 25.03.2026
        or ETYPE.eventtypeid = 'Captacion AAFF') --APM 28.04.2026
    ;
 
    filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga de la tabla ENEL_TM2_MENSUAL: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TM2_MENSUAL_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_TM2_MENSUAL_TF.',v_contador_debug);
    
    w_debug('Insertando Registros de datos en tabla ENEL_TM12_MENSUAL_TF.' ,  v_contador_debug);
    INSERT INTO ENELEXT.ENEL_TM12_MENSUAL_TF (PERIODO, PERIODSEQ, ORDERID, LINENUMBER, SUBLINENUMBER, EVENTTYPEID, IMPORTE, UNIDAD, VALOR_1, UNIDAD_1, PRODUCTO_SCAWEB, CODIGO_PDS_OCAP, 
										CICLO_FACTURACION, ESTADO, IDPROVEEDOR, NUMPROVEEDOR, INCIDENCIA, CREDITTYPEID, ESTADO_CTRLCALIDAD, Nom_Credito, PRODUCTO,
										CUPS, FECHA_FIRMA, PEDIDO_CRM, PAYEESEQ, POSITIONSEQ, PERIODO_LIQ, ALTAS, BAJAS, PORC_TDM, IMPORTE_COMISION, 
                                        FILTRO_PRD, FECHA_ALTA, FECHA_BAJA , PERIODO_ANUAL ,NUM_DIAS, MOTIVO_BAJA, PRESCRIPTOR,
                                        MOTIVO_SOLICITUD)
    
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
		ect.name,--INC.name,
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
        iperiod AS PERIODO_ANUAL,       
        to_date(TXN.GENERICDATE5) - to_date(TXN.GENERICDATE4) as NUM_DIAS,
        etxn0.GENERICATTRIBUTE3 as MOTIVO_BAJA,
        ect.genericattribute10 as PRESCRIPTOR,
        TXN.GENERICATTRIBUTE5 AS MOTIVO_SOLICITUD --APM 19.12.2025

    FROM cs_credit ECT
    INNER JOIN CS_CREDITTYPE ctype ON ECT.CREDITTYPESEQ = ctype.DATATYPESEQ 
			AND ctype.TENANTID = itenantId
			AND ctype.REMOVEDATE  = v_eot
		INNER JOIN CS_PERIOD PER
           ON per.STARTDATE = ADD_MONTHS((select STARTDATE from CS_PERIOD where name = iperiod and removedate= '01/01/2200'  ),-13)
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

      WHERE (ctype.CREDITTYPEID LIKE '%Captacion - VR (BV)%' 
      or ctype.CREDITTYPEID LIKE '%Captacion - TW (BV)%' 
      or ctype.CREDITTYPEID  = 'Captacion - AAFF (BV)') --APM 28.04.2026
        and (TEMP_PROV.IDPROVEEDOR = '011' 
            or TEMP_PROV.IDPROVEEDOR = '012')
        and ECT.GENERICBOOLEAN1 = 1
        and ECT.GENERICATTRIBUTE1 is not null
        and (ETYPE.eventtypeid = 'Captacion VR'
        or ETYPE.eventtypeid = 'Captacion RETAIL TF'
        or ETYPE.eventtypeid = 'Captacion TW'
        or ETYPE.eventtypeid = 'Captacion AAFF') --APM 28.04.2026
    ;
    filas := sql%rowcount;
    COMMIT;
  
    w_debug('Fin Carga de la tabla ENEL_TM12_MENSUAL_TF: '|| to_char(filas) || ' filas.', v_contador_debug);

    dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_TM12_MENSUAL_TF',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);


end;
--EOM APM 28/05/2025

--BOM APM 03/12/2025
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
--EOM APM 03/12/2025

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

    --------------- Comprobar si es una ejecuci?n por StageHook o manual --------------
    /*BOM DCR 15.05.2023 - 2.11 - Creamos variables auxiliares para informar el periodo y PU */
    v_periodo := period;
    v_puseq := processingUnitSeq;
    /*EOM  DCR 15.05.2023 - 2.11 */
/* BOM - DCR - Gestion Control de Informes */
begin 
    v_FInicio_Inf := current_timestamp();
    
    SELECT id +1, num_ejecucion +1 INTO v_contador_ctrl_inf, v_num_ejecucion FROM enelext.enel_ctrl_informes
        WHERE id = (SELECT MAX(id) FROM enelext.enel_ctrl_informes);
        --AND paquete = 'ENEL_ACTUALIZA_INFORMES_TF';
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
			-- SCAWEB_FINAL
			UPDATE ENELEXT.ENEL_LIQSCAWEB_FINAL_TF
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq
			;

			--SCAWEB_FINAL_WBE
			UPDATE ENELEXT.ENEL_LIQSCAWEB_FINAL_WBE
			SET ESTADO = 'Liquidado'
			, CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq
			;

			--RAPPELES
			UPDATE ENELEXT.ENEL_RAPPELES_TF
			SET CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = v_periodo
			and PROCESSINGUNITSEQ = v_puseq
			;

			--RAPPELES_WBE
			UPDATE ENELEXT.ENEL_RAPPELES_WBE
			SET CICLO_FACTURACION = to_char(SYSDATE, 'DD/MM/YYYY')
			WHERE Periodo = period
			and PROCESSINGUNITSEQ = 38280596832649318
			;
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
        -- Volcar datos de clasificacion a una Temporal de Operaciones Tabla ENEL_OPERACIONES_TEMP        
        p_Temporal_Operaciones ( period ,periodSeq , tenantId  );   
        -- Volcar datos de Productos a una Temporal Tabla ENEL_PRODUCTOS_TEMP   
        p_Temporal_Productos ( period ,periodSeq , tenantId  );

        p_Temporal_E4E_Negativos_TF ( period ,periodSeq , tenantId  );
        
        p_rappeles_TF ( period ,periodSeq , tenantId , v_Interfaz_Proceso );
        p_Eco_FINAL_TF (  period ,periodSeq , tenantId ,processingUnitSeq );
        p_Taksforce_Aprovisionamiento ( period,periodseq, tenantId );
        p_Inf_Factura_TF_Detalle ( processingUnitSeq, period,periodSeq, tenantId );
        p_Inf_Factura_TF_Portada ( processingUnitSeq, period,periodSeq, tenantId );
        p_creditos_ricorrente (processingUnitSeq, period,periodSeq, tenantId ); --APM 16.12.2024
        p_informe_tasa_mortandad ( processingUnitSeq, period,periodseq, tenantId, v_Interfaz_Proceso);

        IF f_ExisteInformeEnLista('E4E', v_Listado_Informes) THEN
            -- Volcar datos de clasificaci?n a una Temporal de Contratos.     Tabla ENEL_E4E_CONTRATOS_TEMP
            p_Temporal_Contratos_E4E ( period ,periodSeq , tenantId  );
            -- Extraer datos de Dep?sitos y JOIN con tablas temporales Tabla: ENEL_E4E_DEPOSIT_TEMP
            p_Temporal_Depositos_E4E_TF  ( processingUnitSeq, period ,periodSeq , tenantId, v_Interfaz_Proceso  );
            -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 1 
            p_Final_E4E_TF_1  ( period ,periodSeq , tenantId  );
            -- Extraer datos de TEMP_Depositos. Tabla: ENEL_E4E_FINAL Fichero 2 
            p_Final_E4E_TF_2  ( period ,periodSeq , tenantId  );        
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'E4E_TF');

            if v_Interfaz_Proceso = 'ACTUALIZA_INFORMES_REWARD' THEN  -- v2.4
                -- Los datos Negativos solo se extraen enel REWARD
                -- Extraer datos NEGATIVOS de TEMP_Depositos. Tabla: ENEL_E4E_NEGATIVOS
                p_Final_E4E_Negativos_TF  ( processingUnitSeq, period ,periodSeq , tenantId  );
                -- Actualizamos la fecha del informe en la tabla 
                p_Actualiza_Informe_Fecha ( period, 'E4ENEG_TF');          
            end if;
     
            -- Generamos datos de resumen de pagos
            p_Informe_Resumen_Pagos( processingUnitSeq, period ,periodSeq , tenantId  );
        
        end if;

        ------------------------------------
        -- Datos para INTERFACE SCAWEB
        ------------------------------------
        --if v_Listado_Informes = 'ALL' OR v_Listado_Informes = 'ANDROMEDA' then
        IF f_ExisteInformeEnLista('SCAWEB', v_Listado_Informes) THEN
            -- Extraer datos de creditos calculados para el periodo -> Tabla : ENEL_SCAWEB_LIQUIDACION   
            p_Temporal_Creditos_Scaweb_TF  ( processingUnitSeq, period ,periodSeq , tenantId  );    
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'SCAWEB_TF');      
        end if;
        
        -- Comparativa Pagos solo se hace si se ejecutan todos los informes
        IF v_Listado_Informes = 'ALL' THEN
            p_Comp_Pagos_SCAWEB_E4E_TF ( processingUnitSeq, period ,periodSeq , tenantId  );
             p_Comp_Pagos_SCAWEB_E4E_CAB_TF ( processingUnitSeq, period ,periodSeq , tenantId  ); -- RMM 31.05.2022
            p_Actualiza_Informe_Fecha ( period, 'SCAWEB_E4E_TF');
        end if;        
        
        ---------------------------------------------------
        -- Datos para INFORMES GENERAL DE PROVEEDORES
        ---------------------------------------------------    
        IF f_ExisteInformeEnLista('INFGRALPROV', v_Listado_Informes) THEN
            -- Extraer datos de Transacciones para informes del PDS    
            p_Inf_GeneralProv_Det_TF  ( processingUnitSeq, period ,periodSeq , tenantId  );
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'INFGRALPROV_TF');            
        end if;        

        --------------------------------
        -- Datos para Mensual de Liquidación SCAWEB
        --------------------------------    
        IF f_ExisteInformeEnLista('LIQSCAWEB', v_Listado_Informes) THEN
            -- Extraer datos para Interface de LIQUIDACION MENSUAL SCAWEB  (Captacion - Importe Base)
            p_Informe_LIQSCAWEB_TF (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
         
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'LIQSCAWEB_TF');    
        end if;
        
        ---------------------------------------------------
        -- Datos para Informe Agrupado de liquidaciones
        ---------------------------------------------------
        IF f_ExisteInformeEnLista('LIQ_MENSUAL_TF', v_Listado_Informes) THEN
            p_informe_agrupado (processingUnitSeq, period ,periodSeq , tenantId , v_Interfaz_Proceso );
            -- Actualizamos la fecha del informes en la tabla 
            p_Actualiza_Informe_Fecha ( period, 'LIQ_MENSUAL_TF');    
        end if;        
     
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

procedure p_Comp_Pagos_SCAWEB_E4E_CAB_TF ( iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
AS
begin

    v_finicio := current_timestamp();

    w_debug('Inicio Borrado de la tabla ENEL_COMP_SCAWEB_E4E_CAB_TF.', v_contador_debug);
	BEGIN
		LOOP
			DELETE FROM ENELEXT.ENEL_COMP_SCAWEB_E4E_CAB_TF WHERE PERIODO = iperiod AND ROWNUM <= 10000;
			EXIT WHEN SQL%ROWCOUNT = 0;
			COMMIT;
		END LOOP;
	END;
    w_debug('Fin Borrado de la tabla ENEL_COMP_SCAWEB_E4E_CAB_TF.', v_contador_debug);

    w_debug('Insertando Registros SCAWEB-E4E de datos en tabla ENEL_COMP_SCAWEB_E4E_CAB_TF.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_CAB_TF ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO, 
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES )
                                                --, TITLE_NAME )   --RMM 10.06.2022
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
        --T_SCAWEB.NOMBRE --MIKE 05.05.2022 Se añade el campo que solicitan de una regla que impacta en los incentivos del informe PUSH --RMM 10.06.2022
  
	FROM
		(select PERIODO, TRIM(to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
			--,NOMBRE --RMM 10.06.2022
            from ENEL_SCAWEB_LIQUIDACION_TF sca 
			where PERIODO = iperiod
			and TIPO_PRESTADOR = 'SI'
            and nombre not like '%Alta Contrato' --RMM 10.06.2022 
             group by PERIODO, TRIM(to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO
             --,NOMBRE --RMM 10.06.2022
            
		) T_SCAWEB
      
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
                sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
                SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
                SUM(VALOR_OPERACIONES) AS OPERACIONES
            from ENEL_E4E_DEPOSIT_TF_TEMP 
			where periodseq=iperiodseq
			and TIPO_PRESTADOR like 'SI'
            group by TRIM(IDPROVEEDOR), PDS
			) T_E4E
           ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
           AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
		LEFT JOIN 
			(select 
				TRIM(IDPROVEEDOR) as IDPROVEEDOR, PDS, 
				sum(case when VALUE is null then 0 else VALUE end) as NEGATIVO
			from ENEL_E4E_NEGATIVOS_TEMP_tf 
			where periodseq=iperiodseq
			group by TRIM(IDPROVEEDOR), PDS
			)E4ENT
			ON TRIM(T_SCAWEB.PDS) = TRIM(E4ENT.PDS)
            AND TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(E4ENT.IDPROVEEDOR)
                        
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			ON T_SCAWEB.PDS=TMP_PDS.PDS


		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_SCAWEB.IDPROVEEDOR)
	;      
           
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros SCAWEB-E4E de la tabla ENEL_COMP_SCAWEB_E4E_CAB_TF: '|| to_char(filas) || ' filas.', v_contador_debug);

    w_debug('Insertando Registros E4E-SCAWEB (scaweb nulos) de datos en tabla ENEL_COMP_SCAWEB_E4E_CAB_TF.' ,  v_contador_debug);
    
	INSERT INTO ENELEXT.ENEL_COMP_SCAWEB_E4E_CAB_TF ( PERIODO, IDPROVEEDOR, DESCRIPCION, ACTIVIDAD, PDS, NOMBRE_FISCAL, IMPORTE_SCAWEB, E4E_POS_CON_CONTRATO,
                                                E4E_POS_SIN_CONTRATO, E4E_NEGATIVO,E4E_OPERACIONES)
                                               -- , TITLE_NAME ) --RMM 10.06.2022
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
        --T_SCAWEB.NOMBRE --RRMM 10.06.2022
   
	FROM 
        (select 
			iperiod PERIODO, TRIM(IDPROVEEDOR)  as IDPROVEEDOR, PDS, 
			sum(CASE when VALUE > 0 AND COD_CONTRATO is not null THEN VALUE ELSE 0 END) AS POSITIVO_CON_CONTRATO,
			sum(CASE when VALUE > 0 AND COD_CONTRATO is null THEN VALUE ELSE 0 END) AS POSITIVO_SIN_CONTRATO,
			SUM(CASE when VALUE < 0 THEN VALUE ELSE 0 END) AS NEGATIVO,
			SUM(VALOR_OPERACIONES) AS OPERACIONES
          
		from ENEL_E4E_DEPOSIT_TF_TEMP 
		where periodseq=iperiodseq
		and TIPO_PRESTADOR like 'SI'
       group by iperiod, TRIM(IDPROVEEDOR), PDS 
		) T_E4E
            
		LEFT JOIN
			( select PERIODO, trim( to_char(PROVEEDOR,'000')) IDPROVEEDOR, SCA.CODIGO_AGENTE_INTERNO as PDS, sum(REALVALUE) as IMPORTE_SCAWEB, count(*) registros
            --,NOMBRE --RMM 10.06.2022
				from ENEL_SCAWEB_LIQUIDACION_TF sca where PERIODO = iperiod and TIPO_PRESTADOR = 'SI'
                 and nombre not like '%Alta Contrato' --RMM 10.06.2022 
				group by PERIODO, trim( to_char(PROVEEDOR,'000')) , SCA.CODIGO_AGENTE_INTERNO -- , NOMBRE
			) T_SCAWEB
           
			ON TRIM(T_SCAWEB.IDPROVEEDOR) = TRIM(T_E4E.IDPROVEEDOR) 
			AND TRIM(T_SCAWEB.PDS) = TRIM(T_E4E.PDS)
          
		INNER JOIN ENEL_PDS_TEMP_TF TMP_PDS
			ON T_E4E.PDS=TMP_PDS.PDS
          --  and tmp_pds.title_name not like '%Alta Contrato'  

		INNER JOIN ENEL_PROVEEDORES_TEMP_TF TMP_PROV 
			ON  TRIM(TMP_PROV.IDPROVEEDOR)=TRIM(T_E4E.IDPROVEEDOR)
      
	WHERE T_SCAWEB.IMPORTE_SCAWEB is null
	;
      
	filas := sql%rowcount;
    COMMIT;

    w_debug('Fin Carga Registros E4E-SCAWEB (scaweb nulos) de la tabla ENEL_COMP_SCAWEB_E4E_CAB_TF : '|| to_char(filas) || ' filas.', v_contador_debug);
      dbms_stats.gather_table_stats(ownname => 'ENELEXT',tabname => 'ENEL_COMP_SCAWEB_E4E',estimate_percent => dbms_stats.auto_sample_size,degree => dbms_stats.default_degree,cascade => true);
  
    --EXECUTE IMMEDIATE 'ANALYZE TABLE ENELEXT.ENEL_COMP_SCAWEB_E4E COMPUTE STATISTICS FOR ALL INDEXES';
    w_debug('Fin Actualizacion Indices ENELEXT.ENEL_COMP_SCAWEB_E4E.',v_contador_debug);

    z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Comp_Pagos_SCAWEB_E4E_CAB_TF', v_finicio, current_timestamp(), null);
exception
    when others then
        z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Comp_Pagos_SCAWEB_E4E_CAB_TF', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

end;
end;