BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.7' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.8', ver;
END $$;

ALTER TABLE mb_grain_base
    ADD COLUMN xattrs varchar(510);

CREATE INDEX mb_idx_grain_base_xattrs
  ON mb_grain_base
  (xattrs);

DROP VIEW mb_grain_trait_with_meta;
DROP VIEW mb_propdef_as_grain_with_path;
DROP VIEW mb_typedef_as_grain_with_path;
DROP VIEW mb_grain_with_path;

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
SELECT t.impl, g.* FROM mb_typedef AS t
LEFT JOIN mb_grain_with_path AS g
    ON g.id = t.base_id;

/* mb_propdef_as_grain_with_path */
CREATE VIEW mb_propdef_as_grain_with_path
AS
SELECT p.*, g.* FROM mb_propdef AS p
LEFT JOIN mb_grain_with_path AS g
    ON g.id = p.base_id;

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
    
UPDATE mb_schema_opts SET val = '0.1.8' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;