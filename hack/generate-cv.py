#!/usr/bin/env python3
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import yaml
from jinja2 import Environment, FileSystemLoader

def escape_tex(text):
    if not isinstance(text, str):
        return text
    # Avoid double escaping if string contains LaTeX commands
    if r'\href' in text or r'\textbf' in text or r'\faGithub' in text:
        return text

    # Custom replacements for exact LaTeX parity
    text = text.replace('Nix / NixOS', r'Nix\slash NixOS')
    text = text.replace('Spark+AI', r'Spark\texttt{+}AI')

    # General TeX special characters
    replacements = [
        ('&', r'\&'),
        ('%', r'\%'),
        ('_', r'\_'),
        ('#', r'\#'),
        ('$', r'\$'),
    ]
    for old, new in replacements:
        text = text.replace(old, new)
    return text

def prepare_data(data):
    # Deep copy dictionary with TeX-specific strings
    data = yaml.safe_load(yaml.dump(data))

    # Personal
    for k, v in list(data.get('personal', {}).items()):
        if isinstance(v, str):
            data['personal'][k + '_tex'] = escape_tex(v)

    # Skills
    for cat in data.get('skills', []):
        cat['category_tex'] = escape_tex(cat['category'])
        for item in cat.get('items', []):
            item['name_tex'] = escape_tex(item['name'])

    # Experience
    for exp in data.get('experience', []):
        exp['company_tex'] = escape_tex(exp['company'])
        exp['role_tex'] = escape_tex(exp['role'])
        exp['description_tex'] = escape_tex(exp['description'])
        exp['hard_chips_tex'] = [escape_tex(c) for c in exp.get('hard_chips', [])]
        exp['soft_chips_tex'] = [escape_tex(c) for c in exp.get('soft_chips', [])]

    # Education
    for edu in data.get('education', []):
        edu['institution_tex'] = escape_tex(edu['institution'])
        edu['degree_tex'] = escape_tex(edu['degree'])
        if 'thesis_title' in edu:
            edu['thesis_title_tex'] = escape_tex(edu['thesis_title'])

    # Projects
    for prj in data.get('projects', {}).get('hobby', []):
        prj['name_tex'] = escape_tex(prj['name'])
        prj['description_tex'] = escape_tex(prj['description'])
        prj['hard_chips_tex'] = [escape_tex(c) for c in prj.get('hard_chips', [])]
        prj['soft_chips_tex'] = [escape_tex(c) for c in prj.get('soft_chips', [])]

    for pub in data.get('projects', {}).get('publications', []):
        pub['title_tex'] = escape_tex(pub['title'])

    return data

def main():
    parser = argparse.ArgumentParser(description='Generate CV outputs from templates.')
    parser.add_argument('--src-dir', default='src/cv',
                        help='Directory containing cv.yaml, cv.cls, and templates/ (default: src/cv)')
    parser.add_argument('--html-output-dir', default='src/cv',
                        help='Directory to place generated index.html (default: src/cv)')
    parser.add_argument('--pdf-output-dir', default='src/assets',
                        help='Directory to place generated PDF (default: src/assets)')
    parser.add_argument('--build-dir', default=None,
                        help='Directory for intermediate LaTeX compilation (default: temporary directory)')
    parser.add_argument('--with-latex', action='store_true', default=False,
                        help='Explicitly enable LaTeX generation, PDF compilation, and PDF download button')
    args = parser.parse_args()

    with_latex = args.with_latex

    # Project root is the parent of hack/
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src_dir = os.path.isabs(args.src_dir) and args.src_dir or os.path.join(root_dir, args.src_dir)
    html_output_dir = os.path.isabs(args.html_output_dir) and args.html_output_dir or os.path.join(root_dir, args.html_output_dir)
    pdf_output_dir = os.path.isabs(args.pdf_output_dir) and args.pdf_output_dir or os.path.join(root_dir, args.pdf_output_dir)

    yaml_path = os.path.join(src_dir, 'cv.yaml')

    if not os.path.exists(yaml_path):
        print(f"Error: {yaml_path} not found.")
        sys.exit(1)

    with open(yaml_path, 'r', encoding='utf-8') as f:
        raw_data = yaml.safe_load(f)

    data = prepare_data(raw_data)
    templates_dir = os.path.join(src_dir, 'templates')

    # HTML Environment — rendered directly to html-output-dir
    os.makedirs(html_output_dir, exist_ok=True)
    html_env = Environment(
        loader=FileSystemLoader(templates_dir),
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True
    )
    html_template = html_env.get_template('cv.html.j2')
    html_output = html_template.render(with_latex=with_latex, **data)

    html_path = os.path.join(html_output_dir, 'index.html')
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html_output)
    print(f"Generated {html_path}")

    # LaTeX & PDF Compilation — when --with-latex is explicitly passed
    if with_latex:
        if args.build_dir:
            compile_dir = os.path.isabs(args.build_dir) and args.build_dir or os.path.join(root_dir, args.build_dir)
            os.makedirs(compile_dir, exist_ok=True)
            _compile_pdf(src_dir, templates_dir, compile_dir, data, pdf_output_dir, root_dir)
        else:
            with tempfile.TemporaryDirectory() as tmp_dir:
                _compile_pdf(src_dir, templates_dir, tmp_dir, data, pdf_output_dir, root_dir)

def _compile_pdf(src_dir, templates_dir, compile_dir, data, pdf_output_dir, root_dir):
    tex_env = Environment(
        loader=FileSystemLoader(templates_dir),
        block_start_string='((%',
        block_end_string='%))',
        variable_start_string='((',
        variable_end_string='))',
        comment_start_string='((#',
        comment_end_string='#))',
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True
    )
    tex_template = tex_env.get_template('david_szakallas.tex.j2')
    tex_output = tex_template.render(**data)
    tex_path = os.path.join(compile_dir, 'david_szakallas.tex')
    with open(tex_path, 'w', encoding='utf-8') as f:
        f.write(tex_output)

    # Copy cv.cls to compile directory
    cls_src = os.path.join(src_dir, 'cv.cls')
    cls_dst = os.path.join(compile_dir, 'cv.cls')
    if os.path.exists(cls_src):
        shutil.copy2(cls_src, cls_dst)

    # Compile LaTeX with xelatex
    print("Compiling LaTeX to PDF with xelatex...")
    res = subprocess.run(
        ['xelatex', '-interaction=nonstopmode', 'david_szakallas.tex'],
        cwd=compile_dir,
        capture_output=True,
        text=True
    )
    if res.returncode != 0:
        print(f"Error compiling LaTeX:\n{res.stdout}\n{res.stderr}")
        sys.exit(res.returncode)

    pdf_src = os.path.join(compile_dir, 'david_szakallas.pdf')
    if os.path.exists(pdf_src):
        os.makedirs(pdf_output_dir, exist_ok=True)
        dst_assets = os.path.join(pdf_output_dir, 'david_szakallas.pdf')
        dst_root = os.path.join(root_dir, 'src', 'david_szakallas.pdf')
        shutil.copy2(pdf_src, dst_assets)
        shutil.copy2(pdf_src, dst_root)
        print(f"Generated PDF: {dst_assets} and {dst_root}")

if __name__ == '__main__':
    main()
