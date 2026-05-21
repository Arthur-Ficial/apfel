import sys
import json

def extract_inline_content(elements, references):
    if not elements:
        return ""
    text = ""
    for elem in elements:
        e_type = elem.get('type')
        if e_type == 'text':
            text += elem.get('text', '')
        elif e_type == 'codeVoice':
            text += f"`{elem.get('code', '')}`"
        elif e_type == 'reference':
            ref_id = elem.get('identifier', '')
            if ref_id:
                ref_data = references.get(ref_id, {})
                ref_title = ref_data.get('title', '')
                if ref_title:
                    text += f"`{ref_title}`"
                else:
                    fallback = ref_id.rstrip('/').split('/')[-1]
                    if fallback:
                        text += f"`{fallback}`"
        elif e_type == 'strong':
            text += f"**{elem.get('strong', '')}**"
        elif e_type == 'emphasis':
            text += f"*{elem.get('emphasis', '')}*"
    return text

def parse_content_block(block, references):
    b_type = block.get('type')
    if b_type == 'heading':
        level = block.get('level', 3)
        inline = block.get('inlineContent', [])
        if inline:
            heading_text = extract_inline_content(inline, references)
        else:
            heading_text = block.get('text', '')
        return f"{'#' * level} {heading_text}"
    elif b_type == 'paragraph':
        return extract_inline_content(block.get('inlineContent', []), references)
    elif b_type == 'codeListing':
        code = "\n".join(block.get('code', []))
        syntax = block.get('syntax', 'swift')
        return f"```{syntax}\n{code}\n```"
    elif b_type == 'unorderedList' or b_type == 'orderedList':
        list_items = []
        for index, item in enumerate(block.get('items', [])):
            item_content = item.get('content', [])
            item_text = ""
            for ic in item_content:
                item_text += parse_content_block(ic, references)
            prefix = f"{index + 1}. " if b_type == 'orderedList' else "* "
            list_items.append(f"{prefix}{item_text}")
        return "\n".join(list_items)
    return ""

def parse_docc_json(data):
    title = data.get('metadata', {}).get('title', '')
    role = data.get('metadata', {}).get('roleHeading', '')
    references = data.get('references', {})
    
    # 1. Parse Abstract
    abstract_text = extract_inline_content(data.get('abstract', []), references)
            
    # 2. Parse Primary Content Sections
    sections_text = []
    for section in data.get('primaryContentSections', []):
        kind = section.get('kind')
        if kind == 'declarations':
            decs = section.get('declarations', [])
            if decs:
                tokens = decs[0].get('tokens', [])
                sig = "".join([t.get('text', '') for t in tokens])
                sections_text.append(f"## Declaration\n```swift\n{sig}\n```")
        elif kind == 'parameters':
            params_text = ["## Parameters\n"]
            for param in section.get('parameters', []):
                name = param.get('name', '')
                content = param.get('content', [])
                desc = ""
                for block in content:
                    desc += parse_content_block(block, references)
                params_text.append(f"* **{name}**: {desc}")
            sections_text.append("\n".join(params_text))
        elif kind == 'content':
            content_blocks = section.get('content', [])
            overview_text = []
            for block in content_blocks:
                p = parse_content_block(block, references)
                if p:
                    overview_text.append(p)
            if overview_text:
                sections_text.append("\n\n".join(overview_text[:8]))
                
    output = []
    output.append(f"# {role} {title}\n")
    if abstract_text:
        output.append(abstract_text + "\n")
    output.extend(sections_text)
    
    return "\n\n".join(output)

if __name__ == '__main__':
    try:
        raw_data = json.load(sys.stdin)
        parsed_md = parse_docc_json(raw_data)
        print(parsed_md)
    except Exception as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
