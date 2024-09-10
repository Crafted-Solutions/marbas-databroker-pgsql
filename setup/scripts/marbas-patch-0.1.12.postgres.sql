BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.11' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.12', ver;
END $$;

INSERT INTO mb_schema_opts (name, val) VALUES ('schema.status', 'stable');
INSERT INTO mb_schema_opts (name, val) VALUES ('instace.id', CAST(gen_random_uuid() as text));

ALTER TABLE mb_role
	RENAME COLUMN capabilities TO entitlement;
DROP INDEX IF EXISTS mb_idx_role_capabilities;
CREATE INDEX mb_idx_role_entitlement
  ON mb_role (entitlement);

DROP VIEW mb_grain_trait_with_meta;
DROP VIEW mb_propdef_as_grain_with_path;
DROP VIEW mb_typedef_as_grain_with_path;
DROP VIEW mb_grain_with_path;

ALTER TABLE mb_grain_base
    ADD COLUMN child_count integer DEFAULT 0;
ALTER TABLE mb_grain_base
	DROP CONSTRAINT mb_fk_grain_base_typedef;
ALTER TABLE IF EXISTS mb_grain_base
    ADD CONSTRAINT mb_fk_grain_base_typedef FOREIGN KEY (typedef_id)
    REFERENCES mb_typedef (base_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE RESTRICT;
ALTER TABLE mb_grain_base
	ADD CONSTRAINT mb_grain_base_revision CHECK (revision >= 1);
    
ALTER TABLE mb_grain_trait
	ADD CONSTRAINT mb_grain_trait_revision CHECK (revision >= 0);
ALTER TABLE mb_grain_trait
	ADD CONSTRAINT mb_grain_trait_ord CHECK (ord >= 0);

ALTER TABLE mb_propdef
	ADD CONSTRAINT mb_prodef_cardinality_min CHECK (cardinality_min >= 0);
ALTER TABLE mb_propdef
	ADD CONSTRAINT mb_prodef_cardinality_max CHECK (cardinality_max = -1 OR cardinality_max >= 1);
    
ALTER TABLE mb_grain_history
	ADD CONSTRAINT mb_grain_history_revision CHECK (revision >= 1);
    
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

CREATE OR REPLACE FUNCTION mb_set_grain_base_mtime()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_set_grain_base_mtime$
BEGIN
    IF new.mtime IS NULL OR new.mtime = old.mtime THEN
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
		UPDATE mb_grain_base SET mtime = current_timestamp, child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = old.parent_id) WHERE id = old.parent_id;
		RETURN old;
	ELSIF TG_OP = 'INSERT' THEN
		UPDATE mb_grain_base SET mtime = current_timestamp, child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = new.parent_id) WHERE id = new.parent_id;
		RETURN new;
	ELSIF TG_OP = 'UPDATE' THEN
		UPDATE mb_grain_base SET mtime = current_timestamp, child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = old.parent_id) WHERE id = old.parent_id;
		UPDATE mb_grain_base SET mtime = current_timestamp, child_count = (SELECT COUNT(id) FROM mb_grain_base WHERE parent_id = new.parent_id) WHERE id = new.parent_id;
		RETURN new;
	END IF;
END;
$mb_update_grain_base_parent$;

CREATE OR REPLACE TRIGGER mb_tg_grain_base_insert_parent_update
    AFTER INSERT
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_update_grain_base_parent();

CREATE OR REPLACE TRIGGER mb_tg_grain_base_delete_parent_update
    AFTER DELETE
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_update_grain_base_parent();

CREATE OR REPLACE TRIGGER mb_tg_grain_base_update_parent_mtime
    AFTER UPDATE OF parent_id
    ON mb_grain_base
    FOR EACH ROW
EXECUTE FUNCTION mb_update_grain_base_parent();

CREATE OR REPLACE FUNCTION mb_ignore_grain_label_equal_name()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_ignore_grain_label_equal_name$
BEGIN
    IF EXISTS (SELECT 1 FROM mb_grain_base WHERE id = new.grain_id AND name = new.label) THEN
        IF TG_OP = 'UPDATE' THEN
            DELETE FROM mb_grain_label WHERE grain_id = new.grain_id AND lang_code = new.lang_code;
        END IF;
        RETURN null;
    END IF;
    RETURN new;
END;
$mb_ignore_grain_label_equal_name$;

CREATE OR REPLACE TRIGGER mb_tg_grain_label_insert_grain_name
    BEFORE INSERT
    ON mb_grain_label
    FOR EACH ROW
EXECUTE FUNCTION mb_ignore_grain_label_equal_name();

CREATE OR REPLACE TRIGGER mb_tg_grain_label_update_grain_name
    BEFORE UPDATE
    ON mb_grain_label
    FOR EACH ROW
EXECUTE FUNCTION mb_ignore_grain_label_equal_name();

CREATE OR REPLACE FUNCTION mb_sync_grain_trait_l10n()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_sync_grain_trait_l10n$
BEGIN
	IF new.lang_code IS NULL AND (SELECT localizable FROM mb_propdef WHERE base_id = new.propdef_id) = TRUE THEN
		new.lang_code = 'en';
	ELSIF new.lang_code IS NOT NULL AND (SELECT localizable FROM mb_propdef WHERE base_id = new.propdef_id) <> TRUE THEN
		new.lang_code = NULL;
	END IF;
    RETURN new;
END;
$mb_sync_grain_trait_l10n$;

CREATE OR REPLACE TRIGGER mb_tg_grain_trait_sync_l10n
    BEFORE INSERT OR UPDATE OF lang_code
    ON mb_grain_trait
    FOR EACH ROW
EXECUTE FUNCTION mb_sync_grain_trait_l10n();

INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-00000000000e', '00000000-0000-1000-a000-000000000003', NULL, 'Trashbin', 0x1000);
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000e', NULL);
INSERT INTO mb_typedef_mixin (base_typedef_id, derived_typedef_id) VALUES ('00000000-0000-1000-a000-000000000005', '00000000-0000-1000-a000-00000000000e');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000010', '00000000-0000-1000-a000-000000000006', '00000000-0000-1000-a000-00000000000e', 'Trash', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('7bf1d5b2-f45a-43f8-8a08-4cb52490e47a', '00000000-0000-1000-a000-000000000006', '00000000-0000-1000-a000-000000000005', 'Playground');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000011', '00000000-0000-1000-a000-000000000002', '00000000-0000-1000-a000-00000000000e', 'Trash', 0x1000);

INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000010', 'en', 'Trash (Content)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000010', 'de', 'Ausschuss (Inhalte)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000011', 'en', 'Trash (Schema)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000011', 'de', 'Ausschuss (Schema)');

UPDATE mb_grain_base SET parent_id = '7bf1d5b2-f45a-43f8-8a08-4cb52490e47a' WHERE id IN ('f5a20495-400d-4584-b75f-211500026b0b', 'c1fd9974-1204-4c29-a721-700405983d92');

UPDATE mb_grain_base
  SET custom_flag = 0x1000
  WHERE id IN (
'00000000-0000-1000-a000-000000000001',
'00000000-0000-1000-a000-000000000002',
'00000000-0000-1000-a000-000000000003',
'00000000-0000-1000-a000-000000000004',
'00000000-0000-1000-a000-000000000005',
'00000000-0000-1000-a000-000000000009',
'00000000-0000-1000-a000-00000000000a',
'00000000-0000-1000-a000-00000000000e',
'00000000-0000-1000-a000-000000000006',
'00000000-0000-1000-a000-000000000008',
'00000000-0000-1000-a000-000000000010',
'00000000-0000-1000-a000-000000000011',
'00000000-0000-1000-a000-000000000007',
'3beed4d5-593e-44ad-a5fe-bb77b61580fb',
'00000000-0000-1000-a000-00000000000d'
);
UPDATE mb_grain_base AS c SET child_count = (SELECT COUNT(id) FROM mb_grain_base AS g WHERE g.parent_id = c.id);
UPDATE mb_grain_base SET ctime = '2024-01-05T00:00:10Z', mtime = '2024-01-05T00:00:11Z' WHERE owner = 'system@marbas';

UPDATE mb_schema_opts SET val = '0.1.12' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;