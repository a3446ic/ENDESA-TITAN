CREATE OR REPLACE FUNCTION EXT.SMM_F_FECHA_INICIO(IN i_periodseq BIGINT)
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
	
    SELECT PER.STARTDATE INTO v_Primer_Dia
    FROM CS_PERIOD PER 
    WHERE PER.PERIODSEQ=i_periodseq 
    AND PER.REMOVEDATE = v_eot;

END