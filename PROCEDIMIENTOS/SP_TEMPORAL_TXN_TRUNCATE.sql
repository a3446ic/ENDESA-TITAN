CREATE OR REPLACE PROCEDURE EXT.SP_TEMPORAL_TXN_TRUNCATE(iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: XX-XX-2026
    |----------------------------------------------------------------------
    | Procedimiento para rellenar la tabla de SAP Autofacturas    
    | Parámetros: PROCESSINGUNITSEQ, PERIODSEQ, TENANTID          
    | Calendario: Mensual y Semanal                               
    |
	| Version:	0.1	SMM 20251217	Initial Version.
	| Version:	1.0	LLS 20260219	Puesto nombre de procedure en el texto de Procedure successful
	| Version:	2.0	SMM	20260309	Redondeo campo DEPOSITO_VALUE a 2 decimales
	| Version:	3.0	SMM	20260417	Eliminamos carga de la tabla RESULTS_SAP_AUTOFACT
	|
    -----------------------------------------------------------------------
*/

BEGIN

-- --------- Volcar datos de las tablas de Transacciones a una Temporal general para usar como base en todas las demas extracciones 
-- ---------- Tabla ENEL_TXN_TEMP ----
-- procedure p_Temporal_TXN_truncate (  iprocessingUnitSeq IN VARCHAR2, iperiod IN VARCHAR2,iperiodseq IN VARCHAR2, itenantId IN VARCHAR2 )
-- AS
-- begin

--     v_finicio := current_timestamp();
    
--     w_debug('Inicio Truncado de la tabla ENEL_TXN_TEMP.', v_contador_debug);
--     EXECUTE IMMEDIATE 'TRUNCATE TABLE ENELEXT.ENEL_TXN_TEMP';
--     w_debug('Fin Truncado de la tabla ENEL_TXN_TEMP.', v_contador_debug);
    
--     z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_TXN_truncate', v_finicio, current_timestamp(), null);
    
-- exception
--     when others then
--         z_ctrl_inf(v_contador_ctrl_inf, v_num_ejecucion, 'p_Temporal_TXN_truncate', v_finicio, current_timestamp(), 'Error:'||SQLCODE||SQLERRM);

-- end;