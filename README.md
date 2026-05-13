# 2: QC script

# Single machine (no sharding)
python qc_robust.py --db ia_crawler.db --output clean_jobs.jsonl

# Worker 0 of 4 (on machine A)
python qc_robust.py --shard 0 --total-shards 4 --state-dir /mnt/nfs/qc_state

# Worker 1 of 4 (on machine B)
python qc_robust.py --shard 1 --total-shards 4 --state-dir /mnt/nfs/qc_state

# Merge all JSONL shards into a single JSON array
python -c "
import json, glob
jobs = []
for f in glob.glob('clean_jobs_shard*.jsonl'):
    with open(f) as inf:
        jobs.extend(json.loads(line) for line in inf)
json.dump(jobs, open('clean_jobs.json', 'w'))
"
