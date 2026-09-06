BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.20' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.21', ver;
END $$;

CREATE OR REPLACE FUNCTION mb_delete_typedef_defaults()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_delete_typedef_defaults$
BEGIN
    UPDATE mb_grain_base SET typedef_id = '00000000-0000-1000-a000-000000000004' WHERE (0x1000 & custom_flag) = 0 AND parent_id = old.id AND typedef_id = old.id;
	RETURN old;
END;
$mb_delete_typedef_defaults$;

CREATE TRIGGER mb_tg_grain_typedef_delete
  BEFORE DELETE
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_delete_typedef_defaults();

DROP VIEW IF EXISTS mb_grain_trait_with_meta;

CREATE VIEW mb_grain_trait_with_meta
AS
SELECT p.*, d.name, d.path AS propdef_path,
    d.value_type, d.cardinality_min, d.cardinality_max, d.value_constraint, d.localizable, d.versionable
    FROM mb_grain_trait AS p
LEFT JOIN mb_propdef_as_grain_with_path AS d
    ON d.base_id = p.propdef_id;
    
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000014', '00000000-0000-1000-a000-000000000002', '00000000-0000-1000-a000-000000000005', '$Config$', 0x1000);
UPDATE mb_grain_base SET ctime = '2024-01-05T00:00:10Z', mtime = '2024-01-05T00:00:11Z' WHERE id = '00000000-0000-1000-a000-000000000014';

INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000014', true, 0x001, 0x002 | 0x004 | 0x008 | 0x010 | 0x020 | 0x100 | 0x200 | 0x400);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000014', true, 0x001, 0x002 | 0x004 | 0x008 | 0x010 | 0x020 | 0x100 | 0x200 | 0x400);

UPDATE mb_schema_opts SET val = '0.1.21' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;