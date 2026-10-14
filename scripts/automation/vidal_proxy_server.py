#!/usr/bin/env python3
"""
Medsina Platform - Vidal Backend Proxy & Auto-Enrichment Server
Production-grade rate-limiting proxy with anti-ban queue & self-enriching Supabase cache.

Features:
1. Singleton Mutex (Threading Lock): Exactly 1 request to Vidal at a time.
2. Anti-Ban Throttling: Strict cooldown between requests.
3. Cache-First: Checks Supabase `vidal_drug_interactions` first.
4. Auto-Enrichment: Newly discovered Vidal interactions are automatically saved to Supabase.
5. REST API: Exposes POST /api/analyze-prescription for client apps or edge functions.
"""

import os
import sys
import time
import json
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
from pathlib import Path
from typing import List, Dict, Any

try:
    import requests
except ImportError:
    print("Error: requests is required. Run 'pip install requests'.", file=sys.stderr)
    sys.exit(1)

# Import analyzer methods from local script
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from vidal_prescription_analyzer import VidalPrescriptionAnalyzer

DEFAULT_SUPABASE_URL = "https://qzfssrhhuorljftpdvjm.supabase.co"
SUPABASE_URL = os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL).rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or os.environ.get("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6ZnNzcmhodW9ybGpmdHBkdmptIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTYxMjg1NCwiZXhwIjoyMTA3MTg4ODU0fQ.-KCUgZdY8RDUwvNOUAabDhQFwv5FFGHYz0J-dM7Cic4")

# Rate limiting Mutex
VIDAL_LOCK = threading.Lock()
LAST_VIDAL_CALL_TIME = 0.0
MIN_DELAY_SECONDS = 1.0  # Safe delay between Vidal calls

# Global singleton analyzer
GLOBAL_ANALYZER = None

def get_vidal_analyzer():
    global GLOBAL_ANALYZER
    if GLOBAL_ANALYZER is None:
        GLOBAL_ANALYZER = VidalPrescriptionAnalyzer()
        GLOBAL_ANALYZER.login()
    return GLOBAL_ANALYZER


def check_supabase_for_interactions(drug_names: List[str]) -> List[Dict[str, Any]]:
    """Checks if known interactions exist in Supabase for the given drug list."""
    if not SUPABASE_KEY:
        return []

    try:
        endpoint = f"{SUPABASE_URL}/rest/v1/vidal_drug_interactions?select=*"
        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}"
        }
        resp = requests.get(endpoint, headers=headers, timeout=5)
        if resp.status_code == 200:
            rules = resp.json()
            matches = []
            upper_drugs = [d.strip().upper() for d in drug_names]
            for r in rules:
                drug_a = [x.upper() for x in r.get("drug_a", [])]
                drug_b = [x.upper() for x in r.get("drug_b", [])]
                
                # Forward match
                match_a = any(any(d in pat or pat in d for pat in drug_a) for d in upper_drugs)
                match_b = any(any(d in pat or pat in d for pat in drug_b) for d in upper_drugs)
                
                # Cross match (two distinct drugs)
                if match_a and match_b and len(upper_drugs) >= 2:
                    matches.append(r)
            return matches
    except Exception as e:
        print(f"[Supabase Check Warning] {e}", file=sys.stderr)
    return []

def save_interaction_to_supabase(rule: Dict[str, Any]):
    """Saves a new interaction rule into Supabase."""
    if not SUPABASE_KEY:
        return
    try:
        endpoint = f"{SUPABASE_URL}/rest/v1/vidal_drug_interactions"
        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        }
        requests.post(endpoint, headers=headers, json=rule, timeout=5)
        print(f"[Auto-Enrich] Saved '{rule.get('title')}' into Supabase!")
    except Exception as e:
        print(f"[Auto-Enrich Error] {e}", file=sys.stderr)

def process_prescription_safely(drug_names: List[str]) -> Dict[str, Any]:
    """
    Core pipeline:
    1. Check Supabase first.
    2. If needed, acquire VIDAL_LOCK and throttle query to Vidal IAM.
    3. Auto-enrich Supabase with any newly found interaction.
    """
    global LAST_VIDAL_CALL_TIME

    # Step 1: Check existing Supabase cache
    cached_rules = check_supabase_for_interactions(drug_names)
    if cached_rules:
        return {
            "source": "supabase_cache",
            "cached": True,
            "interactions_count": len(cached_rules),
            "interactions": cached_rules
        }

    # Step 2: Acquire strict rate-limiting mutex (Single request at a time)
    with VIDAL_LOCK:
        now = time.time()
        elapsed = now - LAST_VIDAL_CALL_TIME
        if elapsed < MIN_DELAY_SECONDS:
            time.sleep(MIN_DELAY_SECONDS - elapsed)

        analyzer = get_vidal_analyzer()
        analysis_result = analyzer.analyze_prescription(drug_names)
        LAST_VIDAL_CALL_TIME = time.time()

        resolved_drugs = analysis_result.get("resolvedDrugs") or analysis_result.get("resolved_drugs", [])
        interactions = analysis_result.get("interactions", [])

        # Step 3: Auto-enrich Supabase
        for item in interactions:
            sev_str = item.get("severityCode", "info").lower()
            if sev_str == "contraindicated":
                sev_lvl = 4
            elif sev_str == "disadvised":
                sev_lvl = 3
            elif sev_str == "precaution":
                sev_lvl = 2
            else:
                sev_lvl = 1

            new_rule = {
                "drug_a": [resolved_drugs[0]["name"].upper()] if len(resolved_drugs) > 0 else [],
                "drug_b": [resolved_drugs[1]["name"].upper()] if len(resolved_drugs) > 1 else [],
                "severity": sev_str,
                "severity_level": sev_lvl,
                "title": item.get("title", ""),
                "description": item.get("risk", ""),
                "recommendation": item.get("management", ""),
                "source": "vidal_live_enrichment"
            }
            save_interaction_to_supabase(new_rule)

        return {
            "source": "vidal_live_analysis",
            "cached": False,
            "resolved_drugs": resolved_drugs,
            "interactions_count": len(interactions),
            "interactions": interactions
        }

class PrescriptionProxyHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/analyze-prescription":
            content_length = int(self.headers.get("Content-Length", 0))
            post_data = self.rfile.read(content_length)
            try:
                payload = json.loads(post_data.decode("utf-8"))
                drugs = payload.get("drugs", [])
                if not drugs or len(drugs) < 2:
                    self.send_response(400)
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": "Provide at least 2 drugs."}).encode("utf-8"))
                    return

                result = process_prescription_safely(drugs)

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))

            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": str(e)}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

def run_server(port: int = 8085):
    server_address = ("", port)
    httpd = HTTPServer(server_address, PrescriptionProxyHandler)
    print(f"============================================================")
    print(f"MEDSINA VIDAL RATE-LIMITING PROXY SERVER STARTED")
    print(f"Listening on: http://localhost:{port}/api/analyze-prescription")
    print(f"Queue Mode: Strict Singleton Mutex (Anti-Ban Protection)")
    print(f"Self-Enrichment: Supabase -> {SUPABASE_URL}")
    print(f"============================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")
        httpd.server_close()

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Medsina Vidal Proxy Server")
    parser.add_argument("--port", type=int, default=8085, help="Port to listen on")
    parser.add_argument("--test", nargs="+", help="Test directly with drug names in CLI mode")
    args = parser.parse_args()

    if args.test:
        print(f"Testing prescription safely for: {args.test}")
        res = process_prescription_safely(args.test)
        print(json.dumps(res, indent=2, ensure_ascii=False))
    else:
        run_server(args.port)
