"""Render the bundled policy text as local HTML; never deploys or sends data."""

import argparse
from datetime import date
from html import escape
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("en", "hi")
PAGES = ("privacy", "support")


def validate_content(content):
    if content.get("schema") != 1 or not content.get("revision", "").strip():
        raise ValueError("Unsupported or incomplete policy content")
    if set(content.get("pages", {})) != set(PAGES):
        raise ValueError("Expected privacy and support pages")
    for page in content["pages"].values():
        ids = set()
        if not page.get("sections"):
            raise ValueError("Empty policy page")
        for section in page["sections"]:
            section_id = section.get("id", "")
            if not re.fullmatch(r"[a-z][a-z0-9-]*", section_id) or section_id in ids:
                raise ValueError("Invalid or duplicate section ID")
            ids.add(section_id)
        translations = [page["title"]]
        for section in page["sections"]:
            translations.extend((section["title"], section["body"]))
        for translation in translations:
            if any(not translation.get(lang, "").strip() for lang in LANGUAGES):
                raise ValueError("Missing policy translation")


def valid_https(value):
    if not isinstance(value, str):
        return False
    url = urlsplit(value)
    return (url.scheme == "https" and bool(url.hostname) and not url.username
            and not url.password and not url.fragment and not url.query
            and url.hostname not in ("localhost", "example.com", "example.invalid")
            and not url.hostname.endswith((".invalid", ".example", ".test")))


def validate_public_config(content, config):
    """Rendering prerequisites, not certification or evidence of working services."""
    errors = []
    for field in ("operatorName", "supportEmail", "baseUrl", "effectiveDate",
                  "accountDeletionUrl", "reviewedContentRevision"):
        if not isinstance(config.get(field), str) or not config[field].strip():
            errors.append(f"Missing {field}")
    email = config.get("supportEmail", "")
    if not re.fullmatch(r"[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+", email):
        errors.append("A real support email is required")
    elif email.rsplit("@", 1)[-1].endswith((".invalid", ".example", ".test")):
        errors.append("Placeholder email is not a public contact")
    for field in ("baseUrl", "accountDeletionUrl"):
        try:
            valid = valid_https(config.get(field, ""))
        except ValueError:
            valid = False
        if not valid:
            errors.append(f"{field} must be a real HTTPS URL without credentials/query/fragment")
    try:
        date.fromisoformat(config.get("effectiveDate", ""))
    except ValueError:
        errors.append("effectiveDate must be a reviewed ISO date")
    if config.get("accountDeletionInApp") is not True:
        errors.append("Reachable signup requires an implemented in-app deletion request path")
    if ("draft" in content["revision"].lower()
            or config.get("reviewedContentRevision") != content["revision"]):
        errors.append("Content must be revised and reviewed before a public render")
    # Operator and deletion status are part of the shared notice, not merely HTML.
    pending_markers = ("not configured", "unpublished", "not implemented", "still need operator review")
    if any(marker in json.dumps(content, ensure_ascii=False).lower()
           for marker in pending_markers):
        errors.append("Shared notice still describes unresolved test-build release gates")
    if errors:
        raise ValueError("Public render blocked:\n- " + "\n- ".join(errors))


def render_page(content, page_id, language, draft, config):
    page = content["pages"][page_id]
    title = escape(page["title"][language])
    other = "hi" if language == "en" else "en"
    nav_links = []
    for key in PAGES:
        current = ' aria-current="page"' if key == page_id else ""
        nav_links.append(f'<a href="{key}-{language}.html"{current}>'
                         f'{escape(content["pages"][key]["title"][language])}</a>')
    nav = "".join(nav_links)
    contents = "".join(
        f'<li><a href="#{section["id"]}">{escape(section["title"][language])}</a></li>'
        for section in page["sections"])
    sections = "".join(
        f'<section id="{section["id"]}" aria-labelledby="heading-{section["id"]}">'
        f'<h2 id="heading-{section["id"]}">{escape(section["title"][language])}</h2>'
        f'<p>{escape(section["body"][language])}</p></section>'
        for section in page["sections"])
    status = ("Unpublished draft — operator and contact details are pending."
              if language == "en" else "अप्रकाशित मसौदा — संचालक और संपर्क विवरण बाकी हैं।")
    banner = f'<p class="draft" role="note">{status}</p>' if draft else ""
    contact = ""
    if not draft:
        contact = (f'<p>{escape(config["operatorName"])} · '
                   f'{escape(config["supportEmail"])} · {escape(config["effectiveDate"])}</p>'
                   f'<p><a href="{escape(config["accountDeletionUrl"], quote=True)}">'
                   f'{"Request account deletion" if language == "en" else "खाता मिटाने का अनुरोध करें"}</a></p>')
    skip = "Skip to content" if language == "en" else "मुख्य सामग्री पर जाएँ"
    contents_label = "On this page" if language == "en" else "इस पेज पर"
    return f'''<!doctype html>
<html lang="{language}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light"><meta name="robots" content="{"noindex,nofollow" if draft else "index,follow"}">
<title>{title} · Medicine Reminder</title><link rel="stylesheet" href="style.css"></head>
<body><a class="skip" href="#content">{skip}</a><header><a class="brand" href="index.html">Medicine Reminder</a>
<nav aria-label="{"Pages" if language == "en" else "पेज"}">{nav}<a href="{page_id}-{other}.html" lang="{other}" hreflang="{other}">{"हिन्दी" if other == "hi" else "English"}</a></nav></header>
<main id="content">{banner}<h1>{title}</h1>{contact}
<nav class="contents" aria-label="{contents_label}"><h2>{contents_label}</h2><ol>{contents}</ol></nav>{sections}
<footer><p>{escape(content["revision"])}</p></footer></main></body></html>
'''


CSS = """*{box-sizing:border-box}html{scroll-behavior:auto}body{margin:0;color:#18382f;background:#fcfcf8;font:1.0625rem/1.75 system-ui,sans-serif}a{color:#075c45;text-underline-offset:.22em;overflow-wrap:anywhere}a:focus-visible{outline:3px solid #853e16;outline-offset:4px}header{padding:1.25rem clamp(1rem,5vw,4rem);border-bottom:1px solid #bdccc2;display:flex;gap:1rem;align-items:center;justify-content:space-between;flex-wrap:wrap}header nav{display:flex;gap:1.25rem;flex-wrap:wrap}.brand{font-weight:750;font-size:1.35rem;text-decoration:none}main{max-width:76ch;margin:auto;padding:2.5rem 1.25rem 4rem}h1{font-size:clamp(2rem,5vw,3rem);line-height:1.2;font-weight:650;letter-spacing:-.035em}h2{font-size:1.4rem;line-height:1.4;margin:0 0 .6rem}section{padding:1.75rem 0;border-top:1px solid #d1dbd3;scroll-margin-top:1rem}p{margin:.5rem 0;overflow-wrap:anywhere}.draft{border-left:4px solid #853e16;padding:.6rem 1rem;background:#fff1db;color:#64300f}.contents{margin:2rem 0}.contents li{padding:.2rem 0}footer{border-top:1px solid #bdccc2;font-size:.9rem;padding-top:1rem}.skip{position:absolute;left:1rem;top:-10rem;background:white;padding:1rem;z-index:2}.skip:focus{top:1rem}[aria-current=page]{font-weight:750}@media print{header,.contents,.skip{display:none}main{max-width:none;padding:0}section{break-inside:avoid}.draft{background:none}}"""


def write_site(content, config, output, draft):
    validate_content(content)
    if not draft:
        validate_public_config(content, config)
    output.mkdir(parents=True, exist_ok=True)
    for page in PAGES:
        for language in LANGUAGES:
            (output / f"{page}-{language}.html").write_text(
                render_page(content, page, language, draft, config), encoding="utf-8")
    (output / "index.html").write_text(
        render_page(content, "privacy", "en", draft, config), encoding="utf-8")
    (output / "style.css").write_text(CSS, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--draft", action="store_true", help="Explicit unpublished/noindex preview")
    parser.add_argument("--output", type=Path, default=ROOT / "build/med-034/site")
    parser.add_argument("--config", type=Path, default=ROOT / "docs/launch/site-config.example.json")
    args = parser.parse_args()
    try:
        content = json.loads((ROOT / "assets/policies.json").read_text(encoding="utf-8"))
        config = json.loads(args.config.read_text(encoding="utf-8"))
        write_site(content, config, args.output, args.draft)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"{error}\n")
    print(f"Rendered {'unpublished draft' if args.draft else 'review candidate'} to {args.output}")


if __name__ == "__main__":
    main()
