CREATE OR REPLACE FUNCTION EXT.SMM_F_EXISTE_INFORME_EN_LISTA(IN iInforme VARCHAR2(250), IN iListaInformes VARCHAR2(250))
RETURNS v_existe INTEGER
AS
    /*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: XX-XX-2026
    |----------------------------------------------------------------------
    | Se comprueba si el informe sobre el que se van a generar los datos pertenece a la lista de informes. Para 'ALL', se devuelve que si existe
    |
    | Parámetros: iInforme, iListaInformes
	| Version:	0.1	SMM 2026XXXX	Initial Version.
    -----------------------------------------------------------------------
*/

BEGIN

    -- Si lista de INFORMES es 'ALL', se devuelve como que existe siempre
    IF iListaInformes = 'ALL' THEN
        v_existe := 1;
    ELSEIF LOCATE(iInforme, iListaInformes) > 0 THEN
    -- Si el nombre del informe existe en la lista que se ha pasado como parametro (ejecucion manual), se devuelve que existe (true)   
        v_existe := 1;
    ELSE
    -- Si el nombre del informe no existe en la lista que se ha pasado como parametro (ejecucion manual), se devuelve que no existe (false)
        v_existe := 0;
    END IF; 

    -- if v_existe then
    --     w_debug(' SI ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    -- else
    --     w_debug(' NO ExisteInformeEnLista: '||iInforme ||' ListaInformes: '||iListaInformes ,  v_contador_debug);
    -- end if;

END