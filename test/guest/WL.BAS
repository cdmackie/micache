' WL.BAS - run the random workload in C:\WL.TXT (made by wl.pl) on files
' C:\WL\W??.DAT, printing the checksum of each R op to C:\WL.LOG.
DECLARE FUNCTION Gen$ (s AS INTEGER, l AS LONG)
DECLARE FUNCTION Fname$ (i AS INTEGER)
DIM SHARED base$
base$ = ""
FOR j = 0 TO 1023
  base$ = base$ + CHR$(((j * 7) + (j \ 3)) AND 255)
NEXT
OPEN "C:\WL.TXT" FOR INPUT AS #1
OPEN "C:\WL.LOG" FOR OUTPUT AS #3
DO
  INPUT #1, op$
  SELECT CASE op$
  CASE "W"
    INPUT #1, fi%, off&, ln&, s%
    OPEN Fname$(fi%) FOR BINARY AS #2
    d$ = Gen$(s%, ln&)
    IF off& > LOF(2) THEN
      z$ = STRING$(off& - LOF(2), 0)
      PUT #2, LOF(2) + 1, z$
    END IF
    PUT #2, off& + 1, d$
    CLOSE #2
  CASE "K"
    INPUT #1, fi%
    KILL Fname$(fi%)
  CASE "C"
    INPUT #1, fi%, fj%
    OPEN Fname$(fi%) FOR BINARY AS #2
    d$ = SPACE$(LOF(2))
    GET #2, 1, d$
    CLOSE #2
    IF LEN(Fname$(fj%)) > 0 THEN
      OPEN Fname$(fj%) FOR OUTPUT AS #2
      CLOSE #2
    END IF
    OPEN Fname$(fj%) FOR BINARY AS #2
    PUT #2, 1, d$
    CLOSE #2
  CASE "R"
    INPUT #1, fi%
    OPEN Fname$(fi%) FOR BINARY AS #2
    d$ = SPACE$(LOF(2))
    GET #2, 1, d$
    CLOSE #2
    a& = 0: b& = 0
    FOR i& = 1 TO LEN(d$)
      c% = ASC(MID$(d$, i&, 1))
      a& = (a& + c%) MOD 65536
      b& = (b& + c% * (((i& - 1) MOD 251) + 1)) MOD 65536
    NEXT
    PRINT #3, LTRIM$(STR$(a&)); " "; LTRIM$(STR$(b&))
  END SELECT
LOOP UNTIL op$ = "E"
CLOSE
SYSTEM

FUNCTION Fname$ (i AS INTEGER)
  Fname$ = "C:\WL\W" + RIGHT$("0" + LTRIM$(STR$(i)), 2) + ".DAT"
END FUNCTION

FUNCTION Gen$ (s AS INTEGER, l AS LONG)
  d$ = ""
  k = 0
  DO WHILE LEN(d$) < l
    d$ = d$ + MID$(base$, ((s + k * 61) MOD 512) + 1, 512)
    k = k + 1
  LOOP
  Gen$ = LEFT$(d$, l)
END FUNCTION
