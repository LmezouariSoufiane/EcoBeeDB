---------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------- Création des Table ----------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------
--------- Table Searcher-------
create table searcher(
id_saercher INTEGER PRIMARY KEY,
searcher_name VARCHAR2(50),
email VARCHAR2(50),
adresse VARCHAR2(50),
institution VARCHAR2(50)
);

--------- Table Bee_species----------
CREATE TABLE Bee_species (
    id_bee INTEGER PRIMARY KEY,
    specie_name VARCHAR2(50) NOT NULL,
    parasitic SMALLINT CHECK (parasitic IN (0, 1)), -- 0: Non-parasitaire, 1: Parasitaire
    nesting VARCHAR2(50) NOT NULL,
    status VARCHAR2(50) DEFAULT 'common'
);



------Table Bee_sex---------
CREATE TABLE Bee_sex (
    id_bee INTEGER,
    sex CHAR(1) CHECK (sex IN ('m', 'f')), -- M: Male, F: Female
    PRIMARY KEY (id_bee, sex),
    CONSTRAINT fk_bee FOREIGN KEY (id_bee) REFERENCES Bee_species(id_bee)
);


-------------- Table Plant--------
CREATE TABLE Plant (
    id_plant INTEGER PRIMARY KEY,
    plant_name VARCHAR2(50) NOT NULL,
    is_native SMALLINT CHECK (is_native IN (0, 1)) -- 0: Non-native, 1: Native
);

--------- Table Season -----------
CREATE TABLE Season (
    id_season INTEGER PRIMARY KEY,
    season_name VARCHAR2(50) NOT NULL
);

----------- Table Site ------------------
CREATE TABLE Site (
    id_site INTEGER PRIMARY KEY,
    site_name VARCHAR2(50) NOT NULL
);

---------- Table Sampling_method-------------
CREATE TABLE Sampling_method (
    id_method INTEGER PRIMARY KEY,
    Method_name VARCHAR2(50) NOT NULL
);

-------------- Table Sample ---------------


-- Table Sample
    CREATE TABLE Sample (
    sample_id INTEGER PRIMARY KEY,
    id_season INTEGER,
    id_site INTEGER,
    id_method INTEGER,
    Date_Time DATE,
    Species_nbr INTEGER,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    CONSTRAINT fk_season FOREIGN KEY (id_season) REFERENCES Season(id_season),
    CONSTRAINT fk_site FOREIGN KEY (id_site) REFERENCES Site(id_site),
    CONSTRAINT fk_method FOREIGN KEY (id_method) REFERENCES Sampling_method(id_method)
);



--------- Table sample_details-----------
CREATE TABLE sample_details (
    ID_sample_details INTEGER PRIMARY KEY,
    id_plant INTEGER NOT NULL,
    id_bee INTEGER NOT NULL,
    sample_id INTEGER NOT NULL,
    CONSTRAINT fk_plant FOREIGN KEY (id_plant) REFERENCES Plant(id_plant),
    CONSTRAINT fk_beee FOREIGN KEY (id_bee) REFERENCES Bee_species(id_bee),
    CONSTRAINT fk_sample FOREIGN KEY (sample_id) REFERENCES Sample(sample_id)
);

-------- Table specialized_on --------------
CREATE TABLE specialized_on (
    id_bee INTEGER,
    id_plant INTEGER,
    PRIMARY KEY (id_bee, id_plant),
    CONSTRAINT fk_bee_specialized FOREIGN KEY (id_bee) REFERENCES Bee_species(id_bee),
    CONSTRAINT fk_plant_specialized FOREIGN KEY (id_plant) REFERENCES Plant(id_plant)
);

------------- Table Native--------------
CREATE TABLE Native (
    id_bee INTEGER,
    id_site INTEGER,
    is_native SMALLINT CHECK (is_native IN (0, 1)), -- 0: Non-native, 1: Native
    PRIMARY KEY (id_bee, id_site),
    CONSTRAINT fk_bee_native FOREIGN KEY (id_bee) REFERENCES Bee_species(id_bee),
    CONSTRAINT fk_site_native FOREIGN KEY (id_site) REFERENCES Site(id_site)
);





--------------------------liste de triggers --------------------------------

-------------------------------------------------------------------------------------
--******************************pour la table Plant***************************************
--------------------------------------------------------------------------------------

--1. Trigger pour éviter les doublons dans Plant

CREATE OR REPLACE TRIGGER trg_check_plant_duplicates
BEFORE INSERT OR UPDATE ON Plant
FOR EACH ROW
DECLARE
    v_existing_id INTEGER;
BEGIN
    SELECT id_plant
    INTO v_existing_id
    FROM Plant
    WHERE plant_name = :NEW.plant_name
    AND ROWNUM = 1;

    -- Si un ID existe mais est différent, lève une exception
    IF v_existing_id IS NOT NULL AND v_existing_id != :NEW.id_plant THEN
        RAISE_APPLICATION_ERROR(-20001, 'Duplicate plant name with different ID detected.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Aucune action nécessaire, la plante est unique
        NULL;
END;
/



-----2. Trigger pour mettre à jour automatiquement les références
--Ce trigger met à jour automatiquement les id_plant dans sample_details lorsqu'une duplication est détectée.
CREATE OR REPLACE TRIGGER trg_update_sample_details_plant
AFTER INSERT OR UPDATE ON Plant
FOR EACH ROW
BEGIN
    -- Met à jour les références dans sample_details pour pointer vers le nouvel ID unique
    UPDATE sample_details
    SET id_plant = :NEW.id_plant
    WHERE id_plant = :OLD.id_plant;
END;
/


---3. Trigger pour empêcher des valeurs conflictuelles de is_native

CREATE OR REPLACE TRIGGER trg_check_is_native_conflict
BEFORE INSERT OR UPDATE ON Plant
FOR EACH ROW
DECLARE
    v_existing_status INTEGER;
BEGIN
    SELECT is_native
    INTO v_existing_status
    FROM Plant
    WHERE plant_name = :NEW.plant_name
    AND id_plant != :NEW.id_plant
    AND ROWNUM = 1;

    
    IF v_existing_status IS NOT NULL AND v_existing_status != :NEW.is_native THEN
        RAISE_APPLICATION_ERROR(-20003, 'Conflict detected for is_native value of the same plant.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
END;
/
------------------------------------------------------------------------------
--********************* Table Sample----------------------
-------------------------------------------------------------------------------------
---1. verifier que start time < end time  

CREATE OR REPLACE TRIGGER trg_check_sample_time_order
BEFORE INSERT OR UPDATE ON Sample
FOR EACH ROW
BEGIN
    IF :NEW.start_time >= :NEW.end_time THEN
        RAISE_APPLICATION_ERROR(-20005, 'Start time must be earlier than end time.');
    END IF;
END;
/


---------------requêtes intelligentes -----------------

-------------1) Simple requêtes--------------


------ 1. Lister tous les chercheurs et leurs institutions
SELECT 
    searcher_name AS "Nom du Chercheur", 
    institution AS "Institution"
FROM 
    Searcher;


----- 2. Lister les espèces parasitaires et leur statut
SELECT 
    specie_name AS "Espèce", 
    status AS "Statut"
FROM 
    Bee_species
WHERE 
    parasitic = 1;

------- Amélioration de code:
SELECT 
    bs.specie_name AS "Espèce",
    bx.sex AS "Sexe"
FROM 
    Bee_sex bx
JOIN 
    Bee_species bs ON bx.id_bee = bs.id_bee
WHERE 
    bs.id_bee = 3;

 


---3. Identifier les abeilles natives dans un site spécifique par exemple site A :

SELECT bs.specie_name, s.site_name
FROM Native n
JOIN Bee_species bs ON n.id_bee = bs.id_bee
JOIN Site s ON n.id_site = s.id_site
WHERE n.is_native = 0 AND s.site_name = 'A';


--- 4. Trouver les plantes les plus visitées par une espèce d’abeille abeile avec id 12 :


SELECT p.plant_name, COUNT(sd.id_plant) AS visit_count
FROM sample_details sd
JOIN Plant p ON sd.id_plant = p.id_plant
WHERE sd.id_bee = 12
GROUP BY p.plant_name
ORDER BY visit_count DESC;

----- 5. Identifier les méthodes d'échantillonnage les plus utilisées par saison :

SELECT se.season_name, sm.Method_name, COUNT(s.sample_id) AS usage_count
FROM Sample s
JOIN Season se ON s.id_season = se.id_season
JOIN Sampling_method sm ON s.id_method = sm.id_method
GROUP BY se.season_name, sm.Method_name
ORDER BY usage_count DESC;



-----6. Trouver les plantes visitées par des abeilles natives
SELECT DISTINCT
    p.plant_name AS "Plante",
    s.site_name AS "Site"
FROM 
    Native n
JOIN 
    Bee_species bs ON n.id_bee = bs.id_bee
JOIN 
    sample_details sd ON sd.id_bee = n.id_bee
JOIN 
    Plant p ON p.id_plant = sd.id_plant
JOIN 
    Site s ON s.id_site = n.id_site
WHERE 
    n.is_native = 1;


--- 7. Lister les espèces spécialisées sur une plante spécifique

SELECT 
    bs.specie_name AS "Espèce", 
    p.plant_name AS "Plante"
FROM 
    specialized_on so
JOIN 
    Bee_species bs ON so.id_bee = bs.id_bee
JOIN 
    Plant p ON so.id_plant = p.id_plant
WHERE 
    p.plant_name = 'Viola';



--8. determiner les plantes  favorables à chaque type d'abeille et que ces plantes soient native ou non-native,

SELECT 
    bs.specie_name AS "Bee Name",
    p.plant_name AS "Plant Name",
    CASE 
        WHEN p.is_native = 1 THEN 'Native'
        ELSE 'Non-Native'
    END AS "Native Status"
FROM 
    specialized_on so
JOIN 
    Bee_species bs ON so.id_bee = bs.id_bee
JOIN 
    Plant p ON so.id_plant = p.id_plant
ORDER BY 
    bs.specie_name, p.plant_name;





--9. Trouver les périodes les plus actives pour chaque site en termes de collecte d’échantillons
SELECT 
    si.site_name AS "Site", 
    TO_CHAR(sa.start_time, 'HH24:MI') AS "Heure Début",
    TO_CHAR(sa.end_time, 'HH24:MI') AS "Heure Fin",
    COUNT(sa.sample_id) AS "Nombre d'Échantillons"
FROM 
    Sample sa
JOIN 
    Site si ON sa.id_site = si.id_site
GROUP BY 
    si.site_name, TO_CHAR(sa.start_time, 'HH24:MI'), TO_CHAR(sa.end_time, 'HH24:MI')
ORDER BY 
    COUNT(sa.sample_id) DESC;
    
    
--10. Compter les échantillons collectés par jour
SELECT 
    TRUNC(Date_Time) AS sample_date,
    COUNT(*) AS total_samples
FROM Sample
GROUP BY TRUNC(Date_Time)
ORDER BY sample_date;



--11. les 5 plantes les plus visitées par les abeilles,
SELECT 
    p.plant_name AS "Plant Name", 
    COUNT(sd.id_bee) AS "Number of Visits"
FROM 
    sample_details sd
JOIN 
    Plant p ON sd.id_plant = p.id_plant
GROUP BY 
    p.plant_name
ORDER BY 
    "Number of Visits" DESC
FETCH FIRST 5 ROWS ONLY;


--12 lister les interactions par site

SELECT
    si.site_name AS Site,
    p.plant_name AS Plant,
    bs.specie_name AS Bee_Species,
    COUNT(DISTINCT sd.id_sample_details) AS Interaction_Count
FROM sample_details sd
JOIN Sample s ON sd.sample_id = s.sample_id
JOIN Site si ON s.id_site = si.id_site
JOIN Plant p ON sd.id_plant = p.id_plant
JOIN Bee_species bs ON sd.id_bee = bs.id_bee
GROUP BY si.site_name, p.plant_name, bs.specie_name
ORDER BY si.site_name, Interaction_Count DESC;


--13.les informations détaillées sur les interactions entre une plante spécifique 
-- (Cosmos bipinnatus) et les abeilles sur un site donné (A)
SELECT 
    p.id_plant, 
    p.plant_name, 
    p.is_native, 
    si.site_name,
    COALESCE(bx.sex, 'Unknown') AS sex,
    COUNT(*) AS interaction_count
FROM Plant p
JOIN sample_details sd ON p.id_plant = sd.id_plant
JOIN Sample s ON sd.sample_id = s.sample_id
JOIN Site si ON s.id_site = si.id_site
LEFT JOIN Bee_sex bx ON sd.id_bee = bx.id_bee
WHERE p.plant_name = 'Cosmos bipinnatus' AND si.site_name = 'A'
GROUP BY p.id_plant, p.plant_name, p.is_native, si.site_name, bx.sex;





-------------------------------------------------------------------------------
--**************************** autre Trigger***********************
---------------------------------------------------------------------------

 --1  Détection des abeilles non natives ajoutées
 
 CREATE OR REPLACE TRIGGER alert_non_native_bees
AFTER INSERT ON Native
FOR EACH ROW
WHEN (NEW.is_native = 0)
BEGIN
    INSERT INTO alerts (alert_type, message, created_at)
    VALUES ('Non-Native Bee', 'Non-native bee detected in site ' || :NEW.id_site, SYSDATE);
END;


--  Ajout automatique d’un statut pour une abeille
CREATE OR REPLACE TRIGGER default_bee_status
BEFORE INSERT ON Bee_species
FOR EACH ROW
BEGIN
    IF :NEW.status IS NULL THEN
        :NEW.status := 'unknown';
    END IF;
END;


-- Supprime automatiquement les doublons dans la table sample_details
CREATE OR REPLACE PROCEDURE remove_duplicates_sample_details
AS
BEGIN
    DELETE FROM sample_details
    WHERE ROWID NOT IN (
        SELECT MIN(ROWID)
        FROM sample_details
        GROUP BY id_plant, id_bee, sample_id
    );
END;

--------------<application>------------------
BEGIN
    remove_duplicates_sample_details();
END;
---------------------------------------------

-------------------*********** triiger Avancee---------
--------------Notification pour dépassement du temps d’échantillonnage---

CREATE TABLE alerts (
    alert_id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    alert_type VARCHAR2(50),
    message VARCHAR2(255),
    created_at DATE DEFAULT SYSDATE
);

CREATE OR REPLACE TRIGGER notify_long_sample_duration
AFTER INSERT OR UPDATE ON Sample
FOR EACH ROW
DECLARE
    sample_duration_hours NUMBER;
BEGIN
    -- Convert TIMESTAMP difference to an interval and extract hours
    sample_duration_hours := EXTRACT(HOUR FROM NUMTODSINTERVAL((
        CAST(:NEW.end_time AS DATE) - CAST(:NEW.start_time AS DATE)
    ) * 24, 'HOUR'));

    -- Vérifier si l'heure est supérieur de 15 hours
    IF sample_duration_hours > 15 THEN
        INSERT INTO alerts (alert_type, message, created_at)
        VALUES ('Long Duration', 'Sample ' || :NEW.sample_id || ' exceeded 8 hours.', SYSDATE);
    END IF;
END;
/


INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time)
VALUES (50000, 1, 1, 1, TO_DATE('2023-07-01', 'YYYY-MM-DD'), 10, TO_TIMESTAMP('08:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:30:00', 'HH24:MI:SS'));

SELECT * FROM alerts;

    
/* ----------------------------------------------------*/
--*************Génération d’un rapport journalier----------------
----------------------------------------------------
CREATE TABLE DAILY_REPORTS (
    report_date DATE PRIMARY KEY,         -- Date du rapport
    total_samples INTEGER,                -- Nombre total d'échantillons
    total_species INTEGER                 -- Nombre total d'espèces observées
);

CREATE OR REPLACE PROCEDURE generate_daily_report
AS
BEGIN
    INSERT INTO DAILY_REPORTS (report_date, total_samples, total_species)
    SELECT 
        TRUNC(SYSDATE) AS report_date,
        COUNT(s.sample_id) AS total_samples,
        COUNT(DISTINCT sd.id_bee) AS total_species
    FROM sample_details sd
    JOIN Sample s ON sd.sample_id = s.sample_id
    WHERE TRUNC(s.Date_Time) = TRUNC(SYSDATE);
END;



BEGIN
    generate_daily_report();
END;


SELECT * FROM DAILY_REPORTS WHERE report_date = TRUNC(SYSDATE);









----------------------- code de remplissage de la base ------------------

-----------table searcher

INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (49, 'Sarah D. Kocher', 'sarah.kocher@gmail.com', 'Princeton, NJ, USA', 'Princeton University');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (2, 'Sydney A. Cameron', 'sydney.cameron@gmail.com', 'Urbana, IL, USA', 'University of Illinois');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (3, 'Heather M. Hines', 'heather.hines@gmail.com', 'State College, PA, USA', 'Pennsylvania State Univ');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (4, 'Hollis Woodard', 'hollis.woodard@gmail.com', 'Riverside, CA, USA', 'UC Riverside');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (5, 'Robert J. Paxton', 'robert.paxton@gmail.com', 'Halle, Germany', 'Martin Luther Univ.');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (6, 'Christoph Grüter', 'christoph.gruter@gmail.com', 'Mainz, Germany', 'Johannes Gutenberg Univ.');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (7, 'Lars Chittka', 'lars.chittka@gmail.com', 'London, UK', 'Queen Mary University');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (8, 'Alice C. Hughes', 'alice.hughes@gmail.com', 'Kunming, China', 'Chinese Academy of Sci.');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (9, 'Ignacio Bartomeus', 'ignacio.bartomeus@gmail.com', 'Sevilla, Spain', 'Estación Biológica Doñana');
INSERT INTO SEARCHER (id_saercher, SEARCHER_NAME, EMAIL, ADRESSE, INSTITUTION) VALUES (10, 'Margarita López-Uribe', 'margarita.lopez@gmail.com', 'State College, PA, USA', 'Pennsylvania State Univ');



--------- table plant 



INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1001, 'Cirsium', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1002, 'Viola', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1003, 'Cucurbita', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1004, 'Penstemon', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1005, 'Ipomoea', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1006, 'Vernonia', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1007, 'Hibiscus', 1);
INSERT INTO Plant (id_plant, plant_name, is_native) VALUES (1008, 'Claytonia', 1);

INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (1, 'Trifolium repens', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2, 'Cosmos bipinnatus', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (4, 'Bidens aristosa', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (7, 'Helenium flexuosum', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (11, 'Daucus carota', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (34, 'Symphyotrichum laeve', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (47, 'Chamaecrista fasciculata + Eupatorium perfoliatum', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (49, 'Trifolium incarnatum', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (50, 'Asclepias tuberosa', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (53, 'Cichorium intybus', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (57, 'Eupatorium perfoliatum', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (61, 'Melilotus officinalis', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (105, 'Papaver rhoeas', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (118, 'Leucanthemum vulgare', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (233, 'Monarda punctata', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (561, 'Calendula officinalis', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (563, 'Chamaecrista fasciculata', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (564, 'Lobularia maritima', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (1296, 'Viola cornuta', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (1467, 'Tradescantia virginiana', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (1567, 'Penstemon digitalis', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (1585, 'Trifolium pratense', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (1811, 'Coronilla varia', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2076, 'Pycnanthemum tenuifolium', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2101, 'Agastache foeniculum', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2257, 'Origanum vulgare', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2261, 'Lotus corniculatus', 0);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2783, 'Chamaecrista nictitans', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (2982, 'Solidago odora', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (5, 'Rudbeckia hirta', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (6, 'Rudbeckia triloba', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (33, 'Chamaecrista nictitans', 1);
INSERT INTO PLANT (ID_PLANT, PLANT_NAME, IS_NATIVE) VALUES (100, 'none', 1);





-------------  BEE_SPECIES

INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (1, 'Bombus', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (2, 'large green bee', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (3, 'Xylocopa virginica', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (4, 'Apis mellifera', 0, 'hive', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (5, 'small dark bee', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (6, 'small green bee', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (7, 'Augochlorella aurata', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (8, 'Halictus rubicundus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (9, 'Osmia collinsiae', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (10, 'Lasioglossum coriaceum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (11, 'Osmia bucephala', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (12, 'Andrena perplexa', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (13, 'Lasioglossum cressonii', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (14, 'Andrena nasonii', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (15, 'nan', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (16, 'Lasioglossum hitchensi', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (17, 'Lasioglossum versatum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (18, 'Lasioglossum trigeminum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (19, 'Lasioglossum pilosum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (20, 'Eucera hamata', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (21, 'Agapostemon virescens', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (22, 'Lasioglossum tegulare', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (23, 'Halictus poeyi/ligatus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (24, 'Agapostemon texanus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (25, 'Lasioglossum nelumbonis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (26, 'Nomada', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (27, 'Augochlora pura', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (28, 'Lasioglossum bruneri', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (29, 'Andrena cressonii', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (30, 'Lasioglossum subviridatum', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (31, 'Agapostemon splendens', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (32, 'Osmia pumila', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (33, 'Nomada bidentate_group', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (34, 'Nomada luteoloides', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (35, 'Nomada imbricata', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (36, 'Nomada articulata', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (37, 'Andrena carlini', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (38, 'Osmia atriventris', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (39, 'Nomada denticulata', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (40, 'Halictus confusus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (41, 'Nomada maculata', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (42, 'Lasioglossum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (43, 'Anthidium oblongatum', 0, 'cavities', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (44, 'Calliopsis andreniformis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (45, 'Hylaeus affinis/modestus', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (46, 'Ceratina calcarata', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (47, 'Ceratina', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (48, 'Megachile brevis', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (49, 'Ceratina strenua', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (50, 'Lasioglossum coreopsis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (51, 'Lasioglossum callidum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (52, 'Melissodes bimaculatus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (53, 'Melissodes desponsus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (54, 'Lasioglossum floridanum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (55, 'Svastra obliqua', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (56, 'Andrena violae', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (57, 'Ceratina mikmaqi', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (58, 'Andrena banksi', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (59, 'Ceratina dupla', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (60, 'Bombus bimaculatus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (61, 'Lasioglossum pectorale', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (62, 'Hylaeus modestus', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (63, 'Nomada australis', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (64, 'Sphecodes', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (65, 'Melissodes trinodis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (66, 'Peponapis pruinosa', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (67, 'Lasioglossum admirandum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (68, 'Bombus impatiens', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (69, 'Triepeolus lunatus', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (70, 'Megachile inimica', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (71, 'Bombus citrinus', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (72, 'Melissodes', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (73, 'Lasioglossum oblongum', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (74, 'Osmia georgica', 0, 'wood/cavities', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (75, 'Andrena (Trachandrena)', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (76, 'Augochloropsis metallica_metallica', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (77, 'Lasioglossum abanci', 0, 'unknown', 'uncommon');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (78, 'Andrena miserabilis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (79, 'Megachile gemula', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (80, 'Agapostemon', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (81, 'Halictus parallelus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (82, 'Osmia subfasciata', 0, 'wood/shell', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (83, 'Lasioglossum vierecki', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (84, 'Nomada pygmaea', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (85, 'Osmia taurus', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (86, 'Osmia distincta', 0, 'unknown', 'uncommon');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (87, 'Hoplitis producta', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (88, 'Andrena barbara', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (89, 'Nomada parva', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (90, 'Osmia sandhouseae', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (91, 'Megachile mendica', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (92, 'Lasioglossum weemsi', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (93, 'Hoplitis pilosifrons', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (94, 'Bombus griseocollis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (95, 'Agapostemon sericeus', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (96, 'Andrena wilkella', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (97, 'Andrena macra', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (98, 'Hoplitis truncata', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (99, 'Augochloropsis metallica_fulgida', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (100, 'Andrena atlantica', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (101, 'Melissodes subillatus', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (102, 'Anthidiellum notatum', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (103, 'Megachile exilis', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (104, 'Heriades carinata', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (105, 'Lasioglossum ephialtum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (106, 'Megachile georgica', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (107, 'Lasioglossum gotham', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (108, 'Megachile texana', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (109, 'Melissodes comptoides', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (110, 'Bombus fervidus/pensylvanicus', 0, 'ground', 'vulnerable (IUCN)');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (111, 'Nomada texana', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (112, 'Melitoma taurea', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (113, 'Triepeolus remigatus', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (114, 'Anthidium manicatum', 0, 'wood/cavities', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (115, 'Bombus pensylvanicus', 0, 'ground', 'vulnerable (IUCN)');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (116, 'Bombus fervidus', 0, 'ground', 'vulnerable (IUCN)');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (117, 'Nomada vegana', 1, 'parasite [ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (118, 'Stelis louisae', 1, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (119, 'Melissodes denticulata', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (120, 'Lasioglossum leucocomum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (121, 'Lasioglossum imitatum', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (122, 'Coelioxys octodentata', 1, 'parasite [wood&ground]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (123, 'Megachile petulans', 0, 'unknown', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (124, 'Ptilothrix bombiformis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (125, 'Pseudopanurgus near_labrosiformis', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (126, 'Lasioglossum fuscipenne', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (127, 'Lasioglossum coeruleum', 0, 'wood', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (128, 'Coelioxys sayi', 1, 'parasite [wood]', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (129, 'Megachile montivaga', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (130, 'Andrena vicina', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (131, 'Andrena imitatrix/morrisonella', 0, 'ground', 'common');
INSERT INTO BEE_SPECIES (ID_BEE, SPECIE_NAME, PARASITIC, NESTING, STATUS) VALUES (132, 'Andrena erigeniae', 0, 'ground', 'common');




---------------Tabel bee_sex

INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (1, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (1, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (2, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (3, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (3, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (4, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (4, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (5, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (6, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (7, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (7, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (8, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (9, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (9, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (10, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (10, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (11, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (11, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (12, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (12, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (13, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (14, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (14, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (15, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (16, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (17, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (18, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (19, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (19, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (20, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (20, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (21, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (21, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (22, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (22, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (23, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (23, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (24, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (24, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (25, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (26, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (27, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (27, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (28, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (29, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (30, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (31, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (31, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (32, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (32, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (33, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (33, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (34, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (35, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (36, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (36, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (37, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (38, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (38, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (39, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (39, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (40, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (40, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (41, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (42, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (42, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (43, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (44, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (44, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (45, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (45, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (46, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (46, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (47, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (48, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (48, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (49, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (49, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (50, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (50, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (51, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (52, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (52, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (53, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (53, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (54, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (55, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (55, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (56, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (57, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (57, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (58, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (58, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (59, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (59, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (60, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (60, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (61, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (61, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (62, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (63, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (63, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (64, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (65, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (65, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (66, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (67, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (68, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (68, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (69, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (70, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (70, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (71, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (72, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (72, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (73, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (74, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (75, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (76, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (76, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (77, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (78, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (78, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (79, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (80, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (81, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (82, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (82, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (83, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (84, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (84, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (85, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (86, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (86, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (87, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (88, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (88, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (89, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (90, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (91, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (91, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (92, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (93, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (93, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (94, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (94, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (95, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (96, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (96, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (97, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (98, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (99, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (100, 'f');

















