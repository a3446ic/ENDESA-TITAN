CREATE OR REPLACE FUNCTION EXT.SMM_F_ULTIMO_DIA_PERIODO(
 i_periodseq BIGINT
)
RETURNS v_Ultimo_Dia DATE
LANGUAGE SQLSCRIPT 
AS
BEGIN

	DECLARE v_tenantid NVARCHAR(4) := EXT.LIB_GLOBAL_ENDESA:getTenantID();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	
   SELECT ADD_DAYS(PER.ENDDATE,-1)  INTO v_Ultimo_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ = i_periodseq 
    AND PER.REMOVEDATE = v_eot;                                                                                                                                                                                                                            
 
END;