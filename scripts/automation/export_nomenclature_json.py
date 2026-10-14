import openpyxl
import json

wb = openpyxl.load_workbook('assets/clean_NOMENCLATURE.VERSION.AOUT_.2026-.xlsx', read_only=True)
ws = wb['Nomenclature Aout 2026']

products = []
for r in ws.iter_rows(values_only=True, min_row=17):
    if not any(r):
        continue
    num = r[0]
    reg_num = str(r[1] or '').strip()
    code = str(r[2] or '').strip()
    dci = str(r[3] or '').strip().upper()
    brand = str(r[4] or '').strip().upper()
    form = str(r[5] or '').strip()
    dosage = str(r[6] or '').strip()
    packaging = str(r[7] or '').strip()
    liste = str(r[8] or '').strip()
    lab = str(r[12] or '').strip()
    pays = str(r[13] or '').strip()
    type_p = str(r[16] or '').strip()
    status = str(r[17] or '').strip()

    if dci or brand:
        products.append({
            'num': num,
            'regNum': reg_num,
            'code': code,
            'dci': dci,
            'brand': brand,
            'form': form,
            'dosage': dosage,
            'packaging': packaging,
            'liste': liste,
            'lab': lab,
            'pays': pays,
            'type': type_p,
            'status': status
        })

print(f"Loaded {len(products)} products from Nomenclature Aout 2026.")

with open('assets/data/algerian_nomenclature.json', 'w', encoding='utf-8') as f:
    json.dump(products, f, ensure_ascii=False, indent=2)

print("Saved assets/data/algerian_nomenclature.json")

