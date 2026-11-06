import re
import json
import sys
import os

sys.stdout.reconfigure(encoding='utf-8')

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
                q_type = 'QCS'
            elif 'CAS' in raw_t:
                q_type = 'casClinique'
            elif 'QROC' in raw_t:
                q_type = 'qroc'
            else:
                q_type = 'QCM'
            
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

sample_file = '../exports/qcms/Anatomie (1 ère)/Muscles de la hanche et de la cuisse_QCM.md'
with open(sample_file, 'r', encoding='utf-8') as f:
    parsed = parse_md_questions(f.read(), 'Blida_ANATOMIE_1_ERE_MUSCLES_DE_LA_HANCHE_ET_DE_LA_CUISSE', 'Muscles de la hanche et de la cuisse', 'Blida_ANATOMIE_1_ERE')

print(f'Parsed {len(parsed)} questions from Muscles de la hanche et de la cuisse!')
print(json.dumps(parsed[0], indent=2, ensure_ascii=False))

