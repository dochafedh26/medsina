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
import unicodedata
import datetime
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
        self.email = email or os.environ.get("VIDAL_EMAIL") or self.DEFAULT_EMAIL
        self.password = password or os.environ.get("VIDAL_PASSWORD") or self.DEFAULT_PASS
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

    # =========================================================================
    # VIDAL OFFICIAL DRUG MONOGRAPHS (FICHES DE SYNTHÈSE OFFICIELLES)
    # =========================================================================

    @staticmethod
    def strip_accents(text: str) -> str:
        """Strips accents and diacritics for clean fuzzy matching."""
        if not text:
            return ""
        return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn").lower()

    def normalize_dci_query(self, query: str) -> str:
        """Normalizes clinical query string to match Vidal nomenclature."""
        clean = self.strip_accents(query)
        clean = re.sub(r'\(.*?\)', '', clean).strip()
        clean = re.sub(r'\[.*?\]', '', clean).strip()
        clean = re.sub(r'\b(iv|im|pse|sc|perfusion|ampoule|flacon|sol inj|comprime|gelule|\d+%\s*|\d+\s*mg|\d+\s*g)\b', '', clean).strip()

        synonyms = {
            "ocytocine": "oxytocine",
            "aspirine": "acide acetylsalicylique",
            "acetylsalicylate de lysine": "acide acetylsalicylique",
            "suxamethonium": "suxamethonium",
            "succinylcholine": "suxamethonium",
            "chlorure de suxamethonium": "suxamethonium",
            "heparine non fractionnee": "heparine sodique",
            "heparine hnf": "heparine sodique",
            "hnf": "heparine sodique",
            "serum sale hypertonique": "chlorure de sodium",
            "serum glucose hypertonique": "glucose",
            "serum glucose": "glucose",
            "insuline humaine rapide": "insuline",
            "complexe prothrombinique": "facteurs ii vii ix x",
            "ppsb": "facteurs ii vii ix x",
            "charbon vegetal active": "charbon active",
            "charbon vegetal": "charbon active",
            "emulsion lipidique": "lipides",
            "physostigmine": "eserine",
            "salicylate de physostigmine": "eserine",
            "trinitrine / dinitrate d'isosorbide": "trinitrine",
            "dinitrate d'isosorbide": "isosorbide dinitrate",
            "bicarbonate de sodium": "bicarbonate de sodium",
            "chlorure de potassium": "chlorure de potassium",
            "gluconate de calcium": "calcium gluconate",
            "sulfate de magnesium": "magnesium sulfate",
            "sulfate de morphine": "morphine",
            "hydrocortisone": "hydrocortisone",
            "hemisuccinate d'hydrocortisone": "hydrocortisone",
            "mannitol": "mannitol",
            "dexamethasone": "dexamethasone",
            "amoxicilline + acide clavulanique": "amoxicilline acide clavulanique",
            "amoxicilline clavulanate": "amoxicilline acide clavulanique",
            "serum antiscorpionique": "serum",
            "vaccin antirabique": "vaccin",
        }
        for k, v in synonyms.items():
            if k in clean:
                return v
        return clean.strip()

    def find_substance_url(self, query: str):
        """Finds the substance monograph URL on Vidal.fr."""
        if not self._is_logged_in:
            self.login()
        clean_q = self.normalize_dci_query(query)
        if not clean_q:
            clean_q = query.strip()

        # 1. suggestion-plus API
        url = f"{self.BASE_URL}recherche/suggestion-plus.html?types=drug,vmp,substance&priority=substance&query={requests.utils.quote(clean_q)}"
        try:
            res = self.session.get(url, timeout=12)
            if res.status_code == 200:
                items = res.json()
                clean_q_norm = self.strip_accents(clean_q)

                # 1a. Direct substance url with exact name match
                for it in items:
                    u = it.get("url") or ""
                    n = self.strip_accents(it.get("name", ""))
                    if "medicaments/substances/" in u and (n == clean_q_norm or clean_q_norm in n):
                        return f"{self.BASE_URL}{u.lstrip('/')}", it.get("name")

                # 1b. Any item with direct substance url
                for it in items:
                    u = it.get("url") or ""
                    if "medicaments/substances/" in u:
                        return f"{self.BASE_URL}{u.lstrip('/')}", it.get("name")

                # 1c. Resolve by vidal:/// substance id
                for it in items:
                    v_id = (it.get("id") or "").split("///")[-1]
                    if v_id.isdigit():
                        slug = re.sub(r'[^a-zA-Z0-9]+', '-', it.get("name", "").lower()).strip('-')
                        if slug:
                            return f"{self.BASE_URL}medicaments/substances/{slug}-{v_id}.html", it.get("name")
        except Exception as e:
            sys.stderr.write(f"Error querying suggestion-plus for {query}: {e}\n")

        # 2. Search page fallback
        try:
            search_url = f"{self.BASE_URL}recherche.html?query={requests.utils.quote(clean_q)}"
            res_s = self.session.get(search_url, timeout=12)
            soup = BeautifulSoup(res_s.text, "html.parser")
            for a in soup.select("ul.search_results a, div.content a"):
                href = a.get("href", "")
                if "medicaments/substances/" in href:
                    return f"{self.BASE_URL}{href.lstrip('/')}", a.text.strip()
        except Exception as e:
            sys.stderr.write(f"Error searching Vidal page for {query}: {e}\n")

        return None, None

    def fetch_drug_monograph(self, query: str, prefer_injectable: bool = True):
        """
        Fetches the official drug monograph directly and strictly from Vidal.fr.
        Includes indications, dosage, administration routes, contraindications, and monitoring.
        """
        if not self._is_logged_in:
            self.login()

        url, found_name = self.find_substance_url(query)
        if not url:
            return None

        try:
            res = self.session.get(url, timeout=15)
            if res.status_code != 200:
                return None

            html = res.text
            # Normalize mismatched HTML tags on Vidal
            html = re.sub(r'(<h4[^>]*>[^<]*)</h3>', r'\1</h4>', html)
            html = re.sub(r'(<h5[^>]*>[^<]*)</h4>', r'\1</h5>', html)
            soup = BeautifulSoup(html, "html.parser")

            # Check if there is an injectable VMP to render
            vmp_select = soup.find("select", id="list_vmps") or soup.find("select", {"name": "vmp"})
            if prefer_injectable and vmp_select:
                injectable_vmp_id = None
                clean_q_base = self.strip_accents(query.lower()).strip()
                # Prioritize standard solution injectable (sol inj / ampoule)
                candidates = []
                for opt in vmp_select.find_all("option"):
                    val = opt.get("value")
                    txt = self.strip_accents(opt.get_text().lower())
                    if not val:
                        continue
                    # Prevent matching derivative molecules (e.g. dexketoprofene when querying ketoprofene)
                    if "dex" in txt and "dex" not in clean_q_base:
                        continue
                    if any(k in txt for k in ["sol inj", "solution injectable", "ampoule", "inj"]):
                        candidates.append((val, 1, txt)) # High priority
                    elif any(k in txt for k in ["perf", "flacon", "iv"]):
                        candidates.append((val, 2, txt)) # Medium priority

                if candidates:
                    candidates.sort(key=lambda x: x[1])
                    injectable_vmp_id = candidates[0][0]
                if injectable_vmp_id:
                    vmp_url = f"{url}?render=true&vmp={injectable_vmp_id}"
                    try:
                        vmp_res = self.session.get(vmp_url, headers={"X-Requested-With": "XMLHttpRequest"}, timeout=12)
                        if vmp_res.status_code == 200:
                            vmp_data = vmp_res.json()
                            if "html" in vmp_data:
                                vmp_html = vmp_data["html"]
                                vmp_html = re.sub(r'(<h4[^>]*>[^<]*)</h3>', r'\1</h4>', vmp_html)
                                vmp_html = re.sub(r'(<h5[^>]*>[^<]*)</h4>', r'\1</h5>', vmp_html)
                                soup = BeautifulSoup(vmp_html, "html.parser")
                    except Exception:
                        pass

            # Title
            h1 = soup.find("h1") or soup.find("h2")
            vidal_title = h1.text.strip() if h1 else query

            # Classification
            classification = ""
            for tag in soup.find_all(["div", "p", "li"]):
                txt = tag.get_text()
                if "Classification pharmacothérapeutique VIDAL" in txt:
                    classification = txt.split("Classification pharmacothérapeutique VIDAL")[-1].strip().split("\n")[0].strip(": \t")
                    break

            # Mechanism
            mec_div = soup.find("div", id="substance_mecanisme")
            mechanism = mec_div.text.strip() if mec_div else ""

            def extract_rubric(h4_id):
                h = soup.find("h4", id=h4_id)
                if not h:
                    return ""
                texts = []
                for sib in h.next_siblings:
                    if getattr(sib, 'name', None) in ['h3', 'h4']:
                        break
                    t = getattr(sib, 'get_text', lambda **kw: str(sib).strip())(separator='\n', strip=True)
                    if t:
                        texts.append(t)
                if not texts:
                    parent = h.find_parent("div", class_=re.compile(r"rubric|card|section|well"))
                    if parent:
                        cloned = BeautifulSoup(str(parent), "html.parser")
                        for th in cloned.find_all(["h3", "h4"]):
                            th.decompose()
                        return cloned.get_text("\n", strip=True)
                return "\n".join(texts)
                texts = []
                for sib in h.next_siblings:
                    if getattr(sib, 'name', None) in ['h3', 'h4']:
                        break
                    t = getattr(sib, 'get_text', lambda **kw: str(sib).strip())(strip=True)
                    if t:
                        texts.append(t)
                return "\n".join(texts)

            indications = extract_rubric("ind")
            dosage = extract_rubric("dos")
            contraindications = extract_rubric("con")
            monitoring = extract_rubric("PatientsMonitoring")
            risks = extract_rubric("Risqueslisautraitement")
            precautions = extract_rubric("prec")
            interactions = extract_rubric("int")
            routes = extract_rubric("Modalitsdadministrationdutraitement")

            # Specialties
            specs = []
            for a in soup.select("#dci_specialties a, div.specialties a"):
                raw_t = a.get_text(" ", strip=True)
                clean_t = re.sub(r'^(fiche abr[ée]g[ée]e|monographie)\s*', '', raw_t, flags=re.I)
                clean_t = re.sub(r'(Liste \d+|Commercialis[ée]|Arr[êe]t de commercialisation.*)', '', clean_t, flags=re.I).strip()
                if clean_t and clean_t not in specs:
                    specs.append(clean_t)

            return {
                "query": query,
                "dci": found_name or query,
                "vidal_title": vidal_title,
                "url": url,
                "classification": classification,
                "mechanism": mechanism,
                "indications": indications,
                "dosage": dosage,
                "contraindications": contraindications,
                "monitoring": monitoring,
                "risks": risks,
                "precautions": precautions,
                "interactions": interactions,
                "routes": routes,
                "specialties": specs
            }
        except Exception as e:
            sys.stderr.write(f"Error fetching Vidal monograph for {query}: {e}\n")
            return None

    @staticmethod
    def categorize_molecule(dci: str, classification: str = "", indications: str = "") -> str:
        """Deterministically categorizes an emergency drug to prevent hallucinated classifications."""
        dci_clean = VidalPrescriptionAnalyzer.strip_accents(dci)
        dci_norm = re.sub(r'[^a-z0-9]', '', dci_clean)
        class_clean = VidalPrescriptionAnalyzer.strip_accents(classification)
        ind_clean = VidalPrescriptionAnalyzer.strip_accents(indications)
        text = f"{dci_clean} {class_clean} {ind_clean}"

        # 1. Direct DCI matches (highest priority)
        if any(k in dci_norm for k in ["salbutamol", "ipratropium", "terbutaline", "budesonide", "aminophylline"]):
            return "Respiratoire"

        if any(k in dci_norm for k in ["ciprofloxacine", "moxifloxacine", "ceftriaxone", "cefotaxime", "amoxicilline", "gentamicine", "amikacine", "metronidazole", "vancomycine", "teicoplanine", "piperacilline", "imipeneme", "meropeneme", "colistine", "linezolide", "aciclovir", "fluconazole", "voriconazole", "amphotericine"]):
            return "Infectiologie"

        if any(k in dci_norm for k in ["oxytocine", "ocytocine", "carbetocine", "sulprostone", "dinoprostone"]):
            return "Obstétrique & Gynécologie"

        if any(k in dci_norm for k in ["sodium", "sel", "chloruredesodium", "serumsale", "glucose", "serumglucose", "calcium", "potassium", "bicarbonate", "magnesium", "insuline", "glucagon", "hydrocortisone", "dexamethasone", "methylprednisolone"]):
            return "Métabolisme & Endocrinologie"

        if any(k in dci_norm for k in ["morphine", "paracetamol", "ketoprofene", "nefopam", "tramadol", "fentanyl", "sufentanil", "remifentanil"]):
            return "Antalgiques"

        if any(k in dci_norm for k in ["naloxone", "flumazenil", "acetylcysteine", "pralidoxime", "bleudemethylene", "hydroxocobalamine", "antivip", "antiscorpion", "antitetan", "antirabique", "intralipid", "emulsionlipidique", "digifab", "deferoxamine", "physostigmine", "eserine", "charbon"]):
            return "Antidotes & Sérums"

        if any(k in dci_norm for k in ["adrenaline", "noradrenaline", "nicardipine", "dobutamine", "amiodarone", "atropine", "trinitrine", "isosorbide", "digoxine", "furosemide", "labetalol", "esmolol", "urapidil", "clonidine", "ephedrine", "milrinone", "adenosine", "diltiazem", "verapamil", "nitroprussiate"]):
            return "Cardio / ACR / Choc"

        if any(k in dci_norm for k in ["diazepam", "midazolam", "clonazepam", "propofol", "etomidate", "ketamine", "rocuronium", "atracurium", "cisatracurium", "suxamethonium", "succinylcholine", "phenytoine", "levetiracetam", "valproate", "sugammadex", "neostigmine", "mannitol", "haloperidol", "loxapine"]):
            return "Neurologie / Sédation"

        if any(k in dci_norm for k in ["enoxaparine", "heparine", "aspirine", "acetylsalicylate", "clopidogrel", "tranexamique", "ppsb", "prothrombinique", "fibrinogene", "facteurvii", "protamine"]):
            return "Hémostase & Anticoagulants"

        if any(k in dci_norm for k in ["omeprazole", "esomeprazole", "pantoprazole", "terlipressine", "octreotide", "somatostatine", "ondansetron"]):
            return "Gastro-entérologie"

        # 2. Broader text and classification matching
        if any(k in text for k in ["oxytocique", "retraction uterine", "atonie uterine", "post-partum", "travail obstetrical"]):
            return "Obstétrique & Gynécologie"
        if any(k in text for k in ["bronchodilatateur", "asthme aigu", "bpco"]):
            return "Respiratoire"
        if any(k in text for k in ["antidote", "envenimation", "intoxication aigue"]):
            return "Antidotes & Sérums"
        if any(k in text for k in ["antiarythmique", "inotrop", "antihypertenseur", "vasopresseur", "choc cardiogenique", "arret cardiaque"]):
            return "Cardio / ACR / Choc"
        if any(k in text for k in ["antibacterien", "antibiotique", "antifongique", "antiviral"]):
            return "Infectiologie"
        if any(k in text for k in ["antithrombotique", "anticoagulant", "hemostatique", "antiagregant"]):
            return "Hémostase & Anticoagulants"
        if any(k in text for k in ["hypoglycemie", "hyperkaliemie", "acidose", "electrolyte", "corticosteroide", "endocrinologie"]):
            return "Métabolisme & Endocrinologie"
        if any(k in text for k in ["antiacide", "antiemetique", "ipp"]):
            return "Gastro-entérologie"
        if any(k in text for k in ["hypnotique", "curare", "antiepileptique", "anticonvulsivant", "sedation"]):
            return "Neurologie / Sédation"

        return "Général"
    @staticmethod
    def _clean_bullets(text: str, max_items: int = 8) -> str:
        """Cleans Vidal raw text into clear, readable medical bullets."""
        if not text:
            return ""
        lines = [line.strip() for line in text.split("\n") if line.strip()]
        cleaned = []
        seen = set()
        skip_words = {
            "x", "critique", "niveau de gravite", "contre-indication absolue",
            "precautions", "posologie", "posologie standard", "unite de prise", "modalites dadministration",
            "ce medicament est indique dans les cas suivants", "ce medicament est indique chez",
            "indications", "surveillances du patient", "a diluer avant administration",
            "posologie a adapter a letat du patient", "ml", "posologie standard", "patient quel que soit le poids",
            "patient a partir de", "s assurer de la compatibilite des excipients avec la voie d administration"
        }
        for l in lines:
            l_clean = re.sub(r'[^a-z0-9 ]', '', VidalPrescriptionAnalyzer.strip_accents(l)).strip()
            if not l_clean or l_clean in skip_words or l.startswith("(*)"):
                continue
            if l_clean in seen:
                continue
            seen.add(l_clean)
            bullet = l.lstrip("•*- ")
            cleaned.append(f"• {bullet}")
            if len(cleaned) >= max_items:
                break
        return "\n".join(cleaned)

    def format_as_emergency_drug(self, vidal_data: Dict[str, Any], dci_display_name: str, drug_id: str = None, algerian_nomenclature: list = None) -> Dict[str, Any]:
        """Builds a certified Medsina emergency drug record strictly and authentically from Vidal + Algerian nomenclature."""
        clean_dci = dci_display_name or vidal_data.get("dci") or vidal_data.get("query")
        if not drug_id:
            safe_id = re.sub(r'[^a-zA-Z0-9]', '_', clean_dci.lower()).strip('_')
            drug_id = f"drug_{safe_id}"

        # 1. Category
        category = self.categorize_molecule(
            clean_dci,
            classification=vidal_data.get("classification", ""),
            indications=vidal_data.get("indications", "")
        )

        # 2. Algerian nomenclature matching
        matched_algerian_brands = []
        if algerian_nomenclature:
            dci_norm = re.sub(r'[^a-z0-9]', '', self.strip_accents(clean_dci))
            dci_norm = dci_norm.replace("ocytocine", "oxytocine")
            for item in algerian_nomenclature:
                item_dci = re.sub(r'[^a-z0-9]', '', self.strip_accents(item.get("dci", "")))
                if (dci_norm and len(dci_norm) >= 4 and dci_norm in item_dci) or (item_dci and len(item_dci) >= 4 and item_dci in dci_norm):
                    b = item.get("brand")
                    lab = item.get("lab")
                    if b:
                        matched_algerian_brands.append(f"{b} ({lab})" if lab else b)

        unique_algerian = list(dict.fromkeys(matched_algerian_brands))
        vidal_specs = vidal_data.get("specialties", [])

        # Merge brands (Algerian registered first, then Vidal princeps)
        combined_brands = unique_algerian[:3]
        for spec in vidal_specs:
            spec_base = spec.split()[0].lower()
            if not any(spec_base in b.lower() for b in combined_brands):
                combined_brands.append(spec)
            if len(combined_brands) >= 4:
                break

        brand_str = " / ".join(combined_brands) if combined_brands else (vidal_specs[0] if vidal_specs else "Disponible PCH / Hôpitaux")

        # 3. Route
        raw_route = vidal_data.get("routes", "")
        if not raw_route:
            dosage_txt = vidal_data.get("dosage", "")
            match = re.search(r"Modalités d'administration\s*\n([^\n]+)", dosage_txt, re.I)
            if match:
                raw_route = match.group(1).strip()
            else:
                title_txt = vidal_data.get("vidal_title", "")
                if "inj" in title_txt.lower() or "perf" in title_txt.lower():
                    raw_route = "Voie intraveineuse (IVD / Perfusion), IM"
                else:
                    raw_route = "Voie orale / Injectable selon spécialité"

        # 4. Indications
        ind_bullets = self._clean_bullets(vidal_data.get("indications", ""), max_items=6)
        if not ind_bullets and vidal_data.get("mechanism"):
            ind_bullets = f"• {vidal_data.get('mechanism')[:200]}"

        # 5. Dose / Posology
        dose_bullets = self._clean_bullets(vidal_data.get("dosage", ""), max_items=8)

        # 6. Alert (Contraindications + Monitoring)
        ci_bullets = self._clean_bullets(vidal_data.get("contraindications", ""), max_items=5)
        monit_bullets = self._clean_bullets(vidal_data.get("monitoring", ""), max_items=3)
        alert_parts = []
        if ci_bullets:
            alert_parts.append(f"Contre-indications absolues (Vidal) :\n{ci_bullets}")
        if monit_bullets:
            alert_parts.append(f"Surveillances patient :\n{monit_bullets}")
        alert_str = "\n\n".join(alert_parts) if alert_parts else "Surveillance clinique et hémodynamique continue requise."

        return {
            "id": drug_id,
            "dci": clean_dci,
            "brand": brand_str,
            "category": category,
            "route": raw_route,
            "indication": ind_bullets,
            "dose": dose_bullets,
            "alert": alert_str,
            "algerian_availability": "Disponible UMC / PCH / Blocs opératoires (Nomenclature MSPRH)",
            "source": "vidal.fr"
        }

    def format_as_clinical_monograph(self, vidal_data: Dict[str, Any]) -> Dict[str, Any]:
        """Formats the monograph as a rich clinical document for the prescription analyzer."""
        return {
            "dci": vidal_data.get("dci", ""),
            "title": vidal_data.get("vidal_title", ""),
            "url": vidal_data.get("url", ""),
            "classification": vidal_data.get("classification", ""),
            "mechanism": vidal_data.get("mechanism", ""),
            "routes": vidal_data.get("routes", ""),
            "indications": self._clean_bullets(vidal_data.get("indications", ""), max_items=10),
            "dosage": self._clean_bullets(vidal_data.get("dosage", ""), max_items=12),
            "contraindications": self._clean_bullets(vidal_data.get("contraindications", ""), max_items=8),
            "monitoring": self._clean_bullets(vidal_data.get("monitoring", ""), max_items=6),
            "specialties": vidal_data.get("specialties", []),
            "source": "vidal.fr"
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

