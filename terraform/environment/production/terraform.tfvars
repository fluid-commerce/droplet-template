# fluid droplet shiphero production
# project variables
project_id = "fluid-417204"
region     = "europe-west1"

# compute engine variables for jobs console
vm_name      = "fluid-droplet-TEMPLATE-jobs-console"
machine_type = "e2-small"
zone         = "europe-west1-b"

# labels for the instance
environment            = "production"
purpose_compute_engine = "jobs"
project                = "fluid-droplet-TEMPLATE"

# service account email to compute engine
email_service_account = ""

# variable module container
#master key
container_rails_master_key        = ""
container_image                   = "europe-west1-docker.pkg.dev/fluid-417204/fluid-droplets/fluid-droplet-TEMPLATE-rails/web:latest"
container_db_url_production       = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production?host="
container_db_url_production_queue = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production_queue?host="
container_db_url_production_cache = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production_cache?host="
container_db_url_production_cable = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production_cable?host="

# cloud_run fluid droplet shiphero
cloud_run_app_name = "fluid-droplet-shiphero"
vpc_network_cloud_run = "fluid-egress-vpc"
vpc_subnet_cloud_run = "fluid-egress-vpc"

vpc_connector_cloud_run = ""
cloud_sql_instances_cloud_run = [
  "fluid-417204:europe-west1:fluid-droplet-TEMPLATE"
]
environment_variables_cloud_run = {
  "CABLE_DATABASE_URL"  = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production_cable?host=/cloudsql/fluid-417204:europe-west1:fluid-droplet-TEMPLATE",
  "CACHE_DATABASE_URL"  = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production_cache?host=/cloudsql/fluid-417204:europe-west1:fluid-droplet-TEMPLATE",
  "DATABASE_URL"        = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production?host=/cloudsql/fluid-417204:europe-west1:fluid-droplet-TEMPLATE",
  "QUEUE_DATABASE_URL"  = "postgresql://TEMPLATE_production_user:fxE6awibsevpgZzy@localhost/fluid_droplet_TEMPLATE_production_queue?host=/cloudsql/fluid-417204:europe-west1:fluid-droplet-TEMPLATE",
  "RACK_ENV"            = "production",
  "RAILS_ENV"           = "production",
  "RAILS_LOG_TO_STDOUT" = "enabled",
  "RAILS_MASTER_KEY"    = ""
}

# Postgres variables
postgres_password_production_user = ""
postgres_name_instance = "fluid-droplet-TEMPLATE"
postgres_name_database = "fluid_droplet_TEMPLATE_production"

# cloud run migrations
cloud_run_migrations_name = "fluid-droplet-TEMPLATE-migrations"