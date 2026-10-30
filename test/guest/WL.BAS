' WL.BAS - run the random workload in C:\WL.TXT (made by wl.pl) on files
' C:\WL\W??.DAT, printing the checksum of each R op to C:\WL.LOG.
DECLARE FUNCTION Gen$ (s AS INTEGER, l AS LONG)
DECLARE FUNCTION FileOf$ (i AS INTEGER)
DIM SHARED bpat$
bpat$ = ""
FOR j = 0 TO 1023
  bpat$ = bpat$ + CHR$(((j * 7) + (j \ 3)) AND 255)
NEXT
OPEN "C:\WL.TXT" FOR INPUT AS #1
OPEN "C:\WL.LOG" FOR OUTPUT AS #3
ON ERROR GOTO Failed
DO
  INPUT #1, op$
  nop& = nop& + 1
  SELECT CASE op$
  CASE "W"
    INPUT #1, fi%, ofs&, ln&, s%
    OPEN FileOf$(fi%) FOR BINARY AS #2
    d$ = Gen$(s%, ln&)
    ' files outgrow QBasic's string space, so everything below works in
    ' chunks of at most 4K
    DO WHILE ofs& > LOF(2)
      n& = ofs& - LOF(2)
      IF n& > 4096 THEN n& = 4096
      z$ = STRING$(n&, 0)
      PUT #2, LOF(2) + 1, z$
    LOOP
    PUT #2, ofs& + 1, d$
    CLOSE #2
  CASE "K"
    INPUT #1, fi%
    KILL FileOf$(fi%)
  CASE "C"
    INPUT #1, fi%, fj%
    OPEN FileOf$(fj%) FOR OUTPUT AS #5
    CLOSE #5
    OPEN FileOf$(fi%) FOR BINARY AS #2
    OPEN FileOf$(fj%) FOR BINARY AS #5
    FOR p& = 1 TO LOF(2) STEP 4096
      n& = LOF(2) - p& + 1
      IF n& > 4096 THEN n& = 4096
      d$ = SPACE$(n&)
      GET #2, p&, d$
      PUT #5, p&, d$
    NEXT
    CLOSE #2, #5
  CASE "R"
    INPUT #1, fi%
    OPEN FileOf$(fi%) FOR BINARY AS #2
    a& = 0: b& = 0
    FOR p& = 1 TO LOF(2) STEP 4096
      n& = LOF(2) - p& + 1
      IF n& > 4096 THEN n& = 4096
      d$ = SPACE$(n&)
      GET #2, p&, d$
      FOR j& = 1 TO n&
        i& = p& + j& - 1
        c% = ASC(MID$(d$, j&, 1))
        a& = (a& + c%) MOD 65536
        b& = (b& + c% * (((i& - 1) MOD 251) + 1)) MOD 65536
      NEXT
    NEXT
    CLOSE #2
    PRINT #3, LTRIM$(STR$(a&)); " "; LTRIM$(STR$(b&))
  END SELECT
LOOP UNTIL op$ = "E"
CLOSE
SYSTEM

' any error: record it and stop, rather than wait at a dialog for a key
Failed:
  e% = ERR
  RESUME Report
Report:
  CLOSE
  OPEN "C:\WL.ERR" FOR OUTPUT AS #4
  PRINT #4, "error"; e%; "at op"; nop&
  CLOSE
  SYSTEM

FUNCTION FileOf$ (i AS INTEGER)
  FileOf$ = "C:\WL\W" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".DAT"
END FUNCTION

FUNCTION Gen$ (s AS INTEGER, l AS LONG)
  d$ = ""
  k = 0
  DO WHILE LEN(d$) < l
    d$ = d$ + MID$(bpat$, ((s + k * 61) MOD 512) + 1, 512)
    k = k + 1
  LOOP
  Gen$ = LEFT$(d$, l)
END FUNCTION
