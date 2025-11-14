BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.17' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.18', ver;
END $$;

DROP VIEW mb_grain_trait_with_meta;

ALTER TABLE mb_grain_trait ALTER COLUMN val_number TYPE numeric;

CREATE VIEW mb_grain_trait_with_meta
AS
SELECT p.*, a.path, b.name,
    d.value_type, d.cardinality_min, d.cardinality_max, d.value_constraint, d.localizable, d.versionable
    FROM mb_grain_trait AS p
LEFT JOIN mb_grain_with_path AS a
    ON a.id = p.grain_id
LEFT JOIN mb_grain_base AS b
    ON b.id = p.propdef_id
LEFT JOIN mb_propdef AS d
    ON d.base_id = p.propdef_id;

DROP VIEW mb_grain_acl_effective;

CREATE MATERIALIZED VIEW mb_grain_acl_effective
AS
WITH RECURSIVE cte_ancestor(id, parent_id, distance, start) AS (
    SELECT g.id, g.parent_id, 0, g.id as start
        FROM mb_grain_base AS g
    UNION ALL
    SELECT b.id, b.parent_id, a.distance + 1, a.start
        FROM mb_grain_base AS b
        JOIN cte_ancestor AS a ON a.parent_id = b.id
)
SELECT * FROM (
SELECT c.start AS grain_id, p.role_id, p.permission_mask, p.restriction_mask, p.inherit, c.distance AS acl_type, c.id AS acl_source
    FROM mb_grain_acl AS p
LEFT JOIN cte_ancestor AS c 
ON c.id = p.grain_id
    WHERE p.grain_id <> '00000000-0000-1000-a000-000000000000'
    AND (p.inherit OR p.grain_id = c.start)
    ORDER BY start, distance
)
UNION ALL
SELECT d.grain_id, d.role_id, d.permission_mask, d.restriction_mask, d.inherit, 0xFFFFFFF0 AS acl_type, d.grain_id AS acl_source
FROM mb_grain_acl AS d WHERE grain_id = '00000000-0000-1000-a000-000000000000'
UNION ALL
SELECT NULL AS grain_id, NULL AS role_id, 0 AS pemission_mask, -1 AS restriction_mask, TRUE AS inherit, 0xFFFFFFF1 AS acl_type, NULL AS acl_source;
   
CREATE INDEX mb_idx_grain_acl_effective_type
ON mb_grain_acl_effective(acl_type);

CREATE INDEX mb_idx_grain_acl_effective_source
ON mb_grain_acl_effective(acl_source);

CREATE OR REPLACE FUNCTION mb_acl_update()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_acl_update$
BEGIN
    REFRESH MATERIALIZED VIEW mb_grain_acl_effective;
	IF TG_OP = 'DELETE' THEN
        IF NOT EXISTS(SELECT 1 FROM mb_grain_control WHERE grain_id = old.grain_id AND (0x1 & flag) > 0) THEN
            UPDATE mb_grain_base SET mtime = current_timestamp WHERE id = old.grain_id;
        END IF;
		RETURN old;
	ELSIF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NOT EXISTS(SELECT 1 FROM mb_grain_control WHERE grain_id = new.grain_id AND (0x1 & flag) > 0) THEN
            UPDATE mb_grain_base SET mtime = current_timestamp WHERE id = new.grain_id;
        END IF;
		RETURN new;
	END IF;
END;
$mb_acl_update$;

DROP TRIGGER IF EXISTS mb_tg_grain_acl_update_mtime ON mb_grain_acl;
DROP TRIGGER IF EXISTS mb_tg_grain_acl_delete_mtime ON mb_grain_acl;

CREATE TRIGGER mb_tg_grain_acl_update
  AFTER INSERT OR UPDATE
  ON mb_grain_acl
  FOR EACH ROW
EXECUTE PROCEDURE mb_acl_update();

CREATE TRIGGER mb_tg_grain_acl_delete
  AFTER DELETE
  ON mb_grain_acl
  FOR EACH ROW
EXECUTE PROCEDURE mb_acl_update();
    
UPDATE mb_schema_opts SET val = '0.1.18' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;