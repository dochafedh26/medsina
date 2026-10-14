#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Medsina - Vidal Prescription & Drug Interaction Analyzer
Automates prescription validation using Vidal Pro authentication and IAM APIs.
"""

import sys
import os
import json
import re
import argparse
import xml.etree.ElementTree as ET
import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util import Retry

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

class VidalPrescriptionAnalyzer:
    DEFAULT_EMAIL = "doc.hafedh14@gmail.com"
    DEFAULT_PASS = "MyNewPass@2024"
    BASE_URL = "https://www.vidal.fr/"

    SEVERITY_MAP = {
        "LEVEL_4": {
            "level": 4,
            "code": "CONTRAINDICATED",
            "label": "Contre-indication",
            "icon": "🔴",
            "color": "#DC2626"
        },
        "LEVEL_3": {
            "level": 3,
            "code": "DISADVISED",
            "label": "Association déconseillée",
            "icon": "🟠",
            "color": "#EA580C"
        },
        "LEVEL_2": {
            "level": 2,
            "code": "PRECAUTION",
            "label": "Précaution d'emploi",
            "icon": "🟡",
            "color": "#D97706"
        },
        "LEVEL_1": {
            "level": 1,
            "code": "INFO",
            "label": "À prendre en compte",
            "icon": "🔵",
            "color": "#2563EB"
        },
        "INFO": {
            "level": 0,
            "code": "INFO",
            "label": "Information",
            "icon": "ℹ️",
            "color": "#6B7280"
        }
    }

    def __init__(self, email=None, password=None):
        self.email = email or self.DEFAULT_EMAIL
        self.password = password or self.DEFAULT_PASS
        self.session = requests.Session()
        retries = Retry(total=3, backoff_factor=0.5, status_forcelist=[500, 502, 503, 504])
        adapter = HTTPAdapter(max_retries=retries)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7"
        })
        self._is_logged_in = False

    def login(self):
        """Authenticates with Vidal Pro account."""
        if self._is_logged_in:
            return True
        try:
            login_init_url = f"{self.BASE_URL}login.html?redirect=https%3A%2F%2Fwww.vidal.fr%2Fanalyse-ordonnance.html%3Ftab%3D2"
            res_init = self.session.get(login_init_url, timeout=12)
            
            login_data = {
                "login[email]": self.email,
                "login[password]": self.password,
                "login[submit]": "Se connecter"
            }
            res_login = self.session.post(res_init.url, data=login_data, timeout=15)
            self._is_logged_in = (res_login.status_code == 200)
            return self._is_logged_in
        except Exception as e:
            sys.stderr.write(f"Vidal login error: {e}\n")
            return False

    def search_drug(self, query):
        """Searches Vidal catalog for matching drug or VMP/DCI."""
        if not self._is_logged_in:
            self.login()
        clean_q = query.strip()
        if not clean_q:
            return []
        url = f"{self.BASE_URL}recherche/suggestion-plus.html?types=drug,vmp&priority=vmp&query={requests.utils.quote(clean_q)}"
        try:
            res = self.session.get(url, timeout=12)
            if res.status_code == 200:
                data = res.json()
                return data
            return []
        except Exception as e:
            sys.stderr.write(f"Error searching drug '{query}': {e}\n")
            return []

    def analyze_prescription(self, drug_queries):
        """
        Accepts a list of drug query strings (e.g. ['sintrom', 'rifampicine']),
        resolves each to Vidal product IDs, and queries the IAM alerts API.
        """
        if not self._is_logged_in:
            if not self.login():
                return {"error": "Failed to log in to Vidal"}

        resolved_drugs = []
        unresolved_queries = []

        for q in drug_queries:
            results = self.search_drug(q)
            if results:
                # Prefer exact match or first result
                best = results[0]
                resolved_drugs.append({
                    "query": q,
                    "id": best.get("id"),
                    "name": best.get("name"),
                    "type": best.get("type"),
                    "url": best.get("url")
                })
            else:
                unresolved_queries.append(q)

        if len(resolved_drugs) < 2:
            return {
                "resolvedDrugs": resolved_drugs,
                "unresolvedQueries": unresolved_queries,
                "interactions": [],
                "warnings": [],
                "sideEffects": [],
                "redundancies": [],
                "message": "Au moins 2 médicaments résolus sont requis pour détecter des interactions médicamenteuses."
            }

        # Construct Vidal Prescription XML
        xml_lines = "".join(f"<prescription-line><drug>{d['id']}</drug></prescription-line>" for d in resolved_drugs)
        xml_payload = f"<prescription><patient></patient><prescription-lines>{xml_lines}</prescription-lines></prescription>"

        try:
            alerts_url = f"{self.BASE_URL}outils/iam/alerts.html"
            res = self.session.post(
                alerts_url,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                data={"prescription": xml_payload},
                timeout=18
            )

            if res.status_code != 200:
                return {"error": f"Vidal IAM API returned status {res.status_code}"}

            return self._parse_alerts_xml(res.text, resolved_drugs, unresolved_queries)
        except Exception as e:
            return {"error": f"Error querying Vidal IAM: {e}"}

    def _parse_alerts_xml(self, xml_text, resolved_drugs, unresolved_queries):
        """Parses the Atom XML returned by Vidal IAM."""
        ns = {
            'atom': 'http://www.w3.org/2005/Atom',
            'vidal': 'http://api.vidal.net/-/spec/vidal-api/1.0/'
        }
        try:
            root = ET.fromstring(xml_text)
        except Exception as e:
            return {"error": f"XML parse error: {e}"}

        interactions = []
        redundancies = []
        warnings = []
        side_effects = []

        for entry in root.findall('atom:entry', ns):
            cat = entry.attrib.get('{http://api.vidal.net/-/spec/vidal-api/1.0/}categories', '')
            t_node = entry.find('vidal:type', ns)
            entry_type = t_node.text if t_node is not None else ""

            title_node = entry.find('atom:title', ns)
            title = title_node.text.strip() if title_node is not None and title_node.text else ""

            content_node = entry.find('atom:content', ns)
            content_html = content_node.text.strip() if content_node is not None and content_node.text else ""

            # Clean HTML text
            content_clean = re.sub(r'<[^>]+>', ' ', content_html).strip()
            content_clean = re.sub(r'\s+', ' ', content_clean)

            sev_node = entry.find('vidal:severity', ns)
            raw_severity = sev_node.text.strip() if sev_node is not None and sev_node.text else "INFO"
            sev_info = self.SEVERITY_MAP.get(raw_severity, self.SEVERITY_MAP["INFO"])

            risk_node = entry.find('vidal:risksAndMechanisms', ns)
            risk = risk_node.text.strip() if risk_node is not None and risk_node.text else ""

            mgmt_node = entry.find('vidal:management', ns)
            mgmt = mgmt_node.text.strip() if mgmt_node is not None and mgmt_node.text else ""

            if entry_type == 'DRUG_INTERACTION':
                interactions.append({
                    "title": title,
                    "severity": raw_severity,
                    "severityLevel": sev_info["level"],
                    "severityCode": sev_info["code"],
                    "severityLabel": sev_info["label"],
                    "icon": sev_info["icon"],
                    "color": sev_info["color"],
                    "content": content_clean,
                    "risksAndMechanisms": risk,
                    "management": mgmt,
                })
            elif entry_type == 'REDUNDANCY':
                redundancies.append({
                    "title": title,
                    "content": content_clean,
                    "severity": raw_severity,
                    "severityLabel": sev_info["label"],
                })
            elif entry_type in ['CONTRA_INDICATION', 'PRECAUTION', 'WARNING']:
                warnings.append({
                    "type": entry_type,
                    "title": title,
                    "content": content_clean,
                    "severity": raw_severity,
                    "severityLabel": sev_info["label"],
                })
            elif entry_type == 'SIDE_EFFECT':
                side_effects.append({
                    "title": title,
                    "content": content_clean,
                })

        # Sort interactions by severity descending (Level 4 first, then Level 3, 2, 1)
        interactions.sort(key=lambda x: x["severityLevel"], reverse=True)

        return {
            "status": "success",
            "resolvedDrugs": resolved_drugs,
            "unresolvedQueries": unresolved_queries,
            "interactionCount": len(interactions),
            "interactions": interactions,
            "redundancies": redundancies,
            "warningsCount": len(warnings),
            "warnings": warnings,
            "sideEffectsCount": len(side_effects),
            "hasCriticalAlerts": any(i["severityLevel"] >= 3 for i in interactions),
        }

def main():
    parser = argparse.ArgumentParser(description="Medsina Vidal Prescription Analyzer")
    parser.add_argument("--drugs", "-d", nargs="+", required=True, help="List of drug names or DCIs (e.g. sintrom rifampicine)")
    parser.add_argument("--json", action="store_true", help="Output pure JSON")
    args = parser.parse_args()

    analyzer = VidalPrescriptionAnalyzer()
    report = analyzer.analyze_prescription(args.drugs)

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("=" * 60)
        print("MEDSINA - RAPPORT D'ANALYSE D'ORDONNANCE (MOTEUR VIDAL)")
        print("=" * 60)
        print("\nMédicaments analysés :")
        for d in report.get("resolvedDrugs", []):
            print(f"  ✓ {d['name']} ({d['type']})")
        for q in report.get("unresolvedQueries", []):
            print(f"  ✗ Non résolu : {q}")

        interactions = report.get("interactions", [])
        print(f"\nInteractions Médicamenteuses Détectées : {len(interactions)}")
        print("-" * 60)
        if not interactions:
            print("Aucune interaction médicamenteuse détectée entre ces molécules.")
        for i, inter in enumerate(interactions, 1):
            print(f"\n{i}. {inter['icon']} [{inter['severityLabel']}] {inter['title']}")
            if inter['risksAndMechanisms']:
                print(f"   ⚠️ Risque / Mécanisme : {inter['risksAndMechanisms']}")
            if inter['management']:
                print(f"   💡 Conduite à tenir : {inter['management']}")

        print("\n" + "=" * 60)

if __name__ == "__main__":
    main()

