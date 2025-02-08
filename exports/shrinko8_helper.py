from pico_process import SubLanguageBase
from collections import Counter

class SplitKeysSubLang(SubLanguageBase):
    # parses the string
    def __init__(self, str, **_):
        self.data = [item.split("=") for item in str.split(",")]

    # counts usage of keys
    # (returned keys are ignored if they're not identifiers)
    def get_member_usages(self, **_):
        return Counter(item[0] for item in self.data if len(item) > 1)

    # renames the keys
    def rename(self, members, **_):
        for item in self.data:
            if len(item) > 1:
                item[0] = members.get(item[0], item[0])

    # formats back to string
    def minify(self, **_):
        return ",".join("=".join(item) for item in self.data)

def sublanguage_main(lang, **_):
    if lang == "mem_addresses":
        return SplitKeysSubLang