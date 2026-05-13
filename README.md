# 1: ia scraper
# Step 1 – run the power crawler

QUERY = '(cd OR "cd rip" OR "lossless rip") AND mediatype:(audio) AND (format:flac)'

# Choose one of:
#   "--search-only"   – only discover identifiers (no metadata fetch)
#   "--harvest-only"  – only fetch metadata for already discovered identifiers
#   "--export-json"   – export current file list to JSON and exit
#   ""                – full crawl (search + harvest)

# Optional: reset database before run? (caution: deletes all progress)
# MODE = "--reset"   # use with care, usually not needed

=> best to start for first time with no options 


# 2: QC script (multi machine optimized, takes the scraped database and returns jobs)
-> sharded, multi machine support

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

# 3: downloader (single machine optimized, takes a json)
Download and re-encode all to 16/44.1 FLAC level 4
python ia_downloader_robust.py clean_jobs.json --reencode --workers 8
