BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.19' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.20', ver;
END $$;

UPDATE mb_grain_base SET custom_flag = 0x1000 WHERE id IN('00000000-0000-1000-a000-000000000000', '00000000-0000-1000-a000-00000000000f');

CREATE OR REPLACE FUNCTION mb_restrict_grain_base_delete()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_restrict_grain_base_delete$
BEGIN
	IF (0x1000 & old.custom_flag) > 0 THEN
		RAISE EXCEPTION 'Protected system Grains cannot be deleted';
	END IF;
	RETURN old;
END;
$mb_restrict_grain_base_delete$;

CREATE TRIGGER mb_tg_grain_base_delete_restrict
  BEFORE DELETE
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_restrict_grain_base_delete();

CREATE OR REPLACE FUNCTION mb_restrict_typedef_mixin()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_restrict_typedef_mixin$
BEGIN
	IF new.derived_typedef_id IN('00000000-0000-1000-a000-000000000009', '00000000-0000-1000-a000-00000000000a', '00000000-0000-1000-a000-00000000000e', '00000000-0000-1000-a000-000000000004', '00000000-0000-1000-a000-000000000005') THEN
		RAISE EXCEPTION 'This TypeDef is not allowed as derived_typedef_id';
	END IF;
	RETURN new;
END;
$mb_restrict_typedef_mixin$;    

CREATE TRIGGER mb_tg_typedef_mixin_restrict
  BEFORE INSERT OR UPDATE
  ON mb_typedef_mixin
  FOR EACH ROW
EXECUTE PROCEDURE mb_restrict_typedef_mixin();

UPDATE mb_schema_opts SET val = '0.1.20' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;