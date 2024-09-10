BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.9' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.10', ver;
END $$;

CREATE VIEW mb_typedef_mixin_descendant
AS
WITH RECURSIVE cte_derived(derived_typedef_id, base_typedef_id, distance, start) AS (
    SELECT derived_typedef_id, base_typedef_id, 0, base_typedef_id AS start
        FROM mb_typedef_mixin
    UNION ALL
    SELECT b.derived_typedef_id, b.base_typedef_id, a.distance + 1, a.start
        FROM mb_typedef_mixin AS b
        JOIN cte_derived AS a ON a.derived_typedef_id = b.base_typedef_id
)
SELECT * FROM cte_derived
ORDER by start, distance;

INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Superuser@marbas'), '00000000-0000-1000-a000-000000000001', false, -1, 0);

UPDATE mb_schema_opts SET val = '0.1.10' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;