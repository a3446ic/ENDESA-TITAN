CREATE FUNCTION EXT.SMM_F_COMPROBAR_PERIODO_LIQUIDADO(
 i_processingUnitSeq BIGINT
 ,i_period NVARCHAR(50)
 ,iperiodseq BIGINT
)
RETURNS v_liquidado BOOLEAN
LANGUAGE SQLSCRIPT 
AS
BEGIN

	DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	DECLARE v_checkCountEstado INT;
	
    SELECT count(ESTADO)
        into v_checkCountEstado
	FROM EXT.SMM_PERIODOS_LIQUIDADOS epl 
	WHERE epl.PERIODO = i_period 
        AND epl.PROCESSINGUNITSEQ=i_processingUnitSeq;
 
    IF v_checkCountEstado > 0 THEN 
        v_liquidado := true;
        -- w_debug(' Comprobar Estado del Periodo : LIQUIDADO - '||  i_period ||' Unidad Proceso: '|| to_char(i_processingUnitSeq) ,  v_contador_debug);
    ELSE
        v_liquidado := false;    
        -- w_debug(' Comprobar Estado del Periodo : NO Liquidado - '||  i_period ||' Unidad Proceso: '|| to_char(i_processingUnitSeq) ,  v_contador_debug);
    END IF;
    
                                                                                                                                                                                                                      
  
END