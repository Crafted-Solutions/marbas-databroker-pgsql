BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.15' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.16', ver;
END $$;

CREATE INDEX IF NOT EXISTS mb_idx_grain_trait_boolean
  ON mb_grain_trait
  (val_boolean);

CREATE INDEX IF NOT EXISTS mb_idx_grain_trait_text
  ON mb_grain_trait
  (val_text);

CREATE INDEX IF NOT EXISTS mb_idx_grain_trait_number
  ON mb_grain_trait
  (val_number);

CREATE INDEX IF NOT EXISTS mb_idx_grain_trait_guid
  ON mb_grain_trait
  (val_guid);
  
CREATE INDEX IF NOT EXISTS mb_idx_grain_trait_memo
  ON mb_grain_trait
  (substring(val_memo, 0, 1000));

CREATE OR REPLACE FUNCTION mb_ignore_grain_label_equal_name()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_ignore_grain_label_equal_name$
BEGIN
    IF EXISTS (SELECT 1 FROM mb_grain_base WHERE id = new.grain_id AND name = new.label) THEN
        IF TG_OP = 'UPDATE' THEN
            DELETE FROM mb_grain_label WHERE grain_id = new.grain_id AND lang_code = new.lang_code;
            RETURN null;
        ELSIF TG_OP = 'INSERT' AND NOT EXISTS(SELECT 1 FROM mb_grain_label WHERE grain_id = new.grain_id AND lang_code = new.lang_code) THEN
            RETURN null;
        END IF;
    END IF;
    RETURN new;
END;
$mb_ignore_grain_label_equal_name$;

CREATE OR REPLACE FUNCTION mb_modify_grain_base()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_modify_grain_base$
BEGIN
	IF TG_OP = 'DELETE' THEN
		UPDATE mb_grain_base SET child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = old.parent_id) WHERE id = old.parent_id;
        DELETE FROM mb_grain_trait WHERE val_guid = old.id;
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
$mb_modify_grain_base$;

CREATE OR REPLACE TRIGGER mb_tg_grain_base_insert_parent_update
    AFTER INSERT
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_modify_grain_base();

CREATE OR REPLACE TRIGGER mb_tg_grain_base_delete_parent_update
    AFTER DELETE
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_modify_grain_base();

CREATE OR REPLACE TRIGGER mb_tg_grain_base_update_parent_update
    AFTER UPDATE OF parent_id
    ON mb_grain_base
    FOR EACH ROW
    WHEN (new.parent_id IS DISTINCT FROM old.parent_id)
EXECUTE FUNCTION mb_modify_grain_base();

DROP FUNCTION mb_update_grain_base_parent;

UPDATE mb_schema_opts SET val = '0.1.16' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;