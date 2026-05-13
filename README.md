# 2: QC script

# Basic run on single machine
python qc_from_db.py

# Specify custom DB and output
python qc_from_db.py --db ia_crawler.db --output my_clean.json --workers 16

# Distributed run (machine 0 of 4)
python qc_from_db.py --shard 0 --total-shards 4 --output clean_jobs.json

# Machine 1 of 4
python qc_from_db.py --shard 1 --total-shards 4 --output clean_jobs.json

# After all shards finish, merge them:
jq -s 'add' clean_jobs_shard*.json > clean_jobs.json
