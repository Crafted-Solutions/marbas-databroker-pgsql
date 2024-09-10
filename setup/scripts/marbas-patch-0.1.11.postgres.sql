BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.10' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.11', ver;
END $$;

DROP VIEW mb_grain_trait_with_meta;
DROP VIEW mb_propdef_as_grain_with_path;
DROP VIEW mb_typedef_as_grain_with_path;
DROP VIEW mb_grain_with_path;

ALTER TABLE mb_grain_trait ALTER COLUMN val_memo TYPE text;
ALTER TABLE mb_grain_base ADD COLUMN custom_flag integer DEFAULT 0;
ALTER TABLE mb_propdef
  ADD COLUMN constraint_params varchar(1024);

CREATE INDEX mb_idx_grain_base_flag
  ON mb_grain_base
  (custom_flag);
  
CREATE VIEW mb_grain_with_path
AS
WITH RECURSIVE descendant(id, path, id_path) AS (
    SELECT id, cast(name as varchar), cast(id AS text) AS id_path
        FROM mb_grain_base
        WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, r.path  || '/' || c.name, r.id_path || '/' || cast(c.id AS text) AS id_path
        FROM mb_grain_base AS c
        INNER JOIN descendant AS r ON (c.parent_id = r.id)
)
SELECT a.*, b.name AS type_name, b.xattrs AS type_xattrs, t.impl AS type_impl, descendant.path, descendant.id_path
    FROM mb_grain_base AS a
JOIN descendant
    ON a.id = descendant.id
LEFT JOIN mb_grain_base b
    ON b.id = a.typedef_id
LEFT JOIN mb_typedef AS t
    ON t.base_id = a.typedef_id;

CREATE VIEW mb_typedef_as_grain_with_path
AS
SELECT t.impl, d.id AS defaults_id, g.* FROM mb_typedef AS t
LEFT JOIN mb_grain_with_path AS g
    ON g.id = t.base_id
LEFT JOIN mb_grain_base AS d
    ON d.parent_id = t.base_id AND d.typedef_id = t.base_id;
    
CREATE VIEW mb_propdef_as_grain_with_path
AS
SELECT p.*, g.*, b.name AS parent_name, b.sort_key AS parent_sort_key
FROM mb_propdef AS p
LEFT JOIN mb_grain_with_path AS g
ON g.id = p.base_id
LEFT JOIN mb_grain_base AS b
ON b.id = g.parent_id;

CREATE VIEW mb_grain_trait_with_meta
AS
SELECT p.*, a.path, b.name, d.value_type, d.cardinality_min, d.cardinality_max, d.value_constraint
    FROM mb_grain_trait AS p
LEFT JOIN mb_grain_with_path AS a
    ON a.id = p.grain_id
LEFT JOIN mb_grain_base AS b
    ON b.id = p.propdef_id
LEFT JOIN mb_propdef AS d
    ON d.base_id = p.propdef_id;

INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, ctime, mtime, custom_flag) VALUES ('3beed4d5-593e-44ad-a5fe-bb77b61580fb', '00000000-0000-1000-a000-000000000009', '00000000-0000-1000-a000-000000000005', 'Property Description', '2024-07-17 17:50:46', '2024-07-17 17:57:17', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, ctime, mtime) VALUES ('00000000-0000-1000-a000-00000000000d', '3beed4d5-593e-44ad-a5fe-bb77b61580fb', '00000000-0000-1000-a000-000000000009', 'Comment', '2024-01-06 19:19:31', '2024-07-17 17:54:08');
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, value_constraint) VALUES ('00000000-0000-1000-a000-00000000000d', 'text', 1, 1, NULL);

UPDATE mb_schema_opts SET val = '0.1.11' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;