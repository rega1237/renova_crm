-- Initial databases for Rails 8 triad using Postgres
-- NOTE: This runs on first boot of the Postgres accessory container.
-- Owner must exist: POSTGRES_USER=renova_crm

CREATE DATABASE renova_crm_production OWNER renova_crm;
CREATE DATABASE renova_crm_production_cache OWNER renova_crm;
CREATE DATABASE renova_crm_production_queue OWNER renova_crm;
CREATE DATABASE renova_crm_production_cable OWNER renova_crm;