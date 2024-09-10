BEGIN TRANSACTION;

DO $$
DECLARE ver TEXT;
BEGIN
  SELECT val FROM mb_schema_opts WHERE name = 'schema.version' INTO ver;
  IF NOT ver = '0.1.6' THEN
  	RAISE EXCEPTION 'This patch is not compatible with version %', ver;
  END IF;
  RAISE INFO 'Updating schema from % to 0.1.7', ver;
END $$;

ALTER TABLE mb_grain_base RENAME COLUMN creator TO owner;
ALTER VIEW mb_grain_with_path RENAME COLUMN creator TO owner;
ALTER VIEW mb_propdef_as_grain_with_path RENAME COLUMN creator TO owner;
ALTER VIEW mb_typedef_as_grain_with_path RENAME COLUMN creator TO owner;
ALTER INDEX mb_idx_grain_base_creator RENAME TO mb_idx_grain_base_owner;

CREATE TABLE mb_role (
  id    uuid NOT NULL,
  name  varchar(255) NOT NULL,
  capabilities  integer NOT NULL DEFAULT 0,
  /* Keys */
  PRIMARY KEY (id)
);

CREATE INDEX mb_idx_role_capabilities
  ON mb_role
  (capabilities);

CREATE UNIQUE INDEX mb_idx_role_name
  ON mb_role
  (name);

CREATE TABLE mb_grain_acl (
  role_id           uuid NOT NULL,
  grain_id          uuid NOT NULL DEFAULT '00000000-0000-1000-a000-000000000000',
  inherit           boolean NOT NULL DEFAULT TRUE,
  permission_mask   integer NOT NULL DEFAULT 1,
  restriction_mask  integer NOT NULL DEFAULT 0,
  /* Keys */
  CONSTRAINT mb_pk_grain_acl
    PRIMARY KEY (role_id, grain_id),
  /* Foreign keys */
  CONSTRAINT mb_fk_grain_acl_grain
    FOREIGN KEY (grain_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_grain_acl_role
    FOREIGN KEY (role_id)
    REFERENCES mb_role(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_fki_grain_acl_grain
  ON mb_grain_acl
  (grain_id);

CREATE INDEX mb_fki_grain_acl_role
  ON mb_grain_acl
  (role_id);

CREATE INDEX mb_idx_grain_acl_inherit
  ON mb_grain_acl
  (inherit);

CREATE INDEX mb_idx_grain_acl_permissions
  ON mb_grain_acl
  (permission_mask);

CREATE INDEX mb_idx_grain_acl_restrictions
  ON mb_grain_acl
  (restriction_mask);

CREATE VIEW mb_grain_acl_effective
AS
WITH RECURSIVE cte_ancestor(id, parent_id, distance, start) AS (
    SELECT g.id, g.parent_id, 0, g.id as start
        FROM mb_grain_base AS g
    UNION ALL
    SELECT b.id, b.parent_id, a.distance + 1, a.start
        FROM mb_grain_base AS b
        JOIN cte_ancestor AS a ON a.parent_id = b.id
)
SELECT * FROM (
SELECT c.start AS grain_id, p.role_id, p.permission_mask, p.restriction_mask, p.inherit, c.distance AS acl_type, c.id AS acl_source
    FROM mb_grain_acl AS p
LEFT JOIN cte_ancestor AS c 
ON c.id = p.grain_id
    WHERE p.grain_id <> '00000000-0000-1000-a000-000000000000'
    AND (p.inherit OR p.grain_id = c.start)
    ORDER BY start, distance
)
UNION ALL
SELECT d.grain_id, d.role_id, d.permission_mask, d.restriction_mask, d.inherit, 0xFFFFFFF0 AS acl_type, d.grain_id AS acl_source
FROM mb_grain_acl AS d WHERE grain_id = '00000000-0000-1000-a000-000000000000'
UNION ALL
SELECT NULL AS grain_id, NULL AS role_id, 0 AS pemission_mask, -1 AS restriction_mask, TRUE AS inherit, 0xFFFFFFF1 AS acl_type, NULL AS acl_source;

INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, ctime, mtime) VALUES ('00000000-0000-1000-a000-000000000000', NULL, NULL, '.', '2024-01-05 16:13:39', '2024-01-06 15:58:52');

INSERT INTO mb_role (id, name, capabilities) VALUES ('00000000-0000-1000-b000-000000000000', 'Superuser@marbas', -1);
INSERT INTO mb_role (id, name, capabilities) VALUES ('00000000-0000-1000-b000-000000000001', 'Developer@marbas', -1);
INSERT INTO mb_role (id, name, capabilities) VALUES ('00000000-0000-1000-b000-000000000002', 'Schema_Manager@marbas', 0x001 | 0x002 | 0x004 | 0x010 | 0x100 | 0x200);
INSERT INTO mb_role (id, name, capabilities) VALUES ('00000000-0000-1000-b000-000000000003', 'Content_Contributor@marbas', 0x001);
INSERT INTO mb_role (id, name) VALUES ('00000000-0000-1000-b000-000000000004', 'Content_Consumer@marbas');
INSERT INTO mb_role (id, name) VALUES ('00000000-0000-1000-b000-000000000005', 'Everyone@marbas');

INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Superuser@marbas'), '00000000-0000-1000-a000-000000000000', true, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Developer@marbas'), '00000000-0000-1000-a000-000000000000', true, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas'), '00000000-0000-1000-a000-000000000000', true, 0x001 | 0x002 | 0x004 | 0x008 | 0x010, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000000', true, 0x001, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Everyone@marbas'), '00000000-0000-1000-a000-000000000001', false, 0x001, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas'), '00000000-0000-1000-a000-000000000001', false, 0x001 | 0x002 | 0x010, 0x004 | 0x008 | 0x100 | 0x200 | 0x400);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas'), '00000000-0000-1000-a000-000000000002', true, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000002', false, 0, -1);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000006', true, 0x001 | 0x002 | 0x004 | 0x010 | 0x400, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000008', true, 0x001 | 0x002 | 0x004 | 0x010 | 0x400, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000006', true, 0x001, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000008', true, 0x001, 0);

UPDATE mb_schema_opts SET val = '0.1.7' WHERE name = 'schema.version';
UPDATE mb_schema_opts SET val = to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') WHERE name = 'schema.mtime';

CREATE USER "Superuser" WITH NOINHERIT CREATEROLE ENCRYPTED PASSWORD 'SCRAM-SHA-256$4096:RTtoUGZsXk8YIPLcU2uNHw==$1UW1tIu9qnxKwsqo1pVQcn7uS2+B67XNSH5FBRz7Dcc=:9RzN0vyQJYtnScdQlooh6XLryo5kER3ElfHHRtePOkM=';
GRANT ALL ON DATABASE marbas TO "Superuser";

CREATE USER "Developer" WITH NOINHERIT ENCRYPTED PASSWORD 'SCRAM-SHA-256$4096:lP7hWe/X8YtW4uhlaCq1eg==$rl/botbnYwyH20s5F2eT5cyvA03FKdgLn75qwS1u3IU=:3slOuxCO3Y431drhUXYjsgmE+MYzE89Bn9eU6EC+Pns=';
GRANT ALL ON DATABASE marbas TO "Developer";

CREATE USER "Schema_Manager" WITH NOINHERIT ENCRYPTED PASSWORD 'SCRAM-SHA-256$4096:eJQI4YXx0T1heymOkKS/XQ==$RBLdZWU091sA6XrcarmYgDZUpUJSlppV8dWBeUkZhLo=:kynhjjHa3jfqOnJKgHE1b7spgd2v/xKkNv8zgXHaAME=';
GRANT SELECT ON mb_role, mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_typedef_mixin, mb_propdef, mb_typedef, mb_grain_trait, mb_value_type, mb_grain_history, mb_lang TO "Schema_Manager";
GRANT UPDATE ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_grain_trait, mb_grain_history, mb_typedef_mixin, mb_propdef, mb_typedef, mb_lang TO "Schema_Manager";
GRANT INSERT ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_grain_trait, mb_grain_history, mb_typedef_mixin, mb_propdef, mb_typedef, mb_lang TO "Schema_Manager";
GRANT DELETE ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_grain_trait, mb_grain_history, mb_typedef_mixin, mb_propdef, mb_typedef, mb_lang TO "Schema_Manager";

CREATE USER "Content_Contributor" WITH NOINHERIT ENCRYPTED PASSWORD 'SCRAM-SHA-256$4096:vaGGvbcuooogZQUcm8OoMg==$mPTAEYY8XYEBj3ekcKG1x1Ul+czpKr1Sz9HPIMKI1KU=:H48hHsxQjaJHTz6rPQ7Ur7ip7BJgRXHWJc9JD1Xln28=';
GRANT SELECT ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_typedef_mixin, mb_propdef, mb_typedef, mb_grain_trait, mb_value_type, mb_grain_history, mb_lang TO "Content_Contributor";
GRANT UPDATE ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_grain_trait, mb_grain_history TO "Content_Contributor";
GRANT INSERT ON mb_grain_base, mb_grain_label, mb_file, mb_grain_trait, mb_grain_history TO "Content_Contributor";
GRANT DELETE ON mb_grain_base, mb_grain_label, mb_file, mb_grain_trait, mb_grain_history TO "Content_Contributor";

CREATE USER "Content_Consumer" WITH NOINHERIT ENCRYPTED PASSWORD 'SCRAM-SHA-256$4096:ZTJdG8kpvVdH2IBvhz0n1A==$vn/TXOpPTG3nkq4QJQbbvKJ0IsfveUHRDHgKfgyZxnE=:oNV3uSUFrmwN4HQGprOy7z0YgJQqafiAo09bUyo3J+k=';
GRANT SELECT ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_file, mb_typedef_mixin, mb_propdef, mb_typedef, mb_grain_trait, mb_value_type TO "Content_Consumer";

CREATE USER "Everyone" WITH NOINHERIT ENCRYPTED PASSWORD 'SCRAM-SHA-256$4096:MuKwDxklpxxZEC//hc7wiA==$gPzk5SPXNDvYKJCls6o4TIN8Pr5vkwBzzjC01WwyPxU=:HlqfkWgm4k8wqP02UsQACjgoRc5yflykV73eDT39GxU=';
GRANT SELECT ON mb_grain_acl, mb_grain_base, mb_grain_label, mb_propdef, mb_typedef, mb_grain_trait, mb_value_type TO "Everyone";

COMMIT;