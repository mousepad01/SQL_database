-- STANCIU ANDREI CALIN
--
-- am conceput un model demonstrativ (simplist) pentru gestionarea personalului 
-- si resurselor materiale intr-un conflict militar
--
-- baza de date va retine informatii 
-- despre personal si status-ul acestuia
-- despre misiunile in care el este angrenat
-- despre vehiculele folosite si status-ul lor
-- despre regiunile conflictului si legaturile acestora cu misiunile desfasurate si personalul alocat
-- despre proviziile alocate fiecarei misiuni
--
-- detaliere (in mare) a tabelelor:
-- tabelul PERSONAL, asociat 1:1 cu tabelul VICTIME si RETRAS 
--                   fiecare intrare din tabelul PERSONAL poate avea un departament din tabelul DEPARTAMENTE
--                   si un superior din acelasi tabel (PERSONAL)
-- tabelul MISIUNE care contine informatii despre misiunile trecute/ actuale/viitoare
--                 este asociat cu tabelul PERSONAL cu ajutorul tabelului intermediar PERSONAL_ALOCAT
--                 mai este asociat cu tabelul VEHICULE prin tabelul intermediar VEHICULE_ALOCATE,
--                 si cu PROVIZII si PUNCTE_STRATEGICE in mod direct
--                 in plus, el este legat direct si de tabelele VICTIME si VEHICULE_DEFECTE
-- tabelul REGIUNE, legat cu PUNCTE_STRATEGICE si PERSONAL

-- subpunct 13
-- (impreuna cu toate subpunctele ce au putut fi introduse in pachet
--  si impreuna cu celelalte tipuri de date create pentru subpunctele din pachet)

CREATE OR REPLACE PACKAGE pack
AS
    -- subpunct 6
    -- sa se afiseze in ordinea id-urilor toate misiunile care au alocate provizii de tip dat 
    PROCEDURE find_m_byprov(tip_p provizii.tip%TYPE);
    
    -- subpunct 7
    -- functie care returneaza numarul total de personal alocat
    -- pentru misiunea care a rezultat in cei mai multi raniti
    FUNCTION max_personal RETURN NUMBER;
    
    -- subpunct 8 
    -- o functie care returneaza, dintre toti militarii retrasi, pe cei care au participat
    -- in cele mai multe misiuni de succes
    TYPE pers_id_arr IS TABLE OF NUMBER;
    
    FUNCTION get_pers_bysuccess
    RETURN pers_id_arr;
    
    -- subpunct 9

    -- o procedura care actualizeaza baza de date in functie de rezultatul unei misiuni
    -- se vor da ca parametri:
        -- id ul misiunii de actualizat
        -- statusul finalizarii acesteia
        -- tablou imbricat de obiecte de tip (id victima, status)
        -- tablou imbricat de obiecte de tip (id vehicul defectat, status)
        -- tablou imbricat de obiecte de tip (id punct strategic, status)
        
    -- se vor actualiza tabelele misiune, vehicule_defecte, victime, puncte_strategice
    -- se vor extrage date (si) din tabelele personal_alocat, vehicule_alocate
    PROCEDURE actualizare_misiune(id_m misiune.id_misiune%TYPE,
                                status_m misiune.status%TYPE,
                                vat victime_act_t,
                                vdat vehicule_defecte_act_t,
                                pstat p_str_act_t);

END pack;
/

-- tablou imbricat pentru subpunctul 6 
-- trebuie declarat aici si nu in pachet pentru a putera fi folosit in procedura corespunzatoare
CREATE OR REPLACE TYPE id_m_arr IS TABLE OF NUMBER(7);


-- obiecte folosite pentru subpunctul 9 (nu pot fi declarate in pachet)
CREATE OR REPLACE TYPE victime_act IS OBJECT (id_p NUMBER, status_p VARCHAR2(20));
CREATE OR REPLACE TYPE vehicule_defecte_act IS OBJECT (id_v NUMBER, status_v VARCHAR2(20));
CREATE OR REPLACE TYPE p_str_act IS OBJECT (cod_ps NUMBER, status_ps VARCHAR2(20));

CREATE OR REPLACE TYPE victime_act_t IS TABLE OF victime_act;
CREATE OR REPLACE TYPE vehicule_defecte_act_t IS TABLE OF vehicule_defecte_act;
CREATE OR REPLACE TYPE p_str_act_t IS TABLE OF p_str_act;


CREATE OR REPLACE PACKAGE BODY pack
AS
    
    -- subpunct 6
    -- sa se afiseze in ordinea id-urilor toate misiunile care au alocate provizii de tip dat 
    
    PROCEDURE find_m_byprov(tip_p provizii.tip%TYPE)
    IS
        
        id_arr id_m_arr := id_m_arr();
        
    BEGIN
    
        SELECT id_misiune
        BULK COLLECT INTO id_arr
        FROM provizii
        WHERE tip = tip_p;
        
        FOR idm IN (SELECT column_value idmisiune
                    FROM TABLE(id_arr)
                    ORDER BY 1) LOOP
                 
            DBMS_OUTPUT.PUT_LINE(idm.idmisiune);
                    
        END LOOP;
    
    END find_m_byprov;
    
    -- subpunct 7
    -- functie care returneaza numarul total de personal alocat
    -- pentru misiunea care a rezultat in cei mai multi raniti
    FUNCTION max_personal
    RETURN NUMBER
    
    IS
        cnt_personal NUMBER := 0;
        cnt_raniti_max NUMBER := -1;
        
        CURSOR c IS
            SELECT v.id_misiune idm, COUNT(v.id_misiune) cnt
            FROM victime v
            WHERE v.status = 'RANIT'
            GROUP BY v.id_misiune;
        
    BEGIN
        
        FOR m IN c LOOP
            
            IF cnt_raniti_max < m.cnt THEN
                
                cnt_raniti_max := m.cnt;
                
                SELECT COUNT(pa.id_aloc)
                INTO cnt_personal
                FROM personal_alocat pa
                WHERE pa.id_misiune = m.idm;
            
            END IF;
            
        END LOOP;
        
        RETURN cnt_personal;
        
    --EXCEPTION
    -- nu exista exceptii pe care le poate arunca
    
    END max_personal;
    
    -- subpunct 8 
    -- o functie care returneaza, dintre toti militarii retrasi, pe cei care au participat
    -- in cele mai multe misiuni de succes
    FUNCTION get_pers_bysuccess
    RETURN pers_id_arr
    IS
        max_success_ids pers_id_arr := pers_id_arr();
        
        max_success_cnt NUMBER := 0;
        success_cnt NUMBER;
        
        current_stat misiune.status%TYPE;
    
    BEGIN
        
        FOR p IN (SELECT id_pers FROM retras) LOOP
            
            success_cnt := 0;
            
            FOR m IN (SELECT id_misiune 
                      FROM personal_alocat
                      WHERE id_pers = p.id_pers) LOOP
                
                -- nu poate arunca NO_DATA_FOUND deoarece id ul misiunii sigur exista
                SELECT ms.status
                INTO current_stat
                FROM misiune ms
                WHERE ms.id_misiune = m.id_misiune;
                
                IF current_stat = 'SUCCES' THEN
                    success_cnt := success_cnt + 1;
                END IF;
                
            END LOOP;
            
            IF success_cnt > max_success_cnt THEN
                
                max_success_cnt := success_cnt;
                max_success_ids := pers_id_arr(p.id_pers);
            
            ELSIF success_cnt = max_success_cnt THEN
                
                max_success_ids.EXTEND(1);
                
                max_success_ids(max_success_ids.LAST()) := p.id_pers;
                
            END IF;
            
        END LOOP;
        
        RETURN max_success_ids;
    
    --EXCEPTION
    -- nu exista exceptii ce pot fi aruncate
    
    END get_pers_bysuccess;
    
    -- subpunct 9

    -- o procedura care actualizeaza baza de date in functie de rezultatul unei misiuni
    -- se vor da ca parametri:
        -- id ul misiunii de actualizat
        -- statusul finalizarii acesteia
        -- tablou imbricat de obiecte de tip (id victima, status)
        -- tablou imbricat de obiecte de tip (id vehicul defectat, status)
        -- tablou imbricat de obiecte de tip (id punct strategic, status)
        
    -- se vor actualiza tabelele misiune, vehicule_defecte, victime, puncte_strategice
    -- se vor extrage date (si) din tabelele personal_alocat, vehicule_alocate
    PROCEDURE actualizare_misiune(id_m misiune.id_misiune%TYPE,
                                  status_m misiune.status%TYPE,
                                  vat victime_act_t,
                                  vdat vehicule_defecte_act_t,
                                  pstat p_str_act_t)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        
        INVALID_CHECK_CONSTRAINT EXCEPTION;
        PRAGMA EXCEPTION_INIT(INVALID_CHECK_CONSTRAINT, -2290);
        
        INVALID_FOREIGN_KEY EXCEPTION;
        PRAGMA EXCEPTION_INIT(INVALID_FOREIGN_KEY, -2291);
        
        -- variabile pentru statisticile finale
        p_total NUMBER := 0;
        victime_total NUMBER := 0;
        
        v_total NUMBER := 0;
        v_def_total NUMBER := 0;
        
        ps_capt_cnt NUMBER := 0;
        ps_lost_cnt NUMBER := 0;
        
    BEGIN
        
        -- actualizare pe rand a tabelelor victime, vehicule_defecte, puncte_strategice
        
        -- daca cheia primara deja exista in tabelele victime / vehicule_defecte,
        -- va arunca eroarea DUP_VAL_ON_INDEX
        
        FOR i IN vat.FIRST .. vat.LAST LOOP
            
            IF vat.EXISTS(i) THEN
                
                INSERT INTO victime
                VALUES (vat(i).id_p, id_m, vat(i).status_p);
                
                victime_total := victime_total + 1;
                
            END IF;
            
        END LOOP;
        
        FOR i IN vdat.FIRST .. vdat.LAST LOOP
            
            IF vdat.EXISTS(i) THEN
                
                INSERT INTO vehicule_defecte
                VALUES (vdat(i).id_v, id_m, vdat(i).status_v);
                
                v_def_total := v_def_total + 1;
                
            END IF;
            
        END LOOP;
        
        -- inainte de a actualiza punctele strategice, verific daca toate dintre acestea exista
        
        FOR i IN pstat.FIRST .. pstat.LAST LOOP
            
            IF pstat.EXISTS(i) THEN
                
                UPDATE puncte_strategice
                SET status = pstat(i).status_ps
                WHERE cod_pct = pstat(i).cod_ps;
                
                IF SQL%ROWCOUNT < 1 THEN
                    RAISE NO_DATA_FOUND;
                END IF;
                
                IF pstat(i).status_ps = 'CONTROLAT' THEN
                    ps_capt_cnt := ps_capt_cnt + 1;
                ELSE
                    ps_lost_cnt := ps_lost_cnt + 1;
                END IF;
            
            END IF;
            
        END LOOP;
        
        -- actualizarea statusului misiunii si datei de finalizare
        UPDATE misiune
        SET data_final = sysdate, status = status_m
        WHERE id_misiune = id_m;
        
        IF SQL%ROWCOUNT < 1 THEN
            RAISE NO_DATA_FOUND;
        END IF;
        
        COMMIT;
        
        SELECT COUNT(id_aloc)
        INTO p_total 
        FROM personal_alocat
        WHERE id_misiune = id_m;
        
        SELECT COUNT(id_aloc)
        INTO v_total
        FROM vehicule_alocate
        WHERE id_misiune = id_m;
        
        DBMS_OUTPUT.PUT_LINE('Actualizare cu succes pentru misiunea ' || id_m);
        DBMS_OUTPUT.PUT_LINE('Personal total alocat: ' || p_total);
        DBMS_OUTPUT.PUT_LINE('Personal ramas: ' || (p_total - victime_total));
        DBMS_OUTPUT.PUT_LINE('Numar vehicule alocate: ' || v_total);
        DBMS_OUTPUT.PUT_LINE('Vehicule ramase: ' || (v_total - v_def_total));
        DBMS_OUTPUT.PUT_LINE('Puncte strategice capturate: ' || ps_capt_cnt);
        DBMS_OUTPUT.PUT_LINE('Puncte strategice pierdute: ' || ps_lost_cnt);
        
    EXCEPTION
    
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Datele au fost introduse gre?it!');
            
        WHEN DUP_VAL_ON_INDEX THEN
            DBMS_OUTPUT.PUT_LINE('Una dintre victime / unul dintre vehiculele dezafectate se află deja în baza de date!');
            
        WHEN INVALID_CHECK_CONSTRAINT THEN
            DBMS_OUTPUT.PUT_LINE('Un status a fost introdus gre?it!');
            
        WHEN INVALID_FOREIGN_KEY THEN
            DBMS_OUTPUT.PUT_LINE('Id-ul unui vehicul dezafectat sau a unei victime este gre?it!');
    
    END actualizare_misiune;
    
END pack;
/

-- exemplu functionare subpunct 6
BEGIN
    DBMS_OUTPUT.PUT_LINE('Misiunile ordonate, care au provizii de tipul MRE:');
    pack.find_m_byprov('mâncare - MRE');
    
END;
/

-- exemplu functionare subpunct 7
SELECT *
FROM personal;

SELECT *
FROM personal_alocat;

SELECT * 
FROM victime;

BEGIN
    
    DBMS_OUTPUT.PUT_LINE('Pentru misiunea cu cei mai multi raniti s-au alocat'
                        || max_personal || ' militari');
    
END;
/

-- exemplu functionare subpunct 8

SELECT *
FROM retras;

SELECT * 
FROM personal_alocat;

SELECT * 
FROM misiune;

DECLARE

    id_maxsuccess_arr pack.pers_id_arr := pack.pers_id_arr();
    
    nume_v personal.nume%TYPE;
    prenume_v personal.prenume%TYPE;

BEGIN
    
    id_maxsuccess_arr := pack.get_pers_bysuccess;
    
    IF id_maxsuccess_arr.COUNT > 0 THEN
        
        DBMS_OUTPUT.PUT_LINE('Cei ' || id_maxsuccess_arr.COUNT ||
                                ' veterani cu cele mai multe misiuni de suuces:');
        
        FOR i IN id_maxsuccess_arr.FIRST() .. id_maxsuccess_arr.LAST() LOOP
            
            -- id urile sunt sigur valide, deci nu va arunca eroare
            SELECT nume, prenume
            INTO nume_v, prenume_v
            FROM personal
            WHERE id_pers = id_maxsuccess_arr(i);
            
            DBMS_OUTPUT.PUT_LINE(nume_v || ' ' || prenume_v);
            
        END LOOP;
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('Nu exista soldati retrasi!');
    END IF;
    
END;
/

-- exemplu functionare subpunct 9

SELECT p.nume, p.prenume
FROM personal p, personal_alocat pa
WHERE p.id_pers = pa.id_pers
AND pa.id_misiune = 1;

SELECT v.id_vehicul, v.nume
FROM vehicule v, vehicule_alocate va
WHERE va.id_vehicul = v.id_vehicul
AND va.id_misiune = 1;

SELECT *
FROM puncte_strategice;

SELECT *
FROM misiune
WHERE id_misiune = 1;

DECLARE 

    victime_arr victime_act_t := victime_act_t(victime_act(3, 'RANIT'));
    vehicule_defecte_arr vehicule_defecte_act_t := vehicule_defecte_act_t(vehicule_defecte_act(1, 'DISTRUS'), vehicule_defecte_act(4, 'DEFECT'));
    pcte_str_arr p_str_act_t := p_str_act_t(p_str_act(4, 'CONTROLAT'));
    
BEGIN
    pack.actualizare_misiune(1, 'SUCCES', victime_arr, vehicule_defecte_arr, pcte_str_arr);
END;
/

SELECT *
FROM puncte_strategice;

SELECT *
FROM vehicule_defecte;

SELECT *
FROM victime;

---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------


-- subpunct 4 - CREAREA TABELELOR

CREATE TABLE departamente(
    id_departament VARCHAR2(10) PRIMARY KEY,
    nume_departament VARCHAR2(30) NOT NULL
);

CREATE TABLE regiune(
    cod_regiune NUMBER(3) PRIMARY KEY,
    nume VARCHAR2(50) NOT NULL
);

CREATE TABLE personal(
    id_pers NUMBER(7) PRIMARY KEY,
    nume VARCHAR2(50) NOT NULL,
    prenume VARCHAR2(50) NOT NULL,
    data_nastere DATE NOT NULL,
    data_inrolare DATE NOT NULL,
    grad VARCHAR2(20) NOT NULL,
    superior_direct NUMBER(7),
    id_departament VARCHAR2(10),
    cod_regiune NUMBER(3),
    salariu NUMBER(6) NOT NULL
);

ALTER TABLE personal
ADD FOREIGN KEY (superior_direct) REFERENCES personal(id_pers);

ALTER TABLE personal
ADD FOREIGN KEY (id_departament) REFERENCES departamente(id_departament);

ALTER TABLE personal
ADD FOREIGN KEY (cod_regiune) REFERENCES regiune(cod_regiune);

CREATE TABLE misiune(
    id_misiune NUMBER(7) PRIMARY KEY,
    data_start DATE NOT NULL,
    data_final DATE,
    status VARCHAR2(20) CHECK (status = 'PREGATIRE' OR status = 'DESFASURARE' OR status = 'ESEC' OR status = 'SUCCES'),
    obiectiv VARCHAR2(200) NOT NULL
);

CREATE TABLE victime(
    id_pers NUMBER(7) PRIMARY KEY REFERENCES personal(id_pers),
    id_misiune NUMBER(7) NOT NULL,
    status VARCHAR2(20) NOT NULL CHECK (status = 'RANIT' OR status = 'DECEDAT')
);

ALTER TABLE victime
ADD FOREIGN KEY (id_misiune) REFERENCES misiune(id_misiune);

CREATE TABLE retras(
    id_pers NUMBER(7) PRIMARY KEY REFERENCES personal(id_pers),
    data_retragere DATE NOT NULL
);

CREATE TABLE personal_alocat(
    id_aloc NUMBER(7) PRIMARY KEY,
    id_pers NUMBER(7) NOT NULL,
    id_misiune NUMBER(7) NOT NULL
);

ALTER TABLE personal_alocat
ADD FOREIGN KEY (id_pers) REFERENCES personal(id_pers);

ALTER TABLE personal_alocat
ADD FOREIGN KEY (id_misiune) REFERENCES misiune(id_misiune);

CREATE TABLE puncte_strategice(
    cod_pct NUMBER(7) PRIMARY KEY,
    cod_regiune NUMBER(3) NOT NULL,
    nume VARCHAR2(30),
    status VARCHAR2(20) NOT NULL CHECK(status = 'CONTROLAT' OR status = 'NECONTROLAT'),
    id_misiune NUMBER(7)
);

ALTER TABLE puncte_strategice
ADD FOREIGN KEY (cod_regiune) REFERENCES regiune(cod_regiune);

ALTER TABLE puncte_strategice
ADD FOREIGN KEY (id_misiune) REFERENCES misiune(id_misiune);

ALTER TABLE puncte_strategice
ADD UNIQUE(nume);

CREATE TABLE vehicule(
    id_vehicul NUMBER(7) PRIMARY KEY,
    nume VARCHAR2(30),
    producator VARCHAR2(30),
    data_intrare_servici DATE NOT NULL
);

CREATE TABLE vehicule_alocate(
    id_aloc NUMBER(7) PRIMARY KEY,
    id_vehicul NUMBER(7) NOT NULL,
    id_misiune NUMBER(7) NOT NULL
);

ALTER TABLE vehicule_alocate
ADD FOREIGN KEY (id_misiune) REFERENCES misiune(id_misiune);

ALTER TABLE vehicule_alocate
ADD FOREIGN KEY (id_vehicul) REFERENCES vehicule(id_vehicul);

CREATE TABLE vehicule_defecte(
    id_vehicul NUMBER(7) PRIMARY KEY REFERENCES vehicule(id_vehicul),
    id_misiune NUMBER(7) NOT NULL,
    status VARCHAR2(20) NOT NULL CHECK (status = 'DEFECT' OR status = 'DISTRUS')
);

ALTER TABLE vehicule_defecte
ADD FOREIGN KEY (id_misiune) REFERENCES misiune(id_misiune);

CREATE TABLE provizii(
    id_prov NUMBER(7) PRIMARY KEY,
    id_misiune NUMBER(7) NOT NULL,
    tip VARCHAR2(50) NOT NULL,
    cantitate NUMBER(10) NOT NULL CHECK (cantitate > 0)
);

ALTER TABLE provizii
ADD FOREIGN KEY (id_misiune) REFERENCES misiune(id_misiune);

-- subpunct 5
-- adaugarea de date

-- DEPARTAMENTE
INSERT INTO departamente
VALUES ('TER', 'For?e terestre');

INSERT INTO departamente
VALUES ('AER', 'For?e aeriene');

INSERT INTO departamente
VALUES ('MED', 'Medical');

INSERT INTO departamente
VALUES ('INF', 'Informa?ii ?i spionaj');

-- REGIUNE
INSERT INTO regiune
VALUES (1, 'Bagdad');

INSERT INTO regiune
VALUES (2, 'Mosul');

INSERT INTO regiune
VALUES (3, 'Al Hasakah');

INSERT INTO regiune
VALUES (4, 'Kut');

-- PERSONAL
INSERT INTO personal
VALUES (1, 'Alexandru', 'Stamate', '20.08.1985' , sysdate, 'General', null, 'TER', 2, 7000);

INSERT INTO personal
VALUES (2, 'Virgil', 'Murariu', '12.09.2000' , '04.05.2019', 'Maior', 1, 'TER', 2, 3000);

INSERT INTO personal
VALUES (3, 'Codrin', 'Vicu', '04.10.1994' , '23.09.2016', 'Maistru', 2, 'TER', 2, 1000);

INSERT INTO personal
VALUES (4, 'Ion', 'Gavrila', '20.12.1986' , sysdate, 'General', null, 'AER', 3, 8000);

INSERT INTO personal
VALUES (5, 'Ciprian', 'Politic', '20.08.1991' , '01.01.2010', 'Locotenent', null, 'MED', 1, 4000);

INSERT INTO personal
VALUES (6, 'Vlad', 'George', '20.07.1988' , sysdate, 'Frunta?', 4, 'AER', 3, 1000);

INSERT INTO personal
VALUES (7, 'Enache', 'Florin', '19.11.1987' , '14.11.2007', 'Maior', 1, 'INF', 3, 5000);

INSERT INTO personal
VALUES (8, 'Titu', 'Vasile', '20.08.1990' , sysdate, 'Caporal', 5, 'MED', 1, 2500);

INSERT INTO personal
VALUES (9, 'Inbru', 'Mihai', '30.03.1995' , '20.10.2016', 'Colonel', null, 'TER', null, 7000);

INSERT INTO personal
VALUES (10, 'Manole', 'Popescu', '20.08.1970' , '19.08.2000', 'General', null, 'AER', null, 10000);

INSERT INTO personal
VALUES (11, 'Ion', 'Gheorghe', '25.10.1980' , '19.08.2010', 'Colonel', null, 'TER', null, 10000);

INSERT INTO personal
VALUES (12, 'Gaina', 'Dragoslav', '25.10.1982' , '19.08.2009', 'Soldat', 1, 'INF', 3, 2000);

INSERT INTO personal
VALUES (13, 'Nicu', 'Presecan', '25.10.1983' , '19.08.2007', 'Caporal', 4, 'AER', 3, 2500);

INSERT INTO personal
VALUES (14, 'Valentin', 'Balan', '25.10.1987' , '19.08.2006', 'Maior', null, 'TER', null, 4000);

INSERT INTO personal
VALUES (16, 'Calin', 'Ianculescu', '25.10.1990' , '19.08.2010', 'General', null, 'TER', 1, 14000);

INSERT INTO personal
VALUES (17, 'George', 'Mihailescu', '25.12.1993' , '19.08.2014', 'Caporal', 4, 'TER', 3, 4000);


-- VICTIME
INSERT INTO victime
VALUES (11, 5, 'RANIT');

INSERT INTO victime
VALUES (12, 5, 'RANIT');

INSERT INTO victime
VALUES (13, 5, 'RANIT');

-- RETRAS
INSERT INTO retras
VALUES (10, '15.07.2020');

INSERT INTO retras
VALUES (9, '20.07.2019');

INSERT INTO retras
VALUES (14, '22.08.2019');

-- MISIUNE
INSERT INTO misiune
VALUES (1, sysdate, null, 'DESFASURARE', 'Capturare oras Mosul, district Mosul');

INSERT INTO misiune
VALUES (2, '10.06.2019', '20.06.2019', 'SUCCES', 'Ocupare cartier Kazimain - Bagdad');

INSERT INTO misiune
VALUES (3, '12.03.2018', '19.04.2018', 'ESEC', 'Protejare oras Kut, district Kut');

INSERT INTO misiune
VALUES (4, '17.09.2017', '18.09.2017', 'SUCCES', 'Penetrare baricada Al-Yarubiyah');

INSERT INTO misiune
VALUES (5, '10.11.2011', '20.11.2011', 'SUCCES', 'Innabusire gherila oras Mosul');

-- PERSONAL ALOCAT

INSERT INTO personal_alocat
VALUES (1, 9, 4);

INSERT INTO personal_alocat
VALUES (2, 9, 2);

INSERT INTO personal_alocat
VALUES (3, 10, 4);

INSERT INTO personal_alocat
VALUES (4, 10, 2);

INSERT INTO personal_alocat
VALUES (5, 5, 1);

INSERT INTO personal_alocat
VALUES (6, 6, 1);

INSERT INTO personal_alocat
VALUES (7, 3, 3);

INSERT INTO personal_alocat
VALUES (8, 3, 4);

INSERT INTO personal_alocat
VALUES (9, 5, 2);

INSERT INTO personal_alocat
VALUES (10, 2, 2);

INSERT INTO personal_alocat
VALUES (11, 12, 5);

INSERT INTO personal_alocat
VALUES (12, 11, 5);

INSERT INTO personal_alocat
VALUES (13, 13, 5);

INSERT INTO personal_alocat
VALUES (14, 14, 3);

INSERT INTO personal_alocat
VALUES (15, 16, 5);

INSERT INTO personal_alocat
VALUES (16, 17, 1);

-- PUNCTE STRATEGICE

INSERT INTO puncte_strategice
VALUES (1, 4, 'Kut', 'NECONTROLAT', 3); 

INSERT INTO puncte_strategice
VALUES (2, 1, 'Kazimain', 'CONTROLAT', 2); 

INSERT INTO puncte_strategice
VALUES (3, 3, 'Al-Yarubiyah', 'CONTROLAT', 4); 

INSERT INTO puncte_strategice
VALUES (4, 2, 'Mosul', 'NECONTROLAT', 5); 

-- PROVIZII

-- nu poate fi introdusa sau creata in pachet
CREATE SEQUENCE provizii_seq
MINVALUE 1
START WITH 1
INCREMENT BY 1
CACHE 5;

INSERT INTO provizii
VALUES (provizii_seq.nextval, 1, 'sniper', 10);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 1, 'mâncare - MRE', 200);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 4, 'mâncare - MRE', 250);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 3, 'mâncare - MRE', 180);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 5, 'medicamente', 50);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 2, 'medicamente', 74);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 2, 'sniper', 14);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 4, 'pusca semiautomata', 500);

INSERT INTO provizii
VALUES (provizii_seq.nextval, 5, 'pusca semiautomata', 620);

-- VEHICULE

INSERT INTO vehicule
VALUES (1, 'Leopard', 'Krauss-Mafei', '10.07.2010');

INSERT INTO vehicule
VALUES (2, 'Leopard', 'Krauss-Mafei', '13.09.2010');

INSERT INTO vehicule
VALUES (3, 'Leopard', 'Krauss-Mafei', '14.09.2010');

INSERT INTO vehicule
VALUES (4, 'Prava V3S', 'Avia', '01.02.2011');

INSERT INTO vehicule
VALUES (5, 'Prava V3S', 'BAZ', '11.10.2011');

INSERT INTO vehicule
VALUES (6, 'Humvee', 'AM General', '13.12.2014');

INSERT INTO vehicule
VALUES (7, 'Puma', 'Rheinmetall Landsysteme', '02.04.2013');

-- VEHICULE ALOCATE

INSERT INTO vehicule_alocate
VALUES (1, 2, 3);

INSERT INTO vehicule_alocate
VALUES (2, 3, 3);

INSERT INTO vehicule_alocate
VALUES (3, 4, 1);

INSERT INTO vehicule_alocate
VALUES (4, 4, 2);

INSERT INTO vehicule_alocate
VALUES (5, 4, 4);

INSERT INTO vehicule_alocate
VALUES (6, 4, 5);

INSERT INTO vehicule_alocate
VALUES (7, 5, 5);

INSERT INTO vehicule_alocate
VALUES (8, 1, 1);

INSERT INTO vehicule_alocate
VALUES (9, 3, 3);

INSERT INTO vehicule_alocate
VALUES (10, 2, 5);

INSERT INTO vehicule_alocate
VALUES (11, 6, 3);

INSERT INTO vehicule_alocate
VALUES (12, 7, 2);

-- VEHICULE DEFECTE

INSERT INTO vehicule_defecte
VALUES (2, 3, 'DISTRUS');

INSERT INTO vehicule_defecte
VALUES (6, 3, 'DEFECT');

INSERT INTO vehicule_defecte
VALUES (7, 2, 'DISTRUS'); 

--extragere date din tabele, (dupa inserare - subpunct 5)

SELECT *
FROM personal;

SELECT *
FROM departamente;

SELECT *
FROM misiune;

SELECT *
FROM victime;

SELECT *
FROM retras;

SELECT *
FROM personal_alocat;

SELECT *
FROM regiune;

SELECT *
FROM puncte_strategice;

SELECT *
FROM provizii;

SELECT *
FROM vehicule;

SELECT *
FROM vehicule_alocate;

SELECT *
FROM vehicule_defecte;


-- subpunct 10
-- trigger LMD la nivel de comanda combinat cu trigger LMD la nivel de linie
-- trigger ul la nivel de line va face imposibila recrutarea a mai mult de N de soldati 
-- intr-o regiune anume
-- trigger ul la nivel de comanda va ajuta aceasta operatie, folosindu-se de un pachet
-- pentru exemplificare, numarul N va fi egal cu 6 (spre deosebire de o situatie reala unde as avea cel putin ~mii)

CREATE TYPE regpers IS OBJECT (cod_reg NUMBER, cnt NUMBER);
CREATE TYPE allregpers IS TABLE OF regpers;

CREATE OR REPLACE PACKAGE regpers_helper_package 
AS
    
    reg_pers_freq allregpers := allregpers();
    
END regpers_helper_package;

-- trigger ul la nivel de comanda
CREATE OR REPLACE TRIGGER pers_cnt
BEFORE INSERT OR UPDATE
OF cod_regiune ON personal

DECLARE

    ind NUMBER := 0;

BEGIN
    
    FOR regcnt IN (SELECT cod_regiune r_cod, COUNT(cod_regiune) r_cnt
                   FROM personal
                   GROUP BY cod_regiune) LOOP
        
        regpers_helper_package.reg_pers_freq.EXTEND(1);
        
        ind := ind + 1;
        
        regpers_helper_package.reg_pers_freq(ind) := regpers(regcnt.r_cod, regcnt.r_cnt);
                   
    END LOOP;
    
END;
/

-- trigger ul la nivel de linie
-- voi face si o updatare a obiectului din pachet, intrucat
-- pot avea cazuri cand fac update pe mai multe campuri in aceeasi comanda
-- iar trigger ul heper care colecteaza informatia auxiliara ruleaza doar la inceputul executiei comenzii

CREATE OR REPLACE TRIGGER reg_pers_max_limit
BEFORE INSERT OR UPDATE
OF cod_regiune ON personal
FOR EACH ROW

DECLARE

    MAX_LIMIT NUMBER := 6; -- !!! NUMARUL 6 PUS DEMONSTRATIV !!!

    pers_cnt NUMBER;
    old_pers_cnt NUMBER; -- pentru a actualiza obiectul din pachet care tine informatia despre regiune
    
    ind NUMBER := 0;
    
    old_ind NUMBER; -- pentru a actualiza obiectul din pachet care tine informatia despre regiune
    new_ind NUMBER; -- pentru a actualiza obiectul din pachet care tine informatia despre regiune

BEGIN
    
    IF :NEW.cod_regiune != :OLD.cod_regiune THEN
    
        FOR ind IN regpers_helper_package.reg_pers_freq.FIRST .. regpers_helper_package.reg_pers_freq.LAST LOOP
            
            IF regpers_helper_package.reg_pers_freq.EXISTS(ind) AND regpers_helper_package.reg_pers_freq(ind).cod_reg = :NEW.cod_regiune THEN -- ar trebui sa fie valabila tot timpul, dar o pun de siguranta
                
                pers_cnt := regpers_helper_package.reg_pers_freq(ind).cnt;
                new_ind := ind;
                
            END IF;
            
            IF regpers_helper_package.reg_pers_freq.EXISTS(ind) AND regpers_helper_package.reg_pers_freq(ind).cod_reg = :OLD.cod_regiune THEN 
                
                old_pers_cnt := regpers_helper_package.reg_pers_freq(ind).cnt;
                old_ind := ind;
                
            END IF;
            
        END LOOP;
        
        IF pers_cnt = MAX_LIMIT THEN 
            RAISE_APPLICATION_ERROR(-20002, 'Limita de ' || MAX_LIMIT || ' militari alocati in regiunea ' || :NEW.cod_regiune || ' ar fi depasita!');
        ELSE
            
            regpers_helper_package.reg_pers_freq(new_ind).cnt := regpers_helper_package.reg_pers_freq(new_ind).cnt + 1;
                
            IF UPDATING THEN
               
                regpers_helper_package.reg_pers_freq(old_ind).cnt := regpers_helper_package.reg_pers_freq(old_ind).cnt - 1;
                
            END IF;
            
        END IF;
        
    END IF;   
END;
/

ALTER TRIGGER reg_pers_max_limit DISABLE;
ALTER TRIGGER reg_pers_max_limit ENABLE;

--exemplu declansare

SELECT *
FROM personal
WHERE cod_regiune = 3;

DECLARE

    MAX_LIM_EXP EXCEPTION;
    PRAGMA EXCEPTION_INIT(MAX_LIM_EXP, -20002);

BEGIN

    UPDATE personal
    SET cod_regiune = 3
    WHERE id_pers = 3;
    
EXCEPTION

    WHEN MAX_LIM_EXP THEN
        DBMS_OUTPUT.PUT_LINE('Limita de 6 militari alocati ar fi depasita!');
    
END;
/


-- subpunct 11
-- trigger LMD la nivel de linie, in inserarea in tabelul personal verifica varsta minima de 18 ani
-- verifica si in cazul unei editari (presupunem ca datele intiale au fost introduse gresit)

CREATE OR REPLACE TRIGGER min_age_ver
BEFORE INSERT OR UPDATE
ON personal
FOR EACH ROW

BEGIN
    
    IF :NEW.data_inrolare - :NEW.data_nastere < 364 * 18 THEN
        RAISE VALUE_ERROR;
    END IF;

END;
/

-- exemplu declansare

SELECT *
FROM personal;

BEGIN

    INSERT INTO personal
    VALUES (15, 'Draghici', 'Emilian', '19.11.2007' , '14.11.2014', 'Soldat', 1, 'INF', 3, 1000);
    
    --UPDATE personal
    --SET data_inrolare = '19.08.1980'
    --WHERE nume = 'Manole';
        
EXCEPTION
    
    WHEN VALUE_ERROR THEN
        DBMS_OUTPUT.PUT_LINE('Vârsta minimă de 18 ani pentru înrolare nu este atinsă!');

END;
/

-- subpunct 12
-- trigger care permite modificarea, stergerea, sau adaugarea tabelelor 
-- numai daca utilizatorul este unul specificat, si in plus doar intr-un interval de zile specificat

-- pentru a retine utilizatorii specificati, voi folosi un tablou intr-un pachet si o procedura care ii adauga
-- procedura va putea fi accesata doar de catre utilizatorul SYS sau MAINUSER

CREATE TYPE lista_useri IS TABLE OF VARCHAR2(50);

CREATE OR REPLACE PACKAGE lista_useri_package
AS
    priv_users lista_useri := lista_useri();

END;

CREATE OR REPLACE PROCEDURE alter_priv_users(u_name VARCHAR2, 
                                             flag VARCHAR2)
IS

    found NUMBER := 0;
    i NUMBER;

BEGIN

    IF USER != 'SYS' AND USER != 'MAINUSER' THEN
        DBMS_OUTPUT.PUT_LINE('Nu aveti dreptul de a modifica userii privilegiati!');
    ELSE

        IF flag = 'ADD' THEN
            
            lista_useri_package.priv_users.EXTEND(1);
            
            lista_useri_package.priv_users(lista_useri_package.priv_users.LAST()) := u_name;
            
            DBMS_OUTPUT.PUT_LINE('Utilizatorului i s-au conferit privilegiile');
        
        ELSIF flag = 'REMOVE' THEN
        
            IF lista_useri_package.priv_users.COUNT > 0 THEN
        
                FOR i IN lista_useri_package.priv_users.FIRST() .. lista_useri_package.priv_users.LAST() LOOP
                    
                    IF lista_useri_package.priv_users.EXISTS(i) AND lista_useri_package.priv_users(i) = u_name THEN
                        
                        lista_useri_package.priv_users.DELETE(i);
                        found := 1;
                        
                    END IF;
                    
                END LOOP;
            
            END IF;
                
            IF found = 0 THEN
                DBMS_OUTPUT.PUT_LINE('Nu s-a gasit utlizatorul cu acest nume!');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Utilizatorului i s-au retras privilegiile');
            END IF;
            
        ELSIF flag = 'RESET' THEN
        
            lista_useri_package.priv_users := lista_useri();
            
            DBMS_OUTPUT.PUT_LINE('Lista de utilizatori privilegiati a fost golita');
        
        ELSE
            DBMS_OUTPUT.PUT_LINE('Actiunea cu numele ' || flag || ' este nerecunoscuta!');
        END IF;
        
    END IF;

END alter_priv_users;
/

CREATE OR REPLACE TRIGGER ldd_check
BEFORE CREATE
ON SCHEMA

DECLARE

    found NUMBER := 0;
    i NUMBER;

BEGIN
    
    IF lista_useri_package.priv_users.COUNT > 0 THEN
    
        FOR i IN lista_useri_package.priv_users.FIRST() .. lista_useri_package.priv_users.LAST() LOOP
            
            IF lista_useri_package.priv_users.EXISTS(i) AND lista_useri_package.priv_users(i) = USER THEN
                found := 1;
            END IF;
            
        END LOOP;
        
    END IF;
    
    IF found = 0 THEN
        
        RAISE_APPLICATION_ERROR(-20001, 'Nu aveti dreptul de modificare a schemei bazei de date!');
        
    ELSIF EXTRACT(DAY FROM sysdate) > 2 THEN
    
        RAISE_APPLICATION_ERROR(-20003, 'Nu aveti dreptul de modificare a schemei bazei de date decat in prima si a doua zi din luna!');
    
    END IF;
    
END;
/

-- exemplu declansare

ALTER TRIGGER ldd_check DISABLE;
ALTER TRIGGER ldd_check ENABLE;

CREATE TABLE ttemp(
    nume VARCHAR2(2) PRIMARY KEY,
    nr NUMBER(4)
);

BEGIN 
    alter_priv_users(USER, 'ADD');
END;
/

CREATE TABLE ttemp(
    nume VARCHAR2(2) PRIMARY KEY,
    nr NUMBER(4)
);

DROP TABLE ttemp;

BEGIN 
    alter_priv_users(USER, 'REMOVE');
END;
/

-- cerinta suplimentara: indecsi
-- index compus pentru tabelele asociative PERSONAL_ALOCAT si VEHICULE_ALOCATE:

-- sa se afiseze numele si prenumele tuturor militarilor care participa in misiuni in desfasurare
-- sa se afiseze numele si data intrarii in servici a tuturor vehiculelor care participa in misiuni in desfasurare

SELECT p.nume, p.prenume, m.obiectiv
FROM personal p, personal_alocat pa, misiune m
WHERE p.id_pers = pa.id_pers
AND pa.id_misiune = m.id_misiune
AND m.status = 'DESFASURARE';

CREATE INDEX pa_index ON personal_alocat(id_pers, id_misiune);
DROP INDEX pa_index;

-- index compus pentru tabela VEHICULE_ALOCATE

CREATE INDEX va_index ON vehicule_alocate(id_vehicul, id_misiune);
DROP INDEX va_index;

SELECT v.nume, v.data_intrare_servici, m.obiectiv
FROM vehicule v, vehicule_alocate va, misiune m
WHERE v.id_vehicul = va.id_vehicul
AND va.id_misiune = m.id_misiune
AND m.status = 'DESFASURARE';


-- sa se afiseze pentru fiecare misiune in desfasurare, obiectivul ei si numarul total de personal alocat

SELECT COUNT(p.id_pers), m.id_misiune, m.obiectiv
FROM personal p, personal_alocat pa, misiune m
WHERE p.id_pers = pa.id_pers
AND pa.id_misiune = m.id_misiune
AND m.status = 'DESFASURARE'
GROUP BY m.id_misiune, m.obiectiv;











