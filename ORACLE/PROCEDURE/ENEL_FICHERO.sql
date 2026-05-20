create or replace PACKAGE BODY ENEL_FICHERO AS

  PROCEDURE RUN(calendar IN VARCHAR2,calendarSeq IN VARCHAR2,groupid IN VARCHAR2,period IN VARCHAR2,periodSeq IN VARCHAR2,processingUnit IN VARCHAR2,processingUnitSeq IN VARCHAR2,stage IN VARCHAR2,userName IN VARCHAR2,triggerFilename IN VARCHAR2,tenantId IN VARCHAR2,salidacontrol out varchar2,informe varchar2 DEFAULT 'ALL') AS
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


	CASE 
		when stage = 'Reward__'  								then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_REWARD';  
		WHEN stage = 'Post__' and processingUnit='MENSUAL TF' 	then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST_TF';
		when stage = 'Post__' and processingUnit='MENSUAL'		then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST';
		when stage = 'Post__' and processingUnit='ALIADOS'	 	then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST_ALIADO';
        when stage = 'Post__' and processingUnit='CCDD' 	 	then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_POST_CCDD';
		when stage = 'Pay__'     								then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_PAY';
		when stage = 'DTM__' 									then v_Interfaz_Proceso := 'ACTUALIZA_INFORMES_DTM';
	end CASE;
    IF  v_PeriodoLiquidado = false THEN
 p_credit_final(period,processingUnitSeq, tenantId , periodSeq,v_Interfaz_Proceso);
 	end if;
  END RUN;

procedure w_debug ( txt IN VARCHAR2, valor IN Number)
AS
    proc_name VARCHAR2(50 CHAR) := $$PLSQL_UNIT ; -- Nombre del procedimiento para DEBUG
begin
    insert into ENELEXT.ENEL_debug(tenantid, datetime,text,VALUE) VALUES (SUBSTR (USER,1,4),SYSDATE, proc_name || ' ' || txt, valor);
    select v_contador_debug + 1 into v_contador_debug from dual;
    commit;
end;


PROCEDURE p_credit_final(iperiod varchar2,iprocessingunitseq VARCHAR2, iTENANTID VARCHAR2, IPERIODSEQ VARCHAR2, iInterfaz VARCHAR2)as 
begin
    w_debug('Inicio Truncado de la tabla ENEL_FICHERO_ORDTXNCRED.', v_contador_debug);
    BEGIN
		LOOP
            DELETE FROM ENELEXT.ENEL_CREDIT_DTM WHERE PERIODO = iperiod and estado='Pte Liquidar' and TXN_PROCESSINGUNITSEQ=iprocessingunitseq AND ROWNUM <= 10000;
            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;
		END LOOP;
	END;
    w_debug('Fin Truncado de la tabla ENEL_FICHERO_ORDTXNCRED.', v_contador_debug);

    w_debug('Cargando tabla ENEL_FICHERO_ORDTXNCRED. Periodo:'|| iperiod ,  v_contador_debug);
    
    INSERT INTO ENELEXT.ENEL_FICHERO_ORDTXNCRED (ID_Oferta,Observaciones_1,Observaciones_Confidencial,Consumo_estimado_total,Consumo_estimado_anual,Consumo_estimado_anual_tipo,Margen_Termino_Fijo_tipo_1,Margen_Termino_Variable,Margen_Termino_Variable_tipo,
                                                Margen_Potencia,Margen_Potencia_tipo,Duracion_meses,Duracion_meses_tipo,Margen_GDO_1,Margen_GDO_tipo_1,Margen_Total_1,Margen_Total_tipo_1,Numero_CUPS,Numero_CUPS_tipo,Sumatorio_de_Potencias,
                                                Sumatorio_de_Potencias_tipo,Margen_Fee_1,Margen_Fee_tipo_1,Ajuste_Manual_Controlling_1,Ajuste_Manual_Controlling_tipo_1,Multicups,Personalizado,Dual,Codigo_Asset,Codigo_Numero_Cuota,Tipo_de_evento,
                                                Fecha_de_compensacion,ID_de_producto,Nombre_del_producto,Observaciones,Comercializadora,CUPS,Razon_Social,Codigo_Postal,Tarifa_ATR,Segmento,Linea_de_Negocio,Numero_Contrato,CIF_Cuenta_Padre,
                                                Tipo_Contrato,Numero_Renovacion,CEBE,Codigo_Tipo_de_Comisionado,Descripcion_Tipo_de_Comisionado,Motivo_Regularizacion,Tipo_de_Producto,ID_Oferta_Original,Consumo_estimado_total_MWh_tipo,Consumo_estimado_anual_MWh,
                                                Consumo_estimado_anual_MWh_tipo,Potencia_KW,Potencia_KW_tipo,Margen_Termino_Potencia,Margen_Termino_Potencia_tipo,Margen_Interno,Margen_Interno_tipo,Duracion_Contrato_meses,Duracion_Contrato_meses_tipo,
                                                Margen_Termino_Fijo,Margen_Termino_Fijo_tipo,Margen_Termino_Variable_Energia,Margen_Termino_Variable_Energia_tipo,Margen_GDO,Margen_GDO_tipo,Margen_Total,Margen_Fee,Margen_Fee_tipo,
                                                Valor_Forzado_Salesforce,Valor_Forzado_Salesforce_tipo,Ajuste_Manual_Controlling,Ajuste_Manual_Controlling_tipo,Numero_Cuota,Numero_Cuotas_Totales,Numero_Cuotas_Totales_tipo,Consumo_real_MWh,
                                                Consumo_real_MWh_tipo,Fecha_Firma_Contrato,Fecha_Fin_Vigencia_Contrato,Fecha_Inicio_Real_Contrato,Fecha_Fin_Real_Contrato,Licitacion,Agencia,Periodo,Calendario,Tipo_de_credito,Valor_Comision,
                                                Valor_Comision_tipo,Origen_del_calculo,Sector,Origen_del_calculo_payee,Codigo_Liquidacion,Comision_Total_tipo,Comision_Pagada,Comision_Pagada_tipo,Margen_Total_Especifico_MWh_Contrato,Margen_Total_Especifico_MWh_Contrato_tipo,
                                                Margen_Agente_Definitivo,Margen_Agente_Definitivo_tipo,Margen_tipo,Margen_Agente_Inicial,Margen_Agente_Inicial_tipo,Estado_Resultado)
   
   SELECT                                             
    ordtxn.ID	as ID_Oferta,
ordtxn.genericattribute1	as Observaciones_1,
ordtxn.genericattribute2	as Observaciones_Confidencial,
ordtxn.genericnumber1	as Consumo_estimado_total,
'PENDIENTE'	as Consumo_estimado_total_tipo,
ordtxn.genericnumber2	as Consumo_estimado_anual,
'PENDIENTE'	as Consumo_estimado_anual_tipo,
ordtxn.genericnumber3	as Margen_Termino_Fijo_1,
'PENDIENTE'	as Margen_Termino_Fijo_tipo_1,
ordtxn.genericnumber4	as Margen_Termino_Variable,
'PENDIENTE'	as Margen_Termino_Variable_tipo,
ordtxn.genericnumber5	as Margen_Potencia,
'PENDIENTE'	as Margen_Potencia_tipo,
ordtxn.genericnumber6	as Duracion_meses,
'PENDIENTE'	as Duracion_meses_tipo,
ordtxn.EN1	as Margen_GDO_1,
'PENDIENTE'	as Margen_GDO_tipo_1,
ordtxn.EN2	as Margen_Total_1,
'PENDIENTE'	as Margen_Total_tipo_1,
ordtxn.EN3	as Numero_CUPS,
'PENDIENTE'	as Numero_CUPS_tipo,
ordtxn.EN4	as Sumatorio_de_Potencias,
'PENDIENTE'	as Sumatorio_de_Potencias_tipo,
ordtxn.EN5	as Margen_Fee_1,
'PENDIENTE'	as Margen_Fee_tipo_1,
ordtxn.EN6	as Ajuste_Manual_Controlling_1,
'PENDIENTE'	as Ajuste_Manual_Controlling_tipo_1,
ordtxn.genericboolean1	as Multicups,
ordtxn.genericboolean2	as Personalizado,
ordtxn.genericboolean3	as Dual,
TXN.Line	as Codigo_Asset,
TXN.Subline	as Codigo_Numero_Cuota,
TXN.Eventype	as Tipo_de_evento,
TXN.CompensationDate	as Fecha_de_compensacion,
TXN.ProductID	as ID_de_producto,
TXN.ProductName	as Nombre_del_producto,
TXN.ProductDescription	as Observaciones_Confidencial_txn,
TXN.Observaciones	as Observaciones,
TXN.genericattribute1	as Comercializadora,
TXN.genericattribute2	as CUPS,
TXN.genericattribute3	as Razon_Social,
TXN.genericattribute4	as Codigo_Postal,
TXN.genericattribute5	as Tarifa_ATR,
TXN.genericattribute6	as Segmento,
TXN.genericattribute7	as Linea_de_Negocio,
TXN.genericattribute8	as Numero_Contrato,
TXN.genericattribute9	as CIF_Cuenta_Padre,
TXN.genericattribute10	as Tipo_Contrato,
TXN.genericattribute11	as Numero_Renovacion,
TXN.genericattribute12	as CEBE,
TXN.genericattribute13	as Codigo_Tipo_de_Comisionado,
TXN.genericattribute15	as Descripcion_Tipo_de_Comisionado,
TXN.genericattribute17	as Motivo_Regularizacion,
TXN.genericattribute18	as Tipo_de_Producto,
TXN.genericattribute19	as ID_Oferta_Original,
TXN.genericnumber1	as Consumo_estimado_total_MWh,
'PENDIENTE'	as Consumo_estimado_total_MWh_tipo,
TXN.genericnumber2	as Consumo_estimado_anual_MWh,
'PENDIENTE'	as Consumo_estimado_anual_MWh_tipo,
TXN.genericnumber3	as Potencia_KW,
'PENDIENTE'	as Potencia_KW_tipo,
TXN.genericnumber4	as Margen_Termino_Potencia,
'PENDIENTE'	as Margen_Termino_Potencia_tipo,
TXN.genericnumber5	as Margen_Interno,
'PENDIENTE'	as Margen_Interno_tipo,
TXN.genericnumber6	as Duracion_Contrato_meses,
'PENDIENTE'	as Duracion_Contrato_meses_tipo,
TXN.EN1	as Margen_Termino_Fijo,
'PENDIENTE'	as Margen_Termino_Fijo_tipo,
TXN.EN2	as Margen_Termino_Variable_Energia,
'PENDIENTE'	as Margen_Termino_Variable_Energia_tipo,
TXN.EN3	as Margen_genericdateO,
'PENDIENTE'	as Margen_genericdateO_tipo,
TXN.EN4	as Margen_Total,
'PENDIENTE'	as Margen_Total_tipo,
TXN.EN5	as Margen_Fee,
'PENDIENTE'	as Margen_Fee_tipo,
TXN.EN6	as Valor_Forzado_Salesforce,
'PENDIENTE'	as Valor_Forzado_Salesforce_tipo,
TXN.EN7	as Ajuste_Manual_Controlling,
'PENDIENTE'	as Ajuste_Manual_Controlling_tipo,
TXN.EN9	as Numero_Cuota,
'PENDIENTE'	as Numero_Cuota_tipo,
TXN.EN10	as Numero_Cuotas_Totales,
'PENDIENTE'	as Numero_Cuotas_Totales_tipo,
TXN.EN11	as Consumo_real_MWh,
'PENDIENTE'	as Consumo_real_MWh_tipo,
TXN.genericdate1	as Fecha_Firma_Contrato,
TXN.genericdate2	as Fecha_Inicio_Vigencia_Contrato,
TXN.genericdate3	as Fecha_Fin_Vigencia_Contrato,
TXN.genericdate4	as Fecha_Inicio_Real_Contrato,
TXN.genericdate5	as Fecha_Fin_Real_Contrato,
TXN.genericboolean1	as Licitacion,
CD.POSITIONID	as Agencia,
CD.PERIODO	as Periodo,
CD.CALENDAR	as Calendario,
CD.CreditType	as Tipo_de_credito,
CD.Value	as Valor_Comision,
'PENDIENTE'	as Valor_Comision_tipo,
CD.genericattribute1	as Tipo_Agencia,
CD.genericattribute4	as Origen_del_calculo,
CD.genericattribute10	as Sector,
CD.genericattribute14	as Origen_del_calculo_payee,
CD.genericattribute15	as Codigo_Liquidacion,
CD.genericnumber1	as Comision_Total,
'PENDIENTE'	as Comision_Total_tipo,
CD.genericnumber2	as Comision_Pagada,
'PENDIENTE'	as Comision_Pagada_tipo,
CD.genericnumber3	as Margen_Total_Especifico_MWh_Contrato,
'PENDIENTE'	as Margen_Total_Especifico_MWh_Contrato_tipo,
CD.genericnumber4	as Margen_Agente_Definitivo,
'PENDIENTE'	as Margen_Agente_Definitivo_tipo,
CD.genericnumber5	as Margen,
'PENDIENTE'	as Margen_tipo,
CD.genericnumber6	as Margen_Agente_Inicial,
'PENDIENTE'	as Margen_Agente_Inicial_tipo,
'Provisional / Definitivo'	as Estado_Resultado

from cs_salestransaction txn
		left JOIN CS_SALESORDER ordtxn
			ON TXN.txn_SALESORDERSEQ = ORDTXN.SALESORDERSEQ
			AND ORDTXN.REMOVEDATE = v_eot
        inner join cs_credit CD
			on txn.txn_salestransactionseq=cred.cred_salestransactionseq
			and txn.periodseq=cred.cred_periodseq
	;

    filas := sql%rowcount;
    COMMIT;
    end;

END ENEL_FICHERO;