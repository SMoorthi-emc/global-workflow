C-----------------------------------------------------------------------
      SUBROUTINE RSEARCH(IM,KM1,IXZ1,KXZ1,Z1,KM2,IXZ2,KXZ2,Z2,IXL2,KXL2,
     &                   L2)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:    RSEARCH     SEARCH FOR A SURROUNDING REAL INTERVAL
C   PRGMMR: IREDELL          ORG: W/NMC23     DATE: 98-05-01
C
C ABSTRACT: THIS SUBPROGRAM SEARCHES MONOTONIC SEQUENCES OF REAL NUMBERS
C   FOR INTERVALS THAT SURROUND A GIVEN SEARCH SET OF REAL NUMBERS.
C   THE SEQUENCES MAY BE MONOTONIC IN EITHER DIRECTION; THE REAL NUMBERS
C   MAY BE SINGLE OR DOUBLE PRECISION; THE INPUT SEQUENCES AND SETS
C   AND THE OUTPUT LOCATIONS MAY BE ARBITRARILY DIMENSIONED.
C
C PROGRAM HISTORY LOG:
C 1999-01-05  MARK IREDELL
C
C USAGE:    CALL RSEARCH(IM,KM1,IXZ1,KXZ1,Z1,KM2,IXZ2,KXZ2,Z2,IXL2,KXL2,
C    &                   L2)
C   INPUT ARGUMENT LIST:
C     IM           INTEGER NUMBER OF SEQUENCES TO SEARCH
C     KM1          INTEGER NUMBER OF POINTS IN EACH SEQUENCE
C     IXZ1         INTEGER SEQUENCE SKIP NUMBER FOR Z1
C     KXZ1         INTEGER POINT SKIP NUMBER FOR Z1
C     Z1           REAL (1+(IM-1)*IXZ1+(KM1-1)*KXZ1)
C                  SEQUENCE VALUES TO SEARCH
C                  (Z1 MUST BE MONOTONIC IN EITHER DIRECTION)
C     KM2          INTEGER NUMBER OF POINTS TO SEARCH FOR
C                  IN EACH RESPECTIVE SEQUENCE
C     IXZ2         INTEGER SEQUENCE SKIP NUMBER FOR Z2
C     KXZ2         INTEGER POINT SKIP NUMBER FOR Z2
C     Z2           REAL (1+(IM-1)*IXZ2+(KM2-1)*KXZ2)
C                  SET OF VALUES TO SEARCH FOR
C                  (Z2 NEED NOT BE MONOTONIC)
C     IXL2         INTEGER SEQUENCE SKIP NUMBER FOR L2
C     KXL2         INTEGER POINT SKIP NUMBER FOR L2
C     
C   OUTPUT ARGUMENT LIST:
C     L2           INTEGER (1+(IM-1)*IXL2+(KM2-1)*KXL2)
C                  INTERVAL LOCATIONS HAVING VALUES FROM 0 TO KM1
C                  (Z2 WILL BE BETWEEN Z1(L2) AND Z1(L2+1))
C
C SUBPROGRAMS CALLED:
C   SBSRCH       ESSL BINARY SEARCH
C   DBSRCH       ESSL BINARY SEARCH
C
C REMARKS:
C   IF THE ARRAY Z1 IS DIMENSIONED (IM,KM1), THEN THE SKIP NUMBERS ARE
C   IXZ1=1 AND KXZ1=IM; IF IT IS DIMENSIONED (KM1,IM), THEN THE SKIP
C   NUMBERS ARE IXZ1=KM1 AND KXZ1=1; IF IT IS DIMENSIONED (IM,JM,KM1),
C   THEN THE SKIP NUMBERS ARE IXZ1=1 AND KXZ1=IM*JM; ETCETERA.
C   SIMILAR EXAMPLES APPLY TO THE SKIP NUMBERS FOR Z2 AND L2.
C
C   RETURNED VALUES OF 0 OR KM1 INDICATE THAT THE GIVEN SEARCH VALUE
C   IS OUTSIDE THE RANGE OF THE SEQUENCE.
C
C   IF A SEARCH VALUE IS IDENTICAL TO ONE OF THE SEQUENCE VALUES
C   THEN THE LOCATION RETURNED POINTS TO THE IDENTICAL VALUE.
C   IF THE SEQUENCE IS NOT STRICTLY MONOTONIC AND A SEARCH VALUE IS
C   IDENTICAL TO MORE THAN ONE OF THE SEQUENCE VALUES, THEN THE
C   LOCATION RETURNED MAY POINT TO ANY OF THE IDENTICAL VALUES.
C
C   TO BE EXACT, FOR EACH I FROM 1 TO IM AND FOR EACH K FROM 1 TO KM2,
C   Z=Z2(1+(I-1)*IXZ2+(K-1)*KXZ2) IS THE SEARCH VALUE AND
C   L=L2(1+(I-1)*IXL2+(K-1)*KXL2) IS THE LOCATION RETURNED.
C   IF L=0, THEN Z IS LESS THAN THE START POINT Z1(1+(I-1)*IXZ1)
C   FOR ASCENDING SEQUENCES (OR GREATER THAN FOR DESCENDING SEQUENCES).
C   IF L=KM1, THEN Z IS GREATER THAN OR EQUAL TO THE END POINT
C   Z1(1+(I-1)*IXZ1+(KM1-1)*KXZ1) FOR ASCENDING SEQUENCES
C   (OR LESS THAN OR EQUAL TO FOR DESCENDING SEQUENCES).
C   OTHERWISE Z IS BETWEEN THE VALUES Z1(1+(I-1)*IXZ1+(L-1)*KXZ1) AND
C   Z1(1+(I-1)*IXZ1+(L-0)*KXZ1) AND MAY EQUAL THE FORMER.
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN
C
C$$$
      IMPLICIT NONE
      INTEGER,INTENT(IN):: IM,KM1,IXZ1,KXZ1,KM2,IXZ2,KXZ2,IXL2,KXL2
      REAL,INTENT(IN):: Z1(1+(IM-1)*IXZ1+(KM1-1)*KXZ1)
      REAL,INTENT(IN):: Z2(1+(IM-1)*IXZ2+(KM2-1)*KXZ2)
      INTEGER,INTENT(OUT):: L2(1+(IM-1)*IXL2+(KM2-1)*KXL2)
      INTEGER(4) INCX,N,INCY,M,INDX(KM2),RC(KM2),IOPT
      INTEGER I,K1,K2,CT
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  FIND THE SURROUNDING INPUT INTERVAL FOR EACH OUTPUT POINT.
      print*, IM,KM1,KM2,INCX,INCY
      DO I=1,IM
        IF(Z1(1+(I-1)*IXZ1).LE.Z1(1+(I-1)*IXZ1+(KM1-1)*KXZ1)) THEN
C  INPUT COORDINATE IS MONOTONICALLY ASCENDING.
          INCX=KXZ2
          N=KM2
          INCY=KXZ1
          M=KM1
          IOPT=1
!          IF(DIGITS(1.).LT.DIGITS(1._8)) THEN
!            CALL SBSRCH(Z2(1+(I-1)*IXZ2),INCX,N,
!     &                  Z1(1+(I-1)*IXZ1),INCY,M,INDX,RC,IOPT)
!          ELSE
!            CALL DBSRCH(Z2(1+(I-1)*IXZ2),INCX,N,
!     &                  Z1(1+(I-1)*IXZ1),INCY,M,INDX,RC,IOPT)
!          ENDIF
!          DO K2=1,KM2
!            L2(1+(I-1)*IXL2+(K2-1)*KXL2)=INDX(K2)-RC(K2)
!          ENDDO
          DO K2=1,KM2
            L2(K2)=KM1
            DO K1=(1+(I-1)*IXZ1),(1+(I-1)*IXZ1+(KM1-1)*KXZ1)-1
              IF(Z1(K1)>=Z2(K2).AND.Z1(K1+1)>Z2(K2)) THEN
                L2(K2)=K1
                EXIT
              ENDIF
            ENDDO
          ENDDO
        ELSE
C  INPUT COORDINATE IS MONOTONICALLY DESCENDING.
          INCX=KXZ2
          N=KM2
          INCY=-KXZ1
          M=KM1
          IOPT=0
!          IF(DIGITS(1.).LT.DIGITS(1._8)) THEN
!            CALL SBSRCH(Z2(1+(I-1)*IXZ2),INCX,N,
!     &                  Z1(1+(I-1)*IXZ1),INCY,M,INDX,RC,IOPT)
!          ELSE
!            CALL DBSRCH(Z2(1+(I-1)*IXZ2),INCX,N,
!     &                  Z1(1+(I-1)*IXZ1),INCY,M,INDX,RC,IOPT)
!          ENDIF
!          DO K2=1,KM2
!            L2(1+(I-1)*IXL2+(K2-1)*KXL2)=KM1+1-INDX(K2)
!          ENDDO
          DO K2=1,KM2
            L2(K2)=KM1
            CT=0
            DO K1=(1+(I-1)*IXZ1+(KM1-1)*KXZ1),(1+(I-1)*IXZ1)+1,-1
              CT=CT+1
              IF(Z2(K2)<=Z1(K1).AND.Z2(K2)<Z1(K1-1)) THEN
                L2(K2)=CT
                EXIT
              ENDIF
            ENDDO
          ENDDO
        ENDIF
      ENDDO
      END SUBROUTINE
