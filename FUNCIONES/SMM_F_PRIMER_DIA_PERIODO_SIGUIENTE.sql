CREATE OR REPLACE FUNCTION EXT.SMM_F_PRIMER_DIA_PERIODO_SIGUIENTE(IN i_periodseq BIGINT)
RETURNS v_primer_dia DATE
AS
    /*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: XX-XX-2026
    |----------------------------------------------------------------------
    | Se calcula el primer dia del mes siguiente al actual 
    |
    | Parámetros: i_periodseq
	| Version:	0.1	SMM 2026XXXX	Initial Version.
    -----------------------------------------------------------------------
*/

BEGIN
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	
    SELECT ADD_MONTHS( PER.STARTDATE , 1 ) INTO v_primer_dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=i_periodseq 
    AND PER.REMOVEDATE = v_eot;

END