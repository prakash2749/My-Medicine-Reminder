import copy
from html.parser import HTMLParser
import json
from pathlib import Path
import tempfile
import unittest

import render_policy_site as site


class PageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.external_resources = []
        self.scripts = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a":
            self.links.append(attrs["href"])
        if tag == "script":
            self.scripts += 1
        if tag in ("link", "img", "script", "iframe"):
            self.external_resources.append(attrs.get("href", attrs.get("src", "")))


class PolicySiteTests(unittest.TestCase):
    def setUp(self):
        self.content = json.loads((site.ROOT / "assets/policies.json").read_text(encoding="utf-8"))
        self.config = json.loads((site.ROOT / "docs/launch/site-config.example.json").read_text())

    def test_all_draft_pages_are_local_accessible_and_have_resolving_links(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            site.write_site(self.content, self.config, output, True)
            for path in output.glob("*.html"):
                text = path.read_text(encoding="utf-8")
                parser = PageParser()
                parser.feed(text)
                self.assertIn("noindex,nofollow", text)
                self.assertIn('role="note"', text)
                self.assertIn("<main", text)
                self.assertEqual(parser.scripts, 0)
                self.assertEqual(parser.external_resources, ["style.css"])
                for link in parser.links:
                    if link.startswith("#"):
                        self.assertIn(link[1:], parser.ids)
                    else:
                        self.assertTrue((output / link).is_file(), link)
                page_id = "support" if path.name.startswith("support") else "privacy"
                language = "hi" if '-hi.html' in path.name else "en"
                for section in self.content["pages"][page_id]["sections"]:
                    self.assertIn(section["id"], parser.ids)
                    self.assertIn(site.escape(section["title"][language]), text)
                    self.assertIn(site.escape(section["body"][language]), text)
            self.assertEqual(len(list(output.iterdir())), 6)

    def test_non_draft_render_is_blocked_before_creating_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "blocked"
            with self.assertRaisesRegex(ValueError, "Public render blocked"):
                site.write_site(self.content, self.config, output, False)
            self.assertFalse(output.exists())

    def test_metadata_alone_cannot_turn_pending_content_into_public_notice(self):
        self.config.update(operatorName="Synthetic operator", supportEmail="support@medicine-demo.org",
                           baseUrl="https://medicine-demo.org", effectiveDate="2026-10-18",
                           accountDeletionUrl="https://medicine-demo.org/deletion",
                           accountDeletionInApp=True, reviewedContentRevision=self.content["revision"])
        with self.assertRaisesRegex(ValueError, "Content must be revised"):
            site.validate_public_config(self.content, self.config)
        self.content["revision"] = self.config["reviewedContentRevision"] = "review-candidate"
        with self.assertRaisesRegex(ValueError, "Shared notice still describes"):
            site.validate_public_config(self.content, self.config)

    def test_content_and_contact_are_html_escaped(self):
        self.content["pages"]["privacy"]["sections"][0]["body"]["en"] = '<script>alert("secret")</script> & details'
        text = site.render_page(self.content, "privacy", "en", True, self.config)
        self.assertNotIn('<script>', text)
        self.assertIn('&lt;script&gt;', text)
        self.assertIn('&amp; details', text)

    def test_translation_or_duplicate_section_failure_is_not_silently_rendered(self):
        for invalid in ("missing", "duplicate"):
            content = copy.deepcopy(self.content)
            sections = content["pages"]["privacy"]["sections"]
            if invalid == "missing":
                del sections[0]["body"]["hi"]
            else:
                sections[1]["id"] = sections[0]["id"]
            with self.assertRaises(ValueError):
                site.validate_content(content)

    def test_public_urls_cannot_include_credentials_or_placeholder_hosts(self):
        for value in ("http://host.org", "https://user:password@host.org", "https://example.invalid",
                      "https://host.org/#secret", "https://host.org/?token=secret"):
            self.assertFalse(site.valid_https(value), value)


if __name__ == "__main__":
    unittest.main()
