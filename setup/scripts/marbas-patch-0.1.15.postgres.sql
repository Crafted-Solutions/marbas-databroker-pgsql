BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.14' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.15', ver;
END $$;

INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('00000000-0000-1000-a000-00000000000f', '00000000-0000-1000-a000-000000000003', NULL, 'Link');
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000f', NULL);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000012', '00000000-0000-1000-a000-00000000000f', '00000000-0000-1000-a000-000000000009', 'LinkTarget', 0x1000);
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, localizable) VALUES ('00000000-0000-1000-a000-000000000012', 'grain', 1, 1, FALSE);

INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000012', 'en', 'Link Target');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000012', 'de', 'Verknüpfungsziel');

UPDATE mb_grain_base SET sort_key = '100' WHERE id = '4f3cf6bf-89fe-43aa-8ac5-0068be6d9e3a' AND sort_key IS NULL;
UPDATE mb_grain_base SET sort_key = '200' WHERE id = '557a4274-9c24-4b38-91c2-b6603b3647d9' AND sort_key IS NULL;
UPDATE mb_grain_base SET sort_key = '300' WHERE id = 'e8b87a2d-4154-4f37-b16d-f8781870ad84' AND sort_key IS NULL;
UPDATE mb_propdef SET cardinality_min = 0 WHERE base_id = 'e8b87a2d-4154-4f37-b16d-f8781870ad84';
UPDATE mb_propdef SET cardinality_min = 0 WHERE base_id = '00000000-0000-1000-a000-00000000000d';

UPDATE mb_grain_base SET ctime = '2024-01-05T00:00:10Z', mtime = '2024-01-05T00:00:11Z'
    WHERE id IN ('00000000-0000-1000-a000-00000000000f', '00000000-0000-1000-a000-000000000012', '00000000-0000-1000-a000-00000000000d', '4f3cf6bf-89fe-43aa-8ac5-0068be6d9e3a', '557a4274-9c24-4b38-91c2-b6603b3647d9', 'e8b87a2d-4154-4f37-b16d-f8781870ad84');

UPDATE mb_schema_opts SET val = '0.1.15' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;