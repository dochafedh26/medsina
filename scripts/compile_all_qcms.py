import re
import json
import sys
import os
import glob
import unicodedata

sys.stdout.reconfigure(encoding='utf-8')

def normalize_key(s):
    if not s:
        return ''
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn').lower()
    return re.sub(r'[^a-z0-9]', '', s)

def tokenize(s):
    if not s:
        return set()
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn').lower()
    words = re.findall(r'[a-z0-9]{3,}', s)
    return set(words) - {'des', 'les', 'pour', 'avec', 'dans', 'une', 'qui', 'par', 'sur', 'aux', 'non'}

def parse_md_questions(md_content, course_id, course_name, module_id):
    questions = []
    raw_blocks = re.split(r'\n(?=### Q\d+\.)', md_content)
    for block in raw_blocks:
        if not block.strip().startswith('### Q'):
            continue
        
        # 1. Question text
        m_q = re.search(r'### Q\d+\.\s*(.*?)(?=\n\n|\n\*Type:|\n- \[)', block, re.DOTALL)
        if not m_q:
            continue
        q_text = m_q.group(1).strip()
        
        # 2. Metadata (Type, Source, Year)
        q_type = 'QCM'
        source = 'Concours'
        year = 2024
        
        m_type = re.search(r'\*Type:\s*([^*|]+)\*', block)
        if m_type:
            raw_t = m_type.group(1).strip().upper()
            if 'QCS' in raw_t:
                q_type = 'qcs'
            elif 'CAS' in raw_t:
                q_type = 'casClinique'
            elif 'QROC' in raw_t:
                q_type = 'qroc'
            else:
                q_type = 'qcm'
        else:
            q_type = 'qcm'
            
        m_src = re.search(r'\*Source:\s*([^*|\n]+)\*', block)
        if m_src:
            source = m_src.group(1).strip()
            years = re.findall(r'\b(20\d\d|19\d\d)\b', source)
            if years:
                year = int(years[-1])

        # 3. Options
        options = []
        opt_matches = re.finditer(r'^- \[( |x)\] \*\*\[([A-Z])\]\*\*\s*(.*)$', block, re.MULTILINE)
        found_checked = []
        for match in opt_matches:
            checked = match.group(1)
            opt_key = match.group(2)
            opt_text = match.group(3).strip()
            if checked == 'x':
                found_checked.append(opt_key)
            cleaned_text = re.sub(r'\s*\*\([A-Z\s]+\)\*\s*$', '', opt_text).strip()
            options.append({'key': opt_key, 'text': cleaned_text})
            
        # 4. Correct answers
        m_ans = re.search(r'\*\*Réponse\(s\)\s+correcte\(s\)\*\*\s*:\s*`([^`]+)`', block)
        if m_ans:
            raw_ans = m_ans.group(1).strip()
            correct_answers = [a.strip() for a in re.split(r'[,;\s]+', raw_ans) if a.strip()]
        else:
            correct_answers = found_checked
            
        # 5. Explanation
        m_exp = re.search(r'<details><summary><b>Explication détaillée</b></summary>\s*(.*?)\s*</details>', block, re.DOTALL)
        explanation = ''
        if m_exp:
            explanation = m_exp.group(1).strip()
            
        q_id = f'{course_id}_{len(questions)+1}'
        questions.append({
            'id': q_id,
            'moduleId': module_id,
            'courseId': course_id,
            'courseName': course_name,
            'type': q_type,
            'questionText': q_text,
            'options': options,
            'correctAnswers': correct_answers,
            'explanation': explanation,
            'source': source,
            'year': year,
        })
    return questions

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    catalog_path = os.path.join(root_dir, 'medsina', 'assets', 'data', 'modules_catalog_47.json')
    qcms_export_dir = os.path.join(root_dir, 'exports', 'qcms')
    output_dir = os.path.join(root_dir, 'medsina', 'assets', 'data', 'qcms')
    os.makedirs(output_dir, exist_ok=True)
    
    with open(catalog_path, 'r', encoding='utf-8') as f:
        modules = json.load(f)
        
    # Group exported md files by directory
    dir_map = {}
    for r, dirs, files in os.walk(qcms_export_dir):
        mds = [f for f in files if f.endswith('.md')]
        if mds:
            dname = os.path.basename(r)
            dir_map[normalize_key(dname)] = [(os.path.join(r, f), f) for f in mds]
            
    total_parsed_questions = 0
    total_courses_with_q = 0
    module_stats = []

    for m in modules:
        mod_id = m['id']
        mod_name = m['name']
        norm_mod = normalize_key(mod_name)
        mod_files = dir_map.get(norm_mod, [])
        
        module_questions = []
        
        for c in m.get('courses', []):
            course_id = c['id']
            course_name = c['name']
            c_norm = normalize_key(course_name)
            c_tokens = tokenize(course_name)
            
            # Find matching MD file
            found_path = None
            for path, fname in mod_files:
                base = re.sub(r'_qcm\.md$', '', fname, flags=re.IGNORECASE)
                base = re.sub(r'\.md$', '', base, flags=re.IGNORECASE)
                if normalize_key(base) == c_norm or normalize_key(re.sub(r'\(.*?\)', '', base)) == normalize_key(re.sub(r'\(.*?\)', '', course_name)):
                    found_path = path
                    break
                    
            if not found_path and c_tokens:
                best_score = 0
                best_match = None
                for path, fname in mod_files:
                    base = re.sub(r'_qcm\.md$', '', fname, flags=re.IGNORECASE)
                    f_tokens = tokenize(base)
                    overlap = len(c_tokens & f_tokens)
                    if overlap > best_score:
                        best_score = overlap
                        best_match = path
                if best_score >= 1 and (best_score >= len(c_tokens) * 0.4 or best_score >= 2):
                    found_path = best_match

            if found_path:
                try:
                    with open(found_path, 'r', encoding='utf-8', errors='ignore') as fp:
                        qs = parse_md_questions(fp.read(), course_id, course_name, mod_id)
                        if qs:
                            module_questions.extend(qs)
                            total_courses_with_q += 1
                except Exception as ex:
                    print(f"Error parsing {found_path}: {ex}")

        # Save module questions JSON
        safe_mod_filename = re.sub(r'[^a-zA-Z0-9_-]', '_', mod_id) + '.json'
        mod_out_file = os.path.join(output_dir, safe_mod_filename)
        with open(mod_out_file, 'w', encoding='utf-8') as out_f:
            json.dump(module_questions, out_f, ensure_ascii=False, indent=2)
            
        total_parsed_questions += len(module_questions)
        module_stats.append((mod_name, len(module_questions), len(m.get('courses', []))))
        print(f"✅ Module '{mod_name}': {len(module_questions)} questions saved to {safe_mod_filename}")

    print(f"\n==========================================")
    print(f"🎉 Total questions compiled: {total_parsed_questions}")
    print(f"📚 Total courses with questions: {total_courses_with_q}")
    print(f"📁 Output directory: {output_dir}")
    print(f"==========================================")

if __name__ == '__main__':
    main()

