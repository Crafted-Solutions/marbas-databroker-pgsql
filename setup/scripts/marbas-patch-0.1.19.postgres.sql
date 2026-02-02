BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.18' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.19', ver;
END $$;

INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000013', '00000000-0000-1000-a000-000000000003', '00000000-0000-1000-a000-000000000005', 'TypeDefSpec', 0x1000);

INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000013', 'en', 'Type Specification');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000013', 'de', 'Typspezifikation');

INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000009', 'de', 'Eigenschaft');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-00000000000a', 'de', 'Datei');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-00000000000e', 'de', 'Papierkorb');
    
UPDATE mb_schema_opts SET val = '0.1.19' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;