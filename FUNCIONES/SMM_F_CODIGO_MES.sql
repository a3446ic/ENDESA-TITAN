CREATE OR REPLACE FUNCTION EXT.SMM_F_CODIGO_MES(IN i_date DATE)
RETURNS v_CodigoMes VARCHAR(1)
AS
    /*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: XX-XX-2026
    |----------------------------------------------------------------------
    |  Se extrae un codigo de mes de modo que Enero es A , Febrero B .... hasta Diciembre que es L
    |  ASCII('A') = 65  y ASCII('L') = 76
    |  Metodo:
    |  Se extrae numero de mes: extract(month from idate) 
    |  Se suma 64 y ese codigo ascci se convierte a caracter con chr
    |
    | Parámetros: i_periodseq
	| Version:	0.1	SMM 2026XXXX	Initial Version.
    -----------------------------------------------------------------------
*/

BEGIN
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES_ENDESA:v_eot;
	
    SELECT CHAR(extract(month from :i_date) + 64)
    INTO  v_CodigoMes
    FROM DUMMY;  

END