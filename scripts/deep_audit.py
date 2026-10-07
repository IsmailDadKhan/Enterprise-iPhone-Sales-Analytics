import sys, csv, collections
sys.stdout.reconfigure(encoding='utf-8')
from datetime import datetime

with open('iphone_transactions.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    rows = [r for r in reader if r['Tranid'].strip()]

print(f"=== DEEP DATA AUDIT ({len(rows)} valid records) ===")

# 1. Duplicate Transaction IDs
tranids = [r['Tranid'] for r in rows]
dupes = {k: v for k, v in collections.Counter(tranids).items() if v > 1}
print(f"\n--- 1. DUPLICATE TRANSACTION IDS ---")
print(f"Unique Tranids: {len(set(tranids))}")
print(f"Duplicate Tranids: {len(dupes)}")
if dupes:
    for tid, cnt in sorted(dupes.items(), key=lambda x: -x[1])[:10]:
        # Show details of dupes
        dupe_rows = [r for r in rows if r['Tranid'] == tid]
        print(f"  {tid}: appears {cnt} times")
        for dr in dupe_rows:
            print(f"    Date={dr['Trandate']} Entity={dr['Entity']} Type={dr['Type']} Qty={dr['Quantity']} Item={dr['Item_ID']} Amt={dr['Amount']}")

# 2. Negative / Zero values
print(f"\n--- 2. NEGATIVE / ZERO VALUE CHECK ---")
neg_qty = [r for r in rows if int(r['Quantity']) < 0]
zero_qty = [r for r in rows if int(r['Quantity']) == 0]
neg_price = [r for r in rows if float(r['Unit_Price']) < 0]
zero_price = [r for r in rows if float(r['Unit_Price']) == 0]
print(f"Negative Quantity rows: {len(neg_qty)}")
print(f"Zero Quantity rows: {len(zero_qty)}")
print(f"Negative Unit_Price rows: {len(neg_price)}")
print(f"Zero Unit_Price rows: {len(zero_price)}")
if neg_qty:
    print("  Sample negative qty:")
    for r in neg_qty[:3]:
        print(f"    {r['Tranid']} Type={r['Type']} Qty={r['Quantity']} Amt={r['Amount']}")

# 3. Date anomalies
print(f"\n--- 3. DATE ANOMALIES ---")
future = 0
inv_after_tran = 0
for r in rows:
    td = datetime.strptime(r['Trandate'], '%Y-%m-%d')
    lid = datetime.strptime(r['LastInvDate'], '%Y-%m-%d')
    if td > datetime(2026, 9, 9):
        future += 1
    if lid > td:
        inv_after_tran += 1
print(f"Dates after Sep 9, 2026 (outside stated range): {future}")
print(f"LastInvDate AFTER Trandate (logically suspect): {inv_after_tran}")

# 4. Transaction Type breakdown by sign
print(f"\n--- 4. TRANSACTION TYPE VS QUANTITY SIGN ---")
type_stats = collections.defaultdict(lambda: {'pos': 0, 'neg': 0, 'zero': 0, 'total_qty': 0, 'total_amt': 0.0})
for r in rows:
    t = r['Type']
    q = int(r['Quantity'])
    a = float(r['Amount'])
    if q > 0: type_stats[t]['pos'] += 1
    elif q < 0: type_stats[t]['neg'] += 1
    else: type_stats[t]['zero'] += 1
    type_stats[t]['total_qty'] += q
    type_stats[t]['total_amt'] += a
for t, s in sorted(type_stats.items()):
    print(f"  {t}: positive={s['pos']} negative={s['neg']} zero={s['zero']} totalQty={s['total_qty']:,} totalAmt=${s['total_amt']:,.2f}")

# 5. Item_ID join coverage
print(f"\n--- 5. ITEM_ID JOIN COVERAGE ---")
with open('product_master.csv', 'r', encoding='utf-8') as f2:
    pm_reader = csv.DictReader(f2)
    pm_ids = set(r['Item_ID'] for r in pm_reader)
trans_ids = set(r['Item_ID'] for r in rows)
unmatched = trans_ids - pm_ids
orphan_master = pm_ids - trans_ids
print(f"Unique Item_IDs in transactions: {len(trans_ids)}")
print(f"Unique Item_IDs in product master: {len(pm_ids)}")
print(f"Transaction IDs NOT in Product Master (LEFT JOIN nulls): {len(unmatched)}")
if unmatched:
    for u in sorted(unmatched):
        cnt = sum(1 for r in rows if r['Item_ID'] == u)
        print(f"  {u} ({cnt} transactions)")
print(f"Product Master IDs with ZERO transactions (orphan SKUs): {len(orphan_master)}")
if orphan_master:
    for o in sorted(orphan_master):
        print(f"  {o}")

# 6. Quantity distribution & outliers
print(f"\n--- 6. QUANTITY OUTLIER CHECK ---")
quantities = sorted([int(r['Quantity']) for r in rows])
print(f"Min: {quantities[0]}, Max: {quantities[-1]}")
print(f"Mean: {sum(quantities)/len(quantities):.1f}")
print(f"Median: {quantities[len(quantities)//2]}")
# Top 5 largest orders
print("Top 5 largest single orders:")
by_qty = sorted(rows, key=lambda r: int(r['Quantity']), reverse=True)
for r in by_qty[:5]:
    print(f"  {r['Tranid']} Entity={r['Entity']} Qty={r['Quantity']} Item={r['Item_ID']} Amt=${float(r['Amount']):,.2f}")

# 7. Unit Price range check
print(f"\n--- 7. UNIT PRICE RANGE CHECK ---")
prices = sorted([float(r['Unit_Price']) for r in rows])
print(f"Min price: ${prices[0]:,.2f}, Max price: ${prices[-1]:,.2f}")
print(f"Mean: ${sum(prices)/len(prices):,.2f}")
# Check if any price seems unreasonable for iPhones (< $300 or > $2000)
suspicious_low = [r for r in rows if float(r['Unit_Price']) < 300]
suspicious_high = [r for r in rows if float(r['Unit_Price']) > 2000]
print(f"Prices below $300 (suspiciously low for iPhone): {len(suspicious_low)}")
print(f"Prices above $2000 (suspiciously high for iPhone): {len(suspicious_high)}")

# 8. Entity-Country consistency
print(f"\n--- 8. ENTITY-COUNTRY CONSISTENCY ---")
entity_countries = collections.defaultdict(set)
for r in rows:
    entity_countries[r['Entity']].add(r['Country'])
multi_country = {e: c for e, c in entity_countries.items() if len(c) > 1}
print(f"Entities operating across multiple countries: {len(multi_country)}")
for e, c in multi_country.items():
    print(f"  {e}: {sorted(c)}")

# 9. Entity-Subsidiary consistency
print(f"\n--- 9. ENTITY-SUBSIDIARY CONSISTENCY ---")
entity_subs = collections.defaultdict(set)
for r in rows:
    entity_subs[r['Entity']].add(r['Subsidiary'])
multi_sub = {e: s for e, s in entity_subs.items() if len(s) > 1}
print(f"Entities linked to multiple subsidiaries: {len(multi_sub)}")
for e, s in multi_sub.items():
    print(f"  {e}: {sorted(s)}")

print("\n=== AUDIT COMPLETE ===")
