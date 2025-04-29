INSERT INTO mb_schema_opts (name, val) VALUES ('schema.version', '0.1.16');
INSERT INTO mb_schema_opts (name, val) VALUES ('schema.mtime', to_char(now()::timestamp at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
INSERT INTO mb_schema_opts (name, val) VALUES ('schema.status', 'stable');
INSERT INTO mb_schema_opts (name, val) VALUES ('instace.id', CAST(gen_random_uuid() as text));

/* Data for table mb_lang */
INSERT INTO mb_lang (iso_code, label, label_native) VALUES ('en', 'English', 'English');
INSERT INTO mb_lang (iso_code, label, label_native) VALUES ('en-US', 'English (US)', 'English (US)');
INSERT INTO mb_lang (iso_code, label, label_native) VALUES ('de', 'German', 'Deutsch');
INSERT INTO mb_lang (iso_code, label, label_native) VALUES ('de-DE', 'German (Germany)', 'Deutsch (Deutschland)');

/* Data for table mb_value_type */
INSERT INTO mb_value_type (name) VALUES ('boolean');
INSERT INTO mb_value_type (name) VALUES ('number');
INSERT INTO mb_value_type (name) VALUES ('datetime');
INSERT INTO mb_value_type (name) VALUES ('text');
INSERT INTO mb_value_type (name) VALUES ('memo');
INSERT INTO mb_value_type (name) VALUES ('file');
INSERT INTO mb_value_type (name) VALUES ('grain');

/* Data for table mb_typedef */
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('00000000-0000-1000-a000-000000000000', NULL, NULL, '.');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000001', NULL, NULL, 'marbas', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000002', '00000000-0000-1000-a000-000000000001', NULL, 'Schema', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000003', '00000000-0000-1000-a000-000000000002', NULL, 'System', 0x1000);

INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000004', '00000000-0000-1000-a000-000000000003', NULL, 'Element', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000005', '00000000-0000-1000-a000-000000000003', NULL, 'Container', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000009', '00000000-0000-1000-a000-000000000003', NULL, 'Property', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-00000000000a', '00000000-0000-1000-a000-000000000003', NULL, 'File', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-00000000000e', '00000000-0000-1000-a000-000000000003', NULL, 'Trashbin', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('00000000-0000-1000-a000-00000000000b', '00000000-0000-1000-a000-000000000003', NULL, 'TextWithImage');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('00000000-0000-1000-a000-00000000000c', '00000000-0000-1000-a000-000000000003', NULL, 'SimpleText');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('00000000-0000-1000-a000-00000000000f', '00000000-0000-1000-a000-000000000003', NULL, 'Link');

INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-000000000004', 'MarBasSchema.Spec.GrainElement');
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-000000000005', 'MarBasSchema.Spec.GrainContainer');
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-000000000009', 'MarBasSchema.GrainDef.GrainPropDef');
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000a', 'MarBasSchema.Spec.GrainFile');
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000b', NULL);
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000c', NULL);
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000e', NULL);
INSERT INTO mb_typedef (base_id, impl) VALUES ('00000000-0000-1000-a000-00000000000f', NULL);

UPDATE mb_grain_base SET typedef_id = '00000000-0000-1000-a000-000000000005' WHERE id IN ('00000000-0000-1000-a000-000000000001', '00000000-0000-1000-a000-000000000002', '00000000-0000-1000-a000-000000000003');

/* Data for table mb_grain_base */
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000006', '00000000-0000-1000-a000-000000000001', '00000000-0000-1000-a000-000000000005', 'Content', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000008', '00000000-0000-1000-a000-000000000001', '00000000-0000-1000-a000-000000000005', 'Files', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000010', '00000000-0000-1000-a000-000000000006', '00000000-0000-1000-a000-00000000000e', 'Trash', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('7bf1d5b2-f45a-43f8-8a08-4cb52490e47a', '00000000-0000-1000-a000-000000000006', '00000000-0000-1000-a000-000000000005', 'Playground');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('f5a20495-400d-4584-b75f-211500026b0b', '7bf1d5b2-f45a-43f8-8a08-4cb52490e47a', '00000000-0000-1000-a000-00000000000b', 'Sample Text With Image');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('c1fd9974-1204-4c29-a721-700405983d92', '7bf1d5b2-f45a-43f8-8a08-4cb52490e47a', '00000000-0000-1000-a000-000000000004', 'Sample Compound');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name) VALUES ('50cda8ab-23af-4ee2-b77e-4f6154b59357', '00000000-0000-1000-a000-000000000008', '00000000-0000-1000-a000-00000000000a', 'marbas.png');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000011', '00000000-0000-1000-a000-000000000002', '00000000-0000-1000-a000-00000000000e', 'Trash', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000007', '00000000-0000-1000-a000-000000000002', '00000000-0000-1000-a000-000000000005', 'UserDefined', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, sort_key) VALUES ('4f3cf6bf-89fe-43aa-8ac5-0068be6d9e3a', '00000000-0000-1000-a000-00000000000c', '00000000-0000-1000-a000-000000000009', 'Title', '100');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, sort_key) VALUES ('557a4274-9c24-4b38-91c2-b6603b3647d9', '00000000-0000-1000-a000-00000000000c', '00000000-0000-1000-a000-000000000009', 'Body', '200');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, sort_key) VALUES ('e8b87a2d-4154-4f37-b16d-f8781870ad84', '00000000-0000-1000-a000-00000000000b', '00000000-0000-1000-a000-000000000009', 'Image', '300');
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('3beed4d5-593e-44ad-a5fe-bb77b61580fb', '00000000-0000-1000-a000-000000000009', '00000000-0000-1000-a000-000000000005', 'Property Description', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-00000000000d', '3beed4d5-593e-44ad-a5fe-bb77b61580fb', '00000000-0000-1000-a000-000000000009', 'Comment', 0x1000);
INSERT INTO mb_grain_base (id, parent_id, typedef_id, name, custom_flag) VALUES ('00000000-0000-1000-a000-000000000012', '00000000-0000-1000-a000-00000000000f', '00000000-0000-1000-a000-000000000009', 'LinkTarget', 0x1000);

INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000006', 'de', 'Inhalt');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000008', 'de', 'Dateien');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000007', 'en', 'User Defined');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000007', 'de', 'Benutzerdefiniert');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000010', 'en', 'Trash (Content)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000010', 'de', 'Ausschuss (Inhalte)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000011', 'en', 'Trash (Schema)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000011', 'de', 'Ausschuss (Schema)');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000012', 'en', 'Link Target');
INSERT INTO mb_grain_label (grain_id, lang_code, label) VALUES ('00000000-0000-1000-a000-000000000012', 'de', 'Verknüpfungsziel');

/* Data for table mb_typedef_mixin */
INSERT INTO mb_typedef_mixin (base_typedef_id, derived_typedef_id) VALUES ('00000000-0000-1000-a000-000000000005', '00000000-0000-1000-a000-00000000000e');
INSERT INTO mb_typedef_mixin (base_typedef_id, derived_typedef_id) VALUES ('00000000-0000-1000-a000-00000000000c', '00000000-0000-1000-a000-00000000000b');

/* Data for table mb_propdef */
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, localizable) VALUES ('4f3cf6bf-89fe-43aa-8ac5-0068be6d9e3a', 'text', 1, 1, TRUE);
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, localizable) VALUES ('557a4274-9c24-4b38-91c2-b6603b3647d9', 'memo', 1, 1, TRUE);
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, localizable) VALUES ('e8b87a2d-4154-4f37-b16d-f8781870ad84', 'file', 0, 1, FALSE);
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, localizable) VALUES ('00000000-0000-1000-a000-00000000000d', 'text', 0, 1, TRUE);
INSERT INTO mb_propdef (base_id, value_type, cardinality_min, cardinality_max, localizable) VALUES ('00000000-0000-1000-a000-000000000012', 'grain', 1, 1, FALSE);

/* Data for table mb_grain_trait */
INSERT INTO mb_grain_trait (id, grain_id, propdef_id, lang_code, ord, val_boolean, val_text, val_number, val_memo, val_guid) VALUES ('ce1d23e8-1ed6-4837-8ecc-35694513a7eb', 'f5a20495-400d-4584-b75f-211500026b0b', '557a4274-9c24-4b38-91c2-b6603b3647d9', 'en', 0, FALSE, NULL, NULL, 'Sed sit amet mi dignissim, interdum ligula in, viverra magna. Vivamus ac enim eu odio volutpat porttitor non sit amet nibh. Morbi id lectus nibh. Quisque ut quam ut sapien volutpat commodo eu sed augue. Donec varius ipsum mi, at finibus felis mattis vitae. Nunc accumsan eros nec nisi pretium, quis facilisis enim suscipit. Donec nisi libero, auctor ac congue et, congue eget ipsum. Aenean bibendum tempus tortor vel pellentesque. Fusce vel pharetra diam, sit amet ullamcorper arcu. Nullam auctor velit eu sem mollis, id facilisis leo facilisis. Donec id leo ac mi lacinia commodo et et nunc. Ut luctus diam eget nibh molestie, et dictum lorem consequat. ', NULL);
INSERT INTO mb_grain_trait (id, grain_id, propdef_id, lang_code, ord, val_boolean, val_text, val_number, val_memo, val_guid) VALUES ('2d81e841-b96a-4f23-9f53-05b75beef9e5', 'f5a20495-400d-4584-b75f-211500026b0b', '4f3cf6bf-89fe-43aa-8ac5-0068be6d9e3a', 'en', 0, FALSE, 'Text with Image (EN)', NULL, NULL, NULL);
INSERT INTO mb_grain_trait (id, grain_id, propdef_id, lang_code, ord, val_boolean, val_text, val_number, val_memo, val_guid) VALUES ('6d3f9e90-bbc3-4fbc-9151-0f3c00cc6123', 'f5a20495-400d-4584-b75f-211500026b0b', 'e8b87a2d-4154-4f37-b16d-f8781870ad84', NULL, 0, FALSE, NULL, NULL, NULL, '50cda8ab-23af-4ee2-b77e-4f6154b59357');

UPDATE mb_grain_base AS c SET child_count = (SELECT COUNT(id) FROM mb_grain_base AS g WHERE g.parent_id = c.id);
UPDATE mb_grain_base SET ctime = '2024-01-05T00:00:10Z', mtime = '2024-01-05T00:00:11Z';

/* Data for table mb_role */
INSERT INTO mb_role (id, name, entitlement) VALUES ('00000000-0000-1000-b000-000000000000', 'Superuser@marbas', -1);
INSERT INTO mb_role (id, name, entitlement) VALUES ('00000000-0000-1000-b000-000000000001', 'Developer@marbas', -1);
INSERT INTO mb_role (id, name, entitlement) VALUES ('00000000-0000-1000-b000-000000000002', 'Schema_Manager@marbas', 0x001 | 0x002 | 0x004 | 0x010 | 0x100 | 0x200);
INSERT INTO mb_role (id, name, entitlement) VALUES ('00000000-0000-1000-b000-000000000003', 'Content_Contributor@marbas', 0x001);
INSERT INTO mb_role (id, name) VALUES ('00000000-0000-1000-b000-000000000004', 'Content_Consumer@marbas');
INSERT INTO mb_role (id, name) VALUES ('00000000-0000-1000-b000-000000000005', 'Everyone@marbas');

/* Data for table mb_grain_acl */
/*
    None = 0x000,
    Read = 0x001,
    Write = 0x002,
    Delete = 0x004,
    WriteAcl = 0x008,
    CreateSubelement = 0x010,
    Publish = 0x100,
    TakeOwnership = 0x200,
    TransferOwnership = 0x400,
    Full = 0xffffffff
 */
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Superuser@marbas'), '00000000-0000-1000-a000-000000000000', true, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Developer@marbas'), '00000000-0000-1000-a000-000000000000', true, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas'), '00000000-0000-1000-a000-000000000000', true, 0x001 | 0x002 | 0x004 | 0x008 | 0x010 | 0x020, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000000', true, 0x001 | 0x020, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Everyone@marbas'), '00000000-0000-1000-a000-000000000001', false, 0x001, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Superuser@marbas'), '00000000-0000-1000-a000-000000000001', false, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas'), '00000000-0000-1000-a000-000000000001', false, 0x001 | 0x002 | 0x010, 0x004 | 0x008 | 0x100 | 0x200 | 0x400);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Schema_Manager@marbas'), '00000000-0000-1000-a000-000000000002', true, -1, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000002', false, 0, -1);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000006', true, 0x001 | 0x002 | 0x004 | 0x010 | 0x400, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Contributor@marbas'), '00000000-0000-1000-a000-000000000008', true, 0x001 | 0x002 | 0x004 | 0x010 | 0x400, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000006', true, 0x001, 0);
INSERT INTO mb_grain_acl (role_id, grain_id, inherit, permission_mask, restriction_mask) VALUES ((SELECT id FROM mb_role WHERE name = 'Content_Consumer@marbas'), '00000000-0000-1000-a000-000000000008', true, 0x001, 0);
