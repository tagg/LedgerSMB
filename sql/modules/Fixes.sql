-- SQL Fixes for upgrades.  These must be safe to run repeatedly, or they must 
-- fail transactionally.  Please:  one transaction per fix.  
--
-- These will be cleaned up going back no more than one beta.

-- Chris Travers

update defaults set value='yes' where setting_key='module_load_ok';

DELETE FROM menu_acl 
 WHERE node_id IN (select node_id from menu_attribute 
                    where attribute = 'module' and value = 'bp.pl');
DELETE FROM menu_attribute 
 WHERE node_id IN (select node_id from menu_attribute 
                    where attribute = 'module' and value = 'bp.pl');
DELETE FROM menu_node 
 WHERE id NOT IN (select node_id from menu_attribute);

DELETE FROM menu_acl
 WHERE node_id IN (select node_id from menu_attribute
                    where attribute = 'menu' and node_id not in
                          (select parent from menu_node));

DELETE FROM menu_attribute
 WHERE node_id IN (select node_id from menu_attribute
                    where attribute = 'menu' and node_id not in
                          (select parent from menu_node));
DELETE FROM menu_node 
 WHERE id NOT IN (select node_id from menu_attribute);
COMMIT;

BEGIN;

INSERT INTO location_class(id,class,authoritative) VALUES ('4','Physical',TRUE);
INSERT INTO location_class(id,class,authoritative) VALUES ('5','Mailing',FALSE);

SELECT SETVAL('location_class_id_seq',5);

INSERT INTO location_class_to_entity_class
       (location_class, entity_class)
SELECT lc.id, ec.id
  FROM entity_class ec
 cross
  join location_class lc
 WHERE ec.id <> 3 and lc.id < 4;

INSERT INTO location_class_to_entity_class (location_class, entity_class)
SELECT id, 3 from location_class lc where lc.id > 3;

COMMIT;

BEGIN;
ALTER TABLE BATCH DROP CONSTRAINT "batch_locked_by_fkey";

ALTER TABLE BATCH ADD FOREIGN KEY (locked_by) references session (session_id) 
ON DELETE SET NULL;

COMMIT;

BEGIN;
UPDATE entity_credit_account
   SET curr = (select s from unnest(string_to_array((setting_get('curr')).value, ':')) s limit 1)
 WHERE curr IS NULL;
COMMIT;

BEGIN;
update entity_credit_account set language_code = 'en' where language_code is null;
COMMIT;

BEGIN;
UPDATE menu_node set position = (position * -1) - 1 
 where parent IN (172, 156) and position > 1;
UPDATE menu_node set position = position * -1 where position < 0;
INSERT INTO menu_node (id, parent, position, label)
VALUES (90, 172, 2, 'Product Receipt'),
       (99, 156, 2, 'Product Receipt');

INSERT INTO menu_attribute 
(id, node_id, attribute, value) VALUES
(228, 90, 'module', 'template.pm'),
(229, 90, 'action', 'display'),
(230, 90, 'template_name', 'product_receipt'),
(231, 90, 'format', 'tex'),
(240, 99, 'module', 'template.pm'),
(241, 99, 'action', 'display'),
(242, 99, 'template_name', 'product_receipt'),
(245, 99, 'format', 'html');
COMMIT;

BEGIN;
ALTER TABLE person ADD COLUMN birthdate date;
ALTER TABLE person ADD COLUMN personal_id text;
COMMIT;

BEGIN;
ALTER TABLE ar ADD COLUMN is_return bool default false;
COMMIT;
BEGIN; -- SEPARATE transaction due to questions of if one of the cols si there
ALTER TABLE ap ADD COLUMN is_return bool default false;
COMMIT;

BEGIN;
UPDATE menu_node SET position = position * -1 - 1 WHERE parent = 1 and position > 6;
INSERT INTO menu_node (id, parent, position, label)
VALUES (129, 1, 7, 'Add Return');
update menu_node set position = position * -1 where position < 0;
INSERT INTO menu_attribute (id, node_id, attribute, value)
VALUES (251, 129, 'module', 'is.pl'),
       (252, 129, 'action', 'add'),
       (253, 129, 'type', 'customer_return');
COMMIT;

BEGIN;
ALTER TABLE invoice ADD vendor_sku text;
UPDATE invoice SET vendor_sku = (select min(partnumber) from partsvendor
                                  where parts_id = invoice.parts_id
                                        AND credit_id = (
                                                 select entity_credit_account
                                                   from ap
                                                  where ap.id = invoice.trans_id
                                        )
                                )
 WHERE trans_id in (select id from ap);
COMMIT;

BEGIN;
ALTER TABLE ar DROP CONSTRAINT ar_invnumber_key;
ALTER TABLE ar ADD CHECK(invnumber is not null OR not approved);
CREATE UNIQUE INDEX ar_invnumber_key_p ON ar(invnumber) where invnumber is not null;
COMMIT;
ALTER TABLE ar ADD setting_sequence TEXT;

BEGIN;
UPDATE menu_attribute SET value = 'contact.pl'
 WHERE node_id = 48 AND attribute = 'module';
COMMIT;

BEGIN;
UPDATE menu_attribute SET value = 'template.pl' WHERE value = 'template.pm';
COMMIT;

-- Add parent of the header as its "heading"
CREATE OR REPLACE VIEW chart AS
SELECT id, accno, description,
       'H' as charttype, NULL as category, NULL as link,
       parent_id as account_heading,
       null as gifi_accno, false as contra,
       false as tax
  from account_heading
UNION
select c.id, c.accno, c.description,
       'A' as charttype, c.category, concat_colon(l.description) as link,
       heading, gifi_accno, contra,
       tax
  from account c
  left join account_link l
    ON (c.id = l.account_id)
group by c.id, c.accno, c.description, c.category, c.heading,
         c.gifi_accno, c.contra, c.tax;

BEGIN;
UPDATE language SET code = 'ms_MY' WHERE code = 'my';
COMMIT;
