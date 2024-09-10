BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.8' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.9', ver;
END $$;

DROP VIEW mb_typedef_as_grain_with_path;

CREATE VIEW mb_typedef_as_grain_with_path
AS
SELECT t.impl, d.id AS defaults_id, g.* FROM mb_typedef AS t
LEFT JOIN mb_grain_with_path AS g
    ON g.id = t.base_id
LEFT JOIN mb_grain_base AS d
    ON d.parent_id = t.base_id AND d.typedef_id = t.base_id;

CREATE OR REPLACE FUNCTION mb_ignore_typedef_defaults_duplicates()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_ignore_typedef_defaults_duplicates$
BEGIN
	IF new.parent_id = new.typedef_id AND EXISTS (SELECT 1 FROM mb_grain_base WHERE parent_id = new.parent_id AND typedef_id = new.typedef_id) THEN
		RETURN null;
	END IF;
	RETURN new;
END;
$mb_ignore_typedef_defaults_duplicates$;

CREATE TRIGGER mb_tg_grain_typedef_defaults_check
  BEFORE INSERT
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_ignore_typedef_defaults_duplicates();

CREATE OR REPLACE FUNCTION mb_set_typedef_defaults_name()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_set_typedef_defaults_name$
BEGIN
	IF new.parent_id = new.typedef_id THEN
		new.name = '__defaults__';
	END IF;
	RETURN new;
END;
$mb_set_typedef_defaults_name$;

CREATE TRIGGER mb_tg_grain_typedef_defaults_name
  BEFORE INSERT OR UPDATE
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_typedef_defaults_name();

UPDATE mb_grain_acl SET permission_mask = 0x001 | 0x002 | 0x004 | 0x008 | 0x010 | 0x020 WHERE role_id = (SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas') AND grain_id = '00000000-0000-1000-a000-000000000000';
UPDATE mb_grain_acl SET permission_mask = 0x001 | 0x020 WHERE role_id = (SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas') AND grain_id = '00000000-0000-1000-a000-000000000000';

UPDATE mb_schema_opts SET val = '0.1.9' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;