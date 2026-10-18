import unittest

from upcatalog import licenses as L


class LicenseTest(unittest.TestCase):
    def test_from_url(self):
        cases = {
            "http://creativecommons.org/licenses/by/3.0/": "CC-BY-3.0",
            "https://creativecommons.org/licenses/by-sa/4.0/deed.en": "CC-BY-SA-4.0",
            "http://creativecommons.org/licenses/by-nc/4.0/": "CC-BY-NC-4.0",
            "https://creativecommons.org/licenses/by-nc-sa/4.0/": "CC-BY-NC-SA-4.0",
            "http://creativecommons.org/licenses/by-nc/3.0/": "CC-BY-NC-3.0",
            "http://creativecommons.org/licenses/by-nc-sa/3.0/": "CC-BY-NC-SA-3.0",
            "https://creativecommons.org/publicdomain/zero/1.0/": "CC0-1.0",
            "https://creativecommons.org/publicdomain/mark/1.0/": "PD",
        }
        for url, want in cases.items():
            self.assertEqual(L.from_url(url), want)

    def test_rejects_unknown_or_nd_or_old_nc(self):
        for url in (
            "https://creativecommons.org/licenses/by-nd/4.0/",
            "https://creativecommons.org/licenses/by-nc-nd/3.0/",
            "http://creativecommons.org/licenses/sampling+/1.0/",  # ccMixter 的 Sampling Plus
            "https://example.com/license",
            "",
        ):
            with self.assertRaises(L.LicenseError, msg=url):
                L.from_url(url)
        with self.assertRaises(L.LicenseError):
            L.require("MIT")

    def test_flags(self):
        self.assertTrue(L.commercial_ok("CC-BY-4.0"))
        self.assertFalse(L.commercial_ok("CC-BY-NC-4.0"))
        self.assertTrue(L.share_alike("CC-BY-SA-3.0"))
        self.assertTrue(L.share_alike("CC-BY-NC-SA-4.0"))
        self.assertFalse(L.share_alike("CC0-1.0"))

    def test_attribution(self):
        self.assertEqual(L.attribution("A", "B", "CC0-1.0"), "“A” by B, CC0 1.0")


if __name__ == "__main__":
    unittest.main()
