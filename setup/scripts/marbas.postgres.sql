CREATE SCHEMA IF NOT EXISTS public
    AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public
    IS 'standard public schema';

GRANT USAGE ON SCHEMA public TO PUBLIC;

GRANT ALL ON SCHEMA public TO pg_database_owner;

/* System tables */
CREATE TABLE mb_schema_opts (
  name  varchar(255) NOT NULL,
  val   varchar(255),
  /* Keys */
  CONSTRAINT mb_pk_schema_opts
    PRIMARY KEY (name, val)
);

CREATE TABLE mb_lang (
  iso_code      varchar(24) NOT NULL,
  label         varchar(255) NOT NULL,
  label_native  varchar(255),
  /* Keys */
  PRIMARY KEY (iso_code), 
  CONSTRAINT mb_idx_lang_label
    UNIQUE (label), 
  CONSTRAINT mb_idx_lang_label_native
    UNIQUE (label_native)
);

CREATE TABLE mb_value_type (
  name  varchar(255) NOT NULL,
  /* Keys */
  PRIMARY KEY (name)
);

/* Business data tables */
/* mb_grain_base */
CREATE TABLE mb_grain_base (
  id          uuid NOT NULL,
  parent_id   uuid,
  typedef_id  uuid,
  name        varchar(255) NOT NULL,
  ctime       timestamp,
  mtime       timestamp,
  owner     varchar(255) NOT NULL DEFAULT 'system@marbas',
  revision    integer NOT NULL DEFAULT 1,
  sort_key    varchar(50),
  xattrs      varchar(510),
  custom_flag integer DEFAULT 0,
  child_count integer DEFAULT 0,
  /* Keys */
  PRIMARY KEY (id),
  CONSTRAINT mb_idx_grain_base_level_name
    UNIQUE (parent_id, name),
  /* Checks */
  CONSTRAINT mb_grain_base_revision
    CHECK (revision >= 1),
  /* Foreign keys */
  CONSTRAINT mb_fk_grain_base_parent
    FOREIGN KEY (parent_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_idx_grain_base_owner
  ON mb_grain_base
  (owner);

CREATE INDEX mb_idx_grain_base_ctime
  ON mb_grain_base
  (ctime);

CREATE INDEX mb_idx_grain_base_mtime
  ON mb_grain_base
  (mtime);

CREATE INDEX mb_idx_grain_base_name
  ON mb_grain_base
  (name);

CREATE INDEX mb_idx_grain_base_revision
  ON mb_grain_base
  (revision);

CREATE INDEX mb_idx_grain_base_sort
  ON mb_grain_base
  (sort_key);
 
CREATE INDEX mb_idx_grain_base_xattrs
  ON mb_grain_base
  (xattrs);
  
CREATE INDEX mb_idx_grain_base_flag
  ON mb_grain_base
  (custom_flag);
  
CREATE OR REPLACE FUNCTION mb_set_grain_base_ctime()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_set_grain_base_ctime$
BEGIN
	IF new.ctime IS NULL THEN
		new.ctime = current_timestamp;
	END IF;
	RETURN new;
END;
$mb_set_grain_base_ctime$;

CREATE TRIGGER mb_tg_grain_base_ctime
  BEFORE INSERT
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_base_ctime();
 
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

CREATE TRIGGER mb_tg_grain_base_mtime
  BEFORE INSERT OR UPDATE
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_base_mtime();

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

CREATE OR REPLACE TRIGGER mb_tg_grain_base_update_parent_update
    AFTER UPDATE OF parent_id
    ON mb_grain_base
    FOR EACH ROW
    WHEN (new.parent_id IS DISTINCT FROM old.parent_id)
EXECUTE FUNCTION mb_update_grain_base_parent();

CREATE OR REPLACE FUNCTION mb_ignore_typedef_defaults_duplicates()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_ignore_typedef_defaults_duplicates$
BEGIN
	IF new.parent_id = new.typedef_id AND EXISTS (SELECT 1 FROM mb_grain_base WHERE parent_id = new.parent_id AND typedef_id = new.typedef_id) THEN
		RETURN null;
	END IF;
	RETURN new;
END;
$mb_ignore_typedef_defaults_duplicates$;

CREATE TRIGGER mb_tg_grain_typedef_defaults_check
  BEFORE INSERT
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_ignore_typedef_defaults_duplicates();

CREATE OR REPLACE FUNCTION mb_set_typedef_defaults_name()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_set_typedef_defaults_name$
BEGIN
	IF new.parent_id = new.typedef_id THEN
		new.name = '__defaults__';
	END IF;
	RETURN new;
END;
$mb_set_typedef_defaults_name$;

CREATE TRIGGER mb_tg_grain_typedef_defaults_name
  BEFORE INSERT OR UPDATE
  ON mb_grain_base
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_typedef_defaults_name();


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

/* mb_typedef */ 
CREATE TABLE mb_typedef (
  base_id  uuid NOT NULL,
  impl     varchar(1024),
  /* Keys */
  PRIMARY KEY (base_id),
  /* Foreign keys */
  CONSTRAINT mb_fk_typedef_base
    FOREIGN KEY (base_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

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

CREATE TRIGGER mb_tg_typedef_update_mtime
  AFTER UPDATE
  ON mb_typedef
  FOR EACH ROW
EXECUTE PROCEDURE mb_update_grain_base_mtime();

ALTER TABLE IF EXISTS mb_grain_base
    ADD CONSTRAINT mb_fk_grain_base_typedef FOREIGN KEY (typedef_id)
    REFERENCES mb_typedef (base_id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE RESTRICT;
CREATE INDEX IF NOT EXISTS mb_fki_grain_base_typedef
    ON mb_grain_base(typedef_id);

/* mb_typedef_mixin */
CREATE TABLE mb_typedef_mixin (
  base_typedef_id     uuid NOT NULL,
  derived_typedef_id  uuid NOT NULL,
  /* Keys */
  CONSTRAINT mb_pk_typedef_inheritance
    PRIMARY KEY (base_typedef_id, derived_typedef_id),
  /* Foreign keys */
  CONSTRAINT mb_fk_typedef_mixin_derived
    FOREIGN KEY (derived_typedef_id)
    REFERENCES mb_typedef(base_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_typedef_mixin_base
    FOREIGN KEY (base_typedef_id)
    REFERENCES mb_typedef(base_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

CREATE INDEX mb_fki_typedef_mixin_derived
  ON mb_typedef_mixin
  (derived_typedef_id);
  
CREATE INDEX mb_fki_typedef_mixin_base
  ON mb_typedef_mixin
  (base_typedef_id);

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

CREATE TRIGGER mb_tg_typedef_mixin_update_mtime
  AFTER INSERT OR UPDATE
  ON mb_typedef_mixin
  FOR EACH ROW
EXECUTE PROCEDURE mb_update_typedef_derived_mtime();

CREATE TRIGGER mb_tg_typedef_mixin_delete_mtime
  AFTER DELETE
  ON mb_typedef_mixin
  FOR EACH ROW
EXECUTE PROCEDURE mb_update_typedef_derived_mtime();

/* mb_propdef */
CREATE TABLE mb_propdef (
  base_id           uuid NOT NULL,
  value_type        varchar(255) NOT NULL DEFAULT 'text',
  cardinality_min   integer NOT NULL DEFAULT 1,
  cardinality_max   integer NOT NULL DEFAULT 1,
  value_constraint  uuid,
  constraint_params varchar(1024),
  versionable       boolean NOT NULL DEFAULT TRUE,
  localizable       boolean NOT NULL DEFAULT TRUE,
  /* Keys */
  PRIMARY KEY (base_id),
  /* Checks */
  CONSTRAINT mb_prodef_cardinality_min
    CHECK (cardinality_min >= 0),
  CONSTRAINT mb_prodef_cardinality_max
    CHECK (cardinality_max = -1 OR cardinality_max >= 1),
  /* Foreign keys */
  CONSTRAINT mb_fk_propdef_value_type
    FOREIGN KEY (value_type)
    REFERENCES mb_value_type(name)
    ON DELETE RESTRICT
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_propdef_base
    FOREIGN KEY (base_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_propdef_value_constr
    FOREIGN KEY (value_constraint)
    REFERENCES mb_grain_base(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

CREATE INDEX mb_idx_propdef_localizable
  ON mb_propdef
  (localizable);

CREATE INDEX mb_idx_propdef_value_type
  ON mb_propdef
  (value_type);

CREATE INDEX mb_idx_propdef_versionable
  ON mb_propdef
  (versionable);

CREATE INDEX mb_idx_propdef_value_constr
  ON mb_propdef
  (value_constraint);
  
CREATE TRIGGER mb_tg_propdef_update_mtime
  AFTER UPDATE
  ON mb_propdef
  FOR EACH ROW
EXECUTE PROCEDURE mb_update_grain_base_mtime();

/* mb_file */
CREATE TABLE mb_file (
  base_id    uuid NOT NULL,
  mime_type  varchar(255) NOT NULL DEFAULT 'application/octet-stream',
  size       bigint NOT NULL DEFAULT -1,
  content    oid,
  /* Keys */
  PRIMARY KEY (base_id),
  /* Foreign keys */
  CONSTRAINT mb_fk_file_base
    FOREIGN KEY (base_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_idx_file_mime
  ON mb_file
  (mime_type);
  
CREATE TRIGGER mb_tg_file_update_mtime
  AFTER UPDATE
  ON mb_file
  FOR EACH ROW
EXECUTE PROCEDURE mb_update_grain_base_mtime();

CREATE OR REPLACE FUNCTION mb_unlink_file_lob(id uuid)
    RETURNS integer
	LANGUAGE plpgsql
	AS $mb_unlink_file_lob$
 BEGIN
    PERFORM lo_unlink(mb_file.content) FROM mb_file WHERE mb_file.base_id = id AND mb_file.content IS NOT NULL;
    RETURN 1;
END;
$mb_unlink_file_lob$;

CREATE OR REPLACE FUNCTION mb_delete_file_content()
	RETURNS TRIGGER
	LANGUAGE plpgsql
	AS $mb_delete_file_content$
BEGIN
	PERFORM mb_unlink_file_lob(old.base_id);
    RETURN old;
END;
$mb_delete_file_content$;

CREATE TRIGGER mb_tg_delete_file_content
  BEFORE DELETE
  ON mb_file
  FOR EACH ROW
EXECUTE PROCEDURE mb_delete_file_content();

/* mb_grain_trait */
CREATE TABLE mb_grain_trait (
  id           uuid NOT NULL,
  grain_id     uuid NOT NULL,
  propdef_id   uuid NOT NULL,
  lang_code    varchar(24),
  revision     integer NOT NULL DEFAULT 1,
  ord          integer NOT NULL DEFAULT 0,
  val_boolean  boolean DEFAULT FALSE,
  val_text     varchar(512),
  val_number   real,
  val_datetime  timestamp,
  val_memo     text,
  val_guid     uuid,
  /* Keys */
  PRIMARY KEY (id),
  /* Checks */
  CONSTRAINT mb_grain_trait_revision
    CHECK (revision >= 0),
  CONSTRAINT mb_grain_trait_ord
    CHECK (ord >= 0),
  /* Foreign keys */
  CONSTRAINT mb_fk_grain_trait_lang
    FOREIGN KEY (lang_code)
    REFERENCES mb_lang(iso_code)
    ON DELETE CASCADE
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_grain_trait_propdef
    FOREIGN KEY (propdef_id)
    REFERENCES mb_propdef(base_id)
    ON DELETE CASCADE
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_grain_trait_grain
    FOREIGN KEY (grain_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_fki_grain_trait_lang
  ON mb_grain_trait
  (lang_code);
  
CREATE INDEX mb_fki_grain_trait_grain
  ON mb_grain_trait
  (grain_id);
  
CREATE INDEX mb_fki_grain_trait_propdef
  ON mb_grain_trait
  (propdef_id);
  
CREATE UNIQUE INDEX mb_idx_grain_trait_propdef
  ON mb_grain_trait
  (grain_id, propdef_id, lang_code, ord, revision);

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

CREATE TRIGGER mb_tg_grain_trait_update_mtime
  AFTER INSERT OR UPDATE
  ON mb_grain_trait
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_ref_mtime();

CREATE TRIGGER mb_tg_grain_trait_delete_mtime
  AFTER DELETE
  ON mb_grain_trait
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_ref_mtime();

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

/* mb_grain_label */
CREATE TABLE mb_grain_label (
  grain_id   uuid NOT NULL,
  lang_code  varchar(24) NOT NULL,
  label      varchar(512) NOT NULL,
  /* Keys */
  CONSTRAINT mb_pk_grain_label
    PRIMARY KEY (grain_id, lang_code),
  /* Foreign keys */
  CONSTRAINT mb_fk_label_grain
    FOREIGN KEY (grain_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE, 
  CONSTRAINT mb_fk_label_lang
    FOREIGN KEY (lang_code)
    REFERENCES mb_lang(iso_code)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_idx_grain_label_label
  ON mb_grain_label
  (label);
  
CREATE INDEX mb_fki_grain_label_lang
  ON mb_grain_label
  (lang_code);
  
CREATE INDEX mb_fki_grain_label_grain
  ON mb_grain_label
  (grain_id);

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

CREATE TRIGGER mb_tg_grain_label_update_mtime
  AFTER INSERT OR UPDATE
  ON mb_grain_label
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_ref_mtime();

CREATE TRIGGER mb_tg_grain_label_delete_mtime
  AFTER DELETE
  ON mb_grain_label
  FOR EACH ROW
EXECUTE PROCEDURE mb_set_grain_ref_mtime();

/* mb_grain_history */
CREATE TABLE mb_grain_history (
  grain_id  uuid NOT NULL,
  revision  integer NOT NULL DEFAULT 1,
  author    varchar(255) NOT NULL DEFAULT 'system@marbas',
  comment   varchar(255),
  ctime     timestamp NOT NULL,
  /* Keys */
  CONSTRAINT mb_pk_grain_history
    PRIMARY KEY (grain_id, revision),
  /* Checks */
  CONSTRAINT mb_grain_history_revision
    CHECK (revision >= 1),
  /* Foreign keys */
  CONSTRAINT mb_fk_grain_history_base
    FOREIGN KEY (grain_id)
    REFERENCES mb_grain_base(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE INDEX mb_idx_grain_history_author
  ON mb_grain_history
  (author);

CREATE INDEX mb_idx_grain_history_ctime
  ON mb_grain_history
  (ctime);

CREATE INDEX mb_fki_grain_history_grain
  ON mb_grain_history
  (grain_id);

CREATE INDEX mb_fki_grain_history_revision
  ON mb_grain_history
  (revision);

/* Acess control */
/* mb_role */
CREATE TABLE mb_role (
  id    uuid NOT NULL,
  name  varchar(255) NOT NULL,
  entitlement  integer NOT NULL DEFAULT 0,
  /* Keys */
  PRIMARY KEY (id)
);

CREATE INDEX mb_idx_role_entitlement
  ON mb_role
  (entitlement);

CREATE UNIQUE INDEX mb_idx_role_name
  ON mb_role
  (name);

/* mb_grain_acl */
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


/* Views */
/* mb_grain_with_path */
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
    
/* mb_grain_ancestor */
CREATE VIEW mb_grain_ancestor
AS
WITH RECURSIVE cte_ancestor(id, name, parent_id, distance, start) AS (
    SELECT id, name, parent_id, 0, id as start
        FROM mb_grain_base
    UNION ALL
    SELECT y.id, y.name, y.parent_id, a.distance + 1, a.start
        FROM mb_grain_base AS y
        JOIN cte_ancestor a ON a.parent_id = y.id
)
SELECT *
    FROM cte_ancestor
    ORDER BY start, distance;

/* mb_grain_trait_with_meta */
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
    
/* mb_typedef_as_grain_with_path */
CREATE VIEW mb_typedef_as_grain_with_path
AS
SELECT t.impl, d.id AS defaults_id, g.* FROM mb_typedef AS t
LEFT JOIN mb_grain_with_path AS g
    ON g.id = t.base_id
LEFT JOIN mb_grain_base AS d
    ON d.parent_id = t.base_id AND d.typedef_id = t.base_id;

/* mb_propdef_as_grain_with_path */
CREATE VIEW mb_propdef_as_grain_with_path
AS
SELECT p.*, g.* FROM mb_propdef AS p
LEFT JOIN mb_grain_with_path AS g
    ON g.id = p.base_id;

/* mb_typedef_mixin_ancestor */
CREATE VIEW mb_typedef_mixin_ancestor
AS
WITH RECURSIVE cte_base(derived_typedef_id, base_typedef_id, distance, start) AS (
    SELECT derived_typedef_id, base_typedef_id, 0, derived_typedef_id AS start
        FROM mb_typedef_mixin
    UNION ALL
    SELECT b.derived_typedef_id, b.base_typedef_id, a.distance + 1, a.start
        FROM mb_typedef_mixin AS b
        JOIN cte_base AS a ON a.base_typedef_id = b.derived_typedef_id
)
SELECT * FROM cte_base
ORDER by start, distance;

/* mb_typedef_mixin_descendant */
CREATE VIEW mb_typedef_mixin_descendant
AS
WITH RECURSIVE cte_derived(derived_typedef_id, base_typedef_id, distance, start) AS (
    SELECT derived_typedef_id, base_typedef_id, 0, base_typedef_id AS start
        FROM mb_typedef_mixin
    UNION ALL
    SELECT b.derived_typedef_id, b.base_typedef_id, a.distance + 1, a.start
        FROM mb_typedef_mixin AS b
        JOIN cte_derived AS a ON a.derived_typedef_id = b.base_typedef_id
)
SELECT * FROM cte_derived
ORDER by start, distance;

/* mb_grain_acl_effective */
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

/* Roles */
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
