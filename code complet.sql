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



























