CREATE OR REPLACE FUNCTION EXT.F_CODIGOMES(IN idate DATE)
RETURNS v_CodigoMes CHAR
AS
    /*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: XX-XX-2026
    |----------------------------------------------------------------------
    | Se extrae un codigo de mes de modo que Enero es A , Febrero B .... hasta Diciembre que es L
    | ASCII('A') = 65  y ASCII('L') = 76
    | Metodo:
    |  Se extrae numero de mes: month(idate) 
    |  Se suma 64 y ese codigo ascci se convierte a caracter con char
    |
    | Parámetros: idate     
	| Version:	0.1	SMM 2026XXXX	Initial Version.
    -----------------------------------------------------------------------
*/

BEGIN

    SELECT CHAR(MONTH(idate) + 64) INTO v_CodigoMes FROM DUMMY;

END