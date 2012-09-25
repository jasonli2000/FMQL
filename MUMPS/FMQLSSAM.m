FMQLSSAM; Caregraf - FMQL Schema Enhancement for Terminologies ; Sept 4th, 2012
    ;;0.96;FMQLQP;;Sept 4th, 2012


;
; FMQL Schema Enhancement for Terminologies - sameas relationships
;
; FMQL Query Processor (c) Caregraf 2010-2012 AGPL
;  
; Link (declare sameas) local vocabulary to standard or national equivalents. 
; This is part of FMQL's FileMan schema enhancements and all vocabs identified
; in the vocabulary graph should be processed here.
;
; Get SAMEAS of: LOCAL (no national map where there might be), LOCAL:XX-XX
; a local only map, VA:xxxx (usually VUIDs), NLT64 (for Lab only)
; 
; Note: Like other enhancements, the logic could be migrated to FileMan's 
; schema. Computed pointers called "sameas" could be added to relevant files.
; 
; TBD: 
; - ongoing: more and more vocabs matched
; - change to be dictionary driven ie. from, to, byfield. Key for scale
;   and to share definition with vocab client
; - DEFLABEL passed in for VUID. Lookup explicitly with better .01 routine
;

; IMPORTANT: pass in empty SAMEAS
RESOLVE(FILENUM,IEN,DEFLABEL,SAMEAS)
    Q:'$D(^DIC(FILENUM,0,"GL"))  ; catches CNode
    Q:IEN'=+IEN ; catch non numeric IEN
    I FILENUM="50.7" D RESOLVE50dot7(IEN,.SAMEAS) Q  ; PHARMACY ORDERABLE
    I FILENUM="50" D RESOLVE50(IEN,.SAMEAS) Q  ; DRUG
    I FILENUM="71" D RESOLVE71(IEN,.SAMEAS) Q  ; RAD/NUC PROCEDURE
    I FILENUM="790.2" D RESOLVE790dot2(IEN,.SAMEAS) Q  ; WV PROCEDURE
    I FILENUM="757" D RESOLVE757(IEN,.SAMEAS) Q  ; Major Concept
    I FILENUM="757.01" D RESOLVE757dot01(IEN,.SAMEAS) Q ; EXP
    I FILENUM="9999999.27" D RESOLVE9999999dot27(IEN,.SAMEAS) Q ; Prov Nav
    I FILENUM="60" D RESOLVE60(IEN,.SAMEAS) Q ; Lab Local
    I FILENUM="64" D RESOLVE64(IEN,.SAMEAS) Q ; Lab National WKLD
    D RESOLVEVAFIXED(FILENUM,IEN,DEFLABEL,.SAMEAS) Q:$D(SAMEAS("URI"))
    D RESOLVESTANDARD(FILENUM,IEN,DEFLABEL,.SAMEAS) Q:$D(SAMEAS("URI"))
    D RESOLVEVUID(FILENUM,IEN,DEFLABEL,.SAMEAS) Q:$D(SAMEAS("URI"))
    Q

;
; If VUID-ed file entry has no VUID then will return "LOCAL" as sameAs value 
; 
; TBD: VUIDs for many coded-value fields, all given in 8985_1. Can LU with NS
;      CR _11-537. Ex/ YES/NO fields etc. File#,Field#,IVALUE leads to VUID
;      Note: complication of 63_04. Could local enum labs get VUIDs too?
RESOLVEVUID(FILENUM,IEN,DEFLABEL,SAMEAS)
    N VUID,VUIDE
    I (($G(DEFLABEL)="")!($G(IEN)="")) Q  ; RESOLVEDRUG, maybe more need this
    Q:'$D(^DD(FILENUM,"B","VUID",99.99))
    S SAMEAS("URI")="LOCAL"
    S VUIDE=^DIC(FILENUM,0,"GL")_IEN_","_"""VUID"""_")"
    I DEFLABEL["/" S DEFLABEL=$TR(DEFLABEL,"/","-")  ; TMP: names with /. TBD fix.
    I $G(@VUIDE) S SAMEAS("URI")="VA:"_$P($G(@VUIDE),"^",1) S SAMEAS("LABEL")=DEFLABEL  Q
    Q

; Fixed files: 5,11,13 no VUID but VA standard
; Note: 10(.1/.2) not in here. CDC/HL7 coded.
; Unlike VUIDes will make SAMEAS take same value as IEN.
RESOLVEVAFIXED(FILENUM,IEN,DEFLABEL,SAMEAS)
    I FILENUM="5"!(FILENUM="11")!(FILENUM="13")  D
    . S SAMEAS("URI")="VA:"_$TR(FILENUM,".","_")_"-"_IEN 
    . S SAMEAS("LABEL")=$P(DEFLABEL,"/",2)
    Q 

; Standard files: 80 (ICD), 81 (CPT), 8932.1 (Provider Codes)
; TBD: 95.3 (LOINC), SNOMED/RT 61 ...
; ISSUE: must intercept LOINC BEFORE try VUID sameas
; These should never be local - unless in error
RESOLVESTANDARD(FILENUM,IEN,DEFLABEL,SAMEAS)
    ; No default local: should all have codes!
    I FILENUM="80" D
    . Q:'$D(@("^ICD9("_IEN_",0)"))  ; TBD: log invalid
    . S SAMEAS("URI")="ICD9:"_$P(DEFLABEL,"/",2) 
    . S SAMEAS("LABEL")=$P(@("^ICD9("_IEN_",0)"),"^",3)
    I FILENUM="81" D
    . Q:'$D(@("^ICPT("_IEN_",0)")) 
    . S SAMEAS("URI")="CPT:"_$P(DEFLABEL,"/",2) 
    . S SAMEAS("LABEL")=$P(@("^ICPT("_IEN_",0)"),"^",2)
    I FILENUM="8932.1" D 
    . Q:'$D(^USC(8932.1,IEN,0)) 
    . S SAMEAS("URI")="LOCAL" ; inactives lack codes
    . N X12CODE S X12CODE=$P(^USC(8932.1,IEN,0),"^",7)
    . Q:X12CODE=""
    . S SAMEAS("URI")="PROVIDER:"_X12CODE
    . S SAMEAS("LABEL")=$P(^USC(8932.1,IEN,0),"^",2) 
    ; For 61: SNOMED RT, snomed code and name
    Q

; Provider Narrative is used in problems (and POV, V CPT) to describe
; a problem. Most but not all resolve to expressions which in turn resolve
; to meaningful ICD codes.
RESOLVE9999999dot27(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^AUTNPOV(IEN,757))
    N SEVEN5701 S SEVEN5701=$P(^AUTNPOV(IEN,757),"^")
    Q:SEVEN5701=""
    D RESOLVE757dot01(SEVEN5701,.SAMEAS)
    Q ; don't fall back on a 757.01 that doesn't resolve to 757

; Lexicon expressions: turn expression (757_01) into major concept (757)
RESOLVE757dot01(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^LEX(757.01,IEN,1))
    N SEVEN57 S SEVEN57=$P(^LEX(757.01,IEN,1),"^")
    Q:SEVEN57=""
    D RESOLVE757(SEVEN57,.SAMEAS)
    Q

RESOLVE757(IEN,SAMEAS)
    Q:'$D(^LEX(757,IEN,0))
    ; Even major concept has a major expression and its label comes from that
    N MJRE S MJRE=$P(^LEX(757,IEN,0),"^")
    Q:MJRE=""
    Q:'$D(^LEX(757.01,MJRE,0))
    N SAMEASLABEL S SAMEASLABEL=$P(^LEX(757.01,MJRE,0),"^")
    Q:SAMEASLABEL=""
    S SAMEAS("URI")="VA:757-"_IEN
    S SAMEAS("LABEL")=SAMEASLABEL
    Q

; Pharmacy Orderable Item facade for 50.
; Three cases: no link to 50, link to 50 but it doesn't link and 50 links.
; the second case leads to a qualified local ala "LOCAL:50-IEN"
RESOLVE50dot7(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^PSDRUG("ASP",IEN))
    N DRUGIEN S DRUGIEN=$O(^PSDRUG("ASP",IEN,""))
    D RESOLVE50(DRUGIEN,.SAMEAS)
    Q:SAMEAS("URI")'="LOCAL"
    N SAMEASLABEL S SAMEASLABEL=$P(^PSDRUG(DRUGIEN,0),"^")
    Q:SAMEASLABEL=""
    S SAMEAS("URI")="LOCAL:50-"_DRUGIEN
    S SAMEAS("LABEL")=SAMEASLABEL
    Q
    
; VistA Drug 50 to Standard 50.68 or mark as local
RESOLVE50(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^PSDRUG(IEN,"ND")) ; Not mandatory to map to VA Product
    N VAPIEN S VAPIEN=$P(^PSDRUG(IEN,"ND"),"^",3)
    ; Q:VAPIEN'=+VAPIEN ; catch corrupt IEN
    Q:VAPIEN'=+VAPIEN ; VAPIEN may be zero so can't be subscript
    D RESOLVEVUID("50.68",VAPIEN,$P(^PSDRUG(IEN,"ND"),"^",2),.SAMEAS)
    Q

; TBD: RESOLVE50_605 (DRUG CLASS). VA GETS hard codes a name map for this.

; TBD: one CPT resolver. Switch on 71, 790_2 and more. Merge the following

; Special: VistA Rad/Nuc Procedures 71 to Standard CPT
RESOLVE71(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^DIC(71,0,"GL"))
    N CODEAR S CODEAR=^DIC(71,0,"GL")
    D RESOLVETOCPT(IEN,CODEAR,9,.SAMEAS)
    Q
    
; Special: VistA WV Procedures 790_2 to Standard CPT
RESOLVE790dot2(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^DIC(790.2,0,"GL"))
    N CODEAR S CODEAR=^DIC(790.2,0,"GL")
    D RESOLVETOCPT(IEN,CODEAR,8,.SAMEAS)
    Q

; Reusable CPT sameas formatter
RESOLVETOCPT(IEN,CODEAR,CPTFI,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(@(CODEAR_IEN_",0)"))
    N CPT S CPT=$P(@(CODEAR_IEN_",0)"),"^",CPTFI)
    Q:CPT=""
    Q:'$D(^ICPT("B",CPT))
    S CPTIEN=$O(^ICPT("B",CPT,""))
    N SAMEASLABEL S SAMEASLABEL=$P(^ICPT(CPTIEN,0),"^",2)
    Q:SAMEASLABEL=""
    S SAMEAS("URI")="CPT:"_CPT
    S SAMEAS("LABEL")=SAMEASLABEL
    Q

; TBD: LU LRVER1
RESOLVE60(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    Q:'$D(^LAB(60,IEN,64))
    ; Take Result NLT over National NLT
    N NLTIEN S NLTIEN=$S($P(^LAB(60,IEN,64),"^",2):$P(^LAB(60,IEN,64),"^",2),$P(^LAB(60,IEN,64),"^"):$P(^LAB(60,IEN,64),"^"),1:"")
    Q:NLTIEN=""
    Q:'$D(^LAM(NLTIEN))
    D RESOLVE64(NLTIEN,.SAMEAS)
    Q

; By design, do not map from WKLD to LOINC to its VUID. 
; VA assigned VUIDs to LOINCs but want LOINC and not VUID in sameas.
; TBD: LU LRVER1. See its logic.
RESOLVE64(IEN,SAMEAS)
    S:'$D(SAMEAS("URI")) SAMEAS("URI")="LOCAL"
    N WKLDCODE S WKLDCODE=$P(^LAM(IEN,0),"^",2)
    Q:'WKLDCODE?5N1".0000" ; leave local codes
    S SAMEAS("URI")="VA:wkld"_$P(WKLDCODE,".",1) ; 00000 dropped
    S SAMEAS("LABEL")=$P(^LAM(IEN,0),"^")
    Q:'$D(^LAM(IEN,9))
    N DEFLN S DEFLN=$P(^LAM(IEN,9),"^")
    Q:DEFLN=""
    Q:'$D(^LAB(95.3,DEFLN))
    Q:'$D(^LAB(95.3,DEFLN,81))  ; shortname
    S SAMEAS("URI")="LOINC:"_$P(^LAB(95.3,DEFLN,0),"^")_"-"_$P(^LAB(95.3,DEFLN,0),"^",15)  ; code and check_digit
    S SAMEAS("LABEL")=^LAB(95.3,DEFLN,81)
    Q
