#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import os
import sys

SCANNING_DIR = sys.argv[1]
OUTPUT_LIST_FILE = sys.argv[2]
print(f"[*] scanning directory: {SCANNING_DIR}")

# use regex to find the string
# eg ::License.feature_available?(:aaa) || ::Feature.enabled?(:bbb, self)
# make sure +? for shortest match
REGEX_PARTTERN = "License.feature_available\?\(:.+?\)"

REQUIRED_FILE_SUFFIX = ['rb']

scanning_file_list = set()
def build_file_list(input: str):
    global scanning_file_list
    scanning_file_list.add(input)
    if os.path.isdir(input):
        for file in os.listdir(input): 
            build_file_list(os.path.join(input, file))
build_file_list(SCANNING_DIR)

print(f"[*] scanning {len(scanning_file_list)} files...")
feature_list=set()
for file in scanning_file_list:
    if not os.path.isfile(file): continue
    if not file.split(".")[-1] in REQUIRED_FILE_SUFFIX: continue
    with open(file, "r") as f:
        content = f.read()
        all_match = re.findall(REGEX_PARTTERN, content)
        all_match = [x.split(":")[1].split(")")[0] for x in all_match]
        all_match = [x for x in all_match if x]
        feature_list.update(all_match)
print(f"[*] found {len(feature_list)} features")

feature_list = list(feature_list)
feature_list.sort()

print(f"[*] writing to {OUTPUT_LIST_FILE}...")
with open(OUTPUT_LIST_FILE, "w") as f:
    for feature in feature_list:
        f.write(feature + "\n")

print(f"[*] done")
