BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.16' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.17', ver;
END $$;

DELETE FROM mb_grain_acl WHERE role_id = '00000000-0000-1000-b000-000000000004' AND grain_id IN ('00000000-0000-1000-a000-000000000006', '00000000-0000-1000-a000-000000000008');

INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000000', true, 0x001, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000002', false, 0, -1);

UPDATE mb_schema_opts SET val = '0.1.17' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';
    
COMMIT;