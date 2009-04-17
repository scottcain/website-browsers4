/* ILE-C compile REXX proc */
/* THIS WAS A MAKEFILE FOR VERSION 4 OF ANALOG. IT WON'T WORK FOR VERSION 5. */
SAY " "
SAY "Start Analog compilation."
SAY " You must have authority to exec CRTCMOD and CRTPGM."
SAY " "
SAY "    * * * * * * * * * * * * * * * * * * * * * * "
SAY " "
/* SAY "Input source library name."    */
/* PULL SLIB                           */
SLIB = 'ANALOG'
/* SAY "Input object library name."    */
/* PULL OLIB                           */
OLIB = 'ANALOG'
OUT = "*PRINT"
DEBUG = "*ALL"
TGT = 'V4R2M0'

D1 = "AS400"

MO.1 = 'alias'
MO.2 = 'analog'
MO.3 = 'cache'
MO.4 = 'dates'
MO.5 = 'globals'
MO.6 = 'hash'
MO.7 = 'init'
MO.8 = 'init2'
MO.9 = 'input'
MO.10 = 'output'
MO.11 = 'output2'
MO.12 = 'pcre'
MO.13 = 'process'
MO.14 = 'settings'
MO.15 = 'sort'
MO.16 = 'tree'
MO.17 = 'utils'

DO I = 1 TO 17
  SAY 'creating module 'MO.I'...'
  'CRTCMOD MODULE(QTEMP/'MO.I') SRCFILE(&SLIB/QCSRC)',
  'OUTPUT(&OUT) DEFINE(&D1) SYSIFCOPT(*ALL) DBGVIEW(&DEBUG) ',
  'TGTRLS(&TGT)'
  SAY "  result->" RC
END
SAY " "

SAY 'creating program Analog (Main) ...'
'CRTPGM PGM(&OLIB/ANALOG) MODULE(',
'QTEMP/'MO.1' QTEMP/'MO.2' QTEMP/'MO.3' QTEMP/'MO.4' QTEMP/'MO.5,
'QTEMP/'MO.6' QTEMP/'MO.7' QTEMP/'MO.8' QTEMP/'MO.9' QTEMP/'MO.10,
'QTEMP/'MO.11' QTEMP/'MO.12' QTEMP/'MO.13' QTEMP/'MO.14' QTEMP/'MO.15,
'QTEMP/'MO.16' QTEMP/'MO.17') TGTRLS(&TGT)'
SAY "  result->" RC
SAY " "

SAY 'creating CL program Anacgi ...'
'CRTCLPGM PGM(&OLIB/ANACGI) SRCFILE(&SLIB/QCLSRC) TGTRLS(&TGT)'
SAY "  result->" RC
SAY " "

SAY 'add symbolic link to programs ...'
'RMVLNK OBJLNK(''/analog/analog'')'
'ADDLNK OBJ(''/qsys.lib/'OLIB'.lib/analog.pgm'') NEWLNK(''/analog/analog'')'
SAY " "

SAY 'creating work files ...'
'CRTSRCPF FILE(&OLIB/PARMS) MBR(PARMS) CCSID(37)'
SAY "  result->" RC
'CRTSRCPF FILE(&OLIB/REPORT) CCSID(37)'
SAY "  result->" RC
SAY " "

SAY "Compile finished. Confirm error(s) if exists."
SAY " "
