import sys
import os
import json
import datetime
import requests

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

from vidal_prescription_analyzer import VidalPrescriptionAnalyzer

def main():
    print("=======================================================")
    print("🔄 REBUILDING 100% OF EMERGENCY DRUGS FROM VIDAL.FR")
    print("=======================================================")

    analyzer = VidalPrescriptionAnalyzer()
    if not analyzer.login():
        print("❌ Impossible de se connecter à Vidal.fr. Arrêt.")
        return

    drugs_path = "assets/data/emergency_drugs_algeria.json"
    nomen_path = "assets/data/algerian_nomenclature.json"

    with open(drugs_path, "r", encoding="utf-8") as f:
        existing_drugs = json.load(f)

    with open(nomen_path, "r", encoding="utf-8") as f:
        nomen = json.load(f)

    # Supabase credentials
    from medsina_agent import SupabaseClient, _resolve_supabase_key, DEFAULT_SUPABASE_URL
    supa_key = _resolve_supabase_key()
    supabase = SupabaseClient(DEFAULT_SUPABASE_URL, supa_key) if supa_key else None

    # Query mapping overrides for special emergency solutions
    query_map = {
        "drug_chlorure_sodium_hypertonique": "chlorure de sodium",
        "drug_glucose_30_50": "glucose",
        "drug_heparine_hnf": "heparine sodique",
        "drug_aspirine_iv": "acide acetylsalicylique",
        "drug_physostigmine": "eserine",
        "drug_ppsb": "facteurs ii vii ix x",
        "drug_emulsion_lipidique": "lipides",
        "drug_charbon_active": "charbon active",
        "drug_vitamine_k1": "phytomenadione",
        "drug_vaccin_antirabique_serum": "vaccin rabique",
    }

    updated_drugs = []
    success_count = 0
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()

    for idx, d in enumerate(existing_drugs, 1):
        drug_id = d.get("id")
        dci = d.get("dci")
        search_query = query_map.get(drug_id, dci)

        print(f"\n[{idx:02d}/{len(existing_drugs)}] Processing {dci} (query: {search_query})...")
        mono = analyzer.fetch_drug_monograph(search_query, prefer_injectable=True)

        if not mono:
            # Fallback retry with raw query
            mono = analyzer.fetch_drug_monograph(dci, prefer_injectable=True)

        if mono:
            clean_rec = analyzer.format_as_emergency_drug(
                mono,
                dci_display_name=dci,
                drug_id=drug_id,
                algerian_nomenclature=nomen
            )
            clean_rec["created_at"] = d.get("created_at") or now_iso
            clean_rec["updated_at"] = now_iso

            # Ensure algerianAvailability
            clean_rec["algerianAvailability"] = clean_rec["algerian_availability"]

            print(f"   ✅ Vidal: {mono.get('dci')} -> Cat: {clean_rec['category']} | Brands: {clean_rec['brand'][:60]}...")
            updated_drugs.append(clean_rec)
            success_count += 1

            # Sync to remote Supabase if available
            if supabase:
                supa_rec = {
                    "id": clean_rec["id"],
                    "dci": clean_rec["dci"],
                    "brand": clean_rec["brand"],
                    "category": clean_rec["category"],
                    "route": clean_rec["route"],
                    "indication": clean_rec["indication"],
                    "dose": clean_rec["dose"],
                    "alert": clean_rec["alert"],
                    "algerian_availability": clean_rec["algerian_availability"],
                    "created_at": clean_rec["created_at"],
                    "updated_at": clean_rec["updated_at"],
                }
                supabase.post("emergency_drugs", supa_rec, upsert=True)
        else:
            print(f"   ⚠️ Vidal monograph not found for {dci}. Preserving existing record.")
            d["updated_at"] = now_iso
            updated_drugs.append(d)

    # Save to local JSON
    with open(drugs_path, "w", encoding="utf-8") as f:
        json.dump(updated_drugs, f, indent=2, ensure_ascii=False)

    print("\n=======================================================")
    print(f"🎉 COMPLETED: {success_count} / {len(existing_drugs)} emergency drugs rebuilt strictly from Vidal.fr!")
    print(f"💾 Updated {drugs_path}")
    print("=======================================================")

if __name__ == "__main__":
    main()

