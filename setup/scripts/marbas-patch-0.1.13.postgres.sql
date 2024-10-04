BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.12' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.13', ver;
END $$;

CREATE TABLE mb_grain_control (
  grain_id  uuid NOT NULL PRIMARY KEY,
  flag      integer,
  /* Foreign keys */
  CONSTRAINT mb_fk_grain_control
    FOREIGN KEY (grain_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_idx_grain_control_flag
  ON mb_grain_control
  (flag);

CREATE OR REPLACE FUNCTION mb_set_grain_base_mtime()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_set_grain_base_mtime$
BEGIN
    IF (new.mtime IS NULL OR new.mtime = old.mtime) AND NOT EXISTS(SELECT 1 FROM mb_grain_control WHERE grain_id = new.id AND (0x1 & flag) > 0) THEN
		new.mtime = current_timestamp;
	END IF;
	RETURN new;
END;
$mb_set_grain_base_mtime$;

CREATE OR REPLACE FUNCTION mb_update_grain_base_parent()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_update_grain_base_parent$
BEGIN
	IF TG_OP = 'DELETE' THEN
		UPDATE mb_grain_base SET child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = old.parent_id) WHERE id = old.parent_id;
		RETURN old;
	ELSIF TG_OP = 'INSERT' THEN
		UPDATE mb_grain_base SET child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = new.parent_id) WHERE id = new.parent_id;
		RETURN new;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE mb_grain_base SET child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = old.parent_id) WHERE id = old.parent_id;
		UPDATE mb_grain_base SET child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = new.parent_id) WHERE id = new.parent_id;
		RETURN new;
	END IF;
END;
$mb_update_grain_base_parent$;

CREATE OR REPLACE FUNCTION mb_update_grain_base_mtime()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_update_grain_base_mtime$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM mb_grain_control WHERE grain_id = new.base_id AND (0x1 & flag) > 0) THEN
        UPDATE mb_grain_base SET mtime = current_timestamp WHERE id = new.base_id;
    END IF;
	RETURN new;
END;
$mb_update_grain_base_mtime$;

CREATE OR REPLACE FUNCTION mb_update_typedef_derived_mtime()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_update_typedef_derived_mtime$
BEGIN
	IF TG_OP = 'DELETE' THEN
        IF NOT EXISTS(SELECT 1 FROM mb_grain_control WHERE grain_id = old.derived_typedef_id AND (0x1 & flag) > 0) THEN
            UPDATE mb_grain_base SET mtime = current_timestamp WHERE id = old.derived_typedef_id;
        END IF;
		RETURN old;
	ELSIF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NOT EXISTS(SELECT 1 FROM mb_grain_control WHERE grain_id = new.derived_typedef_id AND (0x1 & flag) > 0) THEN
            UPDATE mb_grain_base SET mtime = current_timestamp WHERE id = new.derived_typedef_id;
        END IF;
		RETURN new;
	END IF;
END;
$mb_update_typedef_derived_mtime$;

CREATE OR REPLACE FUNCTION mb_set_grain_ref_mtime()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_set_grain_ref_mtime$
BEGIN
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
$mb_set_grain_ref_mtime$;

DROP TRIGGER IF EXISTS mb_tg_grain_base_delete_parent_mtime ON mb_grain_base;
DROP TRIGGER IF EXISTS mb_tg_grain_base_insert_parent_mtime ON mb_grain_base;
DROP TRIGGER IF EXISTS mb_tg_grain_base_update_parent_mtime ON mb_grain_base;

CREATE OR REPLACE TRIGGER mb_tg_grain_base_delete_parent_update
    AFTER DELETE
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_update_grain_base_parent();

CREATE OR REPLACE TRIGGER mb_tg_grain_base_insert_parent_update
    AFTER INSERT
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_update_grain_base_parent();

CREATE OR REPLACE TRIGGER mb_tg_grain_base_update_parent_update
    AFTER UPDATE OF parent_id
    ON mb_grain_base
    FOR EACH ROW
    WHEN (new.parent_id IS DISTINCT FROM old.parent_id)
EXECUTE FUNCTION mb_update_grain_base_parent();

UPDATE mb_propdef SET localizable = FALSE WHERE base_id = 'e8b87a2d-4154-4f37-b16d-f8781870ad84';

UPDATE mb_schema_opts SET val = '0.1.13' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;