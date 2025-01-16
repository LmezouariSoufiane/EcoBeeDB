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
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (101, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (101, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (102, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (102, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (103, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (104, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (105, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (106, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (106, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (107, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (108, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (109, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (109, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (110, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (111, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (112, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (113, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (114, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (115, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (115, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (116, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (117, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (118, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (118, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (119, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (120, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (121, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (122, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (122, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (123, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (124, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (125, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (126, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (127, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (128, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (129, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (130, 'm');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (131, 'f');
INSERT INTO BEE_SEX (ID_BEE, SEX) VALUES (132, 'f');




-------------- table Site
INSERT INTO SITE (ID_SITE, SITE_NAME) VALUES (1, 'A');
INSERT INTO SITE (ID_SITE, SITE_NAME) VALUES (2, 'B');
INSERT INTO SITE (ID_SITE, SITE_NAME) VALUES (3, 'C');


-------------------SEASON

INSERT INTO SEASON (ID_SEASON, SEASON_NAME) VALUES (1, 'late.season');
INSERT INTO SEASON (ID_SEASON, SEASON_NAME) VALUES (2, 'early.season');


------------SPECIALIZED_ON

INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (53, 1001);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (56, 1002);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (66, 1003);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (86, 1004);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (112, 1005);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (119, 1006);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (124, 1007);
INSERT INTO SPECIALIZED_ON (ID_BEE, ID_PLANT) VALUES (132, 1008);

------  SAMPLING_METHOD
INSERT into SAMPLING_METHOD (ID_METHOD, METHOD_NAME) VALUES (1, 'hand netting');
INSERT into SAMPLING_METHOD (ID_METHOD, METHOD_NAME) VALUES (2, 'pan traps');


---------------- is_native

INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (1, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (1, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (1, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (2, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (3, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (4, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (4, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (3, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (4, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (5, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (5, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (5, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (6, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (6, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (3, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (7, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (8, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (9, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (10, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (11, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (12, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (13, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (14, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (15, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (16, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (17, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (18, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (19, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (20, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (21, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (22, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (10, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (19, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (21, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (8, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (14, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (20, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (13, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (15, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (23, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (22, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (24, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (23, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (25, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (26, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (27, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (15, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (28, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (29, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (18, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (30, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (19, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (31, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (24, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (14, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (16, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (24, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (32, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (11, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (7, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (9, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (33, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (34, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (35, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (32, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (20, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (22, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (36, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (9, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (37, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (36, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (38, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (39, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (37, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (32, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (40, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (41, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (42, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (43, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (44, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (18, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (45, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (46, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (27, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (31, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (42, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (47, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (48, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (23, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (21, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (7, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (49, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (50, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (44, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (42, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (50, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (44, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (45, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (17, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (51, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (48, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (50, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (52, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (53, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (46, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (45, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (54, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (53, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (55, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (53, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (47, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (46, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (56, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (57, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (58, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (59, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (60, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (61, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (62, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (28, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (51, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (40, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (54, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (63, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (64, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (49, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (8, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (30, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (27, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (52, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (65, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (30, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (66, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (67, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (13, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (67, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (68, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (68, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (55, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (69, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (70, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (71, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (70, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (40, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (71, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (72, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (52, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (16, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (73, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (74, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (75, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (76, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (51, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (54, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (77, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (78, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (79, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (72, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (64, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (74, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (68, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (64, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (10, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (80, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (37, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (12, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (61, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (17, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (38, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (33, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (78, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (63, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (47, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (81, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (49, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (75, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (63, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (82, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (83, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (84, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (85, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (58, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (86, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (38, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (57, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (87, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (82, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (76, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (86, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (88, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (48, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (74, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (89, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (82, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (90, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (88, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (91, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (92, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (91, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (93, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (60, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (94, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (84, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (95, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (75, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (96, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (97, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (98, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (93, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (91, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (81, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (99, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (100, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (60, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (12, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (98, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (94, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (101, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (102, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (103, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (104, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (105, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (92, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (106, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (73, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (67, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (103, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (107, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (77, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (105, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (92, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (103, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (108, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (69, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (109, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (110, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (111, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (101, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (101, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (102, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (112, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (113, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (114, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (115, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (102, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (94, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (116, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (81, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (117, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (76, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (118, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (110, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (109, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (109, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (119, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (115, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (120, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (106, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (121, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (120, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (122, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (83, 2, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (123, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (124, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (125, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (122, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (126, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (127, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (28, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (126, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (128, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (126, 2, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (59, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (57, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (115, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (116, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (83, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (121, 1, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (31, 1, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (129, 3, 0);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (78, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (130, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (39, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (131, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (132, 3, 1);
INSERT INTO NATIVE (ID_BEE, ID_SITE, IS_NATIVE) VALUES (97, 3, 0);






-----------------Table Sample----------------
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15902, 1, 2, 1, TO_DATE('07-JUN-2016', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15903, 1, 2, 1, TO_DATE('07-JUN-2016', 'DD-MON-YYYY'), 14, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15904, 1, 1, 1, TO_DATE('07-JUN-2016', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15905, 1, 1, 1, TO_DATE('07-JUN-2016', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15906, 1, 1, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15907, 1, 2, 1, TO_DATE('24-MAY-2016', 'DD-MON-YYYY'), 8, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15908, 1, 3, 1, TO_DATE('07-JUN-2016', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15909, 1, 3, 1, TO_DATE('07-JUN-2016', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15910, 1, 1, 1, TO_DATE('26-APR-2016', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('07:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15911, 1, 1, 1, TO_DATE('26-APR-2016', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('07:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15912, 1, 3, 1, TO_DATE('26-APR-2016', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('07:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15913, 1, 2, 1, TO_DATE('26-APR-2016', 'DD-MON-YYYY'), 22, TO_TIMESTAMP('07:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15914, 2, 1, 1, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 29, TO_TIMESTAMP('10:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15915, 2, 1, 1, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('10:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15916, 2, 2, 1, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 23, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15917, 2, 3, 1, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('10:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15918, 2, 2, 1, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 19, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15919, 2, 3, 1, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('10:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15920, 2, 1, 1, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 33, TO_TIMESTAMP('08:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15921, 2, 1, 1, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 34, TO_TIMESTAMP('08:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15922, 2, 2, 1, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 26, TO_TIMESTAMP('09:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15923, 2, 2, 1, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 21, TO_TIMESTAMP('09:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15924, 2, 3, 1, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 42, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15925, 2, 3, 1, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 35, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15926, 2, 1, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('14:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15928, 2, 1, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15929, 2, 1, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15933, 2, 2, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('12:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15934, 2, 3, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 19, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('10:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15935, 2, 2, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('13:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15937, 2, 3, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('10:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15938, 2, 3, 2, TO_DATE('26-AUG-2016', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('10:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15940, 1, 3, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('14:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15941, 1, 1, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('10:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15942, 1, 2, 1, TO_DATE('26-APR-2016', 'DD-MON-YYYY'), 26, TO_TIMESTAMP('07:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15943, 1, 2, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15944, 1, 2, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('13:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15945, 1, 1, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 16, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15946, 1, 3, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('14:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15947, 1, 3, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15948, 1, 3, 2, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15949, 1, 2, 1, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 34, TO_TIMESTAMP('11:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15950, 1, 1, 1, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 14, TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15951, 1, 1, 1, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 16, TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15952, 1, 3, 2, TO_DATE('09-JUN-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('13:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15953, 1, 2, 1, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('08:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15954, 1, 3, 1, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 42, TO_TIMESTAMP('09:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15955, 1, 2, 1, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('11:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15956, 1, 1, 1, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 16, TO_TIMESTAMP('08:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15957, 1, 1, 1, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 30, TO_TIMESTAMP('08:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15958, 1, 2, 1, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('08:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15959, 2, 1, 1, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('09:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15960, 2, 1, 1, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('09:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15961, 2, 2, 1, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('09:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15962, 2, 2, 1, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('09:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15963, 2, 3, 1, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15964, 2, 3, 1, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (15965, 2, 1, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 8, TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16024, 2, 1, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 8, TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16025, 2, 1, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('16:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16026, 2, 2, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('11:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16027, 2, 2, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 14, TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16030, 2, 3, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16032, 2, 3, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('15:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16033, 2, 3, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16034, 2, 3, 1, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 63, TO_TIMESTAMP('10:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16035, 2, 3, 1, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 36, TO_TIMESTAMP('10:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16036, 1, 3, 1, TO_DATE('26-APR-2016', 'DD-MON-YYYY'), 21, TO_TIMESTAMP('07:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16037, 1, 3, 2, TO_DATE('15-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16038, 1, 3, 1, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('11:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16053, 1, 1, 2, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16054, 1, 3, 2, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16056, 1, 1, 2, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16058, 1, 3, 2, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16060, 1, 3, 1, TO_DATE('24-MAY-2016', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16061, 1, 1, 2, TO_DATE('09-JUN-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('12:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16062, 1, 3, 2, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16063, 1, 3, 2, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16064, 1, 3, 1, TO_DATE('07-JUL-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('09:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16065, 1, 3, 1, TO_DATE('22-JUN-2016', 'DD-MON-YYYY'), 30, TO_TIMESTAMP('11:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16066, 1, 2, 1, TO_DATE('24-MAY-2016', 'DD-MON-YYYY'), 33, TO_TIMESTAMP('09:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16067, 1, 1, 1, TO_DATE('24-MAY-2016', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('09:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16068, 2, 2, 1, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('10:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16074, 1, 3, 1, TO_DATE('24-MAY-2016', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16075, 2, 2, 2, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('11:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16076, 2, 2, 1, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('10:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16077, 2, 1, 1, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('10:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16078, 2, 1, 1, TO_DATE('27-JUL-2016', 'DD-MON-YYYY'), 22, TO_TIMESTAMP('10:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16079, 1, 1, 1, TO_DATE('24-MAY-2016', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('09:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16080, 2, 1, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('10:10:00', 'HH24:MI:SS'), TO_TIMESTAMP('10:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16081, 2, 1, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('10:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16082, 2, 1, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('10:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16083, 2, 2, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('16:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16084, 2, 2, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('15:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16085, 2, 2, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16086, 2, 3, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16087, 2, 3, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16088, 2, 3, 2, TO_DATE('06-SEP-2016', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('12:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16089, 2, 1, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16090, 2, 1, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16091, 2, 1, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 14, TO_TIMESTAMP('13:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16092, 2, 2, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('11:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16093, 2, 2, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('11:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('11:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16094, 2, 2, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('11:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16095, 2, 3, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('15:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (16096, 2, 3, 2, TO_DATE('21-SEP-2016', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17400, 1, 1, 1, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 23, TO_TIMESTAMP('09:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17401, 1, 1, 1, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('09:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17402, 1, 2, 1, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('09:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17403, 1, 2, 1, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 35, TO_TIMESTAMP('09:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17406, 1, 3, 2, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('13:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17407, 1, 1, 1, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17408, 1, 1, 1, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17409, 1, 1, 2, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('13:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17410, 1, 2, 1, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17411, 1, 2, 1, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17412, 1, 2, 2, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('10:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17413, 1, 3, 1, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 32, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17414, 1, 3, 1, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 28, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17415, 1, 3, 2, TO_DATE('02-MAY-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('21:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17416, 1, 1, 1, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17417, 1, 1, 1, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17418, 1, 1, 2, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('12:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17419, 1, 2, 1, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17420, 1, 2, 2, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('10:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17421, 1, 2, 1, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17422, 1, 2, 2, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('11:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17423, 1, 3, 1, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 25, TO_TIMESTAMP('09:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17424, 1, 3, 1, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 23, TO_TIMESTAMP('09:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17425, 1, 3, 2, TO_DATE('16-MAY-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('13:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17426, 1, 1, 1, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17427, 1, 1, 2, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('16:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('21:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17428, 1, 1, 1, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17429, 1, 1, 2, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('15:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17430, 1, 2, 1, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 42, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17431, 1, 2, 2, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('14:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17432, 1, 2, 1, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 32, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17433, 1, 2, 2, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('13:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17434, 1, 3, 1, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 28, TO_TIMESTAMP('11:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17435, 1, 3, 2, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('12:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17436, 1, 3, 1, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 35, TO_TIMESTAMP('11:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17437, 1, 3, 2, TO_DATE('26-MAY-2017', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('11:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17438, 1, 1, 1, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 18, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17439, 1, 1, 2, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('10:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17440, 1, 1, 1, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 21, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17441, 1, 1, 2, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17442, 1, 2, 1, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 35, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17443, 1, 2, 2, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17444, 1, 2, 1, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 27, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17445, 1, 2, 2, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('16:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17446, 1, 3, 1, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 60, TO_TIMESTAMP('09:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17447, 1, 3, 2, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('13:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17448, 1, 1, 1, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 26, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17449, 1, 3, 1, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 28, TO_TIMESTAMP('09:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17450, 1, 1, 2, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('17:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17451, 1, 1, 1, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17452, 1, 1, 2, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('16:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17453, 2, 2, 1, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('09:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17454, 1, 2, 2, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 25, TO_TIMESTAMP('03:01:00', 'HH24:MI:SS'), TO_TIMESTAMP('05:01:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17455, 1, 2, 1, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 26, TO_TIMESTAMP('03:01:00', 'HH24:MI:SS'), TO_TIMESTAMP('05:01:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17456, 1, 2, 2, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('05:01:00', 'HH24:MI:SS'), TO_TIMESTAMP('08:01:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17457, 1, 3, 1, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 43, TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17458, 1, 3, 2, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17459, 1, 3, 2, TO_DATE('13-JUN-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('14:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17460, 1, 3, 1, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 51, TO_TIMESTAMP('11:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17461, 1, 3, 2, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('14:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17462, 2, 1, 1, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 43, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17463, 2, 1, 2, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('15:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17464, 2, 1, 1, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 34, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17465, 2, 1, 2, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('15:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17466, 2, 2, 2, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('10:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17467, 1, 2, 1, TO_DATE('03-JUL-2017', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('04:01:00', 'HH24:MI:SS'), TO_TIMESTAMP('09:01:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17468, 2, 2, 1, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 22, TO_TIMESTAMP('09:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17469, 2, 2, 2, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('11:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17470, 2, 3, 1, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 34, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17471, 2, 3, 2, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('10:10:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17472, 2, 3, 1, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 36, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17473, 2, 3, 2, TO_DATE('18-JUL-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('09:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17474, 2, 1, 1, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 37, TO_TIMESTAMP('10:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17475, 2, 1, 2, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('12:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17476, 2, 1, 1, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 28, TO_TIMESTAMP('10:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17477, 2, 1, 2, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('11:10:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17478, 2, 2, 1, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('10:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17479, 2, 2, 2, TO_DATE('02-AUG-2017', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('10:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17480, 2, 2, 1, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('10:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17481, 2, 2, 2, TO_DATE('02-AUG-2017', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17482, 2, 3, 1, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 33, TO_TIMESTAMP('10:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17483, 2, 3, 2, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('15:10:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:10:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17484, 2, 3, 1, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 32, TO_TIMESTAMP('10:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17485, 2, 3, 2, TO_DATE('01-AUG-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('14:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17486, 2, 1, 2, TO_DATE('02-AUG-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('11:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17487, 2, 1, 1, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 27, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17488, 2, 1, 2, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('10:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17489, 2, 1, 1, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 21, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17490, 2, 1, 2, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('11:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17491, 2, 2, 1, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17492, 2, 2, 2, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('13:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17493, 2, 2, 1, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 10, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17494, 2, 2, 2, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17495, 2, 3, 1, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 26, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17496, 2, 3, 2, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('15:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17497, 2, 3, 1, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 17, TO_TIMESTAMP('09:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17498, 2, 3, 2, TO_DATE('24-AUG-2017', 'DD-MON-YYYY'), 8, TO_TIMESTAMP('16:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17499, 2, 2, 2, TO_DATE('25-AUG-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('11:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17500, 2, 3, 2, TO_DATE('25-AUG-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('09:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17501, 2, 1, 1, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 28, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17502, 2, 1, 2, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('16:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17503, 2, 1, 1, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 34, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17504, 2, 1, 2, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('15:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17505, 2, 2, 1, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17506, 2, 2, 2, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('13:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17507, 2, 2, 1, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17508, 2, 2, 2, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('13:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17509, 2, 3, 1, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17510, 2, 3, 2, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('11:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17511, 2, 3, 1, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17512, 2, 3, 2, TO_DATE('31-AUG-2017', 'DD-MON-YYYY'), 15, TO_TIMESTAMP('10:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17513, 2, 1, 1, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 7, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17514, 2, 1, 2, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('15:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17515, 2, 1, 1, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17516, 2, 1, 2, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('16:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('19:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17517, 2, 2, 1, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17518, 2, 2, 2, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 8, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17519, 2, 2, 1, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('09:40:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:40:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17520, 2, 2, 2, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('11:50:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:50:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17521, 2, 3, 1, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 12, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17522, 2, 3, 2, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 8, TO_TIMESTAMP('13:00:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:00:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17523, 2, 3, 1, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('12:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17524, 2, 3, 2, TO_DATE('15-SEP-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17525, 2, 1, 1, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17526, 2, 1, 2, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('11:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17527, 2, 1, 1, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('09:55:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:55:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17528, 2, 1, 2, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('10:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17529, 2, 2, 1, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17530, 2, 2, 2, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('17:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('21:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17531, 2, 2, 1, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('09:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17532, 2, 2, 2, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('16:30:00', 'HH24:MI:SS'), TO_TIMESTAMP('21:30:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17533, 2, 3, 1, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17534, 2, 3, 2, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('14:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17535, 2, 3, 1, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 9, TO_TIMESTAMP('09:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17536, 2, 3, 2, TO_DATE('20-SEP-2017', 'DD-MON-YYYY'), 11, TO_TIMESTAMP('13:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('18:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17537, 2, 1, 1, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 14, TO_TIMESTAMP('10:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17538, 2, 1, 2, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('11:20:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:20:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17539, 2, 1, 1, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 14, TO_TIMESTAMP('10:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17540, 2, 1, 2, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('12:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17541, 2, 2, 1, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 4, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17542, 2, 2, 2, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('13:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('16:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17543, 2, 2, 1, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 2, TO_TIMESTAMP('10:35:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:35:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17544, 2, 2, 2, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 3, TO_TIMESTAMP('14:25:00', 'HH24:MI:SS'), TO_TIMESTAMP('17:25:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17545, 2, 3, 1, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 13, TO_TIMESTAMP('10:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('13:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17546, 2, 3, 2, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 5, TO_TIMESTAMP('16:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17547, 2, 3, 1, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 6, TO_TIMESTAMP('10:15:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:15:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17548, 2, 3, 2, TO_DATE('03-OCT-2017', 'DD-MON-YYYY'), 1, TO_TIMESTAMP('16:45:00', 'HH24:MI:SS'), TO_TIMESTAMP('20:45:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17404, 1, 3, 1, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 30, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('14:05:00', 'HH24:MI:SS'));"
INSERT INTO Sample (sample_id, id_season, id_site, id_method, Date_Time, Species_nbr, start_time, end_time) VALUES (17405, 1, 3, 1, TO_DATE('18-APR-2017', 'DD-MON-YYYY'), 20, TO_TIMESTAMP('10:05:00', 'HH24:MI:SS'), TO_TIMESTAMP('15:05:00', 'HH24:MI:SS'));"



select *from sample

---------------------- table sample_details-----------


INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1,100, 7, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2,100, 8, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3,100, 9, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4,100, 10, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (5,100, 11, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (6,100, 10, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (7,100, 12, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (8,100, 10, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (9,100, 13, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (10,100, 14, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (11,100, 14, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (12,100, 13, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (13,100, 14, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (14,100, 16, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (15,100, 7, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (16,100, 10, 15902);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (17,100, 17, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (18,100, 18, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (19,100, 18, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (20,100, 10, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (21,100, 19, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (22,100, 20, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (23,100, 10, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (24,100, 10, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (25,100, 21, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (26,100, 19, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (27,100, 10, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (28,100, 22, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (29,100, 12, 15903);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (30,100, 10, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (31,100, 19, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (32,100, 21, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (33,100, 19, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (34,100, 8, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (35,100, 14, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (36,100, 19, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (37,100, 19, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (38,100, 10, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (39,100, 20, 15904);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (40,100, 10, 15905);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (41,100, 13, 15905);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (42,100, 11, 15905);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (43,100, 19, 15905);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (44,100, 21, 15905);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (45, 105, 23, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (46, 16, 23, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (47, 105, 22, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (48, 16, 22, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (49, 105, 23, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (50, 16, 23, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (51, 105, 23, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (52, 16, 23, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (53, 105, 19, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (54, 16, 19, 15906);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (55,100, 7, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (56,100, 20, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (57,100, 20, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (58,100, 21, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (59,100, 24, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (60,100, 23, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (61,100, 25, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (62,100, 26, 15907);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (63,100, 27, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (64,100, 11, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (65,100, 28, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (66,100, 29, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (67,100, 18, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (68,100, 30, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (69,100, 30, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (70,100, 19, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (71,100, 19, 15908);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (72,100, 19, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (73,100, 19, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (74,100, 19, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (75,100, 31, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (76,100, 19, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (77,100, 30, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (78,100, 19, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (79,100, 24, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (80,100, 19, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (81,100, 28, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (82,100, 24, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (83,100, 14, 15909);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (84,100, 16, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (85,100, 16, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (86,100, 20, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (87,100, 19, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (88,100, 22, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (89,100, 24, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (90,100, 32, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (91,100, 19, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (92,100, 19, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (93,100, 12, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (94,100, 24, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (95,100, 21, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (96,100, 32, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (97,100, 24, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (98,100, 11, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (99,100, 11, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (100,100, 24, 15910);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (101,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (102,100, 19, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (103,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (104,100, 7, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (105,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (106,100, 9, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (107,100, 21, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (108,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (109,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (110,100, 33, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (111,100, 34, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (112,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (113,100, 19, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (114,100, 21, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (115,100, 7, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (116,100, 24, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (117,100, 19, 15911);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (118,100, 24, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (119,100, 35, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (120,100, 19, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (121,100, 32, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (122,100, 20, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (123,100, 19, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (124,100, 24, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (125,100, 22, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (126,100, 24, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (127,100, 36, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (128,100, 9, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (129,100, 32, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (130,100, 24, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (131,100, 24, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (132,100, 37, 15912);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (133,100, 24, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (134,100, 7, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (135,100, 36, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (136,100, 38, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (137,100, 7, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (138,100, 7, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (139,100, 21, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (140,100, 24, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (141,100, 39, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (142,100, 39, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (143,100, 7, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (144,100, 37, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (145,100, 11, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (146,100, 32, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (147,100, 40, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (148,100, 41, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (149,100, 14, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (150,100, 24, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (151,100, 7, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (152,100, 24, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (153,100, 24, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (154,100, 7, 15913);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (155,100, 42, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (156,100, 43, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (157,100, 22, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (158,100, 10, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (159,100, 22, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (160,100, 42, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (161,100, 22, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (162,100, 10, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (163,100, 7, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (164,100, 22, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (165,100, 23, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (166,100, 19, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (167,100, 7, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (168,100, 44, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (169,100, 19, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (170,100, 19, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (171,100, 18, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (172,100, 45, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (173,100, 10, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (174,100, 46, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (175,100, 19, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (176,100, 23, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (177,100, 10, 15914);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (178,100, 23, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (179,100, 21, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (180,100, 18, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (181,100, 21, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (182,100, 23, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (183,100, 7, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (184,100, 7, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (185,100, 7, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (186,100, 45, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (187,100, 7, 15915);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (188,100, 21, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (189,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (190,100, 27, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (191,100, 19, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (192,100, 31, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (193,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (194,100, 27, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (195,100, 23, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (196,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (197,100, 21, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (198,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (199,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (200,100, 42, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (201,100, 19, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (202,100, 42, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (203,100, 21, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (204,100, 27, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (205,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (206,100, 13, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (207,100, 27, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (208,100, 47, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (209,100, 7, 15916);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (210,100, 48, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (211,100, 23, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (212,100, 30, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (213,100, 21, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (214,100, 27, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (215,100, 7, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (216,100, 7, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (217,100, 24, 15917);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (218,100, 49, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (219,100, 10, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (220,100, 4, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (221,100, 7, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (222,100, 4, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (223,100, 18, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (224,100, 4, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (225,100, 21, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (226,100, 50, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (227,100, 18, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (228,100, 7, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (229,100, 10, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (230,100, 7, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (231,100, 10, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (232,100, 42, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (233,100, 4, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (234,100, 44, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (235,100, 10, 15918);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (236,100, 24, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (237,100, 42, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (238,100, 50, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (239,100, 24, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (240,100, 3, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (241,100, 42, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (242,100, 21, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (243,100, 19, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (244,100, 19, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (245,100, 44, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (246,100, 31, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (247,100, 31, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (248,100, 45, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (249,100, 4, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (250,100, 17, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (251,100, 7, 15919);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (252,100, 42, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (253,100, 51, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (254,100, 22, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (255,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (256,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (257,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (258,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (259,100, 42, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (260,100, 44, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (261,100, 42, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (262,100, 16, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (263,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (264,100, 44, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (265,100, 42, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (266,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (267,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (268,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (269,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (270,100, 48, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (271,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (272,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (273,100, 44, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (274,100, 50, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (275,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (276,100, 42, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (277,100, 19, 15920);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (278,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (279,100, 44, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (280,100, 23, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (281,100, 22, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (282,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (283,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (284,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (285,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (286,100, 48, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (287,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (288,100, 23, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (289,100, 42, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (290,100, 44, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (291,100, 44, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (292,100, 44, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (293,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (294,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (295,100, 44, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (296,100, 16, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (297,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (298,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (299,100, 23, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (300,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (301,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (302,100, 19, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (303,100, 7, 15921);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (304,100, 19, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (305,100, 27, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (306,100, 22, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (307,100, 27, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (308,100, 27, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (309,100, 16, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (310,100, 23, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (311,100, 7, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (312,100, 52, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (313,100, 7, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (314,100, 16, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (315,100, 22, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (316,100, 20, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (317,100, 7, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (318,100, 18, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (319,100, 53, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (320,100, 27, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (321,100, 27, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (322,100, 10, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (323,100, 27, 15922);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (324,100, 7, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (325,100, 7, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (326,100, 10, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (327,100, 7, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (328,100, 23, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (329,100, 19, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (330,100, 50, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (331,100, 27, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (332,100, 7, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (333,100, 7, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (334,100, 7, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (335,100, 46, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (336,100, 45, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (337,100, 22, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (338,100, 23, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (339,100, 42, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (340,100, 10, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (341,100, 50, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (342,100, 19, 15923);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (343,100, 23, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (344,100, 19, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (345,100, 19, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (346,100, 22, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (347,100, 23, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (348,100, 19, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (349,100, 30, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (350,100, 22, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (351,100, 23, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (352,100, 28, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (353,100, 31, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (354,100, 50, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (355,100, 54, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (356,100, 23, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (357,100, 19, 15924);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (358,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (359,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (360,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (361,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (362,100, 19, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (363,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (364,100, 19, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (365,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (366,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (367,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (368,100, 19, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (369,100, 7, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (370,100, 19, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (371,100, 23, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (372,100, 42, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (373,100, 27, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (374,100, 19, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (375,100, 13, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (376,100, 19, 15925);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (377, 2,100, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (378, 273,100, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (379, 20,100, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (380, 2, 22, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (381, 273, 22, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (382, 20, 22, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (383, 2, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (384, 273, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (385, 20, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (386, 2, 53, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (387, 273, 53, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (388, 20, 53, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (389, 2, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (390, 273, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (391, 20, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (392, 2, 46, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (393, 273, 46, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (394, 20, 46, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (395, 2, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (396, 273, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (397, 20, 23, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (398, 2, 53, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (399, 273, 53, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (400, 20, 53, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (401, 2, 3, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (402, 273, 3, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (403, 20, 3, 15926);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (404, 5, 23, 15928);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (405, 6, 42, 15929);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (406, 2, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (407, 273, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (408, 20, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (409, 2, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (410, 273, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (411, 20, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (412, 2, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (413, 273, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (414, 20, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (415, 2, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (416, 273, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (417, 20, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (418, 2, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (419, 273, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (420, 20, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (421, 2, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (422, 273, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (423, 20, 23, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (424, 2, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (425, 273, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (426, 20, 53, 15933);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (427, 2, 4, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (428, 273, 4, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (429, 20, 4, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (430, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (431, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (432, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (433, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (434, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (435, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (436, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (437, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (438, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (439, 2, 55, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (440, 273, 55, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (441, 20, 55, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (442, 2, 53, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (443, 273, 53, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (444, 20, 53, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (445, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (446, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (447, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (448, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (449, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (450, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (451, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (452, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (453, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (454, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (455, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (456, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (457, 2, 50, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (458, 273, 50, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (459, 20, 50, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (460, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (461, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (462, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (463, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (464, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (465, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (466, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (467, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (468, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (469, 2, 1, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (470, 273, 1, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (471, 20, 1, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (472, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (473, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (474, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (475, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (476, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (477, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (478, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (479, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (480, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (481, 2, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (482, 273, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (483, 20, 23, 15934);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (484, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (485, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (486, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (487, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (488, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (489, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (490, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (491, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (492, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (493, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (494, 5, 23, 15935);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (495, 6, 23, 15937);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (496, 5, 50, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (497, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (498, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (499, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (500, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (501, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (502, 5, 50, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (503, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (504, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (505, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (506, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (507, 5, 23, 15938);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (508, 2, 47, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (509, 273, 47, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (510, 20, 47, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (511, 2, 23, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (512, 273, 23, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (513, 20, 23, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (514, 2, 46, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (515, 273, 46, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (516, 20, 46, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (517, 2, 30, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (518, 273, 30, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (519, 20, 30, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (520, 2, 46, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (521, 273, 46, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (522, 20, 46, 15940);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (523, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (524, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (525, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (526, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (527, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (528, 5, 19, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (529, 5, 19, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (530, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (531, 5, 23, 15941);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (532,100, 9, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (533,100, 38, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (534,100, 49, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (535,100, 56, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (536,100, 7, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (537,100, 7, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (538,100, 47, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (539,100, 26, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (540,100, 7, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (541,100, 57, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (542,100, 20, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (543,100, 32, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (544,100, 50, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (545,100, 50, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (546,100, 58, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (547,100, 59, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (548,100, 57, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (549,100, 32, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (550,100, 7, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (551,100, 57, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (552,100, 38, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (553,100, 24, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (554,100, 7, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (555,100, 4, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (556,100, 20, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (557,100, 32, 15942);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (558, 5, 23, 15943);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (559, 5, 23, 15943);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (560, 5, 23, 15943);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (561, 5, 23, 15943);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (562, 5, 23, 15943);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (563, 5, 23, 15943);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (564, 2, 52, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (565, 273, 52, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (566, 20, 52, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (567, 2, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (568, 273, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (569, 20, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (570, 2, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (571, 273, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (572, 20, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (573, 2, 7, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (574, 273, 7, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (575, 20, 7, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (576, 2, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (577, 273, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (578, 20, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (579, 2, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (580, 273, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (581, 20, 23, 15944);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (582, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (583, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (584, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (585, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (586, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (587, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (588, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (589, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (590, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (591, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (592, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (593, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (594, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (595, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (596, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (597, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (598, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (599, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (600, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (601, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (602, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (603, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (604, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (605, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (606, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (607, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (608, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (609, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (610, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (611, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (612, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (613, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (614, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (615, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (616, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (617, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (618, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (619, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (620, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (621, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (622, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (623, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (624, 2, 19, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (625, 273, 19, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (626, 20, 19, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (627, 2, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (628, 273, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (629, 20, 23, 15945);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (630, 561, 30, 15946);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (631, 21, 30, 15946);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (632, 561, 31, 15946);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (633, 21, 31, 15946);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (634, 563, 50, 15947);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (635, 22, 50, 15947);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (636, 564,100, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (637, 23,100, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (638, 564, 60, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (639, 23, 60, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (640, 564, 61, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (641, 23, 61, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (642, 564, 62, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (643, 23, 62, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (644, 564, 22, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (645, 23, 22, 15948);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (646,100, 17, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (647,100, 19, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (648,100, 28, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (649,100, 23, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (650,100, 51, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (651,100, 44, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (652,100, 18, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (653,100, 7, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (654,100, 28, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (655,100, 18, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (656,100, 21, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (657,100, 21, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (658,100, 10, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (659,100, 22, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (660,100, 16, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (661,100, 10, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (662,100, 7, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (663,100, 7, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (664,100, 21, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (665,100, 17, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (666,100, 10, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (667,100, 28, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (668,100, 7, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (669,100, 7, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (670,100, 21, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (671,100, 42, 15949);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (672,100, 19, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (673,100, 18, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (674,100, 22, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (675,100, 22, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (676,100, 40, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (677,100, 7, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (678,100, 22, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (679,100, 19, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (680,100, 22, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (681,100, 54, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (682,100, 18, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (683,100, 19, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (684,100, 40, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (685,100, 19, 15950);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (686,100, 18, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (687,100, 10, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (688,100, 19, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (689,100, 19, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (690,100, 19, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (691,100, 4, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (692,100, 22, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (693,100, 23, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (694,100, 22, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (695,100, 23, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (696,100, 42, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (697,100, 21, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (698,100, 23, 15951);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (699, 564, 63, 15952);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (700, 23, 63, 15952);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (701, 564, 64, 15952);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (702, 23, 64, 15952);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (703,100, 52, 15953);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (704,100, 10, 15953);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (705,100, 22, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (706,100, 19, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (707,100, 19, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (708,100, 4, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (709,100, 19, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (710,100, 49, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (711,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (712,100, 19, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (713,100, 4, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (714,100, 19, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (715,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (716,100, 27, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (717,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (718,100, 28, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (719,100, 8, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (720,100, 19, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (721,100, 23, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (722,100, 27, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (723,100, 23, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (724,100,11, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (725,100, 54, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (726,100, 22, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (727,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (728,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (729,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (730,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (731,100, 27, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (732,100, 27, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (733,100, 18, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (734,100, 42, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (735,100, 50, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (736,100, 30, 15954);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (737,100, 21, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (738,100, 7, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (739,100, 18, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (740,100, 23, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (741,100, 21, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (742,100, 7, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (743,100, 22, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (744,100, 23, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (745,100, 7, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (746,100, 7, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (747,100, 17, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (748,100, 30, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (749,100, 22, 15955);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (750,100, 19, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (751,100, 7, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (752,100, 19, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (753,100, 44, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (754,100, 18, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (755,100, 27, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (756,100, 52, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (757,100, 52, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (758,100, 65, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (759,100,11, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (760,100, 7, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (761,100, 30, 15956);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (762,100, 24, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (763,100, 16, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (764,100, 19, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (765,100, 19, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (766,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (767,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (768,100, 66, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (769,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (770,100, 24, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (771,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (772,100, 13, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (773,100, 24, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (774,100, 19, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (775,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (776,100, 27, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (777,100, 24, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (778,100, 27, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (779,100, 22, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (780,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (781,100, 7, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (782,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (783,100, 52, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (784,100, 22, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (785,100, 19, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (786,100, 19, 15957);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (787,100, 46, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (788,100, 27, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (789,100, 24, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (790,100, 21, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (791,100, 52, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (792,100, 7, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (793,100, 52, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (794,100, 23, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (795,100, 24, 15958);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (796,100, 4, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (797,100, 18, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (798,100, 19, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (799,100, 23, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (800,100, 19, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (801,100, 19, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (802,100, 50, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (803,100, 27, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (804,100, 23, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (805,100, 23, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (806,100, 18, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (807,100, 4, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (808,100, 42, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (809,100, 23, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (810,100, 67, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (811,100, 50, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (812,100, 19, 15959);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (813,100, 23, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (814,100, 50, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (815,100, 19, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (816,100, 4, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (817,100, 27, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (818,100, 27, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (819,100, 27, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (820,100, 23, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (821,100, 23, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (822,100, 50, 15960);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (823,100, 16, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (824,100, 7, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (825,100, 22, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (826,100, 42, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (827,100, 27, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (828,100, 4, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (829,100, 10, 15961);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (830,100, 22, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (831,100, 23, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (832,100, 10, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (833,100, 23, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (834,100, 50, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (835,100, 27, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (836,100, 18, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (837,100, 18, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (838,100, 7, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (839,100, 7, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (840,100, 42, 15962);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (841,100, 44, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (842,100, 13, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (843,100, 17, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (844,100, 19, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (845,100, 67, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (846,100, 24, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (847,100, 31, 15963);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (848,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (849,100, 19, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (850,100, 68, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (851,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (852,100, 22, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (853,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (854,100, 19, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (855,100, 27, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (856,100, 19, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (857,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (858,100, 54, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (859,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (860,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (861,100, 23, 15964);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (862, 5, 23, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (863, 5, 23, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (864, 5, 23, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (865, 5, 19, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (866, 5, 23, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (867, 5, 23, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (868, 5, 23, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (869, 5, 19, 15965);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (870, 563, 42, 16024);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (871, 22, 42, 16024);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (872, 563, 68, 16024);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (873, 22, 68, 16024);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (874, 2, 19, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (875, 273, 19, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (876, 20, 19, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (877, 2, 23, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (878, 273, 23, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (879, 20, 23, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (880, 2, 23, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (881, 273, 23, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (882, 20, 23, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (883, 2, 4, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (884, 273, 4, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (885, 20, 4, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (886, 2, 55, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (887, 273, 55, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (888, 20, 55, 16025);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (889, 563, 22, 16026);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (890, 22, 22, 16026);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (891, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (892, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (893, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (894, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (895, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (896, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (897, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (898, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (899, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (900, 2, 69, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (901, 273, 69, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (902, 20, 69, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (903, 2, 50, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (904, 273, 50, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (905, 20, 50, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (906, 2, 50, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (907, 273, 50, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (908, 20, 50, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (909, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (910, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (911, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (912, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (913, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (914, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (915, 2, 46, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (916, 273, 46, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (917, 20, 46, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (918, 2, 4, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (919, 273, 4, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (920, 20, 4, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (921, 2, 70, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (922, 273, 70, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (923, 20, 70, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (924, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (925, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (926, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (927, 2, 71, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (928, 273, 71, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (929, 20, 71, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (930, 2, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (931, 273, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (932, 20, 23, 16027);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (933, 5, 70, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (934, 5, 42, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (935, 5, 68, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (936, 5, 22, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (937, 5, 23, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (938, 5, 23, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (939, 5, 40, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (940, 5, 71, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (941, 5, 72, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (942, 5, 46, 16030);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (943, 2, 23, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (944, 273, 23, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (945, 20, 23, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (946, 2, 46, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (947, 273, 46, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (948, 20, 46, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (949, 2, 52, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (950, 273, 52, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (951, 20, 52, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (952, 2, 71, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (953, 273, 71, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (954, 20, 71, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (955, 2, 23, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (956, 273, 23, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (957, 20, 23, 16032);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (958, 561, 23, 16033);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (959, 21, 23, 16033);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (960,100, 4, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (961,100, 46, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (962,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (963,100, 16, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (964,100, 4, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (965,100, 17, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (966,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (967,100, 7, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (968,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (969,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (970,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (971,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (972,100, 7, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (973,100, 18, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (974,100, 4, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (975,100, 27, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (976,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (977,100, 7, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (978,100, 27, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (979,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (980,100, 19, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (981,100, 42, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (982,100, 23, 16034);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (983,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (984,100, 28, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (985,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (986,100, 30, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (987,100, 22, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (988,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (989,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (990,100, 27, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (991,100, 28, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (992,100, 18, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (993,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (994,100, 7, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (995,100, 7, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (996,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (997,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (998,100, 4, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (999,100, 28, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1000,100, 4, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1001,100, 27, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1002,100,11, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1003,100, 17, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1004,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1005,100, 27, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1006,100, 16, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1007,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1008,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1009,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1010,100, 19, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1011,100, 52, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1012,100, 73, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1013,100, 4, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1014,100, 31, 16035);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1015,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1016,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1017,100, 36, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1018,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1019,100, 74, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1020,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1021,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1022,100, 75, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1023,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1024,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1025,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1026,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1027,100, 7, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1028,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1029,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1030,100, 19, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1031,100, 63, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1032,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1033,100, 19, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1034,100, 36, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1035,100, 24, 16036);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1036, 5, 23, 16037);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1037, 5, 23, 16037);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1038,100, 28, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1039,100, 45, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1040,100, 19, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1041,100, 22, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1042,100, 19, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1043,100, 54, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1044,100, 22, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1045,100, 19, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1046,100, 28, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1047,100, 22, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1048,100, 19, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1049,100, 19, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1050,100, 54, 16038);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1051, 561, 23, 16053);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1052, 21, 23, 16053);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1053, 105, 19, 16054);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1054, 16, 19, 16054);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1055, 105, 23, 16054);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1056, 16, 23, 16054);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1057, 2, 24, 16056);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1058, 273, 24, 16056);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1059, 20, 24, 16056);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1060, 2, 23, 16056);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1061, 273, 23, 16056);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1062, 20, 23, 16056);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1063, 561, 22, 16058);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1064, 21, 22, 16058);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1065,100, 7, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1066,100, 31, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1067,100, 24, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1068,100, 28, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1069,100, 19, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1070,100, 20, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1071,100, 76, 16060);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1072, 564, 22, 16061);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1073, 23, 22, 16061);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1074, 564,100, 16061);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1075, 23,100, 16061);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1076, 564, 30, 16062);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1077, 23, 30, 16062);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1078, 564, 27, 16062);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1079, 23, 27, 16062);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1080, 564, 19, 16062);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1081, 23, 19, 16062);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1082, 2, 23, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1083, 273, 23, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1084, 20, 23, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1085, 2, 22, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1086, 273, 22, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1087, 20, 22, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1088, 2, 28, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1089, 273, 28, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1090, 20, 28, 16063);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1091,100, 52, 16064);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1092,100, 24, 16064);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1093,100, 51, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1094,100, 19, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1095,100, 28, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1096,100, 30, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1097,100, 22, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1098,100, 67, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1099,100, 19, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1100,100, 50, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1101,100, 30, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1102,100, 76, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1103,100, 28, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1104,100, 19, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1105,100, 28, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1106,100, 51, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1107,100, 28, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1108,100, 23, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1109,100, 19, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1110,100, 28, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1111,100, 30, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1112,100, 31, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1113,100, 30, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1114,100, 22, 16065);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1115,100, 13, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1116,100, 54, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1117,100, 21, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1118,100, 42, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1119,100, 23, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1120,100, 49, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1121,100, 28, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1122,100, 19, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1123,100, 21, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1124,100, 12, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1125,100, 32, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1126,100, 14, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1127,100, 19, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1128,100, 7, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1129,100, 30, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1130,100, 56, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1131,100, 24, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1132,100, 19, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1133,100, 28, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1134,100, 30, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1135,100, 32, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1136,100, 77, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1137,100, 8, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1138,100, 21, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1139,100, 42, 16066);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1140,100, 20, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1141,100, 18, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1142,100, 10, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1143,100, 19, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1144,100, 24, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1145,100, 78, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1146,100, 22, 16067);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1147,100, 44, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1148,100, 7, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1149,100, 7, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1150,100, 27, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1151,100, 17, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1152,100, 7, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1153,100, 7, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1154,100, 10, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1155,100, 52, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1156,100, 7, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1157,100, 13, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1158,100, 18, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1159,100, 17, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1160,100, 7, 16068);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1161,100, 16, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1162,100, 45, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1163,100, 28, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1164,100, 24, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1165,100, 24, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1166,100, 22, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1167,100, 63, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1168,100, 36, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1169,100, 79, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1170,100, 28, 16074);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1171, 5, 59, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1172, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1173, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1174, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1175, 5, 19, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1176, 5, 21, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1177, 5,100, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1178, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1179, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1180, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1181, 5, 23, 16075);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1182,100, 7, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1183,100, 27, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1184,100, 52, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1185,100, 23, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1186,100, 17, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1187,100, 7, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1188,100, 72, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1189,100, 16, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1190,100, 27, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1191,100, 52, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1192,100, 27, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1193,100, 42, 16076);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1194,100, 23, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1195,100, 7, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1196,100, 23, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1197,100, 7, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1198,100, 19, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1199,100, 19, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1200,100, 7, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1201,100, 19, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1202,100, 52, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1203,100, 19, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1204,100, 19, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1205,100, 7, 16077);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1206,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1207,100, 7, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1208,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1209,100, 44, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1210,100, 7, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1211,100, 44, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1212,100, 50, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1213,100, 44, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1214,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1215,100, 7, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1216,100, 23, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1217,100, 22, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1218,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1219,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1220,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1221,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1222,100, 19, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1223,100, 44, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1224,100, 44, 16078);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1225,100, 24, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1226,100, 64, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1227,100, 24, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1228,100, 74, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1229,100, 22, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1230,100, 14, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1231,100, 22, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1232,100, 23, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1233,100, 22, 16079);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1234, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1235, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1236, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1237, 2, 4, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1238, 273, 4, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1239, 20, 4, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1240, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1241, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1242, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1243, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1244, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1245, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1246, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1247, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1248, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1249, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1250, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1251, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1252, 2, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1253, 273, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1254, 20, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1255, 2, 3, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1256, 273, 3, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1257, 20, 3, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1258, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1259, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1260, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1261, 2, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1262, 273, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1263, 20, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1264, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1265, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1266, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1267, 2, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1268, 273, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1269, 20, 68, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1270, 2, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1271, 273, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1272, 20, 23, 16080);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1273, 4, 23, 16081);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1274, 5, 23, 16082);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1275, 5, 23, 16083);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1276, 5, 23, 16083);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1277, 5, 23, 16083);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1278, 11, 4, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1279, 51, 4, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1280, 11, 4, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1281, 51, 4, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1282, 11, 53, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1283, 51, 53, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1284, 11, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1285, 51, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1286, 11, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1287, 51, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1288, 11, 68, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1289, 51, 68, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1290, 11, 68, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1291, 51, 68, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1292, 11, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1293, 51, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1294, 11, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1295, 51, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1296, 11, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1297, 51, 23, 16084);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1298, 2, 64, 16085);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1299, 273, 64, 16085);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1300, 20, 64, 16085);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1301, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1302, 5, 42, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1303, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1304, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1305, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1306, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1307, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1308, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1309, 5, 23, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1310, 5, 50, 16086);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1311, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1312, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1313, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1314, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1315, 4, 10, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1316, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1317, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1318, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1319, 4, 23, 16087);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1320, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1321, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1322, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1323, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1324, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1325, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1326, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1327, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1328, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1329, 2, 31, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1330, 273, 31, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1331, 20, 31, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1332, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1333, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1334, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1335, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1336, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1337, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1338, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1339, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1340, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1341, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1342, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1343, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1344, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1345, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1346, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1347, 2, 31, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1348, 273, 31, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1349, 20, 31, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1350, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1351, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1352, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1353, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1354, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1355, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1356, 2, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1357, 273, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1358, 20, 23, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1359, 2, 68, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1360, 273, 68, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1361, 20, 68, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1362, 2, 53, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1363, 273, 53, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1364, 20, 53, 16088);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1365, 5, 23, 16089);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1366, 5, 23, 16089);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1367, 5, 23, 16089);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1368, 4, 23, 16090);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1369, 4, 23, 16090);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1370, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1371, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1372, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1373, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1374, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1375, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1376, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1377, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1378, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1379, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1380, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1381, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1382, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1383, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1384, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1385, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1386, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1387, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1388, 2, 46, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1389, 273, 46, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1390, 20, 46, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1391, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1392, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1393, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1394, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1395, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1396, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1397, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1398, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1399, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1400, 2, 68, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1401, 273, 68, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1402, 20, 68, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1403, 2, 68, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1404, 273, 68, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1405, 20, 68, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1406, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1407, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1408, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1409, 2, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1410, 273, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1411, 20, 23, 16091);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1412, 5, 23, 16092);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1413, 5, 23, 16092);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1414, 5, 23, 16092);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1415, 2, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1416, 273, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1417, 20, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1418, 2, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1419, 273, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1420, 20, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1421, 2, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1422, 273, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1423, 20, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1424, 2, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1425, 273, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1426, 20, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1427, 2, 4, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1428, 273, 4, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1429, 20, 4, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1430, 2, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1431, 273, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1432, 20, 68, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1433, 2, 23, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1434, 273, 23, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1435, 20, 23, 16093);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1436, 4,100, 16094);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1437, 4, 27, 16094);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1438, 4, 23, 16094);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1439, 4, 23, 16094);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1440, 4, 10, 16094);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1441, 5, 23, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1442, 5, 46, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1443, 5, 50, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1444, 5, 23, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1445, 5, 24, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1446, 5, 23, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1447, 5, 50, 16095);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1448, 2, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1449, 273, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1450, 20, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1451, 2, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1452, 273, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1453, 20, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1454, 2, 21, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1455, 273, 21, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1456, 20, 21, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1457, 2, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1458, 273, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1459, 20, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1460, 2, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1461, 273, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1462, 20, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1463, 2, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1464, 273, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1465, 20, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1466, 2, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1467, 273, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1468, 20, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1469, 2, 21, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1470, 273, 21, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1471, 20, 21, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1472, 2, 24, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1473, 273, 24, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1474, 20, 24, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1475, 2, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1476, 273, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1477, 20, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1478, 2, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1479, 273, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1480, 20, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1481, 2, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1482, 273, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1483, 20, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1484, 2, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1485, 273, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1486, 20, 68, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1487, 2, 46, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1488, 273, 46, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1489, 20, 46, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1490, 2, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1491, 273, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1492, 20, 31, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1493, 2, 80, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1494, 273, 80, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1495, 20, 80, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1496, 2, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1497, 273, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1498, 20, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1499, 2, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1500, 273, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1501, 20, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1502, 2, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1503, 273, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1504, 20, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1505, 2, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1506, 273, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1507, 20, 23, 16096);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1508,100, 7, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1509,100, 24, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1510,100, 7, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1511,100, 37, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1512,100, 12, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1513,100, 4, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1514,100, 4, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1515,100, 4, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1516,100, 4, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1517,100, 4, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1518,100, 4, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1519,100, 22, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1520,100, 61, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1521,100, 22, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1522,100, 61, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1523,100, 19, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1524,100, 19, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1525,100, 13, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1526,100, 18, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1527,100, 32, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1528,100, 61, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1529,100, 78, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1530,100, 7, 17400);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1531,100, 17, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1532,100, 32, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1533,100, 32, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1534,100, 23, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1535,100, 23, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1536,100, 23, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1537,100, 38, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1538,100, 38, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1539,100, 32, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1540,100, 33, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1541,100, 24, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1542,100, 24, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1543,100, 24, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1544,100, 24, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1545,100, 11, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1546,100, 4, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1547,100, 11, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1548,100, 4, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1549,100, 4, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1550,100, 22, 17401);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1551,100, 19, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1552,100, 22, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1553,100, 19, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1554,100, 33, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1555,100, 17, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1556,100, 23, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1557,100, 23, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1558,100, 23, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1559,100, 51, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1560,100, 46, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1561,100, 7, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1562,100, 24, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1563,100, 31, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1564,100, 24, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1565,100, 24, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1566,100, 4, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1567,100, 11, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1568,100, 11, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1569,100, 50, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1570,100, 22, 17402);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1571,100, 22, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1572,100, 22, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1573,100, 50, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1574,100, 22, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1575,100, 50, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1576,100, 50, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1577,100, 50, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1578,100, 51, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1579,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1580,100, 23, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1581,100, 18, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1582,100, 19, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1583,100, 32, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1584,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1585,100, 23, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1586,100, 23, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1587,100, 78, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1588,100, 23, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1589,100, 23, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1590,100, 4, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1591,100, 4, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1592,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1593,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1594,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1595, 49, 4, 17406);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1596, 9, 4, 17406);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1597, 1296, 13, 17406);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1598, 24, 13, 17406);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1599, 1296, 46, 17406);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1600, 24, 46, 17406);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1601,100, 63, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1602,100, 22, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1603,100, 19, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1604,100, 7, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1605,100, 22, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1606,100, 22, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1607,100, 47, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1608,100, 24, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1609,100, 19, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1610,100, 23, 17407);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1611,100, 50, 17408);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1612,100, 7, 17408);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1613,100, 7, 17408);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1614,100, 7, 17408);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1615,100, 19, 17408);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1616,100, 48, 17408);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1617, 1, 81, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1618, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1619, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1620, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1621, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1622, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1623, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1624, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1625, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1626, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1627, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1628, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1629, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1630, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1631, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1632, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1633, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1634, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1635, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1636, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1637, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1638, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1639, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1640, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1641, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1642, 118, 49, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1643, 127, 49, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1644, 17, 49, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1645, 18, 49, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1646, 118, 75, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1647, 127, 75, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1648, 17, 75, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1649, 18, 75, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1650, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1651, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1652, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1653, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1654, 118, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1655, 127, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1656, 17, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1657, 18, 23, 17409);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1658,100, 7, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1659,100, 7, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1660,100, 17, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1661,100, 19, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1662,100, 7, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1663,100, 63, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1664,100, 14, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1665,100, 7, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1666,100, 7, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1667,100, 57, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1668,100, 63, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1669,100, 21, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1670,100, 21, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1671,100, 23, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1672,100, 24, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1673,100, 24, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1674,100, 31, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1675,100, 31, 17410);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1676,100, 7, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1677,100, 7, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1678,100, 7, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1679,100, 82, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1680,100, 38, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1681,100, 12, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1682,100, 24, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1683,100, 31, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1684,100, 23, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1685,100, 13, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1686,100, 10, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1687,100, 4, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1688,100, 4, 17411);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1689, 118, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1690, 127, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1691, 17, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1692, 18, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1693, 118, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1694, 127, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1695, 17, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1696, 18, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1697, 118, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1698, 127, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1699, 17, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1700, 18, 23, 17412);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1701,100, 83, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1702,100, 83, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1703,100, 84, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1704,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1705,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1706,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1707,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1708,100, 36, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1709,100, 19, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1710,100, 19, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1711,100, 32, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1712,100, 32, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1713,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1714,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1715,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1716,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1717,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1718,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1719,100, 24, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1720,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1721,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1722,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1723,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1724,100, 63, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1725,100, 23, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1726,100, 23, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1727,100, 23, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1728,100, 85, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1729,100, 58, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1730,100, 4, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1731,100, 4, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1732,100, 4, 17413);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1733,100, 36, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1734,100, 36, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1735,100, 4, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1736,100, 4, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1737,100, 4, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1738,100, 7, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1739,100, 19, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1740,100, 17, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1741,100, 17, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1742,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1743,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1744,100, 75, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1745,100, 23, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1746,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1747,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1748,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1749,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1750,100, 7, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1751,100, 23, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1752,100, 86, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1753,100, 7, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1754,100, 24, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1755,100, 24, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1756,100, 24, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1757,100, 31, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1758,100, 24, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1759,100, 63, 17414);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1760, 118, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1761, 127, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1762, 17, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1763, 18, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1764, 118, 36, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1765, 127, 36, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1766, 17, 36, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1767, 18, 36, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1768, 118, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1769, 127, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1770, 17, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1771, 18, 23, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1772, 49, 32, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1773, 9, 32, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1774, 49, 32, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1775, 9, 32, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1776, 1, 38, 17415);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1777,100, 7, 17416);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1778,100, 7, 17416);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1779,100, 7, 17416);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1780,100, 50, 17416);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1781,100, 57, 17416);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1782,100, 20, 17416);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1783,100, 7, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1784,100, 21, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1785,100, 7, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1786,100, 14, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1787,100, 87, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1788,100, 22, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1789,100, 87, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1790,100, 82, 17417);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1791, 61, 76, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1792, 77, 76, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1793, 14, 76, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1794, 15, 76, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1795, 118, 24, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1796, 127, 24, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1797, 17, 24, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1798, 18, 24, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1799, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1800, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1801, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1802, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1803, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1804, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1805, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1806, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1807, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1808, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1809, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1810, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1811, 118, 40, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1812, 127, 40, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1813, 17, 40, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1814, 18, 40, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1815, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1816, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1817, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1818, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1819, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1820, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1821, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1822, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1823, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1824, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1825, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1826, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1827, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1828, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1829, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1830, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1831, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1832, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1833, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1834, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1835, 118, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1836, 127, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1837, 17, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1838, 18, 23, 17418);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1839,100, 22, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1840,100, 7, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1841,100, 17, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1842,100, 59, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1843,100, 7, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1844,100, 7, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1845,100, 7, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1846,100, 36, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1847,100, 32, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1848,100, 23, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1849,100, 24, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1850,100, 86, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1851,100, 21, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1852,100, 4, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1853,100, 4, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1854,100, 4, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1855,100, 88, 17419);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1856, 1467, 51, 17420);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1857, 25, 51, 17420);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1858,100, 17, 17421);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1859,100, 7, 17421);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1860,100, 7, 17421);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1861,100, 48, 17421);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1862, 118, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1863, 127, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1864, 17, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1865, 18, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1866, 118, 59, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1867, 127, 59, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1868, 17, 59, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1869, 18, 59, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1870, 118, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1871, 127, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1872, 17, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1873, 18, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1874, 118, 19, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1875, 127, 19, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1876, 17, 19, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1877, 18, 19, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1878, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1879, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1880, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1881, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1882, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1883, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1884, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1885, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1886, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1887, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1888, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1889, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1890, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1891, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1892, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1893, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1894, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1895, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1896, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1897, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1898, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1899, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1900, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1901, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1902, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1903, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1904, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1905, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1906, 118, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1907, 127, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1908, 17, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1909, 18, 23, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1910, 118, 74, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1911, 127, 74, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1912, 17, 74, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1913, 18, 74, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1914, 61, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1915, 77, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1916, 14, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1917, 15, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1918, 61, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1919, 77, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1920, 14, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1921, 15, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1922, 61, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1923, 77, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1924, 14, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1925, 15, 7, 17422);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1926,100, 7, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1927,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1928,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1929,100, 36, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1930,100, 63, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1931,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1932,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1933,100, 63, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1934,100, 23, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1935,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1936,100, 73, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1937,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1938,100, 19, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1939,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1940,100, 22, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1941,100, 54, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1942,100, 89, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1943,100, 7, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1944,100, 82, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1945,100, 90, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1946,100, 24, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1947,100, 31, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1948,100, 24, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1949,100, 23, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1950,100, 20, 17423);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1951,100, 84, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1952,100, 22, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1953,100, 22, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1954,100, 22, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1955,100, 49, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1956,100, 7, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1957,100, 22, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1958,100, 51, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1959,100, 32, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1960,100, 76, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1961,100, 24, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1962,100, 24, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1963,100, 28, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1964,100, 23, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1965,100, 23, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1966,100, 23, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1967,100, 23, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1968,100, 23, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1969,100, 88, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1970,100, 19, 17424);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1971, 1296, 22, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1972, 24, 22, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1973, 118, 89, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1974, 127, 89, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1975, 17, 89, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1976, 18, 89, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1977, 118, 63, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1978, 127, 63, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1979, 17, 63, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1980, 18, 63, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1981, 118, 36, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1982, 127, 36, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1983, 17, 36, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1984, 18, 36, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1985, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1986, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1987, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1988, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1989, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1990, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1991, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1992, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1993, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1994, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1995, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1996, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1997, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1998, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (1999, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2000, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2001, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2002, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2003, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2004, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2005, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2006, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2007, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2008, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2009, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2010, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2011, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2012, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2013, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2014, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2015, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2016, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2017, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2018, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2019, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2020, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2021, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2022, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2023, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2024, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2025, 118, 91, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2026, 127, 91, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2027, 17, 91, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2028, 18, 91, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2029, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2030, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2031, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2032, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2033, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2034, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2035, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2036, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2037, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2038, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2039, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2040, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2041, 118, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2042, 127, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2043, 17, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2044, 18, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2045, 1, 23, 17425);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2046,100, 19, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2047,100, 22, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2048,100, 92, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2049,100, 18, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2050,100, 63, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2051,100, 91, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2052,100, 20, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2053,100, 18, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2054,100, 93, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2055,100, 13, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2056,100, 18, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2057,100, 7, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2058,100, 21, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2059,100, 24, 17426);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2060, 1567, 21, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2061, 26, 21, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2062, 1567, 21, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2063, 26, 21, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2064, 1567, 60, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2065, 26, 60, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2066, 1567, 60, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2067, 26, 60, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2068, 1567, 60, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2069, 26, 60, 17427);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2070,100, 63, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2071,100, 42, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2072,100, 30, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2073,100, 22, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2074,100, 18, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2075,100, 17, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2076,100, 51, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2077,100, 7, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2078,100, 7, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2079,100, 7, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2080,100, 7, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2081,100, 7, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2082,100, 7, 17428);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2083, 1585, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2084, 27, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2085, 1585, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2086, 27, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2087, 1585, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2088, 27, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2089, 1585, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2090, 27, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2091, 1585, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2092, 27, 60, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2093, 61, 76, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2094, 77, 76, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2095, 14, 76, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2096, 15, 76, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2097, 61, 68, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2098, 77, 68, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2099, 14, 68, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2100, 15, 68, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2101, 61, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2102, 77, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2103, 14, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2104, 15, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2105, 61, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2106, 77, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2107, 14, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2108, 15, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2109, 61, 94, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2110, 77, 94, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2111, 14, 94, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2112, 15, 94, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2113, 118, 16, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2114, 127, 16, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2115, 17, 16, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2116, 18, 16, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2117, 118, 92, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2118, 127, 92, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2119, 17, 92, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2120, 18, 92, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2121, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2122, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2123, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2124, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2125, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2126, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2127, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2128, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2129, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2130, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2131, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2132, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2133, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2134, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2135, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2136, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2137, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2138, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2139, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2140, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2141, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2142, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2143, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2144, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2145, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2146, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2147, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2148, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2149, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2150, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2151, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2152, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2153, 118, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2154, 127, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2155, 17, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2156, 18, 23, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2157, 118, 12, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2158, 127, 12, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2159, 17, 12, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2160, 18, 12, 17429);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2161,100, 36, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2162,100, 36, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2163,100, 63, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2164,100, 84, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2165,100, 38, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2166,100, 7, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2167,100, 7, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2168,100, 7, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2169,100, 24, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2170,100, 95, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2171,100, 24, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2172,100, 24, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2173,100, 24, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2174,100, 24, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2175,100, 24, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2176,100, 21, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2177,100, 21, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2178,100, 21, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2179,100, 18, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2180,100, 75, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2181,100, 13, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2182,100, 96, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2183,100, 23, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2184,100, 48, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2185,100, 10, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2186,100, 23, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2187,100, 16, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2188,100, 16, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2189,100, 36, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2190,100, 63, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2191,100, 23, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2192,100, 14, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2193,100, 97, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2194,100, 4, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2195,100, 4, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2196,100, 4, 17430);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2197, 1567, 7, 17431);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2198, 26, 7, 17431);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2199, 1467, 98, 17431);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2200, 25, 98, 17431);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2201, 1467, 18, 17431);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2202, 25, 18, 17431);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2203,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2204,100, 46, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2205,100, 84, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2206,100, 59, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2207,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2208,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2209,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2210,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2211,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2212,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2213,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2214,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2215,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2216,100, 7, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2217,100, 63, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2218,100, 93, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2219,100, 96, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2220,100, 96, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2221,100, 48, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2222,100, 96, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2223,100, 48, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2224,100, 91, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2225,100, 4, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2226,100, 81, 17432);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2227, 1, 81, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2228, 1, 38, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2229, 61, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2230, 77, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2231, 14, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2232, 15, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2233, 61, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2234, 77, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2235, 14, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2236, 15, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2237, 61, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2238, 77, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2239, 14, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2240, 15, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2241, 61, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2242, 77, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2243, 14, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2244, 15, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2245, 61, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2246, 77, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2247, 14, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2248, 15, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2249, 61, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2250, 77, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2251, 14, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2252, 15, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2253, 61, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2254, 77, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2255, 14, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2256, 15, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2257, 61, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2258, 77, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2259, 14, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2260, 15, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2261, 1585, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2262, 27, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2263, 1585, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2264, 27, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2265, 1585, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2266, 27, 96, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2267, 1585, 60, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2268, 27, 60, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2269, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2270, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2271, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2272, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2273, 118, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2274, 127, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2275, 17, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2276, 18, 100, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2277, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2278, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2279, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2280, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2281, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2282, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2283, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2284, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2285, 118, 36, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2286, 127, 36, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2287, 17, 36, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2288, 18, 36, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2289, 118, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2290, 127, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2291, 17, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2292, 18, 99, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2293, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2294, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2295, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2296, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2297, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2298, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2299, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2300, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2301, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2302, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2303, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2304, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2305, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2306, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2307, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2308, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2309, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2310, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2311, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2312, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2313, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2314, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2315, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2316, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2317, 118, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2318, 127, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2319, 17, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2320, 18, 23, 17433);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2321,100, 89, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2322,100, 36, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2323,100, 36, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2324,100, 36, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2325,100, 36, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2326,100, 63, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2327,100, 36, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2328,100, 63, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2329,100, 63, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2330,100, 63, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2331,100, 63, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2332,100, 28, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2333,100, 7, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2334,100, 7, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2335,100, 17, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2336,100, 38, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2337,100, 23, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2338,100, 14, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2339,100, 23, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2340,100, 23, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2341,100, 24, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2342,100, 4, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2343,100, 12, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2344,100, 4, 17434);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2345, 1567, 98, 17435);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2346, 26, 98, 17435);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2347,100, 63, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2348,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2349,100, 63, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2350,100, 63, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2351,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2352,100, 14, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2353,100, 98, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2354,100, 23, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2355,100, 54, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2356,100, 19, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2357,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2358,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2359,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2360,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2361,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2362,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2363,100, 36, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2364,100, 14, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2365,100, 14, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2366,100, 7, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2367,100, 31, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2368,100, 14, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2369,100, 91, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2370,100, 48, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2371,100, 91, 17436);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2372, 118, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2373, 127, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2374, 17, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2375, 18, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2376, 118, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2377, 127, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2378, 17, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2379, 18, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2380, 118, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2381, 127, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2382, 17, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2383, 18, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2384, 118, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2385, 127, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2386, 17, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2387, 18, 36, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2388, 118, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2389, 127, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2390, 17, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2391, 18, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2392, 118, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2393, 127, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2394, 17, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2395, 18, 63, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2396, 118, 31, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2397, 127, 31, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2398, 17, 31, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2399, 18, 31, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2400, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2401, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2402, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2403, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2404, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2405, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2406, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2407, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2408, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2409, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2410, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2411, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2412, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2413, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2414, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2415, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2416, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2417, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2418, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2419, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2420, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2421, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2422, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2423, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2424, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2425, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2426, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2427, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2428, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2429, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2430, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2431, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2432, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2433, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2434, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2435, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2436, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2437, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2438, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2439, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2440, 118, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2441, 127, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2442, 17, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2443, 18, 23, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2444, 1585, 94, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2445, 27, 94, 17437);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2446,100, 19, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2447,100, 19, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2448,100, 44, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2449,100, 22, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2450,100, 19, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2451,100, 51, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2452,100, 18, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2453,100, 18, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2454,100, 19, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2455,100, 16, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2456,100, 16, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2457,100, 7, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2458,100, 18, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2459,100, 17, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2460,100, 44, 17438);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2461, 233, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2462, 3, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2463, 19, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2464, 233, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2465, 3, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2466, 19, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2467, 233, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2468, 3, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2469, 19, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2470, 233, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2471, 3, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2472, 19, 60, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2473, 50, 23, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2474, 10, 23, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2475, 50, 76, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2476, 10, 76, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2477, 1567, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2478, 26, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2479, 1567, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2480, 26, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2481, 1567, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2482, 26, 19, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2483, 1567, 51, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2484, 26, 51, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2485, 5, 50, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2486, 5, 16, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2487, 5, 50, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2488, 5, 23, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2489, 5, 23, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2490, 5, 101, 17439);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2491,100, 44, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2492,100, 23, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2493,100, 51, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2494,100, 19, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2495,100, 22, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2496,100, 44, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2497,100, 44, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2498,100, 18, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2499,100, 16, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2500,100, 16, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2501,100, 16, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2502,100, 17, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2503,100, 44, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2504,100, 44, 17440);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2505, 1811, 51, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2506, 28, 51, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2507, 1811, 102, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2508, 28, 102, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2509, 1811, 102, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2510, 28, 102, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2511, 1811, 103, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2512, 28, 103, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2513, 1811, 103, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2514, 28, 103, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2515, 1811, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2516, 28, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2517, 1811, 94, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2518, 28, 94, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2519, 1811, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2520, 28, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2521, 1811, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2522, 28, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2523, 1811, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2524, 28, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2525, 1, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2526, 61, 104, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2527, 77, 104, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2528, 14, 104, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2529, 15, 104, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2530, 1585, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2531, 27, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2532, 1585, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2533, 27, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2534, 1585, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2535, 27, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2536, 1585, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2537, 27, 60, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2538, 564, 50, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2539, 23, 50, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2540, 564, 23, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2541, 23, 23, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2542, 564, 23, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2543, 23, 23, 17441);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2544,100, 17, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2545,100, 17, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2546,100, 18, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2547,100, 22, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2548,100, 18, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2549,100, 18, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2550,100, 16, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2551,100, 18, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2552,100, 17, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2553,100, 44, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2554,100, 16, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2555,100, 30, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2556,100, 7, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2557,100, 44, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2558,100, 21, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2559,100, 105, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2560,100, 44, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2561,100, 92, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2562,100, 42, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2563,100, 51, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2564,100, 44, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2565,100, 30, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2566,100, 19, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2567,100, 7, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2568,100, 7, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2569,100, 18, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2570,100, 18, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2571,100, 7, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2572,100, 7, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2573,100, 7, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2574,100, 21, 17442);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2575, 50, 7, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2576, 10, 7, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2577, 1567, 57, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2578, 26, 57, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2579, 1567, 86, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2580, 26, 86, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2581, 1567, 86, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2582, 26, 86, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2583, 1567, 86, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2584, 26, 86, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2585, 1567, 106, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2586, 26, 106, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2587, 5, 23, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2588, 5, 23, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2589, 5, 23, 17443);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2590,100, 44, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2591,100, 30, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2592,100, 18, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2593,100, 16, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2594,100, 18, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2595,100, 30, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2596,100, 73, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2597,100, 44, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2598,100, 16, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2599,100, 16, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2600,100, 44, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2601,100, 44, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2602,100, 18, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2603,100, 51, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2604,100, 67, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2605,100, 105, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2606,100, 44, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2607,100, 42, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2608,100, 16, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2609,100, 16, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2610,100, 16, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2611,100, 17, 17444);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2612, 118, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2613, 127, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2614, 17, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2615, 18, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2616, 118, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2617, 127, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2618, 17, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2619, 18, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2620, 1585, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2621, 27, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2622, 1585, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2623, 27, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2624, 1585, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2625, 27, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2626, 1585, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2627, 27, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2628, 1585, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2629, 27, 60, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2630, 61, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2631, 77, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2632, 14, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2633, 15, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2634, 61, 36, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2635, 77, 36, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2636, 14, 36, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2637, 15, 36, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2638, 61, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2639, 77, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2640, 14, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2641, 15, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2642, 61, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2643, 77, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2644, 14, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2645, 15, 103, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2646, 61, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2647, 77, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2648, 14, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2649, 15, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2650, 61, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2651, 77, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2652, 14, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2653, 15, 96, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2654, 61, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2655, 77, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2656, 14, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2657, 15, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2658, 564, 7, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2659, 23, 7, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2660, 564, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2661, 23, 23, 17445);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2662,100, 16, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2663,100, 107, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2664,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2665,100, 22, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2666,100, 42, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2667,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2668,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2669,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2670,100, 18, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2671,100, 7, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2672,100, 30, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2673,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2674,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2675,100, 77, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2676,100, 30, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2677,100, 105, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2678,100, 30, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2679,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2680,100, 92, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2681,100, 30, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2682,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2683,100, 30, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2684,100, 83, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2685,100, 28, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2686,100, 16, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2687,100, 17, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2688,100, 22, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2689,100, 30, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2690,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2691,100, 23, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2692,100, 17, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2693,100, 105, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2694,100, 22, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2695,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2696,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2697,100, 73, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2698,100, 83, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2699,100, 54, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2700,100, 19, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2701,100, 16, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2702,100, 42, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2703,100, 7, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2704,100, 105, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2705,100, 7, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2706,100, 21, 17446);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2707, 50, 103, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2708, 10, 103, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2709, 50, 103, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2710, 10, 103, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2711, 50, 103, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2712, 10, 103, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2713, 50, 23, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2714, 10, 23, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2715, 50, 31, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2716, 10, 31, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2717, 50, 108, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2718, 10, 108, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2719, 50, 91, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2720, 10, 91, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2721, 50, 60, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2722, 10, 60, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2723, 50, 94, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2724, 10, 94, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2725, 50, 60, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2726, 10, 60, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2727, 50, 94, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2728, 10, 94, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2729, 50, 94, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2730, 10, 94, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2731, 50, 89, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2732, 10, 89, 17447);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2733,100, 18, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2734,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2735,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2736,100, 22, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2737,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2738,100, 18, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2739,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2740,100, 30, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2741,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2742,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2743,100, 19, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2744,100, 60, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2745,100, 60, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2746,100, 60, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2747,100, 60, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2748,100, 60, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2749,100, 60, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2750,100, 69, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2751,100, 69, 17448);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2752,100, 7, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2753,100, 18, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2754,100, 19, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2755,100, 19, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2756,100, 19, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2757,100, 7, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2758,100, 19, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2759,100, 22, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2760,100, 72, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2761,100, 52, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2762,100, 52, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2763,100, 52, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2764,100, 52, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2765,100, 52, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2766,100, 109, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2767,100, 52, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2768, 233, 101, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2769, 3, 101, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2770, 19, 101, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2771, 233, 51, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2772, 3, 51, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2773, 19, 51, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2774, 233, 16, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2775, 3, 16, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2776, 19, 16, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2777, 233, 23, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2778, 3, 23, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2779, 19, 23, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2780, 233, 65, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2781, 3, 65, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2782, 19, 65, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2783, 233, 65, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2784, 3, 65, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2785, 19, 65, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2786, 5, 101, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2787, 5, 19, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2788, 5, 50, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2789, 5, 18, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2790, 5, 18, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2791, 5, 18, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2792, 5, 44, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2793, 5, 19, 17450);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2794,100, 7, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2795,100, 52, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2796,100, 52, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2797,100, 52, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2798,100, 52, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2799,100, 52, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2800,100, 60, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2801,100, 68, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2802,100, 68, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2803,100, 68, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2804,100, 68, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2805,100, 110, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2806,100, 110, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2807,100, 110, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2808,100, 68, 17451);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2809, 61, 68, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2810, 77, 68, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2811, 14, 68, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2812, 15, 68, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2813, 61, 81, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2814, 77, 81, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2815, 14, 81, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2816, 15, 81, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2817, 1585, 50, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2818, 27, 50, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2819, 1811, 50, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2820, 28, 50, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2821, 11, 16, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2822, 51, 16, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2823, 11, 18, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2824, 51, 18, 17452);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2825,100, 48, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2826,100, 48, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2827,100, 48, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2828,100, 68, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2829,100, 68, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2830,100, 68, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2831,100, 68, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2832,100, 68, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2833,100, 68, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2834,100, 23, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2835,100, 23, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2836,100, 23, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2837,100, 23, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2838,100, 23, 17453);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2839, 5, 111, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2840, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2841, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2842, 5, 40, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2843, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2844, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2845, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2846, 5, 101, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2847, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2848, 5, 101, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2849, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2850, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2851, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2852, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2853, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2854, 5, 101, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2855, 5, 27, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2856, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2857, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2858, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2859, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2860, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2861, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2862, 5, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2863, 5, 101, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2864, 563, 7, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2865, 22, 7, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2866, 2076, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2867, 29, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2868, 2076, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2869, 29, 23, 17454);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2870,100, 22, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2871,100, 16, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2872,100, 17, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2873,100, 42, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2874,100, 42, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2875,100, 42, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2876,100, 16, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2877,100, 19, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2878,100, 16, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2879,100, 51, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2880,100, 18, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2881,100, 7, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2882,100, 7, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2883,100, 19, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2884,100, 18, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2885,100, 7, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2886,100, 24, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2887,100, 23, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2888,100, 52, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2889,100, 52, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2890,100, 52, 17455);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2891, 118, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2892, 127, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2893, 17, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2894, 18, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2895, 118, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2896, 127, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2897, 17, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2898, 18, 23, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2899, 2101, 71, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2900, 30, 71, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2901, 2101, 60, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2902, 30, 60, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2903, 11, 45, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2904, 51, 45, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2905, 11, 45, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2906, 51, 45, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2907, 11, 45, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2908, 51, 45, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2909, 11, 46, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2910, 51, 46, 17456);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2911,100, 7, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2912,100, 54, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2913,100, 19, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2914,100, 19, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2915,100, 18, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2916,100, 46, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2917,100, 30, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2918,100, 22, 17457);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2919, 2076, 46, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2920, 29, 46, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2921, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2922, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2923, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2924, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2925, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2926, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2927, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2928, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2929, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2930, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2931, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2932, 5, 23, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2933, 5, 101, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2934, 5, 101, 17458);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2935, 1811, 30, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2936, 28, 30, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2937, 1811, 22, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2938, 28, 22, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2939, 2, 17, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2940, 273, 17, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2941, 20, 17, 17459);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2942,100, 23, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2943,100, 23, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2944,100, 102, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2945,100, 103, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2946,100, 103, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2947,100, 46, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2948,100, 83, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2949,100, 22, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2950,100, 40, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2951,100, 73, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2952,100, 19, 17460);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2953, 11, 19, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2954, 51, 19, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2955, 11, 7, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2956, 51, 7, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2957, 11, 46, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2958, 51, 46, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2959, 11, 23, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2960, 51, 23, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2961, 11, 23, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2962, 51, 23, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2963, 11, 23, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2964, 51, 23, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2965, 1585, 62, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2966, 27, 62, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2967, 1811, 45, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2968, 28, 45, 17461);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2969,100, 45, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2970,100, 45, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2971,100, 22, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2972,100, 110, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2973,100, 102, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2974,100, 19, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2975,100, 22, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2976,100, 92, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2977,100, 22, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2978,100, 7, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2979,100, 19, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2980,100, 44, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2981,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2982,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2983,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2984,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2985,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2986,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2987,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2988,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2989,100, 52, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2990,100, 112, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2991,100, 23, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2992,100, 18, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2993,100, 18, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2994,100, 16, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2995,100, 16, 17462);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2996, 563, 69, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2997, 22, 69, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2998, 563, 23, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (2999, 22, 23, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3000, 563, 23, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3001, 22, 23, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3002, 233, 68, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3003, 3, 68, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3004, 19, 68, 17463);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3005,100, 113, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3006,100, 114, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3007,100, 68, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3008,100, 68, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3009,100, 94, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3010,100, 115, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3011,100, 16, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3012,100, 22, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3013,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3014,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3015,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3016,100, 22, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3017,100, 23, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3018,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3019,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3020,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3021,100, 114, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3022,100, 19, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3023,100, 48, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3024,100, 68, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3025,100, 23, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3026,100, 19, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3027,100, 7, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3028,100, 52, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3029,100, 23, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3030,100, 16, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3031,100, 18, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3032,100, 19, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3033,100, 18, 17464);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3034, 1585, 44, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3035, 27, 44, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3036, 1585, 16, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3037, 27, 16, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3038, 61, 19, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3039, 77, 19, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3040, 14, 19, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3041, 15, 19, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3042, 11, 16, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3043, 51, 16, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3044, 11, 52, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3045, 51, 52, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3046, 11, 52, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3047, 51, 52, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3048, 11, 52, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3049, 51, 52, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3050, 11, 68, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3051, 51, 68, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3052, 11, 68, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3053, 51, 68, 17465);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3054, 563, 23, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3055, 22, 23, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3056, 563, 18, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3057, 22, 18, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3058, 563, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3059, 22, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3060, 563, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3061, 22, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3062, 563, 16, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3063, 22, 16, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3064, 7, 18, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3065, 46, 18, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3066, 7, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3067, 46, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3068, 7, 16, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3069, 46, 16, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3070, 7, 18, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3071, 46, 18, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3072, 7, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3073, 46, 7, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3074, 2076, 17, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3075, 29, 17, 17466);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3076,100, 48, 17467);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3077,100, 16, 17467);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3078,100, 18, 17467);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3079,100, 91, 17467);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3080,100, 91, 17467);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3081,100, 52, 17467);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3082,100, 16, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3083,100, 16, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3084,100, 50, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3085,100, 17, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3086,100, 23, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3087,100, 23, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3088,100, 23, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3089,100, 23, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3090,100, 7, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3091,100, 7, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3092,100, 7, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3093,100, 7, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3094,100, 7, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3095,100, 31, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3096,100, 52, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3097,100, 52, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3098,100, 52, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3099,100, 23, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3100,100, 60, 17468);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3101, 2257, 60, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3102, 31, 60, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3103, 2101, 71, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3104, 30, 71, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3105, 2101, 50, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3106, 30, 50, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3107, 2101, 102, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3108, 30, 102, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3109, 2261, 102, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3110, 32, 102, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3111, 2261, 68, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3112, 32, 68, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3113, 2261, 68, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3114, 32, 68, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3115, 11, 16, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3116, 51, 16, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3117, 11, 91, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3118, 51, 91, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3119, 11, 91, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3120, 51, 91, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3121, 11, 23, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3122, 51, 23, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3123, 11, 23, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3124, 51, 23, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3125, 11, 68, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3126, 51, 68, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3127, 11, 94, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3128, 51, 94, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3129, 11, 4, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3130, 51, 4, 17469);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3131,100, 23, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3132,100, 24, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3133,100, 24, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3134,100, 22, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3135,100, 22, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3136,100, 22, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3137,100, 19, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3138,100, 19, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3139,100, 19, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3140,100, 22, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3141,100, 22, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3142,100, 22, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3143,100, 19, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3144,100, 19, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3145,100, 19, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3146,100, 50, 17470);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3147, 7, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3148, 46, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3149, 7, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3150, 46, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3151, 7, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3152, 46, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3153, 7, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3154, 46, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3155, 7, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3156, 46, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3157, 5, 23, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3158, 5, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3159, 5, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3160, 563, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3161, 22, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3162, 563, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3163, 22, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3164, 563, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3165, 22, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3166, 563, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3167, 22, 68, 17471);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3168,100, 83, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3169,100, 19, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3170,100, 83, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3171,100, 19, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3172,100, 54, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3173,100, 19, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3174,100, 23, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3175,100, 19, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3176,100, 7, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3177,100, 51, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3178,100, 24, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3179,100, 31, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3180,100, 94, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3181,100, 116, 17472);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3182, 1585, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3183, 27, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3184, 1585, 68, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3185, 27, 68, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3186, 11, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3187, 51, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3188, 11, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3189, 51, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3190, 11, 68, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3191, 51, 68, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3192, 11, 68, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3193, 51, 68, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3194, 11, 71, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3195, 51, 71, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3196, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3197, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3198, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3199, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3200, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3201, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3202, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3203, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3204, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3205, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3206, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3207, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3208, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3209, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3210, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3211, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3212, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3213, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3214, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3215, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3216, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3217, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3218, 53, 24, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3219, 12, 24, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3220, 53, 81, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3221, 12, 81, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3222, 53, 31, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3223, 12, 31, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3224, 53, 31, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3225, 12, 31, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3226, 53, 31, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3227, 12, 31, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3228, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3229, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3230, 53, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3231, 12, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3232, 2, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3233, 273, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3234, 20, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3235, 2, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3236, 273, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3237, 20, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3238, 2, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3239, 273, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3240, 20, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3241, 2, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3242, 273, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3243, 20, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3244, 2, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3245, 273, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3246, 20, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3247, 2, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3248, 273, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3249, 20, 23, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3250, 2, 117, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3251, 273, 117, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3252, 20, 117, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3253, 2, 117, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3254, 273, 117, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3255, 20, 117, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3256, 2257, 71, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3257, 31, 71, 17473);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3258,100, 44, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3259,100, 44, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3260,100, 19, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3261,100, 18, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3262,100, 50, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3263,100, 44, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3264,100, 44, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3265,100, 18, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3266,100, 18, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3267,100, 44, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3268,100, 50, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3269,100, 44, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3270,100, 19, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3271,100, 18, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3272,100, 23, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3273,100, 52, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3274,100, 52, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3275,100, 52, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3276,100, 52, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3277,100, 112, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3278,100, 110, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3279,100, 7, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3280,100, 23, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3281,100, 23, 17474);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3282, 7, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3283, 46, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3284, 7, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3285, 46, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3286, 7, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3287, 46, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3288, 7, 46, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3289, 46, 46, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3290, 7, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3291, 46, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3292, 6, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3293, 6, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3294, 6, 23, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3295, 6, 42, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3296, 6, 91, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3297, 563, 68, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3298, 22, 68, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3299, 563, 22, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3300, 22, 22, 17475);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3301,100, 16, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3302,100, 18, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3303,100, 44, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3304,100, 46, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3305,100, 44, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3306,100, 51, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3307,100, 22, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3308,100, 17, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3309,100, 22, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3310,100, 67, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3311,100, 23, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3312,100, 4, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3313,100, 52, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3314,100, 52, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3315,100, 52, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3316,100, 52, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3317,100, 52, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3318,100, 52, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3319,100, 23, 17476);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3320, 11, 23, 17477);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3321, 51, 23, 17477);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3322, 11, 92, 17477);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3323, 51, 92, 17477);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3324,100, 18, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3325,100, 44, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3326,100, 50, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3327,100, 18, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3328,100, 18, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3329,100, 18, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3330,100, 17, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3331,100, 7, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3332,100, 17, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3333,100, 18, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3334,100, 50, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3335,100, 23, 17478);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3336, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3337, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3338, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3339, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3340, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3341, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3342, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3343, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3344, 7, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3345, 46, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3346, 7, 76, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3347, 46, 76, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3348, 7, 76, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3349, 46, 76, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3350, 7, 76, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3351, 46, 76, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3352, 563, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3353, 22, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3354, 563, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3355, 22, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3356, 563, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3357, 22, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3358, 563, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3359, 22, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3360, 563, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3361, 22, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3362, 563, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3363, 22, 68, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3364, 563, 16, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3365, 22, 16, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3366, 563, 73, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3367, 22, 73, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3368,100, 18, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3369,100, 17, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3370,100, 49, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3371,100, 51, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3372,100, 23, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3373,100, 23, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3374,100, 23, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3375,100, 52, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3376,100, 52, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3377,100, 52, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3378,100, 52, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3379,100, 23, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3380,100, 23, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3381,100, 23, 17480);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3382, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3383, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3384, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3385, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3386, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3387, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3388, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3389, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3390, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3391, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3392, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3393, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3394, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3395, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3396, 53, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3397, 12, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3398, 53, 7, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3399, 12, 7, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3400, 53, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3401, 12, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3402, 53, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3403, 12, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3404, 2101, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3405, 30, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3406, 2101, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3407, 30, 71, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3408, 2101, 16, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3409, 30, 16, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3410, 2101, 50, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3411, 30, 50, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3412, 2101, 7, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3413, 30, 7, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3414, 2, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3415, 273, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3416, 20, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3417, 2, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3418, 273, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3419, 20, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3420, 2, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3421, 273, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3422, 20, 23, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3423, 2, 47, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3424, 273, 47, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3425, 20, 47, 17481);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3426,100, 23, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3427,100, 16, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3428,100, 23, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3429,100, 23, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3430,100, 48, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3431,100, 68, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3432,100, 68, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3433,100, 118, 17482);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3434, 563, 91, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3435, 22, 91, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3436, 563, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3437, 22, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3438, 7, 61, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3439, 46, 61, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3440, 7, 118, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3441, 46, 118, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3442, 7, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3443, 46, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3444, 7, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3445, 46, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3446, 7, 46, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3447, 46, 46, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3448, 7, 46, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3449, 46, 46, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3450, 7, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3451, 46, 23, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3452, 6, 16, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3453, 6, 83, 17483);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3454,100, 83, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3455,100, 22, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3456,100, 54, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3457,100, 19, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3458,100, 22, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3459,100, 19, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3460,100, 7, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3461,100, 19, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3462,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3463,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3464,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3465,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3466,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3467,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3468,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3469,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3470,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3471,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3472,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3473,100, 76, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3474,100, 21, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3475,100, 52, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3476,100, 52, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3477,100, 52, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3478,100, 110, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3479,100, 116, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3480,100, 23, 17484);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3481, 1585, 23, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3482, 27, 23, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3483, 1585, 23, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3484, 27, 23, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3485, 11, 19, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3486, 51, 19, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3487, 11, 21, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3488, 51, 21, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3489, 11, 42, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3490, 51, 42, 17485);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3491, 53, 23, 17486);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3492, 12, 23, 17486);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3493, 53, 17, 17486);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3494, 12, 17, 17486);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3495, 53, 19, 17486);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3496, 12, 19, 17486);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3497,100, 50, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3498,100, 16, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3499,100, 50, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3500,100, 44, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3501,100, 44, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3502,100, 44, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3503,100, 18, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3504,100, 16, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3505,100, 67, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3506,100, 42, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3507,100, 17, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3508,100, 7, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3509,100, 44, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3510,100, 109, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3511,100, 23, 17487);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3512, 6, 23, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3513, 6, 10, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3514, 6, 50, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3515, 6, 23, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3516, 6, 23, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3517, 6, 23, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3518, 6, 76, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3519, 6, 23, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3520, 6, 17, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3521, 6, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3522, 7, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3523, 46, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3524, 563, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3525, 22, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3526, 563, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3527, 22, 68, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3528, 563,100, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3529, 22,100, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3530, 563, 22, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3531, 22, 22, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3532, 563, 16, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3533, 22, 16, 17488);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3534,100, 16, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3535,100, 44, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3536,100, 17, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3537,100, 23, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3538,100, 23, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3539,100, 23, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3540,100, 7, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3541,100, 19, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3542,100, 44, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3543,100, 67, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3544,100, 50, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3545,100, 19, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3546,100, 16, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3547,100, 44, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3548,100, 4, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3549,100, 55, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3550,100, 50, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3551,100, 23, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3552,100, 23, 17489);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3553, 53, 68, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3554, 12, 68, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3555, 11, 23, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3556, 51, 23, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3557, 11, 23, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3558, 51, 23, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3559, 11, 115, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3560, 51, 115, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3561, 2, 17, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3562, 273, 17, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3563, 20, 17, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3564, 2, 44, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3565, 273, 44, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3566, 20, 44, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3567, 1585, 19, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3568, 27, 19, 17490);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3569,100, 18, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3570,100, 18, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3571,100, 17, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3572,100, 16, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3573,100, 18, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3574,100, 18, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3575,100, 7, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3576,100, 23, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3577,100, 109, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3578,100, 4, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3579,100, 4, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3580,100, 23, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3581,100, 23, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3582,100, 23, 17491);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3583, 7, 23, 17492);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3584, 46, 23, 17492);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3585, 7, 23, 17492);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3586, 46, 23, 17492);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3587, 6, 18, 17492);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3588, 6, 18, 17492);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3589,100, 16, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3590,100, 7, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3591,100, 7, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3592,100, 19, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3593,100, 28, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3594,100, 119, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3595,100, 119, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3596,100, 119, 17493);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3597, 2, 70, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3598, 273, 70, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3599, 20, 70, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3600, 2, 115, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3601, 273, 115, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3602, 20, 115, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3603, 2, 7, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3604, 273, 7, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3605, 20, 7, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3606, 2, 46, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3607, 273, 46, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3608, 20, 46, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3609, 1585, 51, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3610, 27, 51, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3611, 53, 18, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3612, 12, 18, 17494);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3613,100, 22, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3614,100, 22, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3615,100, 18, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3616,100, 18, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3617,100, 120, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3618,100, 18, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3619,100, 22, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3620,100, 22, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3621,100, 16, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3622,100, 22, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3623,100, 7, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3624,100, 7, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3625,100, 46, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3626,100, 40, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3627,100, 23, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3628,100, 23, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3629,100, 4, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3630,100, 106, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3631,100, 16, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3632,100, 50, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3633,100, 23, 17495);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3634, 6, 7, 17496);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3635, 6, 7, 17496);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3636,100, 18, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3637,100, 19, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3638,100, 19, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3639,100, 19, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3640,100, 19, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3641,100, 105, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3642,100, 54, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3643,100, 23, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3644,100, 23, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3645,100, 23, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3646,100, 31, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3647,100, 23, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3648,100, 23, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3649,100, 24, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3650,100, 23, 17497);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3651, 2, 23, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3652, 273, 23, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3653, 20, 23, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3654, 2, 23, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3655, 273, 23, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3656, 20, 23, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3657, 2, 31, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3658, 273, 31, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3659, 20, 31, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3660, 2, 110, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3661, 273, 110, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3662, 20, 110, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3663, 2, 110, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3664, 273, 110, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3665, 20, 110, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3666, 2, 7, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3667, 273, 7, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3668, 20, 7, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3669, 2, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3670, 273, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3671, 20, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3672, 11, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3673, 51, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3674, 53, 19, 17499);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3675, 12, 19, 17499);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3676, 53, 23, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3677, 12, 23, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3678, 53, 31, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3679, 12, 31, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3680, 53, 121, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3681, 12, 121, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3682, 53, 42, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3683, 12, 42, 17500);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3684,100, 18, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3685,100, 50, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3686,100, 18, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3687,100, 17, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3688,100, 49, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3689,100, 18, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3690,100, 19, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3691,100, 49, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3692,100, 51, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3693,100, 120, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3694,100, 23, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3695,100, 27, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3696,100, 23, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3697,100, 23, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3698,100, 48, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3699,100, 50, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3700,100, 42, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3701,100, 16, 17501);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3702, 563, 17, 17502);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3703, 22, 17, 17502);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3704,100, 17, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3705,100, 46, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3706,100, 42, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3707,100, 19, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3708,100, 50, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3709,100, 23, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3710,100, 23, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3711,100, 23, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3712,100, 23, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3713,100, 48, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3714,100, 21, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3715,100, 4, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3716,100, 19, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3717,100, 42, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3718,100, 18, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3719,100, 44, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3720,100, 23, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3721,100, 109, 17503);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3722, 2, 50, 17504);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3723, 273, 50, 17504);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3724, 20, 50, 17504);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3725, 11, 47, 17504);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3726, 51, 47, 17504);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3727,100, 7, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3728,100, 23, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3729,100, 109, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3730,100, 18, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3731,100, 23, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3732,100, 122, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3733,100, 46, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3734,100, 23, 17505);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3735, 7, 16, 17506);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3736, 46, 16, 17506);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3737,100, 52, 17507);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3738,100, 4, 17507);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3739,100, 23, 17507);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3740,100, 23, 17507);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3741,100, 70, 17507);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3742,100, 109, 17507);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3743, 2, 68, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3744, 273, 68, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3745, 20, 68, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3746, 2, 94, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3747, 273, 94, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3748, 20, 94, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3749, 2, 83, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3750, 273, 83, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3751, 20, 83, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3752, 2, 22, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3753, 273, 22, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3754, 20, 22, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3755, 11, 49, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3756, 51, 49, 17508);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3757,100, 46, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3758,100, 40, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3759,100, 23, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3760,100, 24, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3761,100, 24, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3762,100, 24, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3763,100, 24, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3764,100, 31, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3765,100, 109, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3766,100, 76, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3767,100, 23, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3768,100, 46, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3769,100, 46, 17509);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3770, 233, 19, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3771, 3, 19, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3772, 19, 19, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3773, 7, 23, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3774, 46, 23, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3775, 6, 23, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3776, 6, 76, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3777, 6, 30, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3778, 6, 19, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3779, 6, 46, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3780, 6, 19, 17510);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3781,100, 40, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3782,100, 27, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3783,100, 48, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3784,100, 24, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3785,100, 24, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3786,100, 31, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3787,100, 24, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3788,100, 23, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3789,100, 23, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3790,100, 21, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3791,100, 31, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3792,100, 23, 17511);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3793, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3794, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3795, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3796, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3797, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3798, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3799, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3800, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3801, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3802, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3803, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3804, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3805, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3806, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3807, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3808, 2, 123, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3809, 273, 123, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3810, 20, 123, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3811, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3812, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3813, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3814, 2, 91, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3815, 273, 91, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3816, 20, 91, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3817, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3818, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3819, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3820, 2, 68, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3821, 273, 68, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3822, 20, 68, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3823, 2, 68, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3824, 273, 68, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3825, 20, 68, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3826, 2, 19, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3827, 273, 19, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3828, 20, 19, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3829, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3830, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3831, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3832, 2, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3833, 273, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3834, 20, 23, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3835, 2, 31, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3836, 273, 31, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3837, 20, 31, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3838, 53, 42, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3839, 12, 42, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3840, 53, 46, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3841, 12, 46, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3842, 53, 47, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3843, 12, 47, 17512);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3844,100, 51, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3845,100, 48, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3846,100, 4, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3847,100, 23, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3848,100, 42, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3849,100, 42, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3850,100, 46, 17513);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3851, 7, 46, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3852, 46, 46, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3853, 2783, 17, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3854, 33, 17, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3855, 4, 46, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3856, 34, 23, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3857, 2785, 23, 17514);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3858,100, 27, 17515);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3859,100, 24, 17515);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3860,100, 124, 17515);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3861,100, 23, 17515);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3862,100, 68, 17515);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3863,100, 68, 17515);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3864, 2, 7, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3865, 273, 7, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3866, 20, 7, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3867, 1585, 24, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3868, 27, 24, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3869, 11, 23, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3870, 51, 23, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3871, 11, 4, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3872, 51, 4, 17516);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3873,100, 125, 17517);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3874,100, 125, 17517);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3875,100, 125, 17517);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3876,100, 125, 17517);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3877, 4, 23, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3878, 4, 68, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3879, 4, 68, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3880, 4, 68, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3881, 4, 18, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3882, 4, 46, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3883, 4, 4, 17518);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3884,100, 23, 17519);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3885, 11, 68, 17520);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3886, 51, 68, 17520);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3887, 11, 83, 17520);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3888, 51, 83, 17520);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3889, 11, 7, 17520);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3890, 51, 7, 17520);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3891,100, 40, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3892,100, 24, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3893,100, 24, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3894,100, 24, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3895,100, 23, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3896,100, 23, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3897,100, 83, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3898,100, 46, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3899,100, 46, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3900,100, 46, 17521);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3901, 34, 46, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3902, 2785, 46, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3903, 34, 23, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3904, 2785, 23, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3905, 34, 122, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3906, 2785, 122, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3907, 34, 91, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3908, 2785, 91, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3909, 34, 91, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3910, 2785, 91, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3911, 34, 42, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3912, 2785, 42, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3913, 2783, 17, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3914, 33, 17, 17522);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3915,100, 126, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3916,100, 44, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3917,100, 40, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3918,100, 40, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3919,100, 23, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3920,100, 46, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3921,100, 19, 17523);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3922, 53, 46, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3923, 12, 46, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3924, 11, 127, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3925, 51, 127, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3926, 2, 46, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3927, 273, 46, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3928, 20, 46, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3929, 2, 24, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3930, 273, 24, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3931, 20, 24, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3932, 2, 23, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3933, 273, 23, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3934, 20, 23, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3935, 2, 23, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3936, 273, 23, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3937, 20, 23, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3938, 2, 91, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3939, 273, 91, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3940, 20, 91, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3941, 2, 68, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3942, 273, 68, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3943, 20, 68, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3944, 2, 19, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3945, 273, 19, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3946, 20, 19, 17524);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3947,100, 46, 17525);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3948,100, 42, 17525);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3949,100, 23, 17525);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3950,100, 91, 17525);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3951, 34, 23, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3952, 2785, 23, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3953, 34, 21, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3954, 2785, 21, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3955, 34, 7, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3956, 2785, 7, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3957, 4, 19, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3958, 2783, 21, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3959, 33, 21, 17526);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3960,100, 4, 17527);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3961,100, 23, 17527);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3962,100, 23, 17527);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3963,100, 23, 17527);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3964, 11, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3965, 51, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3966, 2, 48, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3967, 273, 48, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3968, 20, 48, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3969, 2, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3970, 273, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3971, 20, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3972, 2, 21, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3973, 273, 21, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3974, 20, 21, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3975, 2, 50, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3976, 273, 50, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3977, 20, 50, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3978, 2, 19, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3979, 273, 19, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3980, 20, 19, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3981, 53, 42, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3982, 12, 42, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3983, 53, 19, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3984, 12, 19, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3985, 53, 27, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3986, 12, 27, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3987, 53, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3988, 12, 23, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3989, 53, 28, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3990, 12, 28, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3991, 53, 126, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3992, 12, 126, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3993, 53, 128, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3994, 12, 128, 17528);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3995,100, 68, 17529);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3996,100, 68, 17529);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3997, 4, 68, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3998, 4, 68, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (3999, 4, 126, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4000, 4, 126, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4001, 4, 24, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4002, 4, 99, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4003, 34, 49, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4004, 2785, 49, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4005, 34, 19, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4006, 2785, 19, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4007, 34, 4, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4008, 2785, 4, 17530);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4009,100, 27, 17531);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4010,100, 23, 17531);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4011,100, 48, 17531);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4012,100, 109, 17531);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4013, 2, 42, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4014, 273, 42, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4015, 20, 42, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4016, 2, 122, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4017, 273, 122, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4018, 20, 122, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4019, 2, 23, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4020, 273, 23, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4021, 20, 23, 17532);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4022,100, 4, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4023,100, 4, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4024,100, 4, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4025,100, 24, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4026,100, 24, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4027,100, 24, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4028,100, 7, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4029,100, 23, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4030,100, 7, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4031,100, 59, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4032,100, 46, 17533);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4033, 57, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4034, 13, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4035, 34, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4036, 2785, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4037, 34, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4038, 2785, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4039, 34, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4040, 2785, 46, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4041, 34, 126, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4042, 2785, 126, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4043, 34, 31, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4044, 2785, 31, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4045, 34, 24, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4046, 2785, 24, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4047, 34, 23, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4048, 2785, 23, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4049, 34, 23, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4050, 2785, 23, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4051, 34, 91, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4052, 2785, 91, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4053, 34, 23, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4054, 2785, 23, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4055, 34, 45, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4056, 2785, 45, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4057, 34, 19, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4058, 2785, 19, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4059, 2783, 19, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4060, 33, 19, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4061, 6, 7, 17534);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4062,100, 7, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4063,100, 40, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4064,100, 24, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4065,100, 24, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4066,100, 24, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4067,100, 57, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4068,100, 27, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4069,100, 23, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4070,100, 91, 17535);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4071, 2, 24, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4072, 273, 24, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4073, 20, 24, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4074, 2, 91, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4075, 273, 91, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4076, 20, 91, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4077, 2, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4078, 273, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4079, 20, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4080, 2, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4081, 273, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4082, 20, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4083, 2, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4084, 273, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4085, 20, 68, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4086, 2, 46, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4087, 273, 46, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4088, 20, 46, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4089, 2, 46, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4090, 273, 46, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4091, 20, 46, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4092, 2, 91, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4093, 273, 91, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4094, 20, 91, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4095, 2, 115, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4096, 273, 115, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4097, 20, 115, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4098, 2, 50, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4099, 273, 50, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4100, 20, 50, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4101, 2, 21, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4102, 273, 21, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4103, 20, 21, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4104, 2257, 23, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4105, 31, 23, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4106, 1585, 4, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4107, 27, 4, 17536);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4108,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4109,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4110,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4111,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4112,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4113,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4114,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4115,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4116,100, 4, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4117,100, 116, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4118,100, 76, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4119,100, 68, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4120,100, 23, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4121,100, 23, 17537);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4122, 6, 68, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4123, 2783, 68, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4124, 33, 68, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4125, 4, 68, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4126, 4, 83, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4127, 233, 121, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4128, 3, 121, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4129, 19, 121, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4130, 233, 51, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4131, 3, 51, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4132, 19, 51, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4133, 233, 18, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4134, 3, 18, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4135, 19, 18, 17538);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4136,100, 7, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4137,100, 23, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4138,100, 23, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4139,100, 23, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4140,100, 48, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4141,100, 4, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4142,100, 4, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4143,100, 4, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4144,100, 4, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4145,100, 4, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4146,100, 21, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4147,100, 31, 17539);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4148, 53, 27, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4149, 12, 27, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4150, 53, 23, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4151, 12, 23, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4152, 11, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4153, 51, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4154, 11, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4155, 51, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4156, 2, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4157, 273, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4158, 20, 68, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4159, 2, 16, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4160, 273, 16, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4161, 20, 16, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4162, 2, 7, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4163, 273, 7, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4164, 20, 7, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4165, 2, 4, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4166, 273, 4, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4167, 20, 4, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4168, 2, 4, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4169, 273, 4, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4170, 20, 4, 17540);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4171,100, 27, 17541);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4172,100, 27, 17541);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4173,100, 7, 17541);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4174,100, 7, 17541);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4175, 2982, 68, 17542);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4176, 35, 68, 17542);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4177, 2982, 68, 17542);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4178, 35, 68, 17542);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4179,100, 68, 17543);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4180,100, 68, 17543);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4181, 2, 23, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4182, 273, 23, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4183, 20, 23, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4184, 2, 23, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4185, 273, 23, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4186, 20, 23, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4187, 2, 31, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4188, 273, 31, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4189, 20, 31, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4190, 1585, 31, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4191, 27, 31, 17544);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4192,100, 24, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4193,100, 31, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4194,100, 31, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4195,100, 48, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4196,100, 4, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4197,100, 4, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4198,100, 4, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4199,100, 4, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4200,100, 4, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4201,100, 31, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4202,100, 31, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4203,100, 31, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4204,100, 31, 17545);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4205, 233, 68, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4206, 3, 68, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4207, 19, 68, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4208, 233, 42, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4209, 3, 42, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4210, 19, 42, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4211, 233, 19, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4212, 3, 19, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4213, 19, 19, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4214, 233, 31, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4215, 3, 31, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4216, 19, 31, 17546);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4217,100, 23, 17547);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4218,100, 129, 17547);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4219,100, 68, 17547);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4220,100, 68, 17547);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4221,100, 68, 17547);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4222,100, 68, 17547);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4223, 1585, 68, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4224, 27, 68, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4225, 2, 68, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4226, 273, 68, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4227, 20, 68, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4228, 2, 70, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4229, 273, 70, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4230, 20, 70, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4231, 2, 23, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4232, 273, 23, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4233, 20, 23, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4234, 2, 91, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4235, 273, 91, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4236, 20, 91, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4237, 2, 31, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4238, 273, 31, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4239, 20, 31, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4240, 2, 42, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4241, 273, 42, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4242, 20, 42, 17548);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4243,100, 13, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4244,100, 18, 17449);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4245, 6, 23, 17479);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4246, 11, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4247, 51, 19, 17498);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4248,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4249,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4250,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4251,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4252,100, 7, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4253,100, 22, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4254,100, 18, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4255,100, 22, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4256,100, 92, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4257,100, 19, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4258,100, 33, 17403);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4259,100, 78, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4260,100, 24, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4261,100, 24, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4262,100, 23, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4263,100, 130, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4264,100, 4, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4265,100, 39, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4266,100, 22, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4267,100, 49, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4268,100, 30, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4269,100, 50, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4270,100, 7, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4271,100, 24, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4272,100, 7, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4273,100, 7, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4274,100, 7, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4275,100, 13, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4276,100, 10, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4277,100, 131, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4278,100, 88, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4279,100, 132, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4280,100, 4, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4281,100, 4, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4282,100, 4, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4283,100, 4, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4284,100, 22, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4285,100, 62, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4286,100, 50, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4287,100, 32, 17404);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4288,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4289,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4290,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4291,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4292,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4293,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4294,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4295,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4296,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4297,100, 32, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4298,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4299,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4300,100, 32, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4301,100, 97, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4302,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4303,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4304,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4305,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4306,100, 7, 17405);"
INSERT INTO sample_details (ID_sample_details, id_plant, id_bee, sample_id) VALUES (4307,100, 7, 17405);"





















