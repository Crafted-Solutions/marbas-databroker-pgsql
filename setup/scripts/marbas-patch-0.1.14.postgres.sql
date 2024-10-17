BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.13' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.14', ver;
END $$;

CREATE OR REPLACE TRIGGER mb_tg_grain_acl_update_mtime
  AFTER INSERT OR UPDATE
  ON mb_grain_acl
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_ref_mtime();

CREATE OR REPLACE TRIGGER mb_tg_grain_acl_delete_mtime
  AFTER DELETE
  ON mb_grain_acl
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_ref_mtime();


UPDATE mb_schema_opts SET val = '0.1.14' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;