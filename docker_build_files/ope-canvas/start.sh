#!/bin/bash
set -e

touch /usr/src/app/log/app_starting

APP_DIR=/usr/src/app

# Make sure the initial database is setup for canvas
export PGPASSWORD=$IT_PW;

# Make sure the database has a chance to come online
db_online=0
until [ $db_online -eq 1 ]
do
	echo "waiting for database..."
	sleep 1
	db_online=1  # Gets set back to 0 if the db connection fails
	psql -U postgres -h postgresql -tc "select 1" | grep -q 1 || db_online=0
done


#createuser --superuser canvas
psql -U postgres -h postgresql -tc "select 1 from pg_database where datname='canvas_$RAILS_ENV'" | grep -q 1 || createdb -U postgres -h postgresql -E UTF-8 -T template0 --lc-collate=en_US.UTF-8 --lc-ctype=en_US.UTF-8 --owner postgres canvas_$RAILS_ENV
psql -U postgres -h postgresql -tc "select 1 from pg_database where datname='canvas_queue'" | grep -q 1 || createdb -U postgres -h postgresql -E UTF-8 -T template0 --lc-collate=en_US.UTF-8 --lc-ctype=en_US.UTF-8 --owner postgres canvas_queue

# Make sure canvas is init
export CANVAS_LMS_ADMIN_EMAIL=$ADMIN_EMAIL
export CANVAS_LMS_ADMIN_PASSWORD=$IT_PW
export CANVAS_LMS_ACCOUNT_NAME=$LMS_ACCOUNT_NAME
export CANVAS_LMS_STATS_COLLECTION="opt_out"

cd $APP_DIR

sed -i "s/EMAIL_DELIVERY_METHOD/${EMAIL_DELIVERY_METHOD-test}/" config/outgoing_mail.yml
sed -i "s/SMTP_ADDRESS/${SMTP_ADDRESS-localhost}/" config/outgoing_mail.yml
sed -i "s/SMTP_PORT/${SMTP_PORT-25}/" config/outgoing_mail.yml
sed -i "s/SMTP_USER/${SMTP_USER-}/" config/outgoing_mail.yml
sed -i "s/SMTP_PASS/${SMTP_PASS-}/" config/outgoing_mail.yml

cp config/domain.yml.tmpl config/domain.yml
sed -i -- "s/<VIRTUAL_HOST>/$VIRTUAL_HOST/g" config/domain.yml
sed -i -- "s/<IT_PW>/$IT_PW/g" config/database.yml

cp config/security.yml.tmpl config/security.yml
sed -i -- "s/<CANVAS_SECRET>/$CANVAS_SECRET/g" config/security.yml

# Change the shard ID so that we can use that space to sync servers
sed -i -- "s/10_000_000_000_000/1_000_000_000_000_000_000/g" $GEM_HOME/gems/switchman-*/app/models/switchman/shard_internal.rb
 #IDS_PER_SHARD = 10_000_000_000_000
 #IDS_PER_SHARD =  1_000_000_000_000_000_000
                 #   30_578_000_000_000_005
				 
# Need to adjust the partitions values for version tables - tables aren't created when they should be with very large ids
sed -i -- "s/5_000_000/1_000_000_000_000_000_000/g" $APP_DIR/config/initializers/simply_versioned.rb
# Constraint gets altered during ope:startup

# This will change, make sure to deal with it
$GEM_HOME/bin/bundle exec rake db:reset_encryption_key_hash

# Generate the initial db if a table called versions doesn't already exist
count=`psql -d canvas_$RAILS_ENV -U postgres -h postgresql -tqc "select count(tablename) as count from pg_tables where tablename='versions'"`
#psql -d canvas_$RAILS_ENV -U postgres -h postgresql -tc "select 1 from pg_tables where tablename='versions'" | grep -q 1 || $GEM_HOME/bin/bundle exec rake db:initial_setup
if [ $count != '1' ]; then
    # Run initial setup
    $GEM_HOME/bin/bundle exec rake db:initial_setup
    $GEM_HOME/bin/bundle exec rake canvas:compile_assets
fi

# Setup auditing, sequence range, db migrate and compile assets if needed
$GEM_HOME/bin/bundle exec rake ope:startup --trace


# This is run by supervisord 
#$GEM_HOME/bin/bundle exec rails server

# Adding dev key?
#psql -U canvas -d canvas_development -c "INSERT INTO developer_keys (api_key, email, name, redirect_uri) VALUES ('test_developer_key', 'canvas@example.edu', 'Canvas Docker', 'http://localhost:8000');"

# 'crypted_token' value is hmac sha1 of 'canvas-docker' using default config/security.yml encryption_key value as secret
#psql -U canvas -d canvas_development -c "INSERT INTO access_tokens (created_at, crypted_token, developer_key_id, purpose, token_hint, updated_at, user_id) SELECT now(), '4bb5b288bb301d3d4a691ebff686fc67ad49daa8', dk.id, 'canvas-docker', '', now(), 1 FROM developer_keys dk where dk.email = 'canvas@example.edu';"


# Make sure this is all owned by the correct user
#echo "setting permissions..."
#chown -R docker:docker $APP_DIR

rm -f /usr/src/app/log/app_starting

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf